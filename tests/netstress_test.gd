extends Node
## A 5v5 online match under a bad connection (M9, task 11). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 300000 res://tests/netstress_test.tscn
##
## The host, two clients and seven bots play bomb rounds on Depot in this one process
## ([NetHarness], D-111). Client A has a good connection; client B 100 ms of round trip, 5% of
## its packets lost both ways and 15 ms of jitter. Both clients run around their spawns the whole
## time. Checked: both clients see every round end, kill and score exactly as the host does;
## their predictions need few corrections; B's puppets still move smoothly; the bomb ends every
## round in the same state on all three; and the traffic per client stays small (a 5v5 at 64
## snapshots a second). Quits with the number of failed checks as the exit code.

const MAP := preload("res://maps/depot.tscn")
## Rounds to play (each is short: elimination, a bomb, or the clock).
const ROUNDS := 4

var _harness: NetHarness
var _failures: int = 0
var _host_main: Node
var _mains: Array[Node] = []
var _clients: Array[NetClient] = []
var _client_sessions: Array[NetSession] = []
var _host_session: NetSession
var _host_rules: RoundManager
## Per side (0: host, 1: A, 2: B): the round ends [winner, reason, score] and kills [victim, killer, headshot].
var _rounds: Array = [[], [], []]
var _kills: Array = [[], [], []]
## The bomb's state when each round ended, per side.
var _bomb_states: Array = [[], [], []]
## B's view of one puppet: the largest step between two ticks while it was alive.
var _worst_step: float = 0.0
var _watched: Character
var _watched_last := Vector3.INF


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test()
	for main in _mains:
		if is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in _client_sessions + [_host_session]:
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


func _physics_process(_delta: float) -> void:
	# B's puppet of a bot: it must glide, not jump, even with loss and jitter.
	if _watched != null and is_instance_valid(_watched):
		var at := _watched.global_position
		if _watched.is_alive() and _watched_last != Vector3.INF:
			_worst_step = maxf(_worst_step, at.distance_to(_watched_last))
		_watched_last = at if _watched.is_alive() else Vector3.INF


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = 5
	rules.enemy_team_size = 5
	rules.rounds_to_win = 10
	rules.freeze_time = 1.0
	rules.round_time = 45.0
	rules.round_end_time = 1.0
	rules.bomb_fuse_time = 20.0
	return rules


func _test() -> void:
	_host_session = _harness.start_host("Host", "Host")
	for side_name in ["A", "B"]:
		var session := _harness.start_client(side_name, side_name)
		_client_sessions.append(session)
		await _harness.wait_until(session.is_active)
	_host_session.set_player_team(_client_sessions[0].local_peer_id, 0)
	_host_session.set_player_team(_client_sessions[1].local_peer_id, 1)
	await _harness.wait_ticks(10)
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_mains.append(_host_main)
	for session in _client_sessions:
		var main := _harness.start_game(session.get_parent(), session, MAP, _rules())
		_harness.silence(main.get_player())
		_mains.append(main)
		_clients.append(main.get_net_game() as NetClient)
	var host := _host_main.get_net_game() as NetHost
	var everyone_in := func() -> bool: return host.is_started() and _clients[0].is_welcomed() and _clients[1].is_welcomed()
	var started := await _harness.wait_until(everyone_in, 1200)
	_check("A 5v5 starts with the host, two clients and seven bots", started and host.rules.get_participants().size() == 10,
			"started %s, %d characters" % [started, host.rules.get_participants().size() if started else 0])
	if not started:
		return
	_host_rules = host.rules
	for character in _host_rules.get_participants():
		_harness.silence(character)
		character.weapon.rng.seed = character.net_id
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = character.net_id
	_listen(0, _host_rules)
	for i in _clients.size():
		_harness.silence_bomb(_clients[i].rules.bomb)
		_listen(i + 1, _clients[i].rules)
	_harness.silence_bomb(_host_rules.bomb)
	# B's bad connection: 50 ms each way (B and the host both delay what they receive from each
	# other... the host's delay counts for A too, so A gets 50 ms of round trip), 5% loss, jitter.
	var bad := _client_sessions[1]
	bad.fake_lag_ms = 50.0
	bad.fake_jitter_ms = 15.0
	bad.fake_loss = 0.05
	bad.rng.seed = 11
	_host_session.fake_lag_ms = 50.0
	_host_session.fake_loss = 0.05
	_host_session.rng.seed = 12
	# Both clients run around their spawns.
	for i in _clients.size():
		var client := _clients[i]
		var count := [0]
		var yaw := client.player.get_aim_angles().x
		client.command_source = func(_delta: float) -> CharacterInput:
			count[0] += 1
			var command := CharacterInput.new()
			command.yaw = yaw + count[0] * 0.01
			command.move = Vector2(sin(count[0] * 0.02), -1.0).normalized() if (count[0] / 160) % 3 != 2 else Vector2.ZERO
			command.jump = count[0] % 150 == 60
			return command
	var bot := _host_rules.get_members(1).filter(func(c: Character) -> bool: return c.get_node_or_null("BotController") != null)[0] as Character
	_watched = _clients[1].get_character(bot.net_id)
	# A respawn moves it across the map in one tick: that is no glide to measure.
	_watched.respawned.connect(func() -> void: _watched_last = Vector3.INF)
	var corrections_before := [_clients[0].corrections, _clients[1].corrections]
	var played := func() -> bool: return _rounds[0].size() >= ROUNDS
	var done := await _harness.wait_until(played, 200000)
	await _harness.wait_ticks(60)
	_check("%d rounds are played under the bad connection" % ROUNDS, done, "%d rounds" % _rounds[0].size())
	for i in 2:
		var side := i + 1
		_check("Client %s sees every round end exactly as the host (winner, reason, score)" % ["A", "B"][i],
				_rounds[side].slice(0, _rounds[0].size()) == _rounds[0], "host %s, client %s" % [_rounds[0], _rounds[side]])
		_check("Client %s's kill feed has every kill of the host's, in order" % ["A", "B"][i],
				_kills[side].slice(0, _kills[0].size()) == _kills[0] and _kills[0].size() >= 4, "host %d kills, client %d" % [_kills[0].size(), _kills[side].size()])
		_check("Client %s's bomb ends every round in the host's state" % ["A", "B"][i],
				_bomb_states[side].slice(0, _bomb_states[0].size()) == _bomb_states[0], "host %s, client %s" % [_bomb_states[0], _bomb_states[side]])
	var ticks := float(_rounds[0].size()) * 20.0 * Engine.physics_ticks_per_second
	var corrections_a: int = _clients[0].corrections - corrections_before[0]
	var corrections_b: int = _clients[1].corrections - corrections_before[1]
	_watched = null
	print("      (corrections: A %d, B %d, largest A %.2f m, B %.2f m, teleports A %d, B %d; B's puppet steps at most %.3f m)" % [
			corrections_a, corrections_b, _clients[0].largest_correction, _clients[1].largest_correction,
			_clients[0].teleports, _clients[1].teleports, _worst_step])
	_check("Predictions need correcting less than once a second, also at 100 ms with 5% loss, each by under a metre (smoothed)",
			corrections_a <= ticks / Engine.physics_ticks_per_second and corrections_b <= ticks / Engine.physics_ticks_per_second
					and _clients[0].largest_correction < 1.0 and _clients[1].largest_correction < 1.0,
			"A %d, B %d in about %.0f s" % [corrections_a, corrections_b, ticks / Engine.physics_ticks_per_second])
	_check("Through loss and jitter, B's puppets still glide (at most 15 cm a tick, a bot runs 4.3 cm)", _worst_step < 0.15, "%.3f m" % _worst_step)
	var down_a := _clients[0].kilobytes_in
	var up_a := _clients[0].kilobytes_out
	print("      (traffic of a 5v5 client: %.1f KB/s down, %.1f KB/s up; the host sends %.1f KB/s in all)" % [
			down_a, up_a, _host_session.bytes_sent / 1024.0 / maxf(host.tick / float(Engine.physics_ticks_per_second), 1.0)])
	_check("A 5v5 client's traffic stays small: under 48 KB/s down and 24 KB/s up", down_a > 5.0 and down_a < 48.0 and up_a < 24.0,
			"%.1f KB/s down, %.1f up" % [down_a, up_a])


func _listen(side: int, rules: RoundManager) -> void:
	rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_rounds[side].append([winner, reason, rules.score.duplicate()])
		# The bomb's last state comes with the snapshots, a moment after the round's end event.
		get_tree().create_timer(0.3, false, true).timeout.connect(func() -> void:
			_bomb_states[side].append(rules.bomb.state if is_instance_valid(rules) and rules.bomb != null else -1)))
	rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_kills[side].append([victim.net_id, killer.net_id if killer != null else 0, headshot]))


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
