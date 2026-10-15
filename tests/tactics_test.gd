extends Node
## Automated checks that bots play rounds (D-045). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/tactics_test.tscn
##
## Plays a bots-only 3v3 on the real test map (no player; then team 0 is all
## bots too), with short pauses between rounds. Every random number is seeded,
## so every run plays the same match. Checks that bots get orders for the
## round, defenders take different hold spots and watch their angles, attackers
## push toward the defenders' end in loose groups, and rounds are decided by
## fighting instead of running out the clock. Quits with the number of failed
## checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
## Rounds to play for the last check. Eight rather than four, so one unlucky round on the
## fixed seeds doesn't decide it: on many seeds about one round in ten runs out of time.
const ROUNDS_TO_PLAY := 8
## Share of those rounds that must end by elimination (3 of 4 before M6, 6 of 8 now).
const MIN_ELIMINATION_SHARE := 0.75

var _map: Node3D
var _rounds: RoundManager
var _failures: int = 0
## [reason, seconds live] for every round_ended signal.
var _results: Array = []
var _live_ticks: int = 0


func _ready() -> void:
	_map = MAP_SCENE.instantiate()
	_map.get_node("Player").free()
	add_child(_map)
	var settings := MatchSettings.new()
	settings.freeze_time = 0.5
	settings.round_end_time = 0.5
	# Long enough that the match can't end during the test.
	settings.rounds_to_win = 15
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 11
	_rounds.phase_changed.connect(func(phase: RoundManager.Phase) -> void:
		if phase == RoundManager.Phase.LIVE:
			_live_ticks = 0)
	_rounds.round_ended.connect(func(_winner: int, reason: RoundManager.EndReason) -> void:
		_results.append([reason, _live_ticks / 128.0]))
	_map.add_child(_rounds)
	# The match starts at the end of the first frame, in freeze time.
	for i in 2:
		await get_tree().physics_frame
	var participants := _rounds.get_participants()
	for i in participants.size():
		_silence(participants[i])
		(participants[i].get_node("BotController") as BotController).rng.seed = i + 1
		participants[i].weapon.rng.seed = i + 1
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _physics_process(_delta: float) -> void:
	if _rounds != null and _rounds.phase == RoundManager.Phase.LIVE:
		_live_ticks += 1


## Waits until the current round has been live for [param seconds] (counted from going live).


func _run_all() -> void:
	await _test_orders()
	await _test_defenders_hold()
	await _test_attackers_push()
	await _test_rounds_are_decided()


func _test_orders() -> void:
	var attackers := _brains(_rounds.attacking_team)
	var defenders := _brains(_rounds.get_defending_team())
	var attacking := attackers.all(func(brain: BotController) -> bool: return brain.role == BotController.Role.ATTACK)
	var defending := defenders.all(func(brain: BotController) -> bool: return brain.role == BotController.Role.DEFEND)
	_check("Every bot gets orders for the round: attackers attack, defenders defend",
			attackers.size() == 3 and defenders.size() == 3 and attacking and defending,
			"%d attackers attacking: %s, %d defenders defending: %s" % [attackers.size(), attacking, defenders.size(), defending])


func _test_defenders_hold() -> void:
	await _wait_live_seconds(8.0)
	var markers := get_tree().get_nodes_in_group(BotTactics.HOLD_GROUP)
	var taken := {}
	var holding := 0
	var detail := ""
	for defender in _rounds.get_members(_rounds.get_defending_team()):
		var marker := _nearest(markers, defender.global_position)
		var off := _flat(defender.global_position - marker.global_position).length()
		var angle := absf(rad_to_deg(angle_difference(defender.rotation.y, marker.global_rotation.y)))
		var fighting := (defender.get_node("BotController") as BotController).state != BotController.State.PATROL
		if off < 1.0 and not taken.has(marker) and (angle < 20.0 or fighting):
			holding += 1
		taken[marker] = true
		detail += "%s %.1f m from %s, %.0f° off its angle%s; " % [defender.name, off, marker.name, angle, " (fighting)" if fighting else ""]
	_check("8 s into the round, each defender holds a different spot and watches its angle", holding == 3, detail)


func _test_attackers_push() -> void:
	await _wait_live_seconds(10.0)
	var attackers := _rounds.get_members(_rounds.attacking_team)
	var spawn_z := (get_tree().get_nodes_in_group(Teams.ATTACK_SPAWN_GROUP)[0] as Node3D).global_position.z
	var least_progress := INF
	var closest_pair := INF
	var min_x := INF
	var max_x := -INF
	for attacker in attackers:
		least_progress = minf(least_progress, spawn_z - attacker.global_position.z)
		min_x = minf(min_x, attacker.global_position.x)
		max_x = maxf(max_x, attacker.global_position.x)
		for other in attackers:
			if other != attacker:
				closest_pair = minf(closest_pair, _flat(attacker.global_position - other.global_position).length())
	_check("10 s into the round, the attackers push toward the defenders' end in loose groups",
			least_progress > 25.0 and max_x - min_x > 15.0 and closest_pair > 1.0,
			"every attacker at least %.0f m out of spawn (> 25), spread %.0f m across the map (> 15, more than one route), closest two %.1f m apart (> 1)" % [
					least_progress, max_x - min_x, closest_pair])


func _test_rounds_are_decided() -> void:
	var ticks := 0
	while _results.size() < ROUNDS_TO_PLAY and ticks < 128 * 130 * ROUNDS_TO_PLAY:
		await get_tree().physics_frame
		ticks += 1
	var eliminations := _results.filter(func(result: Array) -> bool: return result[0] == RoundManager.EndReason.ELIMINATION).size()
	var lengths := _results.map(func(result: Array) -> String: return "%.0f s" % result[1])
	_check("Rounds are decided by fighting, not by running out the clock",
			_results.size() == ROUNDS_TO_PLAY and eliminations >= ceili(ROUNDS_TO_PLAY * MIN_ELIMINATION_SHARE),
			"%d of %d rounds ended by elimination; live time per round: %s" % [eliminations, _results.size(), ", ".join(lengths)])


# --- Helpers ---


func _brains(team: int) -> Array[BotController]:
	var brains: Array[BotController] = []
	for member in _rounds.get_members(team):
		brains.append(member.get_node("BotController") as BotController)
	return brains


func _nearest(nodes: Array[Node], point: Vector3) -> Node3D:
	var best: Node3D = null
	for node in nodes:
		if best == null or _flat((node as Node3D).global_position - point).length() < _flat(best.global_position - point).length():
			best = node
	return best


func _flat(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)

func _wait_live_seconds(seconds: float) -> void:
	while _rounds.phase != RoundManager.Phase.LIVE or _live_ticks < roundi(seconds * 128):
		await get_tree().physics_frame


## Headless runs have no audio device; sounds that never finish "playing" would
## be reported as leaks when Godot exits.
func _silence(character: Character) -> void:
	character.footstep_sound = null
	if character.weapon != null:
		var data := character.weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		character.weapon.data = data


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
