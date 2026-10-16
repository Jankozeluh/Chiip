extends Node
## Automated checks for an online team respawn match (M9, D-082 online). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netrespawn_test.tscn
##
## A host and a client play a 3v3 team respawn match on Square, first to 15 kills, in this one
## process ([NetHarness]). The client's player runs around and fights back with taps at the
## nearest enemy it sees. Checked: the client's replica is a respawn match too; every kill and
## the score follow the host's; the dead come back on the client as on the host (the puppets and
## your own player, at the host's spot); the match ends with the same winner and score. Quits
## with the number of failed checks as the exit code.

const MAP := preload("res://maps/square.tscn")

var _harness: NetHarness
var _failures: int = 0
var _host_main: Node
var _client_main: Node
var _host_session: NetSession
var _client_session: NetSession
var _host_kills: Array = []
var _client_kills: Array = []
var _host_respawns: int = 0
var _client_respawns: int = 0
var _own_respawn_errors: Array[float] = []


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test()
	for main in [_client_main, _host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [_client_session, _host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	for i in 40:
		await get_tree().physics_frame
	remove_child(_harness)
	_harness.queue_free()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	rules.team_size = 3
	rules.enemy_team_size = 3
	rules.kill_limit = 15
	rules.time_limit = 240.0
	rules.freeze_time = 1.0
	rules.round_end_time = 1.0
	rules.respawn_delay = 2.0
	return rules


func _test() -> void:
	_host_session = _harness.start_host("Host", "Host")
	_client_session = _harness.start_client("Client", "Jan")
	await _harness.wait_until(_client_session.is_active)
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_client_main = _harness.start_game(_client_session.get_parent(), _client_session, MAP, _rules())
	_harness.silence(_client_main.get_player())
	var host := _host_main.get_net_game() as NetHost
	var client := _client_main.get_net_game() as NetClient
	var both := func() -> bool: return host.is_started() and client.is_welcomed()
	var started := await _harness.wait_until(both, 1200)
	var host_rules := host.rules
	var client_rules := client.rules
	_check("Online team respawn: the client's replica is a respawn match too", started and client_rules is RespawnMatch and host_rules is RespawnMatch, "")
	if not started:
		return
	for character in host_rules.get_participants():
		_harness.silence(character)
		character.weapon.rng.seed = character.net_id
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = character.net_id * 7
	host_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		_host_kills.append([victim.net_id, killer.net_id if killer != null else 0, host_rules.score.duplicate()]))
	client_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		_client_kills.append([victim.net_id, killer.net_id if killer != null else 0, client_rules.score.duplicate()]))
	for character in host_rules.get_participants():
		character.respawned.connect(func() -> void: _host_respawns += 1)
	var own: Character = client.player
	for character in client_rules.get_participants():
		character.respawned.connect(func() -> void:
			_client_respawns += 1
			if character == own:
				var original := host.get_character(own.net_id)
				_own_respawn_errors.append(own.global_position.distance_to(original.global_position)))
	# The client's player hunts: runs at the nearest enemy puppet it can see and taps at its chest.
	var count := [0]
	client.command_source = func(_delta: float) -> CharacterInput:
		count[0] += 1
		var command := CharacterInput.new()
		var target: Character = null
		var best := INF
		for other in client_rules.get_participants():
			if other.team != own.team and other.is_alive() and other.visible:
				var distance := other.global_position.distance_to(own.global_position)
				if distance < best:
					best = distance
					target = other
		if target != null:
			var direction := (target.get_chest_position() - own.get_eye_position()).normalized()
			command.yaw = atan2(-direction.x, -direction.z)
			command.pitch = asin(clampf(direction.y, -1.0, 1.0))
			command.move = Vector2(0.0, -1.0) if best > 8.0 else Vector2.ZERO
			command.shoot = best < 30.0 and count[0] % 32 == 0
		else:
			command.yaw = own.get_aim_angles().x
		return command
	var over := func() -> bool: return host_rules.phase == RoundManager.Phase.MATCH_END and client_rules.phase == RoundManager.Phase.MATCH_END
	var ended := await _harness.wait_until(over, 120000)
	await _harness.wait_ticks(30)
	client.command_source = Callable()
	_check("The match ends on both sides with the same winner and score (first to 15)",
			ended and client_rules.winner == host_rules.winner and client_rules.score == host_rules.score and host_rules.score.max() >= 15,
			"ended %s, host %d %s, client %d %s" % [ended, host_rules.winner, host_rules.score, client_rules.winner, client_rules.score])
	_check("Every kill reaches the client in order, with the score after it", _client_kills == _host_kills and _host_kills.size() >= 15,
			"host %d kills, client %d" % [_host_kills.size(), _client_kills.size()])
	_check("The dead come back on the client as on the host (every respawn)", _client_respawns == _host_respawns and _host_respawns >= 15,
			"host %d, client %d" % [_host_respawns, _client_respawns])
	var worst := 0.0
	for error in _own_respawn_errors:
		worst = maxf(worst, error)
	_check("Your own player comes back where the host put it", worst < 0.01, "%d respawns, worst %.3f m" % [_own_respawn_errors.size(), worst])
	print("      (score %s, %d kills, %d respawns, your player respawned %d times, %d corrections)" % [
			host_rules.score, _host_kills.size(), _host_respawns, _own_respawn_errors.size(), client.corrections])


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
