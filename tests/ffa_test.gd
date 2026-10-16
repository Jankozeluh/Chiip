extends Node
## Automated checks for the free-for-all deathmatch (M17, D-240). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/ffa_test.tscn
##
## Offline on Square: everyone is an enemy, also a character with your team number (damage, a bot's eyes,
## the colours in both schemes); the start spreads everyone out and a respawn comes far from everyone; a
## kill is a point for the killer alone and the first to the kill limit wins alone; the time limit, and
## overtime on a tie at the top; a bots-only match where the bots fight and each hunts alone. Online (in
## this process, [NetHarness]): the client's replica is free-for-all too, and every kill, the standings and
## the winner are the same on both. Quits with the number of failed checks as the exit code.

const MAP_SCENE := preload("res://maps/square.tscn")
const KILL_LIMIT := 4
const TIME_LIMIT := 12.0
const RESPAWN_DELAY := 1.0

var _map: Node3D
var _rounds: FreeForAllMatch
var _player: Character
var _failures: int = 0
var _results: Array = []


func _ready() -> void:
	Weapon.silent = true
	await _test_everyone_an_enemy()
	await _test_spread_out()
	await _test_kill_limit()
	await _test_time_limit()
	await _test_overtime()
	await _test_bots_fight()
	_free_match()
	await _test_online()
	Weapon.silent = false
	Teams.free_for_all = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Offline ---


func _test_everyone_an_enemy() -> void:
	await _new_match()
	await _go_live()
	var mate: Character = null
	for member in _rounds.get_participants():
		if member != _player and member.team == _player.team:
			mate = member
			break
	_check("Free-for-all: the rules say so, and nobody is anybody's ally (also with your team number)",
			_rounds.is_free_for_all() and Teams.free_for_all and mate != null and not Teams.are_allies(mate, _player)
			and Teams.are_allies(_player, _player) and Teams.damage_factor(mate, _player) == 1.0,
			"rules %s, flag %s, a bot on your team number %s" % [_rounds.is_free_for_all(), Teams.free_for_all, mate != null])
	if mate == null:
		return
	var before := mate.health
	mate.take_damage(30.0, Hitbox.Zone.CHEST, _player)
	_check("Your shots hurt a character with your team number", mate.health < before, "health %.0f → %.0f" % [before, mate.health])

	# A bot sees another with its own team number as an enemy.
	var watcher: Character = null
	for member in _rounds.get_members(mate.team):
		if member != mate and member != _player:
			watcher = member
	var seen := false
	if watcher != null:
		var aim := watcher.get_aim_angles()
		var forward := -Basis.from_euler(Vector3(0.0, aim.x, 0.0)).z
		var navigation_map := _map.get_world_3d().navigation_map
		var spot := NavigationServer3D.map_get_closest_point(navigation_map, watcher.global_position + forward * 5.0)
		await _teleport(mate, spot)
		var senses := watcher.get_node("BotSenses") as BotSenses
		seen = senses.can_see(mate)
	_check("A bot sees a character with its own team number as an enemy", seen, "watcher %s" % [watcher != null])

	# Colours: you in your colour, everyone else in the enemy colour, in both schemes.
	var colours := func() -> bool:
		for member in _rounds.get_participants():
			var want := Teams.friendly_color() if member == _player else Teams.enemy_color()
			if not member.body.get_team_color().is_equal_approx(want):
				return false
		return true
	var standard: bool = colours.call()
	Teams.set_color_scheme(Teams.ColorScheme.COLORBLIND)
	var colorblind: bool = colours.call()
	Teams.set_color_scheme(Teams.ColorScheme.STANDARD)
	_check("Everyone else wears the enemy colour (also in the colour-blind scheme), you your own",
			standard and colorblind and Teams.ui_color_of(mate) == Teams.scheme_color(&"enemy_text"),
			"standard %s, colour-blind %s" % [standard, colorblind])


func _test_spread_out() -> void:
	await _new_match()
	var closest := _closest_pair()
	_check("The start spreads everyone over the respawn points (no team ends)", closest >= 6.0, "closest two %.1f m apart" % closest)
	await _go_live()
	var victim := _rounds.get_participants()[1]
	victim.take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_seconds(RESPAWN_DELAY + 0.3)
	var nearest := INF
	for other in _rounds.get_participants():
		if other != victim and other.is_alive():
			nearest = minf(nearest, _flat(other.global_position, victim.global_position))
	_check("A respawn comes far from everyone", victim.is_alive() and nearest >= 10.0, "alive %s, nearest %.1f m" % [victim.is_alive(), nearest])


func _test_kill_limit() -> void:
	await _new_match()
	await _go_live()
	var victims := _rounds.get_participants().filter(func(member: Character) -> bool: return member != _player)
	var counted := true
	for i in KILL_LIMIT:
		victims[i % victims.size()].take_damage(500.0, Hitbox.Zone.CHEST, _player)
		await _wait_ticks(2)
		counted = counted and _rounds.get_kills(_player) == i + 1
		await _wait_seconds(RESPAWN_DELAY + 0.2 if i < KILL_LIMIT - 1 else 0.1)
	_check("Every kill is a point for the killer alone, also the kill of a character with your team number",
			counted and _rounds.score == [0, 0] and _rounds.get_leader() == _player,
			"your kills %d, team score %s" % [_rounds.get_kills(_player), _rounds.score])
	_check("The first to the kill limit ends the match", _results == [[_player.team, RoundManager.EndReason.KILL_LIMIT]],
			"results %s" % [_results])
	await _wait_seconds(1.2)
	_check("After the round-end pause the match is over, and you are its winner",
			_rounds.phase == RoundManager.Phase.MATCH_END and _rounds.get_winner() == _player and _rounds.get_standings()[0] == _player,
			"phase %s, winner %s" % [RoundManager.Phase.keys()[_rounds.phase], _rounds.get_winner().name if _rounds.get_winner() != null else "none"])


func _test_time_limit() -> void:
	await _new_match()
	await _go_live()
	var bots := _rounds.get_participants().filter(func(member: Character) -> bool: return member != _player)
	bots[1].take_damage(500.0, Hitbox.Zone.CHEST, bots[0])
	await _wait_seconds(TIME_LIMIT + 1.5)
	_check("When time runs out, the one with the most kills wins", _rounds.phase == RoundManager.Phase.MATCH_END
			and _results.size() == 1 and _results[0][1] == RoundManager.EndReason.TIME_LIMIT and _rounds.get_winner() == bots[0],
			"results %s, winner %s" % [_results, _rounds.get_winner().name if _rounds.get_winner() != null else "none"])


func _test_overtime() -> void:
	await _new_match()
	await _go_live()
	var bots := _rounds.get_participants().filter(func(member: Character) -> bool: return member != _player)
	# Two at the top with a kill each: a tie.
	bots[2].take_damage(500.0, Hitbox.Zone.CHEST, bots[0])
	bots[3].take_damage(500.0, Hitbox.Zone.CHEST, bots[1])
	await _wait_seconds(TIME_LIMIT + 0.3)
	var tied := _rounds.overtime and _rounds.phase == RoundManager.Phase.LIVE and _results.is_empty()
	# A kill by someone else (one kill, not at the top) doesn't break the tie...
	bots[0].take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await _wait_ticks(4)
	var still := _rounds.phase == RoundManager.Phase.LIVE and _results.is_empty()
	# ...a second kill by one of the leaders does.
	bots[2].take_damage(500.0, Hitbox.Zone.CHEST, bots[1])
	await _wait_ticks(4)
	_check("A tie at the top goes to overtime; the kill that leaves one player alone at the top wins it",
			tied and still and _results.size() == 1 and _results[0][1] == RoundManager.EndReason.TIME_LIMIT and _rounds.get_leader() == bots[1],
			"overtime %s, still live after a kill below the top %s, results %s" % [tied, still, _results])


func _test_bots_fight() -> void:
	await _new_match(false)
	_rounds.settings.kill_limit = 100
	_rounds.settings.time_limit = 120.0
	await _go_live(false)
	var plans := {}
	for member in _rounds.get_participants():
		plans[_rounds._hunt_plan_for(member)] = true
	var alone := plans.size() == _rounds.get_participants().size()
	var same_team_kills := [0]
	_rounds.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		if killer != null and killer != victim and killer.team == victim.team:
			same_team_kills[0] += 1)
	await _wait_seconds(60.0)
	var kills := 0
	for member in _rounds.get_participants():
		kills += _rounds.get_kills(member)
	_check("Bots-only: each bot hunts alone and they fight each other (bots with the same team number too)",
			alone and kills >= 6 and same_team_kills[0] >= 1,
			"own plans %s, %d kills in 60 s, %d between bots with the same team number" % [alone, kills, same_team_kills[0]])


# --- Online ---


func _test_online() -> void:
	var harness := NetHarness.new()
	add_child(harness)
	var host_session := harness.start_host("Host", "Host")
	var client_session := harness.start_client("Client", "Jan")
	await harness.wait_until(client_session.is_active)
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.FREE_FOR_ALL
	rules.team_size = 3
	rules.enemy_team_size = 3
	rules.kill_limit = 6
	rules.time_limit = 180.0
	rules.freeze_time = 1.0
	rules.round_end_time = 1.0
	rules.respawn_delay = 1.0
	var host_main := harness.start_game(host_session.get_parent(), host_session, MAP_SCENE, rules)
	var client_main := harness.start_game(client_session.get_parent(), client_session, MAP_SCENE, rules)
	var host := host_main.get_net_game() as NetHost
	var client := client_main.get_net_game() as NetClient
	var both := func() -> bool: return host.is_started() and client.is_welcomed()
	var started := await harness.wait_until(both, 1200)
	var host_rules := host.rules as FreeForAllMatch
	var client_rules := client.rules as FreeForAllMatch
	_check("Online free-for-all: the client's replica is free-for-all too", started and host_rules != null and client_rules != null,
			"started %s, host %s, client %s" % [started, host.rules, client.rules])
	if host_rules == null or client_rules == null:
		await _close_online(harness, host_main, client_main, host_session, client_session)
		return
	for character in host_rules.get_participants():
		NetHarness.silence(character)
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = character.net_id * 7
	var host_kills: Array = []
	var client_kills: Array = []
	host_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		host_kills.append([victim.net_id, killer.net_id if killer != null else 0]))
	client_rules.character_killed.connect(func(victim: Character, killer: Character, _headshot: bool) -> void:
		client_kills.append([victim.net_id, killer.net_id if killer != null else 0]))
	var over := func() -> bool:
		return host_rules.phase == RoundManager.Phase.MATCH_END and client_rules.phase == RoundManager.Phase.MATCH_END
	var ended := await harness.wait_until(over, 128 * 180)
	await harness.wait_ticks(64)
	var host_order: Array = host_rules.get_standings().map(func(character: Character) -> Array: return [character.net_id, host_rules.get_kills(character)])
	var client_order: Array = client_rules.get_standings().map(func(character: Character) -> Array: return [character.net_id, client_rules.get_kills(character)])
	var host_winner := host_rules.get_winner()
	var client_winner := client_rules.get_winner()
	_check("Online: the match ends on both with the same winner, first to the kill limit",
			ended and host_winner != null and client_winner != null and host_winner.net_id == client_winner.net_id
			and host_rules.get_kills(host_winner) >= rules.kill_limit,
			"ended %s, host winner %s, client winner %s" % [ended, host_winner.net_id if host_winner != null else -1, client_winner.net_id if client_winner != null else -1])
	_check("Online: every kill and the standings are the same on the client", client_kills == host_kills and client_order == host_order,
			"host %s / %s, client %s / %s" % [host_kills.size(), host_order, client_kills.size(), client_order])
	await _close_online(harness, host_main, client_main, host_session, client_session)


func _close_online(harness: NetHarness, host_main: Node, client_main: Node, host_session: NetSession, client_session: NetSession) -> void:
	for main in [client_main, host_main]:
		if main != null and is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	for session in [client_session, host_session]:
		if session != null and is_instance_valid(session):
			session.close()
	for i in 40:
		await get_tree().physics_frame
	remove_child(harness)
	harness.queue_free()
	for i in 5:
		await get_tree().physics_frame


# --- Helpers ---


## A fresh free-for-all on Square: you and five bots (team sizes 3 and 3), the short test rules.
## Without [param with_player] the map's Player is removed (bots only).
func _new_match(with_player: bool = true) -> void:
	_free_match()
	_results.clear()
	_map = MAP_SCENE.instantiate()
	_player = _map.get_node("Player")
	if not with_player:
		_player.free()
		_player = null
	add_child(_map)
	await _wait_ticks(30)
	var settings := MatchSettings.new()
	settings.game_mode = MatchSettings.GameMode.FREE_FOR_ALL
	settings.team_size = 3
	settings.enemy_team_size = 3
	settings.freeze_time = 0.5
	settings.round_end_time = 1.0
	settings.kill_limit = KILL_LIMIT
	settings.time_limit = TIME_LIMIT
	settings.respawn_delay = RESPAWN_DELAY
	settings.bots_buy = false
	_rounds = FreeForAllMatch.new()
	_rounds.settings = settings
	_rounds.rng.seed = 7
	_rounds.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void: _results.append([winner, reason]))
	_map.add_child(_rounds)
	await _wait_ticks(2)
	var participants := _rounds.get_participants()
	for i in participants.size():
		participants[i].footstep_sound = null
		var brain := participants[i].get_node_or_null("BotController") as BotController
		if brain != null:
			brain.rng.seed = i + 1
			participants[i].weapon.rng.seed = i + 1
	if _player != null:
		Teams.set_viewer(_player)
	await _wait_ticks(2)


func _free_match() -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


## Waits for the live phase, then (with [param freeze_bots]) freezes every bot, so none of them moves or shoots.
func _go_live(freeze_bots: bool = true) -> void:
	var ticks := 0
	while _rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	if freeze_bots:
		for member in _rounds.get_participants():
			if member != _player:
				member.frozen = true
	await _wait_ticks(2)


func _closest_pair() -> float:
	var closest := INF
	var everyone := _rounds.get_participants()
	for i in everyone.size():
		for j in range(i + 1, everyone.size()):
			closest = minf(closest, _flat(everyone[i].global_position, everyone[j].global_position))
	return closest


func _teleport(character: Character, at: Vector3) -> void:
	character.respawn(at, character.rotation.y)
	await _wait_ticks(3)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _wait_seconds(seconds: float) -> void:
	await _wait_ticks(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", check_name, "  (", detail, ")")
	else:
		_failures += 1
		print("FAIL  ", check_name, "  (", detail, ")")
