# Chiip — Maps

> Last updated: 2026-10-15
>
> The three quick maps of M8 (D-049), built early so the game has a rotation: **Depot**, **Square** and **Spillway** (placeholder names you picked). They are **blockouts**: complete, playable layouts in plain textures, tested with bots, but not yet detailed, without baked lighting and without bomb logic. Decisions: D-060–D-062.

## Playing them

- In the game: open the console (the key left of 1) and type `map depot`, `map square` or `map spillway`. `map` alone lists all maps.
- From the terminal: add `-- --map res://maps/depot.tscn` to the run command (see README). Add `--practice` for the bot arena where everyone respawns.
- A match (the default) puts the defenders at the north end and the attackers at the south end; sides swap at half time.

## Rules every map follows

| Rule | Value | Why |
|---|---|---|
| Size | 46–48 m wide, 56 m long inside the outer walls | D-049: 40–60 m across |
| Lanes | Three (west, mid, east), each with its own character, plus connectors between them | D-049 |
| First contact | 5–10 s after the round goes live, measured with bots (median of 4 rounds) | D-049; measured by `tests/maps_test.tscn` (D-061) |
| Sightlines | No spot sees the other spawn; the longest views stay around 40 m or less | D-049: short sightlines (D-061) |
| Spawns | 5 per side, 3 m apart: defenders at the north end (−z, facing south), attackers at the south end (+z, facing north), 49–51 m apart | D-042 |
| Bomb sites | A in the west half, B in the east half, both at the defenders' end | M8 bomb rounds |
| Respawn points | 12, in four zones (north, south, west, east), for the later respawn mode | M8 respawn mode |
| Looks | Existing retro textures, cool daylight; no desert or CS look | D-031 |

**Building rules** (what the characters and the bots can handle):

- **No steps.** Characters don't climb steps; every height change is a ramp of 26° or less (the navmesh allows 46°).
- **Doors and gaps at least 2.5 m wide** (bots are 1 m wide on the navmesh) and 3 m tall.
- **Tall cover is 2.2 m or more**, so it hides a standing player (eyes at 1.63 m). **Low cover is 1.2 m or less**, which you can shoot over and jump onto (a jump clears 1.45 m).
- **Raised floors see over walls:** a 1.5 m terrace adds 1.5 m to your eye height, so the walls it overlooks must be taller (Spillway's channel fences are 3 m for that reason).
- **The centre of each bomb site is open floor** (a plant spot), not a crate.

### Markers in each map scene

Every map scene has the same nodes, like the test map:

| Node | Contents | Used by |
|---|---|---|
| `Map` | The built TrenchBroom geometry (`FuncGodotMap`, group `navigation_source`) | Navmesh bake |
| `Navigation` | `NavigationRegion3D`, mesh in `maps/<name>_navmesh.tres` | Bots |
| `Spawns` | `DefendSpawn1–5` (`defend_spawns`), `AttackSpawn1–5` (`attack_spawns`) | Round manager |
| `Tactics` | 7 `Hold…` markers (`hold_points`, facing the angle to hold) and `RouteWest`, `RouteMid`, `RouteEast` (`attack_routes`, waypoints in order) | Bot round plans (D-045) |
| `Objectives` | `BombSiteA`, `BombSiteB`: `Area3D` (group `bomb_sites`) on the triggers layer, watching players and bots but switched off (no logic yet), with a floating letter | M8 bomb |
| `Respawns` | `North1–3`, `South1–3`, `West1–3`, `East1–3` (`respawn_points`, also `bot_spawns` and `player_spawns`) | Practice now, respawn mode later |
| `Practice` | 14–16 `Patrol…` markers (`patrol_points`) | Practice bots |
| `Lamps`, `Sun`, `WorldEnvironment` | Lighting and the map's sky and fog | — |
| `Player` | You (stands at the attackers' spawn when no rules move you) | `main.gd` |

### Editing a map

The `.map` files in `maps/` are the source: open them in TrenchBroom (README, "Making maps with TrenchBroom"). Then:

1. Rebuild the scene: `tools/build_maps.gd -- res://maps/depot.tscn` (or *Build Map* on the `Map` node).
2. Bake the navmesh: `tools/bake_navmesh.gd -- res://maps/depot.tscn`.
3. Check it: `tests/maps_test.tscn` (markers, paths, first contact) and `tools/map_report.gd` (sizes, walks, sightlines). If you moved floor or walls, move any marker that now stands inside them.
4. Screenshots: `tools/map_screenshots.gd` renders an overview, both spawns, both sites and mid through the real game.

The exact commands are in CLAUDE.md. **In TrenchBroom the map is turned:** Godot's x is TrenchBroom's Y and Godot's z is TrenchBroom's X. In TrenchBroom's top view, north (the defenders' end) is on the left and east is at the top.

## Map 1: Depot

![Depot plan](maps/depot.svg)

A freight yard. **Indoor mid, open side lanes.**

- **Mid:** a brick warehouse with an S-bend inside. Its north and south doors are offset, and two metal racks block the view from one door to the other. Side doors lead west (north half) and east (south half). Warm lamps inside.
- **West, site A:** an open container yard. Overlapping containers (2.6 m) and crates break up the views. A sits in the north-west corner beside a container.
- **East, site B:** a boxcar on the track, a small signal hut and a 1.2 m loading dock along the east wall. B is on the dock, with ramps up from the south end and from the west. Pallet stacks on the dock break the view along it.
- **Spawns:** container stacks (5.2 m) split each spawn yard from the side lanes; wooden stacks in the forecourts give cover and cut the long views across them.
- **Look:** grey gravel, red brick, metal containers, wood. Today's cool daylight (`cool_daylight.tres`), sun 38° high.

## Map 2: Square

![Square plan](maps/square.svg)

An old-town square. **Open mid, tight side lanes.**

- **Mid:** an open plaza around a 5.5 m stone column on a fountain basin, with two market stalls and planters. The streets from the spawns enter it at opposite corners.
- **West, site A:** a narrow zig-zag alley between houses. The two houses that jut into it overlap, so no straight line runs through. A is a small square with a well at the alley's north end. A covered passage through the houses connects the alley to the plaza.
- **East, site B:** a long market hall with a roof, stone pillars and stalls. A wall with a gap on the east side splits it in two; B is **indoors** at the north end. An arch through the houses connects the plaza to the hall's north half. The hall's doors are offset from the gap, so you can't see down the whole hall.
- **Spawns:** a kiosk in front of each spawn breaks the views across the spawn yards.
- **Look:** stone paving, painted plaster and brick houses, wooden stalls. A low morning sun (24° high) with long shadows (`clear_morning.tres`: a slightly paler sky and a little more haze).

## Map 3: Spillway

![Spillway plan](maps/spillway.svg)

A dry concrete water works. **Sunken mid, high sides.**

- **Mid:** a dry channel 3 m deep, with ramps down at both ends and 3 m fences along its edges. A walled footbridge crosses it in the middle; under the bridge the channel narrows to a 2.5 m culvert, and concrete blocks on either side of the bridge stop anyone seeing straight through. Two overlooks with low parapets let the sides shoot down into the channel.
- **West, site A:** a pump house you can go through (offset doors with a pump in between) or around (two corridors with overlapping blockers). A is in front of its north door.
- **East, site B:** a tank yard split by a pipe wall with two gaps, each with a tank right behind it, so no view runs through. B is on a 1.5 m terrace with ramps up from the south and the west; a control house blocks the view from the yard up onto the terrace.
- **Look:** concrete, plaster and metal under an overcast sky (`overcast.tres`: grey sky, flatter light, more fog), a weak high sun.

## Measurements

From `tests/maps_test.tscn` (seeded bots-only 3v3, 4 rounds, timed from the round going live) and `tools/map_report.gd`. Walking distances follow the navmesh from the middle spawn marker.

| | Depot | Square | Spillway |
|---|---|---|---|
| First contact, each round (median) | 5.3, 5.6, 5.8, 6.2 s (5.7 s) | 5.6, 6.5, 6.7, 7.1 s (6.6 s) | 5.5, 5.7, 6.0, 9.2 s (5.8 s) |
| Round length (all ended by elimination) | 9–16 s | 9–23 s | 11–17 s |
| Spawn to spawn, walking (straight line) | 52 m (49 m) | 62 m (50 m) | 52 m (51 m) |
| Attackers to A / B | 57 m / 52 m | 65 m / 54 m | 51 m / 53 m |
| Defenders to A / B | 25 m / 23 m | 18 m / 20 m | 20 m / 21 m |
| Routes west / mid / east | 58 / 49 / 68 m | 61 / 51 / 59 m | 57 / 53 / 55 m |
| Longest sightline | 44 m | 35 m | 38 m |
| Spot pairs that see each other over 30 m / 40 m | 560 / 3 | 79 / 0 | 375 / 0 |
| Spawn-to-spawn views | 0 | 0 | 0 |

At 5.5 m/s (rifle in hand) a 52 m walk takes about 9.5 s. Contact comes earlier because defenders move up to their hold spots and toward the sound of footsteps.

## How the layouts were tuned

The blockouts were generated once from a small layout script (outside the repository, so the `.map` files are the only source), then tuned in three rounds with bots and the sightline report:

1. **First build:** first contact Depot 4.1–5.1 s, Square 6.1–7.6 s, Spillway 3.4–5.8 s. Depot and Spillway were too quick: defenders who heard footsteps met attackers early, and on Spillway an attacker in the tank yard could see a defender on the B terrace 30 m away. Both maps got 2 m deeper spawn yards at each end (56 m long), Depot's corridor between the warehouse and the boxcar was closed to the south, and Spillway got a control house in front of the terrace.
2. **Sightlines:** the report found 45–60 m diagonals slipping between obstacles that had only been placed against straight north–south views. Obstacles now overlap (the alley houses, the containers, the pump-house corridor blockers), doors are offset (pump house, market hall, the passage and arch on Square), there are "gates" with something right behind them (Spillway's pipe wall), and kiosks and wooden stacks break the views across the spawn yards and forecourts.
3. **Bugs found on the way:** Depot's west ramp onto the dock started against a container stack, so it couldn't be walked onto (bots took a 43 m detour); the ramp and stack moved. Spillway's 1.5 m terrace saw over the 2.4 m channel fences, which are now 3 m.

## Next for these maps

- **Your playtest:** how they feel, what to change, and the final names.
- **Detail pass (M8):** props, trim, signs, lamps, and baked lighting once it's decided.
- **Bomb logic (M8):** the `bomb_sites` areas are ready; switch on `monitoring` when planting needs them.
- **Respawn mode (M8):** pick a `respawn_points` marker away from enemies.
