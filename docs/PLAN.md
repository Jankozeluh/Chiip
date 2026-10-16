# Chiip — Plan & Roadmap

> Last updated: 2026-10-15
>
> **Current milestone:** M7 — Arsenal, perks & economy, in progress (the task list is in the M7 section). M5 — Rounds & game flow, M6 — Crew & animation and M8 — Modes & 3 quick maps (bomb rounds, team respawn, three quick maps in rotation, sound pass, export) are built and wait for your playtest in "Your open checks".

## Your open checks

Things only you can check, kept here until done instead of moving from milestone to milestone:

- [ ] **Ctrl + click on macOS:** hold Ctrl, click, and watch Shoot/Aim in the F3 overlay. If it shows *Aim*, macOS turns Ctrl + click into a right click while crouching, and we change the crouch key or work around it.
- [ ] **Sensitivity:** compare how far you move the mouse for a 360° turn here and in CS, at your CS sensitivity.
- [ ] **Confirm weapon names** (M7, D-090): Ram (AK-style rifle), Warden (carbine), Hornet (SMG), Breaker (pump shotgun), Heron (sniper rifle), Sparrow (service pistol), Verdict (hand cannon), Knife, Frag, Flashbang, Smoke. Keep them, or tell me the ones you'd rather have: only the data files change.
- [ ] **M5 playtest** (rounds & game flow). Start the game: the main menu appears. Then:
  - **Play** a default match (3v3, first to 5). In freeze time you can look but not move or shoot, and the line in the middle says whether you attack or defend.
  - Watch the bots: blue teammates and red enemies attack in loose pairs along three lanes or hold angles near the north end. Rounds should end in fights, not drag on.
  - **Round HUD:** timer, score, alive squares, kill feed (HS marks, your kills outlined), "Round won/lost" banners, "Switching sides" after round 4, "Match point".
  - **Die once:** 2 s on your death view, then you watch a teammate through their eyes; click for the next one.
  - **Hold Tab** for the scoreboard. At the end: Victory/Defeat with the scoreboard, **Play again**, **Main menu**.
  - **Esc** pauses (the game freezes): Resume, Settings, Leave match.
  - **Settings:** set your CS sensitivity and FOV, volumes, the crosshair (live preview), and rebind a key. Quit and restart: they're still there.
  - **Match setup:** try 1v5 or 5v5, Hard bots and friendly fire on; also **Practice** (the old arena, bots respawn).
  - Tell me: bot difficulty and tactics, round pacing (1:55 on this map), whether the UI is readable, and anything confusing.
- [ ] **TrenchBroom hands-on:** set up and try TrenchBroom (see README, "Making maps with TrenchBroom") before M8, so the map-tool choice (D-032) can be confirmed.
- [ ] **Playtest the three quick maps:** `map depot`, `map square`, `map spillway` in the console (docs/MAPS.md). How do they feel, what should change, and what should they be called?
- [ ] **M8 playtest: bomb rounds** (`-- --map res://maps/depot.tscn`, also Square and Spillway). As an attacker with the bomb: hold **E** inside A or B to plant (3.2 s, you can't move); does the gold BOMB tag, the "Hold E to plant" prompt and the bar read well? As a defender: retake and hold E next to the bomb (10 s). Do the bots plant, guard the bomb, retake and defuse believably? Are 40 s of fuse and the blast (lethal to ~13 m) right for maps this small? (D-080, D-081)
- [ ] **M8 playtest: team respawn** (`-- --map res://maps/square.tscn --respawn`). Do you respawn somewhere safe (never in front of an enemy)? Is a match to **50 kills** (about 4 minutes with bots) the right length, and do the bots hunting in pairs feel like CoD? Does Depot's fighting pile up too much in the warehouse? (D-082, D-083)
- [ ] **M8 playtest: sound.** With headphones: can you tell gravel, concrete, metal (container and warehouse roofs) and wood (crates) apart by the footsteps? Is the headshot "dink" satisfying and the body hit clear? Are the round stingers, the "go" beep, the bomb-planted alert and menu clicks pleasant, or too loud? (D-084)
- [ ] **M8: the exported app.** Double-click `builds/macos/Chiip.app` in the `m8-maps` worktree (or re-export, README "Exporting the game"): does it start, play a match and quit normally? (D-086)
- [ ] **M8 playtest: modes and rotation in match setup.** Play → choose **Team respawn** (the length turns into 30 / 50 / 75 kills) and **Rotation** (the summary lists the maps), Start: you begin on Depot (or the map you picked if it's one of the three). After the match, **Next map: Square** gives a fresh match there; Play again stays. Is the setup panel clear, and is the rotation's order right? (D-087)
- [ ] **M8: lighting.** Look at `docs/maps/lighting_depot.jpg`: is staying with real-time lighting (left column) right, or do you want SSAO as a video setting, or a lightmap bake once the maps are final? (D-085)
- [ ] **M6 playtest (crew & animation).** Start a match (F5); the class menu opens in the first freeze time (M changes class in any freeze time, `-- --practice` and the console's `class` command any time). Check:
  1. **Silhouettes:** you can tell the four classes apart at a distance by shape alone: the medium Rifleman, the broad Bulwark, the Marksman in his coat, the short Scout with the antenna.
  2. **Team colour:** teammates blue, enemies red, readable from every side and at range.
  3. **Animation:** bots run, strafe, walk backward, crouch-walk, jump, aim up and down, fire (flash in the hands), reload and die (forward, backward, the headshot crumple) without popping or sliding badly; the Bulwark hunches.
  4. **Your arms:** your class's own gloves, sleeves in your team's blue; the draw after respawning, the kick, the reload; the gun lags a little when you turn and rocks when you run. Does the gun sit right (low right, receiver and magazine visible)?
  5. **Hit zones:** headshots land on the heads you see, also on crouching and running bots. Is the Bulwark a fair target? Its zones are about twice the Rifleman's (D-077).
  6. **Spectating:** after dying, the teammate you watch shows their own first-person arms.
  7. **Smoothness:** no stutter with ten characters (a 5v5 from match setup, or `bot_add` in practice).

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
| M5 | Rounds & game flow | ✅ | Full matches against bots, with teammates, menus and settings |
| M6 | Crew & animation | 🟨 built, waiting for your playtest | Four distinct classes that run, crouch, jump, aim, shoot, reload and die, in blue and red; your own arms and rifle on screen |
| M7 | Arsenal, perks & economy | 🟨 in progress | Pick up and buy from the full arsenal with a light economy, fight over power weapons, and play each class a little differently |
| M8 | Modes & 3 quick maps | ✅ | Bomb rounds and team respawn matches on three small, fast maps in rotation (built; your playtest is open) |
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

## M5 — Rounds & game flow ✅

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
9. [x] **Settings, saved to disk.** A `Settings` class, saved as `user://settings.cfg` and applied the moment something changes. Settings: sensitivity (CS-compatible numbers), field of view, volumes through audio buses (master, effects, interface), crosshair, key bindings, and video (fullscreen, V-Sync, FPS cap, pixel resolution, palette effect, pixelated HUD). *(Sonnet)* Built as `systems/settings.gd` (D-058): a plain class with a shared instance (`Settings.get_instance()`, not an autoload) that starts at the defaults and, once the game calls `load_from_disk()`, saves every change to `user://settings.cfg` (sections game, video, audio, crosshair, controls; forgiving when read: clamped, defaults for gaps). Each change is applied at once and announced with `changed(key)`: the player controller (sensitivity, Y inversion, CS-style 90° FOV across 4:3), the crosshair (the whole style), `main.gd` (pixel height, pixelated HUD, palette effect), and `Settings` itself (fullscreen, V-Sync, `fps_max`, bus volumes, key bindings in the `InputMap`). New `default_bus_layout.tres` with Master, Effects and Interface; all game sounds play on Effects. 13 actions rebindable with two slots each (API for the menu). Console: `sensitivity`, `fov`, `volume`, `fps_max`, `settings_reset`. New `tests/settings_test.tscn` (63 checks).
10. [x] **Settings menu.** Tabs for Game, Video, Audio, Crosshair (with a live preview) and Controls (click an action, then press its new key). *(Sonnet)* Built as `ui/settings_menu.tscn` + `.gd` (`SettingsMenu`, D-059), a reusable themed menu that hides until `open()` and emits `closed`: Game (sensitivity slider with an exact number field, invert Y, field of view), Video (fullscreen, V-Sync, frame limit, pixel resolution, palette effect, pixelated HUD), Audio (three volume sliders), Crosshair (color swatches and a hex code, opacity, size, gap, thickness, outline, dot, dynamic, with a live preview: a real `Crosshair` on a dark and a light patch) and Controls (click a slot, press the new key or mouse button; Esc cancels, Backspace clears; a key belongs to one action, so the other one loses it, and a line says so). Every control writes to `Settings` at once and follows its `changed` signal; "Reset tab to defaults" per tab. New `ui/menu_state.gd` (`MenuState`) is the one place that says a menu is open (the console registers too): the player controller ignores input, the Tab scoreboard stays hidden and the mouse is shown, then captured again when the last menu closes. Opened for now by the console command `settings` (tasks 11 and 12 add the menus that open it); the console output now scrolls (mouse wheel, Page Up / Down) and shows 16 lines, so `help` fits. `ui_test` grew from 35 to 78 checks.
11. [x] **Main menu and match setup.** Main menu: Play, Practice, Settings, Quit, over a slow camera flight across the map. Play opens match setup: team sizes (1–5 per side, you included; 3v3 by default), bot difficulty, match length (first to 5, 10 or 15; 5 by default) and friendly fire. Practice is today's respawning bot arena, kept for warm-ups and testing. *(Sonnet)* Built as `ui/main_menu.tscn` + `.gd` (`MainMenu`, now the project's main scene, D-064): the title CHIIP and four themed buttons over the test map rendered like the game (its `Player` removed before it enters the tree, so nothing plays) with a camera that flies an 80 s loop (`MenuFlight`: `Path3D` + `PathFollow3D`). Play opens `ui/match_setup.tscn` (`MatchSetup`): your team and the enemy team 1–5, Easy / Normal / Hard, first to 5 / 10 / 15, friendly fire Off / On and a map (every scene in `res://maps/`), Back and Start; the choices are stored in `Settings` (a new `[match]` section) so the next start offers the same match. Start and Practice leave a `GameLaunch` description (static variables) and change to `main.tscn`, which reads it; `-- --match`, `--practice` and `--map` still skip the menu. The match-end screen's Quit became **Main menu**, and the console got `disconnect`. `ui_test` grew from 78 to 111 checks.
12. [x] **Pause menu.** Esc pauses the game: Resume, Settings, Leave match. Single-player only; in M9 it becomes an overlay that doesn't pause. *(Sonnet)* Built as `ui/pause_menu.tscn` + `.gd` (`PauseMenu`, D-065): Esc opens a themed panel (Paused; Resume, Settings, Leave match / Leave practice) and sets `get_tree().paused`, so the whole world stands still (round timer, bots, weapons, tweens, sounds); the pause menu, settings menu, console and Tab scoreboard have `process_mode = Always`. Esc resumes; in the settings menu (opened from the pause menu) it comes back; the console and the match-end screen take it first. The action `toggle_mouse` is now `pause` (Esc, fixed). Leave unpauses and calls `return_to_menu()`. `ui_test` has 132 checks now.
13. [x] **Tests and checks.** Rounds end on elimination and on time-out, with the right winner. Score, half-time swap and match end. Friendly fire off and on. Settings survive a save and load. The existing 45 checks still pass. A full 3v3 match runs without errors. *(Sonnet writes, Haiku runs and reports)* Built as `tests/match_test.tscn` (a whole seeded 3v3 match, first to 5, through the real game scene, 13 checks) and `tools/run_tests.sh` (all suites with one command, a summary table, non-zero exit on any failure) (D-066); elimination and time-out winners, score, half time and match end were already checked by `round_test`, friendly fire off and on by `bot_test`, and saving and loading by `settings_test`. Eight suites, 340 checks (movement 13, weapon 20, bot 17, round 74, tactics 4, ui 132, settings 67, match 13), all passing (bot 17 after the long-duel fix, D-067).

**Built:** all 13 tasks on 2026-10-15. The full-match test also found one AI stall, fixed in D-067 (attackers close in instead of trading shots at long range). Your playtest is in "Your open checks" at the top.

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

## M6 — Crew & animation 🟨 *(built, waiting for your playtest)*

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
9. [x] **First-person arms.** Arms for each class (its own gloves and sleeves, sleeves in your team colour), made by the same generator, holding the AK-style rifle: draw, fire and reload animations, plus weapon sway and bob in code. *(Opus)* Built (D-079): `modelgen.py` also writes `<class>_arms.glb` (the class's own sleeves, gloves and wrist detail on a 7-bone camera-space rig, sharing the body's texture) with draw, idle, fire and reload clips; the weapon's viewmodel holds them with the AK-style rifle on their weapon bone; sway and bob in code; the old box gun and its code-driven kick and dip are gone; 3 new crew checks.
10. [x] **Performance and tests.** 10 animated characters on the test map at full frame rate. New checks that hit zones follow the animated body; the existing checks still pass. *(Sonnet writes, Haiku runs and reports)* Built: `tests/perf_test.tscn` (a seeded bots-only 5v5 on the test map: 0.42 ms per physics tick headless, 0.7 ms windowed, against the 7.8 ms budget; 60 FPS windowed, which is the display's refresh rate, with the CPU busy 10% of the time) and `tests/zone_test.tscn` (24 checks: every class's zones stay on their bones while running, with no lag at all; shins swing, hands rise when aiming up, the head zone drops 0.43 m crouched, rays hit the running body where it is). All 10 suites pass.

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

## M7 — Arsenal, perks & economy 🟨

**Goal:** a mix of CS and Call of Duty, built around picking weapons up: a light economy where money still matters (spend or save every round), a fresh loadout every round like CoD's Search & Destroy, guns taken from the fallen and power weapons on the maps worth fighting for, and classes that each play a little differently.

*Revised on 2026-10-16 after your answers ("built around picking up weapons", "light economy + pickups", "fresh loadout every round", "but economy has to be there"): tasks 5 and 9 to 14 and the decisions below changed (D-090).*

**The key idea:** every rule lives in authority code. The `RoundManager` hands out the loadouts, pays out money and decides every purchase (`request_buy()`), the same way it already decides class changes, so in M9 the host runs it and the buy menu only asks. A character carries its weapons in slots (an `Inventory` node), holds one at a time, and switches, drops, picks up and throws through its per-tick input commands, so bots follow exactly the same rules as you. Each weapon is one data file (`WeaponData`, Godot's ScriptableObject) and one generated model (D-054); the balancing table is exported from those files, so the spreadsheet can never drift from the game.

**Tasks**, in order, one commit each. The tag says which model builds it (CLAUDE.md, "Choosing a model"):

1. [x] **Plan.** This task list, the decisions below (D-090, provisional, revised on 2026-10-16) and the proposed weapon names. *(Opus)*
2. [x] **The arsenal's data and balancing table.** `WeaponData` grows the fields the arsenal needs: an id, slot (primary, pistol, knife, grenade), price, kill reward, *armor penetration*, draw time, how it's held, pellets (shotgun), scope levels (sniper), melee and grenade values. One data file per weapon in `weapons/`: the AK-style rifle (today's numbers), carbine, SMG, pump shotgun, sniper rifle, service pistol, hand cannon, knife, and the three grenades, with CS-based starting numbers. `tools/export_weapon_table.gd` writes `docs/weapons.csv` (open it in Excel or Numbers): every stat plus derived columns (damage per second, shots to kill with and without armor, whether a headshot kills through a helmet, at 10 and 30 m). New `tests/arsenal_test.tscn` checks the files and that the CSV is up to date. *(Opus: the numbers; Sonnet: the export tool)* Built (D-091): eleven data files with CS-based numbers (GAME_DESIGN 4.3), `docs/weapons.csv` exported by `tools/export_weapon_table.gd`, the armor math in `Armor` (`characters/armor.gd`), new `tests/arsenal_test.tscn` (28 checks). The light economy's rounder prices and rewards came with the revised plan.
3. [x] **Weapon models and icons.** The generator (`tools/modelgen/weapons.py`) builds every weapon from a part list, like the AK: carbine, SMG, pump shotgun, sniper rifle with a scope, service pistol, hand cannon, knife, the three grenades and the defuse kit, each with the points the animations need (grip, foregrip, magazine, muzzle...). One model per weapon serves as the world model (lying on the floor), the third-person model on the hand bone and the first-person model (D-090). The generator also renders each weapon's icons: a shaded side view for the buy menu and a white silhouette for the kill feed. *(Sonnet: part lists from a spec; Opus reviews the renders)* Built (D-092): eleven weapons and the kit in `tools/modelgen/weapons.py` (`modelgen.py weapons`), icons by `tools/modelgen/icons.py`, the data files point at them, and the kill feed shows the weapon's icon.
4. [x] **Armor and helmet.** CS:GO's rules: armor covers chest, stomach and arms, the helmet the head; on an armored hit only the weapon's armor penetration gets through to health (the AK: 77.5%, so an AK headshot still kills through a helmet and a carbine's doesn't), and armor wears down by half of what it stopped. Bought for one round (task 11). The Bulwark's *Plated* perk switches on (10% less damage and 30% less wear while armored). Armor and helmet on the HUD; console `armor`. *(Opus)* Built (D-093): `Armor` in `Character.take_damage()`, hits carry their weapon, the bomb ignores armor, `ArmorIcon` on the HUD, new `tests/gear_test.tscn` (13 checks).
5. [x] **Weapon slots, loadouts, switching, dropping and picking up.** An `Inventory` per character: primary, pistol, knife and grenades. Keys: **1** primary, **2** pistol, **3** knife, **4** grenades (again for the next one), **Q** last weapon, **G** drop. Every weapon has a draw time before it can fire (the Rifleman's *Quick Hands* makes it 15% shorter). **A fresh loadout every round** (D-090): at each round start everyone, alive or not, has the knife and the Sparrow and nothing else; whatever you bought or picked up lasts one round. In team respawn and practice you spawn with your class's loadout (its signature gun, the Sparrow, the knife and one grenade). **Pickups:** a dropped gun lies on the floor with its ammo for the rest of the round; walking over it picks it up when that slot is free, **E** while looking at it swaps it for what you hold in that slot; on death your best gun drops. The HUD (a slot list), the third-person body and the bots follow whichever weapon is held. *(Opus: architecture)* Built (D-094): `Inventory` (`characters/inventory.gd`), `WeaponPickup`, the generic `weapons/weapon.tscn`, six new rebindable actions, loadouts from the rules, `gear_test` 31 checks.
6. [x] **How each gun works.** Pistols fire once per click. The shotgun fires 9 pellets and reloads shell by shell (fire to interrupt). The sniper rifle zooms in two steps with the right mouse button (a scope overlay, sensitivity scaled to the zoom), is accurate only scoped and standing, and unscopes after each shot; the Marksman's *Steady* switches on (scoped accuracy recovers 30% faster, scoping in is 20% faster). The knife slashes (left) and stabs (right), and a hit in the back does more. The Rifleman's faster reload switches on. Each gun gets its own generated shot sound. *(Opus)* Built (D-095): pellets, shell reloads, the scope with `ScopeOverlay`, the knife, the Rifleman's and Marksman's perks; new `tests/guns_test.tscn` (16 checks).
7. [x] **Holds and animations.** The generator writes the new holds for the body and the first-person arms: pistols (two hands, arms out), the knife (one hand, low), grenades (pin, throw, lob), their aim poses, fire kicks and attacks, and a reload for each weapon (the shotgun one shell at a time, the sniper with its bolt). The AnimationTree switches the upper body by the held weapon; the body holds the weapon's own model. *(Opus: tuned by feel)* Built (D-096): nine animation sets in `tools/modelgen/holds.py`, 93 body clips and 38 arm clips per class, the graph's `Hold`, `FireKind`, `Attack` and `ReloadKind`; 5 new crew checks.
8. [x] **Grenades.** High explosive (damage that walls stop, armor halves), flashbang (blinds anyone who looks toward it, teammates and bots included, less when looking away; a white screen and a ring for you, no sight for bots) and smoke (a cloud for 18 s that blocks sight for you and the bots). Left click throws, right click lobs; they bounce off walls and floors. Kills with a grenade count, with the grenade in the kill feed. *(Opus: design)* Built (D-097): `Grenade`, `Explosion`, `SmokeCloud` and `Smokes`, flash and smoke overlays on the HUD, blinded bots, new `tests/grenade_test.tscn` (14 checks).
9. [x] **Power weapons on the maps.** Each quick map gets two clearly marked spots in contested places, a Heron (sniper rifle) and a Breaker (shotgun), on a glowing floor ring with the gun turning above it. Walk over to take it (or E to swap). In rounds they are back at every round start; in team respawn 30 s after being taken. Marker groups in MAPS.md. *(Opus: placement; Sonnet: the spot scene)* Built (D-098): `WeaponSpot`, two spots per quick map placed by walking distance; checks in the gear and maps suites. The spot scene was small, so the main session wrote it.
10. [x] **Money.** A light economy (D-090): $1,000 to start each half, at most $10,000; $3,000 for a round win, $1,500 for a loss and $500 more for each loss in a row up to $3,000 (a win starts the count again); $200 a kill ($500 with the knife), −$200 for a teamkill; a planted bomb gives every attacker $200, a defuse the defuser $200. Money carries over between rounds, gear doesn't. Your money on the HUD with a line for each reward ("+$200 · kill"), your teammates' money in the Tab scoreboard, console `money`. *(Opus: balance)* Built (D-098): money in the `RoundManager` (`MatchSettings` group *Economy*), the HUD's money and reward lines, the scoreboard's money column; new `tests/economy_test.tscn` (10 checks).
11. [x] **Buy menu.** Freeze time becomes 15 s, and that is when you buy (everyone stands at their spawn, so there is no buy zone): **B** opens the buy menu with categories (pistols, mid-tier, rifles, gear, grenades), each item with its icon, price and key, greyed out when you can't afford or carry it; keys or the mouse to buy. It asks the round manager, which decides. Practice mode buys anything for free, any time; team respawn has no money and no buy menu. On the UI theme, registered with `MenuState`, with `UiSounds`. *(Sonnet: the menu; Opus: the rules)* Built (D-098): `Shop`, the round manager's `request_buy()`, `BuyMenu` (by a Sonnet subagent), 15 s of freeze time; 11 new economy checks.
12. [ ] **Defuse kits.** Defenders can buy a kit for $300; it halves the defuse time through the bomb's `kit_check` hook (D-080). A kit icon on the HUD and in the Tab scoreboard. *(Sonnet)*
13. [ ] **Class perks switch on.** The Scout's *Light Step* (running steps carry 70% as far, for bots and for your ears alike) completes the four perks; the class menu and docs describe them as working, and the class menu shows each class's loadout. *(Sonnet)*
14. [ ] **Bots buy, pick up and use the arsenal.** Bots pick their class at the match start and at half time (still a mix per team), then buy every round from their money, decided together like a CS team: save, a cheap buy, or a full buy, with each class's favourite guns, armor, grenades and kits. They pick up better guns lying near them and go for a power weapon when they pass close by. They use what they have: tap with pistols, close in with the shotgun and SMG, scope with the sniper rifle, switch to the pistol when the magazine runs dry, and throw grenades at enemies they know about. *(Opus: AI)*
15. [ ] **Names, checks and the playtest list.** The weapon names (provisional until you confirm them) everywhere, the balancing table refreshed, all suites passing, and the M7 playtest list in "Your open checks". *(Sonnet writes, Haiku runs and reports)*

**Done when:** you play several rounds where money matters (you save for a rifle, or take one off the floor), the power weapons are worth fighting for, and each class plays a little differently.

**You learn:** composition vs. inheritance in Godot (an `Inventory` node next to the character instead of a weapon class hierarchy), simple projectile physics with shape casts, particles (`GPUParticles3D`) for smoke and explosions, camera zoom and a scope overlay, a data-driven buy menu, and exporting data to a spreadsheet from a tool script.

**Decisions** (provisional, D-090; revised on 2026-10-16 after your answers. You asked for the whole roadmap to be built and will playtest at the end, so these are my recommendations, applied until you say otherwise):

| Question | Options | My recommendation (applied) |
|---|---|---|
| Weapon names | **(a)** Names of their own: **Ram** (AK-style rifle), **Warden** (carbine), **Hornet** (SMG), **Breaker** (pump shotgun), **Heron** (sniper rifle), **Sparrow** (service pistol), **Verdict** (hand cannon), **Knife**, **Frag**, **Flashbang**, **Smoke**. **(b)** Plain descriptions ("Rifle", "Carbine"...). | **(a)**, provisional: short, easy to call out, nothing taken from CS or another well-known shooter. Files and code use the role ids (`rifle`, `carbine`...), so renaming touches only the data files. Your check: "Confirm weapon names" |
| Between rounds | **(a)** Your answer: a fresh loadout every round (the knife and the Sparrow), like CoD's Search & Destroy; money carries over, gear doesn't. **(b)** CS: survivors keep their gear. | **(a)** |
| Money values | **(a)** A light economy with round numbers: $1,000 to start each half, $10,000 at most; win $3,000; loss $1,500, $2,000, $2,500, then $3,000 for losses in a row (a win starts over); $200 a kill, $500 with the knife, −$200 for a teamkill; plant: $200 for every attacker; defuse: $200 for the defuser. **(b)** CS2's exact values ($800 start, $3,250 win, $1,400–$3,400 losses, a reward per weapon...). | **(a)**: easy to read, and with a fresh loadout every round a winning team can buy a rifle each round while a losing team has to save one or two rounds or take guns off the floor |
| Prices | **(a)** Round prices by tier: Verdict $500; Hornet and Breaker $1,000; Ram and Warden $2,500; Heron $4,000; Sparrow $200 (only if you lost yours); vest $500, vest and helmet $800; kit $300; Frag $300, Flashbang $200, Smoke $300. **(b)** CS's prices. | **(a)**: a full buy (rifle, vest and helmet, a grenade) is $3,600, a win pays $3,000 plus kills |
| When you buy | **(a)** During the freeze time (15 s), when everyone stands at their spawn: no buy zone needed. **(b)** Also the first seconds of the round, in a buy zone. | **(a)**: simplest, and the maps are small |
| Pickups | **(a)** Guns the dead drop stay on the floor for the rest of the round; walk over to take one into a free slot, E to swap. Each quick map also has two marked power-weapon spots (a Heron and a Breaker) that are back every round (in team respawn 30 s after being taken). **(b)** Dropped guns only. | **(a)**: your "built around picking up weapons", and power weapons give the maps points worth fighting for, like CoD |
| Team respawn (no money) | **(a)** No money and no buy menu: you spawn with your class's loadout (its signature gun, the Sparrow, the knife and a grenade), pickups as in rounds; the class menu (M) works any time and the new class's loadout comes with your next respawn. **(b)** A free loadout picker. | **(a)**: CoD-like, and the class becomes your loadout |
| Practice mode | **(a)** Your class's loadout, and B buys anything for free, any time. **(b)** No buying. | **(a)**: practice is for warm-ups and trying weapons |
| Models | **(a)** One generated model per weapon, used on the floor, in the hand and in first person; icons rendered from the same part list by the Python generator. **(b)** Separate detailed first-person models; icons rendered in Godot with a `SubViewport`. | **(a)**: our models are low-poly anyway; Python renders icons headless, with no window popping up (a Godot render needs a window) |
| The bomb | **(a)** Stays on Use (hold E, D-080); no slot 5. **(b)** CS's way: slot 5 and fire. | **(a)**: it works today and bots already use it |
| Grenades | **(a)** CS's limits: 1 frag, 2 flashbangs, 1 smoke; left click throws, right click lobs; flashbangs blind everyone who looks, teammates too. **(b)** One grenade of any kind. | **(a)** |
| Dropping on death | **(a)** Your best gun drops (primary, else pistol); grenades and kits are lost. **(b)** Everything drops, like CS. | **(a)**: fewer things on the floor |
| Bulwark's *Plated* | **(a)** While its armor lasts, every hit does 10% less to health and wears the armor 30% less. **(b)** Only armored zones. | **(a)**: simplest to read, matches the perk's text |

## M8 — Modes & 3 quick maps ✅

*Built 2026-10-15 in the `m8-maps` branch, in parallel with M5 and M6: the three map blockouts first, then the modes, sound, lighting decision, first export and the rotation. Waiting for: your playtest ("Your open checks") and the maps' detail pass, which follows your playtest.*

**Goal:** fast, action-packed maps like Call of Duty's, three of them in rotation, playable in two modes: CS-style bomb rounds and a team respawn mode (D-049).

- [x] **Map rules:** small and fast: about 40–60 m across, three lanes with connections between them, first contact within 5–10 s of spawning, and short sightlines. Every map works in both modes: two bomb sites plus spawn zones for respawning. Sketch all three on paper first
- [ ] **Maps 1, 2 and 3** in TrenchBroom (D-032), each one blockout → bot test → detail: navmesh, side spawns, bomb sites, bot attack routes and hold spots. Three distinct looks within the no-desert rule (D-031). *Blockouts and bot tests done early (2026-10-15): Depot, Square, Spillway, see [MAPS.md](MAPS.md) (D-060–D-062); detail pass still open*
- [x] **Map rotation:** match setup picks a map or "Rotation"; after a match, "Next map" continues to the next one. Built (D-087, provisional): match setup's new **Mode** row (Rounds or Team respawn; the length becomes 30, 50 or 75 kills for team respawn) and **Maps** row (One map or Rotation: Depot → Square → Spillway, starting on the chosen map); the end screen's "Next map: Square". `-- --match --rotation` from the terminal. New `tests/rotation_test.tscn` (13 checks)
- [x] Baked lighting (lightmaps) for the maps, moved from M3, and a decision on baked vs. real-time lighting. Decided: **real-time** (D-085, provisional), from before/after screenshots ([maps/lighting_depot.jpg](maps/lighting_depot.jpg)): SSAO is barely visible at 480 lines, SDFGI brings back blue shadows and dark interiors, and baking would need a manual re-bake in the editor after every map edit. New `tools/frame_timing.gd` and `--lighting` for `tools/map_screenshots.gd`
- [x] **Bomb:** carry, plant, timer, explosion, defuse (faster with a kit). Built as `bomb/bomb.tscn` (D-080, provisional): an attacker carries it, hold **E** in a site for 3.2 s to plant, 40 s fuse with faster beeps, hold E next to it for 10 s to defuse (the kit is a hook for M7), the plant stops the round clock, the blast is lethal out to ~13 m; dropped on death, picked up by attackers; HUD tag, prompts, progress bar and messages. New `tests/bomb_test.tscn` (26 checks)
- [x] **Bots play the objective:** attack a site, plant, rotate, defuse. Built in `BotTactics` and `BotController` (D-081, provisional): the attackers pick a target site, the carrier's group takes the route ending nearest to it, the carrier plants, the nearest bot fetches a dropped bomb, attackers guard the planted bomb; every defender retakes, one defuses while the others cover, and a bot keeps defusing under fire only when 70% done. Stuck bots jump, then back off and re-path. 6 new bot checks in `tests/bomb_test.tscn`; in the maps test bots planted in 11 of 12 rounds
- [x] **Team respawn mode** (like CoD's Team Deathmatch): you respawn about 3 s after dying, at a spawn point away from enemies; the first team to a kill limit wins, or the team with most kills when the time runs out. Grows out of today's Practice arena. Built as `RespawnMatch` (D-082, provisional): 30 kills (50 since D-083) or 10 minutes, overtime on a tie, 3 s respawns at the safest `respawn_points` marker (far from enemies, out of their sight); `MatchSettings.game_mode`, `-- --respawn` from the terminal. New `tests/respawn_test.tscn` (15 checks)
- [x] **Bots in the respawn mode:** hunt in small groups instead of attacking and holding. Built as `HuntPlan` + the HUNT role (D-083, provisional): pairs per team, the longest-living member leads to a teammate's sighting within 25 m or roams the patrol points, the other follows about 6 m behind watching a flank; the kill limit is now 50 (bots-only matches score about 20 kills a minute). 4 new checks in the respawn test; the maps test plays a respawn match on every map
- [x] Full sound pass: weapons, footsteps on different surfaces, bomb beeps, UI. Built (D-084, provisional): footsteps on hard, gravel, metal and wood floors (the floor's texture comes from func_godot's metadata, via Chiip's own worldspawn class); bullet impacts per surface, body hits and a CS-like headshot "dink"; the bomb's sounds plus a planted alert; menu hover and click, round start, round won and lost stingers. 24 generated sounds, no downloads. New `tests/sound_test.tscn` (8 checks)
- [x] Performance check and the first exported macOS build. Done (D-086): 5v5 on all three maps holds the display rate (slowest 1% of frames 19–22 ms, ~2 ms physics for 10 bots); a universal, ad-hoc signed `builds/macos/Chiip.app` (165 MB) from the new `export_presets.cfg`, after installing the official 4.7.2 export templates (checksum verified). The export also found and fixed a broken player script in the TrenchBroom comparison room and the console's map list in exported builds

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
