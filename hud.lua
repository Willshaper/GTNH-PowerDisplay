-- Power Display: shows the LSC's charge on AR glasses and on the computer's screen.
-- Run it with: hud      Stop it with C (or Ctrl+Alt+C), edit the settings with S.
local computer = require('computer')
local event = require('event')
local shell = require('shell')
local term = require('term')

-- OpenOS keeps loaded modules until reboot; forget ours so an update takes effect
-- and nothing is left over from a previous run
for _, name in ipairs({'src.format', 'src.options', 'src.lsc', 'src.glasses', 'src.screen', 'src.generators', 'src.link',
    'src.discord'}) do
  package.loaded[name] = nil
end

local options = require('src.options')
local lsc = require('src.lsc')
local hud = require('src.glasses')
local screen = require('src.screen')
local generators = require('src.generators')
local link = require('src.link')
local discord = require('src.discord')

local RETRY_SECONDS = 5
local FRAME_SECONDS = 0.1 -- animation frames between updates (arrows, low power fade)

-- config.lua is found the same way require would find it, and read fresh every start
local configPath = package.searchpath('config', package.path)
configPath = configPath and shell.resolve(configPath) or shell.resolve('config.lua')

local config, problems = options.load(configPath)
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

local notes -- shown in the screen's footer, e.g. when no glasses terminal is connected
local generatorProblem, generatorHint -- why generator control can't run, shown on the screen
local editProblems -- mistakes in a config.lua just edited with S (the previous settings stay)

-- Finds the LSC, waiting until it can be read. Returns the proxy, or nil and 'stop'
-- or 'edit' when C or S was pressed.
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
    link.sendStatus('The Power Display computer is waiting for the LSC.', hint)
    discord.missing(hint)
    local action = wait(RETRY_SECONDS)
    if action then
      return nil, action
    end
  end
end

local function animate(now)
  hud.animate(now)
  screen.animate(now)
end

-- Reads and draws until C or S is pressed (returns 'stop' or 'edit') or something
-- fails (raises an error)
local function run(machine)
  local average = lsc.newAverage(config.euTAverage)
  -- "Full in" / "Empty in" uses its own, longer average and changes only every
  -- timeLeftUpdateOnScreen seconds on the screen, so it doesn't jump around.
  -- The HUD shows it on every update, together with the EU/t.
  local timeAverage = lsc.newAverage(config.timeLeftAverage)
  local timeTo, timeToWhat, timeRate
  local nextTimeTo = 0
  while true do
    local data = lsc.read(machine, config)
    local now = computer.uptime()
    average.add(now, data.stored)
    timeAverage.add(now, data.stored)

    local view = {notes = notes, generatorProblem = generatorProblem, generatorHint = generatorHint,
      discordProblems = discord.problems()}
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
        nextTimeTo = now + config.timeLeftUpdateOnScreen
      end
    end
    view.timeTo, view.timeToWhat, view.timeRate = timeTo, timeToWhat, timeRate
    view.hudTimeTo, view.hudTimeToWhat = lsc.timeTo(data, timeAverage.value())
    view.lowPower = config.lowPower ~= false and data.percent * 100 < config.lowPower

    generators.update(data.percent)
    view.generators = generators.isRunning()
    link.send(data, view, config)
    discord.update(data, view)

    if config.showHud then
      hud.update(data, view)
      hud.animate(now)
    end
    screen.addSample(now, data.percent)
    screen.update(data, view)

    local action = wait(config.updateEvery, animate)
    if action then
      return action
    end
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
  notes = {}
  if config.showHud and hud.start(config) == 0 then
    table.insert(notes, 'No glasses terminal found')
  end
  local linkProblem = link.start(config)
  if linkProblem then
    table.insert(notes, 'Linked card: ' .. linkProblem)
  elseif link.active() then
    table.insert(notes, 'Sending to the linked card')
  end
  if config.showScreen and not screen.start(config) then
    print('No screen or graphics card found; showing the HUD only.')
  end
  if #notes > 0 and not screen.active() then
    print(table.concat(notes, '. ') .. '.')
  end
  generatorProblem, generatorHint = generators.start(config)
  discord.configure(config, discordWarning)
  if generatorProblem and not screen.active() then
    print('Generator control is off: ' .. generatorProblem)
    print(generatorHint)
  end

  -- A config.lua edited with S that has a mistake: say so for a while
  if editProblems then
    local lines = {}
    for _, found in ipairs(editProblems) do
      table.insert(lines, '- ' .. found.text)
    end
    table.insert(lines, '')
    table.insert(lines, 'Press S to fix it: Power Display will not start with it next time.')
    editProblems = nil
    hud.notice('config.lua has a mistake (see the screen)')
    message('config.lua has a mistake, so the previous settings are still used', lines, 0xFF5555)
    local action = wait(8)
    if action then
      return action
    end
  end

  -- Anything other than C / Ctrl+Alt+C is shown and retried, so one bad read
  -- (the adapter unloaded, the LSC rebuilt) doesn't stop the display.
  while true do
    local machine, action = waitForLSC()
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
    generators.update(nil)
    hud.notice('Power Display error, retrying...')
    message('Something went wrong, retrying in ' .. RETRY_SECONDS .. 's', {tostring(err)}, 0xFF5555)
    link.sendStatus('The Power Display computer had an error and is retrying.', tostring(err))
    discord.missing('Error: ' .. tostring(err))
    local action = wait(RETRY_SECONDS)
    if action then
      return action
    end
  end
end

-- S: edits config.lua in OpenOS's editor, then reads it again. The new settings are
-- used if they have no mistakes; otherwise the previous ones stay and main says so.
local function editConfig()
  hud.notice('Editing config.lua...')
  link.sendStatus("The Power Display computer's settings are being edited.", 'It continues when they are saved.')
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
  discord.started({started = 'Power Display started', lost = "The LSC can't be read",
    back = 'The LSC can be read again'})
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
generators.stop()
discord.stop()

if not ok and err ~= 'interrupted' then
  io.stderr:write(tostring(err) .. '\n')
end
print('Power Display stopped.')
