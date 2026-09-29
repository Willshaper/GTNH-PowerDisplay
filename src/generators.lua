-- Optional generator control: a redstone signal that starts generators when the LSC
-- runs low and stops them when it is full enough (hysteresis, so they don't flicker).
--
-- generatorSignal = "stop": a signal means "stop". A redstone card's outputs switch off
-- when the computer turns off, so if this computer dies the generators run. (A Redstone
-- I/O block keeps its output, so the card is the fail-safe choice.)
-- Wire it to a machine controller cover set to "Disable with Redstone".
-- generatorSignal = "run": a signal means "run" (enable with redstone).
local component = require('component')
local sides = require('sides')

local generators = {}

local config
local redstone
local side
local running = nil -- nil until the first update decides

local function output(run)
  local wantSignal
  if config.generatorSignal == 'stop' then
    wantSignal = not run
  else
    wantSignal = run
  end
  redstone.setOutput(side, wantSignal and 15 or 0)
end

-- Returns nil, or a sentence saying why it can't run
function generators.start(cfg)
  config = cfg
  running = nil
  if not config.generatorControl then
    return nil
  end
  if not component.isAvailable('redstone') then
    return 'generatorControl is on, but there is no redstone card or Redstone I/O block'
  end
  redstone = component.redstone
  side = sides[config.generatorSide]
  return nil
end

function generators.enabled()
  return config ~= nil and config.generatorControl and redstone ~= nil
end

-- percent: 0..1, or nil if the LSC couldn't be read (then the generators run)
function generators.update(percent)
  if not generators.enabled() then
    return
  end
  local previous = running
  if percent == nil then
    running = true
  elseif percent * 100 < config.generatorOnBelow then
    running = true
  elseif percent * 100 > config.generatorOffAbove then
    running = false
  elseif running == nil then
    running = false -- started in between the two set points: wait until it drops
  end
  if running ~= previous then
    output(running)
  end
end

function generators.isRunning()
  return running
end

-- On exit: leave the generators running
function generators.stop()
  if generators.enabled() then
    pcall(output, true)
  end
  running = nil
end

return generators
