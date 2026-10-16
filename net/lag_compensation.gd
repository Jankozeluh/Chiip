class_name LagCompensation
extends RefCounted
## Lag compensation on the host (M9, D-107): the last second of everyone's hit zones, and a
## bullet test against them as they were at the moment a friend's screen showed.
##
## A friend sees everyone else a little in the past: half their ping for the snapshot to
## travel, plus the interpolation delay (D-104). If the host checked their shot against where
## the targets are *now*, they would have to lead every moving target by that much. So at the
## end of every tick [method record] stores each hit-zone box (one transform per zone), and
## [method trace] tests a shot against the boxes at the shooter's view tick
## ([member CharacterInput.view_tick]), interpolated between the two recorded ticks around it,
## at most [constant MAX_REWIND] seconds back. Walls are tested as they are now, with the
## physics engine's ray.
##
## The boxes are tested in code (a ray against an oriented box, the "slab" test) instead of
## moving the real [Hitbox] areas back in time, because the physics engine only moves bodies at
## the next physics step (CLAUDE.md, the Jolt gotcha). The hit is reported like a physics ray's
## result, so the weapon handles it the same way.

## How far back a shot may be checked, in seconds (CS allows 1 s; 0.4 s covers any normal ping).
const MAX_REWIND := 0.4
## Ticks of history kept: a second at 128 Hz.
const HISTORY := 128

## One recorded tick: the host tick and every zone's box then.
class Frame:
	var tick: int = 0
	## Hitbox → [Transform3D of its box, half its size, its character alive then].
	var boxes: Dictionary = {}

## Recorded ticks, oldest first.
var _frames: Array[Frame] = []


## Records the hit zones of [param characters] at the end of host tick [param tick].
func record(tick: int, characters: Array[Character]) -> void:
	var frame := Frame.new()
	frame.tick = tick
	for character in characters:
		if character.body == null:
			continue
		for hitbox in character.body.get_hitboxes():
			var shape := _box_of(hitbox)
			if shape == null:
				continue
			frame.boxes[hitbox] = [shape.global_transform, (shape.shape as BoxShape3D).size * 0.5, character.is_alive()]
	_frames.append(frame)
	while _frames.size() > HISTORY:
		_frames.pop_front()


## The newest recorded tick, or -1.
func newest_tick() -> int:
	return _frames.back().tick if not _frames.is_empty() else -1


## The tick a shot made at [param view_tick] is checked at: no further back than
## [constant MAX_REWIND] and no newer than the newest record.
func clamp_view_tick(view_tick: float) -> float:
	var newest := float(newest_tick())
	var oldest := newest - MAX_REWIND * Engine.physics_ticks_per_second
	if not _frames.is_empty():
		oldest = maxf(oldest, float(_frames[0].tick))
	return clampf(view_tick, oldest, newest)


## Where [param hitbox]'s box was at [param view_tick] (interpolated between records), or null
## when it wasn't recorded then.
func box_at(hitbox: Hitbox, view_tick: float) -> Variant:
	var pair := _frames_around(clamp_view_tick(view_tick))
	if pair.is_empty():
		return null
	var a: Frame = pair[0]
	var b: Frame = pair[1]
	if not a.boxes.has(hitbox) or not b.boxes.has(hitbox):
		return null
	var weight: float = pair[2]
	return (a.boxes[hitbox][0] as Transform3D).interpolate_with(b.boxes[hitbox][0], weight)


## Tests a bullet from [param from] to [param to], fired by [param shooter] at its command's
## view tick, against the world as it is and the hit zones as they were then. Zones whose
## [method CollisionObject3D.get_rid] is in [param exclude] (the shooter's own, teammates' with
## friendly fire off) and the zones of characters dead now don't count. Returns what
## [method PhysicsDirectSpaceState3D.intersect_ray] would: [code]position[/code],
## [code]normal[/code], [code]collider[/code], [code]shape[/code]; for a zone hit also
## [code]impact_position[/code] and [code]impact_normal[/code], the same spot on the body where
## the zone is now (for the bullet hole). Empty when nothing was hit.
func trace(shooter: Character, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	return trace_at(shooter, shooter.get_last_input().view_tick, from, to, exclude)


## [method trace] for a shot seen at [param view_tick] (host ticks).
func trace_at(shooter: Character, view_tick: float, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var space := shooter.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	var wall := space.intersect_ray(query)
	var best_distance := from.distance_to(wall.position) if not wall.is_empty() else from.distance_to(to)
	var pair := _frames_around(clamp_view_tick(view_tick))
	if pair.is_empty():
		return wall
	var a: Frame = pair[0]
	var b: Frame = pair[1]
	var weight: float = pair[2]
	var direction := (to - from).normalized()
	var best: Hitbox = null
	var best_box := Transform3D()
	var best_normal := Vector3.ZERO
	for key: Variant in a.boxes:
		if not is_instance_valid(key) or not b.boxes.has(key):
			continue
		var hitbox := key as Hitbox
		var owner := _character_of(hitbox)
		if owner == null or owner == shooter or not owner.is_alive() or not a.boxes[hitbox][2]:
			continue
		if exclude.has(hitbox.get_rid()):
			continue
		var box := (a.boxes[hitbox][0] as Transform3D).interpolate_with(b.boxes[hitbox][0], weight)
		var hit := ray_box(from, direction, box, a.boxes[hitbox][1])
		if hit.is_empty() or hit[0] >= best_distance:
			continue
		best_distance = hit[0]
		best = hitbox
		best_box = box
		best_normal = hit[1]
	if best == null:
		return wall
	var position := from + direction * best_distance
	var now := _box_of(best).global_transform
	var local := best_box.affine_inverse() * position
	return {
		"position": position,
		"normal": best_normal,
		"collider": best,
		"collider_id": best.get_instance_id(),
		"rid": best.get_rid(),
		"shape": 0,
		"impact_position": now * local,
		"impact_normal": (now.basis * (best_box.basis.inverse() * best_normal)).normalized(),
	}


## Where a ray from [param from] along the unit [param direction] enters the box
## [param box] (centre and orientation) with [param half_size]: [distance, normal], or empty if
## it misses or the box is behind. A ray starting inside the box hits at distance 0.
static func ray_box(from: Vector3, direction: Vector3, box: Transform3D, half_size: Vector3) -> Array:
	var inverse := box.affine_inverse()
	var origin := inverse * from
	var heading := inverse.basis * direction
	var enter := -INF
	var leave := INF
	var enter_axis := -1
	var enter_sign := 0.0
	for axis in 3:
		if absf(heading[axis]) < 1e-9:
			if origin[axis] < -half_size[axis] or origin[axis] > half_size[axis]:
				return []
			continue
		var near := (-half_size[axis] - origin[axis]) / heading[axis]
		var far := (half_size[axis] - origin[axis]) / heading[axis]
		var sign := -1.0
		if near > far:
			var swap := near
			near = far
			far = swap
			sign = 1.0
		if near > enter:
			enter = near
			enter_axis = axis
			enter_sign = sign
		leave = minf(leave, far)
	if leave < maxf(enter, 0.0):
		return []
	var local_normal := Vector3.ZERO
	if enter >= 0.0 and enter_axis >= 0:
		local_normal[enter_axis] = enter_sign
	else:
		local_normal = -heading.normalized()
	var distance := maxf(enter, 0.0)
	var world_point := box * (origin + heading * distance)
	return [from.distance_to(world_point), (box.basis * local_normal).normalized()]


## The two recorded frames around [param tick] and how far between them it is: [a, b, weight],
## or empty without records.
func _frames_around(tick: float) -> Array:
	if _frames.is_empty():
		return []
	for i in range(_frames.size() - 1, -1, -1):
		if float(_frames[i].tick) <= tick:
			if i == _frames.size() - 1:
				return [_frames[i], _frames[i], 0.0]
			var a := _frames[i]
			var b := _frames[i + 1]
			return [a, b, clampf((tick - a.tick) / float(maxi(b.tick - a.tick, 1)), 0.0, 1.0)]
	return [_frames[0], _frames[0], 0.0]


static func _box_of(hitbox: Hitbox) -> CollisionShape3D:
	for child in hitbox.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child
	return null


static func _character_of(hitbox: Hitbox) -> Character:
	var node: Node = hitbox.get_parent()
	while node != null and not node is Character:
		node = node.get_parent()
	return node as Character
