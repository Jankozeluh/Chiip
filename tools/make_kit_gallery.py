"""
make_kit_gallery.py - writes maps/kit/kit_gallery.map: every texture and entity of the map kit
laid out in one playable yard (D-129). Run it again after adding textures or props, then rebuild
the gallery's scene (tools/build_maps.gd) and re-bake its navmesh (tools/bake_navmesh.gd);
the first time, make the scene with tools/new_map.gd.

    ~/miniconda3/envs/chiip/bin/python -I tools/make_kit_gallery.py

The gallery is generated: change this script, not the .map (an edit in TrenchBroom is lost the
next time it runs). It doubles as an example of a map built only from TrenchBroom entities:
spawns, bomb sites, routes, hold spots, respawn and patrol points are all entities.

Layout (Godot metres; TrenchBroom x = Godot z, y = Godot x, z = up; 39.37 units a metre):
    a yard 40 m wide (x) and 72 m long (z), 4 m walls. North (-z) is the defenders' end.
    West wall: one 2-metre panel per wall texture.  East wall: doors, windows, signs, wall
    lamps and pipes.  Middle: floor tiles of every floor texture, props in rows by category,
    a canopy with the ceiling lamps, a glass pane and a chain-link fence.
"""
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'modelgen'))
import kit  # noqa: E402
import props  # noqa: E402

OUT = os.path.join(ROOT, 'maps', 'kit', 'kit_gallery.map')
S = 39.37
HALF_X, HALF_Z, WALL_H, WALL_T = 20.0, 36.0, 4.0, 0.5

WALL_TEXTURES = [
    'concrete_floor', 'plaster_wall', 'painted_plaster', 'stone_grey', 'metal_plates', 'wood_planks',
    'industrial/corrugated_grey', 'industrial/corrugated_green', 'industrial/corrugated_rust', 'industrial/corrugated_teal',
    'industrial/rust_plates', 'industrial/concrete_worn',
    'industrial/perforated', 'industrial/hazard_stripes', 'industrial/diamond_plate', 'industrial/grate',
    'urban/blocks_grey', 'urban/rubble_wall', 'urban/plaster_olive', 'urban/wood_siding', 'urban/roof_slate',
    'interior/tiles_white', 'interior/tiles_dark', 'interior/ceiling_tiles', 'interior/planks_old',
    'nature/rock_moss', 'nature/bark', 'gravel_grey', 'urban/slabs',
]
FLOOR_TEXTURES = [
    'urban/asphalt', 'urban/cobbles', 'urban/slabs', 'industrial/diamond_plate', 'industrial/grate',
    'industrial/floor_line', 'interior/wood_floor_dark', 'interior/parquet', 'interior/tiles_dark',
    'interior/tiles_checker', 'interior/terrazzo', 'nature/grass', 'nature/dirt', 'gravel_grey', 'wood_planks',
]
WALL_PROP_CATEGORIES = ('doors', 'signs')
WALL_PROPS = ('pipe_wall', 'pipe_valve', 'light_wall', 'light_flood')
CEILING_LAMPS = ('light_cage', 'light_ceiling', 'light_strip')


def tb(x, y, z):
    """Godot metres -> TrenchBroom units (x, y, z)."""
    return z * S, x * S, y * S


def brush(lo, hi, tex, top=None):
    """an axis-aligned box brush between Godot points lo and hi (metres)."""
    (x0, y0, z0), (x1, y1, z1) = tb(*lo), tb(*hi)
    x0, x1 = sorted((round(x0), round(x1)))
    y0, y1 = sorted((round(y0), round(y1)))
    z0, z1 = sorted((round(z0), round(z1)))
    top = top or tex
    return '\n'.join([
        '{',
        f'( {x0} {y0} {z1} ) ( {x0} {y1} {z1} ) ( {x1} {y1} {z1} ) {top} [ 1 0 0 0 ] [ 0 -1 0 0 ] 0 1 1',
        f'( {x0} {y0} {z0} ) ( {x1} {y1} {z0} ) ( {x0} {y1} {z0} ) {tex} [ -1 0 0 0 ] [ 0 -1 0 0 ] 0 1 1',
        f'( {x0} {y0} {z0} ) ( {x0} {y0} {z1} ) ( {x1} {y0} {z1} ) {tex} [ 1 0 0 0 ] [ 0 0 -1 0 ] 0 1 1',
        f'( {x0} {y1} {z0} ) ( {x1} {y1} {z1} ) ( {x0} {y1} {z1} ) {tex} [ -1 0 0 0 ] [ 0 0 -1 0 ] 0 1 1',
        f'( {x0} {y0} {z0} ) ( {x0} {y1} {z0} ) ( {x0} {y1} {z1} ) {tex} [ 0 -1 0 0 ] [ 0 0 -1 0 ] 0 1 1',
        f'( {x1} {y0} {z0} ) ( {x1} {y1} {z1} ) ( {x1} {y1} {z0} ) {tex} [ 0 1 0 0 ] [ 0 0 -1 0 ] 0 1 1',
        '}'])


def entity(classname, brushes=(), **properties):
    lines = ['{', f'"classname" "{classname}"']
    lines += [f'"{k}" "{v}"' for k, v in properties.items()]
    for i, b in enumerate(brushes):
        lines += [f'// brush {i}', b]
    return '\n'.join(lines + ['}'])


def point(classname, x, y, z, facing=None, **properties):
    """a point entity at Godot (x, y, z). facing: the Godot direction (degrees about +Y, 0 = -Z,
    90 = -X) its front should face; func_godot turns entities by angle + 180."""
    ox, oy, oz = tb(x, y, z)
    if facing is not None:
        properties = dict(angle=f'{(facing - 180) % 360:g}', **properties)
    return entity(classname, origin=f'{ox:.0f} {oy:.0f} {oz:.0f}', **properties)


def world():
    brushes = []
    # Floor: 4 x 4 m tiles, concrete except the carpet of floor textures in the middle.
    carpet = {}
    for i, tex in enumerate(FLOOR_TEXTURES):
        carpet[(-8 + (i % 4) * 4, -8 + (i // 4) * 4)] = tex     # a 4 x 4 block of tiles on the grid
    for x in range(int(-HALF_X), int(HALF_X), 4):
        for z in range(int(-HALF_Z), int(HALF_Z), 4):
            brushes.append(brush((x, -0.4, z), (x + 4, 0, z + 4), 'concrete_floor', carpet.get((x, z))))
    # West wall: one panel per wall texture, the rest plain.
    z = -HALF_Z
    for tex in WALL_TEXTURES + ['concrete_floor'] * 8:
        if z >= HALF_Z:
            break
        brushes.append(brush((-HALF_X - WALL_T, 0, z), (-HALF_X, WALL_H, min(z + 2.0, HALF_Z)), tex))
        z += 2.0
    brushes.append(brush((HALF_X, 0, -HALF_Z), (HALF_X + WALL_T, WALL_H, HALF_Z), 'plaster_wall'))
    brushes.append(brush((-HALF_X - WALL_T, 0, -HALF_Z - WALL_T), (HALF_X + WALL_T, WALL_H, -HALF_Z), 'concrete_floor'))
    brushes.append(brush((-HALF_X - WALL_T, 0, HALF_Z), (HALF_X + WALL_T, WALL_H, HALF_Z + WALL_T), 'concrete_floor'))
    # A canopy for the ceiling lamps: a roof on four posts.
    cx, cz = -12.0, 22.0
    brushes.append(brush((cx - 4, 3.5, cz - 2.5), (cx + 4, 3.7, cz + 2.5), 'industrial/corrugated_grey'))
    for dx in (-3.8, 3.6):
        for dz in (-2.3, 2.1):
            brushes.append(brush((cx + dx, 0, cz + dz), (cx + dx + 0.2, 3.5, cz + dz + 0.2), 'metal_plates'))
    return entity('worldspawn', brushes, mapversion=220), (cx, cz)


def prop_sizes():
    """every prop's footprint (x, z) and height, in metres, from the generator."""
    sizes = {}
    for name, spec in props.PROPS.items():
        lo, hi = kit.bounds(kit.build(spec))
        sizes[name] = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], lo, hi)
    return sizes


def main():
    ents = []
    worldspawn, (cx, cz) = world()
    ents.append(worldspawn)
    sizes = prop_sizes()
    order = list(props.CATEGORY_COLORS)
    names = sorted(props.PROPS, key=lambda n: (order.index(props.PROPS[n]['category']), n))
    wall = [n for n in names if props.PROPS[n]['category'] in WALL_PROP_CATEGORIES or n in WALL_PROPS]
    ceiling = [n for n in names if n in CEILING_LAMPS]
    floor = [n for n in names if n not in wall and n not in ceiling]

    # Floor props in rows, 2.5 m apart so bots fit between them, their fronts to the north,
    # around the carpet of floor tiles, the canopy, the glass and fence, and the bomb sites.
    gap = 2.5
    reserved = [(-8.5, 8.5, -8.5, 8.5), (cx - 4.5, cx + 4.5, cz - 3.0, cz + 3.0), (5.0, 17.0, 21.0, 23.5)]
    x, z, row_depth = -HALF_X + 2.0, -21.0, 0.0
    taken = list(reserved[1:])        # footprints markers must keep off (the carpet is free floor)
    for name in floor:
        w, h, d, lo, hi = sizes[name]
        while True:
            if x + w > HALF_X - 2.0:
                x, z, row_depth = -HALF_X + 2.0, z + row_depth + gap, 0.0
            blocker = next((r for r in reserved if x < r[1] and x + w > r[0] and z < r[3] and z + d > r[2]), None)
            if blocker is None:
                break
            x = blocker[1] + gap
        ents.append(point(props.classname(name), x - lo[0], 0, z - lo[2], facing=0))
        taken.append((x, x + w, z, z + d))
        x += w + gap
        row_depth = max(row_depth, d)
    if z + row_depth > HALF_Z - 5.0:
        raise SystemExit(f'the props reach z = {z + row_depth:.1f}: too far south, into the attackers\' spawn')

    # Wall props along the inside of the east wall, facing west (into the yard).
    face = HALF_X - 0.001
    zz = -HALF_Z + 4.0
    for name in wall:
        w, h, d, lo, hi = sizes[name]
        span = max(w, 1.0)
        if name.startswith(('door', 'pipe_')):
            y = 0.0
        elif name.startswith('light_'):
            y = 2.8
        elif name.startswith('window'):
            y = 1.9
        else:
            y = 1.8
        ents.append(point(props.classname(name), face, y, zz + span / 2, facing=90))
        zz += span + 1.5

    # Ceiling lamps under the canopy.
    for i, name in enumerate(ceiling):
        ents.append(point(name, cx - 2.5 + i * 2.5, 3.5, cz))

    # See-through brushes: a glass pane and a chain-link fence, 4 m wide.
    ents.append(entity('func_glass', [brush((6, 0, 22), (10, 2.6, 22.06), 'interior/glass')]))
    ents.append(entity('func_fence', [brush((12, 0, 22), (16, 2.6, 22.04), 'industrial/chainlink')]))
    ents.append(entity('func_clip', [brush((-HALF_X, WALL_H, -HALF_Z), (HALF_X, WALL_H + 2, HALF_Z), 'concrete_floor')]))

    # Gameplay: spawns at both ends, sites at the defenders' end, routes, holds, respawns, patrols.
    for i, sx in enumerate((-6, -3, 0, 3, 6)):
        ents.append(point('info_attack_spawn', sx, 0, HALF_Z - 2.5, facing=0))
        ents.append(point('info_defend_spawn', sx, 0, -HALF_Z + 2.5, facing=180))
    for site, sx in (('A', -12.0), ('B', 12.0)):
        ents.append(entity('trigger_bombsite', [brush((sx - 4, 0, -31), (sx + 4, 3, -25), 'concrete_floor')], site=site))
    for route, rx in (('west', -12.0), ('mid', 0.0), ('east', 12.0)):
        for i, rz in enumerate((30.0, 18.0, 6.0, -8.0, -22.0)):
            ents.append(point('info_route', rx, 0, rz, route=route, order=i + 1))
    for hx, hz in ((-12, -24), (-6, -24), (0, -26), (6, -24), (12, -24)):
        ents.append(point('info_hold', hx, 0, hz, facing=180))
    def free(mx, mz):
        return not any(r[0] - 0.8 < mx < r[1] + 0.8 and r[2] - 0.8 < mz < r[3] + 0.8 for r in taken)

    respawns = [(-16, -30), (0, -28), (16, -30), (-16, 30), (0, 28), (16, 30),
                (-7, -4), (7, -4), (-7, 4), (7, 4), (0, -3), (0, 3)]
    patrols = [(-16, -28), (-6, -28), (6, -28), (16, -28), (-9, -5), (-3, -5), (3, -5), (9, -5),
               (-9, 5), (-3, 5), (3, 5), (9, 5), (-6, 30), (6, 30), (-17, 31), (17, 31)]
    for mx, mz in respawns + patrols:
        if not free(mx, mz):
            raise SystemExit(f'a marker at x {mx}, z {mz} stands on a prop: move it')
    for mx, mz in respawns:
        ents.append(point('info_respawn', mx, 0, mz, facing=0 if mz > 0 else 180))
    for mx, mz in patrols:
        ents.append(point('info_patrol', mx, 0, mz))

    with open(OUT, 'w') as fh:
        fh.write('// Game: Chiip\n// Format: Valve\n')
        fh.write('// The map kit gallery (D-129): generated by tools/make_kit_gallery.py. Do not edit; change the script.\n')
        for i, e in enumerate(ents):
            fh.write(f'// entity {i}\n{e}\n')
    print(f'{OUT}: {len(ents)} entities')


if __name__ == '__main__':
    main()
