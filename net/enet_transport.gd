class_name EnetTransport
extends NetTransport
## The LAN transport (M9, D-100, D-114): Godot's ENet peer, reliable and unreliable UDP packets
## to an IP address and port. ENet is a small library on top of UDP, like Unity Transport: it
## numbers the packets, sends the reliable ones again until they arrive, and keeps channels
## apart, so a lost unreliable snapshot never holds up a reliable kill event.
##
## Two of ENet's helpers are turned off (D-103): its bandwidth limit and its throttle, which drop
## unreliable packets when the round trip wobbles. The game stream repeats what matters itself,
## so a packet ENet throws away only ever costs.

## Channels: [constant NetSession.RELIABLE_CHANNEL] and [constant NetSession.UNRELIABLE_CHANNEL].
const CHANNELS := 2
## Milliseconds without an answer before ENet drops a connection (between these bounds), so a
## lost friend is noticed within seconds instead of ENet's default half a minute.
const TIMEOUT_MIN_MS := 3000
const TIMEOUT_MAX_MS := 8000


func host(port: int, max_clients: int) -> Error:
	var enet := ENetMultiplayerPeer.new()
	var result := enet.create_server(port, max_clients, CHANNELS, 0, 0)
	if result != OK:
		return result
	# No bandwidth limit, said out loud: without this call ENet's bandwidth throttle cut the
	# unreliable packets to 1 in 32 in the tests (D-103).
	enet.host.bandwidth_limit(0, 0)
	peer = enet
	return OK


func join(address: String, port: int) -> Error:
	var enet := ENetMultiplayerPeer.new()
	var result := enet.create_client(address, port, CHANNELS, 0, 0)
	if result != OK:
		return result
	enet.host.bandwidth_limit(0, 0)
	peer = enet
	return OK


func configure_connection(peer_id: int) -> void:
	var connection := _connection(peer_id)
	if connection == null:
		return
	connection.set_timeout(32, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
	# The throttle's deceleration of 0: it never slows down (drops) unreliable packets.
	connection.throttle_configure(5000, 2, 0)


func flush() -> void:
	var enet := peer as ENetMultiplayerPeer
	if enet != null and enet.host != null:
		enet.host.flush()


func get_ping_ms(peer_id: int) -> int:
	var connection := _connection(peer_id)
	if connection == null:
		return -1
	return int(connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func disconnect_later(peer_id: int) -> void:
	var connection := _connection(peer_id)
	if connection != null:
		# ENet sends what is queued (a refusal) before it disconnects.
		connection.peer_disconnect_later()
	else:
		super(peer_id)


## ENet's own connection to [param peer_id], or null.
func _connection(peer_id: int) -> ENetPacketPeer:
	var enet := peer as ENetMultiplayerPeer
	if enet == null or enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return null
	return enet.get_peer(peer_id)
