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

M7 (D-096): every other animation set (holds.py) gets its own clips, fp_<set>_<action>: the long
guns their idle, draw, fire and reload around their own points (the Breaker adds its pump and a
clip per shell, the Heron its bolt); the pistols a two-handed hold out in front; the knife a slash
and a stab; the grenades the pin, a throw and a lob. See set_clips().
"""
import math

import numpy as np

import anims
import holds
from anims import frame_from, pitch_up, rx, rz, two_bone
from rig import frame, hand_in_weapon, norm

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
# The left hand reaches this share of the arm's full length at most (M11, D-157).
LEFT_REACH = 0.97


def left_shoulder(body):
    """a class's left shoulder (M11, D-157): SHOULDER_L, moved toward the long guns' foregrips
    until the left hand reaches every one of them at rest (the Breaker's pump is far forward,
    and the Scout's arms are short). It stays out of view below the camera."""
    shoulder = SHOULDER_L - np.array([0.02 * (body.w - 1), 0, 0])
    reach = (body.upper_arm + body.forearm) * LEFT_REACH
    rot = anims.turn_right(-GRIP_YAW) @ pitch_up(GRIP_PITCH)
    wrist_offset = hand_in_weapon('l')[1]
    for _ in range(3):
        for name in holds.SETS:
            if holds.style(name) != 'rifle':
                continue
            wrist = GRIP + rot @ (holds.points(name)['foregrip'] + wrist_offset)
            extra = np.linalg.norm(wrist - shoulder) - reach
            if extra > 0:
                shoulder = shoulder + norm(wrist - shoulder) * (extra + 0.002)
    return shoulder


class ArmsRig:
    """solves first-person arm poses for one class around one gun."""

    def __init__(self, body, gun_points, grip=None, grip_yaw=None, grip_pitch=None):
        self.body = body
        self.gun = gun_points
        # Where the grip sits at rest, and how the gun is turned (the rifle's unless given).
        self.grip = GRIP if grip is None else np.asarray(grip, float)
        self.grip_yaw = GRIP_YAW if grip_yaw is None else grip_yaw
        self.grip_pitch = GRIP_PITCH if grip_pitch is None else grip_pitch
        self.hand_r_rot, self.hand_r_wrist = hand_in_weapon('r')
        self.hand_l_rot, self.hand_l_wrist = hand_in_weapon('l')
        w = body.w
        self.off = {'view': np.zeros(3),
                    'upper_arm_r': SHOULDER_R + np.array([0.02 * (w - 1), 0, 0]),
                    'upper_arm_l': left_shoulder(body),
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
        rot = anims.turn_right(-self.grip_yaw - yaw) @ pitch_up(self.grip_pitch + pitch) @ rz(roll)
        return rot, self.grip + np.asarray(offset, float)

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



# ---------------------------------------------------------------- M7: the other weapons (D-096)
# Rest placements per style: grip position in camera space, yaw (degrees, barrel inward), pitch.
PISTOL_GRIP = (np.array([0.11, -0.15, -0.40]), 2.0, 1.0)
KNIFE_GRIP = (np.array([0.15, -0.15, -0.38]), 10.0, -38.0)
GRENADE_GRIP = (np.array([0.15, -0.14, -0.36]), 4.0, 0.0)
# A left hand that isn't on the gun: out of view below the camera, or near the grenade.
LEFT_AWAY = np.array([-0.20, -0.62, -0.05])
LEFT_NEAR_GRENADE = np.array([0.02, -0.22, -0.35])


def _relaxed_left(rig, wrist, pole=(-0.9, -0.8, 0.1)):
    """a left hand at `wrist` (camera space), palm up and fingers forward, not on the gun."""
    fingers = norm(np.array([0.25, 0.15, -1.0]))
    return np.asarray(wrist, float), frame_from(-fingers, (-0.3, -1.0, 0.0)), pole


def _named(prefix, clips_list):
    return [(f'fp_{prefix}_{name[3:]}', loop, ch) for name, loop, ch in clips_list]


def _one_hand(rig, left_wrist, **kw):
    rot, pos = rig.gun_at(**kw)
    return rig.hold(rot, pos, left=_relaxed_left(rig, left_wrist))


def _keyed_clip(name, keys, length, loop=False):
    return (name, loop, keyed(*eased(keys, length)))


def _idle(rig, pose_at):
    n = int(2.4 * anims.FPS)
    times = np.arange(n + 1) / anims.FPS
    poses = [pose_at(math.sin(2 * math.pi * t / 2.4)) for t in times]
    return keyed(times, poses)


def _long_gun_extras(rig, set_name):
    """the Breaker's pump after a shot and its shells; the Heron's bolt."""
    out = []
    if set_name == 'shotgun':
        def pumped(back):
            rot, pos = rig.gun_at()
            wrist = pos + rot @ (rig.gun['foregrip'] + rig.hand_l_wrist + np.array([0, 0, 0.09 * back]))
            return rig.hold(rot, pos, left=(wrist, rot @ rig.hand_l_rot, (-0.9, -0.8, 0.1)))
        kick = rig.held(offset=(0, 0.006, 0.05), pitch=5.0)
        out.append(_keyed_clip('fp_shotgun_fire', [(0.0, rig.held()), (0.03, kick), (0.18, rig.held()),
                                                   (0.32, pumped(1.0)), (0.46, pumped(0.0)), (0.6, rig.held())], 0.6))

        def tipped(k, left=None):
            rot, pos = rig.gun_at(offset=(-0.02 * k, -0.06 * k, 0.03 * k), pitch=10 * k, roll=-40 * k)
            if left is None:
                return rig.hold(rot, pos)
            if isinstance(left, str):
                # the shell in the palm goes into the loading port (GunModel shows it there)
                wrist = pos + rot @ (rig.gun[left] + rig.hand_l_wrist)
            else:
                wrist = np.asarray(left, float)
            return rig.hold(rot, pos, left=(wrist, rot @ rig.hand_l_rot, (-0.9, -0.7, 0.1)))
        # keyed to holds.RELOAD_EVENTS['shell']: the shell taken at 0.28, in at 0.80
        shell = [(0.0, tipped(1.0)), (0.14, tipped(1.0, (-0.06, -0.55, -0.20))), (0.32, tipped(1.0, 'magazine')),
                 (0.40, tipped(1.0, 'magazine')), (0.50, tipped(1.0))]
        out.append(_keyed_clip('fp_shotgun_reload', [(0.0, rig.held()), (0.40, tipped(1.0))] +
                               [(0.40 + t, p) for t, p in shell[1:]], 0.90))
        out.append(_keyed_clip('fp_shotgun_reload_shell', shell, 0.50))
    elif set_name == 'sniper':
        def bolt(k, back):
            rot, pos = rig.gun_at(offset=(0, -0.02 * k, 0.02 * k), roll=-12 * k)
            wrist = pos + rot @ (rig.gun['handle'] + np.array([-0.02, 0.05 + 0.02 * back, 0.05 + 0.08 * back]))
            return rig.hold(rot, pos, left=(wrist, rot @ rig.hand_l_rot, (-0.4, 0.6, 0.3)))
        kick = rig.held(offset=(0, 0.01, 0.06), pitch=7.0)
        out.append(_keyed_clip('fp_sniper_fire', [(0.0, rig.held()), (0.04, kick), (0.30, rig.held()),
                                                  (0.50, bolt(1.0, 0.0)), (0.70, bolt(1.0, 1.0)), (0.88, bolt(1.0, 0.0)),
                                                  (1.20, rig.held())], 1.2))
    return out


def _pistol_clips(rig, set_name):
    big = set_name == 'hand_cannon'
    out = [(f'fp_{set_name}_idle', True, _idle(rig, lambda k: rig.held(offset=(0, 0.003 * k, 0.002 * k), pitch=0.4 * k)))]
    out.append(_keyed_clip(f'fp_{set_name}_draw', [(0.0, rig.held(offset=(0.05, -0.20, 0.10), pitch=-40, roll=20)),
                                                   (0.28, rig.held(offset=(0, 0.01, 0), pitch=3)), (0.45, rig.held())], 0.45))
    kick = rig.held(offset=(0, 0.012 if big else 0.006, 0.045 if big else 0.025), pitch=12.0 if big else 6.0)
    out.append(_keyed_clip(f'fp_{set_name}_fire', [(0.0, rig.held()), (0.025, kick), (0.22 if big else 0.15, rig.held())],
                           0.22 if big else 0.15))

    def tipped(k, left=None):
        rot, pos = rig.gun_at(offset=(-0.03 * k, -0.04 * k, 0.06 * k), pitch=15 * k, roll=-30 * k)
        if left is None:
            return rig.hold(rot, pos)
        if isinstance(left, str):
            wrist = pos + rot @ (rig.gun[left] + np.array([-0.03, -0.05, 0.04]))
        else:
            wrist = np.asarray(left, float)
        return rig.hold(rot, pos, left=(wrist, rot @ rig.hand_l_rot, (-0.9, -0.7, 0.1)))
    # keyed to holds.RELOAD_EVENTS['magazine'] (fractions of 2.2 s): grab, swap, insert, slide
    keys = [(0.0, rig.held()), (0.25, tipped(1.0)), (0.53, tipped(1.0, 'magazine')),
            (0.84, tipped(1.0, (-0.08, -0.60, -0.20))), (1.12, tipped(1.0, (-0.05, -0.45, -0.30))),
            (1.45, tipped(1.0, 'magazine')), (1.72, tipped(0.6, 'handle')), (1.87, tipped(0.6, 'handle')),
            (2.20, rig.held())]
    out.append(_keyed_clip(f'fp_{set_name}_reload', keys, 2.2))
    return out


def _knife_clips(rig):
    hand = lambda **kw: _one_hand(rig, LEFT_AWAY, **kw)
    rest = hand()
    out = [('fp_knife_idle', True, _idle(rig, lambda k: _one_hand(rig, LEFT_AWAY, offset=(0, 0.004 * k, 0), pitch=0.6 * k)))]
    out.append(_keyed_clip('fp_knife_draw', [(0.0, hand(offset=(0.05, -0.25, 0.12), pitch=-40, roll=30)),
                                             (0.30, hand(offset=(0, 0.01, 0), pitch=4)), (0.45, rest)], 0.45))
    out.append(_keyed_clip('fp_knife_slash', [(0.0, rest), (0.08, hand(offset=(0.08, 0.10, 0.04), yaw=-25, roll=-35, pitch=10)),
                                              (0.20, hand(offset=(-0.22, -0.04, -0.12), yaw=40, roll=45, pitch=-20)),
                                              (0.40, rest)], 0.40))
    out.append(_keyed_clip('fp_knife_stab', [(0.0, rest), (0.12, hand(offset=(0.0, 0.03, 0.06), pitch=-10)),
                                             (0.24, hand(offset=(-0.06, 0.05, -0.20), pitch=-35)),
                                             (0.38, hand(offset=(-0.06, 0.05, -0.19), pitch=-35)), (0.60, rest)], 0.60))
    return out


def _grenade_clips(rig):
    def hand(left=LEFT_NEAR_GRENADE, **kw):
        return _one_hand(rig, left, **kw)
    rest = hand()
    out = [('fp_grenade_idle', True, _idle(rig, lambda k: _one_hand(rig, LEFT_NEAR_GRENADE, offset=(0, 0.004 * k, 0))))]
    out.append(_keyed_clip('fp_grenade_draw', [(0.0, hand(offset=(0.04, -0.22, 0.10), pitch=-30)),
                                               (0.30, hand(offset=(0, 0.01, 0))), (0.45, rest)], 0.45))
    rot, pos = rig.gun_at()
    pin = pos + rot @ rig.gun['pin']
    out.append(_keyed_clip('fp_grenade_pull', [(0.0, rest), (0.12, hand(left=pin + np.array([-0.03, -0.02, 0.04]))),
                                               (0.30, hand(left=pin + np.array([-0.16, -0.10, 0.06])))], 0.30))
    away = LEFT_AWAY
    out.append(_keyed_clip('fp_grenade_throw', [(0.0, hand(left=away)), (0.14, hand(left=away, offset=(0.06, 0.16, 0.30), pitch=-20)),
                                                (0.28, hand(left=away, offset=(-0.06, 0.18, -0.30), pitch=40)),
                                                (0.40, hand(left=away, offset=(-0.04, -0.10, -0.10), pitch=10))], 0.40))
    out.append(_keyed_clip('fp_grenade_lob', [(0.0, hand(left=away)), (0.14, hand(left=away, offset=(0.0, -0.25, 0.10), pitch=-30)),
                                              (0.28, hand(left=away, offset=(-0.04, 0.02, -0.28), pitch=30)),
                                              (0.40, hand(left=away, offset=(-0.04, -0.10, -0.10)))], 0.40))
    return out


def set_clips(body, set_name, style, gun_points):
    """the first-person clips of one animation set (not the rifle's: clips() has those)."""
    if style == 'rifle':
        rig = ArmsRig(body, gun_points)
        out = [c for c in _named(set_name, clips(rig)) if not (set_name == 'shotgun' and c[0] == 'fp_shotgun_reload')]
        out = [c for c in out if not (set_name in ('shotgun', 'sniper') and c[0] == f'fp_{set_name}_fire')]
        return out + _long_gun_extras(rig, set_name)
    if style == 'pistol':
        return _pistol_clips(ArmsRig(body, gun_points, *PISTOL_GRIP), set_name)
    if style == 'knife':
        return _knife_clips(ArmsRig(body, gun_points, *KNIFE_GRIP))
    return _grenade_clips(ArmsRig(body, gun_points, *GRENADE_GRIP))
