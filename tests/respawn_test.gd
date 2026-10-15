extends Node
## Automated checks for the team respawn mode (M8, D-082). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/respawn_test.tscn
##
## Plays short team respawn matches on Depot (kill limit 5, 20 s, 1 s to
## respawn). The bots are frozen once the match goes live, so they neither move
## nor shoot; the test decides the fights by dealing damage directly. Checks:
## the start (both team ends, freeze time, no bomb, the clock), kills scoring
## for the killer's team and nothing else, coming back after the respawn delay
## with full health at a respawn point, the choice of respawn point (away from
## the enemies and out of their sight), the kill limit, the time limit with a
## leader, overtime on a tie, the HUD's texts, and that the main scene runs the
## mode from the match settings with spectating off. Quits with the number of
## failed checks as the exit code.

const MAP_SCENE := preload("res://maps/depot.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const KILL_LIMIT := 5
const TIME_LIMIT := 20.0
const RESPAWN_DELAY := 1.0

var _map: Node3D
var _rounds: RespawnMatch
var _player: Character
var _hud: Node
var _failures: int = 0
## [winner, reason] for every round_ended signal, and the winner of every match_ended.
var _results: Array = []
var _match_ends: Array = []


func _ready() -> void:
	await _test_start()
	await _test_kills_and_respawns()
	await _test_spawn_choice()
	await _test_kill_limit()
	await _test_time_limit()
	await _test_overtime()
	await _test_main_scene()
	_free_match()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The checks ---


func _test_start() -> void:
	await _new_match()
	var at_ends := _rounds.get_participants().all(func(member: Character) -> bool:
		var group := Teams.spawn_group(_rounds.get_side(member.team))
		return _markers(group).any(func(marker: Node3D) -> bool: return _flat(marker.global_position, member.global_position) < 0.5))
	_check("A team respawn match starts like a round: both teams at their ends, frozen, no bomb",
			_rounds.is_team_respawn() and _rounds.phase == RoundManager.Phase.FREEZE and at_ends and _rounds.bomb == null
			and _player.frozen and _rounds.score == [0, 0],
			"phase %s, at their ends %s, bomb %s, score %s" % [RoundManager.Phase.keys()[_rounds.phase], at_ends, _rounds.bomb, _rounds.score])
	_check("The freeze time says what wins", _center() == ["", "Team respawn  ·  starts in 1", "First team to %d kills wins" % KILL_LIMIT, ""], str(_center()))
	await _go_live()
	_check("Live: the clock runs the time limit and the top bar says what wins",
			_rounds.phase == RoundManager.Phase.LIVE and absf(_rounds.time_left - TIME_LIMIT) < 0.1 and _round_label() == "First to %d" % KILL_LIMIT
			and _timer_text() == "0:20",
			"time left %.1f, label '%s', timer '%s'" % [_rounds.time_left, _round_label(), _timer_text()])


func _test_kills_and_respawns() -> void:
	var enemy := _rounds.get_members(1)[0]
	var mate := _rounds.get_members(0)[1]
	enemy.take_damage(500.0, Hitbox.Zone.HEAD, _player)
	await _wait_ticks(2)
	_check("A kill of an enemy is a point for the killer's team, shown in the top bar",
			_rounds.score == [1, 0] and _bar_score(0) == "1" and _bar_score(1) == "0", "score %s" % [_rounds.score])
	mate.take_damage(500.0, Hitbox.Zone.CHEST, null)
	await _wait_ticks(2)
	_check("A death without an enemy killer scores nothing", _rounds.score == [1, 0], "score %s" % [_rounds.score])
	await _wait_seconds(RESPAWN_DELAY - 0.2)
	var still_dead := not enemy.is_alive() and _rounds.get_respawn_time_left(enemy) > 0.0
	await _wait_seconds(0.4)
	var on_marker := _markers(RespawnMatch.RESPAWN_GROUP).any(func(marker: Node3D) -> bool: return _flat(marker.global_position, enemy.global_position) < 0.5)
	_check("The dead come back after the respawn delay, with full health, at a respawn point",
			still_dead and enemy.is_alive() and enemy.health == enemy.max_health and on_marker and mate.is_alive()
			and _rounds.get_respawn_time_left(enemy) < 0.0,
			"dead at 0.8 s: %s, alive at 1.2 s: %s (%.0f HP), on a respawn point: %s" % [still_dead, enemy.is_alive(), enemy.health, on_marker])
	var stats := _rounds.get_stats(_player)
	_check("The scoreboard numbers count as in rounds", stats.kills == 1 and _rounds.get_stats(enemy).deaths == 1,
			"your kills %d, the enemy's deaths %d" % [stats.kills, _rounds.get_stats(enemy).deaths])


func _test_spawn_choice() -> void:
	var enemies := _rounds.get_members(1)
	var victim := _rounds.get_members(0)[2]
	# All enemies at the north end: the victim should come back at the south end, and the other way round.
	var picks := []
	for zone in ["North", "South"]:
		for i in enemies.size():
			await _teleport(enemies[i], _map.get_node("Respawns/%s%d" % [zone, i + 1]).global_position)
		var spot := _rounds.pick_spawn(victim).origin
		var nearest := INF
		var seen := false
		for enemy in enemies:
			nearest = minf(nearest, _flat(enemy.global_position, spot))
			seen = seen or _rounds._can_see_spot(enemy, spot, victim)
		picks.append([zone, _marker_name_at(spot), nearest, seen])
	# Every spot 40 m or more from the nearest enemy counts as equally safe (RespawnMatch.SAFE_DISTANCE).
	var ok: bool = picks.all(func(pick: Array) -> bool: return pick[2] >= 35.0 and not pick[3]) \
			and not String(picks[0][1]).begins_with("North") and not String(picks[1][1]).begins_with("South")
	_check("A respawn point is chosen away from the enemies (35 m or more here) and out of their sight",
			ok, ", ".join(picks.map(func(pick: Array) -> String: return "enemies %s → %s (%.0f m, seen %s)" % pick)))
	# A spot someone stands on is skipped.
	var free_spot := _rounds.pick_spawn(victim).origin
	var blocker := _rounds.get_members(0)[1]
	await _teleport(blocker, free_spot)
	var second := _rounds.pick_spawn(victim).origin
	_check("A respawn point someone stands on is skipped", _flat(second, free_spot) > 1.0,
			"%s taken, chose %s" % [_marker_name_at(free_spot), _marker_name_at(second)])


func _test_kill_limit() -> void:
	await _new_match()
	await _go_live()
	var killer := _rounds.get_members(1)[0]
	var victims := _rounds.get_members(0)
	for i in KILL_LIMIT:
		victims[i % victims.size()].take_damage(500.0, Hitbox.Zone.CHEST, killer)
		await _wait_seconds(RESPAWN_DELAY + 0.2 if i < KILL_LIMIT - 1 else 0.1)
	_check("The first team to the kill limit wins: the banner says who and why",
			_results == [[1, RoundManager.EndReason.KILL_LIMIT]] and _rounds.score == [0, KILL_LIMIT]
			and _center()[0] == "The enemy team wins" and _center()[1] == "First to %d kills" % KILL_LIMIT,
			"results %s, score %s, banner %s" % [_results, _rounds.score, _center()])
	await _wait_seconds(1.1)
	_check("After the round-end pause the match ends", _match_ends == [1] and _rounds.phase == RoundManager.Phase.MATCH_END,
			"match ends %s, phase %s" % [_match_ends, RoundManager.Phase.keys()[_rounds.phase]])


func _test_time_limit() -> void:
	await _new_match()
	await _go_live()
	_rounds.get_members(1)[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_seconds(TIME_LIMIT + 0.2)
	_check("When time runs out, the team with more kills wins",
			_results == [[0, RoundManager.EndReason.TIME_LIMIT]] and _center()[0] == "Your team wins"
			and _center()[1] == "Most kills when time ran out",
			"results %s, banner %s" % [_results, _center()])


func _test_overtime() -> void:
	await _new_match()
	await _go_live()
	await _wait_seconds(TIME_LIMIT + 0.2)
	await _wait_ticks(2)
	_check("A tie when time runs out goes to overtime: the clock shows OT and the next kill wins",
			_rounds.overtime and _rounds.phase == RoundManager.Phase.LIVE and _results.is_empty()
			and _timer_text() == RoundHud.OVERTIME_TIMER_TEXT and _round_label() == "Next kill wins" and _center()[0] == "Overtime",
			"overtime %s, phase %s, timer '%s', label '%s', center %s" % [_rounds.overtime, RoundManager.Phase.keys()[_rounds.phase], _timer_text(), _round_label(), _center()])
	await _wait_seconds(2.0)
	var still := _rounds.phase == RoundManager.Phase.LIVE
	_rounds.get_members(0)[0].take_damage(500.0, Hitbox.Zone.CHEST, _rounds.get_members(1)[1])
	await _wait_ticks(2)
	_check("In overtime the next kill decides the match", still and _results == [[1, RoundManager.EndReason.TIME_LIMIT]],
			"still live after 2 s: %s, results %s" % [still, _results])


## The main scene plays a team respawn match when the match settings say so,
## without spectating and with the "Respawning..." hint.
func _test_main_scene() -> void:
	_free_match()
	var main := MAIN_SCENE.instantiate()
	main.set("map_scene", MAP_SCENE)
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	main.set("match_settings", settings)
	add_child(main)
	await _wait_ticks(3)
	var map: Node = main.call("get_map")
	var rules := map.get_node_or_null("RespawnMatch") as RespawnMatch
	if rules != null:
		for member in rules.get_participants():
			_silence(member)
	var controller := map.get_node("Player/PlayerController") as PlayerController
	var hud := main.get_node("HUD")
	_check("The main scene runs team respawn from the match settings, with no spectating and the respawn hint",
			rules != null and map.get_node_or_null("RoundManager") == null and not controller.spectating_enabled
			and hud.get("respawn_hint") == true,
			"rules %s, spectating %s, respawn hint %s" % [rules, controller.spectating_enabled, hud.get("respawn_hint")])
	remove_child(main)
	main.queue_free()


# --- Helpers ---


## A fresh team respawn match on Depot with the short test rules, a HUD, and every bot silenced.
func _new_match() -> void:
	_free_match()
	_results.clear()
	_match_ends.clear()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	settings.freeze_time = 0.5
	settings.round_end_time = 1.0
	settings.kill_limit = KILL_LIMIT
	settings.time_limit = TIME_LIMIT
	settings.respawn_delay = RESPAWN_DELAY
	_rounds = RespawnMatch.new()
	_rounds.settings = settings
	_rounds.rng.seed = 5
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
	_rounds.match_ended.connect(func(winner: int) -> void: _match_ends.append(winner))
	_map.add_child(_rounds)
	await _wait_ticks(2)
	for character in _rounds.get_participants():
		_silence(character)
	Teams.set_viewer_team(_player.team)
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.call("set_player", _player)
	_hud.call("set_round_manager", _rounds)
	await _wait_ticks(2)


func _free_match() -> void:
	if _hud != null:
		remove_child(_hud)
		_hud.queue_free()
		_hud = null
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


## Waits for the live phase, then freezes every bot, so none of them moves or shoots.
func _go_live() -> void:
	var ticks := 0
	while _rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	for member in _rounds.get_participants():
		if member != _player:
			member.frozen = true
	await _wait_ticks(2)


func _teleport(character: Character, at: Vector3) -> void:
	character.respawn(at, character.rotation.y)
	await _wait_ticks(3)


func _markers(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return _map.is_ancestor_of(node))


func _marker_name_at(spot: Vector3) -> String:
	for marker: Node3D in _markers(RespawnMatch.RESPAWN_GROUP):
		if _flat(marker.global_position, spot) < 0.1:
			return marker.name
	return str(spot)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _round_label() -> String:
	return (_hud.get_node("RoundHud/TopBar/TimerBox/Margin/Content/RoundLabel") as Label).text


func _timer_text() -> String:
	return (_hud.get_node("RoundHud/TopBar/TimerBox/Margin/Content/Timer") as Label).text


## Your score (team 0) or theirs (team 1) as the top bar shows it.
func _bar_score(team: int) -> String:
	var box := "YourBox" if team == Teams.viewer_team else "EnemyBox"
	return (_hud.get_node("RoundHud/TopBar/%s/Margin/Content/Score" % box) as Label).text


func _center() -> Array:
	var lines := []
	for label_name in ["Title", "Line1", "Line2", "Line3"]:
		var label := _hud.get_node("RoundHud/Center/" + label_name) as Label
		lines.append(label.text if label.visible else "")
	return lines


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
