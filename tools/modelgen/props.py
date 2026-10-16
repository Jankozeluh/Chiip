"""
props.py - the props of Chiip's map kit (D-122, M10).

A prop is built like the crew (D-054): low-poly pieces (bevelled boxes, tapered cylinders,
low-res spheres) painted from 16-shade ramps with baked light, grain and patterns. Props have
no bones; every piece sits in prop space:

    metres, +Y up, the prop stands on y = 0 and is centred on x = 0, z = 0,
    its front faces -Z (like the crew), which is the direction the entity's angle points.

Each prop is a function returning its pieces, registered with @prop(...), which also says:
    category   the set it belongs to in the entity list ('crates', 'industrial', ...)
    surface    what footsteps and bullet impacts sound like on it: hard, metal, wood, gravel
    collide    'auto' (one box around everything), 'none' (decoration), or a list of boxes
               (centre, size[, yaw degrees]) in prop space
    layer      'world' blocks movement, bullets and sight; 'seethrough' blocks only movement
               (railings, open barriers: D-123)
    light      for lamps (D-124): the light's kind, position and default colour, energy, range

modelgen.py props writes, per prop: assets/models/props/<name>.glb + <name>_albedo.png, the
scene maps/kit/props/<classname>.tscn (or maps/kit/lights/ for lamps), and all props'
entity definitions into maps/fgd/chiip_kit_fgd.tres (func_godot point classes; TrenchBroom
shows the .glb itself).
"""
import math

import numpy as np

import paint
from geometry import Piece
from paint import concept

BONE = 'prop'
# Atlas texels per metre on props: the world's textures have about 39 (64 per 1.63 m), the
# crew 96. Big props (vehicles, containers, trees) use fewer so they fit a 256-wide atlas.
DENSITY = 48

# ---------------------------------------------------------------- palette
# Ramps beyond the concept palette (tools/concept/spritegen.py), built the same way: anchors
# interpolated in OkLab. Neutral and muted like the maps (D-031, D-063): rust stays brown,
# greens stay olive, the only strong colour is safety yellow on small parts.
_ANCHORS = {
    'rust':      ['#0c0705', '#2e1910', '#5a3420', '#8c5a36', '#c49a6c'],
    'safety':    ['#120d02', '#3d2e08', '#86661a', '#c8a436', '#efe0a0'],
    'leaf':      ['#06080a', '#18210f', '#33441f', '#5a6c3a', '#9aa77a'],
    'dirt':      ['#0b0907', '#28211a', '#4f4439', '#7d7062', '#b5aa9a'],
    'cardboard': ['#100b06', '#3a2b1a', '#6e5638', '#9f8560', '#d2c09c'],
    'concrete':  ['#0b0b0b', '#2a2a29', '#555451', '#8a8984', '#c9c8c2'],
    'teal':      ['#050908', '#14211f', '#2c4440', '#56706a', '#9fb3ad'],   # muted grey-green paint
    'fb_white':  ['#2b2d2e', '#6d7072', '#b9bcbc', '#e9eae6', '#ffffff'],   # fullbright, neutral
    'fb_amber':  ['#3a1d00', '#8a4c08', '#d78f22', '#ffcc6a', '#fff4d8'],   # fullbright, warm
}


def _build_ramp(anchors):
    lab = concept.lin_to_oklab(concept.srgb_to_lin(np.array([concept._hex(h) for h in anchors])))
    xs = np.linspace(0, 1, len(anchors))
    out = []
    for i in range(16):
        t = i / 15.0
        out.append([np.interp(t, xs, lab[:, k]) for k in range(3)])
    return np.round(concept.lin_to_srgb(concept.oklab_to_lin(np.array(out))) * 255).astype(np.uint8)


RAMPS = {name: _build_ramp(a) for name, a in _ANCHORS.items()}

# ramp, base shade (0-15) at mid brightness, grain (chance of a +-1 speck), pattern, edges
# (darker rim on box sides), glow (an emissive material: bulbs, lit panels).
MATERIALS = {
    'wood':      dict(ramp='wood', base=7, grain=0.14, pattern='woodgrain'),
    'wood_lt':   dict(ramp='wood', base=9, grain=0.12, pattern='woodgrain'),
    'wood_dk':   dict(ramp='wood', base=5, grain=0.12, pattern='woodgrain'),
    'planks':    dict(ramp='wood', base=8, grain=0.12, pattern='planks'),
    'planks_dk': dict(ramp='wood', base=6, grain=0.12, pattern='planks'),
    'metal':     dict(ramp='gunmetal', base=7, grain=0.20, pattern='speckle'),
    'metal_lt':  dict(ramp='grey', base=10, grain=0.15),
    'metal_dk':  dict(ramp='charcoal', base=7, grain=0.15),
    'steel':     dict(ramp='gunmetal', base=9, grain=0.12),
    'plate':     dict(ramp='gunmetal', base=8, grain=0.08, pattern='plate'),
    'ribs':      dict(ramp='gunmetal', base=8, grain=0.10, pattern='ribs'),
    'olive':     dict(ramp='olive', base=7, grain=0.16),
    'olive_dk':  dict(ramp='olive', base=5, grain=0.14),
    'olive_ribs': dict(ramp='olive', base=7, grain=0.10, pattern='ribs'),
    'teal':      dict(ramp='teal', base=8, grain=0.14),
    'teal_ribs': dict(ramp='teal', base=8, grain=0.10, pattern='ribs'),
    'grey_ribs': dict(ramp='grey', base=8, grain=0.10, pattern='ribs'),
    'paint_grey': dict(ramp='grey', base=8, grain=0.14),
    'paint_white': dict(ramp='stone', base=12, grain=0.10),
    'rust':      dict(ramp='rust', base=7, grain=0.30, pattern='blotches'),
    'safety':    dict(ramp='safety', base=9, grain=0.14),
    'concrete':  dict(ramp='concrete', base=9, grain=0.30),
    'concrete_dk': dict(ramp='concrete', base=6, grain=0.30),
    'stone':     dict(ramp='stone', base=8, grain=0.25),
    'rubber':    dict(ramp='charcoal', base=3, grain=0.08),
    'tire':      dict(ramp='charcoal', base=3, grain=0.06, pattern='tread'),
    'plastic':   dict(ramp='grey', base=5, grain=0.06),
    'cardboard': dict(ramp='cardboard', base=8, grain=0.18),
    'tape':      dict(ramp='cardboard', base=11, grain=0.0, edges=False),
    'canvas':    dict(ramp='olive', base=6, grain=0.25),
    'leaf':      dict(ramp='leaf', base=8, grain=0.30, pattern='leaves', edges=False),
    'leaf_dk':   dict(ramp='leaf', base=6, grain=0.30, pattern='leaves', edges=False),
    'bark':      dict(ramp='dirt', base=6, grain=0.25, pattern='woodgrain'),
    'soil':      dict(ramp='dirt', base=5, grain=0.35, edges=False),
    'brass':     dict(ramp='brass', base=8, grain=0.10),
    'glass':     dict(ramp='glass', base=6, grain=0.0, pattern='glint', edges=False),
    'sign':      dict(ramp='stone', base=13, grain=0.04, edges=False),
    'sign_dark': dict(ramp='charcoal', base=3, grain=0.0, edges=False),
    'sign_yellow': dict(ramp='safety', base=10, grain=0.04, edges=False),
    'sign_green': dict(ramp='moss', base=7, grain=0.04, edges=False),
    'black':     dict(ramp='charcoal', base=2, grain=0.05),
    'glow_warm': dict(ramp='fb_amber', base=12, grain=0.0, glow=True, edges=False),
    'glow_white': dict(ramp='fb_white', base=12, grain=0.0, glow=True, edges=False),
}


# ---------------------------------------------------------------- patterns (shade offsets)
def _face_axes(P):
    """the two in-plane axes of a side (the third barely changes across it), as (u, v) indices,
    v being the vertical one when the side is a wall."""
    spread = [float(np.ptp(P[..., k])) for k in range(3)]
    normal = int(np.argmin(spread))
    axes = [k for k in range(3) if k != normal]
    if normal != 1:
        return (axes[0] if axes[1] == 1 else axes[1]), 1, normal
    return 0, 2, normal


def _planks(rng, I, J, w, h, P):
    """boards 0.16 m wide with dark gaps between them and a streak or two of grain:
    horizontal on walls, along x on tops."""
    u, v, _ = _face_axes(P)
    across = P[..., v]
    board = np.floor(across / 0.16)
    gap = (across - board * 0.16) < (1.2 / DENSITY)
    streak = rng.random((int(board.max() - board.min()) + 3, 7))
    s = streak[(board - board.min()).astype(int), (np.floor(P[..., u] * 3) % 7).astype(int)] < 0.18
    return -2.0 * gap - 1.0 * s


def _ribs(rng, I, J, w, h, P):
    """corrugation: vertical ribs every 0.12 m on walls (a light and a dark band each)."""
    u, _, normal = _face_axes(P)
    if normal == 1:
        return 0.0
    phase = (P[..., u] / 0.12) % 1.0
    return 1.0 * (phase < 0.25) - 1.0 * ((phase >= 0.5) & (phase < 0.75))


def _blotches(rng, I, J, w, h, P):
    """rust: darker and lighter patches about 10 cm across."""
    cell = np.floor(P / 0.1).astype(int)
    hsh = (cell[..., 0] * 73856093) ^ (cell[..., 1] * 19349663) ^ (cell[..., 2] * 83492791)
    r = (hsh % 97) / 97.0
    return -1.0 * (r < 0.25) + 1.0 * (r > 0.85)


def _leaves(rng, I, J, w, h, P):
    """foliage: clumps two texels across, much lighter or darker."""
    r = rng.random((h // 2 + 3, w // 2 + 3))
    rr = r[np.clip(J // 2 + 1, 0, h // 2 + 2), np.clip(I // 2 + 1, 0, w // 2 + 2)]
    return 2.0 * (rr > 0.8) - 2.0 * (rr < 0.25)


def _tread(rng, I, J, w, h, P):
    return -1.0 * ((I % 3) == 0)


paint.PATTERNS.update(planks=_planks, ribs=_ribs, blotches=_blotches, leaves=_leaves, tread=_tread)


# ---------------------------------------------------------------- lettering for signs
# 5 x 7 glyphs, one string per row, '#' = ink.
GLYPHS = {
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.####', '#....', '#....', '#....', '#....', '#....', '.####'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'I': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'],
    'N': ['#...#', '##..#', '#.#.#', '#.#.#', '#..##', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '!': ['..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'],
    '>': ['..#..', '..##.', '#####', '######', '#####', '..##.', '..#..'],
    ' ': ['.....'] * 7,
}


def lettering(text, centre, height, side='-z', mat='sign_dark'):
    """a decal that writes `text` in block letters on one side of a piece. centre (x, y) is the
    middle of the text in the piece's frame, height the letters' height in metres. On the '-z'
    side (the front) the text reads left to right for someone standing in front of it."""
    rows = len(GLYPHS['A'])
    px = height / rows
    widths = [max(len(r) for r in GLYPHS[c]) for c in text]
    total = (sum(widths) + len(text) - 1) * px
    cx, cy = centre

    def test(x, y, z, face):
        if face != side:
            return False
        col = (cx - x if side == '-z' else x - cx) + total / 2
        row = (cy + height / 2 - y) / px
        if col < 0 or col >= total or row < 0 or row >= rows:
            return False
        c = col / px
        for ch, wd in zip(text, widths):
            if c < wd:
                g = GLYPHS[ch][int(row)]
                return int(c) < len(g) and g[int(c)] == '#'
            c -= wd + 1
            if c < 0:
                return False
        return False
    return test, mat


def stripes(width, mat, side=None, axis=(1, 1)):
    """a decal of diagonal hazard stripes `width` metres wide (on every side, or only `side`)."""
    def test(x, y, z, face):
        if side is not None and face != side:
            return False
        a = (x if face not in ('+x', '-x') else z) * axis[0] + y * axis[1]
        return (math.floor(a / width) % 2) == 0
    return test, mat


# ---------------------------------------------------------------- piece helpers
def box(size, pos, mat, bevel=0.012, rot=(0, 0, 0), decals=(), name=''):
    """a box centred on pos."""
    return Piece(BONE, 'box', size, pos, rot, mat=mat, bevel=bevel, decals=decals, name=name)


def cyl(radius, length, pos, mat, axis='+y', radius_end=None, sides=8, rot=(0, 0, 0), decals=(), smooth=None):
    """a cylinder from pos along axis."""
    r2 = radius if radius_end is None else radius_end
    return Piece(BONE, 'cyl', (radius, r2, length), pos, rot, mat=mat, axis=axis, sides=sides, decals=decals,
                 smooth=smooth)


def ell(radii, pos, mat, sides=8, rings=5, rot=(0, 0, 0)):
    return Piece(BONE, 'ell', radii, pos, rot, mat=mat, sides=sides, rings=rings)


def moved(pieces, offset=(0, 0, 0), yaw=0.0):
    """copies of pieces turned by yaw degrees about +Y, then moved by offset."""
    out = []
    a = math.radians(yaw)
    r = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
    for p in pieces:
        out.append(Piece(p.bone, p.shape, p.size, r @ p.pos + np.asarray(offset, float),
                         (p.rot[0], p.rot[1] + yaw, p.rot[2]), mat=p.mat, bevel=p.bevel, sides=p.sides,
                         rings=p.rings, axis=p.axis, clip=p.clip, smooth=p.smooth, decals=p.decals, name=p.name))
    return out


# ---------------------------------------------------------------- registry
PROPS = {}

# TrenchBroom entity-box colours per category.
CATEGORY_COLORS = {
    'crates': (0.65, 0.48, 0.3), 'industrial': (0.55, 0.58, 0.6), 'barriers': (0.75, 0.7, 0.35),
    'urban': (0.6, 0.6, 0.55), 'interior': (0.55, 0.5, 0.45), 'signs': (0.9, 0.9, 0.85),
    'vehicles': (0.5, 0.55, 0.5), 'nature': (0.4, 0.6, 0.35), 'debris': (0.5, 0.45, 0.4),
    'lights': (1.0, 0.8, 0.4),
}


def prop(name, category, description, surface='hard', collide='auto', layer='world', density=DENSITY,
         light=None):
    """registers a prop part list; see the module docstring for the arguments."""
    def deco(fn):
        PROPS[name] = dict(name=name, build=fn, category=category, description=description, surface=surface,
                           collide=collide, layer=layer, density=density, light=light)
        return fn
    return deco


def classname(name):
    """the entity's classname: lamps keep their light_ name, everything else is prop_<name>."""
    return name if name.startswith('light_') else 'prop_' + name


# ================================================================ crates and pallets
def _crate(s, body='planks', frame='wood_dk'):
    """a wooden crate s metres on a side: planked sides, a frame of battens on every edge and
    a diagonal brace on the front and back."""
    t = 0.07 * s / 1.2 + 0.02          # batten width
    h = s / 2
    P = [box((s - 0.02, s - 0.02, s - 0.02), (0, h, 0), body, bevel=0.01)]
    for x in (-1, 1):
        for z in (-1, 1):
            P.append(box((t, s, t), (x * (h - t / 2), h, z * (h - t / 2)), frame, bevel=0.008))
    for y in (t / 2, s - t / 2):
        for z in (-1, 1):
            P.append(box((s - 2 * t, t, t * 0.9), (0, y, z * (h - t * 0.45)), frame, bevel=0))
        for x in (-1, 1):
            P.append(box((t * 0.9, t, s - 2 * t), (x * (h - t * 0.45), y, 0), frame, bevel=0))
    diag = math.degrees(math.atan2(s - 2 * t, s - 2 * t))
    for z in (-1, 1):
        P.append(box((math.hypot(s - 2 * t, s - 2 * t) - t, t * 0.9, t * 0.8), (0, h, z * (h - t * 0.4)), frame,
                     bevel=0, rot=(0, 0, diag * z)))
    return P


@prop('crate_wood', 'crates', 'Wooden crate, 1.2 m: low cover you can jump onto and shoot over.', surface='wood')
def crate_wood():
    return _crate(1.2)


@prop('crate_wood_small', 'crates', 'Small wooden crate, 0.8 m: a step up onto bigger crates.', surface='wood')
def crate_wood_small():
    return _crate(0.8)


@prop('crate_stack', 'crates', 'Two 1.2 m crates stacked, the top one turned a little: tall cover (2.4 m).',
      surface='wood', collide=[((0, 0.6, 0), (1.2, 1.2, 1.2)), ((0.05, 1.8, -0.03), (1.2, 1.2, 1.2), 9)])
def crate_stack():
    return _crate(1.2) + moved(_crate(1.2, 'planks_dk'), (0.05, 1.2, -0.03), 9)


@prop('crate_metal', 'crates', 'Olive steel transport box, 1.2 x 0.8 x 0.9 m, with handles and latches: low cover.',
      surface='metal')
def crate_metal():
    P = [box((1.2, 0.62, 0.8), (0, 0.31, 0), 'olive', bevel=0.02),
         box((1.24, 0.16, 0.84), (0, 0.70, 0), 'olive_dk', bevel=0.025),          # lid
         box((1.16, 0.04, 0.76), (0, 0.8, 0), 'olive', bevel=0.01)]
    for x in (-0.42, 0.42):
        P.append(box((0.08, 0.10, 0.04), (x, 0.58, -0.42), 'metal', bevel=0.008))    # latches
        P.append(box((0.08, 0.10, 0.04), (x, 0.58, 0.42), 'metal', bevel=0.008))
    for x in (-1, 1):
        P.append(box((0.04, 0.05, 0.26), (x * 0.62, 0.45, 0), 'metal_dk', bevel=0.008))  # handles
    P.append(box((0.36, 0.2, 0.01), (0, 0.36, -0.401), 'sign', bevel=0, decals=[lettering('A1', (0, 0), 0.16)]))
    for x in (-1, 1):
        for z in (-1, 1):
            P.append(box((0.07, 0.62, 0.07), (x * 0.585, 0.31, z * 0.385), 'olive_dk', bevel=0.01))
    return P


def _pallet(y0=0.0, mat='wood_lt'):
    P = []
    for z in (-0.42, 0, 0.42):
        P.append(box((1.2, 0.09, 0.14), (0, y0 + 0.045, z), mat, bevel=0))               # bearers
    for i in range(7):
        P.append(box((0.13, 0.024, 1.0), (-0.53 + i * 0.1767, y0 + 0.102, 0), mat, bevel=0))  # deck boards
    for x in (-0.53, 0, 0.53):
        P.append(box((0.13, 0.024, 1.0), (x, y0 + 0.012, 0), mat, bevel=0))               # bottom boards
    return P


@prop('pallet', 'crates', 'A wooden pallet lying flat (0.12 m). Decoration: no collision.', surface='wood',
      collide='none')
def pallet():
    return _pallet()


@prop('pallet_stack', 'crates', 'Four pallets stacked, 0.46 m: low clutter you jump onto.', surface='wood')
def pallet_stack():
    P = []
    for i, (dx, yaw) in enumerate(((0, 0), (0.03, 3), (-0.02, -2), (0.02, 5))):
        P += moved(_pallet(0, 'wood_lt' if i % 2 == 0 else 'wood'), (dx, i * 0.115, 0), yaw)
    return P


@prop('pallet_load', 'crates', 'A pallet of strapped cardboard boxes, 1.2 m tall: low cover.', surface='wood',
      collide=[((0, 0.6, 0), (1.2, 1.2, 1.0))])
def pallet_load():
    P = _pallet()
    tape = (lambda x, y, z, f: abs(x) < 0.025 and f == '+y', 'tape')
    for row, y in enumerate((0.125, 0.665)):
        for i, x in enumerate((-0.3, 0.3)):
            for j, z in enumerate((-0.25, 0.25)):
                lift = 0.02 * ((i + j + row) % 2)
                P.append(box((0.58, 0.52 - lift, 0.48), (x, y + 0.26 - lift / 2, z), 'cardboard', bevel=0.01,
                             decals=[tape]))
    for z in (-0.35, 0.35):
        P.append(box((1.21, 1.08, 0.03), (0, 0.66, z), 'black', bevel=0.004))             # straps
    return P


# ================================================================ barrels
def _barrel(mat, lid='metal_dk', band=None):
    P = [cyl(0.29, 0.88, (0, 0, 0), mat, sides=12)]
    for y in (0.29, 0.59):
        P.append(cyl(0.302, 0.035, (0, y, 0), band or mat, sides=12))                     # rolling hoops
    P.append(cyl(0.296, 0.03, (0, 0.86, 0), lid, sides=12))                                # rim
    P.append(cyl(0.05, 0.02, (0.17, 0.88, 0.05), 'metal', sides=6))                         # bung
    return P


@prop('barrel', 'industrial', 'Olive steel drum, 0.9 m: low cover.', surface='metal')
def barrel():
    return _barrel('olive')


@prop('barrel_rust', 'industrial', 'Rusty steel drum, 0.9 m: low cover.', surface='metal')
def barrel_rust():
    return _barrel('rust', 'rust')


@prop('barrel_hazard', 'industrial', 'Yellow drum with a black band, 0.9 m: low cover.', surface='metal')
def barrel_hazard():
    P = _barrel('safety', 'metal_dk', 'black')
    P.append(cyl(0.292, 0.16, (0, 0.36, 0), 'black', sides=12))
    return P


@prop('barrel_group', 'industrial', 'Three drums in a cluster, about 1.2 m across: low cover.', surface='metal',
      collide=[((0, 0.45, 0), (1.25, 0.9, 1.15))])
def barrel_group():
    return (moved(_barrel('olive'), (-0.31, 0, 0.2)) + moved(_barrel('rust', 'rust'), (0.32, 0, 0.18), 40)
            + moved(_barrel('olive_dk'), (0.0, 0, -0.33), 15))
