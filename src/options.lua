-- Reads config.lua: plain "name = value" lines, no commas or return needed. Fills in
-- defaults for anything left out and checks every value. Mistakes are reported as
-- plain sentences instead of a Lua error.
local options = {}

-- Colours that can be used by name, e.g. barColor = "electricBlue"
options.COLORS = {
  red = 0xFF0000, orange = 0xFFA500, yellow = 0xFFFF00, green = 0x008000, blue = 0x0000FF,
  indigo = 0x4B0082, violet = 0x800080, maroon = 0x800000, golden = 0xDAA520, lime = 0x00FF00,
  olive = 0x556B2F, cyan = 0x00FFFF, magenta = 0xFF00FF,
  black = 0x000000, white = 0xFFFFFF, gray = 0x3C5B72, lightGray = 0xA9A9A9, offWhite = 0xE6E6E6,
  darkGray = 0x181828,
  electricBlue = 0x00A6FF, dodgerBlue = 0x1E90FF, steelBlue = 0x4682B4, midnightBlue = 0x191970,
  darkBlue = 0x000080, darkSlateGreen = 0x2F4F4F, darkSlateBlue = 0x303850,
}

-- Words for the hud and screen settings, and where each can be shown
local HUD_WORDS = {'Percent', 'Stored', 'EUt', 'Arrows', 'Max', 'Maintenance', 'TimeLeft'}
local SCREEN_ONLY_WORDS = {'Averages', 'PassiveLoss', 'History'}

local DEFAULTS = {
  -- What to show
  hud = 'Percent Stored EUt Arrows Max Maintenance',
  screen = 'Percent Stored EUt Arrows Max Maintenance TimeLeft Averages PassiveLoss History',
  hudCorner = 'left',
  lowPower = 20,

  -- Minecraft window
  windowSize = {1920, 1080},
  fullscreen = true,
  guiScale = 3,

  -- Generators
  generatorControl = false,
  generatorOnBelow = 20,
  generatorOffAbove = 90,
  generatorSide = 'north',
  generatorSignal = 'stop',

  linkedCard = false,

  -- Colours
  barColor = 'electricBlue',
  barEmptyColor = 'darkSlateBlue',
  textOverFillColor = 'black',
  textOverEmptyColor = 'offWhite',
  euTColor = false,
  alertColor = 'red',
  frameColor = 'darkGray',
  timeLeftColor = 'offWhite',

  -- Advanced
  numberFormat = 'metric',
  wireless = false,
  euTAverage = 5,
  timeLeftAverage = 30,
  timeLeftUpdateOnScreen = 5,
  updateEvery = 2,
  lowPowerBlink = true,
  historyMinutes = 30,
  barTextStyle = 'shadow',
  hudHeight = 12,
  hudLength = 168,
  hudBorderBottom = 2,
  hudBorderTop = 2,
  hudFontSize = 3,
  hudEuTFontSize = false,
  hudShapeOpacity = 0.9,
  hudTextOpacity = 1.0,
  lscAddress = false,
}

-- A Redstone I/O block can't be turned, so its sides are compass directions
local SIDES = {bottom = true, top = true, north = true, south = true, west = true, east = true}

-- Every setting name, for the installer
function options.isSetting(name)
  return DEFAULTS[name] ~= nil
end

-- Runs the text of a config.lua. Returns the settings it sets, or nil and a message.
-- A name that isn't in quotes and isn't known stops it with a clear message, so
-- barColor = electricBlue (without quotes) isn't silently ignored.
function options.parse(text)
  local values = {}
  local env = {}
  local chunk, err = load(text, '=config.lua', 't', env)
  if not chunk then
    return nil, 'config.lua has a typing mistake: ' .. tostring(err)
  end
  -- Only now: OpenOS's load looks names up in env itself (env.load), which must not
  -- count as a mistake in config.lua
  setmetatable(env, {
    __index = function(_, name)
      error(string.format('%s is unknown: text such as colour names and sides goes in quotes, e.g. "%s"', name, name), 2)
    end,
    __newindex = function(_, name, value)
      values[name] = value
    end,
  })
  local ok, result = pcall(chunk)
  if not ok then
    return nil, 'config.lua: ' .. tostring(result)
  end
  if result ~= nil then
    return nil, 'config.lua should only have settings, one per line like barColor = "electricBlue"'
  end
  return values
end

local problems

-- key: the setting that is wrong; other: a second setting it conflicts with
local function problem(key, text, other)
  table.insert(problems, {key = key, text = text, other = other})
end

local function isNumber(value)
  return type(value) == 'number' and value == value
end

local function number(config, key, min, max)
  local value = config[key]
  if not isNumber(value) then
    problem(key, string.format('%s must be a number (it is %s)', key, tostring(value)))
  elseif (min and value < min) or (max and value > max) then
    if max then
      problem(key, string.format('%s (%s) must be between %s and %s', key, value, min, max))
    else
      problem(key, string.format('%s (%s) must be at least %s', key, value, min))
    end
  end
end

local function boolean(config, key)
  if type(config[key]) ~= 'boolean' then
    problem(key, string.format('%s must be true or false (it is %s)', key, tostring(config[key])))
  end
end

local function oneOf(config, key, allowed)
  for _, value in ipairs(allowed) do
    if config[key] == value then
      return
    end
  end
  problem(key, string.format('%s must be "%s" (it is %s)', key, table.concat(allowed, '" or "'), tostring(config[key])))
end

-- A colour name in quotes or a number like 0xFF8800; turned into the number
local function color(config, key, optional)
  local value = config[key]
  if optional and value == false then
    return
  end
  if type(value) == 'string' and options.COLORS[value] then
    config[key] = options.COLORS[value]
  elseif not (math.type(value) == 'integer' and value >= 0 and value <= 0xFFFFFF) then
    problem(key, string.format('%s must be a colour name in quotes from the list at the end of config.lua, '
      .. 'or a number like 0xFF8800 (it is %s)', key, tostring(value)))
  end
end

-- "Percent Stored EUt" -> {Percent = true, Stored = true, EUt = true}; any case
local function words(config, key, allowed, elsewhere)
  local value = config[key]
  if type(value) ~= 'string' then
    problem(key, string.format('%s must be a list of words in quotes, e.g. "%s"', key, DEFAULTS[key]))
    return
  end
  local known = {}
  for _, word in ipairs(allowed) do
    known[word:lower()] = word
  end
  local set = {}
  for word in value:gmatch('%S+') do
    local name = known[word:lower()]
    if name then
      set[name] = true
    elseif elsewhere and elsewhere[word:lower()] then
      problem(key, string.format('%s: %s can only be shown on the screen', key, word))
    else
      problem(key, string.format('%s: "%s" is not one of %s', key, word, table.concat(allowed, ', ')))
    end
  end
  config[key] = set
end

local function check(config)
  local screenWords = {}
  for _, word in ipairs(HUD_WORDS) do table.insert(screenWords, word) end
  for _, word in ipairs(SCREEN_ONLY_WORDS) do table.insert(screenWords, word) end
  local screenOnly = {}
  for _, word in ipairs(SCREEN_ONLY_WORDS) do screenOnly[word:lower()] = true end
  local hudText, screenText = config.hud, config.screen
  words(config, 'hud', HUD_WORDS, screenOnly)
  words(config, 'screen', screenWords)
  -- Whether there is a HUD / a screen monitor at all
  config.showHud = type(hudText) == 'string' and hudText:find('%S') ~= nil
  config.showScreen = type(screenText) == 'string' and screenText:find('%S') ~= nil
  if type(hudText) == 'string' and type(screenText) == 'string' and not config.showHud and not config.showScreen then
    problem('screen', 'hud and screen are both empty, so there is nothing to show', 'hud')
  end
  oneOf(config, 'hudCorner', {'left', 'right'})
  if config.lowPower ~= false and not (isNumber(config.lowPower) and config.lowPower >= 0 and config.lowPower <= 100) then
    problem('lowPower', string.format('lowPower must be a percentage from 0 to 100, or false to turn it off (it is %s)',
      tostring(config.lowPower)))
  end

  local size = config.windowSize
  if type(size) ~= 'table' or not isNumber(size[1]) or not isNumber(size[2]) then
    problem('windowSize', 'windowSize must look like {1920, 1080}')
  end
  boolean(config, 'fullscreen')
  number(config, 'guiScale', 1, 10)

  if config.generatorControl ~= false and type(config.generatorControl) ~= 'string' then
    problem('generatorControl', "generatorControl must be false, or the Redstone I/O block's address in quotes, e.g. \"1a2b3c4d\"")
  end
  number(config, 'generatorOnBelow', 0, 100)
  number(config, 'generatorOffAbove', 0, 100)
  if isNumber(config.generatorOnBelow) and isNumber(config.generatorOffAbove)
      and config.generatorOnBelow >= config.generatorOffAbove then
    problem('generatorOnBelow', string.format('generatorOnBelow (%s) must be lower than generatorOffAbove (%s)',
      config.generatorOnBelow, config.generatorOffAbove), 'generatorOffAbove')
  end
  if not SIDES[config.generatorSide] then
    problem('generatorSide', string.format('generatorSide must be one of north, south, east, west, top, bottom (it is %s)',
      tostring(config.generatorSide)))
  end
  oneOf(config, 'generatorSignal', {'stop', 'run'})
  boolean(config, 'linkedCard')

  for _, key in ipairs({'barColor', 'barEmptyColor', 'textOverFillColor', 'textOverEmptyColor', 'alertColor',
      'frameColor', 'timeLeftColor'}) do
    color(config, key)
  end
  color(config, 'euTColor', true)

  oneOf(config, 'numberFormat', {'metric', 'scientific'})
  if config.wireless ~= false and not (isNumber(config.wireless) and config.wireless >= 1) then
    problem('wireless', string.format('wireless must be false, or the EU that counts as 100%%, e.g. 1e15 (it is %s)',
      tostring(config.wireless)))
  end
  number(config, 'euTAverage', 1)
  number(config, 'timeLeftAverage', 1)
  number(config, 'timeLeftUpdateOnScreen', 1)
  number(config, 'updateEvery', 0.05)
  boolean(config, 'lowPowerBlink')
  number(config, 'historyMinutes', 1)
  oneOf(config, 'barTextStyle', {'split', 'shadow'})
  for _, key in ipairs({'hudHeight', 'hudLength', 'hudFontSize'}) do
    number(config, key, 1)
  end
  number(config, 'hudBorderBottom', 0)
  number(config, 'hudBorderTop', 0)
  if config.hudEuTFontSize ~= false and not (isNumber(config.hudEuTFontSize) and config.hudEuTFontSize >= 1) then
    problem('hudEuTFontSize', string.format('hudEuTFontSize must be a size of at least 1, or false for the same size as '
      .. 'the stored/max EU (it is %s)', tostring(config.hudEuTFontSize)))
  end
  number(config, 'hudShapeOpacity', 0, 1)
  number(config, 'hudTextOpacity', 0, 1)
  if config.lscAddress ~= false and type(config.lscAddress) ~= 'string' then
    problem('lscAddress', 'lscAddress must be false, or an address in quotes to pick one LSC')
  end
end

-- Checks a table of settings (from parse). Returns the full config with defaults,
-- colour names turned into numbers and the word lists into sets, or nil and a list
-- of problems: {key = the setting, text = what is wrong}.
function options.check(values)
  problems = {}
  local config = {}
  for key, value in pairs(DEFAULTS) do
    config[key] = value
  end
  for key, value in pairs(values) do
    if DEFAULTS[key] == nil then
      problem(key, string.format('%s is not a setting (check the spelling)', tostring(key)))
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

-- Reads and checks config.lua. Returns the config, or nil and a list of problems.
function options.load(path)
  local file = io.open(path, 'r')
  if not file then
    return nil, {{text = 'config.lua is missing; run setup again to get one'}}
  end
  local text = file:read('*a')
  file:close()
  local values, err = options.parse(text)
  if not values then
    return nil, {{text = err}}
  end
  return options.check(values)
end

return options
