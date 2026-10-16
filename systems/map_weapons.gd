class_name MapWeapons
extends Node
## Random map weapons (M7 task 16, D-098): guns that appear on the floor at random places, so the
## map has something worth fighting for that isn't always in the same place. Each one is a
## [WeaponSpot] (a gun floating and turning over a glowing ring, with its name and a beam of light),
## taken by walking over it like any gun on the floor.
##
## Where: anywhere on the walkable floor of the map's navmesh, picked at runtime (maps need no
## markers, so a new map gets map weapons for free), on the navmesh islands the spawns stand on
## (not on a roof nobody can reach), at least [member spawn_clearance] from every team spawn,
## [member respawn_clearance] from every respawn point when [member avoid_respawn_points] is on,
## off the bomb sites when [member avoid_bomb_sites] is on, [member spacing] apart, and with
## [constant ROOM] to the nearest wall or crate. When the
## map is too small for that, the spacing shrinks first, then the other distances, until it fits.
##
## Which gun: a weighted draw from [member pool] (the Hornet most often, the Heron rarest), never
## the same gun twice at once while the pool has others.
##
## When: the rules call [method replace_all] at every round start (rounds: [member count] new guns,
## the old ones gone). With [member replace_time] of 0 or more (Team Deathmatch), a gun that is
## taken is replaced that many seconds later by a new one somewhere else, so [member count] are
## out at a time. Time counts in physics ticks (the pause stops it).
##
## Every draw comes from [member rng], the round manager's seeded generator (or one seeded from
## it), so tests repeat. Authority code: in M9 the host decides where and what, and the clients
## show the spots.

## Emitted when a gun appears on the map.
signal weapon_placed(spot: WeaponSpot)

const SPOT_SCENE := preload("res://weapons/weapon_spot.tscn")
## Spawn marker groups whose distance counts as [member spawn_clearance].
const SPAWN_GROUPS: Array[String] = [Teams.ATTACK_SPAWN_GROUP, Teams.DEFEND_SPAWN_GROUP]
## The respawn points' group ([constant RespawnMatch.RESPAWN_GROUP]).
const RESPAWN_POINT_GROUP := "respawn_points"
## How often the distances shrink when a gun doesn't fit, and by how much each time: the spacing
## between guns twice, then the distances from the spawns.
const RELAX_STEPS := 4
const RELAX_FACTOR := 0.7
## Random floor points tried per gun at each distance.
const TRIES := 64
## A gun needs this much room around it (metres, to walls and crates), so its ring doesn't run into
## a wall and it's easy to see and walk over.
const ROOM := 0.8

## Which guns appear, by weapon id, with their weights (out of the sum).
@export var pool: Dictionary = {&"smg": 30, &"carbine": 20, &"rifle": 15, &"shotgun": 15, &"hand_cannon": 10, &"sniper": 10}
## How many guns are out at a time.
@export var count: int = 2
## Seconds before a taken gun is replaced elsewhere; below 0, it isn't (rounds).
@export var replace_time: float = -1.0
## Metres (flat) a gun keeps from every team spawn.
@export var spawn_clearance: float = 15.0
## Metres (flat) from every respawn point, when [member avoid_respawn_points].
@export var respawn_clearance: float = 8.0
## Keep away from the respawn points too (Team Deathmatch).
@export var avoid_respawn_points: bool = false
## Keep off the bomb sites, by this margin in metres (bomb rounds).
@export var avoid_bomb_sites: bool = false
@export var site_margin: float = 2.0
## Metres (flat) between two guns.
@export var spacing: float = 15.0

## The seeded generator every draw comes from. Set before [method replace_all].
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## The walkable floor: [code][a, b, c, cumulative area][/code] per triangle, world positions.
var _triangles: Array = []
var _area: float = 0.0
var _floor_ready: bool = false
## The guns out now.
var _spots: Array[WeaponSpot] = []
## Seconds until each waiting replacement.
var _waiting: Array[float] = []


func _physics_process(delta: float) -> void:
	if _waiting.is_empty():
		return
	for i in range(_waiting.size() - 1, -1, -1):
		_waiting[i] -= delta
		if _waiting[i] <= 0.0:
			_waiting.remove_at(i)
			place_one()


## The guns out on the map now.
func get_spots() -> Array[WeaponSpot]:
	var out_now: Array[WeaponSpot] = []
	for spot in _spots:
		if is_instance_valid(spot) and not spot.is_queued_for_deletion():
			out_now.append(spot)
	_spots = out_now
	return _spots


## Takes every gun away and puts [member count] new ones out (a round start).
func replace_all() -> void:
	clear()
	for i in count:
		place_one()


## Takes every gun away, and forgets the replacements waiting.
func clear() -> void:
	for spot in _spots:
		if is_instance_valid(spot):
			spot.clear()
			spot.queue_free()
	_spots.clear()
	_waiting.clear()


## Puts one more gun out at a random place. Returns its spot, or null when the map has no
## floor for it.
func place_one() -> WeaponSpot:
	var data := pick_weapon()
	var place := pick_place()
	if data == null or place.is_empty():
		return null
	var spot: WeaponSpot = SPOT_SCENE.instantiate()
	spot.weapon = data
	spot.name = "MapWeapon_%s" % data.id
	add_child(spot, true)
	spot.global_position = place.position
	spot.rotation.y = rng.randf() * TAU
	spot.taken.connect(_on_taken.bind(spot))
	_spots.append(spot)
	weapon_placed.emit(spot)
	return spot


## A weighted draw from [member pool], avoiding the guns already out while the pool has others.
func pick_weapon() -> WeaponData:
	var out_now: Array[StringName] = []
	for spot in get_spots():
		if spot.weapon != null:
			out_now.append(spot.weapon.id)
	var choices: Array[StringName] = []
	for id: StringName in pool:
		if not out_now.has(id) and WeaponData.find(id) != null:
			choices.append(id)
	if choices.is_empty():
		for id: StringName in pool:
			if WeaponData.find(id) != null:
				choices.append(id)
	if choices.is_empty():
		return null
	var total := 0
	for id in choices:
		total += int(pool[id])
	var roll := rng.randi_range(1, maxi(total, 1))
	for id in choices:
		roll -= int(pool[id])
		if roll <= 0:
			return WeaponData.find(id)
	return WeaponData.find(choices[-1])


## A random floor place that keeps the distances (see the class description), as
## [code]{position}[/code]; empty when the map has no floor at all.
func pick_place() -> Dictionary:
	_build_floor()
	if _triangles.is_empty():
		return {}
	var spawns := _positions(SPAWN_GROUPS)
	var respawns: Array[Vector3] = []
	if avoid_respawn_points:
		respawns = _positions([RESPAWN_POINT_GROUP])
	var others: Array[Vector3] = []
	for spot in get_spots():
		others.append(spot.global_position)
	var sites: Array = []
	if avoid_bomb_sites:
		sites = _site_boxes()
	for step in RELAX_STEPS + 1:
		# The guns' spacing gives way first, the distance from the spawns only after it.
		var apart := spacing * pow(RELAX_FACTOR, mini(step, 2))
		var clear := pow(RELAX_FACTOR, maxi(step - 2, 0))
		for attempt in TRIES:
			var point := _random_floor_point()
			if _keeps_away(point, spawns, spawn_clearance * clear) and _keeps_away(point, respawns, respawn_clearance * clear) \
					and _keeps_away(point, others, apart) and not _on_site(point, sites):
				var floor_point := _floor_under(point)
				if _has_room(floor_point):
					return {"position": floor_point}
	# Nothing kept every distance even at the smallest: anywhere on the floor will do.
	return {"position": _floor_under(_random_floor_point())}


func _on_taken(_by: Character, spot: WeaponSpot) -> void:
	_spots.erase(spot)
	if replace_time >= 0.0:
		_waiting.append(replace_time)


# --- The floor ---


## Reads the map's navmesh once: the triangles of the islands the spawns stand on.
func _build_floor() -> void:
	if _floor_ready:
		return
	_floor_ready = true
	_triangles.clear()
	_area = 0.0
	var markers := _positions(SPAWN_GROUPS + [RESPAWN_POINT_GROUP])
	for node in _map().find_children("*", "NavigationRegion3D", true, false):
		var region := node as NavigationRegion3D
		if region.navigation_mesh == null:
			continue
		_add_region(region, markers)


func _add_region(region: NavigationRegion3D, markers: Array[Vector3]) -> void:
	var mesh := region.navigation_mesh
	var vertices := mesh.get_vertices()
	var world := PackedVector3Array()
	for vertex in vertices:
		world.append(region.global_transform * vertex)
	var polygon_count := mesh.get_polygon_count()
	# Islands: polygons that share a vertex are connected (union-find over polygon numbers).
	var parent: Array[int] = []
	for i in polygon_count:
		parent.append(i)
	var first_with_vertex := {}
	for i in polygon_count:
		for index in mesh.get_polygon(i):
			var key := Vector3i((vertices[index] * 20.0).round())
			if first_with_vertex.has(key):
				var a := _root(parent, i)
				var b := _root(parent, first_with_vertex[key])
				if a != b:
					parent[a] = b
			else:
				first_with_vertex[key] = i
	# The islands the spawn markers stand on (the nearest polygon to each marker).
	var keep := {}
	for marker in markers:
		var best := -1
		var best_distance := INF
		for i in polygon_count:
			var distance := _centre(mesh.get_polygon(i), world).distance_squared_to(marker)
			if distance < best_distance:
				best = i
				best_distance = distance
		if best >= 0:
			keep[_root(parent, best)] = true
	for i in polygon_count:
		if not markers.is_empty() and not keep.has(_root(parent, i)):
			continue
		var polygon := mesh.get_polygon(i)
		for k in range(1, polygon.size() - 1):
			var a := world[polygon[0]]
			var b := world[polygon[k]]
			var c := world[polygon[k + 1]]
			_area += (b - a).cross(c - a).length() * 0.5
			_triangles.append([a, b, c, _area])


func _root(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _centre(polygon: PackedInt32Array, world: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for index in polygon:
		sum += world[index]
	return sum / maxf(polygon.size(), 1.0)


## A random point on the floor, every square metre as likely as any other.
func _random_floor_point() -> Vector3:
	var roll := rng.randf() * _area
	var low := 0
	var high := _triangles.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if _triangles[middle][3] < roll:
			low = middle + 1
		else:
			high = middle
	var triangle: Array = _triangles[low]
	var u := rng.randf()
	var v := rng.randf()
	if u + v > 1.0:
		u = 1.0 - u
		v = 1.0 - v
	var a: Vector3 = triangle[0]
	return a + (triangle[1] - a) * u + (triangle[2] - a) * v


## The floor right under a navmesh point (the navmesh floats a little above it).
func _floor_under(point: Vector3) -> Vector3:
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world == null:
		return point
	var space := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 1.5, PhysicsLayers.WORLD)
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else point


## The map: the round manager's parent (this node is the round manager's child), else the parent.
func _map() -> Node:
	return get_parent().get_parent() if get_parent() is RoundManager else get_parent()


## True if nothing solid is within [constant ROOM] of the gun's spot, from knee to head height.
func _has_room(floor_point: Vector3) -> bool:
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world == null:
		return true
	var sphere := SphereShape3D.new()
	sphere.radius = ROOM
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, floor_point + Vector3.UP * (ROOM + 0.25))
	query.collision_mask = PhysicsLayers.WORLD
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _positions(groups: Array) -> Array[Vector3]:
	var map := _map()
	var out: Array[Vector3] = []
	for group: String in groups:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D and map.is_ancestor_of(node):
				out.append((node as Node3D).global_position)
	return out


func _keeps_away(point: Vector3, from: Array, distance: float) -> bool:
	for other: Vector3 in from:
		if Vector2(point.x - other.x, point.z - other.z).length() < distance:
			return false
	return true


## Each bomb site's box shapes, as [code][inverse transform, half size + margin][/code].
func _site_boxes() -> Array:
	var map := _map()
	var boxes: Array = []
	for node in get_tree().get_nodes_in_group(Bomb.SITE_GROUP):
		if not map.is_ancestor_of(node):
			continue
		for child in node.get_children():
			var shape := child as CollisionShape3D
			if shape != null and shape.shape is BoxShape3D:
				var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5 + Vector3(site_margin, 2.0, site_margin)
				boxes.append([shape.global_transform.affine_inverse(), half])
	return boxes


func _on_site(point: Vector3, boxes: Array) -> bool:
	for box: Array in boxes:
		var local: Vector3 = (box[0] as Transform3D) * point
		var half: Vector3 = box[1]
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	return false
