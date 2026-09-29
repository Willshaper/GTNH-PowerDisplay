-- Full-screen power monitor on the computer's own screen.
-- Rows are redrawn only when they change, so the screen doesn't flicker.
local component = require('component')
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
  bar = 0x55AAFF,
  barEmpty = 0x333333,
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
local blinkOn = false

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
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.setResolution(originalWidth, originalHeight)
    gpu.fill(1, 1, originalWidth, originalHeight, ' ')
  end)
  gpu = nil
end

function screen.addSample(time, fraction)
  if not gpu then
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
    -- Wrap long lines
    while len(line) > width - 2 and y < height do
      row(y, {{' ' .. unicode.sub(line, 1, width - 2), COLOR.text}})
      line = unicode.sub(line, width - 1)
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

-- Left-to-right fill with eighth blocks
local EIGHTHS = {'▏', '▎', '▍', '▌', '▋', '▊', '▉'}

local function barText(fraction, size)
  local cells = fraction * size
  local full = math.floor(cells)
  local part = math.floor((cells - full) * 8)
  local text = string.rep('█', full)
  if full < size and part > 0 then
    text = text .. EIGHTHS[part]
    full = full + 1
  end
  return text .. string.rep(' ', size - full)
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

-- data: from lsc.read; view: {eut, lowPower, generators (true/false/nil)}
function screen.update(data, view)
  if not gpu then
    return
  end
  beginFrame()
  blinkOn = not blinkOn
  local metric = config.metric
  local y = 1

  -- Title and status
  local status
  if not data.maintenanceOk then
    status = {' Maintenance needed ', COLOR.bad}
  else
    status = {' Maintenance OK ', COLOR.good}
  end
  split(y, {{' Power Display', COLOR.text}, {config.wirelessMode and '  (wireless)' or '', COLOR.dim}}, {status})
  y = y + 2

  -- Stored and percentage
  split(y, {
    {config.wirelessMode and ' Wireless  ' or ' Stored  ', COLOR.dim},
    {format.eu(data.stored, metric, 2), COLOR.text},
    {' / ', COLOR.dim},
    {format.eu(data.capacity, metric, 2), COLOR.text},
    {' EU', COLOR.dim},
  }, {{string.format('%.2f %% ', data.percent * 100), view.lowPower and COLOR.bad or COLOR.text}})
  y = y + 1

  -- Bar, two rows tall
  local barColor = COLOR.bar
  if view.lowPower and (blinkOn or not config.lowPowerBlink) then
    barColor = COLOR.bad
  end
  local bar = barText(data.percent, width - 2)
  row(y, {{' ', COLOR.text}, {bar, barColor, COLOR.barEmpty}})
  row(y + 1, {{' ', COLOR.text}, {bar, barColor, COLOR.barEmpty}})
  y = y + 3

  -- Net EU/t over the configured window, and time to full or empty
  local rateColor = COLOR.dim
  if view.eut and view.eut > 0.5 then
    rateColor = COLOR.good
  elseif view.eut and view.eut < -0.5 then
    rateColor = COLOR.bad
  end
  local timeText
  if view.timeTo then
    timeText = (view.timeToWhat == 'full' and 'Full in ' or 'Empty in ') .. format.duration(view.timeTo)
  elseif view.eut then
    timeText = 'Steady'
  else
    timeText = 'Measuring...'
  end
  split(y, {
    {' Net  ', COLOR.dim},
    {format.rate(view.eut, metric, 2) .. ' EU/t', rateColor},
    {string.format('  (last %ss)', config.euTSeconds), COLOR.faint},
  }, {{timeText .. ' ', COLOR.text}})
  y = y + 2

  -- GT's own averages, when there is room for them
  local footer = height
  local wantTable = height >= 20
  if wantTable then
    local c1, c2 = 12, 14
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
    row(y + 4, {{pad(' Passive loss', c1), COLOR.dim}, {pad(format.eu(data.passiveLoss, metric, 2), c2, true), COLOR.text}, {'  EU/t', COLOR.faint}})
    y = y + 6
  end

  -- Generators
  if view.generators ~= nil or config.generatorControl then
    local state, color = 'waiting', COLOR.dim
    if view.generators == true then
      state, color = 'RUNNING', COLOR.good
    elseif view.generators == false then
      state, color = 'stopped', COLOR.dim
    end
    row(y, {
      {' Generators  ', COLOR.dim}, {state, color},
      {string.format('   start below %s%%, stop above %s%%, signal on %s side',
        config.generatorOnBelow, config.generatorOffAbove, config.generatorSide), COLOR.faint},
    })
    y = y + 2
  end

  -- History graph in the space that is left
  if footer - 1 - y >= 3 then
    row(y, {{string.format(' History, last %s min', config.historyMinutes), COLOR.dim}})
    drawGraph(y + 1, footer - 1)
  end

  -- Footer: alerts, or how to stop
  local alerts = {}
  if view.lowPower then
    table.insert(alerts, {string.format(' LOW POWER (below %s%%) ', config.lowPowerAlert), COLOR.bad})
  end
  if not data.maintenanceOk then
    table.insert(alerts, {' MAINTENANCE NEEDED ', COLOR.bad})
  end
  if #alerts > 0 then
    row(footer, alerts)
  else
    row(footer, {{string.format(' Updates every %ss.  Press C to stop.', config.sleep), COLOR.faint}})
  end
  endFrame()
end

return screen
