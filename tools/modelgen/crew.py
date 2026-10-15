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
import numpy as np

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
        if tor == 'heavy':
            add(thigh, 'box', (0.14 * w, 0.26, 0.06), (0, -0.20, -0.075 * w), 'plate', 'legs', bevel=0.015)
            add(shin, 'box', (0.10 * w, 0.24, 0.056), (0, -0.20, -0.05 * w), 'plate', 'legs', bevel=0.015)
        if tor == 'slim' and side == 'r':
            add(thigh, 'box', (0.044, 0.17, 0.104), (0.085 * w, -0.17, -0.01), 'polymer', 'legs', bevel=0.01)
            add(thigh, 'box', (0.03, 0.06, 0.044), (0.088 * w, -0.06, -0.015), 'polymer', 'legs', bevel=0.006)
        if cd.get('coat'):
            # knee-length coat: one flap per thigh, so it swings with the leg like a segmented model
            add(thigh, 'box', (0.216 * w, 0.48 * sl, 0.232 * w), (x * 0.012, -0.19 * sl, 0.006), 'coat', 'legs', bevel=0.03)
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

    elif tor == 'rig':
        add('chest', 'box', (0.30 * w, 0.17, 0.25 * w), (0, cy + 0.16, 0), 'gear', 'chest', bevel=0.03)
        for x in (-0.06, 0.06):
            add('chest', 'box', (0.08, 0.096, 0.05), (x, cy + 0.15, -0.125 * w), 'gear_dk', 'chest', bevel=0.012)
        add('hips', 'box', (0.07, 0.10, 0.07), (-0.16 * w, 0.0, 0.02), 'gear_dk', 'stomach', bevel=0.012)
    elif tor == 'heavy':
        add('chest', 'box', (0.40 * w, 0.34, 0.31 * w), (0, cy + 0.24, 0), 'plate', 'chest', bevel=0.04)
        add('chest', 'ell', (0.17 * w, 0.065, 0.15 * w), (0, cy + 0.41, 0.005), 'gear', 'chest', sides=10, rings=4)
        for yy in (0.27, 0.15):
            add('chest', 'box', (0.26 * w, 0.11, 0.05), (0, cy + yy, -0.165 * w), 'gear_dk', 'chest', bevel=0.015)
        for x in (-1, 1):
            # shoulder plates, sloping down and out, edged in team colour
            add('chest', 'ell', (0.112 * w, 0.072, 0.118 * w), (x * 0.235 * w, cy + 0.40, 0), 'plate', 'chest',
                rot=(0, 0, -x * 25.8), sides=10, rings=4)
            add('chest', 'ell', (0.118 * w, 0.03, 0.124 * w), (x * 0.235 * w, cy + 0.37, 0), 'team', 'chest',
                rot=(0, 0, -x * 25.8), sides=10, rings=4)
        add('hips', 'box', (0.19 * w, 0.17, 0.05), (0, -0.10, -0.115 * w), 'plate', 'stomach', rot=(5.7, 0, 0), bevel=0.015)
        for x in (-1, 1):
            add('hips', 'box', (0.07, 0.10, 0.08), (x * 0.165 * w, 0.0, -0.04), 'gear_dk', 'stomach', bevel=0.012)
    elif tor == 'slim':
        add('chest', 'box', (0.29 * w, 0.18, 0.24 * w), (0, cy + 0.17, 0), 'gear', 'chest', bevel=0.025)
        for x in (-0.055, 0.055):
            add('chest', 'box', (0.07, 0.09, 0.044), (x, cy + 0.16, -0.12 * w), 'gear_dk', 'chest', bevel=0.01)
        for x in (-1, 1):
            add('chest', 'box', (0.06, 0.04, 0.22), (x * 0.10, cy + 0.40, 0), 'gear', 'chest', bevel=0.01)

    if cd.get('coat'):
        add('hips', 'box', (0.336 * w, 0.22, 0.244 * w), (0, -0.035, 0), 'coat', 'stomach', bevel=0.04)
        add('chest', 'ell', (0.125 * w, 0.06, 0.11 * w), (0, cy + 0.42 * s, 0.01), 'coat', 'chest', sides=10, rings=4)
        # a team-colour panel across the upper back, so the team also reads from behind
        add('chest', 'box', (0.30 * w, 0.15, 0.06), (0, cy + 0.33 * s, 0.112 * w), 'team', 'chest', bevel=0.02)

    if back == 'hydration':
        add('chest', 'box', (0.24, 0.30, 0.10), (0, cy + 0.25, 0.155 * w), 'gear', 'chest', bevel=0.03)
    elif back == 'ammo':
        add('chest', 'box', (0.32 * w, 0.34, 0.16), (0, cy + 0.24, 0.20 * w), 'gear_dk', 'chest', bevel=0.03)
    elif back == 'radio':
        add('chest', 'box', (0.22, 0.30, 0.11), (0, cy + 0.24, 0.145), 'gear_dk', 'chest', bevel=0.03)
        a0 = np.array([-0.075, cy + 0.37, 0.16])
        a1 = np.array([-0.10, cy + 0.80, 0.25])
        add('chest', 'cyl', (0.011, 0.009, float(np.linalg.norm(a1 - a0))), tuple(a0), 'polymer', None,
            axis=tuple(a1 - a0), sides=5, tall=False)

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

    elif hd == 'gasmask':
        add('head', 'ell', (0.084, 0.088, 0.072), (0, 0.088, -0.058), 'polymer', 'head', sides=8, rings=5)
        for x in (-1, 1):
            add('head', 'cyl', (0.026, 0.026, 0.016), (x * 0.036, 0.13, -0.087), 'lens', 'head', axis='-z', sides=8)
        add('head', 'cyl', (0.040, 0.036, 0.064), (0, 0.065, -0.115), 'polymer', 'head', axis='-z', rot=(-30, 0, 0), sides=8)
        stripe = (lambda x, y, z, f: abs(x) < 0.03 and f in ('+y', '-z', '+z'), 'team')
        add('head', 'dome', (0.138, 0.128, 0.143), (0, 0.13, 0.008), 'gear', 'head', sides=10, rings=6,
            clip=((0, 1, 0.18), -0.0013), decals=[stripe])
        for x, ax in ((-1, '-x'), (1, '+x')):
            add('head', 'cyl', (0.050, 0.050, 0.064), (x * 0.085, 0.105, 0.01), 'gear_dk', 'head', axis=ax, sides=8)
        add('head', 'box', (0.22, 0.04, 0.04), (0, 0.185, -0.122), 'gear_dk', 'head', bevel=0.01)
    elif hd == 'hood':
        add('head', 'dome', (0.128, 0.138, 0.128), (0, 0.125, 0.018), 'coat', 'head', sides=10, rings=6,
            clip=((0, 0.25, 1.0), -0.06))
        add('head', 'ell', (0.104, 0.062, 0.104), (0, 0.048, -0.018), 'team', 'head', sides=8, rings=4)
        add('chest', 'ell', (0.12 * w, 0.055, 0.112 * w), (0, cy + 0.43 * s, -0.01), 'team', 'chest', sides=10, rings=4)
        add('chest', 'box', (0.096, 0.24, 0.036), (-0.06 * w, cy + 0.31 * s, -0.15 * w), 'team', 'chest',
            rot=(0, 0, -6.9), bevel=0.012)
    elif hd == 'beanie':
        add('head', 'dome', (0.104, 0.120, 0.111), (0, 0.135, 0.004), 'knit', 'head', sides=10, rings=6,
            clip=((0, 1, -0.08), 0.0308))
        add('head', 'cyl', (0.105, 0.103, 0.032), (0, 0.157, 0.004), 'knit', 'head', axis='+y', sides=10)
        add('head', 'box', (0.124, 0.034, 0.04), (0, 0.128, -0.088), 'skin', 'head', bevel=0.008)
        add('head', 'box', (0.136, 0.044, 0.04), (0, 0.128, -0.094), 'polymer', 'head', bevel=0.012)
        for x in (-1, 1):
            add('head', 'cyl', (0.021, 0.021, 0.032), (x * 0.033, 0.128, -0.094), 'polymer', 'head', axis='-z', sides=8)
            add('head', 'cyl', (0.017, 0.017, 0.010), (x * 0.033, 0.128, -0.124), 'glow', 'head', axis='-z', sides=8)

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
