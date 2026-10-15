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
├── main.tscn / .gd    The game's root scene: pixelated world + HUD
├── README.md          Start here
├── CLAUDE.md          Working rules for Claude, including documentation rules
├── docs/              All documentation
├── addons/            Third-party Godot plugins only (func_godot)
├── assets/            Shared raw assets
│   ├── textures/      Retro 64 × 64 textures (sources in docs/CREDITS.md)
│   ├── materials/     One material per texture, world triplanar (for CSG geometry)
│   ├── environments/  Shared sky / fog / ambient settings
│   ├── models/
│   ├── sounds/        Weapon sounds (generated placeholders for now, D-020)
│   └── fonts/         Silkscreen pixel font (+ its OFL license text)
├── characters/        Shared Character (movement + CS rules), input commands, controller base
├── player/            The player: a Character variant with keyboard/mouse controller and camera
├── weapons/           Weapon logic, weapon data files (.tres), weapon scenes
├── bots/              Bot scene (a Character variant) and its AI controller
├── maps/              Test maps and playable maps
│   ├── comparison/    M3: the same room built with CSG and with TrenchBroom
│   └── props/         Reusable map objects (target dummy)
├── ui/                HUD, menus, developer console
├── systems/           Global systems (autoloads): game state, rounds, settings, console commands
├── shaders/           Shaders: palette effect, grid placeholder for blockouts
├── tests/             Automated test scenes, run headless (D-018)
└── tools/             One-off tool scripts run from the command line (not part of the game)
```

## Scenes and files

| File | What it is |
|---|---|
| `main.tscn` + `main.gd` | Root (main) scene. Loads the map from `map_scene` (default `maps/test_map.tscn`, or `-- --map <scene>` on the command line), puts it in the world viewport and hands its `Player` to the HUD and overlay. The world (test map + player) runs inside a `SubViewport` rendered at `pixel_height` (360) lines and scaled up with nearest filtering; the HUD and debug overlay sit on top. `pixelate_hud` switches to rendering the whole window at the low resolution |
| `shaders/palette_limit.gdshader` | Optional retro color limit for the world image: 12 shades per channel with 4 × 4 ordered (Bayer) dithering. Drawn by a full-screen `ColorRect` in `World/SubViewport/PaletteEffect`, switched by `Main.palette_effect` |
| `ui/ui_scale.gd` | `UiScale.apply()`: scales a Control's font, outline and position for the current UI resolution |
| `assets/environments/cool_daylight.tres` | The shared `Environment`: blue sky with a grey-blue horizon, ambient light, cool haze, tonemapping and color adjustments (D-031) |
| `assets/materials/map_default.tres` | Base material for TrenchBroom maps: func_godot copies it and sets each face's texture. Uses the map's own UVs (no triplanar), nearest-with-mipmaps, matte |
| `maps/chiip_map_settings.tres` | func_godot settings for Chiip: 39.37 units per metre (1 unit = 1 inch, as in CS), textures from `assets/textures`, lightmap UV texel size 8 units (≈ 0.2 m), generated materials not saved |
| `maps/comparison/comparison_room.map` | The M3 comparison room as a TrenchBroom map (Valve 220 format, 13 brushes) |
| `maps/comparison/trenchbroom_room.tscn` | That map built by func_godot (`Map` node, built geometry stored in the scene), lights set to *Static* for baking, a `LightmapGI` node, and a Player |
| `maps/comparison/csg_room.tscn` | The same room made of CSG boxes with triplanar materials, same lights, and a Player |
| `maps/test_map.tscn` | Test map (shown inside `main.tscn`). A `Navigation` region (`NavigationRegion3D`) covers the `Geometry` and `Range` nodes (group `navigation_source`). Lighting: neutral white sun (35° high, shadows), the shared cool-daylight environment, three colored `OmniLight3D` lamps (D-031). Retextured in M3: concrete floor (course), grey gravel (range), muted red brick outer walls, grey stone platform/stairs/peek walls, wooden crates, metal tunnel, painted spray wall. North: movement course (jump boxes 32/48/64/80 u, platform with a 25° ramp and stairs, crouch tunnel, peek walls). South: shooting range (firing line at z = 16, dummies at 5/10/20/40 m, a moving dummy at 15 m, a spray wall at 10 m with an aim mark). You spawn on the range facing the targets |
| `characters/character.gd` | `Character` (`CharacterBody3D`): all CS movement rules (run/walk/crouch, jump, air strafing), weapon handling, eye position and aim, 100 HP (`take_damage()`, signals `damaged` and `died`, dead characters stop acting), `team` (0 = player's, 1 = bots'), footsteps every 1.8 m (`footstep` signal; loud ones make noise). In the `characters` group. Simulates one `CharacterInput` per physics tick from its controller |
| `characters/character.tscn` | Base character scene: standing and crouching capsules, a `Head` at eye height, the soldier `Body`. On the **bots** layer by default (bullets pass through the capsule to the hit zones); the player overrides this. Player and bots are *inherited* variants of it |
| `characters/soldier_body.tscn` | The visible body with CS hit zones (`Hitbox` areas): `Upper` (head, chest, stomach, arms; sinks 0.457 m when crouching) and `Legs`. Chest and arm meshes are in the `team_colored` group and get the character's team color |
| `characters/character_input.gd` | `CharacterInput`: one tick of commands (move direction, look yaw/pitch, jump, crouch, walk, shoot, reload), like CS's "usercmd" |
| `characters/character_controller.gd` | `CharacterController`: base for whatever drives a character (`get_input()`, `set_look_angles()`, `get_camera()`) |
| `bots/bot.tscn` | A bot: inherits `character.tscn`, team 1, red team color, a `BotSenses` node, the rifle under `Head` (aims with the head's pitch), a `NavigationAgent3D` and a `BotController`. On the bots layer |
| `bots/bot_senses.gd` | `BotSenses`: vision (80 m, 110° cone, line of sight to head or chest, checked 10×/s), hearing (noises from enemies within range), memory of the last known position (8 s). Emits `enemy_spotted` |
| `bots/bot_controller.gd` | `BotController`: the bot's brain, a state machine. **Patrol** (patrol points or random navmesh spots) → **Engage** (enemy visible: reaction time, aim that settles and wobbles, counter-strafe to a stop, bursts at range / sprays up close with partial recoil control) → **Search** (walk to the last known position while facing it, look around, forget). Walks paths from its `NavigationAgent3D` by "pressing" movement keys; turns its view at a limited speed |
| `bots/bot_difficulty.gd` + `bots/difficulty_{easy,normal,hard}.tres` | `BotDifficulty` resource: reaction time, aim turn speed, initial and minimum aim error, settle time, headshot chance, recoil control, counter-strafing, burst/spray lengths and pause |
| `player/player.tscn` | The player: inherits `character.tscn`, adds `Head/Camera3D` with the rifle and a `PlayerController`. On the player layer |
| `player/player_controller.gd` | `PlayerController`: keyboard and mouse → commands, CS sensitivity, mouse capture (no shot on the recapture click), first-person camera with recoil kick |
| `ui/debug_overlay.tscn` + `.gd` | F3 readout: speed, position, jump peak, stance, shoot/aim buttons, weapon inaccuracy, built-up recoil, last hit (zone, damage, distance) |
| `systems/noises.gd` | `Noises`: the gameplay noise bus. `Noises.make_noise(position, range, source)`; listeners connect to `Noises.get_bus().noise_made`. Running footsteps carry 25 m, gunshots 60 m; walking and crouching are silent. A static shared instance, not an autoload (autoloads don't exist in `--script` runs) |
| `systems/physics_layers.gd` | `PhysicsLayers` constants: bit values of the named physics layers |
| `weapons/weapon_data.gd` | `WeaponData` resource: every number of a weapon (damage, fire rate, ammo, accuracy, spray pattern, recoil, sounds) |
| `weapons/rifle.tres` | The Rifle's data (AK-like) |
| `weapons/weapon.gd` | `Weapon` node: firing, ammo, reload. Signals `fired`, `ammo_changed`, `reload_started`, `reload_finished` |
| `weapons/bullet_impact.tscn` | Bullet hole (16 × 16 pixel radial gradient quad) and a burst of sparks |
| `weapons/hitbox.gd` | `Hitbox` (`Area3D`): one damage zone with its multiplier; emits `hit` with the damage, zone, position and attacker |
| `maps/test_map_navmesh.tres` | The test map's navigation mesh: settings (agent 2.0 m tall, 0.5 m radius, 0.25 m step, 46° slope, 0.25 m cells; parses static colliders on world + bots layers from the `navigation_source` group) and the baked result (153 polygons). Baked with `tools/bake_navmesh.gd` |
| `maps/props/target_dummy.tscn` + `.gd` | `TargetDummy`: CS-sized, color-coded hitboxes (head red, chest blue, stomach teal, arms light blue, legs dark), floating damage numbers, running total, optional side-to-side movement |
| `weapons/rifle.tscn` | The Rifle as a scene: `Weapon` script + `rifle.tres` + audio players + a blocky first-person model (`Viewmodel`) with a muzzle flash (gradient quad + orange light). Instanced in the player under `Head/Camera3D` |
| `ui/hud.tscn` + `.gd` | HUD: health (bottom left, red at ≤ 25), crosshair, weapon name ("· reloading"), ammo counter (red at ≤ 25%). Listens to the weapon's signals |
| `ui/crosshair.gd` | `Crosshair` (`Control`): CS-style crosshair drawn with `_draw()`; static or dynamic |
| `tools/make_retro_texture.gd` | Turns any image into a retro texture: square crop, shrink in halving steps to 64 × 64, optional contrast, brightness and saturation, k-means palette (16 colors), PNG + lossless/mipmapped import settings, into `assets/textures/` |
| `tools/bake_navmesh.gd` | Bakes every `NavigationRegion3D` in the given scenes and saves each navigation mesh to its own resource file (the editor's *Bake NavigationMesh*, headless) |
| `tools/build_maps.gd` | Builds every `FuncGodotMap` in the given scenes from their `.map` files and saves the scenes (the editor's *Build Map* button, headless) |
| `tools/export_trenchbroom_config.gd` | Writes Chiip's TrenchBroom game configuration (GameConfig.cfg, icon, FGD) into TrenchBroom's games folder |
| `tools/generate_sounds.gd` | Generates the placeholder sounds into `assets/sounds/` (gunshot, empty click, reload clack) |
| `assets/materials/*.tres` | One `StandardMaterial3D` per texture: world triplanar mapping at Quake's density (64 px = 64 units = 1.63 m, `uv1_scale` 0.6152), nearest-with-mipmaps filtering, matte (roughness 1, specular 0.2) |
| `assets/textures/*.png` | Retro textures, 64 × 64, 16 colors, made from ambientCG CC0 photos (list and settings in `docs/CREDITS.md`) |
| `assets/fonts/Silkscreen-*.ttf` | Pixel font: the project's default UI font (*Project Settings → GUI → Theme → Custom Font*) and the font of all 3D labels. Imported without antialiasing, hinting or subpixel positioning so pixels stay sharp |
| `addons/func_godot/` | FuncGodot addon (enabled in *Project Settings → Plugins*): builds Godot scenes from TrenchBroom `.map` files |
| `assets/sounds/*.wav` | Generated 22 kHz mono sounds: rifle shot, empty click, reload clack (referenced by `weapons/rifle.tres`) and three footsteps |
| `assets/sounds/footsteps.tres` | `AudioStreamRandomizer`: picks one of the three footsteps each step, with ±12% pitch and ±2 dB volume |
| `tests/movement_test.tscn` + `.gd` | Automated movement checks (D-018) |
| `tests/weapon_test.tscn` + `.gd` | Automated weapon checks: fire rate, ammo, reloads, inaccuracy, first-shot accuracy, zone damage, falloff, spray pattern, recovery |
| `shaders/prototype_grid.gdshader` | World-space 1 m grid "developer texture", no longer used on the test map; kept for quick blockouts |

## Systems

| System | Purpose | Milestone | Status |
|---|---|---|---|
| Character + controllers | CS-style movement for everyone, driven by per-tick commands | M1, M4 | Built: `Character`, `PlayerController` (bots in M4) |
| Debug overlay | Speed and position readout | M1 | Built |
| Weapon system | Hitscan, spread, recoil, ammo; stats in Resources | M2 | In progress: data, firing, ammo, reload, hitscan, impacts, accuracy, spray pattern, aim punch |
| Hitbox / damage | Hit zones, damage multipliers, armor | M2 | Built: zones and falloff (armor in M5) |
| HUD | Crosshair, ammo, later health, timer, kill feed | M2 → M5 | Built: crosshair, ammo, weapon name |
| Retro rendering | Low-res output, pixel filtering, palette | M3 | In progress: low-res world, two HUD styles |
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
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D | PlayerController |
| `jump` | Space, mouse wheel down | PlayerController |
| `crouch` | Ctrl | PlayerController |
| `walk` | Shift | PlayerController |
| `shoot` / `aim` | Left / right mouse button | Debug overlay now, weapons from M2 |
| `reload` | R | PlayerController → command → weapon |
| `toggle_mouse` | Esc | PlayerController (frees or captures the mouse) |
| `toggle_debug` | F3 | Debug overlay |

## How the player camera works

Physics interpolation (D-010) draws the player's body smoothly between physics ticks. If the camera were a normal child of the body, mouse look would only be applied once per tick and then smoothed, which adds a small delay. Instead:

1. Mouse movement updates two angles (`_yaw`, `_pitch`) immediately in `_unhandled_input`.
2. Each physics tick, the body turns to `_yaw`, so movement keys follow your view.
3. Each rendered frame, `_process` places the camera at the head's *interpolated* position and applies the angles directly. The camera is `top_level` (ignores its parent's transform) and has interpolation off.

## TrenchBroom maps (being evaluated in M3)

1. Open the `.map` in TrenchBroom (game "Chiip"), edit and save.
2. Rebuild: select the `Map` node in Godot and click *Build Map*, or run `tools/build_maps.gd`.
3. Bake lighting: select `LightmapGI` and click *Bake Lightmaps* (editor only, it needs the GPU).

TrenchBroom axes become Godot axes as (x, y, z) → (y, z, x), divided by 39.37. A 64-pixel texture covers 64 units = 1.63 m, the same density as the CSG materials.

## How the screen is put together

```
Main (Node, main.gd)
├── World (SubViewportContainer: stretch on, shrink = window height / 360, nearest filter)
│   └── SubViewport (640 × 360 in a 720p window)
│       ├── TestMap (map + Player)
│       └── PaletteEffect (CanvasLayer, optional full-screen color limit)
├── HUD (CanvasLayer)
└── DebugOverlay (CanvasLayer)
```

- The SubViewport renders the 3D world at low resolution, and the container scales it up with sharp (nearest) pixels.
- Sharp-HUD style: the window itself stays full resolution, so the HUD is crisp. Pixelated-HUD style: the window's *content scale* is set to the low resolution (`Window.content_scale_mode = viewport`), so everything is pixelated, HUD included.
- The HUD and overlay are laid out for a 720-pixel-tall window and scaled with `UiScale` to the real UI height.
- Mouse look uses `screen_relative`, so sensitivity is the same in both styles (checked: 2.200° for 100 counts).
- Text in the 3D world (`Label3D`) uses the pixel font with nearest filtering. Map signs are world-sized (`pixel_size` 0.04, about 0.32 m tall) and shrink with distance. Dummy titles and damage numbers use *Fixed Size* (the same size on screen at any distance) with `pixel_size` 0.004167, so one font pixel = one pixel of the 360-line world image.

## How characters are controlled (M4)

```
Character (CharacterBody3D, character.gd)        ← simulates commands by CS rules
├── StandingCollision / CrouchingCollision
├── Head (eyes; tilts with pitch)
│   └── Camera3D + Weapon (player)  or  Weapon (bot, later)
└── PlayerController / BotController            ← produces one CharacterInput per tick
```

1. Each physics tick, `Character._physics_process` asks its controller for a `CharacterInput` (`get_input()`): the *pull* model guarantees the command is fresh for this tick.
2. The character applies it: it faces `yaw`, tilts the head to `pitch`, sets `weapon.trigger_held` and reloads, then moves, jumps and crouches by the CS rules.
3. The player's controller reads keys in `get_input()` and the mouse in `_unhandled_input()`; its camera follows the head every rendered frame, so mouse look stays instant.
4. A bot's controller fills the same command from its AI (walking: movement keys toward the next path point); in M8 a network controller will fill it from packets. The character can't tell the difference.

## Sound

- **Your own** footsteps and gunshots play through `AudioStreamPlayer` (no position, both ears). **Everyone else's** play through `AudioStreamPlayer3D`, from where they are: footsteps carry 25 m, gunshots 80 m. `Character.is_local_player()` decides which, through `CharacterController.is_local()`.
- The 3D listener is the player's camera inside the world `SubViewport` (`audio_listener_enable_3d` is on).
- Footsteps play only for loud steps (running). Walking and crouch-walking are silent, matching what bots can hear (D-035).
- Tests set `footstep_sound = null` and use silent weapon data: headless runs have no audio device.

## How a character and its weapon work together

- The player's weapon scene sits under the camera, so the first-person model follows the view.
- The character sets `weapon.trigger_held` from the command. The character processes first and its children after, so the weapon sees the new value in the same tick.
- The weapon sets the character's top speed (`Character.get_max_speed()`).
- The click that recaptures the mouse, and clicks while the mouse is free, never fire (`PlayerController`).
- Shots start at `Character.get_eye_position()` and use `Character.get_aim_angles()`, the aim *without* recoil kick. The ray tests world + hitboxes only, and excludes the shooter's own hit zones (`Character.get_hitbox_rids()`), since it starts inside their head.
- Damage path: weapon → `Hitbox.receive_hit()` (zone multiplier) → `hit` signal → `Character.take_damage()` → `damaged` / `died` signals → HUD, and later kill feed and rounds.
- Recoil has two parts. `Weapon._get_shot_direction()` adds the spray pattern offset to the aim. `Weapon.view_punch` (half the pattern, smoothed every frame) is added to the camera rotation in `PlayerController._process`. The aim itself never changes, so the view returns to it as recoil wears off.
- When a ray hits a `Hitbox`, the weapon computes `damage × range_modifier^(distance / 500 units)` and calls `Hitbox.receive_hit()`, which applies the zone multiplier and emits `hit` to whoever owns the hitbox (the dummy now, bots in M4).
- The viewmodel moves with the camera because it's a child of it. Shot kick is a tween back to the rest pose; the reload dip is computed every frame from the reload progress. Viewmodel meshes don't cast shadows. Known limitation: the gun pokes into walls when you stand right against them (proper viewmodel rendering later).
- Bullet holes are parented to whatever was hit, so they move with moving targets. Each weapon keeps its last 100.

## Physics layers

Named in *Project Settings → Layer Names → 3D Physics*. Code uses the bit values from `systems/physics_layers.gd` (D-022).

| Layer | Name | Bit value | Used by |
|---|---|---|---|
| 1 | world | 1 | Map geometry |
| 2 | player | 2 | The player's body (collides with world and bots: mask 5) |
| 3 | bots | 4 | Bot bodies (and any `Character` by default; mask 7), target dummies |
| 4 | hitboxes | 8 | Head / chest / stomach / arm / leg zones (`Area3D`) that bullets hit |
| 5 | triggers | 16 | Buy zones, bombsites |

Bullets test **world + hitboxes** (mask 9) only.

## Testing

Run the checks from the project folder:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/movement_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/weapon_test.tscn
```

`--headless` means no window, and `--fixed-fps 128` runs exactly one physics tick per frame as fast as possible. `--quit-after` is a safety net in case a script error stops a test from finishing. Each check prints PASS or FAIL, and the exit code is the number of failures. The weapon test seeds the spread so every run fires the same shots, and uses a silent copy of the rifle data because headless runs have no audio device. When a test file uses a `class_name` for the first time, run `Godot --headless --path . --import` first so Godot knows the class.

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
- **Keep multiplayer possible** (it comes in M8, D-033). See the next section.

## Keeping multiplayer possible

Multiplayer is added in M8, after the single-player game. These rules for M4–M7 keep that retrofit manageable:

1. **Characters only move and shoot through input commands.** A `Character` never reads the keyboard; a controller (player, bot, later network) gives it a `CharacterInput` each tick.
2. **Game rules live in "authority" code, separate from what's shown.** Damage, deaths, round state, money and the bomb are decided by gameplay nodes and announced with signals. HUD, sounds and effects only react to those signals. In M8 the host runs the rules, and clients just show the results.
3. **Gameplay runs in `_physics_process`**, at a fixed tick (128 Hz). `_process` is only for visuals (camera, effects, UI).
4. **Randomness that affects gameplay uses seeded generators** (like `Weapon.rng`), never the global `randf()`. Visual-only randomness (spark directions, hole rotation) can stay global.
5. **Characters and other gameplay objects get stable IDs**, so the host and clients can refer to the same thing.
