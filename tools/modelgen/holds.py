"""
holds.py - how each weapon is held, for the body's and the first-person arms' clips (D-096,
M7 task 7).

Every weapon belongs to an animation set (WeaponData.anim_set in Godot; the weapon's id when
empty). A set names the hold style and the gun whose points (foregrip, magazine, handle...)
the hands reach for:

  style 'rifle'    both hands on a long gun, butt in the shoulder (the M6 AK hold)
  style 'pistol'   both hands on a pistol, arms out in front (an isosceles stance)
  style 'knife'    the knife in the right hand, low and forward; the left hand on guard
  style 'grenade'  a grenade in the right hand at the chest; the left hand ready for the pin

The rifle set keeps the M6 clip names (aim_d80..., fire, reload, fp_idle...); every other set
gets its own: aim_<set>_<pitch>, reload_<set>, fp_<set>_<action>.

HOLD_OFFSETS: the knife and the grenades aren't held by a pistol grip, so their models sit in
the hand with an extra transform. The same numbers are in their Godot data files
(WeaponData.hold_offset); change both together.
"""
import numpy as np

import weapons

SETS = {
    'rifle': dict(style='rifle', gun='rifle'),
    'carbine': dict(style='rifle', gun='carbine'),
    'smg': dict(style='rifle', gun='smg'),
    'shotgun': dict(style='rifle', gun='shotgun'),
    'sniper': dict(style='rifle', gun='sniper'),
    'pistol': dict(style='pistol', gun='pistol'),
    'hand_cannon': dict(style='pistol', gun='hand_cannon'),
    'knife': dict(style='knife', gun='knife'),
    'grenade': dict(style='grenade', gun='frag'),
}

# Extra placement of a model in the hand, in weapon space: pitch in degrees about +X (the knife's
# blade goes from along -Z to up and forward, along the fist), then a shift in metres.
HOLD_OFFSETS = {
    'knife': dict(pitch=72.0, shift=(0.0, -0.05, 0.0)),
    'grenade': dict(pitch=0.0, shift=(0.0, -0.05, -0.005)),
}


def points(set_name):
    """the gun points of a set, in weapon space, with its hold offset applied."""
    pts = weapons.GUNS[SETS[set_name]['gun']]()[1]
    off = HOLD_OFFSETS.get(set_name)
    if off is None:
        return pts
    a = np.radians(off['pitch'])
    rot = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])
    shift = np.asarray(off['shift'], float)
    return {k: rot @ np.asarray(v, float) + shift for k, v in pts.items()}


def style(set_name):
    return SETS[set_name]['style']
