#!/usr/bin/env python3
"""
spritegen.py - Chiip concept-art tool: renders Doom/Quake-style 8-direction sprite
turnarounds of the crew (docs/DECISIONS.md: D-051 sprites are concept art, D-053 the
crew and its team colours). M6 task 1.

Not part of the game. Chiip's characters are rigged 3D models built by the model
generator (M6 task 2); this tool is for agreeing on their looks before modelling.
Each class here is built from the same kind of pieces the generator uses (boxes,
tapered cylinders, spheres hung on a skeleton), so a sheet translates into a part list.

How it works: each class is built from signed-distance-field primitives hung on a
small skeleton (FK legs, 2-bone IK arms that grip the weapon), posed per animation
frame, ray-marched from 8 directions at 4x supersampling, then reduced to a
256-colour palette. The render stores material ids, so one render is coloured twice:
- every class wears a neutral kit (greys, olive-greys, charcoal; no desert tones, D-031),
- the team-colour parts (the TEAM slot: armbands, helmet stripe, scarf, ...) are painted
  blue for your team and red for the enemy (D-041, D-042), like the runtime shader (D-053).

Setup (once):  python3 -m venv ~/.venvs/chiip-tools
               ~/.venvs/chiip-tools/bin/pip install -r tools/concept/requirements.txt
Usage:         ~/.venvs/chiip-tools/bin/python tools/concept/spritegen.py --out <folder outside the project>
               ... --anims idle,aim          only these animations (faster; the sheets need idle and aim)
               ... --test rifleman aim 0     one frame, 8 directions, blue and red, plus a size/colour report
Output:        lineup.png (all classes, both teams, silhouettes, height lines),
               turnaround_<class>.png (8 directions, idle and aim, blue and red),
               <class>_<team>.png and _indexed.png sprite sheets (rows = frames, columns = 8
               directions, 96x96 cells, feet pivot at 48,88), sprites.json, palette files,
               and preview.html (open it in a browser to spin the turnarounds).
"""
import argparse
import base64
import io
import json
import math
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFont

f32 = np.float32
np.seterr(all="ignore")  # numpy 2.0 + macOS Accelerate raises spurious FP warnings in float32 matmul

# ---------------------------------------------------------------- render config
CELL = 96                 # sprite cell (px)
PIVOT = (48, 88)          # where the world origin (between the feet) lands in the cell
PPM = 34.0                # pixels per metre  (1.82 m ~ 62 px tall)
SS = 4                    # supersampling factor per axis
ALPHA_CUT = 6             # subsamples (of SS*SS) needed for an opaque pixel
EDGE_DARKEN = 2           # shades to darken silhouette pixels (0 = off)
CAM_PITCH = math.radians(8.0)
DIRS = 8
MAX_STEPS = 110
FOOT_H = 0.09             # ankle height above the ground (m)

# ---------------------------------------------------------------- palette
# Kit ramps are neutral or olive-grey on purpose: no tan, coyote or sand (D-031), and no
# blue or red tint, so the team colours are the only saturated colours on a character.
RAMP_ANCHORS = [
    ('grey',      ['#0a0a0b', '#2b2c2e', '#5b5d5f', '#97999a', '#dcdddb']),
    ('stone',     ['#0f1012', '#33363a', '#686d71', '#a7abae', '#e7e9e9']),
    ('olivegrey', ['#0b0c09', '#2d3027', '#5a5f4c', '#90957d', '#d2d5c2']),
    ('moss',      ['#080a07', '#1f261b', '#3f4a35', '#6d7a5c', '#b4bfa0']),
    ('charcoal',  ['#060607', '#1a1b1d', '#36383b', '#5f6266', '#a3a6a9']),
    ('ink',       ['#040405', '#111215', '#24262b', '#43464d', '#7c808a']),
    ('skin_l',    ['#190b0a', '#562c22', '#9a6145', '#d49c78', '#f9dcc0']),
    ('skin_d',    ['#0e0605', '#331a12', '#5c3422', '#8e5b3c', '#c9946e']),
    ('brown',     ['#0f0805', '#33200f', '#623f22', '#9a6c43', '#d6b185']),   # wood, hair
    ('gunmetal',  ['#06070a', '#1b1f26', '#39404a', '#6a7480', '#bac4ce']),
    ('brass',     ['#130b02', '#462f09', '#8a6517', '#d1a538', '#fff1a8']),
    ('glass',     ['#030607', '#0c1a1e', '#1f3a40', '#4b7480', '#b0d4dc']),
    # team ramps: the middle anchor is Teams.FRIENDLY_COLOR / Teams.ENEMY_COLOR (systems/teams.gd)
    ('team_blue', ['#060a1c', '#16275a', '#4066b3', '#7ea2e0', '#d0e2ff']),
    ('team_red',  ['#1a0504', '#4e130f', '#b8382e', '#e57a62', '#ffd2c2']),
    ('fb_warm',   ['#3c0c00', '#8e2b00', '#e26c00', '#ffc63f', '#fffce2']),   # fullbright
    ('fb_cool',   ['#00200f', '#005a22', '#12b142', '#72ff92', '#e8fff0']),   # fullbright
]
RAMPS = [n for n, _ in RAMP_ANCHORS]
RAMP_ID = {n: i for i, n in enumerate(RAMPS)}
TRANSPARENT = 255         # palette index reserved for "no pixel" (last entry of fb_cool)
FULLBRIGHT_FIRST = 224    # indices 224..254 are meant to ignore engine lighting


def _hex(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def lin_to_oklab(c):
    c = np.asarray(c, float)
    l = 0.4122214708 * c[..., 0] + 0.5363325363 * c[..., 1] + 0.0514459929 * c[..., 2]
    m = 0.2119034982 * c[..., 0] + 0.6806995451 * c[..., 1] + 0.1073969566 * c[..., 2]
    s = 0.0883024619 * c[..., 0] + 0.2817188376 * c[..., 1] + 0.6299787005 * c[..., 2]
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


def oklab_to_lin(c):
    L, a, b = c[..., 0], c[..., 1], c[..., 2]
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                     -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                     -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], -1)


def build_palette():
    pal = []
    for _, anchors in RAMP_ANCHORS:
        lab = lin_to_oklab(srgb_to_lin(np.array([_hex(h) for h in anchors])))
        xs = np.linspace(0, 1, len(anchors))
        for i in range(16):
            t = i / 15.0
            pal.append([np.interp(t, xs, lab[:, k]) for k in range(3)])
    srgb = lin_to_srgb(oklab_to_lin(np.array(pal)))
    return np.round(srgb * 255).astype(np.uint8)


PAL8 = build_palette()                         # (256, 3) sRGB bytes
PAL_LIN = srgb_to_lin(PAL8 / 255.0)
PAL_LAB = lin_to_oklab(PAL_LIN)

# ---------------------------------------------------------------- materials & teams
# slot: filled per class (kit) or per team (TEAM); ramp: fixed. lo/hi: ramp span used by shading.
# tex: strength of the pixel noise. Kept low: the look is minimalistic, colour comes in flat blocks.
MATERIALS = {
    'top':        dict(slot='TOP',    lo=1, hi=14, tex=0.06, freq=22),
    'bottom':     dict(slot='BOTTOM', lo=1, hi=13, tex=0.06, freq=22),
    'gear':       dict(slot='GEAR',   lo=1, hi=13, tex=0.05, freq=30),
    'gear_dk':    dict(slot='GEAR',   lo=0, hi=9,  tex=0.05, freq=30),
    'helm':       dict(slot='HELM',   lo=1, hi=14, tex=0.04, freq=30, spec=0.10),
    'team':       dict(slot='TEAM',   lo=2, hi=14, tex=0.04, freq=25),   # the team mask (D-053)
    'team_dk':    dict(slot='TEAM',   lo=1, hi=10, tex=0.04, freq=25),
    'skin':       dict(slot='SKIN',   lo=2, hi=15, tex=0.03, freq=30, spec=0.08),
    'boot':       dict(ramp='charcoal', lo=0, hi=9, tex=0.04, freq=40, spec=0.10),
    'eye':        dict(ramp='grey',   lo=0, hi=2),
    'hair':       dict(ramp='brown',  lo=0, hi=6, tex=0.2, freq=70),
    'mask':       dict(ramp='ink',    lo=0, hi=12, tex=0.05, freq=40),
    'glove':      dict(ramp='charcoal', lo=0, hi=10, tex=0.04, freq=40),
    'sole':       dict(ramp='grey',   lo=0, hi=4),
    'metal':      dict(ramp='gunmetal', lo=0, hi=12, tex=0.03, freq=50, spec=0.55),
    'polymer':    dict(ramp='grey',   lo=0, hi=8, tex=0.03, freq=50, spec=0.20),
    'wood':       dict(ramp='brown',  lo=2, hi=12, tex=0.08, freq=30, spec=0.15),
    'furn':       dict(ramp='olivegrey', lo=1, hi=11, tex=0.04, freq=30, spec=0.10),
    'lens':       dict(ramp='glass',  lo=0, hi=12, spec=1.0),
    'brass':      dict(ramp='brass',  lo=3, hi=15, spec=0.6),
    'glow':       dict(ramp='fb_cool', lo=8, hi=14, emissive=True),
    'flash':      dict(ramp='fb_warm', lo=4, hi=14, emissive=True, tex=0.35, freq=55),
    'flash_core': dict(ramp='fb_warm', lo=12, hi=15, emissive=True),
}
MAT_NAMES = list(MATERIALS)
MAT_ID = {n: i for i, n in enumerate(MAT_NAMES)}
TEAM_MATS = [MAT_ID['team'], MAT_ID['team_dk']]

# Teams have no names (D-041): your team is always blue, the enemy always red.
TEAMS = {
    'blue': dict(title='Blue', blurb='Your team (Teams.FRIENDLY_COLOR)', TEAM='team_blue'),
    'red':  dict(title='Red',  blurb='The enemy (Teams.ENEMY_COLOR)',    TEAM='team_red'),
}

# ---------------------------------------------------------------- math
D = math.radians


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    """degrees; yaw about +y, then pitch (+ = nose/forward tilts down), then roll (+ = top tilts to -x)."""
    return ry(D(yaw)) @ rx(D(pitch)) @ rz(D(roll))


class Frame:
    __slots__ = ('R', 't')

    def __init__(self, R=None, t=None):
        self.R = np.eye(3) if R is None else np.asarray(R, float)
        self.t = np.zeros(3) if t is None else np.asarray(t, float)

    def __matmul__(self, o):
        return Frame(self.R @ o.R, self.R @ o.t + self.t)

    def pt(self, p):
        return self.R @ np.asarray(p, float) + self.t

    def vec(self, v):
        return self.R @ np.asarray(v, float)


def T(x, y=0.0, z=0.0):
    return Frame(None, (x, y, z))


def Rt(R):
    return Frame(R)


def norm(v):
    return v / max(np.linalg.norm(v), 1e-9)


def seg_frame(a, b, ref):
    """frame with origin a and +y running to b; x as close to `ref` as possible."""
    y = norm(b - a)
    x = ref - y * np.dot(ref, y)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross(y, [0, 0, 1.0])
    x = norm(x)
    z = np.cross(x, y)
    return Frame(np.column_stack([x, y, z]), a), float(np.linalg.norm(b - a))


# ---------------------------------------------------------------- SDF shapes
# a shape is (fn(q)->dist, local bound centre, bound radius); q is (N,3) float32 in shape space

def S_sph(r):
    return (lambda q: np.sqrt((q * q).sum(1)) - r), np.zeros(3), r


def S_ell(a, b, c):
    r = np.array([a, b, c], f32)
    r2 = r * r

    def fn(q):
        k0 = np.sqrt(((q / r) ** 2).sum(1))
        k1 = np.sqrt(((q / r2) ** 2).sum(1))
        return k0 * (k0 - 1) / np.maximum(k1, 1e-6)
    return fn, np.zeros(3), float(r.max())


def S_box(a, b, c, rr=0.01):
    rr = min(rr, a, b, c)
    h = np.array([a, b, c], f32) - rr

    def fn(q):
        d = np.abs(q) - h
        return np.sqrt((np.maximum(d, 0) ** 2).sum(1)) + np.minimum(d.max(1), 0) - rr
    return fn, np.zeros(3), float(np.linalg.norm(h) + rr)


def S_cyl(r, h, rr=0.0):
    """capped cylinder along local z, radius r, half-length h."""
    rr = min(rr, r, h)

    def fn(q):
        dx = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2) - (r - rr)
        dz = np.abs(q[:, 2]) - (h - rr)
        return (np.minimum(np.maximum(dx, dz), 0)
                + np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dz, 0) ** 2) - rr)
    return fn, np.zeros(3), math.hypot(r, h)


def S_cone(L, r1, r2):
    """round cone from origin (radius r1) to (0,L,0) (radius r2)."""
    L = max(L, 1e-4)
    b = (r1 - r2) / L
    a = math.sqrt(max(1 - b * b, 1e-6))

    def fn(q):
        qx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2)
        qy = q[:, 1]
        k = -b * qx + a * qy
        d0 = np.sqrt(qx * qx + qy * qy) - r1
        d1 = np.sqrt(qx * qx + (qy - L) ** 2) - r2
        d2 = qx * a + qy * b - r1
        return np.where(k < 0, d0, np.where(k > a * L, d1, d2))
    return fn, np.array([0, L / 2, 0]), L / 2 + max(r1, r2)


def S_tcone(L, r1, r2):
    """tapered cylinder with flat ends from origin (radius r1) to (0,L,0) (radius r2)."""
    h = L / 2.0
    k2x, k2y = r2 - r1, 2.0 * h
    k22 = k2x * k2x + k2y * k2y

    def fn(q):
        qx = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2)
        qy = q[:, 1] - h
        cax = qx - np.minimum(qx, np.where(qy < 0, r1, r2))
        cay = np.abs(qy) - h
        t = np.clip(((r2 - qx) * k2x + (h - qy) * k2y) / k22, 0, 1)
        cbx = qx - r2 + k2x * t
        cby = qy - h + k2y * t
        sgn = np.where((cbx < 0) & (cay < 0), -1.0, 1.0).astype(f32)
        return sgn * np.sqrt(np.minimum(cax * cax + cay * cay, cbx * cbx + cby * cby))
    return fn, np.array([0, h, 0]), math.hypot(h, max(r1, r2))


def S_at(shape, fr):
    """place a shape inside a local frame."""
    fn, c, r = shape
    R = fr.R.astype(f32)
    t = fr.t.astype(f32)
    return (lambda q: fn((q - t) @ R)), fr.pt(c), r


def S_scale(shape, k):
    """uniformly scale a shape about its origin."""
    fn, c, r = shape
    k32 = f32(k)
    return (lambda q: fn(q / k32) * k32), np.asarray(c, float) * k, r * k


def S_scale3(shape, k):
    """non-uniform scale (kept mild, so the distance stays usable for ray marching)."""
    fn, c, r = shape
    k3 = np.asarray(k, f32)
    m = f32(min(k))
    return (lambda q: fn(q / k3) * m), np.asarray(c, float) * k3, r * float(max(k))


def S_sub(A, B):
    fa, c, r = A
    fb = B[0]
    return (lambda q: np.maximum(fa(q), -fb(q))), c, r


def S_cut(A, n, h):
    """keep the part of A where dot(q, n) >= h."""
    fa, c, r = A
    n = np.asarray(n, f32) / np.linalg.norm(n)
    return (lambda q: np.maximum(fa(q), h - q @ n)), c, r


def S_slab(A, axis, h, centre=0.0):
    """keep the part of A where |q[axis] - centre| <= h (a stripe through A)."""
    fa, c, r = A
    return (lambda q: np.maximum(fa(q), np.abs(q[:, axis] - f32(centre)) - f32(h))), c, r


class Part:
    __slots__ = ('fn', 'R', 't', 'c', 'rad', 'mat', 'k', 'ground', 'seed')

    def __init__(self, shape, frame, mat, k=0.0, ground=True):
        fn, bc, br = shape
        self.fn = fn
        self.R = frame.R.astype(f32)
        self.t = frame.t.astype(f32)
        self.c = frame.pt(bc).astype(f32)
        self.rad = f32(br + 0.002)
        self.mat = MAT_ID[mat]
        self.k = f32(k)
        self.ground = ground
        self.seed = 0

    def local(self, P):
        return (P - self.t) @ self.R

    def shift(self, dy):
        self.t = self.t + np.array([0, dy, 0], f32)
        self.c = self.c + np.array([0, dy, 0], f32)


# ---------------------------------------------------------------- scene evaluation
class Scene:
    def __init__(self, parts):
        self.parts = parts
        cs = np.array([p.c for p in parts])
        lo = (cs - [[p.rad] for p in parts]).min(0)
        hi = (cs + [[p.rad] for p in parts]).max(0)
        self.center = ((lo + hi) / 2).astype(f32)
        self.radius = float(max(np.linalg.norm(p.c - self.center) + p.rad for p in parts))

    def sdf(self, P):
        d = np.full(len(P), 1e3, f32)
        for pt in self.parts:
            diff = P - pt.c
            dc = np.sqrt((diff * diff).sum(1)) - pt.rad
            m = dc < d + pt.k
            if not m.any():
                continue
            sel = np.nonzero(m)[0]
            dp = pt.fn((P[sel] - pt.t) @ pt.R)
            dcur = d[sel]
            if pt.k > 0:
                h = np.clip(0.5 + 0.5 * (dcur - dp) / pt.k, 0, 1)
                d[sel] = dcur * (1 - h) + dp * h - pt.k * h * (1 - h)
            else:
                d[sel] = np.minimum(dcur, dp)
        return d

    def nearest(self, P):
        best = np.full(len(P), 1e3, f32)
        pid = np.zeros(len(P), np.int32)
        for i, pt in enumerate(self.parts):
            diff = P - pt.c
            dc = np.sqrt((diff * diff).sum(1)) - pt.rad
            m = dc < best
            if not m.any():
                continue
            sel = np.nonzero(m)[0]
            dp = pt.fn((P[sel] - pt.t) @ pt.R)
            closer = dp < best[sel]
            best[sel[closer]] = dp[closer]
            pid[sel[closer]] = i
        return pid

    def normal(self, P, e=0.004):
        ks = np.array([[1, -1, -1], [-1, -1, 1], [-1, 1, -1], [1, 1, 1]], f32)
        n = np.zeros_like(P)
        for k in ks:
            n += k * self.sdf(P + k * e)[:, None]
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)

    def ao(self, P, N):
        occ = np.zeros(len(P), f32)
        sca = 1.0
        for i in range(5):
            h = 0.012 + 0.13 * i / 4.0
            d = self.sdf(P + N * h)
            occ += (h - d) * sca
            sca *= 0.85
        return np.clip(1.0 - 2.2 * occ, 0, 1)

    def march(self, O, Dv):
        """sphere-trace rays (O: (N,3), Dv: (3,)) -> t, hit mask."""
        n = len(O)
        oc = O - self.center
        b = oc @ Dv
        c = (oc * oc).sum(1) - self.radius ** 2
        disc = b * b - c
        t = np.full(n, 1e9, f32)
        hit = np.zeros(n, bool)
        live = disc > 0
        sq = np.sqrt(np.maximum(disc, 0))
        t0 = (-b - sq).astype(f32)
        t1 = (-b + sq).astype(f32)
        act = np.nonzero(live)[0]
        t[act] = np.maximum(t0[act], 0)
        eps = f32(0.0015)
        last = np.zeros(n, f32)
        for _ in range(MAX_STEPS):
            if len(act) == 0:
                break
            P = O[act] + Dv * t[act, None]
            d = self.sdf(P)
            last[act] = d
            h = d < eps
            hit[act[h]] = True
            t[act] += d * f32(0.92)
            keep = (~h) & (t[act] < t1[act])
            act = act[keep]
        if len(act):
            hit[act[last[act] < 0.01]] = True
        return t, hit


# ---------------------------------------------------------------- noise
def _hash(ix, iy, iz, seed):
    h = (ix * np.int64(73856093)) ^ (iy * np.int64(19349663)) ^ (iz * np.int64(83492791)) ^ np.int64(seed * 7919 + 1013)
    h = (h ^ (h >> np.int64(13))) * np.int64(1274126177)
    h = h ^ (h >> np.int64(16))
    return (h & np.int64(0xFFFF)).astype(f32) / f32(65535.0)


def vnoise(p, seed=0):
    p = p.astype(np.float64)
    i = np.floor(p).astype(np.int64)
    fr = (p - i).astype(f32)
    u = fr * fr * (3 - 2 * fr)
    x, y, z = i[:, 0], i[:, 1], i[:, 2]
    ux, uy, uz = u[:, 0], u[:, 1], u[:, 2]

    def lerp(a, b, t):
        return a + (b - a) * t
    x0 = lerp(_hash(x, y, z, seed), _hash(x + 1, y, z, seed), ux)
    x1 = lerp(_hash(x, y + 1, z, seed), _hash(x + 1, y + 1, z, seed), ux)
    x2 = lerp(_hash(x, y, z + 1, seed), _hash(x + 1, y, z + 1, seed), ux)
    x3 = lerp(_hash(x, y + 1, z + 1, seed), _hash(x + 1, y + 1, z + 1, seed), ux)
    return lerp(lerp(x0, x1, uy), lerp(x2, x3, uy), uz)


# ---------------------------------------------------------------- weapons
# The four signature guns (GAME_DESIGN 4.9, D-056). Drawn oversize so they read at sprite scale.
WEAPONS = {
    'ak':      dict(title='AK-style rifle', scale=1.10),
    'shotgun': dict(title='Pump shotgun',   scale=1.10),
    'sniper':  dict(title='Sniper rifle',   scale=1.10),
    'smg':     dict(title='SMG',            scale=1.15),
}


def weapon_def(kind):
    """parts in weapon space: origin at the top of the pistol grip, +z down the barrel, +y up."""
    P = []

    def add(shape, fr, mat):
        P.append((shape, fr, mat))

    if kind == 'ak':          # AK-style rifle: wood furniture, gas tube, slant brake, curved mag
        add(S_box(0.024, 0.038, 0.135, 0.010), T(0, 0.045, 0.06), 'metal')          # receiver
        add(S_box(0.021, 0.012, 0.12, 0.010), T(0, 0.086, 0.05), 'metal')           # top cover
        add(S_box(0.016, 0.012, 0.02, 0.005), T(0, 0.094, 0.20), 'metal')           # rear sight
        add(S_box(0.027, 0.028, 0.085, 0.012), T(0, 0.045, 0.28), 'wood')           # lower handguard
        add(S_box(0.019, 0.013, 0.075, 0.008), T(0, 0.086, 0.29), 'wood')           # upper handguard
        add(S_cyl(0.012, 0.09), T(0, 0.055, 0.44), 'metal')                         # barrel
        add(S_cyl(0.008, 0.05), T(0, 0.086, 0.40), 'metal')                         # gas tube
        add(S_box(0.009, 0.026, 0.010, 0.004), T(0, 0.085, 0.475), 'metal')         # front sight post
        add(S_cyl(0.016, 0.024, 0.004), T(0, 0.055, 0.545), 'metal')                # muzzle brake
        add(S_box(0.016, 0.030, 0.030, 0.006), T(0, -0.005, 0.135) @ Rt(rx(-0.20)), 'metal')   # curved mag
        add(S_box(0.016, 0.030, 0.030, 0.006), T(0, -0.061, 0.153) @ Rt(rx(-0.42)), 'metal')
        add(S_box(0.016, 0.030, 0.030, 0.006), T(0, -0.112, 0.183) @ Rt(rx(-0.66)), 'metal')
        add(S_box(0.016, 0.045, 0.021, 0.008), T(0, -0.025, -0.01) @ Rt(rx(0.35)), 'wood')     # grip
        add(S_box(0.020, 0.030, 0.11, 0.010), T(0, 0.036, -0.13) @ Rt(rx(0.13)), 'wood')       # stock
        add(S_box(0.022, 0.050, 0.05, 0.012), T(0, 0.012, -0.235) @ Rt(rx(0.13)), 'wood')
        pts = dict(R=(0, -0.02, -0.005), L=(0, 0.012, 0.27), muzzle=(0, 0.055, 0.57),
                   eject=(-0.03, 0.07, 0.06), flash=1.0)
    elif kind == 'shotgun':   # pump shotgun: long barrel over a magazine tube, ribbed pump
        add(S_box(0.026, 0.045, 0.105, 0.012), T(0, 0.048, 0.05), 'metal')         # receiver
        add(S_cyl(0.014, 0.25), T(0, 0.072, 0.40), 'metal')                         # barrel
        add(S_cyl(0.016, 0.21), T(0, 0.036, 0.36), 'metal')                         # magazine tube
        add(S_box(0.027, 0.027, 0.08, 0.012), T(0, 0.036, 0.33), 'polymer')         # pump
        for z in (0.29, 0.33, 0.37):
            add(S_box(0.029, 0.029, 0.006, 0.004), T(0, 0.036, z), 'polymer')       # pump ribs
        add(S_box(0.008, 0.008, 0.008, 0.003), T(0, 0.090, 0.63), 'metal')          # bead
        add(S_box(0.016, 0.045, 0.021, 0.008), T(0, -0.025, -0.01) @ Rt(rx(0.35)), 'polymer')
        add(S_box(0.020, 0.032, 0.11, 0.010), T(0, 0.034, -0.13) @ Rt(rx(0.10)), 'polymer')
        add(S_box(0.024, 0.054, 0.045, 0.012), T(0, 0.012, -0.235) @ Rt(rx(0.10)), 'polymer')
        pts = dict(R=(0, -0.02, -0.005), L=(0, 0.012, 0.33), muzzle=(0, 0.072, 0.65),
                   eject=(-0.03, 0.06, 0.06), flash=1.4)
    elif kind == 'sniper':    # bolt-action rifle with scope and folded bipod
        add(S_box(0.024, 0.062, 0.09, 0.016), T(0, 0.010, -0.25), 'furn')
        add(S_box(0.019, 0.032, 0.07, 0.010), T(0, 0.035, -0.13), 'furn')
        add(S_box(0.024, 0.032, 0.18, 0.012), T(0, 0.035, 0.22), 'furn')
        add(S_cyl(0.020, 0.10), T(0, 0.065, 0.04), 'metal')
        add(S_cyl(0.015, 0.25), T(0, 0.065, 0.42), 'metal')
        add(S_cyl(0.021, 0.03, 0.005), T(0, 0.065, 0.69), 'metal')
        add(S_cyl(0.020, 0.13), T(0, 0.128, 0.05), 'metal')
        add(S_cyl(0.029, 0.035, 0.006), T(0, 0.128, 0.19), 'metal')
        add(S_cyl(0.025, 0.025, 0.006), T(0, 0.128, -0.09), 'metal')
        add(S_cyl(0.022, 0.004), T(0, 0.128, 0.227), 'lens')
        add(S_box(0.012, 0.024, 0.024, 0.005), T(0, 0.032, 0.06), 'metal')
        add(S_box(0.007, 0.007, 0.03, 0.006), T(-0.032, 0.062, 0.0) @ Rt(ry(-0.9)), 'metal')
        add(S_sph(0.012), T(-0.052, 0.062, -0.02), 'metal')
        add(S_box(0.017, 0.045, 0.022, 0.008), T(0, -0.025, -0.06) @ Rt(rx(0.35)), 'furn')
        for sx in (-0.012, 0.012):
            add(S_cyl(0.008, 0.11), T(sx, 0.005, 0.45), 'metal')
        pts = dict(R=(0, -0.022, -0.065), L=(0, 0.002, 0.25), muzzle=(0, 0.065, 0.72),
                   eject=(-0.03, 0.08, 0.05), flash=1.25)
    elif kind == 'smg':       # compact SMG: magazine in the grip, vertical foregrip, folding stock
        add(S_box(0.022, 0.042, 0.10, 0.010), T(0, 0.045, 0.06), 'metal')           # receiver
        add(S_box(0.016, 0.014, 0.07, 0.006), T(0, 0.094, 0.05), 'polymer')         # top rail
        add(S_cyl(0.017, 0.045, 0.005), T(0, 0.050, 0.20), 'metal')                 # barrel shroud
        add(S_cyl(0.010, 0.03), T(0, 0.050, 0.265), 'metal')                        # barrel
        add(S_box(0.015, 0.045, 0.021, 0.008), T(0, -0.025, 0.0) @ Rt(rx(0.2)), 'polymer')    # grip
        add(S_box(0.013, 0.055, 0.017, 0.005), T(0, -0.123, -0.02) @ Rt(rx(0.2)), 'metal')    # magazine
        add(S_box(0.014, 0.040, 0.018, 0.007), T(0, -0.02, 0.15), 'polymer')        # foregrip
        for sx in (-0.014, 0.014):
            add(S_cyl(0.006, 0.07), T(sx, 0.055, -0.11), 'metal')                   # stock rods
        add(S_box(0.022, 0.035, 0.010, 0.005), T(0, 0.045, -0.185), 'polymer')      # butt plate
        pts = dict(R=(0, -0.02, -0.005), L=(0, -0.035, 0.15), muzzle=(0, 0.05, 0.30),
                   eject=(-0.03, 0.07, 0.05), flash=0.7)
    else:
        raise ValueError(kind)
    WS = WEAPONS[kind]['scale']
    out = []
    for shape, fr, mat in P:
        out.append((S_scale(shape, WS), Frame(fr.R, fr.t * WS), mat))
    pts = {k: (np.array(v) * WS if isinstance(v, tuple) else v) for k, v in pts.items()}
    return out, pts


# ---------------------------------------------------------------- classes
# The crew (GAME_DESIGN 4.9, D-053). Silhouette first: height, build, posture and headgear
# differ, not only the kit. The team colour sits on the 'team' parts only.
#   height:  standing height to the top of the head, without headgear (m)
#   build:   w torso width, depth torso depth, shoulders, hips, limb thickness, leg and torso
#            length factors, head size (all 1.0 = average)
#   posture: hunch (deg, chest leans forward), knee (deg, knees bent at rest), stance (feet spread)
#   kit:     ramps for the class-coloured slots (TOP jacket/coat, BOTTOM trousers, GEAR vest/rig, HELM headgear)
CLASSES = {
    'rifleman': dict(
        title='Rifleman', height=1.82,
        build=dict(w=1.10, depth=1.08, shoulders=1.10, hips=1.05, limb=1.10, leg=0.97, torso=1.0, head=1.0),
        posture=dict(hunch=-2, knee=0, stance=1.0),
        skin='skin_l', kit=dict(TOP='olivegrey', BOTTOM=('olivegrey', 0, 11), GEAR='moss', HELM='moss'),
        head='highcut', torso='carrier', back='hydration', weapon='ak',
        perk=('Quick Hands', 'Reloads and weapon switches 15% faster.'),
        silhouette='Stocky and upright: the everyman shape. Rounded high-cut helmet with ear cups, boxy plate carrier.',
        look='High-cut helmet with a team stripe and goggles, plate carrier with three mag pouches, '
             'team armbands and a team patch on the carrier, knee pads, hydration pack.'),
    'bulwark': dict(
        title='Bulwark', height=1.92,
        build=dict(w=1.30, depth=1.25, shoulders=1.34, hips=1.15, limb=1.28, leg=0.96, torso=1.04, head=1.04),
        posture=dict(hunch=13, knee=7, stance=1.35),
        skin='skin_l', kit=dict(TOP='charcoal', BOTTOM='charcoal', GEAR='grey', HELM='grey'),
        head='closed', torso='heavy', back='plates', weapon='shotgun',
        perk=('Plated', 'With armor on, takes 10% less damage and the armor wears down 30% slower.'),
        silhouette='Tallest and widest, hunched forward. Big closed helmet over a gas-mask snout, wide shoulder plates.',
        look='Closed helmet with a team stripe over a gas mask with a front filter, team shoulder plates, '
             'heavy chest and groin plates, thigh and shin guards, team armbands.'),
    'marksman': dict(
        title='Marksman', height=1.88,
        build=dict(w=0.90, depth=0.92, shoulders=0.94, hips=0.95, limb=0.84, leg=1.07, torso=1.02, head=0.96),
        posture=dict(hunch=5, knee=0, stance=0.85),
        skin='skin_d', kit=dict(TOP=('grey', 0, 12), BOTTOM='charcoal', GEAR='olivegrey', HELM=('grey', 0, 12)),
        head='hood', torso='coat', back='scarf', weapon='sniper',
        perk=('Steady', 'Scoped accuracy recovers 30% faster after moving; scoping in is 20% faster.'),
        silhouette='Tall and thin, slightly stooped. Pointed hood, a long coat that flares to the knees.',
        look='Hood, a team scarf over the lower face with a tail down the back, long light-grey coat, '
             'lean chest rig, team armbands.'),
    'scout': dict(
        title='Scout', height=1.72,
        build=dict(w=0.88, depth=0.90, shoulders=0.92, hips=0.95, limb=0.86, leg=1.0, torso=0.97, head=0.97),
        posture=dict(hunch=7, knee=14, stance=1.15),
        skin='skin_d', kit=dict(TOP='charcoal', BOTTOM='moss', GEAR='ink', HELM='charcoal'),
        head='beanie', torso='slim', back='radio', weapon='smg',
        perk=('Light Step', 'Running footsteps carry 70% as far.'),
        silhouette='Shortest and slimmest, knees bent, ready to move. Small round head, a radio antenna over the shoulder.',
        look='Team beanie over a black balaclava, glowing goggles, slim chest rig, radio pack with a whip '
             'antenna, thigh holster, team armbands.'),
}

# weapon holds, relative to the pelvis (x right = -x, y up, z forward), in metres + degrees.
# x and y are scaled by the class's size in build().
HOLDS = {
    'ak':      dict(idle=(-0.10, 0.30, 0.24, 40, 15, 0), run=(-0.08, 0.32, 0.24, 32, 20, 6),
                    aim=(-0.10, 0.52, 0.24, 0, 0, 0)),
    'shotgun': dict(idle=(-0.10, 0.30, 0.22, 36, 18, 0), run=(-0.08, 0.32, 0.22, 30, 20, 6),
                    aim=(-0.10, 0.52, 0.22, 0, 0, 0)),
    'sniper':  dict(idle=(-0.12, 0.26, 0.22, 46, 20, 0), run=(-0.10, 0.30, 0.22, 40, 24, 6),
                    aim=(-0.10, 0.51, 0.22, 0, 0, 0)),
    'smg':     dict(idle=(-0.08, 0.30, 0.22, 45, 15, 0), run=(-0.07, 0.32, 0.22, 38, 18, 6),
                    aim=(-0.09, 0.52, 0.22, 0, 0, 0)),
}

ANIMS = [  # name, frames, fps, loop
    ('idle', 1, 1, True),
    ('run', 4, 8, True),
    ('aim', 1, 1, False),
    ('fire', 1, 12, False),
    ('pain', 1, 6, False),
    ('crouch', 1, 1, False),
    ('crouch_fire', 1, 12, False),
    ('death', 5, 8, False),
]


def frame_list(anims):
    return [(a, i) for a, n, _, _ in ANIMS if a in anims for i in range(n)]


def base_pose():
    return dict(root_off=(0, 0, 0), root_pitch=0, root_roll=0, pelvis_yaw=0,
                chest_pitch=0, chest_yaw=0, chest_roll=0, head=(0, 0, 0), hunch=0,
                legL=(6, 5, 6, 0), legR=(-4, 5, 4, 0),
                weapon=('held', None), handR='grip', handL='fore',
                poleR=(-0.7, -1.0, -0.35), poleL=(0.6, -1.0, -0.2), flash=False)


def make_pose(cdef, anim, i):
    p = base_pose()
    H = HOLDS[cdef['weapon']]
    if anim == 'idle':
        p.update(pelvis_yaw=-10, chest_yaw=-8, head=(2, 10, 0), weapon=('held', H['idle']),
                 legL=(8, 6, 8, 0), legR=(-6, 6, 6, 0))
    elif anim == 'run':
        legs = [((30, 4, 14, -12), (-24, 4, 42, 22)),
                ((4, 4, 20, 0), (28, 4, 92, 12)),
                ((-24, 4, 42, 22), (30, 4, 14, -12)),
                ((28, 4, 92, 12), (4, 4, 20, 0))][i]
        sw = [1, 0, -1, 0][i]
        bob = [-0.012, 0.012, -0.012, 0.012][i]
        x, y, z, pi, ya, ro = H['run']
        p.update(legL=legs[0], legR=legs[1], pelvis_yaw=-8 * sw, chest_yaw=-12 + 8 * sw,
                 chest_pitch=10, head=(-6, 8 - 6 * sw, 0),
                 weapon=('held', (x, y + bob, z, pi + 3 * sw, ya, ro)))
    elif anim in ('aim', 'fire', 'crouch', 'crouch_fire'):
        x, y, z, pi, ya, ro = H['aim']
        p.update(pelvis_yaw=-18, chest_yaw=-18, head=(6, 0, 8),
                 legL=(12, 8, 10, -2), legR=(-10, 10, 8, 2))
        if anim.startswith('crouch'):
            p.update(legL=(84, 8, 92, 0), legR=(6, 10, 108, 62), chest_pitch=6)
        if anim.endswith('fire'):
            kick = 1.5 if cdef['weapon'] == 'shotgun' else 1.0
            z -= 0.022 * kick
            pi -= 5 * kick
            p.update(flash=True, chest_pitch=p['chest_pitch'] - 2)
        p['weapon'] = ('held', (x, y, z, pi, ya, ro))
    elif anim == 'pain':
        x, y, z, pi, ya, ro = H['aim']
        p.update(pelvis_yaw=-12, chest_yaw=-6, chest_pitch=-14, chest_roll=-10, head=(-24, 10, -16),
                 legL=(6, 8, 18, 0), legR=(-18, 8, 30, 8),
                 weapon=('held', (x + 0.04, y - 0.10, z - 0.06, pi - 26, ya + 14, ro + 18)),
                 handL=('free', (0.04, 0.36, 0.17)), poleL=(0.9, -0.6, 0.2))
    elif anim == 'death':
        if i == 0:
            x, y, z, pi, ya, ro = H['aim']
            p.update(root_pitch=-8, chest_pitch=-18, chest_yaw=-4, head=(-28, 0, -6),
                     legL=(4, 6, 8, 0), legR=(-6, 6, 12, 0),
                     weapon=('held', (x, y + 0.04, z - 0.08, pi - 42, ya - 10, ro + 20)),
                     handL=('free', (0.42, 0.62, 0.10)), poleL=(0.4, -0.6, -0.8))
        elif i == 1:
            p.update(root_pitch=-16, root_roll=16, chest_pitch=-6, chest_roll=8, head=(-12, 6, 18),
                     legL=(32, 8, 72, 10), legR=(22, 8, 62, 10),
                     weapon=('drop', (-0.32, 0.60, 0.34, -60, 30, 40)),
                     handR=('free', (-0.32, 0.14, 0.24)), handL=('free', (0.40, 0.48, 0.06)),
                     poleR=(-0.6, -0.6, -0.6), poleL=(0.6, -0.4, -0.7))
        elif i == 2:
            p.update(root_pitch=-36, root_roll=44, chest_pitch=8, chest_roll=12, head=(8, 4, 22),
                     legL=(42, 10, 82, 20), legR=(26, 10, 70, 16),
                     weapon=('drop', (-0.36, 0.16, 0.46, -12, 50, 80)),
                     handR=('free', (-0.34, 0.12, 0.10)), handL=('free', (0.46, 0.60, 0.0)),
                     poleR=(-0.6, -0.6, -0.6), poleL=(0.6, -0.4, -0.7))
        elif i == 3:
            p.update(root_pitch=-62, root_roll=74, chest_pitch=2, chest_roll=8, head=(-10, 10, 12),
                     legL=(30, 12, 52, 20), legR=(14, 10, 42, 20),
                     weapon=('drop', (-0.42, 0.0, 0.40, 0, 62, 90)),
                     handR=('free', (-0.38, -0.02, 0.02)), handL=('free', (0.42, 0.74, 0.0)),
                     poleR=(-0.6, -0.6, -0.6), poleL=(0.6, -0.2, -0.8))
        else:
            p.update(root_pitch=-84, root_roll=86, chest_pitch=0, chest_roll=4, head=(-6, 22, 14),
                     legL=(22, 14, 26, 30), legR=(8, 10, 38, 30),
                     weapon=('drop', (-0.44, 0.0, 0.40, 0, 62, 90)),
                     handR=('free', (-0.36, -0.10, 0.06)), handL=('free', (0.44, 0.80, 0.0)),
                     poleR=(-0.6, -0.6, -0.6), poleL=(0.6, -0.2, -0.8))

    # class posture: a hunch leans the chest (the weapon follows it in build()), bent knees
    # and a wider stance change the resting shape. Not applied once the body falls.
    po = cdef['posture']
    if not (anim == 'death' and i > 0):
        p['hunch'] = po['hunch'] * (0.6 if anim == 'run' else 1.0)
        p['chest_pitch'] += p['hunch']
        if anim in ('idle', 'aim', 'fire', 'pain'):
            k = po['knee']
            for key in ('legL', 'legR'):
                hf, abd, kf, toe = p[key]
                p[key] = (hf + 0.5 * k, abd * po['stance'], kf + k, toe)
    return p


def ik(S, Tg, a, b, pole):
    d = Tg - S
    L = float(np.linalg.norm(d))
    dirv = d / max(L, 1e-9)
    over = L > (a + b) * 0.995
    L = min(max(L, abs(a - b) + 1e-3), (a + b) * 0.995)
    x = (a * a - b * b + L * L) / (2 * L)
    h = math.sqrt(max(a * a - x * x, 0.0))
    pn = pole - dirv * np.dot(pole, dirv)
    pn = norm(pn)
    E = S + dirv * x + pn * h
    W = S + dirv * L
    return E, W, over


def body_dims(cd):
    """derived skeleton sizes. s scales lengths so the head top lands at the class height."""
    b = cd['build']
    lg, tl, hd = b.get('leg', 1.0), b.get('torso', 1.0), b.get('head', 1.0)
    s = (cd['height'] - FOOT_H - 0.23 * hd) / (0.87 * lg + 0.17 + 0.45 * tl)
    return dict(s=s, w=b['w'], d=b.get('depth', b['w']), sh=b.get('shoulders', b['w']),
                hip=b.get('hips', 1.0), lw=b.get('limb', 1.0), lg=lg, tl=tl, hd=hd, ty=s * tl,
                ysc=(0.10 * s + 0.37 * s * tl) / 0.47)


def build(cname, pose, yaw_deg, warn=None):
    cd = CLASSES[cname]
    B = body_dims(cd)
    s, w, d, sh, lw, ty, hd = B['s'], B['w'], B['d'], B['sh'], B['lw'], B['ty'], B['hd']
    wh = w * B['hip']
    p = pose
    parts = []

    def add(shape, fr, mat, k=0.0, ground=True):
        parts.append(Part(shape, fr, mat, k, ground))

    th_len, sh_len = 0.44 * s * B['lg'], 0.43 * s * B['lg']
    F = Rt(ry(D(yaw_deg))) @ T(*p['root_off'])
    base = F @ T(0, FOOT_H + th_len + sh_len + 0.07 * s, 0) @ Rt(rx(D(p['root_pitch'])) @ rz(D(p['root_roll'])))
    pelvis = base @ Rt(ry(D(p['pelvis_yaw'])))

    def chest_at(pitch):
        return pelvis @ T(0, 0.10 * s, 0) @ Rt(rot(pitch, p['chest_yaw'], p['chest_roll']))
    chest = chest_at(p['chest_pitch'])
    hp, hy, hr = p['head']
    neck = chest.pt((0, 0.45 * ty, 0.005))
    head = Frame(base.R @ rot(hp, hy, hr), neck)
    side_ref = base.vec((1, 0, 0))

    def limb(a, b, r1, r2, mat, k=0.025, ref=None):
        fr, L = seg_frame(np.asarray(a, float), np.asarray(b, float), side_ref if ref is None else ref)
        add(S_cone(L, r1, r2), fr, mat, k)
        return fr, L

    def hadd(shape, fr, mat, k=0.0):
        """add a head part; head parts are authored for an average head and scaled by hd."""
        add(S_scale(shape, hd), head @ Frame(fr.R, fr.t * hd), mat, k)

    tor = cd['torso']
    # ------------------------------------------------ legs
    for side, key in ((1, 'legL'), (-1, 'legR')):
        hf, abd, kf, toe = p[key]
        hip = pelvis.pt((side * 0.095 * wh, -0.07 * s, 0))
        Rth = pelvis.R @ rz(D(side * abd)) @ rx(D(-hf))
        knee = hip + Rth @ np.array([0, -th_len, 0])
        Rsh = Rth @ rx(D(kf))
        ankle = knee + Rsh @ np.array([0, -sh_len, 0])
        Rft = Rsh @ rx(D(hf - kf + toe))
        thigh = Frame(Rth, hip)
        shin = Frame(Rsh, knee)
        foot = Frame(Rft, ankle)
        add(S_cone(th_len, 0.092 * lw, 0.068 * lw), Frame(Rth @ rz(math.pi), hip), 'bottom', 0.03)
        add(S_cone(sh_len, 0.065 * lw, 0.050 * lw), Frame(Rsh @ rz(math.pi), knee), 'bottom', 0.02)
        if tor in ('carrier', 'slim'):
            add(S_box(0.030 * lw, 0.06, 0.05, 0.02), thigh @ T(side * 0.07 * lw, -0.22 * s, 0.0), 'bottom', 0.01)
        if tor in ('carrier', 'heavy'):
            add(S_box(0.054 * lw, 0.060, 0.03, 0.022), shin @ T(0, -0.025, 0.052 * lw), 'gear_dk', 0.006)
        if tor == 'heavy':
            add(S_box(0.07 * lw, 0.14, 0.03, 0.02), thigh @ T(0, -0.21 * s, 0.075 * lw), 'gear', 0.006)
            add(S_box(0.05 * lw, 0.13, 0.028, 0.02), shin @ T(0, -0.21 * s, 0.052 * lw), 'gear', 0.006)
        if tor == 'slim' and side == -1:
            add(S_box(0.024, 0.085, 0.052, 0.012), thigh @ T(-0.085 * lw, -0.17 * s, 0.01), 'gear_dk', 0.004)
        bw = math.sqrt(lw)
        add(S_box(0.056 * bw, 0.075, 0.062 * bw, 0.03), shin @ T(0, -sh_len + 0.03, 0.0), 'boot', 0.015)
        add(S_box(0.052 * bw, 0.042, 0.118 * bw, 0.03), foot @ T(0, -0.042, 0.05), 'boot', 0.015)
        add(S_box(0.055 * bw, 0.012, 0.124 * bw, 0.008), foot @ T(0, -0.078, 0.05), 'sole')

    # ------------------------------------------------ pelvis / torso
    add(S_box(0.145 * wh, 0.085, 0.10 * d, 0.05), pelvis @ T(0, -0.02, 0), 'bottom', 0.03)
    add(S_ell(0.135 * w, 0.13 * B['tl'], 0.095 * d), chest @ T(0, 0.08 * ty, 0), 'top', 0.03)
    add(S_box(0.172 * sh, 0.13 * ty, 0.108 * d, 0.07), chest @ T(0, 0.27 * ty, 0), 'top', 0.03)
    for side in (1, -1):
        add(S_sph(0.074 * max(lw, sh) ** 0.5 * min(lw, sh) ** 0.5), chest @ T(side * 0.18 * sh, 0.37 * ty, 0), 'top', 0.04)
    add(S_box(0.15 * wh, 0.028, 0.11 * d, 0.02), pelvis @ T(0, 0.055, 0), 'gear_dk', 0.008)

    fz = 0.108 * d  # chest front surface
    if tor == 'carrier':
        add(S_box(0.168 * sh, 0.15 * ty, fz + 0.02, 0.04), chest @ T(0, 0.25 * ty, 0.004), 'gear', 0.01)
        for x in (-0.074, 0.0, 0.074):
            add(S_box(0.033, 0.05, 0.025, 0.012), chest @ T(x * sh, 0.165 * ty, fz + 0.024), 'gear_dk', 0.006)
        add(S_box(0.085, 0.040, 0.012, 0.008), chest @ T(0, 0.30 * ty, fz + 0.026), 'team', 0.004)
        for side in (1, -1):
            add(S_box(0.04, 0.03, 0.12 * d, 0.015), chest @ T(side * 0.11 * sh, 0.40 * ty, 0), 'team', 0.01)
    elif tor == 'coat':
        add(S_ell(0.15 * sh, 0.05, 0.12 * d), chest @ T(0, 0.40 * ty, -0.005), 'top', 0.02)        # collar yoke
        add(S_box(0.13 * w, 0.075, fz + 0.012, 0.03), chest @ T(0, 0.16 * ty, 0.0), 'gear', 0.01)  # lean rig
        for x in (-0.055, 0.055):
            add(S_box(0.035, 0.045, 0.022, 0.012), chest @ T(x, 0.15 * ty, fz + 0.016), 'gear_dk', 0.006)
        # the coat skirt hangs from the waist to below the knee, open at the front
        L = 0.10 * s + th_len + 0.06 * s
        skirt = S_scale3(S_tcone(L, 0.150 * w, 0.190 * w), (1.0, 1.0, 0.80))
        slit = S_at(S_cone(L, 0.0, 0.075 * w), T(0, 0.0, -0.17 * w))   # opens towards the hem (z is flipped by rz(pi))
        add(S_sub(skirt, slit), pelvis @ T(0, 0.03, 0) @ Rt(rz(math.pi)), 'top', 0.02)
        add(S_ell(0.14 * sh, 0.055, 0.125 * d), chest @ T(0, 0.43 * ty, -0.005), 'team', 0.01)        # scarf cowl
    elif tor == 'heavy':
        add(S_box(0.20 * sh, 0.17 * ty, 0.155 * d, 0.05), chest @ T(0, 0.24 * ty, 0.0), 'gear', 0.01)
        add(S_ell(0.17 * sh, 0.065, 0.15 * d), chest @ T(0, 0.41 * ty, -0.005), 'gear', 0.02)
        for yy in (0.27, 0.15):
            add(S_box(0.13 * w, 0.055, 0.025, 0.015), chest @ T(0, yy * ty, 0.165 * d), 'gear_dk', 0.006)
        for side in (1, -1):   # shoulder plates in team colour
            add(S_ell(0.118 * sh, 0.074, 0.122 * d), chest @ T(side * 0.235 * sh, 0.40 * ty, 0) @ Rt(rz(-side * 0.45)), 'team', 0.01)
            add(S_ell(0.120 * sh, 0.03, 0.124 * d), chest @ T(side * 0.235 * sh, 0.37 * ty, 0) @ Rt(rz(-side * 0.45)), 'team_dk', 0.004)
        add(S_box(0.095 * w, 0.085, 0.025, 0.02), pelvis @ T(0, -0.10, 0.115 * d) @ Rt(rx(-0.1)), 'gear', 0.006)
    elif tor == 'slim':
        add(S_box(0.145 * w, 0.09, fz + 0.012, 0.03), chest @ T(0, 0.17 * ty, 0.0), 'gear', 0.01)
        for x in (-0.055, 0.055):
            add(S_box(0.035, 0.045, 0.022, 0.012), chest @ T(x, 0.16 * ty, fz + 0.016), 'gear_dk', 0.006)
        for side in (1, -1):
            add(S_box(0.035, 0.024, 0.115 * d, 0.01), chest @ T(side * 0.10 * sh, 0.40 * ty, 0), 'team', 0.01)

    back = cd['back']
    bz = -0.108 * d
    if back == 'hydration':
        add(S_box(0.12, 0.15 * ty, 0.05, 0.04), chest @ T(0, 0.25 * ty, bz - 0.045), 'gear', 0.01)
        add(S_box(0.06, 0.03, 0.012, 0.008), chest @ T(0, 0.33 * ty, bz - 0.094), 'team', 0.004)
    elif back == 'plates':
        add(S_box(0.17 * sh, 0.17 * ty, 0.05, 0.03), chest @ T(0, 0.24 * ty, -0.155 * d - 0.02), 'gear', 0.01)
    elif back == 'scarf':      # the scarf's tail, down the back
        a0 = chest.pt((0.05, 0.43 * ty, bz - 0.01))
        a1 = chest.pt((0.07, 0.10 * ty, bz - 0.05))
        fr, L = seg_frame(a0, a1, side_ref)
        add(S_box(0.035, L / 2, 0.012, 0.008), fr @ T(0, L / 2, 0), 'team', 0.006)
    elif back == 'radio':
        add(S_box(0.11, 0.15 * ty, 0.055, 0.03), chest @ T(0, 0.24 * ty, bz - 0.04), 'gear_dk', 0.01)
        a0 = chest.pt((0.075, 0.37 * ty, bz - 0.06))
        a1 = chest.pt((0.11, 0.86 * ty, bz - 0.16))
        limb(a0, a1, 0.011, 0.008, 'polymer', 0.0)

    # ------------------------------------------------ head
    hd_kind = cd['head']
    face = {'closed': 'mask', 'beanie': 'mask'}.get(hd_kind, 'skin')
    hadd(S_box(0.05, 0.06, 0.05, 0.045), T(0, 0.01, 0.0), face, 0.03)
    hadd(S_ell(0.095, 0.115, 0.104), T(0, 0.115, 0.005), face, 0.02)
    hadd(S_box(0.066, 0.04, 0.066, 0.034), T(0, 0.055, 0.03), face, 0.02)
    if hd_kind != 'closed':
        hadd(S_ell(0.016, 0.024, 0.02), T(0, 0.103, 0.104), face, 0.01)
        for side in (1, -1):
            hadd(S_ell(0.014, 0.027, 0.02), T(side * 0.09, 0.11, -0.005), face, 0.01)
    if hd_kind == 'hood':
        for side in (1, -1):
            hadd(S_ell(0.017, 0.010, 0.012), T(side * 0.034, 0.128, 0.091), 'eye')

    if hd_kind == 'highcut':
        shell = S_at(S_ell(0.126, 0.116, 0.132), T(0, 0.137, -0.006))
        hadd(S_cut(shell, (0, 1, -0.25), 0.140), Frame(), 'helm', 0.004)
        stripe = S_at(S_ell(0.131, 0.121, 0.137), T(0, 0.137, -0.006))
        hadd(S_slab(S_cut(stripe, (0, 1, -0.25), 0.150), 0, 0.034), Frame(), 'team')
        for side in (1, -1):    # ear cups
            hadd(S_at(S_cyl(0.042, 0.022, 0.008), Rt(ry(math.pi / 2))), T(side * 0.105, 0.11, -0.005), 'polymer')
        hadd(S_box(0.078, 0.024, 0.010, 0.008), T(0, 0.128, 0.094), 'polymer')       # goggle frame
        hadd(S_box(0.070, 0.017, 0.010, 0.006), T(0, 0.128, 0.101), 'lens')          # goggle lens
    elif hd_kind == 'closed':
        hadd(S_ell(0.090, 0.092, 0.075), T(0, 0.088, 0.058), 'polymer', 0.01)         # gas mask
        for side in (1, -1):
            hadd(S_at(S_cyl(0.027, 0.008, 0.003), Rt(ry(side * 0.28))), T(side * 0.037, 0.13, 0.10), 'lens')
        hadd(S_at(S_cyl(0.044, 0.036, 0.008), Rt(rx(0.6))), T(0, 0.040, 0.145), 'gear_dk')   # filter
        shell = S_sub(S_at(S_ell(0.142, 0.134, 0.148), T(0, 0.128, -0.012)),
                      S_at(S_ell(0.085, 0.075, 0.10), T(0, 0.105, 0.125)))
        hadd(S_cut(shell, (0, 1, -0.08), 0.045), Frame(), 'helm', 0.004)
        stripe = S_at(S_ell(0.147, 0.139, 0.153), T(0, 0.128, -0.012))
        hadd(S_slab(S_cut(stripe, (0, 1, -0.08), 0.150), 0, 0.026), Frame(), 'team')
    elif hd_kind == 'hood':
        hood = S_sub(S_at(S_ell(0.130, 0.140, 0.130), T(0, 0.125, -0.018)),
                     S_at(S_ell(0.082, 0.092, 0.09), T(0, 0.112, 0.112)))
        hadd(hood, Frame(), 'helm', 0.015)
        hadd(S_ell(0.07, 0.06, 0.07), T(0, 0.225, -0.075) @ Rt(rx(-0.6)), 'helm', 0.03)   # pointed crown
        hadd(S_ell(0.104, 0.064, 0.106), T(0, 0.062, 0.022), 'team', 0.015)                # scarf over the face
        hadd(S_box(0.05, 0.075, 0.016, 0.012), T(0.04, -0.03, 0.10) @ Rt(rz(0.15)), 'team', 0.01)
    elif hd_kind == 'beanie':
        cap = S_at(S_ell(0.104, 0.112, 0.112), T(0, 0.132, 0.0))
        hadd(S_cut(cap, (0, 1, 0.06), 0.150), Frame(), 'team', 0.01)
        hadd(S_slab(S_at(S_ell(0.108, 0.116, 0.116), T(0, 0.132, 0.0)), 1, 0.014, 0.162), Frame(), 'team_dk')
        hadd(S_box(0.072, 0.016, 0.03, 0.008), T(0, 0.128, 0.086), 'polymer', 0.004)       # goggle band
        for side in (1, -1):
            hadd(S_cyl(0.020, 0.014, 0.004), T(side * 0.033, 0.128, 0.104), 'polymer')
            hadd(S_cyl(0.016, 0.004), T(side * 0.033, 0.128, 0.118), 'glow')

    # ------------------------------------------------ weapon
    wparts, wp = weapon_def(cd['weapon'])
    kind, hold = p['weapon']
    if kind == 'held':
        x, y, z, pi, ya, ro = hold
        Wf = base @ T(x * s, y * B['ysc'], z) @ Rt(rot(pi, ya, ro))
        if p['hunch']:
            # a hunch moves the shoulders; the weapon goes with them
            mid = (0, 0.37 * ty, 0.05)
            Wf = Frame(Wf.R, Wf.t + 0.9 * (chest.pt(mid) - chest_at(p['chest_pitch'] - p['hunch']).pt(mid)))
    else:
        x, y, z, pi, ya, ro = hold
        Wf = F @ T(x, y, z) @ Rt(rot(pi, ya, ro))

    # ------------------------------------------------ arms (IK onto weapon or free targets)
    ua, fa = 0.29 * s, 0.27 * s + 0.05
    for side, hkey, pkey, gkey in ((-1, 'handR', 'poleR', 'R'), (1, 'handL', 'poleL', 'L')):
        S = chest.pt((side * 0.185 * sh, 0.37 * ty, 0))
        tgt = p[hkey]
        if tgt in ('grip', 'fore'):
            Tg = Wf.pt(wp[gkey])
        else:
            Tg = base.pt(np.array(tgt[1]) * [1, B['ysc'], 1])
        E, Wr, over = ik(S, Tg, ua, fa, base.vec(p[pkey]))
        if over and warn is not None:
            warn.append(f'{cname}: {hkey} out of reach by {np.linalg.norm(Tg - S) - (ua + fa):.3f} m')
        fdir = norm(Wr - E)
        wrist = E + fdir * (fa - 0.05)
        limb(S, E, 0.063 * lw, 0.053 * lw, 'top', 0.03)
        limb(E, wrist, 0.051 * lw, 0.042 * lw, 'top', 0.02)
        u_fr, u_L = seg_frame(S, E, side_ref)
        add(S_cone(0.055 * s, 0.067 * lw, 0.062 * lw), u_fr @ T(0, 0.075 * s, 0), 'team', 0.004)   # armband
        if tor in ('carrier', 'heavy'):
            add(S_sph(0.051 * lw), Frame(np.eye(3), E), 'gear_dk', 0.006)
        h_fr, _ = seg_frame(wrist, wrist + fdir, side_ref)
        gs = math.sqrt(lw)
        add(S_ell(0.038 * gs, 0.052 * gs, 0.032 * gs), h_fr @ T(0, 0.04, 0), 'glove', 0.012)

    nbody = len(parts)
    for shape, fr, mat in wparts:
        add(shape, Wf @ fr, mat, 0.0, ground=(kind == 'drop'))

    if p['flash']:
        sz = wp['flash']
        M = Wf @ T(*wp['muzzle'])
        add(S_ell(0.028 * sz, 0.028 * sz, 0.045 * sz), M @ T(0, 0, 0.035 * sz), 'flash_core', 0.0, False)
        if sz > 0.6:
            add(S_ell(0.034 * sz, 0.034 * sz, 0.11 * sz), M @ T(0, 0, 0.10 * sz), 'flash', 0.0, False)
            for k in range(4):
                add(S_ell(0.012 * sz, 0.085 * sz, 0.012 * sz), M @ T(0, 0, 0.03 * sz) @ Rt(rz(D(45 + 90 * k))),
                    'flash', 0.0, False)
        add(S_cyl(0.008, 0.016, 0.003), Wf @ T(*(wp['eject'] + np.array([-0.13, 0.08, -0.03]))) @ Rt(ry(1.1)),
            'brass', 0.0, False)

    for i, pt in enumerate(parts):
        pt.seed = i

    # ---------------------------------------------- ground contact
    body = parts[:nbody] + ([] if kind == 'drop' else parts[nbody:])
    body_g = [q for q in parts[:nbody]]
    dy = -lowest_point(body_g)
    for q in body:
        q.shift(dy)
    if kind == 'drop':
        wpart = parts[nbody:nbody + len(wparts)]
        dyw = -lowest_point(wpart)
        for q in wpart:
            q.shift(dyw)
    return parts


def lowest_point(parts):
    lows = np.array([q.c[1] - q.rad for q in parts])
    cutoff = lows.min() + 0.35
    cand = [q for q, l in zip(parts, lows) if l < cutoff]
    sc = Scene(cand)
    cs = np.array([q.c for q in cand])
    rs = np.array([q.rad for q in cand])
    x0, z0 = (cs[:, 0] - rs).min(), (cs[:, 2] - rs).min()
    x1, z1 = (cs[:, 0] + rs).max(), (cs[:, 2] + rs).max()
    xs = np.arange(x0, x1, 0.012)
    zs = np.arange(z0, z1, 0.012)
    X, Z = np.meshgrid(xs, zs)
    O = np.stack([X.ravel(), np.full(X.size, lows.min() - 0.5), Z.ravel()], 1).astype(f32)
    t, hit = sc.march(O, np.array([0, 1, 0], f32))
    if not hit.any():
        return float(lows.min())
    return float((O[hit, 1] + t[hit]).min())


# ---------------------------------------------------------------- rendering
def camera():
    cp, sp = math.cos(CAM_PITCH), math.sin(CAM_PITCH)
    fwd = np.array([0, -sp, -cp], f32)
    up = np.array([0, cp, -sp], f32)
    right = np.array([1, 0, 0], f32)
    return fwd, up, right


def render_gbuffer(parts):
    """returns (mat ids int16 [-1 = empty], ramp position float16) at CELL*SS resolution."""
    n = CELL * SS
    xs = ((np.arange(n) + 0.5) / SS - PIVOT[0]) / PPM
    ys = (PIVOT[1] - (np.arange(n) + 0.5) / SS) / PPM
    X, Y = np.meshgrid(xs, ys)
    fwd, up, right = camera()
    O = (X.reshape(-1, 1) * right + Y.reshape(-1, 1) * up - fwd * 6.0).astype(f32)
    sc = Scene(parts)
    t, hit = sc.march(O, fwd)
    gm = np.full(n * n, -1, np.int16)
    gt = np.zeros(n * n, np.float16)
    idx = np.nonzero(hit)[0]
    if len(idx) == 0:
        return gm.reshape(n, n), gt.reshape(n, n)
    P = O[idx] + fwd * t[idx, None]
    pid = sc.nearest(P)
    N = sc.normal(P)
    ao = sc.ao(P, N)

    L1 = norm(-0.55 * right + 0.78 * up - 0.62 * fwd).astype(f32)
    L2 = norm(0.75 * right + 0.25 * up + 0.45 * fwd).astype(f32)
    Hh = norm(L1 - fwd).astype(f32)
    ndl = (N * L1).sum(1)
    diff = np.clip((ndl + 0.22) / 1.22, 0, 1)
    rim = np.clip((N * L2).sum(1), 0, 1)
    spec = np.clip((N * Hh).sum(1), 0, 1) ** 28
    facing = np.clip(-(N * fwd).sum(1), 0, 1)
    shade = (0.14 + 0.80 * diff + 0.16 * rim) * (0.42 + 0.58 * ao)

    mats = np.array([parts[i].mat for i in range(len(parts))])[pid]
    tval = shade.copy()
    for i in np.unique(pid):
        sel = np.nonzero(pid == i)[0]
        pt = parts[i]
        md = MATERIALS[MAT_NAMES[pt.mat]]
        q = pt.local(P[sel])
        tex = np.zeros(len(sel), f32)
        if md.get('tex'):
            fq = md['freq']
            nz = 0.62 * vnoise(q * fq, pt.seed) + 0.38 * vnoise(q * fq * 2.7, pt.seed + 77) - 0.5
            tex += nz * 2 * md['tex']
        if md.get('emissive'):
            tval[sel] = 0.35 + 0.65 * facing[sel] + tex
        else:
            tval[sel] = shade[sel] + tex + md.get('spec', 0.0) * spec[sel]
    gm[idx] = mats
    gt[idx] = np.clip(tval, 0, 1).astype(np.float16)
    return gm.reshape(n, n), gt.reshape(n, n)


def team_lut(team, cname):
    """material -> (ramp, lo, hi) for one class in one team colour."""
    slots = dict(CLASSES[cname]['kit'], SKIN=CLASSES[cname]['skin'], TEAM=TEAMS[team]['TEAM'])
    ramp = np.zeros(len(MAT_NAMES), np.int32)
    lo = np.zeros(len(MAT_NAMES), f32)
    hi = np.zeros(len(MAT_NAMES), f32)
    for i, name in enumerate(MAT_NAMES):
        md = MATERIALS[name]
        r, a, b = md.get('ramp'), md['lo'], md['hi']
        if 'slot' in md:
            sv = slots[md['slot']]
            if isinstance(sv, tuple):
                r, a2, b2 = sv
                # remap the material's span proportionally into the override span
                a, b = a2 + (b2 - a2) * a / 15.0, a2 + (b2 - a2) * b / 15.0
            else:
                r = sv
        ramp[i], lo[i], hi[i] = RAMP_ID[r], a, b
    return ramp, lo, hi


def compose(gm, gt, lut):
    """reduce a supersampled g-buffer to an indexed CELLxCELL image (255 = transparent)."""
    ramp, lo, hi = lut
    valid = gm >= 0
    m = np.where(valid, gm, 0)
    r = ramp[m]
    pos = lo[m] + gt.astype(f32) * (hi[m] - lo[m])
    i0 = np.clip(np.floor(pos).astype(np.int32), 0, 15)
    i1 = np.minimum(i0 + 1, 15)
    fr = (pos - i0)[..., None]
    col = PAL_LIN[r * 16 + i0] * (1 - fr) + PAL_LIN[r * 16 + i1] * fr
    col *= valid[..., None]
    n = CELL
    colb = col.reshape(n, SS, n, SS, 3).sum((1, 3))
    cov = valid.reshape(n, SS, n, SS).sum((1, 3))
    bits = np.where(valid, np.left_shift(1, r), 0).astype(np.int64).reshape(n, SS, n, SS)
    bits = np.bitwise_or.reduce(np.bitwise_or.reduce(bits, axis=3), axis=1)
    avg = colb / np.maximum(cov, 1)[..., None]
    lab = lin_to_oklab(np.maximum(avg, 0)).reshape(-1, 3)
    dist = ((lab[:, None, :] - PAL_LAB[None, :, :]) ** 2).sum(2)
    ramp_of = np.arange(256) // 16
    allowed = (bits.reshape(-1, 1) >> ramp_of[None, :]) & 1
    allowed[:, TRANSPARENT] = 0
    dist = np.where(allowed > 0, dist, 1e9)
    out = dist.argmin(1).astype(np.uint8).reshape(n, n)
    out[cov < ALPHA_CUT] = TRANSPARENT
    if EDGE_DARKEN:
        solid = out != TRANSPARENT
        pad = np.pad(solid, 1, constant_values=False)
        edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        edge &= out < FULLBRIGHT_FIRST
        shade = out % 16
        out = np.where(edge, out - np.minimum(shade, EDGE_DARKEN), out).astype(np.uint8)
    return out


def measure(gm):
    """(height in m, team-colour share of the visible body) from a g-buffer."""
    rows = np.nonzero((gm >= 0).any(1))[0]
    if len(rows) == 0:
        return 0.0, 0.0
    top = rows[0] / SS
    height = (PIVOT[1] - top) / PPM / math.cos(CAM_PITCH)
    hit = gm >= 0
    team = np.isin(gm, TEAM_MATS)
    return height, float(team.sum()) / max(int(hit.sum()), 1)


def render_task(args):
    cname, anim, i, d = args
    warn = []
    parts = build(cname, make_pose(CLASSES[cname], anim, i), d * 45.0, warn)
    gm, gt = render_gbuffer(parts)
    return cname, (anim, i), d, gm, gt, warn


# ---------------------------------------------------------------- output
BG = (44, 46, 49)          # neutral grey backdrop for the composite sheets
INK = (214, 216, 218)
MUTED = (140, 144, 148)


def indexed_to_rgba(idx):
    rgba = np.zeros(idx.shape + (4,), np.uint8)
    rgba[..., :3] = PAL8[idx]
    rgba[..., 3] = np.where(idx == TRANSPARENT, 0, 255)
    return rgba


def flatten(idx, bg=BG):
    rgba = indexed_to_rgba(idx)
    al = rgba[..., 3:4] / 255.0
    return (rgba[..., :3] * al + np.array(bg) * (1 - al)).astype(np.uint8)


def silhouette(idx, bg=(150, 153, 156), fg=(20, 21, 23)):
    out = np.empty(idx.shape + (3,), np.uint8)
    out[:] = bg
    out[idx != TRANSPARENT] = fg
    return out


def save_indexed(idx, path):
    im = Image.frombytes('P', (idx.shape[1], idx.shape[0]), np.ascontiguousarray(idx).tobytes())
    im.putpalette(PAL8.ravel().tolist())
    im.save(path, transparency=TRANSPARENT, optimize=True)


def write_palette(out):
    os.makedirs(out, exist_ok=True)
    sw = np.repeat(np.repeat(PAL8.reshape(16, 16, 3), 12, 0), 12, 1)
    Image.fromarray(sw.astype(np.uint8)).save(os.path.join(out, 'palette.png'))
    with open(os.path.join(out, 'palette.lmp'), 'wb') as fh:      # Quake-style raw 768-byte palette
        fh.write(PAL8.astype(np.uint8).tobytes())
    with open(os.path.join(out, 'palette.gpl'), 'w') as fh:       # GIMP / Aseprite
        fh.write('GIMP Palette\nName: Chiip crew\nColumns: 16\n#\n')
        for i, c in enumerate(PAL8):
            fh.write(f'{c[0]:3d} {c[1]:3d} {c[2]:3d}\t{RAMPS[i // 16]}_{i % 16}\n')
    with open(os.path.join(out, 'palette.pal'), 'w') as fh:       # JASC-PAL
        fh.write('JASC-PAL\n0100\n256\n')
        for c in PAL8:
            fh.write(f'{c[0]} {c[1]} {c[2]}\n')


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:            # Pillow < 10.1
        return ImageFont.load_default()


def labelled(img, zoom, top, left, labels):
    """scale an RGB array by zoom (nearest) and add a label band on top and/or left."""
    big = Image.fromarray(np.repeat(np.repeat(img, zoom, 0), zoom, 1))
    canvas = Image.new('RGB', (big.width + left, big.height + top), BG)
    canvas.paste(big, (left, top))
    dr = ImageDraw.Draw(canvas)
    for (x, y, text, size, col) in labels:
        dr.text((x, y), text, fill=col, font=font(size))
    return canvas


def height_lines(img, x0, x1, heights=(1.7, 1.8, 1.9)):
    for h in heights:
        y = int(round(PIVOT[1] - h * PPM * math.cos(CAM_PITCH)))
        seg = img[y, x0:x1]
        bgmask = (seg == np.array(BG)).all(-1)
        seg[bgmask] = (70, 73, 77)
    return img


def write_lineup(out, classes, cells, crop=(10, 86)):
    """all classes side by side: blue, red, front silhouette, side silhouette."""
    a, b = crop
    cw = b - a
    rows = []
    for kind in ('blue', 'red', 'sil0', 'sil2'):
        row = []
        for c in classes:
            if kind in TEAMS:
                img = flatten(cells[(c, kind, ('idle', 0), 1)])
                img = height_lines(img, 0, CELL)
            else:
                d = int(kind[-1])
                img = silhouette(cells[(c, 'blue', ('idle', 0), d)])
            row.append(img[:, a:b])
        rows.append(np.concatenate(row, 1))
    grid = np.concatenate(rows, 0)
    zoom, top, left = 3, 56, 150
    labels = []
    for k, c in enumerate(classes):
        cd = CLASSES[c]
        x = left + k * cw * zoom + 8
        labels.append((x, 8, cd['title'], 22, INK))
        labels.append((x, 34, f"{cd['height']:.2f} m  ·  {WEAPONS[cd['weapon']]['title']}", 13, MUTED))
    for r, name in enumerate(('Blue (yours)', 'Red (enemy)', 'Front shape', 'Side shape')):
        labels.append((10, top + r * CELL * zoom + CELL * zoom // 2 - 10, name, 16, INK))
    for r in range(2):
        for h in (1.7, 1.8, 1.9):
            y = top + r * CELL * zoom + int(round(PIVOT[1] - h * PPM * math.cos(CAM_PITCH))) * zoom - 7
            labels.append((left - 34, y, f'{h:.1f}', 11, MUTED))
    labelled(grid, zoom, top, left, labels).save(os.path.join(out, 'lineup.png'))


def write_turnaround(out, c, cells, anims=('idle', 'aim')):
    rows, names = [], []
    for anim in anims:
        for team in TEAMS:
            if (c, team, (anim, 0), 0) not in cells:
                continue
            rows.append(np.concatenate([flatten(cells[(c, team, (anim, 0), d)]) for d in range(DIRS)], 1))
            names.append(f'{TEAMS[team]["title"]} · {anim.capitalize()}')
    grid = np.concatenate(rows, 0)
    zoom, top, left = 2, 60, 130
    cd = CLASSES[c]
    labels = [(left + 6, 8, f"{cd['title']}  ·  {cd['height']:.2f} m  ·  {WEAPONS[cd['weapon']]['title']}", 22, INK),
              (left + 6, 36, f"Perk: {cd['perk'][0]}. {cd['perk'][1]}", 13, MUTED)]
    dirnames = ['front', 'front-right', 'right', 'back-right', 'back', 'back-left', 'left', 'front-left']
    for r, name in enumerate(names):
        labels.append((10, top + r * CELL * zoom + CELL * zoom // 2 - 8, name, 14, INK))
    img = labelled(grid, zoom, top, left, labels)
    foot = Image.new('RGB', (img.width, 26), BG)
    dr = ImageDraw.Draw(foot)
    for d in range(DIRS):
        dr.text((left + d * CELL * zoom + 8, 4), f'{d} {dirnames[d]}', fill=MUTED, font=font(12))
    full = Image.new('RGB', (img.width, img.height + 26), BG)
    full.paste(img, (0, 0))
    full.paste(foot, (0, img.height))
    full.save(os.path.join(out, f'turnaround_{c}.png'))


def run_test(a):
    cname, anim, i = a.test[0], a.test[1], int(a.test[2])
    t0 = time.time()
    with Pool(min(a.jobs, 8)) as pool:
        res = pool.map(render_task, [(cname, anim, i, d) for d in range(DIRS)])
    row = []
    for team in TEAMS:
        lut = team_lut(team, cname)
        row.append(np.concatenate([flatten(compose(r[3], r[4], lut)) for r in res], 1))
    row.append(np.concatenate([silhouette(compose(r[3], r[4], team_lut('blue', cname))) for r in res], 1))
    img = np.concatenate(row, 0)
    big = np.repeat(np.repeat(img, 3, 0), 3, 1)
    os.makedirs(a.out, exist_ok=True)
    Image.fromarray(big).save(os.path.join(a.out, 'test.png'))
    for r in res:
        for wmsg in r[5]:
            print('warn', wmsg)
    h, share = measure(res[0][3])
    print(f'{cname} {anim} {i}: height {h:.2f} m (front), team colour {share * 100:.0f}% of the body (front), '
          f'{np.mean([measure(r[3])[1] for r in res]) * 100:.0f}% (all 8 directions)')
    print(f'rendered in {time.time() - t0:.1f}s -> {a.out}/test.png')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True, help='output folder; keep it outside the Godot project')
    ap.add_argument('--classes', default=','.join(CLASSES))
    ap.add_argument('--anims', default=','.join(a for a, _, _, _ in ANIMS),
                    help='comma-separated animations to render (the composite sheets need idle and aim)')
    ap.add_argument('--jobs', type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument('--test', nargs=3, metavar=('CLASS', 'ANIM', 'FRAME'))
    a = ap.parse_args()

    if a.test:
        run_test(a)
        return

    out = a.out
    classes = a.classes.split(',')
    anims = a.anims.split(',')
    frames = frame_list(anims)
    write_palette(out)
    tasks = [(c, an, i, d) for c in classes for (an, i) in frames for d in range(DIRS)]
    t0 = time.time()
    g = {}
    warns = set()
    with Pool(a.jobs) as pool:
        for k, (c, fr, d, gm, gt, wn) in enumerate(pool.imap_unordered(render_task, tasks, chunksize=2)):
            g[(c, fr, d)] = (gm, gt)
            warns.update(wn)
            if (k + 1) % 40 == 0 or k + 1 == len(tasks):
                print(f'  {k + 1}/{len(tasks)} frames  ({time.time() - t0:.0f}s)', flush=True)
    for wmsg in sorted(warns):
        print('warn', wmsg)

    meta = dict(
        generator='spritegen.py', cell=[CELL, CELL], pivot=list(PIVOT), pixels_per_metre=PPM,
        directions=DIRS,
        direction_note=('Columns are view directions. dir 0 = facing the camera, dir 2 = facing screen-right, '
                        'dir 4 = facing away, dir 6 = facing screen-left (45 deg steps, counter-clockwise seen from above). '
                        'dir = round((actor_yaw - angle_from_actor_to_camera) / 45deg) mod 8.'),
        palette=dict(file='palette.png', lmp='palette.lmp', transparent_index=TRANSPARENT,
                     fullbright_indices=[FULLBRIGHT_FIRST, 254],
                     ramps=RAMPS),
        animations={}, teams={k: dict(title=v['title'], blurb=v['blurb']) for k, v in TEAMS.items()},
        classes={})
    row = 0
    for name, nfr, fps, loop in ANIMS:
        if name in anims:
            meta['animations'][name] = dict(row=row, frames=nfr, fps=fps, loop=loop)
            row += nfr
    cells = {}
    for c in classes:
        cd = CLASSES[c]
        h, share = measure(g[(c, frames[0], 0)][0])
        meta['classes'][c] = dict(title=cd['title'], height=cd['height'], weapon=WEAPONS[cd['weapon']]['title'],
                                  perk=dict(name=cd['perk'][0], text=cd['perk'][1]),
                                  silhouette=cd['silhouette'], look=cd['look'],
                                  team_share=round(share, 3), sheets={})
        for team in TEAMS:
            lut = team_lut(team, c)
            sheet = np.full((len(frames) * CELL, DIRS * CELL), TRANSPARENT, np.uint8)
            for fi, fr in enumerate(frames):
                for d in range(DIRS):
                    gm, gt = g[(c, fr, d)]
                    cell = compose(gm, gt, lut)
                    cells[(c, team, fr, d)] = cell
                    sheet[fi * CELL:(fi + 1) * CELL, d * CELL:(d + 1) * CELL] = cell
            base = f'{c}_{team}'
            Image.fromarray(indexed_to_rgba(sheet)).save(os.path.join(out, base + '.png'), optimize=True)
            save_indexed(sheet, os.path.join(out, base + '_indexed.png'))
            meta['classes'][c]['sheets'][team] = dict(rgba=base + '.png', indexed=base + '_indexed.png',
                                                      size=[DIRS * CELL, len(frames) * CELL])
        if 'idle' in anims:
            write_turnaround(out, c, cells)
        print(f'  {cd["title"]}: {h:.2f} m tall in the render, team colour {share * 100:.0f}% of the front view')
    if 'idle' in anims:
        write_lineup(out, classes, cells)
    with open(os.path.join(out, 'sprites.json'), 'w') as fh:
        json.dump(meta, fh, indent=2)
    write_preview(out, meta)
    print(f'done in {time.time() - t0:.0f}s -> {out}/')


def write_preview(out, meta):
    """self-contained viewer: sheets are embedded as data URIs so the page works from disk."""
    tpl_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview_template.html')
    if not os.path.exists(tpl_path):
        return
    sheets = {}
    for c, cm in meta['classes'].items():
        sheets[c] = {}
        for team, sh in cm['sheets'].items():
            with open(os.path.join(out, sh['rgba']), 'rb') as fh:
                sheets[c][team] = 'data:image/png;base64,' + base64.b64encode(fh.read()).decode()
    data = dict(meta=meta, sheets=sheets, palette=PAL8.tolist())
    with open(tpl_path) as fh:
        html = fh.read().replace('__DATA__', json.dumps(data, separators=(',', ':')))
    with open(os.path.join(out, 'preview.html'), 'w') as fh:
        fh.write(html)


if __name__ == '__main__':
    main()
