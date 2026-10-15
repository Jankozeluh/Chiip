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
├── ui/                HUD, scoreboard, menus, developer console
├── systems/           Shared systems: teams, round manager and match settings, noise bus, arena rules (practice), physics layers; later settings
├── shaders/           Shaders: palette effect, grid placeholder for blockouts
├── tests/             Automated test scenes, run headless (D-018)
└── tools/             One-off tool scripts run from the command line (not part of the game)
```

## Scenes and files

| File | What it is |
|---|---|
| `main.tscn` + `main.gd` | Root (main) scene. `get_map()`, `change_map(path)` (console), `restart_match()` (reloads the current map in the current mode: the match-end screen's Play again). Loads the map from `map_scene` (default `maps/test_map.tscn`, or `-- --map <scene>` on the command line), puts it in the world viewport, adds the game rules and hands its `Player` to the HUD and overlay, and the round manager (if the rules are a match) to the match-end screen, which hides again whenever a map loads, and to the HUD (`set_round_manager()`: the round HUD with top bar, kill feed and banners; null in practice mode hides it, and the previous manager is dropped) and to the hold-Tab scoreboard (`Scoreboard.set_round_manager()`, null in practice mode = it never shows). Game rules by `mode` (`Mode.MATCH` by default, `-- --practice` for `Mode.PRACTICE`): a `RoundManager` with `match_settings` on maps with navigation and both team spawn groups, else an `ArenaRules` on maps with navigation, else none. Maps hold only the level; the rules node is added as a child of the map, named after its class. In a match it also turns on `PlayerController.spectating_enabled` and connects the controller's `view_target_changed` to the HUD (`_set_up_spectating()`). The world (test map + player) runs inside a `SubViewport` rendered at `pixel_height` (360) lines and scaled up with nearest filtering; the HUD, debug overlay, scoreboard and match-end screen sit on top. `pixelate_hud` switches to rendering the whole window at the low resolution |
| `shaders/palette_limit.gdshader` | Optional retro color limit for the world image: 16 shades per channel with 4 × 4 ordered (Bayer) dithering. Drawn by a full-screen `ColorRect` in `World/SubViewport/PaletteEffect`, switched by `Main.palette_effect` |
| `ui/dev_console.tscn` + `.gd` | `DevConsole` (key left of 1): commands `help`, `clear`, `bot_add [easy|normal|hard] [ally|enemy]`, `bot_kick`, `bot_difficulty`, `god`, `noclip`, `mp_friendlyfire [0|1]`, `map`; history with ↑/↓. `DevConsole.is_open` (static) makes the player's controls ignore input. `run(text)` runs a command from code. Lives in `main.tscn` (not an autoload) |
| `ui/ui_scale.gd` | `UiScale.apply()`: scales a Control's font, outline and position for the current UI resolution. `UiScale.apply_tree(root, factor)` scales a whole container-based layout (font sizes, minimum sizes, container spacing, label outlines, and the offsets of controls that are not inside a container), remembering the original values; used by the round HUD |
| `assets/environments/cool_daylight.tres` | The shared `Environment`: blue sky with a grey-blue horizon, ambient light, cool haze, tonemapping and color adjustments (D-031) |
| `assets/materials/map_default.tres` | Base material for TrenchBroom maps: func_godot copies it and sets each face's texture. Uses the map's own UVs (no triplanar), nearest-with-mipmaps, matte |
| `maps/chiip_map_settings.tres` | func_godot settings for Chiip: 39.37 units per metre (1 unit = 1 inch, as in CS), textures from `assets/textures`, lightmap UV texel size 8 units (≈ 0.2 m), generated materials not saved |
| `maps/comparison/comparison_room.map` | The M3 comparison room as a TrenchBroom map (Valve 220 format, 13 brushes) |
| `maps/comparison/trenchbroom_room.tscn` | That map built by func_godot (`Map` node, built geometry stored in the scene), lights set to *Static* for baking, a `LightmapGI` node, and a Player |
| `maps/comparison/csg_room.tscn` | The same room made of CSG boxes with triplanar materials, same lights, and a Player |
| `maps/test_map.tscn` | Test map (shown inside `main.tscn`). An `Arena` node with 11 patrol points (`patrol_points`), 4 bot spawns in the far corners (`bot_spawns`) and your spawn (`player_spawns`) for practice mode, plus 10 team spawns (D-042): 5 `defend_spawns` at the north end behind the peek walls (z = −28, facing south) and 5 `attack_spawns` at the south end of the range (z = 84, facing north), 3 m apart, 112 m between the ends. A `Tactics` node for the bots' round plans (D-045): 6 `hold_points` near the north (defenders') end (platform, west flank, both peek-wall ends, the gap between them, beside the tunnel; each faces the angle to hold) and 3 `attack_routes` from the south end (`RouteWest`, `RouteMiddle`, `RouteEast`, 5 waypoints each). All markers are on walkable floor. No rules node of its own: `main.gd` adds a `RoundManager` (match) or `ArenaRules` (practice). A `Navigation` region (`NavigationRegion3D`) covers the `Geometry` and `Range` nodes (group `navigation_source`). Lighting: neutral white sun (35° high, shadows), the shared cool-daylight environment, three colored `OmniLight3D` lamps (D-031). Retextured in M3: concrete floor (course), grey gravel (range), muted red brick outer walls, grey stone platform/stairs/peek walls, wooden crates, metal tunnel, painted spray wall. North: movement course (jump boxes 32/48/64/80 u, platform with a 25° ramp and stairs, crouch tunnel, peek walls). South: shooting range (firing line at z = 16, dummies at 5/10/20/40 m, a moving dummy at 15 m, a spray wall at 10 m with an aim mark). You spawn on the range facing the targets |
| `characters/character.gd` | `Character` (`CharacterBody3D`): all CS movement rules (run/walk/crouch, jump, air strafing), weapon handling, eye position and aim, 100 HP (`take_damage()`, signals `damaged`, `died` and `respawned`; dead characters stop acting, tip over and stop blocking others; `respawn()` resets health, stance and weapon; `damaged` reports the health actually lost), `frozen` (set by the round manager during freeze time: looking, crouching and reloading still work, moving, jumping and shooting don't), `god_mode` and `noclip` (console), `team` (0 or 1, no names; setting it recolors the body), clothes colored by `Teams.color_for(team)` (one material per character, `update_team_color()`; no `team_color` export), friendly fire in `take_damage()` (damage scaled by `Teams.damage_factor()`: nothing from a teammate unless `Teams.friendly_fire`), footsteps every 1.8 m (`footstep` signal; loud ones make noise). In the `characters` group. Simulates one `CharacterInput` per physics tick from its controller |
| `characters/character.tscn` | Base character scene: standing and crouching capsules, a `Head` at eye height, the soldier `Body`. On the **bots** layer by default (bullets pass through the capsule to the hit zones); the player overrides this. Player and bots are *inherited* variants of it |
| `characters/soldier_body.tscn` + `.gd` | `SoldierBody`: the visible body with CS hit zones (`Hitbox` areas): `Upper` (head, chest, stomach; arms on shoulder joints; sinks 0.457 m when crouching) and `Legs` (on hip joints). `update_pose()` runs a procedural walk cycle each physics tick (D-039). Chest and arm meshes are in the `team_colored` group and get the character's team color (blue for the viewer's team, red for the other) |
| `characters/character_input.gd` | `CharacterInput`: one tick of commands (move direction, look yaw/pitch, jump, crouch, walk, shoot, reload), like CS's "usercmd" |
| `characters/character_controller.gd` | `CharacterController`: base for whatever drives a character (`get_input()`, `set_look_angles()`, `get_camera()`) |
| `bots/bot.tscn` | A bot: inherits `character.tscn`, team 1 by default (no fixed color: the clothes are red or blue depending on the viewer's team; `ArenaRules.add_bot()` can set another team for a teammate), a `BotSenses` node, the rifle under `Head` (aims with the head's pitch), a `NavigationAgent3D` and a `BotController`. On the bots layer |
| `bots/bot_senses.gd` | `BotSenses`: vision (60 m, 110° cone, line of sight to head or chest, checked 10×/s) with gradual *noticing* (awareness builds while in view; slower far away and at the edge of vision, D-037), hearing (noises from enemies within range), being shot, memory of the last known position (8 s). Emits `enemy_spotted` |
| `bots/bot_controller.gd` | `BotController`: the bot's brain, a state machine (optionally `hold_position`). **Patrol**, i.e. follow the round's orders by `role` (D-045): `ATTACK` (`attack(route, clear_points, delay)`: wait out its start delay, walk the route, then clear the defenders' end at walking speed; after a detour it continues from the nearest route leg), `DEFEND` (`defend(spot, all_spots)`: walk to the hold spot, watch its angle with a ±10° drift; only search enemies within `ROTATE_DISTANCE` 35 m; afterwards hold the nearest spot) or `PATROL` (`patrol()`: patrol points or random navmesh spots; practice mode, and after every respawn until new orders) → **Engage** (enemy visible: reaction time, aim that settles and wobbles, counter-strafe to a stop, bursts at range / sprays up close with partial recoil control; holds fire while a living teammate is within 0.6 m of the line of fire) → **Search** (walk to the last known position while facing it, look around, forget). Walks paths from its `NavigationAgent3D` by "pressing" movement keys; turns its view at a limited speed |
| `bots/bot_difficulty.gd` + `bots/difficulty_{easy,normal,hard}.tres` | `BotDifficulty` resource: reaction time, aim turn speed, initial and minimum aim error, settle time, headshot chance, recoil control, counter-strafing, burst/spray lengths and pause |
| `player/player.tscn` | The player: inherits `character.tscn`, adds `Head/Camera3D` with the rifle and a `PlayerController`. On the player layer |
| `player/player_controller.gd` | `PlayerController`: keyboard and mouse → commands, CS sensitivity, mouse capture (no shot on the recapture click), first-person camera with recoil kick. **Spectating** (D-046), only when `spectating_enabled` (set by `main.gd` in a match): after your death, once `spectate_delay` (2 s) has passed, the camera shows a living teammate (`spectate_next()` = the next one in scene-tree order, also on a click once you watch someone; `get_view_target()` is yourself in your own view; `is_spectating()`; signal `view_target_changed`). When the watched teammate dies, the view moves on after `spectate_switch_delay` (1.5 s), or stays with them if nobody is left; `on_respawned()` (the next round) ends it. Hides the watched `Body` and your own rifle while it lasts |
| `ui/debug_overlay.tscn` + `.gd` | F3 readout: speed, position, jump peak, stance, shoot/aim buttons, weapon inaccuracy, built-up recoil, last hit (zone, damage, distance) |
| `systems/arena_rules.gd` | `ArenaRules`: practice mode (`-- --practice`). Keeps `bot_count` bots on the map (names Bot1, Bot2, …), respawns anyone 3 s after death (spawn markers in groups `bot_spawns` / `player_spawns`, preferring markers nobody stands on; else random walkable spots ≥ 20 m from the player). `add_bot(difficulty, team)` (team 1 by default; the team is set before the bot enters the tree), `remove_bot()`, `get_bots()`. Added to the map by `main.gd` in practice mode |
| `bots/bot_tactics.gd` | `BotTactics`: static round planner. `plan_round(attackers, defenders, map, rng)` gives every bot its orders: attackers in groups of about two on different `attack_routes` (start 0.6 s apart + up to 0.4 s, waypoints shifted up to 1.2 m), clearing the `hold_points` and defender spawns afterwards; defenders on different `hold_points`. Falls back to `patrol()` on maps without routes or hold spots. Seeded by the round manager's `rng` |
| `systems/round_manager.gd` | `RoundManager`: the match's game state and rules (D-043). Phases `FREEZE` → `LIVE` → `ROUND_END` → next round, or `MATCH_END` once a team has `rounds_to_win` rounds (D-044), timed in `_physics_process` from `MatchSettings`. Adds the bots (the map's `Player` plus `team_size − 1` bot teammates on `player_team`, `enemy_team_size` bots on the other team), picks the attacking team at random (seeded `rng`), and at each round start respawns everyone on a shuffled spawn marker of their side and sets `Character.frozen`. Elimination is checked at the end of the frame after a death; time-out → defenders win; both teams wiped → defenders. Counts the `score` (the winner's score goes up before `round_ended` is emitted). After round `rounds_to_win − 1` it flips `attacking_team` (the teams keep their numbers) and emits `sides_swapped`. At the match end the last round's pause still runs, then everyone is frozen, `winner` is set and `match_ended(winner)` is emitted. Signals `phase_changed`, `round_started`, `round_ended(winner, reason)`, `sides_swapped`, `match_ended(winner)`, `character_killed(victim, killer, headshot)`. Reads: `phase`, `round_number`, `time_left`, `attacking_team`, `score` (rounds won, index = team), `winner` (−1 until the match is decided), `get_side()`, `get_defending_team()`, `get_members()`, `get_alive_count()`, `get_participants()`, `get_stats()` (`RoundManager.Stats`: kills, deaths, assists, damage) |
| `systems/match_settings.gd` | `MatchSettings` resource: the rules of one match. Team sizes (1–5 each, 3v3 default, yours includes you), bot difficulty, `rounds_to_win` (5), `friendly_fire` (off), `freeze_time` 5 s, `round_time` 115 s, `round_end_time` 5 s |
| `systems/noises.gd` | `Noises`: the gameplay noise bus. `Noises.make_noise(position, range, source)`; listeners connect to `Noises.get_bus().noise_made`. Running footsteps carry 25 m, gunshots 60 m; walking and crouching are silent. A static shared instance, not an autoload (autoloads don't exist in `--script` runs) |
| `systems/teams.gd` | `Teams`: static helper (not an autoload, so `--script` tools can load maps with characters). `enum Side { ATTACKING, DEFENDING }`, `COUNT` (teams are the numbers 0 and 1), `FRIENDLY_COLOR` / `ENEMY_COLOR`, `viewer_team` + `set_viewer_team()` (recolors every character), `color_for(team)`, `text_color_for(team)` (the same lightened by 0.35, for text on dark panels), `other(team)`, `spawn_group(side)` (`attack_spawns` / `defend_spawns`), `friendly_fire` (off by default) + `FRIENDLY_FIRE_DAMAGE` (1/3) and `damage_factor(victim, attacker)`. See D-042 |
| `systems/physics_layers.gd` | `PhysicsLayers` constants: bit values of the named physics layers |
| `weapons/weapon_data.gd` | `WeaponData` resource: every number of a weapon (damage, fire rate, ammo, accuracy, spray pattern, recoil, sounds) |
| `weapons/rifle.tres` | The Rifle's data (AK-like) |
| `weapons/weapon.gd` | `Weapon` node: firing, ammo, reload. Signals `fired`, `ammo_changed`, `reload_started`, `reload_finished`. With friendly fire off, bullets pass through living teammates (their hit zones are excluded from the ray) |
| `weapons/bullet_impact.tscn` | Bullet hole (16 × 16 pixel radial gradient quad) and a burst of sparks |
| `weapons/hitbox.gd` | `Hitbox` (`Area3D`): one damage zone with its multiplier; emits `hit` with the damage, zone, position and attacker |
| `maps/test_map_navmesh.tres` | The test map's navigation mesh: settings (agent 2.0 m tall, 0.5 m radius, 0.25 m step, 46° slope, 0.25 m cells; parses static colliders on world + bots layers from the `navigation_source` group) and the baked result (153 polygons). Baked with `tools/bake_navmesh.gd` |
| `maps/props/target_dummy.tscn` + `.gd` | `TargetDummy`: CS-sized, color-coded hitboxes (head red, chest blue, stomach teal, arms light blue, legs dark), floating damage numbers, running total, optional side-to-side movement |
| `weapons/rifle.tscn` | The Rifle as a scene: `Weapon` script + `rifle.tres` + audio players + a blocky first-person model (`Viewmodel`) with a muzzle flash (gradient quad + orange light). Instanced in the player under `Head/Camera3D` |
| `ui/hud.tscn` + `.gd` | HUD: health (bottom left, red at ≤ 25), "Killed by …" message while dead (plus "Respawning..." when `respawn_hint` is on, i.e. in practice mode), crosshair, weapon name ("· reloading"), ammo counter (red at ≤ 25%). Listens to the signals of the *shown* character (`shown`): the player, or while spectating the teammate being watched, set with `set_view_target()` (`main.gd` connects it to `PlayerController.view_target_changed`). While spectating it also shows "Spectating Bot2  ·  click for next" ("· dead" once they're down) at the bottom centre, and hides the "Killed by …" message. In a match its `RoundHud` child (below) adds the top bar, countdown, banners and kill feed: `set_round_manager(manager)` hands it the match (null in practice mode hides it) and `set_ui_scale()` scales it too |
| `ui/match_end_screen.tscn` + `.gd` | `MatchEndScreen` (`CanvasLayer`, layer 5, above the HUD, hidden until the match is over). `set_round_manager(manager)` connects `match_ended` (and hides the screen; `main.gd` calls it on every map load). Shows "Victory" / "Defeat" for `Teams.viewer_team`, the score "yours - theirs" in blue and red, and a scoreboard of both teams, which is a `ScoreboardTable` (below) with `dim_dead` off, so the final numbers show without greyed-out rows; `show_match()` fills it when the match ends and `set_round_manager()` empties it. Buttons "Play again" and "Quit" emit `play_again_pressed` / `quit_pressed`; `main.gd` reacts. A full-screen background `ColorRect` with `mouse_filter = STOP` keeps clicks from reaching the player controls; the screen shows the mouse, keeps it visible and swallows Esc while open. `set_ui_scale(factor)` scales font sizes, minimum sizes and container spacing (containers place their children, so there are no offsets to scale as in the HUD); the table scales its own rows, so the screen hands it the factor instead of walking into it. Plain look: the shared UI theme comes in task 8 |
| `ui/round_hud.tscn` + `.gd` | `RoundHud` (`Control`, a child of the HUD, shown only in a match, D-047). A pure view of the `RoundManager`: it connects to `phase_changed`, `round_started`, `round_ended`, `sides_swapped` and `character_killed`, reads `phase`, `time_left`, `round_number`, `score`, `attacking_team`, `get_side()`, `get_members()` and `get_alive_count()`, and never changes anything. `set_round_manager(manager)` (null hides it) drops the old connections, empties the feed and shows the current state. **Top bar** (top centre, an `HBoxContainer` of three `PanelContainer` boxes): your score in a blue box, the timer with "Round N", their score in a red box, and one square per player under each score, lit while alive (`get_alive_shown(team)`). The timer shows the freeze countdown (yellow) in freeze time, then `format_time()` m:ss (red at ≤ 10 s) and keeps its value in the round-end pause (0:00 after a time-out). **Center** (four labels `Title`, `Line1`–`Line3`, empty ones hidden): in freeze time "Round 3 · starts in 4", your side ("You attack: push to the far end" / "You defend: hold your end"), "Switching sides" after a half-time swap and "Match point" / "Enemy match point" / "Match point for both teams"; at the round end "Round won" / "Round lost" with the reason said for your side. Everything ignores the mouse. `set_ui_scale()` uses `UiScale.apply_tree()` |
| `ui/kill_feed.gd` | `KillFeed` (`VBoxContainer`, the `KillFeed` node of the round HUD, top right). `add_kill(victim, killer, headshot)` adds a line "Killer > Victim" (names in team colors from `Teams.text_color_for()`, gold "HS" for a headshot, only the victim when there is no killer), your own lines with a darker background and a white outline; newest at the bottom, at most `MAX_LINES` (5), each fades after `LINE_LIFETIME` (5 s) with a per-line `Tween`; `clear()`, `get_line_count()`, `set_ui_scale()`. The separator is ">" because Silkscreen has no arrow glyph |
| `ui/scoreboard_table.tscn` + `.gd` | `ScoreboardTable` (`VBoxContainer`, D-050): the two-team table shared by the hold-Tab overlay and the match-end screen. `show_match(rounds)` hands it the match, `refresh()` reads the numbers (call it every frame: it rebuilds only when something shown changed, by comparing a signature). Your team (`Teams.viewer_team`) first under a blue header, then the enemy under a red one; one row per player (name, kills, deaths, assists, damage rounded), sorted by kills, then damage, then join order; your row highlighted and marked "(you)"; with `dim_dead` (on by default) a dead player's row is dimmed to 40%, so you see who is alive. Built in code from `VBoxContainer`, `PanelContainer`, `MarginContainer`, `HBoxContainer` and `Label`, all with `mouse_filter = IGNORE`. Test hooks: `get_row(character)`, `get_displayed(team)`; boxes are named `Team0` / `Team1` with a `Header` row. `set_ui_scale()` scales it with `UiScale.apply_tree()` and remembers the factor for rows built later |
| `ui/scoreboard.tscn` + `.gd` | `Scoreboard` (`CanvasLayer`, layer 3: above the HUD, below the match-end screen and the console; hidden by default). The hold-Tab scoreboard (D-050): while the `scoreboard` action is held in a match it shows a centered panel with "Round N", the score (yours blue, theirs red) and a `ScoreboardTable`. A pure view of the `RoundManager`, polled every frame while visible (no signals, so nothing to disconnect). Shows only when a round is under way, the phase isn't `MATCH_END` and `DevConsole.is_open` is false. `set_round_manager(manager)` (called by `main.gd` on every map load; null in practice mode = it never shows), `set_ui_scale()`. Doesn't pause or block anything; no control takes the mouse |
| `ui/crosshair.gd` | `Crosshair` (`Control`): CS-style crosshair drawn with `_draw()`; static or dynamic |
| `tools/make_retro_texture.gd` | Turns any image into a retro texture: square crop, shrink in halving steps to 64 × 64, optional contrast, brightness and saturation, k-means palette (16 colors), PNG + lossless/mipmapped import settings, into `assets/textures/` |
| `tools/bake_navmesh.gd` | Bakes every `NavigationRegion3D` in the given scenes and saves each navigation mesh to its own resource file (the editor's *Bake NavigationMesh*, headless) |
| `tools/build_maps.gd` | Builds every `FuncGodotMap` in the given scenes from their `.map` files and saves the scenes (the editor's *Build Map* button, headless) |
| `tools/export_trenchbroom_config.gd` | Writes Chiip's TrenchBroom game configuration (GameConfig.cfg, icon, FGD) into TrenchBroom's games folder |
| `tools/generate_sounds.gd` | Generates the placeholder sounds into `assets/sounds/` (gunshot, empty click, reload clack) |
| `tools/concept/` | Concept-art tool in Python (not Godot): renders 8-direction sprite turnarounds of character designs from 3D shapes (D-051). Has a `.gdignore`, so Godot skips the folder. Needs Python 3 with numpy and Pillow (`requirements.txt`); writes its output outside the project |
| `assets/materials/*.tres` | One `StandardMaterial3D` per texture: world triplanar mapping at Quake's density (64 px = 64 units = 1.63 m, `uv1_scale` 0.6152), nearest filtering with mipmaps and anisotropic filtering (sharp at grazing angles), matte (roughness 1, specular 0.2) |
| `assets/textures/*.png` | Retro textures, 64 × 64, 16 colors, made from ambientCG CC0 photos (list and settings in `docs/CREDITS.md`) |
| `assets/fonts/Silkscreen-*.ttf` | Pixel font: the project's default UI font (*Project Settings → GUI → Theme → Custom Font*) and the font of all 3D labels. Imported without antialiasing, hinting or subpixel positioning so pixels stay sharp |
| `addons/func_godot/` | FuncGodot addon (enabled in *Project Settings → Plugins*): builds Godot scenes from TrenchBroom `.map` files |
| `assets/sounds/*.wav` | Generated 22 kHz mono sounds: rifle shot, empty click, reload clack (referenced by `weapons/rifle.tres`) and three footsteps |
| `assets/sounds/footsteps.tres` | `AudioStreamRandomizer`: picks one of the three footsteps each step, with ±12% pitch and ±2 dB volume |
| `tests/movement_test.tscn` + `.gd` | Automated movement checks (D-018) |
| `tests/tactics_test.tscn` + `.gd` | Automated checks that bots play rounds (4), on the real test map in a seeded bots-only 3v3: orders, defenders on different spots watching their angles, attackers pushing in loose groups, rounds decided by elimination |
| `tests/round_test.tscn` + `.gd` | Automated round checks (74) on the real test map with short timings: 3v3 setup, spawns with full health and ammo, freeze time, going live, elimination (not before the last kill), kill credit and headshots, the dead stay dead until the next round, assists and damage, time-out → defenders; then the same match to its end (first to 5): the score at each `round_ended`, the half-time swap after round 4 and the spawns at the other end, the last round's pause, the match end (`MATCH_END`, one `match_ended`, everyone frozen), nothing happening afterwards; two tiny matches (first to 1: no half time; first to 2: swap after round 1, decided in round 3); and spectating (9 checks, long rounds, spectating switched on by the test): off by default, your own view for 2 s and then a teammate's eyes (camera on their head, along their aim), their body and your rifle hidden, `spectate_next()`, the recapture click doesn't count, the view moving on when the watched teammate dies, staying put when nobody is left, and your own view back in the next round; and the round HUD (26 checks, the real `hud.tscn` fed by seeded matches): `format_time`, the freeze countdown and both side lines, score and squares after kills, kill-feed lines (names, colors, headshot mark, victim only, your own lines highlighted, colors relative to the viewer), the five-line cap and the 5 s fade, round-end banners for a win and a loss by elimination and on time-out, "Switching sides" and the three match-point texts, handing the HUD another round manager or none (no doubled connections), UI scaling, and that no part of the HUD takes mouse clicks; and the scoreboard (22 checks): the Tab action and a real Tab press, the table (both teams, yours first under the right header, also from team 1; every cell against `get_stats()` after a scripted fight; sorting by kills, then damage, then join order; dead rows dimmed, only your row highlighted; rows kept when nothing changed; nothing dimmed in the next round), the hold-Tab overlay (hidden, shown while held, header with round and score, follows damage and kills, movement still works, ignored while the console is open, no control takes clicks, UI scaling, a replaced or missing round manager, hidden at the match end but not in the last round's pause) and the match-end screen's table (not dimmed, scaled, emptied) |
| `tests/bot_test.tscn` + `.gd` | Automated bot checks (16): patrol walking, vision (open / behind / wall), hearing (run vs walk), reaction time, no shooting through walls, Normal bot wins, Hard faster than Easy, death at 100 damage, friendly fire (off: no damage; on: a third; off: bullets pass through teammates). Builds its own level and bakes a navigation mesh at runtime; holding fire while a teammate is in the line of fire |
| `tests/weapon_test.tscn` + `.gd` | Automated weapon checks: fire rate, ammo, reloads, inaccuracy, first-shot accuracy, zone damage, falloff, spray pattern, recovery |
| `shaders/prototype_grid.gdshader` | World-space 1 m grid "developer texture", no longer used on the test map; kept for quick blockouts |

## Systems

| System | Purpose | Milestone | Status |
|---|---|---|---|
| Character + controllers | CS-style movement for everyone, driven by per-tick commands | M1, M4 | Built: `Character`, `PlayerController` (bots in M4) |
| Debug overlay | Speed and position readout | M1 | Built |
| Weapon system | Hitscan, spread, recoil, ammo; stats in Resources | M2 | Built: data, firing, ammo, reload, hitscan, impacts, accuracy, spray pattern, aim punch |
| Hitbox / damage | Hit zones, damage multipliers, armor | M2 | Built: zones and falloff (armor in M7) |
| HUD | Crosshair, ammo, health, timer, score, kill feed, banners | M2 → M5 | Built: crosshair, ammo, weapon name, health, spectate line; round HUD (top bar, countdown and side, banners, kill feed, D-047) |
| Retro rendering | Low-res output, pixel filtering, palette | M3 | Built: low-res world, palette with dithering, two HUD styles |
| Bot AI | Navigation, perception, state machine, aim, round tactics | M4, M5 | Built: senses with gradual noticing, patrol/engage/search, navmesh paths, difficulty levels; attack routes, hold spots, holding fire for teammates (M5) |
| Developer console | `bot_add`, `noclip` and similar commands | M4 | Built: help, clear, bot_add, bot_kick, bot_difficulty, god, noclip, mp_friendlyfire, map |
| Character animation | Walk cycle now; rigged models, animation blending, first-person arms later | M4 → M6 | Built: procedural walk placeholder (`SoldierBody`) |
| Teams | Two teams, viewer-relative colors, attack/defend spawn ends, friendly fire | M5 | Built: `Teams`, 10 spawns on the test map (D-042) |
| Round manager | Phases, timer, win conditions, match score | M5 | Built: rounds, freeze time, elimination and time-out, stats, match score, half-time swap, match end (D-044) |
| Spectating | Watch a living teammate through their eyes after you die | M5 | Built in `PlayerController`, local presentation only (D-046) |
| Settings | Sensitivity, FOV, crosshair, audio, keys; saved to disk | M5 | Planned |
| Match-end screen | Victory / Defeat, final score, scoreboard, Play again / Quit | M5 | Built: `MatchEndScreen` (the main menu replaces Quit in task 11) |
| Scoreboard | Hold Tab: both teams' kills, deaths, assists, damage and who is alive | M5 | Built: `Scoreboard` + `ScoreboardTable` (D-050), also used by the match-end screen |
| Economy | Money, rewards, buy menu | M7 | Planned |
| Bomb | Plant, defuse, explosion | M8 | Planned |

## Input actions

Defined in *Project → Project Settings → Input Map* (stored in `project.godot`). Keys are bound by physical position (D-012). Code only uses action names, never raw keys.

| Action | Default binding | Used by |
|---|---|---|
| `move_forward` / `move_back` / `move_left` / `move_right` | W / S / A / D | PlayerController |
| `jump` | Space, mouse wheel down | PlayerController |
| `crouch` | Ctrl | PlayerController |
| `walk` | Shift | PlayerController |
| `shoot` / `aim` | Left / right mouse button | Debug overlay now, weapons from M2; `shoot` also switches to the next teammate while you spectate (PlayerController) |
| `reload` | R | PlayerController → command → weapon |
| `toggle_mouse` | Esc | PlayerController (frees or captures the mouse) |
| `toggle_debug` | F3 | Debug overlay |
| `toggle_console` | key left of 1 (`` ` `` / `~`; on Czech keyboards the key under Esc) | Developer console |
| `scoreboard` | Tab (hold) | Scoreboard overlay (polls `Input.is_action_pressed`; ignored while the console is open) |

## How the player camera works

Physics interpolation (D-010) draws the player's body smoothly between physics ticks. If the camera were a normal child of the body, mouse look would only be applied once per tick and then smoothed, which adds a small delay. Instead:

1. Mouse movement updates two angles (`_yaw`, `_pitch`) immediately in `_unhandled_input`.
2. Each physics tick, the body turns to `_yaw`, so movement keys follow your view.
3. Each rendered frame, `_process` places the camera at the head's *interpolated* position and applies the angles directly. The camera is `top_level` (ignores its parent's transform) and has interpolation off.

**Spectating (D-046).** In a match, when you are dead the same camera shows a teammate instead: `_process` takes the head's interpolated transform from `get_view_target()` (your own character, or the teammate being watched). For a teammate the rotation is that head's drawn rotation (their aim, smoothed between ticks like the position) instead of your mouse angles; the recoil kick is added from *their* weapon's `view_punch`. There is no new camera, so the crosshair, the audio listener and the HUD keep pointing at the same node. The teammate's `Body` and your own rifle (a child of the camera) are hidden meanwhile; the teammate's rifle stays, because a bot's rifle hangs under its `Head` at the same offset as your first-person rifle and so looks like their viewmodel. The state (who is watched, the 2 s / 1.5 s waits) lives in `PlayerController._physics_process` and only reads `team`, `is_alive()` and the head: it is presentation, so no game rule depends on it.

## TrenchBroom maps (being evaluated in M3)

1. Open the `.map` in TrenchBroom (game "Chiip"), edit and save.
2. Rebuild: select the `Map` node in Godot and click *Build Map*, or run `tools/build_maps.gd`.
3. Bake lighting: select `LightmapGI` and click *Bake Lightmaps* (editor only, it needs the GPU).

TrenchBroom axes become Godot axes as (x, y, z) → (y, z, x), divided by 39.37. A 64-pixel texture covers 64 units = 1.63 m, the same density as the CSG materials.

## How the screen is put together

```
Main (Node, main.gd)
├── World (SubViewportContainer: stretch on, shrink = window height / 480 rounded, nearest filter)
│   └── SubViewport (853 × 480 on a 1440p screen, 640 × 360 in a 720p window)
│       ├── TestMap (map + Player)
│       └── PaletteEffect (CanvasLayer, optional full-screen color limit)
├── HUD (CanvasLayer)
│   └── RoundHud (Control: top bar, center messages, KillFeed; hidden in practice mode)
├── DebugOverlay (CanvasLayer)
├── Scoreboard (CanvasLayer, layer 3, shown only while Tab is held in a match)
├── MatchEndScreen (CanvasLayer, layer 5, hidden until the match ends)
└── DevConsole (CanvasLayer, layer 10)
```

- The SubViewport renders the 3D world at low resolution, and the container scales it up with sharp (nearest) pixels.
- Sharp-HUD style: the window itself stays full resolution, so the HUD is crisp. Pixelated-HUD style: the window's *content scale* is set to the low resolution (`Window.content_scale_mode = viewport`), so everything is pixelated, HUD included.
- The HUD and overlay are laid out for a 720-pixel-tall window and scaled with `UiScale` to the real UI height. The scoreboard, the match-end screen and the console get the same factor through their own `set_ui_scale()`. The round HUD is part of the HUD: `HUD.set_ui_scale()` passes the factor on, and `UiScale.apply_tree()` scales its containers.
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
4. A bot's controller fills the same command from its AI (walking: movement keys toward the next path point); in M9 a network controller will fill it from packets. The character can't tell the difference.

## How a round works (M5)

```
Map (test_map.tscn)
├── Player, markers (attack_spawns, defend_spawns, patrol_points), geometry …
├── Tactics                 ← hold_points (Marker3D) and attack_routes (Node3D → Marker3D waypoints)
├── RoundManager            ← added by main.gd; owns the game state
└── Bot1 … Bot5             ← added by the RoundManager (teammates and enemies)
```

1. `RoundManager` starts the match at the end of its first frame (so the map's navigation and markers are ready): it puts you on `player_team`, adds the bots and picks which team attacks.
2. Each round: everyone `respawn()`s on their side's markers, `Character.frozen` is set, and the phase runs `FREEZE` (5 s) → `LIVE` (1:55) → `ROUND_END` (5 s) → the next round (or the end of the match, see 7). Timers count down in `_physics_process`, never with `Timer` nodes, so they advance with the 128 Hz simulation (ARCHITECTURE rule 3).
3. Right after the respawns, `BotTactics.plan_round()` gives every bot its orders for the round (attack along a route, or hold a spot); during freeze time they can't act on them yet.
4. Freeze time is applied inside `Character`, to whatever its controller sends, so the player, bots and later network players are all held by the same rule.
5. The round manager listens to every participant's `damaged` and `died` signals for the stats and the kill events, and checks for an elimination at the end of the frame (`call_deferred`), so two last players killing each other in the same tick both count.
6. The HUD, kill feed and scoreboard only connect to its signals and read its state (the scoreboard just reads it every frame while Tab is held, D-050): in M9 the host runs it and clients show what it announces. The round HUD (`RoundHud`, D-047) reads `phase`, `time_left`, `score` and the alive counts every frame for the top bar, and builds its messages from `phase_changed`, `round_ended`, `sides_swapped` and `character_killed`; `main.gd` hands it the manager (or null) on every map load.
7. The match: first to `rounds_to_win` rounds (5, 10 or 15). `_end_round()` adds the round to `score[winner]` *before* emitting `round_ended`. When the `ROUND_END` pause is over, `_after_round_end()` decides what comes next: if a team has `rounds_to_win`, it freezes everyone, sets `winner`, enters `MATCH_END` and emits `match_ended(winner)`, and nothing happens after that; otherwise, if the round just played was number `rounds_to_win − 1`, it flips `attacking_team` and emits `sides_swapped`, and then the next round starts. After the flip each team spawns at the other end; team numbers, colors and stats don't change. The longest match is `2 × rounds_to_win − 1` rounds, so there is no draw.
8. `MatchEndScreen` (in `main.tscn`, above the HUD) listens to `match_ended`, reads `score` and, through its `ScoreboardTable`, `get_members()` and `get_stats()`, and shows the result. Its buttons only emit signals; `main.gd` restarts the map or quits.
9. Spectating doesn't touch the round manager: `PlayerController` notices your own death (`died`) and your respawn at the next round start (`on_respawned()`), and the HUD follows its `view_target_changed` signal (D-046).

## Sound

- **Your own** footsteps (−12 dB) and gunshots play through `AudioStreamPlayer` (no position, both ears). **Everyone else's** play through `AudioStreamPlayer3D`, from where they are: footsteps +2 dB, unit size 10 m, fading out at 30 m; gunshots unit size 20 m, out to 120 m (D-038). `Character.is_local_player()` decides which, through `CharacterController.is_local()`.
- The 3D listener is the player's camera inside the world `SubViewport` (`audio_listener_enable_3d` is on). While you spectate a teammate that camera sits at their head, so you hear from where they are, as in CS; no sound routing changes.
- Footsteps play only for loud steps (running). Walking and crouch-walking are silent, matching what bots can hear (D-035).
- Tests set `footstep_sound = null` and use silent weapon data: headless runs have no audio device.

## How a character and its weapon work together

- The player's weapon scene sits under the camera, so the first-person model follows the view.
- The character sets `weapon.trigger_held` from the command. The character processes first and its children after, so the weapon sees the new value in the same tick.
- The weapon sets the character's top speed (`Character.get_max_speed()`).
- The click that recaptures the mouse, and clicks while the mouse is free, never fire (`PlayerController`).
- Shots start at `Character.get_eye_position()` and use `Character.get_aim_angles()`, the aim *without* recoil kick. The ray tests world + hitboxes only, and excludes the shooter's own hit zones (`Character.get_hitbox_rids()`), since it starts inside their head, and, with friendly fire off (`Teams.friendly_fire`), the hit zones of every living teammate, so bullets pass through them as in CS. With friendly fire on, teammates are hit and `Character.take_damage()` scales their damage to a third.
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
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/bot_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/round_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/tactics_test.tscn
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
- **Keep multiplayer possible** (it comes in M9, D-033). See the next section.

## Keeping multiplayer possible

Multiplayer is added in M9, after the single-player game. These rules for M4–M8 keep that retrofit manageable:

1. **Characters only move and shoot through input commands.** A `Character` never reads the keyboard; a controller (player, bot, later network) gives it a `CharacterInput` each tick.
2. **Game rules live in "authority" code, separate from what's shown.** Damage, deaths, round state, money and the bomb are decided by gameplay nodes and announced with signals. HUD, sounds and effects only react to those signals. In M9 the host runs the rules, and clients just show the results.
3. **Gameplay runs in `_physics_process`**, at a fixed tick (128 Hz). `_process` is only for visuals (camera, effects, UI).
4. **Randomness that affects gameplay uses seeded generators** (like `Weapon.rng`), never the global `randf()`. Visual-only randomness (spark directions, hole rotation) can stay global.
5. **Characters and other gameplay objects get stable IDs**, so the host and clients can refer to the same thing.
