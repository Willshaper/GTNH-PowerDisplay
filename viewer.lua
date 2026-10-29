-- Power Display viewer: shows the display of a Power Display computer somewhere else,
-- received through a linked card. That computer needs linkedCard = true in its
-- config.lua and the other card of the pair.
-- Run it with: viewer      Stop it with C (or Ctrl+Alt+C), edit the settings with S.
local component = require('component')
local computer = require('computer')
local event = require('event')
local shell = require('shell')
local term = require('term')

-- OpenOS keeps loaded modules until reboot; forget ours so an update takes effect
for _, name in ipairs({'src.format', 'src.options', 'src.lsc', 'src.glasses', 'src.screen', 'src.generators', 'src.link',
    'src.discord'}) do
  package.loaded[name] = nil
end

local options = require('src.options')
local hud = require('src.glasses')
local screen = require('src.screen')
local link = require('src.link')
local discord = require('src.discord')

local FRAME_SECONDS = 0.1 -- animation frames (arrows, low power fade)
local STALE_SECONDS = 10 -- no update for this long (plus 3 update intervals): say so

-- Colours, sizes and what to show come from this computer's config.lua. The values
-- (EU/t, time to full or empty, generator state) come from the Power Display computer.
local configPath = package.searchpath('config', package.path)
configPath = configPath and shell.resolve(configPath) or shell.resolve('config.lua')

local config, problems = options.load(configPath)
if not config then
  io.stderr:write('The viewer did not start. Please fix config.lua (edit config.lua):\n')
  for _, found in ipairs(problems) do
    io.stderr:write('  - ' .. found.text .. '\n')
  end
  return
end
if not component.isAvailable('tunnel') then
  io.stderr:write('The viewer needs a linked card in this computer (paired with one in the Power Display computer).\n')
  return
end

-- C stops the program, S edits config.lua
local function keyAction(char)
  if char == 99 or char == 67 then
    return 'stop'
  elseif char == 115 or char == 83 then
    return 'edit'
  end
end

local editProblems -- mistakes in a config.lua just edited with S (the previous settings stay)

-- Shows a message on the screen, or prints it once if there is no screen
local lastPrinted
local function message(title, lines, color)
  if screen.active() then
    screen.message(title, lines, color)
    return
  end
  local text = title .. '\n' .. table.concat(lines or {}, '\n')
  if lastPrinted ~= text then
    print(text)
    lastPrinted = text
  end
end

-- The display settings sent by the Power Display computer (its generator set points,
-- wireless mode, update interval) replace this computer's
local function applySender(sender)
  for key, value in pairs(sender) do
    config[key] = value
  end
end

-- A problem with sending to Discord: printed if there is no screen (the screen
-- shows it in its footer)
local function discordWarning(text)
  if not screen.active() then
    print(text)
  end
end

-- Shows the display with the current settings until C or S is pressed; returns
-- 'stop' or 'edit'
local function main()
  -- Glasses are optional here; with none connected, the HUD is just left out
  if config.showHud then
    hud.start(config)
  end
  if config.showScreen and not screen.start(config) then
    print('No screen or graphics card found; showing the HUD only.')
  end
  discord.configure(config, discordWarning)

  -- A config.lua edited with S that has a mistake: say so for a while
  if editProblems then
    local lines = {}
    for _, found in ipairs(editProblems) do
      table.insert(lines, '- ' .. found.text)
    end
    table.insert(lines, '')
    table.insert(lines, 'Press S to fix it: the viewer will not start with it next time.')
    editProblems = nil
    hud.notice('config.lua has a mistake (see the screen)')
    message('config.lua has a mistake, so the previous settings are still used', lines, 0xFF5555)
    local deadline = computer.uptime() + 8
    repeat
      local name, _, char = event.pull(math.max(0, deadline - computer.uptime()), 'key_down')
      local action = name == 'key_down' and keyAction(char)
      if action then
        return action
      end
    until computer.uptime() >= deadline
  end

  local waitingText = {'Nothing received yet. On the Power Display computer, set linkedCard = true',
    'in config.lua, and put the other linked card of this pair in it.'}
  message('Waiting for the Power Display computer...', waitingText)

  local lastReceived -- uptime of the last packet
  local missing = 'Nothing received since the viewer started.' -- why there are no values, for Discord
  local showingData = false
  local staleShown = false
  local nextFrame = 0
  while true do
    local name, a, b, c, d, e = event.pull(FRAME_SECONDS)
    local now = computer.uptime()
    local action = name == 'key_down' and keyAction(b)
    if action then
      return action
    end

    if name == 'modem_message' then
      local packet = link.decode(a, e)
      if packet then
        lastReceived = now
        staleShown = false
        if packet.status then
          showingData = false
          missing = packet.status .. ' ' .. tostring(packet.text or '')
          hud.notice(packet.status)
          message(packet.status, {packet.text})
        else
          applySender(packet.config)
          local data, view = packet.data, packet.view
          view.remote = true
          view.discordProblems = discord.problems()
          view.lowPower = config.lowPower ~= false and data.percent * 100 < config.lowPower
          if config.showHud then
            hud.update(data, view)
          end
          screen.addSample(now, data.percent)
          screen.update(data, view)
          discord.update(data, view)
          showingData = true
        end
      end
    end

    -- Nothing heard for a while: the other computer is off, or its chunk isn't loaded
    local stale = STALE_SECONDS + 3 * (config.updateEvery or 1)
    if lastReceived and now - lastReceived > stale and not staleShown then
      showingData, staleShown = false, true
      missing = 'Nothing received for a while. It may be off, or its chunk may not be loaded.'
      hud.notice('No data from the Power Display computer')
      message('No data from the Power Display computer', {
        'Nothing received for ' .. math.floor(now - lastReceived) .. ' seconds. It may be off,',
        'or its chunk may not be loaded.'})
    end

    if not showingData then
      discord.missing(missing)
    end

    if showingData and now >= nextFrame then
      nextFrame = now + FRAME_SECONDS
      if config.showHud then
        hud.animate(now)
      end
      screen.animate(now)
    end
  end
end

-- S: edits config.lua in OpenOS's editor, then reads it again. The new settings are
-- used if they have no mistakes; otherwise the previous ones stay and main says so.
local function editConfig()
  hud.notice('Editing config.lua...')
  screen.stop()
  shell.execute('edit "' .. configPath .. '"')
  term.setCursorBlink(false) -- edit turns the blinking cursor back on
  local newConfig, found = options.load(configPath)
  if newConfig then
    config = newConfig
  else
    editProblems = found
  end
  hud.stop() -- drawn again with the settings now in use
end

local function program()
  discord.started({started = 'Viewer started', lost = 'No data from the Power Display computer',
    back = 'Receiving data from the Power Display computer again'})
  while main() == 'edit' do
    editConfig()
  end
end

local ok, err = xpcall(program, function(msg)
  if msg == 'interrupted' then
    return msg
  end
  return debug.traceback(tostring(msg), 2)
end)

hud.stop()
screen.stop()
discord.stop()

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Viewer stopped.')
