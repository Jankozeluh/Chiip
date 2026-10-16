class_name NetSession
extends Node
## One online session (M9, D-100 to D-102): hosting a game or being connected to one, the
## roster of who is in it, and the packets of the game stream.
##
## [b]Hosting and joining.[/b] [method host_game] opens a UDP port (26000 by default, Quake's)
## with Godot's ENet peer; [method join_game] connects to a host by IP. Godot's high-level
## multiplayer gives every computer in the session a *peer id*: the host is always 1, every
## client gets a random number. This node talks through its own [member Node.multiplayer]
## (the [SceneMultiplayer] of its branch of the tree): the game's single one in a real game, or
## one per side in the network tests, which run a host and clients in one process (D-111).
##
## [b]The roster[/b] is the host's list of players (peer id, name, team, in join order). Clients
## say hello with their name; the host answers everyone with the whole roster whenever it
## changes. These session messages are RPCs: functions marked [code]@rpc[/code] that one
## computer calls on another, like Unity's (Netcode) [code][ServerRpc][/code] and
## [code][ClientRpc][/code]. [code]"any_peer"[/code] functions may be called by clients
## and check who called them; [code]"authority"[/code] ones only by the host.
##
## [b]The game stream[/b] (commands, snapshots, events) is not RPCs but raw byte packets
## ([method send_packet], [signal packet_received]), packed by [NetProtocol] (D-101). Every
## received packet waits in a queue until the next physics tick (or later, with fake lag) and
## is handed out at the start of that tick, before any game code runs, so the game sees
## network input at a fixed point of its tick. [member fake_lag_ms] and [member fake_loss]
## make a connection worse on purpose, like CS's [code]net_fakelag[/code] and
## [code]net_fakeloss[/code]: they delay every received packet and drop some of the unreliable
## ones. The delay is counted in physics ticks, so headless tests repeat exactly.
##
## The session survives scene changes: [method open] adds it to the root of the tree, next to
## the current scene, and [method close] frees it. It is not an autoload, because tools and the
## one-process tests can't use one (D-102); [code]main.gd[/code] hands it to the nodes that need it.

## What this computer is in the session.
enum Role {
	## Runs the game; peer id 1.
	HOST,
	## Connected to a host.
	CLIENT,
}

## Emitted on a client once the host has accepted it and sent the roster.
signal joined
## Emitted on a client when connecting failed or the host refused it. [param reason] is for people.
signal join_failed(reason: String)
## Emitted whenever the roster changed (someone joined, left, renamed or changed team).
signal roster_changed
## Emitted on the host when a client has said hello and is in the roster.
signal player_joined(peer_id: int)
## Emitted on the host when a client left or lost the connection, after the roster dropped it.
signal player_left(peer_id: int)
## Emitted once when the session ends: [method close], the host leaving, or a lost
## connection. [param reason] is for people ("" when you left yourself).
signal closed(reason: String)
## Emitted for every packet of the game stream, at the start of the physics tick it is due
## in. [param peer_id] is the sender (1 is the host).
signal packet_received(peer_id: int, packet: PackedByteArray)
## Emitted on every computer when the host sends a message for the match itself (starting
## it, the lobby's settings): [param data] is whatever the host passed to [method send_to_all].
signal match_message(data: Dictionary)

## The port a host listens on unless told otherwise (Quake's).
const DEFAULT_PORT := 26000
## Players besides the host: 5v5 at most.
const MAX_CLIENTS := 9
## Names are cut to this many characters.
const MAX_NAME_LENGTH := 16
## Reliable game-stream packets and session messages travel on this ENet channel, unreliable
## ones on the next, so a lost snapshot never holds up a kill event behind it.
const RELIABLE_CHANNEL := 0
const UNRELIABLE_CHANNEL := 1
## Seconds without an answer before ENet drops a connection (between these bounds).
const TIMEOUT_MIN_MS := 3000
const TIMEOUT_MAX_MS := 8000
## The node's name at the tree root.
const NODE_NAME := "NetSession"
## Seconds the host waits after telling the clients it is leaving, before it closes the connections.
const GOODBYE_TIME := 0.2

## Host or client. Read-only for other scripts.
var role: Role = Role.HOST
## This computer's peer id: 1 on the host. 0 until connected.
var local_peer_id: int = 0
## The name this computer plays under (as the host made it unique).
var local_name: String = ""
## Fake lag: every received packet waits this many milliseconds longer (0 = off).
## Counted in physics ticks at [member Engine.physics_ticks_per_second].
var fake_lag_ms: float = 0.0
## Extra random lag, 0 to this many milliseconds, per packet (0 = off). Unreliable packets
## can overtake each other then, as on a real connection; reliable ones keep their order.
var fake_jitter_ms: float = 0.0
## Fake loss: the share (0 to 1) of received unreliable packets that are dropped.
var fake_loss: float = 0.0
## Randomness for fake loss and jitter. Seed it for repeatable tests.
var rng := RandomNumberGenerator.new()
## The host's limit of players per team ([team 0, team 1]; 0 = no limit): a full team refuses
## one more. The lobby sets it from the match's team sizes ([method NetLobby.publish]).
var team_limits: Array[int] = [0, 0]

## Peer id → {"name": String, "team": int}. The host's copy decides; clients get copies.
var _players: Dictionary = {}
## Peer ids in the order they joined (the host first).
var _order: Array[int] = []
## Received game-stream packets waiting for their tick: [due_tick, arrival number, peer_id, packet].
var _inbox: Array = []
## Counts arrivals, so packets due in the same tick keep their order (sorting isn't stable).
var _arrivals: int = 0
## The physics ticks this session has run, for fake lag.
var _tick: int = 0
## The latest due tick given to a reliable packet, so reliable packets stay in order.
var _last_reliable_due: int = 0
## True once [signal closed] has been emitted.
var _closed: bool = false
## True on a client between connecting and the host's roster.
var _waiting_for_roster: bool = false
## True once [method close] was called.
var _closing: bool = false
## The connection this session made (the tree's multiplayer may have a newer one by the time this
## session finishes closing).
var _peer: MultiplayerPeer
## Why the host is ending the session, once it said so.
var _closing_reason: String = ""
## Packets sent and received, and their bytes, for the status line and the tests.
var packets_sent: int = 0
var packets_received: int = 0
var bytes_sent: int = 0
var bytes_received: int = 0
## Packets fake loss dropped.
var packets_dropped: int = 0


## Creates a session node and adds it to the root of the tree (next to the current scene, so
## it survives scene changes). [param parent] puts it somewhere else instead: a test side.
static func open(tree: SceneTree, parent: Node = null) -> NetSession:
	var session := NetSession.new()
	session.name = NODE_NAME
	(parent if parent != null else tree.root).add_child(session)
	return session


func _init() -> void:
	# The stream must be read before the game's own physics code in every tick.
	process_physics_priority = -1000
	# Online games never pause (D-109), but the session must not stop even if something does.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(_on_peer_packet)


func _exit_tree() -> void:
	if not _closed:
		_shut_down("")


## Starts hosting on [param port] as [param player_name]. Returns OK, or the error (for
## example [constant ERR_CANT_CREATE] when the port is taken).
func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_CLIENTS, 2, 0, 0)
	if result != OK:
		return result
	# No bandwidth limit, said out loud: without this call ENet's bandwidth throttle cut the
	# unreliable packets to 1 in 32 in the tests (D-103).
	peer.host.bandwidth_limit(0, 0)
	role = Role.HOST
	_peer = peer
	multiplayer.multiplayer_peer = peer
	# Clients never talk to each other through the host, so Godot needn't relay anything.
	(multiplayer as SceneMultiplayer).server_relay = false
	local_peer_id = 1
	local_name = _clean_name(player_name)
	_players.clear()
	_order.clear()
	_add_player(1, local_name, 0)
	roster_changed.emit()
	return OK


## Connects to the host at [param address] (an IP or a host name) as [param player_name].
## Returns OK when the attempt started; [signal joined] or [signal join_failed] follows.
func join_game(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port, 2, 0, 0)
	if result != OK:
		return result
	peer.host.bandwidth_limit(0, 0)
	role = Role.CLIENT
	_peer = peer
	multiplayer.multiplayer_peer = peer
	local_name = _clean_name(player_name)
	_waiting_for_roster = true
	return OK


## Leaves the session (a client) or ends it for everyone (the host), and frees this node. The
## host tells the clients first and gives the message [constant GOODBYE_TIME] seconds to get
## out before it closes the connections, so they can say "The host ended the game" instead of a
## lost connection. [method is_active] is false from the call on.
func close() -> void:
	if _closing:
		return
	_closing = true
	if not _closed and is_host() and _order.size() > 1 and is_inside_tree():
		_rpc_closing.rpc("The host ended the game.")
		_flush()
		# The name is free at once: a new session can be opened while this one says goodbye.
		name = NODE_NAME + "Closing"
		await get_tree().create_timer(GOODBYE_TIME, true, false, true).timeout
	if not _closed:
		_shut_down("")
	queue_free()


## The host only: sends [param data] to the client [param peer_id] alone (it arrives as
## [signal match_message] there). Used to send a late joiner the match that is being played.
func send_to(peer_id: int, data: Dictionary) -> void:
	if is_host() and _players.has(peer_id):
		_rpc_match_message.rpc_id(peer_id, data)


## The host only: refuses [param peer_id] with [param reason] (it goes back to the menu and
## shows it) and drops the connection.
func kick(peer_id: int, reason: String) -> void:
	if not is_host() or peer_id == 1:
		return
	_rpc_refused.rpc_id(peer_id, reason)
	_flush()
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null and peer.get_peer(peer_id) != null:
		# ENet sends what is queued (the refusal) before it disconnects.
		peer.get_peer(peer_id).peer_disconnect_later()
	elif multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


## True on the host.
func is_host() -> bool:
	return role == Role.HOST


## True while the session is up: hosting, or connected and accepted.
func is_active() -> bool:
	return not _closed and not _closing and local_peer_id != 0 and not _waiting_for_roster


## The players in join order (the host first): each a Dictionary with
## [code]peer_id[/code], [code]name[/code] and [code]team[/code].
func get_players() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for peer_id in _order:
		var entry: Dictionary = _players[peer_id].duplicate()
		entry["peer_id"] = peer_id
		list.append(entry)
	return list


## The roster entry of [param peer_id] (see [method get_players]), or an empty Dictionary.
func get_player(peer_id: int) -> Dictionary:
	if not _players.has(peer_id):
		return {}
	var entry: Dictionary = _players[peer_id].duplicate()
	entry["peer_id"] = peer_id
	return entry


## The team [param peer_id] plays on (0 or 1), or -1 if it isn't in the roster.
func get_team(peer_id: int) -> int:
	return _players[peer_id]["team"] if _players.has(peer_id) else -1


## Asks to play on [param team]. The host decides (it refuses a team that is full, see
## [member team_limits]) and sends everyone the new roster.
func request_team(team: int) -> void:
	if is_host():
		_set_team(1, team, true)
	else:
		_rpc_request_team.rpc_id(1, team)


## The host only: puts [param peer_id] on [param team] and tells everyone (even when full).
func set_player_team(peer_id: int, team: int) -> void:
	if is_host():
		_set_team(peer_id, team, false)


## The host only: sends [param data] to every client (and emits [signal match_message] here
## too), reliably and in order with the roster. Used to start a match and for the lobby's settings.
func send_to_all(data: Dictionary) -> void:
	if not is_host():
		return
	_rpc_match_message.rpc(data)
	match_message.emit(data)


## A client only: sends [param data] to the host, which emits [signal match_message] with it
## and the sender in [code]data["from"][/code]. Used for "I have loaded the map".
func send_to_host(data: Dictionary) -> void:
	if is_host():
		return
	_rpc_message_to_host.rpc_id(1, data)


## Sends a game-stream packet to [param peer_id] (0: every other computer). [param reliable]
## packets arrive, in order; unreliable ones may be lost or overtaken (snapshots, commands).
func send_packet(peer_id: int, packet: PackedByteArray, reliable: bool) -> void:
	if _closed or multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	var result := (multiplayer as SceneMultiplayer).send_bytes(packet, peer_id, mode,
			RELIABLE_CHANNEL if reliable else UNRELIABLE_CHANNEL)
	if result == OK:
		var copies := _order.size() - 1 if peer_id == 0 and is_host() else 1
		packets_sent += copies
		bytes_sent += packet.size() * copies


## The round-trip time to [param peer_id] (the host, from a client) in milliseconds, as ENet
## measures it, without fake lag. -1 when unknown (another transport: [NetClient] measures its own).
func get_ping_ms(peer_id: int = 1) -> int:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return -1
	var packet_peer := peer.get_peer(peer_id)
	if packet_peer == null:
		return -1
	return int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## The physics ticks the fake lag adds to a packet.
func fake_lag_ticks() -> int:
	return roundi(fake_lag_ms * Engine.physics_ticks_per_second / 1000.0)


func _physics_process(_delta: float) -> void:
	_tick += 1
	if _inbox.is_empty():
		return
	# Hand out what is due, oldest first. Packets of one tick keep their order of arrival.
	var due: Array = []
	var waiting: Array = []
	for item: Array in _inbox:
		(due if item[0] <= _tick else waiting).append(item)
	_inbox = waiting
	due.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for item: Array in due:
		if _closed:
			return
		packet_received.emit(item[2], item[3])


# --- Connection events ---


func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	_configure_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host() or not _players.has(peer_id) or _closed or _closing:
		return
	_players.erase(peer_id)
	_order.erase(peer_id)
	_send_roster()
	player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_configure_peer(1)
	_rpc_hello.rpc_id(1, local_name, NetProtocol.VERSION)


func _on_connection_failed() -> void:
	_waiting_for_roster = false
	join_failed.emit("Couldn't reach the host.")
	_shut_down("Couldn't reach the host.")


func _on_server_disconnected() -> void:
	if _waiting_for_roster:
		_waiting_for_roster = false
		join_failed.emit(_closing_reason if _closing_reason != "" else "The host closed the connection.")
	_shut_down(_closing_reason if _closing_reason != "" else "The connection to the host was lost.")


func _on_peer_packet(peer_id: int, packet: PackedByteArray) -> void:
	if _closed or packet.is_empty():
		return
	packets_received += 1
	bytes_received += packet.size()
	var reliable := NetProtocol.is_reliable(packet)
	if not reliable and fake_loss > 0.0 and rng.randf() < fake_loss:
		packets_dropped += 1
		return
	var lag := fake_lag_ticks()
	if fake_jitter_ms > 0.0:
		lag += rng.randi_range(0, roundi(fake_jitter_ms * Engine.physics_ticks_per_second / 1000.0))
	var due := _tick + 1 + lag
	if reliable:
		due = maxi(due, _last_reliable_due)
		_last_reliable_due = due
	_arrivals += 1
	_inbox.append([due, _arrivals, peer_id, packet])


# --- Session messages (RPCs) ---


## A client introduces itself: its name and the protocol version it speaks.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(player_name: String, version: int) -> void:
	if not is_host():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if version != NetProtocol.VERSION:
		_rpc_refused.rpc_id(peer_id, "The host runs a different version of Chiip.")
		return
	if _players.has(peer_id):
		return
	_add_player(peer_id, _unique_name(_clean_name(player_name)), _smaller_team())
	_send_roster()
	player_joined.emit(peer_id)


## The host refuses a client (another version, a full game). The client gives up.
@rpc("authority", "call_remote", "reliable")
func _rpc_refused(reason: String) -> void:
	if _waiting_for_roster:
		_waiting_for_roster = false
		join_failed.emit(reason)
	_shut_down(reason)


## The host is about to end the session: the reason replaces "the connection was lost".
@rpc("authority", "call_remote", "reliable")
func _rpc_closing(reason: String) -> void:
	_closing_reason = reason


## The host's whole roster: [peer_id, name, team] for each player, in join order.
@rpc("authority", "call_remote", "reliable")
func _rpc_roster(entries: Array) -> void:
	_players.clear()
	_order.clear()
	for entry: Array in entries:
		_add_player(int(entry[0]), String(entry[1]), int(entry[2]))
	if _players.has(local_peer_id):
		local_name = _players[local_peer_id]["name"]
	roster_changed.emit()
	if _waiting_for_roster:
		_waiting_for_roster = false
		joined.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_team(team: int) -> void:
	if is_host():
		_set_team(multiplayer.get_remote_sender_id(), team, true)


@rpc("authority", "call_remote", "reliable")
func _rpc_match_message(data: Dictionary) -> void:
	match_message.emit(data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_message_to_host(data: Dictionary) -> void:
	if not is_host():
		return
	var message := data.duplicate()
	message["from"] = multiplayer.get_remote_sender_id()
	match_message.emit(message)


# --- Helpers ---


## Sets up the ENet connection to [param peer_id]: a dropped connection is noticed within
## seconds instead of ENet's default half a minute, and ENet never drops unreliable packets on
## its own. Its *throttle* would drop some whenever the round trip time wobbles (together with
## [method ENetConnection.bandwidth_limit] at creation, D-103); the game stream repeats what
## matters itself, so a dropped command packet only costs, never helps.
## Sends what is queued now, before closing a connection (so a last message gets out first).
func _flush() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null and peer.host != null:
		peer.host.flush()


func _configure_peer(peer_id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or peer.get_peer(peer_id) == null:
		return
	var packet_peer := peer.get_peer(peer_id)
	packet_peer.set_timeout(32, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
	packet_peer.throttle_configure(5000, 2, 0)


func _add_player(peer_id: int, player_name: String, team: int) -> void:
	_players[peer_id] = {"name": player_name, "team": team}
	if not _order.has(peer_id):
		_order.append(peer_id)


func _send_roster() -> void:
	var entries: Array = []
	for peer_id in _order:
		entries.append([peer_id, _players[peer_id]["name"], _players[peer_id]["team"]])
	_rpc_roster.rpc(entries)
	roster_changed.emit()


func _set_team(peer_id: int, team: int, limited: bool) -> void:
	if not _players.has(peer_id) or team < 0 or team >= Teams.COUNT or _players[peer_id]["team"] == team:
		return
	if limited and team_limits[team] > 0 and _team_count(team) >= team_limits[team]:
		return
	_players[peer_id]["team"] = team
	_send_roster()


func _team_count(team: int) -> int:
	return _order.filter(func(peer_id: int) -> bool: return _players[peer_id]["team"] == team).size()


## The team with fewer players (team 0 on a tie): where a newcomer goes first, unless it is full
## and the other one isn't.
func _smaller_team() -> int:
	var team := 1 if _team_count(1) < _team_count(0) else 0
	var other := Teams.other(team)
	if team_limits[team] > 0 and _team_count(team) >= team_limits[team] and (team_limits[other] == 0 or _team_count(other) < team_limits[other]):
		return other
	return team


## A name for people and for a node: trimmed, at most [constant MAX_NAME_LENGTH] characters,
## without the characters node names can't have, and never empty or a bot's name ("Bot3").
static func _clean_name(text: String) -> String:
	var clean := text.strip_edges().validate_node_name().replace("%", "").left(MAX_NAME_LENGTH).strip_edges()
	if clean.is_empty():
		clean = "Player"
	var bot_name := RegEx.create_from_string("^Bot[0-9]+$")
	if bot_name.search(clean) != null:
		clean = "Player " + clean
	return clean.left(MAX_NAME_LENGTH)


## [param wanted], or with a number after it when someone has that name already ("Jan 2").
func _unique_name(wanted: String) -> String:
	var taken: Array[String] = []
	for peer_id in _order:
		taken.append(_players[peer_id]["name"])
	if not taken.has(wanted):
		return wanted
	var number := 2
	while taken.has("%s %d" % [wanted.left(MAX_NAME_LENGTH - 3), number]):
		number += 1
	return "%s %d" % [wanted.left(MAX_NAME_LENGTH - 3), number]


func _shut_down(reason: String) -> void:
	if _closed:
		return
	_closed = true
	_inbox.clear()
	if _peer != null:
		_peer.close()
	# Only this session's own connection: a newer session may already have put its own in place.
	if multiplayer != null and _peer != null and multiplayer.multiplayer_peer == _peer:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_peer = null
	closed.emit(reason)
