"""
fparms.py - first-person arms for each class (D-054, M6 task 9).

The arms you see in first person are a small model of their own: the class's upper arms,
forearms and hands (its own sleeves in the team colour, its own gloves and elbow pads, the same
pieces as its body) on a 7-bone skeleton in *camera space*. The camera sits at the origin and
looks along -Z; the root bone `view` is the camera. The shoulders are placed below and around
the camera, where they are never seen, so the hands hold the gun where a first-person gun
belongs: low on the right, barrel toward the crosshair.

Clips (all solved with the same two-bone IK as the body, so the hands stay on the gun):
  fp_idle    a slow breath (loops)
  fp_draw    the gun comes up from below and settles (0.5 s)
  fp_fire    the kick: back and up, then home (0.12 s)
  fp_reload  tilt, magazine out, a fresh one in, rack the handle (2.5 s, scaled to the weapon)
Sway and bob are added in code (weapons/weapon.gd), since they follow the mouse and the feet.
"""
import math

import numpy as np

import anims
from anims import frame_from, pitch_up, rx, rz, two_bone
from rig import hand_in_weapon, norm

BONES = ['view', 'upper_arm_l', 'forearm_l', 'hand_l', 'upper_arm_r', 'forearm_r', 'hand_r', 'weapon']
PARENT = {'view': None, 'upper_arm_l': 'view', 'forearm_l': 'upper_arm_l', 'hand_l': 'forearm_l',
          'upper_arm_r': 'view', 'forearm_r': 'upper_arm_r', 'hand_r': 'forearm_r', 'weapon': 'hand_r'}
INDEX = {b: i for i, b in enumerate(BONES)}
ARM_BONES = BONES[1:7]

# Where the gun's grip sits in camera space when held at rest, and how it is turned: low on the
# right, a little inward, so the barrel points just left of the crosshair's line like a CS
# viewmodel. (The old box viewmodel's receiver sat at (0.17, -0.19, -0.42).)
GRIP = np.array([0.20, -0.165, -0.36])
GRIP_YAW = 4.0           # degrees toward the left (barrel aims a little inward)
GRIP_PITCH = 1.0
# Shoulders, out of view below the camera. The left one is forward and inward, as in a bladed
# stance, so the left hand reaches the foregrip.
SHOULDER_R = np.array([0.27, -0.36, 0.02])
SHOULDER_L = np.array([0.02, -0.46, -0.10])


class ArmsRig:
    """solves first-person arm poses for one class around one gun."""

    def __init__(self, body, gun_points):
        self.body = body
        self.gun = gun_points
        self.hand_r_rot, self.hand_r_wrist = hand_in_weapon('r')
        self.hand_l_rot, self.hand_l_wrist = hand_in_weapon('l')
        w = body.w
        self.off = {'view': np.zeros(3),
                    'upper_arm_r': SHOULDER_R + np.array([0.02 * (w - 1), 0, 0]),
                    'upper_arm_l': SHOULDER_L - np.array([0.02 * (w - 1), 0, 0]),
                    'forearm_r': np.array([body.upper_arm, 0, 0]), 'hand_r': np.array([body.forearm, 0, 0]),
                    'forearm_l': np.array([-body.upper_arm, 0, 0]), 'hand_l': np.array([-body.forearm, 0, 0])}
        rot, wrist = hand_in_weapon('r')
        self.off['weapon'] = -rot.T @ wrist
        self.weapon_rest_rot = rot.T

    def rest_rotations(self):
        rots = {b: np.eye(3) for b in BONES}
        rots['weapon'] = self.weapon_rest_rot
        return rots

    def rest_globals(self):
        rots = self.rest_rotations()
        out = {}
        for b in BONES:
            p = PARENT[b]
            if p is None:
                out[b] = (rots[b], self.off[b])
            else:
                pr, pp = out[p]
                out[b] = (pr @ rots[b], pp + pr @ self.off[b])
        return out

    def new_pose(self):
        return dict(local={b: np.eye(3) for b in BONES}, hips=np.zeros(3))

    def gun_at(self, offset=(0, 0, 0), pitch=0.0, yaw=0.0, roll=0.0):
        """the gun's rotation and grip position, moved from its rest place."""
        rot = anims.turn_right(-GRIP_YAW - yaw) @ pitch_up(GRIP_PITCH + pitch) @ rz(roll)
        return rot, GRIP + np.asarray(offset, float)

    def arm(self, pose, side, wrist, hand_rot, pole):
        shoulder = self.off['upper_arm_' + side]
        a, b = self.body.upper_arm, self.body.forearm
        elbow, end = two_bone(shoulder, np.asarray(wrist, float), a, b, pole)
        upper, fore = elbow - shoulder, end - elbow
        hinge = np.cross(upper, fore)
        if np.linalg.norm(hinge) < 1e-6:
            hinge = np.cross(upper, -np.asarray(pole, float))
        hinge = norm(hinge)
        r_up = frame_from(norm(upper), hinge) @ anims.ARM_REST[side].T
        r_fore = frame_from(norm(fore), hinge) @ anims.ARM_REST[side].T
        pose['local']['upper_arm_' + side] = r_up
        pose['local']['forearm_' + side] = r_up.T @ r_fore
        pose['local']['hand_' + side] = r_fore.T @ hand_rot

    def hold(self, gun_rot, gun_pos, left=None):
        """both hands on the gun, or the left hand at `left` = (wrist, hand rotation, pole)."""
        pose = self.new_pose()
        self.arm(pose, 'r', gun_pos + gun_rot @ self.hand_r_wrist, gun_rot @ self.hand_r_rot, (1.0, -0.6, 0.6))
        if left is None:
            left = (gun_pos + gun_rot @ (self.gun['foregrip'] + self.hand_l_wrist), gun_rot @ self.hand_l_rot,
                    (-0.9, -0.8, 0.1))
        self.arm(pose, 'l', *left)
        return pose

    def held(self, **kw):
        return self.hold(*self.gun_at(**kw))


def keyed(times, poses):
    """rotation channels for the arm bones (the view root and the weapon bone stay put)."""
    chans = []
    for b in ARM_BONES:
        qs = np.array([anims.quat(p['local'][b]) for p in poses])
        for i in range(1, len(qs)):
            if np.dot(qs[i], qs[i - 1]) < 0:
                qs[i] = -qs[i]
        chans.append((b, 'rotation', times, qs))
    return chans


def eased(keys, length):
    """poses from (time, pose) keys, eased between them, at anims.FPS."""
    def at(t):
        for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
            if t <= t1:
                u = (t - t0) / max(t1 - t0, 1e-9)
                u = u * u * (3 - 2 * u)
                out = {'local': {b: anims.slerp_m(p0['local'][b], p1['local'][b], u) for b in BONES},
                       'hips': np.zeros(3)}
                return out
        return keys[-1][1]
    n = max(1, int(round(length * anims.FPS)))
    times = np.arange(n + 1) / anims.FPS * (length / (n / anims.FPS))
    return times, [at(t) for t in times]


def clips(rig):
    """every first-person clip: (name, loops, channels)."""
    out = []
    # idle: a slow breath, the gun rising and settling a few millimetres
    n = int(2.4 * anims.FPS)
    times = np.arange(n + 1) / anims.FPS
    poses = [rig.held(offset=(0, 0.004 * math.sin(2 * math.pi * t / 2.4), 0.002 * math.sin(2 * math.pi * t / 2.4)),
                      pitch=0.4 * math.sin(2 * math.pi * t / 2.4)) for t in times]
    out.append(('fp_idle', True, keyed(times, poses)))
    # draw: from low on the right, tilted, up into place with a little overshoot
    keys = [(0.0, rig.held(offset=(0.06, -0.22, 0.10), pitch=-35, roll=25, yaw=-10)),
            (0.30, rig.held(offset=(0.0, 0.008, 0.0), pitch=2.0)),
            (0.50, rig.held())]
    out.append(('fp_draw', False, keyed(*eased(keys, 0.5))))
    # fire: the old code-driven kick (3.5 cm back, 2.5 degrees up), as a clip
    n = int(0.12 * anims.FPS)
    times = np.arange(n + 1) / anims.FPS * (0.12 / (n / anims.FPS))
    def kick(t):
        k = 0.0 if t <= 0 else min(1.0, t / 0.015) * math.exp(-max(0.0, t - 0.015) / 0.03)
        return rig.held(offset=(0, 0.005 * k, 0.035 * k), pitch=2.5 * k)
    out.append(('fp_fire', False, keyed(times, [kick(t) for t in times])))
    # reload: tilt the gun and lower it, left hand to the magazine, out and away, a fresh one from
    # the vest, in, over the top to rack the handle, back on the foregrip
    def tilted(k, left=None):
        rot, pos = rig.gun_at(offset=(-0.03 * k, -0.07 * k, 0.03 * k), pitch=12 * k, roll=-32 * k, yaw=6 * k)
        if left is None:
            return rig.hold(rot, pos)
        where, pole = left
        if isinstance(where, str):
            point = pos + rot @ rig.gun[where]
            wrist = point + rot @ np.array([-0.05, -0.06, 0.04])
        else:
            wrist = np.asarray(where, float)
        return rig.hold(rot, pos, left=(wrist, rot @ rig.hand_l_rot, pole))
    pole = (-0.9, -0.7, 0.1)
    keys = [(0.0, rig.held()),
            (0.30, tilted(1.0)),
            (0.60, tilted(1.0, ('magazine', pole))),
            (0.95, tilted(1.0, ((-0.05, -0.55, -0.30), pole))),
            (1.30, tilted(1.0, ((-0.02, -0.40, -0.38), pole))),
            (1.65, tilted(1.0, ('magazine', pole))),
            (1.95, tilted(0.6, ('handle', (-0.4, 0.6, 0.3)))),
            (2.12, tilted(0.6, ('handle', (-0.4, 0.6, 0.3)))),
            (2.30, tilted(0.15)),
            (2.50, rig.held())]
    out.append(('fp_reload', False, keyed(*eased(keys, 2.5))))
    return out
