extends SceneTree
## Tool: measures a map's layout, for tuning and for docs/MAPS.md: its size,
## walking distances (spawn to spawn, spawns to the bomb sites, each attack
## route) and its sightlines, the longest straight views at eye height between
## spots you can stand on. Run after building and baking a map:
##
##     Godot --headless --path . --quit-after 5000 --script res://tools/map_report.gd -- res://maps/depot.tscn
##
## Prints a report and changes nothing.

## Eye height of a standing player (CS: 64 units).
const EYE_HEIGHT := 64.0 * 0.0254
## Spacing of the spots sampled for sightlines, in metres.
const GRID := 1.5
## Only views longer than this are traced (shorter ones don't matter for the report).
const MIN_REPORTED := 18.0
## Spots higher than this are roofs or wall tops, not floor.
const MAX_FLOOR_HEIGHT := 2.5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <map scene> [more map scenes]")
		quit(1)
		return
	for path in args:
		await _report(path)
	quit()


func _report(path: String) -> void:
	var map: Node3D = load(path).instantiate()
	root.add_child(map)
	# The tree only runs once _init() has returned: wait for a frame before using the world.
	await physics_frame
	var nav := map.get_world_3d().navigation_map
	var probe := _markers(map, "attack_spawns")[2].global_position
	# Wait until this map's region is the only one (the previous map's is gone)
	# and the navigation map has synchronized twice since.
	var region := map.find_children("*", "NavigationRegion3D", true, false)[0] as NavigationRegion3D
	var synced_from := -1
	for i in 120:
		await physics_frame
		var regions := NavigationServer3D.map_get_regions(nav)
		if regions.size() != 1 or regions[0] != region.get_rid():
			continue
		if synced_from < 0:
			synced_from = NavigationServer3D.map_get_iteration_id(nav)
		elif NavigationServer3D.map_get_iteration_id(nav) >= synced_from + 2:
			break
	print("\n=== %s ===" % path)
	var spots := _floor_spots(map, nav, probe)
	var bounds := Rect2(Vector2(spots[0].x, spots[0].z), Vector2.ZERO)
	for spot in spots:
		bounds = bounds.expand(Vector2(spot.x, spot.z))
	print("Walkable area: %.0f × %.0f m (x × z), %d spots sampled every %.1f m" % [bounds.size.x, bounds.size.y, spots.size(), GRID])

	var attack := _markers(map, "attack_spawns")[2].global_position
	var defend := _markers(map, "defend_spawns")[2].global_position
	print("Walk, spawn to spawn: %.0f m (straight line %.0f m)" % [_walk(nav, [attack, defend]), attack.distance_to(defend)])
	for site in _markers(map, "bomb_sites"):
		# The site's area stands 3 m tall on its floor; aim for the floor, not the crates.
		var goal := NavigationServer3D.map_get_closest_point(nav, site.global_position + Vector3.DOWN * 1.5)
		print("Walk to site %s: attackers %.0f m, defenders %.0f m" % [site.name.trim_prefix("BombSite"), _walk(nav, [attack, goal]), _walk(nav, [defend, goal])])
	for route in _markers(map, "attack_routes"):
		var points: Array[Vector3] = [attack]
		for point in route.get_children():
			points.append((point as Node3D).global_position)
		print("Route %s: %.0f m from the attackers' spawn" % [route.name.trim_prefix("Route"), _walk(nav, points)])

	var space := map.get_world_3d().direct_space_state
	var lines: Array = []
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var length := spots[i].distance_to(spots[j])
			if length >= MIN_REPORTED and _sees(space, spots[i], spots[j]):
				lines.append([length, spots[i], spots[j]])
	lines.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var over_25 := lines.filter(func(line: Array) -> bool: return line[0] > 25.0).size()
	var over_30 := lines.filter(func(line: Array) -> bool: return line[0] > 30.0).size()
	var over_40 := lines.filter(func(line: Array) -> bool: return line[0] > 40.0).size()
	print("Sightlines: longest %.0f m; %d spot pairs see each other over 25 m, %d over 30 m, %d over 40 m" % [
			lines[0][0] if not lines.is_empty() else 0.0, over_25, over_30, over_40])
	var shown: Array = []
	for line in lines:
		if shown.size() == 6:
			break
		var near := shown.any(func(other: Array) -> bool:
			return (line[1].distance_to(other[1]) < 6.0 and line[2].distance_to(other[2]) < 6.0) \
					or (line[1].distance_to(other[2]) < 6.0 and line[2].distance_to(other[1]) < 6.0))
		if not near:
			shown.append(line)
			print("  %.0f m: (%.0f, %.0f) ↔ (%.0f, %.0f)" % [line[0], line[1].x, line[1].z, line[2].x, line[2].z])

	var spawn_views := 0
	for a in _markers(map, "attack_spawns"):
		for d in _markers(map, "defend_spawns"):
			if _sees(space, _eye(a.global_position), _eye(d.global_position)):
				spawn_views += 1
	print("Spawn to spawn views: %d of 25 marker pairs" % spawn_views)
	map.queue_free()
	await process_frame


## Eye-height points over the floor on a grid, where someone can walk to from
## [param start] (so not on top of crates, which the navigation mesh also covers).
func _floor_spots(map: Node3D, nav: RID, start: Vector3) -> Array[Vector3]:
	var space := map.get_world_3d().direct_space_state
	var spots: Array[Vector3] = []
	for x in range(-40, 41):
		for z in range(-40, 41):
			var top := Vector3(x * GRID, 30.0, z * GRID)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 40.0, 1))
			if hit.is_empty() or hit.position.y > MAX_FLOOR_HEIGHT:
				continue
			var floor_point: Vector3 = hit.position
			var on_mesh := NavigationServer3D.map_get_closest_point(nav, floor_point)
			if on_mesh.distance_to(floor_point) > 0.6:
				continue
			var nav_path := NavigationServer3D.map_get_path(nav, start, on_mesh, true)
			if nav_path.is_empty() or nav_path[-1].distance_to(on_mesh) > 0.5:
				continue
			spots.append(_eye(floor_point))
	return spots


func _eye(feet: Vector3) -> Vector3:
	return feet + Vector3.UP * EYE_HEIGHT


func _sees(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()


## Walking distance along the navigation mesh through [param points] in order.
func _walk(nav: RID, points: Array[Vector3]) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		var nav_path := NavigationServer3D.map_get_path(nav, points[i - 1], points[i], true)
		for k in range(1, nav_path.size()):
			length += nav_path[k - 1].distance_to(nav_path[k])
	return length


func _markers(map: Node, group: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in map.get_tree().get_nodes_in_group(group):
		if map.is_ancestor_of(node):
			found.append(node as Node3D)
	return found
