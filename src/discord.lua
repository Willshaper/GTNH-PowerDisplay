-- Optional Discord messages through a webhook: low power, empty soon, maintenance,
-- no values for a few minutes, generators started or stopped, and the program
-- starting. Requests go straight to the internet card and are never waited for:
-- each one is checked on later updates, so a slow or unreachable Discord can't hold
-- up the display. Nothing here may stop the display, so every public function
-- catches its own errors.
local component = require('component')
local computer = require('computer')
local filesystem = require('filesystem')
local format = require('src.format')

local discord = {}

local FLAP_COOLDOWN = 1800 -- seconds before an alert that cleared is sent again
local LOST_SECONDS = 120 -- no values for this long: "can't be read" is sent
local LOW_POWER_MARGIN = 2 -- % above lowPower before low power is over (so it doesn't flicker)
local EMPTY_SOON_CLEAR = 2 -- "empty soon" is over once the time left is twice discordEmptySoonMinutes
local REQUEST_TIMEOUT = 30 -- seconds before a request without an answer is given up
local MAX_OPEN = 2 -- requests open at once (an internet card allows 4 connections)
local MAX_QUEUE = 20 -- messages waiting to be sent; the oldest are dropped beyond this
local MAX_ATTEMPTS = 3 -- tries per message for errors other than rate limits
local MAX_RATE_LIMITED = 5 -- tries per message when Discord answers "too many requests"
local RETRY_WAIT = 60 -- seconds before a message that failed to send is tried again
local CLOCK_FILE = '/tmp/.powerdisplay_clock'
local RED, GREEN, GRAY = 0xE74C3C, 0x2ECC71, 0x95A5A6
local HEADERS = {
  ['Content-Type'] = 'application/json',
  ['User-Agent'] = 'DiscordBot (https://github.com/Willshaper/GTNH-PowerDisplay, 1)',
}

-- From config.lua, via discord.configure()
local settings = {}
local url, name, mention = '', '', ''
local onWarning -- prints a problem for the player

-- From the program, via discord.started(): the titles of its messages
local texts = {}
local startPending = false -- the "started" message is sent with the next update

local cardChecked = false -- whether the internet card was checked since config.lua was loaded
local cardOk = false
local disabled = false -- Discord rejected the webhook; off until config.lua is loaded again
local warned = {} -- problems already printed, so each is printed once
local problems = {} -- key -> problem with sending, while it lasts (for the screen)

local alerts = {} -- kind -> {since, reported, lastSent} while the alert is on
local lastReport = {} -- kind -> uptime of its last message (kept after it clears)
local lastSeen -- uptime of the last values
local generatorsRunning -- the generators' state at the last update

local queue = {} -- messages waiting to be sent: {body, attempts, limited, notBefore}
local open = {} -- requests sent and not answered yet: {handle, item, started}
local waitUntil = 0 -- uptime before which nothing is sent (Discord's rate limit)

-- Hides the webhook URL (and any other web address) in text that is shown:
-- anyone who has it can post to the channel
local function hideUrls(text)
  text = tostring(text)
  if url:find('^https?://') then
    local start, stop = text:find(url, 1, true)
    while start do
      text = text:sub(1, start - 1) .. '<webhook URL>' .. text:sub(stop + 1)
      start, stop = text:find(url, start + 13, true)
    end
  end
  return (text:gsub('https?://[^%s"\'<>]+', '<URL>'))
end

-- A problem with sending, e.g. no internet card. Short, to fit the screen's footer.
local function warn(key, message)
  problems[key] = message
  if not warned[key] then
    warned[key] = true
    if onWarning then
      onWarning(message)
    end
  end
end

-- JSON --------------------------------------------------------------------------

local ARRAY = {} -- metatable that marks a table as a JSON array, so an empty one is []
local function array(list)
  return setmetatable(list, ARRAY)
end

local ESCAPES = {['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r',
  ['\t'] = '\\t'}

-- A JSON string of plain ASCII. OpenComputers sends the body in the server's default
-- charset, so everything else is written as \uXXXX, decoded from UTF-8 by hand.
-- A byte that isn't valid UTF-8 becomes U+FFFD.
local function encodeString(text)
  if not text:find('[%c"\\\128-\255]') then
    return '"' .. text .. '"'
  end
  local out = {'"'}
  local i, size = 1, #text
  while i <= size do
    local byte = text:byte(i)
    if byte < 0x80 then
      local char = string.char(byte)
      if ESCAPES[char] then
        table.insert(out, ESCAPES[char])
      elseif byte < 0x20 or byte == 0x7F then
        table.insert(out, string.format('\\u%04x', byte))
      else
        table.insert(out, char)
      end
      i = i + 1
    else
      local length, code
      if byte >= 0xC2 and byte <= 0xDF then
        length, code = 2, byte - 0xC0
      elseif byte >= 0xE0 and byte <= 0xEF then
        length, code = 3, byte - 0xE0
      elseif byte >= 0xF0 and byte <= 0xF4 then
        length, code = 4, byte - 0xF0
      end
      for k = 1, (length or 1) - 1 do
        local follow = text:byte(i + k)
        if not follow or follow < 0x80 or follow > 0xBF then
          length = nil
          break
        end
        code = code * 64 + (follow - 0x80)
      end
      -- Overlong forms, surrogates and anything above U+10FFFF aren't valid either
      if length == 3 and (code < 0x800 or (code >= 0xD800 and code <= 0xDFFF)) then
        length = nil
      elseif length == 4 and (code < 0x10000 or code > 0x10FFFF) then
        length = nil
      end
      if not length then
        table.insert(out, '\\ufffd')
        i = i + 1
      elseif code >= 0x10000 then
        -- Above U+FFFF JSON needs a surrogate pair
        code = code - 0x10000
        table.insert(out, string.format('\\u%04x\\u%04x', 0xD800 + code // 0x400, 0xDC00 + code % 0x400))
        i = i + length
      else
        table.insert(out, string.format('\\u%04x', code))
        i = i + length
      end
    end
  end
  table.insert(out, '"')
  return table.concat(out)
end

local function encode(value)
  local kind = type(value)
  if kind == 'string' then
    return encodeString(value)
  elseif kind == 'number' then
    if value == math.floor(value) and math.abs(value) < 2^53 then
      return string.format('%d', value)
    end
    return string.format('%.14g', value)
  elseif kind == 'boolean' then
    return tostring(value)
  elseif kind == 'table' then
    local parts = {}
    if getmetatable(value) == ARRAY or value[1] ~= nil then
      for _, item in ipairs(value) do
        table.insert(parts, encode(item))
      end
      return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}
    for key in pairs(value) do
      table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      table.insert(parts, encodeString(key) .. ':' .. encode(value[key]))
    end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  return 'null'
end

discord.encode = encode -- for testing

-- Message text --------------------------------------------------------------------

-- Cuts text to at most `limit` bytes without splitting a UTF-8 character
local function cut(text, limit)
  if #text <= limit then
    return text
  end
  local stop = limit
  while stop > 0 and text:byte(stop + 1) >= 0x80 and text:byte(stop + 1) < 0xC0 do
    stop = stop - 1
  end
  return text:sub(1, stop)
end

-- The real time, read from when a file was last written (nil if it can't be)
local function realTime()
  local ok, modified = pcall(function()
    local file = io.open(CLOCK_FILE, 'w')
    if not file then
      return nil
    end
    file:close()
    return filesystem.lastModified(CLOCK_FILE)
  end)
  if ok and modified and modified > 0 then
    return modified / 1000
  end
  return nil
end

-- Current time for the embeds, e.g. "2026-10-29T14:02:11Z" (nil without a real clock)
local function isoTime()
  local now = realTime()
  if not now then
    return nil
  end
  local t = os.date('*t', math.floor(now))
  return string.format('%04d-%02d-%02dT%02d:%02d:%02dZ', t.year, t.month, t.day, t.hour, t.min, t.sec)
end

-- The content and allowed_mentions for discordMention. Only the users and roles in
-- it are pinged.
local function mentionParts()
  local text = mention
  if text:match('^%s*%d+%s*$') then
    text = '<@' .. text:match('%d+') .. '>' -- a bare user id
  end
  local users, roles, parse = array({}), array({}), array({})
  for id in text:gmatch('<@!?(%d+)>') do
    table.insert(users, id)
  end
  for id in text:gmatch('<@&(%d+)>') do
    table.insert(roles, id)
  end
  if text:find('@everyone', 1, true) or text:find('@here', 1, true) then
    table.insert(parse, 'everyone')
  end
  return cut(text, 1000), {parse = parse, users = users, roles = roles}
end

-- Warns once about anything in discordMention that can't ping, e.g. a plain
-- "@Willshaper": Discord only pings user and role IDs, @here and @everyone
local function checkMention()
  if mention:match('^%s*%d+%s*$') then
    return -- a bare user id
  end
  local rest = mention:gsub('<@[!&]?%d+>', ''):gsub('@everyone', ''):gsub('@here', '')
  rest = rest:match('^%s*(.-)%s*$')
  if rest ~= '' then
    warn('mention', 'Discord: "' .. cut(rest, 20) .. '" in discordMention won\'t ping, it needs an ID')
  end
end

-- Sending -----------------------------------------------------------------------

local function closeOpen()
  for _, request in ipairs(open) do
    pcall(request.handle.close)
  end
  open = {}
end

-- Whether this computer can reach Discord at all (warns why not, once)
local function checkCard()
  if not component.isAvailable('internet') then
    warn('card', 'Discord: no internet card in this computer')
    return false
  end
  local ok, enabled = pcall(component.internet.isHttpEnabled)
  if ok and enabled == false then
    warn('http', "Discord: HTTP is off in the server's OpenComputers config")
    return false
  end
  return true
end

local function active()
  if url == '' or disabled then
    return false
  end
  if not cardChecked then
    cardChecked = true
    cardOk = checkCard()
  end
  return cardOk
end

local function enqueue(body)
  table.insert(queue, {body = body, attempts = 0, limited = 0, notBefore = 0})
  while #queue > MAX_QUEUE do
    table.remove(queue, 1)
  end
end

-- The HTTP status from a failed connection. Java reports 4xx/5xx answers as an error
-- ("Server returned HTTP response code: 429 for URL: ..."), and a 404 as just the URL.
local function codeFromError(problem)
  local code = tonumber(problem:match('response code: (%d%d%d)'))
  if not code and (problem:find('FileNotFound', 1, true) or problem:match('^%s*<webhook URL>%s*$')) then
    code = 404
  end
  return code
end

-- Seconds from a Retry-After header (header names are matched in any case)
local function retryAfter(headers)
  if type(headers) ~= 'table' then
    return nil
  end
  for key, value in pairs(headers) do
    if type(key) == 'string' and key:lower() == 'retry-after' then
      if type(value) == 'table' then
        value = value[1]
      end
      local seconds = tonumber(value)
      if seconds then
        return math.min(math.max(seconds, 1), 600)
      end
    end
  end
  return nil
end

-- What happened to a sent message: done, retried later, or dropped
local function handleResult(item, code, problem, headers, now)
  if disabled then
    return
  end
  if code and code >= 200 and code < 300 then
    warned.send, problems.send = nil, nil -- a later failure is worth a warning again
    return
  end
  if code == 401 or code == 403 or code == 404 then
    disabled = true
    queue = {}
    warn('rejected', 'Discord: webhook rejected (HTTP ' .. code .. '), check discordWebhook')
    return
  end
  if code == 429 then
    waitUntil = now + (retryAfter(headers) or 5)
    item.limited = item.limited + 1
    if item.limited < MAX_RATE_LIMITED then
      table.insert(queue, 1, item)
    end
    return
  end
  item.attempts = item.attempts + 1
  warn('send', 'Discord: sending failed (' .. (code and ('HTTP ' .. code) or cut(hideUrls(problem), 30))
    .. '), trying again')
  if item.attempts < MAX_ATTEMPTS then
    item.notBefore = now + RETRY_WAIT * item.attempts
    table.insert(queue, 1, item)
  end
end

-- Checks the open requests and closes the ones that are answered or took too long
local function poll(now)
  local still = {}
  local done = {}
  for _, request in ipairs(open) do
    local finished, code, problem, headers = false, nil, nil, nil
    local ok, connected = pcall(request.handle.finishConnect)
    if not ok then
      finished = true
      problem = hideUrls(connected)
      code = codeFromError(problem)
    elseif connected then
      local answered, status, _, responseHeaders = pcall(request.handle.response)
      if answered and status then
        finished, code, headers = true, tonumber(status), responseHeaders
      end
    end
    if not finished and now - request.started >= REQUEST_TIMEOUT then
      finished, problem = true, 'no answer after ' .. REQUEST_TIMEOUT .. 's'
    end
    if finished then
      pcall(request.handle.close)
      table.insert(done, {request.item, code, problem, headers})
    else
      table.insert(still, request)
    end
  end
  open = still
  -- Handled in reverse, so retried messages go back to the front of the queue in order
  for i = #done, 1, -1 do
    handleResult(done[i][1], done[i][2], done[i][3], done[i][4], now)
  end
end

local function send(now)
  while #open < MAX_OPEN and queue[1] and now >= waitUntil and now >= queue[1].notBefore do
    if not component.isAvailable('internet') then
      cardChecked = false -- the card was removed; warns once and stops
      if not active() then
        queue = {}
      end
      return
    end
    local item = table.remove(queue, 1)
    local ok, handle, reason = pcall(component.internet.request, url, item.body, HEADERS)
    if ok and handle then
      table.insert(open, {handle = handle, item = item, started = now})
    else
      handleResult(item, nil, ok and (reason or 'request refused') or handle, nil, now)
      return
    end
  end
end

-- One message with the embeds of one update; red ones ping discordMention
local function flush(embeds, now)
  if #embeds > 0 then
    local time = isoTime() -- only now: reading the clock writes a file
    local author = 'Power Display'
    if name ~= '' then
      author = cut(author .. ' - ' .. name, 200)
    end
    local red = false
    for _, each in ipairs(embeds) do
      each.author, each.timestamp = {name = author}, time
      red = red or each.color == RED
    end
    local body = {embeds = embeds, allowed_mentions = {parse = array({})}}
    if red and mention ~= '' then
      body.content, body.allowed_mentions = mentionParts()
    end
    enqueue(encode(body))
  end
  send(now)
end

local function embed(embeds, color, title, description)
  table.insert(embeds, {title = title, description = cut(description, 2000), color = color})
end

-- Alerts --------------------------------------------------------------------------

-- An alert that is on now. Returns true when it should be sent: the first time,
-- unless the same alert was sent less than FLAP_COOLDOWN ago (then it is checked
-- again on every update until it may be sent).
local function raise(kind, now)
  local state = alerts[kind]
  if not state then
    state = {since = now, reported = false}
    alerts[kind] = state
  end
  if state.reported or (lastReport[kind] and now - lastReport[kind] < FLAP_COOLDOWN) then
    return false
  end
  state.reported, state.lastSent = true, now
  lastReport[kind] = now
  return true
end

-- An alert that is over. Returns true if it had been sent, so "back to normal" is.
local function clear(kind)
  local state = alerts[kind]
  alerts[kind] = nil
  return state ~= nil and state.reported
end

-- Nothing is sent (no webhook, or it doesn't work): forget what was sent, so once it
-- works again everything that is wrong is reported
local function forget()
  alerts, lastReport = {}, {}
end

-- Public --------------------------------------------------------------------------

-- Wraps a public function so an error in it is shown once instead of reaching the
-- display. "interrupted" (Ctrl+Alt+C) still stops the program.
local function guarded(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      if err == 'interrupted' then
        error(err, 0)
      end
      warn('bug', 'Discord error: ' .. hideUrls(err))
    end
  end
end

-- Once, when the program starts. `titles`: started = the "started" message,
-- lost = no values for a while, back = values again.
discord.started = guarded(function(titles)
  texts = titles
  startPending = true
end)

-- Takes the discord settings from config.lua (when the program starts, and after
-- every edit). warning(text) prints a problem with sending, once.
-- After an edit, a rejected webhook is tried again and problems show again.
discord.configure = guarded(function(config, warning)
  settings = config
  onWarning = warning
  url = config.discordWebhook
  name = config.discordName
  mention = config.discordMention
  disabled, cardChecked, waitUntil, warned, problems = false, false, 0, {}, {}
  if url ~= '' then
    checkMention()
  end
  if not alerts.lost then
    lastSeen = computer.uptime() -- the time spent editing doesn't count as no values
  end
end)

-- An update with values. data: the LSC's (percent, maintenanceOk); view: what was
-- worked out (eut, hudTimeTo, hudTimeToWhat, generators).
discord.update = guarded(function(data, view)
  local now = computer.uptime()
  poll(now)
  lastSeen = now
  local running = view.generators
  local wasRunning = generatorsRunning
  generatorsRunning = running
  if not active() then
    forget()
    return
  end

  local embeds = {}
  local metric = settings.numberFormat == 'metric'
  local percent = data.percent * 100
  local charge = 'Charge ' .. format.percent(data.percent)
  local rate = view.eut and (', ' .. format.rate(view.eut, metric) .. ' EU/t') or ''
  local emptyIn = view.hudTimeToWhat == 'empty' and view.hudTimeTo or nil

  if startPending then
    startPending = false
    if settings.discordStarted then
      embed(embeds, GRAY, texts.started, charge .. rate .. '.')
    end
  end

  if clear('lost') then
    embed(embeds, GREEN, texts.back, charge .. rate .. '.')
  end

  local lowPower = settings.lowPower
  if not settings.discordLowPower or lowPower == false then
    alerts.lowPower = nil
  elseif percent < lowPower then
    if raise('lowPower', now) then
      embed(embeds, RED, 'Low power', charge .. ' (below ' .. lowPower .. '%)' .. rate
        .. (emptyIn and (', empty in ' .. format.shortDuration(emptyIn)) or '') .. '.')
    else
      local state = alerts.lowPower
      local reminder = settings.discordReminder * 3600
      if state.reported and reminder > 0 and now - state.lastSent >= reminder then
        state.lastSent = now
        embed(embeds, RED, 'Still low power', charge .. rate .. ', low for '
          .. format.shortDuration(now - state.since) .. '.')
      end
    end
  elseif percent >= math.min(lowPower + LOW_POWER_MARGIN, 100) and clear('lowPower') then
    embed(embeds, GREEN, 'Power back to normal', charge .. rate .. '.')
  end

  local limit = settings.discordEmptySoonMinutes * 60
  if not settings.discordEmptySoon then
    alerts.emptySoon = nil
  elseif emptyIn and emptyIn < limit then
    if raise('emptySoon', now) then
      embed(embeds, RED, 'Empty soon', 'Empty in ' .. format.shortDuration(emptyIn) .. ' at '
        .. format.rate(view.eut, metric) .. ' EU/t (' .. charge:lower() .. ').')
    end
  elseif not emptyIn or emptyIn >= limit * EMPTY_SOON_CLEAR then
    clear('emptySoon') -- no message: the charge or a low power message says enough
  end

  if not settings.discordMaintenance then
    alerts.maintenance = nil
  elseif data.maintenanceOk == false then
    if raise('maintenance', now) then
      embed(embeds, RED, 'Maintenance needed', 'The LSC has a maintenance problem.')
    end
  elseif clear('maintenance') then
    embed(embeds, GREEN, 'Maintenance fixed', 'The LSC has no maintenance problems.')
  end

  if settings.discordGenerators and running ~= nil and wasRunning ~= nil and running ~= wasRunning then
    embed(embeds, GRAY, running and 'Generators started' or 'Generators stopped', charge .. rate .. '.')
  end

  flush(embeds, now)
end)

-- An update without values (the LSC can't be read, or nothing received). After
-- LOST_SECONDS of this, texts.lost is sent with `text`, why.
discord.missing = guarded(function(text)
  local now = computer.uptime()
  poll(now)
  if not active() then
    forget()
    return
  end
  local embeds = {}
  if startPending then
    startPending = false
    if settings.discordStarted then
      embed(embeds, GRAY, texts.started, text)
    end
  end
  if not settings.discordLscLost then
    alerts.lost = nil
  elseif now - (lastSeen or now) >= LOST_SECONDS and raise('lost', now) then
    embed(embeds, RED, texts.lost, text)
  end
  flush(embeds, now)
end)

-- The problems with sending right now, for the screen
function discord.problems()
  local list = {}
  for _, text in pairs(problems) do
    table.insert(list, text)
  end
  table.sort(list)
  return list
end

-- Closes open requests when the program stops
discord.stop = guarded(function()
  closeOpen()
  queue = {}
end)

return discord
