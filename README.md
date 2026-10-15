# Chiip

A single-player tactical FPS in the spirit of Counter-Strike, played against bots, with the look of a 1990s Quake-era shooter. Built with Godot 4.7.2.

> **Status:** M1–M4 done (CS-style movement, a rifle with CS-like recoil, the retro look, bots). M5 (rounds & game flow) in progress: teams, spawns, friendly fire, rounds, the match flow, bots that attack and defend, spectating a teammate after you die, the round HUD (timer, score, players alive, kill feed, round banners) and a hold-Tab scoreboard are in (tasks 1–7 of 13), so F5 starts a 3v3 match to 5 rounds won; menus and settings follow. Progress is tracked in [docs/PLAN.md](docs/PLAN.md).

## Requirements

- Godot **4.7.2**, standard edition (GDScript). The .NET edition is not needed.
- macOS for development. Other platforms can be added later through Godot's export.

## Running the game

**From the Godot editor** (recommended):
1. Open Godot. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
2. Press **F5** (or the ▶ button at the top right) to play. A 3v3 match starts on the test map: you and two bot teammates (blue) against three bots (red). After 5 s of freeze time the round goes live; eliminate the other team, or hold out until time runs out if your team defends.
   The top bar shows the score (yours blue on the left, theirs red), the round timer and who is alive; the kill feed is at the top right.
   If you die, you watch a living teammate through their eyes until the next round (left click for the next teammate).
   A match is first to 5 rounds; the sides swap at half time (after round 4), and when a team wins its 5th round an end screen shows Victory or Defeat, the score and a scoreboard, with **Play again** and **Quit** buttons.
3. For the old bot arena without rounds (bots respawn; good for warm-ups and the shooting range), run with `-- --practice` (see below).

**From the terminal**, without opening the editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip
```

For the **team respawn** mode (like Call of Duty's Team Deathmatch: respawn after 3 s, first team to 50 kills wins; bots hunt in pairs), add `-- --respawn`, e.g. on Depot:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --map res://maps/depot.tscn --respawn
```

For practice mode, add `-- --practice`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --practice
```

**Maps:** the three quick maps **Depot**, **Square** and **Spillway** (M8 blockouts, see [docs/MAPS.md](docs/MAPS.md)), and the test map (the default). In the game, open the console and type `map depot`, `map square` or `map spillway`. On these maps a match is played as **bomb rounds**: one attacker carries the bomb; hold **E** inside site A or B to plant it, and as a defender hold E next to it to defuse (docs/GAME_DESIGN.md, 4.7).

To play a different map from the start, add `-- --map` and the map scene, e.g. `-- --map res://maps/depot.tscn`, or the TrenchBroom comparison room:

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
| Next teammate (while dead in a match) | Left mouse button |
| Reload | R |
| Plant the bomb (inside a bomb site) / defuse it (next to it), on the quick maps | Hold E |
| Scoreboard (in a match: both teams, kills, deaths, assists, damage, who is alive) | Hold Tab |
| Debug overlay (speed, jump peak, inaccuracy, recoil, last hit) | F3 |
| Developer console | Key left of 1 (`` ` ``; on Czech keyboards the key under Esc) |

**Console commands:** `help`, `bot_add [easy|normal|hard] [ally|enemy]` (`ally` adds a teammate on your team), `bot_kick [all]`, `bot_difficulty <level>`, `god`, `noclip`, `mp_friendlyfire [0|1]` (teammates hurt each other; off by default, then bullets pass through teammates), `map <name>` (e.g. `map depot` or `map comparison/trenchbroom_room`), `clear`. Up/down arrows recall earlier commands.

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

## The UI theme

Every menu is styled by one Godot theme, `ui/chiip_theme.tres` (D-057). To see all its controls in one window (add `--resolution 1920x1080` to see it scaled for a bigger window):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip res://ui/theme_preview.tscn
```

The theme is generated from `tools/ui_palette.gd` (colors), `tools/generate_ui_icons.gd` (pixel-art icons in `assets/ui/`) and `tools/make_ui_theme.gd`. After changing one of them, run the three steps (the commands are in [CLAUDE.md](CLAUDE.md)): the icon tool, the asset import, then the theme tool.

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

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/round_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/tactics_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/ui_test.tscn
```

The bomb test plays short bomb rounds on Depot (plant, explosion, drop and pickup, defuse):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/bomb_test.tscn
```

The respawn test plays short team respawn matches on Depot (kills, respawns, spawn choice, kill limit, time limit, overtime):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 100000 res://tests/respawn_test.tscn
```

The maps test plays bot rounds on all three quick maps and takes a minute or two:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 400000 res://tests/maps_test.tscn
```

## Documentation

All design, planning and technical notes live in [`docs/`](docs/):

| Document | What it contains |
|---|---|
| [PLAN.md](docs/PLAN.md) | Roadmap: milestones, tasks and current status |
| [GAME_DESIGN.md](docs/GAME_DESIGN.md) | What the game is: pillars, mechanics, controls, look |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the project is built: folders, systems, code conventions |
| [DECISIONS.md](docs/DECISIONS.md) | Log of important decisions, why they were made, and open questions |
| [MAPS.md](docs/MAPS.md) | The quick maps: plans, layouts, map rules, measurements |
| [DEVLOG.md](docs/DEVLOG.md) | Diary of each work session: what changed and what's next |
| [LEARNING.md](docs/LEARNING.md) | Godot concepts learned along the way, compared to Unity |
| [CREDITS.md](docs/CREDITS.md) | Third-party assets and tools, with sources and licenses |

## How we work

- The game is built in small milestones, and each one ends with something playable.
- Every change is documented in the same step it is made. The rules are in [CLAUDE.md](CLAUDE.md).
