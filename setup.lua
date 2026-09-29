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

-- An existing config.lua can be swapped for a fresh one with only the settings this
-- install uses, at their defaults. The old one is kept as config.old.lua (or
-- config.old2.lua, ... if that is taken).
local backup
if filesystem.exists(path('config.lua')) then
  print('This computer already has a config.lua.')
  if ask('Replace it with a fresh config for ' .. role.name .. ' (only its settings, default values)?') then
    backup = 'config.old.lua'
    local n = 1
    while filesystem.exists(path(backup)) do
      n = n + 1
      backup = 'config.old' .. n .. '.lua'
    end
  end
  print()
end

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
  shell.execute(string.format('wget -fq %s%s/%s %s', repo, ref, file, temp(target)))
  return filesystem.exists(temp(target)) and filesystem.size(temp(target)) > 0
end

if not filesystem.exists(path('src')) then
  filesystem.makeDirectory(path('src'))
end

-- {file in the repo, where it goes}
local wanted = {}
for _, file in ipairs(role.files) do
  table.insert(wanted, {file, file})
end
-- A kept config.lua isn't touched; the current defaults then go to config.default.lua,
-- to see what settings exist
local keepConfig = filesystem.exists(path('config.lua')) and not backup
if keepConfig then
  table.insert(wanted, {role.config, 'config.default.lua'})
else
  table.insert(wanted, {role.config, 'config.lua'})
end

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

if backup then
  filesystem.rename(path('config.lua'), path(backup))
  filesystem.remove(path('config.default.lua')) -- the fresh config.lua has the defaults now
end
for _, entry in ipairs(wanted) do
  filesystem.remove(path(entry[2]))
  filesystem.rename(temp(entry[2]), path(entry[2]))
end
print('Installed.')
if backup then
  print('config.lua is now a fresh config for ' .. role.name .. '. The old one is ' .. backup .. '.')
elseif keepConfig then
  print('Your config.lua was kept. The settings ' .. role.name .. ' uses are listed in config.default.lua.')
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
