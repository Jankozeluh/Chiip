"""
props_urban.py - the map kit's urban, interior, nature and debris props (D-122, M10).

Part lists in the style of props.py (read its docstring): pieces in prop space, metres, +Y up,
standing on y = 0, centred on x = z = 0, the front facing -Z. Every part uses a material of
props.MATERIALS. Solid props get collision boxes that hug their shape; tiny clutter (cones,
grass, debris) is decoration without collision.
"""
import math

import numpy as np

from geometry import Piece, rot as _rot
from props import BONE, box, cyl, ell, moved, prop  # noqa: F401


# ---------------------------------------------------------------- helpers
def _dir(tilt, yaw):
    """the direction +Y points to after rot(0, yaw, tilt): leaned `tilt` degrees towards -x
    (yaw 0), then turned by `yaw` about +Y (90 leans towards +z, 180 towards +x, 270 towards -z)."""
    t, y = math.radians(tilt), math.radians(yaw)
    return np.array([-math.sin(t) * math.cos(y), math.cos(t), math.sin(t) * math.sin(y)])


def _stalk(base, tilt, yaw, length):
    """(centre, rot) for a box or ellipsoid whose long (y) axis starts at `base` and leans."""
    return tuple(np.asarray(base, float) + _dir(tilt, yaw) * length / 2), (0, yaw, tilt)


def _tip(base, tilt, yaw, length):
    """where a stalk from `base` ends."""
    return tuple(np.asarray(base, float) + _dir(tilt, yaw) * length)


def _ground_box(size, x, z, mat, rot=(0, 0, 0), bevel=0.01, y0=0.0, decals=()):
    """a (possibly tumbled) box resting on the surface at height y0: its lowest corner touches it."""
    r = _rot(*rot)
    lift = float(np.sum(np.abs(r[1]) * np.asarray(size, float) / 2)) - 0.4 * bevel
    return box(size, (x, y0 + lift, z), mat, bevel, rot, decals)


def _dome(radii, pos, mat, cut, sides=8, rings=5, rot=(0, 0, 0)):
    """an ellipsoid pressed flat below y = cut (in its own frame): a lump with a flat bottom."""
    return Piece(BONE, 'dome', radii, pos, rot, mat=mat, sides=sides, rings=rings, clip=((0, 1, 0), cut))


def _tilted_box(size, base, pitch, mat, bevel=0.0, along=0.0, off=0.0):
    """a box tilted back by `pitch` degrees (its top towards +z) about base; `along` and `off` slide
    it along the tilted up axis and along the tilted front normal."""
    p = math.radians(pitch)
    up = np.array([0, math.cos(p), math.sin(p)])
    front = np.array([0, math.sin(p), -math.cos(p)])
    return box(size, np.asarray(base, float) + up * along + front * off, mat, bevel, (pitch, 0, 0))


# ================================================================ urban
@prop('bench', 'urban', 'Park bench, 2 m: low cover you can jump onto, with a backrest to shoot over.', surface='wood')
def bench():
    P = []
    for z in (-0.145, 0.0, 0.145):
        P.append(box((1.96, 0.04, 0.12), (0, 0.43, z), 'wood', bevel=0.008))               # seat slats
    for s in (0.12, 0.26, 0.40):
        P.append(_tilted_box((1.96, 0.12, 0.03), (0, 0.41, 0.19), 14, 'wood', along=s, off=0.035))
    for x in (-0.9, 0.9):
        P.append(box((0.05, 0.64, 0.05), (x, 0.32, -0.2), 'metal_dk', bevel=0))             # front leg + arm post
        P.append(box((0.05, 0.41, 0.05), (x, 0.205, 0.17), 'metal_dk', bevel=0))            # rear leg
        P.append(box((0.05, 0.04, 0.46), (x, 0.39, 0.0), 'metal_dk', bevel=0))              # seat rail
        P.append(_tilted_box((0.05, 0.46, 0.04), (x, 0.41, 0.19), 14, 'metal_dk', along=0.23))   # back post
        P.append(box((0.06, 0.04, 0.50), (x, 0.66, 0.0), 'metal_dk', bevel=0))              # armrest
    return moved(P, (0, 0, -0.06))


@prop('trash_can', 'urban', 'Street litter bin, 0.95 m: a small obstacle, low cover.', surface='metal')
def trash_can():
    return [cyl(0.26, 0.05, (0, 0, 0), 'metal_dk', sides=12),                                 # foot ring
            cyl(0.25, 0.78, (0, 0.05, 0), 'paint_grey', radius_end=0.272, sides=12),          # body
            cyl(0.272, 0.03, (0, 0.40, 0), 'metal_dk', sides=12),                             # band
            box((0.2, 0.1, 0.02), (0, 0.68, -0.262), 'black', bevel=0),                       # opening
            cyl(0.285, 0.05, (0, 0.81, 0), 'metal_dk', sides=12),                             # rim
            cyl(0.28, 0.07, (0, 0.86, 0), 'metal_dk', radius_end=0.2, sides=12),              # lid
            cyl(0.04, 0.02, (0, 0.93, 0), 'metal', sides=6)]


@prop('dumpster', 'urban', 'Olive steel dumpster, 1.9 x 1.1 m, one lid ajar: tall cover you can jump onto.',
      surface='metal')
def dumpster():
    P = []
    for x in (-0.8, 0.8):
        P.append(box((0.08, 0.1, 1.1), (x, 0.11, 0), 'metal_dk', bevel=0))                    # skids
        P.append(cyl(0.08, 0.06, (x - 0.03, 0.08, 0.5), 'rubber', axis='+x', sides=8))        # rear wheels
    P.append(box((1.86, 0.78, 1.2), (0, 0.55, 0), 'olive_ribs', bevel=0.02))                  # body
    P.append(box((1.9, 0.05, 1.24), (0, 0.955, 0), 'metal_dk', bevel=0.01))                   # rim
    for x in (-0.6, 0.6):
        P.append(box((0.3, 0.05, 0.01), (x, 0.45, -0.605), 'sign_yellow', bevel=0))          # reflector strips
    # lids: hinged at the back (z = 0.62); the left one shut, the right one opened 8 degrees
    for x, pitch in ((-0.47, 0.0), (0.47, 8.0)):
        p = math.radians(pitch)
        hinge = np.array([x, 0.985, 0.62])

        def lid(size, local, mat, bevel):
            ly, lz = local[1], local[2]
            c = hinge + np.array([local[0] - x, math.cos(p) * ly - math.sin(p) * lz, math.sin(p) * ly + math.cos(p) * lz])
            return box(size, c, mat, bevel, (pitch, 0, 0))
        P.append(lid((0.93, 0.05, 1.26), (x, 0.025, -0.63), 'metal_dk', 0.012))
        P.append(lid((0.7, 0.04, 0.04), (x, 0.045, -1.2), 'metal', 0.006))                    # handle bar
    return P


@prop('bollard', 'urban', 'Steel bollard, 0.95 m with a yellow band: a post you can strafe around.', surface='metal')
def bollard():
    return [cyl(0.13, 0.04, (0, 0, 0), 'metal_dk', sides=10),
            cyl(0.105, 0.86, (0, 0.04, 0), 'metal_dk', sides=10),
            cyl(0.112, 0.12, (0, 0.68, 0), 'safety', sides=10),
            cyl(0.11, 0.05, (0, 0.9, 0), 'metal', radius_end=0.07, sides=10)]


@prop('planter', 'urban', 'Concrete planter with a shrub, 1.2 x 1.1 m: chest-high cover that blocks sight.',
      surface='hard', collide=[((0, 0.55, 0), (1.24, 1.1, 0.64))])
def planter():
    P = [box((1.2, 0.5, 0.6), (0, 0.25, 0), 'concrete', bevel=0.025),
         box((1.24, 0.06, 0.64), (0, 0.53, 0), 'concrete_dk', bevel=0.015),
         box((1.1, 0.04, 0.5), (0, 0.555, 0), 'soil', bevel=0)]
    for x, y, rx, ry, mat in ((-0.32, 0.78, 0.3, 0.32, 'leaf'), (0.32, 0.77, 0.3, 0.31, 'leaf_dk'),
                              (0.0, 0.8, 0.38, 0.3, 'leaf_dk'), (-0.12, 0.92, 0.3, 0.18, 'leaf'),
                              (0.2, 0.9, 0.28, 0.2, 'leaf')):
        P.append(ell((rx, ry, 0.27), (x, y, 0.0), mat, sides=8, rings=4))
    return P


@prop('traffic_cone', 'urban', 'Traffic cone, 0.6 m. Decoration: no collision.', surface='hard', collide='none')
def traffic_cone():
    return [box((0.36, 0.03, 0.36), (0, 0.015, 0), 'black', bevel=0.006),
            cyl(0.135, 0.57, (0, 0.03, 0), 'safety', radius_end=0.03, sides=8),
            cyl(0.0905, 0.1, (0, 0.28, 0), 'paint_white', radius_end=0.0725, sides=8)]


@prop('hydrant', 'urban', 'Fire hydrant, 0.75 m: a squat obstacle, low cover.', surface='metal')
def hydrant():
    P = [cyl(0.15, 0.05, (0, 0, 0), 'metal_dk', sides=8),
         cyl(0.115, 0.5, (0, 0.05, 0), 'safety', radius_end=0.105, sides=8),
         cyl(0.125, 0.04, (0, 0.55, 0), 'safety', sides=8),                                     # collar
         ell((0.105, 0.09, 0.105), (0, 0.6, 0), 'safety', sides=8, rings=4),                      # dome
         cyl(0.05, 0.05, (0, 0.67, 0), 'metal_dk', sides=6),                                     # bonnet
         cyl(0.03, 0.03, (0, 0.72, 0), 'metal_dk', sides=6)]
    for x in (-1, 1):
        P.append(cyl(0.05, 0.14, (x * 0.1, 0.42, 0), 'safety', axis='+x' if x > 0 else '-x', sides=8))
        P.append(cyl(0.06, 0.04, (x * 0.24, 0.42, 0), 'metal_dk', axis='+x' if x > 0 else '-x', sides=8))
    P.append(cyl(0.065, 0.1, (0, 0.34, -0.1), 'safety', axis='-z', sides=8))                       # pumper nozzle
    P.append(cyl(0.075, 0.04, (0, 0.34, -0.2), 'metal_dk', axis='-z', sides=8))
    return P


@prop('phone_box', 'urban', 'Phone booth, 1 x 2.3 m, grey frame and glass: tall cover that blocks sight.',
      surface='metal')
def phone_box():
    P = [box((1.0, 0.1, 1.0), (0, 0.05, 0), 'concrete_dk', bevel=0.012),                      # plinth
         box((1.06, 0.1, 1.06), (0, 2.2, 0), 'paint_grey', bevel=0.02),                      # roof
         box((0.8, 0.06, 0.8), (0, 2.27, 0), 'metal_dk', bevel=0.012)]
    for x in (-0.46, 0.46):
        for z in (-0.46, 0.46):
            P.append(box((0.07, 2.1, 0.07), (x, 1.15, z), 'paint_grey', bevel=0))             # corner posts
    front = [box((0.86, 0.7, 0.03), (0, 0.45, -0.46), 'paint_grey', bevel=0),                # lower panel
             box((0.86, 1.3, 0.014), (0, 1.45, -0.46), 'glass', bevel=0),                     # glass
             box((0.86, 0.06, 0.04), (0, 2.12, -0.46), 'paint_grey', bevel=0),                # header rail
             box((0.86, 0.04, 0.04), (0, 0.8, -0.46), 'paint_grey', bevel=0)]                 # sill rail
    for x in (-0.14, 0.14):
        front.append(box((0.03, 1.3, 0.04), (x, 1.45, -0.46), 'paint_grey', bevel=0))        # mullions
    for y in (1.23, 1.67):
        front.append(box((0.86, 0.03, 0.04), (0, y, -0.46), 'paint_grey', bevel=0))
    P += front + moved(front, yaw=90) + moved(front, yaw=180) + moved(front, yaw=270)
    P.append(box((0.03, 0.22, 0.03), (0.3, 1.1, -0.5), 'metal', bevel=0))                    # door handle
    P.append(box((0.5, 0.14, 0.02), (0, 2.08, -0.5), 'sign', bevel=0))                       # sign above the door
    P.append(box((0.3, 0.38, 0.16), (0, 1.25, 0.37), 'metal_dk', bevel=0.01))                 # the phone itself
    return P


# ================================================================ interior
@prop('table', 'interior', 'Wooden table, 1.4 x 0.75 m: low cover you can jump onto.', surface='wood')
def table():
    P = [box((1.4, 0.04, 0.8), (0, 0.73, 0), 'wood', bevel=0.012)]
    for x in (-0.63, 0.63):
        for z in (-0.33, 0.33):
            P.append(box((0.05, 0.71, 0.05), (x, 0.355, z), 'metal_dk', bevel=0))
    for z in (-0.33, 0.33):
        P.append(box((1.2, 0.05, 0.02), (0, 0.68, z), 'metal_dk', bevel=0))
    for x in (-0.63, 0.63):
        P.append(box((0.02, 0.05, 0.6), (x, 0.68, 0), 'metal_dk', bevel=0))
    return P


@prop('chair', 'interior', 'Wooden chair, 0.85 m: clutter you can jump onto.', surface='wood')
def chair():
    P = [box((0.45, 0.04, 0.42), (0, 0.45, -0.03), 'wood', bevel=0.01)]
    for x in (-0.2, 0.2):
        for z in (-0.2, 0.17):
            P.append(box((0.03, 0.43, 0.03), (x, 0.215, z), 'metal', bevel=0))
        P.append(_tilted_box((0.03, 0.4, 0.03), (x, 0.45, 0.17), 8, 'metal', along=0.2))
        P.append(box((0.03, 0.03, 0.4), (x, 0.12, -0.015), 'metal', bevel=0))                 # stretchers
    P.append(_tilted_box((0.4, 0.24, 0.025), (0, 0.45, 0.17), 8, 'wood', bevel=0.006, along=0.27, off=0.0))
    return moved(P, (0, 0, -0.015))


@prop('shelf', 'interior', 'Steel storage rack, 2 x 2.2 m, stocked with boxes: tall cover that blocks sight.',
      surface='metal')
def shelf():
    P = []
    for x in (-0.975, 0.975):
        for z in (-0.275, 0.275):
            P.append(box((0.05, 2.2, 0.05), (x, 1.1, z), 'steel', bevel=0))
    levels = (0.12, 0.64, 1.16, 1.68, 2.18)
    for y in levels:
        P.append(box((1.95, 0.03, 0.6), (0, y, 0), 'metal', bevel=0.006))
    P.append(box((1.9, 0.03, 0.02), (0, 1.12, 0.285), 'steel', bevel=0, rot=(0, 0, 38)))        # back brace
    cardboard = lambda s, x, y, z, yaw=0.0: box(s, (x, y, z), 'cardboard', bevel=0.008, rot=(0, yaw, 0),
                                                decals=[(lambda px, py, pz, f: abs(px) < 0.025 and f == '+y', 'tape')])
    P += [cardboard((0.5, 0.35, 0.4), -0.65, 0.315, -0.02, 4), cardboard((0.4, 0.28, 0.4), -0.1, 0.285, 0.02),
          cardboard((0.55, 0.3, 0.42), 0.6, 0.30, -0.04, -3)]
    P += [cardboard((0.45, 0.3, 0.38), -0.55, 0.835, 0.0), cardboard((0.7, 0.25, 0.45), 0.2, 0.81, 0.0, -2)]
    # a small wooden crate and more boxes higher up
    P.append(box((0.5, 0.38, 0.45), (-0.5, 1.365, 0), 'planks', bevel=0.01))
    for x in (-0.73, -0.27):
        P.append(box((0.04, 0.38, 0.47), (x, 1.365, 0), 'wood_dk', bevel=0))
    P += [cardboard((0.6, 0.4, 0.42), 0.35, 1.395, 0.0, 3)]
    P += [cardboard((0.6, 0.3, 0.45), -0.3, 1.865, 0.0, -4), cardboard((0.4, 0.4, 0.4), 0.4, 1.895, 0.0, 6)]
    return P


@prop('locker', 'interior', 'Bank of three steel lockers, 0.9 x 1.9 m: tall cover that blocks sight.', surface='metal')
def locker():
    P = [box((0.86, 0.1, 0.46), (0, 0.05, 0), 'metal_dk', bevel=0),
         box((0.9, 1.8, 0.5), (0, 1.0, 0), 'teal', bevel=0.015)]
    for x in (-0.15, 0.15):
        P.append(box((0.03, 1.72, 0.01), (x, 1.0, -0.252), 'metal_dk', bevel=0))               # gaps between the doors
    for x in (-0.3, 0.0, 0.3):
        P.append(box((0.27, 1.7, 0.012), (x, 1.0, -0.256), 'teal', bevel=0))                  # door
        for y in (1.72, 1.76, 1.8):
            P.append(box((0.15, 0.014, 0.006), (x, y, -0.265), 'black', bevel=0))             # upper vent
        for y in (0.3, 0.34):
            P.append(box((0.15, 0.014, 0.006), (x, y, -0.265), 'black', bevel=0))             # lower vent
        P.append(box((0.05, 0.16, 0.01), (x + 0.08, 1.0, -0.267), 'metal', bevel=0))          # latch plate
        P.append(box((0.03, 0.12, 0.02), (x + 0.08, 1.0, -0.277), 'metal_dk', bevel=0.004))   # handle
        P.append(box((0.07, 0.035, 0.006), (x, 1.52, -0.265), 'sign', bevel=0))               # number plate
    return P


@prop('desk', 'interior', 'Office desk with a drawer pedestal, 1.4 x 0.75 m: low cover you can jump onto.',
      surface='wood')
def desk():
    P = [box((1.4, 0.04, 0.7), (0, 0.73, 0), 'wood', bevel=0.012),
         box((0.45, 0.71, 0.62), (-0.45, 0.355, 0), 'wood_dk', bevel=0.01),                    # drawer pedestal
         box((0.04, 0.71, 0.6), (0.66, 0.355, 0), 'wood_dk', bevel=0),                         # side panel
         box((0.865, 0.4, 0.02), (0.2075, 0.5, 0.29), 'wood_dk', bevel=0)]                    # modesty panel
    for y in (0.14, 0.37, 0.60):
        P.append(box((0.4, 0.19, 0.015), (-0.45, y, -0.3125), 'wood', bevel=0.004))
        P.append(box((0.12, 0.02, 0.025), (-0.45, y + 0.045, -0.33), 'metal', bevel=0))
    return P


@prop('cabinet', 'interior', 'Steel filing cabinet, 0.5 x 1.3 m: chest-high cover.', surface='metal')
def cabinet():
    P = [box((0.5, 1.3, 0.6), (0, 0.65, 0), 'paint_grey', bevel=0.012),
         box((0.52, 0.03, 0.62), (0, 1.285, 0), 'metal_lt', bevel=0.008)]
    for i in range(4):
        y = 0.03 + 0.155 + 0.31 * i
        P.append(box((0.46, 0.285, 0.016), (0, y, -0.308), 'metal_lt', bevel=0))
        P.append(box((0.46, 0.014, 0.006), (0, y - 0.155, -0.316), 'black', bevel=0))           # gap above the drawer
        P.append(box((0.2, 0.025, 0.03), (0, y + 0.07, -0.33), 'metal_dk', bevel=0))
        P.append(box((0.1, 0.045, 0.006), (0, y - 0.03, -0.318), 'sign', bevel=0))
    return P


@prop('potted_plant', 'interior', 'Potted plant, 1.2 m: leafy cover that blocks sight.', surface='hard')
def potted_plant():
    P = [cyl(0.17, 0.42, (0, 0, 0), 'plastic', radius_end=0.22, sides=10),
         cyl(0.235, 0.03, (0, 0.42, 0), 'plastic', sides=10),
         cyl(0.2, 0.02, (0, 0.44, 0), 'soil', sides=10),
         ell((0.2, 0.2, 0.2), (0, 0.7, 0), 'leaf_dk', sides=8, rings=4)]
    tilts = (8, 22, 30, 14, 26, 34, 18)
    yaws = (0, 51, 103, 154, 206, 257, 309)
    lengths = (0.8, 0.62, 0.55, 0.7, 0.58, 0.5, 0.65)
    for t, ya, ln in zip(tilts, yaws, lengths):
        c, r = _stalk((0, 0.44, 0), t, ya, ln)
        P.append(ell((0.065, ln / 2, 0.14), c, 'leaf' if ya % 2 == 0 else 'leaf_dk', sides=6, rings=4, rot=r))
    return P


# ================================================================ nature
@prop('tree_pine', 'nature', 'Pine tree, 6 m: the trunk and crown are solid cover.', surface='wood',
      collide=[((0, 0.8, 0), (0.35, 1.6, 0.35)), ((0, 2.2, 0), (2.2, 1.6, 2.2)),
               ((0, 3.75, 0), (1.5, 1.5, 1.5)), ((0, 5.25, 0), (0.9, 1.5, 0.9))], density=32)
def tree_pine():
    P = [cyl(0.17, 5.4, (0, 0, 0), 'bark', radius_end=0.05, sides=7)]
    for y, length, r, yaw in ((1.3, 1.9, 1.55, 0), (2.5, 1.8, 1.25, 20), (3.5, 1.7, 0.95, 5), (4.4, 1.6, 0.65, 25)):
        P.append(cyl(r, length, (0, y, 0), 'leaf_dk', radius_end=0.0, sides=8, rot=(0, yaw, 0), smooth=False))
    return P


@prop('tree_leafy', 'nature', 'Leafy tree, 5 m: the trunk and crown are solid cover.', surface='wood',
      collide=[((0, 1.0, 0), (0.5, 2.0, 0.5)), ((0, 3.9, 0), (2.55, 1.7, 2.3)), ((0.3, 2.95, -0.5), (1.5, 1.1, 1.35)),
               ((-1.15, 3.35, 0.35), (1.9, 1.4, 1.7)), ((1.2, 3.45, -0.3), (1.95, 1.5, 1.7)),
               ((0.2, 4.2, 0.2), (1.6, 1.2, 1.5))], density=32)
def tree_leafy():
    P = [cyl(0.26, 2.0, (0, 0, 0), 'bark', radius_end=0.17, sides=7),
         cyl(0.15, 1.5, (0, 1.8, 0), 'bark', radius_end=0.07, sides=7, rot=(0, 0, 28)),
         cyl(0.15, 1.6, (0, 1.8, 0), 'bark', radius_end=0.07, sides=7, rot=(0, 200, 24))]
    for pos, radii, mat in (((0, 3.9, 0), (1.7, 1.15, 1.55), 'leaf'), ((-1.15, 3.35, 0.35), (1.25, 0.95, 1.15), 'leaf_dk'),
                            ((1.2, 3.45, -0.3), (1.3, 1.0, 1.15), 'leaf_dk'), ((0.2, 4.2, 0.2), (1.1, 0.8, 1.0), 'leaf'),
                            ((0.3, 2.95, -0.5), (1.0, 0.7, 0.9), 'leaf_dk')):
        P.append(ell(radii, pos, mat, sides=8, rings=5))
    return P


@prop('bush', 'nature', 'Bush, 1.5 x 1.1 m: leafy cover that blocks sight.', surface='hard')
def bush():
    return [ell((0.5, 0.45, 0.48), (-0.25, 0.45, 0.0), 'leaf', sides=8, rings=4),
            ell((0.5, 0.5, 0.5), (0.25, 0.5, 0.05), 'leaf_dk', sides=8, rings=4),
            ell((0.42, 0.4, 0.42), (0.0, 0.7, -0.08), 'leaf', sides=8, rings=4),
            ell((0.35, 0.3, 0.35), (-0.05, 0.4, -0.3), 'leaf_dk', sides=7, rings=4)]


@prop('hedge', 'nature', 'Trimmed hedge, 2 x 1.3 m: solid, chest-high cover that blocks sight.', surface='hard')
def hedge():
    return [box((1.86, 0.1, 0.66), (0, 0.05, 0), 'soil', bevel=0),
            box((2.0, 1.1, 0.8), (0, 0.65, 0), 'leaf_dk', bevel=0.12),
            box((1.86, 0.2, 0.66), (0, 1.2, 0), 'leaf', bevel=0.08)]


@prop('grass_tuft', 'nature', 'Tuft of grass, 0.4 m. Decoration: no collision.', surface='gravel', collide='none')
def grass_tuft():
    P = []
    blades = ((0, 0, 0.4), (14, 0, 0.34), (18, 40, 0.38), (12, 80, 0.3), (22, 120, 0.36), (16, 160, 0.32),
              (24, 200, 0.4), (14, 240, 0.28), (20, 280, 0.35), (10, 320, 0.3), (28, 20, 0.24), (26, 170, 0.26))
    for i, (tilt, yaw, ln) in enumerate(blades):
        base = (0.03 * math.cos(math.radians(yaw)), 0, 0.03 * math.sin(math.radians(yaw)))
        P.append(cyl(0.03, ln, base, 'leaf_dk' if i % 4 == 0 else 'leaf', radius_end=0.0, sides=3, rot=(0, yaw, tilt),
                     smooth=False))
    return P


@prop('rock', 'nature', 'Boulder, 1 m: solid, chest-high cover.', surface='hard')
def rock():
    return [_ground_box((1.0, 0.58, 0.8), 0.0, 0.0, 'stone', rot=(0, 20, 0), bevel=0.14),
            _ground_box((0.62, 0.78, 0.58), -0.24, -0.1, 'stone', rot=(4, 50, -6), bevel=0.1),
            _ground_box((0.5, 0.4, 0.44), 0.4, 0.24, 'stone', rot=(-6, 70, 9), bevel=0.1),
            _ground_box((0.32, 0.26, 0.3), -0.05, 0.38, 'stone', rot=(8, 15, -10), bevel=0.07)]


@prop('log', 'nature', 'Fallen log, 2.4 m long with a branch stub: low cover you can jump onto.', surface='wood',
      collide=[((0, 0.245, 0), (2.42, 0.49, 0.5))])
def log():
    r = 0.25
    P = [cyl(r, 2.4, (-1.2, 0.24, 0), 'bark', axis='+x', radius_end=0.22, sides=8),
         cyl(0.235, 0.03, (1.18, 0.24, 0), 'wood_lt', axis='+x', radius_end=0.2, sides=8),
         cyl(0.24, 0.03, (-1.21, 0.24, 0), 'wood_lt', axis='+x', radius_end=0.24, sides=8)]
    stub = np.array([0.35, 0.4, -0.1])
    up = np.array([0.0, math.cos(math.radians(40)), -math.sin(math.radians(40))])        # pitch -40: up and to the front
    P.append(cyl(0.075, 0.4, stub, 'bark', radius_end=0.05, sides=6, rot=(-40, 0, 0)))
    P.append(cyl(0.048, 0.02, stub + up * 0.39, 'wood_lt', sides=6, rot=(-40, 0, 0)))      # its cut end
    return P


# ================================================================ debris (decoration, no collision)
@prop('debris_bricks', 'debris', 'Loose bricks in a low pile, 0.2 m. Decoration: no collision.', surface='hard',
      collide='none')
def debris_bricks():
    P = []
    size = (0.22, 0.065, 0.105)
    base = ((0.0, 0.0, 10, 'stone'), (0.23, 0.02, -4, 'concrete_dk'), (-0.22, 0.03, 80, 'stone'), (0.02, 0.12, 95, 'concrete_dk'),
            (0.24, 0.14, 0, 'stone'), (-0.2, 0.15, 3, 'concrete_dk'))
    for x, z, yaw, mat in base:
        P.append(_ground_box(size, x, z, mat, rot=(0, yaw, 0), bevel=0.006))
    mid = ((0.0, 0.06, 50, 'stone'), (0.2, 0.08, 20, 'concrete_dk'), (-0.15, 0.08, 100, 'stone'), (0.1, 0.07, -15, 'concrete_dk'))
    for x, z, yaw, mat in mid:
        P.append(_ground_box(size, x, z, mat, rot=(0, yaw, 0), bevel=0.006, y0=0.065))
    P.append(_ground_box(size, 0.05, 0.07, 'stone', rot=(0, 70, 10), bevel=0.006, y0=0.13))
    P.append(_ground_box(size, -0.38, -0.12, 'concrete_dk', rot=(0, -25, 0), bevel=0.006))
    P.append(_ground_box(size, 0.4, -0.15, 'stone', rot=(0, 110, 14), bevel=0.006))
    return P


@prop('debris_planks', 'debris', 'Loose wooden planks, 0.25 m high. Decoration: no collision.', surface='wood',
      collide='none')
def debris_planks():
    return [_ground_box((1.1, 0.035, 0.12), 0.0, -0.12, 'wood', rot=(0, 8, 0), bevel=0),
            _ground_box((0.9, 0.035, 0.11), 0.1, 0.1, 'wood_dk', rot=(0, -20, 0), bevel=0),
            _ground_box((1.0, 0.035, 0.12), -0.05, 0.0, 'wood_lt', rot=(0, 70, 0), bevel=0, y0=0.035),
            _ground_box((0.8, 0.035, 0.1), 0.25, 0.3, 'wood', rot=(0, -50, 14), bevel=0),
            _ground_box((0.7, 0.035, 0.11), -0.4, 0.28, 'wood_dk', rot=(0, 30, 0), bevel=0)]


@prop('debris_rubble', 'debris', 'Pile of concrete rubble, 0.35 m. Decoration: no collision.', surface='hard',
      collide='none')
def debris_rubble():
    P = []
    chunks = ((0.0, 0.0, (0.3, 0.2, 0.26), (0, 15, 8), 'concrete'), (0.28, 0.12, (0.22, 0.16, 0.2), (12, 60, 0), 'concrete_dk'),
              (-0.28, 0.1, (0.24, 0.18, 0.2), (0, 30, 15), 'concrete_dk'), (0.1, -0.25, (0.2, 0.14, 0.26), (10, 80, 5), 'concrete'),
              (-0.12, 0.3, (0.18, 0.12, 0.22), (0, 10, 20), 'concrete'), (0.45, -0.12, (0.14, 0.1, 0.16), (18, 45, 0), 'concrete_dk'),
              (-0.45, -0.18, (0.16, 0.1, 0.18), (0, 70, 10), 'concrete'), (0.3, 0.38, (0.12, 0.09, 0.14), (5, 20, 25), 'concrete_dk'),
              (-0.05, -0.05, (0.2, 0.14, 0.16), (15, 40, 12), 'concrete_dk'))
    for x, z, size, rot, mat in chunks:
        y0 = 0.14 if (x, z) == (-0.05, -0.05) else 0.0
        P.append(_ground_box(size, x, z, mat, rot=rot, bevel=0.025, y0=y0))
    return P


@prop('trash_bags', 'debris', 'Three black rubbish bags, 0.5 m. Decoration: no collision.', surface='hard',
      collide='none')
def trash_bags():
    P = []
    bags = ((-0.28, 0.03, 0.32, 0.25, 0.27, 15, 'black'), (0.24, 0.0, 0.3, 0.22, 0.27, -20, 'metal_dk'),
            (0.0, -0.32, 0.26, 0.2, 0.24, 40, 'black'))
    for x, z, rx, ry, rz, yaw, mat in bags:
        P.append(_dome((rx, ry, rz), (x, ry * 0.75, z), mat, -ry * 0.75, sides=7, rings=4, rot=(0, yaw, 0)))
        knot = cyl(0.055, 0.07, (x + 0.02, ry * 0.75 + ry * 0.92, z), mat, radius_end=0.03, sides=5, rot=(0, 0, 12))
        P.append(knot)                                                                          # the tied neck
    return P


@prop('debris_boxes', 'debris', 'Squashed cardboard boxes, 0.4 m. Decoration: no collision.', surface='hard',
      collide='none')
def debris_boxes():
    tape = [(lambda x, y, z, f: abs(x) < 0.025 and f == '+y', 'tape')]
    return [_ground_box((0.5, 0.17, 0.4), -0.1, 0.0, 'cardboard', rot=(0, 12, 0), bevel=0.008, decals=tape),
            _ground_box((0.4, 0.22, 0.34), 0.1, -0.05, 'cardboard', rot=(0, -20, 22), bevel=0.008, y0=0.1),
            _ground_box((0.45, 0.1, 0.45), 0.4, 0.35, 'cardboard', rot=(0, 50, 0), bevel=0.006, decals=tape),
            _ground_box((0.28, 0.01, 0.2), -0.38, -0.25, 'cardboard', rot=(0, 30, 12), bevel=0),
            _ground_box((0.3, 0.01, 0.18), 0.42, -0.12, 'cardboard', rot=(0, -35, 0), bevel=0)]
