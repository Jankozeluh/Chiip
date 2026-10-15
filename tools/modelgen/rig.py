"""
rig.py - the crew's skeleton (D-054).

Seventeen bones. Every bone's rest orientation is the identity, so a piece's position and
size are given straight in model axes (Godot's: +Y up, facing -Z, right +X) relative to
its bone. The rest pose is a T-pose: arms straight out to the sides, palms down.

The weapon bone is a child of the right hand. Its rest transform is the grip: where a gun
sits in the right hand. Guns are separate models fixed to that bone in Godot (a
BoneAttachment3D), authored in "weapon space": origin at the top of the pistol grip, barrel
along -Z, +Y up. The left hand's place on the gun comes from the gun (its foregrip point).
"""
import numpy as np

BONES = ['hips', 'spine', 'chest', 'head',
         'upper_arm_l', 'forearm_l', 'hand_l',
         'upper_arm_r', 'forearm_r', 'hand_r', 'weapon',
         'thigh_l', 'shin_l', 'foot_l',
         'thigh_r', 'shin_r', 'foot_r']
PARENT = {'hips': None, 'spine': 'hips', 'chest': 'spine', 'head': 'chest',
          'upper_arm_l': 'chest', 'forearm_l': 'upper_arm_l', 'hand_l': 'forearm_l',
          'upper_arm_r': 'chest', 'forearm_r': 'upper_arm_r', 'hand_r': 'forearm_r', 'weapon': 'hand_r',
          'thigh_l': 'hips', 'shin_l': 'thigh_l', 'foot_l': 'shin_l',
          'thigh_r': 'hips', 'shin_r': 'thigh_r', 'foot_r': 'shin_r'}
INDEX = {b: i for i, b in enumerate(BONES)}

# Ankle joint height above the floor (boot heel and sole below it).
ANKLE = 0.09


def norm(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-12)


def frame(x_dir, y_hint):
    """a rotation matrix whose +X is x_dir and whose +Y is as close to y_hint as possible."""
    x = norm(x_dir)
    y = norm(np.asarray(y_hint, float) - x * np.dot(y_hint, x))
    return np.column_stack([x, y, np.cross(x, y)])


# The right hand on the pistol grip, in weapon space: the wrist sits above and behind the
# grip, the fingers run forward and down around its front, the back of the hand faces out.
GRIP_FINGERS = norm((-0.25, -0.35, -0.90))
GRIP_BACK = (1.0, 0.25, 0.0)
GRIP_WRIST = np.array([0.012, -0.028, 0.060])
# The left hand under a foregrip, in weapon space relative to the gun's foregrip point:
# palm up, fingers forward and to the right around the handguard.
FORE_FINGERS = norm((0.45, 0.25, -0.85))
FORE_BACK = (-0.45, -0.9, 0.0)
FORE_WRIST_OFFSET = np.array([-0.035, -0.035, 0.045])


def hand_in_weapon(side):
    """(rotation, wrist position) of a hand in weapon space; side 'r' grips, 'l' supports
    (relative to the foregrip point). A hand's own +X runs from the wrist to the fingers on
    the right hand and from the fingers to the wrist on the left (T-pose symmetry)."""
    if side == 'r':
        return frame(GRIP_FINGERS, GRIP_BACK), GRIP_WRIST
    r = frame(-FORE_FINGERS, FORE_BACK)
    return r, FORE_WRIST_OFFSET


class Body:
    """the proportions of one class: s scales the upper body, sl the legs, w the width."""

    def __init__(self, s, legs=1.0, bulk=1.0, hunch=0.0):
        self.s, self.sl, self.w, self.hunch = s, s * legs, bulk, hunch

    # lengths
    @property
    def upper_arm(self):
        return 0.29 * self.s

    @property
    def forearm(self):
        return 0.27 * self.s

    @property
    def thigh(self):
        return 0.44 * self.sl

    @property
    def shin(self):
        return 0.43 * self.sl

    def rest_offsets(self):
        """each bone's position relative to its parent in the rest pose (T-pose)."""
        s, sl, w = self.s, self.sl, self.w
        off = {'hips': (0, ANKLE + self.shin + self.thigh + 0.07 * sl, 0),
               'spine': (0, 0.10 * s, 0), 'chest': (0, 0.20 * s, 0), 'head': (0, 0.25 * s, 0)}
        for side, x in (('l', -1), ('r', 1)):
            off['upper_arm_' + side] = (x * 0.185 * w, 0.17 * s, 0)
            off['forearm_' + side] = (x * self.upper_arm, 0, 0)
            off['hand_' + side] = (x * self.forearm, 0, 0)
            off['thigh_' + side] = (x * 0.095 * w, -0.07 * sl, 0)
            off['shin_' + side] = (0, -self.thigh, 0)
            off['foot_' + side] = (0, -self.shin, 0)
        rot, wrist = hand_in_weapon('r')
        # weapon in hand = inverse(hand in weapon)
        off['weapon'] = tuple(-rot.T @ wrist)
        return {b: np.array(v, float) for b, v in off.items()}

    def rest_rotations(self):
        """rest rotations relative to the parent: identity, except the weapon bone (the grip)."""
        rots = {b: np.eye(3) for b in BONES}
        rots['weapon'] = hand_in_weapon('r')[0].T
        return rots

    def rest_globals(self):
        """(rotation, position) of every bone in model space at rest."""
        off, rots = self.rest_offsets(), self.rest_rotations()
        out = {}
        for b in BONES:
            p = PARENT[b]
            if p is None:
                out[b] = (rots[b], off[b])
            else:
                pr, pp = out[p]
                out[b] = (pr @ rots[b], pp + pr @ off[b])
        return out


def quat(m):
    """rotation matrix -> quaternion (x, y, z, w)."""
    m = np.asarray(m, float)
    t = np.trace(m)
    if t > 0:
        k = 0.5 / np.sqrt(t + 1.0)
        q = [(m[2, 1] - m[1, 2]) * k, (m[0, 2] - m[2, 0]) * k, (m[1, 0] - m[0, 1]) * k, 0.25 / k]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        k = 2.0 * np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2])
        q = [0.25 * k, (m[0, 1] + m[1, 0]) / k, (m[0, 2] + m[2, 0]) / k, (m[2, 1] - m[1, 2]) / k]
    elif m[1, 1] > m[2, 2]:
        k = 2.0 * np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2])
        q = [(m[0, 1] + m[1, 0]) / k, 0.25 * k, (m[1, 2] + m[2, 1]) / k, (m[0, 2] - m[2, 0]) / k]
    else:
        k = 2.0 * np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1])
        q = [(m[0, 2] + m[2, 0]) / k, (m[1, 2] + m[2, 1]) / k, 0.25 * k, (m[1, 0] - m[0, 1]) / k]
    q = np.array(q)
    q /= np.linalg.norm(q)
    return q if q[3] >= 0 else -q
