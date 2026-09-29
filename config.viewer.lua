-- Power Display viewer settings: how this computer shows the display it receives
-- through its linked card. The values themselves (EU/t, time to full or empty,
-- generator state) come from the Power Display computer. Restart the viewer after
-- changing anything.
-- Each setting ends with a comma. Anything you delete falls back to its default.

local colors = {
  red = 0xFF0000,
  orange = 0xFFA500,
  yellow = 0xFFFF00,
  green = 0x008000,
  blue = 0x0000FF,
  indigo = 0x4B0082,
  violet = 0x800080,

  maroon = 0x800000,
  golden = 0xDAA520,
  lime = 0x00FF00,
  olive = 0x556B2F,
  cyan = 0x00FFFF,
  magenta = 0xFF00FF,

  black = 0x000000,
  white = 0xFFFFFF,
  gray = 0x3C5B72,
  lightGray = 0xA9A9A9,
  offWhite = 0xE6E6E6,
  darkGray = 0x181828,

  electricBlue = 0x00A6FF,
  dodgerBlue = 0x1E90FF,
  steelBlue = 0x4682B4,
  midnightBlue = 0x191970,
  darkBlue = 0x000080,

  darkSlateGreen = 0x2F4F4F,
  darkSlateBlue = 0x303850,
}

return {

  -- Where to show it: AR glasses HUD, this computer's screen, or both
  showHud = true,
  showScreen = true,

  -- Your Minecraft window (for placing the HUD)
  resolution = {1920, 1080},
  fullscreen = true,
  GUIscale = 3,
  -- Which bottom corner the HUD sits in: 'left' or 'right' (the shapes are mirrored,
  -- the text on the bar reads the same).
  -- 'right' needs the resolution above to be right.
  hudSide = 'left',

  -- Values on the bar (HUD and screen)
  showPercent = true,   -- charge % left of the bar
  showCurrentEU = true,
  showMaxEU = true,
  showEUt = true,       -- net EU/t in the middle of the bar
  showArrows = true,    -- animated > >> >>> after the EU/t while charging, <<< before it while discharging (HUD and screen)

  -- Maintenance status: "Has Problems!" on the HUD, status and warning on the screen
  showMaintenance = true,

  -- Numbers as 4.4G (true) or 4.42e9 (false)
  metric = true,

  -- HUD size
  height = 12,
  length = 168,
  borderBottom = 2,
  borderTop = 2,
  fontSize = 3,
  euTFontSize = false,  -- size of the EU/t text and arrows; false: the same as the stored/max EU (3 = as big as the %)

  -- HUD transparency (0 to 1)
  shapeAlpha = 0.9,
  textAlpha = 1.0,

  -- Colours (see the list at the top). The bar and its text look the same on the screen.
  primaryColor = colors.electricBlue,
  secondaryColor = colors.darkSlateBlue,
  textColor = colors.black,         -- text over the filled part of the bar
  textColorEmpty = colors.offWhite, -- text over the empty part of the bar
  -- How text on the HUD bar stays readable:
  -- 'split':  each letter takes textColor or textColorEmpty, whichever part of the bar it is over
  -- 'shadow': textColorEmpty text with a textColor shadow (use this if 'split' leaves gaps
  --           or overlaps in the text, which can happen with resource-pack fonts)
  barTextStyle = 'split',
  euTColor = false,     -- one fixed colour for the EU/t text and arrows; false follows barTextStyle
  issueColor = colors.red,
  borderColor = colors.darkGray,

  -- Low power alert: the bar turns red below this percentage (false turns it off)
  lowPowerAlert = 20,
  lowPowerBlink = true,

  -- Screen: "Full in 5m 26s" / "Empty in 2h 03m" under the bar
  showTimeToFullOrEmpty = true,
  -- Screen: GregTech's own In/Out/Net averages over 5 s, 5 min and 1 hour
  showAverages = true,
  -- Screen: a graph of the charge over the last historyMinutes minutes
  showHistory = true,
  historyMinutes = 30,
  -- Screen: show the LSC's passive loss under the Out column (Net always includes it)
  showPassiveLoss = true,
}
