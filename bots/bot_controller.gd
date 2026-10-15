class_name BotController
extends CharacterController
## Drives a [Character] as a bot. It produces the same [CharacterInput]
## commands a player's keyboard and mouse would, so bots follow exactly the
## player's movement and shooting rules.
##
## The bot is a small state machine:
## - [b]Patrol[/b]: follow its orders for the round (see [enum Role]): push
##   along an attack route, hold a spot, or (in practice mode) walk between
##   patrol points (or random spots on the map).
## - [b]Engage[/b]: an enemy is visible. Stop, aim like a person (reaction time,
##   aim that settles onto the target), and shoot in bursts or sprays.
## - [b]Search[/b]: the enemy is out of sight but remembered (seen or heard).
##   Walk to the last known position, look around, then go back to its orders.
##   Defenders only leave their spot for enemies close by.
##
## In a match, [BotTactics] gives every bot its orders at the start of each round.
##
## What it knows comes from its [BotSenses]; how well it fights comes from its
## [BotDifficulty]. Movement uses a [NavigationAgent3D] (sibling node).

enum State { PATROL, ENGAGE, SEARCH }
## What the bot does when it isn't fighting or searching.
enum Role {
	## Walk between patrol points (practice mode, maps without a plan).
	PATROL,
	## Push along an attack route toward the defenders' end, then clear it.
	ATTACK,
	## Hold a spot near its own end, watching the angle the spot faces.
	DEFEND,
}

## The fastest the bot turns its view while walking, in degrees per second.
const WALK_TURN_SPEED := 200.0
## How quickly the view eases toward where the bot wants to look (per second).
## Turning eases in and out like a hand on a mouse, instead of snapping at a
## constant speed. Small corrections are gentle, so moving targets are harder.
const TURN_RESPONSIVENESS := 7.0
## How close the aim must be to where the bot wants it before it pulls the trigger, in degrees.
const ON_TARGET_DEGREES := 2.5
## How long the bot looks around after reaching the last known position, in seconds.
const LOOK_AROUND_TIME := 2.4
## How far the bot looks to each side while looking around, in degrees.
const LOOK_AROUND_DEGREES := 55.0
## Group of Marker3D nodes on the map that bots patrol between.
const PATROL_GROUP := "patrol_points"
## Defenders leave their spot only to check on enemies seen or heard within
## this many metres; farther fights are left to the others.
const ROTATE_DISTANCE := 35.0
## How far a holding defender's view drifts to each side of its angle, in degrees.
const HOLD_SWEEP_DEGREES := 10.0
## How quickly that drift goes back and forth, in radians per second.
const HOLD_SWEEP_SPEED := 0.5
## A teammate this close to the line of fire (metres) makes the bot hold fire.
const LINE_OF_FIRE_CLEARANCE := 0.6

## How well this bot fights.
@export var difficulty: BotDifficulty = preload("res://bots/difficulty_normal.tres")
## Stay put and watch the current direction instead of patrolling, like a CS
## player holding an angle. The bot still fights and searches.
@export var hold_position: bool = false

## What the bot is doing right now. Read-only for other scripts.
var state: State = State.PATROL
## Its orders for the round. Set with [method patrol], [method attack] or [method defend].
var role: Role = Role.PATROL

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
## The direction the bot faced on arriving at the last known position; it looks to either side of it.
var _look_around_yaw: float = NAN
## Attack orders: the route's waypoints, the one being walked to (route.size() =
## the route is done and the bot clears the defenders' end), and the places to clear.
var _route: Array[Vector3] = []
var _route_index: int = 0
var _clear_points: Array[Vector3] = []
## Seconds to wait after freeze time before setting off (attackers start a moment apart).
var _start_delay: float = 0.0
## Defend orders: the spot to hold (position and the angle to watch) and every
## hold spot (after rotating, the bot holds the one nearest to it).
var _hold_spot: Transform3D = Transform3D.IDENTITY
var _hold_spots: Array[Transform3D] = []
var _hold_time: float = 0.0
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
	patrol()


## Orders: walk between patrol points (practice mode).
func patrol() -> void:
	role = Role.PATROL
	_pick_patrol_point()


## Orders: after [param delay] seconds of live round, follow [param route] (world
## positions in order), then keep checking [param clear_points] at random,
## walking silently, until the round is over.
func attack(route: Array[Vector3], clear_points: Array[Vector3], delay: float) -> void:
	role = Role.ATTACK
	_route = route
	_route_index = 0
	_clear_points = clear_points
	_start_delay = delay
	_aim_for_route()


## Orders: go to [param spot] and hold the angle it faces. [param all_spots]
## are every hold spot of the team's end; after leaving to check on a fight,
## the bot holds whichever is nearest.
func defend(spot: Transform3D, all_spots: Array[Transform3D]) -> void:
	role = Role.DEFEND
	_hold_spot = spot
	_hold_spots = all_spots
	_hold_time = 0.0
	move_to(spot.origin)


func get_input(delta: float) -> CharacterInput:
	_update_state()
	var input := CharacterInput.new()
	match state:
		State.PATROL:
			_follow_orders(input, delta)
		State.ENGAGE:
			_engage(input, delta)
		State.SEARCH:
			_search(input, delta)
	input.yaw = _yaw
	input.pitch = _pitch
	return input


# --- Deciding what to do ---


func _update_state() -> void:
	_senses.notice_time_scale = difficulty.notice_time_scale
	if _senses.visible_enemy != null:
		if state != State.ENGAGE or _senses.visible_enemy != _target:
			_start_engaging(_senses.visible_enemy)
		state = State.ENGAGE
	elif state == State.ENGAGE or (state == State.PATROL and _senses.has_lead()):
		if _wants_to_check(_senses.last_known_position):
			# Lost sight of the enemy, or heard one: go and check.
			state = State.SEARCH
			_target = null
			move_to(_senses.last_known_position)
			_look_around_left = LOOK_AROUND_TIME
			_look_around_yaw = NAN
		elif state == State.ENGAGE:
			# A defender that lost sight of a distant enemy keeps holding instead of chasing.
			state = State.PATROL
			_target = null
			_resume_orders()
	elif state == State.SEARCH and not _senses.has_lead():
		state = State.PATROL
		_resume_orders()


## Whether the bot leaves its orders to check on an enemy last seen or heard at [param point].
func _wants_to_check(point: Vector3) -> bool:
	return role != Role.DEFEND or character.global_position.distance_to(point) <= ROTATE_DISTANCE


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


func _follow_orders(input: CharacterInput, delta: float) -> void:
	if hold_position:
		return
	match role:
		Role.ATTACK:
			_advance(input, delta)
		Role.DEFEND:
			_hold(input, delta)
		_:
			if has_arrived():
				_pick_patrol_point()
			_walk(input, delta, true)


## Attacking: wait for the bot's turn to set off, follow the route, then clear
## the defenders' end at walking speed (silent, like a CS player near the enemy).
func _advance(input: CharacterInput, delta: float) -> void:
	if _start_delay > 0.0:
		if not character.frozen:
			_start_delay -= delta
		return
	if has_arrived():
		_route_index = mini(_route_index + 1, _route.size())
		_aim_for_route()
	input.walk = _route_index >= _route.size()
	_walk(input, delta, true)


## Defending: walk to the hold spot, then watch its angle with a slow, small drift.
func _hold(input: CharacterInput, delta: float) -> void:
	if not has_arrived():
		_walk(input, delta, true)
		return
	_hold_time += delta
	var yaw := _hold_spot.basis.get_euler().y + deg_to_rad(HOLD_SWEEP_DEGREES) * sin(_hold_time * HOLD_SWEEP_SPEED)
	_turn_toward(yaw, 0.0, WALK_TURN_SPEED, delta)


## Back to the orders after a fight or a search.
func _resume_orders() -> void:
	match role:
		Role.ATTACK:
			_skip_passed_waypoints()
			_aim_for_route()
		Role.DEFEND:
			_hold_spot = _nearest_hold_spot()
			move_to(_hold_spot.origin)
		_:
			_pick_patrol_point()


## Heads for the current waypoint, or a place to clear once the route is done.
func _aim_for_route() -> void:
	if _route_index < _route.size():
		move_to(_route[_route_index])
	elif not _clear_points.is_empty():
		move_to(_clear_points[rng.randi() % _clear_points.size()])
	else:
		_pick_patrol_point()


## After a detour (a fight or a search), carries on from the route leg the bot
## is nearest to, instead of walking back to a waypoint it has already passed.
## Only legs from the current one on count, so it never goes back along the route.
func _skip_passed_waypoints() -> void:
	if _route_index >= _route.size():
		return
	var here := Vector2(character.global_position.x, character.global_position.z)
	var best_distance := INF
	for i in range(maxi(_route_index, 1), _route.size()):
		var leg_start := Vector2(_route[i - 1].x, _route[i - 1].z)
		var leg_end := Vector2(_route[i].x, _route[i].z)
		var distance := Geometry2D.get_closest_point_to_segment(here, leg_start, leg_end).distance_to(here)
		if distance < best_distance:
			best_distance = distance
			_route_index = i


func _nearest_hold_spot() -> Transform3D:
	var nearest := _hold_spot
	for spot in _hold_spots:
		if _flat_distance(spot.origin, character.global_position) < _flat_distance(nearest.origin, character.global_position):
			nearest = spot
	return nearest


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _search(input: CharacterInput, delta: float) -> void:
	if not has_arrived():
		# Walk there while looking toward where the enemy was (holding the angle).
		_walk(input, delta, false)
		_turn_toward_point(_senses.last_known_position + Vector3.UP * 1.5, WALK_TURN_SPEED, delta)
		return
	# Arrived: check left, then right, then straight ahead, like a player clearing an area.
	if is_nan(_look_around_yaw):
		_look_around_yaw = _yaw
	_look_around_left -= delta
	var progress := 1.0 - _look_around_left / LOOK_AROUND_TIME
	var side := -1.0 if progress < 0.33 else (1.0 if progress < 0.66 else 0.0)
	_turn_toward(_look_around_yaw + deg_to_rad(LOOK_AROUND_DEGREES) * side, 0.0, WALK_TURN_SPEED, delta)
	if _look_around_left <= 0.0:
		_senses.forget()


func _engage(input: CharacterInput, delta: float) -> void:
	_time_on_target += delta
	_reaction_left -= delta
	_pause_left -= delta

	# Aim: where the target is, minus the recoil the bot pulls against, plus a
	# human error that shrinks as the aim settles.
	var aim_point := _target.get_head_position() if _aiming_for_head else _target.get_chest_position()
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
			and _pause_left <= 0.0 and not character.weapon.is_reloading()
			and not _teammate_in_line_of_fire())


## True when a living teammate stands close to the line from the bot's eyes to
## its target, so a shot now could hit them. Bots hold fire then, like a player
## waiting for a teammate to clear the angle (with friendly fire off the bullet
## would pass through, but spraying through a friend still isn't how people play).
func _teammate_in_line_of_fire() -> bool:
	var from := character.get_eye_position()
	var direction := -Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).z
	var reach := from.distance_to(_target.get_eye_position())
	for node in get_tree().get_nodes_in_group("characters"):
		var mate := node as Character
		if mate == character or mate.team != character.team or not mate.is_alive():
			continue
		var points := mate.get_visibility_points()
		points.append(mate.global_position + Vector3.UP * 0.6)
		for point in points:
			var along := (point - from).dot(direction)
			if along > 0.0 and along < reach and (from + direction * along).distance_to(point) < LINE_OF_FIRE_CLEARANCE:
				return true
	return false


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


## Eases the view toward (yaw, pitch): it covers a share of the remaining
## angle each tick (TURN_RESPONSIVENESS), but never faster than [param speed]
## degrees per second.
func _turn_toward(yaw: float, pitch: float, speed: float, delta: float) -> void:
	var blend := 1.0 - exp(-TURN_RESPONSIVENESS * delta)
	var max_step := deg_to_rad(speed) * delta
	_yaw += clampf(angle_difference(_yaw, yaw) * blend, -max_step, max_step)
	_pitch += clampf((pitch - _pitch) * blend, -max_step, max_step)


## The movement keys (as a CharacterInput.move vector) that walk in a world
## direction, given where the bot is facing this tick.
func _keys_for_direction(direction: Vector3) -> Vector2:
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	return Vector2(direction.dot(right), -direction.dot(forward))
