-- Installs or updates Power Display in the current folder: the main program (on the
-- computer connected to the LSC), the viewer (on a computer that shows it through a
-- linked card), or the HUD on its own (connected to the LSC). It asks which.
--   wget -f https://raw.githubusercontent.com/Willshaper/GTNH-PowerDisplay/main/setup.lua && setup
-- Optional arguments: setup [branch] [repo raw URL]
local shell = require('shell')
local filesystem = require('filesystem')
local component = require('component')

local args = {...}
local branch = args[1] or 'main'
local repo = args[2] or 'https://raw.githubusercontent.com/Willshaper/GTNH-PowerDisplay/'
local api = 'https://api.github.com/repos/Willshaper/GTNH-PowerDisplay/commits/'
local dir = shell.getWorkingDirectory()

-- What each kind of install gets
local ROLES = {
  {
    program = 'hud',
    name = 'Power Display',
    description = 'Power Display: this computer is connected to the LSC',
    files = {'hud.lua', 'setup.lua', 'uninstall.lua', 'src/format.lua', 'src/lsc.lua', 'src/options.lua',
      'src/glasses.lua', 'src/screen.lua', 'src/generators.lua', 'src/link.lua'},
    config = 'config.lua',
  },
  {
    program = 'viewer',
    name = 'the viewer',
    description = 'Viewer: this computer shows a Power Display computer through a linked card',
    files = {'viewer.lua', 'setup.lua', 'uninstall.lua', 'src/format.lua', 'src/options.lua',
      'src/glasses.lua', 'src/screen.lua', 'src/link.lua'},
    config = 'config.viewer.lua',
  },
  {
    program = 'hudonly',
    name = 'Power Display (HUD only)',
    description = 'HUD only: this computer is connected to the LSC and only draws the glasses HUD',
    files = {'hudonly.lua', 'setup.lua', 'uninstall.lua', 'src/format.lua', 'src/lsc.lua', 'src/options.lua',
      'src/glasses.lua'},
    config = 'config.hudonly.lua',
  },
}

local function path(file)
  return dir .. '/' .. file
end

local function ask(question)
  io.write(question .. ' [y/N] ')
  local answer = io.read()
  return answer ~= nil and answer:lower():sub(1, 1) == 'y'
end

-- Which install: asked every time, only 1, 2 or 3 is accepted
print('What should be installed on this computer?')
for i, role in ipairs(ROLES) do
  print('  ' .. i .. ') ' .. role.description)
end
local role
repeat
  io.write('Enter 1, 2 or 3: ')
  local answer = io.read()
  if answer == nil then
    print('Nothing was installed.')
    return
  end
  role = ROLES[tonumber(answer:match('^%s*(%d)%s*$'))]
until role
print()

-- GitHub caches each file on a branch for up to 5 minutes, so right after an update
-- some downloads could be old and others new. Downloading from the latest commit's id
-- always gives one matching set. Returns nil if it can't be looked up.
local function latestCommit()
  if args[2] then
    return nil -- a custom repo: use the branch as given
  end
  local ok, sha = pcall(function()
    local internet = require('internet')
    local body = ''
    for chunk in internet.request(api .. branch, nil, {['User-Agent'] = 'GTNH-PowerDisplay installer'}) do
      body = body .. chunk
      if #body > 2048 then
        break -- the commit id is at the start of the response
      end
    end
    return body:match('"sha"%s*:%s*"(%x+)"')
  end)
  return ok and sha or nil
end

local ref = latestCommit()
if ref then
  print('Installing ' .. role.name .. ', version ' .. ref:sub(1, 7))
else
  ref = branch
  print('Installing ' .. role.name .. ' from ' .. branch .. ' (may be a few minutes behind the latest version).')
end

-- Files are downloaded to a temporary name and only put in place once every download
-- worked, so a failed download leaves the existing install untouched.
-- (wget leaves an empty file behind when a download fails.)
local function temp(file)
  return path(file .. '.download')
end

local function download(file, target)
  filesystem.remove(temp(target))
  shell.execute(string.format('wget -fq %s%s/%s "%s"', repo, ref, file, temp(target)))
  return filesystem.exists(temp(target)) and filesystem.size(temp(target)) > 0
end

if not filesystem.exists(path('src')) then
  filesystem.makeDirectory(path('src'))
end

-- {file in the repo, where it goes}. The config is handled after the download.
local wanted = {}
for _, file in ipairs(role.files) do
  table.insert(wanted, {file, file})
end
table.insert(wanted, {role.config, 'config.lua'})

local failed = {}
for _, entry in ipairs(wanted) do
  if not download(entry[1], entry[2]) then
    table.insert(failed, entry[1])
  end
end

if #failed > 0 then
  for _, entry in ipairs(wanted) do
    filesystem.remove(temp(entry[2]))
  end
  print()
  print('Could not download: ' .. table.concat(failed, ', '))
  print('Nothing was changed. Check that the computer has an internet card and try again.')
  return
end

for _, entry in ipairs(wanted) do
  if entry[2] ~= 'config.lua' then
    filesystem.remove(path(entry[2]))
    filesystem.rename(temp(entry[2]), path(entry[2]))
  end
end
print('Installed.')

local function readFile(file)
  local handle = io.open(file, 'r')
  if not handle then
    return nil
  end
  local text = handle:read('*a')
  handle:close()
  return text
end

local function writeFile(file, text)
  local handle = io.open(file, 'w')
  handle:write(text)
  handle:close()
end

-- The new config for this install
local template = readFile(temp('config.lua'))
filesystem.remove(temp('config.lua'))
local oldText = readFile(path('config.lua'))

-- config.old.lua, or config.old2.lua, ... if that is taken
local function backupName()
  local name, n = 'config.old.lua', 1
  while filesystem.exists(path(name)) do
    n = n + 1
    name = 'config.old' .. n .. '.lua'
  end
  return name
end

-- Replaces config.lua with `text`, keeping the old one as a backup
local function replaceConfig(text)
  local backup = backupName()
  filesystem.rename(path('config.lua'), path(backup))
  writeFile(path('config.lua'), text)
  filesystem.remove(path('config.default.lua')) -- config.lua has every setting now
  return backup
end

-- Splits a setting line into its name, value text, comment and the comment's column.
-- Returns nil for anything else (comments, blank lines).
local function splitSetting(line)
  local name, rest = line:match('^([%a_][%w_]*)%s*=%s*(.*)$')
  if not name then
    return nil
  end
  local quote, i = nil, 1
  while i <= #rest do
    local c = rest:sub(i, i)
    if quote then
      if c == '\\' then
        i = i + 1
      elseif c == quote then
        quote = nil
      end
    elseif c == '"' or c == "'" then
      quote = c
    elseif rest:sub(i, i + 1) == '--' then
      return name, (rest:sub(1, i - 1):gsub('%s+$', '')), rest:sub(i), #line - #rest + i
    end
    i = i + 1
  end
  return name, (rest:gsub('%s+$', ''))
end

-- A value written back as config.lua text; colours as hex numbers
local function serialize(name, value)
  if type(value) == 'string' then
    return string.format('%q', value)
  elseif type(value) == 'table' then
    local parts = {}
    for i, each in ipairs(value) do
      parts[i] = serialize(nil, each)
    end
    return '{' .. table.concat(parts, ', ') .. '}'
  elseif math.type(value) == 'integer' and name and name:find('Color$') then
    return string.format('0x%06X', value)
  end
  return tostring(value)
end

local function same(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    if #a ~= #b then
      return false
    end
    for i = 1, #a do
      if a[i] ~= b[i] then
        return false
      end
    end
    return true
  end
  return a == b
end

-- The new config with the values from `old` filled in for the settings in `use`.
-- Comments stay where they were, so they stay lined up.
local function fillIn(old, use)
  return (template:gsub('[^\n]+', function(line)
    local name, _, comment, column = splitSetting(line)
    if not name or not use[name] then
      return line
    end
    local assignment = name .. ' = ' .. serialize(name, old[name])
    if not comment then
      return assignment
    end
    return assignment .. string.rep(' ', math.max(1, column - 1 - #assignment)) .. comment
  end))
end

-- Updates an existing config.lua: the new config with the old values filled in
-- (only the settings this install uses). Values the new version doesn't accept go
-- back to their defaults. Asks before replacing, and keeps the old file.
local function updateConfig()
  local options = assert(loadfile(path('src/options.lua')))()
  local defaults = assert(options.parse(template))
  local old, err = options.parse(oldText)
  print()
  if not old then
    print("Your config.lua can't be read, so its values can't be carried over:")
    print('  ' .. err)
    if ask('Replace it with the new config (default values)? The old file is kept as ' .. backupName() .. '.') then
      print('New config.lua written. The old one is ' .. replaceConfig(template) .. '.')
    else
      writeFile(path('config.default.lua'), template)
      print('Kept your config.lua. The new config is in config.default.lua.')
    end
    return
  end

  -- Which of the old values to use, and what isn't carried over
  local inTemplate, use, missing, notUsed, gone = {}, {}, {}, {}, {}
  for line in template:gmatch('[^\n]+') do
    local name = splitSetting(line)
    if name then
      inTemplate[name] = true
      if old[name] == nil then
        table.insert(missing, name)
      elseif not same(old[name], defaults[name]) then
        use[name] = true
      end
    end
  end
  for name in pairs(old) do
    if not inTemplate[name] then
      table.insert(options.isSetting(name) and notUsed or gone, name)
    end
  end

  -- Old values the new version rejects go back to their defaults
  local reset = {}
  for _ = 1, 10 do
    local values = options.parse(fillIn(old, use))
    local _, problems = options.check(values)
    local changed = false
    for _, found in ipairs(problems or {}) do
      for _, name in ipairs({found.key, found.other}) do
        if use[name] then
          use[name] = nil
          table.insert(reset, name)
          changed = true
        end
      end
    end
    if not changed then
      break
    end
  end
  local merged = fillIn(old, use)

  if merged:gsub('\r\n', '\n') == oldText:gsub('\r\n', '\n') then
    print('Your config.lua is up to date.')
    return
  end
  table.sort(missing)
  table.sort(notUsed)
  table.sort(gone)
  table.sort(reset)
  if #missing > 0 then
    print('Not in your config.lua yet, so they get their default values: ' .. table.concat(missing, ', '))
  end
  if #notUsed > 0 then
    print(role.name .. " doesn't use these, so they are left out: " .. table.concat(notUsed, ', '))
  end
  if #gone > 0 then
    print('No longer settings, so they are left out: ' .. table.concat(gone, ', '))
  end
  if #reset > 0 then
    print('Not valid any more, so back to the default: ' .. table.concat(reset, ', '))
  end
  if #missing == 0 and #notUsed == 0 and #gone == 0 and #reset == 0 then
    print('There is a newer config.lua with updated explanations.')
  end
  if ask('Replace it with the new one? Your values are kept, and the old file is kept as ' .. backupName() .. '.') then
    local backup = replaceConfig(merged)
    local kept = {}
    for name in pairs(use) do
      table.insert(kept, name)
    end
    table.sort(kept)
    if #kept > 0 then
      print('New config.lua written, with your values for: ' .. table.concat(kept, ', '))
    else
      print('New config.lua written (you had only default values).')
    end
    print('The old one is ' .. backup .. '.')
  else
    writeFile(path('config.default.lua'), template)
    print('Kept your config.lua. The new config is in config.default.lua.')
  end
end

if oldText then
  updateConfig()
else
  writeFile(path('config.lua'), template)
end

-- Files only the other kinds of install use, from an earlier install on this computer
local mine, leftover = {}, {}
for _, file in ipairs(role.files) do
  mine[file] = true
end
for _, each in ipairs(ROLES) do
  for _, file in ipairs(each.files) do
    if not mine[file] and filesystem.exists(path(file)) then
      mine[file] = true -- listed once
      table.insert(leftover, file)
    end
  end
end
if #leftover > 0 then
  print()
  print('This computer also has files that ' .. role.name .. " doesn't use: " .. table.concat(leftover, ', '))
  if ask('Remove them?') then
    for _, file in ipairs(leftover) do
      filesystem.remove(path(file))
    end
    print('Removed.')
  end
end

-- Auto-start: OpenOS runs every line of /home/.shrc when the shell starts
local shrc = (os.getenv('HOME') or '/home') .. '/.shrc'
-- Returns the auto-start line for any of the programs, and which program it starts
local function autostartLine()
  local file = io.open(shrc, 'r')
  if not file then
    return nil
  end
  local content = file:read('*a')
  file:close()
  for line in content:gmatch('[^\n]+') do
    local program = line:match('&&%s*(%w+)%s*$')
    for _, each in ipairs(ROLES) do
      if program == each.program then
        return line, program
      end
    end
  end
  return nil
end

print()
local existing, starts = autostartLine()
if starts == role.program then
  print('Auto-start is already on (' .. shrc .. ').')
elseif existing then
  print('Auto-start in ' .. shrc .. ' starts ' .. starts .. ': ' .. existing)
  print('Edit that line to start ' .. role.program .. ' instead (edit ' .. shrc .. ').')
elseif ask('Start ' .. role.name .. ' automatically when the computer boots?') then
  local file = io.open(shrc, 'a')
  file:write(string.format('cd "%s" && %s\n', dir, role.program))
  file:close()
  print('Auto-start on. Delete the ' .. role.program .. ' line in ' .. shrc .. ' to turn it off.')
end

-- The computer's redstone card (a Redstone I/O block, used for generator control,
-- is also a redstone component but doesn't sit in a slot)
local function redstoneCard()
  for address in component.list('redstone') do
    local ok, slot = pcall(component.slot, address)
    if ok and type(slot) == 'number' and slot >= 0 then
      return component.proxy(address)
    end
  end
end

-- Wake on redstone: a rising redstone signal turns the computer on (a running
-- computer ignores it), so a slow redstone clock restarts it after a power loss
local redstone = redstoneCard()
if redstone then
  if redstone.getWakeThreshold() > 0 then
    print('Wake on redstone is already on (threshold ' .. redstone.getWakeThreshold() .. ').')
  elseif ask('Turn the computer on when it receives a redstone signal?') then
    redstone.setWakeThreshold(1)
    print('Wake on redstone on. A redstone pulse now starts the computer if it is off.')
  end
end

print()
print('Edit settings with: edit config.lua')
print('Start with: ' .. role.program .. '    (stop with C)')
