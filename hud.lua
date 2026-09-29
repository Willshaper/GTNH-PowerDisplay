-- Power Display: shows the LSC's charge on AR glasses and on the computer's screen.
-- Run it with: hud      Stop it with C (or Ctrl+Alt+C).
local computer = require('computer')
local event = require('event')
local shell = require('shell')

-- OpenOS keeps loaded modules until reboot; forget ours so an update takes effect
-- and nothing is left over from a previous run
for _, name in ipairs({'src.format', 'src.options', 'src.lsc', 'src.glasses', 'src.screen', 'src.generators'}) do
  package.loaded[name] = nil
end

local options = require('src.options')
local lsc = require('src.lsc')
local hud = require('src.glasses')
local screen = require('src.screen')
local generators = require('src.generators')

local RETRY_SECONDS = 5
local FRAME_SECONDS = 0.1 -- animation frames between updates (arrows, blinking)

-- config.lua is found the same way require would find it, and read fresh every start
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

local hudNote -- shown in the screen's footer, e.g. when no glasses terminal is connected
local generatorProblem -- why generator control can't run, shown on the screen

-- Finds the LSC, waiting until it can be read. Returns the proxy, or nil if C was pressed.
local function waitForLSC()
  while true do
    local machine, seen = lsc.find(config.lscAddress)
    if machine and pcall(machine.getSensorInformation) then
      return machine
    end
    generators.update(nil) -- unknown charge: let the generators run
    hud.notice('Waiting for the LSC...')
    local hint
    if config.lscAddress then
      hint = 'Looking for the address set in config.lua (lscAddress): ' .. config.lscAddress
    elseif machine then
      hint = 'The LSC was found but could not be read yet (is its chunk loaded?).'
    elseif seen and seen > 1 then
      hint = seen .. ' GregTech machines are connected and none looks like an LSC. Set lscAddress in config.lua.'
    else
      hint = 'Place an adapter touching the Lapotronic Supercapacitor controller, and connect it to this computer with cable.'
    end
    message('Waiting for the LSC...', {hint})
    if wait(RETRY_SECONDS) then
      return nil
    end
  end
end

local function animate(now)
  hud.animate(now)
  screen.animate(now)
end

-- Reads and draws until C is pressed (returns) or something fails (raises an error)
local function run(machine)
  local average = lsc.newAverage(config.euTAverage)
  -- "Full in" / "Empty in" uses its own, longer average and changes only every
  -- timeToFullOrEmptyUpdate seconds, so it doesn't jump around
  local timeAverage = lsc.newAverage(config.timeToFullOrEmptyAverage)
  local timeTo, timeToWhat, timeRate
  local nextTimeTo = 0
  while true do
    local data = lsc.read(machine, config)
    local now = computer.uptime()
    average.add(now, data.stored)
    timeAverage.add(now, data.stored)

    local view = {hudNote = hudNote, generatorProblem = generatorProblem}
    view.eut = average.value()
    view.direction = 0
    if view.eut and view.eut >= 1 then
      view.direction = 1
    elseif view.eut and view.eut <= -1 then
      view.direction = -1
    end
    if now + FRAME_SECONDS >= nextTimeTo then -- a little early rather than a whole update late
      timeRate = timeAverage.value()
      timeTo, timeToWhat = lsc.timeTo(data, timeRate)
      if timeRate then
        nextTimeTo = now + config.timeToFullOrEmptyUpdate
      end
    end
    view.timeTo, view.timeToWhat, view.timeRate = timeTo, timeToWhat, timeRate
    view.lowPower = config.lowPowerAlert ~= false and data.percent * 100 < config.lowPowerAlert

    generators.update(data.percent)
    view.generators = generators.isRunning()

    if config.showHud then
      hud.update(data, view)
      hud.animate(now)
    end
    screen.addSample(now, data.percent)
    screen.update(data, view)

    if wait(config.sleep, animate) then
      return
    end
  end
end

local function main()
  if config.showHud and hud.start(config) == 0 then
    hudNote = 'No glasses terminal found'
  end
  if config.showScreen and not screen.start(config) then
    print('No screen or graphics card found; showing the HUD only.')
  end
  if hudNote and not screen.active() then
    print(hudNote .. '; the HUD is not shown.')
  end
  generatorProblem = generators.start(config)
  if generatorProblem and not screen.active() then
    print('Generator control is off: ' .. generatorProblem)
  end

  -- Anything other than C / Ctrl+Alt+C is shown and retried, so one bad read
  -- (the adapter unloaded, the LSC rebuilt) doesn't stop the display.
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
    generators.update(nil)
    hud.notice('Power Display error, retrying...')
    message('Something went wrong, retrying in ' .. RETRY_SECONDS .. 's', {tostring(err)}, 0xFF5555)
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
screen.stop()
generators.stop()

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Power Display stopped.')
