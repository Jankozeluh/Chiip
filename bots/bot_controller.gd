class_name BotController
extends CharacterController
## Drives a [Character] as a bot. It produces the same [CharacterInput]
## commands a player's keyboard and mouse would, so bots follow exactly the
## player's movement and shooting rules.
##
## Movement: a [NavigationAgent3D] (sibling node) finds a path on the map's
## navigation mesh; each tick the bot "presses" the movement keys that point
## toward the next waypoint and turns its view at a limited speed, like a person.

## How fast the bot turns its view while walking, in degrees per second.
@export var walk_turn_speed: float = 360.0

## Horizontal and vertical look angles in radians.
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var _agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")


## Walks to a point on the map along the navigation mesh.
func move_to(target: Vector3) -> void:
	_agent.target_position = target


## True when the bot has arrived (or has nowhere to go).
func has_arrived() -> bool:
	return _agent.is_navigation_finished()


func get_input(delta: float) -> CharacterInput:
	var input := CharacterInput.new()
	var direction := _get_walk_direction()
	if direction != Vector3.ZERO:
		_turn_toward(atan2(-direction.x, -direction.z), 0.0, walk_turn_speed, delta)
		input.move = _keys_for_direction(direction)
	input.yaw = _yaw
	input.pitch = _pitch
	return input


func set_look_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


## The flat direction toward the next waypoint, or zero when there's nowhere to go.
func _get_walk_direction() -> Vector3:
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - character.global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		return Vector3.ZERO
	return to_next.normalized()


## Turns the view toward (yaw, pitch) by at most [param speed] degrees per second.
func _turn_toward(yaw: float, pitch: float, speed: float, delta: float) -> void:
	var max_step := deg_to_rad(speed) * delta
	_yaw += clampf(angle_difference(_yaw, yaw), -max_step, max_step)
	_pitch += clampf(pitch - _pitch, -max_step, max_step)


## The movement keys (as a CharacterInput.move vector) that walk in a world
## direction, given where the bot is facing this tick.
func _keys_for_direction(direction: Vector3) -> Vector2:
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	return Vector2(direction.dot(right), -direction.dot(forward))
