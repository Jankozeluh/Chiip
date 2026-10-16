class_name Acoustics
extends Node
## The listener's side of Chiip's sound (M13, D-190): every game sound plays through
## [method play] (from a position) or [method play_2d] (your own, without one), which set the
## player up from its [SoundMix] category first.
##
## Everything here is worked out on each computer for its own listener, from the map and from
## where the sound comes from, which the network already sends (a puppet's shot, its steps,
## the bomb). So online everyone hears the same thing from the same place (D-190).

## Plays [param stream] on [param player] as a 3D sound of [SoundMix] [param category],
## [param offset_db] louder (a gun's own loudness, D-191), carrying [param range_factor] times
## as far (the Scout's quieter steps). Changing a player's stream stops what it's still playing
## (the last shot's tail), so the stream is only set when it changes.
static func play(player: AudioStreamPlayer3D, stream: AudioStream, category: StringName, offset_db: float = 0.0, range_factor: float = 1.0) -> void:
	if stream == null or not player.is_inside_tree():
		return
	SoundMix.apply_3d(player, category, offset_db)
	player.max_distance *= range_factor
	if player.stream != stream:
		player.stream = stream
	player.play()


## Plays a sound that has a distant variant (a gun's shot, an explosion; D-191): [param stream]
## on [param close] as [param category] and, from [constant SoundMix.FAR_FROM] metres on,
## [param far_stream] on [param far] as [param far_category], crossfading into it by
## [constant SoundMix.FAR_TO] metres. Without a far stream or a listener only the close one plays;
## without a close stream (a silenced test bomb) neither does.
static func play_with_far(close: AudioStreamPlayer3D, far: AudioStreamPlayer3D, stream: AudioStream, far_stream: AudioStream,
		category: StringName, far_category: StringName, offset_db: float = 0.0) -> void:
	if stream == null:
		return
	var far_share := 0.0
	var listener := get_listener(close) if far_stream != null and close.is_inside_tree() else null
	if listener != null:
		far_share = SoundMix.far_share(listener.global_position.distance_to(close.global_position))
	play(close, stream, category, offset_db + SoundMix.CLOSE_AT_FAR_DB * far_share)
	if far_share > 0.0:
		play(far, far_stream, far_category, offset_db + linear_to_db(far_share))


## Plays [param stream] on [param player] as your own sound of [param category] (both ears,
## no position), [param offset_db] louder.
static func play_2d(player: AudioStreamPlayer, stream: AudioStream, category: StringName, offset_db: float = 0.0) -> void:
	if stream == null or not player.is_inside_tree():
		return
	SoundMix.apply_2d(player, category, offset_db)
	if player.stream != stream:
		player.stream = stream
	player.play()


## Where the sounds of [param node]'s world are heard from: the current camera of its
## viewport (the world's [SubViewport] listens, `main.tscn`). Null without a camera.
static func get_listener(node: Node) -> Camera3D:
	var viewport := node.get_viewport()
	return viewport.get_camera_3d() if viewport != null else null
