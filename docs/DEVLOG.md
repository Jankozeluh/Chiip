# Chiip — Devlog

> One entry per work session, newest at the top: what was done, which decisions were made, and what's next.

## 2026-10-15 — Session 4: M2 shooting

**Done**
- Recorded the M2 decisions: working name "Rifle", generated placeholder sounds, static CS-like crosshair (D-019 to D-021).
- Named the physics layers (world, player, bots, hitboxes, triggers), added code constants in `systems/physics_layers.gd`, put the player on its layer, and added the reload key R (D-022).
- `WeaponData` resource and `weapons/rifle.tres`: AK-like stats, a 30-shot spray pattern, accuracy and recoil values, and sound slots.
- `Weapon` node and `weapons/rifle.tscn` in the player's hands: full-auto at exactly 600 rpm (10 shots in 1 s), 30-round magazine, R to reload (2.5 s), empty click and auto-reload, 215 u/s while held. Clicks that capture the mouse don't fire.
- The movement tests caught a bug: crouch-walking with the rifle couldn't overcome friction. Fixed by basing ground acceleration on 250 u/s like CS:GO (D-023). All 13 checks pass again.

## 2026-10-15 — Session 3: M1 closed, M2 planned

**Done**
- You playtested M1: the movement feels good and needs no tuning. **M1 is closed.**
- The Ctrl + click and sensitivity checks weren't reported, so they moved to M2. They matter once you can shoot.
- Wrote the detailed M2 plan: 13 tasks from physics layers to weapon tests, with three decisions to make first (rifle name, sounds, default crosshair).

**Next:** Your go-ahead for M2, and answers to the three decisions (or accept the defaults).

## 2026-10-15 — Session 2: M1 project setup & movement

**Done**
- Started git. The first commit holds the M0 planning docs.
- Created the Godot project (`project.godot`, icon, `.gitignore`, `.gitattributes`) and the folder structure from ARCHITECTURE.md. Empty folders contain a `.gitkeep` file so git tracks them.
- Engine settings: Forward+ renderer, Jolt physics, 128 ticks per second with physics interpolation, CS gravity (D-008 to D-011).
- Input actions for movement, jump, crouch, walk, shoot/aim, freeing the mouse and the debug overlay, bound by physical key position (D-012).
- Test map (`maps/test_map.tscn`): CS crate heights (32/48/64/80 units), a platform with a 25° ramp and stairs (invisible clip ramp, D-013), a 1.5 m crouch tunnel and peek walls, all in a world-space grid "developer texture" (D-014). Verified every surface height with headless raycasts.
- Player (`player/player.tscn` + `player.gd`): capsule with CS dimensions, CS-style mouse look and Quake/Source ground movement (friction, acceleration, stop speed). Headless check: top speed 6.350 m/s (exactly 250 u/s), full stop 0.41 s after releasing the key (D-015, D-016).
- Walking, crouching (two capsules, in-air crouch lifts the legs), jumping (press-only, bunny-hop cap, exact height) and air strafing (D-017).
- Automated movement tests (`tests/movement_test.tscn`), 13 checks, all passing in under a second (D-018). Counter-strafe reaches accurate speed in 78 ms vs. 211 ms when just releasing the key.
- Debug overlay (`ui/debug_overlay.tscn`, F3): speed in m/s and u/s, position, jump peak, stance, and shoot/aim buttons for the Ctrl + click test.
- Visual check through Godot's Movie Maker mode (renders frames to PNG): the map, lighting and overlay look right. Found and fixed a missing `node_paths` entry that left the overlay without its player reference.
- README now explains how to run the game and the tests. CLAUDE.md lists the verified command-line commands and two gotchas.

**Decisions:** D-008 to D-018 in [DECISIONS.md](DECISIONS.md).

**Next:** You playtest M1: movement feel compared with CS, sensitivity (a 360° turn), and Ctrl + click on macOS. Then we tune, close M1, and start M2 (shooting).

## 2026-10-15 — Session 1: Choosing the game

**Done**
- Checked the setup. Godot 4.7.2 (standard edition), git and Homebrew were already installed, so nothing else was needed.
- Chose the game's direction through a round of questions: a 3D CS-style tactical FPS against bots, with a retro Quake look, as an ongoing project built "learn as we go".
- Named the game **Chiip** and created the `Games/Chiip/` folder.
- Wrote the documentation: README, game design, plan (M0–M7), architecture, decision log, learning notes, this devlog and CLAUDE.md.

**Decisions:** D-001 to D-007 in [DECISIONS.md](DECISIONS.md).

**Next:** The user reviews the plan. After that, M1 starts with creating the Godot project and git, then the player movement.
