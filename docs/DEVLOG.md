# Chiip — Devlog

> One entry per work session, newest at the top: what was done, which decisions were made, and what's next.

## 2026-10-15 — M8 modes

Continues M8 on the `m8-maps` branch, in parallel with M5 (main checkout) and M6 (its own worktree).

**Done**
- **The bomb** (D-080, provisional): CS's rules on the three quick maps. A random attacker carries it on their back; hold **E** inside site A or B for 3.2 s to plant (you can't move meanwhile, and letting go starts over); the round clock stops and the timer shows "BOMB"; it beeps faster and faster and explodes after 40 s (lethal out to about 13 m); a defender holds E next to it for 10 s to defuse (a kit will halve that in M7: `Bomb.kit_check` is the hook). If the carrier dies, the bomb drops and the next attacker who walks over it picks it up. After a plant, the defenders must defuse even if every attacker is dead. New `use` input action (E) and `CharacterInput.use`, so bots will plant and defuse by the same rule. HUD: a BOMB tag, plant/defuse prompts with a progress bar, and messages. Generated beep, key-press, wire-click and explosion sounds. New `tests/bomb_test.tscn` (26 checks); all other suites still pass (movement 13, weapon 20, bot 16, round 74, tactics 4, ui 35, maps 15).

**Next:** bots play the objective (carry, plant, rotate, retake, defuse), then the team respawn mode.

## 2026-10-15 — Three quick maps (M8, started early)

Built alongside M5 in its own branch (`m8-maps`), so the game has a map rotation.

**Done**
- You approved three layouts from top-down plans and kept the placeholder names: **Depot** (freight yard: indoor warehouse mid, container yard, loading dock), **Square** (old town: open plaza mid, zig-zag alley, covered market hall) and **Spillway** (dry water works: sunken channel mid, pump house, tank yard with a terrace). Each is 46–48 × 56 m with three lanes, two bomb sites, 5 spawns per side, bot routes and hold spots, 12 respawn points and patrol points (D-060). Plans, rules and numbers: [MAPS.md](MAPS.md).
- Each map has its own lighting mood within cool daylight: today's daylight, a low morning sun, and an overcast sky (D-062).
- New `tests/maps_test.tscn` checks every map's markers, navmesh and paths, and plays seeded bot rounds. First contact (median of 4 rounds): Depot 5.7 s, Square 6.6 s, Spillway 5.8 s; every round ended by elimination after 9–23 s (D-061).
- New `tools/map_report.gd` (sizes, walking distances, sightlines) and `tools/map_screenshots.gd` (screenshots through the real game without touching the mouse).
- Tuning: deeper spawn yards on Depot and Spillway (contact was 3.4–5.1 s), overlapping obstacles, offset doors and gates against long diagonals (they were 45–60 m; now at most 44 m on Depot, 35 m on Square, 38 m on Spillway), a dock ramp on Depot that couldn't be walked onto, and channel fences on Spillway the terrace could see over.
- All existing test suites still pass (movement 13, weapon 20, bot 16, round 26, tactics 4), and the maps test passes 15 of 15.
- Your style direction (minimal, pixelated, characters must stand out) became the maps' look rules (D-063, MAPS.md): at most 5 materials per map, no red brick on large walls, and neutral grey ambient light. Shadows had rendered the same blue as the blue team; now they measure 3 % saturation. Same bot results after the change.

**Next:** Your playtest with `map depot`, `map square` and `map spillway`, and the final names. Then the detail pass and the bomb and respawn logic in M8.
## 2026-10-15 — Session 11: crew, classes and arsenal planned

**Done**
- You asked for retro character sprites with three or four classes. I built a prototype that renders Doom/Quake-style 8-direction sprites from 3D shapes (4 classes, 15 animation frames, 2 team palettes). You liked it as a first shot but chose rigged 3D models for the game, with distinct characters and a full arsenal. The prototype is kept as a concept-art tool in `tools/concept/`. Its team palettes still predate D-031 and D-041 and get replaced in M6 task 1.
- Decisions D-051 to D-056: characters stay rigged 3D, with a 3D viewmodel; four classes (Rifleman, Bulwark, Marksman, Scout), each a look plus one passive perk; a crew told apart by silhouette, with team colour painted at runtime; models, textures and animations come from a generator; hit zones follow each body; class picked at match start and changeable in freeze time; the arsenal is five primaries, two pistols, the knife and three grenades.
- Reworked the plan: M6 is now *Crew & animation* (10 tasks, from concept sheets to first-person arms), and M7 *Arsenal, perks & economy*, which adds weapon models, holds and the class perks. Added the classes to GAME_DESIGN.md (section 4.9) and the arsenal to section 4.3.

**Next:** M5 continues in its own session. M6 starts with the concept sheets, in a fresh session.

## 2026-10-15 — Look tweak, and three quick maps

**Done**
- You asked for less blur and pixelation. Before/after screenshots at 1440 pixels tall (your monitor) found the main blur in mipmapped floor textures, then dither grain and fog haze.
- The world now renders at 480 lines (3 × 3 pixels on your monitor, was 4 × 4). Textures got anisotropic filtering. The palette effect uses 16 shades with lighter dithering, and the fog is lighter (D-048).

- You want a rotation of three quick, action-packed maps, more like Call of Duty. M8 is now "Modes & 3 quick maps": three small maps (40–60 m, three lanes, first contact within 5–10 s) and a team respawn mode next to the bomb rounds (D-049).

**Next:** Check the look in-game. Every value is in one place if it needs another step: `Main.pixel_height`, the palette shader's `levels` and `dither_strength`, and the environment's fog density.

## 2026-10-15 — Session 10: M5 rounds & game flow

**Done**
- **Task 1, teams and spawns** (D-042). New `systems/teams.gd` (`Teams`): two teams (numbers 0 and 1), the two sides (`ATTACKING` / `DEFENDING`) kept separate from them, the viewer-relative colors, the spawn group names, the friendly-fire setting and `damage_factor()`. A plain static class, not an autoload, so `--script` tools can load maps with characters.
- Characters: `team_color` is gone. The clothes color comes from `Teams.color_for(team)` (your team blue, the other red) through one material per character and `update_team_color()`. Changing `team` at runtime recolors the body (a property setter), and `Teams.set_viewer_team()` recolors everyone. `main.gd` sets the viewer team to the player's team after loading a map. Checked in the real main scene: the player and ally bots are blue, enemy bots red; flipping the viewer team swaps them; changing a bot's team at runtime recolors it.
- Friendly fire: off by default. `Character.take_damage()` scales a teammate's damage by `Teams.damage_factor()` (nothing when off, a third when on), so the rule sits in the code that owns health. With it off, bullets pass through living teammates (`Weapon._shoot_bullet` skips their hit zones), as in CS.
- Spawns on the test map: 5 defender spawns at the north end behind the peek walls (z = −28, facing south) and 5 attacker spawns at the south end of the range (z = 84, facing north), 112 m apart. Checked headless: every marker stands on floor at y = 0.000, nothing within 1 m (nearest wall 4.00 m), sits on the navigation mesh, and a navmesh path exists from every attack spawn to every defend spawn (25 pairs). The old bot, player and patrol markers stay for practice mode.
- Practice mode: `ArenaRules.add_bot(difficulty, team)`; console `bot_add [easy|normal|hard] [ally|enemy]` (either order) and new `mp_friendlyfire [0|1]` (no argument shows the state). All checked in the real main scene.
- Bot tests: 3 new checks (friendly fire off: no damage; on: a third, 88 HP vs. 64 HP from an enemy; off: bullets pass through a teammate and hit the enemy behind). The bullet check also runs once with friendly fire on to prove the teammate really is in the line of fire. All 48 checks pass (movement 13, weapon 20, bot 15), and the 12 old bot checks print exactly the same numbers as before.

- **Task 2, the round manager** (D-043). `systems/round_manager.gd` owns the match: it adds you plus bot teammates against bots (3v3 by default, from a new `MatchSettings` resource), picks the attacking team, and runs each round: freeze time (5 s) → live (1:55) → round end (5 s). Everyone respawns on their side's spawn with full health and ammo; the dead stay dead until the next round; eliminating the other team wins, a time-out goes to the defenders. It announces everything with signals (`round_started`, `phase_changed`, `round_ended`, `character_killed` with a headshot flag) and keeps kills, deaths, assists and damage.
- `Character.frozen` holds anyone in place during freeze time (looking, crouching and reloading still work). `Character.damaged` now reports the health actually lost. A death fall that is still running stops when the character respawns.
- `main.gd` adds the game rules to the map: a match by default, the old respawning bot arena with `-- --practice`. The test map no longer has its own `ArenaRules`. In a match the HUD no longer says "Respawning...", and the bot console commands explain that they work in practice only.
- New round test (`tests/round_test.tscn`, 9 checks) on the real test map with short timings: setup, spawns, freeze time, going live, elimination, kill credit and headshots, staying dead, assists and damage, time-out. Watched a headless 3v3 match for three rounds: two eliminations, one time-out win for the defenders. Bots still just wander, so rounds can drag; task 4 fixes that.
- Found a GDScript quirk: with `Teams` and `Character` referring to each other, `Teams.Side` from a third script didn't match `Side` inside `Teams`. `Teams.spawn_group()` now takes an int (LEARNING.md, CLAUDE.md gotchas).

- **Task 3, match flow** (D-044). `RoundManager` now keeps the `score` (rounds won per team, counted before `round_ended` is emitted) and ends the match when a team reaches `rounds_to_win`: the last round's pause still runs, then the phase becomes `MATCH_END`, everyone is frozen, `winner` is set and `match_ended(winner)` is emitted. After `rounds_to_win − 1` rounds the attacking team flips and `sides_swapped` is emitted before the next round, so each team spawns at the other end (teams keep their numbers).
- New match-end screen (`ui/match_end_screen.tscn` + `.gd`, `MatchEndScreen`): Victory or Defeat for your team, the score "yours - theirs" in blue and red, and a scoreboard of both teams (name, kills, deaths, assists, damage, sorted by kills then damage, your row highlighted), built from Godot containers and scaled with the window like the HUD. "Play again" and "Quit" buttons until the main menu exists; a full-screen background that stops clicks, so the player controls never grab the mouse back. `main.gd` hands the round manager to the screen when a map loads (which also hides it) and has a new `restart_match()`.
- Round test: 8 new checks, 17 in all, all passing: the score at each `round_ended`, half time after round 4 of 5 (one `sides_swapped`, spawns at the other end), the match end after the pause, nothing happening after it, and two tiny matches (first to 1: no half time; first to 2: swap after round 1, decided in round 3). The 9 old checks print the same numbers as before.
- Visual check in the real main scene at 1280 × 720 and 1920 × 1080: 3v3 and 5v5, Victory and Defeat. 5v5 fills 576 of 720 px, so it fits. "Play again" starts a fresh match, hides the screen and captures the mouse again.
- Found and fixed: from round 2 on, a respawned bot sometimes stood 0.7 m beside its spawn marker. The physics engine (Jolt) moves a teleported body only at the next physics step, so a bot moving in the same tick bumped into a teammate's *old* position and got pushed. A character now skips moving on the tick it respawns; three headless matches showed no offsets afterwards, and the half-time check requires 0.5 m again.

- **Task 4, bots play rounds** (D-045). New `bots/bot_tactics.gd` (`BotTactics`) gives every bot orders at each round start. Attackers form loose groups of about two, take different routes toward the defenders' end (start 0.6 s apart, waypoints spread a little), then clear that end at walking speed. Defenders each hold a different spot and watch its angle, and only leave it for enemies within 35 m. Bots don't shoot while a teammate is in the line of fire. The test map got a `Tactics` node with six hold spots and three attack routes (west, middle, east).
- Found while watching matches: after a search, an attacker could walk 30 m back to a waypoint it had already passed. It now carries on from the route leg it's nearest to.
- New tactics test (`tests/tactics_test.tscn`, 4 checks, seeded bots-only 3v3, identical on every run): orders; defenders on different spots within 8° of their angles after 8 s; attackers at least 36 m out of spawn after 10 s, on two routes; four rounds all won by elimination, after 27–47 s. New bot check: no shots while a teammate is in the way, 18 once it steps aside. Earlier, with wandering bots, rounds often ran into the clock.

- **Task 5, spectating** (D-046). In a match, about 2 s after you die (time to see who killed you) your camera moves to a living teammate: it sits at their head (the interpolated one, like your own camera) and looks along their aim plus their weapon's recoil kick, so you also see their muzzle flash and kick. A click switches to the next living teammate; when the one you watch dies, the view moves on after 1.5 s; with nobody left it stays where the last one fell; the next round puts you back in your own eyes. Their `Body` and your own rifle are hidden while you watch and restored afterwards. Practice mode (`ArenaRules`, you respawn after 3 s) has none: `main.gd` switches `PlayerController.spectating_enabled` on only in a match. All in `PlayerController` (new `spectate_next()`, `get_view_target()`, `is_spectating()`, signal `view_target_changed`); no game rule and nothing in the round manager changed.
- HUD: a "Spectating Bot2 · click for next" line at the bottom centre ("· dead" while the teammate is down), and health, ammo and weapon name become the teammate's (the HUD now binds to a shown character with `set_view_target()` instead of always to the player). The "Killed by …" message shows during the first 2 s as before.
- Found while building: the bot's rifle hangs under its `Head` at exactly the offset of your first-person rifle, so from a teammate's eyes it already looks like a proper viewmodel. I kept it visible instead of hiding it (the brief said to hide it): the view without a gun looked wrong, and with it the muzzle flash and kick show. Headless runs can't capture the mouse (`Input.mouse_mode` always reads visible there), so the real click was checked in a windowed run instead (the click switched Bot1 → Bot2).
- Round test: 9 new checks, 26 in all, all passing: no spectating while it's off (practice), your own view for the first 2 s and then a teammate's eyes (camera on their head, along their aim), their body and your rifle hidden, `spectate_next()`, a click that only recaptures the mouse doesn't count, the view moving on when the watched teammate dies, the view staying put with nobody left, and everything back in the next round. The 17 old checks print the same numbers as before. Changing the wait time or skipping the "show the body again" step makes six of the new checks fail, so they do catch regressions.
- Visual check in the real main scene at 1280 × 720 (3v3): the killcam, the view from a teammate's eyes, after a click, a muzzle flash and a burst (the view kicks up while the gun stays on their aim), and a dead teammate. The HUD line is readable at the bottom centre, nobody's body sits in the view.

- **Task 6, the round HUD** (D-047). New `ui/round_hud.tscn` + `.gd` (`RoundHud`, a child of the HUD) and `ui/kill_feed.gd` (`KillFeed`). It only listens to the round manager and reads its state; `main.gd` hands the manager to the HUD on every map load (null in practice mode, which hides it), and the old manager is disconnected first.
- Top bar at the top centre: your score in a blue box on the left, the timer in the middle ("Round 3" under it), their score in a red box on the right, and one small square per player under each score, lit while they live. The timer shows the freeze countdown (yellow) during freeze time and then the round time as m:ss (1:55 at the start, red in the last 10 s); during the round-end pause it keeps its last value (0:00 after a time-out).
- Center messages: during freeze time "Round 3 · starts in 4" and your side ("You attack: push to the far end" / "You defend: hold your end"); after half time "Switching sides" on top; "Match point" / "Enemy match point" / "Match point for both teams" below. At the round end "Round won" (blue) or "Round lost" (red) with the reason said for your side ("Enemy team eliminated", "Your team was eliminated", "Time ran out: you held your end", "Time ran out: the defenders held their end").
- Kill feed at the top right: "Killer > Victim" in team colors with a gold "HS" after a headshot, only the victim when nobody killed them, your own lines darker with a white outline, newest at the bottom, at most 5, each fading after 5 s, emptied when a round starts. Silkscreen has no "→" glyph (it does have "·", "×" and "»"), so the separator is ">" and the headshot mark is the text "HS"; both rendered fine in the real game.
- `UiScale.apply_tree()` (new) scales a whole container-based layout (fonts, minimum sizes, spacing, offsets of controls placed by anchors); `Teams.text_color_for()` (new) is the team color lightened for text. The old HUD parts (health, ammo, crosshair, "Killed by …", the spectate line) are untouched and don't overlap the new ones; every control of the HUD ignores the mouse, so clicks still reach the player.
- Round test: 26 new checks, 52 in all, all passing, on the real `hud.tscn` (timer, countdown, both side lines, score and squares after kills, feed lines, the five-line cap, fading, all four banners, half time, match point, handing over another manager or none, scaling, no mouse capture). The 26 old checks print the same numbers as before. A mutation run (no disconnect, swapped texts, notice never cleared, no feed reset, a sixth line, a longer lifetime) fails 8 of the new checks. Other suites unchanged: movement 13, weapon 20, bot 16, tactics 4.
- Visual check in the real main scene at 1280 × 720 (and the freeze and live frames at 1920 × 1080): freeze time with the countdown and side line, a live round with five kill feed lines, "Round lost" and "Round won" banners, a time-out banner, and "Switching sides" with "Match point". Text is readable and nothing overlaps the old HUD. In the real scene "Play again" gave the HUD the new manager (old connections gone), and `-- --practice` hides the round HUD.
- Your first-person rifle now disappears when you die (it stayed on screen during the death view), and comes back when you respawn.

- **Task 7, the scoreboard** (D-050). Hold Tab (new input action `scoreboard`, bound by physical key like the others) and a panel appears in the middle of the screen: "Round 3", the score (yours blue, theirs red) and both teams as tables, yours first under a blue header, the enemy under a red one. One row per player: name, kills, deaths, assists and damage (rounded), best first (kills, then damage), your own row highlighted, and **dead players' rows dimmed**, so you see who is still alive. Let go and it is gone. It follows the match while held, never pauses or blocks anything and takes no mouse clicks.
- The two-team table moved out of the match-end screen into one reusable control, `ui/scoreboard_table.tscn` + `.gd` (`ScoreboardTable`, `show_match(rounds)` / `refresh()`), and the match-end screen now contains one (with `dim_dead` off, so the final table looks exactly as before: compared pixel for pixel against the old screen, the panel differs by at most 1.6% of one color channel, from the game showing through). The overlay is `ui/scoreboard.tscn` + `.gd` (`Scoreboard`, a `CanvasLayer` on layer 3: above the HUD, below the end screen and the console). It polls the round manager every frame while visible (damage, which changes the numbers, has no round-manager signal); the table is rebuilt only when something it shows changes. `main.gd` hands it the round manager on every map load (null in practice mode: it never shows) and scales it with the other UI. Tab is ignored while the developer console is open, and the overlay hides when the match is over.
- Round test: 22 new checks, 74 in all, all passing: the Tab binding and a real Tab press, the table (both teams, yours first, also from the other team; every cell against `get_stats()` after a scripted fight; the sorting; dimmed rows; only your row highlighted; rows kept when nothing changed), the overlay (hold and release, header, following damage and kills, walking still works, the console, mouse, scaling, a replaced or missing round manager, the last round's pause and the match end) and the match-end screen's table. The 52 old checks print the same numbers as before. A mutation run (12 changes) fails at least one new check each. Other suites unchanged: movement 13, weapon 20, bot 16, tactics 4.
- Visual check in the real main scene at 1280 × 720 (3v3 mid-round, score 1 - 1, two rows dimmed) and at 1920 × 1080 (5v5, which fits with room to spare), plus the match-end screen before and after the refactor. Checked through `main.gd` itself: the overlay shows in a match, after "Play again" it shows the new match (the old round manager is gone), and in practice mode it never shows.

- **Task 8, the UI theme** (D-057). One Godot `Theme`, `ui/chiip_theme.tres`, set as the project theme, so every control has it: the Silkscreen pixel font at 16 px (32 for scores, 48 for titles), square shapes with crisp 2 px borders, dark blue-grey panels, light text and **one icy cyan accent** (focus rings, selection, slider fill, check marks, the selected tab). It has styles for buttons (rest, hover, pressed, focus ring, disabled), panels, labels, line edits, sliders, progress bars, check boxes, radio buttons and switches (small pixel-art icons), option buttons with their drop-down list, tabs, scroll bars, separators and tooltips, plus 25 *type variations* for roles that recur (`TitleLabel`, `ScoreLabel`, `HeaderLabel`, `DimLabel`, `ModalPanel`, `OverlayPanel`, `TeamHeaderFriendly` / `TeamHeaderEnemy`, `YouRowPanel`, `ContentBox`, `BigButton`...), so scenes name a role instead of overriding a color or size. The orange borders (CS-like, D-031) are gone from the match-end screen and the console.
- The theme and its icons are **generated**, like the sounds: `tools/ui_palette.gd` (the colors), `tools/generate_ui_icons.gd` (PNG icons in `assets/ui/`, drawn from letter grids in 2 × 2 px cells) and `tools/make_ui_theme.gd` (the theme). Changing the look is a change to those and a re-run. Team blue and red are still owned by `Teams`; the theme copies them for the team headers and a test fails if they drift apart.
- **Scaling:** the old way scaled per-node overrides, which can't reach a stylebox's border or an icon. `UiTheme.apply(root, factor)` (new, `ui/ui_theme.gd`) instead gives a menu a *copy of the theme* with every font size, spacing, margin, border and icon (nearest-neighbor) multiplied, and scales the nodes' own minimum sizes and any one-off overrides; the copy is made once per factor. At 1080 pixels a menu is exactly 1.5× its 720-pixel size. Text sizes are multiples of 16 because Silkscreen is drawn on a grid of 1/8 em: 24 px would land at 36 (4.5 px per font pixel, uneven) at 1.5×.
- Moved onto the theme: the match-end screen, the Tab scoreboard with its table, and the developer console (rebuilt from containers). Their scenes and scripts lost their colors, sizes and styleboxes; the table's rows pick variations by name. Sizes changed slightly where the old ones were off the grid: the result title 56 → 48 px, its scores 40 → 32, the buttons 20 → 16; everything else sits where it did. The HUD isn't a menu and keeps `UiScale`; the only change it sees is the theme's default label color (`#e6ecf5` instead of pure white; rendered alone with and without the theme, no HUD pixel differs by more than 10% of a color channel).
- New `ui/theme_preview.tscn` (developer tool, `Godot --path . res://ui/theme_preview.tscn`): every styled control, all button states, the option button's list open, tabs, a scroll area, panels, team headers and the label variations in one window, scaled with the window.
- New `tests/ui_test.tscn` (35 checks): the project theme and font; the look plain controls get; the variations and the copied colors; the 1.5× theme (every font size, styleboxes, spacing, icons crisp with no blended colors, yes/no constants left alone); a sample menu at 1.0, 1.5, 2.0 and back; the preview; the console; the scoreboard and the match-end screen (rows still built, looks from variations, no style overrides left, exactly 1.5×, rows built after scaling). A mutation run (nine changes, e.g. icons resized in place, bilinear icons, spacing switches scaled, the table's rows or the end screen not scaled, nested themes kept) fails at least one check each, and it caught a real bug on the way: `Texture2D.get_image()` hands out the texture's own image, so resizing it for the 1.5× theme changed the original for the next factor. All six suites pass (movement 13, weapon 20, bot 16, round 74, tactics 4, ui 35); the 74 round checks, which include the scoreboard, the match-end screen and UI scaling, pass unchanged.
- Visual check in the real game at 1280 × 720 and 1920 × 1080: the match-end screen and the scoreboard before and after, the console, and the preview.

**Next:** task 9, settings saved to disk (a `Settings` class, `user://settings.cfg`, applied the moment something changes).

## 2026-10-15 — Session 9: M4 closed, M5 planned

**Done**
- Playtest 2: the bots feel right now. Your own footsteps were too loud and went from −7 to −12 dB. **M4 is closed.**
- Wrote the detailed M5 plan (rounds & game flow): teams with bot teammates, a round manager that owns the game state, match flow, bots that push and hold, spectating, round HUD, scoreboard, a UI theme, saved settings with a settings menu, main and pause menus, and tests. Each task names the model that builds it.
- Renamed M5 from "Health, rounds & game flow" to "Rounds & game flow", because health came early in M4.
- M5 decisions (D-041): 3v3 with bot teammates by default; first to 5, 10 or 15; 5 s freeze time; no armor until M7 (the armor task moved there); friendly fire as a match setting; no team names, so your team is blue and the enemies are red. M5 now has 13 tasks.

**Next:** Start M5 with task 1 (teams and spawns), in a fresh session.

## 2026-10-15 — Session 7: M3 closed, M4 planned

**Done**
- You playtested M3: the look is good. **M3 is closed.**
- Wrote the detailed M4 plan (bots, 12 tasks). Central idea: every character is driven by per-tick input commands (like CS's "usercmd"), so bots follow exactly the same rules as you, which is also the structure multiplayer needs.
- Multiplayer decided: yes, after the single-player game, as a new milestone M8 (D-033). Added M8 to the plan and five "keep multiplayer possible" rules to ARCHITECTURE.md for M4–M7.


## 2026-10-15 — Session 8: M4 bots

**Done**
- Split `Player` into a shared, command-driven `Character` (`characters/`) plus a `PlayerController`; `player.tscn` is now an inherited variant of `characters/character.tscn` (D-034). All 33 checks pass with identical numbers, and mouse sensitivity is unchanged.
- Characters got 100 HP and a shared soldier body (`characters/soldier_body.tscn`) with CS hit zones; the upper body sinks when crouching, the clothes take a team color, and your own body is hidden from you. HUD shows health. Check: chest 35.6, headshot 142.4 and death credited to the shooter; your own shots never hit you. Found and fixed: the base character was on the world layer, so bullets stopped at its capsule; characters now default to the bots layer.
- Navigation mesh for the test map (153 polygons, bake tool `tools/bake_navmesh.gd`). Checked paths: spawn → platform top (via ramp/stairs), long routes around walls and dummies; the 1.5 m tunnel is correctly excluded.
- Bot scene (`bots/bot.tscn`, red team) and `BotController` that walks paths by pressing movement keys. Check: reaches the platform top (y = 2.00), goes around the peek wall and down the range, stopping within 0.8 m of each goal.
- Bot perception (`BotSenses`) and a noise bus (`Noises`), plus teams and footsteps on characters (D-035). All seven perception cases behave as intended. Found: autoloads aren't available to `--script` runs, which would have broken our tools, so the noise bus is a class with a static instance instead.
- Bot behaviour (patrol → engage → search) and human-like fighting with Easy/Normal/Hard data files (D-036). Duels at 10 m against a standing player: first shot ~0.45/0.3/0.17 s, kill ~1.45/0.6–1.2/0.35 s; never through walls. Fixed a fixed-direction aim error that made some bots miss an entire magazine. Behaviour check: a patrolling bot hears you run behind it, turns, sees you and fights.
- Footstep sounds (three generated variations, randomized) and positional audio: your own steps and shots play in both ears, bots' come from where they are. Check: routing correct for both. Existing rifle sounds unchanged when regenerating.
- Death and respawn: bodies tip over and stop blocking, your view sinks to the floor and the HUD names your killer; `ArenaRules` (temporary until M5) keeps 2 bots on the test map and brings everyone back after 3 s with full health and ammo.
- Developer console (key left of 1): `help`, `bot_add`, `bot_kick`, `bot_difficulty`, `god`, `noclip`, `map`, `clear`, with history. `main.gd` can now switch maps at runtime. All commands checked.
- Bot arena on the test map: 11 patrol points, 4 bot spawns in the far corners, your spawn; all on walkable floor. Fixed two bots spawning on the same marker (spawns now prefer free markers).
- Bot tests (`tests/bot_test.tscn`): 11 checks, all passing, seeded so every run is identical. All three suites: 44 checks pass.
- Visual check: the red bot is easy to pick out against the range and the blue dummies; it spots you, stops and shoots.
- You asked when settings and proper UI come: menus, a settings menu (sensitivity, FOV, volume, crosshair, keys) saved to disk, and the round HUD are M5. Until then, tuning happens in the Inspector.

**Decisions:** D-034 to D-036 in [DECISIONS.md](DECISIONS.md).

**Playtest 1 feedback:** bots killed you without a chance and aimed instantly, they glided, turned unnaturally, and sounds (your own included) weren't clear enough. Changes:
- Gradual noticing, slower reaction and less precise aim, so you have about a second at 10 m against Normal (D-037).
- Eased turning and left/right search sweeps instead of spinning.
- A procedural walk cycle with hip and shoulder joints (D-039).
- A brighter footstep sound, your own steps much louder, and enemy steps and shots clearer and symmetric with bot hearing (D-038).
- Bot tests updated: holding an angle, a new noticing check, and "Normal wins within 5 s". All 45 checks pass. Visual check: bots now stride.
- You asked when it gets properly animated (not in the roadmap yet; asked where to put it) and asked to use cheaper models where possible (routing guide added to CLAUDE.md).
- Roadmap: added **M6 — Characters & animation** after M5 (your choice). Economy, bomb mode and multiplayer are now M7–M9 (D-040).
- Playtest 2: the bots feel OK now. Your own footsteps were too loud, so they went from −7 to −12 dB (enemy steps unchanged).

**Result:** after playtest 2 you confirmed the bots feel right. M4 closed in Session 9.

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
- Frame-rate check: 120 fps (the display's limit), slowest 1% of frames ~10 ms, on the range and the course.
- You switched the palette effect on (D-030).
- You said the look was too much like Counter-Strike. Right: I had steered toward a dust-map palette (D-029). You chose to keep the materials and take the dust out: grey stone and grey gravel from the same photos (the texture tool got a saturation option), muted brick, and cool daylight instead of a warm afternoon (D-031). Found on the way: a built TrenchBroom scene can't be loaded once a texture it uses is deleted, so rebuild first (added to CLAUDE.md gotchas). Rooms still match within 0.1 mm and both test suites pass.
- The bake and the TrenchBroom trial didn't reach the project: there was no lightmap file, no map edits, and TrenchBroom's game path for Chiip wasn't set. Checked whether a script could bake instead: Godot 4.7 has no scripting call for it, only the editor button. You chose to skip the bake (moved to M7) and said you hadn't really tried TrenchBroom yet.
- Map workflow decided from the comparison: **TrenchBroom for real maps, CSG for quick tests**, provisional until your hands-on trial (D-032). Added a "Making maps with TrenchBroom" guide to the README and a "Your open checks" list at the top of the plan (Ctrl + click, sensitivity, TrenchBroom trial), so these stop moving from milestone to milestone.

**Next:** You playtest M3 (the look in-game). Then we close M3 and plan M4 (bots). One decision is due before M4: whether Chiip gets multiplayer (see DECISIONS.md, open questions), because that changes how bots should control their characters.

**Decisions:** D-024 to D-030 in [DECISIONS.md](DECISIONS.md).

**Next (your part):** try TrenchBroom on the comparison room and bake its lightmaps in the editor. Then I compare baked vs. real-time lighting, we decide the map workflow (task 10) and close M3. The Ctrl + click and sensitivity checks are still open.

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
