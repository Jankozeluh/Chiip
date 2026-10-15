class_name Player
extends CharacterBody3D
## The player: first-person mouse look and Counter-Strike-style movement.
##
## Movement follows the Quake/Source engine model that CS is built on:
## friction slows you down on the ground, acceleration pushes you toward the
## direction you hold, and top speed depends on what you're doing.
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
## Top running speed. CS: 250 units/s with the knife out.
@export var max_speed: float = 250.0 * UNITS_TO_METRES

@export_group("Ground")
## How quickly you speed up on the ground. CS:GO: sv_accelerate 5.5.
@export var ground_acceleration: float = 5.5
## How quickly you slow down on the ground. CS:GO: sv_friction 5.2.
@export var friction: float = 5.2
## Below this speed, friction acts as if you were moving this fast, so you come
## to a full stop quickly. CS: sv_stopspeed 80 units/s.
@export var stop_speed: float = 80.0 * UNITS_TO_METRES

@export_group("Camera")
## Standing eye height above the feet. CS: 64 units.
@export var stand_eye_height: float = 64.0 * UNITS_TO_METRES

## Horizontal look angle (left/right) in radians.
var _yaw: float = 0.0
## Vertical look angle (up/down) in radians.
var _pitch: float = 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	_yaw = rotation.y
	_head.position.y = stand_eye_height
	# The camera is placed by code every rendered frame (see _process) instead
	# of following its parent, so mouse look has no physics-tick delay.
	_camera.top_level = true
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Face where the mouse points, so "forward" is where you look.
	rotation.y = _yaw

	var wish_direction := _get_wish_direction()
	if is_on_floor():
		velocity.y = 0.0
		_apply_friction(delta)
		_accelerate(wish_direction, max_speed, ground_acceleration, delta)
	else:
		velocity += get_gravity() * delta
	move_and_slide()


func _process(_delta: float) -> void:
	# Position: where the head is drawn this frame (smoothed between physics ticks).
	_camera.global_position = _head.get_global_transform_interpolated().origin
	# Rotation: straight from the mouse, so looking around is instant.
	_camera.global_rotation = Vector3(_pitch, _yaw, 0.0)


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


## Speeds you up toward wish_direction until you reach wish_speed in that
## direction (Quake/Source acceleration). Speed in other directions isn't
## capped, which is what makes counter-strafing and air strafing work.
func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	var current_speed := velocity.dot(wish_direction)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(acceleration * wish_speed * delta, add_speed)
	velocity += wish_direction * accel_speed
