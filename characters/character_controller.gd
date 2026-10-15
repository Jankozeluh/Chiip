class_name CharacterController
extends Node
## Base class for whatever drives a [Character]: the local player, a bot, or
## (in M9) a network player. Add it as a child of the character.
##
## Every physics tick the character calls [method get_input] and simulates the
## command it returns. Subclasses override the methods below.

## The character this controller drives (its parent).
var character: Character


func _enter_tree() -> void:
	character = get_parent() as Character


## Returns this tick's commands. [param delta] is the length of the tick in seconds.
func get_input(_delta: float) -> CharacterInput:
	return CharacterInput.new()


## Turns the view to these angles, in radians. Used when something other than
## the controller sets the aim, such as tests or spawning.
func set_look_angles(_yaw: float, _pitch: float) -> void:
	pass


## Called after the character respawns, to reset whatever the controller remembers.
func on_respawned() -> void:
	pass


## True for the player sitting at this computer: their own sounds play
## without position (in both ears) instead of from a point in the world.
func is_local() -> bool:
	return false


## The camera this controller shows the character through, if it has one.
func get_camera() -> Camera3D:
	return null
