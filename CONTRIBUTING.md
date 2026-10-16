# Contributing to Chiip

Thanks for wanting to help. Chiip is a small game made by JK · Divocakos, and the best contributions are **maps**, **bug reports** and **fixes**. This page says how each works and under which licence it goes in.

Maps are **curated in this repository**: a map comes in as a pull request, is looked at and played by the maintainer, and ships with the next release.

## Licences: what you agree to

Chiip has two open licences, by folder (see [LICENSE](LICENSE) and [LICENSE-ASSETS](LICENSE-ASSETS)):

- **Code** (scripts, scenes, tools, tests, docs): **GPL-3.0**.
- **Art, models, maps and sounds**: **CC BY-NC-SA 4.0** (share and adapt for non-commercial use, with credit, under the same licence).

By opening a pull request you say that you made the work (or that its licence allows it, see "Third-party material" below) and that you license it under the licence of the folder it goes into: **a map, a texture, a model or a sound you submit is CC BY-NC-SA 4.0; code you submit is GPL-3.0**. You keep your copyright; you are credited. The maintainer may adjust a map (tuning, fixes) before it ships. The name "Divocakos" and the studio logo are all rights reserved and are not part of anything you may reuse or submit.

Because contributions come in under the non-commercial licence, Chiip stays a free, non-commercial game. If that isn't acceptable to you, please don't submit.

## Reporting a security problem

Please don't open a public issue for it: see [SECURITY.md](SECURITY.md) (GitHub's private vulnerability reporting).

## Reporting a bug

Open a GitHub issue with:

- the game's version (the bottom left of the main menu, or **Settings → Licences**) and your system (Windows, macOS or Linux, and the graphics card);
- what you did, what you expected and what happened, ideally as numbered steps;
- for an online problem: whether you were host or client, how you connected (Tailscale or LAN) and the console's `status` output (the key left of 1).

[docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) lists what we already know.

## Submitting a map

A map is a pull request that adds your map's files and nothing else (or the small changes listed in step 6). The kit, the rules and the workflow are in [docs/MAPPING.md](docs/MAPPING.md); the maps' look and building rules are in [docs/MAPS.md](docs/MAPS.md).

1. **Build it from the map kit** in TrenchBroom, following [docs/MAPPING.md](docs/MAPPING.md), "Your first map, step by step": textures, props and lamps from the kit, markers for spawns, routes, hold spots and bomb sites. `maps/depot.map`, `square.map` and `spillway.map` are worked examples, and the kit gallery (`maps/kit/kit_gallery.tscn`) shows everything in the kit.
2. **Follow the look rules** ([docs/MAPS.md](docs/MAPS.md), "Look rules"): at most 6 main materials, no saturated red or blue on large surfaces (those are the teams' colours), neutral shadows, warm light only from lamps. A texture or prop of your own must pass `tools/texture_report.gd` and be drawn like the kit's.
3. **Follow the building rules** ([docs/MAPS.md](docs/MAPS.md), "Building rules"; [docs/MAPPING.md](docs/MAPPING.md), "Building rules and timing"): no steps, gap widths, cover heights, first contact in 5 to 10 seconds, no sightline over about 40 m, no view from one spawn to the other.
4. **Make it a scene, bake it, play it:** `tools/new_map.gd` makes `maps/<name>.tscn` and `maps/<name>_navmesh.tres` from your `.map`; rebuild and re-bake after every edit ([docs/MAPPING.md](docs/MAPPING.md), "After an edit"). Play bot rounds on it yourself, with friends if you can.
5. **The checks must pass:**
   - the **maps test** on your map: `godot --headless --path . --fixed-fps 128 --quit-after 400000 res://tests/maps_test.tscn -- --map res://maps/<name>.tscn` (markers, navmesh, paths, first contact, rounds decided by fighting, team respawn); it exits with the number of failed checks, so `0` is a pass;
   - `tools/map_report.gd` shows no spawn-to-spawn views and sightlines of about 40 m or less;
   - the checklist at the end of "Checklist before you share a map" in [docs/MAPPING.md](docs/MAPPING.md) is ticked, including screenshots made with `tools/map_screenshots.gd` (overview, spawns, sites, lanes), which you put in the pull request description.
6. **Add it to the lists:**
   - Anything in `maps/` is found by the console's `map <name>` command by itself.
   - To be offered on the Play screen and in the rotation, the map is added to `GameLaunch.ROTATION_MAPS` (`systems/game_launch.gd`) and to `MAPS` in `tests/maps_test.gd`. Your pull request includes those two one-line changes; the maintainer decides whether a map joins the rotation or stays a console-only map, and in which place.
   - Add a line for it under "Community maps" in [docs/CREDITS.md](docs/CREDITS.md) with the name you want credited.
7. **Don't copy another game.** The map must not be named or laid out like a Counter-Strike map (or any other well-known shooter's), and no desert or dust palettes (D-031). Original layouts only.
8. **Open the pull request** with the map's name, a short description of its idea (where the sites are, what the routes are for), the screenshots and the output of the maps test. The maintainer plays it, may ask for changes, and merges it so that it ships with the next release.

## Contributing code

Small, focused pull requests are easiest to review. For anything bigger than a fix, open an issue first so we agree on the idea.

- Read [docs/DEVELOPING.md](docs/DEVELOPING.md) (running from the editor, the tests) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (folders, systems, conventions). In short: Godot's GDScript style guide, static typing everywhere, feature folders, tunable values as `@export` variables or Resources, and a `##` doc comment on every script, exported variable and public function.
- Keep multiplayer possible: gameplay code follows "Keeping multiplayer possible" in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **Run the tests** before you open the pull request: `bash tools/run_tests.sh` runs all suites (a few minutes), or `bash tools/run_tests.sh <names>` the ones your change touches. A new behaviour gets a check in a suite.
- Explain *why* in the pull request description. The maintainer keeps the devlog and the decisions log; if you changed a design rule or a number, say which one.
- Code is GPL-3.0 (see above). The look and the feel are a design choice of the game: changes to gameplay values or the look are discussed in an issue before the code.

## Contributing art, sounds and models

Textures, models and sounds are made for Chiip by the generators under `tools/` (`make_world_textures.py`, `modelgen/`, `generate_sounds.gd`), so changes go **into the generators**, not into hand-edited output files (the outputs are rebuilt from them). New art in the same style is welcome; it goes in under CC BY-NC-SA 4.0 and is credited in [docs/CREDITS.md](docs/CREDITS.md).

## Third-party material

Bring in nothing you didn't make unless its licence allows it **and** is compatible with the licence of the folder it goes into (public domain and CC0 always are; CC BY needs attribution; anything non-commercial-only or "no derivatives" is not). Every third-party file gets an entry in [docs/CREDITS.md](docs/CREDITS.md) (what, where it is from, its licence) and, when it ships in the game, in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Don't add large downloads to the repository without asking in an issue first.

## Being kind

Be friendly and patient; this is a hobby project. Disagree about ideas, never about people.
