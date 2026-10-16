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
