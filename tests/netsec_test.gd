extends Node
## Automated checks that the host does not trust the computers that join it (M12, D-180). Run
## without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 200000 res://tests/netsec_test.tscn
##
## Source checks first: nothing in the net code decodes objects or runs text from the network, the
## engine's object decoding is off, and every RPC a client may call is guarded for the host. Then a
## host and a friend, and a friend who behaves badly: broken, cut, oversized and random packets,
## commands with angles that are not numbers or no real view, requests of the wrong type, size or
## range, session messages that are nested, huge or claim to come from someone else, a hello said
## over and over, team changes in a flood, a packet flood (the friend is removed), and a computer
## that connects and never says hello (removed after a few seconds). After each, the host must
## still run, the friend's character must still be whole, and no script error may appear in the
## output (the test runner fails a suite for one). Quits with the number of failed checks.

const MAP_PATH := "res://maps/depot.tscn"

var _harness: NetHarness
var _failures: int = 0
var _host_session: NetSession
var _host_main: Node
var _games: Dictionary = {}


func _ready() -> void:
	_test_source()
	_test_pure_functions()
	_harness = NetHarness.new()
	add_child(_harness)
	await _test_hostile_friend()
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


# --- Source and pure checks ---


func _test_source() -> void:
	var dangerous: Array[String] = ["bytes_to_var_with_objects", "str_to_var", "allow_object_decoding = true", "instance_from_id", "inst_to_dict", "dict_to_inst",
			"Expression.new", "OS.execute", "OS.shell_open", "MultiplayerSpawner", "MultiplayerSynchronizer", ".load_from_file", "ResourceLoader.load(", "load(packet", "load(data"]
	var found: Array[String] = []
	var rpc_without_guard: Array[String] = []
	var rpc_count := 0
	var any_peer_count := 0
	for file in DirAccess.get_files_at("res://net"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://net/" + file)
		for word in dangerous:
			if text.contains(word):
				found.append("%s: %s" % [file, word])
		var lines := text.split("\n")
		for index in lines.size():
			var line := lines[index]
			if line.begins_with("@rpc("):
				rpc_count += 1
				if line.begins_with('@rpc("any_peer"'):
					any_peer_count += 1
					# The function's first lines must test is_host() (only the host listens to clients).
					var body := "\n".join(lines.slice(index, mini(index + 8, lines.size())))
					if not body.contains("is_host()"):
						rpc_without_guard.append("%s line %d" % [file, index + 1])
	_check("The net code decodes no objects and runs nothing from the network: none of %d risky calls (objects in variants, str_to_var, instance ids, expressions, shell, spawners, loading by a received path) appears in net/" % dangerous.size(),
			found.is_empty(), "found: %s" % [found])
	_check("Every RPC a client may call (%d of %d are any_peer) opens with an is_host() guard; the others are authority-only (the host's)" % [any_peer_count, rpc_count],
			rpc_without_guard.is_empty() and rpc_count >= 7 and any_peer_count >= 3, "unguarded: %s" % [rpc_without_guard])


func _test_pure_functions() -> void:
	var good := NetSession.is_valid_message({"loaded": true, "n": 3, "x": 1.5, "t": "hello"})
	var bad_nested := NetSession.is_valid_message({"loaded": [1, 2]})
	var bad_dict := NetSession.is_valid_message({"loaded": {"a": 1}})
	var bad_long_text := NetSession.is_valid_message({"t": "x".repeat(NetSession.MAX_MESSAGE_TEXT_LENGTH + 1)})
	var bad_long_key := NetSession.is_valid_message({"k".repeat(NetSession.MAX_MESSAGE_KEY_LENGTH + 1): 1})
	var bad_key_type := NetSession.is_valid_message({1: true})
	var many: Dictionary = {}
	for i in NetSession.MAX_MESSAGE_ENTRIES + 1:
		many["k%d" % i] = i
	var bad_object := NetSession.is_valid_message({"o": Vector3.ONE})
	_check("A session message from a client is a few short text keys with plain values: lists, dictionaries, vectors, long texts, long keys, non-text keys and too many entries are refused",
			good and not bad_nested and not bad_dict and not bad_long_text and not bad_long_key and not bad_key_type and not NetSession.is_valid_message(many) and not bad_object,
			"good %s, nested %s, dict %s, text %s, key %s, key type %s, many %s, vector %s" % [good, bad_nested, bad_dict, bad_long_text, bad_long_key, bad_key_type, NetSession.is_valid_message(many), bad_object])
	var name_clean := NetSession._clean_name("A\nB" + String.chr(0x202E) + "C" + String.chr(0x200B) + "D\t" + "E".repeat(40))
	var plain_clean := true
	for character in name_clean:
		var code := character.unicode_at(0)
		if code < 32 or (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E):
			plain_clean = false
	_check("A name loses control characters and the invisible ones that reverse or hide text, and is cut to %d characters" % NetSession.MAX_NAME_LENGTH,
			plain_clean and name_clean.length() <= NetSession.MAX_NAME_LENGTH and not name_clean.is_empty() and NetSession._clean_name("\n\n") == "Player",
			"'%s'" % name_clean.c_escape())
	# Commands: angles that are not numbers or no real view are dropped, a slot that doesn't exist means "no change".
	var commands: Array[CharacterInput] = []
	for tick in 6:
		var command := CharacterInput.new()
		command.tick = tick + 1
		command.yaw = [0.5, INF, 1.0e30, 0.5, 0.5, NAN][tick]
		command.pitch = [0.1, 0.1, 0.1, 9.0, 0.1, 0.1][tick]
		command.weapon_slot = [-1, -1, -1, -1, 100, -1][tick]
		commands.append(command)
	var packet := NetProtocol.pack_commands(commands)
	var unpacked := NetProtocol.unpack_commands(packet)
	var ticks: Array[int] = []
	for command in unpacked:
		ticks.append(command.tick)
	_check("Of six commands with an angle that is infinite, huge, past looking straight down or not a number, only the sane ones (ticks 1 and 5) survive, and the impossible weapon slot becomes \"no change\"",
			ticks == [1, 5] and unpacked.size() == 2 and unpacked[1].weapon_slot == -1, "ticks %s" % [ticks])
	_check("Cut or empty command packets give no commands; a packet saying 255 commands but holding none gives none",
			NetProtocol.unpack_commands(PackedByteArray()).is_empty() and NetProtocol.unpack_commands(PackedByteArray([NetProtocol.Message.COMMANDS])).is_empty()
					and NetProtocol.unpack_commands(PackedByteArray([NetProtocol.Message.COMMANDS, 255, 1, 2, 3])).is_empty()
					and NetProtocol.unpack_values(PackedByteArray([NetProtocol.Message.REQUEST, 1, 2, 3, 4, 5])).is_empty(),
			"")


# --- A host and a friend who behaves badly ---


func _rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.team_size = 2
	rules.enemy_team_size = 2
	rules.rounds_to_win = 5
	rules.freeze_time = 1.0
	rules.round_time = 120.0
	rules.round_end_time = 1.0
	return rules


## Makes [param session]'s lobby start the game on its own side when the host starts the match.
func _lobby_of(session: NetSession, side_name: String) -> NetLobby:
	var lobby := NetLobby.of(session)
	lobby.change_scene = func(path: String) -> void:
		if path == GameLaunch.GAME_SCENE:
			var rules := GameLaunch.match_settings
			GameLaunch.clear()
			var main := _harness.start_game(session.get_parent(), session, load(MAP_PATH), rules)
			_harness.silence(main.get_player())
			_games[side_name] = main
	return lobby


func _sane(character: Character) -> bool:
	var position := character.global_position
	return is_instance_valid(character) and is_finite(position.x) and is_finite(position.y) and is_finite(position.z) \
			and is_finite(character.rotation.y) and is_finite(character.head.rotation.x) and absf(position.y) < 100.0 and character.health <= 100.0


func _test_hostile_friend() -> void:
	_host_session = _harness.start_host("Host", "Host")
	var ana := _harness.start_client("Ana", "Ana")
	await _harness.wait_until(ana.is_active)
	var ana_id := ana.local_peer_id
	var seen_messages: Array = []
	_host_session.match_message.connect(func(data: Dictionary) -> void: seen_messages.append(data))
	var roster_changes: Array[int] = [0]
	_host_session.roster_changed.connect(func() -> void: roster_changes[0] += 1)
	_check("The engine's object decoding is off on the host and on the friend (a received variant can never become an object)",
			not (_host_session.multiplayer as SceneMultiplayer).allow_object_decoding and not (ana.multiplayer as SceneMultiplayer).allow_object_decoding, "")

	# Session messages and requests at the lobby, before any match.
	var players_before := _host_session.get_players().size()
	for i in 10:
		ana._rpc_hello.rpc_id(1, "Ana", NetProtocol.VERSION)
	await _harness.wait_ticks(8)
	_check("Saying hello again and again changes nothing: still the same %d players" % players_before, _host_session.get_players().size() == players_before, "%d players" % _host_session.get_players().size())
	ana._rpc_message_to_host.rpc_id(1, {"loaded": [1, 2, 3]})
	ana._rpc_message_to_host.rpc_id(1, {"loaded": {"deep": {"er": 1}}})
	ana._rpc_message_to_host.rpc_id(1, {"t": "x".repeat(5000)})
	ana._rpc_message_to_host.rpc_id(1, {"note": "fine", "from": 1})
	await _harness.wait_ticks(8)
	_check("Of four messages (a list, a nested dictionary, a 5,000-character text, and a good one claiming to be from the host) only the good one arrives, and it comes from the friend's own id, not from 1",
			seen_messages.size() == 1 and seen_messages[0].get("note", "") == "fine" and seen_messages[0].get("from", 0) == ana_id,
			"%d messages: %s" % [seen_messages.size(), seen_messages])
	seen_messages.clear()
	for i in 60:
		ana._rpc_message_to_host.rpc_id(1, {"note": i})
	await _harness.wait_ticks(8)
	_check("A flood of 60 messages in one go delivers at most %d (the limit for a second)" % NetSession.MAX_MESSAGES_PER_SECOND,
			seen_messages.size() <= NetSession.MAX_MESSAGES_PER_SECOND and seen_messages.size() >= 1, "%d delivered" % seen_messages.size())
	await _harness.wait_ticks(140)
	roster_changes[0] = 0
	for i in 40:
		ana._rpc_request_team.rpc_id(1, i % 2)
	await _harness.wait_ticks(8)
	_check("40 team requests, back and forth, in one go change the team at most %d times (and so send the roster to everyone at most that often)" % NetSession.MAX_TEAM_REQUESTS_PER_SECOND,
			roster_changes[0] <= NetSession.MAX_TEAM_REQUESTS_PER_SECOND, "%d roster changes" % roster_changes[0])
	ana._rpc_request_team.rpc_id(1, 99)
	ana._rpc_request_team.rpc_id(1, -5)
	await _harness.wait_ticks(8)
	_check("A team that doesn't exist (99, -5) changes nothing: the friend is still on team 0 or 1",
			_host_session.get_player(ana_id).get("team", -1) in [0, 1], "team %s" % _host_session.get_player(ana_id).get("team"))

	# Chat from a hostile friend, straight at the host's door (the session message, below the chat box): what is not
	# text, is too long, is empty or is only spaces never becomes a line; markup, direction marks and control
	# characters come out plain; the name and the sender are the roster's, whatever the message says.
	var host_chat := NetChat.of(_host_session)
	var chat_before := host_chat.lines.size()
	var hostile_chat: Array = [
		{"chat": [1, 2, 3]}, {"chat": {"a": 1}}, {"chat": 12345}, {"chat": "x".repeat(5000)}, {"chat": ""}, {"chat": "     "},
		{"chat": "[b]bold[/b] [url=javascript:alert(1)]click[/url] [img]res://icon.svg[/img] [color=red]red"},
		{"chat": "evil" + String.chr(0x202E) + "txet" + String.chr(0) + "\n\t   zero" + String.chr(0x200B) + "width"},
		{"chat": "an honest line", "from": 1, "name": "Host"},
	]
	for payload: Dictionary in hostile_chat:
		ana._rpc_message_to_host.rpc_id(1, payload)
		# One line a window, so the rate limit (3 in 5 s) isn't what this check is about.
		await _harness.wait_ticks(int(NetChat.RATE_WINDOW * Engine.physics_ticks_per_second / 2.0) + 4)
	var chat_lines := host_chat.lines.slice(chat_before)
	var chat_plain := true
	var chat_roster := true
	for line in chat_lines:
		var text: String = line["text"]
		if text.length() > NetChat.MAX_CHAT_LENGTH or text != text.strip_edges():
			chat_plain = false
		for character in text:
			var code := character.unicode_at(0)
			if code < 32 or (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E):
				chat_plain = false
		if line["peer_id"] != ana_id or line["name"] != "Ana":
			chat_roster = false
	_check("Nine hostile chat messages (a list, a dictionary, a number, 5,000 characters, empty, only spaces, BBCode with a javascript link, direction and control characters, and a line claiming to be the host's) give exactly the three that are text: plain, at most %d characters, and from the friend's own id and roster name" % NetChat.MAX_CHAT_LENGTH,
			chat_lines.size() == 3 and chat_plain and chat_roster and String(chat_lines[0]["text"]).contains("[b]bold[/b]") and String(chat_lines[2]["text"]) == "an honest line",
			"%d lines: %s" % [chat_lines.size(), chat_lines.map(func(line: Dictionary) -> String: return "%s: %s" % [line["name"], line["text"]])])

	# The match.
	var host_lobby := _lobby_of(_host_session, "Host")
	_lobby_of(ana, "Ana")
	host_lobby.start_match(MAP_PATH, _rules())
	var both_in := func() -> bool:
		return _games.has("Host") and _games.has("Ana") and (_games["Host"].get_net_game() as NetHost).is_started() \
				and (_games["Ana"].get_net_game() as NetClient).is_welcomed()
	var started := await _harness.wait_until(both_in, 1600)
	_check("The match starts on both computers", started, "games %s" % [_games.keys()])
	if not started:
		return
	_host_main = _games["Host"]
	var host := _host_main.get_net_game() as NetHost
	var rules := _host_main.get_map().get_node("RoundManager") as RoundManager
	for character in rules.get_participants():
		_harness.silence(character)
	_harness.silence_bomb(rules.bomb)
	await _harness.wait_until(func() -> bool: return rules.phase == RoundManager.Phase.LIVE, 800)
	var ana_character := host.get_character_of(ana_id)
	var money_before := rules.get_money(ana_character) if rules.has_method("get_money") else 0
	var participants_before := rules.get_participants().size()
	var received: Array[int] = [0]
	var too_big_received: Array[int] = [0]
	_host_session.packet_received.connect(func(_peer: int, packet: PackedByteArray) -> void:
		received[0] += 1
		if packet.size() > NetSession.MAX_PACKET_BYTES_FROM_CLIENT:
			too_big_received[0] += 1)

	# Garbage packets, one kind after the other.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016
	var garbage: Array[PackedByteArray] = []
	garbage.append(PackedByteArray([1]))
	garbage.append(PackedByteArray([NetProtocol.Message.COMMANDS]))
	garbage.append(PackedByteArray([NetProtocol.Message.COMMANDS, 255]))
	garbage.append(PackedByteArray([NetProtocol.Message.REQUEST, 0, 0, 0, 0, 0, 0, 0, 0]))
	garbage.append(PackedByteArray([255, 255, 255, 255]))
	for length in [3, 17, 100, 1000, 5000, 9000, 40000]:
		var random := PackedByteArray()
		for i in length:
			random.append(rng.randi() % 256)
		garbage.append(random)
		# The same bytes behind each known message type.
		for type in [NetProtocol.Message.COMMANDS, NetProtocol.Message.REQUEST, NetProtocol.Message.EVENT]:
			var typed := PackedByteArray([type])
			typed.append_array(random)
			garbage.append(typed)
	# Commands with every kind of bad angle, in a well-formed packet.
	for bad in [NAN, INF, -INF, 1.0e30, -1.0e30, 100.0]:
		var command := CharacterInput.new()
		command.tick = 1000000
		command.yaw = bad
		command.pitch = bad
		command.view_tick = bad
		command.weapon_slot = 99
		garbage.append(NetProtocol.pack_commands([command]))
	# Requests of the wrong shape, type, size and range.
	var requests: Array = [
		[], [NetProtocol.Request.CLASS], [NetProtocol.Request.CLASS, 9999], [NetProtocol.Request.CLASS, -3], [NetProtocol.Request.CLASS, "x"],
		[NetProtocol.Request.CLASS, [1, 2]], [NetProtocol.Request.CLASS, {"a": 1}], [NetProtocol.Request.BUY], [NetProtocol.Request.BUY, 12345],
		[NetProtocol.Request.BUY, "x".repeat(3000)], [NetProtocol.Request.BUY, "not_an_item"], [NetProtocol.Request.BUY, [1]],
		[[1, 2], 3], [{"a": 1}], ["text"], [NAN], [7777, 1], [-1, 1], [NetProtocol.Request.BUY, "rifle", "extra", "more"],
		[NetProtocol.Request.SKIP_KILLCAM, [1]], [NetProtocol.Request.SKIP_KILLCAM, "x", "y"], [NetProtocol.Request.SKIP_KILLCAM, {"a": 1}],
	]
	# A skip request in a flood (the killcam only ever needs one): the request limit takes it.
	for i in 60:
		requests.append([NetProtocol.Request.SKIP_KILLCAM])
	for values in requests:
		garbage.append(NetProtocol.pack_values(NetProtocol.Message.REQUEST, values))
	# Bytes that decode to something odd as a variant: a deeply nested array, a huge claimed length.
	var nested: Variant = []
	for i in 200:
		nested = [nested]
	garbage.append(NetProtocol.pack_values(NetProtocol.Message.REQUEST, [NetProtocol.Request.BUY, nested]))
	var claims := PackedByteArray([NetProtocol.Message.REQUEST, 28, 0, 0, 0, 255, 255, 255, 127])
	garbage.append(claims)
	var too_big_sent := 0
	for packet in garbage:
		ana.send_packet(1, packet, packet.size() > 0 and packet[0] == NetProtocol.Message.REQUEST)
		if packet.size() > NetSession.MAX_PACKET_BYTES_FROM_CLIENT:
			too_big_sent += 1
		await _harness.wait_ticks(1)
	await _harness.wait_ticks(40)
	_check("%d broken, cut, random, oversized and hostile packets later (commands with angles that are NaN, infinite or huge, requests of the wrong type, size or range, a 200-deep nested list): the host still runs, the round goes on, nobody was added, the friend's character is whole and his money is as it was"
			% garbage.size(),
			_host_session.is_active() and rules.phase != RoundManager.Phase.MATCH_END and rules.get_participants().size() == participants_before
					and _sane(ana_character) and _sane(_host_main.get_player())
					and (not rules.has_method("get_money") or rules.get_money(ana_character) == money_before),
			"active %s, phase %s, %d participants (was %d), money %s (was %s)" % [_host_session.is_active(), rules.phase, rules.get_participants().size(), participants_before,
					rules.get_money(ana_character) if rules.has_method("get_money") else "n/a", money_before])
	_check("The packets that were too big (over %d bytes; %d were sent) never reached the game" % [NetSession.MAX_PACKET_BYTES_FROM_CLIENT, too_big_sent],
			too_big_sent >= 1 and too_big_received[0] == 0, "%d too big handed on, %d packets handed on in all (the friend's real commands included)" % [too_big_received[0], received[0]])
	for character in rules.get_participants():
		if not _sane(character):
			_check("Every character is still whole", false, "%s at %s" % [character.name, character.global_position])
			return

	# A computer that connects and never says hello.
	var ghost_side := _harness.add_side("Ghost")
	var ghost := _harness.open_session(ghost_side)
	ghost.multiplayer.connected_to_server.disconnect(ghost._on_connected_to_server)
	ghost.join_game("127.0.0.1", "Ghost", _harness.port)
	var peers_with_ghost := await _harness.wait_until(func() -> bool: return _host_session.multiplayer.get_peers().size() >= 2, 400)
	var ghost_players := _host_session.get_players().size()
	await _harness.wait_ticks(int(NetSession.HELLO_TIMEOUT * Engine.physics_ticks_per_second) + 80)
	_check("A computer that connects but never says hello takes no player's place and is removed after %.0f seconds" % NetSession.HELLO_TIMEOUT,
			peers_with_ghost and ghost_players == _host_session.get_players().size() and _host_session.multiplayer.get_peers().size() == 1 and not is_instance_valid(ghost) or not ghost.is_active(),
			"peers %d, players %d" % [_host_session.multiplayer.get_peers().size(), _host_session.get_players().size()])
	if is_instance_valid(ghost):
		ghost.close()

	# A flood: more than the limit every tick for several seconds, and the friend is removed.
	received[0] = 0
	var flood_packet := PackedByteArray([NetProtocol.Message.COMMANDS, 0])
	var flooding := true
	var ticks_flooded := 0
	while flooding and ticks_flooded < 128 * 8:
		for i in 450:
			ana.send_packet(1, flood_packet, false)
		await _harness.wait_ticks(1)
		ticks_flooded += 1
		flooding = not _host_session.get_player(ana_id).is_empty()
	var handed_on := received[0]
	_check("A flood of 450 packets every tick: the friend is removed after about %d seconds (%.1f s here) and the host handed on far fewer than were sent (%d of %d)" % [
			NetSession.FLOOD_SECONDS_TO_KICK, ticks_flooded / 128.0, handed_on, ticks_flooded * 450],
			_host_session.get_player(ana_id).is_empty() and ticks_flooded >= 128 * (NetSession.FLOOD_SECONDS_TO_KICK - 1) and handed_on < ticks_flooded * 450 / 2,
			"removed %s after %d ticks, %d handed on of %d" % [_host_session.get_player(ana_id).is_empty(), ticks_flooded, handed_on, ticks_flooded * 450])
	await _harness.wait_ticks(40)
	_check("The host, alone again, still runs the match: a bot took over the removed friend's character, and the host's own is whole",
			_host_session.is_active() and rules.get_participants().size() == participants_before and ana_character.get_controller() is BotController
					and _sane(_host_main.get_player()),
			"active %s, %d participants, controller %s" % [_host_session.is_active(), rules.get_participants().size(), ana_character.get_controller()])


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  %s: %s" % [description, detail])
	else:
		print("FAIL  %s: %s" % [description, detail])
		_failures += 1
