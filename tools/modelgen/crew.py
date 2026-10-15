"""
crew.py - the part lists of Chiip's four classes (D-052, D-053, D-070).

The looks, heights, builds and kits are the approved concept sheets: the class table
(CLASSES, with each class's kit of ramps) is imported from tools/concept/spritegen.py, so
a colour or a height changes in one place. The shapes here are the same pieces as the
concept's, turned into low-poly parts on bones (Godot's axes: facing -Z, right +X).

parts(name, s) returns every Piece of a class with body scale s; class_scale() finds the
s at which the class stands its concept height in the rest pose.

Hit zones: every piece names the zone it belongs to (head, chest, stomach, arms, legs).
Gear sits in the zone of the body it covers; the gun, the antenna and small trinkets have
none (D-055).
"""
from geometry import Piece
from paint import concept
from rig import Body

CLASSES = concept.CLASSES


def body_of(name, s):
    cd = CLASSES[name]
    return Body(s, cd['legs'], cd['bulk'], cd['hunch'])


def parts(name, s):
    cd = CLASSES[name]
    b = body_of(name, s)
    w, sl = b.w, b.sl
    tor, hd, back = cd['torso'], cd['head'], cd['back']
    P = []

    def add(bone, shape, size, pos=(0, 0, 0), mat='top', zone=None, **kw):
        P.append(Piece(bone, shape, size, pos, mat=mat, zone=zone, **kw))

    # ------------------------------------------------------------ legs
    for side, x in (('l', -1), ('r', 1)):
        thigh, shin, foot = 'thigh_' + side, 'shin_' + side, 'foot_' + side
        add(thigh, 'cyl', (0.092 * w, 0.068 * w, b.thigh), axis='-y', mat='bottom', zone='legs')
        add(thigh, 'box', (0.06 * w, 0.12, 0.10), (x * 0.068 * w, -0.22 * sl, 0), 'bottom', 'legs', bevel=0.015)
        add(shin, 'cyl', (0.065 * w, 0.050 * w, b.shin), axis='-y', mat='bottom', zone='legs')
        if tor in ('carrier', 'heavy', 'slim'):
            kp = 1.25 if tor == 'heavy' else 1.0
            add(shin, 'box', (0.104 * w * kp, 0.116 * kp, 0.06), (0, -0.025, -0.052 * w), 'gear_dk', 'legs', bevel=0.02)
        bw = 1.12 if tor == 'heavy' else 1.0
        add(shin, 'box', (0.112 * bw, 0.15, 0.124 * bw), (0, -b.shin + 0.03, 0), 'boot', 'legs', bevel=0.02)
        add(foot, 'box', (0.104 * bw, 0.084, 0.236 * bw), (0, -0.042, -0.05), 'boot', 'legs', bevel=0.02)
        add(foot, 'box', (0.11 * bw, 0.024, 0.248 * bw), (0, -0.078, -0.05), 'sole', 'legs', bevel=0.006)

    # ------------------------------------------------------------ pelvis and torso
    add('hips', 'box', (0.29 * w, 0.17, 0.20 * w), (0, -0.02, 0), 'bottom', 'stomach', bevel=0.03)
    add('hips', 'box', (0.30 * w, 0.056, 0.22 * w), (0, 0.055, 0), 'gear_dk', 'stomach', bevel=0.012)
    add('spine', 'box', (0.27 * w, 0.24, 0.19 * w), (0, 0.08, 0), 'top', 'stomach', bevel=0.045)
    cy = -0.20 * s                       # concept chest-frame heights -> the chest bone
    add('chest', 'box', (0.344 * w, 0.26 * s, 0.216 * w), (0, 0.07 * s, 0), 'top', 'chest', bevel=0.05)
    for x in (-1, 1):
        add('chest', 'ell', (0.074 * w,) * 3, (x * 0.18 * w, 0.17 * s, 0), 'top', 'chest', sides=8, rings=4)

    if tor == 'carrier':
        add('chest', 'box', (0.336 * w, 0.30, 0.256 * w), (0, cy + 0.25, -0.004), 'gear', 'chest', bevel=0.03)
        for x in (-0.074, 0.0, 0.074):
            add('chest', 'box', (0.066, 0.10, 0.05), (x * w, cy + 0.165, -0.132 * w), 'gear_dk', 'chest', bevel=0.012)
        add('chest', 'box', (0.16, 0.06, 0.04), (0, cy + 0.30, -0.13 * w), 'gear', 'chest', bevel=0.01)
        for x in (-1, 1):
            add('chest', 'box', (0.08, 0.06, 0.24), (x * 0.11 * w, cy + 0.40, 0), 'gear', 'chest', bevel=0.015)
        add('chest', 'box', (0.06, 0.12, 0.07), (-0.168 * w, cy + 0.24, 0.02), 'polymer', 'chest', bevel=0.012)
        add('hips', 'box', (0.06, 0.08, 0.07), (-0.16 * w, 0.02, -0.03), 'gear', 'stomach', bevel=0.012)
        add('hips', 'box', (0.06, 0.14, 0.09), (0.17 * w, -0.06, 0.0), 'polymer', 'stomach', bevel=0.012)

    if back == 'hydration':
        add('chest', 'box', (0.24, 0.30, 0.10), (0, cy + 0.25, 0.155 * w), 'gear', 'chest', bevel=0.03)

    # ------------------------------------------------------------ head
    face = 'mask' if hd == 'beanie' else 'skin'
    add('head', 'box', (0.10, 0.12, 0.10), (0, 0.01, 0), face, 'head', bevel=0.03)
    eyes = (lambda x, y, z, f: f == '-z' and abs(abs(x) - 0.034) < 0.014 and abs(y - 0.013) < 0.009, 'eye')
    brows = (lambda x, y, z, f: f == '-z' and abs(abs(x) - 0.034) < 0.02 and 0.027 < y < 0.036, 'brow')
    mouth = (lambda x, y, z, f: f == '-z' and abs(x) < 0.024 and -0.052 < y < -0.044, 'brow')
    add('head', 'ell', (0.095, 0.115, 0.104), (0, 0.115, -0.005), face, 'head', sides=8, rings=6,
        decals=[eyes, brows, mouth] if face == 'skin' else [eyes])
    add('head', 'box', (0.132, 0.08, 0.132), (0, 0.055, -0.03), face, 'head', bevel=0.03)
    add('head', 'box', (0.032, 0.048, 0.04), (0, 0.103, -0.104), face, 'head', bevel=0.01)

    if hd == 'helmet':
        stripe = (lambda x, y, z, f: abs(x) < 0.026 and f in ('+y', '-z', '+z'), 'team')
        add('head', 'dome', (0.126, 0.116, 0.132), (0, 0.137, 0.006), 'gear', 'head', sides=10, rings=6,
            clip=((0, 1, -0.12), 0.02), decals=[stripe])
        add('head', 'box', (0.048, 0.036, 0.024), (0, 0.205, -0.118), 'polymer', 'head', bevel=0.008)
        for x, ax in ((-1, '-x'), (1, '+x')):
            add('head', 'cyl', (0.042, 0.042, 0.044), (x * 0.083, 0.11, 0.005), 'polymer', 'head', axis=ax, sides=8)
        add('head', 'box', (0.152, 0.044, 0.032), (0, 0.128, -0.098), 'polymer', 'head', bevel=0.012)
        for x in (-1, 1):
            add('head', 'box', (0.054, 0.03, 0.012), (x * 0.034, 0.128, -0.113), 'lens', 'head', bevel=0.004)

    # ------------------------------------------------------------ arms (T-pose: along -X / +X)
    for side, x, ax in (('l', -1, '-x'), ('r', 1, '+x')):
        add('upper_arm_' + side, 'cyl', (0.063 * w, 0.053 * w, b.upper_arm), axis=ax, mat='sleeve', zone='arms')
        add('forearm_' + side, 'cyl', (0.051 * w, 0.042 * w, b.forearm), axis=ax, mat='sleeve', zone='arms')
        if tor in ('carrier', 'heavy'):
            add('forearm_' + side, 'ell', (0.051 * w,) * 3, (0, 0, 0), 'gear_dk', 'arms', sides=8, rings=4)
        gs = 1.12 if tor == 'heavy' else 1.0
        add('hand_' + side, 'ell', (0.052 * gs, 0.032 * gs, 0.038 * gs), (x * 0.04, 0, 0), 'glove', 'arms',
            sides=8, rings=4)
    return P


def height(pieces, s, name):
    """top of the head or headgear in the rest pose."""
    from geometry import shape_polys
    import numpy as np
    rest = body_of(name, s).rest_globals()
    top = 0.0
    for p in pieces:
        if not p.tall:
            continue
        rot, pos = rest[p.bone]
        basis = p.basis()
        for pts, _ in shape_polys(p):
            for q in pts:
                top = max(top, float((pos + rot @ (p.pos + basis @ np.asarray(q)))[1]))
    return top


def class_scale(name):
    """the body scale at which the class stands its concept height (the head keeps its
    size, so a few rounds of scaling by target / measured settle on it)."""
    s = 1.0
    for _ in range(5):
        s *= CLASSES[name]['height'] / height(parts(name, s), s, name)
    return s
