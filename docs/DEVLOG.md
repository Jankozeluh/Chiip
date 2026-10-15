# Chiip — Devlog

> One entry per work session, newest at the top: what was done, which decisions were made, and what's next.

## 2026-10-15 — Session 5: M2 closed, M3 planned

**Done**
- You playtested M2: shooting feels good, no tuning needed. **M2 is closed.**
- The Ctrl + click and sensitivity checks still weren't reported, so they moved on to M3.
- Wrote the detailed M3 plan: 12 tasks from pixelated rendering to the map-tool comparison, with three decisions to make first (texture source, map tool comparison, HUD font).

**Next:** Your go-ahead for M3 and answers to the three decisions.

## 2026-10-15 — Session 6: M3 retro look

**Done**
- Recorded the M3 decisions: ambientCG CC0 textures (each download with your OK), comparing TrenchBroom + func_godot now, an OFL pixel font (D-024 to D-026).
- You asked whether Chiip could go on Steam. Answer: yes, technically and legally (own names and assets, CC0/OFL licenses). Multiplayer is the big piece, and the realistic scope is Steam lobbies with one player hosting, plus bots. If we want multiplayer, player control should become per-tick input commands *before* bots (M4). Added as an open question in DECISIONS.md.
- New main scene `main.tscn`: the world renders at 640 × 360 in a `SubViewport` and is scaled up with sharp pixels; HUD and overlay on top. Two styles: sharp HUD (B) and pixelated HUD (A). Mouse sensitivity is identical in both (2.200° for 100 counts). Found: text placed in the 3D world (dummy labels, damage numbers) becomes unreadable at 360 lines; to be fixed with the pixel font.
- Retro texture tool (`tools/make_retro_texture.gd`): square crop, shrink in halving steps, k-means palette, lossless + mipmapped import. Tested on a generated brick image: crisp 64 × 64, 12 colors, tiles cleanly.
- You picked style B (sharp HUD) from screenshots, approved all 8 textures, the func_godot addon and the Silkscreen font, and will install TrenchBroom yourself (D-027, D-028).
- Downloaded the 8 ambientCG textures (sizes matched ambientCG's listing to the byte) and turned them into 64 × 64, 16-color textures. Smooth surfaces came out almost flat, so the tool got a contrast option (2–3 for concrete, plaster, sand, metal). Started `docs/CREDITS.md`.
- You installed TrenchBroom (it's at `~/Downloads/TrenchBroom.app`).
- Installed the func_godot addon (pure GDScript, MIT) and the Silkscreen font (OFL). Silkscreen is now the default UI font and the font of all 3D labels (fixed on-screen size, crisp pixels), which should make dummy titles and damage numbers readable again at 360 lines.
- Retro materials (`assets/materials/`): one per texture, world triplanar at Quake's texel density, nearest-with-mipmaps filtering, matte.
- Retextured the test map and the rifle. Visual check: the textures read well and the dummies stand out, but the concrete looked like snow (darkened it), and fixed-size labels piled on top of each other (map signs now shrink with distance; only dummy titles and damage numbers stay fixed size, at 1 font pixel per world-image pixel).
- Lighting and atmosphere: warm low sun, dusty sky, darker ambient light, haze, three colored lamps (D-029). The first fog setting hid the 40 m dummy, so I halved it.
- Optional palette effect: 12 shades per channel with ordered dithering, world image only, off by default until you decide from the side-by-side screenshots.
- `main.tscn` can load any map (`map_scene`, or `-- --map <scene>`); the HUD and overlay get the player from the loaded map. Moved the sky/fog settings into `assets/environments/dusty_afternoon.tres` so every map shares them.
- Map comparison setup: one layout (a CS-sized room with a doorway, crates, platform and ramp) generated as a TrenchBroom `.map` and as a CSG scene. func_godot builds the `.map` headlessly (`tools/build_maps.gd`) with lightmap UVs and our textures. Raycasts at 9 spots: both versions match within 0.1 mm (after fixing a ramp bug in my generator that affected both). Installed a "Chiip" game config in TrenchBroom (`tools/export_trenchbroom_config.gd`).
- Real-time screenshots of both rooms look the same, except the TrenchBroom floor was brighter: the darkening was a tint on the CSG materials only. Moved it into the textures (new brightness option in the texture tool), so both pipelines share one source.

## 2026-10-15 — Session 4: M2 shooting

**Done**
- Recorded the M2 decisions: working name "Rifle", generated placeholder sounds, static CS-like crosshair (D-019 to D-021).
- Named the physics layers (world, player, bots, hitboxes, triggers), added code constants in `systems/physics_layers.gd`, put the player on its layer, and added the reload key R (D-022).
- `WeaponData` resource and `weapons/rifle.tres`: AK-like stats, a 30-shot spray pattern, accuracy and recoil values, and sound slots.
- `Weapon` node and `weapons/rifle.tscn` in the player's hands: full-auto at exactly 600 rpm (10 shots in 1 s), 30-round magazine, R to reload (2.5 s), empty click and auto-reload, 215 u/s while held. Clicks that capture the mouse don't fire.
- The movement tests caught a bug: crouch-walking with the rifle couldn't overcome friction. Fixed by basing ground acceleration on 250 u/s like CS:GO (D-023). All 13 checks pass again.
- Hitscan shots (ray against world + hitboxes, up to 208 m) and bullet impacts: a pixelated hole plus sparks, attached to what was hit, last 100 kept. Check: a shot aimed at the peek wall hit 0.0 mm from the aim point at 28 m.
- Accuracy: shots land at a random spot in a cone (0.12° standing, 0.08° crouched, up to +4.5° running, +9° in the air). Measured 20 taps per stance: every shot inside its cone.
- Spray pattern and aim punch: shots follow the 30-point pattern exactly, the view kicks by half the pattern, and recoil wears off at 12 shots/s once you stop (a 10-shot burst is gone after a 1 s pause).
- Hit zones (`Hitbox` areas: head ×4, stomach ×1.25, chest/arms ×1, legs ×0.75), damage falloff (×0.98 per 500 units), and a target dummy with floating damage numbers and a running total. Measured: headshot 142.9 at 5 m, 135.2 at 40 m.
- HUD (`ui/hud.tscn`): CS-style crosshair drawn in code (static, green; dynamic mode as a setting), weapon name and ammo counter that turns red when low.
- First-person Rifle model built from boxes and a cylinder (metal + wood), muzzle flash (gradient quad + light), kick on every shot (tween), dip while reloading.
- Placeholder sounds generated by `tools/generate_sounds.gd` (gunshot, empty click, reload clack, bit-crushed for a retro feel) and saved as `.wav` files that `rifle.tres` points to (D-020).
- Shooting range on the test map (extended 56 m south): firing line, dummies at 5/10/20/40 m, a moving dummy at 15 m, and a spray wall at 10 m with an aim mark. The player now spawns on the range.
- Debug overlay shows weapon inaccuracy, built-up recoil and the last hit (zone, damage, distance).
- Weapon tests (`tests/weapon_test.tscn`): 20 checks, all passing in about a second. Fixed leak warnings at test exit: the weapon now always plays the sound named in its data, and the test uses a silent copy.
- Visual check (Movie Maker frames of spraying and tapping on the range): viewmodel, muzzle flash, crosshair, ammo counter, dummies and overlay all render correctly. Moved the firing-line label out of your face at spawn.

**Decisions:** D-019 to D-023 in [DECISIONS.md](DECISIONS.md).

**Next:** You playtest M2 on the range: first-shot accuracy, counter-strafe then shoot, the spray on the spray wall, headshots, and the moving target. Also the two checks carried over from M1 (Ctrl + click, sensitivity). Then we tune and close M2.

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
