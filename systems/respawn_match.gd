class_name RespawnMatch
extends RoundManager
## Team respawn mode, like Call of Duty's Team Deathmatch (D-049, D-082).
##
## One long round: after the freeze time both teams fight for
## [member MatchSettings.time_limit] seconds. Whoever dies comes back
## [member MatchSettings.respawn_delay] seconds later at a respawn point away
## from the enemies. Each kill of an enemy is a point for the killer's team
## ([member RoundManager.score] counts kills here); the first team to
## [member MatchSettings.kill_limit] wins. When the time runs out the team with
## more kills wins, and a tie goes to overtime: the next kill wins. After the
## deciding kill the usual round-end pause plays, then the match ends as a
## round match does ([signal RoundManager.match_ended]).
##
## It is a [RoundManager], so the HUD, kill feed, scoreboard and match-end
## screen show it without knowing the difference (they ask
## [method is_team_respawn] for the few texts that change). There is no bomb
## and no spectating; the start is at the two team ends, like a round.
##
## Authority code, like the round manager: in M9 only the host runs it.

## Emitted when the time runs out with the score tied: the next kill wins.
signal overtime_started

## Seconds of freeze time at the start (the rounds' 15 s are buy time, which this mode has none of).
const FREEZE_TIME := 5.0
## Group of the map's respawn markers (12 per quick map, in four zones).
const RESPAWN_GROUP := "respawn_points"
## A respawn spot counts as taken while someone stands closer than this (metres).
const SPOT_CLEARANCE := 2.0
## Enemies this far away (metres) or farther make every spot equally safe.
const SAFE_DISTANCE := 40.0
## An enemy within this distance (metres) that can see a spot makes it a bad spot.
const WATCH_DISTANCE := 45.0
## How much worse a spot an enemy can see is, in metres of distance.
const WATCHED_PENALTY := 40.0
## How much better a spot with a teammate nearby is, in metres of distance.
const TEAMMATE_BONUS := 4.0
## A teammate this close (metres) counts as nearby.
const TEAMMATE_DISTANCE := 15.0
## Random spread added to each spot's score, so spots that are about as good take turns.
const SCORE_JITTER := 3.0
## Seconds a gun dropped by the dead lies on the floor before it goes (M7 task 18): ten minutes
## of deaths would otherwise cover the map.
const DROPPED_GUN_LIFETIME := 30.0

## True once the time limit ran out with the score tied.
var overtime: bool = false
## Character → seconds until it comes back.
var _respawn_left: Dictionary = {}
## Class changes waiting for a respawn: Character → ClassData.
var _pending_class: Dictionary = {}
## Online, on a client: sends "I skipped my killcam" to the host ([method skip_killcam]; set by [NetClient]).
var killcam_skip_request: Callable
## Player → the seconds its respawn waits beyond the delay for its killcam ([method _hold_for_killcam]).
var _killcam_hold: Dictionary = {}
## The players at this computer whose killcam is on ([method set_killcam_watcher]).
var _killcam_watchers: Dictionary = {}
## Each team's shared hunting plan for its bots (index = team number).
var _hunt_plans: Array[HuntPlan] = []


func is_team_respawn() -> bool:
	return true


## Seconds until [param character] comes back, or -1 if it isn't waiting to.
func get_respawn_time_left(character: Character) -> float:
	return _respawn_left.get(character, -1.0)


## The best respawn spot for [param character] right now: free, as far from the
## living enemies as possible (counting up to [constant SAFE_DISTANCE]), not in
## an enemy's sight, preferably near a teammate. Uses the map's
## [constant RESPAWN_GROUP] markers, or both teams' spawns if it has none.
func pick_spawn(character: Character) -> Transform3D:
	var markers := _markers(RESPAWN_GROUP)
	if markers.is_empty():
		markers = _markers(Teams.ATTACK_SPAWN_GROUP) + _markers(Teams.DEFEND_SPAWN_GROUP)
	var best: Node3D = null
	var best_score := -INF
	for marker in markers:
		var spot := (marker as Node3D).global_position
		if _is_taken(spot, character):
			continue
		var score := _spot_score(spot, character) + rng.randf() * SCORE_JITTER
		if score > best_score:
			best = marker
			best_score = score
	if best == null:
		# Every spot is taken: use any.
		best = markers[rng.randi_range(0, markers.size() - 1)]
	return best.global_transform


# --- The match ---


## No bomb in this mode.
func _add_bomb() -> void:
	pass


## Five seconds at the team ends, as in D-082: there is nothing to buy (D-090).
func _freeze_time() -> float:
	return minf(settings.freeze_time, FREEZE_TIME)


## Team Deathmatch keeps [member MatchSettings.respawn_map_weapons] guns out all the time: a taken
## one is replaced somewhere else after [member MatchSettings.map_weapon_replace_time] (D-098). They
## keep away from the respawn points too, since anyone can come back at any of them.
func _set_up_map_weapons(weapons: MapWeapons) -> void:
	weapons.count = settings.respawn_map_weapons
	weapons.replace_time = settings.map_weapon_replace_time
	weapons.avoid_respawn_points = true


## No money here (D-090): each class spawns with its own loadout (its signature gun, the Sparrow,
## the knife and a grenade), the round loadout for a class without one.
func _loadout_for(character: Character) -> Array[WeaponData]:
	if character.class_data != null and not character.class_data.loadout.is_empty():
		return character.class_data.loadout
	return settings.round_loadout


## The bots of each team hunt in groups of about two, sharing what they see (D-083).
func _plan_bots() -> void:
	_hunt_plans.clear()
	for team in Teams.COUNT:
		_hunt_plans.append(BotTactics.plan_hunt(get_members(team), get_parent(), rng))


## The hunting plan of [param team]'s bots.
func get_hunt_plan(team: int) -> HuntPlan:
	return _hunt_plans[team] if team < _hunt_plans.size() else null


## The plan [param character] (a bot) hunts with: its team's here.
func _hunt_plan_for(character: Character) -> HuntPlan:
	return get_hunt_plan(character.team)


func _round_duration() -> float:
	return settings.time_limit


func _live_tick(delta: float) -> void:
	for plan in _hunt_plans:
		plan.time += delta
	_clear_old_guns()
	for character: Character in _respawn_left.keys():
		if not is_instance_valid(character):
			_respawn_left.erase(character)
			continue
		_respawn_left[character] -= delta
		if _respawn_left[character] <= 0.0:
			_respawn_left.erase(character)
			_killcam_hold.erase(character)
			var spot := pick_spawn(character)
			if _pending_class.has(character):
				var data: ClassData = _pending_class[character]
				_pending_class.erase(character)
				if character.class_data != data:
					character.class_data = data
					class_changed.emit(character, data)
			character.respawn(spot.origin, spot.basis.get_euler().y)
			_give_loadout(character)
			_rejoin_hunt(character)


## In overtime the clock has run out and stays at 0:00.
func _clock_stopped() -> bool:
	return overtime


func _on_time_up() -> void:
	if score[0] == score[1]:
		overtime = true
		time_left = 0.0
		overtime_started.emit()
		return
	_end_round(_leader(), EndReason.TIME_LIMIT)


## Nobody stays dead, so a team with nobody alive hasn't lost.
func _check_elimination() -> void:
	pass


## A kill of an enemy in the live round is a point for the killer's team.
func _score_kill(victim: Character, killer: Character) -> void:
	if phase == Phase.LIVE and killer != null and not Teams.are_allies(killer, victim):
		score[killer.team] += 1


## The score is kills, so the round itself adds nothing.
func _score_round(_round_winner: int) -> void:
	pass


func _on_died(killer: Character, victim: Character) -> void:
	# Before the kill is announced: a killcam that is off asks for the plain delay back when it hears of it.
	if phase == Phase.LIVE:
		_respawn_left[victim] = settings.respawn_delay + _hold_for_killcam(victim, killer)
	super(killer, victim)
	if phase != Phase.LIVE:
		return
	_check_match_point(killer, victim)


## How much longer than the respawn delay [param victim] stays dead so its killcam can play to the end
## ([constant Killcam.TOTAL], M17, D-241): a player killed by someone else whose killcam is on (one at this
## computer, [method set_killcam_watcher]), or a friend online (its computer asks to skip when its killcam is
## off). Never a bot. Skipping gives it back ([method skip_killcam]).
func _hold_for_killcam(victim: Character, killer: Character) -> float:
	_killcam_hold.erase(victim)
	if killer == null or killer == victim or victim.get_node_or_null("BotController") != null:
		return 0.0
	if not _killcam_watchers.has(victim) and victim.get_node_or_null("NetworkController") == null:
		return 0.0
	var hold := maxf(Killcam.TOTAL - settings.respawn_delay, 0.0)
	if hold > 0.0:
		_killcam_hold[victim] = hold
	return hold


## Whether [param character], a player at this computer, watches its killcam ([Killcam] says so).
func set_killcam_watcher(character: Character, on: bool) -> void:
	if on:
		_killcam_watchers[character] = true
	else:
		_killcam_watchers.erase(character)


## [param character] skipped its killcam (or has it turned off): it comes back after the plain respawn
## delay, counted from its death. Online, on a client, the request goes to the host.
func skip_killcam(character: Character) -> void:
	if replica:
		if killcam_skip_request.is_valid():
			killcam_skip_request.call(character)
		return
	if not _killcam_hold.has(character):
		return
	if _respawn_left.has(character):
		_respawn_left[character] = maxf(_respawn_left[character] - _killcam_hold[character], 0.0)
	_killcam_hold.erase(character)


## Ends the match when a kill decided it: [param killer]'s team reached the kill limit, or scored in overtime.
func _check_match_point(killer: Character, victim: Character) -> void:
	if killer == null or Teams.are_allies(killer, victim):
		return
	if score[killer.team] >= settings.kill_limit:
		_end_round(killer.team, EndReason.KILL_LIMIT)
	elif overtime:
		_end_round(killer.team, EndReason.TIME_LIMIT)


## The only round is over: the team with more kills has won the match.
func _after_round_end() -> void:
	_respawn_left.clear()
	_end_match(_leader())


# --- Helpers ---


## In team respawn the class can change any time (D-099), to the other class of your draft: in
## the freeze time at once, otherwise with the next respawn, which brings the new class's loadout.
## Returns true when accepted.
func request_class(character: Character, data: ClassData) -> bool:
	if data == null or not is_instance_valid(character) or phase == Phase.MATCH_END or not is_drafted(character, data):
		return false
	if replica:
		# Online, on a client: the host decides; its answer comes back as a class change (at once,
		# or with the next respawn). Until then the choice shows as the next class here too.
		if class_request.is_valid():
			class_request.call(character, data)
		if character.class_data != data:
			_pending_class[character] = data
		else:
			_pending_class.erase(character)
		return true
	if phase == Phase.FREEZE or not character.is_alive():
		_pending_class.erase(character)
		if character.class_data != data:
			character.class_data = data
			class_changed.emit(character, data)
		if phase == Phase.FREEZE:
			_give_loadout(character)
		return true
	_pending_class[character] = data
	return true


## The class [param character] will have after its next respawn (its current one if none waits).
func get_next_class(character: Character) -> ClassData:
	return _pending_class.get(character, character.class_data)


## Takes away guns that have lain on the floor longer than [constant DROPPED_GUN_LIFETIME] (not
## the map weapons, which [MapWeapons] looks after).
func _clear_old_guns() -> void:
	var map := get_parent()
	for pickup in WeaponPickup.all_in_world(map):
		if pickup.spot == null and pickup.age > DROPPED_GUN_LIFETIME and map.is_ancestor_of(pickup):
			pickup.remove_from_group(WeaponPickup.GROUP)
			pickup.queue_free()


## A bot that comes back hunts with its group again (respawning reset its orders).
func _rejoin_hunt(character: Character) -> void:
	var brain := character.get_node_or_null("BotController") as BotController
	var plan := _hunt_plan_for(character) if brain != null else null
	if plan != null:
		brain.hunt(plan)
		plan.note_respawn(brain)


func _leader() -> int:
	return 0 if score[0] > score[1] else 1


func _markers(group: String) -> Array[Node]:
	var map := get_parent()
	return get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return map.is_ancestor_of(node))


func _is_taken(spot: Vector3, character: Character) -> bool:
	for other in _participants:
		if other != character and is_instance_valid(other) and other.is_alive() and _flat_distance(other.global_position, spot) < SPOT_CLEARANCE:
			return true
	return false


func _spot_score(spot: Vector3, character: Character) -> float:
	var nearest_enemy := SAFE_DISTANCE
	var watched := false
	var teammate_near := false
	for other in _participants:
		if other == character or not is_instance_valid(other) or not other.is_alive():
			continue
		var distance := _flat_distance(other.global_position, spot)
		if Teams.are_allies(other, character):
			teammate_near = teammate_near or distance <= TEAMMATE_DISTANCE
			continue
		nearest_enemy = minf(nearest_enemy, distance)
		if not watched and distance <= WATCH_DISTANCE and _can_see_spot(other, spot, character):
			watched = true
	return nearest_enemy - (WATCHED_PENALTY if watched else 0.0) + (TEAMMATE_BONUS if teammate_near else 0.0)


## True if [param enemy]'s eyes have a clear line to the head or the chest of
## someone standing at [param spot] (walls only; which way it looks doesn't matter).
func _can_see_spot(enemy: Character, spot: Vector3, character: Character) -> bool:
	var space := enemy.get_world_3d().direct_space_state
	for height in [character.stand_eye_height, character.stand_eye_height - 0.6]:
		var query := PhysicsRayQueryParameters3D.create(enemy.get_eye_position(), spot + Vector3.UP * height, PhysicsLayers.WORLD)
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Online, on a client (M9): the host changed [param character]'s class; a choice waiting for the
## respawn is done.
func replica_class_changed(character: Character, data: ClassData) -> void:
	_pending_class.erase(character)
	super(character, data)


## Online, on a client (M9, D-105): the host's match went into overtime. Emits [signal overtime_started].
func replica_overtime() -> void:
	overtime = true
	time_left = 0.0
	overtime_started.emit()

