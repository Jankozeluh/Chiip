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
##   stance, health and ammo. Puppets are shown [constant INTERPOLATION_TICKS] ticks behind the
##   newest snapshot, interpolated between the two snapshots around that moment (D-104), so
##   they move smoothly even though snapshots come every second tick and a few get lost. If
##   snapshots stop, a puppet keeps moving along its velocity for
##   [constant EXTRAPOLATION_TICKS] ticks, then stands. The shots and reloads riding in the
##   snapshots play on the puppets at once (each is numbered and played once).
## - **Commands** (D-103). Every tick your controller's command is numbered and sent to the
##   host with every earlier one the host hasn't confirmed yet (at most
##   [constant MAX_SENT]); a snapshot's ack confirms them.
## - **Prediction** (D-106). Your character doesn't wait for the host: every command is
##   simulated here at once ([method Character.step]), shots, recoil and ammo included, and the
##   state it leaves is kept with it. When a snapshot says where the host's simulation of the
##   same command left you, the two are compared; if they differ by more than
##   [constant POSITION_TOLERANCE] or [constant VELOCITY_TOLERANCE] (or in crouching or ground
##   contact), you are put where the host says and every newer command is replayed at once
##   (movement only), so you end up where the host will have you. The camera hides the jump of a
##   small correction, letting it fade over [constant SMOOTHING_TIME] (CS's [code]cl_smooth[/code]).
##   Ammo is corrected by the difference between the host's count and the predicted one.
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
## How far behind the newest snapshot the puppets are shown, in ticks: 6 is 47 ms, three
## snapshot intervals, so one lost snapshot still leaves one to interpolate to (D-104).
const INTERPOLATION_TICKS := 6.0
## How long a puppet keeps moving along its velocity when snapshots stop, in ticks (100 ms).
const EXTRAPOLATION_TICKS := 13.0
## Snapshots kept per puppet (half a second).
const MAX_SAMPLES := 32
## Prediction: differences from the host this small are left alone (metres, metres a second).
const POSITION_TOLERANCE := 0.01
const VELOCITY_TOLERANCE := 0.05
## Seconds over which the camera catches up with a corrected position.
const SMOOTHING_TIME := 0.1
## Corrections larger than this (metres) aren't smoothed: a respawn or a teleport.
const SMOOTHING_LIMIT := 1.0
## How quickly the clock follows the snapshots' ticks (a share of the difference per tick), and
## the difference at which it jumps instead.
const CLOCK_CORRECTION := 0.05
const CLOCK_JUMP := 16.0

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
## The host tick this computer thinks it is (it follows the snapshots' ticks smoothly).
var clock: float = -1.0
## Prediction can be switched off (tests compare): your character then stands where the
## host's snapshots put it, a round trip late.
var predict: bool = true
## How often the host disagreed with the prediction, and the largest difference (metres).
var corrections: int = 0
var largest_correction: float = 0.0

## Commands sent but not confirmed yet, oldest first.
var _unconfirmed: Array[CharacterInput] = []
## Net id → the puppet's snapshots, oldest first: [host tick, CharacterState] each.
var _samples: Dictionary = {}
## Net id → the host tick of the puppet's last respawn: older snapshots of it are ignored.
var _respawn_ticks: Dictionary = {}
## Numbers of the cosmetic effects already played (the newest few hundred).
var _played: Dictionary = {}
var _played_order: Array[int] = []
## Every command predicted but not confirmed yet with the state it left: [command, PredictedState].
var _history: Array = []


## What prediction compares: the state a command left the character in.
class PredictedState:
	var position: Vector3
	var velocity: Vector3
	var crouching: bool
	var eye_height: float
	var on_floor: bool
	var magazine: int
	var reserve: int

	static func of(character: Character) -> PredictedState:
		var state := PredictedState.new()
		state.position = character.global_position
		state.velocity = character.velocity
		state.crouching = character.is_crouching
		state.eye_height = character.get_eye_height()
		state.on_floor = character.is_on_floor()
		state.magazine = character.weapon.magazine if character.weapon != null else 0
		state.reserve = character.weapon.reserve if character.weapon != null else 0
		return state

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
	_advance_clock()
	_show_puppets()
	_send_command(delta)


func _process(delta: float) -> void:
	# The camera's share of a correction fades out (cl_smooth).
	if player != null and player.view_offset != Vector3.ZERO:
		player.view_offset *= exp(-delta / SMOOTHING_TIME)
		if player.view_offset.length() < 0.0005:
			player.view_offset = Vector3.ZERO


## The host tick the puppets are shown at now: [constant INTERPOLATION_TICKS] behind the clock.
func get_render_tick() -> float:
	return clock - INTERPOLATION_TICKS


## Moves the clock on by a tick and pulls it gently toward the newest snapshot's tick.
func _advance_clock() -> void:
	if newest_snapshot < 0:
		return
	if clock < 0.0:
		clock = float(newest_snapshot)
		return
	clock += 1.0
	var error := float(newest_snapshot) - clock
	if absf(error) > CLOCK_JUMP:
		clock = float(newest_snapshot)
	else:
		clock += error * CLOCK_CORRECTION


## Puts every puppet where it was at the render tick, between the two snapshots around it.
func _show_puppets() -> void:
	var render := get_render_tick()
	for net_id: int in _samples:
		var character := get_character(net_id)
		var samples: Array = _samples[net_id]
		if character == null or samples.is_empty():
			continue
		var a: Array = samples[0]
		var b: Array = []
		for sample: Array in samples:
			if float(sample[0]) <= render:
				a = sample
			else:
				b = sample
				break
		var from: NetProtocol.CharacterState = a[1]
		if float(a[0]) > render or b.is_empty():
			# Before the first snapshot, or past the newest: hold, or keep going for a moment.
			var ahead := clampf(render - float(a[0]), 0.0, EXTRAPOLATION_TICKS)
			var moved := from.position + from.velocity * ahead / Engine.physics_ticks_per_second if from.has(NetProtocol.FLAG_ALIVE) else from.position
			_pose(character, from, moved, from.yaw, from.pitch, from.eye_height)
			continue
		var to: NetProtocol.CharacterState = b[1]
		var weight := clampf((render - float(a[0])) / float(maxi(b[0] - a[0], 1)), 0.0, 1.0)
		_pose(character, from, from.position.lerp(to.position, weight), lerp_angle(from.yaw, to.yaw, weight),
				lerpf(from.pitch, to.pitch, weight), lerpf(from.eye_height, to.eye_height, weight), from.velocity.lerp(to.velocity, weight))


func _pose(character: Character, state: NetProtocol.CharacterState, at: Vector3, yaw: float, pitch: float, eye_height: float,
		moving: Vector3 = Vector3.INF) -> void:
	character.visible = true
	character.set_remote_pose(at, state.velocity if moving == Vector3.INF else moving, yaw, pitch, eye_height,
			state.has(NetProtocol.FLAG_CROUCHING), state.has(NetProtocol.FLAG_ON_FLOOR))


## Makes this tick's command, numbers it and sends it with the unconfirmed ones.
func _send_command(delta: float) -> void:
	var command: CharacterInput
	if command_source.is_valid():
		command = command_source.call(delta)
	elif player.get_controller() != null:
		command = player.get_controller().get_input(delta)
	else:
		command = CharacterInput.new()
	command_tick += 1
	command.tick = command_tick
	command.view_tick = get_render_tick()
	command = NetProtocol.quantize(command)
	_unconfirmed.append(command)
	while _unconfirmed.size() > MAX_UNCONFIRMED:
		_unconfirmed.pop_front()
	session.send_packet(1, NetProtocol.pack_commands(_unconfirmed.slice(maxi(_unconfirmed.size() - MAX_SENT, 0))), false)
	if predict:
		# Simulate it now, exactly as the host will (D-106), and remember where it left you.
		# A copy: the simulation clears the movement of a frozen command, and the command itself
		# must reach the host (in later packets too) as it was made.
		player.step(command.copy(), delta)
		_history.append([command, PredictedState.of(player)])
		while _history.size() > MAX_UNCONFIRMED:
			_history.pop_front()


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
			_on_respawned(get_character(values[1]), values[2], values[3], values[4])
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
		# Puppets are posed every tick from the snapshots; the engine's smoothing between ticks stays.
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


func _on_respawned(character: Character, at: Vector3, yaw: float, host_tick: int) -> void:
	if character == null:
		return
	character.respawn(at, yaw)
	character.visible = true
	if character != player:
		# From its spawn on: no gliding from where it died, and older snapshots of it don't count.
		_respawn_ticks[character.net_id] = host_tick
		var samples: Array = _samples.get(character.net_id, [])
		_samples[character.net_id] = samples.filter(func(sample: Array) -> bool: return sample[0] >= host_tick)


# --- Snapshots ---


func _on_snapshot(snapshot: NetProtocol.Snapshot) -> void:
	snapshots_received += 1
	# Every snapshot's puppets go into their buffers, also one that arrives late (interpolation
	# can still use it); the rest only from the newest.
	for state in snapshot.characters:
		var character := get_character(state.net_id)
		if character == null or character == player:
			continue
		_store_sample(snapshot.tick, state)
	_play_effects(snapshot.effects)
	if snapshot.tick <= newest_snapshot:
		return
	newest_snapshot = snapshot.tick
	if rules.phase == snapshot.phase:
		rules.replica_set_clock(snapshot.time_left)
	_apply_bomb(snapshot.bomb)
	for state in snapshot.characters:
		var character := get_character(state.net_id)
		if character != null and character != player:
			_apply_puppet_state(character, state)
	if snapshot.own != null:
		_on_ack(snapshot.own.ack)
		_apply_own(snapshot.own)


func _store_sample(host_tick: int, state: NetProtocol.CharacterState) -> void:
	if host_tick < _respawn_ticks.get(state.net_id, -1):
		return
	var samples: Array = _samples.get_or_add(state.net_id, [])
	var index := samples.size()
	while index > 0 and samples[index - 1][0] > host_tick:
		index -= 1
	if index > 0 and samples[index - 1][0] == host_tick:
		return
	samples.insert(index, [host_tick, state])
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()


## What isn't interpolated: frozen and busy, health (while alive) and ammo, from the newest snapshot.
func _apply_puppet_state(character: Character, state: NetProtocol.CharacterState) -> void:
	character.frozen = state.has(NetProtocol.FLAG_FROZEN)
	character.busy = state.has(NetProtocol.FLAG_BUSY)
	if character.is_alive() and state.has(NetProtocol.FLAG_ALIVE):
		character.health = state.health
	character.weapon.set_remote_ammo(state.magazine, state.reserve)


## Plays the shots and reloads of the puppets that weren't played yet. Your own are predicted.
func _play_effects(effects: Array) -> void:
	for effect: Array in effects:
		var number: int = effect[0]
		if _played.has(number):
			continue
		_played[number] = true
		_played_order.append(number)
		while _played_order.size() > 512:
			_played.erase(_played_order.pop_front())
		var character := get_character(effect[2])
		if character == null or character == player or not character.remote:
			continue
		match int(effect[1]):
			NetProtocol.Effect.SHOT_HIT:
				character.weapon.play_remote_shot(true, effect[3])
			NetProtocol.Effect.SHOT_MISS:
				character.weapon.play_remote_shot(false, Vector3.ZERO)
			NetProtocol.Effect.RELOAD:
				character.weapon.start_remote_reload()


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
	if not predict:
		player.set_predicted_state(own.position, own.velocity, own.has(NetProtocol.FLAG_CROUCHING), own.eye_height, own.has(NetProtocol.FLAG_ON_FLOOR))
		return
	_reconcile(own)


## Compares the host's state after command [member NetProtocol.OwnState.ack] with what was
## predicted for it, and corrects the prediction when they differ (D-106).
func _reconcile(own: NetProtocol.OwnState) -> void:
	# Forget what the host has confirmed, up to the acked command itself.
	var predicted: PredictedState = null
	while not _history.is_empty() and (_history[0][0] as CharacterInput).tick <= own.ack:
		var entry: Array = _history.pop_front()
		if (entry[0] as CharacterInput).tick == own.ack:
			predicted = entry[1]
	if predicted == null:
		if own.ack > 0 and _history.is_empty():
			# Nothing predicted after it (prediction just started): take the host's state.
			player.set_predicted_state(own.position, own.velocity, own.has(NetProtocol.FLAG_CROUCHING), own.eye_height, own.has(NetProtocol.FLAG_ON_FLOOR))
		return
	var crouching := own.has(NetProtocol.FLAG_CROUCHING)
	var on_floor := own.has(NetProtocol.FLAG_ON_FLOOR)
	# Ammo: what the host counted that this computer didn't (or the other way round) is added.
	var magazine_difference := own.magazine - predicted.magazine
	var reserve_difference := own.reserve - predicted.reserve
	if magazine_difference != 0 or reserve_difference != 0:
		player.weapon.correct_ammo(magazine_difference, reserve_difference)
		for entry: Array in _history:
			(entry[1] as PredictedState).magazine += magazine_difference
			(entry[1] as PredictedState).reserve += reserve_difference
	var error := predicted.position.distance_to(own.position)
	if error <= POSITION_TOLERANCE and predicted.velocity.distance_to(own.velocity) <= VELOCITY_TOLERANCE \
			and predicted.crouching == crouching and predicted.on_floor == on_floor:
		return
	# The host disagrees: start from its state and replay every newer command, movement only.
	corrections += 1
	largest_correction = maxf(largest_correction, error)
	var shown_before := player.global_position
	player.set_predicted_state(own.position, own.velocity, crouching, own.eye_height, on_floor)
	var delta := 1.0 / Engine.physics_ticks_per_second
	for entry: Array in _history:
		player.step((entry[0] as CharacterInput).copy(), delta, false)
		var state := PredictedState.of(player)
		state.magazine = (entry[1] as PredictedState).magazine
		state.reserve = (entry[1] as PredictedState).reserve
		entry[1] = state
	var jump := shown_before - player.global_position
	if jump.length() <= SMOOTHING_LIMIT:
		player.view_offset += jump
	else:
		player.view_offset = Vector3.ZERO
	player.reset_physics_interpolation()


func _apply_bomb(state: NetProtocol.BombState) -> void:
	var bomb := rules.bomb
	if bomb == null or state.state == NetProtocol.NO_BOMB:
		return
	bomb.apply_replica_state(state.state, get_character(state.carrier), state.position, state.yaw, state.fuse_left,
			get_character(state.actor), state.progress, state.active, state.attacking_team, state.site)
