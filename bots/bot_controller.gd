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
## In bomb rounds (D-081) the orders bend around the [Bomb]: the carrier walks
## its route and then plants at the team's target site, the other attackers
## clear around that site, the nearest attacker fetches a dropped bomb, and
## after the plant the attackers guard the bomb from spots that see it.
## Defenders hold their spots until the plant, then all retake: the first one
## at the bomb defuses while the others cover it. Planting and defusing use the
## same Use command as the player. A bot keeps defusing (or planting) when an
## enemy shows up only if it is nearly done.
##
## In the team respawn mode (D-083) bots hunt in small groups ([HuntPlan]): the
## group's leader runs to the team's freshest enemy sighting, or roams between
## the map's patrol points, and the others follow a few metres behind,
## watching the flanks. Every bot reports what it sees and hears to the plan.
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
	## Team respawn: hunt the enemy with its group (see [HuntPlan]).
	HUNT,
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
## Fights beyond this distance (metres) are long-range duels, where bots rarely hit.
const LONG_RANGE := 35.0
## After this many seconds of a long-range duel, an attacker stops trading
## shots and closes in (a holding defender is happy to wait out the clock).
const LONG_DUEL_PATIENCE := 6.0
## How long an attacker closing in ignores enemies beyond LONG_RANGE, in seconds.
const CLOSE_IN_TIME := 4.0
## How far a plant spot lies from the middle of the site, at most (metres).
const PLANT_SPREAD := 1.0
## Seconds of round time the carrier keeps for walking to a site and planting:
## with less left, it stops following its route and goes straight to plant.
const PLANT_RESERVE := 30.0
## Attackers guard the planted bomb from this far away (metres), where they can see it.
const GUARD_MIN := 5.0
const GUARD_MAX := 10.0
## Defenders covering a teammate's defuse stop this far from the bomb (metres).
const COVER_DISTANCE := 7.0
## After the plant, bots only go and check enemies seen or heard this close to the bomb (metres).
const BOMB_CHECK_DISTANCE := 15.0
## A bot keeps planting or defusing when an enemy shows up once it is this far along.
const STICK_PROGRESS := 0.7
## How far a guarding or covering bot's view drifts to each side, in degrees.
const GUARD_SWEEP_DEGREES := 25.0
## Where a planting or defusing bot looks: down at the bomb, in degrees.
const BOMB_LOOK_PITCH := -50.0
## A hunting follower stays this far behind its leader (metres)...
const FOLLOW_DISTANCE := 2.5
## ...and this far to the side, left or right by its place in the group (metres).
const FOLLOW_SIDE := 1.2
## A follower farther than this from its leader (metres) runs to catch up instead of following.
const REGROUP_DISTANCE := 18.0
## A leader walks (half speed, silent) while a follower is this far behind (metres).
const WAIT_DISTANCE := 6.0
## A group answers a teammate's sighting only within this distance (metres);
## farther groups keep roaming, so the whole team doesn't pile into one fight.
const LEAD_REACH := 25.0
## How far off the leader's view a follower looks, to cover a flank (degrees).
const FLANK_DEGREES := 50.0
## Seconds a hunting leader looks around at a roam point before moving on.
const ROAM_LOOK_TIME := 1.2
## A bot walking slower than this (m/s) isn't getting anywhere.
const STUCK_SPEED := 0.6
## Seconds of getting nowhere before a stuck bot jumps, and before it backs off
## to the side and asks for a new path (like a CS bot that's stuck).
const STUCK_JUMP_TIME := 0.5
const STUCK_BACKUP_TIME := 1.2
## Seconds a stuck bot backs off before following its path again.
const BACKUP_DURATION := 0.5

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
## Seconds left in which this attacker closes in on far enemies instead of shooting at them.
var _close_in_left: float = 0.0
## Bomb rounds: the round's bomb (null without one), the site this bot's team
## attacks, where the carrier plants, and where the bot guards or covers after
## the plant.
var _bomb: Bomb
var _target_site: Area3D
var _plant_spot: Vector3 = Vector3.INF
var _guard_spot: Vector3 = Vector3.INF
## Seconds of live round so far, and when the carrier stops following its
## route and goes straight to plant.
var _live_time: float = 0.0
var _plant_deadline: float = INF
## Seconds spent trying to walk without moving, and the back-off of a stuck bot
## (seconds left, and which way).
var _stuck_time: float = 0.0
var _backup_left: float = 0.0
var _backup_direction: Vector3 = Vector3.ZERO
## Team respawn: the team's shared plan, and how long the bot has looked around at its roam point.
var _hunt_plan: HuntPlan
var _roam_look_left: float = 0.0
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
	_close_in_left = 0.0
	_senses.reset()
	patrol()


## Orders: walk between patrol points (practice mode).
func patrol() -> void:
	role = Role.PATROL
	_reset_objective()
	_pick_patrol_point()


## Orders: after [param delay] seconds of live round, follow [param route] (world
## positions in order), then keep checking [param clear_points] at random,
## walking silently, until the round is over. In a bomb round [param
## target_site] is where the team plants, and a carrier stops following the
## route after [param plant_deadline] seconds of live round.
func attack(route: Array[Vector3], clear_points: Array[Vector3], delay: float, target_site: Area3D = null, plant_deadline: float = INF) -> void:
	role = Role.ATTACK
	_reset_objective()
	_route = route
	_route_index = 0
	_clear_points = clear_points
	_start_delay = delay
	_target_site = target_site
	_plant_deadline = plant_deadline
	_aim_for_route()


## Orders: go to [param spot] and hold the angle it faces. [param all_spots]
## are every hold spot of the team's end; after leaving to check on a fight,
## the bot holds whichever is nearest. In a bomb round, a plant overrides this:
## every defender retakes.
func defend(spot: Transform3D, all_spots: Array[Transform3D]) -> void:
	role = Role.DEFEND
	_reset_objective()
	_hold_spot = spot
	_hold_spots = all_spots
	_hold_time = 0.0
	move_to(spot.origin)


## Orders (team respawn mode): hunt the enemy with this bot's group in [param plan].
func hunt(plan: HuntPlan) -> void:
	role = Role.HUNT
	_reset_objective()
	_hunt_plan = plan
	_roam_look_left = 0.0


## The site this bot's team attacks this round, or null.
func get_target_site() -> Area3D:
	return _target_site


## The team plan this bot hunts with (team respawn mode), or null.
func get_hunt_plan() -> HuntPlan:
	return _hunt_plan


func get_input(delta: float) -> CharacterInput:
	_close_in_left = maxf(_close_in_left - delta, 0.0)
	if not character.frozen:
		_live_time += delta
	_update_state()
	if role == Role.HUNT and _hunt_plan != null and _senses.get_lead_age() < 0.2:
		# Call it out: the whole team learns where the enemy is.
		_hunt_plan.report(_senses.last_known_position)
	var input := CharacterInput.new()
	match state:
		State.PATROL:
			_follow_orders(input, delta)
		State.ENGAGE:
			_engage(input, delta)
			if _should_stick_to_bomb():
				# Nearly done: finish the plant or defuse instead of fighting back.
				input.use = true
				input.shoot = false
		State.SEARCH:
			_search(input, delta)
	input.yaw = _yaw
	input.pitch = _pitch
	return input


# --- Deciding what to do ---


func _update_state() -> void:
	_senses.notice_time_scale = difficulty.notice_time_scale
	var enemy := _senses.visible_enemy
	if enemy != null and _closing_in_on(enemy):
		# Not worth a shot from here: treat it like a lead and go toward it (search).
		enemy = null
	if enemy != null:
		if state != State.ENGAGE or enemy != _target:
			_start_engaging(enemy)
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


## True while an attacker closes in on [param enemy] instead of trading shots
## with it at long range (see [constant LONG_DUEL_PATIENCE]).
func _closing_in_on(enemy: Character) -> bool:
	return _close_in_left > 0.0 and character.global_position.distance_to(enemy.global_position) > LONG_RANGE


## Whether the bot leaves its orders to check on an enemy last seen or heard at [param point].
## In bomb rounds the carrier never does (it fights what it sees, then carries
## on), the bot fetching a dropped bomb doesn't either, and after the plant
## only enemies near the bomb count. Hunting bots (team respawn) only check
## what is within [constant LEAD_REACH], like the sightings they answer.
func _wants_to_check(point: Vector3) -> bool:
	if _objective_live():
		if _bomb.carrier == character or _is_fetching():
			return false
		if _bomb.is_planted():
			return _bomb.global_position.distance_to(point) <= BOMB_CHECK_DISTANCE
	if role == Role.HUNT:
		return character.global_position.distance_to(point) <= LEAD_REACH
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
	if _play_objective(input, delta):
		return
	match role:
		Role.ATTACK:
			_advance(input, delta)
		Role.DEFEND:
			_hold(input, delta)
		Role.HUNT:
			_hunt(input, delta)
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
	if (role == Role.ATTACK and _time_on_target > LONG_DUEL_PATIENCE
			and character.global_position.distance_to(_target.global_position) > LONG_RANGE):
		# A long-range duel nobody wins: stop shooting and close the distance
		# (from the next tick the bot walks toward the enemy, facing it).
		_close_in_left = CLOSE_IN_TIME

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
	for mate in Character.all_in_world(character):
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


# --- Team respawn: hunting in groups ---


func _hunt(input: CharacterInput, delta: float) -> void:
	if _hunt_plan == null:
		return
	var leader := _hunt_plan.get_leader(self)
	if leader != null and leader != self:
		var distance := _flat_distance(character.global_position, leader.character.global_position)
		if distance <= REGROUP_DISTANCE:
			_follow(leader.character, input, delta)
			return
		# Far behind (just came back): run to where the group is.
		_go_near(leader.character.global_position, 2.0)
		_walk(input, delta, true)
		return
	_lead_hunt(input, delta)


## Leading the group (or hunting alone): run to the team's freshest sighting
## if it is within [constant LEAD_REACH], otherwise roam from patrol point to patrol point, looking left and right at
## each before moving on.
func _lead_hunt(input: CharacterInput, delta: float) -> void:
	var goal := _hunt_plan.get_goal(self)
	if _hunt_plan.has_lead() and _flat_distance(_hunt_plan.get_lead(), character.global_position) <= LEAD_REACH:
		goal = _hunt_plan.get_lead()
		_hunt_plan.set_goal(self, goal)
		_roam_look_left = 0.0
	elif _roam_look_left > 0.0:
		_roam_look_left -= delta
		var side := -1.0 if _roam_look_left > ROAM_LOOK_TIME * 0.5 else 1.0
		_turn_toward(_look_around_yaw + deg_to_rad(LOOK_AROUND_DEGREES) * side, 0.0, WALK_TURN_SPEED, delta)
		if _roam_look_left > 0.0:
			return
		goal = _hunt_plan.pick_roam_goal(self, character.global_position, rng)
	elif goal == Vector3.INF:
		goal = _hunt_plan.pick_roam_goal(self, character.global_position, rng)
	elif has_arrived() and _agent.target_position.is_equal_approx(goal):
		# At the roam point: look around before moving on.
		_roam_look_left = ROAM_LOOK_TIME
		_look_around_yaw = _yaw
		return
	_go_to(goal)
	# Let a partner who fell behind catch up: walk (quietly) until they're close.
	for partner in _hunt_plan.get_partners(self):
		if _flat_distance(character.global_position, partner.character.global_position) > WAIT_DISTANCE:
			input.walk = true
	_walk(input, delta, true)


## Following the leader: a few metres behind and to one side, looking off to
## that side so the group covers more than one direction.
func _follow(leader: Character, input: CharacterInput, delta: float) -> void:
	var group := _hunt_plan.groups[_hunt_plan.get_group_index(self)]
	var side := 1.0 if group.find(self) % 2 == 1 else -1.0
	var view := Basis(Vector3.UP, leader.get_aim_angles().x)
	var spot := leader.global_position + view * Vector3(FOLLOW_SIDE * side, 0.0, FOLLOW_DISTANCE)
	var navigation_map := character.get_world_3d().navigation_map
	# Right after a map loads the navigation map isn't ready to answer yet.
	if NavigationServer3D.map_get_iteration_id(navigation_map) > 0:
		spot = NavigationServer3D.map_get_closest_point(navigation_map, spot)
	if _flat_distance(character.global_position, spot) > 1.0:
		_go_near(spot, 1.0)
		_walk(input, delta, false)
	_turn_toward(leader.get_aim_angles().x + deg_to_rad(FLANK_DEGREES) * -side, 0.0, WALK_TURN_SPEED, delta)


## Walks toward [param point], asking for a new path only once the goal has
## moved more than [param slack] metres (a moving target like a teammate).
func _go_near(point: Vector3, slack: float) -> void:
	if _agent.target_position.distance_to(point) > slack:
		move_to(point)


# --- Bomb rounds ---


func _reset_objective() -> void:
	_bomb = Bomb.find_in_world(character)
	_target_site = null
	_plant_spot = Vector3.INF
	_guard_spot = Vector3.INF
	_live_time = 0.0
	_plant_deadline = INF


## True while there is a bomb and the round is live (planting, defusing and picking up work).
func _objective_live() -> bool:
	return is_instance_valid(_bomb) and _bomb.active


## What the bomb asks of this bot right now, ahead of its usual orders.
## Returns true when it took over this tick.
func _play_objective(input: CharacterInput, delta: float) -> bool:
	if not _objective_live():
		return false
	match role:
		Role.ATTACK:
			return _attack_objective(input, delta)
		Role.DEFEND:
			return _defend_objective(input, delta)
	return false


func _attack_objective(input: CharacterInput, delta: float) -> bool:
	match _bomb.state:
		Bomb.State.CARRIED:
			# The others escort: their route, then clearing around the target site.
			if _bomb.carrier != character or _start_delay > 0.0:
				return false
			if _route_index < _route.size() and _live_time < _plant_deadline:
				return false
			_go_plant(input, delta)
			return true
		Bomb.State.DROPPED:
			if not _is_fetching():
				return false
			_go_to(_bomb.global_position)
			_walk(input, delta, true)
			return true
		Bomb.State.PLANTED:
			_guard_bomb(input, delta)
			return true
	return false


## The carrier: to the plant spot in the target site, then hold Use until planted.
func _go_plant(input: CharacterInput, delta: float) -> void:
	if not is_instance_valid(_target_site):
		_target_site = _nearest_site()
	if _plant_spot == Vector3.INF:
		_plant_spot = _pick_plant_spot(_target_site)
	var in_site := _bomb.get_site_of(character) != null
	if in_site and (_flat_distance(character.global_position, _plant_spot) < 1.0 or has_arrived()):
		input.use = true
		_turn_toward(_yaw, deg_to_rad(BOMB_LOOK_PITCH), WALK_TURN_SPEED, delta)
		return
	_go_to(_plant_spot)
	_walk(input, delta, true)
	if has_arrived() and not in_site:
		# The path ended short of the site: step straight in.
		input.move = _keys_for_direction(_flat_direction_to(_plant_spot))


## Attackers after the plant: go to a spot near the bomb that sees it, and watch it.
func _guard_bomb(input: CharacterInput, delta: float) -> void:
	if _guard_spot == Vector3.INF:
		_guard_spot = _pick_guard_spot()
	if _flat_distance(character.global_position, _guard_spot) > 1.0 and not (has_arrived() and _agent.target_position.is_equal_approx(_guard_spot)):
		_go_to(_guard_spot)
		_walk(input, delta, true)
		return
	_watch(_bomb.global_position + Vector3.UP * 0.3, false, input, delta)


## Defenders: hold their spots until the plant; then retake. The first at the
## bomb defuses, the others cover the defuser from a few metres away.
func _defend_objective(input: CharacterInput, delta: float) -> bool:
	if not _bomb.is_planted():
		return false
	if _bomb.actor == character:
		input.use = true
		_turn_toward(_yaw, deg_to_rad(BOMB_LOOK_PITCH), WALK_TURN_SPEED, delta)
		return true
	var distance := _flat_distance(character.global_position, _bomb.global_position)
	if _bomb.actor != null and distance <= COVER_DISTANCE:
		# A teammate is defusing: watch away from the bomb, where attackers come from.
		_watch(_bomb.global_position, true, input, delta)
		return true
	if _bomb.actor == null and distance <= Bomb.DEFUSE_DISTANCE - 0.3:
		input.use = true
		return true
	_go_to(_bomb.global_position)
	_walk(input, delta, true)
	if has_arrived():
		# The path ends a little short of the bomb: step up to it.
		input.move = _keys_for_direction(_flat_direction_to(_bomb.global_position))
	return true


## Holding a spot after the plant: look at [param point] (or straight away from
## it with [param away]), letting the view drift from side to side.
func _watch(point: Vector3, away: bool, _input: CharacterInput, delta: float) -> void:
	_hold_time += delta
	var to_point := point - character.get_eye_position()
	if away:
		to_point = Vector3(-to_point.x, 0.0, -to_point.z)
	if Vector2(to_point.x, to_point.z).length() < 0.1:
		return
	var yaw := atan2(-to_point.x, -to_point.z) + deg_to_rad(GUARD_SWEEP_DEGREES) * sin(_hold_time * HOLD_SWEEP_SPEED * 1.4)
	_turn_toward(yaw, 0.0 if away else asin(to_point.normalized().y), WALK_TURN_SPEED, delta)


## True when a plant or defuse of this bot is nearly done, or a defuse can't
## wait (the fuse would run out before another full defuse).
func _should_stick_to_bomb() -> bool:
	if not _objective_live() or _bomb.actor != character:
		return false
	if _bomb.progress >= STICK_PROGRESS:
		return true
	return _bomb.is_defusing(character) and _bomb.fuse_left < _bomb.get_defuse_time(character) + 1.0


## True when this bot is the attacker (among the bots) nearest to the dropped bomb, so it goes and picks it up.
func _is_fetching() -> bool:
	if not is_instance_valid(_bomb) or _bomb.state != Bomb.State.DROPPED or role != Role.ATTACK:
		return false
	var mine := _flat_distance(character.global_position, _bomb.global_position)
	for other in Character.all_in_world(character):
		if other == character or other.team != character.team or not other.is_alive():
			continue
		if other.get_node_or_null("BotController") is BotController and _flat_distance(other.global_position, _bomb.global_position) < mine:
			return false
	return true


func _nearest_site() -> Area3D:
	var nearest: Area3D = null
	for site in _bomb.get_sites():
		if nearest == null or _flat_distance(site.global_position, character.global_position) < _flat_distance(nearest.global_position, character.global_position):
			nearest = site
	return nearest


## A walkable spot near the middle of [param site] (the middle of every site is open floor).
func _pick_plant_spot(site: Area3D) -> Vector3:
	var point := Bomb.get_site_floor(site) + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * PLANT_SPREAD
	return NavigationServer3D.map_get_closest_point(character.get_world_3d().navigation_map, point)


## A walkable spot 5–10 m from the planted bomb from which the bot's eyes see
## it, or one next to the bomb if no such spot is found.
func _pick_guard_spot() -> Vector3:
	var map := character.get_world_3d().navigation_map
	var space := character.get_world_3d().direct_space_state
	var bomb_point := _bomb.global_position + Vector3.UP * 0.3
	for attempt in 16:
		var angle := rng.randf() * TAU
		var point := _bomb.global_position + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(GUARD_MIN, GUARD_MAX)
		point = NavigationServer3D.map_get_closest_point(map, point)
		var distance := _flat_distance(point, _bomb.global_position)
		if distance < GUARD_MIN * 0.8 or distance > GUARD_MAX * 1.2 or absf(point.y - _bomb.global_position.y) > 2.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * character.stand_eye_height, bomb_point, PhysicsLayers.WORLD)
		if space.intersect_ray(query).is_empty():
			return point
	return NavigationServer3D.map_get_closest_point(map, _bomb.global_position + Vector3(2.0, 0.0, 0.0))


## Walks toward [param point], asking for a new path only when the goal changed.
func _go_to(point: Vector3) -> void:
	if not _agent.target_position.is_equal_approx(point):
		move_to(point)


func _flat_direction_to(point: Vector3) -> Vector3:
	var offset := point - character.global_position
	offset.y = 0.0
	return offset.normalized() if offset.length() > 0.01 else Vector3.ZERO


# --- Moving and looking ---


## Follows the current path. With [param face_path] the bot looks where it walks.
## A bot that gets nowhere (pressed against the side of a ramp or a corner the
## path cuts) jumps after [constant STUCK_JUMP_TIME], and after [constant
## STUCK_BACKUP_TIME] backs off to one side and asks for a new path.
func _walk(input: CharacterInput, delta: float, face_path: bool) -> void:
	var direction := _get_walk_direction()
	if direction == Vector3.ZERO:
		_stuck_time = 0.0
		return
	if face_path:
		_turn_toward(atan2(-direction.x, -direction.z), 0.0, WALK_TURN_SPEED, delta)
	if _backup_left > 0.0:
		_backup_left -= delta
		input.move = _keys_for_direction(_backup_direction)
		return
	input.move = _keys_for_direction(direction)
	_check_stuck(input, direction, delta)


func _check_stuck(input: CharacterInput, direction: Vector3, delta: float) -> void:
	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	if speed >= STUCK_SPEED or character.frozen or character.busy or not character.is_on_floor():
		_stuck_time = 0.0
		return
	var before := _stuck_time
	_stuck_time += delta
	if before < STUCK_JUMP_TIME and _stuck_time >= STUCK_JUMP_TIME:
		input.jump = true
	elif _stuck_time >= STUCK_BACKUP_TIME:
		_stuck_time = 0.0
		_backup_left = BACKUP_DURATION
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		_backup_direction = (-direction + direction.cross(Vector3.UP) * side).normalized()
		# Same goal, fresh path from where the bot ends up.
		_agent.target_position = _agent.target_position


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
