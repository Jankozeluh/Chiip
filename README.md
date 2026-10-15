# Chiip

A single-player tactical FPS in the spirit of Counter-Strike, played against bots, with the look of a 1990s Quake-era shooter. Built with Godot 4.7.2.

> **Status:** M1–M4 done (CS-style movement, a rifle with CS-like recoil, the retro look, bots). M5 (rounds & game flow) in progress: teams with blue/red colors, spawn ends and friendly fire are in (task 1 of 13); two bots still fight you on the test map; see the console commands below. Progress is tracked in [docs/PLAN.md](docs/PLAN.md).

## Requirements

- Godot **4.7.2**, standard edition (GDScript). The .NET edition is not needed.
- macOS for development. Other platforms can be added later through Godot's export.

## Running the game

**From the Godot editor** (recommended):
1. Open Godot. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
2. Press **F5** (or the ▶ button at the top right) to play. You start on the shooting range of the test map; turn around for the movement course.

**From the terminal**, without opening the editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip
```

To play a different map, add `-- --map` and the map scene, e.g. the TrenchBroom comparison room:

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
| Free / capture the mouse | Esc / click |
| Shoot | Left mouse button |
| Reload | R |
| Debug overlay (speed, jump peak, inaccuracy, recoil, last hit) | F3 |
| Developer console | Key left of 1 (`` ` ``; on Czech keyboards the key under Esc) |

**Console commands:** `help`, `bot_add [easy|normal|hard] [ally|enemy]` (`ally` adds a teammate on your team), `bot_kick [all]`, `bot_difficulty <level>`, `god`, `noclip`, `mp_friendlyfire [0|1]` (teammates hurt each other; off by default, then bullets pass through teammates), `map <name>` (e.g. `map comparison/trenchbroom_room`), `clear`. Up/down arrows recall earlier commands.

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

**Scale (same as CS):** 1 TrenchBroom unit = 1 inch = 2.54 cm. The player is 72 units tall (54 crouched). A jump clears 57 units, a crouch-jump 75. The standard crate is 64 units. Doors are 128 units tall and 96 wide in the comparison room. A 64-pixel texture covers 64 units.

**Baked lighting (M8):** select the scene's `LightmapGI` node, click **Bake Lightmaps** in the 3D toolbar, and save. Godot can only bake from the editor.

## Tests

Automated checks run without a window in about a second each:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/movement_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/weapon_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/bot_test.tscn
```

## Documentation

All design, planning and technical notes live in [`docs/`](docs/):

| Document | What it contains |
|---|---|
| [PLAN.md](docs/PLAN.md) | Roadmap: milestones, tasks and current status |
| [GAME_DESIGN.md](docs/GAME_DESIGN.md) | What the game is: pillars, mechanics, controls, look |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the project is built: folders, systems, code conventions |
| [DECISIONS.md](docs/DECISIONS.md) | Log of important decisions, why they were made, and open questions |
| [DEVLOG.md](docs/DEVLOG.md) | Diary of each work session: what changed and what's next |
| [LEARNING.md](docs/LEARNING.md) | Godot concepts learned along the way, compared to Unity |
| [CREDITS.md](docs/CREDITS.md) | Third-party assets and tools, with sources and licenses |

## How we work

- The game is built in small milestones, and each one ends with something playable.
- Every change is documented in the same step it is made. The rules are in [CLAUDE.md](CLAUDE.md).
