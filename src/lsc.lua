-- Reads the Lapotronic Supercapacitor through an adapter (component gt_machine).
--
-- getSensorInformation() returns one line per value. Newer GregTech sends them as
-- encoded translation keys with the values after two backslashes, e.g.
--   kekztech.infodata.lapotronic_super_capacitor.avg_eu_in.sec\\996,147\\5
--   kekztech.infodata.multi.maintenance_status.ok
-- Older versions send translated English text instead. Lines are matched by name,
-- never by position or length, so reordered or added lines don't break anything.
local component = require('component')

local lsc = {}

local SEPARATOR = '\\\\' -- two literal backslashes

-- Every key this module reads, with the English text older versions used for it
local KEYS = {
  stored = {'eu_stored', 'EU Stored'},
  capacity = {'total_capacity', 'Total Capacity'},
  passiveLoss = {'passive_loss', 'Passive Loss'},
  avgIn = {'avg_eu_in.sec', 'Avg EU IN'},
  avgOut = {'avg_eu_out.sec', 'Avg EU OUT'},
  avgIn5m = {'avg_eu_in.min5'},
  avgOut5m = {'avg_eu_out.min5'},
  avgIn1h = {'avg_eu_in.hour1'},
  avgOut1h = {'avg_eu_out.hour1'},
  wirelessEU = {'wireless_eu', 'Total wireless EU'},
}

-- Splits "key\\a\\b" into "key", {"a", "b"}
local function split(line)
  local parts = {}
  local start = 1
  while true do
    local from, to = line:find(SEPARATOR, start, true)
    if not from then
      table.insert(parts, line:sub(start))
      break
    end
    table.insert(parts, line:sub(start, from - 1))
    start = to + 1
  end
  return table.remove(parts, 1), parts
end

-- "4,424,885,923" or "§c1.234.567" -> 4424885923. Values in standard form
-- ("4.42x10^9") are skipped: the plain number is always on an earlier line.
local function wholeNumber(text)
  if text == nil then
    return nil
  end
  text = text:gsub('\194\167.', '') -- Minecraft formatting codes (§c, §r, ...)
  if text:find('x10', 1, true) or text:find('%d[eE][%+%-]?%d') then
    return nil
  end
  -- The first number only: older versions add text such as "(last 5 seconds)" after it
  local sign, number = text:match("(%-?)(%d[%d,%.' ]*)")
  if not number then
    return nil
  end
  local value = tonumber((number:gsub('%D', '')))
  return sign == '-' and -value or value
end

-- Parses sensor lines into a table with the fields named in KEYS, plus
-- maintenanceOk. Missing values stay nil.
function lsc.parse(lines)
  local info = {}
  for _, line in ipairs(lines or {}) do
    local key, args = split(line)
    if key:find('maintenance_status', 1, true) then
      info.maintenanceOk = not key:find('maintenance_status.bad', 1, true)
    elseif key:find('Maintenance', 1, true) or key:find('Problems', 1, true) then
      -- Older GregTech: "Maintenance Status: Working perfectly" / "Has Problems"
      info.maintenanceOk = key:find('Problem', 1, true) == nil
    end
    for field, names in pairs(KEYS) do
      if info[field] == nil then
        for _, name in ipairs(names) do
          if key:find(name, 1, true) then
            -- New format: the value is the first argument. Old format: after the key.
            info[field] = wholeNumber(args[1] or key:sub(key:find(name, 1, true) + #name))
            break
          end
        end
      end
    end
  end
  return info
end

-- The LSC to read: config.lscAddress if set, otherwise the only gt_machine, or the
-- first one whose sensor lines look like an LSC. Returns a proxy, or nil and how many
-- GregTech machines the computer can see.
function lsc.find(address)
  if address then
    local ok, full = pcall(component.get, address)
    if ok and full then
      return component.proxy(full)
    end
    return nil, 0
  end
  local machines = {}
  for addr in component.list('gt_machine') do
    table.insert(machines, addr)
  end
  if #machines == 1 then
    return component.proxy(machines[1])
  end
  for _, addr in ipairs(machines) do
    local proxy = component.proxy(addr)
    local ok, lines = pcall(proxy.getSensorInformation)
    if ok and type(lines) == 'table' then
      for _, line in ipairs(lines) do
        if line:find('apotronic', 1, true) then
          return proxy
        end
      end
    end
  end
  return nil, #machines
end

-- Reads everything once. Returns a table:
--   stored, capacity, percent (0..1), maintenanceOk, passiveLoss,
--   avgIn, avgOut (GT's ~5 s averages), avgIn5m, avgOut5m, avgIn1h, avgOut1h, wirelessEU
-- In wireless mode stored is the wireless network EU and capacity is config.wirelessMax.
function lsc.read(machine, config)
  local lines = machine.getSensorInformation()
  local data = lsc.parse(lines)
  if config.wirelessMode then
    data.stored = data.wirelessEU or 0
    data.capacity = config.wirelessMax
  else
    -- The component getters are exact; the sensor lines are a fallback
    local okStored, stored = pcall(machine.getEUStored)
    local okMax, capacity = pcall(machine.getEUMaxStored)
    -- The getters stop at Long.MAX (about 9.2e18 EU); the sensor lines don't
    local LONG_MAX = 9.2e18
    stored = okStored and tonumber(stored)
    capacity = okMax and tonumber(capacity)
    if not stored or (stored >= LONG_MAX and data.stored) then
      stored = data.stored
    end
    if not capacity or (capacity >= LONG_MAX and data.capacity) then
      capacity = data.capacity
    end
    data.stored, data.capacity = stored or 0, capacity or 0
  end
  if data.capacity and data.capacity > 0 then
    data.percent = math.max(0, math.min(data.stored / data.capacity, 1))
  else
    data.percent = 0
  end
  if data.maintenanceOk == nil then
    data.maintenanceOk = true -- unknown: don't raise a false alarm
  end
  return data
end

-- Net EU/t averaged over the last `seconds`, from the change in stored EU. This
-- includes passive loss, so it matches what the bar actually does.
-- computer.uptime() counts world ticks, so server lag doesn't skew it.
function lsc.newAverage(seconds)
  local samples = {}
  local average = {}

  function average.add(time, stored)
    table.insert(samples, {time = time, stored = stored})
    -- Keep one sample at or before the start of the window as the reference point
    while #samples > 2 and samples[2].time <= time - seconds do
      table.remove(samples, 1)
    end
  end

  -- EU per tick, or nil until there are two samples
  function average.value()
    if #samples < 2 then
      return nil
    end
    local first, last = samples[1], samples[#samples]
    local ticks = (last.time - first.time) * 20
    if ticks <= 0 then
      return nil
    end
    return (last.stored - first.stored) / ticks
  end

  function average.reset()
    samples = {}
  end

  return average
end

-- Seconds until full (rate > 0) or empty (rate < 0). Returns seconds, "full" or "empty".
function lsc.timeTo(data, rate)
  if rate == nil or math.abs(rate) < 0.5 then
    return nil
  end
  if rate > 0 then
    return math.max(0, data.capacity - data.stored) / rate / 20, 'full'
  end
  return data.stored / -rate / 20, 'empty'
end

return lsc
