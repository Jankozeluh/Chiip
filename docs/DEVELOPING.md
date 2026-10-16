# Developing Chiip

> How to run, test, build and extend the game. The player's guide (download, controls, playing with friends) is the [README](../README.md). Last updated: 2026-10-16

The commands below use two shell variables, so they work from any folder and on any machine:

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot   # your Godot 4.7.2 binary (standard edition)
export PROJECT="$HOME/path/to/Chiip"                          # the folder that holds project.godot
```

(On Windows or Linux, point `GODOT` at that platform's Godot 4.7.2 binary. Everything except the macOS-specific paths works the same.)

## Requirements

- Godot **4.7.2**, standard edition (GDScript). The .NET edition is not needed.
- Development is done on macOS. Builds for Windows, Linux and macOS come from the export presets (see *Exporting the game*).


## Running the game

**From the Godot editor** (recommended):
1. Open Godot. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
2. Press **F5** (or the ▶ button at the top right) to play. The main menu opens; the player's guide in the [README](../README.md) describes it, the modes, the controls and online play. **Practice** (or `-- --practice`, below) opens the **Shooting Range**: targets at 5, 10, 20 and 40 m, a stand for every gun and grenade, and no bots until the console adds them (`bot_add [easy|normal|hard] [ally|enemy]`, `bot_kick [all]`, `bot_difficulty <level>`).

**From the terminal**, without opening the editor (this opens the main menu):

```bash
"$GODOT" --path "$PROJECT"
```

To skip the menu and start a default 3v3 match on the test map at once (handy for development; it ignores your saved match setup), add `-- --match`:

```bash
"$GODOT" --path "$PROJECT" -- --match
```

To play the three quick maps in rotation from the terminal (the end screen then offers **Next map**), add `-- --match --rotation` (and `--respawn` for team respawn):

```bash
"$GODOT" --path "$PROJECT" -- --match --rotation
```

For the **team respawn** mode (like Call of Duty's Team Deathmatch: respawn after 3 s, first team to 50 kills wins; bots hunt in pairs), add `-- --respawn`, e.g. on Depot:

```bash
"$GODOT" --path "$PROJECT" -- --map res://maps/depot.tscn --respawn
```

For practice on the Shooting Range (also straight into the game), add `-- --practice` (with `--map`, practice on that map instead, with two bots):

```bash
"$GODOT" --path "$PROJECT" -- --practice
```

**Maps:** the three quick maps **Depot**, **Square** and **Spillway** (M8 layouts, dressed with the map kit in M10, see [docs/MAPS.md](MAPS.md)), the **Shooting Range** (practice) and the kit gallery (`-- --map res://maps/kit/kit_gallery.tscn`, everything in the map kit). The old test map is hidden from match setup and the console's map list: it is the automated tests' map, and still loads with `map test_map`. In the game, open the console and type `map depot`, `map square` or `map spillway`. On these maps a match is played as **bomb rounds**: one attacker carries the bomb; hold **E** inside site A or B to plant it, and as a defender hold E next to it to defuse (docs/GAME_DESIGN.md, 4.7).

To play a different map (also straight into the game, as a match where the map allows it), add `-- --map` and the map scene, e.g. `-- --map res://maps/depot.tscn`, or the TrenchBroom comparison room:

```bash
"$GODOT" --path "$PROJECT" -- --map res://maps/comparison/trenchbroom_room.tscn
```


## Exporting the game

Builds are made **only when asked for** (CLAUDE.md), for a release (M12, D-172). `export_presets.cfg` has three presets: **Windows** (x86_64, one `.exe` with the game's data inside), **Linux** (x86_64, one file) and **macOS** (a universal `.app`, ad-hoc signed). Each lists the licence files in its include filter (so they sit in the game's data and **Settings → Licences** can show them) and leaves `tests/` and `tools/` out. One-time setup: the Godot 4.7.2 export templates are installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (in the editor: *Editor → Manage Export Templates*). Then, from the project folder:

```bash
mkdir -p builds/windows builds/linux builds/macos && touch builds/.gdignore
```

```bash
"$GODOT" --headless --path "$PROJECT" --export-release "Windows" builds/windows/Chiip.exe
"$GODOT" --headless --path "$PROJECT" --export-release "Linux" builds/linux/Chiip.x86_64
"$GODOT" --headless --path "$PROJECT" --export-release "macOS" builds/macos/Chiip.app
```

Smoke-test the Mac build headless: `builds/macos/Chiip.app/Contents/MacOS/Chiip --headless --quit-after 900 -- --map res://maps/depot.tscn`. Command-line options work as for the editor build, after the app's binary. In the editor: *Project → Export…*, pick a preset, *Export Project*.

Then `bash tools/package_release.sh` makes the three zip files for the GitHub Release in `builds/release/` (`Chiip-<version>-windows-x86_64.zip`, `…-linux-x86_64.zip`, `…-macos-universal.zip`), each a folder with the game and `LICENSE`, `LICENSE-ASSETS` and `THIRD_PARTY_NOTICES.md` next to it. The version is `config/version` in `project.godot`; the Mac preset's `short_version` and `version` must match it (`release_test` checks).

The builds are not signed: the README tells players how to get past the warnings (macOS Gatekeeper, Windows SmartScreen). The Windows `.exe` has Godot's default icon, because setting one needs `rcedit`, a download that has not been approved. Nothing in a preset may hold a password or a signing identity (`release_test` checks); Godot keeps those in `export_credentials.cfg`, which is git-ignored.

## Making maps with TrenchBroom

Real maps are built in **TrenchBroom**, a free brush-based map editor similar to Hammer, and imported into Godot by the func_godot addon (D-032).

**One-time setup**
1. Install TrenchBroom from https://github.com/TrenchBroom/TrenchBroom/releases (macOS arm64 build) and move `TrenchBroom.app` to Applications.
2. Chiip's game configuration is already installed in TrenchBroom. To reinstall it:

   ```bash
   "$GODOT" --headless --path "$PROJECT" --quit-after 100 --script res://tools/export_trenchbroom_config.gd -- "$HOME/Library/Application Support/TrenchBroom/games/Chiip"
   ```

3. Open TrenchBroom, then *Preferences* (⌘,). Select **Chiip** in the game list and set *Game Path* to your project folder (`$PROJECT`). If Chiip isn't listed, restart TrenchBroom. Without the game path, faces show missing-texture placeholders.

**Editing a map**
1. In TrenchBroom: *File → Open*, e.g. `maps/comparison/comparison_room.map`. Edit, then save (⌘S). Chiip's textures are in the texture browser.
2. Rebuild it for Godot: open the map's scene (e.g. `maps/comparison/trenchbroom_room.tscn`), select the `Map` node, click **Build Map** in the Inspector, and save. Or from the terminal:

   ```bash
   "$GODOT" --headless --path "$PROJECT" --quit-after 500 --script res://tools/build_maps.gd -- res://maps/comparison/trenchbroom_room.tscn
   ```

3. Play it with `-- --map res://maps/comparison/trenchbroom_room.tscn` (see *Running the game*).

**Textures** come in sets, which TrenchBroom's texture browser shows as collections: the base set (the first eight), `industrial`, `urban`, `interior` and `nature` (D-121). They are drawn in the crew's palette by `tools/make_world_textures.py` (D-140). `industrial/chainlink` is see-through.

**A new map** can be built entirely in TrenchBroom from Chiip's kit: textures, props, lamps, and entities for spawns, bomb sites, routes and the other markers. `tools/new_map.gd` turns the `.map` into a playable scene (docs/MAPPING.md). The kit gallery (`-- --map res://maps/kit/kit_gallery.tscn`) shows everything in the kit.

**Scale (same as CS):** 1 TrenchBroom unit = 1 inch = 2.54 cm. The player is 72 units tall (54 crouched). A jump clears 57 units, a crouch-jump 75. The standard crate is 64 units. Doors are 128 units tall and 96 wide in the comparison room. A 64-pixel texture covers 64 units.

**Lighting** is real-time; the maps aren't baked (D-085). To try a bake anyway (e.g. on the comparison room): select the scene's `LightmapGI` node, click **Bake Lightmaps** in the 3D toolbar, and save. Godot can only bake from the editor.


## The UI theme

Every menu is styled by one Godot theme, `ui/chiip_theme.tres` (D-057). To see all its controls in one window (add `--resolution 1920x1080` to see it scaled for a bigger window):

```bash
"$GODOT" --path "$PROJECT" res://ui/theme_preview.tscn
```

The theme is generated from `tools/ui_palette.gd` (colors), `tools/generate_ui_icons.gd` (pixel-art icons in `assets/ui/`) and `tools/make_ui_theme.gd`. After changing one of them, run the three steps (the commands are in [CLAUDE.md](../CLAUDE.md)): the icon tool, the asset import, then the theme tool.


## Python tools

The character concept art (and, from M6 task 2, the model generator) are Python scripts that run outside Godot. They use Miniconda with one environment named `chiip` (D-071). One-time setup, already done on this Mac:

1. Download the Miniconda installer for macOS (Apple silicon: `Miniconda3-latest-MacOSX-arm64.sh`) from https://repo.anaconda.com/miniconda/.
2. Install it without touching your shell profile: `bash Miniconda3-latest-MacOSX-arm64.sh -b -p ~/miniconda3`
3. Create the environment: `~/miniconda3/bin/conda create -n chiip python=3.12 numpy pillow`

Render the crew's concept sheets (line-up and 8-direction turnarounds in blue and red) into a folder outside the project:

```bash
~/miniconda3/envs/chiip/bin/python "$PROJECT/tools/concept/spritegen.py" --sheet --out ~/Desktop/chiip_concept
```

Leave out `--sheet` to render every animation frame and `preview.html`, a page where you can spin each class.

The crew's 3D models are generated too (D-054). After changing `tools/modelgen/`, regenerate them and let Godot import them:

```bash
~/miniconda3/envs/chiip/bin/python "$PROJECT/tools/modelgen/modelgen.py" all
```

```bash
"$GODOT" --headless --path "$PROJECT" --import
```

To look at them on a turntable (Space pauses, arrow keys turn, T switches between your team's blue and the enemies' red, N / P play the animations):

```bash
"$GODOT" --path "$PROJECT" res://characters/crew/crew_preview.tscn
```


## Tests

Run all the automated checks with one command (no window, about a minute and a quarter in all):

```bash
cd "$PROJECT" && bash tools/run_tests.sh
```

It runs the thirty-four suites one after another and prints a table of how many checks passed and failed in each. It exits with the number of failed suites, so 0 means everything passed. A suite also counts as failed when it prints no PASS line or a script error, which is how a typo in a test shows up. `bash tools/run_tests.sh round ui` runs only the suites you name.

To run a single suite on its own (about a second each, the match test about twenty), use its command:

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 res://tests/movement_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 res://tests/weapon_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 res://tests/bot_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 res://tests/round_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 res://tests/tactics_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 60000 res://tests/ui_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 60000 res://tests/settings_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 200000 res://tests/match_test.tscn
```

The match test plays a whole 3v3 match, bots and all, through the real game scene and prints one line per round before its checks; it plays the same match every time. The tests never touch your real `settings.cfg`. The settings test prints one Godot "ConfigFile parse error" on purpose: it loads a broken file to check that the game falls back to the defaults.

The bomb test plays short bomb rounds on Depot (plant, explosion, drop and pickup, defuse):

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 100000 res://tests/bomb_test.tscn
```

The sound test checks footsteps per floor, bullet impact and headshot sounds, and menu sounds on Depot:

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 20000 res://tests/sound_test.tscn
```

The respawn test plays short team respawn matches on Depot (kills, respawns, spawn choice, kill limit, time limit, overtime):

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 100000 res://tests/respawn_test.tscn
```

The maps test plays bot rounds on all three quick maps and takes a minute or two:

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 400000 res://tests/maps_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 60000 res://tests/crew_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 200000 res://tests/class_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 60000 res://tests/zone_test.tscn
```

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 100000 res://tests/perf_test.tscn
```

The M7 suites (the arsenal's data, gear and inventory, how each gun works, grenades, money and the buy menu, bots and the arsenal) run the same way: `arsenal_test`, `gear_test`, `guns_test` and `grenade_test` with `--quit-after 60000`, `economy_test` and `botgear_test` with `--quit-after 100000`, for example:

```bash
"$GODOT" --headless --path "$PROJECT" --fixed-fps 128 --quit-after 100000 res://tests/economy_test.tscn
```

To see the frame rate with ten animated characters, run the performance test in a window (it prints FPS after 15 s):

```bash
"$GODOT" --path "$PROJECT" --resolution 1920x1080 --quit-after 100000 res://tests/perf_test.tscn -- --window
```


## Documentation

All design, planning and technical notes live in [`docs/`]():

| Document | What it contains |
|---|---|
| [PLAN.md](PLAN.md) | Roadmap: milestones, tasks and current status |
| [UI_MOCKUPS.md](UI_MOCKUPS.md) | The UI screens to design (in Claude Design) and the rules every mockup follows |
| [GAME_DESIGN.md](GAME_DESIGN.md) | What the game is: pillars, mechanics, controls, look |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the project is built: folders, systems, code conventions |
| [DECISIONS.md](DECISIONS.md) | Log of important decisions, why they were made, and open questions |
| [MAPS.md](MAPS.md) | The quick maps: plans, layouts, map rules, measurements |
| [MAPPING.md](MAPPING.md) | Building a map from the map kit: TrenchBroom workflow, rules, every texture, prop, lamp and entity, limits |
| [DEVLOG.md](DEVLOG.md) | Diary of each work session: what changed and what's next |
| [LEARNING.md](LEARNING.md) | Godot concepts learned along the way, compared to Unity |
| [CREDITS.md](CREDITS.md) | Third-party assets and tools, with sources and licenses |


## How we work

- The game is built in small milestones, and each one ends with something playable.
- Every change is documented in the same step it is made. The rules are in [CLAUDE.md](../CLAUDE.md).
