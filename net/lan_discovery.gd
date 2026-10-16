class_name LanDiscovery
extends Node
## Finds games on the local network without typing an IP (M17, D-242): a host *advertises* with a
## small UDP beacon, the Join page *listens* and lists what it hears. One node does both jobs
## (a plain node, no autoload: tools and tests can't use one, D-102), each switched on by its own call.
##
## [b]Host side.[/b] [method advertise] sends a beacon every [constant BEACON_INTERVAL] second to
## [member broadcast_address] (255.255.255.255, "everyone on this network") at [member port], and
## [method update] changes what it says (and sends at once); [method stop_advertising] ends it.
## With the default address the beacon also goes to the directed broadcast of each of this computer's
## networks ([method broadcast_targets]: 192.168.1.71 → 192.168.1.255, a /24 network assumed), because
## macOS refuses 255.255.255.255 on some setups ("No route to host", seen on the development Mac) and
## a computer with several network cards sends the limited broadcast out of one only. A beacon that
## arrives twice (by both addresses) is one game: it is listed by sender and game port.
## [NetLobby] does this for a hosting session, so the beacon lives and dies with the session.
## The beacon is one JSON object, at most [constant MAX_PACKET_BYTES] bytes, UTF-8:
## [codeblock]
## {"game":"chiip","ver":2,"name":"Jan","port":26000,"mode":"tdm","map":"Depot","players":2,"max":6,"state":"lobby"}
## [/codeblock]
## [code]game[/code] is the magic word ([constant MAGIC]); [code]ver[/code] the protocol version
## [constant NetProtocol.VERSION] (the same number the session's hello checks, so the list can mark
## a game "other version"); [code]name[/code] the host's name; [code]port[/code] the game's
## port (the ENet one, [constant NetSession.DEFAULT_PORT] by default; not this node's);
## [code]mode[/code] "tdm" (team deathmatch), "ffa" or "rounds" (bomb); [code]map[/code] its title;
## [code]players[/code] / [code]max[/code] the people in the lobby out of the match's slots;
## [code]state[/code] "lobby" or "match" (a match is running; the host takes latecomers anyway, D-110).
## The info [method advertise] takes is a Dictionary with [code]name[/code], [code]port[/code],
## [code]mode[/code], [code]map[/code], [code]players[/code], [code]max_players[/code] and
## [code]in_game[/code] (optionally [code]version[/code], for tests).
##
## [b]Browser side.[/b] [method listen] binds [member port] and [method _process] collects the
## beacons; [method get_games] lists them (the address is the one the packet came from), an entry
## expires [constant GAME_TTL] seconds after its last beacon, and [signal games_changed] says when
## the list changed (a game appeared, changed or expired; a beacon that only repeats is silent).
## [method listen] answers an error instead of crashing when the port is taken (a second Chiip on
## the same computer holds it): the Join page then says so and Recent and Join by IP still work.
##
## [b]Nothing on the network is trusted[/b] ([method parse_beacon]): a packet over
## [constant MAX_PACKET_BYTES], not JSON, not an object, with the wrong magic word or a field of
## the wrong type or range is dropped; names and maps are cut to plain printable text
## ([PlainText]); the game's port must be 1024 to 65535; at most [constant MAX_GAMES] games are
## listed and at most [constant MAX_GAMES_PER_ADDRESS] per sender; and a frame reads at most
## [constant MAX_PACKETS_PER_FRAME] packets, so a flood of beacons costs a bounded amount of work.
## Times count in [method Node._process] deltas (not the clock), like the rest of the game.

## Emitted when the list [method get_games] returns changed.
signal games_changed

## The UDP port beacons are sent to and heard on: next to [constant NetSession.DEFAULT_PORT].
const DISCOVERY_PORT := 26001
## The first field of every beacon.
const MAGIC := "chiip"
## The address a beacon is sent to: every computer on the local network.
const BROADCAST_ADDRESS := "255.255.255.255"
## Seconds between two beacons of a host.
const BEACON_INTERVAL := 1.0
## Seconds a listed game stays after its last beacon (three missed beacons).
const GAME_TTL := 3.5
## A beacon is at most this many bytes; a bigger packet is dropped unread.
const MAX_PACKET_BYTES := 512
## The list holds at most this many games, and this many from one address.
const MAX_GAMES := 32
const MAX_GAMES_PER_ADDRESS := 4
## Packets read in one frame; the rest wait for the next one.
const MAX_PACKETS_PER_FRAME := 64
## A map title is cut to this many characters, a mode id to the second.
const MAX_MAP_LENGTH := 32
const MAX_MODE_LENGTH := 8
## The most people a game can hold (the host and [constant NetSession.MAX_CLIENTS] clients).
const MAX_PLAYERS := NetSession.MAX_CLIENTS + 1
## What the settings' match modes are called in a beacon.
const MODE_IDS := {"respawn": "tdm", "ffa": "ffa", "rounds": "rounds"}
## The values of a beacon's [code]state[/code].
const STATE_LOBBY := "lobby"
const STATE_MATCH := "match"

## The port every new instance uses. Tests set it to their own block of ports (see
## [code]tests/net_harness.gd[/code]), so a test never sends beacons to a real game's port.
static var default_port: int = DISCOVERY_PORT

## The UDP port to send beacons to and to listen on.
var port: int = default_port
## Where beacons are sent: the whole network by default (and then also to each network's directed
## broadcast, see [method broadcast_targets]); a test sends to 127.0.0.1 alone.
var broadcast_address: String = BROADCAST_ADDRESS
## Seconds between beacons, and how long a game stays listed after its last one.
var beacon_interval: float = BEACON_INTERVAL
var game_ttl: float = GAME_TTL
## Packets taken and dropped since [method listen] (for the tests and the logs).
var packets_accepted: int = 0
var packets_ignored: int = 0
## The most packets one frame read, since [method listen].
var most_read_in_a_frame: int = 0

var _sender: PacketPeerUDP
var _beacon: PackedByteArray = PackedByteArray()
var _beacon_timer: float = 0.0
var _listener: PacketPeerUDP
## "address:port" → the entry ([method get_games]) in the order games were first heard.
var _games: Dictionary = {}
## "address:port" → [member _clock] when the last beacon arrived.
var _seen: Dictionary = {}
var _clock: float = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _sender != null:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_send_beacon()
	if _listener != null:
		_read_packets()
	_expire_games()


func _exit_tree() -> void:
	stop_advertising()
	stop_listening()


# --- Host side ---


## Starts advertising a game ([param info]: see the class description) with a beacon now and one
## every [member beacon_interval] seconds. Returns OK, or [constant ERR_INVALID_DATA] when the
## info can't make a beacon that fits [constant MAX_PACKET_BYTES].
func advertise(info: Dictionary) -> Error:
	var bytes := build_beacon(info)
	if bytes.is_empty():
		return ERR_INVALID_DATA
	if _sender == null:
		_sender = PacketPeerUDP.new()
		# Without this the system refuses to send to the broadcast address.
		_sender.set_broadcast_enabled(true)
	_beacon = bytes
	_send_beacon()
	return OK


## Changes what the running advertisement says and sends a beacon at once. Returns
## [constant ERR_UNCONFIGURED] when nothing is being advertised.
func update(info: Dictionary) -> Error:
	if _sender == null:
		return ERR_UNCONFIGURED
	return advertise(info)


## Ends the advertisement. Friends' lists drop the game within [constant GAME_TTL] seconds.
func stop_advertising() -> void:
	if _sender != null:
		_sender.close()
		_sender = null
	_beacon = PackedByteArray()


## True while a beacon is being sent.
func is_advertising() -> bool:
	return _sender != null


# --- Browser side ---


## Starts listening for beacons on [member port]. Returns OK, or the error when the port can't be
## bound (another program, or a second game on this computer, holds it): the node then lists
## nothing and the caller says so. Calling it while listening does nothing.
func listen() -> Error:
	if _listener != null:
		return OK
	var peer := PacketPeerUDP.new()
	# IPv4 only: the beacons are IPv4 broadcasts, and the address shown to people is the sender's.
	var result := peer.bind(port, "0.0.0.0")
	if result != OK:
		return result
	_listener = peer
	packets_accepted = 0
	packets_ignored = 0
	most_read_in_a_frame = 0
	return OK


## Stops listening and forgets the games.
func stop_listening() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	if not _games.is_empty():
		_games.clear()
		_seen.clear()
		games_changed.emit()


## True while the port is bound.
func is_listening() -> bool:
	return _listener != null


## The games heard lately, in the order they were first heard: each a Dictionary with
## [code]address[/code] (where the beacon came from), [code]port[/code], [code]name[/code],
## [code]mode[/code] ("tdm", "ffa", "rounds"), [code]map[/code], [code]players[/code],
## [code]max_players[/code], [code]in_game[/code] (a match is running) and [code]version[/code]
## (compare with [constant NetProtocol.VERSION]). Copies: change nothing.
func get_games() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry: Dictionary in _games.values():
		list.append(entry.duplicate())
	return list


## What a mode of the settings ("respawn", "ffa", "rounds") is called in a beacon.
static func mode_id(match_mode: String) -> String:
	return MODE_IDS.get(match_mode, "tdm")


## The setting's match mode ("respawn", "ffa", "rounds") of a beacon's [param id], or "" for one
## this version doesn't know.
static func match_mode_of(id: String) -> String:
	for match_mode: String in MODE_IDS:
		if MODE_IDS[match_mode] == id:
			return match_mode
	return ""


## Where a beacon goes: [param main] (this node's [member broadcast_address]) and, when that is the
## limited broadcast [constant BROADCAST_ADDRESS], the directed broadcast of each IPv4 address in
## [param local_addresses] (this computer's by default): the address with its last number
## replaced by 255, a /24 network assumed. Loopback, link-local and Tailscale (100.64.0.0/10)
## addresses have no network to broadcast on and are skipped.
static func broadcast_targets(main: String = BROADCAST_ADDRESS, local_addresses: PackedStringArray = IP.get_local_addresses()) -> Array[String]:
	var targets: Array[String] = [main]
	if main != BROADCAST_ADDRESS:
		return targets
	for address in local_addresses:
		var parts := address.split(".")
		if parts.size() != 4 or address.contains(":") or not address.is_valid_ip_address():
			continue
		var first := int(parts[0])
		var second := int(parts[1])
		if first == 127 or first == 0 or (first == 169 and second == 254) or (first == 100 and second >= 64 and second <= 127):
			continue
		var directed := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not targets.has(directed):
			targets.append(directed)
	return targets


## The beacon for [param info] (see the class description): JSON as UTF-8 bytes. Texts are cut
## and the numbers kept in range. Empty when it wouldn't fit [constant MAX_PACKET_BYTES].
static func build_beacon(info: Dictionary) -> PackedByteArray:
	var players := clampi(int(info.get("players", 0)), 0, MAX_PLAYERS)
	var beacon := {
		"game": MAGIC,
		"ver": int(info.get("version", NetProtocol.VERSION)),
		"name": PlainText.clean(String(info.get("name", "")), NetSession.MAX_NAME_LENGTH),
		"port": clampi(int(info.get("port", NetSession.DEFAULT_PORT)), 0, 65535),
		"mode": PlainText.clean(String(info.get("mode", "")), MAX_MODE_LENGTH),
		"map": PlainText.clean(String(info.get("map", "")), MAX_MAP_LENGTH),
		"players": players,
		"max": clampi(int(info.get("max_players", MAX_PLAYERS)), maxi(players, 1), MAX_PLAYERS),
		"state": STATE_MATCH if bool(info.get("in_game", false)) else STATE_LOBBY,
	}
	var bytes := JSON.stringify(beacon).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_PACKET_BYTES else PackedByteArray()


## The game a beacon describes, as [method get_games] lists it (see there), or an empty Dictionary
## when the packet isn't a good beacon: too big, not JSON, not an object, the wrong magic word, a
## missing field, a field of the wrong type or out of range, a port outside 1024 to 65535, an
## empty name or mode. [param address] is where the packet came from (it must be an IP).
static func parse_beacon(packet: PackedByteArray, address: String) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES or not address.is_valid_ip_address():
		return {}
	# Every beacon starts with "{" (an object): anything else is dropped before it is parsed. A JSON
	# instance (not JSON.parse_string) because a failed parse_string logs an error: a flood would flood the log.
	if packet[0] != 0x7B:
		return {}
	var json := JSON.new()
	if json.parse(packet.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = json.data
	if typeof(data.get("game")) != TYPE_STRING or data["game"] != MAGIC:
		return {}
	var version: Variant = _whole_number(data.get("ver"), 0, 1000000)
	var game_port: Variant = _whole_number(data.get("port"), RecentHosts.MIN_PORT, RecentHosts.MAX_PORT)
	var players: Variant = _whole_number(data.get("players"), 0, MAX_PLAYERS)
	var max_players: Variant = _whole_number(data.get("max"), 1, MAX_PLAYERS)
	if version == null or game_port == null or players == null or max_players == null:
		return {}
	if typeof(data.get("name")) != TYPE_STRING or typeof(data.get("mode")) != TYPE_STRING \
			or typeof(data.get("map")) != TYPE_STRING or typeof(data.get("state")) != TYPE_STRING:
		return {}
	var state: String = data["state"]
	if state != STATE_LOBBY and state != STATE_MATCH:
		return {}
	var host_name := PlainText.clean(data["name"], NetSession.MAX_NAME_LENGTH)
	var mode := PlainText.clean(data["mode"], MAX_MODE_LENGTH)
	if host_name.is_empty() or mode.is_empty():
		return {}
	return {
		"address": address,
		"port": game_port,
		"name": host_name,
		"mode": mode,
		"map": PlainText.clean(data["map"], MAX_MAP_LENGTH),
		"players": players,
		"max_players": maxi(max_players, players),
		"in_game": state == STATE_MATCH,
		"version": version,
	}


## [param value] as an int when it is a whole number between [param low] and [param high] (JSON
## gives every number as a float), else null.
static func _whole_number(value: Variant, low: int, high: int) -> Variant:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null
	var number := float(value)
	if not is_finite(number) or number != floorf(number) or number < low or number > high:
		return null
	return int(number)


func _send_beacon() -> void:
	_beacon_timer = beacon_interval
	if _sender == null or _beacon.is_empty():
		return
	# A target that can't be reached (macOS says "No route to host" to 255.255.255.255 sometimes) costs nothing.
	for target in broadcast_targets(broadcast_address):
		if _sender.set_dest_address(target, port) == OK:
			_sender.put_packet(_beacon)


## Reads what has arrived, at most [constant MAX_PACKETS_PER_FRAME] packets.
func _read_packets() -> void:
	var waiting := _listener.get_available_packet_count()
	var reading := mini(waiting, MAX_PACKETS_PER_FRAME)
	most_read_in_a_frame = maxi(most_read_in_a_frame, reading)
	for i in reading:
		var packet := _listener.get_packet()
		var entry := parse_beacon(packet, _listener.get_packet_ip())
		if entry.is_empty():
			packets_ignored += 1
			continue
		packets_accepted += 1
		_take(entry)


## Lists [param entry] (or updates the one from the same address and port) and notes the time.
func _take(entry: Dictionary) -> void:
	var key := "%s:%d" % [entry["address"], entry["port"]]
	if _games.has(key):
		_seen[key] = _clock
		if (_games[key] as Dictionary).hash() != entry.hash():
			_games[key] = entry
			games_changed.emit()
		return
	if _games.size() >= MAX_GAMES:
		return
	var from_address := 0
	for other: Dictionary in _games.values():
		if other["address"] == entry["address"]:
			from_address += 1
	if from_address >= MAX_GAMES_PER_ADDRESS:
		return
	_games[key] = entry
	_seen[key] = _clock
	games_changed.emit()


func _expire_games() -> void:
	var gone := false
	for key: String in _games.keys():
		if _clock - float(_seen[key]) > game_ttl:
			_games.erase(key)
			_seen.erase(key)
			gone = true
	if gone:
		games_changed.emit()
