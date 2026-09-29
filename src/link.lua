-- Sends the display to other computers through linked cards, and reads it there
-- (see viewer.lua). A linked card only talks to its paired card, so every linked
-- card in this computer gets a copy: one pair per viewer.
local component = require('component')
local serialization = require('serialization')

local link = {}

local cards = {}

-- What the viewer needs from the LSC computer. Everything else (colours, what to
-- show) comes from the viewer's own config.lua.
local DATA_FIELDS = {'stored', 'capacity', 'percent', 'maintenanceOk', 'passiveLoss',
  'avgIn', 'avgOut', 'avgIn5m', 'avgOut5m', 'avgIn1h', 'avgOut1h'}
local VIEW_FIELDS = {'eut', 'direction', 'timeTo', 'timeToWhat', 'timeRate',
  'generators', 'generatorProblem', 'generatorHint'}
local CONFIG_FIELDS = {'wirelessMode', 'generatorControl', 'generatorOnBelow', 'generatorOffAbove',
  'generatorSide', 'sleep'}

local function pick(from, fields)
  local out = {}
  for _, field in ipairs(fields) do
    out[field] = from[field]
  end
  return out
end

-- Returns nil, or why it can't send
function link.start(config)
  cards = {}
  if not config.linkedCard then
    return nil
  end
  for address in component.list('tunnel') do
    table.insert(cards, component.proxy(address))
  end
  if #cards == 0 then
    return 'none found'
  end
  return nil
end

function link.active()
  return #cards > 0
end

local function send(packet)
  local message = serialization.serialize(packet)
  for _, card in ipairs(cards) do
    pcall(card.send, message)
  end
end

-- One update: the LSC's values, what was worked out from them, and the settings
-- the viewer shows (generator set points, wireless mode, update interval)
function link.send(data, view, config)
  if #cards > 0 then
    send({data = pick(data, DATA_FIELDS), view = pick(view, VIEW_FIELDS), config = pick(config, CONFIG_FIELDS)})
  end
end

-- No values right now (waiting for the LSC, or an error): the viewer shows the text
function link.sendStatus(title, text)
  if #cards > 0 then
    send({status = title, text = text})
  end
end

-- For the viewer: turns a modem_message event from a linked card into a packet,
-- or returns nil for anything else
function link.decode(localAddress, payload)
  if type(localAddress) ~= 'string' or component.type(localAddress) ~= 'tunnel' or type(payload) ~= 'string' then
    return nil
  end
  local ok, packet = pcall(serialization.unserialize, payload)
  if not ok or type(packet) ~= 'table' then
    return nil
  end
  if type(packet.status) == 'string' or (type(packet.data) == 'table' and type(packet.view) == 'table'
      and type(packet.config) == 'table' and type(packet.data.percent) == 'number') then
    return packet
  end
  return nil
end

return link
