class_name NetClient
extends Node
## A client's side of an online match (M9, D-104 to D-106): shows the host's game and drives
## this computer's own player.
##
## The client's game is the same scene as the host's: the map, the HUD, the menus. But its
## [RoundManager] and [Bomb] are *replicas* (D-105) that decide nothing, and every character
## except your own is a *puppet* ([member Character.remote]) that only shows where the host
## says it is. This node fills them in:
## - **The welcome.** Once the map is loaded it tells the host; the host answers with
##   [constant NetProtocol.Event.WELCOME]: your network id, every character (it builds the
##   puppets, named after their players, in the host's join order), the match's state and the
##   scoreboard.
## - **Events** (reliable, in order): the round's phases and results, kills (the kill feed),
##   damage, respawns, class changes and the scoreboard go to the replica round manager and the
##   characters, which emit their usual signals, so the HUD and menus work as offline.
## - **Snapshots** (64 a second): the clock, the bomb, and every puppet's position, aim,
##   stance, health and ammo.
## - **Commands** (D-103). Every tick your controller's command is numbered and sent to the
##   host with every earlier one the host hasn't confirmed yet (at most
##   [constant MAX_SENT]); a snapshot's ack confirms them.
##
## [code]main.gd[/code] adds it to the map of an online match on a client, after the replica
## rules, and calls [method setup].

## Emitted once the host's welcome has arrived and every character is on the map.
signal welcomed

## The scene of a puppet: a bot without its brain (it never thinks here).
const PUPPET_SCENE := preload("res://bots/bot.tscn")
## Unconfirmed commands sent in one packet at most (an eighth of a second): enough to cover
## lost packets, small enough to keep the packet small.
const MAX_SENT := 16
## Unconfirmed commands kept at most (a second): older ones are given up.
const MAX_UNCONFIRMED := 128

## The session of this match.
var session: NetSession
## The map, its replica rules and this computer's own player.
var map: Node
var rules: RoundManager
var player: Character
## The newest host tick a snapshot came from (-1: none yet).
var newest_snapshot: int = -1
## Snapshots received, for the status line and the tests.
var snapshots_received: int = 0
## Where this tick's command comes from: null for the player's own controller. Tests set a
## function that takes the tick's length and returns a [CharacterInput].
var command_source: Callable
## The number of the last command made (they count from 1).
var command_tick: int = 0
## The last command the host confirmed it ran.
var acked_tick: int = 0

## Commands sent but not confirmed yet, oldest first.
var _unconfirmed: Array[CharacterInput] = []

## Net id → character, for everyone in the match (you included).
var _characters: Dictionary = {}
var _welcomed: bool = false


func _init() -> void:
	name = "NetClient"
	# After the session hands out this tick's packets, before every character.
	process_physics_priority = -100


## Sets the client up for [param game_rules] (a replica) on [param game_map], with this
## computer's [param own_player], and tells the host the map is loaded.
func setup(game_session: NetSession, game_map: Node, game_rules: RoundManager, own_player: Character) -> void:
	session = game_session
	map = game_map
	rules = game_rules
	player = own_player
	player.name = session.local_name
	player.replica = true
	# The host simulates your player from your commands; this node steps it here (D-103, D-106).
	player.manual = true
	if player.weapon != null:
		player.weapon.manual = true
	rules.class_request = _request_class
	session.packet_received.connect(_on_packet)
	session.send_to_host({"loaded": true})


func _exit_tree() -> void:
	if session != null and is_instance_valid(session) and session.packet_received.is_connected(_on_packet):
		session.packet_received.disconnect(_on_packet)


## True once the host's welcome has arrived.
func is_welcomed() -> bool:
	return _welcomed


## The character with network id [param net_id], or null.
func get_character(net_id: int) -> Character:
	return _characters.get(net_id)


func _physics_process(delta: float) -> void:
	if not _welcomed:
		return
	_send_command(delta)


## Makes this tick's command, numbers it and sends it with the unconfirmed ones.
func _send_command(delta: float) -> void:
	var command: CharacterInput
	if command_source.is_valid():
		command = command_source.call(delta)
	elif player.get_controller() != null:
		command = player.get_controller().get_input(delta)
	else:
		command = CharacterInput.new()
	command = NetProtocol.quantize(command)
	command_tick += 1
	command.tick = command_tick
	command.view_tick = float(newest_snapshot)
	_unconfirmed.append(command)
	while _unconfirmed.size() > MAX_UNCONFIRMED:
		_unconfirmed.pop_front()
	session.send_packet(1, NetProtocol.pack_commands(_unconfirmed.slice(maxi(_unconfirmed.size() - MAX_SENT, 0))), false)


func _request_class(_character: Character, data: ClassData) -> void:
	session.send_packet(1, NetProtocol.pack_values(NetProtocol.Message.REQUEST,
			[NetProtocol.Request.CLASS, ClassData.all().find(data)]), true)


# --- Packets ---


func _on_packet(_peer_id: int, packet: PackedByteArray) -> void:
	match NetProtocol.type_of(packet):
		NetProtocol.Message.EVENT:
			_on_event(NetProtocol.unpack_values(packet))
		NetProtocol.Message.SNAPSHOT:
			if _welcomed:
				var snapshot := NetProtocol.read_snapshot(packet)
				if snapshot != null:
					_on_snapshot(snapshot)


func _on_event(values: Array) -> void:
	if values.is_empty():
		return
	var kind: int = values[0]
	if kind == NetProtocol.Event.WELCOME:
		_on_welcome(values)
		return
	if not _welcomed:
		# Anything before the welcome is already part of it.
		return
	match kind:
		NetProtocol.Event.CHARACTER_ADDED:
			_add_character(values[1])
		NetProtocol.Event.CHARACTER_REMOVED:
			var gone := get_character(values[1])
			if gone != null and gone != player:
				rules.replica_leave(gone)
				_characters.erase(int(values[1]))
				gone.queue_free()
		NetProtocol.Event.RENAMED:
			var renamed := get_character(values[1])
			if renamed != null:
				renamed.name = String(values[2])
		NetProtocol.Event.PHASE:
			rules.replica_set_state(values[1], values[2], values[3], values[4], [values[5], values[6]])
		NetProtocol.Event.ROUND_STARTED:
			rules.replica_round_started(values[1])
		NetProtocol.Event.ROUND_ENDED:
			rules.replica_round_ended(values[1], values[2], [values[3], values[4]])
		NetProtocol.Event.SIDES_SWAPPED:
			rules.replica_sides_swapped(values[1])
		NetProtocol.Event.MATCH_ENDED:
			rules.replica_match_ended(values[1], [values[2], values[3]])
		NetProtocol.Event.OVERTIME:
			if rules is RespawnMatch:
				(rules as RespawnMatch).replica_overtime()
		NetProtocol.Event.KILLED:
			var victim := get_character(values[1])
			if victim != null:
				rules.replica_killed(victim, get_character(values[2]), values[3])
		NetProtocol.Event.DAMAGED:
			var hurt := get_character(values[1])
			if hurt != null:
				hurt.apply_remote_damage(values[2], values[3], get_character(values[4]), values[5])
		NetProtocol.Event.RESPAWNED:
			_on_respawned(get_character(values[1]), values[2], values[3])
		NetProtocol.Event.STATS:
			_apply_stats(values[1])
		NetProtocol.Event.CLASS_CHANGED:
			var changed := get_character(values[1])
			var classes := ClassData.all()
			if changed != null and int(values[2]) >= 0 and int(values[2]) < classes.size():
				rules.replica_class_changed(changed, classes[int(values[2])])


func _on_welcome(values: Array) -> void:
	if _welcomed:
		return
	var own_id: int = values[1]
	player.net_id = own_id
	_characters[own_id] = player
	rules.replica_start()
	for entry: Array in values[2]:
		_add_character(entry)
	var state: Array = values[3]
	rules.replica_set_state(state[0], state[1], state[2], state[3], [state[4], state[5]])
	if state[6] >= 0:
		rules.winner = state[6]
	if state[7] and rules is RespawnMatch:
		(rules as RespawnMatch).replica_overtime()
	_apply_stats(values[4])
	for item: Array in values[5]:
		var character := get_character(item[0])
		if character != null:
			character.health = item[1]
	_welcomed = true
	Teams.set_viewer_team(player.team)
	welcomed.emit()


## Adds the character of [param entry] ([method NetProtocol.character_entry]) to the match: your
## own (it is already on the map) or a new puppet.
func _add_character(entry: Array) -> void:
	var net_id: int = entry[0]
	var classes := ClassData.all()
	var data: ClassData = classes[clampi(int(entry[3]), 0, classes.size() - 1)]
	var character: Character
	if net_id == player.net_id:
		character = player
		character.team = entry[2]
		if character.class_data != data:
			character.class_data = data
	else:
		if _characters.has(net_id):
			return
		character = NetHost.make_player_character(PUPPET_SCENE)
		var agent := character.get_node_or_null("NavigationAgent3D")
		if agent != null:
			character.remove_child(agent)
			agent.free()
		character.name = String(entry[1])
		character.team = entry[2]
		character.class_data = data
		character.net_id = net_id
		character.remote = true
		character.replica = true
		character.footstep_sound = player.footstep_sound
		map.add_child(character)
		character.weapon.remote = true
		character.weapon.data = player.weapon.data
		# Hidden until the first snapshot puts it somewhere.
		character.visible = false
		_characters[net_id] = character
	rules.replica_join(character)


func _apply_stats(list: Array) -> void:
	for item: Array in list:
		var character := get_character(item[0])
		if character != null:
			rules.replica_set_stats(character, item[1], item[2], item[3], item[4])


func _on_respawned(character: Character, at: Vector3, yaw: float) -> void:
	if character == null:
		return
	character.respawn(at, yaw)
	character.visible = true


# --- Snapshots ---


func _on_snapshot(snapshot: NetProtocol.Snapshot) -> void:
	snapshots_received += 1
	if snapshot.tick <= newest_snapshot:
		return
	newest_snapshot = snapshot.tick
	if rules.phase == snapshot.phase:
		rules.replica_set_clock(snapshot.time_left)
	_apply_bomb(snapshot.bomb)
	for state in snapshot.characters:
		var character := get_character(state.net_id)
		if character == null or character == player:
			continue
		_apply_puppet(character, state)
	if snapshot.own != null:
		_on_ack(snapshot.own.ack)
		_apply_own(snapshot.own)


func _apply_puppet(character: Character, state: NetProtocol.CharacterState) -> void:
	character.visible = true
	character.set_remote_pose(state.position, state.velocity, state.yaw, state.pitch, state.eye_height,
			state.has(NetProtocol.FLAG_CROUCHING), state.has(NetProtocol.FLAG_ON_FLOOR))
	character.frozen = state.has(NetProtocol.FLAG_FROZEN)
	character.busy = state.has(NetProtocol.FLAG_BUSY)
	if character.is_alive():
		character.health = state.health
	character.weapon.set_remote_ammo(state.magazine, state.reserve)


## The host has run every command up to [param ack]: they needn't be sent again.
func _on_ack(ack: int) -> void:
	if ack <= acked_tick:
		return
	acked_tick = ack
	while not _unconfirmed.is_empty() and _unconfirmed[0].tick <= ack:
		_unconfirmed.pop_front()


func _apply_own(own: NetProtocol.OwnState) -> void:
	player.frozen = own.has(NetProtocol.FLAG_FROZEN)
	player.busy = own.has(NetProtocol.FLAG_BUSY)
	player.set_predicted_state(own.position, own.velocity, own.has(NetProtocol.FLAG_CROUCHING), own.eye_height, own.has(NetProtocol.FLAG_ON_FLOOR))


func _apply_bomb(state: NetProtocol.BombState) -> void:
	var bomb := rules.bomb
	if bomb == null or state.state == NetProtocol.NO_BOMB:
		return
	bomb.apply_replica_state(state.state, get_character(state.carrier), state.position, state.yaw, state.fuse_left,
			get_character(state.actor), state.progress, state.active, state.attacking_team, state.site)
