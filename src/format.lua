-- Number and time formatting shared by the HUD and the screen
local format = {}

local UNITS = {'', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'}

-- 4424885923 -> "4.4G" (decimals = 1). Creds: Vlamonster
function format.metric(value, decimals)
  decimals = decimals or 1
  for i = 1, #UNITS do
    if math.abs(value) < 1000 or i == #UNITS then
      if i == 1 then
        return string.format('%d', math.floor(value + 0.5))
      end
      return string.format('%.' .. decimals .. 'f%s', value, UNITS[i])
    end
    value = value / 1000
  end
end

-- 4424885923 -> "4.42e9"
function format.scientific(value)
  if math.abs(value) < 1000 then
    return string.format('%d', math.floor(value + 0.5))
  end
  local text = string.format('%.2e', value) -- "4.42e+09"
  return (text:gsub('e%+?(%-?)0*(%d)', 'e%1%2'))
end

function format.eu(value, metric, decimals)
  if value == nil then
    return '-'
  end
  if metric then
    return format.metric(value, decimals)
  end
  return format.scientific(value)
end

-- Signed rate: "+728.8K", "-53", "0"
function format.rate(value, metric, decimals)
  if value == nil then
    return '-'
  end
  -- Under 1 EU/t counts as steady (no arrows), so it shows as 0 too
  if math.abs(value) < 1 then
    return '0'
  end
  return (value > 0 and '+' or '-') .. format.eu(math.abs(value), metric, decimals)
end

-- Seconds -> "45s", "5m 26s", "2h 03m", "3d 04h", "12y"
function format.duration(seconds)
  if seconds == nil or seconds ~= seconds then
    return '-'
  end
  if seconds == math.huge then
    return 'never'
  end
  seconds = math.floor(seconds + 0.5)
  if seconds < 60 then
    return seconds .. 's'
  elseif seconds < 3600 then
    return string.format('%dm %02ds', seconds // 60, seconds % 60)
  elseif seconds < 86400 then
    return string.format('%dh %02dm', seconds // 3600, seconds % 3600 // 60)
  elseif seconds < 31536000 then
    return string.format('%dd %02dh', seconds // 86400, seconds % 86400 // 3600)
  end
  return string.format('%dy', seconds // 31536000)
end

-- Animated direction arrows: ">", ">>", ">>>", ">", ... while charging (direction 1),
-- "<" ... while discharging (-1), nothing when steady (0)
local ARROW_STEP = 0.4 -- seconds per step

function format.arrows(direction, now)
  if direction == nil or direction == 0 then
    return ''
  end
  local count = math.floor(now / ARROW_STEP) % 3 + 1
  return string.rep(direction > 0 and '>' or '<', count)
end

function format.percent(fraction)
  if fraction > 0.999 then
    return '100%'
  end
  return string.format('%.1f%%', fraction * 100)
end

return format
