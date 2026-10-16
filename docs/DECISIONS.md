# Chiip — Decision Log

> Important decisions: what was decided, why, and what else was considered. Newest entries go at the bottom.
>
> Decisions can be revisited. When one changes, add a new entry that replaces the old one instead of rewriting history, and mark the old one as *Replaced by D-xxx*.
>
> Last updated: 2026-10-16

## D-001 — Engine: Godot 4.7.2 with GDScript (2026-10-15)

**Decision:** Godot 4.7.2, standard edition, scripted in GDScript.

**Why:** It's already installed. GDScript is Godot's main language, with the most tutorials and the tightest editor integration, and needs no .NET setup.

**Alternatives:** C#, which is familiar from Unity but needs the .NET edition of Godot and the .NET SDK, and has fewer Godot examples.

## D-002 — Genre: CS-style tactical FPS, single-player against bots (2026-10-15)

**Decision:** A 3D tactical FPS modeled on Counter-Strike, played single-player against bots first.

**Why:** The user mostly plays CS (1.6, CS:GO, CS2) and Quake. With bots, the game can be built and tested alone, while multiplayer would complicate every system from day one.

**Alternatives:** A Quake-style arena shooter, multiplayer from the start, or a movement and aim playground without enemies.

## D-003 — Art style: retro Quake look (2026-10-15)

**Decision:** Low-res rendering, pixelated textures and simple geometry, in the style of Quake and CS 1.x.

**Why:** It fits the games that inspired Chiip, and simple art is realistic for a one-person hobby project.

**Alternatives:** A plain prototype blockout, or free low-poly asset packs.

## D-004 — Name: Chiip (2026-10-15)

**Decision:** The game is called **Chiip**, and its folder is `Games/Chiip/`.

**Why:** Chosen by the user.

## D-005 — Approach: playable milestones, learn as we go (2026-10-15)

**Decision:** Claude builds the game step by step and explains each new Godot concept, compared to Unity, so the user can make changes themselves. Each milestone ends with something playable. Chiip is an ongoing project, with no fixed end date.

**Why:** The user has Unity experience but is new to Godot, and wants to learn it.

**Alternatives:** Claude builds everything with little explanation, or the user codes and Claude only assists.

## D-006 — Everything is documented (2026-10-15)

**Decision:** A `docs/` folder holds the plan, game design, architecture, decisions, devlog and learning notes. Code has doc comments. The rules for keeping all of it current are in `CLAUDE.md`.

**Why:** The user asked for it. It also lets an ongoing project be resumed easily after a break.

## D-007 — Units and reference values (2026-10-15)

**Decision:** 1 Godot unit = 1 metre. Counter-Strike values are converted with 1 Source unit ≈ 2.54 cm.

**Why:** Metres are Godot's convention, which also keeps physics behaving as expected. Converting CS values gives a familiar feel to start from.

## D-008 — Renderer: Forward+ (2026-10-15)

**Decision:** Use the Forward+ renderer.

**Why:** It's Godot's most capable desktop renderer and supports everything planned for the retro look, including baked lightmaps (M3). Performance isn't a concern for low-poly retro scenes.

**Alternatives:** Mobile (fewer features, aimed at phones), Compatibility (OpenGL, for very old hardware and the web).

## D-009 — Physics engine: Jolt (2026-10-15)

**Decision:** Set `physics/3d/physics_engine` to **Jolt Physics** explicitly.

**Why:** Jolt is built into Godot and is faster and more stable than the older GodotPhysics3D, especially with many bodies (bots, ragdolls, grenades later). Setting it explicitly means the project doesn't depend on what "DEFAULT" means in a given Godot version.

**Alternatives:** GodotPhysics3D, Godot's original engine.

## D-010 — 128 physics ticks per second, with physics interpolation (2026-10-15)

**Decision:** Physics runs at 128 Hz, like 128-tick community CS servers (FACEIT). Physics interpolation is on, and the jitter fix is off, as Godot recommends with interpolation.

**Why:** A higher tick rate means input reaches the movement code sooner and movement is simulated more precisely. Physics interpolation draws objects smoothly *between* ticks, so movement looks smooth on any monitor refresh rate (60, 120 or 144 Hz) without being tied to it. The cost of 128 Hz is negligible for one player and a handful of bots.

**Alternatives:** 60 Hz (Godot's default), 64 Hz (CS2/CS:GO matchmaking), or no interpolation (cheaper, but can stutter when the monitor and tick rates differ).

**Consequence:** The camera can't simply be a child of the player. It's updated every rendered frame from the player's smoothed position, while mouse look is applied directly with no delay. See `player/player.gd`.

## D-011 — World gravity: CS's 800 units/s² (2026-10-15)

**Decision:** Project-wide gravity (`physics/3d/default_gravity`) is 20.32 m/s², which is CS's `sv_gravity 800` converted to metres.

**Why:** CS movement and jump heights are tuned for this gravity. Setting it project-wide means everything that falls (players, grenades, ragdolls) uses the same value. Real-world gravity is 9.8 m/s², but CS has always felt "heavier" than reality.

## D-012 — Keys are bound by physical position (2026-10-15)

**Decision:** All keyboard bindings use *physical* keycodes, meaning the position of the key, not the letter printed on it. Jump is also bound to mouse wheel down, as many CS players do.

**Why:** The user has a Czech QWERTZ keyboard, where Y and Z are swapped and the number row types `ěščřžýáíé`. With physical keycodes, WASD and the number keys (weapon slots from M2) stay in the same place on any layout.

**Alternatives:** Letter-based keycodes, which would break on non-US layouts.

## D-013 — Stairs use invisible clip ramps (2026-10-15)

**Decision:** Stairs are visual only. Players walk on an invisible collision ramp laid over the step edges, like the "clip brushes" on many CS maps. There's no code for stepping up onto ledges for now.

**Why:** It's simple and smooth, and it's how CS maps usually handle stairs. Godot's `CharacterBody3D` doesn't climb steps by itself, and step-up code is tricky to get right.

**Alternatives:** Step-up code in the player, which can be added later if maps need small ledges (curbs, door frames) that players should walk over.

## D-014 — Blockout with CSG and a grid shader (2026-10-15)

**Decision:** The M1 test map is built from CSG shapes (`CSGBox3D`, with a subtraction for the tunnel) using a world-space grid shader as a placeholder "developer texture". Box heights match CS's standard 32/48/64/80-unit crates.

**Why:** CSG is built in and editable right in the Godot editor, so it's ideal for quick blockouts. The 1 m grid makes speed and distances easy to judge. The final map workflow is decided in M3.

## D-015 — Player hull: capsule with CS dimensions (2026-10-15)

**Decision:** The player collides as a capsule 1.83 m tall (CS: 72 units) with a 0.4 m radius (CS hull: 32 units wide). Eyes are 1.63 m above the feet (CS: 64 units). The camera's vertical FOV is 73.74°, which is CS's default 90° horizontal FOV on a 4:3 screen. Wider screens show more at the sides, as CS does.

**Why:** The sizes keep CS map dimensions and jump heights working the same. A capsule slides smoothly along walls and over seams between floor pieces.

**Alternatives:** A box hull like CS uses. A box lets you stand on the very edge of a crate, where a capsule slides off, but it catches on seams more easily in Godot.

## D-016 — Mouse look uses CS's sensitivity formula (2026-10-15)

**Decision:** Each mouse count turns the view by `sensitivity × 0.022°`, like CS's `m_yaw`/`m_pitch`. Mouse movement is read with `screen_relative`, which isn't affected by window scaling, so switching to a low-res look in M3 won't change your sensitivity.

**Why:** So the user's CS sensitivity can be used directly.

**To verify:** macOS may apply mouse acceleration or count Retina pixels differently from CS on Windows. Compare a 360° turn distance with CS and adjust if needed.

## D-017 — How crouching and jumping work (2026-10-15)

**Decision:**
- The player has two collision capsules, standing (72 u) and crouching (54 u), and switches between them instantly. Only the view moves smoothly, over 0.15 s.
- On the ground, crouching lowers your head. In the air, it pulls your legs up instead, so your head stays put, which is CS's crouch-jump. Pressing jump and crouch together works, like a crouch-jump bind.
- You can only stand up if there's room: above your head on the ground, or below your feet in the air.
- A jump happens only on the tick you *press* jump while on the ground. Holding jump never auto-hops, as in CS. Presses are remembered until the next tick, so mouse-wheel jumps aren't lost.
- Jumping caps horizontal speed at 1.2× running speed (Source's bunny-hop limit).
- In the air, gravity is applied half before and half after moving (as Source does), so the jump height is exactly 57 units at any tick rate.

**Why:** These are the CS rules a CS player expects. Each one is covered by an automated test (`tests/movement_test.gd`).

**Alternatives:** A gradual hull change while crouching (closer to CS:GO's duck timing), which can be added if crouch-peeking feels off.

## D-018 — Automated tests as headless scenes (2026-10-15)

**Decision:** Gameplay rules are checked by test scenes in `tests/` that simulate input and measure the results. They run without a window and finish in under a second. A test quits with the number of failures as its exit code.

**Why:** Feel still needs a human, but numbers like top speed, jump height and counter-strafe time can be checked automatically after every change, so tuning one thing doesn't silently break another.

**Alternatives:** A test framework addon such as GUT or gdUnit4. They're more features than Chiip needs right now, and can be added later.

## D-019 — The first weapon is called "Rifle" for now (2026-10-15)

**Decision:** The AK-like first weapon uses the working name "Rifle". Final weapon names are chosen in M6.

**Why:** Naming can wait until there are several weapons to name as a set.

## D-020 — Placeholder sounds are generated by code (2026-10-15)

**Decision:** Gunshot, empty-click and reload sounds are generated by a tool script (`tools/generate_sounds.gd`) and saved as normal `.wav` files in `assets/sounds/`. Weapons reference the files, so real sounds can replace them later without code changes.

**Why:** No downloads or licenses are needed, and crunchy noise bursts fit the retro style. A CC0 sound pack remains an option for the sound pass in M7.

**Alternatives:** Downloading a free CC0 sound pack now.

## D-021 — Default crosshair: static and CS-like (2026-10-15)

**Decision:** The default crosshair is static, green, four lines with a small gap, an outline and no center dot. A dynamic mode that opens up with inaccuracy is available as a setting.

**Why:** It's what most CS players use. The dynamic mode is useful for learning how movement affects accuracy.

## D-022 — Physics layers, and hitboxes as areas (2026-10-15)

**Decision:** Five named physics layers: world, player, bots, hitboxes, triggers (code constants in `systems/physics_layers.gd`). Damage zones are `Area3D` nodes on the hitboxes layer. Bodies that should block movement (player, bots, dummies) sit on their own layers, which bullets ignore. Bullets only test the world and hitboxes layers.

**Why:** Bullets hit the precise zone (head, chest, …) instead of a body's single capsule. Players and bots don't collide with each other's hitboxes. The player never shoots itself.

**Alternatives:** Hitboxes as physics bodies, which would also push things around.

## D-023 — Ground acceleration uses a fixed 250 u/s base, like CS:GO (2026-10-15)

**Decision:** How hard you accelerate on the ground comes from the empty-handed top speed (250 u/s) times the stance factor (1 running, 0.52 walking, 0.34 crouching), not from the held weapon's speed. The weapon only limits your top speed.

**Why:** Found by the movement tests once the rifle was added. With a 215 u/s weapon, crouch-walking (73 u/s) gained less speed per tick than friction removed, so you couldn't crouch-walk at all. CS:GO bases acceleration on 250 u/s for the same reason.

**Consequence:** Counter-strafing with the rifle reaches accurate speed in 70 ms.

## D-024 — Textures: CC0 photo textures turned retro by our own tool (2026-10-15) — *Replaced by D-140*

**Decision:** Textures start as free CC0 (public domain) photo textures from ambientCG. A tool script shrinks them to 64 × 64 and reduces their colors. Each download happens only after the user approves it. Sources are listed in `docs/CREDITS.md`.

**Why:** Real materials give much better retro textures than code-generated patterns, and CC0 means no license conditions.

**Alternatives:** Generating textures by code (no downloads, more abstract look).

## D-025 — Compare TrenchBroom + func_godot with CSG now (2026-10-15)

**Decision:** In M3, the same small room is built with CSG and with TrenchBroom (via the `func_godot` addon) before choosing the workflow for real maps.

**Why:** M3 is where the map pipeline gets decided, and TrenchBroom is the classic Quake/CS-style brush editor.

**Alternatives:** Staying with CSG and deciding in M7.

## D-026 — A free pixel font for the HUD (2026-10-15)

**Decision:** The HUD uses a free pixel font under the SIL Open Font License, downloaded with the user's OK.

**Why:** It matches the retro look. The OFL allows using and shipping the font in a game, including a commercial one.

## D-027 — Pixel style: low-res world, sharp HUD (2026-10-15) — *resolution raised to 480 lines in D-048*

**Decision:** The 3D world renders at 360 lines (640 × 360 in a 16:9 window) and is scaled up with sharp pixels. The HUD and debug overlay are drawn at full window resolution (style B). Chosen by the user from screenshots of both styles.

**Why:** Text stays readable (design pillar 3: clarity), and a pixel font still gives the HUD a retro feel. Style A (everything low-res) remains available with `Main.pixelate_hud`.

**Alternatives:** Style A, the whole window at 640 × 360 including the HUD.

## D-028 — Downloads approved for M3 (2026-10-15)

**Decision:** Eight ambientCG CC0 textures (Concrete034, Plaster001, Bricks075A (stone, now used desaturated as grey stone), Bricks097, Ground080, Planks037A, MetalPlates006, PaintedPlaster017), the `func_godot` 2025.12 addon (MIT) and the Silkscreen font (OFL). The user installs TrenchBroom themselves. Only the processed 64 × 64 textures are kept in the project, and the original downloads are deleted.

## D-029 — Look: sun-baked dusty afternoon (2026-10-15) — *Replaced by D-031*

**Decision:** The test map's atmosphere is a warm late-afternoon desert look, closer to CS's dust maps than to Quake's dark dungeons. That means a low warm sun with long shadows, a dusty blue sky with a sandy horizon, darker ambient light, light haze, slightly more contrast and less saturation, plus colored lamps for accents.

**Why:** It fits the textures we picked (sand, beige stone, brick, concrete) and keeps players easy to see. Fog was halved after the 40 m dummy faded into it (clarity rule).

**Alternatives:** A dark, moody Quake-style look (harder to read at a distance).

## D-030 — Palette effect on by default (2026-10-15)

**Decision:** The world image is limited to 12 shades per color channel with ordered dithering (`Main.palette_effect = true`). Chosen by the user from on/off screenshots.

**Why:** It adds the grain and slight banding of 90s software rendering. The HUD isn't affected.

**Alternatives:** Off, for a cleaner image. It remains a setting.

## D-031 — Look: neutral greys and cool daylight, not a dust map (2026-10-15)

**Decision:** Keep the same set of materials, but take the dust out. Sand and beige stone become grey gravel and grey stone (the same CC0 photos, desaturated), and the red brick is muted. The lighting becomes cool daylight: a neutral white sun, a blue sky, a grey-blue horizon and haze (`assets/environments/cool_daylight.tres`). The only warm accents are wooden crates, colored lamps and the yellow firing line. Replaces D-029.

**Why:** You pointed out that the sand, beige and warm light looked too much like Counter-Strike's dust maps. Chiip should have its own identity, which also matters for a possible Steam release. Of the four directions offered, you chose the smallest change.

**Alternatives:** A dark Quake look, retro sci-fi industrial, or urban night. Any of these can still be tried later.

## D-032 — Real maps are built in TrenchBroom; CSG for quick tests (2026-10-15)

**Decision:** Real maps (from M7 on) are made in TrenchBroom and imported with func_godot. CSG stays for quick test setups. This is provisional until you've built something in TrenchBroom yourself. Baked lighting is decided on the real map in M7.

**Why:** In the M3 comparison both produced identical geometry and collision (within 0.1 mm). TrenchBroom wins on the things that matter for full maps: a dedicated Hammer-like brush editor, per-face texture alignment, lightmap UVs built automatically, and static merged meshes instead of CSG computed at load time. Its costs are an extra app and the func_godot addon, plus one *Build* click (or `tools/build_maps.gd`) after editing.

**Evidence not collected:** the lightmap bake was skipped (it can only be started from the editor's button), and you hadn't really tried TrenchBroom yet.

**Alternatives:** CSG for everything (no extra tools, but no per-face alignment or easy baking), or deciding later.

## D-033 — Multiplayer comes after the single-player game, as M8 (2026-10-15) — *now M9, see D-040*

**Decision:** Chiip gets multiplayer, in a new milestone **M8** after M7: one player hosts and friends join (LAN first, then Steam lobbies), with bots filling empty slots. There's no matchmaking or ranked play. M4–M7 stay single-player but follow network-friendly rules (see ARCHITECTURE.md, "Keeping multiplayer possible"), which keeps the retrofit manageable.

**Why:** You chose to finish a complete single-player game first (rounds, economy, bomb, a real map). That's the faster route to something fully playable.

**Cost, accepted knowingly:** rounds, economy and bomb are built without networking, so M8 has to retrofit replication, client prediction and lag compensation. That's more work than building them networked from the start.

**Alternatives:** multiplayer right after rounds (before economy and bomb), single-player only, or deciding later.

## D-034 — Characters are driven by per-tick input commands (2026-10-15)

**Decision:** All movement and shooting rules live in one `Character` script. It never reads the keyboard: each physics tick it asks its controller (a child node) for a `CharacterInput` and simulates it. The player's keyboard/mouse is one controller; bots (M4) and network players (M8) are others. Player and bot scenes are *inherited* variants of one base `character.tscn`.

**Why:** Bots follow exactly the player's rules (fair, and no second movement system to keep in sync). It's the same structure CS uses (the client's "usercmd"), and the one multiplayer needs (D-033). The *pull* model (the character asks) guarantees each tick uses a fresh command, whatever order the nodes process in.

**Checked:** after the split, all 33 movement and weapon checks pass with identical numbers, and mouse sensitivity is unchanged (2.200° per 100 counts).

## D-035 — Fair bot perception (2026-10-15)

**Decision:** Bots only know what a person in their place could know. They see an enemy only within 80 m, inside a 110° view cone, and with a clear line of sight to its head or chest, checked 10 times a second. They hear running footsteps within 25 m and gunshots within 60 m, but never walking or crouch-walking. They remember the last known position for 8 seconds.

**Why:** Design pillar 4 ("fair bots"). It also makes CS skills matter against them: walking past silently, holding angles, and not shooting when you don't need to.

**Checked:** seen in the open; not seen behind a crate, behind the bot or behind a wall; heard when running behind it; not heard when walking or crouch-walking.

## D-036 — How bots fight (2026-10-15) — *values retuned in D-037*

**Decision:** Bots fight through the same commands as the player, with human limits:
- a reaction time before the first shot;
- a limited turn speed;
- aim error that starts large, settles over time, and keeps a small "shaky hands" wobble that wanders around the target;
- stopping before shooting (counter-strafing on Normal and Hard);
- short bursts beyond 15 m and sprays up close, with partial recoil compensation.

All numbers live in difficulty data files (Easy / Normal / Hard).

**Why:** Fair bots (design pillar 4) that reward CS skills: moving, peeking and spraying well beat them.

**Found while tuning:** a fixed leftover aim error made some bots miss a standing target with all 30 rounds (the offset always pointed the same way, off the head). The wobble fixes it. Normal's minimum error was raised from 0.6° to 0.9° so it misses sometimes.

## D-037 — Bot tuning after the M4 playtest (2026-10-15)

**Decision:**
- Bots notice enemies gradually: one must stay in view for 0.25 s + 1 s per 35 m, 2.5× longer outside the central 50° of vision, scaled per difficulty. Sight range drops from 80 m to 60 m.
- Reaction time is counted from noticing.
- Turning eases in and out (no constant-speed snapping), with a lower turn-speed cap.
- Aim is less precise on every difficulty (see GAME_DESIGN.md, 4.4).
- Searching looks left, right and ahead instead of spinning on the spot.
- Getting shot tells a bot where the shooter is.
- Bots can hold a position (`hold_position`) instead of patrolling.

**Why:** In your playtest the bots "killed me without a chance", "aimed instantly" and turned unnaturally. Spotting you instantly at any distance and range of view was the main cause.

**Result (measured):**
- Normal needs ~0.95 s from seeing you at 10 m to its first shot (was 0.3 s).
- Killing a standing player at 10 m takes Easy / Normal / Hard about 4.3 / 2–4 / 1.1–1.5 s.

## D-038 — Sound is gameplay information: clear and symmetric (2026-10-15)

**Decision:**
- New, brighter footstep sound (36% of its energy in the high range, was 1%).
- Your own footsteps at −12 dB (was −16; −7 dB was too loud in playtest 2).
- Enemy footsteps at +2 dB, loud out to 10 m, fading out at 30 m.
- Enemy gunshots carry to 120 m.

**Why:** Your feedback that sound must be clear because it should feel like multiplayer. As in CS, footsteps tell you where enemies are and whether you're being loud. Hearing is kept symmetric: you hear bots about as far as they hear you (25 m).

## D-039 — Procedural walk animation as a placeholder (2026-10-15)

**Decision:** The blocky soldier gets hip and shoulder joints, and `SoldierBody` swings legs and arms and bobs the body in time with the footsteps, all computed in code. Hit zones move with the limbs.

**Why:** The bots "glided". Real animated character models need their own milestone (M6, D-040). This placeholder costs little and removes the worst problem now.

**Update (M6 task 4):** `SoldierBody` was retired when `CrewBody` took over the characters (D-074).

## D-040 — A characters & animation milestone after M5 (2026-10-15)

**Decision:** A new **M6 — Characters & animation**: rigged soldier models, third-person animations, hit zones on bones, and first-person arms with the rifle. The later milestones move back one: economy & arsenal is now M7, bomb mode & the first real map M8, multiplayer M9. Entries above this one and older DEVLOG entries keep the old numbers.

**Why:** You asked when the game gets properly animated. Rounds, menus and settings (M5) come first, so the game is playable from start to finish; the procedural walk (D-039) covers the gap.

**Alternatives:** Right after M4 (looks better sooner, but the game would stay a sandbox longer), or after the last gameplay milestone (cheapest, but blocky placeholders for a long time).

## D-041 — M5 match rules (2026-10-15)

**Decision:**
- **Teams:** you plus bot teammates vs. a bot team, 1–5 per side, 3v3 by default.
- **No team names.** Each player sees their own team in blue and the enemies in red. Underneath, one side attacks and the other defends: that decides spawns, bot behaviour and who wins on time-out.
- **Match length:** first to 5 (default), 10 or 15; sides swap after 4, 9 or 14 rounds.
- **Freeze time:** 5 s, then 15 s once there's something to buy (M7).
- **No armor until the economy (M7),** where armor and helmet are bought. The armor task moves from M5 to M7.
- **Friendly fire** is a match setting: off by default, a third of the damage when on (CS competitive's reduction).

**Why:** Your choices, from my recommendations and your changes. You picked first to 5/10/15 over CS2's 5/9/13, no armor until it can be bought, a friendly-fire setting, and no team names. A first-to-N match with an odd maximum (9, 19 or 29 rounds) can't end in a draw. Colors relative to the viewer keep enemies clearly red for every player, which also suits multiplayer (M9).

**Alternatives:** CS2's 9/13 lengths; armor every round; fixed side colors (red-orange attackers, blue defenders, which swap at half time); placeholder names (Attackers / Defenders).

## D-042 — Teams, sides and team colors (2026-10-15)

**Decision:**
- **Teams are the fixed numbers 0 and 1** (`Character.team`, `systems/teams.gd`). **Sides** (`Teams.Side.ATTACKING` / `DEFENDING`) are tracked separately by whoever runs the match. At half time only the side assignment swaps; no character changes team.
- **Colors are relative to the viewer.** `Teams.viewer_team` is the team of the person at this computer: that team's clothes are blue (`Teams.FRIENDLY_COLOR`), the other team's red (`Teams.ENEMY_COLOR`). `Teams.set_viewer_team()` recolors everyone; `main.gd` sets it to the player's team when a map loads. The `team_color` export on characters is gone.
- **Friendly fire is `Teams.friendly_fire`**, off by default (console: `mp_friendlyfire`). The rule is applied in `Character.take_damage()` (`Teams.damage_factor()`): teammates take nothing when off and a third when on. With it off, **bullets pass through living teammates** (their hit zones are excluded from the ray in `Weapon._shoot_bullet`), as in CS; with it on, teammates are hit.
- **Spawn ends:** defenders spawn at the north end of the test map behind the peek walls (5 markers, z = −28, facing south), attackers at the south end on the range (5 markers, z = 84, facing north): 112 m apart. Marker groups `defend_spawns` and `attack_spawns`; the old `bot_spawns` / `player_spawns` stay for practice mode.
- **`Teams` is a static class, not an autoload**, so tools run with `--script` can load maps that contain characters (same reason as `Noises`).

**Why:** Fixed team numbers make identity stable: scores, kill feed colors and bot ownership never have to be renumbered at half time, and a network player in M9 keeps one team all match. Sides decide only where you spawn and what the bots try to do, and those are the things that actually swap. Viewer-relative colors keep enemies red for every player (D-041), so there is no color decision to make when sides swap. Putting the friendly-fire rule in `take_damage()` follows "game rules live in authority code" (ARCHITECTURE, multiplayer rule 2). Letting bullets pass through teammates when friendly fire is off stops a teammate walking through your spray from absorbing it, which would be annoying and is not how CS behaves. Opposite ends 112 m apart give attackers a long way to push and defenders something to hold, which the bots' round behaviour (task 4) builds on.

**Alternatives:** Swap every character's team at half time, like CS (simple, but scores, colors and ownership all have to follow the swap, and the number stops being an identity). Fixed side colors, e.g. red attackers and blue defenders (rejected in D-041: they would flip at half time and you would not always be blue). Teammates that block bullets even with friendly fire off (more realistic physics, worse feel). Spawning teams in the existing four corners (too close together and not facing each other).

## D-043 — How the round manager works (2026-10-15)

**Decision:**
- **One node owns the match state:** `RoundManager` (`systems/round_manager.gd`) holds the phase, the round timer, who's playing and alive, the round winner and everyone's stats, and announces each change with signals. HUD, kill feed, scoreboard and menus only listen and read. The rules of a match are a `MatchSettings` resource.
- **Maps hold only the level.** `main.gd` adds the rules node to the loaded map: a `RoundManager` for a match (the default, on maps with both team spawn groups and navigation) or `ArenaRules` for practice (`-- --practice`). The test map's own `ArenaRules` node is gone.
- **Phases are counted down in `_physics_process`** at the 128 Hz tick, not with `Timer` nodes or real time.
- **Freeze time is a flag on the character** (`Character.frozen`): the character drops movement, jumping and shooting from whatever command its controller sends. Looking, crouching and reloading still work.
- **Elimination is checked at the end of the frame** after a death (`call_deferred`). If both teams are wiped out at once, the defenders win, as on a time-out.
- **Stats live in the round manager:** kills (teamkill −1), deaths, assists (more than 40 damage, as in CS) and damage. `Character.damaged` now reports the health actually lost, so overkill doesn't inflate damage.
- **Who attacks first is random** (seeded), and team 0 is always yours in single-player.

**Why:** A single owner of the state is the "authority" rule (ARCHITECTURE, multiplayer rule 2): in M9 the host runs it and clients only show its signals. Counting on physics ticks keeps rounds deterministic for tests and in step with the simulation the host will run. Freezing inside `Character` means every controller (player, bot, network) is held by the same rule, with no chance of a controller forgetting it. Keeping the rules out of the map lets one map serve both matches and practice, and the main menu (task 11) just picks a mode.

**Checked:** 9 new round checks pass (`tests/round_test.tscn`). A headless 3v3 match on the test map played three rounds: two won by elimination, one by the defenders on time-out, with sensible stats.

**Alternatives:** `Timer` nodes for the phases (simpler to read, but they run on their own clock and are harder to replicate); freezing in each controller (every controller would have to remember the rule); a round-manager node saved inside each map (every map would need its own copy and practice would need a second map); putting score and stats in a separate scoreboard node (two owners of the state).

## D-044 — Match flow and the match-end screen (2026-10-15)

**Decision:**
- **The score lives in the round manager** (`RoundManager.score`, rounds won per team number, reset when the match starts). The winner's score goes up *before* `round_ended` is emitted, so every listener already sees the new score.
- **Half time after `rounds_to_win − 1` rounds** (4, 9 or 14): when that round's end pause is over, `attacking_team` flips, `sides_swapped` is emitted and the next round starts, so each team spawns at the other end. Teams keep their numbers (D-042). The longest match is `2 × rounds_to_win − 1` rounds, so a draw is impossible. It works for any `rounds_to_win` ≥ 1 (with 1 there is no half time).
- **The last round's pause still runs.** When a team reaches `rounds_to_win`, the round-end pause plays out as usual, so you see how the last round was won. Then the phase becomes `MATCH_END`, everyone is frozen (`Character.frozen`), `winner` is set and `match_ended(winner)` is emitted. Nothing else happens afterwards: no timer and no new round.
- **The match-end screen** (`ui/match_end_screen.tscn`, `MatchEndScreen`) listens to `match_ended`. It shows Victory or Defeat for `Teams.viewer_team`, the score as "yours - theirs" (blue and red), and a scoreboard of both teams, yours first, one row per player (kills, deaths, assists, damage), sorted by kills and then damage, with your own row highlighted. It reads everything from the round manager and changes no game state.
- **Play again and Quit** until the main menu exists (task 11). The screen only emits `play_again_pressed` and `quit_pressed`; `main.gd` reacts: `restart_match()` reloads the current map in the current mode, and Quit closes the game. A new map hides the screen again.
- **The screen blocks the game's mouse input:** a full-screen background `Control` with `mouse_filter = STOP` sits behind the panel, so clicks never reach `PlayerController` (which captures the mouse on any click it receives). The screen shows the cursor, keeps it visible (also after the console closes) and swallows Esc.

**Why:** One owner of the match state is the authority rule (D-043): in M9 the host counts rounds and decides when the match ends, and clients only show the screen. Counting the score before `round_ended` means a HUD or kill feed listening to the signal never shows a stale score. Swapping sides by flipping the attacking team, rather than changing teams, is what D-042 prepared; waiting for the end of the pause keeps the round-end result on screen with the old sides. Letting the last round's pause run avoids a match that ends the instant the last enemy dies. Freezing everyone is enough to stop the game without pausing the tree, which M9 can't do. Emitting signals from the screen instead of calling `main.gd` keeps it reusable: the main menu will replace Quit without touching the screen.

**Checked:** 8 new round checks (17 in all): the score at each `round_ended`, the swap after round 4 of 5 and the spawns at the other end, the match end after the pause, nothing happening afterwards, and two tiny matches (first to 1: no half time; first to 2: swap after round 1, decided in round 3). The screen was rendered in the real main scene at 1280 × 720 (3v3 and 5v5, Victory and Defeat) and at 1920 × 1080; "Play again" starts a fresh match and hides the screen.

**Alternatives:** Ending the match the moment the deciding round is won (the result flashes by, and the last kill gets no moment); swapping every character's team at half time (D-042); pausing the scene tree at match end (M9 can't pause the host); the screen calling `get_tree().quit()` and `reload_current_scene()` itself (couples it to the game's structure and to the Quit button the main menu replaces); scoreboard rows in a `GridContainer` (columns line up for free, but a row can't get a background, which the highlighted "you" row needs).

## D-045 — How bots play rounds (2026-10-15)

**Decision:**
- **A round plan from `BotTactics`** (`bots/bot_tactics.gd`): at every round start the round manager hands both teams to `BotTactics.plan_round()`, which gives each bot its orders (`BotController.attack()`, `defend()` or `patrol()`). You get no orders.
- **The map provides the places:** attack routes (Node3D nodes in group `attack_routes` with Marker3D waypoints as children, in order) and hold spots (Marker3D nodes in group `hold_points`, facing the angle to watch). The test map has three routes and six hold spots under a new `Tactics` node. Maps without them fall back to patrolling.
- **Attackers** form groups of about two (`ceil(n / 2)` groups, at most one per route), take different routes, start 0.6 s apart plus up to 0.4 s at random, and shift each waypoint by up to 1.2 m. After the route they clear the defenders' end (hold spots and spawns) at walking speed.
- **Defenders** each take a different hold spot and watch its angle with a ±10° drift. They engage what they see, but only *go and check* (search) enemies seen or heard within 35 m; after that they hold the nearest spot.
- **After a detour** attackers continue from the route leg they're closest to, never going back along the route.
- **Line of fire:** a bot doesn't pull the trigger while a living teammate is within 0.6 m of the line from its eyes to its target.

**Why:** Today's patrolling bots wandered, so rounds could stall until the clock ran out. A plan per round gives the CS shape: attackers take the fight to the defenders, defenders hold angles and win on time if nobody comes. Routes and hold spots as map markers keep the map's tactical knowledge in the map, editable in the editor, and the M8 map can bring its own. Groups of two and staggered starts look like people moving together without stacking on one spot. The 35 m rotate limit stops one distant gunshot from emptying every hold spot. Holding fire for teammates is how people play, and it matters once friendly fire is on.

**Checked:** a new tactics test (`tests/tactics_test.tscn`, 4 checks) plays a seeded bots-only 3v3: all bots get orders; after 8 s each defender is on a different spot within 8° of its angle; after 10 s every attacker is at least 36 m out of spawn, spread over two routes (52 m apart), the closest two 2.2 m apart; four rounds all end by elimination, after 27–47 s. A new bot check: no shots while a teammate is in the line of fire, 18 shots once it steps aside. With an idle player as the last defender, attackers found and killed it after ~18–40 s.

**Alternatives:** one shared "team brain" that moves bots as a unit (better coordination, much more code; the backlog's "smarter team AI"); routes computed from the navigation mesh instead of hand-placed markers (no map work, but no control over lanes); defenders rotating on any gunshot (simple, but everyone runs to the first fight); letting bots spray through teammates when friendly fire is off (harmless, but looks wrong).

## D-046 — Spectating (2026-10-15)

**Decision:**
- **First person only.** After you die in a match you watch a living teammate through their eyes, like CS. The camera is the same one you play with, moved to the teammate's interpolated head, turned to their aim, plus their weapon's recoil kick (`view_punch`). No free look while you spectate.
- **A 2 s death view first.** For about 2 s (`spectate_delay`) you keep seeing your own death from where you fell, with "Killed by …", so you see who got you. Then the view moves to the first living teammate in scene-tree order. A click switches to the next living teammate (wrapping around). Clicks during the first 2 s are ignored, so a click you were still spamming when you died doesn't skip the view of your killer.
- **When the teammate you watch dies,** the view moves to the next living one after 1.5 s (`spectate_switch_delay`). With nobody left it stays on the last one, where they fell: you see the end of the round from there.
- **Your next respawn ends it.** At the next round start you are back in your own eyes. Practice mode (`ArenaRules`) has none, because you respawn after 3 s: `main.gd` turns `PlayerController.spectating_enabled` on only when the rules are a `RoundManager`.
- **What is hidden:** the watched teammate's `Body` (the camera sits inside its head) and your own first-person rifle (a child of your camera). Both come back when the view moves on or the round restarts. The teammate's rifle stays visible: it hangs under their `Head` at the same offset as your first-person rifle, so from their eyes it looks like their viewmodel, with their muzzle flash and kick.
- **HUD:** the HUD shows the watched teammate's health, ammo and weapon name instead of yours, and a line "Spectating Bot2 · click for next" ("· dead" once they're down). The HUD binds to a *shown character* (`set_view_target()`), connected to the controller's `view_target_changed` signal by `main.gd`.
- **Purely local presentation.** Nothing in the round manager or the characters changed: spectating only reads `team`, `is_alive()`, the head and the aim, and moves the camera, hides two nodes and drives HUD labels (ARCHITECTURE, "Keeping multiplayer possible", rule 2). In M9 it works the same from what the host replicates. Sound needs no change: the 3D listener is the camera, so you hear from the teammate's position, as in CS.
- **Mouse capture unchanged.** The click that recaptures the mouse still doesn't count (it is handled before the spectating click), and the console and the match-end screen still block input.
- **API for tests and later screens:** `PlayerController.spectate_next()`, `get_view_target()` (yourself when you aren't spectating), `is_spectating()`, signal `view_target_changed(target)`.

**Why:** First person matches how people play CS and how the sound already works (you hear what the teammate hears), and it needs no new camera: one camera follows whichever head it's told to. The 2 s delay is what CS does with its death view, and it stops a mashed fire button from skipping the information about who killed you. Staying on the last view when nobody is left means the round-end pause shows the fight from where it ended, with no extra rules. Keeping the teammate's rifle instead of hiding it came out of the screenshots: without a gun the view looks like a floating camera, and with it you also see their shots. Doing it in `PlayerController` keeps the characters and the round manager unaware of it, so the rules stay the single authority.

**Checked:** 9 new round checks (26 in all) cover each rule above, and a mutation run (a wrong wait time, not restoring the body) fails six of them. Rendered in the real main scene at 1280 × 720: the camera sits at the teammate's head, no body or gun clips into the view, the HUD line is readable, and a real click in a windowed run switched Bot1 to Bot2. Headless runs can't capture the mouse, so there a click always counts as the recapturing click; the test checks exactly that.

**Alternatives:** A free-fly camera (flexible, but it shows you the enemy positions and needs its own controls; CS only allows it when you're dead and the team is wiped, or in demos); a third-person chase camera behind the teammate (simple to show, but you don't see what they see, and the sound would come from the wrong place); spectating enemies too (fine for a spectator mode, but it gives away where the other team is, which is exactly what a dead teammate must not do in a tactical shooter); hiding the teammate's rifle as well (no clutter, but no gun in view); starting the view change the moment you die (no time to see your killer); a separate `Spectator` node with its own camera (cleaner separation, but a second camera means the audio listener, the crosshair and the HUD all need re-pointing).

## D-047 — The round HUD (2026-10-15)

**Decision:**
- **A view only.** `RoundHud` (`ui/round_hud.tscn` + `.gd`, a child of the HUD) connects to the round manager's signals and reads its state; it never changes the game. `main.gd` hands the manager to the HUD on every map load (`HUD.set_round_manager()`), with null in practice mode, which hides the round HUD; the previous manager is disconnected first, so "Play again" doesn't leave old connections behind. Timer, score and players alive are read every frame (`_process`), messages and the kill feed come from the signals.
- **Top bar, top centre.** Your score on the left in a blue box, the timer in the middle, their score on the right in a red box (colors relative to the viewer, D-042). Under each score one small square per player, lit while that player is alive, instead of a number. The timer shows the *freeze countdown* (yellow) during freeze time, then the round time as m:ss (a started second counts as a whole one, so a 115 s round starts at 1:55; red in the last 10 s). During the round-end pause it keeps the value the round ended with (0:00 after a time-out), so it doesn't turn into the pause's own countdown. "Round 3" sits under it.
- **Freeze time, in the center.** "Round 3 · starts in 4", and below it your side this half: "You attack: push to the far end" or "You defend: hold your end". After the half-time swap "Switching sides" (gold) is added above for that freeze time, and when a team is one round from winning a line "Match point" (yours, blue), "Enemy match point" (red) or "Match point for both teams" closes the block. All of it disappears when the round goes live.
- **Round-end banner, in the center.** "Round won" in blue or "Round lost" in red, and the reason said for your side: "Enemy team eliminated" / "Your team was eliminated", "Time ran out: you held your end" (you defended and won) / "Time ran out: the defenders held their end" (you attacked and lost). It is cleared when the next round's freeze time starts and at the match end (the end screen takes over).
- **Kill feed, top right** (`ui/kill_feed.gd`, `KillFeed`). One line per death: "Killer > Victim", each name in its team's color, and a gold "HS" after a headshot. A death with no killer (or a suicide) shows just the victim. Lines that involve you, as killer or victim, get a darker background and a white outline. The newest line is at the bottom, there are at most 5 (a sixth pushes the oldest out), and each fades out after 5 s (0.5 s fade). The feed is emptied when a round starts, as in CS.
- **Glyphs.** Silkscreen has no arrow (→, U+2192), so the separator is a plain ">", and the headshot mark is the text "HS" (a skull would need an image). It does have "·", "×" and "»". Checked by rendering a real match.
- **Colors** come from `Teams`: `text_color_for(team)` is the team color lightened by 0.35 (new, the same lightening the match-end screen uses), blue for the viewer's team and red for the other.
- **Clicks go through.** Every control of the HUD ignores the mouse (`mouse_filter = IGNORE`), because the player controls recapture the mouse and shoot from clicks that no `Control` took.
- **Layout from containers**, so it grows with the text, scaled for the window by a new `UiScale.apply_tree()` (font sizes, minimum sizes, spacing, and the offsets of the few controls placed by anchors). Designed for a 720-pixel-tall window like the rest of the HUD.

**Why:** The round manager is the one owner of the game state (D-043), so the HUD is a listener: nothing it does can change a round, and in M9 the same code shows what a host announces. Reading the numbers that change every frame (timer, alive) and using signals for the moments (banner, kill, swap) keeps both simple: a signal can't be missed for the timer, and a message can't flicker. Squares instead of a number read at a glance and fit 1–5 players per team without a label; the lit count is also what tests read. Showing the freeze countdown in the timer slot is what CS does, and freezing the timer at the round end avoids a second, confusing countdown. The side line and "Switching sides" matter because your spawn end changes at half time and you must know where to push or hold. Match point warns you when one round decides the match. ">" and "HS" are what the font can draw and are clear to anyone who has played CS. Highlighting your own lines is how CS lets you find your kills and deaths in a busy feed. Clearing the feed per round and fading after 5 s keep old kills from piling up. Containers adapt to names of any length without hand-placed offsets.

**Checked:** 26 new round checks (52 in all), reading the real `hud.tscn` while a seeded match is played: timer and countdown, side lines for both sides, score and squares after kills, feed lines (names, colors, headshot mark, highlight, victim only), the five-line cap, fading, banners for a win and a loss by elimination and on time-out, half time and the three match-point texts, handing over another manager (or none) without doubled connections, scaling, and that nothing takes mouse clicks. A mutation run (no disconnect, swapped time-out texts, the half-time notice never cleared, no feed reset, a sixth line allowed, a doubled lifetime) fails eight of them. Rendered in the real main scene at 1280 × 720 and 1920 × 1080: freeze time, a live round with five feed lines, the banners and the half-time notice. In the real main scene "Play again" gives the HUD the new manager with no connections left on the old one, and practice mode hides the round HUD.

**Alternatives:** A number for players alive (exact, but a bar of squares is faster to read; the number can still be added later); a skull icon for headshots (needs an image asset, so deferred to the UI theme task); one `RichTextLabel` with BBCode per feed line (one node, but colors and highlights can't be read back by a test and it wraps badly); an arrow font glyph (not in Silkscreen); keeping the feed across rounds (clutter after a long round); showing "Switching sides" for only the first seconds of freeze time (the line is useful for the whole freeze time, and 15 s of freeze time are coming with the buy menu, so it would need another timer); everything inside `hud.tscn` (one 500-line script instead of three small ones); numbers like "2 - 1" for the score in the middle (CS shows the two scores apart, which is what the boxes do).

## D-048 — Less pixelation and blur (2026-10-15)

**Decision:**
- The world renders at **480 lines** instead of 360. Your 1440-pixel-tall monitor shows each world pixel as 3 × 3 screen pixels instead of 4 × 4.
- Textures use **anisotropic filtering** on top of mipmaps, so floors stay sharp into the distance instead of smearing into a blur at about 10 m.
- The palette effect is lighter: **16 shades** per channel instead of 12, and **dithering strength 0.35** instead of 0.6, so less visible grain.
- **Fog density 0.0025** instead of 0.0035: less haze on distant walls.

**Why:** You asked to turn the blur and pixelation down a bit. Before/after screenshots at 1440 pixels tall showed the mipmap smear on floors as the main blur, then the dither grain and the haze.

**Alternatives:** 540 lines, which on a 1440-pixel screen can't scale by whole pixels and gives uneven pixel sizes; turning mipmaps off, which makes distant floors shimmer when you move.

## D-049 — Three quick maps and a respawn mode, like Call of Duty (2026-10-15)

**Decision:**
- **M8 builds three maps,** not one, in a rotation. They're small and fast like CoD's: about 40–60 m across, three lanes with connections, first contact within 5–10 s of spawning, and short sightlines.
- **M8 adds a team respawn mode** next to the bomb rounds, like CoD's Team Deathmatch: respawn about 3 s after dying, away from enemies, first to a kill limit or most kills after 10 minutes. Every map works in both modes.
- M8 is renamed **"Modes & 3 quick maps"**. Multiplayer (M9) starts with all three maps.

**Why:** You want a map rotation of three, and quick maps with a lot of action, more like Call of Duty. Small maps alone speed up the rounds; a respawn mode gives non-stop action. Today's Practice arena already works that way.

**Alternatives:** One map in M8 and two more in their own milestone, or after multiplayer (multiplayer sooner, with fewer maps). Rounds only, with all the action coming from the small maps. The respawn mode as the main mode.

## D-050 — The scoreboard: hold Tab, one shared table (2026-10-15)

**Decision:**
- **Hold Tab, like CS.** A new input action `scoreboard`, bound to the Tab key by physical position (D-012). The panel shows while the key is held and is gone when you let go; there is no toggle. It never pauses anything, never blocks movement and never takes mouse clicks (every control uses `mouse_filter = IGNORE`).
- **One table for both screens.** `ScoreboardTable` (`ui/scoreboard_table.tscn` + `.gd`) is the two-team table that used to live inside the match-end screen: your team first under a blue header, then the enemy under a red one; one row per player with name, kills, deaths, assists and damage (rounded); sorted by kills, then damage, then join order; your own row highlighted and marked "(you)". `show_match(rounds)` hands it the match, `refresh()` reads the numbers. The match-end screen and the new `Scoreboard` overlay both contain one.
- **Who is alive: dead players' rows are dimmed** (40% opacity) with `dim_dead`, which the overlay turns on and the match-end screen turns off (the final table shows final numbers, so the losers of the last round aren't greyed out and it looks exactly as before).
- **The overlay** (`ui/scoreboard.tscn` + `.gd`, `Scoreboard`, a `CanvasLayer` on layer 3: above the HUD, below the match-end screen on 5 and the console on 10) has a header with "Round N" and the score (yours blue, theirs red) above the table, centered on screen. It is a pure view of the `RoundManager` and **polls** it every frame while visible: damage, which changes the numbers, has no round-manager signal, and reading the state each frame is how the round HUD already treats the timer and the alive counts (D-047). The table is rebuilt only when something it shows changes (a stat, a death, a respawn), so polling is cheap, and there are no connections to drop when a map reloads.
- **When it shows.** Only in a match with a round under way: `main.gd` hands it the round manager on every map load (null in practice mode, where it never appears; "Play again" replaces the manager). Tab is ignored while the developer console is open, and the overlay stays hidden once the phase is `MATCH_END`, when the match-end screen takes over. The last round's pause still shows it.
- **Scaling** like the other UI: designed for a 720-pixel window, `Scoreboard.set_ui_scale()` is called from `apply_pixel_settings()`; the table scales its own rows (they are rebuilt), and the match-end screen hands it the factor instead of walking into it.

**Why:** CS players read the scoreboard in a hurry, between fights, so it has to appear and vanish with one finger and never get in the way: hold instead of toggle, no mouse capture, no pause. Moving the table out of the match-end screen avoids a second copy of the same sorting, colors and highlight that could drift apart, and gives the next tasks (UI theme, settings) one place to restyle. Dimming costs no extra column and works at a glance, like CS's greyed-out dead players; keeping it off in the end screen keeps that screen identical. Following the authority rule (D-043), the overlay only reads. Hiding at the match end avoids two overlapping tables.

**Checked:** 22 new round checks (74 in all): the action and a real Tab press through the input path; the table (both teams, yours first under the right header, also seen from team 1; every cell against `get_stats()` after a scripted fight, 20.6 damage reads 21; sorted by kills, then damage, then join order; dead rows dimmed and living ones not; only your row highlighted; rows kept when nothing changed; next round nobody dimmed and the numbers carried over); the overlay (hidden, shown while held, hidden after release; header with round and score in team colors, also after a round is won and in the next round; follows damage and kills while held; you can still walk; ignores Tab while the console is open; no control takes clicks; scaling 1.5 including rebuilt rows; a replaced or missing round manager; hides at the match end but not in the last round's pause); and the match-end screen (same table, nobody dimmed although the three enemies are dead, scaled, emptied when it gets no manager). A mutation run (12 changes, e.g. sorting without kills, never dimming, the console and match-end rules removed, every row highlighted, rows taking the mouse, the end screen dimming, truncating instead of rounding, the enemy listed first) fails at least one check each. Rendered in the real main scene at 1280 × 720 (3v3, mid-round) and 1920 × 1080 (5v5), and the match-end screen's panel matches the one before the change pixel for pixel (largest difference 1.6% of one color channel, from the game showing through the panel).

**Alternatives:** A toggle on Tab (one press to open and another to close: slower in a fight and easy to forget open); building the overlay's rows separately from the match-end screen's (two sorting and highlighting implementations); a `GridContainer` for the table (columns line up for free, but a row can't get a background, which the "you" row needs, see D-044); rebuilding the rows every frame (simple, but 40 nodes created and freed each frame); signals instead of polling (needs a new "stats changed" signal on the round manager only for this view); showing who is alive with a skull or a "dead" text column (needs an icon or a column; the font has no skull); keeping the scoreboard visible over the match-end screen (two tables at once).

## D-051 — Characters stay rigged 3D models; sprites are concept art (2026-10-15)

**Decision:** Characters are rigged low-poly 3D models, as M6 planned, and first person keeps a 3D viewmodel. A prototype that renders 8-direction billboard sprites (Doom and Duke 3D style) becomes a concept-art tool in `tools/concept/`, for designing the crew's looks before they are modelled.

**Why:** You chose it after seeing the prototype's sprites. 3D models give hit zones that follow each limb, smooth blending between animations, and first-person arms that match the body others see. Quake used 3D models too.

**Alternatives:** Billboard sprites for the characters (cheap to make, a strong Doom look, but hit zones could only follow the stance, not the limbs); a 2D sprite viewmodel (Doom style).

## D-052 — Classes: a look and one passive perk (2026-10-15)

**Decision:** Four classes, Rifleman, Bulwark, Marksman and Scout (working names), each with its own body and one passive perk (values in GAME_DESIGN.md, section 4.9). Classes don't restrict weapons. You pick a class at match start and can change it during freeze time; bots get a mix. The perks switch on in M7, when armor and scopes exist. The Scout's *Light Step* (running footsteps carry 70% as far) is a deliberate exception to D-038's rule that sound works the same for everyone.

**Why:** You asked for classes with their own style and a playstyle feature, and picked passive perks. They keep CS's shooting and economy intact: every class buys from the same menu, and no ability button changes how a duel plays out. Small, readable numbers keep it fair with one life per round.

**Alternatives:** A fixed loadout per class (more like Team Fortress; money would only buy armor, pistols and grenades); cosmetic-only characters like CS's player models; active abilities; +4% top speed for the Scout instead of quieter steps; locking the class for a whole half.

## D-053 — A distinct crew, with team colour painted at runtime (2026-10-15)

**Decision:** The four classes differ in height, build, posture and headgear, so you can tell them apart by silhouette alone. Each wears a neutral kit (greys, olive-greys, charcoal; no desert tones, D-031) with team-colour parts marked in a mask. A shader paints those parts blue for the viewer's team and red for the enemy (D-041, D-042: `Teams.FRIENDLY_COLOR` / `Teams.ENEMY_COLOR`) and keeps the shading, like Quake's shirt and pants colours.

**Why:** You chose a distinct crew over one shared body with different kit. Because the colours depend on who is looking, a team's colour can't be baked into the textures: the class has to read from its shape, and the team from its colour.

**Alternatives:** One shared body with different kit per class; retro sci-fi armored troopers; two fixed team looks (ruled out by D-041).

## D-054 — Models and animations come from a generator (2026-10-15)

**Decision:** A Python tool (`tools/modelgen/`, built in M6 task 2) makes every character, weapon and set of first-person arms from a part list. Each part is a low-poly piece (a bevelled box, a tapered cylinder, a low-res sphere) fixed to one bone. The tool paints a palette-limited texture and a team mask, writes the animations as keyframes, and exports `.glb` files that Godot imports. It runs outside the game, with Python 3, numpy and Pillow in a virtual environment.

**Why:** It needs no Blender. Every change is a number in a part list and a re-run, so four classes and the whole arsenal stay consistent with each other. The same definitions also render concept sheets and icons. Pieces fixed to bones give a late-90s look, which is the era Chiip is after. A `.glb` opens in Blender if a piece ever needs polishing by hand.

**Alternatives:** Modelling by hand in Blender (the highest quality ceiling, but weeks per character, and Blender to learn first); free CC0 packs plus Mixamo animations (fastest, but generic: they won't fit a distinct crew, need retexturing, and every download needs your approval).

## D-055 — Hit zones follow each class's body (2026-10-15)

**Decision:** Each class's hit zones are sized from its own part list and follow its bones, so a bigger body is a bigger target: the Bulwark is the easiest to hit and the Scout the hardest. The perks balance the difference.

**Why:** What you see is what you hit. With identical zones for everyone, shots that visibly hit the Bulwark's armor could miss, and the Scout's visible head wouldn't match its zone.

**Alternatives:** Identical hit zones for every class (CS's fairness rule: every player model has the same hitboxes).

## D-056 — The arsenal (2026-10-15)

**Decision:** Five primaries (an AK-style rifle, a carbine, an SMG, a pump shotgun and a sniper rifle), two pistols (a free service pistol and a hand cannon), the knife, and three grenades (high explosive, flashbang, smoke). The names come in M7. Each weapon gets a world model, a third-person model, a first-person model and icons, all from the generator (D-054).

**Why:** You asked for an AK-like rifle and a few others. This set covers CS's buy decisions (an SMG for eco rounds, a shotgun for close range, a rifle for duels, a sniper, a pistol for force-buys) and gives each class a signature gun.

**Alternatives:** The earlier "2 rifles, a sniper, maybe an SMG or a shotgun"; more weapons per slot.

## D-057 — The UI theme: one generated Theme, a scaled copy for each window size (2026-10-15)

**Decision:**
- **One theme, the project theme.** `ui/chiip_theme.tres` is set in *Project Settings → GUI → Theme → Custom* (`gui/theme/custom`), so every `Control` gets it. It styles Button (rest, hover, pressed, focus ring, disabled), Panel and PanelContainer, Label, LineEdit, HSlider/VSlider, ProgressBar, CheckBox and CheckButton (their own styles and pixel-art check marks, radio dots and a switch), OptionButton and its drop-down list (PopupMenu), TabContainer/TabBar, scroll bars, separators, tooltips and RichTextLabel colors. The pixel font stays Silkscreen (D-026).
- **The look:** square shapes with crisp 2 px borders, nothing anti-aliased, in cool dark blue-grey with **one icy cyan accent** for focus rings, selection, slider fill, check marks and the selected tab. Hover is a lighter button, pressed (and a toggle that is on) a dark teal with accent text. It echoes the daylight world (D-031) and shares nothing with Counter-Strike's orange and yellow on black: the match-end screen's and the console's orange borders are gone. Team blue and red stay in `Teams` (D-042).
- **Palette** (`tools/ui_palette.gd`): inset fields `#0b1017` with border `#38465b`; panels `#141b25` (96% opaque, 88% for the Tab overlay) with border `#46546b`; raised page `#1b2432`; button `#232d3d` / hover `#303d54` / pressed `#12384a` / disabled `#171d27`, border `#5b6b85` (disabled `#2b3544`); accent `#4cc9f0`, bright `#a6ebff`, mid `#2f93b4`, dark (selection fill) `#1e6a86`; text `#e6ecf5`, bright `#ffffff`, dim `#9aa8bd`, disabled `#5f6c80`; handles `#c7d2e2`.
- **Pixel sizes** (for a 720-pixel window): text 16 (body, buttons, rows), 32 (scores, big buttons) and 48 (titles). Silkscreen is drawn on a grid of 1/8 em, so a multiple of 16 is a whole number of pixels per font pixel at 1×, 1.5× (24, 48, 72) and 2× (your 1440p monitor), where 24 px would end up at 36 and look uneven. Borders 2 px, padding 14 × 8, icons drawn in 2 × 2 px cells. The old match-end screen's 56 / 40 / 20 px title, scores and buttons became 48 / 32 / 16.
- **Type variations for roles**, so menus name what a thing is instead of overriding how it looks: `TitleLabel`, `ScoreLabel`, `HeaderLabel` (accent), `DimLabel`, `BrightLabel`; panels `ModalPanel` (accent frame), `OverlayPanel`, `InsetPanel`, `ConsolePanel`, `RowPanel`, `YouRowPanel`, `TeamHeaderFriendly`, `TeamHeaderEnemy`; margins `PanelMargin`, `PanelMarginWide`, `RowMargin`; boxes `ContentBox`, `TableBox`, `TeamBox`, `ScoreRow`, `FormRow`, `ButtonRow`; `BigButton`; `TooltipPanel` and `TooltipLabel`. Plain containers keep Godot's own spacing on purpose: the HUD relies on it, so it doesn't move. A custom `Palette` type holds the named colors (`accent`, `text_dim`, `friendly`, `enemy`...) for code that needs one.
- **The theme is generated.** Colors live in `tools/ui_palette.gd`, the icons are drawn by `tools/generate_ui_icons.gd` into `assets/ui/` (PNG files, imported with nearest filtering), and `tools/make_ui_theme.gd` writes `ui/chiip_theme.tres`. Change the look there and run the tools again (commands in CLAUDE.md). The team header and "you" row colors are copied from `Teams` and `ScoreboardTable.YOU_ROW_COLOR`; `ui_test` fails if they drift apart.
- **Scaling: a scaled copy of the theme.** Menus are laid out for 720 pixels. `UiTheme.apply(root, factor)` (`ui/ui_theme.gd`) gives a menu a copy of the theme in which every font size, constant (spacing, margins), stylebox (borders, corners, margins) and icon (resized with nearest-neighbor, so pixel art stays crisp) is multiplied by `factor` and rounded to whole pixels. Because every control below looks its style up in that copy, nothing else needs to know about scaling. What a theme can't hold, a node's own `custom_minimum_size` and any font-size or spacing override, is scaled by the same call, with the originals remembered so it can run again with another factor. A copy is made once per factor (the last four are kept); 1.0 is the theme itself; a `CanvasLayer` root hands the theme to the controls beneath it. The menus' `set_ui_scale()` is now just `UiTheme.apply(self, factor)`. The HUD isn't a menu and stays on `UiScale`.
- **Moved onto the theme:** the match-end screen, the Tab scoreboard and its table (rows, headers and highlights are variations; the code only picks names) and the developer console (rebuilt from containers). Per-node overrides are left only for what is one-off or data: the colors of the result title and scores, the size of a panel or button.
- **A side effect on the HUD:** the project theme is global, so HUD text that sets no color of its own (health, ammo, weapon name, the top bar numbers) is now `#e6ecf5` instead of pure white. Rendering the HUD alone with and without the theme, no pixel differs by more than 10% of a color channel.
- **`ui/theme_preview.tscn`** (a developer tool) shows every styled control, all button states and every label variation in one window; run it with `--resolution 1920x1080` to see the scaling.

**Why:** One theme keeps every menu consistent and lets the look change in one place, which the settings menu, main menu and pause menu (tasks 9 to 12) need: they are built from buttons, sliders, tabs, check boxes and option buttons, and now find them already styled. Variations instead of per-node overrides keep scenes and scripts free of colors and sizes. Scaling the theme instead of the nodes is what makes that work: a stylebox's border or a check mark's size isn't a node property, so the old way (override every font, spacing and size on every node) could never reach them. Sizes on the font's grid keep the pixel look crisp at the window sizes the game really runs at. Generating the theme from one palette file means a color changes in one line, in the project's usual way (sounds, textures, maps and models are generated too).

**Checked:** the new `ui_test` (35 checks): the project theme and font, the look of plain controls in the tree, the variations and the copied colors, every font size, stylebox, icon and constant of the 1.5× theme (icons also at 2.0 and 1.25, always from the original), a sample menu at 1.0, 1.5, 2.0 and back (including the drop-down's popup and one-off overrides), the preview, the console, the Tab scoreboard and the match-end screen (rows still built, also rows built after scaling, looks from variations, no style overrides left, exactly 1.5×). A mutation run (nine changes) fails at least one check each; it exposed that `Texture2D.get_image()` returns the texture's own image, so the scaled icons are made from a copy. The 74 old round checks (which also cover the scoreboard, the match-end screen and UI scaling) still pass unchanged. Rendered in the real game at 1280 × 720 before and after (match-end screen, scoreboard, console) and the preview at 1280 × 720 and 1920 × 1080.

**Alternatives:** Keeping `UiScale` for menus (it scales per-node overrides only, so it can't scale styleboxes or icons, and every node would need an override, which defeats having a theme); scaling the whole menu with `Control.scale` or the window's `content_scale_factor` (text and pixel art would be resampled, blurry at 1.5×, and the 3D viewport container would scale too); one hand-saved `.tres` per size (only fixed sizes, and three files to keep in step); a hand-written theme with no generator (about 900 lines to edit by hand, colors in dozens of places); text sizes 20 and 24 (not a whole number of pixels per font pixel at 1.5×); 9-sliced bevel textures for 90s buttons (a second image set to scale and keep in step; flat boxes with crisp borders were enough); the 56 / 40 px title and score sizes (off the pixel grid at 1.5×).
## D-060 — Three quick-map blockouts: Depot, Square, Spillway (2026-10-15)

**Decision:**
- Three layouts, each with a different middle: **Depot** (indoor mid, open sides), **Square** (open mid, tight sides), **Spillway** (sunken mid, high sides). Details, plans and numbers are in [MAPS.md](MAPS.md). Names are placeholders you picked.
- Same conventions as the test map, plus two new marker groups for M8: `bomb_sites` (an `Area3D` per site on the triggers layer, switched off until the bomb exists) and `respawn_points` (12 per map in four zones, also used as Practice spawns now).
- Building rules for every map: no steps (ramps of 26° or less), gaps at least 2.5 m wide, tall cover 2.2 m or more, low cover 1.2 m or less, walls next to raised floors tall enough not to be seen over, open floor at each site's centre.
- The blockouts were generated once from a layout script kept outside the repository. From now on the `.map` files are the only source, edited in TrenchBroom.

**Why:** Three different middles give three different ways to play the same three-lane idea, so the maps don't blur together in a rotation. Putting the bomb sites and respawn points in now means M8's bomb and respawn mode only add logic, not map work. Keeping the generator out avoids two sources of truth once you start editing in TrenchBroom.

**Alternatives:** Three maps on one template with different textures (quicker, but they would play alike); placing the bomb sites when the bomb exists (the maps would have to be reopened and retuned); keeping the layout script in `tools/` (faster retuning by code, but any regeneration would overwrite your TrenchBroom edits).

## D-061 — Measuring first contact and sightlines (2026-10-15)

**Decision:**
- **First contact** is the moment the first bot notices an enemy (`BotSenses.enemy_spotted`), timed from the round going live, in a seeded bots-only 3v3. `tests/maps_test.tscn` plays 4 rounds per map and requires a median of 5–10 s; it also checks the markers, that every marker stands on the navmesh, and that both spawns can walk to both sites.
- **Sightlines** are measured by `tools/map_report.gd`: eye-height rays (1.63 m) between every pair of spots you can walk to, sampled every 1.5 m. Targets: no spawn-to-spawn views, the longest views around 40 m. Result: Depot 44 m (3 pairs over 40 m), Square 35 m, Spillway 38 m.

**Why:** Bots play the same rounds a player would, so their timing is the closest automatic measure of "action within 5–10 s"; a fixed seed makes it repeatable. The sightline report found long diagonals that the plans didn't show, which is how most of the tuning was guided. Only reachable spots count, so the tops of crates don't produce fake lines.

**Alternatives:** Timing by walking distance only (ignores defenders moving up and sound); requiring every single round in 5–10 s (one slow round would fail a good map); a stricter 30 m sightline limit (would need far more blockers on the open Depot).

## D-062 — A lighting mood per map, all within cool daylight (2026-10-15) — *ambient light and Depot's environment changed in D-063*

**Decision:** Depot uses today's `cool_daylight.tres`. Square gets `clear_morning.tres` (paler sky, a little more haze) with a low sun, 24° high, for long shadows. Spillway gets `overcast.tres` (grey sky, stronger ambient light, more fog) with a weak high sun. All neutral or cool, with warm light only from lamps (D-031).

**Why:** Three distinct looks were asked for, and lighting changes the mood most with the textures we already have. Real-time lights keep it adjustable until baked lighting is decided in M8.

**Alternatives:** One environment for all three (less distinct); night or dusk maps (darker than the clarity rule allows for now).

## D-063 — Look rules for the maps: minimal, pixelated, players stand out (2026-10-15)

**Decision:** Your direction: *"everything should be minimalistic and pixelated, cs/quake/cod like with the characters like I showed you"*. For the maps:
- **Minimal and blocky:** box geometry, clean spaces, no clutter or realistic detail; **at most 5 materials per map** from the 64 × 64 retro textures (Depot 5, Square 4, Spillway 5).
- **No saturated red or blue on large surfaces**, because the characters wear the team colours (blue yours, red enemies). `bricks_red` is no longer used on the maps (Depot's warehouse is now plaster, Square's brick houses stone); walls, floors and big props are neutral greys plus wood.
- **Neutral shadows:** the maps' environments take their ambient light from a neutral grey colour instead of the blue sky. Depot gets its own `clear_noon.tres` (cool-daylight sky, grey ambient); `clear_morning.tres` and `overcast.tres` switch to grey ambient. The shared `cool_daylight.tres` (test map) is unchanged.
- The rules and measurements are in [MAPS.md](MAPS.md), "Look rules".

**Why:** The characters (another session's work) are told apart by silhouette and team colour, so the maps must not compete with those colours. Measured in screenshots, sky-lit shadows were rgb (43–50, 63–70, 92–100): the blue team's hue (215° vs 220°) at 50 % saturation. A blue player standing in shade would blend in. With grey ambient light shadows measure 3 % saturation at the same brightness, and every map surface measured stays at or below 5 %. The brick averaged a muted brown, but a fifth of its pixels are strong reds that would speckle around red players.

**Alternatives:** Keeping the sky ambient and only dropping the brick (shadows stay blue); changing the shared `cool_daylight.tres` too, so the test map gets neutral shadows (affects every map and the other sessions' screenshots, so it's left for you to decide); retinting the brick texture to grey (one more texture to maintain, and plaster or stone already does the job).

## D-080 — The bomb: CS's rules, planted and defused by holding Use (2026-10-15) — *provisional*

**Decision:**
- **CS's bomb rules.** At each round start a random attacker (seeded) carries the bomb on their back. Holding **Use (E)** inside a bomb site for **3.2 s** plants it; the fuse then runs **40 s** and the bomb beeps faster and faster (every 1 s at the plant, every 0.13 s at the end) until it explodes. A defender holding Use within **1.5 m** of it defuses it in **10 s** (5 s with a kit). Letting go of Use starts a plant or a defuse over. Only one defender defuses at a time. If the carrier dies, the bomb falls to the floor where they fell and the first attacker to walk over it (within 1.2 m) picks it up; defenders can't. All values are in `MatchSettings` (group *Bomb*) and the `Bomb` scene.
- **How a bomb round is won:** the explosion wins it for the attackers, a defuse for the defenders. The plant **stops the round clock** (the timer shows "BOMB", as CS hides the time). After the plant, killing every attacker doesn't end the round (the defenders still have to defuse), and killing every defender wins it for the attackers at once. Before the plant the old rules hold (elimination, and time-out for the defenders). A bomb planted when the round ends anyway keeps ticking through the round-end pause.
- **Planting and defusing lock you in place,** as in CS: you can look around and crouch, but not move, jump or shoot (`Character.busy`, applied inside `Character` like freeze time). Taking damage doesn't interrupt.
- **One rule for everyone:** a new `use` field in `CharacterInput`, held by your E key or set by a bot's brain. The bomb only reads `Character.is_holding_use()`; it never asks who is behind the character. Planting and defusing make a noise bots hear 20 m away (key presses, wire clicks), as CS players hear a plant.
- **The blast** follows CS's bell curve (500 damage at the bomb), scaled down for maps half the size: lethal out to about 13.5 m, 50 damage at 17.7 m, nothing beyond about 22 m. Walls don't shield, as in CS. Nobody gets a kill for it.
- **Where it lives:** `bomb/bomb.tscn` + `bomb.gd` (`Bomb`, authority code). The `RoundManager` adds it when the map has `bomb_sites` areas and `MatchSettings.bomb_rounds` is on (the default), hands it to an attacker at every round start, turns it on for the live round (`Bomb.active`), and ends the round on its `planted` / `exploded` / `defused` signals (new `EndReason.BOMB_EXPLODED` and `BOMB_DEFUSED`). The test map has no sites, so it still plays elimination rounds. The sites are the maps' existing `Area3D`s; the bomb switches their `monitoring` on and asks `overlaps_body()`.
- **The defuse kit is a hook:** `Bomb.kit_check` is a `Callable` that answers whether a defender has a kit; it says no for everyone until the economy (M7) sets it.
- **What you see and hear** (presentation only): the bomb strapped upright to the carrier's back (hidden on your own), a blinking red light and a beep when planted, a short flash and a boom when it explodes. A gold **BOMB** marker shows through walls over a dropped bomb for the attackers (CS shows it on their radar) and over a planted bomb for everyone. The new `BombHud` shows a gold "BOMB" tag above your weapon while you carry it, "Hold E to plant" inside a site, "Hold E to defuse" next to the planted bomb, "Planting" / "Defusing" with a progress bar, and short messages: "You have the bomb", "The bomb was dropped" (attackers), "Bomb planted at A" (everyone). Freeze time says "You attack: plant the bomb at A or B" / "You defend: guard A and B", and the round-end banner "The bomb exploded" / "The bomb was defused". The sounds are generated like the others (`tools/generate_sounds.gd`) and play on the *Effects* bus.

**Why:** CS's numbers are the ones you know (D-041), and the maps were built with two sites at the defenders' end for exactly this (D-060). Holding Use instead of switching to the bomb (slot 5) and holding fire works today, before weapon slots exist (M7), and is what CoD's Search & Destroy does; it also gives bots the same simple rule. Locking movement keeps CS's tension of committing to a plant or a defuse. Stopping the clock at the plant is how CS hands the round over to the fuse. Scaling the blast keeps a site explosion from killing someone in the other spawn on a 56 m map. Keeping the bomb a separate node that the round manager only listens to follows the authority rule: in M9 the host runs it and clients only show it.

**Checked:** a new `tests/bomb_test.tscn` (26 checks) plays short matches on Depot through the real input path: a bomb only on maps with sites (and not with bomb rounds off), an attacker carrying it on their back from the round start, no plant in freeze time or outside a site, the plant locking movement and resetting when Use is let go, a full plant at your feet in site A, the clock stopping with "BOMB" on the timer, the fuse beeping and the blast (dead next to it and at 10 m, untouched at 28 m), the round going to the attackers, drop and pickup (defenders can't), the HUD's tag, prompts, bar and messages, no defuse from 5 m, the defuse lock and reset, the kit hook, a full defuse winning for the defenders, the attackers' deaths not ending a planted round and the defenders' deaths ending it at once, and no defusing once the round is over. All other suites pass unchanged.

**Alternatives:** Planting with the bomb as a weapon (slot 5 + fire, CS's way; waits for weapon slots in M7, and can still be added then); a visible countdown after the plant (CS2 shows none; counting the beeps is part of the skill); CS's full-size blast (would reach across a quick map); an explosion blocked by walls (not how CS works, and it needs rays); defusing only while looking at the bomb (CS requires it, but bots would need to aim at a floor object; may come later); a manual drop key (CS's G, useful to hand the bomb to a teammate; easy to add later); bomb timings as `Bomb` exports instead of match settings (they're rules of a match, which the match setup may want to change).

## D-081 — Bots play the bomb: one target site, retake everything, unstick by jumping (2026-10-15) — *provisional*

**Decision:**
- **Attack:** at each round start `BotTactics` picks one of the two sites at random as the attackers' target. The carrier's group takes the route that ends nearest to it; the other groups take the other routes as before, but once their route is done everyone clears the target site's middle and the hold spots within 15 m of it (instead of the whole defenders' end). The carrier walks its route, then goes to a spot within 1 m of the site's middle and holds Use until planted. With less than 30 s of round time left for walking and planting (`PLANT_RESERVE`), it skips the rest of its route and goes straight there.
- **Dropped bomb:** the attacker bot nearest to it (bots only; you can fetch it yourself) drops everything and picks it up, then becomes the carrier with the same target site. The carrier and the fetcher never go and check noises: they fight what they see, then carry on.
- **After the plant:** each attacker picks a spot 5–10 m from the bomb from which it can see the bomb and watches it, its view drifting ±25°. Every defender retakes: the first at the bomb defuses, the others stop within 7 m and watch away from the bomb, where attackers come from. Once the bomb is down, bots only check enemies seen or heard within 15 m of it.
- **Under fire:** a bot planting or defusing stops to fight an enemy who shows up, unless it is at least 70% done, or (defusing) the fuse wouldn't leave time for another full defuse. Then it keeps holding Use and doesn't shoot.
- **Rotations:** defenders keep D-045's rule (they leave a spot for enemies seen or heard within 35 m, which also brings them to a plant they hear) and all rotate to the bomb once it is planted. No team-wide callouts.
- **Stuck bots** (a fix found while testing): our characters can't step up edges (D-013), so a bot that cuts a corner can end up pressed against the side of a ramp. A bot that tries to walk but stays under 0.6 m/s for 0.5 s jumps, as CS bots do; after 1.2 s it backs off to one side for 0.5 s and asks for a new path. On Depot this had left an attacker standing at the foot of the dock ramp for 100 s, so that round ran out the clock.
- Everything uses the same commands as the player: a bot plants and defuses by setting `CharacterInput.use`.

**Why:** One target site is the simplest plan that makes attackers arrive together, which is what wins sites in CS; random keeps the defenders guessing. Clearing only around the target stops attackers from wandering through the whole end after their routes. Fetching and planting before chasing noises keeps the round about the bomb. Watching the bomb after the plant is the classic post-plant: the defuser has to show himself. Sending every defender to the retake matches what CS teams do once a bomb is down, and covering instead of stacking on the bomb keeps them from walking into each other. The 70% rule is the "stick" call: restarting a nearly finished defuse loses more than it saves. Jumping is how CS bots get unstuck, and it fixes the ramp case without changing the maps or the movement.

**Checked:** 6 new bot checks in `tests/bomb_test.tscn` (32 in all): the carrier plants at its team's target site (B on Depot, 16.9 s into the round) with the defenders out of the way; afterwards all three attackers guard within 5–6 m; a dead carrier's bomb is picked up by another attacker bot; defender bots retake and defuse a planted bomb while two teammates cover; a defender 80% into its defuse keeps going when an enemy steps out in front of it, one at 20% stops and fights. In `tests/maps_test.tscn` the bots planted in 11 of 12 seeded bot rounds (7 defused, 4 decided by elimination after the plant), no round ran out of time, and first contact stayed at 5.4–6.7 s (median per map); a new check requires plants and bomb endings. Bot, tactics and all other suites pass unchanged.

**Alternatives:** A shared team brain that times a site take or a split (the backlog's smarter team AI); attackers clearing the whole defenders' end as before and the carrier planting wherever it ends up; defenders rotating on a callout when one of them spots an attacker at a site (more realistic, but needs team communication and a rule for who goes); never stopping a defuse (bots would die defusing into enemies); bots running away from a bomb they can no longer defuse (CS bots do; small gain); a step-up rule in `Character` (would change how everyone moves, D-013); widening the ramps (map work, and corners elsewhere could still catch a bot).

## D-082 — Team respawn mode: a RoundManager with one long round (2026-10-15) — *provisional; kill limit raised to 50 in D-083*

**Decision:**
- **The rules** (GAME_DESIGN 4.5, D-049): after 5 s of freeze time at the two team ends, one live round of **10 minutes**. Whoever dies comes back **3 s** later with full health and a full rifle. Every kill of an enemy is a point for the killer's team; teamkills, suicides and deaths without a killer score nothing (they still count in the scoreboard's personal stats, as in rounds). The first team to **30 kills** wins; when the time runs out the team with more kills wins; a tie goes to **overtime**: the clock shows "OT" and the next kill wins. After the deciding kill the round-end pause (5 s) plays with "Your team wins" / "The enemy team wins" and the reason ("First to 30 kills", "Most kills when time ran out"), then the match ends and the usual end screen opens.
- **Respawn points:** the map's `respawn_points` (12 per quick map, in four zones; both teams' spawns on maps without them). A spot counts as taken within 2 m of someone alive. Each free spot gets a score: the distance to the nearest living enemy (up to 40 m; farther counts as 40, so far spots take turns), minus 40 if a living enemy within 45 m has a clear line to the head or chest of someone standing there (walls only, whichever way the enemy looks), plus 4 if a teammate is within 15 m, plus up to 3 at random (seeded). The best spot wins. CoD's own rules are similar: away from enemies, out of their sight, near teammates.
- **Built as `RespawnMatch extends RoundManager`** (`systems/respawn_match.gd`). It's a round match with one round, so the HUD, kill feed, scoreboard, match-end screen and "Play again" work as they are; `score` holds kills instead of rounds won. `RoundManager` got small hooks the subclass replaces (`_plan_bots`, `_round_duration`, `_live_tick`, `_clock_stopped`, `_on_time_up`, `_score_kill`, `_score_round`, `_add_bomb`, `_check_elimination`, `_after_round_end`) and `is_team_respawn()` for the few texts that change. New `EndReason.KILL_LIMIT` and `TIME_LIMIT`. Respawns are counted in physics ticks, like every other timer of the match.
- **Choosing the mode:** `MatchSettings.game_mode` (`ROUNDS` or `TEAM_RESPAWN`), with `kill_limit`, `time_limit` and `respawn_delay` in a new group *Team respawn*. `main.gd` adds a `RespawnMatch` instead of a `RoundManager` when the settings say so, turns spectating off and shows "Respawning..." under the death message, as in practice. From the terminal: `-- --respawn`. The match setup (M5) can offer it as a choice; the rotation task does that when M5's menus are merged.
- **What changes on screen:** the top bar's scores are kills, "First to 30" replaces "Round 1" under the timer ("Next kill wins" in overtime), the freeze time says "Team respawn · starts in 4" and "First team to 30 kills wins", the Tab scoreboard's header "First to 30 kills". No bomb. Bots roam like in practice until task 4 makes them hunt.
- **Practice stays** as it is (`ArenaRules`): no teams' score, no limits, for warm-ups.

**Why:** A subclass reuses everything a match already has (teams, stats, kill feed, scoreboard, end screen, the authority rule) and changes only the flow, so the HUD and menus need a handful of text changes instead of a second set of screens. Hooks keep the round manager readable: each one is one decision a mode makes. 30 kills at 3v3 is about the same pace per player as CoD's 75 at 6v6. Overtime avoids a draw, which the end screen has no way to show (Victory or Defeat). Scoring only enemy kills keeps a teamkill from helping anyone. Spawns away from enemies and out of their sight stop spawn kills on 50 m maps, where every spawn is close to the action.

**Checked:** a new `tests/respawn_test.tscn` (15 checks) on Depot with short rules (5 kills, 20 s, 1 s respawn): the start at both team ends with no bomb, the freeze text, the clock, a kill scoring for the killer's team and shown in the top bar, a death without an enemy killer scoring nothing, coming back after the delay at a respawn point with full health, the scoreboard stats, the respawn choice (35 m or more from the enemies and out of their sight, wherever they stand) and skipping an occupied spot, the kill limit with its banner and the match end after the pause, the time limit with a leader, overtime (OT, still live, the next kill wins), and the main scene picking the mode from the settings with spectating off. Writing the test found the round's own point being added on top of the kills (6 instead of 5), now a hook. All other suites pass unchanged.

**Alternatives:** A separate rules node beside `RoundManager` (the HUD, scoreboard and end screen would need a second code path or an interface); extending `ArenaRules` (practice has no teams' score, phases or end); a draw on a tie (CoD's TDM can end in a draw; our end screen can't show one); spawning near teammates first (CoD's buddy spawns; with 3 players a side it often puts you next to the fight your teammate is losing); a respawn wave every few seconds (Battlefield-style; slower); choosing respawn points from the navmesh instead of markers (no map work, but no control over where people appear).

## D-083 — Bots in the respawn mode hunt in pairs; the kill limit is 50 (2026-10-15) — *provisional*

**Decision:**
- **Groups:** at the start of a team respawn match `BotTactics.plan_hunt()` puts each team's bots in groups of about two (3 bots: a pair and a single; 5: two pairs and a single), like the attack groups. The groups and the team's shared knowledge live in a `HuntPlan` per team (`bots/hunt_plan.gd`), which the `RespawnMatch` keeps and hands back to every bot that respawns. You aren't in a group.
- **Leader:** the group member alive the longest leads (so a partner who survived keeps leading when the other comes back). It runs to the team's freshest enemy sighting if it is within **25 m**; otherwise it roams the map's patrol points: a random one at least 12 m away and away from the other groups' goals, looking left and right for 1.2 s at each. While its partner is more than 6 m behind, it walks.
- **Follower:** runs to a spot 2.5 m behind and 1.2 m to one side of the leader, and looks 50° off the leader's view to that side, so the pair covers two directions. Farther than 18 m (after respawning) it runs straight to the leader. In practice it trails about 6 m behind: they run equally fast, and the leader only waits beyond 6 m.
- **Sharing:** every hunting bot reports what it sees and hears to the team plan (a callout); sightings older than 6 s are dropped. A bot itself only goes to check enemies it saw or heard within 25 m, like the sightings it answers.
- **Kill limit 50** instead of 30 (D-082). Bots-only 3v3 matches score 18–26 kills a minute in all, so 30 kills ended them in about 2.5 minutes; 50 takes about 4 minutes.

**Why:** Pairs are what "small groups" means at 3 a side, and a leader with a follower is the simplest way to move together without a team brain. Letting the longest-living member lead keeps a pair near the fight instead of pulling the survivor back to someone who just respawned. Answering only nearby sightings and only checking nearby noises came out of measuring where the kills happened: when every bot ran to every sighting and gunshot (gunshots carry across the whole map), 80–90% of the kills on every map happened in the middle third; with the 25 m reach Spillway's spread over 7 of 9 thirds of thirds and Square's over 7, while Depot's warehouse mid still sees most of them (77%), which looks like that map's shape. Walking while a partner catches up is quiet, so it also reads as the pair sneaking. The kill limit follows the measured pace; a human player may be slower, so it's in your playtest list.

**Checked:** 4 new checks in `tests/respawn_test.tscn` (19 in all): every bot hunts, in groups of a pair and a single per team; with nobody to fight, a follower stays within about 6 m of its roaming leader (median 5.9 m, never past 12 m, while the leader covers 31 m); a sighting 12 m from a pair is answered by it but not by the single 38 m away; the pair runs to it. `tests/maps_test.tscn` now also plays a bots-only respawn match to 20 kills on every map: 84–124 s (18–25 kills a minute), and no ninth of the map has 90% of the kills. All other suites pass unchanged.

**Alternatives:** Every bot hunting alone (simpler, but no groups); a shared team brain sending groups to lanes; the whole team chasing every sighting (tested: everyone piles into mid); followers matching the leader's speed exactly (needs a speed between walking and running, which characters don't have); a higher respawn delay instead of a higher kill limit (slows the action the mode is for).

## D-084 — The sound pass: surfaces from the map's texture data, generated sounds (2026-10-15) — *provisional*

**Decision:**
- **Footsteps on four surfaces:** hard (concrete, stone, plaster, brick: today's footstep), **gravel** (a gritty crunch), **metal** (a heel strike with a short ring) and **wood** (a hollow knock). Three variants each, picked at random with a little pitch and volume variation, like the hard ones. Range, loudness and who hears them are unchanged (D-038); only the timbre tells you the floor. Walking stays silent.
- **How the floor is known:** TrenchBroom maps are now built with **Chiip's own copy of the worldspawn class** (`maps/fgd/chiip_worldspawn.tres`, in `maps/fgd/chiip_fgd.tres`, set in `maps/chiip_map_settings.tres`), which turns on three of func_godot's metadata options: each face's texture, each face's normal, and which faces belong to which brush. A step casts a short ray down; the brush it hits and the face of that brush pointing up name the texture, and `Surfaces` (`systems/surfaces.gd`) turns the texture name into a kind (`gravel_grey` → gravel, `metal_plates` → metal, `wood_planks` → wood, anything else hard). Lookups are cached per brush. The three quick maps were rebuilt; their geometry and navmeshes are unchanged. Maps without the data (the CSG test map) are all hard.
- **Bullets:** every hit plays a sound at the impact, for everyone within 35 m: the surface's impact (a sharp crack on hard surfaces, a dull thud in gravel, a ricochet ping on metal, a thock in wood), a fleshy thwack on a body, and on a head a bright, crunchy "dink" 6 dB louder that carries twice as far, like CS's headshot sound. A weapon without a shot sound (the tests' silent weapons) makes no impact sounds.
- **The bomb's sounds** came with the bomb (D-080): the beep, the plant key presses, the defuse clicks, the explosion. New here: a two-tone **"bomb planted" alert** everyone hears.
- **Interface:** a soft tick when the mouse moves onto a menu button (−12 dB) and a click when it's pressed (`UiSounds.attach(menu)`, used on the match-end screen; M5's menus can call it too), a two-beep **"go"** when a round goes live, and a short rising stinger for a round you won and a falling one for a round you lost. They play without position on the *Interface* bus; game sounds use *Effects* (M5's bus layout; without it they fall back to Master). Interface sounds are off in headless runs.
- **Generated, no downloads** (D-020): 24 new sounds from `tools/generate_sounds.gd` (written by a Sonnet subagent from a sound-by-sound brief). New sounds are appended, so the existing ones stay byte-identical. The weapon's shot, reload and empty click are unchanged: you approved them in M2 and M4. Distant gunshots are already muffled by Godot's distance filter on 3D sounds.
- Measured (share of energy below 1 kHz / 1–6 kHz / above 6 kHz): gravel steps 16–19 / 51–56 / 28–31 %, metal steps 16 / 80–81 / 3–4 %, wood steps 68–74 / 23–29 / 3 % (duller, as wood is), the old hard step 35 / 34 / 32 %; the headshot "dink" centres around 3 kHz, the body hit around 0.8 kHz.

**Why:** In CS the floor under a footstep is information (who is on the catwalk, who is in the gravel), and our maps already have distinct materials per area, so the sound should say it. Reading the texture from func_godot's own build data needs no extra map work and stays right when you edit maps in TrenchBroom; a copy of the worldspawn class keeps the addon untouched. Impact and headshot sounds are the other half of CS's audio feedback: you hear a headshot land. Interface sounds and stingers make rounds start and end with a clear cue. Everything generated keeps the retro, consistent sound of the rest and needs no download approvals.

**Checked:** a new `tests/sound_test.tscn` (8 checks) on Depot: gravel in the spawn yard, hard on the dock, metal on a metal roof and wood on a crate (found from the map's own data), hard without a floor; each surface's footsteps and impact sound; the real rifle's bullets sounding like gravel, a body and a head, the headshot louder and carrying farther; a silent weapon making no impact sounds; menu buttons wired once; interface sounds off without a window. All other suites pass unchanged. Not checked by ear: you are the judge (playtest list).

**Alternatives:** Marking floors with trigger areas per surface (map work for every change); one footstep for every floor (less information); per-weapon impact sounds (one rifle so far); CoD-style hit markers and kill sounds for the shooter (not CS's feel; could be a setting later); downloading a CC0 sound pack (better realism, but downloads need approval and wouldn't match the retro sound); changing the approved gunshot.

## D-085 — Lighting stays real-time; no lightmaps, no SSAO or SDFGI (2026-10-15) — *provisional*

**Decision:** The maps keep today's real-time lighting: the sun (`DirectionalLight3D` with shadows), the warm lamps (`OmniLight3D`) and the neutral grey ambient light of D-063. No baked lightmaps, and none of Godot's real-time extras (screen-space ambient occlusion, SDFGI bounce light). The comparison tools stay: `tools/map_screenshots.gd --lighting ssao|sdfgi` and the new `tools/frame_timing.gd`.

**Compared** on Depot through the real game at 480 lines (picture: [maps/lighting_depot.jpg](maps/lighting_depot.jpg); left today's lighting, middle with SSAO, right with SSAO and SDFGI; rows site A, the warehouse, site B):
- **SSAO** darkens the foot of crates and the corners a little; at 480 lines with the palette effect it's barely visible.
- **SDFGI** adds bounce light (warm lamp light on the warehouse floor) but also brings the sky's blue back into the shadows, which D-063 removed so a blue player in the shade stays visible, and makes the warehouse interior much darker. Both work against the clarity rule.
- **Baked lightmaps** would give the same kind of bounce light and soft corners as SDFGI, for free at run time, but: every TrenchBroom edit needs a re-bake by hand in the editor (it can't be scripted: `LightmapGI`'s bake is editor-only), the baked files are large, characters would need light probes to match the baked light, and a bake picks up the blue sky light unless its environment is set by hand. The maps are blockouts that will still change after your playtest.
- **Frame times:** the game holds the display rate in every variant (Depot, 3v3, world 960 × 540 in a 1080p window). macOS enforces V-Sync and Metal doesn't report GPU timestamps here, so the cost difference couldn't be measured more precisely than "within the noise" (slowest 1% of frames 18–23 ms in all three when the window ran at 60 Hz).

**Why:** The look is a 90s shooter with flat, readable light; what extra lighting adds is hard to see at 480 lines and either hurts the clarity rule (SDFGI's blue shadows and dark interiors) or the map workflow (baking after every edit). Real-time lighting keeps the maps editable in TrenchBroom with one build command.

**Alternatives:** Baking once the maps are final (the README keeps the steps; reconsider in a detail pass, with a grey custom environment for the bake); SSAO as an option in the video settings (cheap, small effect); SDFGI with a grey sky for the bounce (fixes the tint, keeps the dark interiors and the cost); `VoxelGI` per map (another bake step).

## D-086 — The first macOS build: universal, ad-hoc signed, tests and tools left out (2026-10-15) — *provisional*

**Decision:**
- **Export preset "macOS"** in `export_presets.cfg` (checked in): a **universal** app (Apple Silicon and Intel), bundle id `org.chiip.game`, version 0.8.0, exported to `builds/macos/Chiip.app` (gitignored; `builds/.gdignore` keeps Godot from importing it). `tests/` and `tools/` are left out. Built with `Godot --headless --path . --export-release "macOS" builds/macos/Chiip.app` (README, "Exporting the game").
- **Ad-hoc signed, not notarized:** Godot's built-in signing with no identity. Apple Silicon Macs only run signed code, and an ad-hoc signature is enough for an app built on this Mac. On another Mac it would need right-click → Open (or a Developer ID and notarization, which need a paid Apple account).
- **ETC2/ASTC texture compression switched on** (`rendering/textures/vram_compression/import_etc2_astc`): Godot refuses to export for Apple Silicon without it. Our pixel textures aren't VRAM-compressed, so nothing visible changes.
- **The export templates** (1.28 GB, official, checksum verified, CREDITS.md) are installed in the user's Godot folder, outside the project.
- **Two fixes the export found:** the TrenchBroom comparison room still pointed its player at `player/player.gd`, a script renamed in M4, so that map had been broken since then; it now uses the player scene's own script. And the console's `map` list read `res://maps/` with `DirAccess`, which in an exported game only sees `depot.tscn.remap` (scenes are stored converted); it now uses `ResourceLoader.list_directory()`.
- **Performance** (`tools/frame_timing.gd`, Apple M5, 1080p window, world 960 × 540): 5v5 on Depot (rounds), Square (team respawn) and Spillway (rounds) all hold the display rate (the window ran at 60 Hz with the editor open next to it), slowest 1% of frames 19–22 ms, about 2 ms of physics per frame for 10 bots and 0.2 ms of CPU to prepare the world's rendering, 157–187 draw calls. macOS keeps V-Sync on and Metal reports no GPU timings, so there's no "frames to spare" number; M3 measured 120 fps on this machine with the display at 120 Hz.

**Why:** A universal build runs on any recent Mac at the cost of a bigger download (165 MB); arm64-only would halve it but shut out Intel Macs. Ad-hoc signing is the minimum that runs on Apple Silicon without an Apple account. Leaving tests and tools out keeps developer scripts out of the game. Putting builds in an ignored folder of the project keeps one place for them.

**Checked:** the exported app ran headless with no errors on Depot (rounds), Square (team respawn) and the TrenchBroom comparison room, and in a window it started on Metal (Apple M5, Forward+) and quit cleanly. `codesign` shows an ad-hoc signature. All test suites pass.

**Alternatives:** arm64 only (smaller, Apple Silicon only); a `.dmg` or `.zip` (for sharing; the `.app` is enough for testing here); no signing (won't launch on Apple Silicon); Developer ID signing and notarization (later, with an Apple developer account, before sharing builds); exporting everything including tests (harmless but bigger and untidy).

## D-058 — Settings: a plain class saved to `user://settings.cfg`, applied the moment they change (2026-10-15)

**Decision:**
- **`Settings` (`systems/settings.gd`) is a plain class with one shared instance** (`Settings.get_instance()`), not an autoload: the same pattern as `Noises` and `Teams`, because autoloads don't exist in `--script` runs (tools, checks) and anything that loads the player would break. It starts at the **defaults**, which equal what the game did before settings existed. Nothing touches the disk until the game calls `load_from_disk()` (`main.gd` at startup now, the main menu in task 11). That call also starts the saving: from then on every change is written to the file it loaded. So tests, tools and a fresh instance always run on defaults and never write the player's file.
- **The file** is a `ConfigFile` (Godot's text format, like an INI file) at `user://settings.cfg`, which on macOS is `~/Library/Application Support/Godot/app_userdata/Chiip/settings.cfg`. Sections `[game]` (sensitivity, invert_y, fov), `[video]` (fullscreen, vsync, fps_cap, pixel_height, palette_effect, pixelate_hud), `[audio]` (master, effects, interface volume), `[crosshair]` (color, length, gap, thickness, outline, dot, dynamic) and `[controls]` (one line per action). **Saved on every change**, all values every time, so the file lists every key that exists. **Reading is forgiving:** a missing file or key keeps the default, unknown keys are ignored, numbers outside their range are clamped (a sensitivity of 999 becomes 10), a value of the wrong type falls back to the default, and a file that can't be parsed at all leaves everything on defaults (the next change rewrites it).
- **Applied the moment something changes.** Each setting is a typed property whose setter (through `set_value(key, value)`) clamps the value, applies it, emits `changed(key: StringName)` and saves. Whatever uses a value listens and applies it, connecting in `_ready` (a freed node's connections end by themselves): `PlayerController` (sensitivity, Y inversion, field of view), `Crosshair` (the whole style), `main.gd` (pixel height, pixelated HUD, palette effect, through the existing `apply_pixel_settings()`). `Settings` itself applies what reaches the engine: fullscreen and V-Sync (`DisplayServer`, skipped in headless runs and only when the window isn't in that state already), the frame limit (`Engine.max_fps`), the bus volumes and the key bindings (`InputMap`). Only the shared instance does that (`applies_to_engine`); a `Settings.new()` just holds values, which is what the save and load tests use. `Main.pixel_height`, `pixelate_hud` and `palette_effect` are gone: the settings are the one place.
- **Values** (defaults are today's): sensitivity 1.0 on CS's scale (0.05 to 10, D-016); `fov` 90 (70 to 110); pixel height 480 (snaps to 270, 360, 480, 540 or 720, D-048); palette effect on (D-030); pixelated HUD off (D-027); V-Sync on; fullscreen off; frame limit 0 = unlimited (otherwise 30 to 1000; the menu will offer 60, 120, 144 and 240); volumes 1.0 (0 to 1); crosshair green, 7 px lines, 4 px gap, 2 px thick, outlined, no dot, static (D-021).
- **Field of view the way CS says it:** `fov` is the **horizontal angle across a 4:3 screen**, 90 by default, and `Settings.vertical_fov()` turns it into Godot's camera value (`Camera3D.fov` is vertical): 90 gives 73.74°, exactly what the camera had, so the default changes nothing. On a wider window the vertical angle stays and the sides show more, as in CS. The player's camera is set from it; the crosshair's dynamic gap already reads `camera.fov`.
- **Audio buses.** `default_bus_layout.tres` (the file Godot loads at startup) has **Master, Effects and Interface**, the last two sending to Master, all at 0 dB and none muted: it must never ship muted, and `settings_test` checks it. The volumes are 0 to 1 and become `linear_to_db()` on the bus (so 0.5 is −6 dB); 0 mutes the bus. Every game sound (footsteps and the rifle's shot, dry fire and reload, 2D and 3D) plays on **Effects**; **Interface** is for the menus and nothing uses it yet.
- **Key bindings.** The 13 gameplay actions (move, jump, crouch, walk, shoot, aim, reload, scoreboard, `toggle_debug`, `toggle_console`) can be rebound, each with two slots (primary and secondary: jump has Space and mouse wheel down). Esc (`toggle_mouse`) is fixed. A binding is a key by *physical position* (D-012) or a mouse button, written as `"key:87"` (Godot's physical keycode) or `"mouse:5"` (the button index), an empty text for an empty slot, e.g. `jump=["key:32", "mouse:5"]`. They are applied to the `InputMap` with `device = -1`, and the project's own bindings are read once at startup so `reset_bindings()` can restore them. The API for the settings menu: `get_binding()`, `set_binding()`, `clear_binding()`, `find_action_using()` (a clash), `reset_binding()`, `reset_bindings()`, `binding_text()`.
- **Settings are local:** a player's own preferences on their own computer, never game rules, so M9's host doesn't send or check them (ARCHITECTURE, "Keeping multiplayer possible").
- **Console commands** to try it before the menu exists: `sensitivity`, `fov`, `volume` (master), `fps_max`, each showing the value without an argument, and `settings_reset`.

**Why:** A settings class is the thing every menu, the HUD and the player controller must agree on, and "saved the moment it changes, applied the moment it changes" means the menu needs no Apply button and a crash loses nothing. A plain class with a static instance keeps tools and tests working (the same reason as `Noises`) and makes "tests never touch the real file" simple: saving only starts when the game asks. `ConfigFile` is Godot's built-in way to keep settings, a text file a player can read and fix by hand, which is why reading is forgiving. CS players think of FOV as 90 across 4:3 and of sensitivity on CS's scale, so the numbers carry over from CS. Two slots per action cover the existing jump binding and CS's habit of a second key. The buses let the player turn the menu or the effects down separately from the master, which a tactical shooter wants (footsteps matter).

**Checked:** the new `settings_test` (63 checks): the defaults against today's values, the project's key bindings and the bus layout; clamping, snapping and wrong types; `changed` once per change; the player controller (100 counts turn exactly 2.200° at sensitivity 1 and 4.400° at 2, Y inversion, the camera at 73.74° and at 100°), the crosshair (every property, also scaled), the bus volumes in dB and muting, `Engine.max_fps`, rebinding (the InputMap, device −1, a real key press, clashes, reset); saving and loading into a second instance (all values and keys), a hand-edited file and an unparseable one, reset; main.gd's pixel settings and the console commands in the real main scene; that freed nodes drop their connections and that the real `settings.cfg` is never touched. A mutation run (12 changes: no FOV, no frame limit, a crosshair part ignored, a sound off the bus, no clamping, a wrong device, bindings not saved, a changed default, reset forgetting the keys, volume without dB...) fails at least one check each. A real run of the main scene: values changed through the console were written to `settings.cfg` and a second run loaded them into the player, `Engine.max_fps` and the camera. The six old suites pass unchanged.

**Alternatives:** An autoload node (breaks `--script` tools and tests, the same reason `Noises` and `Teams` are plain classes); Godot's `ProjectSettings` with `override.cfg` (meant for developers, not per-player files); JSON or a `Resource` saved to `user://` (`ConfigFile` is smaller, human-readable and forgiving for exactly this); writing only the values that differ from the default (a changed default in a later version would then reach players, but the file would hide which keys exist, and the old defaults, like 360 lines before D-048, would stay with players who saved anything); an Apply button or a restart (the settings menu would need state for pending changes, and nothing here is expensive to apply); saving only when the menu closes (a crash or a kill loses changes); the vertical field of view as the setting (nobody can compare it with CS); one binding per action (jump already has two); bindings stored as key names (`OS.get_keycode_string` names don't round-trip for every key and depend on the language); `Settings` applying the pixel settings itself (it would need to reach into the main scene's nodes; `main.gd` already owns them).

## D-059 — The settings menu: one reusable scene, a key belongs to one action, a shared "a menu is open" (2026-10-15)

**Decision:**
- **One reusable scene,** `ui/settings_menu.tscn` + `settings_menu.gd` (`SettingsMenu`, a `CanvasLayer` on layer 6: above the match-end screen, below the console). It is hidden until `open()` and emits `closed` when the player leaves it (Back or Esc). `main.tscn` holds one instance (`Main.open_settings()`); the main menu (task 11) and the pause menu (task 12) open the same scene. For now the console command `settings` does, and closes the console. The frame, the tab container and the crosshair preview are in the scene; the controls are built in code from one short table of rows per tab, so a setting is one line.
- **Layout.** A 960 × 660 panel at 720p (scaled by `UiTheme.apply()` like the other menus) with a `TabContainer`: **Game** (sensitivity slider plus an exact number field with 2 decimals, invert Y, field of view), **Video** (fullscreen, V-Sync, frame limit and pixel resolution as option buttons, palette effect, pixelated HUD), **Audio** (three percentage sliders), **Crosshair** (color swatches and a `#RRGGBB` field, opacity, size, gap, thickness, outline, dot, dynamic, and the preview on the right), **Controls** (a scrolling list, one row per bindable action). Below the tabs: "Reset tab to defaults" and "Back". Only theme variations (`ModalPanel`, `TitleLabel`, `ContentBox`, `FormRow`, `HeaderLabel`, `DimLabel`, `InsetPanel`...), no colors, sizes or styleboxes of its own.
- **No Apply button.** Each control writes to `Settings` the moment it changes (a slider while it is dragged), and the menu follows `Settings.changed`, so a console command or a reset updates the open menu. Opening it reads every value again. A number field takes what is typed on Enter or when it loses the focus (a comma counts as a decimal point; text that is no number puts the old value back); whole-number fields round.
- **Per-tab reset, no confirmation.** "Reset tab to defaults" puts the settings of the tab you are on back to their defaults (on Controls: every key). Smaller than a "reset everything" and safe without asking; the console's `settings_reset` still resets everything.
- **Crosshair preview:** a real `Crosshair` control (the same class the HUD uses, so it can't drift from the game) on a sample that is dark on one half and light on the other, with the crosshair on the boundary, so color, opacity and outline can be judged on both. It reads the settings itself. In dynamic mode the menu makes its gap open and close slowly (the preview has no camera, so `Crosshair.fallback_fov` gives it a field of view to turn degrees into pixels).
- **Rebinding.** Clicking a slot calls `start_listening()`: it shows "Press a key…" and the next key press or mouse button press (the wheel included) becomes the binding. **Esc cancels** (it is the one fixed key) and **Backspace clears** the slot (CS's habit; so Backspace itself can't be bound). The click that started the waiting can't become the binding: a button reports `pressed` on release, so its press and release are over before the waiting begins, and a mouse press in the very frame the waiting started is ignored as well. Slots show the nicer names from `Settings.binding_text()` ("`", "Num 1", "Left Mouse", "Wheel Down"), "—" when empty.
- **The clash rule: a key or button belongs to one action, and the later bind wins** (CS's `bind` works that way). Binding W to the scoreboard takes W away from "Move forward": its slot shows "—", and a line under the list says "Scoreboard (hold): W. Move forward no longer has it." Binding a key to the other slot of the same action moves it. The rule is `Settings.bind_exclusive(action, event, slot)` (with `can_bind()`), which clears the old owners first and then binds, saved once, so the `InputMap` never has the key twice. An action left without keys stays that way (CS allows it); "Reset tab to defaults" is how to get them back.
- **`MenuState` (`ui/menu_state.gd`): the one place that says a menu is open.** A static class with a static list of open menus, like `Settings` and `Teams` (no node, no autoload): `open(menu)`, `close(menu)`, `is_any_open()`, `is_open(menu)`, `is_top(menu)`, `blocks_gameplay()`, `reset()` and `capturing_input`. The settings menu and the developer console register (the console keeps its `DevConsole.is_open` flag too, and `blocks_gameplay()` counts either). While any is open: `PlayerController` ignores keys, buttons and mouse look and gives a neutral command (it also forgets a jump or reload queued just before, and a fire button still held when the last menu closes stays blocked until it is let go, as the click that recaptures the mouse is); the hold-Tab scoreboard stays hidden; the mouse is visible. **The first menu to open shows the mouse and the last to close captures it again**, so the main menu (task 11) just registers too: closing settings on top of it leaves the mouse free, and it is captured when the main menu closes to start a game. **Only the menu on top (`is_top`) reacts to Esc**, so with the console over the menu Esc closes the console first. **`capturing_input`** is true while a slot waits for a key: the console key and Esc don't react then (the console checks it, the settings menu uses the key). A menu removed while open lets go by itself (`_exit_tree`, and dead entries are dropped).
- **The console.** New command `settings`. `help` listed 14 commands in exactly the 14 lines the console kept; with 15 it would lose its first line. The console now shows 16 lines (`VISIBLE_LINES`, the panel is as tall as they need) and keeps 200 (`HISTORY_LINES`): the mouse wheel and Page Up / Page Down scroll back and a new line jumps to the end, so a longer `help` later is scrolled, not lost.

**Why:** The pause and main menus have to open the same settings, so it is a scene that owns nothing about who opens it. Writing to `Settings` on every change matches D-058 (applied and saved at once, nothing to confirm or lose). The preview being the real `Crosshair` means the menu shows exactly what the game draws. "One key, one action" is how CS players expect rebinding to behave, it keeps the `InputMap` free of keys that do two things at once, and telling the player which action lost the key avoids a silent surprise. Putting the rule in `Settings` keeps it with the data (and gives a future `bind` console command the same behavior). `MenuState` is the smallest thing that serves three needs at once (the player must stop, the mouse must come and go, a menu must know whether it is on top), with several menus stacking (main menu → settings, console over a menu) which a single boolean like `DevConsole.is_open` can't do. Static, like `Settings`, so tests and tools can use it without autoloads. The console's scrollback is cheap (a label that shows a window of its lines) and removes the "exactly fills the panel" trap.

**Checked:** `ui_test` grew from 35 to 78 checks (see DEVLOG): the state list, every setting and every key having a control, controls writing to `Settings` and following it (also the console command), the preview, rebinding with a simulated key and mouse press through the real input path (listening, Esc, the starting click, the clash rule, Backspace, the console key, reset), closing, the player ignoring input while a menu is open, the scoreboard, scaling by 1.5 (a 1440 × 990 panel, no tab making it wider), the `settings` command, `help` and the scrollback, and the real settings file untouched. A mutation run (33 changes) fails at least one check each. Also run in a real window at 1280 × 720 and 1920 × 1080 (screenshots of all five tabs): the mouse is visible while the menu is open and captured after Esc, a real click on a slot starts the waiting and the next click binds, with the console over the menu Esc closes the console first. The other six suites pass unchanged.

**Alternatives:** A `SpinBox` for the exact number (the theme doesn't style it, its arrows come from Godot's default theme and don't scale, so a themed `LineEdit` that parses its text did the job); a "Reset everything" button with a confirmation (a dialog `Window` isn't themed, and a two-click confirmation needs a timer; per-tab reset is smaller and safe, and `settings_reset` exists); a full RGB picker (`ColorPickerButton`'s popup isn't themed or scaled; swatches, a hex field and an opacity slider cover what CS offers); a "this key is already used, replace?" prompt on a clash (CS doesn't ask and it would need a dialog); refusing a key that is taken (annoying, you would have to clear the other action first); unbinding the same key only in other actions and leaving two slots of one action equal (pointless duplicates); the console and the menus each tracking "is open" by themselves (the player controller would need to know every one, and stacking would be guesswork); making `MenuState` a node or an autoload (tests and tools couldn't use it); a signal-based pause of the whole game (that is the pause menu's job, task 12; this menu is an overlay); a taller console without scrollback (it just grows again with the next command); rebinding by reading `Input` each frame instead of `_input` (the key would also reach the game and the console).

## D-064 — The main menu is the main scene; a static launch description hands the match to the game (2026-10-15)

**Decision:**
- **Two scenes, one flow: main menu → game → main menu.** `ui/main_menu.tscn` (`MainMenu`) is now the project's main scene (`run/main_scene`); `main.tscn` stays the game. Start and Practice call `change_scene_to_file("res://main.tscn")`, and the match-end screen's **Main menu** button (it was Quit) and the new console command **`disconnect`** (CS's name) call `Main.return_to_menu()`, which changes back. The menu registers with `MenuState` (the mouse is visible) and Esc belongs to whichever panel is on top: it closes match setup or the settings menu; on the main page it does nothing.
- **The hand-over is `GameLaunch`** (`systems/game_launch.gd`): a static class with `map_path`, `practice` and `match_settings`. The menu fills it (`start_match(map, rules)` or `start_practice(map, difficulty)`), changes the scene, and `main.gd` reads it once in `_ready()` (`is_pending()`, then `clear()`). When nothing is pending, `main.gd` behaves as before: its exports and the command line. A scene change frees the menu, so the description has to live outside its nodes; static variables survive the change, like `Settings`, `Teams` and `MenuState`.
- **The command line still starts the game directly:** `-- --match` (new), `-- --practice` and `-- --map <scene>` make the menu change to the game at once, the first time only (a static flag), so a game started that way and left for the menu shows the menu. `main.gd` ignores the command line when the menu left a description, so a later Play isn't overridden by a `--map` from the first start. The shortcuts use `MatchSettings`' own defaults (3v3, Normal, first to 5), not the stored match setup, so smoke runs and tests stay the same whatever the player chose last.
- **The background is the test map, rendered like the game and without its player.** `MainMenu` has the same `SubViewport` + palette-effect setup as `main.tscn`; the pixel settings are applied by one shared function, `PixelView.apply()` (moved out of `main.gd`, which uses it too), so the window scaling, the video settings and the UI scale agree in both scenes. The map's `Player` node is removed *before* the map enters the tree: no camera, no mouse capture, no controller; no rules node is added, so no bots. The map is the unchanged `maps/test_map.tscn` and the map conventions (the `Player` node, the spawn and tactics groups) are untouched.
- **The flight is `MenuFlight`:** a closed `Path3D` built from 11 waypoints (a smooth Catmull-Rom curve, no corners), a `PathFollow3D` moving at a constant speed (80 s a lap, about 3.5 m/s), and a `Camera3D` that each frame looks 24 m ahead along the path and 1.2 m above the floor, turned 48° toward the inside of the loop plus a ±30° sway every 26 s. The camera stays 4 to 6 m up, above the peek walls and the tunnel, and at most 19° a second of turning (checked). Waypoints, speed and angles are exports.
- **Match setup** (`ui/match_setup.tscn`, `MatchSetup`): your team and the enemy team 1–5 (you included, 3v3 by default), bot difficulty Easy / Normal / Hard (Normal), match length first to 5 / 10 / 15 (5), friendly fire Off / On (Off) and a map (every `.tscn` directly in `res://maps/`, like the console's `map` command; today the test map, and the maps session's maps appear by themselves), with a summary line, Back and Start. The rows are segmented toggle buttons, so every option is visible and one click picks it. Practice uses the test map and the difficulty last chosen here.
- **The last choices are remembered** in `Settings`: a new `[match]` section (`team_size`, `enemy_team_size`, `difficulty` as "easy" / "normal" / "hard", `rounds_to_win`, `friendly_fire`, `map`), clamped and defaulted like every other setting (a team of 9 becomes 5, 12 rounds snaps to 10, an unknown difficulty becomes Normal). Settings gained text settings (an optional list of `choices`) for it. Every control writes to `Settings` at once, like the settings menu; the panel follows `Settings.changed`. `settings_reset` in the console now resets the match setup too.
- **The settings are loaded once:** whichever scene starts first loads them (`Settings.is_loaded()` says whether it already has), so the menu does at a normal start and `main.gd` when the game is started directly.
- **The console's `help` grew to 16 commands,** so `DevConsole.VISIBLE_LINES` went from 16 to 17 (the panel is as tall as the lines need).

**Why:** Two scenes keep the game scene free of menu state: leaving a match frees the round manager, the bots and the HUD at once, and the menu has no player to keep quiet. It also fits M9, where a menu will connect or host before a match starts. A static launch description is the smallest thing that survives `change_scene_to_file()` and is easy to test (set it, build the game scene, look at the `RoundManager`). It matches how the project already shares state (`Settings`, `Teams`, `MenuState`). Removing the `Player` before the map enters the tree is the only way to be sure nothing of it runs: a removed node would already have been `_ready()`. A flight along a path that looks ahead can only turn as fast as the path bends, so it is calm by construction. Remembering the last setup is what a CS player expects (the same server settings next time), and putting it in `Settings` reuses saving, clamping and the "tests never touch the real file" rule.

**Checked:** `ui_test` grew from 78 to 111 checks: the menu's buttons and title, the background without a player, character, controller or rules, the camera flight (an 80 s closed loop, at most 3.6 m/s and 19°/s, 4 to 6 m up, inside the walls), the video settings and the 1.5× scaling, Esc on the page and in each panel, `--match` / `--practice` / `--map` detection, match setup on its own `Settings.new()` (the defaults equal `MatchSettings`' own, each control gives the matching `MatchSettings`, the choices are stored and survive a save and load, the map list equals `res://maps/*.tscn`), `GameLaunch` and `main.gd` (a match description builds a `RoundManager` with exactly those settings, practice builds `ArenaRules` with the difficulty, used once), and the real flow through the scenes in a scene of its own: Play, Start, the game, Main menu, Practice and `disconnect`. `settings_test` has 67 (4 new: `is_loaded()`, the `[match]` section saved, and two hand-edited files). The other five suites pass unchanged. A mutation run of 6 changes (the player left in the background, practice ignoring the difficulty, the description never cleared, a row that doesn't store, Esc doing something on the page, the menu not registered) fails at least one check each. Screenshots at 1280 × 720 and 1920 × 1080 (menu, match setup, the game after Start), and `-- --match` goes straight to the match.

**Alternatives:** An autoload for the hand-over (autoloads don't exist in `--script` runs, so tools and tests that load scenes would break, the reason `Noises` and `Teams` are plain classes); instantiating `main.tscn` in the menu, configuring it and swapping it in by hand (more control, but it re-implements `change_scene_to_*`, and the old scene still has to be freed correctly); the menu as a state of `main.tscn` (the match code, HUD and console would have to be hidden and kept quiet behind it, and leaving a match would mean tearing the game down by hand); a recorded video or an image as the background (the live flight costs nothing and shows the real map with the player's video settings); keyframes in an `AnimationPlayer` (the waypoint table is easier to tune than keyframes); a camera that looks at a second "points of interest" path (not built: the two loops move at different speeds, and a rough estimate had the view swinging around at about 40° a second where they come closest, which is not calm); sliders or drop-downs for team size and match length (segmented buttons show all choices at once); making the command-line shortcuts read the stored setup (a player's last choice would change a smoke run).

## D-065 — The pause menu pauses the whole tree; Esc is the `pause` action (2026-10-15)

**Decision:**
- **Esc opens a pause menu** (`ui/pause_menu.tscn` + `pause_menu.gd`, `PauseMenu`, a `CanvasLayer` on layer 4, between the Tab scoreboard and the match-end screen) with a themed panel: the title "Paused" and three big buttons, **Resume**, **Settings** and **Leave match** ("Leave practice" in the bot arena, "Leave" on a map without rules; `main.gd` sets the text whenever a map loads). A dim full-screen `ColorRect` with `mouse_filter = STOP` sits behind the panel like the match-end screen's, so no click reaches the player controls. It registers with `MenuState` while it is open (the mouse is shown, the player's controls and the Tab scoreboard are blocked, the last menu to close captures the mouse again) and is scaled by `UiTheme.apply()`.
- **Opening it pauses the game for real:** `get_tree().paused = true`. Everything with the default process mode (`PROCESS_MODE_INHERIT`, which resolves to "pausable") stops at once: the map, the characters and bots, the `RoundManager` and its timer, the weapons, the HUD and the kill feed, tweens bound to a node (the weapon's kick, the fall-over, the kill feed's fades; a tween pauses with the node it is bound to), `create_timer(…, false)` timers (the practice arena's respawn wait), the physics and navigation servers (`SceneTree` switches them off by itself), and every playing `AudioStreamPlayer` / `AudioStreamPlayer3D` (stream paused, resumed where it stopped). Resume (button, Esc or `close()`) sets it back. Nothing in the game needed changing for that: it already counted time only in `_physics_process`, never with wall-clock time (a rule from "Keeping multiplayer possible").
- **What keeps running while paused** has `process_mode = PROCESS_MODE_ALWAYS` in its scene: the pause menu itself, the **settings menu** (it opens over the pause menu, and its crosshair preview animates), the **developer console** (it works over the pause menu too) and the **Tab scoreboard**. The scoreboard is the odd one: it only has to *hide*. A paused node's `_process` doesn't run, so a scoreboard that was up when Esc was pressed (Tab still held) would stay on screen over the menu; running, it sees `MenuState.blocks_gameplay()` and hides, as it always did for the console. (The HUD and the debug overlay stay pausable: they freeze as they are, which is what "paused" looks like.) A sound that has to play while paused (a menu click on the Interface bus, later) must be `PROCESS_MODE_ALWAYS` too: a plain player pauses with the tree.
- **Esc, who takes it.** Esc is handled where it belongs, and one press does one thing: with nothing open the pause menu opens (so the mouse is freed, as Esc used to do); with the pause menu on top Esc resumes; the settings menu opened from it takes Esc first and returns to the pause menu (still paused); the console takes Esc first and closes only itself; the match-end screen swallows it (the match is over, there is nothing to pause); the main menu's panels are unchanged. The order is the one `_input` already has (later nodes in the tree are called first): in `main.tscn` the pause menu comes *after* the Tab scoreboard and *before* the match-end screen, the settings menu and the console, so those three see Esc before it does. `PauseMenu` only opens when `MenuState.blocks_gameplay()` is false. While the settings menu waits for a key to bind (`MenuState.capturing_input`) nobody else reacts.
- **The action is renamed `toggle_mouse` → `pause`** (`project.godot`, every user of it, the docs): it no longer toggles the mouse. Esc stays fixed (not in `Settings.BINDABLE_ACTIONS`, not rebindable). `PlayerController` doesn't handle it any more. What it keeps from the old behaviour is only "a click into a window with a free mouse and no menu open (after alt-tab) captures the mouse without firing a shot".
- **Leave** emits `leave_pressed`, and `main.gd` calls `return_to_menu()`, which now sets `paused = false` *before* `change_scene_to_file()`: the pause belongs to the tree, not to the scene, so a menu scene started paused would be frozen and deaf to clicks. That also covers the console's `disconnect` typed over the pause menu. `PauseMenu._exit_tree()` unpauses as well if it is freed while open. Settings emits `settings_pressed`; `main.gd` opens the settings menu and calls `PauseMenu.settings_closed()` when it closes. The pause panel hides while the settings menu is up (the settings menu has a dim background of its own, and two would darken the game twice) and comes back with the Settings button focused.
- **After Resume:** `PlayerController` forgets a jump or reload queued just before Esc (`NOTIFICATION_PAUSED`) and, with the fire button still held, doesn't shoot until it is let go (`NOTIFICATION_UNPAUSED`; its `_process` can't do it, it doesn't run while paused). The debug overlay's hint says "Esc pause menu".
- **Single-player only.** In multiplayer (M9) nobody can stop the other players or the host's clock, so this menu becomes an **overlay that doesn't pause**: it keeps its buttons and registration with `MenuState` (the player still can't move or shoot while it is open, the mouse is shown), but `open()` and `close()` stop touching `SceneTree.paused`, and the nodes marked Always here no longer need it. Whatever has to stand still for the *local* player is then done by `MenuState`, which the controller already reads.

**Why:** Pausing the tree is how Godot does a single-player pause, and it is complete: every system stops together without a pause flag in each (the round timer, bots, bullets in flight, sounds), so there is nothing to forget and nothing that drifts. Putting Esc in the pause menu instead of the controller keeps "what Esc means" in one place and removes the half-state the old Esc left (a free mouse with the game still running, bots shooting you while you looked for the Settings). Marking only the four nodes that must live as Always keeps the rule small and visible in the scene files; the scoreboard exception is the kind of thing that surprises later, so it is written down here and in CLAUDE.md. Renaming the action keeps names honest (a `toggle_mouse` that opens a menu would send the next reader looking for mouse code). Unpausing in `return_to_menu()` rather than in the pause menu's Leave handler makes every way out of a paused game safe, including ones that don't exist yet. The M9 note is here so the overlay version is a known small change, not a surprise.

**Checked:** `ui_test` grew from 111 to 132 checks: the `pause` action (on Esc alone, not bindable, `toggle_mouse` gone); in a real game scene Esc opens the menu (visible, on top of `MenuState`, tree paused) with Resume, Settings, Leave match; Resume and Esc close it; Settings opens over it, Esc comes back, still paused, and one more Esc resumes; the console closes alone on Esc, with and without the pause menu; with the match-end screen up Esc does nothing; the round manager's `time_left` and every character's position are exactly the same after 30 physics ticks while paused (and had changed while running), the Tab scoreboard stays hidden although Tab is held, the map, rounds, player and HUD can't process while the menus, the console and the scoreboard can, a world sound is paused and an Always sound plays on, Resume starts it all again and a held fire button doesn't shoot, a queued jump is forgotten; the menu's look (modal panel, 48 px title, three 32 px buttons, no overrides, a click-blocking background, scaled exactly 1.5×); and through the real scenes Leave match and `disconnect` over the pause menu land in an unpaused main menu ("Leave match" in a match, "Leave practice" in practice). A mutation run of 15 changes (no pausing, no unpausing, no fire block, a jump not forgotten, each of the four Always nodes made pausable, the menu after the match-end screen in the tree, the match-end screen not swallowing Esc, the pause panel staying over the settings, no unpause on leaving, Esc not resuming, the pause panel not coming back, the action off Esc) fails at least one check each. In a real window at 1280 × 720 (screenshots of the match running, the pause menu over it, the settings menu opened from it, and back): the round timer did not move for 60 frames while paused, the mouse was visible, and it was captured again after Resume. The other six suites pass unchanged (movement 13, weapon 20, bot 16, round 74, tactics 4, settings 67).

**Alternatives:** Pausing only the pieces by hand (the round manager's timer, bots, weapons... each with its own flag: every new system would have to remember it, and a bot mid-burst or a bullet in flight would be easy to miss); `Engine.time_scale = 0` (Unity's `Time.timeScale`: it slows physics and `_process` deltas to nothing but nodes still run, timers and input handlers still fire, and audio keeps playing, so it is a poor "pause" in Godot); the pause menu as an overlay that doesn't pause now (nothing would stop the bots, which is wrong for single-player and only right for M9); leaving Esc in `PlayerController` and having it call the menu (two owners of one key, and the controller would have to know about the menu); `PROCESS_MODE_WHEN_PAUSED` for the pause menu (it must also work in the main menu's scene tree, where nothing is paused, and the settings menu is shared); making the scoreboard hide with `NOTIFICATION_PAUSED` instead of running while paused (it would work, but the scoreboard would then need a second rule beside `MenuState`, where one already exists); registering the match-end screen with `MenuState` so the pause menu can ask it (cleaner in principle, but it would change what that screen does to the controller and the scoreboard, and belongs in its own change; tree order and a test cover it for now); a single "Leave" text for both modes (the player should read what they are leaving); keeping a rebindable pause key (Esc is fixed for every menu, and the settings menu's cancel key is the same one); pausing automatically when the window loses focus (not asked for; the click that captures the mouse again keeps working for alt-tab).

## D-066 — The full-match check plays one seeded match through the real game; one script runs every suite (2026-10-15)

**Decision:**
- **`tests/match_test.tscn` + `.gd`** plays one whole 3v3 match, first to 5, on the test map through the real `main.tscn`: the test leaves a `GameLaunch` description like the main menu's Start and instantiates the game scene with `load_settings = false`, so the real round manager, HUD, scoreboard and match-end screen are all in play. Freeze time and the round-end pause are 1 s and a round lasts up to 90 s (the real default is 115 s; the match then runs about 500 s of game time in about 20 s of real time). You stand still with no input and die or survive like anyone else; the other five are Normal bots. The round manager's generator and every bot's brain and weapon are seeded right after they join (during round 1's freeze time), and everyone is silenced, so every run plays the same match. The test waits for `match_ended` (with a budget of nine full rounds plus 10 s, so a stuck match fails with a message before the `--quit-after` net), prints one informational line per round, and then runs 13 checks (list in ARCHITECTURE.md, "Testing"). The checks are about the *structure* of any match, not about this seed's story (one `match_ended`; the winner on exactly `rounds_to_win`; 5 to 9 rounds; one swap after round 4; the right winner for each reason; stats adding up; the HUD and the end screen showing the result; everyone frozen; the real settings file untouched), so a balance change that alters who wins doesn't break them.
- **`tools/run_tests.sh`** (a bash script, bash 3.2, no `timeout`) runs the eight suites one at a time, each with its own `--quit-after`, counts their PASS and FAIL lines and prints a table (suite, pass, fail, status, seconds); the exit code is the number of failed suites. A suite fails on a FAIL line, **no PASS line**, a `SCRIPT ERROR`, a missing final "All checks passed." line (the safety net ended it) or a non-zero exit code; a plain `ERROR:` line doesn't count (the settings suite prints one expected). It is the standard way to run the tests (README, CLAUDE.md); the single-suite commands stay for reading one suite's output. It never runs `--import` and never touches git.
- **Not added:** a check for friendly fire in the match test. The rule is checked where it lives (`bot_test`: off, a third on, bullets passing through teammates; `ui_test`: a match launched with friendly fire on sets `Teams.friendly_fire`), and the match test keeps the default (off), like the main menu's default match.

**Why:** Every suite so far checked one system on its own, mostly with the bots held back or the kills scripted, so nothing proved that the parts survive being played together: the round manager, bot tactics, damage, spawns, the HUD, the match-end screen and the scene flow in one real match. A whole match is the closest thing to the playtest that can run after every change, and seeding makes a failure repeatable instead of a one-in-ten flake. The runner exists because eight commands with eight different `--quit-after` values and a silent failure mode (a parse error exits with code 0 and prints nothing) are easy to run wrongly; the counting rules turn that gotcha into a failure. A standing-still player is what a real person who walks away looks like to the bots, and it exercises the "you die, then spectate" path and both ways to lose a round.

**Alternatives:** A match of six bots (no player) like `tactics_test`: simpler, but then no HUD state for "you" and no Victory or Defeat. Driving the real player with scripted input: much more code for little extra, since the player's own movement and shooting have their own suites. Starting the round manager alone on the map (as `round_test` does): doesn't exercise `main.gd`, `GameLaunch`, the HUD wiring or the match-end screen. A longer or random-seeded run (or many seeds in one go): slower and flakier; the default seed was run with four other seeds by hand and all passed. A test framework (GUT, gdUnit4) or a Makefile / CI file: more machinery than eight scenes and one script need (D-018). Reading the exit code only in the runner: exit code 0 hides a parse error, so counting PASS lines is needed.

## D-067 — Attackers close in instead of trading shots at long range (2026-10-15)

**Decision:** an attacking bot that has fought one enemy for more than 6 s at over 35 m stops shooting at enemies beyond 35 m for 4 s and walks toward the enemy, facing it (its search behaviour). Within 35 m it fights normally again. Defenders keep holding and shooting at any range.

**Why:** The full-match test (D-066) showed a round that ran out the clock: the last attacker and a holding defender saw each other 58 m apart, just inside sight range, and traded bursts for over a minute without hitting, because a fighting bot stops to shoot. At that range a bot's aim error is about a metre, so neither wins. A CS player wouldn't stand there either: they'd push to a closer angle. Holding defenders are fine with a long duel, since the clock is on their side.

**Checked:** a new bot check puts an attacker and a holding defender 58 m apart (both in god mode). The attacker fights at long range first, then closes to 35 m after 10.4 s; with the rule switched off it stays at 48 m for the whole 20 s. In the seeded full match, the all-bot attacking rounds now all end by elimination; the remaining time-outs are rounds where only the idle test player was left attacking.

**Alternatives:** a shorter sight range (hides the problem, and you'd see bots that can't see you); better aim at long range (makes bots snipe with a rifle, unfair); a cover-seeking AI (better, much more work; backlog "smarter team AI").

## D-070 — The crew's looks and final class names (2026-10-15)

**Decision:**
- **The names are final:** Rifleman, Bulwark, Marksman, Scout.
- **The looks are the approved concept sheets** (`tools/concept/spritegen.py --sheet`). Heights are measured to the top of the head or headgear in the idle pose, and the tool scales each body to its height:
  - **Rifleman**, 1.82 m, stocky and upright: high-cut helmet with a team stripe, goggles, plate carrier, olive-grey trousers, the AK-style rifle (curved magazine, wood furniture).
  - **Bulwark**, 1.92 m, broad, 13° hunch with the head kept level: closed helmet with a team stripe over a gas mask, big stone-grey shoulder plates edged in team colour, front plates, charcoal trousers, the pump shotgun.
  - **Marksman**, 1.88 m, lanky (6% longer legs): knee-length moss-grey coat whose skirt is one flap per thigh (so it can hang on the leg bones), hood, team-colour scarf over the face, a team panel across the back, the sniper rifle.
  - **Scout**, 1.72 m, slim: knit beanie, balaclava, goggles with glowing green lenses, a fitted team-colour jacket, a radio with a whip antenna above the head, the SMG.
- **Team colour:** every class has **team-colour sleeves** (so first-person arms show your team, task 9), plus marks of its own: the Rifleman's and the Scout's shirt or jacket, both helmet stripes, the Bulwark's plate edges, the Marksman's scarf and back panel. The tool measures the share: 11–23% of the visible body from every one of the 8 directions (Rifleman 18%, Bulwark 12% of the biggest body, Marksman 16%, Scout 19% on average).
- **The kit is neutral:** olive-grey, charcoal, stone grey and moss. Warm colours are only skin, wood and brass (D-031). The team ramps are built around `Teams.FRIENDLY_COLOR` and `Teams.ENEMY_COLOR`, so the sheets show the game's own blue and red.

**Why:** You approved the looks as shown and kept the working names, which tell a CS player the role (rifler, anchor, AWPer, lurker). The first version had team colour only on armbands and a scarf for the Marksman: 6% of the body, 8% from behind, against the clarity rule. Team sleeves on every class are one simple rule, they match the first-person arms, and the measured share now keeps every class readable as friend or foe from every side.

**Alternatives:** Team colour only on small marks (too little on the Marksman); a whole team-colour jacket for everyone (the kit would no longer be neutral and the classes would read less by their gear); callsign names (Striker, Anvil, Longshot, Shade; or Wolf, Bear, Heron and Fox, which would also avoid "Scout", a sniper rifle in CS 1.6), Vanguard, Bulwark, Overwatch and Runner, or squad slang (Pointman, Breacher, Longshot, Runner).

**A second approved version:** another session made the concept sheets in parallel (commit 31f9a75) and you approved those too: armbands on everyone plus per-class accents (the Rifleman's helmet stripe, straps and patches; the Bulwark's shoulder plates; the Marksman's scarf, cowl and tail; the Scout's beanie and rig straps), 8–12% of the body from the front, a long dark-grey coat with a pointed hood for the Marksman, and a bent-kneed, wide stance for the Bulwark. Shown both line-ups side by side, you chose the version above, which the 3D models were already built from (tasks 2–7) and which gives the first-person arms team-colour sleeves (task 9). The other branch was merged for its history; its tool changes were not kept.

## D-071 — Python tools run in a Miniconda environment (2026-10-15)

**Decision:** Chiip's Python tools (`tools/concept/`, and `tools/modelgen/` from task 2) run in a conda environment named `chiip` in `~/miniconda3`: Python 3.12 with numpy and Pillow, nothing else. Miniconda was installed in batch mode, without `conda init`, so no shell profile changed; the tools are called through `~/miniconda3/envs/chiip/bin/python`. glTF files are written by hand (JSON plus a binary buffer), with no glTF library. Replaces the `~/.venvs/chiip-tools` virtual environment that D-054 and CLAUDE.md named.

**Why:** Your choice ("rather first download miniconda and then install there what you need, numpy + Pillow"). One environment keeps the tools' packages apart from the system Python. A `.glb` is a small, well-documented format, so writing it ourselves costs about 200 lines and no dependency. Other packages need your OK first.

**Alternatives:** A venv on the system's `python3` (the old plan); a glTF library such as pygltflib or trimesh.

## D-072 — How the model generator builds a character (2026-10-15) — *provisional*

**Decision:**
- **Pieces on bones.** A class is a list of low-poly pieces (bevelled boxes, tapered cylinders, low-res ellipsoids and domes clipped by a plane), each fully bound to one bone (weight 1), so limbs stay rigid like late-90s models. Each piece also names its hit zone (task 4).
- **One skeleton for every class**, 17 bones: `hips`, `spine`, `chest`, `head`, `upper_arm`/`forearm`/`hand` and `thigh`/`shin`/`foot` per side, and `weapon`, a child of the right hand at the grip. Lengths and widths scale per class (body scale, leg length, bulk), so animations are written once and solved per class. The tool finds the body scale at which the model is exactly its concept height.
- **The rest pose is a T-pose with every bone's rotation the identity** (except `weapon`, which holds the grip's rotation). Piece sizes and positions are then plain model axes relative to the bone, which keeps the part lists readable.
- **Models face −Z with +X to their right**, Godot's own forward, so a model needs no turning in Godot. (glTF assets normally face +Z.)
- **Texture:** each piece gets six rectangles in a 256-texel-wide atlas, one per side of its bounding box, and each triangle is projected onto the side it faces (box projection). 96 texels per metre gives chunky pixels at Chiip's 480 lines. Every texel comes from the concept palette's 16-shade ramps through the class's kit, with a little baked light, edge darkening, grain and patterns.
- **Team colour is a mask texture next to the albedo** (`<class>_mask.png`: red = team colour, green = glow). Team texels in the albedo are a neutral grey whose brightness is the shading; the shader (task 3) multiplies it by the viewer's team colour.
- **Textures are separate PNG files** next to the `.glb`, imported lossless, with mipmaps and without Godot's automatic switch to VRAM compression; the `.glb` references the albedo and samples it nearest-neighbour.

**Why:** Rigid pieces are the look we're after and make skinning trivial (no weight painting). One skeleton keeps the animation set shared and the AnimationTree identical for every class (task 6), and M9's network players animate the same way. Identity rest rotations and model-space numbers make the part lists match the concept's measurements one to one. Box projection needs no hand-made UV layout and lets the painter place patterns and decals in metres. A separate mask keeps the albedo free of alpha tricks, which Godot's import can alter (alpha border fixing), and its green channel gives the Scout's goggles their glow. External PNGs keep their own import settings, so the palette survives import untouched.

**Alternatives:** Smooth skinning with blended weights (softer joints, but weight painting and a less retro look); per-class skeletons (more freedom, but four animation sets); an A-pose rest; UV unwrapping per shape type (less texture waste, more code); the team mask in the albedo's alpha; textures embedded in the `.glb` (Godot would compress them).

## D-073 — Team colour through a shader with a per-instance colour (2026-10-15)

**Decision:**
- **One shader for every crew model** (`characters/crew/crew.gdshader`). It reads the class's albedo and mask textures; where the mask's red channel is set, the albedo's grey is multiplied by the team colour (`team_color * grey / TEAM_BASE`, with `TEAM_BASE` 0.5 as in `tools/modelgen/paint.py`), so the baked light and dark of the grey survive; the green channel adds emission so glowing texels ignore the lights. Everything else is matte (roughness 1, specular 0.2), like the world materials.
- **The colour is an `instance uniform`**, set from code with `set_instance_shader_parameter("team_color", …)`. The `ShaderMaterial` is therefore shared: `CrewBody.material_for(model_path)` builds one per class model (textures found next to the `.glb`: `x.glb` → `x_albedo.png`, `x_mask.png`) and caches it, while each character's meshes carry their own colour.
- **`CrewBody` and `SoldierBody` have the same colour calls** (`set_team_color()`, `get_team_color()`), and `Character.update_team_color()` calls the body. `SoldierBody` owns its clothes material now, so `Character` no longer knows how a body is painted and task 4 can swap bodies without touching it.

**Why:** Team colour depends on who is looking (D-041, D-042), and `Teams.set_viewer_team()` has to recolour everyone at once: a per-instance parameter changes one value per mesh and nothing else. A shared material keeps every character of a class on the same draw settings (the cost that matters when 10 animated characters are on screen in task 10). Keeping the shading in the grey means the artist-side textures stay palette-limited and the team parts still look lit and worn, instead of flat.

**Alternatives:**
- *One material per character*, as `Character` did with a `StandardMaterial3D` for the blocky body: simple, but then every character is its own material (10 characters, 10 materials per class), each holding its own references to the textures.
- *Baking a blue and a red texture* and swapping: doubles the textures, and only works if there are exactly two colours (a spectator or a team-colour setting later would need more).
- *The team mask in the albedo's alpha*: one texture fewer, but Godot's import can alter colour under alpha (alpha border fixing, premultiplying) and would break the palette; two textures are clearer (D-072).

## D-074 — Hit zones are boxes on bones, built from the part list (2026-10-15) — *provisional*

**Decision:**
- **The generator measures the boxes.** For each class it measures the pieces of every zone per bone: one box for the head, one for the chest, one for the stomach, and one for each arm bone and each leg bone (upper arm, forearm and hand; thigh, shin and foot, per side): 15 boxes per class, written to `assets/models/crew/<class>_hit_zones.tres` as a `HitZones` resource (bones, zones, centres in the bone's frame, sizes). Chest and stomach are split at the bottom of the ribcage, 6 cm × body scale below the chest bone (about 1.26 m on the Rifleman); the stomach box covers the pelvis too.
- **`CrewBody` builds them at runtime**: a `BoneAttachment3D` per box under the model's `Skeleton3D`, a `Hitbox` area under it and a `BoxShape3D` at the box's centre. `Character` finds the hit zones as before (`find_children`). `Character.body` is a `CrewBody` and `SoldierBody` is deleted.
- **Every class keeps CS's hull and eye height** (64 units standing, 46 crouched), whatever its height (1.72 to 1.92 m). A taller class shows its head above cover a little before it can see over it, and the Scout a little after; the perks balance this (D-052, D-055).
- **Bots aim at and look for the hit zones' centres** (`Character.get_head_position()` and `get_chest_position()`, with `get_visibility_points()` built from them) instead of the eye position, so they shoot at the head they actually see.
- **Interim, until the AnimationTree (task 6):** the T-pose arms are lowered 75 degrees when the body is built, and `update_pose()` only sinks the hips by the crouch offset, so the head, chest and stomach zones sink 0.457 m as in CS (the legs sink into the floor too).

**Why:** D-055 asks that what you see is what you hit, and boxes on bones are the cheapest way to get it: the zones come from the same part list as the visible model, so they grow with the class, and they follow whatever the skeleton does, including the animations of later tasks. One box per bone for the limbs keeps the hit tests cheap (15 areas per character, 10 characters) while arms and legs can still move away from the body. Keeping the eye height fixed keeps CS's cover and peeking rules the same for every class, so movement and the maps don't depend on who is playing. Aiming at the zone centres matters because the head zone's centre is no longer at the eyes.

**Alternatives:**
- *One box per zone only* (a single arms box, a single legs box): fewer areas, but arms and legs couldn't follow the limbs when they move.
- *Capsules* for the limbs: closer to the limbs' shape, but harder to size from the box-shaped part list, and not as cheap to build.
- *CS's identical hit zones for everyone*: rejected in D-055.
- *A per-class eye height*: a taller class would see over cover sooner and a shorter one later, which changes every map's lines of sight per class.

## D-075 — Animations are solved per class and written by the generator (2026-10-15) — *provisional*

**Decision:**
- **Poses are solved, not stored.** `tools/modelgen/anims.py` describes each pose by intent (where the feet go, where the gun points, how the torso leans) and solves the bones for the class with two-bone IK: the legs to their foot targets, the right hand to the grip, the left hand to the foregrip. The same rules give the short Scout and the tall Bulwark their own clips, with the hands on the gun and the feet on the floor.
- **41 clips per class**, keyed at 30 frames per second: idle and crouch idle; walk, run and crouch-walk in 8 directions; jump, fall, crouched fall and land; aim poses at −80°, −40°, 0°, 40° and 80°; fire and the flinch as *differences* from aiming level (for the AnimationTree's additive layers); the reload (2.5 s, the rifle's reload time); and three deaths, whose lying poses are lowered until the body touches the floor.
- **Locomotion cycles all last 0.66 s** and are made for CS's speeds with a rifle: running 5.46 m/s, walking 2.84 m/s, crouching 1.86 m/s. Same length means the AnimationTree can blend them in step; at running speed a step is 1.8 m, the distance between two footstep sounds (`Character.STEP_DISTANCE`).
- **Moving sideways turns the legs**, up to 45° toward the direction of travel; for backward directions the legs run backward instead. The upper body keeps facing the aim.
- **The rifle stance:** butt in the right shoulder, the chest turned 25° (left shoulder forward), the head turned back to the front, the barrel at exactly the aim pitch. If a class's arms can't reach the foregrip, the gun slides back until they do.
- **Guns are separate models in weapon space** (origin at the grip, barrel along −Z), hung on the `weapon` bone; the AK-style rifle is the first (`assets/models/weapons/ak_rifle.glb`).
- **Looping clips are named with a `-loop` suffix in the `.glb`.** Godot's importer then sets them to loop and drops the suffix. (Writing the loop modes into the `.glb.import` file's `_subresources` works too, but Godot then fills in every default option of every clip: 84,000 lines.)

**Why:** Keyframing four classes by hand would mean four sets of 41 clips that drift apart; solving them from one description keeps the hands on the gun whatever the arm length, and a change to the gait changes every class at once. Equal cycle lengths are what lets a blend space mix walk and run without the legs falling out of step. Tying the step to the footstep distance makes the sounds land on the feet. Turning the legs instead of the whole body keeps the gun on target while strafing, which in CS is most of the movement. A separate gun model is what M7 needs to swap weapons.

**Alternatives:** Motion capture or Mixamo clips (not for our rigid low-poly rig, and every download needs your OK); procedural animation at runtime, as `SoldierBody` did (cheaper to change but not authorable, and the network game would have to run it on every machine); per-speed cycle lengths with a cadence-matching node (more natural cadence, harder blending); sideways steps without turning the legs (the legs would cross at running speed).

## D-076 — One shared AnimationTree, driven by the character's state (2026-10-15) — *provisional*

**Decision:**
- **One graph for every class** (`characters/crew/crew_animation_tree.tres`, built by `tools/make_crew_animation_tree.gd`), since all classes share bone names and clip names. From the legs up: 2D blend spaces of the locomotion clips with the velocity relative to the facing as the blend position (m/s; idle in the middle, walks at 2.84, runs at 5.46, crouch-walks at 1.86), a crouch blend, a time scale so the feet keep up outside the walk–run range, a blend to the falling pose, one-shots for jump and landing (after at least 0.25 s in the air), then the upper body: a Blend2 filtered to spine, chest, head and arms takes them from a 1D blend space of the five aim poses by pitch. Fire and the flinch are *additive* one-shots on top; the reload is a one-shot filtered to the arms (so the head keeps aiming), stretched to the held weapon's reload time; a transition switches to one of three deaths.
- **Driven only by state.** `CrewBody` reads the character every physics tick (velocity, crouching, on the floor, aim pitch) and its events (shot, reload start, damage, death, respawn), never the input. The death picks the headshot crumple after a head hit, otherwise the body falls away from the killer.
- **Physics-tick animation.** The tree and the skeleton update on physics ticks, so hit zones are where the animation put them in the tick a shot is simulated, and the same on every machine.
- **First person vs. third person.** The body holds the gun model on the `weapon` bone with its own muzzle flash. The weapon's first-person viewmodel shows only for whoever looks through that character's eyes (`Character.set_first_person()`: the local player, a spectated teammate); everyone else sees the body.

**Why:** A blend tree is Godot's equivalent of Unity's Animator controller, and one generated graph keeps four classes consistent (the graph is data, so it can be opened and inspected in the editor, but changed in one script). Filtering the upper body is what lets a character run one way and aim another, as in CS. Additive layers keep the kick and the flinch on top of whatever aim pitch the body has; replacing them would snap the gun to level. State-only driving is the M9 rule (ARCHITECTURE, "Keeping multiplayer possible"): a client receives positions, velocities, stance and view angles and animates them the same way. Physics ticks make what you hit match what the server simulates.

**Alternatives:** An `AnimationNodeStateMachine` for locomotion (good for distinct states, but walk/run/strafe blend continuously, which blend spaces do better); playing clips with `AnimationPlayer` and cross-fades in code (simple, but no per-bone layering); keeping the bot's viewmodel as its third-person gun (it floated under the head, not in the hands); animating on rendered frames (smoother on fast monitors, but hit zones would lag the simulation).

## D-077 — The other three classes, and how big a target each one is (2026-10-15) — *provisional*

**Decision:**
- **Bulwark, Marksman and Scout are built from the approved concept sheets** by the same generator, each with its own kit and the shared skeleton and clips (solved for its own body): Bulwark 2,435 triangles, Marksman 1,805, Scout 1,898 (Rifleman 2,106); textures 256 × 288 to 256 × 576.
- **The Marksman's coat is one flap per thigh plus a pelvis piece**, so it swings with the legs like a segmented model; the Scout's goggles glow (the mask's green channel); the Bulwark's shoulder plates carry its team-colour edge.
- **Hit zones keep following the visible body** (D-055), gear included. Total zone volume: Scout 132 L, Marksman 173 L, Rifleman 223 L, Bulwark 484 L. The Bulwark's chest zone is 0.91 m wide (shoulder plates) and 0.59 m deep (ammo pack). Kept as is for the playtest.

**Why:** These are the looks you approved, and the generator keeps them consistent with the Rifleman. Leaving gear out of the hit zones would let bullets pass through things you can see. The Bulwark's size is the trade D-052/D-055 accepted (a bigger target, balanced by *Plated*); the playtest decides if it's too big, and the fix would be in its part list (smaller plates or pack), not in special hit-zone rules.

**Alternatives:** Hit zones from the body only, without gear (fairer sizes, but shots through visible plates and packs would miss); one shared hit-zone set for every class (CS's rule, rejected in D-055); smaller shoulder plates now, before anyone has played against it.

## D-078 — Class data and the class pick (2026-10-15) — *provisional*

**Decision:**
- **One `ClassData` resource per class** (`characters/crew/classes/*.tres`, script `characters/crew/class_data.gd`): id, name, role, height, the model and hit zones that make the body, a slot for the first-person arms (task 9), the signature gun, the look and the perk's name and text. The perk *numbers* are stored there too (`reload_time_factor` 0.85 for the Rifleman, `armor_damage_factor` 0.9 and `armor_wear_factor` 0.7 for the Bulwark, `scoped_recovery_factor` 1.3 and `scope_in_time_factor` 0.8 for the Marksman, `running_footstep_range_factor` 0.7 for the Scout; every other factor 1.0), but nothing reads them until M7, when armour and scopes exist (D-052). `ClassData.all()` is the one list of classes, in menu order.
- **The round manager decides class changes.** `RoundManager.request_class()` accepts a change only in freeze time (and before the first round), refuses it in a live round, at the round end and after the match, and emits `class_changed`. The class menu and the console ask it; nobody sets a player's `class_data` directly in a match. In practice mode `ArenaRules.request_class()` always accepts, because there is no freeze time.
- **When you choose:** a menu opens by itself when round 1's freeze time begins; M opens and closes it during freeze time (any time in practice mode); it closes when the round goes live. Keys 1 to 4 or a click pick, Esc closes without a change. M is the key CS uses for its team and class menu. Your class stays between rounds until you change it.
- **Bots get a mix:** when the match starts each team's bots cycle through the four classes starting at a random one, so three bots are always three different classes. The offset is drawn from a second generator seeded from `rng.seed`, so a seed still gives the same class mix, and the spawn spots and starting sides of older seeds stay the same. The player keeps the Rifleman unless `MatchSettings.player_class` says otherwise.
- **A class change swaps the body at runtime:** `Character.class_data` is set, `CrewBody.set_class()` removes the old model (`remove_child` and `queue_free`), builds the new one and the character gathers the new hit zones. Whoever dies is still dead afterwards (new zones off, the death plays again).

**Why:** Data in resources keeps the classes in one place a designer can edit (Godot's answer to Unity's ScriptableObject, like `WeaponData`), and storing the perk numbers now means M7 only has to read them. Putting the rule in the round manager keeps to the multiplayer rule: the host decides, the menu only asks (D-033). Freeze time is when everyone stands still at the spawn, like CS's buy time, so a class change costs nothing and nobody changes mid-fight. A mix of bots means you meet all four silhouettes and hit-zone sizes in every match, which is what the playtest of D-077 needs.

**Alternatives:** Choosing the class only in match setup, once (simpler, but D-052 wants a change during freeze time); locking the class for a half (rejected in D-052); random bot classes with repeats (a team could be three Scouts, and the mix would not show all classes); applying the perks now without armour or scopes (the Bulwark's and the Marksman's perks would do nothing yet, and the numbers would be tuned blind); drawing the class offsets from `rng` itself (more direct, but it shifts every later draw and changes which team attacks and who fights whom in the seeded tests).

## D-079 — First-person arms come from the generator, one set per class (2026-10-15) — *provisional*

**Decision:**
- **Each class has its own first-person arms model** (`assets/models/crew/<class>_arms.glb`, from `tools/modelgen/fparms.py`): the class's own arm pieces (team-colour sleeves, its gloves and a wrist detail) on a 7-bone skeleton whose root is the camera, sharing the body's texture and material. The class data points at it (`ClassData.arms_model`), and the character puts it into its weapon's viewmodel.
- **The weapon owns its gun model** (`Weapon.gun_model`, the AK in M6) and puts it on the arms' weapon bone, with the muzzle flash at `muzzle_point`; M7's weapons each bring their own.
- **Clips for what the hands do, code for what follows the player:** `fp_draw`, `fp_idle`, `fp_fire` and `fp_reload` are solved with the same IK as the body (so the hands stay on the gun); sway (lag behind the turning view) and bob (in step with the footsteps) are computed every frame, because they depend on the mouse and the feet.
- **The gun sits low on the right**, the grip at (0.20, −0.165, −0.36) m from the camera and turned 4° inward, like a CS viewmodel.

**Why:** The plan asks for arms made by the same generator, with each class's gloves and sleeves; seeing your class's own arms is the cheapest way to feel which class you play. Sharing the body's texture keeps one material per class and puts the team colour on the sleeves for free. Clips keep the first-person kick and reload consistent with the third-person ones and editable in one place.

**Alternatives:** One arms model for everyone (cheaper, but your class wouldn't show in first person); rendering the third-person body's arms from the eye (they are posed for third person and would clip into the camera); a second camera for the viewmodel with its own field of view, so the gun never pokes into walls (a known limitation since M2; later).

## D-087 — Mode and map rotation in match setup; "Next map" on the end screen (2026-10-15) — *provisional*

**Decision:**
- **Match setup** gets a **Mode** row (**Rounds** or **Team respawn**) at the top and a **Maps** row (**One map** or **Rotation**) above the map list. The Match length row counts rounds (first to 5, 10 or 15) for rounds, and is replaced by kills (**30, 50 or 75**, 50 by default, D-083) for team respawn. The summary line says the mode ("Team respawn: You and 2 bots…, first to 50 kills…") and lists the rotation ("Maps in rotation: Square, Spillway, Depot."). All three are remembered with the other match choices (`Settings`: `match_mode`, `match_kill_limit`, `match_rotation`).
- **The rotation** is the three quick maps in a fixed order, **Depot → Square → Spillway → Depot…** (`GameLaunch.ROTATION_MAPS`), each a fresh match by the same rules. It starts on the map chosen in the Map row when that is one of them (otherwise on Depot), so the map list keeps its meaning and stays exactly the maps on disk. "Rounds" on the quick maps are bomb rounds (D-080); on the test map they are elimination rounds, which is why the test map isn't in the rotation.
- **The end screen** shows **"Next map: Square"** next to Play again and Main menu when a rotation is on, with the keyboard focus on it. Play again replays the same map; Next map moves on (and wraps around). Without a rotation the button is hidden.
- **How it travels:** Start leaves the rotation for the game with the rest of the match (`GameLaunch.start_match(map, rules, maps)`, `GameLaunch.rotation`); `main.gd` keeps the list and its place, `next_map()` loads the next one with `change_map()` (like Play again), and `get_next_map()` names it for the end screen. From the terminal: `-- --match --rotation` (add `--respawn` for team respawn).
- **Small fixes on the way:** a hunting bot asked the navigation map for a point before it was ready right after a map loaded (an error line, no harm done), now skipped until the map has synced; and `get_rotation()` couldn't be used as a method name on a menu, because `CanvasLayer` already has one (it's `get_rotation_maps()`).

**Why:** The mode is the biggest choice of a match, so it comes first and decides what "Match length" means. A separate Maps row keeps the map list honest (every scene on disk, as M5 built and tested it) and gives the rotation a clear on/off. A fixed order is what CoD playlists feel like when you stay in a lobby, and starting on the chosen map lets you pick where to begin. "Next map" on the end screen is the moment you'd move on, and it keeps the game in one scene, so the HUD, settings and console stay as they are.

**Checked:** a new `tests/rotation_test.tscn` (13 checks): the rows and their defaults; team respawn switching the length to kills (50, then 75), the summary and the rules Start builds; the rotation's order from the test map and from Square, and its summary; what Start leaves for the game; and in the real game scene: a rotation starting on Depot with "Next map: Square" ready, the button shown and focused after the match, Next map giving a fresh match on Square, Play again staying, the wrap from Spillway to Depot, team respawn kept across maps, and no button without a rotation. M5's settings test lists the three new settings. All seventeen suites pass.

**Alternatives:** "Rotation" as an entry in the map list (one control, but the list would no longer be the maps on disk); a random order or a shuffled playlist (less predictable when you want to learn the maps); a map vote at the end of a match (the backlog's "map voting"); putting the test map in the rotation (it has no bomb sites or respawn zones of its own); moving on automatically after a few seconds, like CoD's lobby countdown (you'd lose the end screen while reading it).

## D-090 — The M7 plan: pickups first, a light economy, a fresh loadout every round (2026-10-15, revised 2026-10-16) — *provisional*

**Decision** (the open choices of the M7 plan; the PLAN.md table has them side by side). Revised on 2026-10-16 after your answers: "I would build it around picking up weapons pretty much, more like combination of cs and call of duty", "light economy + pickups", "fresh loadout every round", "but economy has to be there".
- **Weapon names**, provisional: **Ram** (AK-style rifle), **Warden** (carbine), **Hornet** (SMG), **Breaker** (pump shotgun), **Heron** (sniper rifle), **Sparrow** (service pistol), **Verdict** (hand cannon), **Knife**, **Frag**, **Flashbang**, **Smoke**. Files, ids and code use the weapon's role (`rifle`, `carbine`, `smg`, `shotgun`, `sniper`, `pistol`, `hand_cannon`, `knife`, `frag`, `flashbang`, `smoke`); only `display_name` in the data files carries the name. "Confirm weapon names" is in your open checks.
- **A fresh loadout every round** (bomb rounds), like CoD's Search & Destroy: at each round start everyone has the knife and the Sparrow and nothing else. Bought and picked-up guns, armor, grenades and kits last one round. Money carries over.
- **A light economy, round numbers:** $1,000 at the start of each half, $10,000 at most. Win $3,000. Loss $1,500, then $2,000, $2,500 and $3,000 for losses in a row; a win starts the count again. $200 a kill, $500 with the knife, −$200 for a teamkill. A plant gives every attacker $200, win or lose; a defuse gives the defuser $200.
- **Round prices by tier:** Verdict $500; Hornet and Breaker $1,000; Ram and Warden $2,500; Heron $4,000; Sparrow $200 (only if you lost yours); vest $500, vest and helmet $800; defuse kit $300 (defenders only); Frag $300, Flashbang $200, Smoke $300.
- **Buying happens in the freeze time** (15 s), when everyone stands at their spawn, so there is no buy zone. The round manager decides every purchase.
- **Pickups:** the dead drop their best gun (the primary, else the pistol; grenades and kits are lost), which lies on the floor with its ammo for the rest of the round; walking over a gun takes it into a free slot, E while looking at it swaps it for the gun in that slot, G drops the gun you hold. Floor guns vanish at the next round start.
- **Power weapons:** each quick map gets two marked spots in contested places, a Heron and a Breaker on a glowing floor ring, back at every round start (in team respawn 30 s after being taken).
- **Revised again on 2026-10-16 (D-120):** the power-weapon spots became **random map weapons** (D-098, "Random map weapons"), and each match **drafts two classes** for you (D-099, "Class draft"). Team Deathmatch (team respawn) is the primary mode, so its loadout and pickups got their own task (M7 task 18).
- **Team respawn has no money and no buy menu:** you spawn with your class's loadout: its signature gun (Rifleman: Ram, Bulwark: Breaker, Marksman: Heron, Scout: Hornet), the Sparrow, the knife and one grenade. Pickups and power weapons as in rounds. The class menu (M) works any time there, and the new class's loadout comes with your next respawn.
- **Practice mode:** your class's loadout, and the buy menu gives anything for free, any time.
- **Models:** one generated model per weapon serves on the floor, in the third-person hand and in first person; the generator also renders the buy-menu and kill-feed icons (headless, in Python).
- **The bomb stays on Use** (hold E, D-080); there is no slot 5.
- **Grenades:** CS's limits (1 frag, 2 flashbangs, 1 smoke); left click throws, right click lobs; a flashbang blinds everyone who looks toward it, teammates too.
- **The Bulwark's *Plated*:** while its armor lasts, every hit does 10% less to health and wears the armor 30% less (D-052's text).

**Why:** Your answers: weapons should mostly come from picking them up, as in Call of Duty, with a light economy that still matters, and a fresh loadout every round. With nothing carried over, money is the only thing a round leaves behind, so the spend-or-save choice stays real every freeze time: a full buy ($3,600) costs more than a win pays, a losing team has to save, buy cheap or take guns off the floor, and the growing loss money brings it back. Round numbers by tier are easy to read and remember. Dropped guns reward winning a fight on the spot, and power weapons on the maps give each map a couple of points worth fighting for, like CoD's. Buying only in freeze time needs no buy zones on maps that are still blockouts. In team respawn there is nothing to save for, so the class becomes the loadout, which also gives the bots variety. One model per weapon is enough at our polygon count, and rendering icons in Python avoids a window popping up for a Godot render.

**Alternatives:** The first version of this plan (2026-10-15): CS2's economy ($800 start, $16,000 cap, $3,250 wins, $1,400–$3,400 losses, a kill reward per weapon), survivors keeping their gear, buying for 10 s into the round near your spawn, and a free loadout picker in team respawn. Also: CS's exact prices; dropped guns only, with no power weapons; a CoD-style loadout editor; everything dropping on death like CS; CS's bomb slot (5 and fire); one grenade of any kind; the Bulwark's perk only on armored zones; separate first-person models and icons rendered in Godot through a `SubViewport`.

## D-091 — The arsenal's numbers: one data file per weapon, CS's values, a table exported from them (2026-10-15) — *provisional*

**Decision:**
- **One `WeaponData` file per weapon** in `weapons/`, named after its role (`rifle.tres`, `carbine.tres`...), listed in buy-menu order in `WeaponData.PATHS` (`WeaponData.all()`, `find(id)`). New fields: `id`, `slot` (primary, pistol, knife, grenade), `category` (rifle, SMG, shotgun, sniper, pistol, knife, grenade: buy-menu category, how bots use it), `hold` (rifle, pistol, knife, grenade: animations), `draw_time`, `price`, `kill_reward`, `armor_penetration`, `pellets` and `pellet_spread` (shotgun), shell-by-shell reloads, a `Scope` group (zoom levels, scoped accuracy, scope-in and recovery times, scoped speed, unscope after a shot), a `Melee` group (slash and stab reach, damage and backstab damage) and a `Grenade` group (projectile scene, how many you can carry, throw and lob speeds), plus the generated `model`, `muzzle_point` and the two icons.
- **CS's numbers as the starting point** (GAME_DESIGN 4.3 has the table): the Ram keeps the M2 rifle's numbers and gets the AK's price ($2,700) and armor penetration (77.5%); the Warden is the M4A4 (33 damage, 70%, 666 rounds a minute, 225 u/s, $3,100); the Hornet an MP9 ($1,250, $600 a kill); the Breaker a Nova (9 pellets of 26, $900 a kill); the Heron an AWP (115 damage, 97.5%, 100 u/s scoped, $4,750, $100 a kill); the Sparrow a cross of the Glock and the USP (32 damage, 15 rounds); the Verdict a Desert Eagle (63 damage, 93.2%); the knife CS:GO's (slash 40, stab 65, backstabs 90 and 180, $1,500 a kill); the grenades CS's prices (Frag $300 with 98 damage, Flashbang $200, Smoke $300). Spray patterns for the new automatic guns are derived from the approved rifle pattern (the Warden's climbs 78% as high and sways the other way; the Hornet's climbs 3.6°, then wobbles).
- **Draw times are new numbers, not CS's:** 0.5 s (knife, grenades) to 1.15 s (Heron), rifles 0.95 s. They make switching to the pistol faster than reloading a rifle, as in CS.
- **The balancing table is exported, never typed:** `tools/export_weapon_table.gd` writes `docs/weapons.csv` from the data files (`WeaponTable` in `tools/weapon_table.gd`), with the derived columns computed by the game's own armor rule (`Armor`, D-093): body damage, damage per second, shots to kill with and without armor, time to kill through armor, and whether one headshot kills with and without a helmet, at 10 and 30 m, plus kill reward per dollar. `tests/arsenal_test.tscn` fails while the committed CSV differs from what the data gives, so the spreadsheet can't go stale. A `docs/weapons.csv.import` with the importer "keep" stops Godot from importing the CSV as a translation table (its default for `.csv`).

**Why:** A data file per weapon is the M2 decision (D-019's `WeaponData`) carried through, and naming files by role keeps the provisional names (D-090) out of paths and code. CS's numbers are the ones you know and are balanced against each other already: the AK-vs-M4 trade (one-tap through a helmet vs. accuracy and speed), cheap guns with high kill rewards for anti-ecos, an expensive sniper that pays little. Exporting the table instead of keeping a spreadsheet by hand is the only way it stays true while the numbers get tuned.

**Checked:** the new `tests/arsenal_test.tscn` (28 checks): every file loads with its id, slots and categories, sane values for every gun, the rifle's M2 numbers and pattern unchanged, CS's armor results (the Ram's headshot kills through a helmet and the Warden's doesn't; the Verdict's does; the Sparrow's kills only without one; the Heron kills through armor with a body shot; armor wear and armor giving out; the Bulwark's factors), the table's shots-to-kill matching `Armor.hits_to_kill`, and the CSV up to date. All other suites unchanged.

*Prices and kill rewards were replaced by the light economy's round numbers on 2026-10-16 (D-090); the other numbers stand.*

**Alternatives:** Keeping the stats in one big table resource or a spreadsheet the game reads (one file to edit, but a spreadsheet can't hold models, sounds and patterns, and Godot imports CSVs as translations); a hand-kept spreadsheet (drifts); CS's exact deploy times (not all known, and our quick maps favour fast switches); new spray patterns from scratch (the rifle's is approved and learnable).

## D-093 — Armor: CS:GO's rule in one place, the helmet only with armor, the bomb ignores it (2026-10-16) — *provisional*

**Decision:**
- **CS:GO's rule** (`Armor`, `characters/armor.gd`, static so tools and tests use it too): Kevlar covers the chest, stomach and arms, the helmet the head, the legs never; on a covered hit `armor_penetration` of the damage reaches health and the armor loses half of the rest (`WEAR_PER_DAMAGE` 0.5); when the armor left can't stop that much, each point stops two and the rest goes through. Armor at 0 protects nothing and the helmet is lost with it.
- **Applied in `Character.take_damage()`**, after friendly fire and before health: new parameters `armor_penetration` (default 1.0: armor doesn't help) and `source` (the `WeaponData` that hit). `Character.armor`, `has_helmet`, `has_defuse_kit`, `set_armor()`, `set_defuse_kit()`, signal `gear_changed`, and `last_damage_source` (set before `damaged` and `died` are emitted, so the round manager and the kill feed can read which weapon got a kill). Dying clears armor, helmet and kit.
- **Hit zones pass the weapon on:** `Hitbox.receive_hit()` takes the weapon's data and its `hit` signal carries the penetration and the weapon (the target dummy's listener takes them too).
- **The bomb's blast ignores armor** (it hits with penetration 1.0, so D-080's lethal distances stay true for everyone); the Bulwark's 10% still applies while it wears armor.
- **The Bulwark's Plated perk is on:** `ClassData.armor_damage_factor` (0.9) scales the health damage of every hit while armor lasts, `armor_wear_factor` (0.7) the wear (D-090).
- **HUD:** the armor number right of the health, with a pixel-art shield drawn in code (`ArmorIcon`, an "H" on it with a helmet, dimmed at 0), scaled with the HUD like the labels. Console: `armor [0-100] [helmet]`.

**Why:** The rule is CS's, so the AK-vs-M4 helmet trade and armor's value carry over as you know them. One static function used by the game and the balancing table keeps the spreadsheet honest. Passing the weapon with the hit, rather than through new signal arguments on `Character`, kept every existing listener of `damaged` and `died` working. A shield drawn in code needs no font glyph (Silkscreen has none) and stays crisp at every scale.

**Checked:** a new `tests/gear_test.tscn` (13 checks): the chest, legs, head with and without a helmet (Warden vs. Ram), armor giving out, the Bulwark with and without armor, the bomb's blast, death clearing the gear, a real bullet passing its weapon on, the HUD (dimmed at 0, helmet mark, wearing down, scaling) and the console command in the real game scene. All other suites pass.

**Alternatives:** CS 1.6's armor values (the same idea with different ratios); armor that also reduces the bomb's blast (CS does, but then D-080's distances would depend on gear); the helmet staying after the armor is gone; a text label ("ARMOR 100") instead of an icon.

## D-094 — Weapons in slots: an Inventory node, switching by command, guns on the floor, loadouts from the rules (2026-10-16) — *provisional*

**Decision:**
- **An `Inventory` child node per character** carries the weapons: a primary, a pistol, the knife and grenades (one node per kind; its magazine is how many you carry: 1 frag, 2 flashbangs, 1 smoke, 4 in all). Every carried weapon is a `Weapon` node made with `Weapon.create(data)` from the generic `weapons/weapon.tscn`, hung where the scene's own weapon hangs (the player's camera, a bot's head). `Character.weapon` stays "the weapon in hand", so all the code that shoots, aims and reads ammo keeps working; `Character.weapon_changed` tells the HUD, the body and the bot brain to follow a switch. Weapons not in hand are hidden and don't process.
- **Switching is a command:** `CharacterInput.weapon_slot` (keys 1–4; 4 again cycles the grenades), `last_weapon` (Q), `drop` (G) and a fresh press of `use` (E: swap for the gun on the floor you look at, within 2.4 m and 20°). The `Inventory` follows them in the character's tick, so bots and network players switch by the same rules. A switch puts the old weapon away (its reload is lost, as in CS) and the new one can't fire for its draw time (D-091), 15% shorter for the Rifleman (*Quick Hands*, `weapon_switch_time_factor`).
- **Guns on the floor are `WeaponPickup` nodes** (group `weapon_pickups`) holding the data and the ammo: no collision, only the model lying on its side, falling to the floor where it was dropped. Walking over one (within 0.9 m) takes it into a free slot without taking it out; a full slot needs E, which drops yours in its place and puts the new one in your hands (Call of Duty's swap). A gun you dropped ignores you for 1 s. The dead drop their best gun (primary, else pistol) a moment after dying (deferred, so the hit that killed them is fully dealt with first).
- **Loadouts come from the rules:** the `RoundManager` gives everyone `MatchSettings.round_loadout` (the knife and the Sparrow) at every round start, takes away armor and kit, and clears the floor (D-090's fresh loadout); the `RespawnMatch` and practice's `ArenaRules` give each class its `ClassData.loadout` (signature gun, Sparrow, knife, a grenade) at every spawn. A map without rules keeps the scene's rifle.
- **The HUD** follows the weapon in hand (ammo, name; nothing for the knife, "× n" for a grenade) and shows a slot list for 2.5 s after any change, the held weapon marked "»", like CS's weapon list. The body holds the held weapon's own model on its weapon bone.
- **Bots fire semi-automatic weapons by letting go every other tick**, so the pistols work for them; everything else about using the arsenal comes in task 14.
- The developer console shows 24 lines (was 18), so `help` still fits with the new commands.

**Why:** Keeping `Character.weapon` as the weapon in hand changed the fewest lines in code that took M2–M6 to get right; an inventory beside it, rather than a weapon class hierarchy, keeps every gun a data file (D-091). Commands for switching and dropping are the M4 rule (D-034) that bots and M9's network players must follow. Pickups without physics can't block a doorway or eat a bullet, and walking-over plus E is what both CS and CoD players expect. Loadouts in the rules keep authority where it belongs (the host in M9).

**Checked:** `tests/gear_test.tscn` grew from 13 to 31 checks: what fits in which slot, hidden idle weapons, key 2 drawing the pistol (no shot during its draw time, then one), the Rifleman's shorter draw, Q, 4 cycling the grenades, 3 the knife, G dropping the rifle with its ammo onto the floor, the dropper's one-second wait, walking over a gun, a full slot ignoring it and E swapping, the best gun dropping on death, a body holding the model in hand, the HUD following the weapon (ammo, name, slot list fading), and the loadouts of a round (fresh every round, armor and floor cleared), team respawn (by class) and practice. The maps test now measures first contact with the Ram (everyone had a rifle when D-061's rule was set; with M7's faster pistol rounds the median was 4.9 s instead of 5). All suites pass.

**Team Deathmatch's pickups** (task 18, D-120: Team Deathmatch is the primary mode):
- **Scavenging, as in CoD:** walking over a dropped gun of a kind you already carry takes its ammo into your reserve, up to the gun's full reserve (its reserve first, then its magazine); a gun left with no ammo goes away (`Inventory.scavenge()`, signal `ammo_scavenged`). Never from a map weapon, which is there to be taken. In every mode, for you and the bots alike.
- **Dropped guns go after 30 s in Team Deathmatch** (`RespawnMatch.DROPPED_GUN_LIFETIME`, counted by `WeaponPickup.age`): ten minutes of deaths would otherwise cover the map. Map weapons stay; rounds clear the floor at every round start as before.
- **The respawn loadout** already comes out ready: the class's signature gun in hand, drawn at once (`set_loadout()` holds the best weapon with no draw time).

**Why (task 18):** In Team Deathmatch you live for half a minute and run dry fast; scavenging is how CoD keeps a fight going without a buy menu, and it costs nothing in rounds (a CS player rarely walks over the gun they carry). The 30 s keeps the floor readable without taking a gun from under a fight.

**Checked (task 18):** 3 gear checks: all 45 rounds taken and the empty gun gone, then just the 15 that fit; a map weapon of the same kind left alone; Team Deathmatch taking away a 30 s old gun and keeping a newer one and the map weapons.

**Alternatives:** One weapon node that swaps its data (cheaper, but ammo and recoil state per gun would need bookkeeping, and pickups would have to rebuild it); a weapon subclass per kind (the knife and grenades still get their own behaviour in tasks 6 and 8, as branches on the data); physics pickups (rigid bodies that tumble and bounce: nicer, but they block and need syncing in M9); auto-switching to a picked-up gun (CS doesn't; CoD's swap does, which E keeps); keeping the console at 18 lines (help would no longer fit on one screen).

## D-092 — The arsenal's models and icons from the generator (2026-10-16) — *provisional*

**Decision:**
- **Every weapon is a part list in `tools/modelgen/weapons.py`**, built like the AK (D-075) in weapon space: the Ram (the AK, renamed `rifle`, byte-identical), the Warden (an M4-like carbine with black furniture and a telescoping stock), the Hornet (a boxy SMG with the magazine in the grip and a vertical foregrip), the Breaker (a wooden pump shotgun with a tube magazine), the Heron (an olive thumbhole sniper rifle with a big scope, bolt and folded bipod), the Sparrow (a polymer service pistol), the Verdict (a chunky hand cannon), the knife, the three grenades (a round olive frag, a light grey flashbang with a dark band, a dark smoke can with vents) and the defuse kit. 180–592 triangles each. Each names the points the animations need (`foregrip`, `magazine`, `handle`, `muzzle`, `butt`; the knife's `tip`; the grenades' `pin` and `lever`). `modelgen.py weapons` writes them to `assets/models/weapons/`.
- **One model per weapon, three uses** (D-090): `WeaponData.model` is the first-person gun on the arms, the gun on a body's weapon bone (`CrewBody` shows the held weapon's) and the gun lying on the floor (`WeaponPickup`).
- **Icons rendered by the generator** (`tools/modelgen/icons.py`, numpy and Pillow, headless): a 128 × 48 shaded side view with a dark outline for the buy menu (up to 150 px per metre, so a pistol stays smaller than a rifle; 300 for grenades and gear, which would otherwise be a few pixels), and a 16 px tall white silhouette for the kill feed. Also icons for the vest, the vest with a helmet and the kit.
- **The kill feed shows the killing weapon's icon** between the names, like CS (the victim's `last_damage_source`, D-093); a death without a known weapon keeps the ">".

**Why:** The generator was built for this (D-054): the arsenal stays consistent with the crew's look and a gun changes with a number. One model for all three uses is enough at this polygon count and keeps pickups recognisable from the hands. Rendering icons in Python needs no window (a Godot `SubViewport` render does), and silhouettes are what CS's kill feed uses because they read at a glance.

**Checked:** both contact sheets (side and top views, all icons) looked at: every gun is recognisable by its silhouette. The new rifle mesh and texture are byte-identical to the old AK, and the crew files still regenerate byte for byte. Two new arsenal checks (every weapon has its model and both icons at the right sizes; muzzles in front; the kit and gear icons exist) and a kill-feed check in the gear test. All other suites pass.

**Alternatives:** Separate detailed first-person models (more polygons where they're seen closest; later, if the hands-on look asks for it); icons rendered by Godot through a `SubViewport` in a windowed tool run; text names in the kill feed instead of icons.

## D-095 — How each weapon works: pellets, shell reloads, a CS-style scope, a CS-style knife, perks through the holder (2026-10-16) — *provisional*

**Decision:**
- **Branches on the data, not subclasses** (D-094): one `Weapon` script fires `WeaponData.pellets` hitscan rays per shot (each with its own spread, uniform over a `pellet_spread` cone), reloads `reload_per_shell` guns one shell at a time (fire with a shell in stops the reload), steps a scope through `zoom_levels`, and attacks with the knife when the data has a `melee_range`.
- **Semi-automatic weapons** (pistols, the shotgun, the sniper rifle) need the trigger let go between shots, as since M2. A switch no longer counts as a click: holding fire through a draw fires once the draw ends.
- **The scope is CS's AWP:** the aim button (a fresh press: `Weapon.aim_held` from `CharacterInput.aim`) steps 0 → 1 → 2 → 0; zooming in from out restarts a 0.3 s scope-in during which the cone blends from 4° to 0.02° (two thirds crouched); the moving penalty is remembered and wears off over 0.35 s after you stop (`scoped_recovery_time`), so a scoped shot needs a moment of standing still; scoped speed is 100 u/s; a shot drops you out of the scope and you go back in once the next shot is ready; a reload or a switch drops out too. The camera narrows to the zoom step's fraction of your field of view, the mouse slows by the ratio of the half-angles' tangents (CS's `zoom_sensitivity_ratio 1`), the viewmodel hides, and the HUD draws a scope view (`ScopeOverlay`). With the Heron in hand there is no crosshair at all, scoped or not, as in CS.
- **The knife is CS:GO's:** slash 40 every 0.4 s within 1.5 m, stab 65 every second within 1.1 m, 90 and 180 when the victim faces away (more than 60° away from you); flat damage on every zone (the hit-zone multiplier is divided out), 85% through armor. The trace is a small fan of five rays (3° apart) that prefers a hit zone over a wall, so it forgives a little like CS's hull trace. It makes no noise for bots.
- **Perks through the holder:** `Weapon._class_factor()` reads the holder's `ClassData`: the Rifleman's `reload_time_factor` (0.85, also the shotgun's shells and the animations' speed), the Marksman's `scope_in_time_factor` (0.8) and `scoped_recovery_factor` (1.3: recovers 30% faster). The Rifleman's switch factor came with D-094.
- **The weapon test's player is a Scout** now, so the rifle's M2 numbers (2.5 s reload) are measured without the Rifleman's perk.
- **Every gun sounds like itself** (22 new generated sounds, D-020/D-084's way, written by a Sonnet subagent and measured, not heard): a light snappy Sparrow, a booming Verdict, a small rattling Hornet, a tighter Warden, a wide long Breaker blast, the loudest Heron crack with a long echo; the Breaker's pump and the Heron's bolt play a moment after each shot (`WeaponData.cycle_sound`), shells click in one by one, the knife whooshes and thuds. The grenades' and the buy menu's sounds are made too, for tasks 8 and 11. Existing sounds are byte-identical.

**Why:** CS's rules for these weapons are what players expect: the AWP's scope-in delay and stand-still accuracy are what make a sniper a commitment, the shotgun's shell reload is its weakness, and the knife's flat damage and backstabs are its whole design. Doing it as branches keeps every gun one data file. Scaling sensitivity by tangents keeps flicks consistent when zoomed. Perks as factors read by the weapon keep the class data the only place their numbers live.

**Checked:** a new `tests/guns_test.tscn` (16 checks): one pistol shot per click; nine pellets inside the Breaker's cone, a kill at 5 m and not at 25 m; shells one by one and fire stopping the reload; the Rifleman's 2.125 s reload against the Scout's 2.5 s; the scope's steps and camera, the mouse ratio (0.364 at the first step), 4° unscoped, 0.02° after scoping in, 100 u/s, the accuracy recovering only over its time after moving; the Marksman's 0.234 s scope-in and 0.273 s recovery against the Scout's 0.297 s and 0.352 s; out of the scope after a shot and back once the bolt is worked; the HUD's scope view and no crosshair; the knife's 40 and 65 on any zone, 55.25 through armor, 90 and a kill from behind, nothing beyond its reach. All other suites pass.

**Alternatives:** A weapon subclass per kind (`Shotgun extends Weapon`...: cleaner code per kind, but pickups and data would need to know the classes); AWP-style accuracy without a scope-in delay (simpler, but the sniper becomes a quick-scope cannon); keeping a crosshair for the sniper unscoped (friendlier, not CS); a knife hitting with one ray (less forgiving than CS's hull); headshot multipliers on the knife (not CS).

## D-096 — Holds and animations: nine animation sets solved by the generator, one graph that switches by the held weapon (2026-10-16) — *provisional*

**Decision:**
- **Animation sets** (`tools/modelgen/holds.py`): every weapon belongs to one, by `WeaponData.anim_set` (its id when empty): the five long guns each have their own (`rifle`, `carbine`, `smg`, `shotgun`, `sniper`: the same rifle hold, solved around each gun's own foregrip, magazine and handle), the pistols theirs (`pistol`, `hand_cannon`: both hands out in front, isosceles), the `knife` one-handed low with the blade up and the left hand on guard, and one `grenade` set for all three, held at the chest.
- **The body** (`anims.set_clips()`): five aim poses per set (−80° to 80°), a reload per gun (all 2.5 s long, stretched to the weapon's time like the AK's: the pistols drop the magazine and rack the slide; the Breaker loads a shell at a time with `reload_shell`), an additive pistol kick (`fire_pistol`), the knife's slash and stab, a grenade throw and lob: 52 clips more per class, 93 in all. The legs never change: the graph only takes the upper body from them.
- **The first-person arms** (`fparms.set_clips()`): idle, draw, fire and reload for every gun around its own points (`fp_<set>_<action>`; the rifle keeps `fp_<action>`); the Breaker pumps after a shot and has a clip per shell, the Heron's left hand works the bolt after each shot; pistols are held two-handed lower in the middle; the knife slashes across and thrusts; a grenade's pin is pulled by the left hand before a throw or a lob. 38 clips per class. The weapon stretches a clip to its draw or reload time (for this holder, so Quick Hands shows).
- **The graph** (`tools/make_crew_animation_tree.gd`): the aim blend became `Hold`, a transition over nine `Aim_<set>` blends (0.15 s cross-fade); `Fire` plays `FireKind` (the rifle's or the pistol's kick), a new filtered one-shot `Attack` plays `AttackKind` (slash, stab, throw, lob), and `Reload` plays `ReloadKind` (one reload per gun and the shell). `CrewBody` sets them on every switch (`Character.weapon_changed`), plays the attack from `Weapon.last_attack`, and a shell on `Weapon.shell_loading`.
- **Models that aren't held by a pistol grip** get `WeaponData.hold_offset`: the knife turned 72° so its blade runs up along the fist, a grenade moved into the palm (the same numbers as `holds.HOLD_OFFSETS`, which the solver uses for the pin).

**Why:** The M6 solver already places hands on any gun from its points (D-075), so a new weapon costs a part list and a set entry, not keyframes; per-gun sets keep the left hand on each gun's own foregrip. One shared graph with transitions keeps the M6 rule of one generated graph (D-076) and keeps the hit zones following the same skeleton. Stretching every reload to the weapon's time keeps the animation in step with the rules whatever the numbers become.

**Checked:** stick-figure renders of the new poses (side and front): pistols out in front with the left hand on the support point (0 cm off), the knife low with the blade up, the slash crossing, the throw going back and over, the long guns' left hands on their own foregrips. Five new crew checks: the pistol's hold, kick and reload on the body and arms (stretched to the reload time), the knife's hold, slash, stab and hold offset in both views, the grenade hold, the Breaker's first shell and following shells, and every class's 38 arm clips; the class check now counts 93 body clips. All 20 suites pass.

*Fixed in task 15:* the knife's `hold_offset` had been written as columns, which Godot's text format reads as rows, so the blade pointed down; the knife and grenades also sat too low in first person (now at (0.15, −0.15, −0.38) and (0.15, −0.14, −0.36)). Found on screenshots.

**Alternatives:** One rifle hold for everything (pistols and knives held like rifles); keyframing clips by hand per weapon (a lot of work, and they'd drift from the solver's); a separate AnimationTree per hold (nine graphs to keep in step); detaching the gun from the right hand for bolt and pump actions, as real viewmodels do (the gun hangs on the hand bone here, so the left hand works them).

## D-097 — Grenades: CS's three, thrown by rays, flashes that blind bots too, smoke that hides from bots (2026-10-16) — *provisional*

**Decision:**
- **Throwing** (in `Weapon`, a branch on grenade data): fire or aim pulls the pin (0.3 s); letting go throws (fire: 15 m/s) or lobs (aim: 7 m/s) at CS's angle (10° above a level view, scaled toward straight up or down) plus 1.25 times the thrower's velocity, from 0.4 m in front of the eyes (pulled back before a wall). After 0.45 s the next grenade of the kind comes out, or after the last one the weapon held before (`Inventory.remove(weapon, true)`). Switching away with the pin pulled puts it back. The body plays its throw or lob, the hand is empty until the next draw.
- **Flight** (`Grenade`): gravity 0.4 × 800 units/s² as in CS, a ray along each tick's move against the world and characters (not the thrower for 0.25 s), a bounce keeping 45% of the speed into the surface and 75% along it, resting on a floor below 0.25 m/s. Deterministic: no rigid body.
- **Frag:** 1.6 s fuse; 98 damage falling off as a bell curve (σ 3 m, nothing past 9 m), measured to the chest; it needs a clear line to the chest or head (walls stop it, partly covered still counts); 57.5% through armor; the thrower's kill (`Character.take_damage()` with the frag as source). It can't kill a full-health player alone, as in CS.
- **Flashbang:** 1.6 s fuse; everyone with a clear line within 45 m (teammates and the thrower too) gets up to 4.5 s, the last 2 s fading (`Character.flash()`, `get_flash_alpha()`; a stronger flash replaces a weaker one); strength by facing (full within about 45° of the view, down to 0.35 at 90°, 0.2 behind) times distance (full to 8 m, 0.35 at 45 m). The HUD whites out the view (also a spectated teammate's) and the player's ears ring; a bot that is more than half blind sees nobody (`BotSenses.can_see()`).
- **Smoke:** pops once resting (after at least 1 s, at the latest 3.5 s) into a `SmokeCloud`: 14 low-poly grey puffs, growing over 1.2 s, gone after 18 s with the last 2 s thinning out. It blocks the bots' lines of sight through an ellipsoid 6.8 × 4 m (`Smokes.blocks()`), greys a camera inside it (`Smokes.density_at()`, the HUD's smoke overlay), and lets bullets through.
- **Effects** (`Explosion`): a light and a swelling fireball, `GPUParticles3D` debris and a dark puff for the frag, a white burst for the flash; the generated sounds (pin, throw, bounce, explosion, pop, hiss, ringing).

**Why:** CS's numbers and rules are what make utility worth its money: a frag that can't kill alone but finishes a fight, a flash that punishes looking at it and can blind your own team, a smoke that cuts a sightline for 18 s. Flight by rays gives the same bounce every time, for tests and M9's host. Blinding bots through the same `can_see()` keeps them fair (they're flashed exactly when a player would be), and the smoke check sits in that one place too.

**Checked:** a new `tests/grenade_test.tscn` (14 checks): the pin held while fire is held, a throw at 15 m/s and 10°, the last frag giving way to the rifle, a lob at 7 m/s with the second flashbang coming out, a switch putting a primed grenade back; a bounce and rest on the floor and a bounce off a wall; a hurt player killed next to a frag, the falloff at 4 m and nothing at 11 m, armor's share and a wall stopping the blast, the thrower's kill; a flash's strength facing it (1.0), looking away (0.2) and at 38 m (0.47), nothing behind a wall, the player's screen white and a bot blind, both wearing off; a smoke hiding an enemy from a bot, a clear line beside it, grey inside it, gone after 18 s. All other suites pass.

**Fix (task 18):** a frozen character (freeze time, the match end, planting or defusing) could still stab with the knife or lob a grenade, since freezing cleared only fire. `Character` now clears aim as well while frozen or busy, except for a scoped gun (zooming in freeze time is fine, as in CS). Found by the match suite's frozen-at-the-end check, which now compares rounds left in all (a reload only moves them into the magazine); 1 new guns check.

**Alternatives:** Rigid-body grenades (Jolt does the bounce, but not the same way twice); damage through walls with a falloff (CS's HE is mostly stopped by walls); flashes that spare the thrower's team (CS doesn't); a volumetric fog smoke (`FogVolume`: prettier, but needs volumetric fog in every map's environment and costs more); bullets stopped by smoke (not CS).

## D-098 — Map weapons, the light economy and the buy menu (2026-10-16, map weapons revised the same day) — *provisional*

**Random map weapons** (task 16, replacing task 9's fixed spots below). Your direction: "the arsenal spawned on map, not buyable should be random (not on spawns of course, but not always on the same place".
- **Where:** `MapWeapons` (`systems/map_weapons.gd`, a child of the round manager) picks places at runtime from the map's navmesh: a random point on the walkable floor (every square metre as likely), on the navmesh islands the spawn markers stand on (the navmesh also covers roofs nobody can reach), at least **15 m** (flat) from every team spawn, off the bomb sites (a 2 m margin) in bomb rounds, at least **8 m** from every respawn point in Team Deathmatch, **15 m** apart, and with **0.8 m** of room to the nearest wall or crate (a sphere query from knee to head height; task 19's screenshots showed a ring running into a wall). On a crowded map the spacing between guns gives way first, then the other distances, 30% at a time. No markers in the map files, so the map-kit maps (M10) get map weapons without any work.
- **Which gun:** a weighted draw (`pool`): Hornet 30, Warden 20, Ram 15, Breaker 15, Verdict 10, Heron 10; never two of the same at once.
- **When:** rounds: **two** new ones every round start (`MatchSettings.map_weapons`), the old ones gone, none replaced during the round. Team Deathmatch: **three** out at a time (`respawn_map_weapons`), a taken one replaced somewhere else **20 s** later (`map_weapon_replace_time`). Practice has none.
- **How it looks:** the `WeaponSpot` of task 9 (the gun floating and turning over a gold ring, its name above, now half as big again so it reads at a few metres), plus a thin beam of light rising from above the name (1.8 to 4.6 m, so it never hides the gun), so you can spot it from across the map. Once its gun is taken it emits `taken` and goes away.
- **Seeded:** every draw comes from a generator seeded from the round manager's `rng` (its seed + 7919), so tests repeat and placing guns doesn't change the spawn spots a seed gives.

**Why (random map weapons):** your words, and the coordinating session's brief (never near spawns, from the navmesh at runtime, a weighted pool, easy to spot). Sampling the navmesh needs nothing from the maps, and the island filter keeps guns off roofs without a path query (the navigation server isn't ready in the first frames of a map). 15 m from spawns keeps a gun from being free loot at the start; 8 m from respawn points is the most the Team Deathmatch maps allow with 12 points in four zones (about a fifth of the floor is that far from every one). The pool makes the Hornet common and the Heron rare, so a sniper on the map is an event. A beam reads at a distance even in pixels.

**Checked (random map weapons):** gear checks (a spot floats a Heron with a beam, a walk over takes it and the spot goes; a round puts two out at least 15 m from the spawns; a taken one isn't replaced in the round and the next round's two are elsewhere; Team Deathmatch keeps three out and replaces a taken one somewhere else) and two maps checks per map (twenty rounds of draws: always two, reachable from a spawn by a navigation path, 15 m from the spawns and each other, off the sites, at 30+ different places, the Hornet more often than the Heron; Team Deathmatch's three 8 m from every respawn point).

**Power weapons** (task 9, *replaced by the random map weapons above*):
- **Two spots per quick map**, a Heron and a Breaker (`weapons/weapon_spot.tscn`, group `weapon_spots`, under each map's `Pickups` node): a gold glowing ring, the weapon's name above it, and the gun floating and turning over it (a `WeaponPickup` with `floating` on). Taking it is the same as any gun on the floor (walk over it into a free slot, E to swap); the ring dims and the name hides while it's empty.
- **When they come back:** in rounds the `RoundManager` refills every spot at each round start (`_refill_spots()`; floor guns are cleared but spot guns stay); in team respawn (`RespawnMatch._spots_timed()`) and practice a spot comes back 30 s after being taken.
- **Where:** in different lanes, on patrol points (on the navmesh), chosen by walking distance so both teams reach them about as fast (MAPS.md has the table; within 9 m on every map).

**Why:** Your "built around picking up weapons, CS and CoD": fixed power-weapon spots are CoD's way of giving a map places worth fighting for, and in rounds they give the losing team a way to a sniper or a shotgun on an eco. Gold keeps them clear of the team colours (D-041) and of the UI's cyan; a floating, turning gun reads at a distance in pixels.

**Checked:** two new gear checks (a spot's gun floats, a walk over takes it, the ring dims and the name hides, it's back after its time; in rounds no timer, but fresh at the next round start) and a maps check per map (a Heron and a Breaker on the navmesh, walks within 12 m of each other). All other suites pass.

**Money** (task 10):
- **In the round manager** (authority, M9's host): `MatchSettings` group *Economy* (`economy`, `start_money` 1,000, `max_money` 10,000, `win_money` 3,000, `loss_money` [1,500, 2,000, 2,500, 3,000], `teamkill_penalty` 200, `plant_money` and `defuse_money` 200); kill rewards come from the weapon (`WeaponData.kill_reward`: $200, the knife $500), read from the victim's `last_damage_source` (D-093). `get_money()`, `add_money()`, `spend()`, `get_loss_money()`, `has_economy()` (off in team respawn), signal `money_changed(character, amount, reason)`. The round is paid when it ends (before `round_ended`'s listeners run); losses count in a row per team and a win clears the count; the start of each half resets everyone to the starting money. A defuse pays the defuser and wins the round, so the round's money comes on top.
- **On screen:** your money above your health ("$ 1000", green), with up to three lines for the last rewards ("+$3000  Round won", "+$200  Kill", fading after 3 s); the Tab scoreboard has a money column for your team (the enemy's stays hidden, as in CS; the match-end screen has none); console `money [amount]`.

**Why (money):** The light economy of D-090: round numbers that are easy to read, and since gear doesn't carry over, money is the only thing a round leaves behind, so every freeze time asks "buy or save?". Clearing the loss count on a win (CS:GO's old rule rather than CS2's step down) keeps it the simplest to explain. Showing every reward line is how CS teaches its economy.

**Checked (money):** a new `tests/economy_test.tscn` (10 checks): $1,000 at the start, $3,000 for a win, $1,500 / $2,000 / $2,500 for losses in a row and the count starting over after a win, $200 for a pistol kill and $500 for a knife kill, −$200 for a teamkill, the plant's and defuse's $200, the $10,000 cap, the reset at half time, no money in team respawn, the HUD's money and reward lines, the scoreboard's money column for your team only, and the console command. All 22 suites pass.

**The buy menu** (task 11):
- **The rules are the round manager's** (`request_buy(character, id)` returns "" or why not; `can_buy_now()`, `get_price()`, `get_buy_refusal()`, `get_buy_time_left()`, signal `item_bought`), the items `Shop`'s (`systems/shop.gd`: every weapon with a price plus the vest, vest and helmet and the defuse kit, in five categories). Buying is allowed in the freeze time only, which becomes **15 s** (team respawn keeps 5 s: `_freeze_time()`); a gun you buy replaces the one in its slot, which drops to the floor (as in CS), and comes out; the helmet costs $300 when you already wear a vest; grenades follow the carry limits. Practice (`ArenaRules`) answers the same questions with everything free, any time; team respawn has no buy menu.
- **The menu** (`ui/buy_menu.tscn`, `BuyMenu`, built by a Sonnet subagent): **B** opens it (rebindable; B from the class menu that opens at the match start switches to it); five columns (Pistols, Mid-tier, Rifles, Gear, Grenades) with each item's icon, key and price, your money and the buy time left at the top, greyed items with the reason as their tooltip, the reason for a refused buy on its last line. Keys like CS 1.6: the category's number, then the item's; or click. It stays open for more buys, closes itself when the round goes live or you die, Esc closes it. On the UI theme, registered with `MenuState`, `UiSounds` ticks plus a generated "bought" and "denied" sound on the Interface bus; the menu and its sounds are `process_mode = Always` like the other menus.

**Why (buy menu):** The authority rule again: the menu asks, the round manager decides (bots will ask the same in task 14). Freeze time only, with no buy zone, is the simplest rule for maps that are still blockouts and has everyone at their spawn anyway. CS's number keys stay, because CS players buy by muscle memory.

**Checked (buy menu):** 11 new economy checks: B opens it in freeze time, every item with its price in five columns, the Verdict bought with keys (the Sparrow on the floor), "Not enough money" for the Ram with a greyed button, a vest, the menu closing itself when the round goes live and B doing nothing then, Esc, the message clearing, B closing it, nothing in team respawn, everything free in practice. Rendered at 1280 × 720 and 1920 × 1080 in the real game.

**Defuse kits** (task 12): defenders buy one for $300 on a map with the bomb (attackers are refused: "Only defenders need a kit"); the round manager fills the bomb's `kit_check` hook (D-080) with `Character.has_defuse_kit`, so a kit defuses in 5 s instead of 10. A white kit icon after your armor on the HUD, "· kit" after the name on your team's Tab scoreboard rows (CS shows teammates' kits). Like everything bought, it lasts one round, and it's lost on death. Checked: 3 economy checks (the purchase and the halved defuse, the attacker's refusal; the HUD and scoreboard; gone next round).

**Alternatives:** Pickups anywhere on a timer like old arena shooters (more chaos, less CS); armor and grenade spots too (could come later); spots only in team respawn (rounds would lose the eco-round fight for a power weapon); a weapon icon over the spot instead of the name (the name reads in the font we have). For the random map weapons: a pool of hand-placed candidate points per map (more control, but every map needs them, and the map-kit session is editing the map files); `NavigationServer3D.map_get_random_point()` (uses the engine's unseeded generator, so tests wouldn't repeat); a path query per candidate to check it's reachable (the navigation map isn't synced when the first round starts); the same gun pool for every map (done; a per-map pool could come with the map kit).

## D-099 — Perks on, the class draft, and bots that choose, buy, pick up and use the arsenal (2026-10-16) — *provisional*

**The class draft** (task 17, D-120): "a class draft: two random classes offered per match".
- **Two classes each:** when the match starts the round manager offers everyone two different random classes (`get_draft(character)`, signal `class_drafted`): you first, then your team's bots, then the enemy's. Every offer includes a class the team doesn't have yet while there is one, and a bot takes whichever of its two its team has fewer of, so a team of up to four is all different classes and bigger teams spread evenly. You start as your first (`MatchSettings.player_class` if set, which then is one of your two).
- **Only your two:** `request_class()` refuses a class you weren't offered (rounds: in freeze time; Team Deathmatch: any time, from the next respawn). The class menu shows your two cards (keys 1 and 2; the other two cards hidden) and says so in its footer; the console's `class` names your draft when refused. Practice keeps all four, any time.
- **Half time:** each bot switches to its other drafted class unless a teammate already plays more of it than of its current one; a switch never adds a duplicate, so a mixed team stays mixed, and most bots play the second half as something else.
- **Seeded** from the class generator (itself seeded from the round manager's `rng`), so tests repeat. `MatchSettings.class_draft` (on) switches it off for M6's rules (any class; bots one of each in turn), which the older class checks use.

**Why (the draft):** your feedback asked for "a bit of randomized thing or luck or choosing", and two cards are the smallest real choice: you still pick, but not always the same class. Guaranteeing a missing class in every offer keeps D-078's promise of a mixed team without taking the choice away. Switching only between your two keeps the draft meaningful across the match.

**Checked (the draft):** 7 new class checks: two different classes for everyone and the signal; three classes per team of three; the menu's two cards and footer and the refusal of an undrafted class; key 3 doing nothing and key 2 taking your other class; seeding; half time (most bots switch, never outside their draft, teams still mixed); Team Deathmatch's draft. The pairs-roaming check of the respawn suite now runs without map weapons (with them, a follower's detours for a gun moved the median).

**Alternatives (the draft):** three classes offered (less of a draft with four classes); a new draft every round (you'd lose a class you like halfway through); bots ignoring the team mix (teams of three Bulwarks); a draft only for you (the bots would feel scripted).


**Perks** (task 13): all four work, each read where its effect happens: the Rifleman's *Quick Hands* in the weapon's reload and the inventory's draw time (D-094, D-095), the Bulwark's *Plated* in `Character.take_damage()` (D-093), the Marksman's *Steady* in the scope (D-095), and now the Scout's *Light Step*: `Character.get_footstep_range()` is 70% of the usual 25 m, for the bots' hearing and the footstep sound's own range alike (the sound fades out where the bots stop hearing it, so hearing stays symmetric apart from this one exception, D-052). The class cards show each class's loadout ("Loadout: Ram, Sparrow, Knife, Frag"), and in team respawn the class menu works any time: a change in the live round waits for your next respawn, which brings that class's loadout (`RespawnMatch.request_class()`, `get_next_class()`). The perk values' group in `ClassData` lost its "applied from M7".

**Why (perks):** The perks were designed in M6 and waited only for armor, scopes and slots. Keeping the Scout's footsteps quieter for players' ears as well as for bots' keeps D-038's promise (what bots hear, you hear). Changing class mid-match in team respawn is CoD's class change, and the next respawn is when a loadout can change without anyone switching guns in a fight.

**Checked (perks):** 3 new class checks (the Scout's 17.5 m against the Rifleman's 25 m; the loadout on the card; a class change in a live team-respawn round waiting for the respawn and bringing the Heron). The other perks have their checks in the guns and gear suites.

**Alternatives (perks):** The Scout's steps quieter only for bots (a hidden advantage you couldn't hear); class changes in team respawn only at the start.

**Bots and the arsenal** (task 14):
- **Buying as a team** (`bots/bot_buyer.gd`, `BotBuyer`, called by the round manager as each freeze time begins; `MatchSettings.bots_buy`, on by default, off in the money tests): the team's plan is a **pistol round** in the first round of each half (the Scout buys a Hornet, the Marksman a Verdict and a vest, the others a vest, plus a grenade with what's left), a **full buy** when the team averages $3,300 (each class's gun: Rifleman the Ram, Bulwark the Ram or half the time the Breaker, Marksman the Heron with $4,800 or else a Warden, Scout the Warden; a vest and a helmet; up to two kits for defenders; grenades by class), a **force buy** when either team is on match point, in the last round of a half, or with $2,400 on average (the cheap guns and a vest), and otherwise a **save**. Every purchase goes through `request_buy()`.
- **Choosing a class:** at the match start each team's bots get a mix (D-078); at half time they all shift by the same random step through the class list, so the team stays a mix and each bot plays the second half as something else. *With the class draft (task 17, above) they choose within their two drafted classes instead.*
- **Using the arsenal** (`BotController._use_arsenal()`): a gun in hand at all times (the primary while it has ammo, else the pistol; the pistol instead of a reload when the primary runs dry within 15 m of the enemy; never the knife or a grenade in a fight); the Heron scoped (one step) in a fight and only fired scoped and settled (cone under 0.15°), unscoped otherwise; the shotgun not fired beyond 18 m (attackers close in instead); semi-automatics tapped (D-094). **Pickups:** while following orders a bot goes for a gun lying within 10 m (a power weapon within 15 m) that is worth at least $500 more than its own (the Heron counts $2,000 for anyone but the Marksman), and takes it by walking over it or with a Use press; not while carrying or fetching the bomb, nor once it's planted. **Grenades:** in a search for an enemy it heard or lost sight of 6–24 m away, a bot throws its frag or flashbang there (the low arc solved for the throw speed under the grenades' gravity, `BotController.throw_aim()`), at most every 8 s and not in the first 4 s of a life; after its own flashbang it looks away. Bots don't use smokes.

**Why (bots):** A CS team's buy is a team decision (the eco, the force), and making it from the team's average money is the simplest rule that produces it: a measured bots-only 5v5 first to 6 on Depot shows pistol rounds, full rifle buys after wins, saves after losses (the losers kept $1,500–2,000), force buys on match point, about five grenades a round, and a defuse. Class tastes give the buys variety and use the signature guns. Using each gun the way its rules reward (scope and stand still, close in with the shotgun, pistol over reload) is what makes the arsenal matter against bots. Pickups within a few metres and only for clearly better guns keep bots on their plans.

**Checked (bots):** a new `tests/botgear_test.tscn` (8 checks): the plans (pistol round, full buy at $4,000, save at $1,500, force on match point); a pistol round's buys; a full buy per class with armor (and kits on maps with the bomb); a bot switching to its pistol when the rifle is empty, scoping the Heron before its first shot, going for a Ram on the floor, throwing its frag at an enemy it heard behind a wall, and the throw's arc landing within 1.5 m at 12–18 m. The round, gear and money suites turn bot buying off (they test other things); every other suite plays with it on and passes.

**Alternatives (bots):** Each bot deciding alone (no ecos or force buys as a team); a scripted buy per round number; bots never picking up guns (simpler, but power weapons would be the player's alone); smokes thrown at fixed spots per map (needs map data per site).

## D-100 — Multiplayer is a listen server: the host runs the game, clients send commands and show snapshots (2026-10-16) — *provisional*

**Decision:** One player hosts and plays on the same computer (a *listen server*, as when you start a CS game with friends from the console). The host's computer runs the real game: the same `main.tscn` with the same `RoundManager`, `Bomb`, bots and weapons as single-player. Each friend's computer (a *client*) sends its player's per-tick `CharacterInput` commands (D-034) to the host and shows what the host sends back. The client simulates exactly one thing itself, its own player (prediction, D-106), and corrects it when the host disagrees. Everything that decides the game (damage, deaths, rounds, money, the bomb, class changes) runs only on the host. Single-player stays exactly as it is: no network code runs without a session.

**Why:** It is CS's model, so it plays the way you know (first-shot accuracy, peeking, trading) and the host's word is final, which makes cheating by changing your own game useless. It reuses the whole single-player game unchanged on the host, because M4 to M8 kept the rules in authority code driven by commands ("Keeping multiplayer possible").

**Alternatives:** *lockstep* (every computer runs the whole simulation from everyone's inputs, as RTS games do: tiny traffic, but the game waits for the slowest player every tick and any difference in floating-point maths splits the games apart); *client authority* (each computer decides where its player is and whom it hit: simple, but trivial to cheat and players disagree about who shot first); a *dedicated server* (a host without a player; it would be a small addition later, see the backlog).

## D-101 — Godot's high-level multiplayer over ENet; RPCs for the lobby, compact packets for the game (2026-10-16) — *provisional*

**Decision:** Connections use Godot's high-level multiplayer: a `SceneMultiplayer` (the `multiplayer` object every node can reach) with an `ENetMultiplayerPeer` (ENet is a small library that sends UDP packets reliably or unreliably). The default port is **26000**, Quake's. Two kinds of traffic:
- **The lobby and session** (joining, names, teams, starting a match): *RPCs*, functions marked `@rpc` that one computer calls on the others. Few messages, all reliable.
- **The game stream** (commands, snapshots, game events): our own packets, packed into bytes by `NetProtocol` and sent with `SceneMultiplayer.send_bytes()`, unreliable for commands and snapshots (a newer one replaces a lost one), reliable for events. One `NetSession` layer sends and receives them, which is also where fake lag and loss are added for tests (`net_fakelag` and `net_fakeloss` in milliseconds and percent, like CS's).

**Why:** RPCs are Godot's natural way to say "do this on the other computer" and they are ideal for the lobby. For the game itself, prediction and lag compensation need to know exactly which tick a snapshot shows and which command the host ran last; Godot's `MultiplayerSynchronizer` (which copies chosen properties to the other computers) has no notion of either, and `MultiplayerSpawner` (which creates the same nodes on every computer) doesn't fit characters that the round manager creates and bots that become players. Our own packets are also several times smaller than the synchronizer's, which matters for Steam's relays. One layer for the stream gives us one place to simulate bad connections.

**Alternatives:** `MultiplayerSynchronizer` + `MultiplayerSpawner` for everything (fastest to start, used by most Godot tutorials, but no ticks, no acknowledgements and no redundancy); RPCs for everything (each RPC call has overhead and no tick stamp); raw `PacketPeerUDP` without ENet (we would rewrite reliability and connections).

## D-102 — The session node lives at the tree root; players have network ids and names (2026-10-16) — *provisional*

**Decision:** A `NetSession` node is created when you host or join and is added to the root of the tree, next to the current scene, so it survives the change from the main menu to the game and back (like an autoload, but only while you are online). It isn't an autoload because tools and tests run without autoloads, and because the network tests run a host and clients **in one process**: each side has its own `NetSession` and its own `SceneMultiplayer`, given to its branch of the tree with `SceneTree.set_multiplayer()`. Game code never looks the session up by name: `main.gd` hands it to the nodes that need it.

Every character in an online match has a **network id** (`Character.net_id`, from 1, given by the host when the match starts; bots get one too) so snapshots and events can name it (ARCHITECTURE rule 5). Its node is named after the player (your name from the settings, a number added when two are the same; bots stay "Bot3"), so the kill feed and scoreboard show names without changes.

**Why:** the network code must not be global for the in-process tests, and passing the session down keeps the single-player code free of it.

**Alternatives:** an autoload `Net` (simple, but tools and the one-process tests can't use it); a static instance like `Settings` (one per process, the same problem).

## D-103 — Commands: the host runs every one exactly once; repeated until confirmed; spread from the command number (2026-10-16) — *provisional*

**Decision:**
- The client numbers its commands (`CharacterInput.tick`) and sends, once per frame, every command the host hasn't confirmed yet (up to 32, a quarter of a second). A lost packet is covered by the next one.
- The host runs **each command exactly once, in order**, as soon as it arrives, as CS's server does: the friend's character on the host is stepped by hand (`Character.step()`, the same code as `_physics_process`) once per command instead of once per host tick. A budget of one command per host tick, saved up to 8, stops a client from running faster than real time (a speed hack) while letting late packets catch up. A client whose commands stop arriving stands still on the host.
- Snapshots tell each client the number of the last command the host ran (the *ack*), which prediction compares against (D-106).
- The client predicts with exactly the command it sends: movement keys are packed into whole steps before the client uses them, so both computers simulate the same numbers.
- The **shot spread** of an online character's shot is rolled from a generator seeded with its network id and the command's number, so the host and the shooter's own computer roll the same spread: where your bullet lands on your screen is where it lands on the host.

**Why:** running each command exactly once means the host simulates exactly what your computer predicted, so prediction errors come only from real disagreements (someone bumped you, you were hit). The alternative, one command per host tick from a small buffer, misses or doubles commands whenever packets bunch up, and Godot runs two or three physics ticks per rendered frame, so they always bunch up.

**Alternatives:** one command per host tick with a jitter buffer (Overwatch's way; needs careful buffer tuning and adds delay); sending each command once (a lost packet loses a jump or a shot).

**Added while building (task 4):** ENet has a *throttle* that drops a share of unreliable packets by itself when the round-trip time wobbles. On localhost it dropped the odd command packet with no fake loss at all. Chiip's stream repeats what matters (commands until confirmed, effects in three snapshots, a newer snapshot replaces a lost one), so the throttle is switched off for every connection (`throttle_configure(5000, 2, 0)`); our streams are small (tens of KB/s), so there is no congestion for it to prevent. Later (task 6) ENet's *bandwidth* throttle cut the unreliable packets to 1 in 32 in the middle of a test, although no bandwidth limit had been set; calling `ENetConnection.bandwidth_limit(0, 0)` right after creating the host or client stops it. The redundancy had hidden it until prediction showed the host skipping commands.

## D-104 — Snapshots at 64 Hz; others shown about 50 ms in the past; reliable events for what must not get lost (2026-10-16) — *provisional*

**Decision:**
- The simulation stays at **128 ticks a second** (D-010). Every second tick the host sends each client a **snapshot** (64 a second, CS2's rate): the host tick; the ack (D-103); the round's phase and clock; the bomb (state, carrier, position, fuse, who plants or defuses and how far); and for every character its position, velocity, yaw and pitch, eye height, crouching, on the ground, alive, frozen, busy, health, a *life* counter (it goes up on every respawn), magazine, reserve and reloading. The client's own character comes with the full-precision state prediction needs. A 5v5 snapshot is about 500 bytes, about 30 KB/s per client.
- Clients show every other character **6 ticks (47 ms) behind** the newest snapshot, interpolated between the two snapshots around that moment (CS's `cl_interp`: one lost snapshot still leaves one to interpolate to). If snapshots stop, characters keep moving for up to 100 ms, then stop.
- **Cosmetic events** (a shot with where it hit, a reload) ride in the snapshots, each repeated in three snapshots and numbered so a lost snapshot loses nothing and nothing plays twice.
- **Reliable events** are sent in order the moment they happen: the roster, round phases (freeze, live, round end with winner and reason, half time, match end, overtime), kills (victim, killer, headshot), damage (who, how much, which zone, by whom), the scoreboard numbers (at most 4 times a second, when they change), class changes, and the bomb's pickups, drops, plants, defuses and explosion.

**Why:** 64 Hz is smooth at 128 Hz simulation and half the traffic; 47 ms of delay hides one lost snapshot without making others feel late. Events that change the score must arrive, so they go reliable; shots arrive often and a late gunshot is worthless, so they ride along unreliably but repeated.

**Alternatives:** 128 Hz snapshots (twice the traffic for little gain); 32 Hz (CS:GO's old matchmaking rate: visibly choppier); extrapolation instead of interpolation (no delay, but characters overshoot corners).

## D-105 — On clients the round manager and the bomb are replicas (2026-10-16) — *provisional*

**Decision:** A client's game creates the same `RoundManager` (or `RespawnMatch`) and `Bomb` as the host, with `replica = true`: they make no decisions (no spawning, no timers that end anything, no planting), and the network code fills in their fields (phase, clock, score, sides, stats, the bomb's state) from the host's snapshots and events and emits their signals. Everything that shows a match (round HUD, kill feed, Tab scoreboard, bomb HUD, class menu, end screen) keeps listening to the same object, unchanged. The replica keeps the clock running between snapshots so the timer counts smoothly, and the replica bomb beeps by itself, but it only explodes when the host says so.

**Why:** the views were built to only listen and read (ARCHITECTURE rule 2), so giving them a replica is the smallest change, and online and offline matches look the same.

**Alternatives:** separate client-side views fed by the network code (a second copy of every view); syncing the views themselves (clients would show whatever the host's screen shows, including the host's own perspective).

## D-106 — Client-side prediction with reconciliation by replaying commands (2026-10-16) — *provisional*

**Decision:** The client simulates its own character from its own commands at once, as offline, and keeps each command with the state it predicted after it (the last second). When a snapshot says "the last command I ran was 1234, and this is where it left you", the client compares that with its own prediction for 1234. If they differ by more than 1 cm or 0.05 m/s (or in crouching, or on the ground), it takes the host's state and *replays* every newer command at once (movement only: no sounds, no shots), so it ends up where the host will put it. The visible jump of such a correction is smoothed out over 0.1 s (CS's `cl_smooth`). Ammo is corrected by the difference between the host's count and the predicted count for the same command. Respawns, freeze time and the bomb's `busy` come from the host and are followed the same way. Other characters are never predicted: they are interpolated (D-104).

**Why:** without prediction every step would wait a round trip (100 ms at a typical online ping), which feels like moving through mud. Replaying instead of blending keeps the client exactly on the host's path.

**Alternatives:** no prediction (simple, laggy); blending toward the host's position (cheap, but drifts and rubber-bands); also predicting other players (overshoots, and Source doesn't either).

**Added while building (task 6):** the client must simulate exactly the numbers the host gets. GDScript's floats have 64 bits but the packet carries the angles in 32, so the command is cut to the packet's precision (`NetProtocol.quantize()`) *before* the client simulates it; with that, 3 s of running, strafing, jumping and crouching at 100 ms of round trip needs not a single correction. And (task 11): a client's predicted player collides with the world only, not with the other characters. They are shown 50 to 100 ms in the past, so bumping into them on the client was bumping into where they had been, and in a crowded spawn that caused corrections of up to 0.7 m; the host still decides real bumps, which now cost corrections of a few centimetres. Refined the same day: a puppet that stands still (slower than 0.5 m/s, `NetClient.BLOCKING_SPEED`) is where the host has it, so it does block your prediction (`Character.set_blocking()`); only moving ones let you through. That took a 5v5's corrections from about 90 to under 30 in 80 s. A respawn's jump isn't counted as a correction (`NetClient.teleports`).

## D-107 — Lag compensation: the host checks shots against hit zones rewound to what the shooter saw (2026-10-16) — *provisional*

**Decision:** At the end of every tick the host records every character's hit-zone boxes (one transform per zone) for the last second. Each command carries the tick the client was showing other characters at (the interpolated moment, D-104). When a friend's command fires, the host doesn't test the ray against the hit zones as they are now: it tests it, in code, against the boxes as they were at that moment (interpolated between the two recorded ticks, at most **400 ms** back), and the world (walls) as it is. The rest of the shot (damage, falloff, the zone, the hole, the sound) is unchanged. The host's own shots and the bots' shots need no rewinding. A test checks the ray-against-box maths against the physics engine's own ray test.

**Why:** without it you would have to lead every moving target by your ping, which is unplayable in a CS-like game. Testing against stored boxes in code, instead of moving the real hit-zone areas back and forth, is exact and doesn't depend on when the physics engine (Jolt) moves bodies (CLAUDE.md, "Jolt moves a teleported body only at the next physics step"). 400 ms covers every reasonable ping without letting a very laggy player shoot people who left cover long ago (CS allows up to 1 s).

**Alternatives:** moving the hit-zone areas back in time and using the physics engine's ray (Source's way; risky with Jolt's deferred moves); no lag compensation (lead your targets); client-side hit detection (the shooter's computer decides: cheatable).

## D-108 — The lobby: host or join by IP, two teams of slots, bots fill the rest (2026-10-16) — *provisional*

**Decision:** The main menu gets **Multiplayer**: you enter your name (saved in the settings) and **Host**, or the host's IP and **Join**. The lobby shows the two teams side by side, in your colours (your team blue), each with as many slots as the match has players per team: players by name, empty slots as "Bot". You join a team by clicking it (a full team refuses). The host picks the match with match setup's rows (mode, map or rotation, team sizes, bot difficulty, length, friendly fire) and **Start**; the others see the settings as the host sets them. Online matches are matches only (rounds or team respawn), no practice. You pick your class in the game, as offline (the class menu asks the host).

**Why:** for friends, choosing sides and seeing who is where matters more than automatic balancing; reusing match setup's rows keeps one way to set up a match.

**Alternatives:** automatic team balance; a server browser that finds LAN games by itself (a broadcast; a later addition); joining only through Steam.

**Added while building (task 8):** on the lobby page Esc means Leave (as Back does on the connect page); the summary line is built from the match settings ("Rounds · Depot · first to 5 rounds · Normal bots"); the host's team gets match setup's "your team" size and the other team its "enemy team" size, so match setup needs no online version; the port is a text field that keeps digits (1024 to 65535).

## D-109 — Online, the pause menu is an overlay that doesn't pause (2026-10-16) — *provisional*

**Decision:** As M5 planned (D-065): online, Esc opens the same pause menu, but it doesn't set `get_tree().paused`. It still registers with `MenuState`, so your character stops and doesn't shoot while it's open, and the mouse is free. Leave match disconnects (a client) or ends the game for everyone (the host). The console's cheats (`god`, `noclip`) and bot commands only work offline.

**Why:** nobody can stop the other players' game, and cheats would be unfair (and on a client they would only fight the host's corrections).

**Alternatives:** a vote to pause (CS's tactical pause) for the host only: a later addition if you want it.

## D-110 — Bots take over players who leave; a player who joins late takes over a bot (2026-10-16) — *provisional*

**Decision:** When a friend leaves or loses the connection (ENet notices after a few seconds), the host gives their character a bot's brain: it keeps its name with "(bot)", team, class and stats and plays on. When someone joins a match that is already running, they pick a team and take over one of its bots at the next round start (at once in team respawn). If the host leaves, the clients go back to the main menu with "The host ended the game".

**Why:** "bots fill empty slots" (D-033) shouldn't stop at the start of the match; a match among friends should survive someone's Wi-Fi dropping.

**Alternatives:** the slot stays empty (CS's default); the match ends when someone leaves.

**Added while building (task 10):** a latecomer takes over a bot at once, not at the next round start: if that bot is alive the newcomer plays on from where it stands (CS's "take over a bot"), if it is dead they watch a teammate until the next round. A bot's brain is put aside rather than freed while a friend plays its character (the round's tactics and the respawn mode's hunting plans keep references to it), and comes back when the friend leaves. When every slot of both teams is a player, a latecomer is refused ("The match is full").

## D-111 — Network tests run a host and clients in one process, with fake lag and loss (2026-10-16) — *provisional*

**Decision:** The network suites (`net_test`, `netplay_test`) start a host and one or two clients **inside one Godot process**: each side is its own branch of the tree with its own `SceneMultiplayer` (`SceneTree.set_multiplayer()`), its own physics world (`SubViewport.own_world_3d`) and its own `NetSession`, connected through real ENet on localhost. The session's packet layer adds the fake lag (in ticks, so headless runs are repeatable) and seeded fake loss. To make two games in one tree possible, code that looked at every character in the tree (`get_nodes_in_group("characters")`) now asks only for the characters of its own world (`Character.all_in_world()`).

**Why:** one process means one test run, one log and checks that can look at both sides at the same moment; real ENet means the tests use the same path as a real game.

**Alternatives:** two processes talking to each other (closer to real life, but hard to check both sides at once and slower); a fake in-memory peer (fast, but then ENet is never tested).

## D-112 — Steam through GodotSteam, test app 480, the same game stream (2026-10-16) — *provisional; deferred by D-114*

**Decision:** Steam lobbies and invites come from **GodotSteam**, the open-source Steamworks addon for Godot (a GDExtension, installed under `addons/`, MIT licence, with Valve's Steamworks runtime library). Until Chiip has its own Steam app, it uses Valve's public test app **ID 480** ("Spacewar"), which every Steam developer uses for this. Hosting on Steam creates a friends-only lobby; Steam's overlay invites friends; joining from an invite or the friends list connects through Steam's networking (relayed, so no ports to open). The game stream (D-101) runs over Steam the same way as over ENet, through a Steam `MultiplayerPeer`. Without Steam running the game works as before, and LAN stays.

**Why:** your choice (D-033: LAN first, then Steam lobbies). Steam's relays solve what makes playing over the internet hard (NAT, firewalls, IP addresses).

**Alternatives:** IP only over the internet (players open ports on their routers); a Godot-specific relay service; Epic's Online Services.

## D-113 — The arsenal online: inventories by weapon id, world objects in the snapshots (2026-10-16) — *provisional*

**Decision:** M7's systems stay authority code on the host (its interface table in ARCHITECTURE.md, "Weapons, money and buying"), and clients learn of them like this:
- **What you carry** goes to you alone as a list of weapon ids with their ammo and the one in hand (`INVENTORY`), whenever it changes; your computer builds its own weapon nodes from it. **Switching** (slot keys, Q) is predicted, as movement is: it comes from your commands. **Dropping, swapping and picking up** are the host's only: your computer skips them, and the snapshot names the weapon the host has in your hands for the acked command, so a pickup or a drop that changed it is taken over. Ammo is corrected per weapon (the acked command's), not only for the one in hand now.
- **Everyone else** shows the weapon in hand (its id in every snapshot, with armor, helmet and kit); a puppet carries just that weapon, so its body, sounds and spectator's view follow it.
- **World objects** are numbered by the host and listed in the snapshots: grenades in flight in every one (interpolated like puppets), guns on the floor and map weapons' spots in every fourth (they lie still). Clients make copies (`WeaponPickup`, `Grenade`, `WeaponSpot` with `replica` on) that neither fall, fly, go off nor get taken. A grenade going off is an event (the blast or flash or hiss, and a smoke's cloud from the same seed); a flash's blindness is decided per character on the host and sent (`FLASHED`).
- **Money** changes are events with the reason (the HUD's reward lines), the totals come with the welcome; a **purchase** is a request the host's `request_buy()` decides, the client's buy menu checks the same rules on the replicated money and gear first; the **class draft**'s offers come with the welcome and as events; a kill carries the weapon of the killing hit (the kill feed's icon).
- Shot spread is now seeded once per shot, so a shotgun's pellets spread as they do offline.

**Why:** one stream (snapshots and events) for everything keeps prediction, the tests in one process and the bandwidth under our control; ids instead of nodes let each computer build its own weapon nodes, as M7's note asked.

**Added while building (Team Deathmatch online):** the client keeps its weapons in the host's order (after a class change it had kept the Sparrow and the knife first and added the new class's gun behind them, so "the first grenade" could differ); ammo scavenged from a gun on the floor sends the list too (it changes no slot, so the weapons not in hand never heard of it); a class picked on a client while alive shows as its next class there as well (`RespawnMatch.get_next_class()`), until the host's change arrives with the respawn.

**Alternatives:** `MultiplayerSpawner` for pickups and grenades, as M7's note suggested (it would replicate node creation by path, a second mechanism next to the snapshots, and two games in one test process share node paths); sending every client every inventory (more traffic for nothing they show); predicting pickups (the gun would sometimes jump back into the floor when the host disagreed).

## D-114 — M9 is LAN only for now; connections go through a transport, so Steam is one more later (2026-10-16) — *provisional*

**Decision:** M9 ships without Steam: you host on your computer and friends join by IP over the LAN (or over the internet with a forwarded UDP port, 26000). GodotSteam isn't downloaded; Steam lobbies and invites (D-112, M9's tasks 15 and 16) wait in the Backlog until you approve the download. So that adding them stays small, the session no longer makes its ENet connection itself: a **transport** does (`NetTransport`, `net/net_transport.gd`), the one place that knows which kind of connection is used. It makes the `MultiplayerPeer` and does the four things the session needs from the connection: set up a new connection, measure the ping, send what is queued at once, and drop a connection politely. `EnetTransport` is the LAN one (ENet's timeouts, its bandwidth limit and throttle off, D-103). Everything above (the roster's RPCs, the game stream, the host, the client, the tests) only sees the `MultiplayerPeer`, which GodotSteam's `SteamMultiplayerPeer` also is. A Steam transport would make that peer from a Steam lobby instead of an address, and the lobby menu would get a Host on Steam button and Steam's invite overlay.

**Why:** your answer: "No, don't download GodotSteam; M9 stays LAN-only for now." The transport costs two small files now and keeps the later change to one new class and a button, without touching the netcode.

**Alternatives:** keep ENet in the session and change it when Steam comes (simplest today, but the Steam work would then touch the session's connection code everywhere it calls ENet: kicking, the ping, flushing); a list of transports chosen in the settings (nothing to choose from yet).

## D-120 — M10: a map kit, a modern UI, Team Deathmatch first; random weapons and a class draft in M7 (2026-10-16)

**Decision:**
- **New milestone M10, Look & feel**, in two parts that run in parallel:
  - **A map kit:** about 30 more CC0 ambientCG textures made retro, plus props generated by our own tool in the crew's low-poly style, all placeable in TrenchBroom, with a mapping guide. The three quick maps and the test map get dressed with it.
  - **A UI refresh:** minimal and more modern, still pixelated.
- **Team Deathmatch is the primary mode**, with a simpler mode choice.
- **M7 gets two additions:**
  - **Random map weapons:** never near spawns, never always in the same place.
  - **A class draft:** two random classes offered per match.
- **No other randomness:** no random-mode button and no match twists.

**Why:** Your feedback, in your words:
- "the gamemodes should be much more simple to choose and a bit of randomized thing or luck or choosing should be also there"
- "the arsenal spawned on map, not buyable should be random (not on spawns of course, but not always on the same place"
- the maps "look blank when you look at the environtment … it has to be there, so that I and or the community can build maps"
- the UI "should be more minimal and more modern ish, the retro pixelated look and text, doesnt mean that it has to look like game that some three year old draw"
You chose CC0 textures plus our own props, Team Deathmatch as the primary mode, the class draft, and random map weapons.

**Alternatives:** Everything generated, with no downloads (textures look more synthetic). Ready-made CC0 model packs (style may clash with the crew). A random mode-and-map button, and random match twists.

## D-121 — The texture library: 28 ambientCG textures in four sets, found by folder (2026-10-16) — *provisional; the textures are redrawn in D-140, the sets, folders and sound names stay*

**Decision:**
- **28 more CC0 textures from ambientCG**, turned retro by `tools/make_retro_texture.gd` like the first eight (64 × 64, 16 colours, D-024), in four sets that TrenchBroom shows as collections: `assets/textures/industrial/` (corrugated steel, diamond plate, rusty plates, grating, chain-link, perforated sheet, worn concrete), `urban/` (asphalt, cobbles, slabs, blocks, rubble wall, slate roof, wood siding, olive plaster), `interior/` (two wood floors, white, dark and checker tiles, ceiling tiles, terrazzo, old planks) and `nature/` (grass, dirt, mossy rock, bark).
- **The first eight stay where they are**, at the top of `assets/textures/`, as the base set. Moving them would change every built map and the texture names other branches' maps use.
- **Every texture gets a material** in `assets/materials/<set>/` (world triplanar, like today's, for CSG maps and props). A texture that needs more than func_godot's default material (the chain-link's see-through holes) also gets a `.tres` next to the PNG, which func_godot uses instead of generating one.
- **Footsteps and impacts know new textures by name:** `Surfaces` matches words in the texture's file name (metal, steel, plate, grate, rust → metal; wood, plank, parquet → wood; gravel, dirt, grass, ground → gravel-like ground). A mapper who names a new texture `blue_metal` gets metal steps without touching code.
- **Picked and checked against the look rules** (D-031, D-063): no saturated red or blue on surfaces, no sand or desert tones; greens and ochres muted. Measured on the processed textures, not judged by eye: the new `tools/texture_report.gd` counts a texture's strong team-red and team-blue pixels (at most 3 %) and its average saturation (at most 0.45, which wood just passes). Calibrated on the base set: it fails `bricks_red` with 21 % strong reds, as MAPS.md measured. All 28 pass with 0 % team colours; everything but wood stays at 0.30 saturation or less.
- **Five textures drawn, not downloaded** (`tools/make_kit_textures.py`): `interior/glass` (see-through, for `func_glass`), `industrial/hazard_stripes` and `industrial/floor_line` (trims), and `industrial/corrugated_rust` and `corrugated_teal` (the grey ribbed metal recoloured, so containers come in four colours with one pattern), in the props' palette.
- **Eight sources prepared first** by `tools/texture_prep.py`: their colour maps alone become flat grey or noise at 64 × 64 (the ribs, lugs and holes of corrugated steel, diamond plate, perforated sheet and dark tiles live in the asset's displacement map), the rust's hue counted as team red (36 %), and two patterns are drawn instead (roof shingles that became plaid, and the chain-link's mesh, finer than a pixel). Details in CREDITS.md.
- **Downloads:** 28 of the 1K-JPG zips (1.8–11 MB each, about 170 MB in all, kept in the session's scratchpad and deleted afterwards; only the 64 × 64 PNGs enter the project), within your approval of about 30 (D-120). Most were above the 2–5 MB estimated then, because ambientCG's zips hold every map (normal, roughness…), and nature textures are the biggest.

**Why:** Folders are how TrenchBroom groups textures, so sets need no extra configuration and a mapper finds "industrial" where they expect it. Name-based sounds keep the sound pass (D-084) working for textures nobody has listed yet.

**Alternatives:** Moving the old eight into the sets (tidier, but rebuilds every map and breaks other branches' maps); a texture WAD file (the Quake way, but Godot-side materials are simpler); a table of texture → sound kind only (every new texture would need a code change); 2K textures (the tool shrinks to 64 × 64 anyway).

## D-122 — Props are generated like the crew: part lists → glTF → a scene → a TrenchBroom entity (2026-10-16) — *provisional*

**Decision:**
- **Props come from `tools/modelgen/`** (D-054), from part lists in `props.py`: the same bevelled boxes, tapered cylinders and low-res spheres as the crew, the same painter with 16-shade ramps (plus a few ramps for props: rust, safety yellow, leaf green, concrete), baked light, grain and patterns (wood grain, planks, ribs, rivets, hazard stripes, letters for signs). Static meshes without bones; the crew's 96 texels per metre.
- **One command, `modelgen.py props`, writes everything** for every prop:
  - `assets/models/props/<name>.glb` and `<name>_albedo.png` (Godot imports them like the crew);
  - a scene `maps/kit/props/<name>.tscn`: a `StaticBody3D` with the model and the prop's collision boxes from its part list;
  - its entry in `maps/fgd/chiip_kit_fgd.tres` (generated), a func_godot point class with the scene and the `.glb` as its display model, so TrenchBroom's entity browser shows the real model and `tools/export_trenchbroom_config.gd` writes it into the FGD.
- **Names are `prop_<thing>`** (`prop_crate_wood`, `prop_barrel`), like Quake's and Source's prop classes. A prop's front faces `-Z` in Godot, which is the entity's angle in TrenchBroom.
- **Glowing parts** (lamp bulbs, lit signs) are a second material with emission, so they glow without a light.
- **Props use 48 texels per metre** (the crew 96, the world's textures about 39); a prop whose biggest side doesn't fit a 512-texel atlas gets fewer. Godot makes no LODs for them (`meshes/generate_lods=false`).
- **Checked** (`tests/kit_test.tscn`): every prop scene has its model, a surface and collision for its kind; every one is an entity in the kit's FGD with its scene and display model; props placed in a test `.map` build where they were put, as instances, stop rays at their tops, sound like wood or metal, and are cut out of a navmesh baked around them while decoration isn't. Regenerating the crew after the painter learned props' materials and patterns gives byte-identical files.

**Why:** The crew already proved the pipeline, so props match the crew's chunky low-poly look and palette by construction. Generated scenes and FGD entries mean a new prop is one part list and one command, with nothing to set up by hand in Godot or TrenchBroom.

**Alternatives:** Building props from brushes in TrenchBroom (no tool needed, but no round shapes, and each map would carry its own copies); CC0 model packs (style clash, downloads); func_godot's model point class, which exports display models from the scene at FGD export time (needs the game path set in the editor, and writes into the game folder).

## D-123 — Collision: what you see is what blocks; see-through things block only movement (2026-10-16) — *provisional*

**Decision:**
- **Solid props block movement, bullets and sight** (the WORLD layer), with boxes that follow their shape closely, because bots see by raycasts against the world: if a prop hid you from a player but not from bots (or the other way round), the bots would cheat. Tree crowns and bushes count as solid.
- **See-through things block only movement:** chain-link fences, railings, glass and grates are on the physics layer bots already use (layer 3): characters and the navmesh treat it as solid, bullets and sight pass through. The layer keeps its name; the docs now say what else uses it.
- **Small clutter has no collision:** debris, litter, tufts of grass, wall-mounted things above head height. There are no steps (MAPS.md), so anything low that you could walk into either blocks fully (you jump onto it, as on a crate) or has no collision at all.
- **Props are cover like the maps' boxes:** low cover 1.2 m or less, tall cover 2.2 m or more, so the building rules still hold for props.

- **For brushes** (D-125): `func_glass` (with `interior/glass`) and `func_fence` (with `industrial/chainlink`) are drawn and block only movement; `func_clip` is an invisible movement-only wall (to keep players off roofs) that, unlike Quake's clip texture, never stops a bullet. Glass doesn't break.

**Why:** Fairness between players and bots is the clarity rule's twin: the same things hide everyone. Reusing layer 3 needs no change to characters, bots or weapons.

**Alternatives:** Mesh-shaped collision (expensive, catches on edges); a new "clip" physics layer (cleaner name, but every character scene and the navmesh settings would change in several branches); collision on everything (debris would stop players like a wall).

## D-124 — Light fixtures are entities with a real light (2026-10-16) — *provisional*

**Decision:** Lamp props (`light_wall`, `light_ceiling`, `light_flood`, `light_street`, `light_strip`) are point entities whose scene holds the lamp's model and a real-time light: an `OmniLight3D` for most, a `SpotLight3D` for the floodlight. Colour, brightness, range and shadows are entity properties set in TrenchBroom, with warm defaults (D-031: warm light only from lamps). Shadows are off by default. The bulb is a glowing material, so a lamp reads as on even where its light is weak.

**Built:** caged wall bulkhead, caged bulb, pendant, fluorescent strip, wall floodlight (a spot aimed 30° down), street lamp on a 5 m pole, tripod work light (a wide spot). The light comes from `maps/kit/kit_light.gd` (`KitLight`) and fades out beyond 45 m from the camera.

**Why:** A lamp you can see explains the light in a room, and placing one in TrenchBroom puts the light where the model is. Shadowless omni lights are cheap in Godot's clustered renderer.

**Alternatives:** Lights placed separately in the Godot scene, as today's maps do (two places to edit); Quake-style `light` entities with no model (lights from nowhere); baked light (D-085 keeps lighting real-time).

## D-125 — Gameplay markers can be placed in TrenchBroom (2026-10-16) — *provisional*

**Decision:** Point entities for every marker the game reads: `info_attack_spawn`, `info_defend_spawn`, `info_respawn`, `info_patrol`, `info_hold`, `info_route` (route name and order), and a brush entity `trigger_bombsite` (A or B). They build into the same nodes and groups as the hand-placed markers in today's maps (MAPS.md, "Markers in each map scene"), so the game needs no change. The three quick maps keep their markers in the scene; the kit gallery map uses only entities.

**How:** spawns, respawn, patrol and hold points are `Marker3D` nodes put in the right groups by func_godot (an entity definition's `node_groups`), turned by the entity's angle (the way the spawn or hold spot faces). Two small scripts handle the rest at run time: `KitBombSite` renames the area `BombSiteA` or `BombSiteB` (the bomb's messages read the letter from the name), replaces the brush's convex shapes with one box (the bomb finds the site's floor at the bottom of a box) and adds the floating letter; `KitRoutePoint` gathers the points of each route under one `Route_<name>` node in the `attack_routes` group, sorted by `order` (bots read routes when a round goes live). `tools/new_map.gd` turns a `.map` into a playable scene from `maps/kit/map_template.tscn` (sky, sun, player, navigation) and bakes its navmesh. Ladders aren't part of the kit: movement has none, so ramps it is.

**Why:** "so that I and or the community can build maps": with markers in TrenchBroom a whole map is one `.map` file plus a template scene, without learning Godot's editor first.

**Alternatives:** Markers only in Godot's editor (today; two tools to learn); converting the three maps' markers to entities (risky churn for no gameplay change).

## D-126 — Performance limits for maps (2026-10-16) — *provisional*

**Decision:** Limits a map should stay within (MAPPING.md, "Performance limits"): **up to 150 props** (lamps included), **up to 24 lamps**, **at most 4 lamps with shadows**, 6 main materials plus about 6 detail textures. Within them a 5v5 holds the display rate on the development Mac.

**Measured** with `tools/frame_timing.gd`, 5v5 bots, 1080p window, V-Sync off (macOS keeps it on anyway at the display's 120 Hz): the kit gallery with 86 props and lamps, 120 fps on average, slowest 1 % of frames 11.3 ms, 629 draw calls. The dressed quick maps (67–86 entities each): 120 fps, slowest 1 % 9.7 ms (Depot; 9.9 ms undressed), 10.2 ms (Square), 11.8 ms (Spillway), about 240 draw calls (Depot 122 undressed). Dressing costs nothing measurable here, so the limits keep a wide margin (150 props is about twice the gallery).

**Why:** Mappers need numbers, not "don't overdo it". Each prop is a draw call and each shadowed light renders the scene again, so those are the costs that grow with dressing.

**Alternatives:** No limits (a community map could run badly without anyone knowing why); limits enforced by a tool (later, if needed).

## D-127 — Look rules for a dressed map: six main materials plus details (2026-10-16) — *provisional; changes D-063's material limit*

**Decision:** D-063's "at most 5 materials per map" becomes **at most 6 main materials** for the big surfaces (floors, walls, roofs, the large blocks), where **variants of one material count once** (the same ribbed metal in four colours, pale and olive plaster, cobbles and slabs), plus **details** in small doses: trim, edges, signs, props and lamps. Everything else in D-063 stays: no saturated red or blue on large surfaces, neutral shadows, cool daylight, measured in screenshots.

**Why:** You found the maps blank. Variety comes from details on top of a calm base, which keeps the minimal, readable look while the maps stop looking empty. Dressing Depot showed that five weren't enough once its 6 m yard walls got their own block texture: plain concrete on every wall and floor is what made it blank. Colour variants of one material (containers in a yard) add variety without adding visual noise, because their pattern is the same.

**Measured after dressing** (MAPS.md, "Before and after the map kit"): in the screenshots below the horizon, strong team-red pixels at most 1.3 % of a shot, team-blue at most 0.5 % (before dressing up to 6 %, from the old blue-grey metal plates); warm lamp light on Depot's warehouse floor first measured 4.4 % "red" (hue right at the 20° boundary), so its pendants are a warmer white now.

**Tried and dropped while dressing:** worn concrete with rebar patches on walls and floors (its marks repeat every 1.6 m and look like a pattern), the rusty-plate texture on containers (reads as brown mud), perforated sheet on racks (busy black holes). The rule for detail textures: one calm pattern per surface.

**Alternatives:** Keeping five in total (the maps stay blank); no limit (risks the noisy look D-063 avoided).

## D-128 — Dressing keeps the layouts: details go where they don't change play (2026-10-16) — *provisional*

**Decision:** Dressing a map doesn't move walls, ramps, doors or cover. Props go against walls, in corners, on top of or beside existing cover (where they don't lengthen it), above head height, or replace a plain box with a prop of the same size. After dressing: rebuild, re-bake the navmesh, then the maps test (first contact 5–10 s, every marker on the navmesh, both spawns reach both sites) and the map report (sightlines no longer than before).

**Result:** every map passes the maps test with the same first contact as before (Depot 5.5 s, Square 6.7 s, Spillway 5.8 s median, the same four rounds), and the map report gives the same walks, routes and sightlines, with two small differences: Spillway has 370 long sightline pairs instead of 375 (props block a few), and on Square the bots' walk to A is 62 m instead of 65 m because the re-baked navmesh now includes a 1.4 m gap players could always use. The test map's dressing keeps clear of every test.

**Why:** The layouts were tuned with bots (D-060, D-061); dressing should change the look, not the timing.

**Alternatives:** Redesigning the maps around the new props (a new tuning round, and your playtest of the layouts is still open).

## D-129 — A kit gallery map and a kit test (2026-10-16) — *provisional*

**Decision:** `maps/kit/kit_gallery.map` lays out every texture and entity of the kit, built only from TrenchBroom entities (D-125), and doubles as the guide's picture source and a playable example. `tests/kit_test.tscn` checks the kit: every prop scene loads with a model and the collision its kind needs, every FGD entity has a scene, the gallery's markers and bomb sites work, and a bot round plays on it.

**Built:** `tools/make_kit_gallery.py` writes the gallery's `.map` from the kit itself (every wall texture on a panel of the west wall, every floor texture on a tile, every prop in rows, wall props along the east wall, ceiling lamps under a canopy, glass, fence and clip brushes, and all the gameplay entities), so it stays complete when the kit grows; it is generated, not edited by hand. `tests/maps_test.tscn -- --map res://maps/kit/kit_gallery.tscn` plays bomb rounds and a respawn match on it, with every marker on the navmesh; its first contact is quicker than 5 s, as expected in an open yard that isn't a tuned map.

**Why:** A kit nobody can see is hard to use, and generated files need a check that they still fit together after the next run of the generator.

**Alternatives:** Pictures only (no check); checking props inside the maps test (slower, and mixes kit and maps).

## D-130 — The UI's look comes from your mockups; until then, build what holds whatever the look (2026-10-16) — *provisional*

**Decision:**
- **You design the look** in Claude Design, screen by screen ([UI_MOCKUPS.md](UI_MOCKUPS.md) lists the screens and the ground rules). When a mockup arrives it is the source of truth for that screen: its colours, sizes and spacing go into the theme's tokens, and its layout into the scene.
- **Until then, today's look stays** (D-057). No palette, borders or card style is chosen on your behalf.
- **Meanwhile the UI part of M10 builds what any look needs:** the simpler mode choice and its flow (D-132), the HUD's layout and readability (D-133), a theme where every visual value is a named token and every screen picks roles instead of styling itself (D-131), slots for a pixel icon set, and a screenshot tool that pictures every screen through the real game for before/after comparisons (`tools/ui_screenshots.gd`).

**Why:** Your words: "I'll try to design the UI a bit … its going to be design in claude design". A look chosen now would be thrown away when your mockups come, while the flow, the layout rules and a theme that restyles in one place are needed whatever they show. With every value a token and every screen built from roles, a mockup becomes a set of numbers and a layout, not a rewrite.

**Alternatives:** Pick a modern look now and adjust it to the mockups later (two rounds of restyling, and the first one biases your design); wait and build nothing (the mode choice and HUD layout don't depend on the look); build each screen straight from a mockup without tokens (every screen would carry its own copy of the colours, and the next change would mean editing all of them).

**Built** (M10 UI, 2026-10-16): every screen in your three mockup files is in the game except the boot screen (it waits for the logo file, D-138): main menu, Play, pause, settings, lobby, loading, class draft, the HUD screens 09–13, buy menu, scoreboard, match end and console, each exactly 1.5× at 1080p. The page [Chiip UI Side by Side](https://claude.ai/artifact/Bedjcp1TvtRFUiAqM7TWzn) puts each mockup (rendered from your markup) next to the game's screen; the deliberate differences are listed there and in the "Built" notes of D-135 to D-138. All 31 suites pass (1056 checks).

## D-131 — Theme tokens, roles and icon slots (2026-10-16) — *provisional*

**Decision:**
- **Tokens:** every visual value the theme uses (colours, the fonts, text sizes, borders, paddings, margins, spacings) is a named constant in `tools/ui_palette.gd`. `tools/make_ui_theme.gd` uses only tokens, never a number of its own. A mockup's hex colours, sizes and spacing go there, and the two theme tools run again (CLAUDE.md, Commands).
- **Roles:** screens pick *type variations* (D-057) and never set a colour, font, size or stylebox of their own. New roles are added for what the mockups list (a primary button, a text button, the big mode choices, team-coloured text, the HUD's numbers and labels), in today's look until a mockup says otherwise. The existing role names stay, so M7's buy menu and M9's lobby, built on them, follow along.
- **Icon slots:** the icons the mockups ask for (8 weapons, 3 grenades, armor, helmet, defuse kit, bomb, 4 classes, headshot, health) are looked up by name through the theme (a custom theme type, so they scale with the UI like the other icons). A PNG named after its slot in `assets/ui/icons/` fills it when the theme is rebuilt; an empty slot makes the screen show text instead, as today ("HS", "+").
- **The theme must come out unchanged** by this task: the same look, from tokens.

**Why:** It is what makes D-130 work: one file holds the look, and the screens don't have to be touched to change it. Looking icons up through the theme reuses the scaling that keeps pixel art crisp (D-057) and lets the icon set arrive later without changing code.

**Built** (M10 task 3): 85 tokens in `tools/ui_palette.gd` in six groups (colours, fonts, text sizes, lines, paddings, spacing); the regenerated theme differs from the old one only by additions (no line removed or changed; the icons are byte-identical). New roles: `HeroLabel`, `ModeButton` + `ModeTitleLabel` / `ModeDetailLabel` + `ModeList` / `ModeText`, `PrimaryButton`, `TextButton`, `SegmentRow`, and `friendly_text` / `enemy_text` in `Palette`. The 21 slots are named after M7's weapon ids (`rifle`, `frag`...) and the class ids, so M7's rendered weapon icons and a drawn set use the same names. `ui_test` (139 checks): the theme tool has no numbers of its own (a mutation with one literal fails it), the tokens arrive in the theme, the new roles, the slots, and the old theme checks now compare with the tokens.

**Task 5** (every menu restyles from the theme): the last per-node looks in the menus became roles and tokens: team-coloured scores and the match result (`FriendlyScoreLabel`, `EnemyScoreLabel`, `VictoryLabel`, `DefeatLabel`), the console's monospace font (`ConsoleLabel`, `ConsoleLineEdit`, a `SystemFont` from `FONT_MONO_NAMES`), the swatch spacing, the dim behind every modal menu (`BackdropPanel`, `BACKDROP`), your row's band (`YOU_ROW`, replacing `ScoreboardTable.YOU_ROW_COLOR`) and the dead rows' dimming (`Palette/dead_row`). The theme gained only additions; screenshots of every menu match the earlier ones within the game showing through the panels (at most 3 per colour channel). `ui_test` (153 checks) now builds every menu and fails on any theme override.

**Alternatives:** Tokens in a JSON file read at runtime (the theme is generated anyway, and GDScript constants are checked by the editor); one theme file per look (two copies to keep in step); icons loaded by path in each screen (every screen would need to know the file names and scale them itself); placeholder icons drawn now (they would show up on screen and be thrown away; text is today's look).

## D-132 — Team Deathmatch first, one click to play, the details behind "Custom match" (2026-10-16) — *provisional*

**Decision:**
- **The main menu's page is the mode choice.** Under the game's name, three big choices: **Team Deathmatch** (first, focused when the menu opens, the default), **Bomb** and **Practice**. Each has a line saying what you'll get, built from your last custom choices: "3v3 · Normal bots · first to 50 kills · Depot, Square, Spillway". **One click (or Enter) starts it.** Below them: **Custom match**, **Settings** and **Quit**, and room for M9's Host and Join.
- **Team Deathmatch** is the team respawn mode (D-082), **Bomb** the rounds mode with the bomb (D-080). The settings file keeps the old keys (`respawn`, `rounds`), so saved choices still load. **Practice** is the respawning bot arena, as before.
- **Custom match** is today's match setup, opened over the menu: the mode (Team Deathmatch or Bomb), team sizes, bot difficulty, length, friendly fire, one map or the rotation, the map, a summary, Back and Start. Its choices are what the big buttons use.
- **New defaults** for a fresh settings file: Team Deathmatch, on the rotation of the three quick maps starting on Depot (instead of bomb rounds on the test map). The command-line shortcuts (`-- --match`, `--practice`, `--respawn`) stay as they are, so tests and smoke runs don't change.

**Why:** You asked for modes that are "much more simple to choose" and for Team Deathmatch as the primary mode (D-120). One click from the first screen is as simple as it gets, and the line under each choice tells you what it starts without opening a panel. The details stay one click away. The test map is a range, not a match map, so the default match is on the quick maps, where both modes have spawns, bomb sites and respawn points. Whatever your mockup of the mode choice looks like, this flow is what it shows.

**Built** (M10 task 4): the main page has the three mode buttons (each a container with a `ModeButton` behind two labels: the mode's name and two lines from `MatchSetup.describe_mode()`, the rules and the maps, e.g. "3v3 · Normal bots · first to 50 kills" / "Depot, Square, Spillway"), then **Custom match**, **Settings** and **Quit** as text buttons. One click on Team Deathmatch or Bomb stores the mode and plays the custom choices in it. Match setup is titled Custom match, offers Team Deathmatch first and has a primary Start button. The new defaults are `match_mode = respawn`, `match_rotation = true` and `match_map = Settings.DEFAULT_MATCH_MAP` (Depot); `Settings.DEFAULT_MAP` stays the test map for practice and the menu's background. Because the file saves every value, an older file would have kept the old defaults: the `[match]` section now carries `setup_version = 2`, and loading a file without it puts mode, map and rotation to the new defaults once (other choices stay). Checked: `ui_test` 143 (the page, the lines and how they follow the choices, what one click on each mode leaves for the game, and the real flow: one click on Team Deathmatch starts a team respawn match on Depot with Square next, then Custom match → Bomb on the test map, then Practice); `settings_test` 69 (new defaults, `setup_version` saved, an old file updated and a new one kept); `rotation_test` 13 (the new order and defaults).

**Alternatives:** A Play button that opens a mode screen (two clicks, and the first screen says nothing about the modes); choosing the mode in a row of toggles and pressing Start (today's match setup, which you found too complicated); a Custom panel per mode (two panels with the same rows); a random-mode button (ruled out in D-120); keeping old settings files on their old defaults (you would click Team Deathmatch and land on the test map); a `Button` subclass that measures its labels (Godot's `Button` computes its own minimum size and ignores a script's `_get_minimum_size()`, so a container is simpler).

## D-133 — The HUD: layout and readability first, look from the theme (2026-10-16) — *provisional*

**Decision:**
- **Layout rules** that hold whatever the look: every HUD element is anchored to an edge or the centre of the screen, so it sits right on 16:9, 16:10, 4:3 and ultrawide; the crosshair area stays clear; the information you glance at in a fight (health, ammo, timer, score) is at the screen's edges and big; messages (freeze time, round end, respawn) are centred above the crosshair and short.
- **What it shows**, from UI_MOCKUPS.md: in Team Deathmatch the kills of both teams against the limit and the time left, and after you die "Killed by Bot2" with "Respawning in 3" counting down under it; in Bomb what it shows today. Armor, weapon slots, money and the pickup prompt are being built by M7 in its own branch (in `ui/hud.gd`), so they are not duplicated here.
- **The look comes from the theme:** the HUD's colours, sizes, outlines and shadows become roles and tokens like the menus', so a mockup restyles it in the same place.
- **The F3 debug overlay starts hidden** (F3 shows it), so a first look at the game shows the game.

**Why:** Anchoring and size are what make a HUD readable in a fight, and they don't depend on colours. Today the HUD sets its colours and sizes in its own scenes and code, so a mockup couldn't restyle it from the theme. The respawn countdown and the M7 slots are on your mockup list, so the layout must have room for them. The debug overlay is a developer tool; shown by default it covers a quarter of the screen.

**Built** (M10 task 6, by a Sonnet subagent): 38 `HUD_*` tokens; 25 HUD roles (14 labels such as `HudValueLabel`, `HudTimerLabel`, `HudTitleLabel`, `HudRespawnLabel`; 11 layout roles such as `HudTopBar`, `HudFriendlyBox`, `HudEnemyBox`, `HudTimerBox`, `HudBarBack`); a custom theme type `Hud` with the state colours and the pip size. The scenes `hud.tscn` (its five labels only), `round_hud.tscn` and `bomb_hud.tscn` have no overrides left, and `round_hud.gd` and `bomb_hud.gd` no colour literals (checked). Today's look is unchanged (the health and top-bar pixels are identical in before/after screenshots). The countdown is a `Respawn` label in the round HUD that reads `RespawnMatch.get_respawn_time_left()` for the local player every frame (so it freezes while paused); the death message's "Respawning..." line is now for practice only. Screenshots at 2560 × 1080 and 1440 × 1080 show everything anchored right, so no layout fixes were needed. Left for after M7's merge: `hud.gd`'s low-ammo and low-health colours and the kill feed's look. Tests: 614 checks (round +8, respawn +8, ui +8).

**Alternatives:** Leave the HUD outside the theme (two places to restyle, and they drift); wait for the HUD mockups before touching it (the layout and slots are needed anyway, and M7 builds on them); keep the overlay on by default.

## D-134 — The mockups' Foundations become the theme (2026-10-16) — *provisional*

**Decision:**
- **Your Claude Design mockups are the look** (D-130): the Foundations sheet goes into the tokens and the theme, the Menus and Match sheets into the screens and the HUD.
- **Palette:** VOID `#07090D`, INK `#0B1017`, PANEL `#141B25` at 94%, RAISED `#1C2533`, LINE `#33405A`, MUTE `#5F6C80`, DIM `#9AA8BD`, TEXT `#E6ECF5`; **one lime accent `#C8F03C`, for focus only**; the UI's team colours `#5A94FF` (yours) and `#FF4D3D` (enemy) with fills `#1F4A9E` and `#8F2216`; ALERT `#FFB02E` (bomb, low health and ammo).
- **Type:** Silkscreen at 16, 32, 48 and 96 px; titles (48 and 96) in **Silkscreen Bold**. **8 px grid, 32 px from every screen edge, square corners, 2 px lines.**
- **HUD text gets a hard 2 px shadow** (down and right, in VOID) instead of an outline.
- **Components → roles:** menu items (48 high, 32 px; focus = lime fill, ink text and the 8 px "chip"); buttons (40 high: a 2 px MUTE frame, focus lime, the primary one filled lime with a hard shadow, disabled LINE); segments (a 2 px LINE frame around the choices, the chosen one filled TEXT with ink text); sliders (a 4 px LINE track, a 16 px square knob); value boxes; tabs underlined in lime; key caps.
- **Deliberate differences:** the team colours in the 3D world (the crew's shader, D-073) stay as they are; the mockup's team colours are for the UI only, where they read better on dark ink. A menu item keeps its text in place when it gets the focus chip (Godot's button draws its icon in a fixed slot), where the mockup shifts it right.

**Why:** Your mockups ("I'll try to design the UI … in claude design"). The lime accent, the ink surfaces and the chip are your design; the theme from tasks 3–6 takes them in one place.

**Built** (task 8): `tools/ui_palette.gd` holds the Foundations' colours (VOID, INK, PANEL, RAISED, LINE, MUTE, DIM, TEXT, ACCENT, the UI team colours and fills, ALERT) and sizes (16 / 32 / 48 / 96 px, 32 px page margins, 40 px buttons and 48 px menu items centred on Silkscreen's capitals: its 16 px line box is 21 px with the capitals low, so a 40 px row is 8 + 21 + 11). New roles: `MenuItem`-style `BigButton` (the chip is the button's icon, see-through until hover or focus, through Godot's per-state icon colours), `SmallItemButton`, `PrimaryButton` and `BigPrimaryButton` (the hard shadow is the box grown 2 px right and down with those two edges drawn in VOID), `SegmentButton` in a `SegmentFrame`, `ModeButton` cards, `MuteLabel`, `LargeLabel`, `FriendlyLabel` / `EnemyLabel`, `KeyCapLabel`, `DimKeyCapLabel`, `TagLabel`, `InkPanel`, `SidePanel`, `RaisedPanel`, `PlatePanel`, `CardRow`; titles use Silkscreen Bold. Tabs are spaced by their padding (16 + 16 = the mockup's 32), so the accent underline is 32 px wider than the word. The HUD keeps its look until task 14.

**Alternatives:** Re-colouring the 3D teams to the mockup's colours too (a gameplay readability change for the bots and players, not a UI one; can follow if you want it); a hard shadow with StyleBoxFlat's own shadow (it is always blurred).

## D-135 — Main menu and Play screen as in the mockup (2026-10-16) — *provisional; replaces the one-page mode choice of D-132*

**Decision:**
- **Main menu:** a dark column on the left over the camera flight: CHIIP in 96 px Bold with three chips (blue, red, lime), the menu items **Play** (focused), **Practice**, **Settings**, **Quit**, a line, then **Host** and **Join** marked "soon" (M9 fills them). The build at the bottom left, the background's map name at the bottom right.
- **Play** opens the **Play screen**: three mode cards, **Team Deathmatch** (first, focused, marked DEFAULT), **Bomb** and **Practice**. A click on the focused card plays it ("click to play"), a click on another card picks it; the big **Play** button plays the picked mode. Under the cards, **Custom** shows the picked mode's options as rows of segments: map (Depot, Square, Spillway, Rotation), kill limit (25, 50, 75, 100) or rounds (first to 5, 10, 15), teams (chips for both sides), match length (5, 10, 15 min, Team Deathmatch), bots (Easy, Normal, Hard), friendly fire. Remembered, as before. Esc goes back.
- **New options from the mockup:** the kill limit offers 25 and 100 too (30 is gone), and Team Deathmatch's time limit (10 min until now) can be 5, 10 or 15 min.
- One click still plays Team Deathmatch from the Play screen; from the start of the game it is two (Play, then the card), as the mockup has it.

**Why:** Your mockup's Menus sheet. It keeps the mode choice simple (D-120) while the main menu stays a short list.

**Built** (task 9): `ui/main_menu.tscn` is the left column (a `SidePanel` 448 px wide, `LogoLabel` CHIIP with the three chips, `BigButton` menu items with the chip icon, a line, `SmallItemButton` Host and Join with "Soon", the build and the background's map name). `ui/match_setup.tscn` (still `MatchSetup`) is the Play screen: the cards are containers with a `ModeButton` behind their labels (the picked one `ModeButtonPicked`, framed lime, "Click to play"; the others say what they'd play), the rows are `SegmentButton`s in a `SegmentFrame`, the map row stands for two settings (a quick map, or `match_rotation`), the team sizes are chips (toggle buttons, filled up to the size), Practice shows only the bots' row. New setting `match_time_limit` (5, 10, 15 min; `MatchSettings.time_limit`); `Settings.KILL_LIMITS` is 25, 50, 75, 100. `UiTheme.apply()` now also scales the offsets of controls placed by anchors (the menu's column), so the layout is exactly 1.5× at 1080p. **Differences from the mockup:** the background flies over the test map, so the corner says "Test Map" (the flight was built for it); the studio logo next to it is left out (it's an image on the web); the build reads "Build M10"; the hint says "Click to choose · the setup is remembered" (segments are clicked, not cycled); a focused menu item's text doesn't shift right (D-134).

**Alternatives:** Keeping D-132's one-page choice (it is not what you designed).

## D-136 — The HUD as in the mockup (2026-10-16) — *provisional*

**Decision:** The Match sheet's HUD: Team Deathmatch's top bar (both scores in 48 px team colours, each with a bar filling toward the kill limit, the clock and "First to 50"); Bomb's (squares for players alive, filled or framed, the scores, the clock or the amber BOMB plate, the round); banners centred 96 px from the top ("Round won" 48 px Bold in your colour, the reason under it); the death screen in Team Deathmatch (a grey tint, the countdown in 96 px Bold, a plate "Killed by Bot4 [gun] · Respawning in 3" and the killer's health left); spectating as a plate at the bottom; health with its icon, 48 px and ten chips, ammo 48 px with the reserve in 32 px; kill-feed plates (72% ink; your kills framed white, your deaths framed red; gun icons, the headshot mark; 6 s); toasts under the top bar (switching sides, match point, bomb planted, low ammo; 2.5 s); a hit marker (four corners, white, amber on a headshot, 150 ms). Exact values in the tokens when built. Armor, money, the weapon slots and pickups are M7's, built to the same mockup there.

**Why:** Your mockup; it also fixes what D-133 left open (the look).

**Built: part A** (task 14, by a Sonnet subagent): the corners, top bars, banners, the death screen and spectating as described above. All HUD text has the hard 2 px VOID shadow and no outline; `UiScale` scales shadows, plates and the trimmed fonts too. The big fonts' line boxes are trimmed to their size (CSS line-height), or every gap would come out larger than drawn. Bottom left: health with its icon (and the ten chips in Team Deathmatch and practice), armor or helmet with its icon (hidden at 0), the kit; in Bomb the money ("B Buy" while the buy menu can open, M7's reward lines after it). Bottom right: the weapon's name and icon, the magazine and "/ reserve" at 70%. Team Deathmatch's top bar has the scores with bars filling toward the kill limit; Bomb's the alive chips (filled or framed), scores, the clock and "Round N", or the amber Bomb plate once planted. The Bomb layout is used whenever the match has an economy. Dead: the grey tint, the 96 px countdown and the "Killed by" plate (the respawn countdown moved from `RoundHud` to `hud.gd`); spectating: the mini stats and the plate. Differences: M7's weapon-slots line is hidden (the mockup has none; its data stays); `ui/armor_icon.gd` is gone (the icon slots replace it); the freeze countdown is plain white (the mockup has no yellow).

**Built: part B** (task 14, by a Sonnet subagent): the kill feed's plates (32 high, ink 72%, killer · weapon icon by `WeaponData.id` · headshot mark · victim in team colours; your kill framed white, your death framed red, the bomb's kills with the amber bomb icon and no killer; 5 lines, 6 s, then a 0.5 s fade); the carry plate (amber "Bomb") at the top of the bottom-right column; the plant/defuse prompt (the E key cap, then the bomb or kit icon with the seconds left in amber and a 320 × 8 amber bar); toasts (`ui/toast_stack.gd`, `ToastStack`, centred under the top bar, 2.5 s, frozen while paused): "Switching sides" and the bomb news on ink, "Match point" on white, "Bomb planted at A" on amber, "Low ammo · R reload" framed amber (once per magazine, not with an empty reserve); the freeze banner keeps only the countdown and your side's line. The hit marker (`ui/hit_marker.gd`, `HitMarker`): four L-shaped corners from 14 to 26 px around the centre, white on a body hit, amber on a headshot, 150 ms, on the shown character's `hit_landed` (it reconnects on `weapon_changed`). Differences: the framed feed plates stay 32 high (the frame sits inside the padding, so the names line up); toasts don't slide in, the same text restarts its toast, at most 4 show.

## D-137 — Settings, pause, scoreboard, match end, class menu and console as in the mockup (2026-10-16) — *provisional*

**Built: settings** (task 10, by a Sonnet subagent): as described below, measured against the mockup at 720p (title at 32, tabs at 104, rows from 176, 400 / 480 / 80 × 32 px, swatches, 240 px preview squares, the controls table, the footer ending at 688) and exactly 1.5× at 1080p. Differences: the hex box stays after the swatches (any colour can be set today); the crosshair's numbers are plain text as in the mockup, so they can't be typed; the frame limit offers 120 as well; the controls table starts 8 px lower than drawn and scrolls; the notice line under it shows a hint when idle; the default crosshair colour is now the mockup's `#36D07A`; the page's crosshair column wraps under the rows in narrow windows.

**Built: pause, scoreboard, match end** (task 11): as described below. Differences: the pause menu's online line is there but hidden until M9; M7's money column, the kit mark and "(you)" stay in the table; a rounds match is called Bomb everywhere; the clock line also says "Planted", "Over" and "Overtime"; big text is trimmed to the mockup's line heights (Silkscreen's line box is taller); a 5v5 scoreboard's bottom padding runs off a 720p screen. New `ui/match_text.gd` (`MatchText`) makes the mode · map and clock lines for both screens.

**Decision:** Settings becomes a full ink screen with underlined tabs, 48 px rows (label 400 px), segments for on/off and for short choices, sliders with value boxes, the crosshair preview on a dark and a light square, a controls table (key caps, "Press a key…" in lime), Reset and Back at the bottom. The pause menu is a centred list over the dimmed game. The Tab scoreboard and the match-end screen get the mockup's table (class icon, player, K, D, A, DMG; team lines; your row framed in lime; dead rows muted) and header (scores, mode and map, the clock). The class menu gets the draft's cards (the class's icon large in your colour, the key, height, role, perk in lime, the gun with its icon). The console becomes a VOID strip with a lime prompt and Silkscreen text. Details and any differences are recorded when each is built.

**Built: console** (task 13, by a Sonnet subagent): a 384 px VOID strip with the LINE edge, Silkscreen 16 at a 24 px line height (the system monospace font is gone, `FONT_MONO_NAMES` removed; `help` and `class` print `name · description` instead of padded columns), the banner in MUTE, echoed commands in DIM, errors in ALERT (`ConsoleErrorLabel`, through `print_error()`), the 48 px INK input row with a lime `>`, a 10 px lime caret and the hint "Tab completes · Up history". Tab completes a command name (one match: the name and a space; several: their common start; a second Tab lists them). Differences: 11 lines fit, so `help` scrolls (Page Up / wheel); the caret is a 10 px bar as tall as the text, after the last letter; no placeholder text (the hint says it).

**Built: the lobby** (after M9's merge, by a Sonnet subagent): `ui/lobby_menu.tscn` follows mockup 06 on two pages. The **Lobby** page: the title, "Hosted by you · address:port" (or "Connected to …"), Esc + Leave; a left column with your name and, for the host, "Friends join at" and the LAN addresses; two team columns (a 2 px line in the team colour, "3 / 5"), your row raised with the lime chip and "Host", empty slots framed with "Empty · Bot"; Switch team (replacing M9's two Join team buttons); the footer with Mode / Map / Limit, Edit setup and Start (host), or "Waiting for the host to start" (client). The **Join** page: name, Join by IP (address and port) and Join, the status line (amber for errors), and Host game. The main menu's Host and Join items replace M9's Multiplayer button (Host hosts at once, Join opens the Join page). Match setup opened from the lobby hides Practice and doesn't start a game when its picked card is clicked (`MatchSetup.set_online()`). Clients get the footer's facts from the host (`NetLobby.publish()` carries them). Differences: no Steam friends and no ready state (Chiip has neither yet); the left column shows your name and the addresses instead of Join by IP (you are already in a lobby); the empty-slot frame is solid, not dashed; online the pause menu's title stays M9's "Menu" (it doesn't pause), with the mockup's line "Online · the match keeps running".

**Built: class draft** (task 12, by a Sonnet subagent): mockup 08 on M7's class menu: "Pick a class", "2 of 4 offered · starts in 12" ("any time" in practice and team respawn), 400 × 480 cards (the class icon ×10 in the friendly blue on a raised picture area, the key chip, the height, the name and role, the perk in lime with its text, the signature gun and its icon), the hint at the bottom. Hover or focus moves the lime frame and chip; a click or 1 / 2 picks. Where all four classes show (practice, the draft off) the cards go compact (288 wide, 16 apart) to fit 1280. `ClassData.role` is now the short word (All-round, Anchor, Long range, Flanker); two perk texts are shorter on the card (same numbers). Differences: the gun line reads the signature weapon's name ("Hornet (SMG)"); the perk lines are a few pixels tighter than drawn; the HUD stays visible behind the dim (to be hidden with the buy menu's change).

**Built: buy menu** (by a Sonnet subagent): mockup 14 on M7's buy menu: "Buy", your side and the buy time left ("Practice · any time" in practice, where everything is free), the money in 48 px, four columns (M7's Mid-tier and Rifles folded into Primaries, cheapest first: `Shop.Category` has four values now), 64 px items with the icon at 2× and four looks (ok, focused in lime, owned, too expensive), the footer with "You hold" and the icons of what you carry, and a refusal's reason in amber where the hint is. Items take focus, so the arrow keys and Enter buy too. While the buy menu or the class menu is open the HUD and crosshair hide (`main.gd`'s `_update_hud_visibility()`), as both mockups show only the dimmed world; the pause menu, scoreboard and console leave the HUD alone. Differences: "Vest + helmet" is "Vest + helm" (the column is 286 px); a grenade shows Owned only once you carry its maximum; the kit looks too expensive for attackers (it isn't theirs to buy); items have no key numbers.

## D-138 — A loading screen between maps; the boot screen waits for a logo (2026-10-16) — *provisional*

**Decision:** When a match starts or the rotation moves on, the mockup's loading screen shows the map's name in 96 px Bold, "Map 2 of 3 · Rotation", the mode and the limit, and a row of chips while the map loads. The boot screen with the studio logo is left out until the logo exists as a file in the project *(built in M11 with a stand-in until the file comes, D-153)* (the mockup links an image on the web, and a download needs your OK).

**Built** (task 15, by a Sonnet subagent): `ui/loading_screen.tscn` (`LoadingScreen`), the last node of `main.tscn`. It shows when a match starts from the main menu (a pending `GameLaunch`) and on `next_map()`, not on Play again, the console's `map` or the command-line flags. The map is already loaded when the band is drawn (on `next_map()` the screen comes first, then the load), so the world behind it is the real map, standing still: the screen pauses the tree for its `hold_time` (1.5 s) while the 12 chips fill, then unpauses. While it shows it swallows every input event in `_input()` (it is the last node, so it sees them first) and the Tab scoreboard checks `LoadingScreen.is_showing()`; it doesn't register with `MenuState`. *(The class menu used to open under it at a match start; changed by D-152.)* The lines come from `MatchText.loading_lines()`: "Map 2 of 3 · Rotation" (or the mode's name, or "Practice"), the map's title, "Team Deathmatch · first to 50" / "Bomb · first to N rounds". Tests that start games through `GameLaunch` switch it off (`main.loading_screen`, or the static `LoadingScreen.enabled` for flows that change scenes). Alternatives: real background loading with `ResourceLoader.load_threaded_request()` (the maps load in a fraction of a second, so the chips would barely show; the hold gives time to read the map's name), and a full-screen card without the world (the mockup shows the map). Differences: mixed-case text as on the other screens; on Next map the match-end screen stays under the band until the new map has loaded.

**Online (merge with M9):** an online game never shows the loading screen (`main.gd` `_shows_loading_screen()` is false while `net_session != null`). The screen pauses the whole tree, and in multiplayer nobody can pause the other players (D-109); the host would freeze the match for everyone, and a client's map is chosen by the lobby anyway. The alternative, a band that doesn't pause, would let you move and shoot behind it.

## D-139 — The icon set comes from the mockup's drawing, as PNGs (2026-10-16) — *provisional*

**Decision:** The mockup draws its 21 icons as rectangles on a 32 × 16 (weapons) or 16 × 16 grid in one colour. `tools/generate_ui_icons.gd` draws the same rectangles into white PNGs in `assets/ui/icons/`, one pixel per grid cell, named after the icon slots (D-131; the mockup's `handcannon`, `he`, `flash`, `kit` are the slots `hand_cannon`, `frag`, `flashbang`, `defuse_kit`). Screens tint them (white → any colour) and scale them by whole steps with nearest filtering, as the mockup shows them at 1×, 2× and 10×.

**Why:** One source for the drawings (the mockup), crisp at every scale, and one PNG per slot so the theme picks them up as designed in D-131.

**Built** (task 8): all 21 slots are filled (the headshot mark's eye is cut out even-odd, as in the mockup). At 1080p the UI is 1.5×, so a one-pixel cell becomes 1–2 screen pixels; whole-number scaling where a screen shows an icon large (the class cards) keeps those crisp.
## D-140 — Map textures are drawn like the crew, not made from photos (2026-10-16) — *provisional; replaces D-024 and the photo sources of D-121*

**Decision:**
- **Every map texture is drawn by `tools/make_world_textures.py`**, the way the crew is painted (D-054, `tools/modelgen/paint.py`): a base shade on one of the crew's 16-shade ramps (or the props' ramps), a pattern that says what the surface is (boards, blocks, bricks, stones, panels, tiles, ribs, gravel, grass blades) with one-texel joints, and only ±1-shade grain. Big wooden and green surfaces are muted toward grey, like the crew's kit. Same names, folders, sizes (64 × 64 for 1.63 m) and sound words as before (D-121), so no map had to be rebuilt.
- **No photo texture ships any more:** the 36 ambientCG-based textures (the M3 eight and the kit's 28) and the five recoloured or drawn ones are replaced by 41 generated ones, the chain-link and the glass included. `tools/texture_prep.py` and `tools/make_kit_textures.py` are gone (their work is in the new tool); `tools/make_retro_texture.gd` stays for a mapper who wants a photo texture on a map of their own.
- **A new texture is a painter function** in the tool's table (a ramp, a base shade, a pattern), not a download.

**Why:** Your feedback: *"I dont like the texturing of maps, it doesnt match the players design, that should be fixed"*. The crew is flat, low-poly and palette-limited, with clean shapes and little noise; photo textures, even shrunk to 64 × 64, kept their blotches (the plaster's camouflage pattern, mottled concrete, photo wood grain) and looked busier and more realistic next to the players.

**Compared** in the real game with two bots of each team standing in every shot (new `--lineup` option of `tools/map_screenshots.gd`), on Depot, Square and Spillway:
1. **Generated like the crew** (chosen): clean boards, blocks, ribs and stones that read as the same world as the players; the players still stand out.
2. **The photo textures quantized onto the crew's ramps** (blurred, about five shades): flatter, but the photo blotches became mush at 480 lines.
3. **A mix** (generated walls, floors and metal, quantized photos for stones, rock, bark, grass, dirt, gravel): the natural surfaces kept the mush.

**Checked:** all 41 pass `tools/texture_report.gd` (no team red or blue; average saturation at most 0.45, wood the warmest); in the screenshots below the horizon, team red at most 0.9 % and team blue at most 0.4 % of a shot (the photo textures: 1.3 % and 0.5 %). The rusty ribbed metal had to be muted further: its darkest shades turned reddish in shade after lighting and the palette effect (3 % of a shot on Depot's boxcar).

**Alternatives:** the two other directions above; hand-drawn pixel art (better ceiling, but no artist and nothing to regenerate); keeping photos for a "realistic" look (what you asked to fix).

## D-141 — Practice is a Shooting Range; the test map is hidden (2026-10-16) — *provisional*

**Decision:**
- **A new practice map, `maps/shooting_range`** (a TrenchBroom map built with the kit, in the crew-matched look of D-140): kept simple, as you asked (*"neco jednoducheho"*): one walled yard with lanes, targets at 5, 10, 20 and 40 m and one moving at 15 m, a spray wall, a stand for every gun and grenade, distance lines and signs, and a small open area behind the stands where bots can fight. Layout in MAPS.md. (A first, bigger version, with a separate 44 × 36 m arena, a second moving target and a head-only target, was cut down to this the same day.)
- **Practice plays it:** the main menu's Practice button and `-- --practice` without `--map` (both through `Settings.DEFAULT_MAP`).
- **It starts with no bots.** The console adds them (`bot_add [easy|normal|hard] [ally|enemy]`, `bot_kick [all]`, `bot_difficulty`); they appear at the arena's bot spawns, at least 20 m from you. A map tells practice how many bots to start with by metadata on its scene's root, `practice_bots` (`ArenaRules.START_BOTS_META`), which main.gd reads; without it practice starts with ArenaRules' two, as before.
- **The test map is hidden** from everything the player is offered: `GameLaunch.HIDDEN_MAPS` lists it, and `GameLaunch.list_maps()` (match setup and the lobby) and the console's map list leave it out. The rotation never had it. It stays for the automated tests and still loads by name: `map test_map`, `-- --map res://maps/test_map.tscn`.
- **Match setup doesn't offer the range** (it has no team spawns, so it can't host a match); the console's map list does. `map shooting_range` from a match plays it as practice (main.gd picks practice rules on a map without team spawns).
- **The default match map is Depot** (`Settings.DEFAULT_MATCH_MAP`, the constant the UI refresh introduces too, D-132): the map match setup starts with and falls back to must be one it offers. **`Settings.DEFAULT_MAP` is the practice map**, the Shooting Range (until now the test map, which was both).
- **What stays on the test map:** main.gd's own fallback (`map_scene`, for a game scene started with no menu description and no `--map`: the tests and `-- --match`), the match test (now explicitly), and the main menu's background flight, whose camera path in `ui/main_menu.tscn` is drawn for the test map. That scene belongs to the menu restyle, so the background is left for it.

**Why:** Your words: *"jeste vec k testovaci mape, radeji postav sample shooting range s optional pridanim botum skrze konzoli, tady ten test co tam je nyni bych nechal neviditelny"* (about the test map: rather build a sample shooting range with optional bots added through the console, and keep the current test map invisible).

**Alternatives:**
- **Deleting the test map:** about fifteen suites rely on its small layout and quick rounds.
- **Moving it to `tests/`:** breaks the path in every suite and in the menu, when hiding it by data is enough.
- **A range room added to the test map:** you want that map out of sight.
- **Practice on Depot with no bots:** no targets and no guns to try.
- **The starting bot count as a worldspawn property:** the worldspawn node is buried under `Map`, while metadata on the root is one line.
- **An ArenaRules export saved in the map:** main.gd adds ArenaRules at runtime; maps don't contain it.
- **Practice always starting empty:** practice on another map (the console's `map`) keeps its two bots, and tests rely on that.

## D-142 — Range entities for training maps (2026-10-16) — *provisional*

**Decision:** four entities in `maps/fgd/chiip_mapper_fgd.tres`, so a training map is made in TrenchBroom alone:
- **`range_target`**: the training dummy (`maps/props/target_dummy.tscn`: CS hit zones, a floating number per hit, a running total), with `title`, `move_distance` and `move_speed`; a moving one walks across its angle.
- **`range_weapon`** (`KitWeaponStand`): one gun, chosen from a list, floating over the gold ring of the map weapons (D-098). It comes back 2 s after it's taken (`refill_time`). For training maps only: in a match, guns still come from the buy menu and the random map weapons.
- **`sign_text`** (`KitTextSign`, a `Label3D`): text in the pixel font, read from the side the angle points to, or always facing you (`billboard`); `\n` makes a new line.
- **`info_bot_spawn`**: where practice bots appear and come back (group `bot_spawns` only). You come back where you started.

**Why:** the range is built only from TrenchBroom entities, like the kit gallery (D-129), so a mapper can change it or make another training map without touching Godot.

**Alternatives:**
- **Hand-placing dummies and guns in the scene:** invisible in TrenchBroom, so not reusable.
- **`info_respawn` for the bots:** it is a player spawn too, so you would come back in the open area among the bots.
- **`MapWeapons` with a fixed pool:** it puts guns at random places and is made for rounds.
- **Leaving grenades to the buy menu:** the stands let you throw one after another without opening a menu.

## D-150 — M11 polish and M12 sharing (2026-10-16)

**Decision:**
- **M11 Polish:** UI scaling for any window and fullscreen, weapons and models (no wall clipping, correct holds and reloads), optimization.
- **M12 Share & playtest**, with your choices:
  - **GPL-3.0** for the code and **CC BY-NC-SA 4.0** for art, models, maps and sounds
  - builds on **GitHub Releases** from a **public repo**
  - online play **only through Tailscale**, so nothing is opened on your router
  - no Steam for now
  - exports and the public repo only after your OK

**Why:** In your words:
- "when I expanded on the full screen it completely fucked up the UI"
- guns must not go "through wall", "models are holding them correctly, reloading guns goes correctly"
- "hrani s kamarady by melo jit zdarma i mimo mac" (playing with friends should be free and work beyond the Mac)
- "repo chci verejne idealne ale chci to nasdilet nekam at si to muzem zahrat s kamosema … musi byt bezpecne nasdiletelne" (ideally a public repo, shared somewhere so friends can play it, and safe to share)

**Alternatives:** MIT, or source-available only; itch.io with a restricted page; UPnP and direct-IP play (it opens a port on the host's router).

## D-151 — The UI scales by the tighter of width and height, in half steps (2026-10-16)

**Decision:**
- **The UI scale is the tighter of window width / 1280 and window height / 720** (`PixelView.ui_scale_for()`), so the 1280 × 720 layout always fits, whatever the window's shape. From 1.0 up it is rounded down to a half step (1, 1.5, 2, 2.5 …), because Silkscreen draws every one of its pixels as a whole number of screen pixels only at those steps (16 px text: 2 px per pixel at 1×, 3 at 1.5×, 4 at 2×); in between they come out uneven. Below 1.0 (a small window, or the pixelated HUD's low-res image) it is the exact fit.
- 1280 × 720 → 1, 1920 × 1080 → 1.5, 2560 × 1440, 3440 × 1440 and 2560 × 1600 → 2, **2920 × 1753 → 2** (width-bound: 2920 / 1280 = 2.28), 1440 × 1080 → 1.
- `PixelView.apply()` now returns the **factor** (it returned the UI height); `main.gd` and `MainMenu` hand it to every menu, the HUD, the console and the loading screen. Both already re-run on `Window.size_changed`, which a drag, a fullscreen switch and the editor's embedded game view all emit, so a resize re-lays everything out.
- **The Play screen's three mode cards are equally wide in any window:** their description and last lines wrap (`autowrap_mode`) instead of widening the card. That was the second half of your cut-off screenshot: the page's minimum width was 1338 design pixels (the Practice card's one-line text made it the widest), more than the 1280 the layout is designed for, so even a 16:9 window showed it cut. It is 894 now.

**Why:** Your screenshot of the editor's game view at 2920 × 1753 showed "LAY" for "PLAY", "EAM DEATHMATCH" and the right column cut off, and *"when I expanded on the full screen it completely fucked up the UI"*. The old rule was window height / 720: 2.43 there, a layout 1199 design pixels wide in a 1280-wide design.

**Alternatives:**
- **Exact fit, no steps** (2.28 there): the text would be 36.5 px, which the font engine rounds, so the pixel font's pixels come out 4 or 5 px wide at random.
- **Whole steps only** (1×, 2×): 1920 × 1080 would drop from the mockups' exact 1.5× to 1×.
- **Fixed 16:9 canvas with bars** (`content_scale_aspect = keep`): the ultrawide would waste its sides; the mockups' rule is to anchor to the edges.

## D-152 — The class draft opens after the loading screen, not under it (2026-10-16)

**Decision:**
- **A match start's class draft waits for the loading band to hide.** `ClassMenu.can_open()` is false while `LoadingScreen.is_showing()`; when the match start asks the menu to open (`set_rules()` with round 1 under way, or `round_started(1)`), it remembers that (`_open_pending`) and `main.gd` calls `ClassMenu.open_if_pending()` when the loading screen emits `finished`. Rotation changes (`next_map()`) work the same way, and the band still hides itself only after its 1.5 s hold, as in the mockup.
- **`main.gd` shows the band before it spawns a launched map** (`_load_map()`), not after. It used to show it second, so the class draft had already opened by then.
- **Layers, checked:** loading screen 20 and boot screen 30 stand above every menu (class draft 4, pause 4, settings 6, console 10); the layout test checks that no visible layer sits above the draft once the map is loaded.

**Why:** Your screenshot showed the band ("Map 1 of 3 · Rotation / Spillway / …/ Loading") over the lower part of the class cards. The band is meant to hide while the map is up, but D-138 let the draft open at the same moment, so for the 1.5 s hold (longer when the load stalls) the band covered the cards.

**Alternatives:** shortening the hold to nothing once the map is ready (the band is the mockup's, and the map name needs time to be read); lowering the band's layer under the draft (the band would then show through the dimmed draft and look like part of it); hiding the band when the draft opens (the band also pauses the game, so the draft would open on a game that is still held).

## D-153 — The boot screen and the studio logo (2026-10-16)

**Decision:**
- **There is a boot screen now** (`ui/boot_screen.tscn`, `BootScreen`, the mockup's "01 Boot"): the studio logo (112 × 112 picture shown 224 design pixels wide), the name **Divocakos** under it, a row of eight squares that fill over 2.5 s and "Any key to skip". The main menu shows it **once per run**, over the menu, when the game starts on the menu (not with `-- --match`, `--practice`, `--map`, `--host` or `--join`, not in a headless run, not when the menu comes back from a match). Any key or click skips it and nothing reaches the menu under it.
- **The logo is the studio's own** (`assets/ui/studio_logo.png`, a laughing watermelon, supplied by you on 2026-10-16) with a half-size copy for the main menu (`assets/ui/studio_logo_small.png`, Lanczos-reduced by `tools/make_studio_logo.py`). **Whole steps only:** the boot logo is 224 design pixels × the UI scale, which is a whole multiple of its 112 pixels at every half step (2× at 1.0, 3× at 1.5, 4× at 2.0); the corner mark is 56 px × the whole part of the scale, from the small picture at odd steps and the full one at even steps. The picture is smooth artwork, not pixel art, so the nearest filtering the UI gives every control shows no blockiness, only equal pixels.
- **The main menu shows it small:** a mark in the bottom right corner with the map's name beside it (the mockup), and "Build M10 · Divocakos" in the footer. There is no credits screen in the game yet; the credits are `docs/CREDITS.md` (M12's third-party notices can add one).
- **Rights:** the logo and the name "Divocakos" are **all rights reserved**, outside the planned CC BY-NC-SA 4.0 for the game's art (D-150): recorded in `docs/CREDITS.md`, to be written into the licence files in M12.
- **If a file is missing** the boot screen shows the game's name in the logo's place and the corner mark hides, so nothing breaks.

**Why:** Your words: *"logo naseho studia se nenacetlo vubec v podstate"* (the studio logo basically didn't load at all). D-138 left the boot screen out because the logo wasn't a file, and nothing in the game referred to one: the mockup copy in the project had the image link replaced by placeholder text. You then sent the real file.

**Alternatives:** a Godot boot splash in `project.godot` (`application/boot_splash`; the engine shows it before the game loads, it can't be skipped or animated, and the menu is the first screen anyway); showing the boot screen every time the menu opens (it would delay every return from a match); scaling the 112 px picture to the mockup's 56 px with nearest filtering (drops every other pixel of smooth artwork: jagged); drawing a pixel-art version (the studio's mark is theirs to redraw).

## D-154 — A layout test at seven window sizes (2026-10-16)

**Decision:** `tests/layout_test.tscn` (suite `layout`, in `tools/run_tests.sh`) resizes the real root window to 1280 × 720, 1920 × 1080, 2560 × 1440, 2920 × 1753 (your screenshot), 3440 × 1440, 2560 × 1600 and 1440 × 1080, by setting `Window.size` (which emits `size_changed`, so it goes through the menus' own wiring, nothing calls `apply_pixel_settings()` for them). At each size it opens every menu in turn and checks that **every visible control lies inside the window** (a scroll box's contents may run past its edge, the box may not): the main menu (page, Play with each of its three modes, the lobby's connect page, all five settings tabs, also with the pixelated HUD on), and in a real Bomb game and Team Deathmatch game the HUD, class draft, buy menu, pause menu, Tab scoreboard, console and match-end screen; then the loading screen and the boot screen. It also checks the scale rule, that **after loading nothing covers the class draft** (loading screen hidden, game unpaused, draft open, no visible layer above the draft), and that a runtime resize re-lays out a menu without anyone calling it.

**Why:** The cut-off screens came from two things no existing test measured: the scale rule, and a page whose minimum width was more than the layout width. Rects in a real window are what you see; the earlier checks looked at font sizes and minimum sizes only. With the old height-only rule and the cards' text unwrapped, the new suite fails on the Play screen at 2920 × 1753, 2560 × 1600 and the pixelated 1280 × 720.

**Notes:** A headless run's root window can be resized and keeps its size, so the real window sizes are tested without opening a window. The lobby's team page (needs a session) and the kill feed's moving lines aren't scanned.

**Alternatives:** a screenshot comparison per size (heavy, and a human has to look); testing only the scale function (misses a page that is wider than the layout).

## D-180 — A minimal compass on the HUD that shows where enemies shoot (2026-10-16)

**Decision:**
- **A thin compass strip at the top centre of the HUD** (`ui/compass.gd`, `Compass`): N, E, S and W with small ticks every 15° (taller every 45°), a short pointer in the middle, turning with your view, 120° across 400 design pixels. In the HUD's look: Silkscreen 16 px, hard 2 px shadows, the TEXT, MUTE and enemy colours of the palette. Its sizes are tokens (`HUD_COMPASS_*` in `tools/ui_palette.gd`, the theme's "Hud" type).
- **Enemies show only when they shoot:** a small red square at the bearing of the shot, fading out over the last second of two. One square per enemy (his next shot moves it); only shots within 60 m (`Noises.GUNSHOT_RANGE`, the range bots hear them from); never your team's or your own; further than 60° to the side it sits on the strip's end, so you know which way to turn. No other markers, and **no A/B site letters** in Bomb (optional in the brief; left out to keep it minimal).
- **A new signal for it, `Noises.shot_fired`**, emitted by `Noises.announce_shot()` from `Weapon._fire()` (the host's, the bots', single player) **and from `Weapon.play_remote_shot()`** (a client sees other players' shots as replays from the host, D-104). `noise_made` stays as it was. So it works online with nothing new from the host.
- **The top bar and the toasts moved down 16 px** (bar 24 → 40, toasts 112 → 128) to make room: compass at 8 to 32, the kill feed (32) starts under it. The layout test checks, at all seven window sizes, that the compass lies inside the window and doesn't touch the bar, the toasts, the kill feed or the banners.
- The compass hides while you are dead (the death view) and shows while you spectate a teammate, with their view.

**Why:** Your words: just a simpler compass, "nothing fancy, very minimal", with enemies on it "when they shoot".

**Alternatives:**
- **Using `noise_made` itself:** it also carries footsteps, grenade blasts and the bomb's noise, which would need telling apart by their range, and a client never gets a noise for another player's shot (the replay `play_remote_shot()` makes none, on purpose: a global bus is shared by two games in one test process, and bots listen to it).
- **Marking every enemy continuously, or on sight:** wallhack-like; the point is to answer the shot you heard but couldn't place.
- **Leaving the bar where it was and putting the compass under the toasts:** the toasts come and go below it and the compass would jump around.

## Open questions

| Question | Decide in |
|---|---|
| On macOS, does Ctrl + click clash with crouch + shoot? | M3 (your check) |
| Weapon names: proposed and applied provisionally (D-090) | Your check |
| Team names and the game's setting/theme | Any time |
| Publishing on Steam: Steamworks account, $100 fee per game, store page, "coming soon" at least 2 weeks before launch | Later |
