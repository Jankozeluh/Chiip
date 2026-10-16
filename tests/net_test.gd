extends Node
## Automated checks for the network layer (M9). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/net_test.tscn
##
## A host and two clients run in this one process (D-111, [NetHarness]) and talk over ENet on
## localhost. Checked: the session ([NetSession], D-101, D-102): hosting, joining, the roster
## with unique and cleaned names and balanced teams, team requests and full teams, messages
## from the host to everyone and from a client to the host, game-stream packets both ways,
## fake lag (counted in ticks), fake loss (unreliable packets only) with reliable packets kept in
## order under jitter, a client leaving, and the host closing the session.
## Quits with the number of failed checks as the exit code.

var _harness: NetHarness
var _failures: int = 0


func _ready() -> void:
	_harness = NetHarness.new()
	add_child(_harness)
	await _test_session()
	remove_child(_harness)
	_harness.queue_free()
	await get_tree().physics_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _test_session() -> void:
	var host := _harness.start_host("Host", "  Jan  ")
	_check("A host starts on a free port and is peer 1 in its own roster",
			host.is_active() and host.is_host() and host.local_peer_id == 1 and host.get_players().size() == 1
					and host.get_players()[0]["name"] == "Jan" and host.get_players()[0]["team"] == 0,
			"%s" % [host.get_players()])

	var first := _harness.start_client("ClientA", "Jan")
	var joined_first := await _harness.wait_until(first.is_active)
	var second := _harness.start_client("ClientB", "Bot3")
	var joined_second := await _harness.wait_until(second.is_active)
	await _harness.wait_until(func() -> bool: return first.get_players().size() == 3)
	var names: Array = host.get_players().map(func(entry: Dictionary) -> String: return entry["name"])
	var teams: Array = host.get_players().map(func(entry: Dictionary) -> int: return entry["team"])
	_check("Two clients join, each with its own peer id", joined_first and joined_second
			and first.local_peer_id > 1 and second.local_peer_id > 1 and first.local_peer_id != second.local_peer_id,
			"joined %s %s, ids %d %d" % [joined_first, joined_second, first.local_peer_id, second.local_peer_id])
	_check("The roster lists everyone in join order with unique, cleaned names (\"Jan 2\", no bot names)",
			names == ["Jan", "Jan 2", "Player Bot3"] and first.local_name == "Jan 2" and second.local_name == "Player Bot3",
			"%s, the clients call themselves %s and %s" % [names, first.local_name, second.local_name])
	_check("Newcomers go to the smaller team (host 0, then 1, then 0)", teams == [0, 1, 0], "%s" % [teams])
	_check("Every computer has the same roster", _roster(first) == _roster(host) and _roster(second) == _roster(host),
			"host %s, A %s, B %s" % [_roster(host), _roster(first), _roster(second)])

	second.request_team(1)
	await _harness.wait_until(func() -> bool: return first.get_team(second.local_peer_id) == 1)
	_check("A team request reaches the host and everyone's roster",
			host.get_team(second.local_peer_id) == 1 and first.get_team(second.local_peer_id) == 1 and second.get_team(second.local_peer_id) == 1, "")
	host.request_team(1, 2)
	await _harness.wait_ticks(20)
	_check("A full team refuses one more player", host.get_team(1) == 0 and first.get_team(1) == 0, "host on team %d" % host.get_team(1))

	var got_first: Array = []
	var got_second: Array = []
	var got_host: Array = []
	first.match_message.connect(func(data: Dictionary) -> void: got_first.append(data))
	second.match_message.connect(func(data: Dictionary) -> void: got_second.append(data))
	host.match_message.connect(func(data: Dictionary) -> void: got_host.append(data))
	host.send_to_all({"start": "res://maps/depot.tscn"})
	first.send_to_host({"loaded": true})
	await _harness.wait_until(func() -> bool: return got_first.size() >= 1 and got_second.size() >= 1 and got_host.size() >= 2)
	_check("The host's messages reach every client; a client's reaches the host, which knows who sent it",
			got_first.size() == 1 and got_first[0]["start"] == "res://maps/depot.tscn" and got_second.size() == 1
					and got_host.size() == 2 and got_host[1].get("from", 0) == first.local_peer_id and got_host[1]["loaded"] == true,
			"A %s, B %s, host %s" % [got_first, got_second, got_host])

	await _test_packets(host, first, second)

	var left: Array = []
	host.player_left.connect(func(peer_id: int) -> void: left.append(peer_id))
	var second_id := second.local_peer_id
	second.close()
	await _harness.wait_until(func() -> bool: return first.get_players().size() == 2, 2560)
	_check("A client that leaves is dropped from every roster", left == [second_id] and host.get_players().size() == 2
			and first.get_player(second_id).is_empty(), "left %s, host has %d players" % [left, host.get_players().size()])

	var reasons: Array = []
	first.closed.connect(func(reason: String) -> void: reasons.append(reason))
	host.close()
	await _harness.wait_until(func() -> bool: return not reasons.is_empty(), 2560)
	_check("When the host closes the session the clients are told", reasons.size() == 1 and reasons[0] != "" and not first.is_active(),
			"%s" % [reasons])
	if is_instance_valid(first):
		first.close()


func _test_packets(host: NetSession, first: NetSession, second: NetSession) -> void:
	var at_host: Array = []
	var at_first: Array = []
	var at_second: Array = []
	var host_listener := func(peer_id: int, packet: PackedByteArray) -> void: at_host.append([peer_id, packet])
	var first_listener := func(peer_id: int, packet: PackedByteArray) -> void: at_first.append([peer_id, packet])
	var second_listener := func(peer_id: int, packet: PackedByteArray) -> void: at_second.append([peer_id, packet])
	host.packet_received.connect(host_listener)
	first.packet_received.connect(first_listener)
	second.packet_received.connect(second_listener)

	host.send_packet(0, NetProtocol.pack_values(NetProtocol.Message.EVENT, ["hello", 7]), true)
	first.send_packet(1, PackedByteArray([NetProtocol.Message.COMMANDS, 1, 2, 3]), false)
	await _harness.wait_until(func() -> bool: return at_first.size() >= 1 and at_second.size() >= 1 and at_host.size() >= 1)
	_check("Stream packets travel from the host to every client and from a client to the host",
			at_first.size() == 1 and NetProtocol.unpack_values(at_first[0][1]) == ["hello", 7] and at_first[0][0] == 1
					and at_second.size() == 1 and at_host.size() == 1 and at_host[0][0] == first.local_peer_id
					and at_host[0][1] == PackedByteArray([NetProtocol.Message.COMMANDS, 1, 2, 3]),
			"A %s, B %s, host %s" % [at_first, at_second, at_host])

	# Fake lag on the receiving side, in ticks: 100 ms is 13 ticks at 128 Hz.
	at_first.clear()
	first.fake_lag_ms = 100.0
	var sent_at := Engine.get_physics_frames()
	host.send_packet(first.local_peer_id, PackedByteArray([NetProtocol.Message.SNAPSHOT, 42]), false)
	await _harness.wait_until(func() -> bool: return not at_first.is_empty(), 200)
	var waited := Engine.get_physics_frames() - sent_at
	_check("Fake lag holds a packet back by its length in ticks (100 ms: 13 ticks, plus a tick or two on localhost)",
			at_first.size() == 1 and waited >= 13 and waited <= 17, "arrived after %d ticks" % waited)
	first.fake_lag_ms = 0.0

	# Fake loss drops unreliable packets only; with jitter, reliable ones still keep their order.
	at_first.clear()
	first.rng.seed = 4711
	first.fake_loss = 0.5
	first.fake_jitter_ms = 40.0
	for i in 200:
		host.send_packet(first.local_peer_id, PackedByteArray([NetProtocol.Message.SNAPSHOT, i % 256]), false)
		host.send_packet(first.local_peer_id, NetProtocol.pack_values(NetProtocol.Message.EVENT, [i]), true)
		if i % 8 == 7:
			await get_tree().physics_frame
	await _harness.wait_ticks(60)
	var unreliable := at_first.filter(func(item: Array) -> bool: return NetProtocol.type_of(item[1]) == NetProtocol.Message.SNAPSHOT).size()
	var reliable_order: Array = []
	for item: Array in at_first:
		if NetProtocol.type_of(item[1]) == NetProtocol.Message.EVENT:
			reliable_order.append(NetProtocol.unpack_values(item[1])[0])
	var expected_order: Array = range(200)
	_check("Fake loss drops about its share of unreliable packets (50%: 70 to 130 of 200 arrive)",
			unreliable >= 70 and unreliable <= 130, "%d arrived, %d dropped" % [unreliable, first.packets_dropped])
	_check("Reliable packets are never dropped and stay in order, even with jitter", reliable_order == expected_order,
			"%d arrived" % reliable_order.size())
	first.fake_loss = 0.0
	first.fake_jitter_ms = 0.0
	host.packet_received.disconnect(host_listener)
	first.packet_received.disconnect(first_listener)
	second.packet_received.disconnect(second_listener)


func _roster(session: NetSession) -> Array:
	return session.get_players().map(func(entry: Dictionary) -> Array: return [entry["peer_id"], entry["name"], entry["team"]])


func _check(description: String, passed: bool, detail: String) -> void:
	if passed:
		print("PASS  ", description)
	else:
		_failures += 1
		print("FAIL  ", description, "  (", detail, ")")
