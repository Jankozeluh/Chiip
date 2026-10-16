class_name NetProtocol
extends RefCounted
## The packets of the game stream (M9, D-101): what each kind of packet holds and how it is
## packed into bytes. Every packet starts with one byte, its [enum Message] type.
##
## Packing by hand ([StreamPeerBuffer], like a C struct written field by field) keeps a
## 5v5 snapshot at about 500 bytes; [method @GlobalScope.var_to_bytes] would need several times
## that, because every value carries its type with it. Events are rare, so they use
## [code]var_to_bytes[/code] for simplicity.
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
	## Host → clients, reliable: something that happened (a kill, a round's end, the bomb...).
	EVENT = 3,
	## Either way, reliable: a request or an answer that must arrive (class changes...).
	REQUEST = 4,
}


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
