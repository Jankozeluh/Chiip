extends Node
## Automated checks for online matches (M9). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netplay_test.tscn
##
## A host and a client play a real bomb match on Depot in this one process, each in the real
## game scene with a physics world of its own ([NetHarness], D-111). Checked so far: one match on
## every screen (task 3): the friend's character joins the host's match before the bots, the
## client builds the same characters (names, teams, classes, network ids) as puppets, and its
## replica round manager and bomb follow the host's: phases, rounds, score, kills, the kill
## feed, the scoreboard and the bomb's carrier and state. Server authority (task 4): the
## client's commands move its character on the host, each command runs exactly once (also with
## 25% of the packets lost), a flood of commands can't run faster than the budget, and a shot's
## spread is rolled from its command's number. Quits with the number of failed checks as the
## exit code.

const MAP := preload("res://maps/depot.tscn")
## Seconds of each phase, short so the test plays a few rounds quickly.
const FREEZE_TIME := 1.0
const ROUND_TIME := 40.0
const ROUND_END_TIME := 1.0

var _harness: NetHarness
var _failures: int = 0
var _host_session: NetSession
var _client_session: NetSession
var _host_main: Node
var _client_main: Node
var _host: NetHost
var _client: NetClient
var _host_rules: RoundManager
var _client_rules: RoundManager
## What each side's round manager announced: kills [victim name, killer name, headshot] and round ends.
var _host_kills: Array = []
var _client_kills: Array = []
var _host_rounds: Array = []
var _client_rounds: Array = []


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _start()
	if _host != null and _client != null and _client.is_welcomed():
		# The first snapshots bring the bomb and everyone's place.
		await _harness.wait_ticks(10)
		_test_same_match()
		await _test_commands()
		await _test_rounds()
	_stop()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = 2
	rules.enemy_team_size = 2
	rules.rounds_to_win = 2
	rules.freeze_time = FREEZE_TIME
	rules.round_time = ROUND_TIME
	rules.round_end_time = ROUND_END_TIME
	return rules


## A host and one client in the lobby, then the same match started on both.
func _start() -> void:
	_host_session = _harness.start_host("Host", "Host")
	_client_session = _harness.start_client("Client", "Jan")
	var joined := await _harness.wait_until(_client_session.is_active)
	_check("The client joins the host's session", joined, "")
	if not joined:
		return
	_host_main = _harness.start_game(_host_session.get_parent(), _host_session, MAP, _rules())
	_harness.silence(_host_main.get_player())
	_host = _host_main.get_net_game() as NetHost
	_host_rules = _host_main.get_map().get_node("RoundManager") as RoundManager
	await _harness.wait_ticks(10)
	_check("The host waits for the client to load before starting", _host != null and not _host.is_started(), "")
	_client_main = _harness.start_game(_client_session.get_parent(), _client_session, MAP, _rules())
	_harness.silence(_client_main.get_player())
	_client = _client_main.get_net_game() as NetClient
	_client_rules = _client_main.get_map().get_node("RoundManager") as RoundManager
	var started := await _harness.wait_until(func() -> bool: return _host.is_started() and _client.is_welcomed(), 600)
	_check("Once the client has loaded the map the match starts and the client is welcomed", started,
			"started %s, welcomed %s" % [_host.is_started(), _client.is_welcomed()])
	if not started:
		return
	for character in _host_rules.get_participants():
		_harness.silence(character)
	_harness.silence_bomb(_host_rules.bomb)
	_harness.silence_bomb(_client_rules.bomb)
	_host_rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_host_kills.append([String(victim.name), String(killer.name) if killer != null else "", headshot]))
	_client_rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_client_kills.append([String(victim.name), String(killer.name) if killer != null else "", headshot]))
	_host_rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_host_rounds.append([winner, reason, _host_rules.score.duplicate()]))
	_client_rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_client_rounds.append([winner, reason, _client_rules.score.duplicate()]))


func _test_same_match() -> void:
	var host_list := _describe(_host_rules)
	var client_list := _describe(_client_rules)
	var friend := _host.get_character_of(_client_session.local_peer_id)
	_check("The host's match: the host, the friend (on the smaller team, before the bots), then a bot per empty slot",
			host_list.size() == 4 and host_list[0][1] == "Host" and host_list[1][1] == "Jan"
					and friend != null and friend.get_controller() is NetworkController and friend.manual
					and friend.team == 1 and _host_main.get_player().team == 0
					and _host_rules.get_members(0).size() == 2 and _host_rules.get_members(1).size() == 2,
			"%s" % [host_list])
	_check("The client has the same characters: network ids, names, teams and classes, in the same order",
			client_list == host_list, "host %s, client %s" % [host_list, client_list])
	var puppets_remote := true
	for character in _client_rules.get_participants():
		if character != _client_main.get_player() and not (character.remote and character.replica and character.weapon.remote):
			puppets_remote = false
	var own: Character = _client_main.get_player()
	_check("On the client the friend's own character is the map's player, named after them; everyone else is a puppet",
			own.name == "Jan" and own.net_id == friend.net_id and own.replica and not own.remote and puppets_remote
					and own.team == 1 and Teams.viewer_team == 1,
			"own %s (id %d, team %d), puppets remote %s" % [own.name, own.net_id, own.team, puppets_remote])
	_check("The client's replica round manager shows the host's round, phase, sides and score",
			_client_rules.replica and _client_rules.round_number == _host_rules.round_number and _client_rules.phase == _host_rules.phase
					and _client_rules.attacking_team == _host_rules.attacking_team and _client_rules.score == _host_rules.score,
			"host round %d phase %d, client round %d phase %d" % [_host_rules.round_number, _host_rules.phase, _client_rules.round_number, _client_rules.phase])
	var host_bomb := _host_rules.bomb
	var client_bomb := _client_rules.bomb
	_check("The client has a replica bomb with the same carrier",
			host_bomb != null and client_bomb != null and client_bomb.replica and is_instance_valid(client_bomb.carrier)
					and client_bomb.carrier.net_id == host_bomb.carrier.net_id,
			"host carrier %s, client carrier %s" % [host_bomb.carrier.name if host_bomb != null else "-",
					client_bomb.carrier.name if client_bomb != null and client_bomb.carrier != null else "-"])


## The client's commands drive its character on the host (D-103). The bots are held still
## meanwhile, so nobody gets in the way. "Exactly once" is checked on the totals: every command
## the client ever made has run once on the host (the client never stops sending in a real game,
## so a lost last packet is always covered by the next).
func _test_commands() -> void:
	await _harness.wait_until(func() -> bool: return _host_rules.phase == RoundManager.Phase.LIVE, 600)
	_hold_bots(true)
	var friend := _host.get_character_of(_client_session.local_peer_id)
	var controller := friend.get_controller() as NetworkController
	var own: Character = _client_main.get_player()
	var yaw := friend.rotation.y
	var start := friend.global_position
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, false)
	await _harness.wait_ticks(128)
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, true)
	await _harness.wait_ticks(40)
	# Stop sending for a moment, so nothing is on its way while the two sides are compared.
	_client.set_physics_process(false)
	await _harness.wait_ticks(20)
	var moved := Vector2(friend.global_position.x - start.x, friend.global_position.z - start.z).length()
	_check("The client's commands move its character on the host (a second of running forward: over 3 m)",
			moved > 3.0, "%.2f m" % moved)
	_check("The host runs every command exactly once, in order, and confirms the last one",
			controller.commands_run == _client.command_tick and controller.last_run == _client.command_tick and _client.acked_tick == _client.command_tick,
			"made %d, run %d, last run %d, acked %d" % [_client.command_tick, controller.commands_run, controller.last_run, _client.acked_tick])
	_check("The client shows its character where the host has it", own.global_position.distance_to(friend.global_position) < 0.01,
			"%.3f m apart" % own.global_position.distance_to(friend.global_position))
	_client.set_physics_process(true)

	# A quarter of the client's packets lost: the repeats in every packet still bring every command.
	_host_session.rng.seed = 99
	_host_session.fake_loss = 0.25
	var made_before := _client.command_tick
	var shot_tick := [0]
	_client.command_source = func(_delta: float) -> CharacterInput:
		var command := _walk(yaw + PI, false)
		# One shot, at the 60th command.
		if _client.command_tick - made_before == 59:
			command.shoot = true
			shot_tick[0] = _client.command_tick + 1
		return command
	await _harness.wait_ticks(128)
	_client.command_source = func(_delta: float) -> CharacterInput: return _walk(yaw, true)
	await _harness.wait_ticks(40)
	_host_session.fake_loss = 0.0
	await _harness.wait_ticks(20)
	_client.set_physics_process(false)
	await _harness.wait_ticks(20)
	_check("With 25% of the packets lost, every command still runs exactly once",
			controller.commands_run == _client.command_tick and controller.last_run == _client.command_tick and _host_session.packets_dropped > 10,
			"made %d, run %d, %d packets dropped" % [_client.command_tick, controller.commands_run, _host_session.packets_dropped])
	_check("A shot's spread is rolled from its command's number (the same on both computers)",
			shot_tick[0] > 0 and friend.weapon.rng.seed == hash([friend.net_id, shot_tick[0]]),
			"seed %d, expected %d" % [friend.weapon.rng.seed, hash([friend.net_id, shot_tick[0]])])

	# A flood: 40 new commands in one packet can't all run at once.
	var flood: Array[CharacterInput] = []
	for i in 40:
		var command := _walk(yaw, true)
		command.tick = _client.command_tick + 1 + i
		flood.append(command)
	var run_before := controller.commands_run
	_client_session.send_packet(1, NetProtocol.pack_commands(flood), false)
	await _harness.wait_until(func() -> bool: return controller.commands_run > run_before, 20)
	var first_tick := controller.commands_run - run_before
	await _harness.wait_ticks(60)
	_check("A flood of 40 commands runs no faster than the budget (at most 9 in a tick), then all of them",
			first_tick <= NetworkController.MAX_BUDGET + 1 and controller.commands_run - run_before == 40,
			"%d in the first tick, %d in all" % [first_tick, controller.commands_run - run_before])
	_client.command_tick += 40
	_client.set_physics_process(true)
	_client.command_source = Callable()
	_hold_bots(false)


## A command looking along [param yaw], running forward unless [param still].
func _walk(yaw: float, still: bool) -> CharacterInput:
	var command := CharacterInput.new()
	command.yaw = yaw
	command.move = Vector2.ZERO if still else Vector2(0.0, -1.0)
	return command


## Holds the host's bots still (they can't move or shoot) or lets them go again.
func _hold_bots(hold: bool) -> void:
	for character in _host_rules.get_participants():
		if character.get_node_or_null("BotController") != null:
			character.frozen = hold


## Plays rounds (the two players stand still, the bots fight) and compares what both sides saw.
func _test_rounds() -> void:
	var host_bots: Array = _host_rules.get_participants().filter(func(c: Character) -> bool: return c.get_node_or_null("BotController") != null)
	await _harness.wait_until(func() -> bool: return _host_rules.phase == RoundManager.Phase.LIVE, 600)
	await _harness.wait_ticks(256)
	var worst := 0.0
	for bot: Character in host_bots:
		var puppet := _client.get_character(bot.net_id)
		if puppet != null and bot.is_alive():
			worst = maxf(worst, puppet.global_position.distance_to(bot.global_position))
	_check("The client's puppets of the bots are where the host's bots are (within 0.6 m: a snapshot behind)",
			worst <= 0.6, "%.2f m" % worst)
	var both_over := func() -> bool: return _host_rules.phase == RoundManager.Phase.MATCH_END and _client_rules.phase == RoundManager.Phase.MATCH_END
	var ended := await _harness.wait_until(both_over, 60000)
	_check("The match ends on both sides", ended, "host phase %d, client phase %d, rounds %d" % [_host_rules.phase, _client_rules.phase, _host_rules.round_number])
	await _harness.wait_ticks(20)
	_check("Every round ended the same way on the client (winner, reason, score)", _client_rounds == _host_rounds and not _host_rounds.is_empty(),
			"host %s, client %s" % [_host_rounds, _client_rounds])
	_check("The client's kill feed has every kill of the host's, in order (victim, killer, headshot)",
			_client_kills == _host_kills and not _host_kills.is_empty(), "host %s, client %s" % [_host_kills, _client_kills])
	_check("The match's winner and final score are the host's", _client_rules.winner == _host_rules.winner and _client_rules.score == _host_rules.score,
			"host %d %s, client %d %s" % [_host_rules.winner, _host_rules.score, _client_rules.winner, _client_rules.score])
	var same_stats := true
	for character in _host_rules.get_participants():
		var copy := _client.get_character(character.net_id)
		var a := _host_rules.get_stats(character)
		var b := _client_rules.get_stats(copy) if copy != null else null
		if b == null or a.kills != b.kills or a.deaths != b.deaths or a.assists != b.assists or absf(a.damage - b.damage) > 0.01:
			same_stats = false
	_check("The client's scoreboard has the host's kills, deaths, assists and damage", same_stats, "")
	var same_health := true
	for character in _host_rules.get_participants():
		var copy := _client.get_character(character.net_id)
		if copy == null or copy.is_alive() != character.is_alive():
			same_health = false
	_check("Who is alive is the same on both sides", same_health, "")


func _describe(rules: RoundManager) -> Array:
	return rules.get_participants().map(func(c: Character) -> Array: return [c.net_id, String(c.name), c.team, c.class_data.id])


func _stop() -> void:
	for main in [_client_main, _host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [_client_session, _host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	remove_child(_harness)
	_harness.queue_free()


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
