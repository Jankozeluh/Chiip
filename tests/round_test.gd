extends Node
## Automated round checks. Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/round_test.tscn
##
## Loads the real test map and plays a 3v3 match on it with short timings: you
## (standing still, no keyboard) plus two bot teammates against three bots.
## Bots hold their spawn after freeze time, so nobody meets, and the test
## decides the fights by dealing damage directly. Checks freeze time, spawns,
## winning by elimination and on time-out, that the dead stay dead until the
## next round, and the kill, assist and damage stats. Quits with the number of
## failed checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const FREEZE_TIME := 0.5
const ROUND_TIME := 2.0
const ROUND_END_TIME := 0.5

var _map: Node3D
var _rounds: RoundManager
var _player: Character
var _failures: int = 0
## [winner, reason] for every round_ended signal.
var _results: Array = []
## [victim, killer, headshot] for every character_killed signal.
var _kills: Array = []


func _ready() -> void:
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var settings := MatchSettings.new()
	settings.freeze_time = FREEZE_TIME
	settings.round_time = ROUND_TIME
	settings.round_end_time = ROUND_END_TIME
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 7
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
	_rounds.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void: _kills.append([victim, killer, headshot]))
	_map.add_child(_rounds)
	# The match starts at the end of the first frame.
	await _wait_ticks(2)
	for character in _rounds.get_participants():
		_silence(character)
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_round_start()
	await _test_freeze_time()
	await _test_elimination()
	await _test_time_out()


func _test_round_start() -> void:
	var members := _rounds.get_participants()
	var at_spawn := members.all(func(member: Character) -> bool: return _distance_to_own_spawn(member) < 0.5)
	var full := members.all(func(member: Character) -> bool:
		return member.health == member.max_health and member.weapon.magazine == member.weapon.data.magazine_size)
	_check("A 3v3 match starts: you plus 2 bot teammates against 3 bots",
			_rounds.get_members(0).size() == 3 and _rounds.get_members(1).size() == 3 and _player.team == 0,
			"team sizes %d and %d, you on team %d" % [_rounds.get_members(0).size(), _rounds.get_members(1).size(), _player.team])
	_check("Round 1 starts in freeze time, everyone at their side's spawn with full health and ammo",
			_rounds.round_number == 1 and _rounds.phase == RoundManager.Phase.FREEZE and at_spawn and full,
			"round %d, phase %s, all on own spawn: %s, all full: %s" % [
					_rounds.round_number, RoundManager.Phase.keys()[_rounds.phase], at_spawn, full])


func _test_freeze_time() -> void:
	# Bots still patrol during freeze time and you hold forward and shoot: nobody may move or fire.
	var start_positions := {}
	for member in _rounds.get_participants():
		start_positions[member] = member.global_position
	Input.action_press("move_forward")
	Input.action_press("shoot")
	await _wait_seconds(FREEZE_TIME * 0.6)
	var moved := 0.0
	for member: Character in start_positions:
		moved = maxf(moved, member.global_position.distance_to(start_positions[member]))
	var fired := _player.weapon.magazine < _player.weapon.data.magazine_size
	_check("Freeze time: nobody can move or shoot", moved < 0.05 and not fired,
			"largest movement %.3f m, you fired: %s" % [moved, fired])
	Input.action_release("shoot")
	# From now on the bots hold their spawn, so the teams never meet.
	for member in _rounds.get_participants():
		if member != _player:
			(member.get_node("BotController") as BotController).hold_position = true
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var live_start := _player.global_position
	await _wait_seconds(0.3)
	Input.action_release("move_forward")
	_check("After freeze time the round goes live and you can move",
			_rounds.phase == RoundManager.Phase.LIVE and _player.global_position.distance_to(live_start) > 0.5,
			"phase %s, moved %.2f m in 0.3 s" % [RoundManager.Phase.keys()[_rounds.phase], _player.global_position.distance_to(live_start)])


func _test_elimination() -> void:
	var enemies := _rounds.get_members(1)
	enemies[0].take_damage(500.0, Hitbox.Zone.HEAD, _player)
	enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	var going_on := _results.is_empty() and _rounds.phase == RoundManager.Phase.LIVE
	enemies[2].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(2)
	_check("Killing the whole enemy team wins the round (not before)",
			going_on and _results == [[0, RoundManager.EndReason.ELIMINATION]] and _rounds.phase == RoundManager.Phase.ROUND_END,
			"after 2 of 3 kills the round went on: %s; results %s" % [going_on, _results])
	var stats := _rounds.get_stats(_player)
	_check("Kills are credited, a headshot is flagged",
			stats.kills == 3 and _kills.size() == 3 and _kills[0] == [enemies[0], _player, true] and _kills[1][2] == false,
			"your kills %d, kill events %d, first headshot: %s" % [stats.kills, _kills.size(), _kills[0][2] if not _kills.is_empty() else null])
	await _wait_seconds(ROUND_END_TIME * 0.6)
	var still_dead := enemies.all(func(enemy: Character) -> bool: return not enemy.is_alive())
	await _wait_for_phase(RoundManager.Phase.FREEZE)
	var back := enemies.all(func(enemy: Character) -> bool: return enemy.is_alive() and enemy.health == enemy.max_health)
	_check("The dead stay dead until the next round, then everyone is back",
			still_dead and back and _rounds.round_number == 2,
			"dead during round end: %s; round %d, all back with full health: %s" % [still_dead, _rounds.round_number, back])


func _test_time_out() -> void:
	await _wait_for_phase(RoundManager.Phase.LIVE)
	# An assist: you deal 50 to an enemy that your teammate finishes off.
	var enemy := _rounds.get_members(1)[0]
	var mate := _rounds.get_members(0).filter(func(member: Character) -> bool: return member != _player)[0] as Character
	enemy.take_damage(50.0, Hitbox.Zone.STOMACH, _player)
	enemy.take_damage(100.0, Hitbox.Zone.CHEST, mate)
	var you := _rounds.get_stats(_player)
	var them := _rounds.get_stats(mate)
	# Your damage counts health actually removed: 3 × 100 in round 1 (not 3 × 500), plus 50.
	_check("Assists and damage: you deal 50, a teammate finishes the enemy",
			you.assists == 1 and them.kills == 1 and is_equal_approx(them.damage, 50.0) and is_equal_approx(you.damage, 350.0),
			"your assists %d and damage %.0f (expected 1 and 350); teammate's kills %d and damage %.0f (expected 1 and 50)" % [
					you.assists, you.damage, them.kills, them.damage])
	var results_before := _results.size()
	await _wait_for_phase(RoundManager.Phase.ROUND_END)
	var defenders := _rounds.get_defending_team()
	_check("When time runs out, the defending side wins",
			_results.size() == results_before + 1 and _results.back() == [defenders, RoundManager.EndReason.TIME],
			"defending team %d, result %s" % [defenders, _results.back() if _results.size() > results_before else "none"])


# --- Helpers ---


func _distance_to_own_spawn(member: Character) -> float:
	var closest := INF
	for marker in get_tree().get_nodes_in_group(Teams.spawn_group(_rounds.get_side(member.team))):
		closest = minf(closest, member.global_position.distance_to((marker as Node3D).global_position))
	return closest


## Waits until the round manager reaches [param phase] (at most 10 s).
func _wait_for_phase(phase: RoundManager.Phase) -> void:
	var ticks := 0
	while _rounds.phase != phase and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


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


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
