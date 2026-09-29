-- The HUD bar on AR glasses (OCGlasses glasses terminals). Same look as upstream.
-- With hudSide = 'right' everything is mirrored across the screen: the bar fills
-- leftwards from the right edge and slants the other way. Text still reads normally.
local component = require('component')
local format = require('src.format')

local hud = {}

local terminals = {} -- one entry per glasses terminal: {proxy, widgets, last}
local config
local l, h, b1, b2, y -- bar geometry, as upstream
local mirrored = false
local screenWidth -- in GUI pixels
local lastData, lastView -- for animation frames between updates
local eutText = '' -- the EU/t label's text, which the arrows sit next to

-- Minecraft font widths in pixels (glyph + 1 spacing); everything else is 6
local CHAR_WIDTH = {
  [' '] = 4, ['!'] = 2, ["'"] = 3, ['('] = 5, [')'] = 5, ['*'] = 5, [','] = 2, ['.'] = 2,
  [':'] = 2, [';'] = 2, ['<'] = 5, ['>'] = 5, ['@'] = 7, ['I'] = 4, ['['] = 4, [']'] = 4,
  ['`'] = 3, ['f'] = 5, ['i'] = 2, ['k'] = 5, ['l'] = 3, ['t'] = 4, ['|'] = 2, ['~'] = 7,
}

local function textWidth(text, scale)
  local width = 0
  for c in text:gmatch('.') do
    width = width + (CHAR_WIDTH[c] or 6)
  end
  return width * scale
end

local function RGB(hex)
  return ((hex >> 16) & 0xFF) / 255, ((hex >> 8) & 0xFF) / 255, (hex & 0xFF) / 255
end

-- Mirroring reverses the order the corners go round in, so the corners are also
-- renumbered (1<->2, 3<->4) to keep every quad wound the same way
local MIRRORED_CORNER = {2, 1, 4, 3}

local function setVertex(q, corner, x, vy)
  if mirrored then
    q.setVertex(MIRRORED_CORNER[corner], screenWidth - x, vy)
  else
    q.setVertex(corner, x, vy)
  end
end

local function quad(glasses, v1, v2, v3, v4, color)
  local q = glasses.addQuad()
  setVertex(q, 1, v1[1], v1[2])
  setVertex(q, 2, v2[1], v2[2])
  setVertex(q, 3, v3[1], v3[2])
  setVertex(q, 4, v4[1], v4[2])
  q.setColor(RGB(color))
  q.setAlpha(config.shapeAlpha)
  return q
end

-- Text labels. `x` gives the left edge of the text in the left-side layout; on the
-- right side the text's whole span is mirrored, so it keeps its place against the bar.
-- `onBar` labels sit on the bar and change colour with what is behind them.
local labels = {}

local function defineLabels()
  local fs = config.fontSize
  local small = fs / 1.3 / 3
  local textY = y - b1 - h/2 - fs
  local function eutLeft()
    return 3*h + l/2 - textWidth(eutText, small)/2
  end
  labels = {
    percent = {scale = fs / 3, y = y - b1 - h/1.8 - fs, x = function(text)
      -- Right-aligned against the start of the bar, as upstream
      if text == '100%' then
        return b2 + 2.1*h - 2*fs*#text
      end
      return b2 + 2*h - 2*fs*(#text - 1)
    end},
    curr = {scale = small, y = textY, onBar = true, x = function() return b2 + 3.25*h + 1 end},
    max = {scale = small, y = textY, onBar = true, x = function(text) return 2.25*h + l - 1.5*fs*(#text - 1) end},
    -- Centred on the middle of the slanted bar
    eut = {scale = small, y = textY, onBar = true, eut = true, x = eutLeft},
    -- After the EU/t while charging, before it while discharging; the number itself
    -- stays put while the arrows grow
    arrows = {scale = small, y = textY, onBar = true, eut = true, x = function(text)
      local gap = textWidth(' ', small)
      if (lastView and lastView.direction or 0) > 0 then
        return eutLeft() + textWidth(eutText, small) + gap
      end
      return eutLeft() - gap - textWidth(text, small)
    end},
    alert = {scale = fs / 3, y = y - b1 - b2 - h - 3*fs, x = function() return b2 end},
  }
end

local function labelX(name, text)
  local label = labels[name]
  local x = label.x(text)
  if mirrored then
    return screenWidth - x - textWidth(text, label.scale)
  end
  return x
end

-- Dark text over the filled part of the bar, light text over the empty part
local function labelColor(name, text)
  local label = labels[name]
  if label.eut and config.euTColor then
    return config.euTColor
  end
  local fillEnd = b2 + 2.75*h + l * (lastData and lastData.percent or 0) -- at the text's height
  local centre = label.x(text) + textWidth(text, label.scale) / 2
  return centre < fillEnd and config.textColor or config.textColorEmpty
end

local function text(glasses, name, color)
  local label = labels[name]
  local t = glasses.addTextLabel()
  t.setText('')
  t.setPosition(labelX(name, ''), label.y)
  t.setScale(label.scale)
  t.setColor(RGB(color))
  t.setAlpha(config.textAlpha)
  return t
end

-- Each widget call is a component call sent to every player wearing the glasses,
-- so only send what changed
local function changed(terminal, key, value)
  if terminal.last[key] == value then
    return false
  end
  terminal.last[key] = value
  return true
end

local function setLabel(terminal, name, value)
  local widget = terminal.widgets[name]
  if changed(terminal, name, value) then
    widget.setText(value)
  end
  local x = labelX(name, value)
  if changed(terminal, name .. 'X', x) then
    widget.setPosition(x, labels[name].y)
  end
  if labels[name].onBar then
    local color = labelColor(name, value)
    if changed(terminal, name .. 'Color', color) then
      widget.setColor(RGB(color))
    end
  end
end

local function draw(glasses)
  glasses.removeAll()
  local w = {}

  -- Static shapes
  quad(glasses, {0, y-b1}, {3.5*h+l+b2+1, y-b1}, {2.5*h+l+1, y-b1-h-b2}, {0, y-b1-h-b2}, config.borderColor)
  quad(glasses, {0, y}, {3.5*h+l+b2+1, y}, {3.5*h+l+b2+1, y-b1}, {0, y-b1}, config.borderColor)
  quad(glasses, {3.5*h, y-b1}, {3.5*h+l, y-b1}, {2.5*h+l, y-b1-h}, {2.5*h, y-b1-h}, config.secondaryColor)

  -- Energy bar and values
  w.energyBar = quad(glasses, {b2+3.25*h, y-b1}, {b2+3.25*h, y-b1}, {b2+2.25*h, y-b1-h}, {b2+2.25*h, y-b1-h}, config.primaryColor)
  w.percent = text(glasses, 'percent', config.primaryColor)
  w.curr = text(glasses, 'curr', config.textColor)
  w.max = text(glasses, 'max', config.textColor)
  w.eut = text(glasses, 'eut', config.textColor)
  w.arrows = text(glasses, 'arrows', config.textColor)
  w.alert = text(glasses, 'alert', config.issueColor)
  return w
end

function hud.start(cfg)
  config = cfg
  terminals = {}
  lastData, lastView, eutText = nil, nil, ''
  l, h = config.length, config.height
  b1, b2 = config.borderBottom, config.borderTop
  y = config.resolution[2] / config.GUIscale
  if not config.fullscreen then
    local offsets = {71, 35, 23, 17}
    y = y - (offsets[config.GUIscale] or 0)
  end
  mirrored = config.hudSide == 'right'
  screenWidth = config.resolution[1] / config.GUIscale
  defineLabels()
  for address in component.list('glasses') do
    local proxy = component.proxy(address)
    table.insert(terminals, {proxy = proxy, widgets = draw(proxy), last = {}})
  end
  return #terminals
end

local function blinkPhase(now)
  return math.floor(now * 2) % 2 == 0
end

-- ">", ">>", ">>>" while charging, "<" ... while discharging; mirrored on the right side
local function arrowsText(now)
  if not config.showArrows or eutText == '' then
    return ''
  end
  local arrows = format.arrows(lastView.direction, now)
  if mirrored then
    arrows = arrows:gsub('.', {['<'] = '>', ['>'] = '<'})
  end
  return arrows
end

-- Called several times a second between updates: animates the arrows and blinks the
-- bar. Only changes are sent.
function hud.animate(now)
  if not lastData then
    return
  end
  local barColor = config.primaryColor
  if lastView.lowPower and (not config.lowPowerBlink or blinkPhase(now)) then
    barColor = config.issueColor
  end
  local arrows = arrowsText(now)
  for _, t in ipairs(terminals) do
    if changed(t, 'barColor', barColor) then
      t.widgets.energyBar.setColor(RGB(barColor))
    end
    setLabel(t, 'arrows', arrows)
  end
end

-- data: from lsc.read; view: {eut, direction, lowPower}
function hud.update(data, view)
  lastData, lastView = data, view

  eutText = ''
  if config.showEUt and view.eut then
    eutText = format.rate(view.eut, config.metric) .. ' EU/t'
  end

  local alerts = {}
  if view.lowPower then
    table.insert(alerts, 'Low power!')
  end
  if config.showMaintenance and not data.maintenanceOk then
    table.insert(alerts, 'Has Problems!')
  end

  local percentColor = view.lowPower and config.issueColor or config.primaryColor

  for _, t in ipairs(terminals) do
    local w = t.widgets
    local fill = l * data.percent
    if changed(t, 'fill', fill) then
      setVertex(w.energyBar, 2, b2+3.25*h+fill, y-b1)
      setVertex(w.energyBar, 3, b2+2.25*h+fill, y-b1-h)
    end
    setLabel(t, 'percent', config.showPercent and format.percent(data.percent) or '')
    if changed(t, 'percentColor', percentColor) then
      w.percent.setColor(RGB(percentColor))
    end
    setLabel(t, 'curr', config.showCurrentEU and format.eu(data.stored, config.metric) or '')
    setLabel(t, 'max', config.showMaxEU and format.eu(data.capacity, config.metric) or '')
    setLabel(t, 'eut', eutText)
    setLabel(t, 'alert', table.concat(alerts, '  '))
  end
end

-- Shows text in the alert spot while the LSC can't be read (the numbers are old then)
function hud.notice(text)
  for _, t in ipairs(terminals) do
    pcall(setLabel, t, 'alert', text)
  end
end

function hud.stop()
  for _, t in ipairs(terminals) do
    pcall(t.proxy.removeAll)
  end
  terminals = {}
end

return hud
