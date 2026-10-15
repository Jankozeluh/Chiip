class_name Player
extends CharacterBody3D
## The player: first-person mouse look and Counter-Strike-style movement.
##
## Movement follows the Quake/Source engine model that CS is built on:
## friction slows you down on the ground, acceleration pushes you toward the
## direction you hold, and in the air you only get a little control, which is
## what makes air strafing possible.
##
## Distances are in metres and speeds in metres per second. CS values are
## converted with [constant UNITS_TO_METRES]. See docs/GAME_DESIGN.md, section 4.1.

## CS/Source distance units to metres (1 unit ≈ 1 inch).
const UNITS_TO_METRES := 0.0254
## Degrees turned per mouse count at sensitivity 1, the same as CS's m_yaw and m_pitch.
const DEGREES_PER_MOUSE_COUNT := 0.022
## How far up or down you can look, in degrees (CS: 89).
const MAX_PITCH_DEGREES := 89.0

@export_group("Mouse")
## Mouse sensitivity on CS's scale: each mouse count turns sensitivity × 0.022°.
@export var sensitivity: float = 1.0
## Flip vertical mouse look.
@export var invert_y: bool = false

@export_group("Speed")
## Top running speed with nothing in hand. CS: 250 units/s with the knife out.
## A held weapon sets its own top speed; see [method get_max_speed].
@export var max_speed: float = 250.0 * UNITS_TO_METRES
## Walking (Shift) speed as a fraction of the top speed. CS: 0.52.
@export var walk_speed_factor: float = 0.52
## Crouching speed as a fraction of the top speed. CS: 0.34.
@export var crouch_speed_factor: float = 0.34

@export_group("Ground")
## How quickly you speed up on the ground. CS:GO: sv_accelerate 5.5.
@export var ground_acceleration: float = 5.5
## How quickly you slow down on the ground. CS:GO: sv_friction 5.2.
@export var friction: float = 5.2
## Below this speed, friction acts as if you were moving this fast, so you come
## to a full stop quickly. CS: sv_stopspeed 80 units/s.
@export var stop_speed: float = 80.0 * UNITS_TO_METRES

@export_group("Air")
## How much control you have in the air. CS:GO: sv_airaccelerate 12.
@export var air_acceleration: float = 12.0
## The most speed you can add in any one direction while in the air. It's low,
## which is why you can't run in the air but can air strafe. Source: 30 units/s.
@export var air_speed_cap: float = 30.0 * UNITS_TO_METRES

@export_group("Jump")
## How high your feet rise in a standing jump. CS: about 57 units.
@export var jump_height: float = 57.0 * UNITS_TO_METRES
## Jumping caps your horizontal speed at this multiple of the top speed, so bunny
## hopping can't build up speed. Source engine: 1.2.
@export var bunny_hop_cap: float = 1.2

@export_group("Crouch")
## Standing eye height above the feet. CS: 64 units.
@export var stand_eye_height: float = 64.0 * UNITS_TO_METRES
## Crouched eye height above the feet. CS: 46 units.
@export var crouch_eye_height: float = 46.0 * UNITS_TO_METRES
## Seconds for the view to move between standing and crouched height.
@export var crouch_transition_time: float = 0.15

## True while crouched (the smaller collision capsule is active). Read-only for other scripts.
var is_crouching: bool = false

## Horizontal look angle (left/right) in radians.
var _yaw: float = 0.0
## Vertical look angle (up/down) in radians.
var _pitch: float = 0.0
## Set when jump is pressed and used up by the next physics tick.
var _jump_queued: bool = false
## True while a click shouldn't shoot: after freeing the mouse, and for the
## click that captures it again, until the button is released.
var _shooting_blocked: bool = false
## Current eye height above the feet. Moves smoothly toward the standing or crouched height.
var _eye_height: float = 0.0
## How much taller the standing capsule is than the crouching one (CS: 18 units).
var _hull_height_difference: float = 0.0

## The gun in your hands.
@onready var weapon: Weapon = $Head/Camera3D/Weapon
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _standing_collision: CollisionShape3D = $StandingCollision
@onready var _crouching_collision: CollisionShape3D = $CrouchingCollision


func _ready() -> void:
	_yaw = rotation.y
	_eye_height = stand_eye_height
	_head.position.y = _eye_height
	var standing_shape := _standing_collision.shape as CapsuleShape3D
	var crouching_shape := _crouching_collision.shape as CapsuleShape3D
	_hull_height_difference = standing_shape.height - crouching_shape.height
	_set_crouch_hull(false)
	# The camera is placed by code every rendered frame (see _process) instead
	# of following its parent, so mouse look has no physics-tick delay.
	_camera.top_level = true
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	weapon.equip(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("jump"):
		# Remember the press; the next physics tick decides whether you jump.
		# This also catches mouse-wheel jumps, which press and release instantly.
		_jump_queued = true
	elif event.is_action_pressed("reload"):
		weapon.reload()
	elif event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_shooting_blocked = true
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_shooting_blocked = false
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# This click only captures the mouse; it shouldn't also fire a shot.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_shooting_blocked = true
	elif event.is_action_released("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shooting_blocked = false


func _physics_process(delta: float) -> void:
	# Face where the mouse points, so "forward" is where you look.
	rotation.y = _yaw
	# The weapon processes after the player (children run after their parent),
	# so it sees this tick's trigger state.
	weapon.trigger_held = Input.is_action_pressed("shoot") and not _shooting_blocked

	var on_ground := is_on_floor()
	var wants_jump := _jump_queued
	_jump_queued = false
	# As in CS, you jump only on the tick you press jump while on the ground.
	# Holding jump doesn't jump again when you land.
	if on_ground and wants_jump:
		_jump()
		on_ground = false

	_update_crouch(on_ground, delta)

	var wish_direction := _get_wish_direction()
	var wish_speed := _get_wish_speed()
	if on_ground:
		velocity.y = 0.0
		_apply_friction(delta)
		_accelerate(wish_direction, wish_speed, _get_stance_factor() * max_speed, delta)
		move_and_slide()
	else:
		_air_accelerate(wish_direction, wish_speed, delta)
		# Half the gravity before moving and half after (as the Source engine
		# does) makes the jump height exact at any tick rate.
		var half_gravity := get_gravity() * delta * 0.5
		velocity += half_gravity
		move_and_slide()
		velocity += half_gravity


func _process(_delta: float) -> void:
	# Position: where the head is drawn this frame (smoothed between physics ticks).
	_camera.global_position = _head.get_global_transform_interpolated().origin
	# Rotation: straight from the mouse, so looking around is instant.
	_camera.global_rotation = Vector3(_pitch, _yaw, 0.0)


## Where shots start from: the eyes, as of this physics tick.
func get_eye_position() -> Vector3:
	return _head.global_position


## Where you're aiming as (yaw, pitch) in radians, without any recoil.
func get_aim_angles() -> Vector2:
	return Vector2(_yaw, _pitch)


## Turns the view to look at a world position. Used by tests.
func aim_at(target: Vector3) -> void:
	var direction := (target - get_eye_position()).normalized()
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(direction.y)
	rotation.y = _yaw


## Top running speed right now: set by the held weapon (CS: rifles 215 u/s),
## or [member max_speed] with nothing in hand.
func get_max_speed() -> float:
	if weapon != null and weapon.data != null:
		return weapon.data.max_speed_units * UNITS_TO_METRES
	return max_speed


## Turns the view by a mouse movement measured in mouse counts.
func _look(mouse_motion: Vector2) -> void:
	var radians_per_count := deg_to_rad(sensitivity * DEGREES_PER_MOUSE_COUNT)
	var vertical_sign := -1.0 if invert_y else 1.0
	_yaw -= mouse_motion.x * radians_per_count
	_pitch -= mouse_motion.y * radians_per_count * vertical_sign
	_pitch = clampf(_pitch, deg_to_rad(-MAX_PITCH_DEGREES), deg_to_rad(MAX_PITCH_DEGREES))


## Returns the horizontal direction the movement keys point to, relative to where you look.
func _get_wish_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()


## Returns the top speed for the current stance and weapon.
func _get_wish_speed() -> float:
	return get_max_speed() * _get_stance_factor()


## Returns the speed fraction for the current stance: crouching, walking or running.
func _get_stance_factor() -> float:
	if is_crouching:
		return crouch_speed_factor
	if Input.is_action_pressed("walk"):
		return walk_speed_factor
	return 1.0


## Slows you down on the ground (Quake/Source friction).
func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# Slow speeds lose as much as stop_speed would, so you stop crisply instead of sliding.
	var control := maxf(speed, stop_speed)
	var new_speed := maxf(speed - control * friction * delta, 0.0)
	velocity.x *= new_speed / speed
	velocity.z *= new_speed / speed


## Speeds you up on the ground toward wish_direction until you reach
## wish_speed in that direction (Quake/Source acceleration). Speed in other
## directions isn't capped, which is what makes counter-strafing work.
##
## How hard you accelerate comes from [param acceleration_speed]: CS:GO uses
## the empty-handed top speed (250 u/s) scaled for walking or crouching, not
## the weapon's speed. Otherwise crouch-walking with a rifle (73 u/s) couldn't
## overcome friction at all.
func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration_speed: float, delta: float) -> void:
	var current_speed := velocity.dot(wish_direction)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(ground_acceleration * acceleration_speed * delta, add_speed)
	velocity += wish_direction * accel_speed


## Air control (Source's AirAccelerate). Like _accelerate, but you can only
## build up air_speed_cap in the direction you hold. Turning your view while
## holding a strafe key keeps that small push pointing sideways, so you can
## curve and even gain speed: air strafing.
func _air_accelerate(wish_direction: Vector3, wish_speed: float, delta: float) -> void:
	var capped_wish_speed := minf(wish_speed, air_speed_cap)
	var current_speed := velocity.dot(wish_direction)
	var add_speed := capped_wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(air_acceleration * wish_speed * delta, add_speed)
	velocity += wish_direction * accel_speed


## Launches you upward and caps horizontal speed (CS's bunny hop limit).
func _jump() -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed_cap := get_max_speed() * bunny_hop_cap
	if horizontal.length() > speed_cap:
		horizontal = horizontal.normalized() * speed_cap
	# The upward speed needed to rise exactly jump_height: v = √(2 · g · h).
	velocity = horizontal + Vector3.UP * sqrt(2.0 * get_gravity().length() * jump_height)


## Crouches or stands up to match the crouch key, and moves the view smoothly.
func _update_crouch(on_ground: bool, delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch and not is_crouching:
		_crouch(on_ground)
	elif not wants_crouch and is_crouching:
		_try_stand_up(on_ground)

	var target_eye_height := crouch_eye_height if is_crouching else stand_eye_height
	var eye_speed := (stand_eye_height - crouch_eye_height) / crouch_transition_time
	_eye_height = move_toward(_eye_height, target_eye_height, eye_speed * delta)
	_head.position.y = _eye_height


func _crouch(on_ground: bool) -> void:
	is_crouching = true
	_set_crouch_hull(true)
	if not on_ground:
		# In the air, crouching pulls your legs up instead of lowering your
		# head (CS's crouch-jump): lift the body so the head stays in place.
		global_position.y += _hull_height_difference
		_eye_height -= _hull_height_difference


func _try_stand_up(on_ground: bool) -> void:
	if on_ground:
		# Standing up raises your head, so there must be room above.
		if test_move(global_transform, Vector3.UP * _hull_height_difference):
			return
	else:
		# In the air your legs come back down, so there must be room below.
		if test_move(global_transform, Vector3.DOWN * _hull_height_difference):
			return
		global_position.y -= _hull_height_difference
		_eye_height += _hull_height_difference
	is_crouching = false
	_set_crouch_hull(false)


## Switches between the standing and the crouching collision capsule.
func _set_crouch_hull(crouched: bool) -> void:
	_standing_collision.disabled = crouched
	_crouching_collision.disabled = not crouched
