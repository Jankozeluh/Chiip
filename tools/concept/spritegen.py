#!/usr/bin/env python3
"""
spritegen.py - Chiip concept-art tool: renders Doom/Quake-style 8-direction sprite
turnarounds of character designs (see docs/DECISIONS.md, "Characters stay rigged 3D
models; sprites are concept art").

Not part of the game. Chiip's characters are rigged 3D models; this tool is for
designing their looks quickly before they are modelled (PLAN.md, M6 task 1).

How it works: each class is built from signed-distance-field primitives hung on a
small skeleton (FK legs, 2-bone IK arms that grip the weapon), posed per animation
frame, ray-marched from 8 directions at 4x supersampling, then reduced to a
256-colour palette. Colours work like Quake's shirt/pants ranges: the render stores
material ids, and each team maps the TOP / BOTTOM / GEAR / ACCENT slots to ramps.

Prototype state: the two team palettes ("raiders" tan, "wardens" slate) predate
D-031 (no desert colours) and D-041 (your team blue, enemies red). M6 task 1
replaces them with a neutral kit plus blue/red team parts, and reshapes the
classes into the distinct crew (GAME_DESIGN.md, section 4.9).

Setup (once):  python3 -m venv ~/.venvs/chiip-tools
               ~/.venvs/chiip-tools/bin/pip install -r tools/concept/requirements.txt
Usage:         ~/.venvs/chiip-tools/bin/python tools/concept/spritegen.py --out <folder outside the project>
               ~/.venvs/chiip-tools/bin/python tools/concept/spritegen.py --test rifleman aim 0 --out <folder>
Output:        <out>/<class>_<team>.png (RGBA) and _indexed.png sheets (rows = frames,
               columns = 8 directions, 96x96 cells, feet pivot at 48,88), sprites.json,
               palette files, and preview.html (open it in a browser to spin the turnarounds).
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
from PIL import Image

f32 = np.float32
np.seterr(all="ignore")  # numpy 2.0 + macOS Accelerate raises spurious FP warnings in float32 matmul

# ---------------------------------------------------------------- render config
CELL = 96                 # sprite cell (px)
PIVOT = (48, 88)          # where the world origin (between the feet) lands in the cell
PPM = 34.0                # pixels per metre  (1.85 m operator ~ 63 px tall)
SS = 4                    # supersampling factor per axis
ALPHA_CUT = 6             # subsamples (of SS*SS) needed for an opaque pixel
EDGE_DARKEN = 2           # shades to darken silhouette pixels (0 = off)
CAM_PITCH = math.radians(8.0)
DIRS = 8
MAX_STEPS = 110

# ---------------------------------------------------------------- palette
RAMP_ANCHORS = [
    ('grey',     ['#09090c', '#2a292d', '#5a5757', '#9a958c', '#e2dbcb']),
    ('brown',    ['#100805', '#36200f', '#6a4224', '#a87447', '#e4bd8c']),
    ('tan',      ['#14100a', '#43351e', '#7d6a45', '#b8a578', '#f0e4c2']),
    ('olive',    ['#0a0c07', '#283016', '#4f5a2c', '#868f53', '#cbd199']),
    ('coyote',   ['#110c08', '#3a2a1b', '#6c5335', '#a5895f', '#ddcb9f']),
    ('skin_l',   ['#190b0a', '#562c22', '#9a6145', '#d49c78', '#f9dcc0']),
    ('skin_d',   ['#0e0605', '#331a12', '#5c3422', '#8e5b3c', '#c9946e']),
    ('red',      ['#150305', '#480b0d', '#8f1c17', '#d4492a', '#ffae7e']),
    ('blue',     ['#03061a', '#0d1e56', '#2246aa', '#4b88e6', '#b2deff']),
    ('slate',    ['#080a10', '#202838', '#435069', '#7b8aa0', '#c8d2de']),
    ('ink',      ['#040407', '#13151c', '#292d38', '#4d5463', '#8b92a0']),
    ('gunmetal', ['#06070a', '#1b1f26', '#39404a', '#6a7480', '#bac4ce']),
    ('brass',    ['#130b02', '#462f09', '#8a6517', '#d1a538', '#fff1a8']),
    ('foliage',  ['#050a04', '#192a10', '#385424', '#6c8c43', '#b9d68a']),
    ('fb_warm',  ['#3c0c00', '#8e2b00', '#e26c00', '#ffc63f', '#fffce2']),   # fullbright
    ('fb_cool',  ['#00200f', '#005a22', '#12b142', '#72ff92', '#e8fff0']),   # fullbright
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
# slot: team/class remappable ramp; ramp: fixed ramp. lo/hi: ramp span used by shading.
MATERIALS = {
    'top':        dict(slot='TOP',    lo=1, hi=14, tex=0.09, freq=22, camo=0.10),
    'bottom':     dict(slot='BOTTOM', lo=1, hi=13, tex=0.09, freq=22, camo=0.10),
    'gear':       dict(slot='GEAR',   lo=1, hi=13, tex=0.07, freq=30),
    'gear_dk':    dict(slot='GEAR',   lo=0, hi=9,  tex=0.07, freq=30),
    'accent':     dict(slot='ACCENT', lo=2, hi=15, tex=0.05, freq=25),
    'ghillie':    dict(slot='GHILLIE', lo=0, hi=14, tex=0.34, freq=34),
    'furn':       dict(slot='FURN',   lo=2, hi=13, tex=0.10, freq=30, spec=0.15),
    'boot':       dict(slot='BOOT',   lo=0, hi=9,  tex=0.05, freq=40, spec=0.10),
    'skin':       dict(slot='SKIN',   lo=2, hi=15, tex=0.03, freq=30, spec=0.08),
    'eye':        dict(ramp='grey',   lo=0, hi=2),
    'hair':       dict(ramp='brown',  lo=0, hi=6, tex=0.2, freq=70),
    'mask':       dict(ramp='ink',    lo=0, hi=12, tex=0.06, freq=40),
    'glove':      dict(ramp='grey',   lo=0, hi=8, tex=0.05, freq=40),
    'sole':       dict(ramp='grey',   lo=0, hi=4),
    'metal':      dict(ramp='gunmetal', lo=0, hi=12, tex=0.04, freq=50, spec=0.55),
    'polymer':    dict(ramp='grey',   lo=0, hi=8, tex=0.03, freq=50, spec=0.20),
    'lens':       dict(ramp='ink',    lo=0, hi=12, spec=1.0),
    'brass':      dict(ramp='brass',  lo=3, hi=15, spec=0.6),
    'glow':       dict(ramp='fb_cool', lo=8, hi=14, emissive=True),
    'flash':      dict(ramp='fb_warm', lo=4, hi=14, emissive=True, tex=0.35, freq=55),
    'flash_core': dict(ramp='fb_warm', lo=12, hi=15, emissive=True),
}
MAT_NAMES = list(MATERIALS)
MAT_ID = {n: i for i, n in enumerate(MAT_NAMES)}

TEAMS = {
    'raiders': dict(title='Raiders', blurb='Irregulars. Desert fatigues, olive webbing, wooden furniture, red armbands.',
                    TOP='tan', BOTTOM='coyote', GEAR='olive', ACCENT='red', GHILLIE='olive',
                    FURN=('brown', 2, 13), BOOT=('brown', 0, 9)),
    'wardens': dict(title='Wardens', blurb='Response unit. Slate and black kit, polymer furniture, blue armbands.',
                    TOP='slate', BOTTOM=('ink', 2, 15), GEAR=('grey', 1, 12), ACCENT='blue', GHILLIE=('grey', 1, 12),
                    FURN=('grey', 0, 8), BOOT=('ink', 0, 9)),
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


def S_shag(shape, amp=0.022, freq=28.0, seed=5):
    """noise-displaced surface (ghillie / shaggy cloth). distance is halved to keep sphere tracing safe."""
    fn, c, r = shape

    def f(q):
        return (fn(q) + amp * (2 * vnoise(q * freq, seed) - 1)) * f32(0.5)
    return f, c, r + amp


def S_at(shape, fr):
    """place a shape inside a local frame."""
    fn, c, r = shape
    R = fr.R.astype(f32)
    t = fr.t.astype(f32)
    return (lambda q: fn((q - t) @ R)), fr.pt(c), r


def S_sub(A, B):
    fa, c, r = A
    fb = B[0]
    return (lambda q: np.maximum(fa(q), -fb(q))), c, r


def S_cut(A, n, h):
    """keep the part of A where dot(q, n) >= h."""
    fa, c, r = A
    n = np.asarray(n, f32) / np.linalg.norm(n)
    return (lambda q: np.maximum(fa(q), h - q @ n)), c, r


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
WEAPON_SCALE = dict(ar=1.1, sniper=1.1, lmg=1.24, smg=1.12)   # drawn oversize so they read at sprite scale


def weapon_def(kind):
    """parts in weapon space: origin at the top of the pistol grip, +z down the barrel, +y up."""
    P = []

    def add(shape, fr, mat):
        P.append((shape, fr, mat))

    if kind == 'ar':          # assault rifle
        add(S_box(0.025, 0.040, 0.13, 0.012), T(0, 0.045, 0.05), 'metal')
        add(S_box(0.017, 0.012, 0.13, 0.005), T(0, 0.090, 0.06), 'metal')
        add(S_box(0.017, 0.022, 0.038, 0.008), T(0, 0.115, 0.07), 'polymer')
        add(S_box(0.028, 0.032, 0.10, 0.012), T(0, 0.050, 0.27), 'furn')
        add(S_cyl(0.016, 0.07), T(0, 0.055, 0.43), 'metal')
        add(S_cyl(0.020, 0.025, 0.005), T(0, 0.055, 0.51), 'metal')
        add(S_box(0.010, 0.026, 0.012, 0.004), T(0, 0.085, 0.36), 'metal')
        add(S_box(0.018, 0.075, 0.032, 0.008), T(0, -0.045, 0.11) @ Rt(rx(-0.32)), 'metal')
        add(S_box(0.016, 0.045, 0.021, 0.008), T(0, -0.025, -0.01) @ Rt(rx(0.35)), 'polymer')
        add(S_cyl(0.016, 0.06), T(0, 0.06, -0.12), 'metal')
        add(S_box(0.023, 0.045, 0.075, 0.014), T(0, 0.035, -0.20), 'furn')
        add(S_box(0.013, 0.034, 0.016, 0.006), T(0, 0.000, 0.27), 'polymer')
        pts = dict(R=(0, -0.02, -0.005), L=(0, -0.012, 0.27), muzzle=(0, 0.055, 0.54),
                   eject=(-0.03, 0.07, 0.06), flash=1.0)
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
        add(S_box(0.014, 0.014, 0.014, 0.005), T(0, 0.155, 0.05), 'metal')
        add(S_box(0.012, 0.024, 0.024, 0.005), T(0, 0.032, 0.06), 'metal')
        add(S_box(0.007, 0.007, 0.03, 0.006), T(-0.032, 0.062, 0.0) @ Rt(ry(-0.9)), 'metal')
        add(S_sph(0.012), T(-0.052, 0.062, -0.02), 'metal')
        add(S_box(0.017, 0.045, 0.022, 0.008), T(0, -0.025, -0.06) @ Rt(rx(0.35)), 'furn')
        for sx in (-0.012, 0.012):
            add(S_cyl(0.008, 0.11), T(sx, 0.005, 0.45), 'metal')
        pts = dict(R=(0, -0.022, -0.065), L=(0, 0.002, 0.25), muzzle=(0, 0.065, 0.72),
                   eject=(-0.03, 0.08, 0.05), flash=1.25)
    elif kind == 'lmg':       # belt-fed light machine gun with box mag
        add(S_box(0.036, 0.052, 0.16, 0.012), T(0, 0.050, 0.06), 'metal')
        add(S_box(0.034, 0.016, 0.09, 0.008), T(0, 0.108, 0.04), 'metal')
        add(S_box(0.009, 0.010, 0.055, 0.006), T(0, 0.160, 0.16), 'polymer')
        add(S_box(0.006, 0.022, 0.006, 0.004), T(0, 0.135, 0.12), 'metal')
        add(S_box(0.006, 0.022, 0.006, 0.004), T(0, 0.135, 0.20), 'metal')
        add(S_box(0.031, 0.036, 0.12, 0.012), T(0, 0.050, 0.30), 'furn')
        add(S_cyl(0.019, 0.14), T(0, 0.050, 0.54), 'metal')
        add(S_cyl(0.024, 0.03, 0.006), T(0, 0.050, 0.69), 'metal')
        add(S_box(0.050, 0.065, 0.065, 0.014), T(0.012, -0.065, 0.11), 'gear')
        add(S_box(0.017, 0.045, 0.022, 0.008), T(0, -0.028, -0.01) @ Rt(rx(0.35)), 'polymer')
        add(S_box(0.030, 0.055, 0.10, 0.016), T(0, 0.030, -0.17), 'furn')
        for sx in (-0.014, 0.014):
            add(S_cyl(0.009, 0.12), T(sx, 0.012, 0.52), 'metal')
        for i in range(4):
            add(S_box(0.006, 0.010, 0.009, 0.003), T(0.045, 0.012 + 0.018 * i, 0.09 - 0.012 * i), 'brass')
        pts = dict(R=(0, -0.025, -0.012), L=(0, 0.004, 0.23), muzzle=(0, 0.05, 0.72),
                   eject=(-0.04, 0.06, 0.07), flash=1.35)
    elif kind == 'smg':       # integrally suppressed SMG
        add(S_box(0.023, 0.040, 0.12, 0.012), T(0, 0.045, 0.04), 'metal')
        add(S_cyl(0.026, 0.13, 0.006), T(0, 0.050, 0.27), 'metal')
        add(S_box(0.027, 0.030, 0.05, 0.012), T(0, 0.030, 0.15), 'furn')
        add(S_box(0.015, 0.070, 0.022, 0.006), T(0, -0.060, 0.10) @ Rt(rx(-0.15)), 'metal')
        add(S_box(0.016, 0.045, 0.021, 0.008), T(0, -0.025, -0.01) @ Rt(rx(0.35)), 'polymer')
        for sx in (-0.016, 0.016):
            add(S_cyl(0.007, 0.07), T(sx, 0.055, -0.15), 'metal')
        add(S_box(0.025, 0.042, 0.012, 0.006), T(0, 0.040, -0.225), 'polymer')
        add(S_box(0.014, 0.018, 0.025, 0.006), T(0, 0.100, 0.04), 'polymer')
        pts = dict(R=(0, -0.02, -0.008), L=(0, 0.006, 0.16), muzzle=(0, 0.05, 0.41),
                   eject=(-0.03, 0.07, 0.05), flash=0.45)
    else:
        raise ValueError(kind)
    WS = WEAPON_SCALE[kind]
    out = []
    for shape, fr, mat in P:
        fn, c, r = shape
        # scale: evaluate shape at q/WS and multiply distance by WS
        sfn = (lambda f: (lambda q: f(q / f32(WS)) * f32(WS)))(fn)
        out.append(((sfn, np.asarray(c) * WS, r * WS), Frame(fr.R, fr.t * WS), mat))
    pts = {k: (np.array(v) * WS if isinstance(v, tuple) else v) for k, v in pts.items()}
    return out, pts


# ---------------------------------------------------------------- classes
CLASSES = {
    'rifleman': dict(
        title='Rifleman', role='Entry fragger / all-rounder', height=1.0, bulk=1.0, skin='skin_l',
        head='helmet', torso='carrier', back='hydration', weapon='ar',
        stats=dict(health=100, armor=100, speed=250, weapon='Assault rifle - 30 rnd, full auto'),
        feature=('Momentum', 'Every kill grants +10% move speed and instant recoil reset for 4 s. '
                 'Built to take first contact and keep the push rolling.'),
        look='High-cut helmet, ballistic glasses and headset, plate carrier with triple mag pouches, elbow/knee pads.'),
    'marksman': dict(
        title='Marksman', role='Long-range pick / overwatch', height=1.0, bulk=0.96, skin='skin_d',
        head='hood', torso='rig', back='mantle', weapon='sniper',
        stats=dict(health=100, armor=50, speed=230, weapon='Bolt-action rifle - 5 rnd, 4x/10x scope'),
        feature=('Deadeye', 'Hold breath while scoped for 3 s of zero sway. Any enemy you hit is marked '
                 'on your team\'s radar for 4 s. Moves 30% slower while scoped.'),
        look='Shaggy ghillie mantle and hood, team-colour shemagh over the face, lean chest rig, long scoped rifle.'),
    'heavy': dict(
        title='Heavy', role='Anchor / site holder', height=1.05, bulk=1.28, skin='skin_l',
        head='gasmask', torso='heavy', back='ammo', weapon='lmg',
        stats=dict(health=100, armor=200, speed=215, weapon='Belt-fed LMG - 100 rnd box'),
        feature=('Bulwark', 'Crouching braces the LMG: no recoil climb and 25% blast resistance while braced. '
                 'Footsteps are loud and he can\'t sprint.'),
        look='Bulky frame, full gas mask with front filter, heavy helmet with ear armour, pauldrons, front plates, ammo pack.'),
    'infiltrator': dict(
        title='Infiltrator', role='Lurker / objective runner', height=0.98, bulk=0.92, skin='skin_d',
        head='nvg', torso='slim', back='radio', weapon='smg',
        stats=dict(health=100, armor=25, speed=265, weapon='Suppressed SMG - 30 rnd'),
        feature=('Ghost Step', 'Silent footsteps at full speed, night-vision that sees through smoke, '
                 'and 30% faster bomb plant / defuse.'),
        look='Balaclava with glowing night-vision goggles, beanie, slim chest rig, radio pack with whip antenna, thigh holster.'),
}

# weapon holds, relative to the pelvis (x right = -x, y up, z forward), in metres + degrees
HOLDS = {
    'ar':     dict(idle=(-0.10, 0.30, 0.24, 40, 15, 0), run=(-0.08, 0.32, 0.24, 32, 20, 6),
                   aim=(-0.10, 0.52, 0.24, 0, 0, 0)),
    'sniper': dict(idle=(-0.12, 0.26, 0.22, 46, 20, 0), run=(-0.10, 0.30, 0.22, 40, 24, 6),
                   aim=(-0.10, 0.51, 0.22, 0, 0, 0)),
    'lmg':    dict(idle=(-0.07, 0.19, 0.23, 14, 12, 0), run=(-0.08, 0.18, 0.24, 18, 12, 0),
                   aim=(-0.11, 0.20, 0.26, -3, 3, 0)),
    'smg':    dict(idle=(-0.08, 0.30, 0.22, 45, 15, 0), run=(-0.07, 0.32, 0.22, 38, 18, 6),
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
FRAME_LIST = [(a, i) for a, n, _, _ in ANIMS for i in range(n)]


def base_pose():
    return dict(root_off=(0, 0, 0), root_pitch=0, root_roll=0, pelvis_yaw=0,
                chest_pitch=0, chest_yaw=0, chest_roll=0, head=(0, 0, 0),
                legL=(6, 5, 6, 0), legR=(-4, 5, 4, 0),
                weapon=('held', None), handR='grip', handL='fore',
                poleR=(-0.7, -1.0, -0.35), poleL=(0.6, -1.0, -0.2), flash=False)


def make_pose(cdef, anim, i):
    p = base_pose()
    H = HOLDS[cdef['weapon']]
    heavy = cdef['weapon'] == 'lmg'
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
        p.update(pelvis_yaw=-18, chest_yaw=-18, head=(6, 0, 8) if not heavy else (2, 0, 0),
                 legL=(12, 8, 10, -2), legR=(-10, 10, 8, 2))
        if heavy:
            p.update(pelvis_yaw=-12, chest_yaw=-14, chest_pitch=4)
        if anim.startswith('crouch'):
            p.update(legL=(84, 8, 92, 0), legR=(6, 10, 108, 62), chest_pitch=6 if not heavy else 10)
        if anim.endswith('fire'):
            kick = 1.6 if heavy else 1.0
            z -= 0.022 * kick
            pi -= 5 * kick
            p.update(flash=True, chest_pitch=p['chest_pitch'] - 2)
        p['weapon'] = ('held', (x, y, z, pi, ya, ro))
    elif anim == 'pain':
        x, y, z, pi, ya, ro = H['aim'] if not heavy else H['idle']
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


def build(cname, pose, yaw_deg, warn=None):
    cd = CLASSES[cname]
    s, w = cd['height'], cd['bulk']
    p = pose
    parts = []

    def add(shape, fr, mat, k=0.0, ground=True):
        parts.append(Part(shape, fr, mat, k, ground))

    F = Rt(ry(D(yaw_deg))) @ T(*p['root_off'])
    base = F @ T(0, 1.02 * s, 0) @ Rt(rx(D(p['root_pitch'])) @ rz(D(p['root_roll'])))
    pelvis = base @ Rt(ry(D(p['pelvis_yaw'])))
    chest = pelvis @ T(0, 0.10 * s, 0) @ Rt(rot(p['chest_pitch'], p['chest_yaw'], p['chest_roll']))
    hp, hy, hr = p['head']
    neck = chest.pt((0, 0.45 * s, 0.005))
    head = Frame(base.R @ rot(hp, hy, hr), neck)
    fwd_ref = base.vec((0, 0, 1))
    side_ref = base.vec((1, 0, 0))

    def limb(a, b, r1, r2, mat, k=0.025, ref=None):
        fr, L = seg_frame(np.asarray(a, float), np.asarray(b, float), side_ref if ref is None else ref)
        add(S_cone(L, r1, r2), fr, mat, k)
        return fr, L

    # ------------------------------------------------ legs
    for side, key in ((1, 'legL'), (-1, 'legR')):
        hf, abd, kf, toe = p[key]
        hip = pelvis.pt((side * 0.095 * w, -0.07 * s, 0))
        Rth = pelvis.R @ rz(D(side * abd)) @ rx(D(-hf))
        knee = hip + Rth @ np.array([0, -0.44 * s, 0])
        Rsh = Rth @ rx(D(kf))
        ankle = knee + Rsh @ np.array([0, -0.43 * s, 0])
        Rft = Rsh @ rx(D(hf - kf + toe))
        thigh = Frame(Rth, hip)
        shin = Frame(Rsh, knee)
        foot = Frame(Rft, ankle)
        add(S_cone(0.44 * s, 0.092 * w, 0.068 * w), Frame(Rth @ rz(math.pi), hip), 'bottom', 0.03)
        add(S_cone(0.43 * s, 0.065 * w, 0.050 * w), Frame(Rsh @ rz(math.pi), knee), 'bottom', 0.02)
        add(S_box(0.030 * w, 0.06, 0.05, 0.02), thigh @ T(side * 0.068 * w, -0.22 * s, 0.0), 'bottom', 0.01)
        kp = 1.25 if cd['torso'] == 'heavy' else 1.0
        if cd['torso'] in ('carrier', 'heavy', 'slim'):
            add(S_box(0.052 * w * kp, 0.058 * kp, 0.03, 0.022), shin @ T(0, -0.025, 0.052 * w), 'gear_dk', 0.006)
        if cd['torso'] == 'heavy':
            add(S_box(0.07 * w, 0.13, 0.03, 0.02), thigh @ T(0, -0.20, 0.075 * w), 'gear', 0.006)
            add(S_box(0.05 * w, 0.12, 0.028, 0.02), shin @ T(0, -0.20, 0.05 * w), 'gear', 0.006)
        if cd['torso'] == 'slim' and side == -1:
            add(S_box(0.022, 0.085, 0.052, 0.012), thigh @ T(-0.085 * w, -0.17, 0.01), 'polymer', 0.004)
            add(S_box(0.015, 0.03, 0.022, 0.006), thigh @ T(-0.088 * w, -0.06, 0.015), 'polymer')
        bw = 1.12 if cd['torso'] == 'heavy' else 1.0
        add(S_box(0.056 * bw, 0.075, 0.062 * bw, 0.03), shin @ T(0, -0.40 * s, 0.0), 'boot', 0.015)
        add(S_box(0.052 * bw, 0.042, 0.118 * bw, 0.03), foot @ T(0, -0.042, 0.05), 'boot', 0.015)
        add(S_box(0.055 * bw, 0.012, 0.124 * bw, 0.008), foot @ T(0, -0.078, 0.05), 'sole')

    # ------------------------------------------------ pelvis / torso
    add(S_box(0.145 * w, 0.085, 0.10 * w, 0.05), pelvis @ T(0, -0.02, 0), 'bottom', 0.03)
    add(S_ell(0.135 * w, 0.13, 0.095 * w), chest @ T(0, 0.08, 0), 'top', 0.03)
    add(S_box(0.172 * w, 0.13 * s, 0.108 * w, 0.07), chest @ T(0, 0.27 * s, 0), 'top', 0.03)
    for side in (1, -1):
        add(S_sph(0.074 * w), chest @ T(side * 0.18 * w, 0.37 * s, 0), 'top', 0.04)
    add(S_box(0.15 * w, 0.028, 0.11 * w, 0.02), pelvis @ T(0, 0.055, 0), 'gear_dk', 0.008)

    tor = cd['torso']
    if tor == 'carrier':
        add(S_box(0.168 * w, 0.15, 0.128, 0.04), chest @ T(0, 0.25, 0.004), 'gear', 0.01)
        for x in (-0.074, 0.0, 0.074):
            add(S_box(0.033, 0.05, 0.025, 0.012), chest @ T(x, 0.165, 0.132), 'gear_dk', 0.006)
        add(S_box(0.08, 0.03, 0.02, 0.01), chest @ T(0, 0.30, 0.13), 'gear', 0.006)
        for side in (1, -1):
            add(S_box(0.04, 0.03, 0.12, 0.015), chest @ T(side * 0.11, 0.40, 0), 'gear', 0.01)
        add(S_box(0.03, 0.06, 0.035, 0.012), chest @ T(0.168, 0.24, -0.02), 'polymer', 0.004)
        add(S_box(0.03, 0.04, 0.035, 0.012), pelvis @ T(0.16 * w, 0.02, 0.03), 'gear', 0.006)
        add(S_box(0.03, 0.07, 0.045, 0.012), pelvis @ T(-0.17 * w, -0.06, 0.0), 'polymer', 0.004)
    elif tor == 'rig':
        add(S_box(0.15 * w, 0.085, 0.125 * w, 0.035), chest @ T(0, 0.16, 0.0), 'gear', 0.01)
        for x in (-0.06, 0.06):
            add(S_box(0.04, 0.048, 0.025, 0.012), chest @ T(x, 0.15, 0.125 * w), 'gear_dk', 0.006)
        add(S_box(0.035, 0.05, 0.035, 0.014), pelvis @ T(0.16 * w, 0.0, -0.02), 'gear_dk', 0.006)
    elif tor == 'heavy':
        add(S_box(0.20 * w, 0.17, 0.155 * w, 0.05), chest @ T(0, 0.24, 0.0), 'gear', 0.01)
        add(S_ell(0.17 * w, 0.065, 0.15 * w), chest @ T(0, 0.41, -0.005), 'gear', 0.02)
        for yy in (0.27, 0.15):
            add(S_box(0.13 * w, 0.055, 0.025, 0.015), chest @ T(0, yy, 0.165 * w), 'gear_dk', 0.006)
        for side in (1, -1):
            add(S_ell(0.112 * w, 0.072, 0.118 * w), chest @ T(side * 0.235 * w, 0.40, 0) @ Rt(rz(-side * 0.45)), 'gear', 0.01)
            add(S_ell(0.114 * w, 0.03, 0.12 * w), chest @ T(side * 0.235 * w, 0.37, 0) @ Rt(rz(-side * 0.45)), 'gear_dk', 0.004)
        add(S_box(0.095 * w, 0.085, 0.025, 0.02), pelvis @ T(0, -0.10, 0.115 * w) @ Rt(rx(-0.1)), 'gear', 0.006)
        for side in (1, -1):
            add(S_box(0.035, 0.05, 0.04, 0.014), pelvis @ T(side * 0.165 * w, 0.0, 0.04), 'gear_dk', 0.006)
    elif tor == 'slim':
        add(S_box(0.145 * w, 0.09, 0.12 * w, 0.03), chest @ T(0, 0.17, 0.0), 'gear', 0.01)
        for x in (-0.055, 0.055):
            add(S_box(0.035, 0.045, 0.022, 0.012), chest @ T(x, 0.16, 0.12 * w), 'gear_dk', 0.006)
        add(S_cyl(0.013, 0.045, 0.005), chest @ T(0.075, 0.28, 0.125) @ Rt(rx(math.pi / 2)), 'polymer')
        for side in (1, -1):
            add(S_box(0.03, 0.02, 0.11, 0.01), chest @ T(side * 0.10, 0.40, 0), 'gear', 0.01)

    back = cd['back']
    if back == 'hydration':
        add(S_box(0.12, 0.15, 0.05, 0.04), chest @ T(0, 0.25, -0.155), 'gear', 0.01)
    elif back == 'mantle':
        add(S_shag(S_ell(0.25 * w, 0.115, 0.175), 0.026, 26, 1), chest @ T(0, 0.37, -0.02), 'ghillie', 0.03)
        add(S_shag(S_box(0.20, 0.19, 0.055, 0.05), 0.026, 26, 2), chest @ T(0, 0.20, -0.125) @ Rt(rx(-0.08)), 'ghillie', 0.03)
        add(S_shag(S_ell(0.12, 0.10, 0.06), 0.02, 26, 3), chest @ T(0, 0.30, 0.11), 'ghillie', 0.03)
    elif back == 'ammo':
        add(S_box(0.16 * w, 0.17, 0.08, 0.03), chest @ T(0, 0.24, -0.20 * w), 'gear_dk', 0.01)
        add(S_cyl(0.02, 0.09, 0.006), chest @ T(-0.17 * w, 0.06, -0.10) @ Rt(ry(0.4)), 'polymer')
    elif back == 'radio':
        add(S_box(0.11, 0.15, 0.055, 0.03), chest @ T(0, 0.24, -0.145), 'gear_dk', 0.01)
        a0 = chest.pt((0.075, 0.37, -0.16))
        a1 = chest.pt((0.10, 0.80, -0.25))
        limb(a0, a1, 0.011, 0.009, 'polymer', 0.0)

    # ------------------------------------------------ head
    add(S_box(0.05, 0.06, 0.05, 0.045), head @ T(0, 0.01, 0.0), 'skin', 0.03)
    hd = cd['head']
    skin_face = 'mask' if hd == 'nvg' else 'skin'
    add(S_ell(0.095, 0.115, 0.104), head @ T(0, 0.115, 0.005), skin_face, 0.02)
    add(S_box(0.066, 0.04, 0.066, 0.034), head @ T(0, 0.055, 0.03), skin_face, 0.02)
    add(S_ell(0.016, 0.024, 0.02), head @ T(0, 0.103, 0.104), skin_face, 0.01)
    for side in (1, -1):
        add(S_ell(0.014, 0.027, 0.02), head @ T(side * 0.09, 0.11, -0.005), skin_face, 0.01)
    if hd == 'nvg':
        add(S_box(0.062, 0.017, 0.02, 0.008), head @ T(0, 0.128, 0.088), 'skin', 0.004)
    for side in (1, -1):
        add(S_ell(0.017, 0.010, 0.012), head @ T(side * 0.034, 0.128, 0.091), 'eye')

    if hd == 'helmet':
        add(S_cut(S_at(S_ell(0.126, 0.116, 0.132), T(0, 0.137, -0.006)), (0, 1, -0.25), 0.140),
            head, 'gear', 0.004)
        add(S_box(0.024, 0.018, 0.012, 0.006), head @ T(0, 0.205, 0.118), 'polymer')
        for side in (1, -1):
            add(S_at(S_cyl(0.042, 0.022, 0.008), Rt(ry(math.pi / 2))), head @ T(side * 0.105, 0.11, -0.005), 'polymer')
        add(S_box(0.072, 0.016, 0.012, 0.008), head @ T(0, 0.128, 0.101), 'lens')
        add(S_box(0.045, 0.012, 0.03, 0.006), head @ T(0, 0.135, -0.11) @ Rt(rx(-0.4)), 'polymer')
    elif hd == 'hood':
        hood = S_sub(S_at(S_ell(0.128, 0.138, 0.128), T(0, 0.125, -0.018)),
                     S_at(S_ell(0.082, 0.092, 0.09), T(0, 0.112, 0.112)))
        add(S_shag(hood, 0.018, 30, 4), head, 'ghillie', 0.015)
        add(S_ell(0.104, 0.062, 0.104), head @ T(0, 0.048, 0.018), 'accent', 0.015)
        add(S_box(0.06, 0.09, 0.02, 0.02), head @ T(0.03, -0.04, 0.10) @ Rt(rz(0.2)), 'accent', 0.015)
    elif hd == 'gasmask':
        add(S_ell(0.084, 0.088, 0.072), head @ T(0, 0.088, 0.058), 'polymer', 0.01)
        for side in (1, -1):
            add(S_at(S_cyl(0.026, 0.008, 0.003), Rt(ry(side * 0.28))), head @ T(side * 0.036, 0.13, 0.095), 'lens')
        add(S_at(S_cyl(0.040, 0.032, 0.008), Rt(rx(0.6))), head @ T(0, 0.045, 0.14), 'polymer')
        add(S_cut(S_at(S_ell(0.135, 0.125, 0.14), T(0, 0.13, -0.008)), (0, 1, -0.18), 0.135),
            head, 'gear', 0.004)
        for side in (1, -1):
            add(S_at(S_cyl(0.048, 0.03, 0.01), Rt(ry(math.pi / 2))), head @ T(side * 0.115, 0.105, -0.01), 'gear_dk', 0.004)
        add(S_box(0.11, 0.02, 0.02, 0.008), head @ T(0, 0.185, 0.12), 'gear_dk')
    elif hd == 'nvg':
        add(S_cut(S_at(S_ell(0.104, 0.116, 0.111), T(0, 0.128, 0.002)), (0, 1, 0.05), 0.145), head, 'gear', 0.01)
        add(S_box(0.05, 0.022, 0.03, 0.01), head @ T(0, 0.172, 0.104), 'polymer', 0.004)
        for side in (1, -1):
            add(S_cyl(0.021, 0.036, 0.006), head @ T(side * 0.033, 0.13, 0.135), 'polymer', 0.004)
            add(S_cyl(0.017, 0.006), head @ T(side * 0.033, 0.13, 0.173), 'glow')

    # ------------------------------------------------ weapon
    wparts, wp = weapon_def(cd['weapon'])
    kind, hold = p['weapon']
    if kind == 'held':
        x, y, z, pi, ya, ro = hold
        Wf = base @ T(x * s, y * s, z) @ Rt(rot(pi, ya, ro))
    else:
        x, y, z, pi, ya, ro = hold
        Wf = F @ T(x, y, z) @ Rt(rot(pi, ya, ro))

    # ------------------------------------------------ arms (IK onto weapon or free targets)
    ua, fa = 0.29 * s, 0.27 * s + 0.05
    for side, hkey, pkey, gkey in ((-1, 'handR', 'poleR', 'R'), (1, 'handL', 'poleL', 'L')):
        S = chest.pt((side * 0.185 * w, 0.37 * s, 0))
        tgt = p[hkey]
        if tgt in ('grip', 'fore'):
            Tg = Wf.pt(wp[gkey])
        else:
            Tg = base.pt(np.array(tgt[1]) * [1, s, 1])
        E, Wr, over = ik(S, Tg, ua, fa, base.vec(p[pkey]))
        if over and warn is not None:
            warn.append(f'{cname}: {hkey} out of reach by {np.linalg.norm(Tg - S) - (ua + fa):.3f} m')
        fdir = norm(Wr - E)
        wrist = E + fdir * (fa - 0.05)
        limb(S, E, 0.063 * w, 0.053 * w, 'top', 0.03)
        limb(E, wrist, 0.051 * w, 0.042 * w, 'top', 0.02)
        u_fr, u_L = seg_frame(S, E, side_ref)
        add(S_cone(0.045 * s, 0.067 * w, 0.063 * w), u_fr @ T(0, 0.05 * s, 0), 'accent', 0.004)
        if tor in ('carrier', 'heavy'):
            add(S_sph(0.051 * w), Frame(np.eye(3), E), 'gear_dk', 0.006)
        h_fr, _ = seg_frame(wrist, wrist + fdir, side_ref)
        gs = 1.12 if tor == 'heavy' else 1.0
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
        if md.get('camo'):
            c = vnoise(q * 7.0 + 13.0, 3)
            tex -= md['camo'] * np.clip((c - 0.52) * 10, 0, 1)
        if md.get('emissive'):
            tval[sel] = 0.35 + 0.65 * facing[sel] + tex
        else:
            tval[sel] = shade[sel] + tex + md.get('spec', 0.0) * spec[sel]
    gm[idx] = mats
    gt[idx] = np.clip(tval, 0, 1).astype(np.float16)
    return gm.reshape(n, n), gt.reshape(n, n)


def team_lut(team, cname):
    tm = TEAMS[team]
    ramp = np.zeros(len(MAT_NAMES), np.int32)
    lo = np.zeros(len(MAT_NAMES), f32)
    hi = np.zeros(len(MAT_NAMES), f32)
    for i, name in enumerate(MAT_NAMES):
        md = MATERIALS[name]
        r, a, b = md.get('ramp'), md['lo'], md['hi']
        if 'slot' in md:
            sv = CLASSES[cname]['skin'] if md['slot'] == 'SKIN' else tm[md['slot']]
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


def render_task(args):
    cname, fi, d = args
    anim, i = FRAME_LIST[fi]
    warn = []
    parts = build(cname, make_pose(CLASSES[cname], anim, i), d * 45.0, warn)
    gm, gt = render_gbuffer(parts)
    return cname, fi, d, gm, gt, warn


# ---------------------------------------------------------------- output
def indexed_to_rgba(idx):
    rgba = np.zeros(idx.shape + (4,), np.uint8)
    rgba[..., :3] = PAL8[idx]
    rgba[..., 3] = np.where(idx == TRANSPARENT, 0, 255)
    return rgba


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
        fh.write('GIMP Palette\nName: Retro Ops\nColumns: 16\n#\n')
        for i, c in enumerate(PAL8):
            fh.write(f'{c[0]:3d} {c[1]:3d} {c[2]:3d}\t{RAMPS[i // 16]}_{i % 16}\n')
    with open(os.path.join(out, 'palette.pal'), 'w') as fh:       # JASC-PAL
        fh.write('JASC-PAL\n0100\n256\n')
        for c in PAL8:
            fh.write(f'{c[0]} {c[1]} {c[2]}\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True, help='output folder; keep it outside the Godot project')
    ap.add_argument('--classes', default=','.join(CLASSES))
    ap.add_argument('--jobs', type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument('--test', nargs=3, metavar=('CLASS', 'ANIM', 'FRAME'))
    a = ap.parse_args()

    if a.test:
        cname, anim, i = a.test[0], a.test[1], int(a.test[2])
        fi = FRAME_LIST.index((anim, i))
        t0 = time.time()
        with Pool(min(a.jobs, 8)) as pool:
            res = pool.map(render_task, [(cname, fi, d) for d in range(DIRS)])
        row = []
        for team in TEAMS:
            lut = team_lut(team, cname)
            row.append(np.concatenate([compose(r[3], r[4], lut) for r in res], 1))
        img = indexed_to_rgba(np.concatenate(row, 0))
        bg = np.zeros_like(img)
        bg[..., :3] = (58, 52, 46)
        bg[..., 3] = 255
        al = img[..., 3:4] / 255.0
        comp = (img[..., :3] * al + bg[..., :3] * (1 - al)).astype(np.uint8)
        big = np.repeat(np.repeat(comp, 3, 0), 3, 1)
        os.makedirs(a.out, exist_ok=True)
        Image.fromarray(big).save(os.path.join(a.out, 'test.png'))
        for r in res:
            for wmsg in r[5]:
                print('warn', wmsg)
        print(f'rendered in {time.time() - t0:.1f}s -> {a.out}/test.png')
        return

    out = a.out
    classes = a.classes.split(',')
    write_palette(out)
    tasks = [(c, fi, d) for c in classes for fi in range(len(FRAME_LIST)) for d in range(DIRS)]
    t0 = time.time()
    g = {}
    warns = set()
    with Pool(a.jobs) as pool:
        for k, (c, fi, d, gm, gt, wn) in enumerate(pool.imap_unordered(render_task, tasks, chunksize=2)):
            g[(c, fi, d)] = (gm, gt)
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
        meta['animations'][name] = dict(row=row, frames=nfr, fps=fps, loop=loop)
        row += nfr
    for c in classes:
        cd = CLASSES[c]
        meta['classes'][c] = dict(title=cd['title'], role=cd['role'], stats=cd['stats'],
                                  feature=dict(name=cd['feature'][0], text=cd['feature'][1]),
                                  look=cd['look'], sheets={})
        for team in TEAMS:
            lut = team_lut(team, c)
            sheet = np.full((len(FRAME_LIST) * CELL, DIRS * CELL), TRANSPARENT, np.uint8)
            for fi in range(len(FRAME_LIST)):
                for d in range(DIRS):
                    gm, gt = g[(c, fi, d)]
                    sheet[fi * CELL:(fi + 1) * CELL, d * CELL:(d + 1) * CELL] = compose(gm, gt, lut)
            base = f'{c}_{team}'
            Image.fromarray(indexed_to_rgba(sheet)).save(os.path.join(out, base + '.png'), optimize=True)
            save_indexed(sheet, os.path.join(out, base + '_indexed.png'))
            meta['classes'][c]['sheets'][team] = dict(rgba=base + '.png', indexed=base + '_indexed.png',
                                                      size=[DIRS * CELL, len(FRAME_LIST) * CELL])
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
