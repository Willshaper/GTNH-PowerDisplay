-- The HUD bar on AR glasses (OCGlasses glasses terminals). Same look as upstream.
local component = require('component')
local format = require('src.format')

local hud = {}

local terminals = {} -- one entry per glasses terminal: {proxy, widgets, last}
local config
local l, h, b1, b2, y -- bar geometry, as upstream
local blinkOn = false

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

local function quad(glasses, v1, v2, v3, v4, color)
  local q = glasses.addQuad()
  q.setVertex(1, v1[1], v1[2])
  q.setVertex(2, v2[1], v2[2])
  q.setVertex(3, v3[1], v3[2])
  q.setVertex(4, v4[1], v4[2])
  q.setColor(RGB(color))
  q.setAlpha(config.shapeAlpha)
  return q
end

local function text(glasses, v1, size, color)
  local t = glasses.addTextLabel()
  t.setText('')
  t.setPosition(v1[1], v1[2])
  t.setScale(size / 3)
  t.setColor(RGB(color))
  t.setAlpha(config.textAlpha)
  return t
end

-- Each widget call is a component call, so only send what changed
local function changed(terminal, key, value)
  if terminal.last[key] == value then
    return false
  end
  terminal.last[key] = value
  return true
end

local function draw(glasses)
  glasses.removeAll()
  local w = {}
  local fs = config.fontSize

  -- Static shapes
  quad(glasses, {0, y-b1}, {3.5*h+l+b2+1, y-b1}, {2.5*h+l+1, y-b1-h-b2}, {0, y-b1-h-b2}, config.borderColor)
  quad(glasses, {0, y}, {3.5*h+l+b2+1, y}, {3.5*h+l+b2+1, y-b1}, {0, y-b1}, config.borderColor)
  quad(glasses, {3.5*h, y-b1}, {3.5*h+l, y-b1}, {2.5*h+l, y-b1-h}, {2.5*h, y-b1-h}, config.secondaryColor)

  -- Energy bar and values
  w.energyBar = quad(glasses, {b2+3.25*h, y-b1}, {b2+3.25*h, y-b1}, {b2+2.25*h, y-b1-h}, {b2+2.25*h, y-b1-h}, config.primaryColor)
  w.percent = text(glasses, {0.5*h, y-b1-h/1.8-fs}, fs, config.primaryColor)
  w.curr = text(glasses, {b2+3.25*h+1, y-b1-h/2-fs}, fs/1.3, config.textColor)
  w.max = text(glasses, {-2.25*h+l, y-b1-h/2-fs}, fs/1.3, config.textColor)
  w.eut = text(glasses, {3*h+l/2, y-b1-h/2-fs}, fs/1.3, config.euTColor)
  w.alert = text(glasses, {b2, y-b1-b2-h-3*fs}, fs, config.issueColor)
  return w
end

function hud.start(cfg)
  config = cfg
  terminals = {}
  l, h = config.length, config.height
  b1, b2 = config.borderBottom, config.borderTop
  y = config.resolution[2] / config.GUIscale
  if not config.fullscreen then
    local offsets = {71, 35, 23, 17}
    y = y - (offsets[config.GUIscale] or 0)
  end
  for address in component.list('glasses') do
    local proxy = component.proxy(address)
    table.insert(terminals, {proxy = proxy, widgets = draw(proxy), last = {}})
  end
  return #terminals
end

-- data: from lsc.read; view: {rate = arrows or '', eut = EU/t or nil, lowPower, maintenanceOk}
function hud.update(data, view)
  local fs = config.fontSize
  local small = fs / 1.3 / 3
  blinkOn = not blinkOn

  local percentText = format.percent(data.percent)
  local curr = config.showCurrentEU and format.eu(data.stored, config.metric) or ''
  if view.rate ~= '' then
    curr = curr .. ' ' .. view.rate
  end
  local max = config.showMaxEU and format.eu(data.capacity, config.metric) or ''
  local eut = ''
  if config.showEUt and view.eut then
    eut = format.rate(view.eut, config.metric) .. ' EU/t'
  end

  local alerts = {}
  if view.lowPower then
    table.insert(alerts, 'Low power!')
  end
  if not data.maintenanceOk then
    table.insert(alerts, 'Has Problems!')
  end
  local alert = table.concat(alerts, '  ')

  local barColor = config.primaryColor
  if view.lowPower and (blinkOn or not config.lowPowerBlink) then
    barColor = config.issueColor
  end
  local percentColor = view.lowPower and config.issueColor or config.primaryColor

  for _, t in ipairs(terminals) do
    local w = t.widgets
    local fill = l * data.percent
    if changed(t, 'fill', fill) then
      w.energyBar.setVertex(2, b2+3.25*h+fill, y-b1)
      w.energyBar.setVertex(3, b2+2.25*h+fill, y-b1-h)
    end
    if changed(t, 'barColor', barColor) then
      w.energyBar.setColor(RGB(barColor))
    end
    if changed(t, 'percent', percentText) then
      w.percent.setText(percentText)
      -- Right-aligned against the start of the bar, as upstream
      if percentText == '100%' then
        w.percent.setPosition(b2+2.1*h-2*fs*#percentText, y-b1-h/1.8-fs)
      else
        w.percent.setPosition(b2+2*h-2*fs*(#percentText-1), y-b1-h/1.8-fs)
      end
    end
    if changed(t, 'percentColor', percentColor) then
      w.percent.setColor(RGB(percentColor))
    end
    if changed(t, 'curr', curr) then
      w.curr.setText(curr)
    end
    if changed(t, 'max', max) then
      w.max.setText(max)
      w.max.setPosition(2.25*h+l-1.5*fs*(#max-1), y-b1-h/2-fs)
    end
    if changed(t, 'eut', eut) then
      w.eut.setText(eut)
      -- Centred on the middle of the slanted bar
      w.eut.setPosition(3*h + l/2 - textWidth(eut, small)/2, y-b1-h/2-fs)
    end
    if changed(t, 'alert', alert) then
      w.alert.setText(alert)
    end
  end
end

-- Shows text in the alert spot while the LSC can't be read (the numbers are old then)
function hud.notice(text)
  for _, t in ipairs(terminals) do
    if changed(t, 'alert', text) then
      pcall(t.widgets.alert.setText, text)
    end
  end
end

function hud.stop()
  for _, t in ipairs(terminals) do
    pcall(t.proxy.removeAll)
  end
  terminals = {}
end

return hud
