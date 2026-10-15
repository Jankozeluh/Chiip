# Chiip — instructions for Claude

Chiip is a single-player, CS-style tactical FPS against bots with a retro Quake look, built in Godot 4.7.2 with GDScript. Read README.md first. The roadmap and current status are in docs/PLAN.md.

## The user

- A data analyst who has made games in Unity before but is new to Godot.
- Wants to learn as we go. Briefly explain each Godot concept the first time it's used, comparing it to Unity. Skip programming basics.
- A long-time CS and Quake player. Use CS terms freely (counter-strafe, spray, eco), and aim for a CS-like feel.

## Documentation rules (required)

Everything must be documented, in the same change as the work itself, not later:

1. **docs/PLAN.md:** tick finished tasks and update the milestone status and "Current milestone".
2. **docs/DEVLOG.md:** add or extend today's entry with what was done and what's next.
3. **docs/DECISIONS.md:** add an entry for every design or technical decision, with the reasons and the alternatives. Move resolved open questions into entries.
4. **docs/ARCHITECTURE.md:** update when adding folders, systems, autoloads, physics layers or conventions.
5. **docs/LEARNING.md:** add a note when a Godot concept is used for the first time, with the Unity comparison.
6. **docs/GAME_DESIGN.md:** update when gameplay rules or values change.
7. **README.md:** update when how to run the game, or its controls, change.
8. **Code:** every script starts with a `##` doc comment. Exported variables and public functions have `##` comments.

Update the "Last updated" date on every document you change.

## Workflow

- Work milestone by milestone and task by task, following docs/PLAN.md. Ask the user before starting a new milestone or changing the plan.
- The game must still run after every task.
- Once git is set up in M1, commit after each finished task, with the message prefixed by the milestone, e.g. `M1: Add crouching`.
- Use third-party assets only if their license allows it, and record each one in docs/CREDITS.md. Ask the user before every download (file, source, size). Downloads go to the scratchpad, each in its own folder; only processed results go into the project.

## Choosing a model (keep token cost down)

The user wants cheaper models used wherever they do the job just as well:

| Model | Use for | Chiip examples |
|---|---|---|
| Haiku | Mechanical work with a clear spec | Running the test suites and reporting pass/fail, searching code, running the texture/sound/navmesh/map tools, filling docs and devlog from a list of changes, renames, repetitive scene edits |
| Sonnet | Well-defined features | Menus and settings UI, console commands, HUD layouts, tool scripts, new weapons from a stats table |
| Opus | Design, tricky debugging, tuning by feel | Architecture, movement and physics feel, bot AI, netcode (M9), decisions with trade-offs |

- Delegate mechanical subtasks to a subagent with `model: "haiku"` (or Sonnet), giving it a complete brief, and keep design work in the main session.
- Start a fresh session for each milestone: long conversations re-read their whole history every step. This file and the docs exist so a new session can pick up the project without the old conversation.

## Code conventions

See docs/ARCHITECTURE.md. In short: Godot style guide naming, static typing everywhere, feature folders, and tunable values as `@export` variables or Resources.

## Commands

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`

- Open the editor: `/Applications/Godot.app/Contents/MacOS/Godot -e --path /Users/kozeluhj/Documents/Games/Chiip`
- Run the game: `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip`
- Import assets and refresh the class cache (run after adding scripts with `class_name`): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Run the tests (exit code = number of failures): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/movement_test.tscn`, and the same with `res://tests/weapon_test.tscn` and `res://tests/bot_test.tscn` (use `--quit-after 100000` for the bot test) and `res://tests/round_test.tscn` and `res://tests/tactics_test.tscn` (`--quit-after 200000`) and `res://tests/ui_test.tscn` and `res://tests/crew_test.tscn` (`--quit-after 60000`) and `res://tests/class_test.tscn` (`--quit-after 200000`). Run suites one at a time when reading their output
- Regenerate the placeholder sounds, then import them: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/generate_sounds.gd` and then the import command above
- Rebuild the UI theme after changing `tools/ui_palette.gd`, `tools/generate_ui_icons.gd` or `tools/make_ui_theme.gd` (three steps): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/generate_ui_icons.gd`, then the import command above, then `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/make_ui_theme.gd` (writes `ui/chiip_theme.tres`; the theme is generated, don't edit it by hand). Look at the result with `/Applications/Godot.app/Contents/MacOS/Godot --path . res://ui/theme_preview.tscn` (add `--resolution 1920x1080` for the scaled look)
- Make a retro texture: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/make_retro_texture.gd -- <source image> <name> [size] [colors] [contrast] [brightness] [saturation]`, then the import command. Record the source and settings in docs/CREDITS.md
- Python tools run in the `chiip` conda environment (`~/miniconda3/envs/chiip/bin/python`; setup in README.md, D-071). Ask the user before installing any other package
- Generate the crew models, their animations and first-person arms (writes `assets/models/crew/` and the AK-style rifle into `assets/models/weapons/`; then run the import command): `~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py all` (or one class, e.g. `rifleman`). Look at them with `/Applications/Godot.app/Contents/MacOS/Godot --path . res://characters/crew/crew_preview.tscn`
- Rebuild the crew's AnimationTree graph after changing `tools/make_crew_animation_tree.gd`: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/make_crew_animation_tree.gd` (writes `characters/crew/crew_animation_tree.tres`; generated, don't edit by hand)
- Render concept sprite sheets (Python, outside Godot): `~/miniconda3/envs/chiip/bin/python tools/concept/spritegen.py --out <scratchpad>/concept` (all frames, spin viewer `preview.html`), or `--sheet` for just the approval line-up and turnarounds. Output must stay outside the project, or Godot imports it
- Build TrenchBroom maps into their scenes: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 500 --script res://tools/build_maps.gd -- res://maps/comparison/trenchbroom_room.tscn`
- Bake navigation meshes after changing a map's layout: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 500 --script res://tools/bake_navmesh.gd -- res://maps/test_map.tscn`
- Install Chiip's TrenchBroom config: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/export_trenchbroom_config.gd -- "$HOME/Library/Application Support/TrenchBroom/games/Chiip"`
- Play a specific map: add `-- --map res://maps/comparison/csg_room.tscn` to the run command
- Smoke-run the game headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300`
- Visual check: `/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1280x720 --write-movie <scratchpad>/frame.png --quit-after 45` writes PNG frames. This opens a window briefly and can capture the user's mouse.

## Gotchas

- In hand-written `.tscn` files, a node that sets an exported *node* variable needs `node_paths=PackedStringArray("var_name")` in its `[node]` header, or the reference silently stays null.
- Input bindings created from code need `device = -1` (all devices), like bindings made in the editor.
- In a `--script` that extends `SceneTree`, nodes added in `_init()` aren't ready yet, so `@onready` variables are null. Await a few `physics_frame`s first.
- A built TrenchBroom map scene stores references to its textures. Rebuild the map (tools/build_maps.gd) *before* deleting or renaming a texture it uses, or the scene can't be loaded anymore.
- Multiplayer comes in M9 (D-033). Follow "Keeping multiplayer possible" in docs/ARCHITECTURE.md in all gameplay code.
- Keep Chiip visually distinct from Counter-Strike: no desert/dust palettes, no CS-like map layouts or names (D-031).
- Headless runs use a dummy audio driver where sounds never finish; anything still "playing" at exit is reported as leaked. Tests use silent weapon data.
- Autoloads don't exist in `--script` runs (tools, checks), so code that tools load must not use autoload names. Use a class with a static shared instance instead (see `systems/noises.gd`).
- GDScript lambdas copy captured locals: assigning to a captured `int`/`Vector2` inside a lambda doesn't change the outer variable. Capture an `Array`/`Dictionary` instead.
- `Teams` and `Character` refer to each other. In such a cycle GDScript can reject an enum from one of them passed in from a third script ("should be Side but is Teams.Side"). Take such parameters as `int`.
- Run the game in practice mode (old bot arena) with `-- --practice`; the default is a 3v3 match.
- Jolt moves a teleported body (`global_position = …`) only at the next physics step; other bodies moving in the same tick still collide with its old position. `Character.respawn()` handles this by skipping movement for that tick.
- Headless runs can't capture the mouse: `Input.mouse_mode` always reads visible, so `PlayerController` treats every click as the click that recaptures the mouse. Test click handling in a windowed run, or call the public method behind it (e.g. `spectate_next()`).
- HUD and overlay `Control`s must have `mouse_filter = IGNORE` (Label's default; containers and panels default to STOP), or they swallow the clicks `PlayerController` needs. Menus that should block clicks use a full-screen STOP background.
- A parse error in a test script makes the suite exit with code 0 and print no PASS lines, which looks like a pass. When running suites, check the PASS count and grep for `SCRIPT ERROR`, not only the exit code.
- A script error inside a headless run can leave Godot running forever. Always pass `--quit-after <frames>` as a safety net (macOS has no `timeout` command).
- A new `AnimationNodeTransition` has no current state and outputs nothing (the model stays in its rest pose) until it gets a `transition_request`; `CrewBody` requests "alive" when it builds the tree.
- Menus take their look from the UI theme (D-057): pick *type variations* (list in docs/ARCHITECTURE.md, "The UI theme") instead of overriding colors, fonts or styleboxes on nodes, and scale a menu with `UiTheme.apply(self, factor)` in its `set_ui_scale()` (the HUD uses `UiScale`). `ui/chiip_theme.tres` is generated by `tools/make_ui_theme.gd`: change the tool, not the file.
