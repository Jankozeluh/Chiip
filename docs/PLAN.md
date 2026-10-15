# Chiip — Plan & Roadmap

> Last updated: 2026-10-15
>
> **Current milestone:** M3 — Retro look & map tools (in progress)

## How this plan works

- The game is built in **milestones**. Each one ends with something you can play and test.
- Each milestone lists its **tasks** (checkboxes), a **Done when** test, and the **Godot concepts** you learn along the way.
- Status icons: ⬜ not started · 🟨 in progress · ✅ done
- Tasks are ticked here as the work happens. Details of each work session go into [DEVLOG.md](DEVLOG.md).
- Milestones can be reordered or changed at any time. The reason is recorded in [DECISIONS.md](DECISIONS.md).

## Overview

| # | Milestone | Status | What you can play at the end |
|---|---|---|---|
| M0 | Plan & documentation | ✅ | Nothing yet. This plan and the docs exist |
| M1 | Project setup & movement | ✅ | Run, walk, crouch and jump around a test map |
| M2 | Shooting | ✅ | Shoot targets with a rifle that has CS-like recoil |
| M3 | Retro look & map tools | 🟨 | The test map looks like a 90s shooter |
| M4 | Bots | ⬜ | Bots hunt you and shoot back |
| M5 | Health, rounds & game flow | ⬜ | Full rounds against bots, with menus and settings |
| M6 | Economy & arsenal | ⬜ | Earn money and buy weapons between rounds |
| M7 | Bomb mode & first real map | ⬜ | A complete plant/defuse match on a real map |
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
| The rifle's name | "Rifle" as a working name; final weapon names are decided in M6 |
| Sounds | Generated by code: short retro noise bursts, no downloads. Alternative: a free CC0 sound pack, downloaded only with your OK |
| Default crosshair | Static and CS-like: green, small gap, no dot. Dynamic is a setting |

## M3 — Retro look & map tools 🟨

**Goal:** give Chiip its 90s shooter look (pixelated, chunky textures, moody light) while keeping enemies easy to see, and decide how real maps will be built.

**Your checks, carried over from M1/M2:**
- [ ] **Ctrl + click on macOS:** hold Ctrl, click, and watch Shoot/Aim in the F3 overlay. If it shows *Aim*, macOS turns Ctrl + click into a right click while crouching, and we change the crouch key or work around it.
- [ ] **Sensitivity:** compare how far you move the mouse for a 360° turn here and in CS, at your CS sensitivity.

**Tasks**, in order, one commit each:

1. [x] **Pixelated rendering, two variants.** You chose **B (sharp HUD)** (D-027). A: the whole screen, HUD included, rendered at 640 × 360 and scaled up with sharp pixels. B: only the 3D world rendered low-res, with the HUD drawn sharp at full resolution. I make screenshots of both and you pick. The resolution stays adjustable (480 × 270 / 640 × 360 / 960 × 540).
2. [x] **Mouse and crosshair at low resolution.** Checked: 100 mouse counts turn the view exactly 2.200° in both styles; crosshair sizes are rounded to whole pixels. Check that sensitivity doesn't change (it shouldn't, see D-016) and that the crosshair stays pixel-perfect.
3. [x] **Retro texture tool.** A tool script that turns any image into a retro texture: shrinks it to 64 × 64 (or 128 × 128), reduces its colors, and imports it with sharp pixels and mipmaps (no shimmering in the distance).
4. [x] **Texture set.** About 8 textures: concrete floor, plaster wall, brick, sandy ground, wooden crate, metal, dark trim, spray-wall paint (source: see decisions below).
5. [x] **Retro materials.** Textures are placed by world position (triplanar), so any box gets them without UV work, at Quake's texel density (a 64-pixel texture covers 64 units = 1.63 m). Matte surfaces, no shiny reflections. This replaces the grid placeholder.
6. [x] **Retexture the test map.** Crates look like wooden crates, walls get brick and plaster, the floor concrete and sand. The rifle and dummies get matching retro colors. Dummies stay bright enough to stand out (clarity rule).
7. [ ] **Lighting and atmosphere.** A darker, moodier scene: lower ambient light, a warm sun, a few colored lamps, distance fog, a retro sky.
8. [ ] **Baked lighting experiment.** Bake lightmaps (`LightmapGI`) for the test map and compare with real-time lighting, then decide which to use. Godot bakes on the GPU in the editor, so this step may need one click from you (I'll show where) if it can't be automated.
9. [ ] **Optional color palette effect.** A full-screen shader that limits colors (fewer shades per channel, optional dithering), switchable. Screenshots on/off; you decide.
10. [ ] **How maps get built.** The same small CS-style room (doorway, crates, a ramp) built twice: with CSG in Godot, and with TrenchBroom (the Quake map editor, very close to CS's Hammer) imported through the `func_godot` plugin. We compare effort, texture alignment, collision and baked lighting, then decide the workflow for the real map in M7.
11. [ ] **Credits.** `docs/CREDITS.md` lists every third-party asset and tool with its source and license.
12. [ ] **Checks.** Screenshots of every area of the test map, both test suites still passing, and a frame-rate check at the chosen resolution.

**Done when:** the test map and range look like a 90s shooter, dummies remain easy to spot, the HUD is readable, and we know how the real map in M7 will be built.

**You learn:** viewports and stretch modes, `SubViewport`, texture import settings (filtering, mipmaps), triplanar mapping, the `Environment` (fog, ambient light, tonemapping), `LightmapGI` and lightmap UVs, full-screen (post-process) shaders, installing and using an addon.

**Decisions** (recommendations accepted on 2026-10-15, see D-024 to D-026):

| Question | Options | My recommendation |
|---|---|---|
| Where textures come from | **(a)** Download a few free CC0 textures from ambientCG (public domain photo textures) and turn them retro with our tool. Each download only with your OK. **(b)** Generate textures by code, with no downloads. | **(a):** much better looking, and CC0 means free to use with no strings attached |
| Map tool comparison (task 10) | **(a)** Compare now: you install TrenchBroom (free), and I download the `func_godot` addon with your OK. **(b)** Skip for now, keep CSG, and decide in M7. | **(a):** M3 is where the pipeline gets decided, and TrenchBroom is the classic Quake/CS way to build maps |
| HUD font | **(a)** Download a free pixel font (SIL Open Font License) with your OK. **(b)** Keep Godot's default font for now. | **(a)** if you pick variant A (pixelated HUD) in task 1, otherwise either works |

The pixelation variant (task 1) and the palette effect (task 9) are decided during M3 from screenshots.

## M4 — Bots ⬜

**Goal:** enemies that move around, spot you and fight back fairly.

- [ ] Navigation mesh on the test map
- [ ] Bot scene: body with hit zones, weapon, health
- [ ] Bot movement with pathfinding
- [ ] Behaviour state machine: patrol → engage → search last known position
- [ ] Vision: field of view plus line of sight, so no wallhacks
- [ ] Hearing: footsteps and gunshots
- [ ] Footstep sounds for the player and bots (walking stays silent)
- [ ] Aim with human-like reaction time and error, plus difficulty presets
- [ ] Death for the player and bots (ragdoll or simple animation)
- [ ] Developer console (`` ` `` key) with commands like `bot_add`, `bot_kick`, `noclip` and `god`

**Done when:** you can fight 1–5 bots on the test map and they feel fair: they react with a delay, miss sometimes and can be outplayed.

**You learn:** `NavigationRegion3D` and `NavigationAgent3D`, state machines, groups, timers, autoloads (Godot's singletons).

## M5 — Health, rounds & game flow ⬜

**Goal:** a real game with rounds, wins and losses, and menus.

- [ ] Health and armor (with helmet) for everyone
- [ ] Teams: the player (plus optional bot teammates) vs. the bot team
- [ ] Round manager: freeze time, round timer, round end, restart
- [ ] Win condition: eliminate the other team
- [ ] Match: score, first to N rounds, side swap at half time
- [ ] HUD: health, armor, round timer, score, kill feed
- [ ] Scoreboard (Tab)
- [ ] Spectate teammates after you die
- [ ] Main menu, pause menu and settings menu (sensitivity, FOV, volume, crosshair, key bindings)
- [ ] Settings saved to disk

**Done when:** you can start a match from the main menu and play it to the end against bots.

**You learn:** switching scenes, managing game state, saving data (`ConfigFile`), UI layout containers, themes.

## M6 — Economy & arsenal ⬜

**Goal:** CS's buy-or-save decisions.

- [ ] Money: rewards for wins, losses (with loss bonus) and kills
- [ ] Buy zone and buy menu (B) during freeze time
- [ ] Weapon slots, switching, dropping and picking up weapons
- [ ] Weapons: knife, 2 pistols, 2 rifles, a scoped sniper, maybe an SMG or shotgun
- [ ] Grenades: high explosive, flashbang, smoke
- [ ] Bots buy based on their money
- [ ] Weapon stats table for balancing, exportable to a spreadsheet

**Done when:** you play several rounds where buying, saving and eco rounds actually matter.

**You learn:** inheritance vs. composition in Godot, particle systems, more advanced UI.

## M7 — Bomb mode & first real map ⬜

**Goal:** CS's full objective mode on a proper map.

- [ ] Sketch, then build, the first real map with two bombsites
- [ ] Bomb: carry, plant, timer, explosion, defuse (faster with a kit)
- [ ] Bots play the objective: attack a site, plant, rotate, defuse
- [ ] Full sound pass: weapons, footsteps on different surfaces, bomb beeps, UI
- [ ] Performance check and the first exported macOS build

**Done when:** you can play a full bomb-defusal match against bots on a real map, from an exported app.

**You learn:** level design workflow, `Area3D` triggers, audio buses, exporting a game.

## Backlog (ideas, not scheduled)

- More maps and map voting
- Wallbangs and tagging
- Smarter team AI: callouts, trades, coordinated site takes
- Training modes: aim trainer, spray practice, movement maps (KZ- or surf-style)
- Match statistics (K/D, ADR, headshot %) and a stats screen
- Demo recording and replays
- Online multiplayer
