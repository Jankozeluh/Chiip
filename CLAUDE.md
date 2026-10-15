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
- Use third-party assets only if their license allows it, and record each one in docs/CREDITS.md (created in M3).

## Code conventions

See docs/ARCHITECTURE.md. In short: Godot style guide naming, static typing everywhere, feature folders, and tunable values as `@export` variables or Resources.

## Commands

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`

- Open the editor: `/Applications/Godot.app/Contents/MacOS/Godot -e --path /Users/kozeluhj/Documents/Games/Chiip`
- Run the game: `/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kozeluhj/Documents/Games/Chiip`
- Import assets and refresh the class cache (run after adding scripts with `class_name`): `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Run the movement tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 128 res://tests/movement_test.tscn` (exit code = number of failures)
- Smoke-run the game headless: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 300`
- Visual check: `/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1280x720 --write-movie <scratchpad>/frame.png --quit-after 45` writes PNG frames. This opens a window briefly and can capture the user's mouse.

## Gotchas

- In hand-written `.tscn` files, a node that sets an exported *node* variable needs `node_paths=PackedStringArray("var_name")` in its `[node]` header, or the reference silently stays null.
- Input bindings created from code need `device = -1` (all devices), like bindings made in the editor.
- In a `--script` that extends `SceneTree`, nodes added in `_init()` aren't ready yet, so `@onready` variables are null. Await a few `physics_frame`s first.
- GDScript lambdas copy captured locals: assigning to a captured `int`/`Vector2` inside a lambda doesn't change the outer variable. Capture an `Array`/`Dictionary` instead.
- A script error inside a headless run can leave Godot running forever. Always pass `--quit-after <frames>` as a safety net (macOS has no `timeout` command).
