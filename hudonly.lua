-- Power Display, HUD only: reads the LSC and shows its charge on AR glasses.
-- No screen monitor, generator control or linked card (use hud for those).
-- Run it with: hudonly      Stop it with C (or Ctrl+Alt+C).
local computer = require('computer')
local event = require('event')
local shell = require('shell')

-- OpenOS keeps loaded modules until reboot; forget ours so an update takes effect
for _, name in ipairs({'src.format', 'src.options', 'src.lsc', 'src.glasses'}) do
  package.loaded[name] = nil
end

local options = require('src.options')
local lsc = require('src.lsc')
local hud = require('src.glasses')

local RETRY_SECONDS = 5
local FRAME_SECONDS = 0.1 -- animation frames between updates (arrows, blinking)

local configPath = package.searchpath('config', package.path)
configPath = configPath and shell.resolve(configPath) or shell.resolve('config.lua')

local config, problems = options.load(configPath)
if not config then
  io.stderr:write('Power Display did not start. Please fix config.lua (edit config.lua):\n')
  for _, text in ipairs(problems) do
    io.stderr:write('  - ' .. text .. '\n')
  end
  return
end

local function stopRequested(char)
  return char == 99 or char == 67 -- c or C
end

-- Waits up to `seconds`, returning true as soon as C is pressed. With `frame`,
-- calls frame(uptime) every FRAME_SECONDS meanwhile (arrows and blinking).
-- Ctrl+Alt+C raises "interrupted" from event.pull, which ends the program.
local function wait(seconds, frame)
  local deadline = computer.uptime() + seconds
  repeat
    local timeout = math.max(0, deadline - computer.uptime())
    if frame then
      timeout = math.min(timeout, FRAME_SECONDS)
    end
    local name, _, char = event.pull(timeout, 'key_down')
    if name == 'key_down' and stopRequested(char) then
      return true
    end
    if frame then
      frame(computer.uptime())
    end
  until computer.uptime() >= deadline
  return false
end

-- Prints a status line, once until it changes
local lastPrinted
local function status(text)
  if text ~= lastPrinted then
    print(text)
    lastPrinted = text
  end
end

-- Draws the HUD on every glasses terminal, waiting until there is one.
-- Returns false if C was pressed.
local function waitForGlasses()
  while hud.start(config) == 0 do
    status('No glasses terminal found. Connect one to this computer with cable (checking every ' .. RETRY_SECONDS .. 's).')
    if wait(RETRY_SECONDS) then
      return false
    end
  end
  return true
end

-- Finds the LSC, waiting until it can be read. Returns the proxy, or nil if C was pressed.
local function waitForLSC()
  while true do
    local machine, seen = lsc.find(config.lscAddress)
    if machine and pcall(machine.getSensorInformation) then
      return machine
    end
    hud.notice('Waiting for the LSC...')
    if config.lscAddress then
      status('Waiting for the LSC with the address set in config.lua (lscAddress): ' .. config.lscAddress)
    elseif machine then
      status('Waiting for the LSC: found, but it could not be read yet (is its chunk loaded?).')
    elseif seen and seen > 1 then
      status('Waiting for the LSC: ' .. seen .. ' GregTech machines are connected and none looks like an LSC. Set lscAddress in config.lua.')
    else
      status('Waiting for the LSC: place an adapter touching its controller, and connect it to this computer with cable.')
    end
    if wait(RETRY_SECONDS) then
      return nil
    end
  end
end

-- Reads and draws until C is pressed (returns) or something fails (raises an error)
local function run(machine)
  status('Showing the LSC on the HUD. Press C to stop.')
  local average = lsc.newAverage(config.euTAverage)
  while true do
    local data = lsc.read(machine, config)
    local now = computer.uptime()
    average.add(now, data.stored)

    local view = {eut = average.value(), direction = 0}
    if view.eut and view.eut >= 1 then
      view.direction = 1
    elseif view.eut and view.eut <= -1 then
      view.direction = -1
    end
    view.lowPower = config.lowPowerAlert ~= false and data.percent * 100 < config.lowPowerAlert

    hud.update(data, view)
    hud.animate(now)
    if wait(config.sleep, hud.animate) then
      return
    end
  end
end

local function main()
  if not waitForGlasses() then
    return
  end
  -- Anything other than C / Ctrl+Alt+C is shown and retried, so one bad read
  -- (the adapter unloaded, the LSC rebuilt) doesn't stop the HUD.
  while true do
    local machine = waitForLSC()
    if not machine then
      return
    end
    local ok, err = pcall(run, machine)
    if ok then
      return
    end
    if err == 'interrupted' then
      error(err, 0)
    end
    hud.notice('Power Display error, retrying...')
    status('Something went wrong, retrying in ' .. RETRY_SECONDS .. 's: ' .. tostring(err))
    if wait(RETRY_SECONDS) then
      return
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

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Power Display stopped.')
