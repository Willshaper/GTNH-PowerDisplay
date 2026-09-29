-- Loads config.lua, fills in defaults for anything missing and checks every value.
-- Mistakes are reported as plain sentences instead of a Lua error.
local options = {}

local DEFAULTS = {
  showHud = true,
  showScreen = true,

  resolution = {1920, 1080},
  fullscreen = true,
  GUIscale = 3,
  hudSide = 'left',

  showPercent = true,
  showCurrentEU = true,
  showArrows = true,
  showMaxEU = true,
  showMaintenance = true,
  showTimeTo = true,
  timeToSeconds = 30,
  timeToUpdate = 5,
  showAverages = true,
  showEUt = true,
  euTSeconds = 5,
  euTFontSize = 3,

  wirelessMode = false,
  wirelessMax = 1e15,

  metric = true,

  height = 12,
  length = 168,
  borderBottom = 2,
  borderTop = 2,
  fontSize = 3,

  shapeAlpha = 0.9,
  textAlpha = 1.0,

  primaryColor = 0x00A6FF,
  secondaryColor = 0x303850,
  textColor = 0x000000,
  textColorEmpty = 0xE6E6E6,
  barTextStyle = 'split',
  euTColor = false, -- false: textColor or textColorEmpty, whichever part of the bar it is over
  issueColor = 0xFF0000,
  borderColor = 0x181828,

  lowPowerAlert = 20,
  lowPowerBlink = true,

  generatorControl = false,
  generatorSide = 'back',
  generatorOnBelow = 20,
  generatorOffAbove = 90,
  generatorSignal = 'stop',

  showPassiveLoss = true,
  showHistory = true,
  historyMinutes = 30,
  lscAddress = false,

  sleep = 1,
}

-- Settings from older versions: the new name, or false when it no longer does anything.
-- They are accepted so an old config.lua keeps working.
local RENAMED = {
  showRate = 'showArrows',
  rateThreshold = false,
  barAnimation = false,
}

local SIDES = {
  bottom = true, top = true, back = true, front = true, right = true, left = true,
  down = true, up = true, north = true, south = true, west = true, east = true,
}

local problems

local function problem(text)
  table.insert(problems, text)
end

local function isNumber(value)
  return type(value) == 'number' and value == value
end

local function number(config, key, min, max)
  local value = config[key]
  if not isNumber(value) then
    problem(string.format('%s must be a number (it is %s)', key, tostring(value)))
  elseif (min and value < min) or (max and value > max) then
    if max then
      problem(string.format('%s (%s) must be between %s and %s', key, value, min, max))
    else
      problem(string.format('%s (%s) must be at least %s', key, value, min))
    end
  end
end

local function boolean(config, key)
  if type(config[key]) ~= 'boolean' then
    problem(string.format('%s must be true or false (it is %s)', key, tostring(config[key])))
  end
end

local function color(config, key, optional)
  local value = config[key]
  if optional and value == false then
    return
  end
  if math.type(value) ~= 'integer' or value < 0 or value > 0xFFFFFF then
    problem(string.format('%s must be a colour like 0xFF0000 or colors.red (it is %s)', key, tostring(value)))
  end
end

local function percentOrFalse(config, key)
  local value = config[key]
  if value ~= false and not (isNumber(value) and value >= 0 and value <= 100) then
    problem(string.format('%s must be a percentage from 0 to 100, or false to turn it off (it is %s)', key, tostring(value)))
  end
end

local function check(config)
  boolean(config, 'showHud')
  boolean(config, 'showScreen')

  local resolution = config.resolution
  if type(resolution) ~= 'table' or not isNumber(resolution[1]) or not isNumber(resolution[2]) then
    problem('resolution must look like {1920, 1080}')
  end
  boolean(config, 'fullscreen')
  if config.hudSide ~= 'left' and config.hudSide ~= 'right' then
    problem(string.format('hudSide must be "left" or "right" (it is %s)', tostring(config.hudSide)))
  end
  number(config, 'GUIscale', 1, 10)

  for _, key in ipairs({'showPercent', 'showMaintenance', 'showTimeTo', 'showAverages', 'showCurrentEU', 'showArrows', 'showMaxEU', 'showEUt', 'wirelessMode', 'metric', 'lowPowerBlink',
      'showPassiveLoss', 'showHistory', 'generatorControl'}) do
    boolean(config, key)
  end
  number(config, 'euTSeconds', 1)
  number(config, 'euTFontSize', 1)
  number(config, 'timeToSeconds', 1)
  number(config, 'timeToUpdate', 1)
  number(config, 'wirelessMax', 1)

  for _, key in ipairs({'height', 'length', 'fontSize'}) do
    number(config, key, 1)
  end
  number(config, 'borderBottom', 0)
  number(config, 'borderTop', 0)
  number(config, 'shapeAlpha', 0, 1)
  number(config, 'textAlpha', 0, 1)

  for _, key in ipairs({'primaryColor', 'secondaryColor', 'textColor', 'textColorEmpty', 'issueColor', 'borderColor'}) do
    color(config, key)
  end
  color(config, 'euTColor', true)

  percentOrFalse(config, 'lowPowerAlert')

  if config.barTextStyle ~= 'split' and config.barTextStyle ~= 'shadow' then
    problem(string.format('barTextStyle must be "split" or "shadow" (it is %s)', tostring(config.barTextStyle)))
  end
  if not SIDES[config.generatorSide] then
    problem(string.format('generatorSide must be one of back, front, left, right, top, bottom (it is %s)', tostring(config.generatorSide)))
  end
  number(config, 'generatorOnBelow', 0, 100)
  number(config, 'generatorOffAbove', 0, 100)
  if isNumber(config.generatorOnBelow) and isNumber(config.generatorOffAbove)
      and config.generatorOnBelow >= config.generatorOffAbove then
    problem(string.format('generatorOnBelow (%s) must be lower than generatorOffAbove (%s)',
      config.generatorOnBelow, config.generatorOffAbove))
  end
  if config.generatorSignal ~= 'stop' and config.generatorSignal ~= 'run' then
    problem(string.format('generatorSignal must be "stop" or "run" (it is %s)', tostring(config.generatorSignal)))
  end

  number(config, 'historyMinutes', 1)
  if config.lscAddress ~= false and type(config.lscAddress) ~= 'string' then
    problem('lscAddress must be an address in quotes, or false to find the LSC automatically')
  end
  number(config, 'sleep', 0.05)

  if not config.showHud and not config.showScreen then
    problem('showHud and showScreen are both false, so there is nothing to show')
  end
end

-- Returns the config table, or nil and a list of problems
function options.load(path)
  problems = {}
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, {'config.lua has a typing mistake: ' .. tostring(err)}
  end
  local ok, loaded = pcall(chunk)
  if not ok then
    return nil, {'config.lua stopped with an error: ' .. tostring(loaded)}
  end
  if type(loaded) ~= 'table' then
    return nil, {'config.lua must end with return { ... } (a missing comma between settings can cause this)'}
  end

  local config = {}
  for key, value in pairs(DEFAULTS) do
    config[key] = value
  end
  for key, value in pairs(loaded) do
    local renamed = RENAMED[key]
    if renamed ~= nil then
      -- An older setting: use it for its new name unless that is set too
      if renamed and loaded[renamed] == nil then
        config[renamed] = value
      end
    elseif DEFAULTS[key] == nil then
      problem(string.format('%s is not a setting (check the spelling)', tostring(key)))
    else
      config[key] = value
    end
  end
  check(config)
  if #problems > 0 then
    return nil, problems
  end
  if config.lscAddress == false then
    config.lscAddress = nil
  end
  return config
end

return options
