# Chiip — Plan & Roadmap

> Last updated: 2026-10-15
>
> **Current milestone:** M1 — Project setup & movement (in progress)

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
| M1 | Project setup & movement | 🟨 | Run, walk, crouch and jump around a test map |
| M2 | Shooting | ⬜ | Shoot targets with a rifle that has CS-like recoil |
| M3 | Retro look & map tools | ⬜ | The test map looks like a 90s shooter |
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

## M1 — Project setup & movement 🟨

**Goal:** a first-person player that moves like in CS, on a simple test map.

- [x] Create the Godot project in this folder (`project.godot`) and the folder structure from [ARCHITECTURE.md](ARCHITECTURE.md)
- [x] Set up git with a Godot `.gitignore` and make the first commit
- [x] Decide the renderer and physics tick rate (see open questions)
- [x] Define input actions (move, jump, crouch, walk, …) in the Input Map
- [ ] Build a test map from simple blocks: floor, walls, boxes, ramps, stairs
- [ ] Player scene: `CharacterBody3D` with a collision capsule and a camera
- [ ] Mouse look with a captured cursor, using CS's sensitivity formula so your CS sensitivity carries over
- [ ] CS-style ground movement: acceleration, friction, top speed
- [ ] Walking (Shift) and crouching (Ctrl) with a smooth camera height change
- [ ] Jumping and air movement (air acceleration, air strafing)
- [ ] Debug overlay showing speed and position, like CS's `cl_showpos`
- [ ] All movement values editable in the Godot editor for tuning
- [ ] Check whether Ctrl + click works as crouch + shoot on macOS

**Done when:** you can run, walk, crouch and jump around the test map, counter-strafing stops you quickly, and it feels right to you as a CS player.

**You learn:** project structure, nodes and scenes, GDScript basics, `_physics_process`, `CharacterBody3D` and `move_and_slide()`, the Input Map, `@export` variables.

## M2 — Shooting ⬜

**Goal:** one rifle with CS-like accuracy and recoil, tested on targets.

- [ ] Weapon system foundation, with weapon stats stored as a data file (Resource)
- [ ] Hitscan shooting with a raycast from the camera
- [ ] Fire rate, magazine, reserve ammo and reloading
- [ ] Inaccuracy from moving and jumping, and less of it when crouching
- [ ] Spray pattern, recoil recovery and camera kick
- [ ] Bullet impacts (decals or particles) so you see where shots land
- [ ] Target dummy with hit zones (head, chest, stomach, legs) that shows damage numbers
- [ ] HUD: crosshair (configurable like CS) and ammo counter
- [ ] Placeholder weapon model in first person and a gunshot sound
- [ ] Shooting range on the test map with static and moving targets

**Done when:** first shots are accurate when standing still, moving ruins accuracy, the spray pattern is learnable, and headshots deal ×4 damage.

**You learn:** Resources (Godot's ScriptableObjects), raycasts and physics layers, signals, Control nodes for UI, 3D audio.

## M3 — Retro look & map tools ⬜

**Goal:** give Chiip its 90s shooter style early, and decide how maps will be made.

- [ ] Low internal resolution with crisp pixel upscaling (compare the approaches and pick one)
- [ ] Nearest-neighbor texture filtering across the project
- [ ] Find or make a retro texture set with a license that allows use
- [ ] Retro materials: chunky textures, minimal reflections
- [ ] Baked lighting (lightmaps) on the test map
- [ ] Optional: a post-process shader that limits the color palette
- [ ] Compare map-building options, Godot's CSG shapes vs. TrenchBroom (the Quake map editor) with the `func_godot` plugin, then decide and document
- [ ] Create `docs/CREDITS.md` listing every third-party asset with its source and license

**Done when:** the test map looks like a 90s shooter and we know how future maps will be built.

**You learn:** materials and shaders, viewports, rendering settings, lightmap baking, importing assets, addons.

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
