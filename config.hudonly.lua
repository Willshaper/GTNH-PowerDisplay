-- Power Display (HUD only) settings. Restart hudonly after changing anything.
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

  -- Your Minecraft window (for placing the HUD)
  resolution = {1920, 1080},
  fullscreen = true,
  GUIscale = 3,
  -- Which bottom corner the HUD sits in: 'left' or 'right' (the shapes are mirrored,
  -- the text on the bar reads the same).
  -- 'right' needs the resolution above to be right.
  hudSide = 'left',

  -- Values on the bar
  showPercent = true,   -- charge % left of the bar
  showCurrentEU = true,
  showMaxEU = true,
  showEUt = true,       -- net EU/t in the middle of the bar
  euTAverage = 5,       -- the EU/t is the average over this many seconds
  showArrows = true,    -- animated > >> >>> after the EU/t while charging, <<< before it while discharging

  -- Maintenance status: "Has Problems!" above the bar
  showMaintenance = true,

  -- Wireless mode: show the wireless network's EU instead of the LSC's own
  wirelessMode = false,
  wirelessMax = 1e15,   -- the wireless network has no maximum; this is what counts as 100%

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

  -- Colours (see the list at the top)
  primaryColor = colors.electricBlue,
  secondaryColor = colors.darkSlateBlue,
  textColor = colors.black,         -- text over the filled part of the bar
  textColorEmpty = colors.offWhite, -- text over the empty part of the bar
  -- How text on the bar stays readable:
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

  -- Which LSC to read if the computer sees more than one GregTech machine.
  -- false finds it automatically; otherwise the start of its gt_machine address, e.g. 'e190015a'
  lscAddress = false,

  -- Seconds between updates
  sleep = 1,
}
