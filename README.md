# GTNH Power Display

An OpenComputers (OC) program for GT New Horizons that shows your Lapotronic Supercapacitor (LSC) in real time, both as a HUD on AR glasses and as a full monitor on the computer's own screen. It can also switch backup generators on and off, and warn you when power runs low.

This is a fork of [DylanTaylor1/GTNH-PowerDisplay](https://github.com/DylanTaylor1/GTNH-PowerDisplay). The HUD keeps the original's design.

![HUD](media/HUD.png)

## What's new in this fork

- **Screen monitor:** a framed charge bar in the HUD's colours with the percentage and net EU/t with arrows on it, stored and max EU, time until full or empty, GregTech's own in/out averages (5 s, 5 min, 1 h), passive loss, generator state and a history graph.
- **EU/t on the HUD:** net EU/t in the middle of the bar, averaged over the number of seconds you choose.
- **Time left:** "Full in 52m 00s" on the screen, and optionally "Full: 52min" next to the HUD bar.
- **Low power alert:** below a percentage you set, the HUD bar slowly fades to red and back, the screen's bar turns red, and "Low power!" shows above it.
- **Charge arrows:** animated `>` `>>` `>>>` after the EU/t while charging, `<<<` before it while discharging.
- **Readable text:** text on the bar is light with a dark shadow, readable over both the filled and the empty part.
- **HUD in either corner:** bottom left, or mirrored in the bottom right.
- **Generator control (optional):** a Redstone I/O block starts your generators below one percentage and stops them above another.
- **Three installs:** the full Power Display, a viewer that shows it on another computer through a pair of linked cards (even in another dimension), or just the glasses HUD.
- **Starts by itself:** auto-start on boot, and wake on redstone so a redstone clock turns the computer back on after a power loss.
- **Keeps running:** waits for the LSC at boot, and recovers by itself if a read fails (for example while the chunk reloads).
- **Simple settings file:** one setting per line with no commas to forget, word lists for what the HUD and the screen show, colours by name, and rarely used settings in an Advanced section.
- **Edit while it runs:** press S to change the settings; they apply as soon as you save.
- **Clear config errors:** a mistake in `config.lua` is explained in plain words, naming the setting, instead of a Lua error.
- **Updates keep your settings:** the installer carries your values into a newer `config.lua`.
- **Maintenance warning fixed:** newer GregTech versions send the LSC's sensor lines in a different form, which silently broke the original "Has Problems!" check.

# Components

The following requires EV circuits, epoxid, and titanium (late HV).
- Tier 3 Computer Case
- Tier 2 Screen (a tier 3 screen works too; HUD only needs one just to install and set up)
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
- Optional: a pair of Linked Cards, to show it on another computer

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
9) Set `windowSize` and `guiScale` in the settings, so the HUD lands in the corner: start the program (`hud`) and press S, or run `edit config.lua`.

![Setup](media/Setup.png?)

# Running the Program

Enter `hud`. It runs until you press C (or Ctrl+Alt+C). Press S to change the settings while it runs: `config.lua` opens in the editor, and the new settings are used as soon as you save (Ctrl+S) and close it (Ctrl+W). If the file has a mistake, the previous settings stay in use and the program says what is wrong. The viewer (`viewer`) and the HUD on its own (`hudonly`) work the same way.

To update, run the `wget` line above again. If there is a newer `config.lua`, it shows what changed and asks whether to switch to it. Your values are carried over, settings the chosen install doesn't use are left out, and a value the new version no longer accepts goes back to its default (each of these is listed). The old file is kept as `config.old.lua`. If you say no, your file stays and the new one is saved as `config.default.lua`.

## Settings

`config.lua` has one setting per line, like `hudCorner = "right"`. A setting you leave out uses its default. Text goes in quotes. Press S in the running program to edit it, or edit it with `edit config.lua` and restart the program. A mistake is reported with the setting's name.

These are the settings of the full Power Display. The viewer's and the HUD only `config.lua` have just the ones they use.

### What to show

`hud` and `screen` are lists of words, in any order. `""` turns the HUD or the screen monitor off.

| Word | HUD | Screen |
|---|---|---|
| `Percent` | charge %, left of the bar | inside the bar, on the left |
| `Stored` | EU stored, at the start of the bar | under the bar |
| `EUt` | net EU/t, in the middle of the bar | in the middle of the bar |
| `Arrows` | `>` `>>` `>>>` after the EU/t while charging, `<` to `<<<` before it while draining | the same |
| `Max` | capacity, at the end of the bar | under the bar |
| `Maintenance` | "Has Problems!" above the bar | status in the title and a warning at the bottom |
| `TimeLeft` | "Full: 52min" / "Empty: 2h 05min", past the end of the bar | "Full in 52m 00s", under the bar |
| `Averages` | | GregTech's In/Out/Net over 5 s, 5 min and 1 hour |
| `PassiveLoss` | | the LSC's passive loss, under Out |
| `History` | | a graph of the charge |

| Setting | Default | What it does |
|---|---|---|
| `hud` | `"Percent Stored EUt Arrows Max Maintenance"` | What the HUD shows. |
| `screen` | all ten words | What the computer's screen shows. |
| `hudCorner` | `"left"` | Bottom corner for the HUD. `"right"` mirrors it: the bar fills leftwards and slants the other way; the text on the bar reads the same. |
| `lowPower` | `20` | Below this %, the bar turns red (fading on the HUD, see `lowPowerFade`) and "Low power!" shows. `false` turns it off. |

### Your Minecraft window

| Setting | Default | What it does |
|---|---|---|
| `windowSize` | `{1920, 1080}` | Your monitor's resolution (the game window's size when not fullscreen), to place the HUD in the corner. |
| `fullscreen` | `true` | Whether the game runs fullscreen. |
| `guiScale` | `3` | Video Settings > GUI Scale. |

### Generators and linked card

| Setting | Default | What it does |
|---|---|---|
| `generatorControl` | `false` | The Redstone I/O block's address, e.g. `"1a2b3c4d"` (see Generator control below). `false` = off. |
| `generatorOnBelow`, `generatorOffAbove` | `20`, `90` | Start the generators below the first %, stop them above the second. |
| `generatorSide` | `"north"` | Side of the block the signal leaves: `north`, `south`, `east`, `west`, `top` or `bottom`. |
| `generatorSignal` | `"stop"` | `"stop"`: a signal stops them. `"run"`: a signal runs them. |
| `linkedCard` | `false` | `true` sends the display through the linked card(s), for the viewer on another computer. |

### Colours

A colour is a name in quotes, from the list at the end of `config.lua` (e.g. `"electricBlue"`), or a number like `0xFF8800`.

| Setting | Default | What it colours |
|---|---|---|
| `barColor` | `"electricBlue"` | The filled part of the bar, and the percentage. |
| `barEmptyColor` | `"darkSlateBlue"` | The empty part of the bar. |
| `textOverFillColor` | `"black"` | Text over the filled part. |
| `textOverEmptyColor` | `"offWhite"` | Text over the empty part. |
| `alertColor` | `"red"` | "Low power!", "Has Problems!" and the low power bar. |
| `frameColor` | `"darkGray"` | The frame around the bar. |
| `timeLeftColor` | `"offWhite"` | The time left next to the HUD bar. |
| `euTColor` | `false` | One fixed colour for the EU/t and arrows. `false`: like the other text on the bar. |

### Advanced

| Setting | Default | What it does |
|---|---|---|
| `numberFormat` | `"metric"` | `"metric"` = `4.4G`, `"scientific"` = `4.42e9`. |
| `wireless` | `false` | Show the wireless network's EU instead of the LSC's: the amount that counts as 100%, e.g. `1e15` (the network has no maximum). |
| `euTAverage` | `5` | The EU/t is the average over this many seconds. |
| `timeLeftAverage` | `30` | The time left is worked out from the average over this many seconds. |
| `timeLeftUpdateOnScreen` | `5` | The screen's time left changes on the first update after this many seconds (every 6 s with updates every 2 s). On the HUD it changes together with the EU/t. |
| `updateEvery` | `2` | Seconds between updates. |
| `lowPowerFade` | `true` | While power is low, the HUD bar slowly fades to `alertColor` and back (about every 2 seconds). `false`: steady. The screen's bar is steady red either way. |
| `historyMinutes` | `30` | Minutes the screen's History graph covers. |
| `barTextStyle` | `"shadow"` | Text on the HUD bar: `"shadow"` = light with a dark shadow, readable on both parts of the bar whatever the font; `"split"` = dark over the fill and light over the rest, letter by letter (can leave small gaps or overlaps with resource-pack fonts). |
| `hudHeight`, `hudLength`, `hudBorderBottom`, `hudBorderTop` | `12`, `168`, `2`, `2` | HUD size, in GUI pixels. |
| `hudPercentFontSize` | `3` | Size of the percentage, and of the alerts above the bar. `3` is Minecraft's normal text size. |
| `hudValueFontSize` | `2.3` | Size of the stored and max EU on the bar. |
| `hudEuTFontSize` | `2.3` | Size of the EU/t and arrows. |
| `hudTimeLeftFontSize` | `3` | Size of the time left past the bar. |
| `hudShapeOpacity`, `hudTextOpacity` | `0.9`, `1.0` | HUD opacity, 0 to 1. |
| `lscAddress` | `false` | Only with several GregTech machines connected: the LSC's address (the start is enough). |

## Generator control

With a Redstone I/O block connected to the computer, Power Display can start your generators when the LSC runs low and stop them when it is full enough. Between the two percentages the generators keep doing what they were doing, so they don't switch on and off all the time. The computer's redstone card isn't used for this; it stays free for wake on redstone.

1. Place a Redstone I/O block and connect it to the computer with cable.
2. Set `generatorControl` to the block's address, e.g. `generatorControl = "1a2b3c4d"`. To find it, shift-right-click the block with an Analyzer, or set `generatorControl = "?"` and start Power Display: the screen lists every Redstone I/O block it can see.
3. Set `generatorSide` to the side of the block your wiring leaves from (`north`, `south`, `east`, `west`, `top` or `bottom`).

The recommended wiring uses `generatorSignal = "stop"`: put a Machine Controller cover set to "Disable with Redstone" on each generator (or on whatever turns them on) and run the signal to it. The block only sends a signal while the generators should stop. If Power Display can't read the LSC, or stops, it lets the generators run. With `"run"` it is the other way around: the signal means run.

A Redstone I/O block keeps its last signal when the computer turns off. That is safe in practice: the computer only loses power when the LSC is empty, and by then the generators have already been told to run. With auto-start and wake on redstone (below), the computer comes back and takes over again.

## Auto-start and wake on redstone

A computer that runs out of power switches off and stays off. To have it come back by itself:

1. Answer yes to both installer questions (or add `cd "/home" && hud` to `/home/.shrc`, with `viewer` or `hudonly` instead of `hud` for those installs, and set the redstone card's wake threshold to 1 in `lua`).
2. Put a redstone card in the computer and wire a slow redstone clock (one pulse every 30 to 60 seconds) into it. Keep the signal away from the screen: a redstone pulse turns an OpenComputers screen on or off.

Each pulse turns the computer on if it is off; a running computer ignores it. Power Display then starts with it.

## Showing it on another computer (linked card)

A second computer anywhere, even in another dimension, can show the same monitor and HUD, through a pair of linked cards.

1. Craft a pair of linked cards. Put one in the Power Display computer and set `linkedCard = true` in its `config.lua`.
2. Build a second computer with a screen and graphics card (and a glasses terminal for the HUD there), and put the other linked card in it. It doesn't need an adapter or an LSC.
3. Run the same install command on it and answer 2 (viewer). It installs only what the viewer needs, with its own `config.lua` that has just the settings for what to show and how it looks.
4. Run `viewer` there.

The viewer uses its own `config.lua` for colours, sizes and what to show. The values (EU/t, time to full or empty, generator state) come from the Power Display computer. If nothing arrives for a while, the viewer says so.

A tier 3 computer case has one tier 3 card slot and two tier 2 slots, and the linked card only fits the tier 3 one. Move the graphics card (tier 2) to a tier 2 slot and put the linked card in the tier 3 slot. With a redstone card as well, there is then no room for the internet card: it is only needed to install and update, so swap it in for the redstone card when you update.

Each linked card only talks to its pair, so the Power Display computer sends to every linked card it has: one pair per viewer.

## HUD only

For just the glasses HUD, without the screen monitor, generator control or linked cards, answer 3 when installing. The computer needs the adapter on the LSC and a glasses terminal; a screen is only needed to install and set it up. It installs only what the HUD needs, with a `config.lua` that has just the HUD and LSC settings. Start it with `hudonly`; its status (waiting for the LSC, mistakes in the settings) shows on the computer's terminal.

## Multiplayer

Every glasses terminal connected to the computer shows the HUD, so several players can share one computer. They all get the same settings.

## Other Helpful Commands

    ls                       list the files
    edit config.lua          change the settings (or press S in the running program)
    viewer                   show another Power Display computer's display (linked card)
    hudonly                  just the glasses HUD (installed with answer 3)
    uninstall                remove Power Display (asks before removing config.lua)
    hud 2>/errors.log        save a long error message, then: edit /errors.log

## Thanks

Thanks to DylanTaylor1 for the original Power Display, and to Sampsa and Vlamonster for the implementations it grew from.
