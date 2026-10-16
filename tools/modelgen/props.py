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
    'rust_ribs': dict(ramp='rust', base=7, grain=0.25, pattern='ribs'),
    'grey_slats': dict(ramp='grey', base=8, grain=0.10, pattern='slats'),
    'paint_light': dict(ramp='stone', base=10, grain=0.10),
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
    'sack':      dict(ramp='stone', base=7, grain=0.30),
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


def _slats(rng, I, J, w, h, P):
    """a roller shutter: horizontal slats 0.1 m high, a light top edge and a dark gap each."""
    _, _, normal = _face_axes(P)
    if normal == 1:
        return 0.0
    phase = (P[..., 1] / 0.1) % 1.0
    return 1.0 * (phase > 0.8) - 2.0 * (phase < 0.12)


paint.PATTERNS.update(planks=_planks, ribs=_ribs, blotches=_blotches, leaves=_leaves, tread=_tread, slats=_slats)


# ---------------------------------------------------------------- lettering for signs
# Bold 6 x 7 stencil glyphs, one string per row, '#' = ink: strokes two pixels wide, so letters
# stay readable at Chiip's 480 lines from across a room.
GLYPHS = {
    'A': ['.####.', '##..##', '##..##', '######', '##..##', '##..##', '##..##'],
    'B': ['#####.', '##..##', '##..##', '#####.', '##..##', '##..##', '#####.'],
    'C': ['.#####', '##....', '##....', '##....', '##....', '##....', '.#####'],
    'E': ['######', '##....', '##....', '#####.', '##....', '##....', '######'],
    'I': ['######', '..##..', '..##..', '..##..', '..##..', '..##..', '######'],
    'N': ['##..##', '###.##', '######', '##.###', '##..##', '##..##', '##..##'],
    'O': ['.####.', '##..##', '##..##', '##..##', '##..##', '##..##', '.####.'],
    'T': ['######', '..##..', '..##..', '..##..', '..##..', '..##..', '..##..'],
    'X': ['##..##', '##..##', '.####.', '..##..', '.####.', '##..##', '##..##'],
    '1': ['..##..', '.###..', '..##..', '..##..', '..##..', '..##..', '.####.'],
    '2': ['.####.', '##..##', '....##', '...##.', '..##..', '.##...', '######'],
    '3': ['#####.', '....##', '....##', '.####.', '....##', '....##', '#####.'],
    '!': ['..##..', '..##..', '..##..', '..##..', '..##..', '......', '..##..'],
    '>': ['...#...', '...##..', '######.', '#######', '######.', '...##..', '...#...'],
    '<': ['...#...', '..##...', '.######', '#######', '.######', '..##...', '...#...'],
    ' ': ['....'] * 7,
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


def round_boxes(radius, height, y0=0.0, centre=(0.0, 0.0)):
    """collision for an upright round thing: two square boxes, one turned 45 degrees, which make
    an octagon that touches the circle at its corners (a single box would stick out 40 %)."""
    side = 2 * radius * math.cos(math.radians(22.5))
    c = (centre[0], y0 + height / 2, centre[1])
    return [(c, (side, height, side)), (c, (side, height, side), 45)]


def border(width, height, thickness, mat='sign_dark', side='-z'):
    """a decal: a frame `thickness` wide around a sign plate of width x height (centred)."""
    def test(x, y, z, face):
        return face == side and (abs(x) > width / 2 - thickness or abs(y) > height / 2 - thickness)
    return test, mat


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
    'doors': (0.6, 0.55, 0.5), 'lights': (1.0, 0.8, 0.4),
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


@prop('barrel', 'industrial', 'Olive steel drum, 0.9 m: low cover.', surface='metal', collide=round_boxes(0.3, 0.9))
def barrel():
    return _barrel('olive')


@prop('barrel_rust', 'industrial', 'Rusty steel drum, 0.9 m: low cover.', surface='metal', collide=round_boxes(0.3, 0.9))
def barrel_rust():
    return _barrel('rust', 'rust')


@prop('barrel_hazard', 'industrial', 'Yellow drum with a black band, 0.9 m: low cover.', surface='metal',
      collide=round_boxes(0.3, 0.9))
def barrel_hazard():
    P = _barrel('safety', 'metal_dk', 'black')
    P.append(cyl(0.292, 0.16, (0, 0.36, 0), 'black', sides=12))
    return P


@prop('barrel_group', 'industrial', 'Three drums in a cluster, about 1.2 m across: low cover.', surface='metal',
      collide=[((0, 0.45, 0), (1.25, 0.9, 1.15))])
def barrel_group():
    return (moved(_barrel('olive'), (-0.31, 0, 0.2)) + moved(_barrel('rust', 'rust'), (0.32, 0, 0.18), 40)
            + moved(_barrel('olive_dk'), (0.0, 0, -0.33), 15))


# ================================================================ industrial
def _container(ribs):
    """a 20-foot shipping container, 6.06 x 2.59 x 2.44 m, along x; the doors at the +x end."""
    L, H, D = 6.06, 2.59, 2.44
    frame = 'metal_dk'
    P = [box((L - 0.1, H - 0.14, D - 0.08), (0, H / 2, 0), ribs, bevel=0)]
    for x in (-1, 1):
        for z in (-1, 1):
            P.append(box((0.14, H, 0.14), (x * (L / 2 - 0.07), H / 2, z * (D / 2 - 0.07)), frame, bevel=0.01))
    for y, t in ((H - 0.05, 0.1), (0.075, 0.15)):
        for z in (-1, 1):
            P.append(box((L - 0.28, t, 0.12), (0, y, z * (D / 2 - 0.06)), frame, bevel=0))
        for x in (-1, 1):
            P.append(box((0.12, t, D - 0.28), (x * (L / 2 - 0.06), y, 0), frame, bevel=0))
    for z in (-1, 1):                                                            # the two door leaves
        P.append(box((0.03, H - 0.3, D / 2 - 0.16), (L / 2 - 0.02, H / 2, z * (D / 4 - 0.02)), ribs, bevel=0))
    for z in (-0.88, -0.3, 0.3, 0.88):                                           # locking bars and handles
        P.append(cyl(0.025, H - 0.4, (L / 2 + 0.02, 0.2, z), 'metal', sides=6))
        P.append(box((0.05, 0.05, 0.16), (L / 2 + 0.04, 1.15, z + 0.06), 'metal', bevel=0))
    return P


@prop('container_olive', 'industrial', 'Olive 20-foot shipping container, 6.1 x 2.6 x 2.4 m, doors at one end: tall cover.',
      surface='metal')
def container_olive():
    return _container('olive_ribs')


@prop('container_teal', 'industrial', 'Grey-green 20-foot shipping container, 6.1 x 2.6 x 2.4 m: tall cover.', surface='metal')
def container_teal():
    return _container('teal_ribs')


@prop('container_rust', 'industrial', 'Rusty 20-foot shipping container, 6.1 x 2.6 x 2.4 m: tall cover.', surface='metal')
def container_rust():
    return _container('rust_ribs')


@prop('container_grey', 'industrial', 'Grey 20-foot shipping container, 6.1 x 2.6 x 2.4 m: tall cover.', surface='metal')
def container_grey():
    return _container('grey_ribs')


@prop('tank', 'industrial', 'Upright storage tank, 2.2 m across and 3.7 m tall, on a concrete pad: tall cover.',
      surface='metal', collide=round_boxes(1.1, 3.7))
def tank():
    P = [cyl(1.2, 0.3, (0, 0, 0), 'concrete', sides=12),
         cyl(1.1, 3.0, (0, 0.3, 0), 'paint_light', sides=16),
         cyl(1.1, 0.4, (0, 3.3, 0), 'paint_light', radius_end=0.35, sides=16),
         cyl(0.3, 0.12, (0, 3.68, 0), 'metal_dk', sides=8)]
    for y in (1.3, 2.4):
        P.append(cyl(1.118, 0.06, (0, y, 0), 'metal', sides=16))
    P.append(cyl(0.12, 0.45, (0, 0.65, -1.05), 'metal', axis='-z', sides=8))            # outlet
    P.append(cyl(0.17, 0.05, (0, 0.65, -1.45), 'metal_dk', axis='-z', sides=8))         # flange
    P.append(box((0.5, 0.3, 0.02), (0.5, 1.8, -1.03), 'sign_yellow', bevel=0, rot=(0, -25, 0),
                 decals=[lettering('!', (0, 0), 0.22)]))
    return P


@prop('pipe_floor', 'industrial', 'Big pipe on two concrete saddles, 4 m long and 1.1 m high: low cover.',
      surface='metal', collide=[((0, 0.55, 0), (4.1, 1.1, 0.95))])
def pipe_floor():
    P = [cyl(0.45, 4.0, (-2.0, 0.64, 0), 'metal', axis='+x', sides=12)]
    for x in (-2.0, -0.05, 1.95):
        P.append(cyl(0.5, 0.1, (x, 0.64, 0), 'metal_dk', axis='+x', sides=12))
    for x in (-1.3, 1.3):
        P.append(box((0.4, 0.42, 0.95), (x, 0.21, 0), 'concrete', bevel=0.02))
    return P


@prop('pipe_wall', 'industrial', 'Two pipes on brackets along a wall at 2.5-2.8 m, 3 m long. Origin on the wall face, at the floor. Decoration: no collision.',
      surface='metal', collide='none')
def pipe_wall():
    P = [cyl(0.12, 3.0, (-1.5, 2.5, -0.18), 'metal', axis='+x', sides=8),
         cyl(0.08, 3.0, (-1.5, 2.82, -0.14), 'olive', axis='+x', sides=8)]
    for x in (-1.1, 1.1):
        P.append(box((0.06, 0.5, 0.3), (x, 2.62, -0.15), 'metal_dk', bevel=0))
    return P


@prop('pipe_valve', 'industrial', 'Upright pipe with a flange and a valve wheel, 2.6 m, standing against a wall (origin on the wall face, at the floor).',
      surface='metal', collide=[((0, 1.3, -0.22), (0.36, 2.6, 0.44))])
def pipe_valve():
    P = [cyl(0.12, 2.6, (0, 0, -0.2), 'metal', sides=8),
         cyl(0.18, 0.08, (0, 1.0, -0.2), 'metal_dk', sides=8),
         box((0.3, 0.28, 0.3), (0, 1.25, -0.2), 'metal_dk', bevel=0.02),
         cyl(0.03, 0.22, (0, 1.25, -0.35), 'metal', axis='-z', sides=6),
         cyl(0.2, 0.03, (0, 1.25, -0.57), 'safety', axis='-z', sides=10),
         box((0.36, 0.03, 0.03), (0, 1.25, -0.585), 'safety', bevel=0),
         box((0.03, 0.36, 0.03), (0, 1.25, -0.585), 'safety', bevel=0)]
    for y in (0.3, 2.3):
        P.append(box((0.32, 0.06, 0.2), (0, y, -0.1), 'metal_dk', bevel=0))
    return P


@prop('generator', 'industrial', 'Diesel generator on a skid, 1.8 x 1.15 x 1.0 m, with an exhaust stack: low cover.',
      surface='metal', collide=[((0, 0.58, 0), (1.9, 1.15, 1.05))])
def generator():
    louvres = (lambda x, y, z, f: f in ('+x', '-x') and abs(z) < 0.3 and (y * 20) % 1.0 < 0.45 and abs(y) < 0.3, 'black')
    P = [box((1.9, 0.15, 1.05), (0, 0.075, 0), 'metal_dk', bevel=0.01),
         box((1.8, 1.0, 0.95), (0, 0.65, 0), 'safety', bevel=0.03, decals=[louvres]),
         box((0.5, 0.4, 0.04), (-0.45, 0.75, -0.49), 'metal_dk', bevel=0.01),
         box((0.12, 0.08, 0.02), (-0.55, 0.85, -0.515), 'glass', bevel=0),
         box((0.12, 0.08, 0.02), (-0.35, 0.85, -0.515), 'glass', bevel=0),
         cyl(0.06, 0.5, (0.6, 1.15, 0.2), 'metal_dk', sides=8),
         cyl(0.075, 0.05, (0.6, 1.62, 0.2), 'black', sides=8)]
    return P


@prop('ac_unit', 'industrial', 'Air-conditioning condenser, 1.0 x 0.9 x 0.7 m, with a fan grille: low clutter.', surface='metal')
def ac_unit():
    vents = (lambda x, y, z, f: f in ('+x', '-x', '+z') and (y * 16) % 1.0 < 0.4 and abs(y) < 0.35, 'metal_dk')
    P = [box((1.0, 0.82, 0.7), (0, 0.47, 0), 'paint_light', bevel=0.02, decals=[vents]),
         cyl(0.33, 0.02, (0, 0.47, -0.35), 'black', axis='-z', sides=12),
         box((0.66, 0.03, 0.02), (0, 0.47, -0.37), 'metal_dk', bevel=0),
         box((0.03, 0.66, 0.02), (0, 0.47, -0.37), 'metal_dk', bevel=0)]
    for x in (-0.42, 0.42):
        P.append(box((0.08, 0.06, 0.66), (x, 0.03, 0), 'metal_dk', bevel=0))
    P.append(cyl(0.025, 0.4, (0.4, 0.3, 0.35), 'metal', axis='+z', sides=6))
    return P


@prop('electric_cabinet', 'industrial', 'Floor-standing electrical cabinet, 1.0 x 2.2 x 0.45 m, with a warning plate: tall cover.',
      surface='metal', density=64)
def electric_cabinet():
    P = [box((1.04, 0.1, 0.49), (0, 0.05, 0), 'concrete_dk', bevel=0.01),
         box((1.0, 2.1, 0.45), (0, 1.15, 0), 'paint_grey', bevel=0.02),
         box((0.012, 1.9, 0.01), (0, 1.15, -0.226), 'black', bevel=0),
         box((0.3, 0.3, 0.01), (-0.25, 1.6, -0.228), 'sign_yellow', bevel=0,
             decals=[lettering('!', (0, 0), 0.22), border(0.3, 0.3, 0.02)])]
    for x in (-0.08, 0.08):
        P.append(box((0.03, 0.14, 0.03), (x, 1.1, -0.24), 'metal', bevel=0))
    for x in (-0.3, 0.3):
        P.append(box((0.3, 0.12, 0.01), (x, 0.4, -0.228), 'metal_dk', bevel=0))
    return P


@prop('cable_spool', 'industrial', 'Wooden cable drum on its side, 1.2 m tall: low cover.', surface='wood')
def cable_spool():
    P = [cyl(0.6, 0.07, (0, 0.6, -0.45), 'wood', axis='+z', sides=12),
         cyl(0.6, 0.07, (0, 0.6, 0.38), 'wood', axis='+z', sides=12),
         cyl(0.46, 0.76, (0, 0.6, -0.38), 'black', axis='+z', sides=12),
         cyl(0.08, 0.92, (0, 0.6, -0.46), 'metal_dk', axis='+z', sides=6)]
    return P


@prop('gas_cylinders', 'industrial', 'Three gas cylinders chained in a steel stand, 1.0 x 1.55 x 0.45 m.', surface='metal')
def gas_cylinders():
    P = [box((1.0, 0.05, 0.45), (0, 0.025, 0), 'metal_dk', bevel=0)]
    for i, (x, mat) in enumerate(((-0.3, 'olive'), (0, 'paint_grey'), (0.3, 'olive'))):
        P.append(cyl(0.12, 1.3, (x, 0.05, 0), mat, sides=10))
        P.append(ell((0.12, 0.1, 0.12), (x, 1.35, 0), mat, sides=10, rings=4))
        P.append(cyl(0.035, 0.12, (x, 1.42, 0), 'brass', sides=6))
    for x in (-0.5, 0.5):
        P.append(box((0.04, 1.2, 0.04), (x, 0.6, 0.18), 'metal_dk', bevel=0))
    P.append(box((1.04, 0.04, 0.04), (0, 1.0, -0.14), 'metal_dk', bevel=0))
    P.append(box((1.04, 0.04, 0.04), (0, 1.0, 0.18), 'metal_dk', bevel=0))
    return P


# ================================================================ barriers
@prop('sandbags', 'barriers', 'A wall of sandbags, 1.8 x 0.85 x 0.45 m: low cover.', surface='gravel')
def sandbags():
    P = []
    for row in range(4):
        y = 0.105 + row * 0.205
        count = 4 if row % 2 == 0 else 3
        for i in range(count):
            x = (i - (count - 1) / 2) * 0.44
            P.append(box((0.46, 0.2, 0.42 - row * 0.03), (x, y, 0.0), 'sack', bevel=0.07,
                         rot=(0, (i * 7 + row * 5) % 9 - 4, (i + row) % 3 - 1)))
    return P


@prop('barrier_concrete', 'barriers', 'Concrete road barrier (Jersey barrier), 2 x 0.85 x 0.6 m: low cover.', surface='hard')
def barrier_concrete():
    slots = (lambda x, y, z, f: f in ('+z', '-z') and abs(abs(x) - 0.5) < 0.12 and y < -0.02, 'black')
    P = [box((2.0, 0.1, 0.6), (0, 0.05, 0), 'concrete', bevel=0.01, decals=[slots]),
         box((2.0, 0.85, 0.22), (0, 0.425, 0), 'concrete', bevel=0.03)]
    for z in (-1, 1):
        P.append(box((2.0, 0.42, 0.1), (0, 0.27, z * 0.15), 'concrete', bevel=0.02, rot=(-z * 35, 0, 0)))
    return P


def _railing(mat):
    P = []
    for x in (-0.97, 0.0, 0.97):
        P.append(cyl(0.03, 1.05, (x, 0, 0), mat, sides=6))
    for y in (1.05, 0.55):
        P.append(cyl(0.03, 2.0, (-1.0, y, 0), mat, axis='+x', sides=6))
    P.append(box((2.0, 0.1, 0.02), (0, 0.06, 0), mat, bevel=0))
    return P


@prop('railing', 'barriers', 'Steel railing, 2 m long and 1.05 m high. See-through: it stops you, not bullets or sight.',
      surface='metal', collide=[((0, 0.53, 0), (2.06, 1.06, 0.1))], layer='seethrough')
def railing():
    return _railing('steel')


@prop('railing_yellow', 'barriers', 'Yellow safety railing, 2 m long and 1.05 m high. See-through: it stops you, not bullets or sight.',
      surface='metal', collide=[((0, 0.53, 0), (2.06, 1.06, 0.1))], layer='seethrough')
def railing_yellow():
    return _railing('safety')


@prop('fence_wood', 'barriers', 'Wooden rail fence, 2 m long and 1.2 m high. See-through: it stops you, not bullets or sight.',
      surface='wood', collide=[((0, 0.6, 0), (2.06, 1.2, 0.16))], layer='seethrough')
def fence_wood():
    P = []
    for x in (-0.95, 0.95):
        P.append(box((0.1, 1.2, 0.1), (x, 0.6, 0), 'wood_dk', bevel=0.01))
    for y in (0.3, 0.65, 1.0):
        P.append(box((2.0, 0.12, 0.03), (0, y, -0.065), 'wood', bevel=0))
    return P


@prop('fence_boards', 'barriers', 'Solid board fence, 2 m long and 2.2 m high: tall cover.', surface='wood',
      collide=[((0, 1.1, 0.02), (2.0, 2.2, 0.12))])
def fence_boards():
    P = []
    for i in range(13):
        x = -0.92 + i * 0.1533
        h = 2.2 - 0.05 * (i % 3 == 1)
        P.append(box((0.145, h, 0.025), (x, h / 2, -0.02), 'wood_lt' if i % 4 else 'wood', bevel=0))
    for y in (0.35, 1.85):
        P.append(box((2.0, 0.1, 0.04), (0, y, 0.015), 'wood_dk', bevel=0))
    for x in (-1, 1):
        P.append(box((0.1, 2.2, 0.1), (x * 0.95, 1.1, 0.05), 'wood_dk', bevel=0.01))
    return P


@prop('barrier_road', 'barriers', 'Striped road barrier on folding legs, 1.6 x 1.0 m. See-through: it stops you, not bullets or sight.',
      surface='wood', collide=[((0, 0.5, 0), (1.6, 1.0, 0.5))], layer='seethrough')
def barrier_road():
    P = []
    for y in (0.88, 0.5):
        P.append(box((1.6, 0.2, 0.03), (0, y, 0), 'safety', bevel=0, decals=[stripes(0.2, 'black')]))
    for x in (-0.68, 0.68):
        for z in (-1, 1):
            P.append(box((0.05, 1.0, 0.05), (x, 0.49, z * 0.1), 'metal_dk', bevel=0, rot=(z * 12, 0, 0)))
    return P


@prop('tire_stack', 'barriers', 'Three old tyres stacked, 0.75 m: low clutter you jump onto.', surface='hard',
      collide=round_boxes(0.36, 0.75))
def tire_stack():
    P = []
    for i in range(3):
        P.append(cyl(0.36, 0.24, (0.02 * (i % 2), i * 0.25, -0.02 * (i == 1)), 'tire', sides=12))
    P.append(cyl(0.19, 0.012, (0.02 * 0, 0.742, 0), 'black', sides=10))
    return P


# ================================================================ doors and windows (wall props: the origin is on the wall face)
def _door_frame(w, h, mat='metal_dk'):
    return [box((0.08, h, 0.1), (-w / 2 - 0.04, h / 2, -0.05), mat, bevel=0),
            box((0.08, h, 0.1), (w / 2 + 0.04, h / 2, -0.05), mat, bevel=0),
            box((w + 0.16, 0.08, 0.1), (0, h + 0.04, -0.05), mat, bevel=0)]


def _door(panel_mat):
    P = _door_frame(1.0, 2.1)
    P.append(box((1.0, 2.1, 0.05), (0, 1.05, -0.035), panel_mat, bevel=0.005))
    for y in (0.55, 1.5):
        P.append(box((0.72, 0.75 if y > 1 else 0.6, 0.012), (0, y, -0.066), panel_mat, bevel=0))
    P.append(box((0.9, 0.18, 0.006), (0, 0.12, -0.062), 'metal', bevel=0))
    P.append(cyl(0.02, 0.06, (0.38, 1.0, -0.06), 'metal', axis='-z', sides=6))
    P.append(box((0.13, 0.025, 0.025), (0.33, 1.0, -0.12), 'metal', bevel=0))
    return P


@prop('door', 'doors', 'Grey steel door in its frame, 1.2 x 2.2 m, for a wall (origin on the wall face, at the floor). Does not open.',
      surface='metal', collide=[((0, 1.1, -0.05), (1.16, 2.2, 0.1))])
def door():
    return _door('paint_grey')


@prop('door_wood', 'doors', 'Wooden door in its frame, 1.2 x 2.2 m, for a wall (origin on the wall face, at the floor). Does not open.',
      surface='wood', collide=[((0, 1.1, -0.05), (1.16, 2.2, 0.1))])
def door_wood():
    return _door('wood')


@prop('door_double', 'doors', 'Double steel doors with push bars and small windows, 2.2 x 2.5 m, for a wall (origin on the wall face, at the floor). Do not open.',
      surface='metal', collide=[((0, 1.25, -0.05), (2.16, 2.5, 0.1))])
def door_double():
    P = _door_frame(2.0, 2.4)
    for x in (-0.5, 0.5):
        P.append(box((0.98, 2.4, 0.05), (x, 1.2, -0.035), 'teal', bevel=0.005))
        P.append(box((0.3, 0.4, 0.01), (x, 1.75, -0.063), 'glass', bevel=0))
        P.append(box((0.7, 0.05, 0.05), (x, 1.0, -0.1), 'metal', bevel=0))
        for bx in (x - 0.3, x + 0.3):
            P.append(box((0.04, 0.08, 0.06), (bx, 1.0, -0.075), 'metal_dk', bevel=0))
    return P


@prop('door_rollup', 'doors', 'Roller shutter door, 3.3 x 3.45 m, for a wall (origin on the wall face, at the floor). Does not open.',
      surface='metal')
def door_rollup():
    P = [box((3.0, 3.0, 0.06), (0, 1.5, -0.08), 'grey_slats', bevel=0),
         box((3.3, 0.45, 0.42), (0, 3.22, -0.21), 'metal_dk', bevel=0.02),
         box((3.0, 0.08, 0.1), (0, 0.04, -0.1), 'metal_dk', bevel=0),
         box((0.2, 0.05, 0.05), (0, 0.4, -0.13), 'metal', bevel=0)]
    for x in (-1, 1):
        P.append(box((0.14, 3.0, 0.16), (x * 1.57, 1.5, -0.08), 'metal_dk', bevel=0))
    return P


def _window():
    P = [box((1.2, 0.07, 0.08), (0, 0.615, -0.04), 'paint_light', bevel=0),
         box((1.2, 0.07, 0.08), (0, -0.615, -0.04), 'paint_light', bevel=0),
         box((0.07, 1.16, 0.08), (-0.565, 0, -0.04), 'paint_light', bevel=0),
         box((0.07, 1.16, 0.08), (0.565, 0, -0.04), 'paint_light', bevel=0),
         box((1.06, 0.05, 0.05), (0, 0.1, -0.05), 'paint_light', bevel=0),
         box((0.05, 1.16, 0.05), (0, 0, -0.05), 'paint_light', bevel=0),
         box((1.1, 1.18, 0.02), (0, 0, -0.025), 'glass', bevel=0),
         box((1.36, 0.06, 0.2), (0, -0.68, -0.1), 'concrete', bevel=0.01)]
    return P


@prop('window', 'doors', 'Window with a white frame and dark glass, 1.2 x 1.3 m, for a wall (origin on the wall face, at the middle of the window). Decoration: no collision.',
      surface='hard', collide='none')
def window():
    return _window()


@prop('window_shutters', 'doors', 'Window with open wooden shutters, 2.4 x 1.3 m, for old-town walls (origin on the wall face, at the middle of the window). Decoration: no collision.',
      surface='wood', collide='none')
def window_shutters():
    P = _window()
    for x in (-1, 1):
        P.append(box((0.56, 1.24, 0.03), (x * 0.92, 0, -0.04), 'planks_dk', bevel=0))
        for y in (-0.4, 0.4):
            P.append(box((0.08, 0.03, 0.02), (x * 0.66, y, -0.06), 'metal_dk', bevel=0))
    return P


# ================================================================ vehicles (the nose faces -Z)
def _car(body, glass, wheels=True, drop=0.0):
    """a boxy compact car, 4.2 x 1.45 x 1.75 m."""
    win = (lambda x, y, z, f: (f in ('+x', '-x') and y > -0.2 and abs(z) < 0.88 and abs(z - 0.12) > 0.05)
           or (f in ('+z', '-z') and y > -0.2 and abs(x) < 0.72), glass)
    lift = 0.28 - drop
    P = [box((1.75, 0.62, 4.2), (0, lift + 0.31, 0), body, bevel=0.06),
         box((1.6, 0.55, 2.1), (0, lift + 0.62 + 0.27, 0.25), body, bevel=0.07, decals=[win]),
         box((1.82, 0.14, 0.14), (0, lift + 0.12, -2.08), 'black', bevel=0.02),
         box((1.82, 0.14, 0.14), (0, lift + 0.12, 2.08), 'black', bevel=0.02),
         box((0.7, 0.14, 0.02), (0, lift + 0.4, -2.105), 'black', bevel=0)]
    for x in (-0.6, 0.6):
        P.append(box((0.32, 0.12, 0.02), (x, lift + 0.42, -2.105), 'paint_white' if wheels else 'black', bevel=0))
        P.append(box((0.3, 0.1, 0.02), (x, lift + 0.42, 2.105), 'safety' if wheels else 'black', bevel=0))
    for z in (-1.35, 1.35):
        for x in (-1, 1):
            if wheels:
                P.append(cyl(0.32, 0.22, (x * 0.92 - (0.22 if x > 0 else 0), 0.32, z), 'tire', axis='+x', sides=10))
                P.append(cyl(0.15, 0.02, (x * 0.93 - (0.02 if x > 0 else 0), 0.32, z), 'metal', axis='+x', sides=8))
            else:
                P.append(cyl(0.18, 0.12, (x * 0.86 - (0.12 if x > 0 else 0), 0.18, z), 'rust', axis='+x', sides=8))
    return P


@prop('car', 'vehicles', 'Grey compact car, 4.2 x 1.45 x 1.75 m, nose to the front: low cover you can shoot over.', surface='metal',
      collide=[((0, 0.6, 0), (1.75, 1.2, 4.2)), ((0, 1.17, 0.25), (1.6, 0.55, 2.1))])
def car():
    return _car('paint_grey', 'glass')


@prop('car_wreck', 'vehicles', 'Burnt-out car on its rims, rusty and without glass, 4.2 x 1.3 x 1.75 m: low cover.', surface='metal',
      collide=[((0, 0.45, 0), (1.75, 0.9, 4.2)), ((0, 1.02, 0.25), (1.6, 0.55, 2.1))])
def car_wreck():
    return moved(_car('rust', 'black', wheels=False, drop=0.15), (0, 0, 0), 4)


@prop('van', 'vehicles', 'Light grey panel van, 5 x 2.2 x 2 m, nose to the front: tall cover.', surface='metal',
      collide=[((0, 1.25, 0.5), (2.0, 2.2, 3.9)), ((0, 0.8, -1.95), (2.0, 1.2, 1.1))])
def van():
    win = (lambda x, y, z, f: y > 0.35 and ((f == '-z' and abs(x) < 0.85) or (f in ('+x', '-x') and z < -1.25)), 'glass')
    P = [box((2.0, 1.9, 3.9), (0, 0.35 + 0.95, 0.5), 'paint_light', bevel=0.06, decals=[win]),
         box((2.0, 1.0, 1.1), (0, 0.35 + 0.5, -1.95), 'paint_light', bevel=0.08),
         box((2.06, 0.16, 0.14), (0, 0.42, -2.52), 'black', bevel=0.02),
         box((2.06, 0.16, 0.14), (0, 0.42, 2.48), 'black', bevel=0.02),
         box((0.9, 0.2, 0.02), (0, 0.85, -2.505), 'black', bevel=0),
         box((0.012, 1.4, 0.01), (0, 1.15, 2.452), 'black', bevel=0)]
    for x in (-0.7, 0.7):
        P.append(box((0.3, 0.14, 0.02), (x, 0.95, -2.505), 'paint_white', bevel=0))
        P.append(box((0.22, 0.12, 0.02), (x, 0.9, 2.452), 'safety', bevel=0))
    for z in (-1.6, 1.55):
        for x in (-1, 1):
            P.append(cyl(0.38, 0.25, (x * 1.02 - (0.25 if x > 0 else 0), 0.38, z), 'tire', axis='+x', sides=10))
            P.append(cyl(0.17, 0.02, (x * 1.03 - (0.02 if x > 0 else 0), 0.38, z), 'metal', axis='+x', sides=8))
    return P


@prop('forklift', 'vehicles', 'Yellow forklift, 3.0 x 2.2 x 1.2 m, forks to the front.', surface='metal',
      collide=[((0, 0.62, 0.35), (1.2, 1.25, 2.3)), ((0, 1.1, -0.92), (1.0, 2.2, 0.3))])
def forklift():
    P = [box((1.15, 0.85, 1.9), (0, 0.25 + 0.425, 0.25), 'safety', bevel=0.04),
         box((1.15, 0.75, 0.4), (0, 0.65, 1.35), 'metal_dk', bevel=0.04),
         box((0.5, 0.12, 0.45), (0, 1.16, 0.55), 'black', bevel=0.02),
         box((0.5, 0.45, 0.1), (0, 1.4, 0.8), 'black', bevel=0.02),
         cyl(0.16, 0.03, (0, 1.4, -0.05), 'black', axis='+y', sides=8, rot=(-30, 0, 0)),
         box((1.1, 0.06, 1.45), (0, 2.15, 0.2), 'metal_dk', bevel=0),
         box((0.92, 0.5, 0.08), (0, 0.38, -1.0), 'metal_dk', bevel=0)]
    for x in (-0.5, 0.5):
        for z in (-0.45, 0.85):
            P.append(box((0.06, 1.0, 0.06), (x, 1.65, z), 'metal_dk', bevel=0))
    for x in (-0.36, 0.36):
        P.append(box((0.1, 2.15, 0.12), (x, 1.12, -0.9), 'metal_dk', bevel=0))
    for x in (-0.3, 0.3):
        P.append(box((0.12, 0.05, 1.1), (x, 0.08, -1.55), 'metal', bevel=0))
    for z, r in ((-0.45, 0.3), (1.0, 0.25)):
        for x in (-1, 1):
            P.append(cyl(r, 0.22, (x * 0.6 - (0.22 if x > 0 else 0), r, z), 'tire', axis='+x', sides=10))
    return P


# ================================================================ signs (wall props: the origin is on the wall face, at the middle)
def _sign(w, h, text, plate='sign', ink='sign_dark', text_height=None):
    th = text_height or h * 0.62
    return [box((w, h, 0.03), (0, 0, -0.015), plate, bevel=0, decals=[lettering(text, (0, 0), th, mat=ink),
                                                                     border(w, h, min(w, h) * 0.05, ink)])]


def _sign_prop(name, w, h, text, description, plate='sign', ink='sign_dark', text_height=None):
    @prop(name, 'signs', description + ' For a wall: the origin is on the wall face, at the middle of the sign. No collision.',
          surface='metal', collide='none', density=96)
    def build():
        return _sign(w, h, text, plate, ink, text_height)
    return build


_sign_prop('sign_a', 0.7, 0.7, 'A', 'Bomb site A sign, 0.7 m square.')
_sign_prop('sign_b', 0.7, 0.7, 'B', 'Bomb site B sign, 0.7 m square.')
_sign_prop('sign_a_left', 1.1, 0.5, '< A', 'Sign pointing left to bomb site A, 1.1 x 0.5 m.', text_height=0.3)
_sign_prop('sign_a_right', 1.1, 0.5, 'A >', 'Sign pointing right to bomb site A, 1.1 x 0.5 m.', text_height=0.3)
_sign_prop('sign_b_left', 1.1, 0.5, '< B', 'Sign pointing left to bomb site B, 1.1 x 0.5 m.', text_height=0.3)
_sign_prop('sign_b_right', 1.1, 0.5, 'B >', 'Sign pointing right to bomb site B, 1.1 x 0.5 m.', text_height=0.3)
_sign_prop('sign_arrow_left', 0.6, 0.35, '<', 'Arrow sign pointing left, 0.6 x 0.35 m.', text_height=0.24)
_sign_prop('sign_arrow_right', 0.6, 0.35, '>', 'Arrow sign pointing right, 0.6 x 0.35 m.', text_height=0.24)
_sign_prop('sign_warning', 0.5, 0.5, '!', 'Yellow warning sign, 0.5 m square.', plate='sign_yellow', text_height=0.34)
_sign_prop('sign_exit', 0.9, 0.36, 'EXIT', 'Green exit sign, 0.9 x 0.36 m.', plate='sign_green', ink='sign', text_height=0.22)
