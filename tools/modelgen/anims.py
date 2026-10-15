"""
anims.py - the crew's long-gun animations, written as keyframes by the generator (D-054,
M6 task 5).

Every clip is built from poses, and every pose is *solved* for the class it's written for:
the legs reach their foot targets and the arms reach the gun with two-bone IK, using that
class's limb lengths. So one set of animation rules fits the short Scout and the tall,
hunched Bulwark alike, and the hands stay on the gun.

Coordinates are Godot's: +Y up, the character faces -Z, its right is +X. Bone rest
rotations are the identity (rig.py), so a bone's local rotation is simply how far it
turned from the T-pose.

Clips (FPS keyframes, rotation tracks for every bone, translation for the hips):
  idle, walk_<dir>, run_<dir>, crouch_idle, crouch_walk_<dir>   (<dir>: f fr r br b bl l fl)
  jump, fall, fall_crouch, land
  aim_d80, aim_d40, aim_0, aim_u40, aim_u80                     (upper body aim poses)
  fire, flinch                                                  (additive: differences from aim_0)
  reload                                                        (arms only matter)
  death_forward, death_backward, death_headshot
Locomotion cycles all last CYCLE seconds and cover their speed's distance in that time, so
the AnimationTree can blend and phase-match them (task 6).
"""
import math

import numpy as np

from rig import ANKLE, BONES, PARENT, frame, hand_in_weapon, norm, quat

FPS = 30
UNITS_TO_METRES = 0.0254
# CS speeds with a rifle (215 units/s), walking (x0.52) and crouching (x0.34), m/s
RUN_SPEED = 215 * UNITS_TO_METRES
WALK_SPEED = RUN_SPEED * 0.52
CROUCH_SPEED = RUN_SPEED * 0.34
# One locomotion cycle (two steps). At running speed a step is 1.8 m, the distance between
# two footstep sounds (Character.STEP_DISTANCE), so steps and sounds line up.
CYCLE = 1.8 * 2 / RUN_SPEED
# How far the hips drop when crouching: CS lowers the eyes from 64 to 46 units.
CROUCH_DROP = 18 * UNITS_TO_METRES
DIRECTIONS = {'f': 0, 'fr': 45, 'r': 90, 'br': 135, 'b': 180, 'bl': -135, 'l': -90, 'fl': -45}
UPPER = ['spine', 'chest', 'head', 'upper_arm_l', 'forearm_l', 'hand_l', 'upper_arm_r', 'forearm_r', 'hand_r']
ARMS = ['upper_arm_l', 'forearm_l', 'hand_l', 'upper_arm_r', 'forearm_r', 'hand_r']


# ---------------------------------------------------------------- rotations (degrees)
def rx(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def pitch_up(deg):
    """the front (-Z) turns up."""
    return rx(deg)


def lean_forward(deg):
    """the top (+Y) tips toward the front (-Z)."""
    return rx(-deg)


def turn_right(deg):
    """the front turns toward +X."""
    return ry(-deg)


def tilt_right(deg):
    """the top tips toward +X."""
    return rz(-deg)


def two_bone(start, target, a, b, pole):
    """elbow/knee and end positions of a two-bone chain from `start` toward `target`."""
    d = target - start
    dist = float(np.linalg.norm(d))
    u = d / max(dist, 1e-9)
    dist = min(max(dist, abs(a - b) + 1e-4), (a + b) * 0.9995)
    x = (a * a - b * b + dist * dist) / (2 * dist)
    h = math.sqrt(max(a * a - x * x, 0.0))
    p = np.asarray(pole, float) - u * np.dot(pole, u)
    p = norm(p) if np.linalg.norm(p) > 1e-9 else norm(np.cross(u, [1, 0, 0]))
    return start + u * x + p * h, start + u * dist


def slerp_m(a, b, t):
    """interpolates two rotation matrices."""
    qa, qb = quat(a), quat(b)
    if np.dot(qa, qb) < 0:
        qb = -qb
    d = np.clip(np.dot(qa, qb), -1, 1)
    if d > 0.9995:
        q = norm(qa + (qb - qa) * t)
    else:
        th = math.acos(d)
        q = (math.sin((1 - t) * th) * qa + math.sin(t * th) * qb) / math.sin(th)
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


# ---------------------------------------------------------------- the solver
# Rest frames used to turn a limb direction into a bone rotation: (along the bone, second axis).
THIGH_REST = np.column_stack([(0, -1, 0), (0, 0, -1), (1, 0, 0)])        # along -Y, knee to the front
ARM_REST = {'r': np.eye(3), 'l': np.diag([-1.0, -1.0, 1.0])}             # along +-X, elbow hinge +-Y


class Rig:
    """solves poses for one class: body proportions plus the gun it holds."""

    def __init__(self, body, gun_points):
        self.body = body
        self.off = body.rest_offsets()
        self.rest = body.rest_globals()
        self.gun = gun_points
        self.hand_r_rot, self.hand_r_wrist = hand_in_weapon('r')
        self.hand_l_rot, self.hand_l_wrist = hand_in_weapon('l')
        self.hunch = body.hunch
        self.points = {}

    def settle(self, pose):
        """moves the hips up or down so the lowest point of the posed body touches the floor
        (needs `points`: each bone's mesh vertices relative to the bone, set by modelgen)."""
        w = self.world(pose)
        low = min(float(np.min((w[b][0] @ pts.T).T[:, 1] + w[b][1][1])) for b, pts in self.points.items())
        pose['hips'] = pose['hips'] - np.array([0, low, 0])

    def new_pose(self):
        return dict(local={b: np.eye(3) for b in BONES}, hips=self.off['hips'].copy())

    def world(self, pose):
        """(rotation, position) of every bone in model space."""
        out = {}
        for b in BONES:
            p = PARENT[b]
            loc = pose['local'][b]
            if p is None:
                out[b] = (loc, pose['hips'])
            else:
                pr, pp = out[p]
                rest_rot = self.body.rest_rotations()[b] if b == 'weapon' else np.eye(3)
                out[b] = (pr @ rest_rot @ loc, pp + pr @ self.off[b])
        return out

    # ------------------------------------------------------------ legs
    def leg(self, pose, side, ankle, foot_rot, knee_dir):
        """bends one leg so its ankle reaches `ankle` (model space), knee toward `knee_dir`."""
        w = self.world(pose)
        rh, ph = w['hips']
        hip = ph + rh @ self.off['thigh_' + side]
        knee, end = two_bone(hip, np.asarray(ankle, float), self.body.thigh, self.body.shin, knee_dir)
        along = norm(knee - hip)
        line = norm(end - hip)
        out = knee - (hip + line * np.dot(knee - hip, line))
        front = norm(out) if np.linalg.norm(out) > 1e-4 else norm(knee_dir)
        r_thigh = frame_from(along, front) @ THIGH_REST.T
        along_s = norm(end - knee)
        r_shin = frame_from(along_s, front) @ THIGH_REST.T
        pose['local']['thigh_' + side] = rh.T @ r_thigh
        pose['local']['shin_' + side] = r_thigh.T @ r_shin
        pose['local']['foot_' + side] = r_shin.T @ foot_rot

    # ------------------------------------------------------------ upper body
    def torso(self, pose, aim=0.0, twist=25.0, lean=0.0, tilt=0.0, head=(0.0, 0.0, 0.0), turn=0.0):
        """spine, chest and head: `aim` pitches up (deg), `twist` turns the chest right so the
        left shoulder comes forward (a rifle stance), `lean` tips forward on top of the class's
        hunch, `turn` turns the whole upper body; the head looks back to the front."""
        h = self.hunch + lean
        pose['local']['spine'] = turn_right(turn * 0.5 + twist * 0.5) @ tilt_right(tilt * 0.5) @ lean_forward(h * 0.4) @ pitch_up(aim * 0.25)
        pose['local']['chest'] = turn_right(turn * 0.5 + twist * 0.5) @ tilt_right(tilt * 0.5) @ lean_forward(h * 0.6) @ pitch_up(aim * 0.3)
        w = self.world(pose)
        hp, hy, hr = head
        # the head looks where the hips face (the front, unless the whole body is falling)
        want = w['hips'][0] @ turn_right(turn + hy) @ tilt_right(hr) @ pitch_up(aim * 0.85 + hp)
        pose['local']['head'] = w['chest'][0].T @ want

    def hold(self, aim=0.0, kick=0.0, pose=None):
        """where the gun goes for an aim pitch: butt in the right shoulder, barrel pitched
        exactly `aim` degrees, pulled back until the left hand can reach the foregrip."""
        w = self.world(pose)
        rc, pc = w['chest']
        shoulder_r = pc + rc @ self.off['upper_arm_r']
        shoulder_l = pc + rc @ self.off['upper_arm_l']
        rot = pitch_up(aim)
        butt = shoulder_r + rc @ np.array([-0.075 * self.body.w, -0.01, -0.07])
        pos = butt - rot @ self.gun['butt']
        reach = (self.body.upper_arm + self.body.forearm) * 0.985
        for _ in range(40):
            wrist = pos + rot @ (self.gun['foregrip'] + self.hand_l_wrist)
            extra = np.linalg.norm(wrist - shoulder_l) - reach
            if extra <= 0:
                break
            pos = pos + rot @ np.array([0, 0, min(extra, 0.02) + 0.002])
        # the recoil kick comes after the fit, so a gun already pulled back still kicks
        return rot, pos + rot @ np.array([0, 0, kick])

    def arm(self, pose, side, wrist, hand_rot, pole):
        """bends one arm so the wrist reaches `wrist` with the hand turned to `hand_rot`."""
        w = self.world(pose)
        rc, pc = w['chest']
        shoulder = pc + rc @ self.off['upper_arm_' + side]
        a, b = self.body.upper_arm, self.body.forearm
        elbow, end = two_bone(shoulder, np.asarray(wrist, float), a, b, pole)
        upper, fore = elbow - shoulder, end - elbow
        hinge = np.cross(upper, fore)
        if np.linalg.norm(hinge) < 1e-6:
            hinge = np.cross(upper, -np.asarray(pole, float))
        hinge = norm(hinge)
        r_up = frame_from(norm(upper), hinge) @ ARM_REST[side].T
        r_fore = frame_from(norm(fore), hinge) @ ARM_REST[side].T
        pose['local']['upper_arm_' + side] = rc.T @ r_up
        pose['local']['forearm_' + side] = r_up.T @ r_fore
        pose['local']['hand_' + side] = r_fore.T @ hand_rot

    def grip(self, pose, gun_rot, gun_pos, left=None):
        """both hands on the gun (or the left hand at `left` = (wrist, hand rotation, pole))."""
        self.arm(pose, 'r', gun_pos + gun_rot @ self.hand_r_wrist, gun_rot @ self.hand_r_rot,
                 pole=(0.8, -0.6, 0.35))
        if left is None:
            left = (gun_pos + gun_rot @ (self.gun['foregrip'] + self.hand_l_wrist), gun_rot @ self.hand_l_rot,
                    (-0.7, -0.7, 0.2))
        self.arm(pose, 'l', left[0], left[1], left[2])

    def aim_pose(self, pose, aim=0.0, kick=0.0, lean=0.0, head=(0, 0, 0), tilt=0.0, turn=0.0):
        """the whole upper body aiming at pitch `aim`."""
        self.torso(pose, aim=aim, lean=lean, head=head, tilt=tilt, turn=turn)
        rot, pos = self.hold(aim, kick, pose)
        self.grip(pose, rot, pos)
        return rot, pos

    def free_arm(self, pose, side, wrist_in_chest, pole_in_chest, roll=0.0):
        """an arm reaching a point given in the chest's frame, hand in line with the forearm."""
        w = self.world(pose)
        rc, pc = w['chest']
        wrist = pc + rc @ np.asarray(wrist_in_chest, float)
        pole = rc @ np.asarray(pole_in_chest, float)
        shoulder = pc + rc @ self.off['upper_arm_' + side]
        elbow, end = two_bone(shoulder, wrist, self.body.upper_arm, self.body.forearm, pole)
        fore = norm(end - elbow)
        upper = norm(elbow - shoulder)
        hinge = np.cross(upper, fore)
        hinge = norm(hinge) if np.linalg.norm(hinge) > 1e-6 else norm(np.cross(upper, -pole))
        hand = frame_from(fore, hinge) @ ARM_REST[side].T @ rx(roll)
        self.arm(pose, side, wrist, hand, pole)


def frame_from(along, second):
    """columns: along, `second` made perpendicular to it, and their cross product."""
    x = norm(along)
    y = np.asarray(second, float) - x * np.dot(second, x)
    y = norm(y) if np.linalg.norm(y) > 1e-9 else norm(np.cross(x, [0, 0, 1]))
    return np.column_stack([x, y, np.cross(x, y)])


# ---------------------------------------------------------------- legs: stances and gaits
GAITS = {
    # speed, duty (share of the cycle a foot is on the ground), lift, hips drop, bob, sway,
    # kick (how long the swinging foot stays up behind before it comes forward)
    'walk': dict(speed=WALK_SPEED, duty=0.52, lift=0.11, drop=0.06, bob=0.018, sway=0.012, kick=1.0),
    'run': dict(speed=RUN_SPEED, duty=0.24, lift=0.30, drop=0.085, bob=-0.030, sway=0.006, kick=1.7),
    'crouch': dict(speed=CROUCH_SPEED, duty=0.62, lift=0.08, drop=CROUCH_DROP, bob=0.012, sway=0.010, kick=1.0),
}


def leg_yaw(direction):
    """how far the legs turn toward a direction of travel: up to 45 degrees, mirrored for
    backward directions (legs run backward instead of turning around)."""
    d = ((direction + 180) % 360) - 180
    if abs(d) > 90:
        d = d - math.copysign(180, d)
    return max(-45.0, min(45.0, d))


def gait_pose(rig, kind, direction, phase):
    """legs and hips for a locomotion cycle at `phase` (0..1), moving toward `direction`
    (degrees, 0 = forward, +90 = right), plus the upper body aiming level."""
    g = GAITS[kind]
    pose = rig.new_pose()
    dist = g['speed'] * CYCLE                    # metres per cycle
    travel = np.array([math.sin(math.radians(direction)), 0, -math.cos(math.radians(direction))])
    yaw = leg_yaw(direction)
    stride = dist * g['duty']                    # how far a planted foot slides back under the body
    hips = rig.off['hips'].copy()
    bob = g['bob'] * math.cos(2 * math.pi * 2 * (phase - g['duty'] / 2))
    stance_side = 'l' if (phase % 1.0) < 0.5 else 'r'
    hips[1] += -g['drop'] + bob
    hips[0] += g['sway'] * (-1 if stance_side == 'l' else 1)
    pose['hips'] = hips
    width = 0.105 * rig.body.w if kind != 'crouch' else 0.14 * rig.body.w
    for side, offset in (('l', 0.0), ('r', 0.5)):
        q = (phase + offset) % 1.0
        x = -width if side == 'l' else width
        home = np.array([x, ANKLE, 0.0])
        if kind == 'crouch':
            home[2] += -0.12 if side == 'l' else 0.16
        if q < g['duty']:
            u = q / g['duty']
            along, lift, pitch = (0.5 - u) * stride, 0.0, 0.0
        else:
            u = (q - g['duty']) / (1 - g['duty'])
            k = u ** g['kick']                    # a run keeps the foot behind longer: heel kick
            e = k * k * (3 - 2 * k)
            along = (-0.5 + e) * stride
            lift = g['lift'] * math.sin(math.pi * u ** (1 / g['kick']))
            pitch = -25 * math.sin(math.pi * u)  # toes hang during the swing
        ankle = home + travel * along + np.array([0, lift, 0])
        foot = turn_right(yaw) @ rx(pitch)
        knee = turn_right(yaw) @ np.array([0, 0, -1.0])
        rig.leg(pose, side, ankle, foot, knee)
    rig.aim_pose(pose, 0.0)
    return pose


def stand_pose(rig, crouch=False, sway=0.0, aim=0.0):
    """standing (or crouching) still, feet apart, aiming level; `sway` shifts the weight."""
    pose = rig.new_pose()
    hips = rig.off['hips'].copy()
    hips[0] += sway
    hips[1] -= CROUCH_DROP if crouch else 0.025
    pose['hips'] = hips
    w = rig.body.w
    if crouch:
        feet = {'l': (np.array([-0.15 * w, ANKLE, -0.14]), rx(0), turn_right(-10)),
                'r': (np.array([0.16 * w, ANKLE + 0.05, 0.22]), rx(-35), turn_right(15))}
    else:
        feet = {'l': (np.array([-0.13 * w, ANKLE, -0.07]), rx(0), turn_right(-12)),
                'r': (np.array([0.14 * w, ANKLE, 0.10]), rx(0), turn_right(20))}
    for side, (ankle, pitch, yaw) in feet.items():
        rig.leg(pose, side, ankle, yaw @ pitch, yaw @ np.array([0, 0, -1.0]))
    rig.aim_pose(pose, aim)
    return pose


def air_pose(rig, tuck=0.5, crouch=False):
    """legs in the air: `tuck` 0 = hanging straight, 1 = knees pulled up."""
    pose = rig.new_pose()
    hips = rig.off['hips'].copy()
    if crouch:
        hips[1] -= CROUCH_DROP
    pose['hips'] = hips
    w = rig.body.w
    up = 0.10 + 0.25 * tuck + (0.12 if crouch else 0.0)
    for side, x, z in (('l', -0.11 * w, -0.10), ('r', 0.12 * w, 0.12)):
        ankle = np.array([x, ANKLE + up * (1.3 if side == 'l' else 0.8), z])
        rig.leg(pose, side, ankle, rx(-20 * tuck), np.array([0, 0, -1.0]))
    rig.aim_pose(pose, 0.0)
    return pose


# ---------------------------------------------------------------- clips
def sample(fn, length, loop):
    """keys at FPS for t in [0, length]; a loop's last key repeats the first."""
    n = max(1, int(round(length * FPS)))
    times = np.arange(n + 1) / FPS * (length / (n / FPS))
    return times, [fn(t / length if loop else t) for t in times]


def keyed(rig, times, poses, bones=None):
    """animation channels: rotation for each bone (or `bones`), translation for the hips."""
    bones = bones or BONES
    chans = []
    for b in bones:
        if b == 'weapon':
            continue
        qs = np.array([quat(p['local'][b]) for p in poses])
        for i in range(1, len(qs)):         # keep quaternions on one side, so keys blend the short way
            if np.dot(qs[i], qs[i - 1]) < 0:
                qs[i] = -qs[i]
        chans.append((b, 'rotation', times, qs))
    if 'hips' in bones:
        chans.append(('hips', 'translation', times, np.array([p['hips'] for p in poses])))
    return chans


def blend_pose(rig, a, b, t):
    pose = rig.new_pose()
    for bone in BONES:
        pose['local'][bone] = slerp_m(a['local'][bone], b['local'][bone], t)
    pose['hips'] = a['hips'] + (b['hips'] - a['hips']) * t
    return pose


def keyframes(rig, keys, length):
    """a clip from a few hand-placed poses: keys = [(time, pose)], eased between them."""
    def at(t):
        for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
            if t <= t1:
                u = (t - t0) / max(t1 - t0, 1e-9)
                return blend_pose(rig, p0, p1, u * u * (3 - 2 * u))
        return keys[-1][1]
    return sample(at, length, False)


def additive(rig, base, poses, bones):
    """turns poses into differences from `base`, for the AnimationTree's Add nodes."""
    out = []
    for p in poses:
        d = rig.new_pose()
        for b in bones:
            d['local'][b] = base['local'][b].T @ p['local'][b]
        out.append(d)
    return out


def locomotion(rig, kind, dirname):
    times, poses = sample(lambda ph: gait_pose(rig, kind, DIRECTIONS[dirname], ph), CYCLE, True)
    return times, poses


def death(rig, style):
    """three deaths: falling forward (shot from behind), backward (from the front), and the
    headshot crumple (the knees give way, the body drops sideways)."""
    start = stand_pose(rig)
    keys = [(0.0, start)]

    def body(hips_y, pitch, roll=0.0, z=0.0, x=0.0, spine=0.0, head=(0, 0, 0), legs=None, arms=None, aim=-20,
             settle=False):
        p = rig.new_pose()
        p['hips'] = rig.off['hips'] + np.array([x, hips_y - rig.off['hips'][1], z])
        p['local']['hips'] = rx(pitch) @ rz(roll)
        rig.torso(p, aim=0, twist=10, lean=spine, head=head)
        for side, sx in (('l', -1), ('r', 1)):
            hf, kf = (legs or {}).get(side, (10, 20))
            # thigh forward by hf, knee bent by kf, in the hips' frame
            r_thigh = rx(hf) @ rz(sx * 4)
            r_shin = rx(-kf)
            p['local']['thigh_' + side] = r_thigh
            p['local']['shin_' + side] = r_shin
            p['local']['foot_' + side] = rx(kf * 0.5 - hf * 0.3)
        for side, (wrist, pole) in (arms or {}).items():
            rig.free_arm(p, side, wrist, pole)
        if not arms:
            rot, pos = rig.hold(aim, 0.0, p)
            rig.grip(p, rot, pos)
        if settle:
            rig.settle(p)
        return p

    if style == 'backward':
        keys += [(0.12, body(rig.off['hips'][1] - 0.10, 12, spine=-10, head=(25, 0, 0), legs={'l': (25, 40), 'r': (10, 35)})),
                 (0.40, body(0.55, 50, z=0.10, spine=-15, head=(20, 0, 5), legs={'l': (10, 60), 'r': (0, 45)},
                             arms={'l': ((-0.45, 0.10, 0.05), (0, -1, 1)), 'r': ((0.40, 0.0, -0.10), (0, -1, 1))})),
                 (0.70, body(settle=True, hips_y=0.13, pitch=88, z=0.35, spine=-5, head=(-15, 10, 0), legs={'l': (18, 32), 'r': (6, 14)},
                             arms={'l': ((-0.55, 0.20, 0.0), (0, -1, 1)), 'r': ((0.50, 0.15, -0.05), (0, -1, 1))})),
                 (0.85, body(settle=True, hips_y=0.12, pitch=90, z=0.36, spine=-5, head=(-20, 15, 0), legs={'l': (20, 30), 'r': (8, 12)},
                             arms={'l': ((-0.58, 0.22, 0.02), (0, -1, 1)), 'r': ((0.52, 0.18, -0.05), (0, -1, 1))}))]
    elif style == 'forward':
        keys += [(0.12, body(rig.off['hips'][1] - 0.12, -15, spine=20, head=(-15, 0, 0), legs={'l': (20, 45), 'r': (5, 40)})),
                 (0.38, body(0.48, -35, z=-0.10, spine=25, head=(-10, 0, 0), legs={'l': (10, 95), 'r': (-5, 100)},
                             arms={'l': ((-0.25, -0.30, -0.30), (0, 0, 1)), 'r': ((0.25, -0.30, -0.30), (0, 0, 1))})),
                 (0.66, body(settle=True, hips_y=0.14, pitch=-86, z=-0.55, spine=4, head=(20, -15, 0), legs={'l': (-5, 30), 'r': (-10, 10)},
                             arms={'l': ((-0.35, 0.35, -0.10), (0, 0, 1)), 'r': ((0.30, 0.30, -0.15), (0, 0, 1))})),
                 (0.82, body(settle=True, hips_y=0.13, pitch=-89, z=-0.57, spine=2, head=(25, -20, 0), legs={'l': (-8, 25), 'r': (-12, 8)},
                             arms={'l': ((-0.38, 0.38, -0.08), (0, 0, 1)), 'r': ((0.32, 0.32, -0.12), (0, 0, 1))}))]
    else:  # headshot: head snaps back, knees buckle, the body drops onto its left side
        keys += [(0.08, body(rig.off['hips'][1] - 0.03, 4, head=(35, 0, 10))),
                 (0.32, body(0.50, -10, roll=15, spine=15, head=(30, 0, 20), legs={'l': (70, 110), 'r': (50, 100)},
                             arms={'l': ((-0.30, -0.35, -0.10), (0, 0, 1)), 'r': ((0.25, -0.40, -0.05), (0, 0, 1))})),
                 (0.62, body(settle=True, hips_y=0.16, pitch=-4, roll=86, x=0.30, spine=2, head=(0, 0, 12), legs={'l': (45, 70), 'r': (35, 60)},
                             arms={'l': ((-0.12, 0.28, -0.30), (-1, 0, 0.5)), 'r': ((0.26, -0.18, -0.26), (0, 0, 1))})),
                 (0.80, body(settle=True, hips_y=0.15, pitch=-2, roll=92, x=0.32, spine=0, head=(0, 0, 15), legs={'l': (50, 75), 'r': (40, 65)},
                             arms={'l': ((-0.10, 0.30, -0.32), (-1, 0, 0.5)), 'r': ((0.27, -0.20, -0.27), (0, 0, 1))}))]
    return keyframes(rig, keys, 1.0)


def reload_clip(rig):
    """the AK reload, 2.5 s (the rifle's reload_time; the AnimationTree scales it): tilt the
    rifle, left hand to the magazine, out and down, a fresh one from the vest, in, then over
    the top to rack the charging handle, and back on the foregrip."""
    base = stand_pose(rig)

    def at(gun_tilt, gun_drop, left):
        p = stand_pose(rig)
        rot, pos = rig.hold(0.0, 0.0, p)
        tilted = rot @ pitch_up(-22 * gun_tilt) @ rz(38 * gun_tilt)
        pos = pos + np.array([-0.08 * gun_tilt, -gun_drop, 0.06 * gun_tilt])
        if left == 'fore':
            rig.grip(p, tilted, pos)
        else:
            where, pole = left
            if isinstance(where, str):
                point = pos + tilted @ rig.gun[where]
                wrist = point + tilted @ np.array([-0.05, -0.06, 0.04])
            else:
                w = rig.world(p)
                wrist = w['chest'][1] + w['chest'][0] @ np.asarray(where, float)
            hand = tilted @ rig.hand_l_rot
            rig.grip(p, tilted, pos, left=(wrist, hand, pole))
        return p

    pole = (-0.8, -0.6, 0.1)
    keys = [(0.0, base),
            (0.30, at(1.0, 0.15, 'fore')),
            (0.60, at(1.0, 0.16, ('magazine', pole))),
            (0.95, at(1.0, 0.16, ((-0.10, -0.50, -0.25), pole))),
            (1.30, at(1.0, 0.16, ((-0.10, -0.10, -0.20), pole))),
            (1.65, at(1.0, 0.16, ('magazine', pole))),
            (1.95, at(0.7, 0.10, ('handle', (-0.3, 0.6, 0.4)))),
            (2.10, at(0.7, 0.10, ('handle', (-0.3, 0.6, 0.4)))),
            (2.30, at(0.2, 0.02, 'fore')),
            (2.50, stand_pose(rig))]
    return keyframes(rig, keys, 2.5)


def all_clips(rig):
    """every clip: list of (name, loops, channels)."""
    clips = []
    idle_times, idle_poses = sample(lambda ph: stand_pose(rig, sway=0.012 * math.sin(2 * math.pi * ph)), 3.0, True)
    clips.append(('idle', True, keyed(rig, idle_times, idle_poses)))
    ci_times, ci_poses = sample(lambda ph: stand_pose(rig, crouch=True, sway=0.008 * math.sin(2 * math.pi * ph)), 3.0, True)
    clips.append(('crouch_idle', True, keyed(rig, ci_times, ci_poses)))
    for kind, prefix in (('walk', 'walk'), ('run', 'run'), ('crouch', 'crouch_walk')):
        for d in DIRECTIONS:
            t, p = locomotion(rig, kind, d)
            clips.append((f'{prefix}_{d}', True, keyed(rig, t, p)))
    stand = stand_pose(rig)
    clips.append(('jump', False, keyed(rig, *keyframes(rig, [(0.0, stand_pose(rig)), (0.08, air_pose(rig, 0.0)),
                                                             (0.25, air_pose(rig, 0.6))], 0.25))))
    clips.append(('fall', True, keyed(rig, *sample(lambda ph: air_pose(rig, 0.55 + 0.05 * math.sin(2 * math.pi * ph)), 1.0, True))))
    clips.append(('fall_crouch', True, keyed(rig, *sample(lambda ph: air_pose(rig, 0.9, crouch=True), 1.0, True))))
    land_low = _with_hips(rig, stand, -0.10)
    clips.append(('land', False, keyed(rig, *keyframes(rig, [(0.0, air_pose(rig, 0.3)), (0.08, land_low),
                                                             (0.30, stand_pose(rig))], 0.30))))
    for name, aim in (('aim_d80', -80), ('aim_d40', -40), ('aim_0', 0), ('aim_u40', 40), ('aim_u80', 80)):
        p = stand_pose(rig, aim=aim)
        clips.append((name, False, keyed(rig, np.array([0.0]), [p])))
    # fire: the gun kicks back and up and the chest rocks, as differences from aiming level
    def fire_at(t):
        k = math.exp(-t / 0.035) * min(1.0, t / 0.012) if t > 0 else 0.0
        p = stand_pose(rig)
        rig.torso(p, aim=3.0 * k, lean=-2.0 * k)
        rot, pos = rig.hold(3.0 * k, 0.035 * k, p)
        rig.grip(p, rot, pos)
        return p
    times, poses = sample(fire_at, 0.15, False)
    clips.append(('fire', False, keyed(rig, times, additive(rig, stand, poses, UPPER), UPPER)))
    # flinch: a jolt back and to the side, as differences from aiming level
    def flinch_at(t):
        k = math.sin(math.pi * min(t / 0.30, 1.0)) * math.exp(-t / 0.2)
        p = stand_pose(rig)
        rig.torso(p, aim=6 * k, lean=-8 * k, tilt=6 * k, head=(14 * k, 0, 8 * k))
        rot, pos = rig.hold(6 * k, 0.0, p)
        rig.grip(p, rot, pos)
        return p
    times, poses = sample(flinch_at, 0.30, False)
    clips.append(('flinch', False, keyed(rig, times, additive(rig, stand, poses, UPPER), UPPER)))
    times, poses = reload_clip(rig)
    clips.append(('reload', False, keyed(rig, times, poses)))
    for style in ('forward', 'backward', 'headshot'):
        times, poses = death(rig, style)
        clips.append((f'death_{style}', False, keyed(rig, times, poses)))
    return clips


def _with_hips(rig, pose, dy):
    """the same stance with the hips lowered by -dy, legs re-solved onto the same feet."""
    p = rig.new_pose()
    p['local'] = {b: m.copy() for b, m in pose['local'].items()}
    p['hips'] = pose['hips'] + np.array([0, dy, 0])
    w0 = rig.world(pose)
    for side in ('l', 'r'):
        rf, pf = w0['foot_' + side]
        knee_dir = w0['shin_' + side][0] @ np.array([0, 0, -1.0])
        rig.leg(p, side, pf, rf, knee_dir)
    rig.aim_pose(p, 0.0)
    return p
