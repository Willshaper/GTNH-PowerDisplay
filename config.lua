-- Power Display settings. Restart hud after changing anything.
-- One setting per line. A setting you leave out uses its default.

-- What the HUD on your AR glasses shows. Use any of these words, in any order:
--   Percent     = charge %, left of the bar
--   Stored      = EU stored, at the start of the bar
--   EUt         = net EU/t, in the middle of the bar
--   Arrows      = > >> >>> next to the EU/t while charging, <<< while draining
--   Max         = capacity, at the end of the bar
--   Maintenance = "Has Problems!" above the bar when the LSC needs maintenance
--   TimeLeft    = "Full: 52min" / "Empty: 2h 05min", past the end of the bar
-- "" = no HUD.
hud = "Percent Stored EUt Arrows Max Maintenance"

-- What this computer's screen shows: the same words, and also
--   Averages    = GregTech's own In/Out/Net over 5 s, 5 min and 1 hour
--   PassiveLoss = the LSC's passive loss
--   History     = a graph of the charge over the last historyMinutes
-- "" = no screen monitor.
screen = "Percent Stored EUt Arrows Max Maintenance TimeLeft Averages PassiveLoss History"

hudCorner = "left"         -- bottom corner for the HUD: "left" or "right" (mirrored)
lowPower = 20              -- below this %, the bar turns red and "Low power!" shows (false = off)

-- Your Minecraft window, so the HUD lands in the corner
windowSize = {1920, 1080}  -- your monitor's resolution (the game window's size when not fullscreen)
fullscreen = true
guiScale = 3               -- Video Settings > GUI Scale

-- Generators (optional): a Redstone I/O block switches them on and off
generatorControl = false   -- the Redstone I/O block's address, e.g. "1a2b3c4d" (false = off).
                           -- Set it to "?" and start hud to see the blocks it can find.
generatorOnBelow = 20      -- start the generators below this %
generatorOffAbove = 90     -- stop them again above this %
generatorSide = "north"    -- side of the block the signal leaves: north, south, east, west, top or bottom
generatorSignal = "stop"   -- "stop" = a signal stops them, "run" = a signal runs them

-- Another computer (optional): it shows this display, through a pair of linked cards
linkedCard = false         -- true = send to the viewer on the other computer

-- Colours: a name from the list at the end of this file in quotes, or a number like 0xFF8800
barColor = "electricBlue"         -- the filled part of the bar, and the percentage
barEmptyColor = "darkSlateBlue"   -- the empty part of the bar
textOverFillColor = "black"       -- text over the filled part
textOverEmptyColor = "offWhite"   -- text over the empty part
alertColor = "red"                -- "Low power!", "Has Problems!" and the low power bar
frameColor = "darkGray"           -- the frame around the bar
timeLeftColor = "offWhite"        -- the time left next to the HUD bar
euTColor = false                  -- one fixed colour for the EU/t and arrows (false = like other text)

-- Advanced
numberFormat = "metric"    -- "metric" = 4.4G, "scientific" = 4.42e9
wireless = false           -- show the wireless network's EU instead: the amount that counts as 100%, e.g. 1e15
euTAverage = 5             -- the EU/t is the average over this many seconds
timeLeftAverage = 30       -- the time left is worked out from the average over this many seconds
timeLeftUpdateOnScreen = 5 -- the screen's time left changes every this many seconds (the HUD's with the EU/t)
updateEvery = 1            -- seconds between updates
lowPowerBlink = true       -- the low power bar blinks
historyMinutes = 30        -- minutes the screen's History graph covers
barTextStyle = "split"     -- HUD text on the bar: "split" = dark over the fill, light over the rest,
                           -- letter by letter; "shadow" = light with a dark shadow (for resource-pack fonts)
hudHeight = 12             -- HUD size, in GUI pixels
hudLength = 168
hudBorderBottom = 2
hudBorderTop = 2
hudFontSize = 3            -- the percentage, alerts and time left
hudEuTFontSize = false     -- the EU/t and arrows (false = the size of the stored/max EU; 3 = as big as the %)
hudShapeOpacity = 0.9      -- 0 to 1
hudTextOpacity = 1.0       -- 0 to 1
lscAddress = false         -- with several GregTech machines connected: the LSC's address, e.g. "e190015a"

-- Colour names: red, orange, yellow, green, blue, indigo, violet, maroon, golden, lime,
-- olive, cyan, magenta, black, white, gray, lightGray, offWhite, darkGray, electricBlue,
-- dodgerBlue, steelBlue, midnightBlue, darkBlue, darkSlateGreen, darkSlateBlue
