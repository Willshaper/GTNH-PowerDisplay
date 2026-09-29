-- Installs or updates Power Display in the current folder.
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

local scripts = {
  'hud.lua',
  'setup.lua',
  'uninstall.lua',
  'src/format.lua',
  'src/lsc.lua',
  'src/options.lua',
  'src/glasses.lua',
  'src/screen.lua',
  'src/generators.lua',
}

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
  print('Installing version ' .. ref:sub(1, 7))
else
  ref = branch
  print('Downloading from ' .. branch .. ' (may be a few minutes behind the latest version).')
end

local function path(file)
  return dir .. '/' .. file
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
for _, file in ipairs(scripts) do
  table.insert(wanted, {file, file})
end
-- config.lua is yours: it is only downloaded when missing. Otherwise the current
-- defaults go to config.default.lua, to see what settings exist.
if filesystem.exists(path('config.lua')) then
  table.insert(wanted, {'config.lua', 'config.default.lua'})
else
  table.insert(wanted, {'config.lua', 'config.lua'})
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

for _, entry in ipairs(wanted) do
  filesystem.remove(path(entry[2]))
  filesystem.rename(temp(entry[2]), path(entry[2]))
end
print('Installed.')
if filesystem.exists(path('config.default.lua')) then
  print('Your config.lua was kept. New settings are listed in config.default.lua.')
end

local function ask(question)
  io.write(question .. ' [y/N] ')
  local answer = io.read()
  return answer ~= nil and answer:lower():sub(1, 1) == 'y'
end

-- Auto-start: OpenOS runs every line of /home/.shrc when the shell starts
local shrc = (os.getenv('HOME') or '/home') .. '/.shrc'
local function autostartEnabled()
  local file = io.open(shrc, 'r')
  if not file then
    return false
  end
  local content = file:read('*a')
  file:close()
  return content:find('&& hud', 1, true) ~= nil
end

print()
if autostartEnabled() then
  print('Auto-start is already on (' .. shrc .. ').')
elseif ask('Start Power Display automatically when the computer boots?') then
  local file = io.open(shrc, 'a')
  file:write(string.format('cd "%s" && hud\n', dir))
  file:close()
  print('Auto-start on. Delete the hud line in ' .. shrc .. ' to turn it off.')
end

-- Wake on redstone: a rising redstone signal turns the computer on (a running
-- computer ignores it), so a slow redstone clock restarts it after a power loss
if component.isAvailable('redstone') then
  local redstone = component.redstone
  if redstone.getWakeThreshold() > 0 then
    print('Wake on redstone is already on (threshold ' .. redstone.getWakeThreshold() .. ').')
  elseif ask('Turn the computer on when it receives a redstone signal?') then
    redstone.setWakeThreshold(1)
    print('Wake on redstone on. A redstone pulse now starts the computer if it is off.')
  end
end

print()
print('Edit settings with: edit config.lua')
print('Start with: hud    (stop with C)')
