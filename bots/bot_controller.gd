class_name BotController
extends CharacterController
## Drives a [Character] as a bot. It produces the same [CharacterInput]
## commands a player's keyboard and mouse would, so bots follow exactly the
## player's movement and shooting rules.
##
## The bot is a small state machine:
## - [b]Patrol[/b]: walk between patrol points (or random spots on the map).
## - [b]Engage[/b]: an enemy is visible. Stop, aim like a person (reaction time,
##   aim that settles onto the target), and shoot in bursts or sprays.
## - [b]Search[/b]: the enemy is out of sight but remembered (seen or heard).
##   Walk to the last known position, look around, then go back to patrolling.
##
## What it knows comes from its [BotSenses]; how well it fights comes from its
## [BotDifficulty]. Movement uses a [NavigationAgent3D] (sibling node).

enum State { PATROL, ENGAGE, SEARCH }

## How fast the bot turns its view while walking, in degrees per second.
const WALK_TURN_SPEED := 360.0
## How close the aim must be to where the bot wants it before it pulls the trigger, in degrees.
const ON_TARGET_DEGREES := 2.5
## How long the bot looks around after reaching the last known position, in seconds.
const LOOK_AROUND_TIME := 2.0
## Group of Marker3D nodes on the map that bots patrol between.
const PATROL_GROUP := "patrol_points"

## How well this bot fights.
@export var difficulty: BotDifficulty = preload("res://bots/difficulty_normal.tres")

## What the bot is doing right now. Read-only for other scripts.
var state: State = State.PATROL

## Horizontal and vertical look angles in radians.
var _yaw: float = 0.0
var _pitch: float = 0.0
## The enemy being fought.
var _target: Character = null
## Seconds left before the bot reacts to a newly spotted enemy.
var _reaction_left: float = 0.0
## Seconds since the bot spotted its current target (drives how much the aim has settled).
var _time_on_target: float = 0.0
## The initial aim error, in degrees; it shrinks as the aim settles.
var _aim_error: Vector2 = Vector2.ZERO
## Drives the leftover "shaky hands" error, which wanders around the target
## instead of staying on one side (that would miss in the same spot forever).
var _wobble_phase: float = 0.0
## Aim at the head (true) or the chest (false) for this engagement.
var _aiming_for_head: bool = false
## Shots fired in the current burst or spray, and the pause left before the next.
var _shots_in_burst: int = 0
var _pause_left: float = 0.0
## Seconds spent looking around at the end of a search.
var _look_around_left: float = 0.0
## Randomness for aim error and decisions. Seed it for repeatable tests.
var rng := RandomNumberGenerator.new()

@onready var _agent: NavigationAgent3D = get_parent().get_node("NavigationAgent3D")
@onready var _senses: BotSenses = get_parent().get_node("BotSenses")


func _ready() -> void:
	_senses.enemy_spotted.connect(_on_enemy_spotted)
	character.weapon.fired.connect(_on_weapon_fired)


## Walks to a point on the map along the navigation mesh.
func move_to(target: Vector3) -> void:
	_agent.target_position = target


## True when the bot has arrived (or has nowhere to go).
func has_arrived() -> bool:
	return _agent.is_navigation_finished()


func set_look_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func on_respawned() -> void:
	state = State.PATROL
	_target = null
	_senses.reset()
	_pick_patrol_point()


func get_input(delta: float) -> CharacterInput:
	_update_state()
	var input := CharacterInput.new()
	match state:
		State.PATROL:
			_patrol(input, delta)
		State.ENGAGE:
			_engage(input, delta)
		State.SEARCH:
			_search(input, delta)
	input.yaw = _yaw
	input.pitch = _pitch
	return input


# --- Deciding what to do ---


func _update_state() -> void:
	if _senses.visible_enemy != null:
		if state != State.ENGAGE or _senses.visible_enemy != _target:
			_start_engaging(_senses.visible_enemy)
		state = State.ENGAGE
	elif state == State.ENGAGE or (state == State.PATROL and _senses.has_lead()):
		# Lost sight of the enemy, or heard one: go and check.
		state = State.SEARCH
		_target = null
		move_to(_senses.last_known_position)
		_look_around_left = LOOK_AROUND_TIME
	elif state == State.SEARCH and not _senses.has_lead():
		state = State.PATROL
		_pick_patrol_point()


func _on_enemy_spotted(enemy: Character) -> void:
	if state != State.ENGAGE:
		_start_engaging(enemy)


func _start_engaging(enemy: Character) -> void:
	_target = enemy
	_reaction_left = difficulty.reaction_time * rng.randf_range(0.8, 1.2)
	_time_on_target = 0.0
	var direction := rng.randf() * TAU
	_aim_error = Vector2(cos(direction), sin(direction)) * difficulty.initial_aim_error
	_wobble_phase = rng.randf() * TAU
	_aiming_for_head = rng.randf() < difficulty.headshot_chance
	_shots_in_burst = 0
	_pause_left = 0.0


# --- States ---


func _patrol(input: CharacterInput, delta: float) -> void:
	if has_arrived():
		_pick_patrol_point()
	_walk(input, delta, true)


func _search(input: CharacterInput, delta: float) -> void:
	if not has_arrived():
		# Walk there while looking toward where the enemy was (holding the angle).
		_walk(input, delta, false)
		_turn_toward_point(_senses.last_known_position + Vector3.UP * 1.5, WALK_TURN_SPEED, delta)
		return
	_look_around_left -= delta
	_yaw += deg_to_rad(90.0) * delta
	if _look_around_left <= 0.0:
		_senses.forget()


func _engage(input: CharacterInput, delta: float) -> void:
	_time_on_target += delta
	_reaction_left -= delta
	_pause_left -= delta

	# Aim: where the target is, minus the recoil the bot pulls against, plus a
	# human error that shrinks as the aim settles.
	var aim_point := _target.get_eye_position() if _aiming_for_head else _target.get_visibility_points()[1]
	var to_target := aim_point - character.get_eye_position()
	var desired := Vector2(atan2(-to_target.x, -to_target.z), asin(to_target.normalized().y))
	var recoil := character.weapon.data.get_spray_offset(maxf(character.weapon.get_spray_shot() - 1, 0))
	desired.x += deg_to_rad(recoil.x * difficulty.recoil_control)
	desired.y -= deg_to_rad(recoil.y * difficulty.recoil_control)
	var settle := exp(-_time_on_target / difficulty.aim_settle_time)
	_wobble_phase += delta * 2.0
	var wobble := Vector2(sin(_wobble_phase), sin(_wobble_phase * 1.37 + 1.0)) * difficulty.minimum_aim_error
	var error := _aim_error * settle + wobble
	desired += Vector2(deg_to_rad(error.x), deg_to_rad(error.y))
	_turn_toward(desired.x, desired.y, difficulty.aim_turn_speed, delta)

	# Stop before shooting, like a player: counter-strafe or just let go.
	var horizontal := Vector3(character.velocity.x, 0.0, character.velocity.z)
	var accurate_speed := character.get_max_speed() * Weapon.ACCURATE_SPEED_FRACTION
	var stopped := horizontal.length() < accurate_speed
	if not stopped and difficulty.counter_strafes:
		input.move = _keys_for_direction(-horizontal.normalized())

	# Shoot when reacted, stopped, on target and not pausing between bursts.
	var off_target := rad_to_deg(Vector2(angle_difference(_yaw, desired.x), _pitch - desired.y).length())
	input.shoot = (_reaction_left <= 0.0 and stopped and off_target <= ON_TARGET_DEGREES
			and _pause_left <= 0.0 and not character.weapon.is_reloading())


func _on_weapon_fired(_spray_shot: int) -> void:
	if state != State.ENGAGE or _target == null:
		return
	_shots_in_burst += 1
	var far := character.global_position.distance_to(_target.global_position) > difficulty.burst_distance
	var limit := difficulty.burst_length if far else difficulty.spray_length
	if _shots_in_burst >= limit:
		_shots_in_burst = 0
		_pause_left = difficulty.burst_pause


# --- Moving and looking ---


## Follows the current path. With [param face_path] the bot looks where it walks.
func _walk(input: CharacterInput, delta: float, face_path: bool) -> void:
	var direction := _get_walk_direction()
	if direction == Vector3.ZERO:
		return
	if face_path:
		_turn_toward(atan2(-direction.x, -direction.z), 0.0, WALK_TURN_SPEED, delta)
	input.move = _keys_for_direction(direction)


func _pick_patrol_point() -> void:
	var points := get_tree().get_nodes_in_group(PATROL_GROUP)
	if not points.is_empty():
		move_to((points[rng.randi() % points.size()] as Node3D).global_position)
		return
	var map := character.get_world_3d().navigation_map
	move_to(NavigationServer3D.map_get_random_point(map, 1, true))


## The flat direction toward the next waypoint, or zero when there's nowhere to go.
func _get_walk_direction() -> Vector3:
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - character.global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		return Vector3.ZERO
	return to_next.normalized()


func _turn_toward_point(point: Vector3, speed: float, delta: float) -> void:
	var to_point := point - character.get_eye_position()
	if to_point.length() < 0.1:
		return
	_turn_toward(atan2(-to_point.x, -to_point.z), asin(to_point.normalized().y), speed, delta)


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
