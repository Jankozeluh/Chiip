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
├── project.godot      Godot project file
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
│   └── props/         Reusable map objects (target dummy)
├── ui/                HUD, menus, developer console
├── systems/           Global systems (autoloads): game state, rounds, settings, console commands
├── shaders/           Shaders (grid placeholder now, retro look in M3)
└── tests/             Automated test scenes, run headless (D-018)
```

## Scenes and files

| File | What it is |
|---|---|
| `maps/test_map.tscn` | M1 movement test map and the current main scene: jump boxes (32/48/64/80 u), platform with a 25° ramp and stairs, crouch tunnel, peek walls |
| `player/player.tscn` | Player: `CharacterBody3D` with a capsule collision, a `Head` node at eye height and a `Camera3D` |
| `player/player.gd` | `Player` class: mouse look and CS-style movement |
| `ui/debug_overlay.tscn` + `.gd` | F3 readout: speed, position, jump peak, stance, shoot/aim buttons |
| `systems/physics_layers.gd` | `PhysicsLayers` constants: bit values of the named physics layers |
| `weapons/weapon_data.gd` | `WeaponData` resource: every number of a weapon (damage, fire rate, ammo, accuracy, spray pattern, recoil, sounds) |
| `weapons/rifle.tres` | The Rifle's data (AK-like) |
| `weapons/weapon.gd` | `Weapon` node: firing, ammo, reload. Signals `fired`, `ammo_changed`, `reload_started`, `reload_finished` |
| `weapons/bullet_impact.tscn` | Bullet hole (16 × 16 pixel radial gradient quad) and a burst of sparks |
| `weapons/hitbox.gd` | `Hitbox` (`Area3D`): one damage zone with its multiplier; emits `hit` |
| `maps/props/target_dummy.tscn` + `.gd` | `TargetDummy`: CS-sized, color-coded hitboxes (head red, chest blue, stomach teal, arms light blue, legs dark), floating damage numbers, running total, optional side-to-side movement |
| `weapons/rifle.tscn` | The Rifle as a scene: `Weapon` script + `rifle.tres` + audio players. Instanced in the player under `Head/Camera3D` |
| `ui/hud.tscn` + `.gd` | HUD: crosshair, weapon name ("· reloading"), ammo counter (red at ≤ 25%). Listens to the weapon's signals |
| `ui/crosshair.gd` | `Crosshair` (`Control`): CS-style crosshair drawn with `_draw()`; static or dynamic |
| `tests/movement_test.tscn` + `.gd` | Automated movement checks (D-018) |
| `shaders/prototype_grid.gdshader` | Placeholder world-space 1 m grid "developer texture" |

## Systems

| System | Purpose | Milestone | Status |
|---|---|---|---|
| Player controller | Mouse look, CS-style movement | M1 | Built: mouse look, run/walk/crouch, jump, air strafing |
| Debug overlay | Speed and position readout | M1 | Built |
| Weapon system | Hitscan, spread, recoil, ammo; stats in Resources | M2 | In progress: data, firing, ammo, reload, hitscan, impacts, accuracy, spray pattern, aim punch |
| Hitbox / damage | Hit zones, damage multipliers, armor | M2 | Built: zones and falloff (armor in M5) |
| HUD | Crosshair, ammo, later health, timer, kill feed | M2 → M5 | Built: crosshair, ammo, weapon name |
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
| `reload` | R | Player → weapon |
| `toggle_mouse` | Esc | Player (frees or captures the mouse) |
| `toggle_debug` | F3 | Debug overlay |

## How the player camera works

Physics interpolation (D-010) draws the player's body smoothly between physics ticks. If the camera were a normal child of the body, mouse look would only be applied once per tick and then smoothed, which adds a small delay. Instead:

1. Mouse movement updates two angles (`_yaw`, `_pitch`) immediately in `_unhandled_input`.
2. Each physics tick, the body turns to `_yaw`, so movement keys follow your view.
3. Each rendered frame, `_process` places the camera at the head's *interpolated* position and applies the angles directly. The camera is `top_level` (ignores its parent's transform) and has interpolation off.

## How the player and the weapon work together

- The weapon scene sits under the player's camera, so a first-person model will follow the view.
- Each physics tick the player sets `weapon.trigger_held` from the shoot button. The player processes first and its children after, so the weapon sees the new value in the same tick.
- R calls `weapon.reload()`. The weapon sets the player's top speed (`Player.get_max_speed()`).
- The click that recaptures the mouse, and clicks while the mouse is free, never fire.
- Shots start at `Player.get_eye_position()` and use `Player.get_aim_angles()`, the aim *without* recoil kick. The ray tests world + hitboxes only, so it can't hit the player's own body.
- Recoil has two parts. `Weapon._get_shot_direction()` adds the spray pattern offset to the aim. `Weapon.view_punch` (half the pattern, smoothed every frame) is added to the camera rotation in `Player._process`. The aim itself never changes, so the view returns to it as recoil wears off.
- When a ray hits a `Hitbox`, the weapon computes `damage × range_modifier^(distance / 500 units)` and calls `Hitbox.receive_hit()`, which applies the zone multiplier and emits `hit` to whoever owns the hitbox (the dummy now, bots in M4).
- Bullet holes are parented to whatever was hit, so they move with moving targets. Each weapon keeps its last 100.

## Physics layers

Named in *Project Settings → Layer Names → 3D Physics*. Code uses the bit values from `systems/physics_layers.gd` (D-022).

| Layer | Name | Bit value | Used by |
|---|---|---|---|
| 1 | world | 1 | Map geometry |
| 2 | player | 2 | Player body (collides with world and bots: mask 5) |
| 3 | bots | 4 | Bot bodies, target dummies |
| 4 | hitboxes | 8 | Head / chest / stomach / arm / leg zones (`Area3D`) that bullets hit |
| 5 | triggers | 16 | Buy zones, bombsites |

Bullets test **world + hitboxes** (mask 9) only.

## Testing

Run all movement checks from the project folder:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 res://tests/movement_test.tscn
```

`--headless` means no window, and `--fixed-fps 128` runs exactly one physics tick per frame as fast as possible. Each check prints PASS or FAIL, and the exit code is the number of failures. When a test file uses a `class_name` for the first time, run `Godot --headless --path . --import` first so Godot knows the class.

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
