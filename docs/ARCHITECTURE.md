# Chiip — Architecture

> How the project is organized and which rules the code follows. Updated whenever a folder, system or convention is added.
>
> Last updated: 2026-10-15. The Godot project exists; the folders below are created, systems are added milestone by milestone.

## Engine

- Godot 4.7.2, standard edition, scripted in GDScript.
- Units: 1 Godot unit = 1 metre. Godot's Y axis points up and "forward" is −Z.

## Key project settings

Stored in `project.godot`. The reasons are in [DECISIONS.md](DECISIONS.md).

| Setting | Value | Decision |
|---|---|---|
| Renderer | Forward+ | D-008 |
| 3D physics engine | Jolt Physics | D-009 |
| Physics ticks per second | 128 | D-010 |
| Physics interpolation | On (jitter fix 0) | D-010 |
| Default gravity | 20.32 m/s² (CS `sv_gravity 800`) | D-011 |
| Window size | 1280 × 720 | — |

## Folder structure (planned)

The project is organized **by feature**: a scene and its script sit in the same folder. Unity projects often split by type instead, with separate Scripts/ and Prefabs/ folders.

```
Chiip/
├── project.godot      Godot project file (created in M1)
├── README.md          Start here
├── CLAUDE.md          Working rules for Claude, including documentation rules
├── docs/              All documentation
├── addons/            Third-party Godot plugins only
├── assets/            Shared raw assets
│   ├── textures/
│   ├── models/
│   ├── sounds/
│   └── fonts/
├── player/            Player scene, movement, camera
├── weapons/           Weapon logic, weapon data files (.tres), weapon scenes
├── bots/              Bot scene, AI, state machine
├── maps/              Test maps and playable maps
├── ui/                HUD, menus, developer console
├── systems/           Global systems (autoloads): game state, rounds, settings, console commands
└── shaders/           Shaders for the retro look
```

## Systems

| System | Purpose | Milestone | Status |
|---|---|---|---|
| Player controller | Mouse look, CS-style movement | M1 | Planned |
| Debug overlay | Speed and position readout | M1 | Planned |
| Weapon system | Hitscan, spread, recoil, ammo; stats in Resources | M2 | Planned |
| Hitbox / damage | Hit zones, damage multipliers, armor | M2 | Planned |
| HUD | Crosshair, ammo, later health, timer, kill feed | M2 → M5 | Planned |
| Retro rendering | Low-res output, pixel filtering, palette | M3 | Planned |
| Bot AI | Navigation, perception, state machine, aim | M4 | Planned |
| Developer console | `bot_add`, `noclip` and similar commands | M4 | Planned |
| Round manager | Phases, timer, win conditions, match score | M5 | Planned |
| Settings | Sensitivity, FOV, crosshair, audio, keys; saved to disk | M5 | Planned |
| Economy | Money, rewards, buy menu | M6 | Planned |
| Bomb | Plant, defuse, explosion | M7 | Planned |

## Input actions

Defined in *Project → Project Settings → Input Map* (stored in `project.godot`). Keys are bound by physical position (D-012). Code only uses action names, never raw keys.

| Action | Default binding | Used by |
|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D | Player |
| `jump` | Space, mouse wheel down | Player |
| `crouch` | Ctrl | Player |
| `walk` | Shift | Player |
| `shoot` / `aim` | Left / right mouse button | Debug overlay now, weapons from M2 |
| `toggle_mouse` | Esc | Player (frees or captures the mouse) |
| `toggle_debug` | F3 | Debug overlay |

## Physics layers (planned, finalized in M2)

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Map geometry |
| 2 | player | Player body |
| 3 | bots | Bot bodies |
| 4 | hitboxes | Head / chest / stomach / leg zones that bullets hit |
| 5 | triggers | Buy zones, bombsites |

## Naming conventions

These follow the official Godot style guide.

| Thing | Style | Example |
|---|---|---|
| Files and folders | snake_case | `player_movement.gd`, `test_map.tscn` |
| Node names | PascalCase | `Player`, `HeadCamera` |
| Classes (`class_name`) | PascalCase | `WeaponData` |
| Functions and variables | snake_case | `apply_friction()`, `max_speed` |
| Constants | CONSTANT_CASE | `GRAVITY` |
| Signals | snake_case, past tense | `weapon_fired`, `round_ended` |

## Code rules

- **Static typing everywhere**, e.g. `var speed: float = 6.0` and typed function signatures. Godot then catches mistakes early and autocomplete works better.
- **Documented code.** Every script starts with a `##` doc comment that explains its purpose. Exported variables and public functions get `##` comments too. Godot shows these in its built-in help (F1), so the documentation is visible inside the editor.
- **No magic numbers.** Gameplay values are `@export` variables or stored in Resource data files, so they can be tuned in the editor.
- **Signals for "something happened"** (e.g. `died`, `round_ended`), and direct function calls for "do this".
- **Keep multiplayer possible.** Keep player input separate from the simulation that uses it, and avoid global state where it isn't needed.
