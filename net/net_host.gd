class_name NetHost
extends Node
## The host's side of an online match (M9, D-100, D-103, D-104): the friends' characters, their
## commands, and what every client is told.
##
## The host plays the single-player game as it is: the map, its [RoundManager] (or
## [RespawnMatch]), the [Bomb], the bots and the host's own player. This node adds what an
## online match needs on top:
## - **The friends' characters.** One per client in the roster, on its team, named after the
##   player, driven by a [NetworkController]. They join the match before the bots fill the rest
##   of each team ([member RoundManager.extra_players]). The match starts when every client has
##   loaded the map (or after [constant LOAD_TIMEOUT] seconds).
## - **Commands** (D-103). Each client's packets carry its unconfirmed commands; the controller
##   keeps the new ones, and every tick (before anyone else moves) this node runs each waiting
##   command once with [method Character.step], within the controller's budget.
## - **Events** (D-104), reliable and in order: the match's phases and results, kills, damage,
##   respawns, class changes and (at most 4 times a second, when they changed) the scoreboard.
##   A client that finishes loading gets a [constant NetProtocol.Event.WELCOME] with everything
##   first, so a late one misses nothing.
## - **Snapshots** (D-104), 64 a second, at the end of every second tick, when everyone has
##   moved: every character, the round's clock, the bomb, and the shots and reloads of the last
##   few ticks. Each client's copy also has its own character at full precision and the number
##   of its last command run.
## - **Lag compensation** (D-107): at the end of every tick the hit zones are recorded
##   ([LagCompensation]), and the friends' shots are checked against them.
##
## [code]main.gd[/code] adds it to the map of an online match on the host, after the rules,
## and calls [method setup].

## Seconds to wait for every client to load the map before starting without them.
const LOAD_TIMEOUT := 15.0
## A snapshot every this many ticks (2: 64 a second at 128 Hz).
const SNAPSHOT_INTERVAL := 2
## Ticks between scoreboard updates (32: 4 a second).
const STATS_INTERVAL := 32
## Ticks a cosmetic effect (a shot, a reload) is repeated in the snapshots: three snapshots.
const EFFECT_TICKS := 6
## The scene of a friend's character: a bot without its brain (D-110: a bot can take it over).
const PLAYER_SCENE := preload("res://bots/bot.tscn")

## Emitted once the match has started (every client loaded, or the wait ran out).
signal match_started

## The session of this match.
var session: NetSession
## The map, its rules and the host's own player.
var map: Node
var rules: RoundManager
var player: Character
## Host ticks since the match began (snapshots and lag compensation count in them).
var tick: int = 0
## The hit-zone history for the friends' shots.
var lag_compensation := LagCompensation.new()

## Peer id → the friend's character.
var _characters_by_peer: Dictionary = {}
## Net id → character, for everyone in the match.
var _characters_by_id: Dictionary = {}
## Character → peer id (1 for the host's own player; bots aren't in it).
var _peers: Dictionary = {}
## Peer ids of the clients that loaded the map and got the welcome.
var _ready_peers: Array[int] = []
## Peer ids of the clients that loaded the map (they get the welcome once the match started).
var _loaded_peers: Array[int] = []
## Seconds since setup while waiting for the clients to load.
var _waiting: float = 0.0
var _started: bool = false
var _next_net_id: int = 1
## Cosmetic effects of the last few ticks: [sequence, Effect, net id, position, tick made].
var _effects: Array = []
var _effect_sequence: int = 0
## Character → where its last bullet landed this tick (from [signal Weapon.hit_landed]).
var _landed: Dictionary = {}
var _stats_dirty: bool = false
var _late: _LateTick


## Runs at the end of every tick, after everyone has moved: records the hit zones and sends
## the snapshots.
class _LateTick extends Node:
	var host: NetHost

	func _init() -> void:
		process_physics_priority = 1000

	func _physics_process(_delta: float) -> void:
		host._end_of_tick()


func _init() -> void:
	name = "NetHost"
	# Before every character: the friends' commands of this tick run first.
	process_physics_priority = -100


## Sets the match up: the friends' characters join [param game_rules] on [param game_map],
## next to the host's [param own_player]. Call it right after the rules were added.
func setup(game_session: NetSession, game_map: Node, game_rules: RoundManager, own_player: Character) -> void:
	session = game_session
	map = game_map
	rules = game_rules
	player = own_player
	_late = _LateTick.new()
	_late.name = "NetHostLate"
	_late.host = self
	add_child(_late)
	if player != null:
		player.name = session.local_name
		_peers[player] = 1
	for entry in session.get_players():
		var peer_id: int = entry["peer_id"]
		if peer_id != 1:
			_add_friend(peer_id, entry["name"], entry["team"])
	session.packet_received.connect(_on_packet)
	session.match_message.connect(_on_match_message)
	_connect_rules()


func _exit_tree() -> void:
	if session != null and is_instance_valid(session):
		if session.packet_received.is_connected(_on_packet):
			session.packet_received.disconnect(_on_packet)
		if session.match_message.is_connected(_on_match_message):
			session.match_message.disconnect(_on_match_message)


## True once the match has started.
func is_started() -> bool:
	return _started


## The character of the friend with [param peer_id], or null.
func get_character_of(peer_id: int) -> Character:
	return _characters_by_peer.get(peer_id)


## The character with network id [param net_id], or null.
func get_character(net_id: int) -> Character:
	return _characters_by_id.get(net_id)


## The peer ids of the clients that are in the match (loaded and welcomed).
func get_ready_peers() -> Array[int]:
	return _ready_peers.duplicate()


## Starts the match now, without waiting for the clients still loading.
func start_now() -> void:
	if _started:
		return
	_started = true
	rules.start()
	for character in rules.get_participants():
		_register(character)
	for peer_id in _loaded_peers:
		_welcome(peer_id)
	match_started.emit()


func _physics_process(delta: float) -> void:
	if not _started:
		_waiting += delta
		var everyone_loaded := true
		for entry in session.get_players():
			if entry["peer_id"] != 1 and not _loaded_peers.has(entry["peer_id"]):
				everyone_loaded = false
		if everyone_loaded or _waiting >= LOAD_TIMEOUT:
			start_now()
		return
	# Each friend's waiting commands, oldest first, once each (D-103).
	for peer_id: int in _characters_by_peer:
		var character: Character = _characters_by_peer[peer_id]
		if not is_instance_valid(character):
			continue
		var controller := character.get_controller() as NetworkController
		if controller == null:
			continue
		controller.add_tick()
		var command := controller.next_command()
		while command != null:
			character.step(command, delta)
			command = controller.next_command()


func _end_of_tick() -> void:
	if not _started:
		return
	tick += 1
	lag_compensation.record(tick, _all_characters())
	var oldest := tick - EFFECT_TICKS
	while not _effects.is_empty() and _effects[0][4] <= oldest:
		_effects.pop_front()
	if _stats_dirty and tick % STATS_INTERVAL == 0:
		_stats_dirty = false
		_broadcast([NetProtocol.Event.STATS, _stats_list()])
	if tick % SNAPSHOT_INTERVAL == 0:
		_send_snapshots()


# --- Characters ---


## A friend's character: the bot scene without its brain, with a [NetworkController], stepped
## by this node and checked by lag compensation. It joins the match before the bots.
func _add_friend(peer_id: int, player_name: String, team: int) -> Character:
	var character := make_player_character(PLAYER_SCENE)
	var controller := NetworkController.new()
	controller.name = "NetworkController"
	controller.peer_id = peer_id
	character.add_child(controller)
	character.name = player_name
	character.team = team
	character.manual = true
	character.lag_compensation = lag_compensation
	map.add_child(character)
	character.weapon.manual = true
	# Out of the way until the first round puts it on a spawn.
	character.global_position = Vector3(0.0, -100.0, 0.0)
	rules.extra_players.append(character)
	_characters_by_peer[peer_id] = character
	_peers[character] = peer_id
	return character


## The bot scene [param scene] instantiated without its brain (the [BotController] and its
## senses), for a network player: its controller is added by the caller. The navigation agent
## stays, so a bot can take the character over later (D-110).
static func make_player_character(scene: PackedScene) -> Character:
	var character := scene.instantiate() as Character
	for node_name in ["BotController", "BotSenses"]:
		var node := character.get_node_or_null(node_name)
		if node != null:
			character.remove_child(node)
			node.free()
	return character


## Gives [param character] its network id and listens to what the clients must hear about it.
func _register(character: Character) -> void:
	if character.net_id == 0:
		character.net_id = _next_net_id
		_next_net_id += 1
	_characters_by_id[character.net_id] = character
	character.damaged.connect(_on_damaged.bind(character))
	character.died.connect(_on_died.bind(character))
	character.respawned.connect(_on_respawned.bind(character))
	if character.weapon != null:
		character.weapon.fired.connect(_on_fired.bind(character))
		character.weapon.hit_landed.connect(_on_hit_landed.bind(character))
		character.weapon.reload_started.connect(_on_reload_started.bind(character))


func _all_characters() -> Array[Character]:
	var list: Array[Character] = []
	for character in rules.get_participants():
		if is_instance_valid(character) and character.net_id != 0:
			list.append(character)
	return list


# --- Packets and messages ---


func _on_packet(peer_id: int, packet: PackedByteArray) -> void:
	match NetProtocol.type_of(packet):
		NetProtocol.Message.COMMANDS:
			var character: Character = _characters_by_peer.get(peer_id)
			if character == null:
				return
			var controller := character.get_controller() as NetworkController
			if controller != null:
				controller.receive(NetProtocol.unpack_commands(packet))
		NetProtocol.Message.REQUEST:
			_on_request(peer_id, NetProtocol.unpack_values(packet))


func _on_request(peer_id: int, values: Array) -> void:
	if values.is_empty():
		return
	var character: Character = _characters_by_peer.get(peer_id)
	match int(values[0]):
		NetProtocol.Request.CLASS:
			var classes := ClassData.all()
			if character != null and values.size() >= 2 and int(values[1]) >= 0 and int(values[1]) < classes.size():
				rules.request_class(character, classes[int(values[1])])


func _on_match_message(data: Dictionary) -> void:
	if data.get("loaded", false) and data.has("from"):
		var peer_id: int = data["from"]
		if not _loaded_peers.has(peer_id):
			_loaded_peers.append(peer_id)
		if _started:
			_welcome(peer_id)


## Everything a client needs to show the match: its own network id, every character, the
## match's state and the scoreboard.
func _welcome(peer_id: int) -> void:
	if _ready_peers.has(peer_id):
		return
	var own: Character = _characters_by_peer.get(peer_id)
	var entries: Array = []
	for character in _all_characters():
		entries.append(NetProtocol.character_entry(character, _peers.get(character, 0)))
	var respawn := rules as RespawnMatch
	var state := [rules.phase, rules.time_left, rules.round_number, rules.attacking_team,
			rules.score[0], rules.score[1], rules.winner, respawn != null and respawn.overtime]
	var health: Array = []
	for character in _all_characters():
		health.append([character.net_id, character.health])
	_ready_peers.append(peer_id)
	session.send_packet(peer_id, NetProtocol.pack_values(NetProtocol.Message.EVENT,
			[NetProtocol.Event.WELCOME, own.net_id if own != null else 0, entries, state, _stats_list(), health]), true)


func _broadcast(values: Array) -> void:
	var packet := NetProtocol.pack_values(NetProtocol.Message.EVENT, values)
	for peer_id in _ready_peers:
		session.send_packet(peer_id, packet, true)


func _send_snapshots() -> void:
	var body := StreamPeerBuffer.new()
	NetProtocol.write_snapshot_body(body, rules, _all_characters(), _effects)
	for peer_id in _ready_peers:
		var own: Character = _characters_by_peer.get(peer_id)
		var ack := 0
		if own != null and own.get_controller() is NetworkController:
			ack = (own.get_controller() as NetworkController).last_run
		session.send_packet(peer_id, NetProtocol.pack_snapshot(tick, own, ack, body.data_array), false)


func _stats_list() -> Array:
	var list: Array = []
	for character in _all_characters():
		var stats := rules.get_stats(character)
		if stats != null:
			list.append([character.net_id, stats.kills, stats.deaths, stats.assists, stats.damage])
	return list


# --- What the rules and the characters announce ---


func _connect_rules() -> void:
	rules.phase_changed.connect(_on_phase_changed)
	rules.round_started.connect(func(number: int) -> void: _broadcast([NetProtocol.Event.ROUND_STARTED, number]))
	rules.round_ended.connect(func(winner: int, reason: RoundManager.EndReason) -> void:
		_broadcast([NetProtocol.Event.ROUND_ENDED, winner, reason, rules.score[0], rules.score[1]]))
	rules.sides_swapped.connect(func() -> void: _broadcast([NetProtocol.Event.SIDES_SWAPPED, rules.attacking_team]))
	rules.match_ended.connect(func(winner: int) -> void:
		_broadcast([NetProtocol.Event.MATCH_ENDED, winner, rules.score[0], rules.score[1]]))
	rules.character_killed.connect(func(victim: Character, killer: Character, headshot: bool) -> void:
		_broadcast([NetProtocol.Event.KILLED, victim.net_id, killer.net_id if killer != null else 0, headshot]))
	rules.class_changed.connect(func(character: Character, data: ClassData) -> void:
		_broadcast([NetProtocol.Event.CLASS_CHANGED, character.net_id, ClassData.all().find(data)]))
	if rules is RespawnMatch:
		(rules as RespawnMatch).overtime_started.connect(func() -> void: _broadcast([NetProtocol.Event.OVERTIME]))


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	_broadcast([NetProtocol.Event.PHASE, phase, rules.time_left, rules.round_number, rules.attacking_team, rules.score[0], rules.score[1]])


func _on_damaged(amount: float, zone: Hitbox.Zone, attacker: Character, victim: Character) -> void:
	_stats_dirty = true
	_broadcast([NetProtocol.Event.DAMAGED, victim.net_id, amount, zone, attacker.net_id if attacker != null else 0, victim.health])


func _on_died(_killer: Character, _victim: Character) -> void:
	_stats_dirty = true


func _on_respawned(character: Character) -> void:
	_broadcast([NetProtocol.Event.RESPAWNED, character.net_id, character.global_position, character.rotation.y])


func _on_hit_landed(hit: Dictionary, character: Character) -> void:
	_landed[character] = hit["position"]


func _on_fired(_spray_shot: int, character: Character) -> void:
	_effect_sequence += 1
	if _landed.has(character):
		_effects.append([_effect_sequence, NetProtocol.Effect.SHOT_HIT, character.net_id, _landed[character], tick])
		_landed.erase(character)
	else:
		_effects.append([_effect_sequence, NetProtocol.Effect.SHOT_MISS, character.net_id, Vector3.ZERO, tick])


func _on_reload_started(character: Character) -> void:
	_effect_sequence += 1
	_effects.append([_effect_sequence, NetProtocol.Effect.RELOAD, character.net_id, Vector3.ZERO, tick])
