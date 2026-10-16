"""
weapons.py - the arsenal's models (D-054, D-056): guns, knife, grenades and gear.

An item is built from the same low-poly pieces as a character, in "weapon space": the origin
is the top of the pistol grip (where the right hand holds it), the barrel points along -Z
and +Y is up (+X is the gun's right). In Godot a gun hangs on a character's `weapon` bone,
which sits at the grip. A function returns (pieces, points); its docstring names the real
gun that inspired it and its length.

Each gun names a few points the animations need (in weapon space, numpy arrays):
  foregrip  where the left hand holds it (pistols: where it cups the right hand)
  magazine  the middle of the magazine, or where shells load (reloads)
  handle    the charging handle, bolt, pump or slide rear (reloads)
  muzzle    the end of the barrel
  butt      the end of the stock, which rests against the shoulder (pistols: the back of the grip)
The knife names `tip` and `butt` (the pommel); a grenade is centred on its body, which sits
in the palm, and names `pin` (the ring) and `lever`. The defuse kit has no points.

Named pieces (M11, D-158) become their own nodes in the .glb, so reloads can move them:
  'magazine'         the magazine (its node's origin is the gun's `magazine` point)
  'magazine_hidden'  more of the magazine, hidden inside the grip while it's in (not in icons)
  'shell'            a shotgun shell for the left hand, centred on the origin (not in icons)
Every point is also a node, `point_<name>`, so the game can find it on the model.

GUNS lists everything that gets a .glb and an icon (rifle, carbine, smg, shotgun, sniper,
pistol, hand_cannon, knife, frag, flashbang, smoke, defuse_kit). GEAR lists what only gets an
icon (armor, armor_helmet); these face +X so the icon's side view shows their front. KITS
holds each item's changes to the gun kit (GUN_KIT), e.g. black furniture on the carbine.
Materials: metal, polymer, furn (the kit's furniture ramp), lens, gear, gear_dk, and the
class slots top and bottom, which the grenades use for body and band.
"""
import math

import numpy as np

from geometry import Piece

# The kit for guns: wood furniture, gunmetal steel, no team colour.
GUN_KIT = dict(FURN='wood', GEAR=('charcoal', 1, 12), TOP='grey', SLEEVE='grey', BOTTOM='grey', COAT='grey',
               KNIT='grey', BOOT='charcoal')

B = 'weapon'


def _v(*xyz):
    return np.array(xyz, float)


def _strut(a, b, thick, width, mat='metal', bevel=0.0):
    """a flat bar from point a to point b in the XY plane (a lever), `thick` across it in
    that plane and `width` along Z."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    top, bot = (a, b) if a[1] >= b[1] else (b, a)
    u = top - bot
    length = float(np.linalg.norm(u))
    u = u / length
    roll = math.degrees(math.atan2(-u[0], u[1]))
    c = (a + b) / 2
    return Piece(B, 'box', (thick, length, width), (c[0], c[1], 0.0), rot=(0, 0, roll), mat=mat, bevel=bevel)


def _ring(centre, radius, n=6, thick=0.003, mat='metal'):
    """a pull ring: n short bars round a circle in the YZ plane, centred on `centre`."""
    seg = 2 * radius * math.tan(math.pi / n) * 1.04
    out = []
    for k in range(n):
        th = 360.0 * k / n
        c = (centre[0], centre[1] + radius * math.cos(math.radians(th)), centre[2] + radius * math.sin(math.radians(th)))
        out.append(Piece(B, 'box', (thick, thick, seg), c, rot=(th, 0, 0), mat=mat))
    return out


def rifle():
    """the AK-style rifle (signature gun of the Rifleman): 0.91 m long, wood furniture."""
    P = [
        Piece(B, 'box', (0.044, 0.064, 0.30), (0, 0.022, -0.07), mat='metal', bevel=0.008),        # receiver
        Piece(B, 'box', (0.040, 0.020, 0.26), (0, 0.062, -0.08), mat='metal', bevel=0.008),        # dust cover
        Piece(B, 'box', (0.030, 0.022, 0.040), (0, 0.066, -0.215), mat='metal', bevel=0.004),     # rear sight
        Piece(B, 'box', (0.050, 0.046, 0.18), (0, 0.016, -0.31), mat='furn', bevel=0.012),         # lower handguard
        Piece(B, 'box', (0.034, 0.028, 0.15), (0, 0.052, -0.30), mat='furn', bevel=0.008),         # upper handguard
        Piece(B, 'cyl', (0.011, 0.010, 0.14), (0, 0.022, -0.40), mat='metal', axis='-z', sides=6),  # barrel
        Piece(B, 'box', (0.026, 0.046, 0.030), (0, 0.044, -0.50), mat='metal', bevel=0.004),      # front sight block
        Piece(B, 'box', (0.008, 0.030, 0.008), (0, 0.080, -0.505), mat='metal'),                    # front sight post
        Piece(B, 'cyl', (0.015, 0.015, 0.045), (0, 0.022, -0.535), mat='metal', axis='-z', sides=6),  # muzzle brake
        Piece(B, 'box', (0.028, 0.100, 0.068), (0, -0.055, -0.130), rot=(12, 0, 0), mat='metal', bevel=0.006, name='magazine'),
        Piece(B, 'box', (0.028, 0.100, 0.064), (0, -0.140, -0.170), rot=(32, 0, 0), mat='metal', bevel=0.006),
        Piece(B, 'box', (0.030, 0.090, 0.040), (0, -0.048, 0.022), rot=(-18, 0, 0), mat='furn', bevel=0.008),  # grip
        Piece(B, 'box', (0.010, 0.010, 0.060), (0, -0.018, -0.040), mat='metal'),                  # trigger guard
        Piece(B, 'box', (0.040, 0.066, 0.24), (0, -0.010, 0.195), rot=(6, 0, 0), mat='furn', bevel=0.012),     # stock
        Piece(B, 'box', (0.044, 0.096, 0.020), (0, -0.030, 0.320), rot=(6, 0, 0), mat='metal', bevel=0.006),   # butt plate
        Piece(B, 'box', (0.014, 0.012, 0.030), (0.028, 0.040, -0.120), mat='metal'),               # charging handle
    ]
    points = dict(foregrip=np.array([0.0, -0.008, -0.31]), magazine=np.array([0.0, -0.10, -0.15]),
                  handle=np.array([0.034, 0.040, -0.12]), muzzle=np.array([0.0, 0.022, -0.58]),
                  butt=np.array([0.0, -0.03, 0.33]))
    return P, points


def carbine():
    """an M4-style carbine, but its own gun: 0.84 m, black furniture, a flat-top receiver with a raised box sight, a boxy handguard, a barely curved
    magazine, a thin telescoping stock (two rails and a pad round a gap) and a flash hider."""
    P = [
        Piece(B, 'box', (0.040, 0.046, 0.21), (0, 0.030, -0.06), mat='metal', bevel=0.005),          # upper receiver
        Piece(B, 'box', (0.036, 0.040, 0.15), (0, -0.012, -0.04), mat='polymer', bevel=0.005),       # lower receiver
        Piece(B, 'box', (0.020, 0.008, 0.21), (0, 0.057, -0.06), mat='metal'),                       # flat-top rail
        Piece(B, 'box', (0.026, 0.026, 0.050), (0, 0.070, 0.005), mat='metal', bevel=0.004),         # raised box sight
        Piece(B, 'box', (0.052, 0.046, 0.27), (0, 0.016, -0.295), mat='furn', bevel=0.008),          # boxy handguard
        Piece(B, 'box', (0.022, 0.008, 0.27), (0, 0.043, -0.295), mat='metal'),                      # handguard rail
        Piece(B, 'cyl', (0.009, 0.009, 0.10), (0, 0.026, -0.42), mat='metal', axis='-z', sides=6),    # barrel
        Piece(B, 'box', (0.022, 0.032, 0.026), (0, 0.054, -0.455), mat='metal', bevel=0.003),         # front sight block
        Piece(B, 'box', (0.006, 0.024, 0.006), (0, 0.082, -0.455), mat='metal'),                      # front sight post
        Piece(B, 'cyl', (0.014, 0.013, 0.045), (0, 0.026, -0.50), mat='metal', axis='-z', sides=6),   # flash hider
        Piece(B, 'box', (0.026, 0.080, 0.044), (0, -0.075, -0.077), rot=(3, 0, 0), mat='metal', bevel=0.004, name='magazine'),
        Piece(B, 'box', (0.026, 0.070, 0.044), (0, -0.149, -0.0875), rot=(14, 0, 0), mat='metal', bevel=0.004),
        Piece(B, 'box', (0.030, 0.090, 0.040), (0, -0.048, 0.022), rot=(-18, 0, 0), mat='furn', bevel=0.008),   # grip
        Piece(B, 'box', (0.010, 0.008, 0.050), (0, -0.037, -0.028), mat='metal'),                    # trigger guard
        Piece(B, 'box', (0.030, 0.008, 0.022), (0, 0.062, 0.052), mat='metal'),                      # charging handle
        Piece(B, 'cyl', (0.013, 0.013, 0.12), (0, 0.010, 0.04), mat='metal', axis='+z', sides=6),     # buffer tube
        Piece(B, 'box', (0.014, 0.012, 0.12), (0, 0.012, 0.22), mat='furn'),                         # upper stock rail
        Piece(B, 'box', (0.014, 0.012, 0.14), (0, -0.034, 0.21), mat='furn'),                        # lower stock rail
        Piece(B, 'box', (0.014, 0.040, 0.016), (0, -0.016, 0.148), mat='furn'),                      # rail strut
        Piece(B, 'box', (0.034, 0.100, 0.024), (0, -0.012, 0.283), rot=(8, 0, 0), mat='furn', bevel=0.006),   # butt pad
    ]
    points = dict(foregrip=_v(0.0, 0.014, -0.30), magazine=_v(0.0, -0.11, -0.085), handle=_v(0.0, 0.062, 0.052),
                  muzzle=_v(0.0, 0.026, -0.545), butt=_v(0.0, -0.014, 0.296))
    return P, points


def smg():
    """a compact SMG after the MP9 and the Vector: 0.45 m. A boxy receiver, the magazine up
    inside the pistol grip (it sticks out below), a vertical foregrip, a short barrel stub and a
    stock bar folded along the right side."""
    P = [
        Piece(B, 'box', (0.044, 0.050, 0.40), (0, 0.016, -0.03), mat='polymer', bevel=0.006),        # receiver body
        Piece(B, 'box', (0.040, 0.020, 0.36), (0, 0.050, -0.06), mat='metal', bevel=0.005),          # top cover
        Piece(B, 'box', (0.014, 0.014, 0.020), (0, 0.067, 0.07), mat='metal'),                       # rear sight
        Piece(B, 'box', (0.008, 0.016, 0.010), (0, 0.068, -0.215), mat='metal'),                     # front sight
        Piece(B, 'cyl', (0.013, 0.011, 0.045), (0, 0.030, -0.235), mat='metal', axis='-z', sides=6), # barrel stub
        Piece(B, 'cyl', (0.014, 0.014, 0.012), (0, 0.030, -0.28), mat='gear_dk', axis='+z', sides=6),  # muzzle
        Piece(B, 'box', (0.032, 0.092, 0.042), (0, -0.048, 0.022), rot=(-18, 0, 0), mat='polymer', bevel=0.006),  # grip
        Piece(B, 'box', (0.024, 0.130, 0.034), (0, -0.088, 0.034), rot=(-18, 0, 0), mat='metal', name='magazine'),     # in the grip
        Piece(B, 'box', (0.030, 0.012, 0.042), (0, -0.153, 0.056), rot=(-18, 0, 0), mat='gear_dk', name='magazine'),  # its base
        Piece(B, 'box', (0.026, 0.080, 0.030), (0, -0.054, -0.185), mat='polymer', bevel=0.006),     # vertical foregrip
        Piece(B, 'box', (0.030, 0.012, 0.056), (0, -0.012, -0.185), mat='metal'),                    # its mount
        Piece(B, 'box', (0.010, 0.008, 0.060), (0, -0.013, -0.04), mat='metal'),                      # trigger guard
        Piece(B, 'box', (0.010, 0.014, 0.300), (0.027, 0.022, -0.02), mat='metal', bevel=0.003),     # folded stock bar
        Piece(B, 'box', (0.016, 0.040, 0.020), (0.027, 0.022, -0.17), mat='gear_dk', bevel=0.003),   # its butt pad
        Piece(B, 'box', (0.014, 0.024, 0.026), (0.026, 0.024, 0.15), mat='metal'),                   # its hinge
        Piece(B, 'box', (0.016, 0.012, 0.024), (0, 0.064, 0.125), mat='metal'),                      # charging knob
    ]
    points = dict(foregrip=_v(0.0, -0.06, -0.185), magazine=_v(0.0, -0.10, 0.04), handle=_v(0.0, 0.064, 0.125),
                  muzzle=_v(0.0, 0.030, -0.28), butt=_v(0.0, 0.016, 0.17))
    return P, points


def shotgun():
    """a pump shotgun after the Nova (and the Remington 870): 1.00 m. A long barrel with a tube
    magazine under it, a ribbed wooden pump grip on the tube, a solid wood stock, a loading
    port under the receiver and a bead sight."""
    P = [
        Piece(B, 'box', (0.040, 0.060, 0.22), (0, 0.016, -0.06), mat='metal', bevel=0.006),          # receiver
        Piece(B, 'cyl', (0.013, 0.013, 0.46), (0, 0.030, -0.16), mat='metal', axis='-z', sides=8),   # barrel
        Piece(B, 'cyl', (0.012, 0.012, 0.38), (0, 0.0, -0.16), mat='metal', axis='-z', sides=8),     # magazine tube
        Piece(B, 'cyl', (0.015, 0.015, 0.024), (0, 0.0, -0.54), mat='metal', axis='-z', sides=8),    # tube cap
        Piece(B, 'box', (0.018, 0.044, 0.020), (0, 0.016, -0.53), mat='metal'),                      # barrel clamp
        Piece(B, 'box', (0.018, 0.040, 0.020), (0, 0.016, -0.30), mat='metal'),                      # inner clamp
        Piece(B, 'box', (0.044, 0.040, 0.16), (0, 0.002, -0.42), mat='furn', bevel=0.012),           # pump grip
        Piece(B, 'box', (0.050, 0.046, 0.008), (0, 0.002, -0.475), mat='furn'),                      # rib
        Piece(B, 'box', (0.050, 0.046, 0.008), (0, 0.002, -0.445), mat='furn'),                      # rib
        Piece(B, 'box', (0.050, 0.046, 0.008), (0, 0.002, -0.415), mat='furn'),                      # rib
        Piece(B, 'box', (0.050, 0.046, 0.008), (0, 0.002, -0.385), mat='furn'),                      # rib
        Piece(B, 'box', (0.050, 0.046, 0.008), (0, 0.002, -0.355), mat='furn'),                      # rib
        Piece(B, 'box', (0.030, 0.012, 0.070), (0, -0.018, -0.07), mat='gear_dk'),                   # loading port
        Piece(B, 'box', (0.004, 0.016, 0.050), (0.021, 0.034, -0.04), mat='gear_dk'),                # ejection port
        Piece(B, 'box', (0.010, 0.010, 0.060), (0, -0.026, 0.010), mat='metal'),                     # trigger guard
        Piece(B, 'box', (0.034, 0.088, 0.060), (0, -0.040, 0.034), rot=(-14, 0, 0), mat='furn', bevel=0.008),  # wrist
        Piece(B, 'box', (0.038, 0.086, 0.30), (0, -0.020, 0.215), rot=(5, 0, 0), mat='furn', bevel=0.012),    # stock
        Piece(B, 'box', (0.042, 0.100, 0.018), (0, -0.032, 0.372), rot=(7, 0, 0), mat='gear_dk', bevel=0.004),  # butt pad
        Piece(B, 'box', (0.006, 0.012, 0.006), (0, 0.049, -0.612), mat='metal'),                     # bead sight
        # one shell, carried in the left hand while reloading (its own node, hidden on the gun)
        Piece(B, 'cyl', (0.0105, 0.0105, 0.052), (0, 0.0, 0.026), mat='polymer', axis='-z', sides=6, name='shell'),
        Piece(B, 'cyl', (0.011, 0.011, 0.013), (0, 0.0, 0.026), mat='metal', axis='+z', sides=6, name='shell'),
    ]
    points = dict(foregrip=_v(0.0, -0.016, -0.42), magazine=_v(0.0, -0.03, -0.06), handle=_v(0.0, 0.0, -0.42),
                  muzzle=_v(0.0, 0.030, -0.62), butt=_v(0.0, -0.032, 0.382))
    return P, points


def sniper():
    """a bolt-action sniper rifle after the AWP (but olive, with a thumbhole stock): 1.15 m. A
    cheek rest, a long thick barrel with a big box muzzle brake, a big scope with lens ends, the
    bolt handle out to the right behind the scope, a small box magazine and a folded bipod."""
    P = [
        Piece(B, 'box', (0.042, 0.060, 0.26), (0, 0.020, -0.06), mat='metal', bevel=0.006),          # receiver
        Piece(B, 'cyl', (0.016, 0.014, 0.50), (0, 0.026, -0.19), mat='metal', axis='-z', sides=8),   # barrel
        Piece(B, 'box', (0.034, 0.040, 0.090), (0, 0.026, -0.73), mat='metal'),                      # muzzle brake
        Piece(B, 'box', (0.037, 0.014, 0.012), (0, 0.032, -0.71), mat='gear_dk'),                    # brake vent
        Piece(B, 'box', (0.037, 0.014, 0.012), (0, 0.032, -0.75), mat='gear_dk'),                    # brake vent
        Piece(B, 'box', (0.046, 0.040, 0.34), (0, -0.010, -0.36), mat='furn', bevel=0.008),          # fore-end
        Piece(B, 'cyl', (0.014, 0.014, 0.06), (0, 0.020, 0.07), mat='metal', axis='+z', sides=6),    # bolt shroud
        # the thumbhole stock: grip in front of the hole, comb above it, lower bar below, butt behind
        Piece(B, 'box', (0.034, 0.100, 0.044), (0, -0.050, 0.022), rot=(-18, 0, 0), mat='furn', bevel=0.006),  # grip
        Piece(B, 'box', (0.040, 0.034, 0.30), (0, 0.008, 0.22), rot=(3, 0, 0), mat='furn'),                    # comb
        Piece(B, 'box', (0.040, 0.026, 0.12), (0, 0.032, 0.25), rot=(3, 0, 0), mat='furn'),                    # cheek rest
        Piece(B, 'box', (0.040, 0.026, 0.19), (0, -0.092, 0.15), rot=(3, 0, 0), mat='furn'),                   # lower bar
        Piece(B, 'box', (0.040, 0.110, 0.20), (0, -0.036, 0.259), rot=(7, 0, 0), mat='furn', bevel=0.008),    # butt
        Piece(B, 'box', (0.044, 0.118, 0.020), (0, -0.036, 0.363), rot=(7, 0, 0), mat='gear_dk'),             # butt pad
        # the scope: tube 0.30 m long, bells at both ends, lenses in the bells
        Piece(B, 'cyl', (0.024, 0.024, 0.30), (0, 0.098, 0.13), mat='metal', axis='-z', sides=8),     # scope tube
        Piece(B, 'cyl', (0.024, 0.033, 0.075), (0, 0.098, -0.17), mat='metal', axis='-z', sides=8),   # objective bell
        Piece(B, 'cyl', (0.029, 0.029, 0.004), (0, 0.098, -0.245), mat='lens', axis='-z', sides=8),   # objective lens
        Piece(B, 'cyl', (0.024, 0.030, 0.060), (0, 0.098, 0.13), mat='metal', axis='+z', sides=8),    # eyepiece bell
        Piece(B, 'cyl', (0.026, 0.026, 0.004), (0, 0.098, 0.19), mat='lens', axis='+z', sides=8),     # eyepiece lens
        Piece(B, 'box', (0.030, 0.030, 0.026), (0, 0.065, -0.11), mat='metal'),                      # front mount
        Piece(B, 'box', (0.030, 0.030, 0.026), (0, 0.065, 0.04), mat='metal'),                       # rear mount
        Piece(B, 'cyl', (0.009, 0.009, 0.018), (0, 0.118, -0.03), mat='metal', axis='+y', sides=6),  # elevation turret
        # the bolt: shaft out to the right, then back and down to the knob
        Piece(B, 'cyl', (0.005, 0.005, 0.050), (0.020, 0.030, 0.055), mat='metal', axis='+x', sides=6),
        Piece(B, 'cyl', (0.005, 0.005, 0.050), (0.070, 0.030, 0.055), mat='metal', axis=(0, -0.45, 0.9), sides=6),
        Piece(B, 'box', (0.016, 0.016, 0.016), (0.070, 0.008, 0.099), mat='gear_dk'),                # bolt knob
        Piece(B, 'box', (0.030, 0.050, 0.060), (0, -0.030, -0.06), mat='metal', name='magazine'),    # box magazine
        Piece(B, 'box', (0.010, 0.010, 0.050), (0, -0.022, 0.0), mat='metal'),                       # trigger guard
        Piece(B, 'box', (0.040, 0.010, 0.18), (0, -0.036, -0.44), mat='metal'),                      # folded bipod legs
        Piece(B, 'box', (0.020, 0.016, 0.026), (0, -0.034, -0.35), mat='metal'),                     # bipod mount
    ]
    points = dict(foregrip=_v(0.0, -0.010, -0.28), magazine=_v(0.0, -0.035, -0.06), handle=_v(0.07, 0.008, 0.099),
                  muzzle=_v(0.0, 0.026, -0.775), butt=_v(0.0, -0.036, 0.374))
    return P, points


def pistol():
    """a polymer service pistol after the Glock and the USP: 0.20 m. A polymer frame and grip
    (angled like the rifle's), a metal slide with serrations, a barrel stub and a magazine base."""
    P = [
        Piece(B, 'box', (0.028, 0.030, 0.19), (0, 0.020, -0.06), mat='metal', bevel=0.004),          # slide
        Piece(B, 'box', (0.026, 0.020, 0.17), (0, -0.003, -0.065), mat='polymer', bevel=0.003),      # frame
        Piece(B, 'box', (0.028, 0.092, 0.040), (0, -0.048, 0.022), rot=(-18, 0, 0), mat='polymer', bevel=0.005),  # grip
        Piece(B, 'box', (0.030, 0.012, 0.046), (0, -0.094, 0.037), rot=(-18, 0, 0), mat='metal', name='magazine'),  # its base
        Piece(B, 'box', (0.022, 0.086, 0.032), (0, -0.050, 0.023), rot=(-18, 0, 0), mat='metal', name='magazine_hidden'),  # in the grip
        Piece(B, 'box', (0.010, 0.008, 0.060), (0, -0.032, -0.040), mat='polymer'),                  # trigger guard
        Piece(B, 'box', (0.010, 0.022, 0.008), (0, -0.021, -0.068), mat='polymer'),                  # guard front
        Piece(B, 'box', (0.006, 0.016, 0.008), (0, -0.018, -0.030), mat='metal'),                    # trigger
        Piece(B, 'cyl', (0.007, 0.007, 0.014), (0, 0.020, -0.155), mat='metal', axis='-z', sides=6), # barrel stub
        Piece(B, 'box', (0.0295, 0.026, 0.004), (0, 0.020, 0.010), mat='gear_dk'),                   # serrations
        Piece(B, 'box', (0.0295, 0.026, 0.004), (0, 0.020, 0.018), mat='gear_dk'),
        Piece(B, 'box', (0.0295, 0.026, 0.004), (0, 0.020, 0.026), mat='gear_dk'),
        Piece(B, 'box', (0.0295, 0.026, 0.004), (0, 0.020, 0.002), mat='gear_dk'),
        Piece(B, 'box', (0.012, 0.007, 0.010), (0, 0.038, 0.027), mat='metal'),                      # rear sight
        Piece(B, 'box', (0.006, 0.008, 0.007), (0, 0.039, -0.147), mat='metal'),                     # front sight
        Piece(B, 'box', (0.003, 0.014, 0.040), (0.0135, 0.024, -0.05), mat='gear_dk'),               # ejection port
    ]
    points = dict(foregrip=_v(0.0, -0.06, -0.01), magazine=_v(0.0, -0.075, 0.032), handle=_v(0.0, 0.020, 0.030),
                  muzzle=_v(0.0, 0.020, -0.162), butt=_v(0.0, -0.04, 0.03))
    return P, points


def hand_cannon():
    """a big-bore hand cannon after the Desert Eagle: 0.27 m. A chunky metal slide with a tall
    barrel housing, a larger grip, a prominent trigger guard and tall sights."""
    P = [
        Piece(B, 'box', (0.034, 0.050, 0.125), (0, 0.030, -0.0275), mat='metal', bevel=0.004),       # rear slide
        Piece(B, 'box', (0.036, 0.060, 0.12), (0, 0.035, -0.15), mat='metal', bevel=0.004),          # barrel housing
        Piece(B, 'cyl', (0.012, 0.012, 0.028), (0, 0.035, -0.21), mat='metal', axis='-z', sides=8),  # muzzle
        Piece(B, 'box', (0.018, 0.008, 0.115), (0, 0.069, -0.15), mat='metal'),                      # top rib
        Piece(B, 'box', (0.034, 0.024, 0.22), (0, -0.007, -0.10), mat='polymer', bevel=0.004),       # frame
        Piece(B, 'box', (0.034, 0.108, 0.048), (0, -0.058, 0.024), rot=(-18, 0, 0), mat='polymer', bevel=0.006),  # grip
        Piece(B, 'box', (0.036, 0.012, 0.054), (0, -0.1135, 0.0425), rot=(-18, 0, 0), mat='metal', name='magazine'),  # its base
        Piece(B, 'box', (0.026, 0.100, 0.038), (0, -0.062, 0.027), rot=(-18, 0, 0), mat='metal', name='magazine_hidden'),  # in the grip
        Piece(B, 'box', (0.012, 0.010, 0.085), (0, -0.040, -0.062), mat='metal'),                    # trigger guard bottom
        Piece(B, 'box', (0.012, 0.032, 0.010), (0, -0.030, -0.104), mat='metal'),                    # trigger guard front
        Piece(B, 'box', (0.007, 0.022, 0.009), (0, -0.026, -0.036), mat='metal'),                    # trigger
        Piece(B, 'box', (0.0345, 0.044, 0.004), (0, 0.030, 0.021), mat='gear_dk'),                   # serrations
        Piece(B, 'box', (0.0345, 0.044, 0.004), (0, 0.030, 0.012), mat='gear_dk'),
        Piece(B, 'box', (0.0345, 0.044, 0.004), (0, 0.030, 0.003), mat='gear_dk'),
        Piece(B, 'box', (0.022, 0.032, 0.012), (0, 0.071, 0.026), mat='metal'),                      # tall rear sight
        Piece(B, 'box', (0.008, 0.022, 0.012), (0, 0.084, -0.195), mat='metal'),                     # tall front sight
        Piece(B, 'box', (0.003, 0.020, 0.050), (0.0175, 0.032, -0.04), mat='gear_dk'),               # ejection port
    ]
    points = dict(foregrip=_v(0.0, -0.065, -0.01), magazine=_v(0.0, -0.09, 0.035), handle=_v(0.0, 0.032, 0.03),
                  muzzle=_v(0.0, 0.035, -0.238), butt=_v(0.0, -0.045, 0.04))
    return P, points


def knife():
    """a combat knife after the KA-BAR: 0.30 m, blade 0.17 m toward -Z, a small crossguard and a
    0.12 m grip. The origin is the middle of the handle."""
    P = [
        Piece(B, 'box', (0.020, 0.028, 0.12), (0, 0, 0), mat='gear_dk', bevel=0.006),                # handle
        Piece(B, 'box', (0.022, 0.030, 0.006), (0, 0, -0.02), mat='polymer'),                        # grip ridges
        Piece(B, 'box', (0.022, 0.030, 0.006), (0, 0, 0.0), mat='polymer'),
        Piece(B, 'box', (0.022, 0.030, 0.006), (0, 0, 0.02), mat='polymer'),
        Piece(B, 'box', (0.018, 0.024, 0.012), (0, 0, 0.066), mat='metal', bevel=0.003),             # pommel
        Piece(B, 'box', (0.016, 0.040, 0.010), (0, -0.002, -0.065), mat='metal', bevel=0.002),       # crossguard
        Piece(B, 'box', (0.005, 0.030, 0.113), (0, 0.003, -0.1265), mat='metal'),                    # blade
        Piece(B, 'box', (0.007, 0.007, 0.113), (0, 0.016, -0.1265), mat='metal'),                    # spine
        Piece(B, 'ell', (0.0025, 0.066, 0.0165), (0, 0.003, -0.1745), rot=(90, 0, 0), mat='metal', sides=4, rings=4),  # point
    ]
    points = dict(tip=_v(0.0, 0.003, -0.241), butt=_v(0.0, 0.0, 0.072))
    return P, points


def _grenade_fuse(top, radius, pin_y, lever_pts, lever_width):
    """a fuse cap, a pin, a pull ring and the lever bars shared by the grenades."""
    P = [Piece(B, 'cyl', (radius, radius, 0.016), (0, top, 0), mat='metal', axis='+y', sides=6)]
    ring_c = _v(0.026, pin_y + 0.009, 0.0)
    P.append(Piece(B, 'box', (0.020, 0.003, 0.003), (0.017, pin_y, 0), mat='metal'))
    P += _ring(ring_c, 0.009, n=6)
    for a, b in zip(lever_pts, lever_pts[1:]):
        P.append(_strut(a, b, 0.003, lever_width))
    return P, ring_c


def frag():
    """a fragmentation grenade after the M67: 0.06 m across, a round moss-green body, a fuse
    cap, a lever hugging one side and a pull ring."""
    P = [
        Piece(B, 'ell', (0.030, 0.034, 0.030), (0, 0, 0), mat='top', sides=8, rings=6),             # body
        Piece(B, 'cyl', (0.016, 0.014, 0.010), (0, 0.027, 0), mat='gear_dk', axis='+y', sides=6),   # neck
    ]
    fuse, ring_c = _grenade_fuse(0.036, 0.010, 0.043, [(0.011, 0.046), (0.0209, 0.0265), (0.0317, 0.010),
                                                       (0.0285, -0.022)], 0.010)
    P += fuse
    points = dict(pin=ring_c, lever=_v(0.031, 0.0, 0.0))
    return P, points


def flashbang():
    """a stun grenade after the M84: a light grey cylinder 0.13 m tall and 0.08 m across with a
    darker band, a fuse cap, a lever and a pull ring."""
    P = [
        Piece(B, 'cyl', (0.040, 0.040, 0.13), (0, -0.065, 0), mat='top', axis='+y', sides=8),       # body
        Piece(B, 'cyl', (0.0415, 0.0415, 0.034), (0, -0.017, 0), mat='bottom', axis='+y', sides=8),  # band
        Piece(B, 'cyl', (0.040, 0.016, 0.010), (0, 0.065, 0), mat='gear_dk', axis='+y', sides=8),   # shoulder
    ]
    fuse, ring_c = _grenade_fuse(0.075, 0.013, 0.086, [(0.013, 0.082), (0.0405, 0.082), (0.0405, -0.050)], 0.012)
    P += fuse
    points = dict(pin=ring_c, lever=_v(0.0405, 0.0, 0.0))
    return P, points


def smoke():
    """a smoke grenade after the M18: a dark grey cylinder 0.14 m tall and 0.09 m across with a
    lighter band, a few vent holes, a fuse cap, a lever and a pull ring."""
    P = [
        Piece(B, 'cyl', (0.045, 0.045, 0.14), (0, -0.07, 0), mat='top', axis='+y', sides=8),        # body
        Piece(B, 'cyl', (0.0465, 0.0465, 0.030), (0, -0.015, 0), mat='bottom', axis='+y', sides=8),  # band
    ]
    for sgn in (1, -1):         # four vents, two on each face next to the lever's
        for y in (0.040, 0.050):
            c = 0.0422
            P.append(Piece(B, 'box', (0.003, 0.007, 0.009), (c * math.sin(math.radians(45)), y, sgn * c * math.cos(math.radians(45))),
                           rot=(0, -45 * sgn, 0), mat='gear_dk'))
    fuse, ring_c = _grenade_fuse(0.080, 0.013, 0.091, [(0.013, 0.087), (0.0455, 0.087), (0.0455, -0.055)], 0.012)
    P += fuse
    points = dict(pin=ring_c, lever=_v(0.0455, 0.0, 0.0))
    return P, points


def defuse_kit():
    """a bomb defusal kit (gear): a small olive pouch, 0.12 m wide, with a pair of wire cutters
    sticking out of the top."""
    P = [
        Piece(B, 'box', (0.044, 0.080, 0.120), (0, -0.01, 0), mat='gear', bevel=0.006),             # pouch
        Piece(B, 'box', (0.048, 0.034, 0.126), (0, 0.028, 0), mat='gear_dk', bevel=0.006),          # flap
        Piece(B, 'box', (0.050, 0.016, 0.018), (0, 0.014, 0), mat='metal'),                          # buckle
        Piece(B, 'box', (0.050, 0.060, 0.010), (0, -0.01, 0.040), mat='gear_dk'),                   # strap
        # the cutters: pivot, two handles crossing in the pouch, two jaws crossing above it
        Piece(B, 'cyl', (0.008, 0.008, 0.016), (-0.008, 0.074, 0), mat='metal', axis='+x', sides=6),
        Piece(B, 'box', (0.007, 0.075, 0.012), (0, 0.045, 0.010), rot=(-12, 0, 0), mat='gear_dk'),
        Piece(B, 'box', (0.007, 0.075, 0.012), (0, 0.045, -0.010), rot=(12, 0, 0), mat='gear_dk'),
        Piece(B, 'box', (0.007, 0.045, 0.012), (0, 0.098, 0.008), rot=(14, 0, 0), mat='metal'),
        Piece(B, 'box', (0.007, 0.045, 0.012), (0, 0.098, -0.008), rot=(-14, 0, 0), mat='metal'),
    ]
    return P, dict()


def armor():
    """body armour (gear, icon only): an olive vest seen from the front, which faces +X so the
    icon's side view shows it. A front plate between two chest panels and a neck gap, shoulder
    straps, and a waist band with pouches."""
    P = [
        Piece(B, 'box', (0.050, 0.170, 0.340), (0, -0.095, 0), mat='gear', bevel=0.010),            # belly
        Piece(B, 'box', (0.050, 0.200, 0.095), (0, 0.090, 0.098), mat='gear', bevel=0.008),         # chest panel
        Piece(B, 'box', (0.050, 0.200, 0.095), (0, 0.090, -0.098), mat='gear', bevel=0.008),
        Piece(B, 'box', (0.020, 0.190, 0.200), (0.032, 0.050, 0), mat='plate', bevel=0.005),        # front plate
        Piece(B, 'box', (0.040, 0.070, 0.062), (0, 0.190, 0.098), mat='gear', bevel=0.008),         # shoulder strap
        Piece(B, 'box', (0.040, 0.070, 0.062), (0, 0.190, -0.098), mat='gear', bevel=0.008),
        Piece(B, 'box', (0.060, 0.040, 0.350), (0, -0.140, 0), mat='gear_dk', bevel=0.008),         # waist band
        Piece(B, 'box', (0.030, 0.056, 0.070), (0.040, -0.140, 0.100), mat='gear', bevel=0.006),    # pouch
        Piece(B, 'box', (0.030, 0.056, 0.070), (0.040, -0.140, -0.100), mat='gear', bevel=0.006),
        Piece(B, 'box', (0.016, 0.066, 0.100), (0.036, -0.045, 0), mat='gear_dk', bevel=0.005),     # lower plate
    ]
    return P, dict()


def armor_helmet():
    """the vest with a helmet (gear, icon only): a helmet dome with a dark brim sits in front of
    the vest's neck, above its upper half."""
    P, _ = armor()
    P = P + [
        Piece(B, 'dome', (0.110, 0.100, 0.118), (0.060, 0.150, 0), mat='top', sides=10, rings=6, clip=((0, 1, 0), -0.01)),
        Piece(B, 'box', (0.150, 0.014, 0.250), (0.060, 0.137, 0), mat='gear_dk', bevel=0.004),      # helmet brim
    ]
    return P, dict()


GUNS = {'rifle': rifle, 'carbine': carbine, 'smg': smg, 'shotgun': shotgun, 'sniper': sniper, 'pistol': pistol,
        'hand_cannon': hand_cannon, 'knife': knife, 'frag': frag, 'flashbang': flashbang, 'smoke': smoke,
        'defuse_kit': defuse_kit}
GEAR = {'armor': armor, 'armor_helmet': armor_helmet}

# What each item changes in GUN_KIT (the painter reads a slot as a ramp name or (ramp, lo, hi)).
KITS = {
    'carbine': dict(FURN='charcoal'),
    'sniper': dict(FURN='olive'),
    'frag': dict(TOP=('moss', 2, 13), BOTTOM=('charcoal', 2, 10)),
    'flashbang': dict(TOP=('grey', 8, 15), BOTTOM=('charcoal', 3, 11)),
    'smoke': dict(TOP=('grey', 1, 10), BOTTOM=('grey', 5, 15), GEAR=('charcoal', 0, 6)),
    'defuse_kit': dict(GEAR=('olive', 1, 12)),
    'armor': dict(GEAR=('olive', 1, 12)),
    'armor_helmet': dict(GEAR=('olive', 1, 12), TOP=('olive', 3, 13)),
}


def kit_for(name):
    """the painter's kit for an item: GUN_KIT with the item's own changes on top."""
    return dict(GUN_KIT, **KITS.get(name, {}))
