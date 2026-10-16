extends Node
## Automated checks for the game browser (M17, D-242). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/browser_test.tscn
##
## Checked: the LAN beacon ([LanDiscovery]): a host advertising to 127.0.0.1 is listed by a listener with
## the right fields within 2 s, a changed beacon updates the entry, a repeated one is silent, and an entry
## expires 3.5 s after the last beacon; the packets nobody may trust (too big, not JSON, not an object,
## wrong magic word, fields of the wrong type or range, a name of control characters) are ignored and
## the strings that do pass are cut to plain text; a flood of junk reads at most 64 packets a frame and
## lists nothing, a flood of beacons from one sender lists four games; a listener says so (an error, no
## crash) when the port is taken; the broadcast targets. The recent hosts ([RecentHosts]): order, no
## repeats, at most 8, damaged text cleaned, saved to and read from a settings file of its own and
## cleaned when a hand-edited file holds junk. A hosting [NetLobby] advertises (the mode, map, players
## out of slots, in the match or not, and stops with the session). The Join page ([LobbyMenu]) lists a
## game that is advertised and its Join button joins that address and port for real, the host goes to
## the recent list, X forgets it, a game of another version can't be joined, and a port that is taken is
## said on the page. Everything runs on ports of this suite's block (tests/net_harness.gd) and on
## loopback; the player's real settings file is never touched. Quits with the number of failed checks.

const LOBBY_SCENE := preload("res://ui/lobby_menu.tscn")
## A temporary settings file of this test's own.
const TEMP_SETTINGS := "user://test_browser_settings.cfg"
## A name of nothing but invisible characters: a zero-width space and a right-to-left override.
const INVISIBLE := "\u200b\u202e"

var _harness: NetHarness
var _failures: int = 0
## The discovery port of this suite.
var _port: int = 0


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	_port = LanDiscovery.default_port
	MenuState.reset()
	GameLaunch.clear()
	await _test_beacon_and_expiry()
	await _test_untrusted_packets()
	await _test_floods()
	await _test_port_taken()
	_test_broadcast_targets()
	_test_recent_hosts()
	await _test_recent_saved()
	await _test_host_advertises()
	await _test_join_page()
	await _test_join_page_port_taken()
	MenuState.reset()
	GameLaunch.clear()
	remove_child(_harness)
	_harness.queue_free()
	await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The beacon ---


func _test_beacon_and_expiry() -> void:
	var listener := _make_discovery()
	var host := _make_discovery()
	host.broadcast_address = "127.0.0.1"
	var listen_result := listener.listen()
	var changes := [0]
	listener.games_changed.connect(func() -> void: changes[0] += 1)
	_check("The default discovery port is next to the game's (26001), the beacon goes to the whole network by default and a beacon is under 512 bytes",
			LanDiscovery.DISCOVERY_PORT == NetSession.DEFAULT_PORT + 1 and LanDiscovery.BROADCAST_ADDRESS == "255.255.255.255"
					and LanDiscovery.build_beacon({"name": "x".repeat(200), "map": "y".repeat(200), "mode": "z".repeat(200)}).size() <= LanDiscovery.MAX_PACKET_BYTES
					and listen_result == OK and listener.is_listening() and not listener.is_advertising(),
			"listen %d" % listen_result)

	var info := {"name": "Jan", "port": 26000, "mode": "tdm", "map": "Depot", "players": 2, "max_players": 6, "in_game": false}
	_check("advertise() starts a beacon", host.advertise(info) == OK and host.is_advertising(), "")
	var found := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty(), 256)
	var game: Dictionary = listener.get_games()[0] if found else {}
	_check("A host advertising to 127.0.0.1 is listed by a listener within 2 seconds, with its address (the packet's sender), port, name, mode, map, players out of slots, lobby state and version",
			found and game.get("address") == "127.0.0.1" and game.get("port") == 26000 and game.get("name") == "Jan" and game.get("mode") == "tdm"
					and game.get("map") == "Depot" and game.get("players") == 2 and game.get("max_players") == 6 and game.get("in_game") == false
					and game.get("version") == NetProtocol.VERSION and changes[0] == 1,
			"%s, %d change(s)" % [game, changes[0]])

	await _harness.wait_ticks(300)
	_check("A beacon that only repeats changes nothing: one game, one change, though two more beacons came (counted in ticks)",
			listener.get_games().size() == 1 and changes[0] == 1 and listener.packets_accepted >= 3,
			"%d games, %d changes, %d packets" % [listener.get_games().size(), changes[0], listener.packets_accepted])

	_check("update() on a host that isn't advertising does nothing", _make_discovery().update(info) == ERR_UNCONFIGURED, "")
	info["players"] = 3
	info["in_game"] = true
	info["map"] = "Square"
	host.update(info)
	var updated := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["players"] == 3, 64)
	game = listener.get_games()[0]
	_check("update() changes the entry at once, not at the next beacon: 3 players, in the match, another map (one game still), and the list reports the change",
			updated and game["in_game"] == true and game["map"] == "Square" and listener.get_games().size() == 1 and changes[0] == 2,
			"%s, %d change(s)" % [game, changes[0]])

	host.stop_advertising()
	await _harness.wait_ticks(400)
	var still_listed := listener.get_games().size() == 1
	var gone := await _harness.wait_until(func() -> bool: return listener.get_games().is_empty(), 100)
	_check("After the host stops, the game stays listed for 3.5 seconds from its last beacon (still there after 3.1 s) and then expires (gone by 3.9 s) and the list says so",
			still_listed and gone and changes[0] == 3 and not host.is_advertising(),
			"still listed %s, gone %s, %d change(s)" % [still_listed, gone, changes[0]])

	listener.stop_listening()
	_check("stop_listening() closes the port", not listener.is_listening() and listener.get_games().is_empty(), "")
	_discard(listener)
	_discard(host)


# --- Packets nobody may trust ---


func _test_untrusted_packets() -> void:
	var listener := _make_discovery()
	listener.listen()
	var good := _beacon()
	var padded := _beacon({"pad": "x".repeat(600)})
	var bad: Array[PackedByteArray] = [
		padded,
		"hello".to_utf8_buffer(),
		"[1, 2, 3]".to_utf8_buffer(),
		"42".to_utf8_buffer(),
		"{\"game\": \"chiip\"".to_utf8_buffer(),
		PackedByteArray([0xff, 0xfe, 0xfd, 0x00, 0x01]),
		("[".repeat(300) + "]".repeat(300)).to_utf8_buffer(),
		_beacon({"game": "quake"}),
		_beacon({"game": 5}),
		_beacon({"game": null}),
		_beacon({"port": "26000"}),
		_beacon({"port": 80}),
		_beacon({"port": 1023}),
		_beacon({"port": 70000}),
		_beacon({"port": 26000.5}),
		_beacon({"port": -5}),
		_beacon({"ver": "2"}),
		_beacon({"ver": -1}),
		_beacon({"players": -1}),
		_beacon({"players": 11}),
		_beacon({"players": "2"}),
		_beacon({"max": 0}),
		_beacon({"max": 99}),
		_beacon({"name": 5}),
		_beacon({"name": ""}),
		_beacon({"name": "   \n\t "}),
		_beacon({"name": INVISIBLE}),
		_beacon({"mode": ""}),
		_beacon({"mode": 3}),
		_beacon({"map": ["Depot"]}),
		_beacon({"state": "weird"}),
		_beacon({"state": 1}),
	]
	var removed_key: Dictionary = JSON.parse_string(good.get_string_from_utf8())
	removed_key.erase("name")
	bad.append(JSON.stringify(removed_key).to_utf8_buffer())
	removed_key = JSON.parse_string(good.get_string_from_utf8())
	removed_key.erase("game")
	bad.append(JSON.stringify(removed_key).to_utf8_buffer())
	_check("A good beacon on its own is accepted by parse_beacon() with the sender's address; a hostname or no address is not (the address must be an IP)",
			not LanDiscovery.parse_beacon(good, "10.1.2.3").is_empty() and LanDiscovery.parse_beacon(good, "10.1.2.3")["address"] == "10.1.2.3"
					and LanDiscovery.parse_beacon(good, "example.com").is_empty() and LanDiscovery.parse_beacon(good, "").is_empty()
					and LanDiscovery.parse_beacon(PackedByteArray(), "10.1.2.3").is_empty(), "")
	var direct_rejected := 0
	for packet in bad:
		if LanDiscovery.parse_beacon(packet, "10.1.2.3").is_empty():
			direct_rejected += 1
	_check("parse_beacon() rejects every one of the %d bad packets (too big, not JSON, not an object, wrong or missing magic word, fields of the wrong type or range, empty names and modes, an unknown state)" % bad.size(),
			direct_rejected == bad.size(), "%d of %d rejected" % [direct_rejected, bad.size()])

	var changes := [0]
	listener.games_changed.connect(func() -> void: changes[0] += 1)
	_send_raw(bad)
	await _harness.wait_until(func() -> bool: return listener.packets_ignored >= bad.size(), 120)
	_check("A listener ignores all of them: they are counted as ignored, nothing is listed, nothing changed",
			listener.packets_ignored == bad.size() and listener.packets_accepted == 0 and listener.get_games().is_empty() and changes[0] == 0,
			"%d ignored of %d, %d accepted, %s" % [listener.packets_ignored, bad.size(), listener.packets_accepted, listener.get_games()])

	var dirty := _beacon({"name": "A" + String.chr(0x202E) + "evil\n" + String.chr(0x200B) + " name that is far too long", "map": "\u0007Depot " + "x".repeat(60), "mode": "tdm"})
	_send_raw([dirty])
	var listed := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty(), 120)
	var game: Dictionary = listener.get_games()[0] if listed else {}
	var host_name := String(game.get("name", ""))
	var map_title := String(game.get("map", ""))
	_check("A beacon that is fine except for its texts is listed with them cut to plain printable text: the name at most 16 characters, the map at most 32, no control or direction characters",
			listed and host_name.length() <= NetSession.MAX_NAME_LENGTH and not host_name.is_empty() and PlainText.printable(host_name) == host_name
					and map_title.length() <= LanDiscovery.MAX_MAP_LENGTH and PlainText.printable(map_title) == map_title and map_title.begins_with("Depot"),
			"name '%s', map '%s'" % [host_name, map_title])
	_discard(listener)


func _test_floods() -> void:
	var listener := _make_discovery()
	listener.listen()
	var junk: Array[PackedByteArray] = []
	for i in 1000:
		junk.append(("junk %d" % i).to_utf8_buffer())
	_send_raw(junk)
	await _harness.wait_until(func() -> bool: return listener.packets_ignored >= junk.size(), 200)
	_check("A flood of 1000 junk packets lists nothing and no frame reads more than 64 of them (the cap was reached, so the rest waited for later frames)",
			listener.get_games().is_empty() and listener.packets_accepted == 0 and listener.packets_ignored == junk.size()
					and listener.most_read_in_a_frame == LanDiscovery.MAX_PACKETS_PER_FRAME,
			"%d ignored, %d accepted, most in a frame %d" % [listener.packets_ignored, listener.packets_accepted, listener.most_read_in_a_frame])
	_discard(listener)

	var second := _make_discovery()
	second.listen()
	var beacons: Array[PackedByteArray] = []
	for i in 200:
		beacons.append(_beacon({"port": 20000 + i, "name": "Spam %d" % i}))
	_send_raw(beacons)
	await _harness.wait_until(func() -> bool: return second.packets_accepted + second.packets_ignored >= beacons.size(), 200)
	_check("A flood of 200 good-looking beacons from one address lists only %d of them (at most %d games per sender, never more than %d in all)" % [LanDiscovery.MAX_GAMES_PER_ADDRESS, LanDiscovery.MAX_GAMES_PER_ADDRESS, LanDiscovery.MAX_GAMES],
			second.get_games().size() == LanDiscovery.MAX_GAMES_PER_ADDRESS and second.get_games().size() <= LanDiscovery.MAX_GAMES
					and second.get_games()[0]["name"] == "Spam 0",
			"%d games" % second.get_games().size())
	_discard(second)


func _test_port_taken() -> void:
	var taken_port := _port + 2
	var blocker := PacketPeerUDP.new()
	var blocked := blocker.bind(taken_port, "0.0.0.0")
	var listener := _make_discovery()
	listener.port = taken_port
	var result := listener.listen()
	await _harness.wait_ticks(5)
	_check("A listener on a port another program holds answers an error instead of crashing: not listening, no games, and the node keeps running",
			blocked == OK and result != OK and not listener.is_listening() and listener.get_games().is_empty(),
			"blocker %d, listen %d" % [blocked, result])
	blocker.close()
	var retry := listener.listen()
	var twin := _make_discovery()
	twin.port = taken_port
	var twin_result := twin.listen()
	_check("Once the port is free the same node listens; a second listener on the same port (a second Chiip on this computer) gets the error",
			retry == OK and listener.is_listening() and twin_result != OK and not twin.is_listening(),
			"retry %d, twin %d" % [retry, twin_result])
	_discard(listener)
	_discard(twin)


func _test_broadcast_targets() -> void:
	var found := PackedStringArray(["fe80:0:0:0:ce81:b1c:bd2c:69e", "192.168.1.71", "127.0.0.1", "169.254.7.7", "100.101.102.103", "10.0.5.9", "192.168.1.200", "0.0.0.0"])
	var targets := LanDiscovery.broadcast_targets(LanDiscovery.BROADCAST_ADDRESS, found)
	_check("The default beacon goes to 255.255.255.255 and to each network's directed broadcast (192.168.1.255, 10.0.5.255), once each; not for loopback, link-local, Tailscale or IPv6 addresses (macOS refused 255.255.255.255 on the Mac this was built on)",
			targets == ["255.255.255.255", "192.168.1.255", "10.0.5.255"], "%s" % [targets])
	_check("A beacon sent to one address (a test's 127.0.0.1) goes there alone", LanDiscovery.broadcast_targets("127.0.0.1", found) == ["127.0.0.1"], "")


# --- Recent hosts ---


func _test_recent_hosts() -> void:
	var text := ""
	text = RecentHosts.remember(text, "192.168.1.5", 26000, "Anna")
	text = RecentHosts.remember(text, "100.64.1.2", 26000, "Tom")
	text = RecentHosts.remember(text, "192.168.1.5", 26000, "")
	var list := RecentHosts.parse(text)
	_check("A host joined again moves to the front instead of being listed twice, and keeps its name when the new join has none (newest first)",
			list.size() == 2 and list[0] == {"address": "192.168.1.5", "port": 26000, "name": "Anna"} and list[1]["address"] == "100.64.1.2",
			text)
	text = RecentHosts.remember(text, "192.168.1.5", 26000, "Anna B")
	text = RecentHosts.remember(text, "192.168.1.5", 27000, "Anna B")
	list = RecentHosts.parse(text)
	_check("A new name replaces the old one; the same address on another port is another host",
			list.size() == 3 and list[0]["port"] == 27000 and list[1]["name"] == "Anna B" and list[1]["port"] == 26000, text)
	text = RecentHosts.remember(text, "JAN-PC.local", 26000, "Jan")
	text = RecentHosts.remember(text, "jan-pc.LOCAL", 26000, "")
	list = RecentHosts.parse(text)
	_check("A host name counts once whatever the case of its letters", list.size() == 4 and list[0]["address"] == "jan-pc.LOCAL" and list[0]["name"] == "Jan", text)

	text = ""
	for i in 12:
		text = RecentHosts.remember(text, "10.0.0.%d" % (i + 1), 26000 + i, "Host %d" % i)
	list = RecentHosts.parse(text)
	_check("The list holds 8 hosts: the newest first (10.0.0.12 down to 10.0.0.5), the oldest four dropped",
			list.size() == RecentHosts.MAX_ENTRIES and RecentHosts.MAX_ENTRIES == 8 and list[0]["address"] == "10.0.0.12" and list[7]["address"] == "10.0.0.5",
			text)
	text = RecentHosts.forget(text, "10.0.0.12", 26011)
	_check("forget() takes one host out (and a host that isn't there changes nothing)",
			RecentHosts.parse(text).size() == 7 and RecentHosts.parse(text)[0]["address"] == "10.0.0.11"
					and RecentHosts.forget(text, "1.2.3.4", 26000) == text and RecentHosts.forget(text, "10.0.0.11", 9999) == text, "")

	var damaged := "garbage;1.2.3.4:80;host:abc;;:26000;bad address:26000;10.0.0.1:26000|Jan\nSmith;10.0.0.1:26000|Again;fd7a:115c:a1e0::1:26001|v6;10.0.0.2:99999;10.0.0.3:26000|a;b|c"
	var cleaned := RecentHosts.parse(damaged)
	_check("A damaged line is cleaned entry by entry: entries that don't parse (no port, port below 1024 or above 65535, a space in the address) are dropped, a repeat is dropped, an IPv6 address keeps its colons, a name loses its line break and separators",
			cleaned.map(func(entry: Dictionary) -> String: return "%s:%d|%s" % [entry["address"], entry["port"], entry["name"]])
					== ["10.0.0.1:26000|Jan Smith", "fd7a:115c:a1e0::1:26001|v6", "10.0.0.3:26000|a"],
			"%s" % [cleaned])
	var long_name := RecentHosts.remember("", "10.9.9.9", 26000, "N".repeat(100) + String.chr(0x202E))
	var huge := ";".join(PackedStringArray(range(5000).map(func(i: int) -> String: return "10.1.%d.%d:26000|x" % [i / 250, i % 250])))
	_check("A remembered name is cut to 16 characters (the session's limit), and a huge text is cut to 8 entries without trouble",
			RecentHosts.parse(long_name)[0]["name"] == "N".repeat(16) and RecentHosts.MAX_NAME_LENGTH == NetSession.MAX_NAME_LENGTH
					and RecentHosts.parse(huge).size() == 8 and RecentHosts.clean(huge).length() < RecentHosts.MAX_TEXT_LENGTH,
			"%s" % [RecentHosts.parse(long_name)])
	_check("An address or port that can't be one leaves the list as it was",
			RecentHosts.remember("10.0.0.1:26000|A", "", 26000, "x") == "10.0.0.1:26000|A" and RecentHosts.remember("10.0.0.1:26000|A", "a b", 26000, "x") == "10.0.0.1:26000|A"
					and RecentHosts.remember("10.0.0.1:26000|A", "10.0.0.2", 80, "x") == "10.0.0.1:26000|A"
					and RecentHosts.remember("10.0.0.1:26000|A", "10.0.0.2", 70000, "x") == "10.0.0.1:26000|A", "")


func _test_recent_saved() -> void:
	var real_accesses_before := Settings.real_file_accesses
	var absolute := ProjectSettings.globalize_path(TEMP_SETTINGS)
	if FileAccess.file_exists(TEMP_SETTINGS):
		DirAccess.remove_absolute(absolute)
	var writer := Settings.new()
	var loaded := writer.load_from_disk(TEMP_SETTINGS)
	writer.online_recent = RecentHosts.remember(writer.online_recent, "192.168.1.5", 26000, "Anna")
	writer.online_recent = RecentHosts.remember(writer.online_recent, "100.64.1.2", 27001, "Tom")
	writer.online_recent = RecentHosts.remember(writer.online_recent, "10.0.0.7", 26000)
	var reader := Settings.new()
	var read_result := reader.load_from_disk(TEMP_SETTINGS)
	var list := RecentHosts.parse(reader.online_recent)
	_check("The recent hosts are saved in the settings file ([online] recent) and read back in order with their names; a new Settings starts with none; the player's real file is not touched",
			loaded == ERR_FILE_NOT_FOUND and read_result == OK and Settings.new().online_recent == "" and list.size() == 3 and list[0]["address"] == "10.0.0.7" and list[1] == {"address": "100.64.1.2", "port": 27001, "name": "Tom"}
					and list[2]["name"] == "Anna" and FileAccess.get_file_as_string(TEMP_SETTINGS).contains("recent=") and Settings.real_file_accesses == real_accesses_before,
			"%s" % [list])

	var edited := ConfigFile.new()
	edited.load(TEMP_SETTINGS)
	edited.set_value("online", "recent", "junk;10.0.0.1:26000|Jan;;nonsense:|:;10.0.0.1:26000|Dup")
	edited.save(TEMP_SETTINGS)
	var hand_edited := Settings.new()
	hand_edited.load_from_disk(TEMP_SETTINGS)
	edited.set_value("online", "recent", 12345)
	edited.save(TEMP_SETTINGS)
	var wrong_type := Settings.new()
	wrong_type.load_from_disk(TEMP_SETTINGS)
	hand_edited.online_recent = "also;10.0.0.9:26000|ok;junk"
	_check("A hand-edited file is cleaned when it loads (junk entries and repeats dropped), a value of the wrong type becomes none, and setting a dirty text cleans it too",
			RecentHosts.parse(hand_edited.online_recent).size() == 1 and hand_edited.online_recent == "10.0.0.9:26000|ok" and wrong_type.online_recent == ""
					and Settings.real_file_accesses == real_accesses_before,
			"'%s', '%s'" % [hand_edited.online_recent, wrong_type.online_recent])
	DirAccess.remove_absolute(absolute)
	_check("The recent hosts are a setting of their own that starts empty",
			Settings.get_default(&"online_recent") == "" and Settings.has_setting(&"online_recent") and Settings.new().online_recent == "", "")


# --- A hosting lobby advertises ---


func _test_host_advertises() -> void:
	var listener := _make_discovery()
	listener.listen()
	var host := _harness.start_host("Host", "Jan")
	var lobby := NetLobby.of(host)
	lobby.change_scene = func(_path: String) -> void: pass
	var beacon := _make_discovery(false)
	beacon.broadcast_address = "127.0.0.1"
	lobby.discovery = beacon
	lobby.add_child(beacon)
	await _harness.wait_ticks(160)
	_check("A host that has not published its lobby advertises nothing yet", not beacon.is_advertising() and listener.get_games().is_empty(), "")

	lobby.publish("Rounds · Depot", [3, 3], "res://maps/depot.tscn", {}, "rounds")
	var found := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty(), 256)
	var game: Dictionary = listener.get_games()[0] if found else {}
	_check("Publishing the lobby starts the beacon: the host's name, its game port, the mode (rounds), the map's title, 1 player out of the 6 slots, in the lobby, this game's version",
			found and game.get("name") == "Jan" and game.get("port") == _harness.port and game.get("mode") == "rounds" and game.get("map") == "Depot"
					and game.get("players") == 1 and game.get("max_players") == 6 and game.get("in_game") == false and game.get("version") == NetProtocol.VERSION,
			"%s" % [game])

	var friend := _harness.start_client("Friend", "Anna")
	NetLobby.of(friend).change_scene = func(_path: String) -> void: pass
	var two := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["players"] == 2, 256)
	_check("A player joining updates the count (2 / 6) within 2 seconds", two, "%s" % [listener.get_games()])

	lobby.publish("Free-for-all · Square", [5, 5], "res://maps/square.tscn", {}, "ffa")
	var changed := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["mode"] == "ffa", 256)
	game = listener.get_games()[0] if changed else {}
	_check("Changing the mode, the map or the slots updates the beacon (free-for-all, Square, 2 / 10)",
			changed and game["map"] == "Square" and game["players"] == 2 and game["max_players"] == 10, "%s" % [game])

	lobby.start_match("res://maps/depot.tscn", MatchSettings.new())
	var playing := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["in_game"] == true, 256)
	lobby.return_to_lobby()
	var back := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["in_game"] == false, 256)
	GameLaunch.clear()
	_check("A running match shows as in game and the way back to the lobby clears it", playing and back, "playing %s, back %s" % [playing, back])

	friend.close()
	var one := await _harness.wait_until(func() -> bool: return not listener.get_games().is_empty() and listener.get_games()[0]["players"] == 1, 512)
	_check("A player leaving updates the count again (1 / 10)", one, "%s" % [listener.get_games()])

	host.close()
	var stopped := await _harness.wait_until(func() -> bool: return not beacon.is_advertising(), 200)
	var expired := await _harness.wait_until(func() -> bool: return listener.get_games().is_empty(), 640)
	_check("When the session closes the beacon stops and the game leaves the list", stopped and expired, "stopped %s, expired %s" % [stopped, expired])
	_discard(listener)
	await _harness.wait_ticks(10)


# --- The Join page ---


func _test_join_page() -> void:
	MenuState.reset()
	var stored := Settings.new()
	stored.online_name = "Jan2"
	# One host never answers (nothing listens on that port of this computer): joining it from the list only connects.
	stored.online_recent = RecentHosts.remember(RecentHosts.remember("", "127.0.0.1", _port + 3), "100.64.0.9", 26000, "Tailscale pal")
	var lobby := LOBBY_SCENE.instantiate() as LobbyMenu
	lobby.settings = stored
	add_child(lobby)
	lobby.set_ui_scale(1.0)
	await get_tree().process_frame
	var listening_before := lobby.get_discovery() != null
	lobby.open()
	var discovery := lobby.get_discovery()
	_check("The Join page listens for games while it shows (not before), says \"Looking for games…\" while there are none, shows the recent hosts newest first (the name and address, or the address alone) and hides the lobby's teams",
			not listening_before and discovery != null and discovery.is_listening() and discovery.port == _port
					and lobby.get_browser().visible and lobby.get_games_note().visible and lobby.get_games_note().text == LobbyMenu.LOOKING_TEXT
					and lobby.get_game_texts().is_empty() and lobby.get_recent_texts() == ["Tailscale pal | 100.64.0.9:26000", "127.0.0.1:%d" % (_port + 3)]
					and not lobby.get_recent_note().visible and lobby.get_recent_join_buttons().size() == 2 and lobby.get_recent_remove_buttons().size() == 2
					and not lobby.get_teams_box().visible,
			"listening %s, note '%s', recent %s" % [discovery.is_listening() if discovery != null else null, lobby.get_games_note().text, lobby.get_recent_texts()])

	# A real host on the network (loopback here) advertises; the page lists it.
	var host := _harness.start_host("JoinHost", "Host")
	var host_lobby := NetLobby.of(host)
	host_lobby.change_scene = func(_path: String) -> void: pass
	var beacon := _make_discovery(false)
	beacon.broadcast_address = "127.0.0.1"
	host_lobby.discovery = beacon
	host_lobby.add_child(beacon)
	host_lobby.publish("Rounds · Depot", [3, 3], "res://maps/depot.tscn", {}, "rounds")
	var listed := await _harness.wait_until(func() -> bool: return lobby.get_game_texts().size() == 1, 256)
	_check("The page lists the advertised game within 2 seconds: its name, map, mode (Bomb), players out of slots (1/6) and Lobby, with a Join button; the \"Looking for games…\" line goes",
			listed and lobby.get_game_texts() == ["Host | Depot | Bomb | 1/6 | Lobby"] and lobby.get_game_join_buttons().size() == 1 and not lobby.get_games_note().visible
					and not lobby.get_game_join_buttons()[0].disabled and lobby.get_game_join_buttons()[0].text == "Join",
			"%s" % [lobby.get_game_texts()])

	lobby.get_game_join_buttons()[0].pressed.emit()
	var address_used := lobby.get_address_field().text
	var port_used := lobby.get_port_field().text
	var connecting_off := lobby.get_game_join_buttons()[0].disabled and lobby.get_recent_join_buttons()[0].disabled and lobby.get_join_button().disabled
	var in_lobby := await _harness.wait_until(func() -> bool: return lobby.get_page() == LobbyMenu.Page.LOBBY, 640)
	var remembered := RecentHosts.parse(stored.online_recent)
	_check("The Join button of a game fills the address and port fields and joins that host for real (here: the lobby page as a client), and the Join buttons are off while the join is under way",
			address_used == "127.0.0.1" and port_used == str(_harness.port) and in_lobby and lobby.get_session() != null and not lobby.get_session().is_host()
					and stored.online_address == "127.0.0.1" and stored.online_port == _harness.port and connecting_off,
			"fields %s:%s, lobby %s, stored %s:%d, off while connecting %s" % [address_used, port_used, in_lobby, stored.online_address, stored.online_port, connecting_off])
	_check("A successful join puts the host (address, port and its name) at the front of the recent hosts, in front of the older ones, and the lobby page stops the listening and hides the browser",
			remembered.size() == 3 and remembered[0] == {"address": "127.0.0.1", "port": _harness.port, "name": "Host"} and remembered[2]["port"] == _port + 3
					and not discovery.is_listening() and not lobby.get_browser().visible,
			"%s, listening %s" % [remembered, discovery.is_listening()])

	lobby.leave()
	await _harness.wait_until(func() -> bool: return lobby.get_game_texts().size() == 1 and not lobby.is_closing_session(), 640)
	_check("Back on the connect page the discovery listens again, the game is listed again and the host just joined leads the recent list (with the host's name, Host)",
			discovery.is_listening() and lobby.get_browser().visible and lobby.get_recent_texts()[0] == "Host | 127.0.0.1:%d" % _harness.port and lobby.get_recent_texts().size() == 3
					and lobby.get_game_texts().size() == 1,
			"%s, %s" % [lobby.get_recent_texts(), lobby.get_game_texts()])

	lobby.get_recent_remove_buttons()[0].pressed.emit()
	var after_forget := RecentHosts.parse(stored.online_recent)
	_check("The X button of a recent host forgets it: gone from the list and from the settings (the others stay)",
			lobby.get_recent_texts() == ["Tailscale pal | 100.64.0.9:26000", "127.0.0.1:%d" % (_port + 3)] and after_forget.size() == 2 and after_forget[0]["address"] == "100.64.0.9",
			"%s, stored %s" % [lobby.get_recent_texts(), stored.online_recent])
	lobby.get_recent_join_buttons()[1].pressed.emit()
	var recent_fields := [lobby.get_address_field().text, lobby.get_port_field().text]
	var recent_connecting := lobby.get_page() == LobbyMenu.Page.CONNECT and lobby.get_session() != null and lobby.get_join_button().disabled \
			and lobby.get_status_label().text.begins_with("Connecting to 127.0.0.1:%d" % (_port + 3))
	_check("The Join button of a recent host joins that address and port too (it fills the fields and connects: nobody answers at this port, so it keeps connecting until Back)",
			recent_fields == ["127.0.0.1", str(_port + 3)] and recent_connecting,
			"fields %s, connecting %s, status '%s'" % [recent_fields, recent_connecting, lobby.get_status_label().text])
	lobby.leave()
	await _harness.wait_until(func() -> bool: return not lobby.is_closing_session(), 640)

	# A game of another version, a list of many, a game of an unknown mode.
	var games: Array[Dictionary] = []
	games.append({"address": "10.0.0.5", "port": 26000, "name": "Old Joe", "mode": "tdm", "map": "Depot", "players": 3, "max_players": 6, "in_game": false, "version": NetProtocol.VERSION + 1})
	games.append({"address": "10.0.0.6", "port": 26001, "name": "Match Mia", "mode": "ffa", "map": "Spillway", "players": 4, "max_players": 4, "in_game": true, "version": NetProtocol.VERSION})
	games.append({"address": "10.0.0.7", "port": 26002, "name": "Future", "mode": "ctf", "map": "Somewhere", "players": 1, "max_players": 2, "in_game": false, "version": NetProtocol.VERSION})
	lobby.show_games(games)
	var buttons := lobby.get_game_join_buttons()
	_check("A game of another version is listed as \"Other version\" with Join off (and a tooltip saying why); a running match says In game; a mode this version doesn't know is shown as it was sent",
			lobby.get_game_texts() == ["Old Joe | Depot | Team Deathmatch | 3/6 | Other version", "Match Mia | Spillway | Free-for-all | 4/4 | In game", "Future | Somewhere | ctf | 1/2 | Lobby"]
					and buttons[0].disabled and not buttons[1].disabled and not buttons[2].disabled and buttons[0].tooltip_text.contains("another version"),
			"%s" % [lobby.get_game_texts()])

	lobby.close()
	_check("Closing the page stops the listening", not discovery.is_listening() and not lobby.is_open(), "")
	remove_child(lobby)
	lobby.queue_free()
	host.close()
	await _harness.wait_ticks(60)
	MenuState.reset()
	GameLaunch.clear()


func _test_join_page_port_taken() -> void:
	var blocker := PacketPeerUDP.new()
	var blocked := blocker.bind(_port, "0.0.0.0")
	var stored := Settings.new()
	var lobby := LOBBY_SCENE.instantiate() as LobbyMenu
	lobby.settings = stored
	add_child(lobby)
	lobby.set_ui_scale(1.0)
	lobby.open()
	await get_tree().process_frame
	var note := lobby.get_games_note()
	_check("When the discovery port is taken the page says so instead of crashing (the line names the port and what still works), and Join by IP is still there",
			blocked == OK and not lobby.get_discovery().is_listening() and note.visible and note.text.begins_with("Can't look for games") and note.text.contains(str(_port))
					and lobby.get_join_button().visible and not lobby.get_join_button().disabled and lobby.get_game_texts().is_empty(),
			"blocker %d, note '%s'" % [blocked, note.text])
	blocker.close()
	lobby.close()
	lobby.open()
	_check("Opening the page again, with the port free, listens and says \"Looking for games…\"",
			lobby.get_discovery().is_listening() and lobby.get_games_note().text == LobbyMenu.LOOKING_TEXT, "note '%s'" % lobby.get_games_note().text)
	lobby.close()
	remove_child(lobby)
	lobby.queue_free()
	await get_tree().process_frame
	MenuState.reset()


# --- Helpers ---


## A discovery node on this suite's port, in the tree (so it runs); [param own_node] false leaves it out of the tree.
func _make_discovery(in_tree: bool = true) -> LanDiscovery:
	var discovery := LanDiscovery.new()
	if in_tree:
		add_child(discovery)
	return discovery


## Takes a discovery node out of the tree and frees it: its sockets are closed at once (queue_free alone
## would keep the port for the rest of the frame, and the next test could not listen on it).
func _discard(discovery: LanDiscovery) -> void:
	if discovery.is_inside_tree():
		remove_child(discovery)
	discovery.queue_free()


## The bytes of a good beacon, with [param changes] applied (a key set to a value of its own; a key
## set to null is sent as null).
func _beacon(changes: Dictionary = {}) -> PackedByteArray:
	var data := {"game": "chiip", "ver": NetProtocol.VERSION, "name": "Jan", "port": 26000, "mode": "tdm", "map": "Depot", "players": 2, "max": 6, "state": "lobby"}
	for key: String in changes:
		data[key] = changes[key]
	return JSON.stringify(data).to_utf8_buffer()


## Sends [param packets] to this suite's discovery port on this computer, from a socket of their own.
func _send_raw(packets: Array[PackedByteArray]) -> void:
	var sender := PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1", _port)
	for packet in packets:
		sender.put_packet(packet)
	sender.close()


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
