# GTNH Power Display

An OpenComputers (OC) program for GT New Horizons that shows your Lapotronic Supercapacitor (LSC) in real time, both as a HUD on AR glasses and as a full monitor on the computer's own screen. It can also switch backup generators on and off, and warn you when power runs low.

This is a fork of [DylanTaylor1/GTNH-PowerDisplay](https://github.com/DylanTaylor1/GTNH-PowerDisplay). The HUD keeps the original's design.

![FoxHUD](media/FoxHUD.png?)

## What's new in this fork

- **Screen monitor:** a framed charge bar in the HUD's colours with the percentage and net EU/t with arrows on it, stored and max EU, time until full or empty, GregTech's own in/out averages (5 s, 5 min, 1 h), passive loss, generator state and a history graph.
- **EU/t on the HUD:** net EU/t in the middle of the bar, averaged over the number of seconds you choose.
- **Low power alert:** below a percentage you set, the bar turns red and blinks, and "Low power!" shows above it.
- **Charge arrows:** animated `>` `>>` `>>>` after the EU/t while charging, `<<<` before it while discharging.
- **Readable text:** text on the bar is dark over the filled part and light over the empty part, letter by letter.
- **Generator control (optional):** a redstone signal that starts your generators below one percentage and stops them above another.
- **Starts by itself:** auto-start on boot, and wake on redstone so a redstone clock turns the computer back on after a power loss.
- **Keeps running:** waits for the LSC at boot, and recovers by itself if a read fails (for example while the chunk reloads).
- **Clear config errors:** a mistake in `config.lua` is explained in plain words instead of a Lua error.
- **Maintenance warning fixed:** newer GregTech versions send the LSC's sensor lines in a different form, which silently broke the original "Has Problems!" check.

# Components

The following requires EV circuits, epoxid, and titanium (late HV).
- Tier 3 Computer Case
- Tier 2 Screen (a tier 3 screen works too)
- Tier 2 Memory
- Tier 1 Central Processing Unit
- Tier 2 Graphics Card
- Tier 1 Hard Disk Drive
- Internet Card
- Adapter
- Keyboard
- EEPROM (Lua BIOS)
- OpenOS Floppy Disk
- 1+ Cables
- For the HUD: Glasses Terminal and AR Glasses
- Optional: MFU, so the adapter can reach an LSC up to 16 blocks away
- Optional: Redstone Card (tier 1 is enough), for wake on redstone
- Optional: Redstone I/O block, for generator control

To use the MFU upgrade, sneak right-click the LSC controller before placing it inside the adapter. The LSC controller should highlight green to indicate that the location is set.

![MinimumComponents](media/MinimumComponents.png?)

# Building the Setup

1) Place the adapter next to the LSC controller, or within 16 blocks if using the MFU upgrade.
2) Connect the adapter, computer case, screen, and glasses terminal with OC cables. Place the keyboard next to the screen.
3) Power the computer case with a GregTech or AE2 cable, or a power converter.
4) Right-click the glasses terminal with the AR glasses to link them. Wear them in a bauble slot, Tinkers mask slot, or helmet slot.
5) Shift-click all the components into the computer case and press the power button.
6) Enter `install`, then Y and Y. The OpenOS floppy is not needed afterwards.
7) Install Power Display by pasting this line into the computer (middle-click to paste). It asks what to install: 1 for Power Display, 2 for a viewer (see "Showing it on another computer"), 3 for the HUD on its own (see "HUD only").

        wget -f https://raw.githubusercontent.com/Willshaper/GTNH-PowerDisplay/main/setup.lua && setup

8) The installer asks whether to start Power Display when the computer boots, and (with a redstone card) whether a redstone signal should turn the computer on.
9) Change the settings with `edit config.lua`, especially the resolution and GUI scale for the HUD.

![Setup](media/Setup.png?)

# Running the Program

Enter `hud`. It runs until you press C (or Ctrl+Alt+C). Restart it after changing `config.lua`.

To update, run the `wget` line above again. It asks whether to replace your `config.lua` with a fresh one (only the settings of the chosen install, at their defaults); the old one is then saved as `config.old.lua`. If you keep yours, the current defaults are saved next to it as `config.default.lua`, so you can see any new settings.

## Settings

| Setting | Default | What it does |
|---|---|---|
| `showHud` / `showScreen` | `true` / `true` | Where to show the display. |
| `resolution`, `fullscreen`, `GUIscale` | `{1920, 1080}`, `true`, `3` | Your Minecraft window, used to place the HUD. |
| `hudSide` | `'left'` | Bottom corner for the HUD. `'right'` mirrors the shapes: the bar fills leftwards and slants the other way, and the percentage sits at the right edge. The text on the bar reads the same as on the left. It needs the right `resolution`. |
| `showPercent` | `true` | Charge percentage: next to the HUD bar, inside the screen's bar. |
| `showCurrentEU`, `showMaxEU` | `true` | Stored and maximum EU: on the HUD bar, under the screen's bar. |
| `showEUt` | `true` | Net EU/t in the middle of the bar (HUD and screen). |
| `showArrows` | `true` | Animated arrows after the EU/t while charging (nothing, `>`, `>>`, `>>>`, repeating) and before it while discharging (`<` to `<<<`), on the HUD and the screen. |
| `euTAverage` | `5` | The EU/t is the average over this many seconds (HUD and screen). |
| `showMaintenance` | `true` | Maintenance status: "Has Problems!" on the HUD, and the status and warning on the screen. |
| `metric` | `true` | Numbers as `4.4G` or as `4.42e9`. |
| `wirelessMode`, `wirelessMax` | `false`, `1e15` | Show the wireless network's EU instead. It has no maximum, so `wirelessMax` counts as 100%. |
| `height`, `length`, `borderBottom`, `borderTop`, `fontSize` | | HUD size. |
| `euTFontSize` | `false` | Size of the EU/t text and its arrows on the HUD bar. `false`: the same size as the stored and max EU. A number sets its own size, on the same scale as `fontSize` (`3` is as big as the percentage). |
| `shapeAlpha`, `textAlpha` | `0.9`, `1.0` | HUD transparency. |
| `primaryColor`, `secondaryColor`, `issueColor` | | Bar colours: filled, empty, low power (HUD and screen). |
| `borderColor` | | Colour of the frame around the bar (HUD and screen). |
| `textColor`, `textColorEmpty` | `colors.black`, `colors.offWhite` | Text on the bar: `textColor` over the filled part, `textColorEmpty` over the empty part (HUD and screen). |
| `barTextStyle` | `'split'` | How text on the HUD bar stays readable. `'split'`: each letter is `textColor` over the filled part and `textColorEmpty` over the empty part. `'shadow'`: `textColorEmpty` text with a `textColor` shadow. Use `'shadow'` if `'split'` leaves small gaps or overlaps in the text (possible with resource-pack fonts). |
| `euTColor` | `false` | One fixed colour for the EU/t text and arrows. `false` follows `barTextStyle`. |
| `lowPowerAlert` | `20` | Percentage below which the low power alert shows. `false` turns it off. |
| `lowPowerBlink` | `true` | Blink the bar while power is low. |
| `generatorControl` | `false` | Turn on generator control (see below). |
| `generatorRedstoneAddress` | `false` | Address of the Redstone I/O block for generator control (the start is enough, e.g. `'1a2b3c4d'`). Required when `generatorControl` is on. |
| `generatorSide` | `'north'` | Side of the Redstone I/O block the signal comes out of: `north`, `south`, `east`, `west`, `top` or `bottom`. |
| `generatorOnBelow`, `generatorOffAbove` | `20`, `90` | Start the generators below the first percentage, stop them above the second. |
| `generatorSignal` | `'stop'` | `'stop'`: a signal means stop. `'run'`: a signal means run. |
| `showTimeToFullOrEmpty` | `true` | "Full in" / "Empty in" on the screen. |
| `timeToFullOrEmptyAverage` | `30` | "Full in" / "Empty in" is worked out from the average EU/t over this many seconds. |
| `timeToFullOrEmptyUpdate` | `5` | How often, in seconds, "Full in" / "Empty in" changes. |
| `showAverages` | `true` | GregTech's In/Out/Net averages (5 s, 5 min, 1 hour) on the screen. |
| `showHistory` | `true` | Show the history graph on the screen. |
| `historyMinutes` | `30` | How much time the screen's history graph covers. |
| `showPassiveLoss` | `true` | Show the LSC's passive loss on the screen, under the Out column. The Net column includes it either way. |
| `linkedCard` | `false` | Send the display through the linked card(s) in this computer, for `viewer` on another computer (see below). |
| `lscAddress` | `false` | Only needed if the computer sees more than one GregTech machine: the start of the LSC's `gt_machine` address. |
| `sleep` | `1` | Seconds between updates. |

## Generator control

With a Redstone I/O block connected to the computer, Power Display can start your generators when the LSC runs low and stop them when it is full enough. Between the two percentages the generators keep doing what they were doing, so they don't switch on and off all the time. The computer's redstone card isn't used for this; it stays free for wake on redstone.

1. Place a Redstone I/O block and connect it to the computer with cable.
2. Set `generatorControl = true` and `generatorRedstoneAddress` to the block's address. To find it, shift-right-click the block with an Analyzer, or start Power Display: while the address is missing, the screen lists every Redstone I/O block it can see.
3. Set `generatorSide` to the side of the block your wiring leaves from (`north`, `south`, `east`, `west`, `top` or `bottom`).

The recommended wiring uses `generatorSignal = 'stop'`: put a Machine Controller cover set to "Disable with Redstone" on each generator (or on whatever turns them on) and run the signal to it. The block only sends a signal while the generators should stop. If Power Display can't read the LSC, or stops, it lets the generators run. With `'run'` it is the other way around: the signal means run.

A Redstone I/O block keeps its last signal when the computer turns off. That is safe in practice: the computer only loses power when the LSC is empty, and by then the generators have already been told to run. With auto-start and wake on redstone (below), the computer comes back and takes over again.

## Auto-start and wake on redstone

A computer that runs out of power switches off and stays off. To have it come back by itself:

1. Answer yes to both installer questions (or add `cd "/home" && hud` to `/home/.shrc`, and set the redstone card's wake threshold to 1 in `lua`).
2. Put a redstone card in the computer and wire a slow redstone clock (one pulse every 30 to 60 seconds) into it.

Each pulse turns the computer on if it is off; a running computer ignores it. Power Display then starts with it.

## Showing it on another computer (linked card)

A second computer anywhere, even in another dimension, can show the same monitor and HUD, through a pair of linked cards.

1. Craft a pair of linked cards. Put one in the Power Display computer and set `linkedCard = true` in its `config.lua`.
2. Build a second computer with a screen and graphics card (and a glasses terminal for the HUD there), and put the other linked card in it. It doesn't need an adapter or an LSC.
3. Run the same install command on it and answer 2 (viewer). It installs only what the viewer needs, with its own `config.lua` that has just the settings for how things look.
4. Run `viewer` there.

The viewer uses its own `config.lua` for colours, sizes and what to show. The values (EU/t, time to full or empty, generator state) come from the Power Display computer. If nothing arrives for a while, the viewer says so.

A tier 3 computer case has three card slots. With a graphics card, internet card and redstone card, the Power Display computer is full; the internet card is only needed to install and update, so it can make room for the linked card.

Each linked card only talks to its pair, so the Power Display computer sends to every linked card it has: one pair per viewer.

## HUD only

For just the glasses HUD, without the screen monitor, generator control or linked cards, answer 3 when installing. The computer needs the adapter on the LSC and a glasses terminal, but no screen. It installs only what the HUD needs, with a `config.lua` that has just the HUD and LSC settings. Start it with `hudonly`.

## Multiplayer

Every glasses terminal connected to the computer shows the HUD, so several players can share one computer. They all get the same settings.

## Other Helpful Commands

    ls                       list the files
    edit config.lua          change the settings
    viewer                   show another Power Display computer's display (linked card)
    hudonly                  just the glasses HUD (installed with answer 3)
    uninstall                remove Power Display (asks before removing config.lua)
    hud 2>/errors.log        save a long error message, then: edit /errors.log

## Thanks

Thanks to DylanTaylor1 for the original Power Display, and to Sampsa and Vlamonster for the implementations it grew from.
