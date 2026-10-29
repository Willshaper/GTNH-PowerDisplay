-- Checks GitHub for a newer version of Power Display and installs it with setup
-- (which keeps your config.lua values). Run it as: update
-- from the folder Power Display is installed in, while Power Display is stopped.
local component = require('component')
local filesystem = require('filesystem')
local shell = require('shell')

local API = 'https://api.github.com/repos/Willshaper/GTNH-PowerDisplay/commits/main'
local RAW = 'https://raw.githubusercontent.com/Willshaper/GTNH-PowerDisplay/'
local SETUP_TEMP = '/tmp/powerdisplay-setup.lua'

-- The folder this file is in: the install to update. OpenOS puts the running
-- program's path in the "_" environment variable.
local function installFolder()
  local program = os.getenv('_')
  local folder = program and filesystem.path(program) or shell.getWorkingDirectory()
  if #folder > 1 then
    folder = folder:gsub('/$', '')
  end
  return folder
end

local function ask(question)
  io.write(question .. ' [y/N] ')
  local answer = io.read()
  return answer ~= nil and answer:lower():sub(1, 1) == 'y'
end

-- The installed version from .version (written by setup): commit id and date
local function installedVersion(folder)
  local file = io.open(folder .. '/.version', 'r')
  if not file then
    return nil
  end
  local sha = file:read('*l')
  local date = file:read('*l')
  file:close()
  if not sha or not sha:match('^%x+$') then
    return nil
  end
  return sha, date
end

-- "Discord notifications" from a JSON-escaped commit message
local function title(message)
  message = (message:match('^(.-)\\n') or message):gsub('\\"', '"'):gsub('\\\\', '\\')
  if #message > 60 then
    message = message:sub(1, 57) .. '...'
  end
  return message
end

-- The newest commit on GitHub: id, date and title, or nil and why not
local function latestVersion()
  if not component.isAvailable('internet') then
    return nil, 'this computer has no internet card'
  end
  local ok, body = pcall(function()
    local text = ''
    for chunk in require('internet').request(API, nil, {['User-Agent'] = 'GTNH-PowerDisplay updater'}) do
      text = text .. chunk
      if #text > 8192 then
        break -- id, date and message are at the start of the answer
      end
    end
    return text
  end)
  if not ok then
    return nil, tostring(body)
  end
  local sha = body:match('"sha"%s*:%s*"(%x+)"')
  if not sha then
    return nil, "GitHub's answer had no version in it (too many requests?)"
  end
  local date = body:match('"date"%s*:%s*"(%d%d%d%d%-%d%d%-%d%d)') -- the author date comes first
  local message = body:match('"message"%s*:%s*"(.-)",') or ''
  return {sha = sha, date = date, title = title(message)}
end

-- "149cac0 (2026-10-21)"
local function describe(sha, date)
  return sha:sub(1, 7) .. (date and date ~= '' and (' (' .. date:sub(1, 10) .. ')') or '')
end

local folder = installFolder()
local installedSha, installedDate = installedVersion(folder)
print('Power Display in ' .. folder)
print('Installed: ' .. (installedSha and describe(installedSha, installedDate) or 'unknown'))

local latest, problem = latestVersion()
if not latest then
  print('Could not check for a new version: ' .. problem)
  if not ask('Run setup anyway (downloads the newest files)?') then
    print('Nothing was changed.')
    return
  end
else
  print('Latest:    ' .. describe(latest.sha, latest.date) .. (latest.title ~= '' and (' ' .. latest.title) or ''))
  if installedSha == latest.sha then
    print('You have the latest version.')
    if not ask('Reinstall it anyway?') then
      print('Nothing was changed.')
      return
    end
  elseif not ask('Update now?') then
    print('Nothing was changed.')
    return
  end
end

-- setup from that version, so it matches the files it downloads
filesystem.remove(SETUP_TEMP)
shell.execute(string.format('wget -fq %s%s/setup.lua %s', RAW, latest and latest.sha or 'main', SETUP_TEMP))
if not filesystem.exists(SETUP_TEMP) or filesystem.size(SETUP_TEMP) == 0 then
  print('Could not download setup; nothing was changed.')
  return
end
shell.setWorkingDirectory(folder)
if latest then
  shell.execute(SETUP_TEMP, nil, latest.sha, latest.date or '')
else
  shell.execute(SETUP_TEMP)
end
