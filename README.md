# Chiip

A single-player tactical FPS in the spirit of Counter-Strike, played against bots, with the look of a 1990s Quake-era shooter. Built with Godot 4.7.2.

> **Status:** online multiplayer (M9) is being built: host or join a LAN game from the main menu (see "Playing with friends"). M1–M5 built: CS-style movement, a rifle with CS-like recoil, the retro look, bots, and full matches (main menu, match setup, 1–5 per side with bot teammates, rounds with freeze time, round HUD, kill feed, scoreboard, spectating, pause menu, settings saved to disk). The M5 playtest is pending (checklist in [docs/PLAN.md](docs/PLAN.md), "Your open checks"). Progress is tracked in [docs/PLAN.md](docs/PLAN.md).

## Requirements

- Godot **4.7.2**, standard edition (GDScript). The .NET edition is not needed.
- macOS for development. Other platforms can be added later through Godot's export.

## Running the game

**From the Godot editor** (recommended):
1. Open Godot. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
2. Press **F5** (or the ▶ button at the top right) to play. The **main menu** opens over a slow camera flight across the test map: **Play**, **Practice**, **Settings** and **Quit** (Esc closes match setup and the settings menu; on the main page it does nothing).
   **Play** opens match setup: the mode (**Rounds**, which are bomb rounds on the quick maps, or **Team respawn**), the size of your team and of the enemy team (1–5 each, you included in yours), the bots' difficulty (Easy, Normal, Hard), the match length (first to 5, 10 or 15 rounds; for team respawn 30, 50 or 75 kills), friendly fire, one map or the **rotation** of the three quick maps, and the map. In a rotation the end screen offers **Next map**. The defaults are a 3v3 match, Normal bots, first to 5, friendly fire off, on the test map, and the game remembers your last choices. **Start** begins the match: you and your bot teammates (blue) against the bots (red). After 5 s of freeze time the round goes live; eliminate the other team, or hold out until time runs out if your team defends.
   The top bar shows the score (yours blue on the left, theirs red), the round timer and who is alive; the kill feed is at the top right.
   If you die, you watch a living teammate through their eyes until the next round (left click for the next teammate).
   At the start of the match a class menu opens with **your two drafted classes** for this match (each match offers two of Rifleman, Bulwark, Marksman and Scout at random): click a card or press 1 or 2; Esc closes it. **M** opens it again during freeze time (any time in Team Deathmatch). Each class has its own perk and loadout. Bots draft too, and each team gets a mix of classes.
   A match is first to 5 rounds; the sides swap at half time (after round 4), and when a team wins its 5th round an end screen shows Victory or Defeat, the score and a scoreboard, with **Play again** and **Main menu** buttons.
   **Esc** during a game opens the **pause menu**, which pauses everything (the round timer, the bots, the sounds): **Resume**, **Settings** and **Leave match** (back to the main menu). Esc again resumes.
3. **Practice** in the main menu (or running with `-- --practice`, see below) is the old bot arena without rounds (bots respawn; good for warm-ups and the shooting range), with the bots' difficulty you last chose in match setup. To leave a game for the menu, use the end screen's **Main menu** button or type `disconnect` in the console.

**From the terminal**, without opening the editor (this opens the main menu):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip
```

To skip the menu and start a default 3v3 match on the test map at once (handy for development; it ignores your saved match setup), add `-- --match`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --match
```

To play the three quick maps in rotation from the terminal (the end screen then offers **Next map**), add `-- --match --rotation` (and `--respawn` for team respawn):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --match --rotation
```

For the **team respawn** mode (like Call of Duty's Team Deathmatch: respawn after 3 s, first team to 50 kills wins; bots hunt in pairs), add `-- --respawn`, e.g. on Depot:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --map res://maps/depot.tscn --respawn
```

For practice mode (also straight into the game), add `-- --practice`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --practice
```

**Maps:** the three quick maps **Depot**, **Square** and **Spillway** (M8 layouts, dressed with the map kit in M10, see [docs/MAPS.md](docs/MAPS.md)), the test map (the default) and the kit gallery (`-- --map res://maps/kit/kit_gallery.tscn`, everything in the map kit). In the game, open the console and type `map depot`, `map square` or `map spillway`. On these maps a match is played as **bomb rounds**: one attacker carries the bomb; hold **E** inside site A or B to plant it, and as a defender hold E next to it to defuse (docs/GAME_DESIGN.md, 4.7).

To play a different map (also straight into the game, as a match where the map allows it), add `-- --map` and the map scene, e.g. `-- --map res://maps/depot.tscn`, or the TrenchBroom comparison room:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --map res://maps/comparison/trenchbroom_room.tscn
```

## Controls (so far)

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Jump | Space or mouse wheel down |
| Crouch (crouch in the air to crouch-jump) | Ctrl |
| Walk (silent) | Shift |
| Pause menu (pauses the game and frees the mouse; Esc again resumes) | Esc |
| Capture the mouse again (after alt-tab, with no menu open) | Click in the window |
| Shoot (the knife: slash; a grenade: throw) | Left mouse button |
| Scope in two steps (Heron), stab (knife), lob (grenade) | Right mouse button |
| Next teammate (while dead in a match) | Left mouse button |
| Reload | R |
| Weapons: primary, pistol, knife, grenades (4 again: the next grenade) | 1, 2, 3, 4 |
| Last weapon / drop the gun in hand | Q / G |
| Pick up a gun: walk over it (into a free slot), or look at it and press E to swap | E |
| Buy menu (during the 15 s freeze time; any time in practice): the category's number then the item's, or click | B |
| Plant the bomb (inside a bomb site) / defuse it (next to it), on the quick maps | Hold E |
| Class menu (opens by itself at the start of a match with your two drafted classes; during freeze time, any time in Team Deathmatch and practice mode; then click a card or press 1 or 2, 1 to 4 in practice) | M |
| Scoreboard (in a match: both teams, kills, deaths, assists, damage, who is alive) | Hold Tab |
| Debug overlay (speed, jump peak, inaccuracy, recoil, last hit) | F3 |
| Developer console | Key left of 1 (`` ` ``; on Czech keyboards the key under Esc) |
| Settings menu | **Settings** in the main menu or the pause menu, or type `settings` in the console during a game; Esc or Back closes it (back to the pause menu if you came from there) |

**Console commands:** `help`, `bot_add [easy|normal|hard] [ally|enemy]` (`ally` adds a teammate on your team), `bot_kick [all]`, `bot_difficulty <level>`, `god`, `noclip`, `mp_friendlyfire [0|1]` (teammates hurt each other; off by default, then bullets pass through teammates), `map <name>` (e.g. `map comparison/trenchbroom_room`), `class [name]` (no name: list the classes; with one: take it, in a match during freeze time only), `armor [0-100] [helmet]` (set your armor), `money [amount]` (show or set your money in a match), `clear`, `settings` (opens the settings menu), `disconnect` (leaves the game for the main menu, like CS), and the settings commands (see *Settings* below). Up/down arrows recall earlier commands; the mouse wheel or Page Up / Page Down scroll back through the output.

## Weapons, money and buying (M7)

- **Every round starts with the knife and the Sparrow** (a pistol); whatever you buy or pick up lasts that round. Money carries over: $1,000 at the start of each half, $3,000 for a win, $1,500 rising to $3,000 for losses in a row, $200 a kill ($500 with the knife).
- **B** opens the buy menu during the 15 s freeze time (in practice any time, free): the category's number, then the item's, or click.
- **Pick guns up:** walk over one to take it into a free slot, or look at it and press **E** to swap. Each quick map has a **Heron** (sniper rifle) and a **Breaker** (shotgun) on gold rings.
- **Team respawn** has no money: you spawn with your class's loadout.
- The weapons' numbers are in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (4.3, 4.6, 4.10, 4.11) and in the spreadsheet **[docs/weapons.csv](docs/weapons.csv)**, exported from the data files (`tools/export_weapon_table.gd`, see CLAUDE.md).

## Settings

Your settings are saved the moment you change them and apply at once. They live in a text file you can open and edit (with the game closed), `settings.cfg` in Godot's user data folder, which on macOS is:

```
~/Library/Application Support/Godot/app_userdata/Chiip/settings.cfg
```

Open the **settings menu** with **Settings** in the main menu, or by typing `settings` in the developer console (the key left of 1) during a game, or from the pause menu (Esc). It has five tabs, and every change applies and is saved at once, with no Apply button:

- **Game:** mouse sensitivity (CS's scale: a slider and a number field you can type an exact value into), invert Y, field of view (90 across a 4:3 screen, like CS).
- **Video:** fullscreen, V-Sync, frame rate limit, pixel resolution (270 to 720 lines), palette effect, pixelated HUD.
- **Audio:** master, effects and interface volume.
- **Crosshair:** color (swatches or a `#RRGGBB` code), opacity, size, gap, thickness, outline, center dot and dynamic, with a live preview on a dark and a light background.
- **Controls:** click a slot, then press the new key or mouse button (Esc cancels, Backspace clears the slot). Every action has a primary and a secondary slot. A key belongs to one action: if it was in use, the other action loses it and the menu tells you which.

"Reset tab to defaults" puts the tab you are on back. Esc or Back closes the menu. The same settings can also be set from the console; without a value, a command shows the current one:

| Command | What it sets | Default |
|---|---|---|
| `sensitivity [0.05-10]` | Mouse sensitivity on CS's scale (your CS number feels the same) | 1.0 |
| `fov [70-110]` | Field of view the CS way, degrees across a 4:3 screen | 90 |
| `volume [0-1]` | Master volume | 1.0 |
| `fps_max [0\|30-1000]` | Frame rate limit, 0 = unlimited | 0 |
| `settings_reset` | Everything back to its default, key bindings and the remembered match setup included | |

The file also holds Y inversion, fullscreen, V-Sync, the pixel resolution (270, 360, 480, 540 or 720 lines), the palette effect, the pixelated HUD, the effects and interface volumes, the crosshair (color, length, gap, thickness, outline, dot, dynamic) the key bindings (`"key:87"` is the W key, `"mouse:1"` the left button; two per action) and, in a `[match]` section, your last match setup (mode, team sizes, difficulty, match length or kill limit, friendly fire, rotation and map). A value that is out of range is clamped and a missing or unreadable one falls back to the default, so deleting the file, or a line in it, is always safe: **delete `settings.cfg` to start from the defaults**.

## Playing with friends (M9)

One player hosts and plays, friends join, and bots fill the empty slots (D-100, D-108).

1. **Main menu → Multiplayer.** Type your name (saved for next time).
2. **The host** presses **Host game**. The lobby shows the port (26000, Quake's, unless you change it) and this Mac's LAN addresses. On a LAN that is all; over the internet the host's router must forward UDP port 26000 to the host's Mac (Steam lobbies, coming later in M9, won't need that).
3. **Friends** type the host's address and press **Join**.
4. In the lobby, click **Join Team 1 / Team 2** to pick a side (your team is blue, the other red). The host's **Match settings…** opens the usual match setup (mode, map or rotation, team sizes, bot difficulty, length, friendly fire); empty slots are bots. The host presses **Start match**, and everyone's game loads.
5. Pick your class in the first freeze time (M) as offline. **Esc** opens the menu as an overlay: the game doesn't pause online. After the match the host chooses: **Next map**, **Play again** or **Lobby**; the others can only **Leave**.

Someone who leaves during a match is taken over by a bot ("Name (bot)"); someone who joins a running match takes over a bot of their team. When the host quits, everyone goes back to the menu.

Console commands online: `status` (the session, ping, snapshot loss, prediction corrections, traffic), `net_fakelag <ms>` and `net_fakeloss <percent>` (make your connection worse on purpose, like CS's), `disconnect` (leave; for the host, end the game). Cheats (`god`, `noclip`), `mp_friendlyfire` and `map` only work offline. **F3** shows the same network lines as `status`.

To try it on one Mac, start the game twice: host in one window and join `127.0.0.1` in the other. Shortcuts skip the typing (add them after the run command's `--path`): `-- --host --name Jan --start 2` (hosts and starts the match once a second player is in the lobby) and `-- --join 127.0.0.1 --name Friend`; `--port <port>` picks another port, `--no-settings` leaves your settings file alone.

## Exporting the game

The first macOS build (D-086). One-time setup: the Godot 4.7.2 export templates are installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (in the editor: *Editor → Manage Export Templates*). Then, from the project folder:

```bash
mkdir -p builds/macos && touch builds/.gdignore
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --export-release "macOS" builds/macos/Chiip.app
```

Open `builds/macos/Chiip.app` with a double-click (it's signed ad-hoc, so on another Mac it needs right-click → *Open*). Command-line options work as for the editor build, after the app's binary: `builds/macos/Chiip.app/Contents/MacOS/Chiip -- --map res://maps/depot.tscn --respawn`. In the editor: *Project → Export…*, preset **macOS**, *Export Project*.

## Making maps with TrenchBroom

Real maps are built in **TrenchBroom**, a free brush-based map editor similar to Hammer, and imported into Godot by the func_godot addon (D-032).

**One-time setup**
1. Install TrenchBroom from https://github.com/TrenchBroom/TrenchBroom/releases (macOS arm64 build) and move `TrenchBroom.app` to Applications.
2. Chiip's game configuration is already installed in TrenchBroom. To reinstall it:

   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --quit-after 100 --script res://tools/export_trenchbroom_config.gd -- "$HOME/Library/Application Support/TrenchBroom/games/Chiip"
   ```

3. Open TrenchBroom, then *Preferences* (⌘,). Select **Chiip** in the game list and set *Game Path* to `/Users/kozeluhj/Documents/Games/Chiip`. If Chiip isn't listed, restart TrenchBroom. Without the game path, faces show missing-texture placeholders.

**Editing a map**
1. In TrenchBroom: *File → Open*, e.g. `maps/comparison/comparison_room.map`. Edit, then save (⌘S). Chiip's textures are in the texture browser.
2. Rebuild it for Godot: open the map's scene (e.g. `maps/comparison/trenchbroom_room.tscn`), select the `Map` node, click **Build Map** in the Inspector, and save. Or from the terminal:

   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --quit-after 500 --script res://tools/build_maps.gd -- res://maps/comparison/trenchbroom_room.tscn
   ```

3. Play it with `-- --map res://maps/comparison/trenchbroom_room.tscn` (see *Running the game*).

**Textures** come in sets, which TrenchBroom's texture browser shows as collections: the base set (the first eight), `industrial`, `urban`, `interior` and `nature` (D-121). They are drawn in the crew's palette by `tools/make_world_textures.py` (D-140). `industrial/chainlink` is see-through.

**A new map** can be built entirely in TrenchBroom from Chiip's kit: textures, props, lamps, and entities for spawns, bomb sites, routes and the other markers. `tools/new_map.gd` turns the `.map` into a playable scene (docs/MAPPING.md). The kit gallery (`-- --map res://maps/kit/kit_gallery.tscn`) shows everything in the kit.

**Scale (same as CS):** 1 TrenchBroom unit = 1 inch = 2.54 cm. The player is 72 units tall (54 crouched). A jump clears 57 units, a crouch-jump 75. The standard crate is 64 units. Doors are 128 units tall and 96 wide in the comparison room. A 64-pixel texture covers 64 units.

**Lighting** is real-time; the maps aren't baked (D-085). To try a bake anyway (e.g. on the comparison room): select the scene's `LightmapGI` node, click **Bake Lightmaps** in the 3D toolbar, and save. Godot can only bake from the editor.

## The UI theme

Every menu is styled by one Godot theme, `ui/chiip_theme.tres` (D-057). To see all its controls in one window (add `--resolution 1920x1080` to see it scaled for a bigger window):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip res://ui/theme_preview.tscn
```

The theme is generated from `tools/ui_palette.gd` (colors), `tools/generate_ui_icons.gd` (pixel-art icons in `assets/ui/`) and `tools/make_ui_theme.gd`. After changing one of them, run the three steps (the commands are in [CLAUDE.md](CLAUDE.md)): the icon tool, the asset import, then the theme tool.

## Python tools

The character concept art (and, from M6 task 2, the model generator) are Python scripts that run outside Godot. They use Miniconda with one environment named `chiip` (D-071). One-time setup, already done on this Mac:

1. Download the Miniconda installer for macOS (Apple silicon: `Miniconda3-latest-MacOSX-arm64.sh`) from https://repo.anaconda.com/miniconda/.
2. Install it without touching your shell profile: `bash Miniconda3-latest-MacOSX-arm64.sh -b -p ~/miniconda3`
3. Create the environment: `~/miniconda3/bin/conda create -n chiip python=3.12 numpy pillow`

Render the crew's concept sheets (line-up and 8-direction turnarounds in blue and red) into a folder outside the project:

```bash
~/miniconda3/envs/chiip/bin/python /Users/kozeluhj/Documents/Games/Chiip/tools/concept/spritegen.py --sheet --out ~/Desktop/chiip_concept
```

Leave out `--sheet` to render every animation frame and `preview.html`, a page where you can spin each class.

The crew's 3D models are generated too (D-054). After changing `tools/modelgen/`, regenerate them and let Godot import them:

```bash
~/miniconda3/envs/chiip/bin/python /Users/kozeluhj/Documents/Games/Chiip/tools/modelgen/modelgen.py all
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --import
```

To look at them on a turntable (Space pauses, arrow keys turn, T switches between your team's blue and the enemies' red, N / P play the animations):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip res://characters/crew/crew_preview.tscn
```

## Tests

Run all the automated checks with one command (no window, about a minute and a quarter in all):

```bash
cd /Users/kozeluhj/Documents/Games/Chiip && bash tools/run_tests.sh
```

It runs the twenty-four suites one after another and prints a table of how many checks passed and failed in each. It exits with the number of failed suites, so 0 means everything passed. A suite also counts as failed when it prints no PASS line or a script error, which is how a typo in a test shows up. `bash tools/run_tests.sh round ui` runs only the suites you name.

To run a single suite on its own (about a second each, the match test about twenty), use its command:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/movement_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/weapon_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/bot_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/round_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/tactics_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/ui_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/settings_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 200000 res://tests/match_test.tscn
```

The match test plays a whole 3v3 match, bots and all, through the real game scene and prints one line per round before its checks; it plays the same match every time. The tests never touch your real `settings.cfg`. The settings test prints one Godot "ConfigFile parse error" on purpose: it loads a broken file to check that the game falls back to the defaults.

The bomb test plays short bomb rounds on Depot (plant, explosion, drop and pickup, defuse):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/bomb_test.tscn
```

The sound test checks footsteps per floor, bullet impact and headshot sounds, and menu sounds on Depot:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 20000 res://tests/sound_test.tscn
```

The respawn test plays short team respawn matches on Depot (kills, respawns, spawn choice, kill limit, time limit, overtime):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/respawn_test.tscn
```

The maps test plays bot rounds on all three quick maps and takes a minute or two:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 400000 res://tests/maps_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/crew_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 200000 res://tests/class_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/zone_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/perf_test.tscn
```

The M7 suites (the arsenal's data, gear and inventory, how each gun works, grenades, money and the buy menu, bots and the arsenal) run the same way: `arsenal_test`, `gear_test`, `guns_test` and `grenade_test` with `--quit-after 60000`, `economy_test` and `botgear_test` with `--quit-after 100000`, for example:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/economy_test.tscn
```

To see the frame rate with ten animated characters, run the performance test in a window (it prints FPS after 15 s):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip --resolution 1920x1080 --quit-after 100000 res://tests/perf_test.tscn -- --window
```

## Documentation

All design, planning and technical notes live in [`docs/`](docs/):

| Document | What it contains |
|---|---|
| [PLAN.md](docs/PLAN.md) | Roadmap: milestones, tasks and current status |
| [UI_MOCKUPS.md](docs/UI_MOCKUPS.md) | The UI screens to design (in Claude Design) and the rules every mockup follows |
| [GAME_DESIGN.md](docs/GAME_DESIGN.md) | What the game is: pillars, mechanics, controls, look |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the project is built: folders, systems, code conventions |
| [DECISIONS.md](docs/DECISIONS.md) | Log of important decisions, why they were made, and open questions |
| [MAPS.md](docs/MAPS.md) | The quick maps: plans, layouts, map rules, measurements |
| [MAPPING.md](docs/MAPPING.md) | Building a map from the map kit: TrenchBroom workflow, rules, every texture, prop, lamp and entity, limits |
| [DEVLOG.md](docs/DEVLOG.md) | Diary of each work session: what changed and what's next |
| [LEARNING.md](docs/LEARNING.md) | Godot concepts learned along the way, compared to Unity |
| [CREDITS.md](docs/CREDITS.md) | Third-party assets and tools, with sources and licenses |

## How we work

- The game is built in small milestones, and each one ends with something playable.
- Every change is documented in the same step it is made. The rules are in [CLAUDE.md](CLAUDE.md).
