-- Power Display settings. Restart the program after changing anything.
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

  -- Where to show it: AR glasses HUD, the computer's screen, or both
  showHud = true,
  showScreen = true,

  -- Your Minecraft window (for placing the HUD)
  resolution = {1920, 1080},
  fullscreen = true,
  GUIscale = 3,
  -- Which bottom corner the HUD sits in: 'left' or 'right' (a mirror image of left).
  -- 'right' needs the resolution above to be right.
  hudSide = 'left',

  -- HUD values
  showCurrentEU = true,
  showRate = true,      -- arrows next to the stored EU: < slowly draining ... >>> charging fast
  showMaxEU = true,
  showEUt = true,       -- net EU/t in the middle of the bar
  euTSeconds = 5,       -- EU/t is the average over this many seconds (HUD and screen)

  -- Wireless mode: show the wireless network's EU instead of the LSC's own
  wirelessMode = false,
  wirelessMax = 1e15,   -- the wireless network has no maximum; this is what counts as 100%

  -- How much the fill % must change per update for one more arrow
  rateThreshold = 0.003,
  -- Numbers as 4.4G (true) or 4.42e9 (false)
  metric = true,

  -- HUD size
  height = 12,
  length = 168,
  borderBottom = 2,
  borderTop = 2,
  fontSize = 3,

  -- HUD transparency (0 to 1)
  shapeAlpha = 0.9,
  textAlpha = 1.0,

  -- HUD colours (see the list at the top)
  primaryColor = colors.electricBlue,
  secondaryColor = colors.darkSlateBlue,
  textColor = colors.black,
  euTColor = false,     -- colour of the EU/t text; false uses textColor
  issueColor = colors.red,
  borderColor = colors.darkGray,

  -- Low power alert: the bar turns red below this percentage (false turns it off)
  lowPowerAlert = 20,
  lowPowerBlink = true,

  -- A light glint runs along the bar while charging (left to right) or discharging
  -- (right to left), on the HUD and the screen
  barAnimation = true,

  -- Generator control (needs a redstone card in the computer)
  generatorControl = false,
  generatorSide = 'back',   -- back, front, left, right, top or bottom
  generatorOnBelow = 20,    -- start the generators below this percentage
  generatorOffAbove = 90,   -- stop them again above this percentage
  -- 'stop': a redstone signal means stop (the generators run if this computer turns off)
  -- 'run':  a redstone signal means run
  generatorSignal = 'stop',

  -- Screen: a graph of the charge over the last historyMinutes minutes
  showHistory = true,
  historyMinutes = 30,
  -- Screen: show the LSC's passive loss under the averages (Net always includes it)
  showPassiveLoss = true,

  -- Which LSC to read if the computer sees more than one GregTech machine.
  -- false finds it automatically; otherwise the start of its gt_machine address, e.g. 'e190015a'
  lscAddress = false,

  -- Seconds between updates
  sleep = 1,
}
