# Chiip

A single-player tactical FPS in the spirit of Counter-Strike, played against bots, with the look of a 1990s Quake-era shooter. Built with Godot 4.7.2.

> **Status:** Milestones 1 and 2 done: CS-style movement and a rifle with CS-like recoil on a test map with a shooting range. Next: M3, the retro look. Progress is tracked in [docs/PLAN.md](docs/PLAN.md).

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

## Tests

Automated checks run without a window in about a second each:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/movement_test.tscn
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/kozeluhj/Documents/Games/Chiip --fixed-fps 128 res://tests/weapon_test.tscn
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

## How we work

- The game is built in small milestones, and each one ends with something playable.
- Every change is documented in the same step it is made. The rules are in [CLAUDE.md](CLAUDE.md).
