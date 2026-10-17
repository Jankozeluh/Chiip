extends Node
## Automated checks for the text chat (M17, D-243). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/chat_test.tscn
##
## A host and a client in this process ([NetHarness]): the host decides every line (the sender's name from
## its roster, plain text, at most 100 characters, 3 lines per 5 s with a private "slow down" notice), a
## client's claims about who it is are ignored, and a client takes lines from the host alone. The lobby page's
## chat box shows and sends lines; in a match the HUD's feed shows them and its input (Enter) registers as a
## menu, sends and cancels. Quits with the number of failed checks as the exit code.

const LOBBY_SCENE := preload("res://ui/lobby_menu.tscn")
const MAP := preload("res://maps/square.tscn")

var _harness: NetHarness
var _failures: int = 0


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test_host_rules()
	await _test_lobby_box()
	await _test_match_hud()
	remove_child(_harness)
	_harness.queue_free()
	for i in 5:
		await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _test_host_rules() -> void:
	var host := _harness.start_host("RulesHost", "Host")
	var client := _harness.start_client("RulesClient", "Jan")
	await _harness.wait_until(client.is_active)
	var host_chat := NetChat.of(host)
	var client_chat := NetChat.of(client)
	var client_id := client.local_peer_id
	var client_notices: Array[String] = []
	var host_notices: Array[String] = []
	client_chat.notice.connect(func(text: String) -> void: client_notices.append(text))
	host_chat.notice.connect(func(text: String) -> void: host_notices.append(text))

	client_chat.send("hello there")
	var arrived := await _harness.wait_until(func() -> bool: return client_chat.lines.size() == 1 and host_chat.lines.size() == 1, 256)
	_check("A client's line reaches everyone, named by the host's roster", arrived and _last(host_chat) == [client_id, "Jan", "hello there"]
			and _last(client_chat) == [client_id, "Jan", "hello there"], "host %s, client %s" % [_last(host_chat), _last(client_chat)])

	host_chat.send("hi Jan")
	arrived = await _harness.wait_until(func() -> bool: return client_chat.lines.size() == 2, 256)
	_check("The host's own line reaches everyone too", arrived and _last(client_chat) == [1, "Host", "hi Jan"] and _last(host_chat) == [1, "Host", "hi Jan"],
			"client %s" % [_last(client_chat)])

	# Wait out the rate window before the cleaning checks (each sends a line).
	await _harness.wait_ticks(128 * 6)
	client_chat.send("    \t  ")
	client_chat.send("a\u0007b\nc   d  [b]x[/b]")
	client_chat.send("x".repeat(150))
	arrived = await _harness.wait_until(func() -> bool: return host_chat.lines.size() == 4, 256)
	await _harness.wait_ticks(20)
	var texts := host_chat.lines.slice(2).map(func(line: Dictionary) -> String: return line["text"])
	_check("The host makes lines plain: an empty one is dropped, control characters go, markup is just characters, 150 characters are cut to 100",
			arrived and texts == ["a b c d [b]x[/b]", "x".repeat(100)] and client_chat.lines.size() == 4,
			"lines %s" % [texts])

	# Rate: three in five seconds, the fourth refused with a notice to the sender alone.
	await _harness.wait_ticks(128 * 6)
	client_notices.clear()
	for i in 4:
		client_chat.send("spam %d" % i)
	await _harness.wait_ticks(64)
	var spam := host_chat.lines.filter(func(line: Dictionary) -> bool: return String(line["text"]).begins_with("spam"))
	_check("At most 3 lines in 5 seconds: the 4th is refused, and only its sender is told",
			spam.size() == 3 and client_notices == [NetChat.SLOW_DOWN_TEXT] and host_notices.is_empty(),
			"%d let through, client notices %s, host notices %s" % [spam.size(), client_notices, host_notices])
	await _harness.wait_ticks(128 * 5 + 32)
	client_chat.send("spam again")
	arrived = await _harness.wait_until(func() -> bool: return _last(host_chat)[2] == "spam again", 256)
	_check("After the window the sender may talk again", arrived, "last %s" % [_last(host_chat)])

	# A client claiming to be someone else: the host names it from its roster.
	client.send_to_host({"chat": "I am the host", "from": 1, "name": "Host"})
	arrived = await _harness.wait_until(func() -> bool: return _last(host_chat)[2] == "I am the host", 256)
	_check("A client's \"from\" and \"name\" are ignored", arrived and _last(host_chat) == [client_id, "Jan", "I am the host"],
			"last %s" % [_last(host_chat)])

	# A client takes lines from the host alone (another peer can't reach it through the session, but check the rule).
	var before := client_chat.lines.size()
	client.match_message_sender = 7
	client_chat._on_match_message({"chat": "fake", "from": 1, "name": "Host"})
	_check("A client ignores a chat line that doesn't come from the host", client_chat.lines.size() == before, "%d lines" % client_chat.lines.size())

	client.close()
	host.close()
	await _harness.wait_ticks(40)


func _test_lobby_box() -> void:
	var host := _harness.start_host("LobbyHost", "Host")
	NetLobby.of(host).change_scene = func(_path: String) -> void: pass
	var settings := Settings.new()
	settings.online_name = "Jan"
	settings.online_address = "127.0.0.1"
	settings.online_port = _harness.port
	var lobby := LOBBY_SCENE.instantiate() as LobbyMenu
	lobby.settings = settings
	add_child(lobby)
	lobby.set_ui_scale(1.0)
	await get_tree().process_frame
	lobby.open()
	lobby.join_game()
	var joined := await _harness.wait_until(func() -> bool: return lobby.get_session() != null and lobby.get_session().is_active() and lobby.get_chat_box().visible, 512)
	var session := lobby.get_session()
	NetChat.of(host).send("welcome")
	var shown := await _harness.wait_until(func() -> bool: return lobby.get_chat_texts().has("Host: welcome"), 256)
	_check("The lobby page shows the chat box and the lines said", joined and shown, "joined %s, lines %s" % [joined, lobby.get_chat_texts()])
	lobby.get_chat_field().text = "thanks"
	lobby.get_chat_send_button().pressed.emit()
	var sent := await _harness.wait_until(func() -> bool: return session != null and _last(NetChat.of(host))[2] == "thanks", 256)
	_check("Its field sends a line, and the field empties", sent and lobby.get_chat_field().text == "", "host's last %s" % [_last(NetChat.of(host))])
	lobby.leave()
	lobby.close()
	remove_child(lobby)
	lobby.queue_free()
	host.close()
	await _harness.wait_ticks(60)


func _test_match_hud() -> void:
	var host := _harness.start_host("GameHost", "Host")
	var client := _harness.start_client("GameClient", "Jan")
	await _harness.wait_until(client.is_active)
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	rules.freeze_time = 1.0
	var host_main := _harness.start_game(host.get_parent(), host, MAP, rules)
	var client_main := _harness.start_game(client.get_parent(), client, MAP, rules)
	var host_game := host_main.get_net_game() as NetHost
	var client_game := client_main.get_net_game() as NetClient
	await _harness.wait_until(func() -> bool: return host_game.is_started() and client_game.is_welcomed(), 1200)
	var client_hud: ChatHud = client_main.get_node("HUD").call("get_chat_hud")
	var host_hud: ChatHud = host_main.get_node("HUD").call("get_chat_hud")
	# The class menus open by themselves at the start; the chat stays shut under a menu, so forget them.
	await _harness.wait_ticks(10)
	MenuState.reset()
	var opened := client_hud.open_input()
	var on_top := MenuState.is_top(client_hud) and client_hud.is_input_open()
	client_hud.get_input().text = "gg"
	client_hud.send_input()
	var closed := not client_hud.is_input_open() and not MenuState.is_top(client_hud)
	var fed := await _harness.wait_until(func() -> bool: return host_hud.get_line_texts().has("Jan: gg") and client_hud.get_line_texts().has("Jan: gg"), 256)
	_check("In a match the input opens as a menu, sends, closes, and the feed shows the line on both screens",
			opened and on_top and closed and fed, "opened %s, on top %s, closed %s, host feed %s" % [opened, on_top, closed, host_hud.get_line_texts()])
	client_hud.open_input()
	client_hud.get_input().text = "never mind"
	client_hud.close_input()
	await _harness.wait_ticks(64)
	var chat_action := InputEventAction.new()
	chat_action.action = &"chat"
	chat_action.pressed = true
	client_hud._unhandled_input(chat_action)
	var by_key := client_hud.is_input_open()
	client_hud.close_input()
	_check("Esc closes it without sending; the chat action (Enter) opens it", not host_hud.get_line_texts().has("Jan: never mind") and by_key,
			"host feed %s, opened by the action %s" % [host_hud.get_line_texts(), by_key])
	MenuState.reset()
	for main in [client_main, host_main]:
		main.get_parent().remove_child(main)
		main.queue_free()
	client.close()
	host.close()
	await _harness.wait_ticks(60)


## [peer id, name, text] of [param chat]'s newest line, or [] when it has none.
func _last(chat: NetChat) -> Array:
	if chat.lines.is_empty():
		return [0, "", ""]
	var line := chat.lines[-1]
	return [line["peer_id"], line["name"], line["text"]]


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description, "  (", detail, ")")
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
