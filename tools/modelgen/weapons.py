"""
weapons.py - gun models for the crew to hold (D-054, D-056).

A gun is built from the same low-poly pieces as a character, in "weapon space": the origin
is the top of the pistol grip (where the right hand holds it), the barrel points along -Z
and +Y is up. In Godot a gun hangs on a character's `weapon` bone, which sits at the grip.

Each gun also names a few points the animations need (in weapon space):
  foregrip  where the left hand holds it
  magazine  the middle of the magazine (reloads)
  handle    the charging handle (reloads)
  muzzle    the end of the barrel
  butt      the end of the stock, which rests against the shoulder

Only the AK-style rifle exists in M6; the rest of the arsenal follows in M7.
"""
import numpy as np

from geometry import Piece

# The kit for guns: wood furniture, gunmetal steel, no team colour.
GUN_KIT = dict(FURN='wood', GEAR=('charcoal', 1, 12), TOP='grey', SLEEVE='grey', BOTTOM='grey', COAT='grey',
               KNIT='grey', BOOT='charcoal')


def ak_rifle():
    """the AK-style rifle (signature gun of the Rifleman): 0.91 m long, wood furniture."""
    B = 'weapon'
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
        Piece(B, 'box', (0.028, 0.100, 0.068), (0, -0.055, -0.130), rot=(12, 0, 0), mat='metal', bevel=0.006),  # magazine
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


GUNS = {'ak_rifle': ak_rifle}
