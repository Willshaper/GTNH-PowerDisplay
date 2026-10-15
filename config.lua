-- Power Display settings. Press S in hud to edit them: the changes are used
-- as soon as you save (Ctrl+S) and close the editor (Ctrl+W).
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

-- Bottom corner for the HUD: "left" or "right" (mirrored)
hudCorner = "left"
-- Below this %, the bar turns red and "Low power!" shows (false = off)
lowPower = 20

-- Your Minecraft window, so the HUD lands in the corner: your monitor's
-- resolution (the game window's size when not fullscreen)
windowSize = {1920, 1080}
fullscreen = true
guiScale = 3               -- Video Settings > GUI Scale

-- Generators (optional): a Redstone I/O block switches them on and off.
-- generatorControl is the block's address, e.g. "1a2b3c4d" (false = off).
-- Set it to "?" and start hud to see the blocks it can find.
generatorControl = false
generatorOnBelow = 20      -- start the generators below this %
generatorOffAbove = 90     -- stop them again above this %
-- Side of the block the signal leaves: north, south, east, west, top, bottom
generatorSide = "north"
-- "stop" = a signal stops them, "run" = a signal runs them
generatorSignal = "stop"

-- Another computer (optional) can show this display, through a pair of
-- linked cards: true = send to the viewer on the other computer
linkedCard = false

-- Colours: a name in quotes from the list at the end of this file, or a
-- number like 0xFF8800
barColor = "electricBlue"         -- the filled part of the bar, and the %
barEmptyColor = "darkSlateBlue"   -- the empty part of the bar
textOverFillColor = "black"       -- text over the filled part
textOverEmptyColor = "offWhite"   -- text over the empty part
alertColor = "red"                -- "Low power!", "Has Problems!", low bar
frameColor = "darkGray"           -- the frame around the bar
timeLeftColor = "offWhite"        -- the time left next to the HUD bar
-- One fixed colour for the EU/t and arrows (false = like the other text)
euTColor = false

-- Advanced
numberFormat = "metric"    -- "metric" = 4.4G, "scientific" = 4.42e9
-- Show the wireless network's EU instead: the amount that counts as 100%,
-- e.g. 1e15 (false = the LSC's own EU)
wireless = false
euTAverage = 5             -- the EU/t is the average over this many seconds
-- The time left is worked out from the average over this many seconds
timeLeftAverage = 30
-- The screen's time left changes every this many seconds (the HUD's
-- together with the EU/t)
timeLeftUpdateOnScreen = 5
updateEvery = 2            -- seconds between updates
-- The low power HUD bar fades to alertColor and back (false = steady red)
lowPowerFade = true
historyMinutes = 30        -- minutes the screen's History graph covers
-- Text on the HUD bar: "shadow" = light with a dark shadow; "split" = dark
-- over the fill, light over the rest, letter by letter (gaps are possible
-- with resource-pack fonts)
barTextStyle = "shadow"
hudHeight = 12             -- HUD size, in GUI pixels
hudLength = 168
hudBorderBottom = 2
hudBorderTop = 2
hudPercentFontSize = 3     -- the percentage and alerts (3 = normal text size)
hudValueFontSize = 2.3     -- stored and max EU on the bar
hudEuTFontSize = 2.3       -- the EU/t and arrows
hudTimeLeftFontSize = 3    -- the time left past the bar
hudShapeOpacity = 0.9      -- 0 to 1
hudTextOpacity = 1.0       -- 0 to 1
-- With several GregTech machines connected: the LSC's address, e.g.
-- "e190015a" (false = find it automatically)
lscAddress = false

-- Colour names: red, orange, yellow, green, blue, indigo, violet, maroon,
-- golden, lime, olive, cyan, magenta, black, white, gray, lightGray,
-- offWhite, darkGray, electricBlue, dodgerBlue, steelBlue, midnightBlue,
-- darkBlue, darkSlateGreen, darkSlateBlue
