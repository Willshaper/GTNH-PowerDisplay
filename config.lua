-- Power Display settings. Press S in hud to edit them: the changes are used
-- as soon as you save (Ctrl+S) and close the editor (Ctrl+W).
-- One setting per line. A setting you leave out uses its default.

-- WHAT TO SHOW --------------------------------------------------------------

-- The HUD on your AR glasses. Use any of these words, in any order:
--   Percent     = charge %, left of the bar
--   Stored      = EU stored, at the start of the bar
--   EUt         = net EU/t, in the middle of the bar
--   Arrows      = > >> >>> next to the EU/t while charging, <<< while draining
--   Max         = capacity, at the end of the bar
--   Maintenance = "Has Problems!" above the bar when the LSC needs maintenance
--   TimeLeft    = "Full: 52min" / "Empty: 2h 05min", past the end of the bar
-- "" = no HUD.
hud = "Percent Stored EUt Arrows Max Maintenance"

-- This computer's screen: the same words, and also
--   Averages    = GregTech's own In/Out/Net over 5 s, 5 min and 1 hour
--   PassiveLoss = the LSC's passive loss
--   History     = a graph of the charge over the last historyMinutes
-- "" = no screen monitor.
screen = "Percent Stored EUt Arrows Max Maintenance TimeLeft Averages PassiveLoss History"

-- Bottom corner for the HUD: "left" or "right" (mirrored)
hudCorner = "left"

-- Below this %, the bar turns red and "Low power!" shows (false = off)
lowPower = 20

-- MINECRAFT WINDOW (so the HUD lands in the corner) -------------------------

-- Your monitor's resolution (the game window's size when not fullscreen),
-- whether the game runs fullscreen, and Video Settings > GUI Scale
windowSize = {1920, 1080}
fullscreen = true
guiScale = 3

-- GENERATORS (optional): a Redstone I/O block switches them -----------------

-- The Redstone I/O block's address, e.g. "1a2b3c4d" (false = off).
-- Set it to "?" and start hud to see the blocks it can find.
generatorControl = false

generatorOnBelow = 20      -- start the generators below this %
generatorOffAbove = 90     -- stop them again above this %

-- Side of the block the signal leaves: north, south, east, west, top, bottom
generatorSide = "north"

-- "stop" = a signal stops them, "run" = a signal runs them
generatorSignal = "stop"

-- ANOTHER COMPUTER (optional) -----------------------------------------------

-- true = send this display through a pair of linked cards to the viewer
-- on another computer
linkedCard = false

-- DISCORD (optional): messages in a Discord channel -------------------------

-- Needs an internet card in this computer. In Discord: channel settings >
-- Integrations > Webhooks > New Webhook > Copy Webhook URL.

-- The webhook URL ("" = off). Anyone who can open this computer can read it.
discordWebhook = ""

-- Shown in each message, e.g. "Main base", to tell computers apart
discordName = ""

-- Who is pinged on red messages: a user ID like "<@123456789>" or a role
-- like "<@&123456789>", not a name ("" = nobody). In Discord: Settings >
-- Advanced > Developer Mode, then right-click the user > Copy User ID.
discordMention = ""

-- What is sent (true = on, false = off)
discordLowPower = true          -- below lowPower %, and back to normal
discordEmptySoon = true         -- empty within discordEmptySoonMinutes
discordMaintenance = true       -- the LSC needs maintenance, and fixed
discordLscLost = true           -- the LSC can't be read for 2 minutes
discordGenerators = false       -- generators started and stopped
discordStarted = true           -- Power Display started

-- "Empty soon" is sent when the time left drops below this many minutes
discordEmptySoonMinutes = 30

-- Hours between "still low" reminders while power stays low (0 = none)
discordReminder = 0

-- COLOURS -------------------------------------------------------------------

-- A name in quotes from the list at the end of this file, or a number
-- like 0xFF8800
barColor = "electricBlue"         -- the filled part of the bar, and the %
barEmptyColor = "darkSlateBlue"   -- the empty part of the bar
textOverFillColor = "black"       -- text over the filled part
textOverEmptyColor = "offWhite"   -- text over the empty part
alertColor = "red"                -- "Low power!", "Has Problems!", low bar
frameColor = "darkGray"           -- the frame around the bar
timeLeftColor = "offWhite"        -- the time left next to the HUD bar

-- One fixed colour for the EU/t and arrows (false = like the other text)
euTColor = false

-- ADVANCED ------------------------------------------------------------------

-- Numbers: "metric" = 4.4G, "scientific" = 4.42e9
numberFormat = "metric"

-- Show the wireless network's EU instead of the LSC's: the amount that
-- counts as 100%, e.g. 1e15 (false = off)
wireless = false

-- Timing, in seconds
euTAverage = 5             -- the EU/t is the average over this long
timeLeftAverage = 30       -- the time left uses the average over this long
timeLeftUpdateOnScreen = 5 -- the screen's time left changes this often
updateEvery = 2            -- time between updates

-- The low power HUD bar fades to alertColor and back (false = steady red)
lowPowerFade = true

-- Minutes the screen's History graph covers
historyMinutes = 30

-- Text on the HUD bar: "shadow" = light with a dark shadow; "split" = dark
-- over the fill and light over the rest, letter by letter (small gaps are
-- possible with resource-pack fonts)
barTextStyle = "shadow"

-- HUD size, in GUI pixels
hudHeight = 12
hudLength = 168
hudBorderBottom = 2
hudBorderTop = 2

-- HUD text sizes (3 = Minecraft's normal text size)
hudPercentFontSize = 3     -- the percentage and alerts
hudValueFontSize = 2.3     -- stored and max EU on the bar
hudEuTFontSize = 2.3       -- the EU/t and arrows
hudTimeLeftFontSize = 3    -- the time left past the bar

-- HUD opacity, 0 to 1
hudShapeOpacity = 0.9
hudTextOpacity = 1.0

-- With several GregTech machines connected: the LSC's address, e.g.
-- "e190015a" (false = find it automatically)
lscAddress = false

-- COLOUR NAMES --------------------------------------------------------------
-- red, orange, yellow, green, blue, indigo, violet, maroon, golden, lime,
-- olive, cyan, magenta, black, white, gray, lightGray, offWhite, darkGray,
-- electricBlue, dodgerBlue, steelBlue, midnightBlue, darkBlue,
-- darkSlateGreen, darkSlateBlue
