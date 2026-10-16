class_name NetProtocol
extends RefCounted
## The packets of the game stream (M9, D-101): what each kind of packet holds and how it is
## packed into bytes. Every packet starts with one byte, its [enum Message] type.
##
## Packing by hand ([StreamPeerBuffer], like a C struct written field by field) keeps a
## 5v5 snapshot at about 500 bytes; [method @GlobalScope.var_to_bytes] would need several times
## that, because every value carries its type with it. Events are rare, so they use
## [code]var_to_bytes[/code] for simplicity ([method pack_values]).
##
## A static class (no instances): both sides of a connection use the same functions, so what
## one side writes the other reads in the same order.

## Bump when packets change: a host refuses clients with another version.
const VERSION := 1

## What a packet is: its first byte.
enum Message {
	## Client → host, unreliable: the player's commands the host hasn't confirmed yet.
	COMMANDS = 1,
	## Host → client, unreliable: where everyone is (64 a second).
	SNAPSHOT = 2,
	## Host → clients, reliable: something that happened (a kill, a round's end...), see [enum Event].
	EVENT = 3,
	## Client → host, reliable: a request the host decides on, see [enum Request].
	REQUEST = 4,
}

## The reliable events of a match (D-104), the first value of an [constant Message.EVENT] packet.
enum Event {
	## [your net id, characters, match state, stats]: everything a client needs to join the match.
	WELCOME = 1,
	## [character entry]: a character joined the match (see [method character_entry]).
	CHARACTER_ADDED,
	## [net id]: a character left the match.
	CHARACTER_REMOVED,
	## [net id, new name]: a character's name changed (a bot took over a player who left).
	RENAMED,
	## [phase, time left, round, attacking team, score 0, score 1].
	PHASE,
	## [round].
	ROUND_STARTED,
	## [winner, reason, score 0, score 1].
	ROUND_ENDED,
	## [attacking team].
	SIDES_SWAPPED,
	## [winner, score 0, score 1].
	MATCH_ENDED,
	## []: a team respawn match went into overtime.
	OVERTIME,
	## [victim, killer (0: none), headshot].
	KILLED,
	## [victim, amount, zone, attacker (0: none), health left].
	DAMAGED,
	## [net id, position, yaw].
	RESPAWNED,
	## [[net id, kills, deaths, assists, damage], ...].
	STATS,
	## [net id, class index in ClassData.all()].
	CLASS_CHANGED,
}

## What a client can ask the host (the first value of a [constant Message.REQUEST] packet).
enum Request {
	## [class index]: play this class (the host's round manager decides, D-078).
	CLASS = 1,
}

## Cosmetic events riding in snapshots (D-104), repeated in a few snapshots each.
enum Effect {
	## A shot whose bullet landed somewhere: [position] is where.
	SHOT_HIT = 1,
	## A shot into the sky.
	SHOT_MISS,
	## A reload starts.
	RELOAD,
}

## Bits of a character's flags in a snapshot.
const FLAG_ALIVE := 1
const FLAG_CROUCHING := 2
const FLAG_ON_FLOOR := 4
const FLAG_FROZEN := 8
const FLAG_BUSY := 16
const FLAG_RELOADING := 32

## Command buttons, one bit each.
const BUTTON_JUMP := 1
const BUTTON_CROUCH := 2
const BUTTON_WALK := 4
const BUTTON_SHOOT := 8
const BUTTON_RELOAD := 16
const BUTTON_USE := 32

## A snapshot's bomb state when there is no bomb.
const NO_BOMB := 255

## One character in a snapshot.
class CharacterState:
	var net_id: int = 0
	var flags: int = 0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0
	var eye_height: float = 0.0
	var health: int = 0
	var magazine: int = 0
	var reserve: int = 0

	func has(flag: int) -> bool:
		return flags & flag != 0


## The receiving client's own character, at full precision, after the host ran command [member ack].
class OwnState:
	var ack: int = 0
	var flags: int = 0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var eye_height: float = 0.0
	var magazine: int = 0
	var reserve: int = 0

	func has(flag: int) -> bool:
		return flags & flag != 0


## The bomb in a snapshot.
class BombState:
	var state: int = NO_BOMB
	var carrier: int = 0
	var position: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var fuse_left: float = 0.0
	var actor: int = 0
	var progress: float = 0.0
	var active: bool = false
	var attacking_team: int = 0
	var site: int = -1


## A whole snapshot, as read by [method read_snapshot].
class Snapshot:
	var tick: int = 0
	## Null when the receiver has no character of its own.
	var own: OwnState
	var phase: int = 0
	var time_left: float = 0.0
	var overtime: bool = false
	var bomb := BombState.new()
	var characters: Array[CharacterState] = []
	## [sequence, Effect, net id, position] each.
	var effects: Array = []


## True for packets that travel reliably (they are never dropped by fake loss either).
static func is_reliable(packet: PackedByteArray) -> bool:
	return not packet.is_empty() and (packet[0] == Message.EVENT or packet[0] == Message.REQUEST)


## The [enum Message] type of [param packet], or 0 for an empty one.
static func type_of(packet: PackedByteArray) -> int:
	return packet[0] if not packet.is_empty() else 0


## A reliable packet of type [param type] carrying [param values] (anything
## [method @GlobalScope.var_to_bytes] can pack, no objects).
static func pack_values(type: Message, values: Array) -> PackedByteArray:
	var packet := PackedByteArray([type])
	packet.append_array(var_to_bytes(values))
	return packet


## The values of a packet made by [method pack_values]; empty if it can't be read.
static func unpack_values(packet: PackedByteArray) -> Array:
	if packet.size() < 2:
		return []
	var values: Variant = bytes_to_var(packet.slice(1))
	return values if values is Array else []


# --- Commands ---


## [param command] as it will arrive at the host: the movement keys in whole steps of 1/127
## (a byte each). The client simulates this copy, so both computers run the same numbers (D-103).
static func quantize(command: CharacterInput) -> CharacterInput:
	var copy := command.copy()
	copy.move = Vector2(roundi(clampf(command.move.x, -1.0, 1.0) * 127.0) / 127.0,
			roundi(clampf(command.move.y, -1.0, 1.0) * 127.0) / 127.0)
	return copy


## A commands packet with [param commands], oldest first (at most 255).
static func pack_commands(commands: Array[CharacterInput]) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(Message.COMMANDS)
	buffer.put_u8(mini(commands.size(), 255))
	for i in mini(commands.size(), 255):
		var command := commands[i]
		buffer.put_u32(command.tick)
		buffer.put_8(roundi(clampf(command.move.x, -1.0, 1.0) * 127.0))
		buffer.put_8(roundi(clampf(command.move.y, -1.0, 1.0) * 127.0))
		buffer.put_float(command.yaw)
		buffer.put_float(command.pitch)
		var buttons := 0
		buttons |= BUTTON_JUMP if command.jump else 0
		buttons |= BUTTON_CROUCH if command.crouch else 0
		buttons |= BUTTON_WALK if command.walk else 0
		buttons |= BUTTON_SHOOT if command.shoot else 0
		buttons |= BUTTON_RELOAD if command.reload else 0
		buttons |= BUTTON_USE if command.use else 0
		buffer.put_u8(buttons)
		buffer.put_float(command.view_tick)
	return buffer.data_array


## The commands of a packet made by [method pack_commands]; empty if it is cut short.
static func unpack_commands(packet: PackedByteArray) -> Array[CharacterInput]:
	var commands: Array[CharacterInput] = []
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = packet
	if packet.size() < 2:
		return commands
	buffer.get_u8()
	var count := buffer.get_u8()
	if packet.size() < 2 + count * 19:
		return commands
	for i in count:
		var command := CharacterInput.new()
		command.tick = buffer.get_u32()
		var x := buffer.get_8()
		var y := buffer.get_8()
		command.move = Vector2(x / 127.0, y / 127.0)
		command.yaw = buffer.get_float()
		command.pitch = buffer.get_float()
		var buttons := buffer.get_u8()
		command.jump = buttons & BUTTON_JUMP != 0
		command.crouch = buttons & BUTTON_CROUCH != 0
		command.walk = buttons & BUTTON_WALK != 0
		command.shoot = buttons & BUTTON_SHOOT != 0
		command.reload = buttons & BUTTON_RELOAD != 0
		command.use = buttons & BUTTON_USE != 0
		command.view_tick = buffer.get_float()
		if not is_finite(command.yaw) or not is_finite(command.pitch) or not is_finite(command.view_tick):
			continue
		commands.append(command)
	return commands


# --- Snapshots ---


## The flags of [param character] for a snapshot.
static func flags_of(character: Character) -> int:
	var flags := 0
	flags |= FLAG_ALIVE if character.is_alive() else 0
	flags |= FLAG_CROUCHING if character.is_crouching else 0
	flags |= FLAG_ON_FLOOR if character.is_grounded() else 0
	flags |= FLAG_FROZEN if character.frozen else 0
	flags |= FLAG_BUSY if character.busy else 0
	if character.weapon != null and character.weapon.is_reloading():
		flags |= FLAG_RELOADING
	return flags


## Writes the part of a snapshot that is the same for every client: the match, the bomb, every
## character in [param characters] and the cosmetic [param effects] ([sequence, Effect, net id,
## position] each).
static func write_snapshot_body(buffer: StreamPeerBuffer, rounds: RoundManager, characters: Array[Character], effects: Array) -> void:
	buffer.put_u8(rounds.phase if rounds != null else 0)
	buffer.put_float(rounds.time_left if rounds != null else 0.0)
	var respawn := rounds as RespawnMatch
	buffer.put_u8(1 if respawn != null and respawn.overtime else 0)
	var bomb := rounds.bomb if rounds != null else null
	if bomb == null:
		buffer.put_u8(NO_BOMB)
	else:
		buffer.put_u8(bomb.state)
		buffer.put_u8(bomb.carrier.net_id if is_instance_valid(bomb.carrier) else 0)
		_put_vector(buffer, bomb.global_position)
		buffer.put_float(bomb.global_rotation.y)
		buffer.put_float(bomb.fuse_left)
		buffer.put_u8(bomb.actor.net_id if is_instance_valid(bomb.actor) else 0)
		buffer.put_u8(roundi(clampf(bomb.progress, 0.0, 1.0) * 255.0))
		buffer.put_u8(1 if bomb.active else 0)
		buffer.put_u8(bomb.attacking_team)
		buffer.put_8(bomb.get_sites().find(bomb.site))
	buffer.put_u8(characters.size())
	for character in characters:
		buffer.put_u8(character.net_id)
		buffer.put_u8(flags_of(character))
		_put_vector(buffer, character.global_position)
		buffer.put_half(character.velocity.x)
		buffer.put_half(character.velocity.y)
		buffer.put_half(character.velocity.z)
		var aim := character.get_aim_angles()
		buffer.put_u16(roundi(wrapf(aim.x, 0.0, TAU) / TAU * 65535.0) % 65536)
		buffer.put_16(roundi(clampf(aim.y, -PI / 2.0, PI / 2.0) / (PI / 2.0) * 32767.0))
		buffer.put_u8(clampi(roundi(character.get_eye_height() * 100.0), 0, 255))
		buffer.put_u8(clampi(ceili(character.health), 0, 255))
		buffer.put_u8(clampi(character.weapon.magazine if character.weapon != null else 0, 0, 255))
		buffer.put_u16(clampi(character.weapon.reserve if character.weapon != null else 0, 0, 65535))
	buffer.put_u8(mini(effects.size(), 255))
	for i in mini(effects.size(), 255):
		var effect: Array = effects[i]
		buffer.put_u16(effect[0] % 65536)
		buffer.put_u8(effect[1])
		buffer.put_u8(effect[2])
		_put_vector(buffer, effect[3])


## A whole snapshot for one client: the host [param tick], the client's own [param character]
## (null: none) after its command [param ack], and the shared [param body] from
## [method write_snapshot_body].
static func pack_snapshot(tick: int, character: Character, ack: int, body: PackedByteArray) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(Message.SNAPSHOT)
	buffer.put_u32(tick)
	if character == null:
		buffer.put_u8(0)
	else:
		buffer.put_u8(1)
		buffer.put_u32(ack)
		buffer.put_u8(flags_of(character))
		_put_vector(buffer, character.global_position)
		_put_vector(buffer, character.velocity)
		buffer.put_float(character.get_eye_height())
		buffer.put_u8(clampi(character.weapon.magazine if character.weapon != null else 0, 0, 255))
		buffer.put_u16(clampi(character.weapon.reserve if character.weapon != null else 0, 0, 65535))
	var packet := buffer.data_array
	packet.append_array(body)
	return packet


## Reads a snapshot made by [method pack_snapshot]; null if it is cut short.
static func read_snapshot(packet: PackedByteArray) -> Snapshot:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = packet
	if packet.size() < 6:
		return null
	var snapshot := Snapshot.new()
	buffer.get_u8()
	snapshot.tick = buffer.get_u32()
	if buffer.get_u8() == 1:
		if buffer.get_available_bytes() < 36:
			return null
		var own := OwnState.new()
		own.ack = buffer.get_u32()
		own.flags = buffer.get_u8()
		own.position = _get_vector(buffer)
		own.velocity = _get_vector(buffer)
		own.eye_height = buffer.get_float()
		own.magazine = buffer.get_u8()
		own.reserve = buffer.get_u16()
		snapshot.own = own
	if buffer.get_available_bytes() < 7:
		return null
	snapshot.phase = buffer.get_u8()
	snapshot.time_left = buffer.get_float()
	snapshot.overtime = buffer.get_u8() == 1
	var bomb_state := buffer.get_u8()
	snapshot.bomb.state = bomb_state
	if bomb_state != NO_BOMB:
		if buffer.get_available_bytes() < 26:
			return null
		snapshot.bomb.carrier = buffer.get_u8()
		snapshot.bomb.position = _get_vector(buffer)
		snapshot.bomb.yaw = buffer.get_float()
		snapshot.bomb.fuse_left = buffer.get_float()
		snapshot.bomb.actor = buffer.get_u8()
		snapshot.bomb.progress = buffer.get_u8() / 255.0
		snapshot.bomb.active = buffer.get_u8() == 1
		snapshot.bomb.attacking_team = buffer.get_u8()
		snapshot.bomb.site = buffer.get_8()
	if buffer.get_available_bytes() < 1:
		return null
	var count := buffer.get_u8()
	if buffer.get_available_bytes() < count * 29:
		return null
	for i in count:
		var state := CharacterState.new()
		state.net_id = buffer.get_u8()
		state.flags = buffer.get_u8()
		state.position = _get_vector(buffer)
		state.velocity = Vector3(buffer.get_half(), buffer.get_half(), buffer.get_half())
		state.yaw = buffer.get_u16() / 65535.0 * TAU
		state.pitch = buffer.get_16() / 32767.0 * (PI / 2.0)
		state.eye_height = buffer.get_u8() / 100.0
		state.health = buffer.get_u8()
		state.magazine = buffer.get_u8()
		state.reserve = buffer.get_u16()
		snapshot.characters.append(state)
	if buffer.get_available_bytes() < 1:
		return snapshot
	var effect_count := buffer.get_u8()
	if buffer.get_available_bytes() < effect_count * 16:
		return snapshot
	for i in effect_count:
		var sequence := buffer.get_u16()
		var kind := buffer.get_u8()
		var net_id := buffer.get_u8()
		snapshot.effects.append([sequence, kind, net_id, _get_vector(buffer)])
	return snapshot


# --- Events ---


## A character for [constant Event.WELCOME] and [constant Event.CHARACTER_ADDED]:
## [net id, name, team, class index, peer id]. [param peer_id] is the player's peer id (1 for the
## host's own player), 0 for a bot.
static func character_entry(character: Character, peer_id: int) -> Array:
	return [character.net_id, String(character.name), character.team,
			maxi(ClassData.all().find(character.class_data), 0), peer_id]


static func _put_vector(buffer: StreamPeerBuffer, value: Vector3) -> void:
	buffer.put_float(value.x)
	buffer.put_float(value.y)
	buffer.put_float(value.z)


static func _get_vector(buffer: StreamPeerBuffer) -> Vector3:
	return Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
