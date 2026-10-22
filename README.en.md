# WakeTheHack

**Wake the Hack** is a small 3D wakeboarding game made with **Godot 4.7**: wakeboarding on a **2-tower cable system** on a lake, as you often find them in Europe – so no boat involved.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf) [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy_me_a_coffee-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/kimpixel)

Deutsch: [README.md](README.md)

## Play in the browser

**▶ https://kimpixel.github.io/wakeportGame/**

Works best in Chrome, Edge or Firefox on a PC. Click into the picture once so keyboard and mouse respond.

**Languages:** Deutsch, English, Français, Español, Nederlands, Polski, Čeština, Português (Brasil). The default is the language of your browser or system; change it under Settings → Game → Language.

## The cable park

The game recreates the **Wakeport at the Raunheimer Waldsee** (Hesse, Germany), right next to Frankfurt Airport. **On the home screen you choose which cable you ride: Terminal 2 or Terminal 1.** An NPC rider (blue vest) rides the other one with jumps and 180s. An operator with the yellow remote control stands on both start docks; the cheering always comes from the start dock of your cable.

- The start tower stands on the beach (real coordinates), the end tower about 233 m out in the lake (Terminal 1: 240 m). The end towers stand 35 m further out than in the geodata so there is enough room between the features and the turn buoys (`Lake.END_EXTEND`).
- A steel rope runs as a loop around two pulleys (Ø 30 cm) at the top of the A-shaped lattice towers.
- A **carrier** is clamped to one of the two strands. The motor reverses direction at each end, so the rider is pulled back and forth.
- Terrain, shore, forest and aerial photo come from the open geodata of Hesse. The beach area with its huts was rebuilt from photos.
- Dense mixed forest of deciduous trees and pines, along the shore a closed forest edge down to the water. The shore grass comes from [SimpleGrassTextured](https://github.com/IcterusGames/SimpleGrassTextured) by IcterusGames (MIT, texture CC0), see `assets/grass/`.

## Features (obstacles)

The real feature setups of both cables are defined modularly in [setups/](setups/README.md): a parts catalogue with the real modules and several setups, one file each for both terminals. **On the home screen you choose which setup you ride.** The current one is “2026 September”, plus several older setups whose dates are still placeholders.

**6-Stair Pool** (setup **Pool Party**, also in Utopia; a module in the editor; its own challenge mode **Pool**): a floating basin with real water. Jump in over the ramp and ride the pool like the lake, slide the coping, and leave over one of the two exits or the 6-step stairs back into the lake – the stairs only work in a **drift** (Ctrl), otherwise you crash. **Pool points** (count in combos): **Pool Drop** (+100), **Pool Gap** (over the whole basin, +400 – very hard), **Stair Gap** (+200), **Stair Drift** (150), **Stair Climb** (250) and **Pool Coping to …** (+150).

**Setup editor** (button on the home screen): build your own setups for both terminals. On the left the lane from above (grid, rope, towers, turns, buoys; switchable to 3D), on the right the parts, all hacks from the real setups, the properties of the selection with a 3D preview and the setup itself (load template, clear/copy terminal, copy/paste JSON). Tap = select (double = whole hack, Shift/Ctrl = several), drag = move, drag empty area = move map, wheel or + / − = zoom. Keys: arrows 0.1 m (Shift 1 m), Q/E rotate, F direction, M mirror, Ctrl+D duplicate, Del delete, Ctrl+Z/Ctrl+Y. **Save** creates a custom setup (stored in the browser or on the device); **Save & ride** starts right away. The **Plants** tab lets you paint reeds, grass, shrubs and trees onto the aerial photo.

You can ride straight over the white floating dock, the wooden dock and the turn buoys; the blue rubber ball (in some setups) has to be jumped.

## Controls

The riding physics are written from scratch and based on the tow rope:
- The rope only pulls when it is tight, and it is slightly elastic.
- Along the board the water brakes little; across it the edge holds against it.
- Riding at an angle to the rope you swing outwards and can become faster than the carrier.

Gamepad names as on the PS4 controller (Xbox: ✕ = A, ○ = B, Options = Start, Share = Back, PS = Guide).

| Key | Gamepad | Function |
|---|---|---|
| ← / → (A / D) | left stick ↔, D-pad ↔ | Steer over the edge. In the air and during a Raley: spin. **On a slider:** each tap a quarter turn, Boardslide ↔ 50-50. **Rail to Rail:** on a slider hold Space and ←/→ = hop sideways on release |
| ↑ / ↓ (W / S) | left stick ↕, D-pad ↕ | In the air: **Frontroll / Backroll**. **Invert** right after take-off: ↑ = **S-Bend**, ↓ = **Backroll**. In a drift: **Drift Press**. On a slider: **Nosepress / Tailpress** (pressed already on approach you land directly in the press). On the start dock: **dock start** – hold ↓, brace against the rope until it yanks you off: board in line = **Nolli**, sideways = **Raley Start** |
| Ctrl (or Alt) | ○ or L2 | **Drift**: edge released – you keep sliding, steering doesn't change your direction, the board spins freely. After a crash: continue right away (−1:00) |
| Hold Space + release | ✕, or R2 (analog) | Pop: an **Ollie**; fully charged with rope tension above the **RALEY** mark and no feature ahead an **Invert** (Raley; with ↑/↓ S-Bend or Backroll). Raley 180 = **Blind Judge** (left) / **Krypt** (right), Raley 360 = **313** / **BS 313** |
| R | Touchpad | back to the start dock (costs 2:00) |
| Z | Share | shuffle a new **scenario** |
| Hold Space | ✕ | after a crash: swim to the handle |
| + / − | R1 / L1 (on the water) | cable speed (16–40 km/h) |
| – | L1 / R1 (in the air) | quick 180 left / right |
| C | – | camera: chase, orbit or shore |
| Tab | – | back to the home screen |
| Mouse / wheel | right stick | look around / zoom |
| P | – | autopilot |
| Esc | PS | **pause** |
| O | Options | **settings** |
| M | – | sound off/on |
| H / F1 | – | help on/off |
| G | – | rope rip on/off (off = **no leaderboard**) |
| F11 / Alt+Enter | – | fullscreen (desktop only) |

**On phones/tablets** (in the browser, detected automatically): ← / → bottom right to steer (or tilt the phone with *Steering: Gyro*), hold JUMP (bottom left) and release to pop, arrows up/down for rolls and presses, DRIFT above JUMP, ☰ menu below the HUD bar.

**Turns:** at each turning point there is a **red buoy** in the middle under the rope (edge out here) and **two white buoys** (ride around one of them). The board only floats with **rope tension or plenty of speed** – if the rope goes slack in the turn and you slow down, you sink. A turn without sinking gives **points** (15, around the white buoy 30).

## Game modes

- **Competition:** a round against the clock (7:30 by default). Points: slides count most (150 + 150 per second, boardslide +100, press +100, rail/pipe ×1.5), airs 50 per second and 50 per 180°, Raley +150, rolls 300 each. **Combos:** the next trick within 3 s doubles, the third triples … A crash or sinking ends the combo. Shortcuts cost time: Ctrl after a crash −1:00, R back to the dock −2:00.
- **Community Challenge:** modes with challenges from easy to hard, each measuring one value for **bronze, silver or gold**: Turns, Kicker, Slider, Dock start, Drifting, Invert Training, Rail to Rail, Transfer and Pool. Always on Terminal 2 with 30 km/h and 16 m rope so the results are comparable. A film crew (red boat or FPV drone) films you and shows the photos afterwards.
- **Secret achievements** (button *Achievements*): 12 greyed-out entries – you only see what they are once you've done them.
- **Leaderboard** (button *Leaderboard*): the best riders per challenge and per competition (terminal, setup, round length). Your results go in automatically, without a name as **“Anonym #…”**. Switching *Show me on the leaderboard* off deletes your name and all entries. Server: [server/README.md](server/README.md).

**Weather, season and time of day** follow the real position of the sun at the lake. A **scenario** (date, time, weather) is picked at random after every game or chosen on the home screen. Wildlife follows the season: SUPs and bathers in summer, grebes, swans, herons, cranes in autumn, ice floes in winter. And the lake lies right in the approach path to Frankfurt – jets fly over low and loud.

## Run locally

1. Download [Godot 4.7.2](https://godotengine.org/download/archive/) (exactly this version, see [CONTRIBUTING.md](CONTRIBUTING.md)).
2. Import this folder in the project manager (`project.godot`).
3. Start with **F5**.

Headless test run:

```
godot --headless --path . --fixed-fps 120 -- --autotest --quit=120
```

## Translations

Texts are written in German in the code (`tr("…")`, gettext msgid) and translated in `locale/*.po`. After changing texts:

```
node tools/i18n.js extract      # collect texts -> locale/messages.pot, sync all .po files
node tools/i18n.js stats        # translated / missing per language
node tools/i18n.js check        # placeholders (%s, %d …) match
```

Improvements to the translations are very welcome – the `.po` files can be edited with any gettext editor (e.g. Poedit) or directly as text.

## Geodata

Based on the **open geodata of Hesse** by the Hessian administration for land management and geoinformation (HVBG): DGM1 terrain model, DOM1 surface model and DOP20 aerial photos. The processed data is in `assets/geo/` (`tools/fetch_geodata.mjs`).

## Project structure

The most important files are listed in [README.md](README.md#projektaufbau) and in detail (all files, rules and decisions, in German) in [CLAUDE.md](CLAUDE.md).

## Support

The game is free and open source, I develop it in my spare time (and pay for the AI tools myself). If you like it, I'm happy about a coffee: **[ko-fi.com/kimpixel](https://ko-fi.com/kimpixel)**.

## License

[MIT](LICENSE) – you may use, modify and share the code freely as long as the license notice is kept.

**Exception:** `assets/board/top.png` and `assets/board/bottom.png` show a board by Slingshot. Photo, graphics and logo © Slingshot. They are not under the MIT license and must not be reused.
