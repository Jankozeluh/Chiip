"""
make_quarry.py - writes maps/quarry.map, Quarry (M17, D-245): a quick map built from the map kit only,
like the kit gallery (tools/make_kit_gallery.py, whose helpers it uses). Run it again after changing the
layout, then rebuild the scene (tools/build_maps.gd) and re-bake its navmesh (tools/bake_navmesh.gd); the
first time, make the scene with tools/new_map.gd.

    ~/miniconda3/envs/chiip/bin/python -I tools/make_quarry.py

The map is generated: change this script, not the .map.

Layout (Godot metres; north, -z, is the defenders' end; 48 m wide, 60 m long, rock walls 5 m high):
    Three lanes. West (x -24..-10) and east (10..24) are the quarry's yards; mid (-5..5) is the haul road.
    Two concrete blocks (x -10..-5 and 5..10, z -14..14) split them, each with a 3 m passage at z = 0.
    Mid: a weigh-house in the middle and two staggered walls (z = -11 and +11) so no line runs from
    spawn to spawn. West: a shed with a path on each side and two wall stubs; east: two staggered sheds
    and two stubs, so no lane is one long sightline. Bomb site A in the north-west yard, B in the
    north-east. Each spawn room has a wall to each side and a crusher in front, which splits the band
    between the yards. Five defender spawns at z = -27, five attacker spawns at z = +24 (51 m apart).
Materials (D-063, at most 6): gravel and dirt floors, mossy rock walls, worn concrete blocks, green
corrugated sheds, wood for the weigh-house; crates, barrels and barriers from the kit as details.
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from make_kit_gallery import brush, entity, point, prop_sizes  # noqa: E402
sys.path.insert(0, os.path.join(ROOT, 'tools', 'modelgen'))
import props  # noqa: E402

OUT = os.path.join(ROOT, 'maps', 'quarry.map')
HALF_X, HALF_Z, WALL_H, WALL_T = 24.0, 30.0, 5.0, 0.5
FLOOR, DIRT = 'gravel_grey', 'nature/dirt'
ROCK, CONCRETE, SHED, WOOD = 'nature/rock_moss', 'industrial/concrete_worn', 'industrial/corrugated_green', 'wood_planks'

# Solid blocks: (x0, z0, x1, z1, height, texture). Every gap between them is 2.5 m or more (D-060).
BLOCKS = [
    # The two long blocks, each split by a passage at z = 0.
    (-10, -14, -5, -1.5, 5.0, CONCRETE), (-10, 1.5, -5, 14, 5.0, CONCRETE),
    (5, -14, 10, -1.5, 5.0, CONCRETE), (5, 1.5, 10, 14, 5.0, CONCRETE),
    # Mid: the weigh-house and the two staggered walls (tall cover).
    (-2, -2.5, 2, 2.5, 3.2, WOOD),
    (-5, -11.5, 1, -10.5, 3.0, CONCRETE), (-1, 10.5, 5, 11.5, 3.0, CONCRETE),
    # West yard: a shed, and two walls with their openings on opposite sides (an S-bend, no straight line).
    (-20, -4, -14, 4, 4.0, SHED), (-24, -9.5, -14, -8.5, 3.2, ROCK), (-20, 8.5, -10, 9.5, 3.2, ROCK),
    # East yard: two staggered sheds and two walls, openings on opposite sides.
    (14, -8, 20, -2, 4.0, SHED), (15, 4, 21, 10, 4.0, SHED),
    (10, -14.5, 18, -13.5, 3.2, ROCK), (16, 13.5, 24, 14.5, 3.2, ROCK),
    # The ends: walls between each spawn room and the yards beside it, and a crusher in each end's band.
    (-9, -30, -7, -21, 3.5, CONCRETE), (7, -30, 9, -21, 3.5, CONCRETE), (-2, -21, 2, -14, 3.2, SHED),
    (-11, 20, -9, 30, 3.5, CONCRETE), (9, 20, 11, 30, 3.5, CONCRETE), (-2, 14, 2, 20, 3.2, SHED),
]
# Dirt patches on the gravel: (x0, z0, x1, z1), on the 4 m floor grid.
DIRT_PATCHES = [(-24, -28, -12, -16), (12, -28, 24, -16), (-4, -8, 4, 8)]
# Low cover and dressing from the kit: (prop, x, z, facing). Never on a site's middle (the plant spot).
PROPS = [
    ('crate_wood', -14.0, -23.0, 0), ('crate_wood', 20.0, -23.0, 90), ('barrel_group', -21.0, -18.5, 0),
    ('barrier_concrete', 13.5, -19.0, 0), ('crate_wood_small', 5.0, 18.0, 0),
    ('barrel_group', -21.5, 18.0, 0), ('crate_metal', 21.0, 20.0, 90), ('barrier_concrete', -16.0, 22.0, 90),
    ('crate_wood', 0.0, 8.0, 0), ('barrel', -6.5, 28.0, 0), ('barrel', 5.0, -29.0, 0),
]


def world():
    brushes = []
    for x in range(int(-HALF_X), int(HALF_X), 4):
        for z in range(int(-HALF_Z), int(HALF_Z), 4):
            dirt = any(x0 <= x < x1 and z0 <= z < z1 for x0, z0, x1, z1 in DIRT_PATCHES)
            brushes.append(brush((x, -0.4, z), (x + 4, 0, min(z + 4, HALF_Z)), FLOOR, DIRT if dirt else None))
    # The quarry's rock walls all round.
    brushes.append(brush((-HALF_X - WALL_T, 0, -HALF_Z - WALL_T), (-HALF_X, WALL_H, HALF_Z + WALL_T), ROCK))
    brushes.append(brush((HALF_X, 0, -HALF_Z - WALL_T), (HALF_X + WALL_T, WALL_H, HALF_Z + WALL_T), ROCK))
    brushes.append(brush((-HALF_X, 0, -HALF_Z - WALL_T), (HALF_X, WALL_H, -HALF_Z), ROCK))
    brushes.append(brush((-HALF_X, 0, HALF_Z), (HALF_X, WALL_H, HALF_Z + WALL_T), ROCK))
    for x0, z0, x1, z1, height, tex in BLOCKS:
        brushes.append(brush((x0, 0, z0), (x1, height, z1), tex))
    return entity('worldspawn', brushes, mapversion=220)


def main():
    sizes = prop_sizes()
    ents = [world()]
    for name, x, z, facing in PROPS:
        if name not in sizes:
            raise SystemExit(f'no kit prop called {name}')
        ents.append(point(props.classname(name), x, 0, z, facing=facing))
    # Gameplay markers (MAPPING.md, "What the maps test checks").
    for sx in (-6.0, -3.0, 0.0, 3.0, 6.0):
        ents.append(point('info_defend_spawn', sx, 0, -27.0, facing=180))
        ents.append(point('info_attack_spawn', sx, 0, 24.0, facing=0))
    for site, x0, x1 in (('A', -22.0, -12.0), ('B', 12.0, 22.0)):
        ents.append(entity('trigger_bombsite', [brush((x0, 0, -25.0), (x1, 3, -17.0), FLOOR)], site=site))
    routes = {
        'west': [(-15.0, 18.0), (-22.0, 0.0), (-17.0, -14.0), (-17.0, -19.0)],
        'mid': [(-3.5, 15.0), (3.5, 0.0), (3.5, -13.0), (4.5, -19.5)],
        'east': [(15.0, 18.0), (12.0, 0.0), (21.0, -14.0), (17.0, -19.0)],
    }
    for route, points in routes.items():
        for i, (rx, rz) in enumerate(points):
            ents.append(point('info_route', rx, 0, rz, route=route, order=i + 1))
    for hx, hz, facing in ((-19.0, -15.0, 0), (-11.5, -18.0, 20), (0.0, -15.0, 0), (11.5, -18.0, -20), (19.0, -15.0, 0), (-7.5, -16.0, 0)):
        ents.append(point('info_hold', hx, 0, hz, facing=facing))
    respawns = [(-20, -27), (-12, -28), (12, -28), (20, -27), (-21, 26), (-6, 28), (6, 28), (21, 26),
                (-22, 6), (22, 0), (-12, 0), (12, 6)]
    patrols = [(-18, -20), (18, -20), (0, -23), (-22, -6), (22, -6), (-12, 18), (14, 22), (0, 22),
               (-3.5, 0), (3.5, -6), (-22, 18), (18, 17), (-16, 6), (17, 1), (-7, 0), (7, 0)]
    for mx, mz in respawns:
        ents.append(point('info_respawn', mx, 0, mz, facing=0 if mz > 0 else 180))
    for mx, mz in patrols:
        ents.append(point('info_patrol', mx, 0, mz))
    with open(OUT, 'w') as fh:
        fh.write('// Game: Chiip\n// Format: Valve\n')
        fh.write('// Quarry (D-245): generated by tools/make_quarry.py. Do not edit; change the script.\n')
        for i, e in enumerate(ents):
            fh.write(f'// entity {i}\n{e}\n')
    print(f'wrote {OUT}: {len(ents)} entities')


if __name__ == '__main__':
    main()
