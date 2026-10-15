# Chiip — Plan & Roadmap

> Last updated: 2026-10-15
>
> **Current milestone:** M5 — Rounds & game flow (in progress: tasks 1–8 of 13 done)

## Your open checks

Things only you can check, kept here until done instead of moving from milestone to milestone:

- [ ] **Ctrl + click on macOS:** hold Ctrl, click, and watch Shoot/Aim in the F3 overlay. If it shows *Aim*, macOS turns Ctrl + click into a right click while crouching, and we change the crouch key or work around it.
- [ ] **Sensitivity:** compare how far you move the mouse for a 360° turn here and in CS, at your CS sensitivity.
- [ ] **TrenchBroom hands-on:** set up and try TrenchBroom (see README, "Making maps with TrenchBroom") before M8, so the map-tool choice (D-032) can be confirmed.

## How this plan works

- The game is built in **milestones**. Each one ends with something you can play and test.
- Each milestone lists its **tasks** (checkboxes), a **Done when** test, and the **Godot concepts** you learn along the way.
- Status icons: ⬜ not started · 🟨 in progress · ✅ done. Tasks: [x] done, [ ] open, [-] skipped or moved.
- Tasks are ticked here as the work happens. Details of each work session go into [DEVLOG.md](DEVLOG.md).
- Milestones can be reordered or changed at any time. The reason is recorded in [DECISIONS.md](DECISIONS.md).

## Overview

| # | Milestone | Status | What you can play at the end |
|---|---|---|---|
| M0 | Plan & documentation | ✅ | Nothing yet. This plan and the docs exist |
| M1 | Project setup & movement | ✅ | Run, walk, crouch and jump around a test map |
| M2 | Shooting | ✅ | Shoot targets with a rifle that has CS-like recoil |
| M3 | Retro look & map tools | ✅ | The test map looks like a 90s shooter |
| M4 | Bots | ✅ | Bots hunt you and shoot back |
| M5 | Rounds & game flow | 🟨 | Full matches against bots, with teammates, menus and settings |
| M6 | Crew & animation | 🟨 | Four distinct classes that run, crouch, jump, aim, shoot, reload and die, in blue and red; your own arms and rifle on screen |
| M7 | Arsenal, perks & economy | ⬜ | Earn money, buy from the full arsenal, and play each class a little differently |
| M8 | Modes & 3 quick maps | ⬜ | Bomb rounds and team respawn matches on three small, fast maps in rotation |
| M9 | Multiplayer | ⬜ | Play with friends (one hosts), bots fill empty slots |
| — | Backlog | — | Ideas for later |

---

## M0 — Plan & documentation ✅

- [x] Choose the game direction
- [x] Name the game: **Chiip**
- [x] Create the project folder and the documentation structure
- [x] Write the README, game design, plan, architecture, decision log, devlog and learning notes

## M1 — Project setup & movement ✅

**Goal:** a first-person player that moves like in CS, on a simple test map.

- [x] Create the Godot project in this folder (`project.godot`) and the folder structure from [ARCHITECTURE.md](ARCHITECTURE.md)
- [x] Set up git with a Godot `.gitignore` and make the first commit
- [x] Decide the renderer and physics tick rate (see open questions)
- [x] Define input actions (move, jump, crouch, walk, …) in the Input Map
- [x] Build a test map from simple blocks: floor, walls, boxes, ramps, stairs
- [x] Player scene: `CharacterBody3D` with a collision capsule and a camera
- [x] Mouse look with a captured cursor, using CS's sensitivity formula so your CS sensitivity carries over
- [x] CS-style ground movement: acceleration, friction, top speed
- [x] Walking (Shift) and crouching (Ctrl) with a smooth camera height change
- [x] Jumping and air movement (air acceleration, air strafing)
- [x] Debug overlay showing speed and position, like CS's `cl_showpos`
- [x] All movement values editable in the Godot editor for tuning
- [x] Playtest the feel: confirmed good on 2026-10-15, no tuning needed

*Moved to M2:* the Ctrl + click and sensitivity checks weren't part of the playtest report, and they matter once you can shoot.

**Done when:** you can run, walk, crouch and jump around the test map, counter-strafing stops you quickly, and it feels right to you as a CS player.

**You learn:** project structure, nodes and scenes, GDScript basics, `_physics_process`, `CharacterBody3D` and `move_and_slide()`, the Input Map, `@export` variables.

## M2 — Shooting ✅

**Goal:** one rifle with CS-like accuracy and recoil, tested on targets in a shooting range.

**Playtest:** shooting confirmed good on 2026-10-15, no tuning needed.

*Moved to M3:* the Ctrl + click and sensitivity checks (still not reported).

**Tasks**, in order, one commit each:

1. [x] **Physics layers.** Name the layers (world, player, bots, hitboxes, triggers) in Project Settings and assign them, so bullets know what they can hit and players don't collide with hitboxes.
2. [x] **Weapon data.** A `WeaponData` resource (Godot's ScriptableObject) holding every number: damage, fire rate, magazine, reload time, movement speed, accuracy, recoil. The first data file is `weapons/rifle.tres` with AK-like starting values: 36 damage, 600 rounds/min, 30 + 90 rounds, 2.5 s reload, 215 u/s while held.
3. [x] **Firing and ammo.** Full-auto while the button is held, magazine and reserve ammo, reload with R, an empty click. Holding the rifle slows you from 250 to 215 u/s, as in CS. The click that recaptures the mouse doesn't fire.
4. [x] **Hitscan and impacts.** Each shot casts a ray from the center of your view up to 208 m (CS: 8192 units). Bullet holes and sparks appear where it lands; the oldest holes disappear after 100 (raised from 64 so a few full sprays fit on the spray wall).
5. [x] **Accuracy.** Each shot lands randomly inside a cone. The cone is tiny standing still (accurate first shot), smaller crouched, grows with speed above 34% of top speed, and is huge in the air.
6. [x] **Spray pattern and recoil.** A fixed, learnable pattern stored in the weapon data so it can be edited: it climbs for about 10 shots, then sways left and right. The view kicks with part of the recoil (CS-style aim punch) and returns to where you aimed. The pattern resets after a short pause in firing.
7. [x] **Hit zones and damage.** Hitboxes for head ×4, chest and arms ×1, stomach ×1.25 and legs ×0.75, plus damage falloff with distance. A target dummy shows each hit as a floating number, plus a running total.
8. [x] **HUD.** A CS-style crosshair with adjustable size, gap, thickness, color, outline and center dot, optionally dynamic (opens up while moving and spraying). An ammo counter.
9. [x] **Viewmodel.** A blocky placeholder rifle in first person, with a muzzle flash and a kick on every shot. It may poke into walls when you stand right against them; proper viewmodel rendering comes later.
10. [x] **Sounds.** Placeholder gunshot, empty-click and reload sounds (see the decisions below).
11. [x] **Shooting range** on the test map: dummies at 5, 10, 20 and 40 m, a dummy moving side to side, and a large spray wall where bullet holes show your spray pattern.
12. [x] **Debug overlay.** Adds current inaccuracy, the shot number within the spray, and the last hit's zone, distance and damage.
13. [x] **Weapon tests.** Automated checks for fire rate, magazine and reload timing, first-shot accuracy, inaccuracy while moving, damage per zone, falloff, and the spray pattern repeating identically.

**Done when:** first shots standing still hit where you aim, shooting while running sprays everywhere, counter-strafing then shooting hits, the spray pattern can be learned on the spray wall, and a headshot does 4× damage (144, a one-tap like the AK).

**You learn:** Resources, raycasts with `intersect_ray`, physics layers and masks, `Area3D`, signals (weapon → HUD, hitbox → target), custom drawing with `_draw()` for the crosshair, Tweens for kick and flash, particles, audio players, and random numbers with seeds (so tests are repeatable).

**Decisions** (all defaults accepted on 2026-10-15, see D-019 to D-021):

| Question | Default |
|---|---|
| The rifle's name | "Rifle" as a working name; final weapon names are decided in M7 |
| Sounds | Generated by code: short retro noise bursts, no downloads. Alternative: a free CC0 sound pack, downloaded only with your OK |
| Default crosshair | Static and CS-like: green, small gap, no dot. Dynamic is a setting |

## M3 — Retro look & map tools ✅

**Goal:** give Chiip its 90s shooter look (pixelated, chunky textures, moody light) while keeping enemies easy to see, and decide how real maps will be built.

*Your checks (Ctrl + click, sensitivity) moved to "Your open checks" at the top.*

**Tasks**, in order, one commit each:

1. [x] **Pixelated rendering, two variants.** You chose **B (sharp HUD)** (D-027). A: the whole screen, HUD included, rendered at 640 × 360 and scaled up with sharp pixels. B: only the 3D world rendered low-res, with the HUD drawn sharp at full resolution. I make screenshots of both and you pick. The resolution stays adjustable (480 × 270 / 640 × 360 / 960 × 540).
2. [x] **Mouse and crosshair at low resolution.** Checked: 100 mouse counts turn the view exactly 2.200° in both styles; crosshair sizes are rounded to whole pixels. Check that sensitivity doesn't change (it shouldn't, see D-016) and that the crosshair stays pixel-perfect.
3. [x] **Retro texture tool.** A tool script that turns any image into a retro texture: shrinks it to 64 × 64 (or 128 × 128), reduces its colors, and imports it with sharp pixels and mipmaps (no shimmering in the distance).
4. [x] **Texture set.** About 8 textures: concrete floor, plaster wall, brick, sandy ground, wooden crate, metal, dark trim, spray-wall paint (source: see decisions below).
5. [x] **Retro materials.** Textures are placed by world position (triplanar), so any box gets them without UV work, at Quake's texel density (a 64-pixel texture covers 64 units = 1.63 m). Matte surfaces, no shiny reflections. This replaces the grid placeholder.
6. [x] **Retexture the test map.** Crates look like wooden crates, walls get brick and plaster, the floor concrete and sand. The rifle and dummies get matching retro colors. Dummies stay bright enough to stand out (clarity rule).
7. [x] **Lighting and atmosphere.** A darker, moodier scene: lower ambient light, a warm sun, a few colored lamps, distance fog, a retro sky.
8. [-] **Baked lighting experiment.** *Skipped, moved to M8.* `maps/comparison/trenchbroom_room.tscn` is ready to bake (`LightmapGI`, lights set to bake), but baking only works from the editor's button, and you chose to bake on the real map instead. Bake lightmaps (`LightmapGI`) for the test map and compare with real-time lighting, then decide which to use. Godot bakes on the GPU in the editor, so this step may need one click from you (I'll show where) if it can't be automated.
9. [x] **Optional color palette effect.** You chose **on** (D-030). A full-screen shader that limits colors (fewer shades per channel, optional dithering), switchable. Screenshots on/off; you decide.
10. [x] **How maps get built.** **TrenchBroom** for real maps, CSG for quick tests (D-032). Provisional until your hands-on trial (see "Your open checks"). The same small CS-style room (doorway, crates, a ramp) built twice: with CSG in Godot, and with TrenchBroom (the Quake map editor, very close to CS's Hammer) imported through the `func_godot` plugin. We compare effort, texture alignment, collision and baked lighting, then decide the workflow for the real map in M8.
11. [x] **Credits.** `docs/CREDITS.md` lists every third-party asset and tool with its source and license.
12. [x] **Checks.** Screenshots of every area; both test suites pass; 120 fps (the display's limit) with the slowest 1% of frames at ~10 ms on an Apple M5, world image 640 × 360. Screenshots of every area of the test map, both test suites still passing, and a frame-rate check at the chosen resolution.

**Playtest:** the look confirmed good on 2026-10-15.

**Done when:** the test map and range look like a 90s shooter, dummies remain easy to spot, the HUD is readable, and we know how the real map in M8 will be built.

**You learn:** viewports and stretch modes, `SubViewport`, texture import settings (filtering, mipmaps), triplanar mapping, the `Environment` (fog, ambient light, tonemapping), `LightmapGI` and lightmap UVs, full-screen (post-process) shaders, installing and using an addon.

**Decisions** (recommendations accepted on 2026-10-15, see D-024 to D-026):

| Question | Options | My recommendation |
|---|---|---|
| Where textures come from | **(a)** Download a few free CC0 textures from ambientCG (public domain photo textures) and turn them retro with our tool. Each download only with your OK. **(b)** Generate textures by code, with no downloads. | **(a):** much better looking, and CC0 means free to use with no strings attached |
| Map tool comparison (task 10) | **(a)** Compare now: you install TrenchBroom (free), and I download the `func_godot` addon with your OK. **(b)** Skip for now, keep CSG, and decide in M8. | **(a):** M3 is where the pipeline gets decided, and TrenchBroom is the classic Quake/CS way to build maps |
| HUD font | **(a)** Download a free pixel font (SIL Open Font License) with your OK. **(b)** Keep Godot's default font for now. | **(a)** if you pick variant A (pixelated HUD) in task 1, otherwise either works |

The pixelation variant (task 1) and the palette effect (task 9) are decided during M3 from screenshots.

## M4 — Bots ✅

**Goal:** enemies that move around, spot you and fight back fairly, playing by exactly the same movement and shooting rules as you.

**The key idea:** bots shouldn't get their own movement or shooting code. As in CS, every character (you or a bot, and later maybe a network player) is driven by a small per-tick **input command**: which keys are held, where it looks, whether it shoots. Your keyboard and mouse produce commands; a bot's brain produces commands. The character simulates them identically. This keeps bots fair, and it's also the structure multiplayer needs (see the decision below).

**Tasks**, in order, one commit each:

1. [x] **Shared character.** Split today's `Player` into a `Character` (movement, crouching, jumping, weapon, all the CS rules) that only follows `CharacterInput` commands, plus a `PlayerController` that turns your keyboard and mouse into commands and owns the camera. All 33 existing movement and weapon checks must still pass unchanged.
2. [x] **Health and hit zones on characters.** Characters get 100 HP and the same CS-sized hit zones as the dummies (head ×4, …). Taking damage, dying, and a `died` signal. Armor moved to M7.
3. [x] **Navigation mesh.** A `NavigationRegion3D` baked for the test map, so bots know where they can walk (stairs, ramp, crouch tunnel excluded or marked).
4. [x] **Bot body and movement.** A bot scene: a character with a blocky, clearly colored soldier model holding the rifle, and a `NavigationAgent3D` that turns paths into movement commands (run, walk when sneaking, crouch).
5. [x] **Perception.** Vision: a field of view plus line-of-sight rays to head and body, so no wallhacks. Hearing: running footsteps and gunshots within range; walking is silent. Bots remember where they last saw or heard you.
6. [x] **Behaviour.** A state machine: patrol (between points on the map) → engage (fight) → search (go to the last known position) → back to patrol.
7. [x] **Fighting like a human.** Reaction time before the first shot, aim that starts off and settles onto you, stopping (counter-strafing) before shooting, tapping at range and spraying up close with partial recoil control. Difficulty presets Easy / Normal / Hard change these numbers.
8. [x] **Footsteps.** Generated footstep sounds for you and bots; bots' steps and shots are positional 3D sound. Walking (Shift) is silent, like CS.
9. [x] **Death and respawn.** Characters collapse when killed (a simple fall-over, no ragdoll yet); bots respawn after a few seconds, and you respawn on death until rounds exist in M5.
10. [x] **Developer console** (`` ` `` key): `bot_add [easy|normal|hard]`, `bot_kick`, `bot_difficulty`, `noclip`, `god`, `map <name>`, `help`.
11. [x] **Bot arena.** Patrol points and spawn points on the test map, so 1–5 bots have room to fight you.
12. [x] **Bot tests.** Automated checks: a bot walks to a point; it spots you in its view but never through a wall; it waits its reaction time before shooting; a Normal bot lands roughly the expected share of shots at 10 m; it dies at 100 damage.

**Playtest 1 (2026-10-15):** too deadly ("no chance", aimed instantly), gliding, unnatural turning, sounds not clear. Fixed in D-037 to D-039: gradual noticing and slower aim, eased turning and search sweeps, a procedural walk cycle, and a sound clarity pass.

**Playtest 2 (2026-10-15):** the bots feel OK now; your own footsteps were too loud, so they went from −7 to −12 dB. **M4 closed** after this playtest.

**Done when:** you can fight 1–5 bots on the test map and they feel fair: they react with a delay, miss sometimes, stop to shoot, can be outplayed, never see through walls, and don't hear you walking.

**You learn:** composition (one `Character`, different controllers), `NavigationRegion3D` / `NavigationAgent3D`, state machines, raycasts for vision, `AudioStreamPlayer3D`, groups, timers, autoloads (Godot's singletons, for the console).

**Multiplayer:** decided, it comes in M9 after the single-player game (D-033). M4 builds the command-driven character, which M9 will reuse for network players.

## M5 — Rounds & game flow 🟨

**Goal:** a real game. Start a match from the main menu, fight round after round with bot teammates against a bot team, and play until one team wins. Settings are saved to disk. (Health came early, in M4.)

**The key idea:** one **round manager** owns the game state (freeze time → live → round end, score, who's alive) and announces changes with signals. HUD, scoreboard, spectating and menus only listen. That's the "authority" rule from ARCHITECTURE.md, so in M9 the host can run the round manager and everyone else just shows it.

**Tasks**, in order, one commit each. The tag says which model builds it (CLAUDE.md, "Choosing a model"):

1. [x] **Teams and spawns.** Two teams without names (D-041). You always see your own team in blue and the enemies in red, so enemies stand out for every player, including in M9. Internally the two sides are *attacking* and *defending* ends of the map, with five spawn points each at opposite ends of the test map. Bot teammates use the same bot scene. Friendly fire is a match setting: off by default; when on, teammates take a third of the damage, as in CS competitive. *(Sonnet)* Built as `systems/teams.gd` (D-042); with friendly fire off, bullets pass through teammates.
2. [x] **Round manager.** Freeze time of 5 s (you can look around but not move or shoot) → live round with a timer → round end. A round is won by eliminating the other team; when time runs out, the defending side wins, as in CS. At each round start, everyone gets full health, ammo and a spawn point. Whoever dies stays dead until the next round. Replaces today's respawning `ArenaRules` in matches. *(Opus: game state design)* Built as `systems/round_manager.gd` with `MatchSettings` (D-043); F5 now starts a 3v3 match, `-- --practice` the old arena.
3. [x] **Match flow.** Score and first to 5, 10 or 15 rounds. Sides swap at half time (after 4, 9 or 14 rounds, so a draw is impossible). A match-end screen shows the winner and the scoreboard. *(Sonnet)* Built as score, half time and match end in `RoundManager`, plus `ui/match_end_screen.tscn` with Play again and Quit until the main menu exists (D-044).
4. [x] **Bots play rounds.** Today's bots wander between patrol points, so a round could stall. The attacking side pushes toward the defending end in loose groups. Defenders hold angles near their end, then rotate toward fights they hear. Bots hold fire while a teammate is in the line of fire. *(Opus: AI)* Built as `bots/bot_tactics.gd` with attack routes and hold spots on the test map (D-045).
5. [x] **Spectating.** After you die, watch a living teammate through their eyes, like CS. Click to switch to the next teammate. If no teammate is alive, you see the end of the round from where you died. *(Sonnet)* Built in `PlayerController` (D-046): about 2 s after you die in a match the camera moves to a living teammate's head and aim, a click switches, the HUD shows their health and ammo; practice mode has none.
6. [x] **Round HUD.** Top bar: round timer, score (yours vs. theirs), and players alive per team. Also a kill feed (killer → victim, with a headshot mark, in team colors), round-end banners ("Round won" / "Round lost"), and the freeze-time countdown. *(Sonnet)* Built as `ui/round_hud.tscn` + `kill_feed.gd` inside the HUD (D-047): a top bar (your score in blue, the timer, their score in red, a square per player alive), the freeze countdown with your side, "Switching sides" and match point, round-end banners, and a kill feed ("Killer > Victim", team colors, "HS", your own lines outlined, 5 lines, fading after 5 s); practice mode shows none of it.
7. [x] **Scoreboard** (hold Tab): both teams with kills, deaths, assists and damage, and who's alive. *(Sonnet)* Built as `ui/scoreboard.tscn` + `scoreboard_table.tscn`: hold Tab (new `scoreboard` action) for a centre panel with the round, the score (yours blue, theirs red) and a table of both teams, yours first (name, kills, deaths, assists, damage, sorted by kills then damage, your row highlighted, dead players' rows dimmed); only in a match, hidden while the console is open or the match is over. The match-end screen now uses the same table.
8. [x] **UI theme.** One Godot `Theme` for every menu: pixel font, colors, buttons, sliders, tabs. It keeps menus consistent and changeable in one place. *(Sonnet, with screenshots for you to judge)* Built as `ui/chiip_theme.tres` (D-057), the project theme: Silkscreen at 16 / 32 / 48 px, square 2 px borders, dark blue-grey with one cyan accent, styles for buttons, panels, labels, line edits, sliders, check boxes and switches, option buttons with their list, tabs, scroll bars and tooltips, and 25 type variations for roles (title, section header, team header, rows...). Generated by `tools/make_ui_theme.gd` from `tools/ui_palette.gd` and the pixel-art icons of `tools/generate_ui_icons.gd`. `UiTheme.apply()` scales a menu by giving it a scaled copy of the theme (exactly 1.5× at 1080). The match-end screen, the Tab scoreboard and the console moved onto it; `ui/theme_preview.tscn` shows every control; new `tests/ui_test.tscn` (35 checks).
9. [ ] **Settings, saved to disk.** A `Settings` class, saved as `user://settings.cfg` and applied the moment something changes. Settings: sensitivity (CS-compatible numbers), field of view, volumes through audio buses (master, effects, interface), crosshair, key bindings, and video (fullscreen, V-Sync, FPS cap, pixel resolution, palette effect, pixelated HUD). *(Sonnet)*
10. [ ] **Settings menu.** Tabs for Game, Video, Audio, Crosshair (with a live preview) and Controls (click an action, then press its new key). *(Sonnet)*
11. [ ] **Main menu and match setup.** Main menu: Play, Practice, Settings, Quit, over a slow camera flight across the map. Play opens match setup: team sizes (1–5 per side, you included; 3v3 by default), bot difficulty, match length (first to 5, 10 or 15; 5 by default) and friendly fire. Practice is today's respawning bot arena, kept for warm-ups and testing. *(Sonnet)*
12. [ ] **Pause menu.** Esc pauses the game: Resume, Settings, Leave match. Single-player only; in M9 it becomes an overlay that doesn't pause. *(Sonnet)*
13. [ ] **Tests and checks.** Rounds end on elimination and on time-out, with the right winner. Score, half-time swap and match end. Friendly fire off and on. Settings survive a save and load. The existing 45 checks still pass. A full 3v3 match runs without errors. *(Sonnet writes, Haiku runs and reports)*

**Done when:** you can start a match from the main menu, play it to the end with bot teammates against bots, see the score, kill feed and scoreboard, change settings, and find them still there after restarting the game.

**You learn:** game state with signals, switching scenes (`change_scene_to_packed`), pausing (`process_mode`), saving data (`ConfigFile`, `user://`), UI containers and themes, audio buses, remapping input at runtime (`InputMap`).

**Decisions** (made on 2026-10-15, see D-041):

| Question | Decision |
|---|---|
| Team setup | You plus bot teammates vs. bots; 3v3 by default, 1–5 per side in match setup |
| Match length | First to 5 (default), 10 or 15, chosen in match setup |
| Freeze time | 5 s now; 15 s once the buy menu exists (M7) |
| Armor | None until the economy: armor and helmet are bought from M7 on |
| Friendly fire | A match setting: off by default, a third of the damage when on |
| Team names | No names. Your team is shown in blue and the enemies in red |

## M6 — Crew & animation 🟨

**Goal:** a crew of four classes that look and move like people, from the outside and in first person (D-040, D-051). Replaces the blocky placeholder and its code-driven walk cycle (D-039).

**The key idea:** characters and weapons are *generated* from part lists by a tool (D-054). Each part is a low-poly piece (a bevelled box, a tapered cylinder, a low-res sphere) fixed to one bone, like the segmented models of late-90s shooters. The tool writes a `.glb` file with the skeleton, texture, team mask and animations, and Godot imports it like any other model. Changing a class means changing numbers and running the tool again. Team colour isn't baked into the texture: a shader paints the masked parts blue or red depending on who is looking (D-053, D-041).

**Tasks**, in order, one commit each. The tag says which model builds it (CLAUDE.md, "Choosing a model"):

1. [x] **Concept sheets.** Adapt the sprite prototype in `tools/concept/` to the crew and the team-colour rule: a neutral kit, team colour on the masked parts, no desert colours (D-031). Render turnarounds of all four classes in blue and red. You approve the looks and the class names before any modelling. *(Opus)* Approved as shown, names final (D-070): `spritegen.py --sheet` renders a line-up (blue, red and black silhouettes with height lines) and 8-direction turnarounds; every class has team-colour sleeves plus one mark of its own, 11–23% of the body from every side. Python now runs in Miniconda (D-071).
2. [x] **Model generator v1.** A Python tool in `tools/modelgen/` that builds the Rifleman from a part list: the low-poly mesh, a palette-limited texture with a team mask, and a skeleton with each piece fixed to one bone. It exports a `.glb` that Godot imports, shown in a T-pose. *(Opus)* Built (D-072): `modelgen.py rifleman` writes `assets/models/crew/rifleman.glb` (17 bones, 50 pieces, 2,106 triangles, exactly 1.82 m) with a 256 × 352 palette texture and a team mask; `characters/crew/crew_preview.tscn` shows it on a turntable.
3. [x] **Team-colour shader.** Paints the masked parts in the viewer's team colours (your team blue, enemies red: `Teams.FRIENDLY_COLOR` and `Teams.ENEMY_COLOR`, D-042) and keeps the shading. `Teams.set_viewer_team()` recolours everyone through it, as it does today. *(Sonnet)* Built (D-073): `characters/crew/crew.gdshader` multiplies the grey team texels by an `instance uniform` colour, one shared material per class; `CrewBody` (`crew_body.tscn`) builds a model and takes `set_team_color()`, the same call `SoldierBody` now has, so `Character.update_team_color()` works with either body; the turntable shows blue and red (T); new `tests/crew_test.tscn` (15 checks).
4. [x] **Hit zones on bones.** A `BoneAttachment3D` per zone (head, chest, stomach, arms, legs), sized from the class's part list (D-055). The blocky `SoldierBody` is retired. All existing checks still pass. *(Sonnet)* Built (D-074): the generator writes `<class>_hit_zones.tres` (a `HitZones` resource, 15 boxes), `CrewBody` builds a `BoneAttachment3D` + `Hitbox` + box per entry under the model's skeleton, `Character.body` is a `CrewBody` (`SoldierBody` deleted), and bots aim at and look for the zones' centres (`get_head_position()`, `get_chest_position()`); 16 new checks in `tests/crew_test.tscn`; the tactics check "Rounds are decided by fighting" now plays 8 rounds (6 must end by elimination, the same 75%) because 4 seeded rounds were too few (see the devlog).
5. [x] **Long-gun animations**, written as keyframes by the generator: idle; walk and run in 8 directions; crouch and crouch-walk; jump, fall and land; aim up and down; fire; reload; a hit flinch; three deaths (forward, backward, headshot). *(Opus, tuned by feel)* Built (D-075): `tools/modelgen/anims.py` solves every pose for the class with two-bone IK (feet on their targets, both hands on the gun) and writes 41 clips into the `.glb` at 30 keys a second; locomotion cycles last 0.66 s, so a run step is 1.8 m like the footstep sounds; fire and the flinch are additive; the AK-style rifle (`assets/models/weapons/ak_rifle.glb`) sits on the weapon bone. N / P in the crew preview play them.
6. [x] **AnimationTree.** The legs blend by speed and by direction relative to where the character faces. The upper body aims up and down on its own and layers fire, reload and the flinch on top. Driven only by the character's state, never by input, so network players animate the same way in M9. *(Opus)* Built (D-076): one shared graph, `characters/crew/crew_animation_tree.tres` (made by `tools/make_crew_animation_tree.gd`); `CrewBody` sets it every physics tick from velocity, stance, floor contact and aim pitch, and plays the character's shots, reloads, hits, deaths and respawns; the AK-style rifle is in the hands with its own muzzle flash, and the first-person viewmodel shows only for whoever looks through a character's eyes; 15 new crew checks.
7. [x] **The other three classes:** Bulwark, Marksman and Scout, built from the approved concept sheets. *(Opus)* Built (D-077): `modelgen.py all` makes all four (1,800–2,400 triangles each, exactly 1.72–1.92 m, 41 clips each, solved for their own limbs); the Bulwark's hit zones are about twice the Rifleman's, the Scout's 60% (a point for your playtest).
8. [x] **Class data and class pick.** A `ClassData` resource per class: name, model, hit-zone sizes and perk values. You pick a class at match start and can change it during freeze time (D-052); bots get a mix. Classes differ only in looks until the perks switch on in M7. *(Sonnet)* Built (D-078): `ClassData` resources in `characters/crew/classes/` (name, role, height, model, hit zones, signature gun, look, perk text and the stored-but-inert perk factors) with `ClassData.all()` / `find()`; `Character.class_data` swaps the body's model and hit zones at runtime (`CrewBody.set_class()`); the `RoundManager` decides class changes (`request_class()`: freeze time only; practice mode any time), gives each team's bots a mix cycling from a random class, and applies `MatchSettings.player_class`; a class menu (`ui/class_menu.tscn`) opens at the start of a match and on M during freeze time (click or keys 1 to 4); console command `class [name]`; new `tests/class_test.tscn` (57 checks).
9. [ ] **First-person arms.** Arms for each class (its own gloves and sleeves, sleeves in your team colour), made by the same generator, holding the AK-style rifle: draw, fire and reload animations, plus weapon sway and bob in code. *(Opus)*
10. [ ] **Performance and tests.** 10 animated characters on the test map at full frame rate. New checks that hit zones follow the animated body; the existing checks still pass. *(Sonnet writes, Haiku runs and reports)*

**Done when:** all four classes visibly run, crouch, jump, aim, shoot, reload and die, in blue and red; you can tell the classes apart by silhouette alone; hit zones follow the animated body; and you see your own arms and rifle in first person.

**You learn:** importing glTF, `Skeleton3D`, `BoneAttachment3D`, `AnimationPlayer` vs. `AnimationTree` (Unity's Animator), blend spaces, animation filters (Unity's avatar masks), shaders with per-instance parameters.

**Decisions** (made on 2026-10-15, see D-051 to D-056):

| Question | Decision |
|---|---|
| Characters | Rigged low-poly 3D models. The sprite prototype is concept art. First person keeps a 3D viewmodel |
| Classes | Four classes, each a look plus one passive perk. Anyone can buy any weapon |
| Look | A distinct crew, told apart by silhouette. Team colour is painted at runtime |
| Where models come from | Generated by a tool in `tools/modelgen/`, not modelled by hand or taken from asset packs |
| Hit zones | Follow each class's body, so the tall Bulwark is a bigger target |
| Class choice | At match start, changeable during freeze time |
| Class names | Rifleman, Bulwark, Marksman, Scout: final (D-070) |

## M7 — Arsenal, perks & economy ⬜

**Goal:** CS's buy-or-save decisions with a full arsenal, and classes that each play a little differently. Planned in detail when M7 starts.

- [ ] Armor and helmet, bought in the buy menu (moved from M5, D-041). CS:GO's rules: armor covers chest, stomach and arms, the helmet covers the head, and each weapon's *armor penetration* (rifle: 77.5%, like the AK) sets how much damage gets through; armor wears down as it absorbs hits. Armor on the HUD
- [ ] Money: rewards for wins, losses (with loss bonus) and kills
- [ ] Buy zone and buy menu (B) during freeze time (15 s from now on)
- [ ] Weapon slots, switching, dropping and picking up weapons
- [ ] The full arsenal (D-056): AK-style rifle, carbine, SMG, pump shotgun, sniper rifle, service pistol, hand cannon and knife. Stats in one data file each, and a balancing table that exports to a spreadsheet
- [ ] Weapon models from the generator (D-054): a world model, a third-person model on the hand bone, a first-person model, and buy-menu and kill-feed icons rendered from the model
- [ ] Holds and animations for pistols, the knife and grenades, in first and third person, and a reload for each weapon
- [ ] Grenades: high explosive, flashbang, smoke
- [ ] Class perks switch on (D-052), now that armor and scopes exist
- [ ] Bots choose a class and buy based on their money
- [ ] Weapon names

**Done when:** you play several rounds where buying, saving and eco rounds actually matter, and each class plays a little differently.

**You learn:** inheritance vs. composition in Godot, particle systems, rendering to a texture (`SubViewport`) for icons, more advanced UI.

## M8 — Modes & 3 quick maps ⬜

**Goal:** fast, action-packed maps like Call of Duty's, three of them in rotation, playable in two modes: CS-style bomb rounds and a team respawn mode (D-049).

- [ ] **Map rules:** small and fast: about 40–60 m across, three lanes with connections between them, first contact within 5–10 s of spawning, and short sightlines. Every map works in both modes: two bomb sites plus spawn zones for respawning. Sketch all three on paper first
- [ ] **Maps 1, 2 and 3** in TrenchBroom (D-032), each one blockout → bot test → detail: navmesh, side spawns, bomb sites, bot attack routes and hold spots. Three distinct looks within the no-desert rule (D-031)
- [ ] **Map rotation:** match setup picks a map or "Rotation"; after a match, "Next map" continues to the next one
- [ ] Baked lighting (lightmaps) for the maps, moved from M3, and a decision on baked vs. real-time lighting
- [ ] **Bomb:** carry, plant, timer, explosion, defuse (faster with a kit)
- [ ] **Bots play the objective:** attack a site, plant, rotate, defuse
- [ ] **Team respawn mode** (like CoD's Team Deathmatch): you respawn about 3 s after dying, at a spawn point away from enemies; the first team to a kill limit wins, or the team with most kills when the time runs out. Grows out of today's Practice arena
- [ ] **Bots in the respawn mode:** hunt in small groups instead of attacking and holding
- [ ] Full sound pass: weapons, footsteps on different surfaces, bomb beeps, UI
- [ ] Performance check and the first exported macOS build

**Done when:** you can play both modes on all three maps against bots, the rotation moves from map to map, and it runs from an exported app.

**You learn:** level design in TrenchBroom (lanes, sightlines, timing), lightmap baking, `Area3D` triggers, spawn selection, exporting a game.

## M9 — Multiplayer ⬜

**Goal:** play Chiip with friends. One player hosts, others join, and bots fill the empty slots (D-033).

- [ ] Networking foundation: Godot's high-level multiplayer (ENet), host/join by IP on a LAN
- [ ] Server authority: the host runs the game rules (damage, rounds, money, bomb); clients send their per-tick input commands (from M4)
- [ ] Client-side prediction and correction for your own movement, so it stays as responsive as single-player
- [ ] Lag compensation for hitscan shots: the host checks hits against where targets were when you fired
- [ ] Replicate rounds, economy, bomb and bots to all players
- [ ] Lobby: host/join, team choice, bots fill empty slots
- [ ] Steam lobbies and friend invites via the GodotSteam addon
- [ ] Network tests: simulated latency and packet loss

**Done when:** you and a friend can play a full bomb-defusal match together against bots, over LAN and through a Steam lobby, and shooting feels fair at normal pings.

**You learn:** Godot's multiplayer API (RPCs, `MultiplayerSynchronizer`, `MultiplayerSpawner`), authority, prediction, lag compensation, Steamworks basics.

## Backlog (ideas, not scheduled)

- Ragdoll deaths (`PhysicalBone3D`) instead of, or blended with, the death animations (M6 uses animations)
- More maps and map voting
- Wallbangs and tagging
- Smarter team AI: callouts, trades, coordinated site takes
- Training modes: aim trainer, spray practice, movement maps (KZ- or surf-style)
- Match statistics (K/D, ADR, headshot %) and a stats screen
- Demo recording and replays
