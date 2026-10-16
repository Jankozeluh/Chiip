extends Node
## Automated checks for players coming and going during an online match (M9, D-110). Run
## without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netjoin_test.tscn
##
## A host and a client start a bomb match on Depot through the lobby ([NetLobby], as the menu
## does, with the scene changes caught by the test); the client leaves in the middle of a round
## and a bot takes over its character (name, team, stats); another client joins the running
## match, is sent the match, loads it and takes over a bot of its team, which it then drives;
## the host ends the game and the remaining client goes back to the menu, told why. Quits with
## the number of failed checks as the exit code.

const MAP_PATH := "res://maps/depot.tscn"

var _harness: NetHarness
var _failures: int = 0
var _host_session: NetSession
var _host_main: Node
## Side name → the game started there.
var _games: Dictionary = {}
## Side name → scene paths its lobby asked for.
var _scenes: Dictionary = {}


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test()
	for side_name: String in _games:
		var main: Node = _games[side_name]
		if is_instance_valid(main):
			main.get_parent().remove_child(main)
			main.queue_free()
	remove_child(_harness)
	_harness.queue_free()
	GameLaunch.clear()
	GameLaunch.notice = ""
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
	rules.rounds_to_win = 5
	rules.freeze_time = 1.0
	rules.round_time = 60.0
	rules.round_end_time = 1.0
	return rules


## The lobby of [param session], with its scene changes caught: the game scene starts the match
## on the session's side of the harness, the menu scene is only noted.
func _lobby_of(session: NetSession, side_name: String) -> NetLobby:
	var lobby := NetLobby.of(session)
	_scenes[side_name] = []
	lobby.change_scene = func(path: String) -> void:
		(_scenes[side_name] as Array).append(path)
		if path == GameLaunch.GAME_SCENE:
			var rules := GameLaunch.match_settings
			GameLaunch.clear()
			var main := _harness.start_game(session.get_parent(), session, load(MAP_PATH), rules)
			_harness.silence(main.get_player())
			_games[side_name] = main
	return lobby


func _test() -> void:
	_host_session = _harness.start_host("Host", "Host")
	var ana := _harness.start_client("Ana", "Ana")
	await _harness.wait_until(ana.is_active)
	var host_lobby := _lobby_of(_host_session, "Host")
	_lobby_of(ana, "Ana")
	host_lobby.start_match(MAP_PATH, _rules())
	var both_in := func() -> bool:
		return _games.has("Host") and _games.has("Ana") and (_games["Host"].get_net_game() as NetHost).is_started() \
				and (_games["Ana"].get_net_game() as NetClient).is_welcomed()
	var started := await _harness.wait_until(both_in, 1200)
	_check("The lobby starts the match on both computers", started, "%s" % [_scenes])
	if not started:
		return
	_host_main = _games["Host"]
	var host := _host_main.get_net_game() as NetHost
	var rules := _host_main.get_map().get_node("RoundManager") as RoundManager
	for character in rules.get_participants():
		_harness.silence(character)
	_harness.silence_bomb(rules.bomb)
	await _harness.wait_until(func() -> bool: return rules.phase == RoundManager.Phase.LIVE, 600)

	# Ana leaves in the middle of the round: a bot takes her character over.
	var ana_peer := ana.local_peer_id
	var ana_character := host.get_character_of(ana_peer)
	var ana_id := ana_character.net_id
	var ana_stats := rules.get_stats(ana_character)
	var ana_main: Node = _games["Ana"]
	ana_main.get_parent().remove_child(ana_main)
	ana_main.queue_free()
	_games.erase("Ana")
	ana.close()
	await _harness.wait_until(func() -> bool: return ana_character.get_controller() is BotController, 2560)
	var start := ana_character.global_position
	var start_aim := ana_character.get_aim_angles()
	# The bot plays on: it moves or turns. One that took over a defender on its hold may stand
	# still until the enemy shows up, so give it up to 20 s (M16; it waited a fixed 2 s).
	var plays_on := func() -> bool:
		return (not ana_character.is_alive() or ana_character.global_position.distance_to(start) > 0.5
				or ana_character.get_aim_angles().distance_to(start_aim) > 0.05)
	await _harness.wait_until(plays_on, 2560)
	_check("A player who leaves mid-round is taken over by a bot: \"Ana (bot)\", same team, same stats, and it plays on",
			ana_character.get_controller() is BotController and String(ana_character.name) == "Ana (bot)" and not ana_character.manual
					and ana_character.team == 1 and rules.get_stats(ana_character) == ana_stats and ana_character.net_id == ana_id
					and (not ana_character.is_alive() or ana_character.global_position.distance_to(start) > 0.5
							or ana_character.get_aim_angles().distance_to(start_aim) > 0.05)
					and host.get_character_of(ana_peer) == null,
			"%s, controller %s, moved %.1f m, turned %.2f rad" % [ana_character.name, ana_character.get_controller(),
					ana_character.global_position.distance_to(start), ana_character.get_aim_angles().distance_to(start_aim)])

	# Bob joins the running match: he is sent it, loads it and takes over a bot.
	var bob := _harness.start_client("Bob", "Bob")
	_lobby_of(bob, "Bob")
	var bob_in := func() -> bool: return _games.has("Bob") and (_games["Bob"].get_net_game() as NetClient).is_welcomed()
	var joined := await _harness.wait_until(bob_in, 1200)
	_check("Someone who joins a running match is sent it at once and loads it", joined and _scenes["Bob"] == [GameLaunch.GAME_SCENE],
			"%s" % [_scenes.get("Bob")])
	if not joined:
		return
	var bob_main: Node = _games["Bob"]
	var bob_client := bob_main.get_net_game() as NetClient
	var bob_character := host.get_character_of(bob.local_peer_id)
	var bob_player: Character = bob_main.get_player()
	_check("He takes over a bot of his team: his name, a network controller, his own player on his screen",
			bob_character != null and String(bob_character.name) == "Bob" and bob_character.get_controller() is NetworkController
					and bob_character.manual and bob_character.get_node_or_null("BotController") == null
					and bob_player.net_id == bob_character.net_id and bob_player.team == bob_character.team
					and bob_client.get_character(ana_id) != null and String(bob_client.get_character(ana_id).name) == "Ana (bot)",
			"%s on team %d" % [bob_character.name if bob_character != null else "-", bob_character.team if bob_character != null else -1])
	# His commands only move a character in a live round, so measure over a window in which the round
	# stays live and he stays alive (bots fight around him, and a round can end in the middle of one;
	# a new round starts with a freeze and puts everyone back on a spawn). Try a few windows. The
	# proof is his top speed, not the distance: depending on which bot he took over, a wall or a crate
	# can stand a metre in front of him (he then stops after 1 m but was running at once), so he walks
	# where the way is longest (M16).
	var measured := false
	var moved := 0.0
	var peak_speed := 0.0
	for attempt in 6:
		await _harness.wait_until(func() -> bool: return rules.phase == RoundManager.Phase.LIVE and bob_character.is_alive(), 2560)
		var bob_start := bob_character.global_position
		var yaw := _open_yaw(bob_character)
		bob_client.command_source = func(_delta: float) -> CharacterInput:
			var command := CharacterInput.new()
			command.yaw = yaw
			command.move = Vector2(0.0, -1.0)
			return command
		var clean := true
		peak_speed = 0.0
		for tick in 128:
			await get_tree().physics_frame
			peak_speed = maxf(peak_speed, Vector2(bob_character.velocity.x, bob_character.velocity.z).length())
			if rules.phase != RoundManager.Phase.LIVE or not bob_character.is_alive():
				clean = false
		bob_client.command_source = Callable()
		moved = bob_character.global_position.distance_to(bob_start)
		if clean:
			measured = true
			break
	_check("His commands drive the character he took over (a second of walking forward in a live round gets him running above 2.5 m/s)",
			measured and peak_speed > 2.5 or not measured and not bob_character.is_alive(),
			"top speed %.2f m/s, moved %.2f m, a clean window %s" % [peak_speed, moved, measured])

	# The host ends the game: Bob goes back to the menu and is told why.
	_host_session.close()
	var back := await _harness.wait_until(func() -> bool: return (_scenes["Bob"] as Array).back() == GameLaunch.MENU_SCENE, 2560)
	_check("When the host ends the game, the clients go back to the menu with \"The host ended the game.\"",
			back and GameLaunch.notice == "The host ended the game.", "notice \"%s\"" % GameLaunch.notice)
	if is_instance_valid(bob):
		bob.close()


## The heading (yaw) from [param character] with the longest free way at waist height, of 16.
func _open_yaw(character: Character) -> float:
	var space := character.get_world_3d().direct_space_state
	var origin := character.global_position + Vector3.UP
	var best_yaw := 0.0
	var best_distance := -1.0
	for i in 16:
		var yaw := TAU * i / 16.0
		var end := origin + Vector3.FORWARD.rotated(Vector3.UP, yaw) * 10.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, PhysicsLayers.WORLD))
		var distance := 10.0 if hit.is_empty() else origin.distance_to(hit["position"])
		if distance > best_distance:
			best_distance = distance
			best_yaw = yaw
	return best_yaw


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
