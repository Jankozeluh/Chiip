class_name SoldierBody
extends Node3D
## The visible soldier and its hit zones, with a simple walk animation done in
## code (procedural): legs swing from the hips, arms swing a little from the
## shoulders, and the upper body bobs with each step. It replaces gliding
## until real animated models arrive.
##
## The [Character] calls [method update_pose] every physics tick. Hit zones
## move with the limbs, like CS hitboxes follow the animation.

## Distance covered by one full walk cycle (two steps), in metres. Matches
## Character.STEP_DISTANCE so footsteps land in time with the legs.
const CYCLE_DISTANCE := 3.6
## How far the legs swing at full running speed, in degrees.
const LEG_SWING_DEGREES := 30.0
## How far the arms swing at full running speed, in degrees (they hold a rifle).
const ARM_SWING_DEGREES := 8.0
## How high the upper body bobs at full running speed, in metres.
const BOB_HEIGHT := 0.03
## How quickly the swing grows when starting and settles when stopping (per second).
const SWING_RESPONSIVENESS := 8.0

## Where in the walk cycle the legs are, in radians.
var _phase: float = 0.0
## How strong the swing is right now: 0 = standing, 1 = full run.
var _swing: float = 0.0

@onready var _upper: Node3D = $Upper
@onready var _left_hip: Node3D = $Legs/LeftHip
@onready var _right_hip: Node3D = $Legs/RightHip
@onready var _left_shoulder: Node3D = $Upper/LeftShoulder
@onready var _right_shoulder: Node3D = $Upper/RightShoulder


## Moves the limbs for this tick. [param speed] is the horizontal speed in m/s,
## [param run_speed] the character's top speed, [param crouch_offset] how far
## the upper body sinks (negative when crouched), [param on_ground] whether the
## feet touch the ground.
func update_pose(speed: float, run_speed: float, crouch_offset: float, on_ground: bool, delta: float) -> void:
	var target_swing := clampf(speed / run_speed, 0.0, 1.0) if on_ground else 0.0
	_swing = lerpf(_swing, target_swing, 1.0 - exp(-SWING_RESPONSIVENESS * delta))
	_phase = fmod(_phase + speed * delta * TAU / CYCLE_DISTANCE, TAU)
	var stride := sin(_phase) * _swing
	_left_hip.rotation.x = deg_to_rad(LEG_SWING_DEGREES) * stride
	_right_hip.rotation.x = -deg_to_rad(LEG_SWING_DEGREES) * stride
	_left_shoulder.rotation.x = -deg_to_rad(ARM_SWING_DEGREES) * stride
	_right_shoulder.rotation.x = deg_to_rad(ARM_SWING_DEGREES) * stride
	_upper.position.y = crouch_offset + absf(sin(_phase)) * BOB_HEIGHT * _swing


## Back to standing still, upright (on respawn).
func reset_pose() -> void:
	_phase = 0.0
	_swing = 0.0
	for joint in [_left_hip, _right_hip, _left_shoulder, _right_shoulder]:
		joint.rotation = Vector3.ZERO
	_upper.position.y = 0.0
	rotation = Vector3.ZERO
