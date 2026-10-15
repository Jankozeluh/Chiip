# Chiip — Architecture

> How the project is organized and which rules the code follows. Updated whenever a folder, system or convention is added.
>
> Last updated: 2026-10-15. This is the planned structure; no code exists yet.

## Engine

- Godot 4.7.2, standard edition, scripted in GDScript.
- Renderer: to be decided in M1 (see [DECISIONS.md](DECISIONS.md)).
- Units: 1 Godot unit = 1 metre. Godot's Y axis points up and "forward" is −Z.

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
