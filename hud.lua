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

-- Waits up to `seconds`, returning true as soon as C is pressed.
-- Ctrl+Alt+C raises "interrupted" from event.pull, which ends the program.
local function wait(seconds)
  local deadline = computer.uptime() + seconds
  repeat
    local name, _, char = event.pull(math.max(0, deadline - computer.uptime()), 'key_down')
    if name == 'key_down' and stopRequested(char) then
      return true
    end
  until computer.uptime() >= deadline
  return false
end

-- Upstream's rate arrows: how fast the fill % changed since the last update
local function arrows(percent, last, threshold)
  if percent > last + 2*threshold then return '>>>'
  elseif percent > last + threshold then return '>>'
  elseif percent >= last then return '>'
  elseif percent > last - threshold then return '<'
  elseif percent > last - 2*threshold then return '<<'
  end
  return '<<<'
end

-- Shows a message on the screen, or prints it once if there is no screen
local printed = {}
local function message(title, lines, color)
  if screen.active() then
    screen.message(title, lines, color)
    return
  end
  local text = title .. '\n' .. table.concat(lines or {}, '\n')
  if printed.last ~= text then
    print(text)
    printed.last = text
  end
end

-- Finds the LSC, waiting until it can be read. Returns the proxy, or nil if C was pressed.
local function waitForLSC()
  while true do
    local machine = lsc.find(config.lscAddress)
    if machine and pcall(machine.getSensorInformation) then
      return machine
    end
    generators.update(nil) -- unknown charge: let the generators run
    hud.notice('Waiting for the LSC...')
    message('Waiting for the LSC...', {
      'Place an adapter touching the Lapotronic Supercapacitor controller,',
      'and connect it to this computer with cable.',
      config.lscAddress and ('Looking for the address set in config.lua: ' .. config.lscAddress) or '',
    })
    if wait(RETRY_SECONDS) then
      return nil
    end
  end
end

-- Reads and draws until C is pressed (returns) or something fails (raises an error)
local function run(machine)
  local average = lsc.newAverage(config.euTSeconds)
  local last = nil
  while true do
    local data = lsc.read(machine, config)
    local now = computer.uptime()
    average.add(now, data.stored)

    local view = {}
    view.eut = average.value()
    view.timeTo, view.timeToWhat = lsc.timeTo(data, view.eut)
    view.lowPower = config.lowPowerAlert ~= false and data.percent * 100 < config.lowPowerAlert
    view.rate = ''
    if config.showRate then
      view.rate = arrows(data.percent, last or data.percent, config.rateThreshold)
      last = data.percent
    end

    generators.update(data.percent)
    view.generators = generators.isRunning()

    if config.showHud then
      hud.update(data, view)
    end
    screen.addSample(now, data.percent)
    screen.update(data, view)

    if wait(config.sleep) then
      return
    end
  end
end

local function main()
  -- Printed notes go first: once the monitor is drawn, printing would land on top of it
  if config.showHud and hud.start(config) == 0 then
    print('No glasses terminal found; the HUD is not shown.')
  end
  if config.showScreen and not screen.start(config) then
    print('No screen or graphics card found; showing the HUD only.')
  end
  local generatorProblem = generators.start(config)
  if generatorProblem then
    message('Generator control is off', {generatorProblem}, 0xFF5555)
    if wait(RETRY_SECONDS) then
      return
    end
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
