-- Power Display viewer: shows the display of a Power Display computer somewhere else,
-- received through a linked card. That computer needs linkedCard = true in its
-- config.lua and the other card of the pair.
-- Run it with: viewer      Stop it with C (or Ctrl+Alt+C).
local component = require('component')
local computer = require('computer')
local event = require('event')
local shell = require('shell')

-- OpenOS keeps loaded modules until reboot; forget ours so an update takes effect
for _, name in ipairs({'src.format', 'src.options', 'src.lsc', 'src.glasses', 'src.screen', 'src.generators', 'src.link'}) do
  package.loaded[name] = nil
end

local options = require('src.options')
local hud = require('src.glasses')
local screen = require('src.screen')
local link = require('src.link')

local FRAME_SECONDS = 0.1 -- animation frames (arrows, blinking)
local STALE_SECONDS = 10 -- no update for this long (plus 3 update intervals): say so

-- Colours, sizes and what to show come from this computer's config.lua. The values
-- (EU/t, time to full or empty, generator state) come from the Power Display computer.
local configPath = package.searchpath('config', package.path)
configPath = configPath and shell.resolve(configPath) or shell.resolve('config.lua')

local config, problems = options.load(configPath)
if not config then
  io.stderr:write('The viewer did not start. Please fix config.lua (edit config.lua):\n')
  for _, text in ipairs(problems) do
    io.stderr:write('  - ' .. text .. '\n')
  end
  return
end
if not component.isAvailable('tunnel') then
  io.stderr:write('The viewer needs a linked card in this computer (paired with one in the Power Display computer).\n')
  return
end

local function stopRequested(char)
  return char == 99 or char == 67 -- c or C
end

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

local function main()
  -- Glasses are optional here; with none connected, the HUD is just left out
  if config.showHud then
    hud.start(config)
  end
  if config.showScreen and not screen.start(config) then
    print('No screen or graphics card found; showing the HUD only.')
  end

  local waitingText = {'Nothing received yet. On the Power Display computer, set linkedCard = true',
    'in config.lua, and put the other linked card of this pair in it.'}
  message('Waiting for the Power Display computer...', waitingText)

  local lastReceived -- uptime of the last packet
  local showingData = false
  local staleShown = false
  local nextFrame = 0
  while true do
    local name, a, b, c, d, e = event.pull(FRAME_SECONDS)
    local now = computer.uptime()
    if name == 'key_down' and stopRequested(b) then
      return
    end

    if name == 'modem_message' then
      local packet = link.decode(a, e)
      if packet then
        lastReceived = now
        staleShown = false
        if packet.status then
          showingData = false
          hud.notice(packet.status)
          message(packet.status, {packet.text})
        else
          applySender(packet.config)
          local data, view = packet.data, packet.view
          view.remote = true
          view.lowPower = config.lowPowerAlert ~= false and data.percent * 100 < config.lowPowerAlert
          if config.showHud then
            hud.update(data, view)
          end
          screen.addSample(now, data.percent)
          screen.update(data, view)
          showingData = true
        end
      end
    end

    -- Nothing heard for a while: the other computer is off, or its chunk isn't loaded
    local stale = STALE_SECONDS + 3 * (config.sleep or 1)
    if lastReceived and now - lastReceived > stale and not staleShown then
      showingData, staleShown = false, true
      hud.notice('No data from the Power Display computer')
      message('No data from the Power Display computer', {
        'Nothing received for ' .. math.floor(now - lastReceived) .. ' seconds. It may be off,',
        'or its chunk may not be loaded.'})
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

local ok, err = xpcall(main, function(msg)
  if msg == 'interrupted' then
    return msg
  end
  return debug.traceback(tostring(msg), 2)
end)

hud.stop()
screen.stop()

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Viewer stopped.')
