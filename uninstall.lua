-- Removes Power Display from the current folder, and its auto-start line.
local shell = require('shell')
local filesystem = require('filesystem')
local component = require('component')

local dir = shell.getWorkingDirectory()
local files = {
  'hud.lua',
  'setup.lua',
  'uninstall.lua',
  'config.default.lua',
  'src/format.lua',
  'src/lsc.lua',
  'src/options.lua',
  'src/glasses.lua',
  'src/screen.lua',
  'src/generators.lua',
  -- from the original PowerDisplay
  'graphics.lua',
  'events.lua',
}

local function ask(question)
  io.write(question .. ' [y/N] ')
  local answer = io.read()
  return answer ~= nil and answer:lower():sub(1, 1) == 'y'
end

for _, file in ipairs(files) do
  local path = dir .. '/' .. file
  if filesystem.exists(path) then
    filesystem.remove(path)
    print('Removed ' .. file)
  end
end
local src = dir .. '/src'
if filesystem.isDirectory(src) and filesystem.list(src)() == nil then
  filesystem.remove(src)
end

if filesystem.exists(dir .. '/config.lua') and ask('Remove config.lua (your settings) too?') then
  filesystem.remove(dir .. '/config.lua')
  print('Removed config.lua')
end

-- Auto-start line in .shrc
local shrc = (os.getenv('HOME') or '/home') .. '/.shrc'
local file = io.open(shrc, 'r')
if file then
  local kept, removed = {}, false
  for line in file:lines() do
    if line:find('&& hud', 1, true) then
      removed = true
    else
      table.insert(kept, line)
    end
  end
  file:close()
  if removed then
    file = io.open(shrc, 'w')
    for _, line in ipairs(kept) do
      file:write(line .. '\n')
    end
    file:close()
    print('Removed auto-start from ' .. shrc)
  end
end

-- Other programs may rely on wake on redstone, so only turn it off when asked
if component.isAvailable('redstone') and component.redstone.getWakeThreshold() > 0
    and ask('Turn off wake on redstone for this computer?') then
  component.redstone.setWakeThreshold(0)
  print('Wake on redstone off.')
end
