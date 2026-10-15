# Chiip

A single-player tactical FPS in the spirit of Counter-Strike, played against bots, with the look of a 1990s Quake-era shooter. Built with Godot 4.7.2.

> **Status:** M1–M4 done (CS-style movement, a rifle with CS-like recoil, the retro look, bots). M5 (rounds & game flow) in progress: teams, spawns, friendly fire, rounds, the match flow, bots that attack and defend, spectating a teammate after you die, the round HUD (timer, score, players alive, kill feed, round banners), a hold-Tab scoreboard, the UI theme, saved settings (sensitivity, field of view, video, audio, crosshair, key bindings) the settings menu, the main menu with match setup (Play, Practice, Settings, Quit over a camera flight) and the pause menu (Esc: Resume, Settings, Leave match) are in (tasks 1–12 of 13), so F5 opens the main menu and Play starts a match you set up. Progress is tracked in [docs/PLAN.md](docs/PLAN.md).

## Requirements

- Godot **4.7.2**, standard edition (GDScript). The .NET edition is not needed.
- macOS for development. Other platforms can be added later through Godot's export.

## Running the game

**From the Godot editor** (recommended):
1. Open Godot. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
2. Press **F5** (or the ▶ button at the top right) to play. The **main menu** opens over a slow camera flight across the test map: **Play**, **Practice**, **Settings** and **Quit** (Esc closes match setup and the settings menu; on the main page it does nothing).
   **Play** opens match setup: the size of your team and of the enemy team (1–5 each, you included in yours), the bots' difficulty (Easy, Normal, Hard), the match length (first to 5, 10 or 15 rounds), friendly fire and the map. The defaults are a 3v3 match, Normal bots, first to 5, friendly fire off, on the test map, and the game remembers your last choices. **Start** begins the match: you and your bot teammates (blue) against the bots (red). After 5 s of freeze time the round goes live; eliminate the other team, or hold out until time runs out if your team defends.
   The top bar shows the score (yours blue on the left, theirs red), the round timer and who is alive; the kill feed is at the top right.
   If you die, you watch a living teammate through their eyes until the next round (left click for the next teammate).
   A match is first to 5 rounds; the sides swap at half time (after round 4), and when a team wins its 5th round an end screen shows Victory or Defeat, the score and a scoreboard, with **Play again** and **Main menu** buttons.
   **Esc** during a game opens the **pause menu**, which pauses everything (the round timer, the bots, the sounds): **Resume**, **Settings** and **Leave match** (back to the main menu). Esc again resumes.
3. **Practice** in the main menu is the old bot arena without rounds (bots respawn; good for warm-ups and the shooting range), with the bots' difficulty you last chose in match setup. To leave a game for the menu, use the end screen's **Main menu** button or type `disconnect` in the console.

**From the terminal**, without opening the editor (this opens the main menu):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip
```

To skip the menu and start a default 3v3 match on the test map at once (handy for development; it ignores your saved match setup), add `-- --match`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --match
```

For practice mode (also straight into the game), add `-- --practice`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip -- --practice
```

To play a different map (also straight into the game, as a match where the map allows it), add `-- --map` and the map scene, e.g. the TrenchBroom comparison room:

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
| Shoot | Left mouse button |
| Next teammate (while dead in a match) | Left mouse button |
| Reload | R |
| Scoreboard (in a match: both teams, kills, deaths, assists, damage, who is alive) | Hold Tab |
| Debug overlay (speed, jump peak, inaccuracy, recoil, last hit) | F3 |
| Developer console | Key left of 1 (`` ` ``; on Czech keyboards the key under Esc) |
| Settings menu | **Settings** in the main menu or the pause menu, or type `settings` in the console during a game; Esc or Back closes it (back to the pause menu if you came from there) |

**Console commands:** `help`, `bot_add [easy|normal|hard] [ally|enemy]` (`ally` adds a teammate on your team), `bot_kick [all]`, `bot_difficulty <level>`, `god`, `noclip`, `mp_friendlyfire [0|1]` (teammates hurt each other; off by default, then bullets pass through teammates), `map <name>` (e.g. `map comparison/trenchbroom_room`), `clear`, `settings` (opens the settings menu), `disconnect` (leaves the game for the main menu, like CS), and the settings commands (see *Settings* below). Up/down arrows recall earlier commands; the mouse wheel or Page Up / Page Down scroll back through the output.

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

The file also holds Y inversion, fullscreen, V-Sync, the pixel resolution (270, 360, 480, 540 or 720 lines), the palette effect, the pixelated HUD, the effects and interface volumes, the crosshair (color, length, gap, thickness, outline, dot, dynamic) the key bindings (`"key:87"` is the W key, `"mouse:1"` the left button; two per action) and, in a `[match]` section, your last match setup (team sizes, difficulty, match length, friendly fire and map). A value that is out of range is clamped and a missing or unreadable one falls back to the default, so deleting the file, or a line in it, is always safe: **delete `settings.cfg` to start from the defaults**.

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

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 --quit-after 60000 res://tests/settings_test.tscn
```

The tests never touch your real `settings.cfg`. The settings test prints one Godot "ConfigFile parse error" on purpose: it loads a broken file to check that the game falls back to the defaults.

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
