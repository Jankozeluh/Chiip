class_name PlayerController
extends CharacterController
## Drives a [Character] with the keyboard and mouse, and runs the first-person
## camera.
##
## Mouse look updates the view every rendered frame, so it has no delay. Keys
## and buttons are turned into a [CharacterInput] command once per physics
## tick, when the character asks for it.

## Degrees turned per mouse count at sensitivity 1, the same as CS's m_yaw and m_pitch.
const DEGREES_PER_MOUSE_COUNT := 0.022
## How far up or down you can look, in degrees (CS: 89).
const MAX_PITCH_DEGREES := 89.0

@export_group("Mouse")
## Mouse sensitivity on CS's scale: each mouse count turns sensitivity × 0.022°.
@export var sensitivity: float = 1.0
## Flip vertical mouse look.
@export var invert_y: bool = false

@export_group("")
## The first-person camera.
@export var camera: Camera3D

## Horizontal look angle (left/right) in radians.
var _yaw: float = 0.0
## Vertical look angle (up/down) in radians.
var _pitch: float = 0.0
## Set when jump is pressed and used up by the next command.
var _jump_queued: bool = false
## Set when reload is pressed and used up by the next command.
var _reload_queued: bool = false
## True while a click shouldn't shoot: after freeing the mouse, and for the
## click that captures it again, until the button is released.
var _shooting_blocked: bool = false


func _ready() -> void:
	# The camera is placed by code every rendered frame (see _process) instead
	# of following its parent, so mouse look has no physics-tick delay.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Hide your own body from your camera. Its hit zones still work, since
	# hiding a node doesn't affect physics.
	character.get_node("Body").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if DevConsole.is_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("jump"):
		# Remember the press; the next command decides whether you jump.
		# This also catches mouse-wheel jumps, which press and release instantly.
		_jump_queued = true
	elif event.is_action_pressed("reload"):
		_reload_queued = true
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


func get_input(_delta: float) -> CharacterInput:
	var input := CharacterInput.new()
	if DevConsole.is_open:
		# Typing in the console shouldn't move or shoot.
		input.yaw = _yaw
		input.pitch = _pitch
		return input
	input.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input.yaw = _yaw
	input.pitch = _pitch
	input.jump = _jump_queued
	input.reload = _reload_queued
	_jump_queued = false
	_reload_queued = false
	input.crouch = Input.is_action_pressed("crouch")
	input.walk = Input.is_action_pressed("walk")
	input.shoot = Input.is_action_pressed("shoot") and not _shooting_blocked
	return input


func set_look_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func get_camera() -> Camera3D:
	return camera


func is_local() -> bool:
	return true


func on_respawned() -> void:
	_jump_queued = false
	_reload_queued = false


func _process(_delta: float) -> void:
	# Position: where the head is drawn this frame (smoothed between physics ticks).
	camera.global_position = character.head.get_global_transform_interpolated().origin
	# Rotation: straight from the mouse, so looking around is instant, plus the
	# weapon's recoil kick (which moves the view but not your aim).
	var punch := character.weapon.view_punch if character.weapon != null else Vector2.ZERO
	camera.global_rotation = Vector3(_pitch + deg_to_rad(punch.y), _yaw - deg_to_rad(punch.x), 0.0)


## Turns the view by a mouse movement measured in mouse counts.
func _look(mouse_motion: Vector2) -> void:
	var radians_per_count := deg_to_rad(sensitivity * DEGREES_PER_MOUSE_COUNT)
	var vertical_sign := -1.0 if invert_y else 1.0
	_yaw -= mouse_motion.x * radians_per_count
	_pitch -= mouse_motion.y * radians_per_count * vertical_sign
	_pitch = clampf(_pitch, deg_to_rad(-MAX_PITCH_DEGREES), deg_to_rad(MAX_PITCH_DEGREES))
