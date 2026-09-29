-- Full-screen power monitor on the computer's own screen.
-- Rows are redrawn only when they change, so the screen doesn't flicker.
local component = require('component')
local computer = require('computer')
local unicode = require('unicode')
local format = require('src.format')

local screen = {}

local MAX_WIDTH, MAX_HEIGHT = 80, 25 -- a tier 2 screen; bigger screens get larger text

local COLOR = {
  text = 0xFFFFFF,
  dim = 0xAAAAAA,
  faint = 0x555555,
  good = 0x55FF55,
  bad = 0xFF5555,
  warn = 0xFFFF55,
  graph = 0x55FFFF,
  background = 0x000000,
}

local gpu
local width, height
local originalWidth, originalHeight
local drawn = {} -- y -> signature of what is on that row
local touched = {} -- rows written during the current frame
local fg, bg -- current GPU colours, to skip needless calls
local config
local barRow -- screen row of the bar's top line (nil when not drawn)
local lastData, lastView -- for animation frames between updates
local savedPalette = {} -- palette index -> colour before we changed it

-- History graph: one sample per bucket, averaged
local history = {} -- list of fractions 0..1, oldest first
local bucketSeconds = 60
local bucketIndex = nil
local bucketSum, bucketCount = 0, 0
local maxSamples = 0

local function setColors(foreground, background)
  if foreground ~= fg then
    gpu.setForeground(foreground)
    fg = foreground
  end
  if background ~= bg then
    gpu.setBackground(background)
    bg = background
  end
end

local function len(text)
  return unicode.len(text)
end

-- segments: list of {text, foreground[, background]}; padded to the screen width
local function row(y, segments)
  if y < 1 or y > height then
    return
  end
  touched[y] = true
  local used = 0
  local signature = {}
  for _, s in ipairs(segments) do
    used = used + len(s[1])
    table.insert(signature, s[1] .. '\0' .. s[2] .. '\0' .. (s[3] or COLOR.background))
  end
  if used < width then
    table.insert(segments, {string.rep(' ', width - used), COLOR.text})
  end
  local key = table.concat(signature, '\1')
  if drawn[y] == key then
    return
  end
  drawn[y] = key
  local x = 1
  for _, s in ipairs(segments) do
    if x > width then
      break
    end
    local text = s[1]
    if x + len(text) - 1 > width then
      text = unicode.sub(text, 1, width - x + 1)
    end
    setColors(s[2], s[3] or COLOR.background)
    gpu.set(x, y, text)
    x = x + len(text)
  end
end

-- A row with segments on the left and on the right
local function split(y, left, right)
  local used = 0
  for _, s in ipairs(left) do used = used + len(s[1]) end
  for _, s in ipairs(right) do used = used + len(s[1]) end
  local segments = {}
  for _, s in ipairs(left) do table.insert(segments, s) end
  table.insert(segments, {string.rep(' ', math.max(1, width - used)), COLOR.text})
  for _, s in ipairs(right) do table.insert(segments, s) end
  row(y, segments)
end

local function pad(text, size, right)
  text = tostring(text)
  local gap = size - len(text)
  if gap <= 0 then
    return text
  end
  return right and (string.rep(' ', gap) .. text) or (text .. string.rep(' ', gap))
end

-- Tier 2 screens show 16 colours, picked from a palette the program can change.
-- Setting the palette to the colours in use shows them exactly (the HUD's blues
-- instead of the nearest default colour). stop() puts the old palette back.
local function usePalette()
  savedPalette = {}
  if gpu.getDepth() < 4 then
    return
  end
  local colors, seen = {}, {}
  for _, color in ipairs({
    COLOR.background, COLOR.text, COLOR.dim, COLOR.faint, COLOR.good, COLOR.bad, COLOR.warn, COLOR.graph,
    config.primaryColor, config.secondaryColor, config.textColor, config.textColorEmpty, config.issueColor,
    config.borderColor,
  }) do
    if not seen[color] and #colors < 16 then
      seen[color] = true
      table.insert(colors, color)
    end
  end
  for i, color in ipairs(colors) do
    local ok, old = pcall(gpu.getPaletteColor, i - 1)
    if ok and pcall(gpu.setPaletteColor, i - 1, color) then
      savedPalette[i - 1] = old
    end
  end
end

-- Returns true if there is a screen to draw on
function screen.start(cfg)
  config = cfg
  drawn, fg, bg = {}, nil, nil
  history, bucketIndex, bucketSum, bucketCount = {}, nil, 0, 0
  if not component.isAvailable('gpu') or not component.isAvailable('screen') then
    gpu = nil
    return false
  end
  gpu = component.gpu
  originalWidth, originalHeight = gpu.getResolution()
  local maxW, maxH = gpu.maxResolution()
  width, height = math.min(maxW, MAX_WIDTH), math.min(maxH, MAX_HEIGHT)
  gpu.setResolution(width, height)
  usePalette()
  setColors(COLOR.text, COLOR.background)
  gpu.fill(1, 1, width, height, ' ')

  -- One history sample per braille dot column; the graph is the width minus the axis labels
  maxSamples = math.max(2, (width - 7) * 2)
  bucketSeconds = config.historyMinutes * 60 / maxSamples
  return true
end

function screen.active()
  return gpu ~= nil
end

function screen.stop()
  if not gpu then
    return
  end
  pcall(function()
    for index, color in pairs(savedPalette) do
      gpu.setPaletteColor(index, color)
    end
    savedPalette = {}
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.setResolution(originalWidth, originalHeight)
    gpu.fill(1, 1, originalWidth, originalHeight, ' ')
  end)
  gpu = nil
end

function screen.addSample(time, fraction)
  if not gpu or not config.showHistory then
    return
  end
  local index = math.floor(time / bucketSeconds)
  if bucketIndex ~= nil and index ~= bucketIndex then
    table.insert(history, bucketSum / bucketCount)
    -- Buckets with no reading (the computer was busy) repeat the last value
    for _ = 1, math.min(index - bucketIndex - 1, maxSamples) do
      table.insert(history, history[#history])
    end
    while #history > maxSamples do
      table.remove(history, 1)
    end
    bucketSum, bucketCount = 0, 0
  end
  bucketIndex = index
  bucketSum = bucketSum + fraction
  bucketCount = bucketCount + 1
end

-- Blanks every row the frame didn't write
local function beginFrame()
  touched = {}
end

local function endFrame()
  for y = 1, height do
    if not touched[y] then
      row(y, {})
    end
  end
end

-- A message screen (waiting for the LSC, config mistakes, errors)
function screen.message(title, lines, color)
  if not gpu then
    return false
  end
  beginFrame()
  row(1, {{' Power Display', COLOR.text}})
  row(2, {})
  row(3, {{' ' .. title, color or COLOR.warn}})
  local y = 4
  for _, line in ipairs(lines or {}) do
    -- Wrap long lines, between words where possible
    while len(line) > width - 2 and y < height do
      local cut = width - 2
      for i = width - 2, math.floor(width / 2), -1 do
        if unicode.sub(line, i + 1, i + 1) == ' ' then
          cut = i
          break
        end
      end
      row(y, {{' ' .. unicode.sub(line, 1, cut), COLOR.text}})
      line = unicode.sub(line, cut + 1):gsub('^ +', '')
      y = y + 1
    end
    if y <= height then
      row(y, {{' ' .. line, COLOR.text}})
      y = y + 1
    end
  end
  endFrame()
  return true
end

-- Blinks twice a second, whatever the update interval
local function blinkPhase(now)
  return math.floor(now * 2) % 2 == 0
end

-- Text on the bar's middle line: cell index (0-based across the inside) -> char.
-- The percentage on the left, the EU/t in the middle with its arrows after it while
-- charging and before it while discharging, so the number itself doesn't move.
local function barTexts(size, now)
  local data, view = lastData, lastView
  local cells = {}
  local function put(start, text)
    for i = 1, unicode.len(text) do
      local index = start + i - 1
      if index >= 0 and index < size then
        cells[index] = unicode.sub(text, i, i)
      end
    end
  end
  if config.showPercent then
    put(1, format.percent(data.percent))
  end
  local eut = ''
  if config.showEUt and view.eut then
    eut = format.rate(view.eut, config.metric) .. ' EU/t'
  end
  local start = math.floor((size - unicode.len(eut)) / 2)
  put(start, eut)
  if config.showArrows then
    local arrows = format.arrows(view.direction, now)
    if view.direction > 0 then
      put(start + unicode.len(eut) + (eut == '' and 0 or 1), arrows)
    elseif view.direction < 0 then
      put(start - (eut == '' and 0 or 1) - unicode.len(arrows), arrows)
    end
  end
  return cells
end

-- The bar: a rectangle in a thin frame, three lines tall. Screen characters are about
-- twice as tall as they are wide, so the frame is one character wide at the sides and
-- half a line (half blocks) at the top and bottom; the fill is two lines tall with the
-- text line in its middle. Text is dark over the filled part and light over the empty part.
local function drawBar(now)
  local data, view = lastData, lastView
  local size = width - 4 -- a margin and the frame on each side
  local fillColor = config.primaryColor
  if view.lowPower and (not config.lowPowerBlink or blinkPhase(now)) then
    fillColor = config.issueColor
  end
  local emptyColor = config.secondaryColor
  local frame = config.borderColor
  local full = math.floor(data.percent * size + 0.5)
  local texts = barTexts(size, now)

  for line = 0, 2 do
    local segments = {}
    local function add(text, fg, bg)
      local last = segments[#segments]
      if last and last[2] == fg and last[3] == bg then
        last[1] = last[1] .. text
      else
        table.insert(segments, {text, fg, bg})
      end
    end
    add(' ', COLOR.text, COLOR.background)
    add(' ', COLOR.text, frame)
    for i = 0, size - 1 do
      local inside = i < full and fillColor or emptyColor
      if line == 0 then
        add('▄', inside, frame) -- frame above, bar below
      elseif line == 2 then
        add('▀', inside, frame) -- bar above, frame below
      elseif texts[i] then
        add(texts[i], i < full and config.textColor or config.textColorEmpty, inside)
      else
        add(' ', COLOR.text, inside)
      end
    end
    add(' ', COLOR.text, frame)
    row(barRow + line, segments)
  end
end

-- Called several times a second between updates: animates the arrows and blinks the
-- bar. Only the bar is redrawn, and only the lines that changed.
function screen.animate(now)
  if gpu and barRow and lastData then
    drawBar(now)
  end
end

-- Braille bit for dot row k (0 = bottom) in the left or right column of a cell
local LEFT_DOTS = {0x40, 0x04, 0x02, 0x01}
local RIGHT_DOTS = {0x80, 0x20, 0x10, 0x08}

local function drawGraph(top, bottom)
  local rows = bottom - top + 1
  local graphWidth = width - 7
  local dots = rows * 4
  -- Newest sample on the right
  local samples = {}
  local offset = maxSamples - #history
  for i = 1, maxSamples do
    samples[i] = history[i - offset]
  end
  local function filled(value)
    if value == nil then
      return -1
    end
    local n = math.floor(value * dots + 0.5)
    if value > 0 and n == 0 then
      n = 1
    end
    return n
  end
  for r = 0, rows - 1 do
    local fromBottom = rows - 1 - r
    local cells = {}
    for c = 0, graphWidth - 1 do
      local left = filled(samples[c * 2 + 1])
      local right = filled(samples[c * 2 + 2])
      local bits = 0
      for k = 0, 3 do
        local dot = fromBottom * 4 + k
        if dot < left then bits = bits | LEFT_DOTS[k + 1] end
        if dot < right then bits = bits | RIGHT_DOTS[k + 1] end
      end
      cells[c + 1] = bits == 0 and ' ' or unicode.char(0x2800 + bits)
    end
    local label = '     '
    if r == 0 then
      label = '100%'
    elseif r == rows - 1 then
      label = '  0%'
    elseif r == math.floor((rows - 1) / 2) and rows >= 5 then
      label = ' 50%'
    end
    row(top + r, {{pad(label, 5, true) .. ' ', COLOR.faint}, {'│', COLOR.faint}, {table.concat(cells), COLOR.graph}})
  end
end

-- data: from lsc.read
-- view: {eut, direction (1, -1 or 0), timeTo, timeToWhat, timeRate, lowPower, generators (true/false/nil),
--        generatorProblem, generatorHint, notes (footer), remote (shown by the viewer)}
function screen.update(data, view)
  if not gpu then
    return
  end
  beginFrame()
  lastData, lastView = data, view
  local now = computer.uptime()
  local metric = config.metric
  local y = 1

  -- Title and status
  local status = {'', COLOR.text}
  if config.showMaintenance then
    if data.maintenanceOk then
      status = {' Maintenance OK ', COLOR.good}
    else
      status = {' Maintenance needed ', COLOR.bad}
    end
  end
  local title = ' Power Display'
  if view.remote then
    title = title .. ' (linked card)'
  end
  split(y, {{title, COLOR.text}, {config.wirelessMode and '  (wireless)' or '', COLOR.dim}}, {status})
  y = y + 2

  barRow = y
  drawBar(now)
  y = y + 4

  -- Stored and max EU, and the time to full or empty
  local timeText = ''
  if config.showTimeToFullOrEmpty then
    if data.percent >= 0.9995 and (view.eut or 0) >= 0 then
      timeText = 'Full'
    elseif data.percent <= 0.0005 and (view.eut or 0) <= 0 then
      timeText = 'Empty'
    elseif view.timeTo then
      timeText = (view.timeToWhat == 'full' and 'Full in ' or 'Empty in ') .. format.duration(view.timeTo)
    elseif view.timeRate then
      timeText = 'Steady'
    else
      timeText = 'Measuring...'
    end
  end
  local left = {}
  if config.showCurrentEU then
    table.insert(left, {' ' .. format.eu(data.stored, metric, 2), COLOR.text})
  end
  if config.showMaxEU then
    table.insert(left, {(config.showCurrentEU and ' / ' or ' '), COLOR.dim})
    table.insert(left, {format.eu(data.capacity, metric, 2), COLOR.text})
  end
  if #left > 0 then
    table.insert(left, {' EU', COLOR.dim})
  end
  split(y, left, {{timeText .. ' ', COLOR.text}})
  y = y + 2

  -- GT's own averages, when there is room for them
  local footer = height
  if config.showAverages and height >= 20 then
    local c1, c2 = 14, 14
    row(y, {{pad('', c1) .. pad('In', c2, true) .. pad('Out', c2, true) .. pad('Net', c2, true), COLOR.faint}})
    local windows = {
      {' 5 s', data.avgIn, data.avgOut},
      {' 5 min', data.avgIn5m, data.avgOut5m},
      {' 1 hour', data.avgIn1h, data.avgOut1h},
    }
    for i, w in ipairs(windows) do
      local net
      if w[2] and w[3] then
        net = w[2] - w[3] - (data.passiveLoss or 0)
      end
      local netColor = COLOR.dim
      if net and net > 0 then netColor = COLOR.good elseif net and net < 0 then netColor = COLOR.bad end
      row(y + i, {
        {pad(w[1], c1), COLOR.dim},
        {pad(format.eu(w[2], metric, 2), c2, true), COLOR.text},
        {pad(format.eu(w[3], metric, 2), c2, true), COLOR.text},
        {pad(format.rate(net, metric, 2), c2, true), netColor},
      })
    end
    y = y + 5
    if config.showPassiveLoss then
      -- An outflow on top of Out (Net includes it), so it sits in that column
      row(y - 1, {
        {pad(' Passive Loss', c1), COLOR.dim},
        {pad('', c2), COLOR.text},
        {pad(format.eu(data.passiveLoss, metric, 2), c2, true), COLOR.text},
      })
      y = y + 1
    end
  elseif config.showPassiveLoss then
    row(y, {{' Passive Loss  ', COLOR.dim}, {format.eu(data.passiveLoss, metric, 2) .. ' EU/t', COLOR.text}})
    y = y + 2
  end

  -- Generators
  if config.generatorControl then
    if view.generatorProblem then
      row(y, {{' Generators  ', COLOR.dim}, {'OFF  ' .. view.generatorProblem, COLOR.bad}})
      row(y + 1, {{'             ' .. (view.generatorHint or ''), COLOR.dim}})
      y = y + 1
    else
      local state, color = 'RUNNING', COLOR.good
      if view.generators == false then
        state, color = 'stopped', COLOR.dim
      end
      row(y, {
        {' Generators  ', COLOR.dim}, {state, color},
        {string.format('   start below %s%%, stop above %s%%, output: %s',
          config.generatorOnBelow, config.generatorOffAbove, config.generatorSide), COLOR.faint},
      })
    end
    y = y + 2
  end

  -- History graph in the space that is left
  if config.showHistory and footer - 1 - y >= 3 then
    row(y, {{string.format(' History, last %s min', config.historyMinutes), COLOR.dim}})
    drawGraph(y + 1, footer - 1)
  end

  -- Footer: alerts, or how to stop
  local alerts = {}
  if view.lowPower then
    table.insert(alerts, {string.format(' LOW POWER (below %s%%) ', config.lowPowerAlert), COLOR.bad})
  end
  if config.showMaintenance and not data.maintenanceOk then
    table.insert(alerts, {' MAINTENANCE NEEDED ', COLOR.bad})
  end
  if #alerts > 0 then
    row(footer, alerts)
  else
    local text = ' Press C to stop.  Updates every ' .. config.sleep .. 's.'
    for _, note in ipairs(view.notes or {}) do
      text = text .. '  ' .. note .. '.'
    end
    row(footer, {{text, COLOR.faint}})
  end
  endFrame()
end

return screen
