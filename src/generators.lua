-- Optional generator control: a Redstone I/O block's signal starts generators when the
-- LSC runs low and stops them when it is full enough (hysteresis, so they don't flicker).
-- The computer's own redstone card is left alone; it is for wake on redstone.
--
-- generatorSignal = "stop": a signal means "stop" (machine controller cover set to
-- "Disable with Redstone"). generatorSignal = "run": a signal means "run".
-- A Redstone I/O block keeps its output when the computer turns off. The computer only
-- loses power when the LSC is empty, and by then the generators were told to run.
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

-- A card sits in one of the computer's slots; a Redstone I/O block doesn't
local function inSlot(address)
  local ok, slot = pcall(component.slot, address)
  return ok and type(slot) == 'number' and slot >= 0
end

-- "Redstone I/O blocks found: 1a2b3c4d, 9f8e7d6c" (the start of each address)
local function blocksFound()
  local found = {}
  for address in component.list('redstone') do
    if not inSlot(address) then
      table.insert(found, address:sub(1, 8))
    end
  end
  if #found == 0 then
    return 'No Redstone I/O block is connected to this computer.'
  end
  return 'Redstone I/O blocks found: ' .. table.concat(found, ', ')
end

-- Returns nil, or why it can't run and a hint listing the Redstone I/O blocks
function generators.start(cfg)
  config = cfg
  running = nil
  redstone = nil
  if not config.generatorControl then
    return nil
  end
  local wanted = config.generatorRedstoneAddress
  if not wanted then
    return 'set generatorRedstoneAddress in config.lua', blocksFound()
  end
  local ok, address = pcall(component.get, wanted, 'redstone')
  if not ok or not address then
    return 'no Redstone I/O block with address ' .. wanted, blocksFound()
  end
  if inSlot(address) then
    return address:sub(1, 8) .. ' is the redstone card, not a Redstone I/O block', blocksFound()
  end
  redstone = component.proxy(address)
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
