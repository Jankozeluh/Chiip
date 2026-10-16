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
## - **The arsenal** (D-113, M7): each friend's own inventory goes to them alone
##   ([constant NetProtocol.Event.INVENTORY]) whenever it changes; every character's weapon in hand
##   and armor ride in the snapshots; guns on the floor (every fourth snapshot) and grenades in
##   flight (every snapshot) too, as numbered world objects; a grenade going off and everyone it
##   blinds are events.
## - **Coming and going** (D-110). A friend who leaves or loses the connection is taken over by
##   a bot ([method hand_to_bot]): the character keeps its team, class and stats and plays on as
##   "Name (bot)". A friend who joins a running match takes over a bot of their team (or of the
##   other team when theirs has none; refused when there is no bot at all), as soon as they have
##   loaded the map.
##
## [code]main.gd[/code] adds it to the map of an online match on the host, after the rules,
## and calls [method setup].

## Seconds to wait for every client to load the map before starting without them.
const LOAD_TIMEOUT := 15.0
## The longest item id a buy request may carry (the real ones are shorter than 20 characters).
const MAX_ITEM_ID_LENGTH := 48
## A snapshot every this many ticks (2: 64 a second at 128 Hz).
const SNAPSHOT_INTERVAL := 2
## Ticks between scoreboard updates (32: 4 a second).
const STATS_INTERVAL := 32
## Guns on the floor go into every this many snapshots (they lie still; grenades go into every one).
const PICKUP_SNAPSHOTS := 4
## Ticks a cosmetic effect (a shot, a reload) is repeated in the snapshots: four snapshots.
const EFFECT_TICKS := 8
## The scene of a friend's character: a bot without its brain (D-110: a bot can take it over).
const PLAYER_SCENE := preload("res://bots/bot.tscn")
## A bot's brain and senses, for a bot taking over a friend's character.
const BOT_CONTROLLER_SCRIPT := preload("res://bots/bot_controller.gd")
const BOT_SENSES_SCRIPT := preload("res://bots/bot_senses.gd")
## A bot brain put aside while a friend plays its character: renamed, so the round's tactics
## (which look for "BotController") see a player, and switched off.
const IDLE_BRAIN_NAME := "IdleBotController"

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
## The size of the last snapshot in bytes (the largest of the last send on the host), and a recent
## average (each new one counts a twentieth), for net_stats and the overlay (M16, D-225).
var snapshot_bytes: int = 0
var snapshot_bytes_average: float = 0.0
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
## World object → its number (guns on the floor, grenades), and the next number.
var _entity_ids: Dictionary = {}
var _next_entity_id: int = 1
## Friends' characters whose inventory changed this tick (sent at its end).
var _inventory_dirty: Dictionary = {}


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
	session.player_left.connect(_on_player_left)
	session.closed.connect(_on_session_closed)
	_connect_rules()


## The session ended (the host left): stop sending, and let go of it before it is freed.
func _on_session_closed(_reason: String) -> void:
	_disconnect_session()
	session = null
	set_physics_process(false)
	_late.set_physics_process(false)


func _exit_tree() -> void:
	_disconnect_session()


func _disconnect_session() -> void:
	if session != null and is_instance_valid(session):
		if session.closed.is_connected(_on_session_closed):
			session.closed.disconnect(_on_session_closed)
		if session.packet_received.is_connected(_on_packet):
			session.packet_received.disconnect(_on_packet)
		if session.match_message.is_connected(_on_match_message):
			session.match_message.disconnect(_on_match_message)
		if session.player_left.is_connected(_on_player_left):
			session.player_left.disconnect(_on_player_left)


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


## Lines for the F3 overlay and the console's [code]status[/code]: every friend's ping and
## waiting commands, and the traffic sent.
func get_status_lines() -> Array[String]:
	if session == null:
		return ["Online     the session has ended"]
	var lines: Array[String] = ["Online     hosting, %d friend(s) in the match" % _ready_peers.size()]
	for peer_id: int in _characters_by_peer:
		var character: Character = _characters_by_peer[peer_id]
		if not is_instance_valid(character):
			continue
		var controller := character.get_controller() as NetworkController
		lines.append("  %-12s ping %s ms, %d command(s) waiting" % [String(character.name), str(session.get_ping_ms(peer_id)),
				controller.pending() if controller != null else 0])
	lines.append("Snapshots  %d/s to each friend, %d B each (recent average %d B)" % [
			Engine.physics_ticks_per_second / SNAPSHOT_INTERVAL, snapshot_bytes, roundi(snapshot_bytes_average)])
	lines.append("Traffic    %.1f KB sent so far" % (session.bytes_sent / 1024.0))
	return lines


## The console's net_stats (M16, D-225): each friend's ping and the snapshots' size. The host
## receives no snapshots, so its loss is on each friend's net_stats.
func get_net_stats_lines() -> Array[String]:
	var lines: Array[String] = ["Hosting: %d friend(s); snapshot loss shows on each friend's screen" % _ready_peers.size()]
	for peer_id: int in _characters_by_peer:
		var character: Character = _characters_by_peer[peer_id]
		if is_instance_valid(character):
			lines.append("  %-12s ping %s ms" % [String(character.name), str(session.get_ping_ms(peer_id)) if session != null else "?"])
	lines.append("Snapshot   %d B, recent average %d B, %d a second to each friend" % [
			snapshot_bytes, roundi(snapshot_bytes_average), Engine.physics_ticks_per_second / SNAPSHOT_INTERVAL])
	return lines


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
	print_verbose("Chiip online: the match started with %d characters, %d friend(s) loaded." % [rules.get_participants().size(), _loaded_peers.size()])
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
	for character: Character in _inventory_dirty:
		if is_instance_valid(character) and _peers.has(character):
			_send_inventory(character)
	_inventory_dirty.clear()
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
	character.flashed.connect(func(full: float, fade: float) -> void: _broadcast([NetProtocol.Event.FLASHED, character.net_id, full, fade]))
	# The weapon in hand changes (M7): follow whichever it is.
	character.weapon_changed.connect(_follow_weapon.bind(character))
	character.inventory.changed.connect(func() -> void: _inventory_dirty[character] = true)
	# Ammo scavenged from a gun on the floor (Team Deathmatch) changes no slot, but the reserve of
	# a weapon that may not be in hand: the weapon in hand is corrected by the snapshots, the others
	# only by the list.
	character.inventory.ammo_scavenged.connect(func(_weapon: Weapon, _amount: int) -> void: _inventory_dirty[character] = true)
	_follow_weapon(character.weapon, character)


## Listens to [param weapon], the one [param character] holds now, for the shots and reloads the
## clients must see; the one held before is let go.
func _follow_weapon(weapon: Weapon, character: Character) -> void:
	for carried in character.inventory.get_weapons():
		for connection in [[carried.fired, _on_fired], [carried.hit_landed, _on_hit_landed], [carried.reload_started, _on_reload_started]]:
			var bound: Callable = (connection[1] as Callable).bind(character)
			if (connection[0] as Signal).is_connected(bound):
				(connection[0] as Signal).disconnect(bound)
	if weapon == null:
		return
	weapon.fired.connect(_on_fired.bind(character))
	weapon.hit_landed.connect(_on_hit_landed.bind(character))
	weapon.reload_started.connect(_on_reload_started.bind(character))


func _all_characters() -> Array[Character]:
	var list: Array[Character] = []
	for character in rules.get_participants():
		if is_instance_valid(character) and character.net_id != 0:
			list.append(character)
	return list


## A bot takes over [param character], a friend's character whose player left (D-110): it keeps
## its team, class and stats, and is called "Name (bot)" from now on.
func hand_to_bot(character: Character) -> void:
	var old := character.get_controller()
	var brain := character.get_node_or_null(IDLE_BRAIN_NAME) as BotController
	if brain != null:
		# The character was a bot before the friend took it over: its own brain comes back.
		brain.name = "BotController"
		brain.process_mode = Node.PROCESS_MODE_INHERIT
		var idle_senses := character.get_node_or_null("IdleBotSenses")
		if idle_senses != null:
			idle_senses.name = "BotSenses"
			idle_senses.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		var senses: Node = BOT_SENSES_SCRIPT.new()
		senses.name = "BotSenses"
		character.add_child(senses)
		brain = BOT_CONTROLLER_SCRIPT.new()
		brain.name = "BotController"
		brain.difficulty = rules.settings.bot_difficulty
		character.add_child(brain)
	character.manual = false
	character.lag_compensation = null
	character.set_controller(brain)
	if old != null and old != brain:
		character.remove_child(old)
		old.queue_free()
	_rename(character, "%s (bot)" % String(character.name).left(NetSession.MAX_NAME_LENGTH))


## The friend with [param peer_id] takes over a bot of [param team] (or of the other team when
## that has none) and plays it from now on under [param player_name]. False when there is no bot.
func _take_over_bot(peer_id: int, player_name: String, team: int) -> bool:
	var bot := _find_bot(team)
	if bot == null:
		bot = _find_bot(Teams.other(team))
	if bot == null:
		return false
	var brain := bot.get_node_or_null("BotController") as BotController
	var senses := bot.get_node_or_null("BotSenses")
	if brain != null:
		brain.name = IDLE_BRAIN_NAME
		brain.process_mode = Node.PROCESS_MODE_DISABLED
	if senses != null:
		senses.name = "IdleBotSenses"
		senses.process_mode = Node.PROCESS_MODE_DISABLED
	var controller := NetworkController.new()
	controller.name = "NetworkController"
	controller.peer_id = peer_id
	bot.add_child(controller)
	bot.set_controller(controller)
	bot.manual = true
	bot.lag_compensation = lag_compensation
	_characters_by_peer[peer_id] = bot
	_peers[bot] = peer_id
	if session.get_team(peer_id) != bot.team:
		session.set_player_team(peer_id, bot.team)
	_rename(bot, player_name)
	return true


## The newest bot of [param team] that no friend plays, or null.
func _find_bot(team: int) -> Character:
	var members := rules.get_members(team)
	for i in range(members.size() - 1, -1, -1):
		if members[i].get_node_or_null("BotController") is BotController and not _peers.has(members[i]):
			return members[i]
	return null


## Renames [param character] (its node, which the kill feed and scoreboard show) and tells everyone.
func _rename(character: Character, new_name: String) -> void:
	character.name = new_name
	if character.net_id != 0:
		_broadcast([NetProtocol.Event.RENAMED, character.net_id, String(character.name)])


func _on_player_left(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	_loaded_peers.erase(peer_id)
	var character: Character = _characters_by_peer.get(peer_id)
	_characters_by_peer.erase(peer_id)
	if character == null or not is_instance_valid(character):
		return
	_peers.erase(character)
	if not _started:
		# Not in the match yet: the slot simply goes to a bot when the match starts.
		rules.extra_players.erase(character)
		character.queue_free()
		return
	hand_to_bot(character)


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


## A request from a friend's computer (D-180): shaped like [code][kind, argument][/code], with the
## types and sizes checked before anything is used, and at most a few a second. Whatever doesn't fit
## is dropped without a word.
func _on_request(peer_id: int, values: Array) -> void:
	if values.size() < 1 or values.size() > 2 or not (values[0] is int) or not session.allow(peer_id, "requests", NetSession.MAX_REQUESTS_PER_SECOND):
		return
	var character: Character = _characters_by_peer.get(peer_id)
	if character == null:
		return
	match int(values[0]):
		NetProtocol.Request.CLASS:
			var classes := ClassData.all()
			if values.size() == 2 and values[1] is int and int(values[1]) >= 0 and int(values[1]) < classes.size():
				rules.request_class(character, classes[int(values[1])])
		NetProtocol.Request.BUY:
			if values.size() == 2 and (values[1] is StringName or values[1] is String) and String(values[1]).length() <= MAX_ITEM_ID_LENGTH:
				rules.request_buy(character, StringName(values[1]))


func _on_match_message(data: Dictionary) -> void:
	if data.get("loaded", false) and data.has("from"):
		var peer_id: int = data["from"]
		var entry := session.get_player(peer_id)
		if entry.is_empty():
			return
		if not _characters_by_peer.has(peer_id):
			# Joined after the match was set up: a character of their own before the start, a bot's later.
			if not _started:
				_add_friend(peer_id, entry["name"], entry["team"])
			elif not _take_over_bot(peer_id, entry["name"], entry["team"]):
				session.kick(peer_id, "The match is full: every slot is taken by a player.")
				return
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
	var money: Array = []
	var drafts: Array = []
	for character in _all_characters():
		health.append([character.net_id, character.health])
		money.append([character.net_id, rules.get_money(character)])
		drafts.append([character.net_id, _class_indices(rules.get_draft(character))])
	_ready_peers.append(peer_id)
	session.send_packet(peer_id, NetProtocol.pack_values(NetProtocol.Message.EVENT,
			[NetProtocol.Event.WELCOME, own.net_id if own != null else 0, entries, state, _stats_list(), health, money, drafts]), true)
	if own != null:
		_send_inventory(own)


func _broadcast(values: Array) -> void:
	var packet := NetProtocol.pack_values(NetProtocol.Message.EVENT, values)
	for peer_id in _ready_peers:
		session.send_packet(peer_id, packet, true)


func _send_snapshots() -> void:
	var body := StreamPeerBuffer.new()
	var with_pickups := (tick / SNAPSHOT_INTERVAL) % PICKUP_SNAPSHOTS == 0
	NetProtocol.write_snapshot_body(body, rules, _all_characters(), _effects, _entities(with_pickups), with_pickups)
	var largest := 0
	for peer_id in _ready_peers:
		var own: Character = _characters_by_peer.get(peer_id)
		var ack := 0
		if own != null and own.get_controller() is NetworkController:
			ack = (own.get_controller() as NetworkController).last_run
		var packet := NetProtocol.pack_snapshot(tick, own, ack, body.data_array)
		largest = maxi(largest, packet.size())
		session.send_packet(peer_id, packet, false)
	if largest > 0:
		snapshot_bytes = largest
		snapshot_bytes_average = lerpf(snapshot_bytes_average, largest, 0.05) if snapshot_bytes_average > 0.0 else float(largest)


## The world objects for a snapshot: every grenade in flight and, with [param with_pickups], every
## gun on the floor of this map, each with its number (given on first sight).
func _entities(with_pickups: bool) -> Array[NetProtocol.EntityState]:
	var list: Array[NetProtocol.EntityState] = []
	for node in get_tree().get_nodes_in_group("grenades"):
		var grenade := node as Grenade
		if grenade == null or not map.is_ancestor_of(grenade) or grenade.is_queued_for_deletion():
			continue
		var state := _entity_state(grenade, NetProtocol.ENTITY_GRENADE, grenade.data)
		state.flags = NetProtocol.ENTITY_RESTING if grenade.resting else 0
		list.append(state)
	if with_pickups:
		for pickup in WeaponPickup.all_in_world(map):
			if pickup.is_queued_for_deletion() or not map.is_ancestor_of(pickup):
				continue
			var state := _entity_state(pickup, NetProtocol.ENTITY_PICKUP, pickup.data)
			state.flags = NetProtocol.ENTITY_FLOATING if pickup.floating else 0
			list.append(state)
		for node in get_tree().get_nodes_in_group(WeaponSpot.GROUP):
			var spot := node as WeaponSpot
			if spot != null and map.is_ancestor_of(spot) and not spot.is_queued_for_deletion():
				list.append(_entity_state(spot, NetProtocol.ENTITY_SPOT, spot.weapon))
	return list


func _entity_state(node: Node3D, kind: int, data: WeaponData) -> NetProtocol.EntityState:
	if not _entity_ids.has(node):
		_entity_ids[node] = _next_entity_id
		_next_entity_id = _next_entity_id % 65535 + 1
		node.tree_exited.connect(func() -> void: _entity_ids.erase(node), CONNECT_ONE_SHOT)
		if node is Grenade:
			(node as Grenade).detonated.connect(_on_grenade_detonated.bind(node as Grenade))
	var state := NetProtocol.EntityState.new()
	state.id = _entity_ids[node]
	state.kind = kind
	state.weapon = NetProtocol.weapon_index(data)
	state.position = node.global_position
	state.yaw = node.global_rotation.y
	return state


func _on_grenade_detonated(at: Vector3, grenade: Grenade) -> void:
	var kind: int = {&"frag": Explosion.Kind.FRAG, &"flashbang": Explosion.Kind.FLASH, &"smoke": Explosion.Kind.SMOKE}.get(grenade.data.id, Explosion.Kind.FRAG)
	_broadcast([NetProtocol.Event.GRENADE, _entity_ids.get(grenade, 0), kind, at])


## Tells a friend what its own character carries now (D-113).
func _send_inventory(character: Character) -> void:
	var weapons: Array = []
	var held := -1
	for weapon in character.inventory.get_weapons():
		if weapon == character.weapon:
			held = weapons.size()
		weapons.append([NetProtocol.weapon_index(weapon.data), weapon.magazine, weapon.reserve])
	var peer_id: int = _peers[character]
	if peer_id != 1 and _ready_peers.has(peer_id):
		session.send_packet(peer_id, NetProtocol.pack_values(NetProtocol.Message.EVENT, [NetProtocol.Event.INVENTORY, weapons, held]), true)


func _class_indices(classes: Array[ClassData]) -> Array:
	var all := ClassData.all()
	return classes.map(func(data: ClassData) -> int: return all.find(data))


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
		_broadcast([NetProtocol.Event.KILLED, victim.net_id, killer.net_id if killer != null else 0, headshot, rules.score[0], rules.score[1],
				NetProtocol.weapon_index(victim.last_damage_source)]))
	rules.money_changed.connect(func(character: Character, amount: int, reason: String) -> void:
		if character.net_id != 0:
			_broadcast([NetProtocol.Event.MONEY, character.net_id, rules.get_money(character), amount, reason]))
	rules.class_drafted.connect(func(character: Character, classes: Array[ClassData]) -> void:
		if character.net_id != 0:
			_broadcast([NetProtocol.Event.DRAFTED, character.net_id, _class_indices(classes)]))
	rules.class_changed.connect(func(character: Character, data: ClassData) -> void:
		_broadcast([NetProtocol.Event.CLASS_CHANGED, character.net_id, ClassData.all().find(data)]))
	if rules is RespawnMatch:
		(rules as RespawnMatch).overtime_started.connect(func() -> void: _broadcast([NetProtocol.Event.OVERTIME]))


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	_broadcast([NetProtocol.Event.PHASE, phase, rules.time_left, rules.round_number, rules.attacking_team, rules.score[0], rules.score[1]])


func _on_damaged(amount: float, zone: Hitbox.Zone, attacker: Character, victim: Character) -> void:
	_stats_dirty = true
	# The weapon (as the kill feed's KILLED event has it) lets the shooter's stats credit the right gun (M14, D-203).
	_broadcast([NetProtocol.Event.DAMAGED, victim.net_id, amount, zone, attacker.net_id if attacker != null else 0, victim.health,
			NetProtocol.weapon_index(victim.last_damage_source)])


func _on_died(_killer: Character, _victim: Character) -> void:
	_stats_dirty = true


func _on_respawned(character: Character) -> void:
	# The snapshot sent at the end of this tick carries tick + 1: the first with the character here.
	_broadcast([NetProtocol.Event.RESPAWNED, character.net_id, character.global_position, character.rotation.y, tick + 1])


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
