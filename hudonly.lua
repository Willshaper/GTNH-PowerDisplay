-- Power Display, HUD only: reads the LSC and shows its charge on AR glasses.
-- No screen monitor, generator control or linked card (use hud for those).
-- Run it with: hudonly      Stop it with C (or Ctrl+Alt+C), edit the settings with S.
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
local FRAME_SECONDS = 0.1 -- animation frames between updates (arrows, low power fade)

local configPath = package.searchpath('config', package.path)
configPath = configPath and shell.resolve(configPath) or shell.resolve('config.lua')

-- Reads config.lua. Returns the config, or nil and a list of problems.
local function loadConfig()
  local loaded, problems = options.load(configPath)
  if loaded and not loaded.showHud then
    return nil, {{text = 'hud in config.lua is empty, so there is nothing to show'}}
  end
  return loaded, problems
end

local config, problems = loadConfig()
if not config then
  io.stderr:write('Power Display did not start. Please fix config.lua (edit config.lua):\n')
  for _, found in ipairs(problems) do
    io.stderr:write('  - ' .. found.text .. '\n')
  end
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

-- Waits up to `seconds`. Returns 'stop' or 'edit' as soon as C or S is pressed.
-- With `frame`, calls frame(uptime) every FRAME_SECONDS meanwhile (arrows and
-- low power fade). Ctrl+Alt+C raises "interrupted" from event.pull, which ends the program.
local function wait(seconds, frame)
  local deadline = computer.uptime() + seconds
  repeat
    local timeout = math.max(0, deadline - computer.uptime())
    if frame then
      timeout = math.min(timeout, FRAME_SECONDS)
    end
    local name, _, char = event.pull(timeout, 'key_down')
    local action = name == 'key_down' and keyAction(char)
    if action then
      return action
    end
    if frame then
      frame(computer.uptime())
    end
  until computer.uptime() >= deadline
  return nil
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
-- Returns 'stop' or 'edit' if C or S was pressed meanwhile.
local function waitForGlasses()
  while hud.start(config) == 0 do
    status('No glasses terminal found. Connect one to this computer with cable (checking every ' .. RETRY_SECONDS .. 's).')
    local action = wait(RETRY_SECONDS)
    if action then
      return action
    end
  end
  return nil
end

-- Finds the LSC, waiting until it can be read. Returns the proxy, or nil and 'stop'
-- or 'edit' when C or S was pressed.
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
    local action = wait(RETRY_SECONDS)
    if action then
      return nil, action
    end
  end
end

-- Reads and draws until C or S is pressed (returns 'stop' or 'edit') or something
-- fails (raises an error)
local function run(machine)
  status('Showing the LSC on the HUD. C stops, S edits settings.')
  local average = lsc.newAverage(config.euTAverage)
  -- Time to full or empty: its own, longer average, worked out on every update
  -- together with the EU/t
  local timeAverage = lsc.newAverage(config.timeLeftAverage)
  while true do
    local data = lsc.read(machine, config)
    local now = computer.uptime()
    average.add(now, data.stored)
    timeAverage.add(now, data.stored)

    local view = {eut = average.value(), direction = 0}
    if view.eut and view.eut >= 1 then
      view.direction = 1
    elseif view.eut and view.eut <= -1 then
      view.direction = -1
    end
    view.lowPower = config.lowPower ~= false and data.percent * 100 < config.lowPower
    view.hudTimeTo, view.hudTimeToWhat = lsc.timeTo(data, timeAverage.value())

    hud.update(data, view)
    hud.animate(now)
    local action = wait(config.updateEvery, hud.animate)
    if action then
      return action
    end
  end
end

-- Shows the HUD with the current settings until C or S is pressed; returns 'stop' or 'edit'
local function main()
  local action = waitForGlasses()
  if action then
    return action
  end
  -- Anything other than C / Ctrl+Alt+C is shown and retried, so one bad read
  -- (the adapter unloaded, the LSC rebuilt) doesn't stop the HUD.
  while true do
    local machine
    machine, action = waitForLSC()
    if not machine then
      return action
    end
    local ok, err = pcall(run, machine)
    if ok then
      return err -- 'stop' or 'edit'
    end
    if err == 'interrupted' then
      error(err, 0)
    end
    hud.notice('Power Display error, retrying...')
    status('Something went wrong, retrying in ' .. RETRY_SECONDS .. 's: ' .. tostring(err))
    action = wait(RETRY_SECONDS)
    if action then
      return action
    end
  end
end

-- S: edits config.lua in OpenOS's editor, then reads it again. The new settings are
-- used if they have no mistakes; otherwise the previous ones stay.
local function editConfig()
  hud.notice('Editing config.lua...')
  shell.execute('edit "' .. configPath .. '"')
  lastPrinted = nil -- the editor cleared the screen: print the status again
  local newConfig, found = loadConfig()
  if newConfig then
    config = newConfig
    print('Settings saved and in use.')
  else
    print('config.lua has a mistake, so the previous settings are still used:')
    for _, each in ipairs(found) do
      print('  - ' .. each.text)
    end
    print('Press S to fix it: Power Display will not start with it next time.')
  end
  hud.stop() -- drawn again with the settings now in use
end

local function program()
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

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Power Display stopped.')
