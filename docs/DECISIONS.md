# Chiip — Decision Log

> Important decisions: what was decided, why, and what else was considered. Newest entries go at the bottom.
>
> Decisions can be revisited. When one changes, add a new entry that replaces the old one instead of rewriting history, and mark the old one as *Replaced by D-xxx*.
>
> Last updated: 2026-10-15

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

## D-024 — Textures: CC0 photo textures turned retro by our own tool (2026-10-15)

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

## Open questions

| Question | Decide in |
|---|---|
| On macOS, does Ctrl + click clash with crouch + shoot? | M3 (your check) |
| Weapon names | M7 |
| Team names and the game's setting/theme | Any time |
| Publishing on Steam: Steamworks account, $100 fee per game, store page, "coming soon" at least 2 weeks before launch | Later |
