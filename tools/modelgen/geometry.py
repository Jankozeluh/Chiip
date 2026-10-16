"""
geometry.py - low-poly pieces for Chiip's model generator (D-054).

A model is a list of Pieces. Each piece is one simple shape fixed to one bone, like the
segmented models of late-90s shooters:
  box   a box with bevelled (chamfered) edges           size = full extents (x, y, z)
  cyl   a tapered cylinder with caps                    size = (radius at start, radius at end, length)
  ell   a low-res ellipsoid                             size = radii (x, y, z)
  dome  an ellipsoid with everything below a plane      size = radii; clip = (normal, offset)
        pressed flat onto it (helmets, hoods, caps)

Coordinates follow Godot: metres, +Y up, the character faces -Z, its right is +X.

UVs: every piece gets its own six rectangles in the texture atlas, one per side of its
bounding box, and each triangle is projected onto the side its normal points to most
(box projection). The painter (paint.py) walks those rectangles and knows, for every
texel, which point of the piece it shows, so patterns and decals can be placed in metres.
"""
import math

import numpy as np

# Atlas texels per metre of surface. A 1.8 m character is about 170 texels tall, so close
# up each texel covers a few screen pixels at Chiip's 480-line world (D-048): chunky pixels.
TEXEL_DENSITY = 96
ATLAS_WIDTH = 256
PADDING = 1

AXES = {'+x': (1, 0, 0), '-x': (-1, 0, 0), '+y': (0, 1, 0), '-y': (0, -1, 0), '+z': (0, 0, 1), '-z': (0, 0, -1)}
# box sides: outward normal axis and sign
FACES = [(0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)]
FACE_NAMES = ['+x', '-x', '+y', '-y', '+z', '-z']


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    """rotation matrix from degrees: yaw about +Y, then pitch about +X, then roll about +Z."""
    p, y, r = math.radians(pitch), math.radians(yaw), math.radians(roll)
    rx = np.array([[1, 0, 0], [0, math.cos(p), -math.sin(p)], [0, math.sin(p), math.cos(p)]])
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rz = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])
    return ry @ rx @ rz


def basis_from_y(direction):
    """a rotation that turns +Y into `direction` (used to point cylinders along an axis)."""
    d = np.asarray(direction, float)
    d = d / np.linalg.norm(d)
    ref = np.array([0, 0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0, 0])
    x = np.cross(d, ref)
    x /= np.linalg.norm(x)
    z = np.cross(x, d)
    return np.column_stack([x, d, z])


class Piece:
    """One low-poly shape fixed to one bone.

    bone   the bone it moves with
    shape  'box', 'cyl', 'ell' or 'dome' (see the module docstring)
    pos    where the shape's origin sits in the bone's frame (box/ell/dome: centre; cyl: start)
    rot    extra rotation in degrees (pitch, yaw, roll)
    axis   for 'cyl': the direction it runs from its start ('+x', '-y', ... or a vector)
    mat    material name (paint.py); 'team' parts are painted in the team colour at runtime
    zone   hit zone it belongs to ('head', 'chest', 'stomach', 'arms', 'legs') or None
    decals list of (test(x, y, z, side) -> bool, material): paint another material where the
           test holds, e.g. a helmet stripe. x, y, z are in the shape's own frame.
    tall   counts toward the class's height (the antenna and the gun don't)
    """

    def __init__(self, bone, shape, size, pos=(0, 0, 0), rot=(0, 0, 0), mat='top', zone=None,
                 bevel=0.0, sides=8, rings=6, axis='+y', clip=None, smooth=None, decals=(), tall=True,
                 pattern=None, name=''):
        self.bone, self.shape, self.size = bone, shape, tuple(float(v) for v in size)
        self.pos, self.rot, self.mat, self.zone = np.asarray(pos, float), rot, mat, zone
        self.bevel, self.sides, self.rings, self.axis, self.clip = bevel, sides, rings, axis, clip
        self.smooth = (shape != 'box') if smooth is None else smooth
        self.decals, self.tall, self.pattern, self.name = list(decals), tall, pattern, name

    def basis(self):
        """the shape's frame inside the bone's frame."""
        b = rot(*self.rot)
        if self.shape == 'cyl':
            b = b @ basis_from_y(AXES[self.axis] if isinstance(self.axis, str) else self.axis)
        return b


# ---------------------------------------------------------------- shapes (in the shape's own frame)
def _box(size, bevel):
    """returns a list of polygons, each (points, normal or None for flat)."""
    h = np.array(size) / 2.0
    b = min(bevel, *(h * 0.95)) if bevel > 0 else 0.0
    inner = h - b
    polys = []

    def corner(s, ax):
        p = np.array(s, float) * inner
        p[ax] = s[ax] * (inner[ax] + b)
        return p

    signs = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    for ax, sg in FACES:
        quad = [corner(s, ax) for s in signs if s[ax] == sg]
        polys.append(_order(quad))
    if b > 0:
        for ax in range(3):            # 12 edge strips
            a1, a2 = [k for k in range(3) if k != ax]
            for s1 in (-1, 1):
                for s2 in (-1, 1):
                    pts = []
                    for s0 in (-1, 1):
                        s = [0, 0, 0]
                        s[ax], s[a1], s[a2] = s0, s1, s2
                        pts += [corner(s, a1), corner(s, a2)]
                    polys.append(_order(pts))
        for s in signs:                # 8 corner triangles
            polys.append(_order([corner(s, 0), corner(s, 1), corner(s, 2)]))
    return [(p, None) for p in polys]


def _order(pts):
    """orders the points of a convex, planar polygon counter-clockwise seen from outside."""
    pts = [np.asarray(p, float) for p in pts]
    c = np.mean(pts, 0)
    n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
    if np.linalg.norm(n) < 1e-12:
        n = np.cross(pts[2] - pts[0], pts[3] - pts[0])
    if np.dot(n, c) < 0:
        n = -n
    n /= np.linalg.norm(n)
    u = pts[0] - c
    u /= np.linalg.norm(u)
    v = np.cross(n, u)
    return sorted(pts, key=lambda p: math.atan2(np.dot(p - c, v), np.dot(p - c, u)))


def _cyl(r1, r2, length, sides, smooth):
    polys = []
    ang = [2 * math.pi * (i + 0.5) / sides for i in range(sides)]
    ring = lambda r, y: [np.array([r * math.sin(a), y, r * math.cos(a)]) for a in ang]
    bottom, top = ring(r1, 0.0), ring(r2, length)
    slope = (r1 - r2) / max(length, 1e-6)
    for i in range(sides):
        j = (i + 1) % sides
        quad = [bottom[i], bottom[j], top[j], top[i]]
        if smooth:
            normals = []
            for k in (i, j, j, i):
                n = np.array([math.sin(ang[k]), slope, math.cos(ang[k])])
                normals.append(n / np.linalg.norm(n))
            polys.append((quad, normals))
        else:
            polys.append((quad, None))
    polys.append((bottom[::-1], None))
    polys.append((top, None))
    return polys


def _ell(radii, sides, rings, clip=None):
    rx, ry, rz = radii
    pts = []
    for r in range(rings + 1):
        lat = math.pi * r / rings          # 0 = top, pi = bottom
        row = []
        for i in range(sides):
            lon = 2 * math.pi * (i + 0.5) / sides
            row.append(np.array([rx * math.sin(lat) * math.sin(lon), ry * math.cos(lat),
                                 rz * math.sin(lat) * math.cos(lon)]))
        pts.append(row)
    normal_of = lambda p: (lambda n: n / max(np.linalg.norm(n), 1e-9))(np.array([p[0] / rx ** 2, p[1] / ry ** 2, p[2] / rz ** 2]))
    if clip is not None:
        n, h = np.asarray(clip[0], float), float(clip[1])
        n /= np.linalg.norm(n)
        for row in pts:
            for p in row:
                if np.dot(p, n) < h:
                    if abs(n[1]) > 0.9:         # a near-level cut (helmets): press the point up onto it
                        p[1] = (h - n[0] * p[0] - n[2] * p[2]) / n[1]
                    else:                       # a steep cut (a hood's face opening): along the normal
                        p += (h - np.dot(p, n)) * n
    polys = []
    for r in range(rings):
        for i in range(len(pts[r])):
            j = (i + 1) % len(pts[r])
            a, b, c, d = pts[r][i], pts[r][j], pts[r + 1][j], pts[r + 1][i]
            for tri in ([a, d, c], [a, c, b]):
                if np.linalg.norm(np.cross(tri[1] - tri[0], tri[2] - tri[0])) < 1e-10:
                    continue
                if clip is not None and all(abs(np.dot(p, n) - h) < 1e-6 for p in tri):
                    continue                    # flattened skirt: leave the underside open
                polys.append((tri, [normal_of(p) for p in tri]))
    return polys


def shape_polys(piece):
    s = piece.size
    if piece.shape == 'box':
        return _box(s, piece.bevel)
    if piece.shape == 'cyl':
        return _cyl(s[0], s[1], s[2], piece.sides, piece.smooth)
    if piece.shape in ('ell', 'dome'):
        return _ell(s, piece.sides, piece.rings, piece.clip if piece.shape == 'dome' else None)
    raise ValueError(piece.shape)


# ---------------------------------------------------------------- atlas
class Atlas:
    """packs rectangles into rows (shelves) of a texture ATLAS_WIDTH texels wide: call add()
    for every rectangle, then pack(), which places them tallest first."""

    def __init__(self, width=ATLAS_WIDTH):
        self.width = width
        self.sizes = []          # (w, h) as added
        self.rects = []          # (x, y, w, h) inner rectangles after pack(), padding around each
        self._used = 0

    def add(self, w, h):
        self.sizes.append((w, h))
        return len(self.sizes) - 1

    def pack(self):
        self.rects = [None] * len(self.sizes)
        x = y = row_h = 0
        for i in sorted(range(len(self.sizes)), key=lambda k: (-self.sizes[k][1], -self.sizes[k][0])):
            w, h = self.sizes[i]
            pw, ph = w + 2 * PADDING, h + 2 * PADDING
            if x + pw > self.width:
                x, y, row_h = 0, y + row_h, 0
            self.rects[i] = (x + PADDING, y + PADDING, w, h)
            x += pw
            row_h = max(row_h, ph)
        self._used = y + row_h

    def height(self):
        """the used height rounded up to a multiple of 32 (Godot doesn't need powers of two)."""
        return max(32, -(-self._used // 32) * 32)


def side_mapping(lo, hi, face):
    """for one side of the box (lo, hi): its size in metres along (u, v), and functions
    point -> (u, v) in 0..1 and (u, v) -> point. u runs to the viewer's right as seen from
    outside, v downward; side faces keep +Y up, the top and bottom keep the front (-Z) up."""
    ax, sg = FACES[face]
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    ext = np.maximum(hi - lo, 1e-6)
    # (axis used for u, u increases with that axis?), (axis for v, v increases with it?)
    table = {(0, 1): ((2, False), (1, False)), (0, -1): ((2, True), (1, False)),
             (1, 1): ((0, True), (2, True)), (1, -1): ((0, False), (2, True)),
             (2, 1): ((0, True), (1, False)), (2, -1): ((0, False), (1, False))}
    (ua, up), (va, vp) = table[(ax, sg)]

    def to_uv(p):
        u = (p[..., ua] - lo[ua]) / ext[ua]
        v = (p[..., va] - lo[va]) / ext[va]
        return np.stack([u if up else 1 - u, v if vp else 1 - v], -1)

    def to_point(u, v):
        p = np.zeros(np.broadcast(u, v).shape + (3,))
        p[..., ua] = lo[ua] + ext[ua] * (u if up else 1 - u)
        p[..., va] = lo[va] + ext[va] * (v if vp else 1 - v)
        p[..., ax] = hi[ax] if sg > 0 else lo[ax]
        return p

    return (ext[ua], ext[va]), to_uv, to_point


class PieceMesh:
    """a piece turned into triangles in its shape frame, with an atlas rectangle per side."""

    def __init__(self, piece, atlas, density=TEXEL_DENSITY):
        """density: atlas texels per metre (map props use fewer than the crew)."""
        self.piece = piece
        polys = shape_polys(piece)
        tris = []
        for pts, normals in polys:
            pts = [np.asarray(p, float) for p in pts]
            for k in range(1, len(pts) - 1):
                tri = [pts[0], pts[k], pts[k + 1]]
                fn = np.cross(tri[1] - tri[0], tri[2] - tri[0])
                if np.linalg.norm(fn) < 1e-12:
                    continue
                fn /= np.linalg.norm(fn)
                nrm = [fn] * 3 if normals is None else [normals[0], normals[k], normals[k + 1]]
                tris.append((tri, nrm, fn))
        allp = np.array([p for t in tris for p in t[0]])
        self.lo, self.hi = allp.min(0), allp.max(0)
        self.sides = []
        for f in range(6):
            (eu, ev), to_uv, to_point = side_mapping(self.lo, self.hi, f)
            w = max(1, int(math.ceil(eu * density - 0.25)))
            h = max(1, int(math.ceil(ev * density - 0.25)))
            self.sides.append(dict(rect=atlas.add(w, h), to_uv=to_uv, to_point=to_point, size=(w, h)))
        self.tris = tris

    def triangles(self, atlas):
        """yields (points (3,3), normals (3,3), atlas uv (3,2) in texels) in the shape frame."""
        for tri, nrm, fn in self.tris:
            ax = int(np.argmax(np.abs(fn)))
            face = ax * 2 + (0 if fn[ax] > 0 else 1)
            side = self.sides[face]
            x, y, w, h = atlas.rects[side['rect']]
            uv = side['to_uv'](np.array(tri))
            texel = np.column_stack([x + uv[:, 0] * w, y + uv[:, 1] * h])
            yield np.array(tri), np.array(nrm), texel
