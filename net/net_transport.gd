class_name NetTransport
extends RefCounted
## How a [NetSession] reaches the other computers (M9, D-114): the one place that knows which
## kind of connection the game uses. A transport makes the [MultiplayerPeer] that Godot's
## high-level multiplayer talks through, and does the few things the session needs from the
## connection itself: setting up a new connection, the ping, sending what is queued at once,
## and dropping a connection politely. Everything above it (the roster's RPCs, the game stream,
## [NetHost], [NetClient]) only ever sees the [MultiplayerPeer], so another kind of connection
## is one more subclass. Like the transports of Unity's Netcode (Unity Transport, a Steam one):
## the game code above doesn't change.
##
## This base class is the interface and does nothing; [EnetTransport] (UDP to an IP address and
## port, for a LAN or a forwarded port) is the only transport so far. A Steam one (GodotSteam's
## [code]SteamMultiplayerPeer[/code], joined through a Steam lobby or an invite instead of an
## address) is deferred (D-114).

## The peer made by [method host] or [method join], or null before.
var peer: MultiplayerPeer


## Opens a game for at most [param max_clients] clients, on [param port] where the transport has
## ports. Returns OK and sets [member peer], or the error (for example ERR_CANT_CREATE when the
## port is taken).
func host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


## Starts connecting to the host at [param address] (and [param port] where the transport has
## ports). Returns OK and sets [member peer] when the attempt started, or the error. The session
## learns from [member peer]'s signals whether it worked.
func join(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


## Sets up a new connection to [param peer_id] (each client on the host, the host on a client).
func configure_connection(_peer_id: int) -> void:
	pass


## Sends what is queued now (so a last message gets out before a connection is closed).
func flush() -> void:
	pass


## The round-trip time to [param peer_id] in milliseconds, as the connection measures it, or -1
## when it doesn't ([NetClient] measures its own from the commands).
func get_ping_ms(_peer_id: int) -> int:
	return -1


## Drops the connection to [param peer_id] once what is queued for it has been sent.
func disconnect_later(peer_id: int) -> void:
	if peer != null:
		peer.disconnect_peer(peer_id)


## Closes every connection.
func close() -> void:
	if peer != null:
		peer.close()
