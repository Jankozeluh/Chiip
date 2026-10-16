class_name Acoustics
extends Node
## The listener's side of Chiip's sound (M13, D-190): every game sound plays through
## [method play] (from a position) or [method play_2d] (your own, without one), which set the
## player up from its [SoundMix] category first.
##
## Behind walls a sound is muffled (D-192): [method occlusion] traces the straight path from the
## sound to the listener through the map, and [method play] turns what it finds into a quieter
## sound on one of [SoundMix]'s muffled buses.
##
## As a node (`main.gd` puts one in the world's viewport), it follows the listener (D-193): four
## times a second [method probe] looks around the camera with rays (sky above? walls how far?)
## and names its [enum SoundMix.Zone]; the Effects bus's reverb glides to that zone's
## [constant SoundMix.REVERB] preset. No map needs zones drawn in.
##
## Everything here is worked out on each computer for its own listener, from the map and from
## where the sound comes from, which the network already sends (a puppet's shot, its steps,
## the bomb). So online everyone hears the same thing from the same place (D-190).

## How far a sound's source is lifted before tracing to the listener, in metres.
const SOURCE_LIFT := 0.3
## How far beside or above either end a path round a corner may bend, in metres.
const AROUND_OFFSET := 1.5
## Walls counted along a path at most (each costs a ray from each end).
const MAX_WALLS := 4
## Seconds between two looks around the listener, and how fast the reverb follows a new zone
## (the time constant of its glide, in seconds).
const PROBE_INTERVAL := 0.25
const GLIDE_TIME := 0.4
## How far the zone probe looks up and around, in metres; walls nearer than ENCLOSED_WITHIN
## enclose the listener.
const SKY_REACH := 40.0
const WALL_REACH := 30.0
const ENCLOSED_WITHIN := 20.0

## The listener's zone, as last probed.
var zone: SoundMix.Zone = SoundMix.Zone.OPEN
## What the last probe saw ([method probe]'s result; empty before the first).
var last_probe: Dictionary = {}

var _reverb: AudioEffectReverb
## The reverb's values when the game started, put back when this node leaves.
var _initial: Dictionary = {}
var _probe_left: float = 0.0
var _probed: bool = false


func _ready() -> void:
	var bus := AudioServer.get_bus_index(SoundMix.BUS_EFFECTS)
	for index in AudioServer.get_bus_effect_count(bus) if bus >= 0 else 0:
		_reverb = AudioServer.get_bus_effect(bus, index) as AudioEffectReverb
		if _reverb != null:
			break
	if _reverb != null:
		for key: String in SoundMix.REVERB[SoundMix.Zone.OPEN]:
			_initial[key] = _reverb.get(key)


func _exit_tree() -> void:
	# Back to the layout's dry reverb, so the menu and the next game start clean.
	if _reverb != null:
		for key: String in _initial:
			_reverb.set(key, _initial[key])


func _physics_process(delta: float) -> void:
	_probe_left -= delta
	if _probe_left <= 0.0:
		_probe_left = PROBE_INTERVAL
		var camera := get_listener(self)
		if camera != null and camera.is_inside_tree():
			last_probe = probe(camera.get_world_3d().direct_space_state, camera.global_position)
			zone = last_probe.zone
	if _reverb == null or last_probe.is_empty():
		return
	# The first look sets the reverb at once; after that it glides.
	var weight := 1.0 if not _probed else 1.0 - exp(-delta / GLIDE_TIME)
	_probed = true
	var target: Dictionary = SoundMix.REVERB[zone]
	for key: String in target:
		_reverb.set(key, lerpf(_reverb.get(key), target[key], weight))


## Looks around [param position] in [param space]'s map (D-193): five rays up (straight and at
## 45° four ways) and eight level ones. {"zone": a [enum SoundMix.Zone], "sky": the share of up
## rays that reach the sky, "enclosure": the share of level rays that meet a wall within
## [constant ENCLOSED_WITHIN] m, "size": the mean distance to the walls, "ceiling": the height of
## the ceiling (INF under the sky)}. Under a roof (a ceiling straight up, and at most two up rays
## see the sky): a hall when the ceiling is 5 m up or more, or 3.5 m with the walls 10 m away on
## average, else a room (a low room stays a room however wide); under the sky: a yard when three
## quarters of the way round is walled within 20 m, else open.
static func probe(space: PhysicsDirectSpaceState3D, position: Vector3) -> Dictionary:
	var up_rays: Array[Vector3] = [Vector3.UP]
	for angle in 4:
		up_rays.append((Vector3.UP + Vector3.FORWARD.rotated(Vector3.UP, angle * TAU / 4.0)).normalized())
	var sky := 0
	var ceiling := INF
	for direction in up_rays:
		var hit := _ray(space, position, position + direction * SKY_REACH)
		if hit.is_empty():
			sky += 1
		elif direction == Vector3.UP:
			ceiling = (hit.position as Vector3).y - position.y
	var walled := 0
	var total := 0.0
	for angle in 8:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, angle * TAU / 8.0)
		var hit := _ray(space, position, position + direction * WALL_REACH)
		var distance := WALL_REACH if hit.is_empty() else position.distance_to(hit.position)
		total += distance
		if distance <= ENCLOSED_WITHIN:
			walled += 1
	var result := {"sky": sky / 5.0, "enclosure": walled / 8.0, "size": total / 8.0, "ceiling": ceiling}
	if ceiling < INF and sky <= 2:
		var tall: bool = ceiling >= 5.0 or (ceiling >= 3.5 and result.size >= 10.0)
		result.zone = SoundMix.Zone.HALL if tall else SoundMix.Zone.ROOM
	else:
		result.zone = SoundMix.Zone.YARD if walled >= 6 else SoundMix.Zone.OPEN
	return result


## The first thing of the map on the line from [param from] to [param to] (empty if none).
static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.hit_back_faces = false
	return space.intersect_ray(query)


## Plays [param stream] on [param player] as a 3D sound of [SoundMix] [param category],
## [param offset_db] louder (a gun's own loudness, D-191), carrying [param range_factor] times
## as far (the Scout's quieter steps). Changing a player's stream stops what it's still playing
## (the last shot's tail), so the stream is only set when it changes.
static func play(player: AudioStreamPlayer3D, stream: AudioStream, category: StringName, offset_db: float = 0.0, range_factor: float = 1.0) -> void:
	if stream == null or not player.is_inside_tree():
		return
	SoundMix.apply_3d(player, category, offset_db)
	player.max_distance *= range_factor
	_muffle(player, category)
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


## What lies between a sound at [param source] and a listener at [param listener] in
## [param space]'s map (D-192): {"walls": walls crossed, "thickness": metres of wall,
## "around": a path round a corner is open, "loss_db": how much quieter, "bus": where it plays}.
## Clear: no loss, the Effects bus. Round a corner (1.5 m to a side or above either end, both
## legs open): [constant SoundMix.AROUND_DB], MuffledLight. Otherwise [constant SoundMix.WALL_DB]
## per wall and [constant SoundMix.WALL_METRE_DB] per metre, Muffled or (from
## [constant SoundMix.HEAVY_FROM_DB]) MuffledHeavy. Only the map counts (the World layer).
static func occlusion(space: PhysicsDirectSpaceState3D, source: Vector3, listener: Vector3) -> Dictionary:
	var result := {"walls": 0, "thickness": 0.0, "around": false, "loss_db": 0.0, "bus": SoundMix.BUS_EFFECTS}
	# A step's player sits at the feet: lift every source a little so the floor under it doesn't count.
	var from := source + Vector3.UP * SOURCE_LIFT
	if _is_clear(space, from, listener):
		return result
	if _gets_around(space, from, listener):
		result.around = true
		result.loss_db = SoundMix.AROUND_DB
		result.bus = SoundMix.BUS_MUFFLED_LIGHT
		return result
	var length := from.distance_to(listener)
	var entries := _entries(space, from, listener)
	var exits := _entries(space, listener, from)
	result.walls = maxi(entries.size(), 1)
	result.thickness = _thickness(entries, exits, length)
	result.loss_db = minf(SoundMix.WALL_DB * result.walls + SoundMix.WALL_METRE_DB * result.thickness, SoundMix.MAX_WALL_LOSS_DB)
	result.bus = SoundMix.BUS_MUFFLED_HEAVY if result.loss_db >= SoundMix.HEAVY_FROM_DB else SoundMix.BUS_MUFFLED
	return result


## Muffles [param player] (already set up as [param category]) by what lies between it and the
## listener: quieter by the loss times the category's occlusion share, and filtered by that
## share's loss (so a shot needs more wall than a step to be filtered hard, and the bomb's
## beep never is).
static func _muffle(player: AudioStreamPlayer3D, category: StringName) -> void:
	var share: float = SoundMix.get_values(category).get("occlusion", 0.0)
	var listener := get_listener(player) if share > 0.0 else null
	if listener == null:
		return
	var heard := occlusion(player.get_world_3d().direct_space_state, player.global_position, listener.global_position)
	var loss: float = heard.loss_db * share
	player.volume_db -= loss
	if heard.around:
		player.bus = SoundMix.BUS_MUFFLED_LIGHT
	elif loss > 0.0:
		player.bus = SoundMix.BUS_MUFFLED_HEAVY if loss >= SoundMix.HEAVY_FROM_DB else SoundMix.BUS_MUFFLED


## True when nothing of the map is in the way from [param from] to [param to]. Back faces don't
## count, so a ray that starts inside a wall leaves it freely.
static func _is_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return _ray(space, from, to).is_empty()


## True when a bent path from [param from] to [param to] is open: through a point
## [constant AROUND_OFFSET] beside or above either end that the end itself can reach.
static func _gets_around(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var side := (to - from).cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	for ends in [[to, from], [from, to]]:
		for offset: Vector3 in [side * AROUND_OFFSET, -side * AROUND_OFFSET, Vector3.UP * AROUND_OFFSET]:
			var bend: Vector3 = ends[0] + offset
			if _is_clear(space, ends[0], bend) and _is_clear(space, ends[1], bend):
				return true
	return false


## The distances from [param from] at which the path to [param to] enters the map's walls (front
## faces only, at most [constant MAX_WALLS]). Traced from the other end, they are the exits.
static func _entries(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> PackedFloat32Array:
	var entries := PackedFloat32Array()
	var direction := from.direction_to(to)
	var length := from.distance_to(to)
	var start := 0.0
	while entries.size() < MAX_WALLS and start < length:
		var query := PhysicsRayQueryParameters3D.create(from + direction * start, to, PhysicsLayers.WORLD)
		query.hit_back_faces = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var distance := (hit.position as Vector3 - from).dot(direction)
		entries.append(distance)
		start = distance + 0.01
	return entries


## Metres of wall along a path [param length] long: the stretches between each entry and its exit
## ([param exits] measured from the far end), overlapping walls counted once.
static func _thickness(entries: PackedFloat32Array, exits: PackedFloat32Array, length: float) -> float:
	var events: Array[Vector2] = []
	for entry in entries:
		events.append(Vector2(entry, 1.0))
	for exit in exits:
		events.append(Vector2(length - exit, -1.0))
	events.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var depth := 0
	var inside := 0.0
	var last := 0.0
	for event in events:
		if depth > 0:
			inside += event.x - last
		depth = maxi(depth + int(event.y), 0)
		last = event.x
	if depth > 0:
		inside += length - last
	return inside
