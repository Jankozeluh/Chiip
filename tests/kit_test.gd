extends Node
## Automated checks for the map kit (M10, D-121 to D-129). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/kit_test.tscn
##
## The texture library: every texture of the four sets is 64 × 64, keeps the
## look rules (measured like tools/texture_report.gd), has its material, and
## footsteps and impacts know what it's made of from its name.
## The props (D-122, D-123): every generated prop scene has its model, the
## collision its kind needs and a surface; every one is a TrenchBroom entity in
## the kit's FGD with its display model; and props placed in a .map file
## (tests/maps/kit_props.map) build into the map where they were put, stop
## rays like walls do (or not, for decoration), sound like what they're made
## of, and are cut out of a navmesh baked around them.
## The lamps (D-124): every lamp makes its light and has a glowing part, and a
## lamp placed in a .map takes the colour, brightness and range set there.
## The kit gallery (D-125, D-129), built only from TrenchBroom entities: its
## spawns, bomb sites, routes, hold spots, respawn and patrol points become
## the same markers as in the hand-made maps, it shows every prop, lamp and
## set texture, its see-through brushes block only movement, and both spawns
## can walk to both sites. (tests/maps_test.tscn -- --map
## res://maps/kit/kit_gallery.tscn plays bomb rounds and a respawn match on it.)
## Quits with the number of failed checks as the exit code.

const TextureReport := preload("res://tools/texture_report.gd")
const TEXTURE_SETS := ["industrial", "urban", "interior", "nature"]
const TEXTURE_FOLDER := "res://assets/textures/"
const MATERIAL_FOLDER := "res://assets/materials/"
const PROP_FOLDERS := ["res://maps/kit/props", "res://maps/kit/lights"]
const KIT_FGD := "res://maps/fgd/chiip_kit_fgd.tres"
const CHIIP_FGD := "res://maps/fgd/chiip_fgd.tres"
const MAP_SETTINGS := "res://maps/chiip_map_settings.tres"
const FIXTURE_MAP := "res://tests/maps/kit_props.map"
const GALLERY := "res://maps/kit/kit_gallery.tscn"
## TrenchBroom units per metre (maps/chiip_map_settings.tres).
const TB_SCALE := 39.37

var _failures: int = 0


func _ready() -> void:
	_test_textures()
	_test_texture_sounds()
	_test_prop_scenes()
	_test_prop_entities()
	await _test_lamps()
	await _test_props_in_a_map()
	await _test_gallery()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Texture library (D-121) ---


## Every PNG of the four sets, as "set/name".
func _set_textures() -> Array[String]:
	var names: Array[String] = []
	for set_name: String in TEXTURE_SETS:
		for file in DirAccess.get_files_at(TEXTURE_FOLDER + set_name):
			if file.ends_with(".png"):
				names.append(set_name.path_join(file.get_basename()))
	return names


func _test_textures() -> void:
	var names := _set_textures()
	var counts: Array[String] = []
	for set_name: String in TEXTURE_SETS:
		counts.append("%s %d" % [set_name, names.filter(func(n: String) -> bool: return n.begins_with(set_name + "/")).size()])
	_check("The texture library has at least 28 textures in four sets", names.size() >= 28 and not counts.any(func(c: String) -> bool: return c.ends_with(" 0")),
			", ".join(counts))

	var wrong_size: Array[String] = []
	var failing_rules: Array[String] = []
	var no_material: Array[String] = []
	for texture_name in names:
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_FOLDER + texture_name + ".png"))
		if image.get_size() != Vector2i(64, 64):
			wrong_size.append("%s %s" % [texture_name, image.get_size()])
		var stats := TextureReport.measure(image)
		if not TextureReport.passes(stats):
			failing_rules.append("%s (sat %.2f, red %.0f%%, blue %.0f%%)" % [texture_name, stats.saturation, stats.red * 100, stats.blue * 100])
		var material := load(MATERIAL_FOLDER + texture_name + ".tres") as StandardMaterial3D
		if material == null or material.albedo_texture == null \
				or material.albedo_texture.resource_path != TEXTURE_FOLDER + texture_name + ".png" or not material.uv1_world_triplanar:
			no_material.append(texture_name)
	_check("Every set texture is 64 × 64", wrong_size.is_empty(), ", ".join(wrong_size) if wrong_size else "%d textures" % names.size())
	_check("Every set texture keeps the look rules (no team red or blue, muted colours)", failing_rules.is_empty(),
			", ".join(failing_rules) if failing_rules else "all within saturation %.2f and %.0f%% team colours" % [
				TextureReport.MAX_SATURATION, TextureReport.MAX_TEAM_SHARE * 100])
	_check("Every set texture has a world-triplanar material in assets/materials/<set>/", no_material.is_empty(),
			", ".join(no_material) if no_material else "%d materials" % names.size())

	# The chain-link is see-through: holes in the texture, alpha scissor in both of its materials.
	var chainlink := Image.new()
	chainlink.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_FOLDER + "industrial/chainlink.png"))
	var holes := 0
	for y in chainlink.get_height():
		for x in chainlink.get_width():
			if chainlink.get_pixel(x, y).a < 0.5:
				holes += 1
	var map_material := load(TEXTURE_FOLDER + "industrial/chainlink.tres") as StandardMaterial3D
	var csg_material := load(MATERIAL_FOLDER + "industrial/chainlink.tres") as StandardMaterial3D
	_check("The chain-link has holes, and its map and CSG materials cut them out (alpha scissor; a brush draws each side once)",
			holes > 64 * 64 / 3 and map_material != null and csg_material != null
			and map_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and csg_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and map_material.cull_mode == BaseMaterial3D.CULL_BACK,
			"%d%% holes" % roundi(holes * 100.0 / (64 * 64)))


func _test_texture_sounds() -> void:
	var expected := {
		"gravel_grey": Surfaces.Kind.GRAVEL, "metal_plates": Surfaces.Kind.METAL, "wood_planks": Surfaces.Kind.WOOD,
		"concrete_floor": Surfaces.Kind.HARD, "painted_plaster": Surfaces.Kind.HARD,
		"industrial/corrugated_grey": Surfaces.Kind.METAL, "industrial/diamond_plate": Surfaces.Kind.METAL,
		"industrial/grate": Surfaces.Kind.METAL, "industrial/rust_plates": Surfaces.Kind.METAL,
		"industrial/concrete_worn": Surfaces.Kind.HARD, "urban/wood_siding": Surfaces.Kind.WOOD,
		"urban/cobbles": Surfaces.Kind.HARD, "urban/asphalt": Surfaces.Kind.HARD,
		"interior/parquet": Surfaces.Kind.WOOD, "interior/wood_floor_dark": Surfaces.Kind.WOOD,
		"interior/tiles_checker": Surfaces.Kind.HARD, "nature/grass": Surfaces.Kind.GRAVEL,
		"nature/dirt": Surfaces.Kind.GRAVEL, "nature/rock_moss": Surfaces.Kind.HARD,
		"industrial/blue_metal": Surfaces.Kind.METAL,
	}
	var wrong: Array[String] = []
	for texture_name: String in expected:
		var kind := Surfaces.kind_for_texture(texture_name)
		if kind != expected[texture_name]:
			wrong.append("%s is %s" % [texture_name, Surfaces.Kind.keys()[kind]])
	_check("Footsteps know textures by name: metal, wood and ground words, the old names unchanged", wrong.is_empty(),
			", ".join(wrong) if wrong else "%d names" % expected.size())


# --- Props (D-122, D-123) ---


## Every kit scene (props and lamps) by path.
func _prop_scenes() -> Array[String]:
	var paths: Array[String] = []
	for folder: String in PROP_FOLDERS:
		for file in ResourceLoader.list_directory(folder):
			if file.ends_with(".tscn"):
				paths.append(folder.path_join(file))
	return paths


func _test_prop_scenes() -> void:
	var paths := _prop_scenes()
	var broken: Array[String] = []
	var solid := 0
	var see_through := 0
	var decoration := 0
	for path in paths:
		var node := (load(path) as PackedScene).instantiate()
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		var shapes := node.find_children("*", "CollisionShape3D", false, false)
		var surface := String(node.get_meta(Surfaces.PROP_META_KEY, ""))
		var problem := ""
		if node.get_node_or_null("Model") == null or meshes.is_empty():
			problem = "no model"
		elif not Surfaces.PROP_SURFACES.has(surface):
			problem = "surface '%s'" % surface
		elif node is StaticBody3D:
			var body := node as StaticBody3D
			if shapes.is_empty():
				problem = "a body without shapes"
			elif body.collision_layer == PhysicsLayers.WORLD:
				solid += 1
			elif body.collision_layer == PhysicsLayers.BOTS:
				see_through += 1
			else:
				problem = "collision layer %d" % body.collision_layer
		elif not shapes.is_empty():
			problem = "shapes without a body"
		else:
			decoration += 1
		if not problem.is_empty():
			broken.append("%s: %s" % [path.get_file(), problem])
		node.free()
	_check("Every kit prop has its model, a surface, and collision for its kind (solid, see-through or none)",
			paths.size() >= 10 and broken.is_empty(),
			", ".join(broken) if broken else "%d props: %d solid, %d see-through, %d decoration" % [paths.size(), solid, see_through, decoration])


func _test_prop_entities() -> void:
	var kit := load(KIT_FGD) as FuncGodotFGDFile
	var definitions := kit.get_entity_definitions()
	var scenes := _prop_scenes()
	var problems: Array[String] = []
	for classname: String in definitions:
		var definition := definitions[classname] as FuncGodotFGDPointClass
		var model: String = String(definition.meta_properties.get("model", "")).trim_prefix("\"").trim_suffix("\"")
		if definition.scene_file == null:
			problems.append(classname + " has no scene")
		elif not FileAccess.file_exists("res://" + model):
			problems.append("%s shows a missing model '%s'" % [classname, model])
		elif definition.description.is_empty():
			problems.append(classname + " has no description")
		scenes.erase(definition.scene_file.resource_path if definition.scene_file else "")
	if not scenes.is_empty():
		problems.append("not in the FGD: " + ", ".join(scenes))
	var chiip := (load(CHIIP_FGD) as FuncGodotFGDFile).get_entity_definitions()
	if not chiip.has("prop_crate_wood") or not chiip.has("worldspawn"):
		problems.append("Chiip's FGD doesn't include the kit")
	_check("Every kit prop is a TrenchBroom entity with its scene, its .glb as display model and a description, in Chiip's FGD",
			problems.is_empty(), "; ".join(problems) if problems else "%d entities" % definitions.size())


# --- Lamps (D-124) ---


func _test_lamps() -> void:
	var problems: Array[String] = []
	var count := 0
	for file in ResourceLoader.list_directory("res://maps/kit/lights"):
		if not file.ends_with(".tscn"):
			continue
		count += 1
		var lamp := (load("res://maps/kit/lights/" + file) as PackedScene).instantiate() as KitLight
		if lamp == null:
			problems.append(file + " isn't a KitLight")
			continue
		add_child(lamp)
		var light := lamp.get_light()
		var glows := false
		for mesh: MeshInstance3D in lamp.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				glows = glows or (material != null and material.emission_enabled)
		if light == null or not is_equal_approx(light.light_energy, lamp.light_energy) or light.shadow_enabled:
			problems.append(file + ": no light, or not as set, or with shadows")
		elif (lamp.light_kind == KitLight.Kind.SPOT) != (light is SpotLight3D):
			problems.append(file + ": wrong kind of light")
		elif not glows:
			problems.append(file + ": nothing glows")
		elif light.light_color.r < light.light_color.b:
			problems.append(file + ": a cold light (D-031)")
		lamp.free()
	_check("Every lamp makes its light (no shadows by default, warm or neutral) and has a glowing part",
			count >= 5 and problems.is_empty(), ", ".join(problems) if problems else "%d lamps" % count)


func _test_props_in_a_map() -> void:
	var map := FuncGodotMap.new()
	map.local_map_file = FIXTURE_MAP
	map.map_settings = load(MAP_SETTINGS)
	map.build()
	add_child(map)
	map.add_to_group(&"navigation_source")
	for i in 3:
		await get_tree().physics_frame
	var crate := _built(map, "prop_crate_wood")
	var barrel := _built(map, "prop_barrel")
	var pallet := _built(map, "prop_pallet")
	# TrenchBroom (x, y, z) is Godot (y, z, x), and angle 0 turns a prop 180° (func_godot).
	var barrel_at := Vector3(0, 0, 120 / TB_SCALE)
	_check("Props placed in a .map build where they were put, as instances of their scenes",
			crate != null and barrel != null and pallet != null
			and crate.scene_file_path.ends_with("prop_crate_wood.tscn") and barrel.global_position.is_equal_approx(barrel_at)
			and is_equal_approx(barrel.rotation_degrees.y, 270.0) and crate.get_node_or_null("Model") != null,
			"barrel at %s, turned %.0f°" % [barrel.global_position if barrel else Vector3.INF, barrel.rotation_degrees.y if barrel else 0.0])

	var world := map.get_world_3d()
	var on_crate := _ray_down(world, Vector3.ZERO)
	var on_barrel := _ray_down(world, barrel_at)
	var on_pallet := _ray_down(world, Vector3(0, 0, -120 / TB_SCALE))
	_check("A solid prop stops rays (bullets, sight) at its top and sounds like what it's made of; decoration doesn't",
			not on_crate.is_empty() and absf(on_crate.position.y - 1.2) < 0.03
			and Surfaces.kind_of(on_crate.collider, on_crate.shape, on_crate.normal) == Surfaces.Kind.WOOD
			and not on_barrel.is_empty() and Surfaces.kind_of(on_barrel.collider, on_barrel.shape, on_barrel.normal) == Surfaces.Kind.METAL
			and not on_pallet.is_empty() and absf(on_pallet.position.y) < 0.01,
			"crate top at %.2f m (%s), barrel %s, pallet: the floor at %.2f m" % [
				on_crate.get("position", Vector3.INF).y, _kind_name(on_crate), _kind_name(on_barrel), on_pallet.get("position", Vector3.INF).y])

	var navigation := NavigationMesh.new()
	var template := load("res://maps/depot_navmesh.tres") as NavigationMesh
	navigation.agent_radius = template.agent_radius
	navigation.agent_height = template.agent_height
	navigation.agent_max_slope = template.agent_max_slope
	navigation.geometry_parsed_geometry_type = template.geometry_parsed_geometry_type
	navigation.geometry_collision_mask = template.geometry_collision_mask
	navigation.geometry_source_geometry_mode = template.geometry_source_geometry_mode
	navigation.geometry_source_group_name = template.geometry_source_group_name
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation, source, self)
	NavigationServer3D.bake_from_source_geometry_data(navigation, source)
	var crate_walkable := _on_navmesh(navigation, Vector3.ZERO)
	var pallet_walkable := _on_navmesh(navigation, Vector3(0, 0, -120 / TB_SCALE))
	var floor_walkable := _on_navmesh(navigation, Vector3(5, 0, 5))
	_check("A navmesh baked around props leaves out solid props and keeps the floor under decoration",
			navigation.get_polygon_count() > 0 and not crate_walkable and pallet_walkable and floor_walkable,
			"%d polygons; under the crate %s, under the pallet %s" % [
				navigation.get_polygon_count(), "walkable" if crate_walkable else "cut out", "walkable" if pallet_walkable else "cut out"])
	var wall_lamp := _built(map, "light_wall") as KitLight
	var street_lamp := _built(map, "light_street") as KitLight
	var wall_light := wall_lamp.get_light() if wall_lamp else null
	_check("A lamp placed in a .map takes its colour, brightness and range from the entity; one without keeps its defaults",
			wall_light != null and wall_light.light_color.is_equal_approx(Color.WHITE) and is_equal_approx(wall_light.light_energy, 2.5)
			and is_equal_approx((wall_light as OmniLight3D).omni_range, 9.0)
			and street_lamp != null and street_lamp.get_light() != null and is_equal_approx(street_lamp.light_energy, 2.0),
			"wall lamp %s, energy %.1f; street lamp energy %.1f" % [
				wall_light.light_color if wall_light else "none", wall_light.light_energy if wall_light else 0.0,
				street_lamp.light_energy if street_lamp else 0.0])
	map.queue_free()
	await get_tree().process_frame


# --- The kit gallery (D-125, D-129) ---


func _test_gallery() -> void:
	var gallery := (load(GALLERY) as PackedScene).instantiate() as Node3D
	add_child(gallery)
	var navigation: RID = gallery.get_world_3d().navigation_map
	await _wait_for_navigation(gallery)
	var counts := {}
	for group: String in ["attack_spawns", "defend_spawns", "hold_points", "respawn_points", "patrol_points", "bomb_sites", "attack_routes"]:
		counts[group] = get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool: return gallery.is_ancestor_of(node))
	var sites: Array = counts["bomb_sites"]
	var site_names := sites.map(func(site: Node) -> String: return String(site.name))
	site_names.sort()
	var sites_ok := site_names == ["BombSiteA", "BombSiteB"] and sites.all(func(site: Node) -> bool:
		return site.get_node_or_null("Shape") is CollisionShape3D and (site.get_node("Shape") as CollisionShape3D).shape is BoxShape3D \
				and site.get_node_or_null("Letter") is Label3D and (site as Area3D).collision_layer == PhysicsLayers.TRIGGERS)
	var routes: Array = counts["attack_routes"]
	var routes_ok := routes.size() == 3 and routes.all(func(route: Node) -> bool:
		var orders := route.get_children().map(func(point: Node) -> int: return (point as KitRoutePoint).order)
		var sorted_orders := orders.duplicate()
		sorted_orders.sort()
		return orders.size() == 5 and orders == sorted_orders)
	_check("The gallery's entities become the game's markers: 5 + 5 spawns, sites A and B (box, letter, triggers layer), 3 routes in order, holds, respawns, patrols",
			counts["attack_spawns"].size() == 5 and counts["defend_spawns"].size() == 5 and sites_ok and routes_ok
			and counts["hold_points"].size() >= 5 and counts["respawn_points"].size() >= 8 and counts["patrol_points"].size() >= 8,
			"%s; sites %s; routes %s" % [", ".join(counts.keys().map(func(group: String) -> String: return "%s %d" % [group, counts[group].size()])),
				site_names, routes.map(func(route: Node) -> String: return "%s %d" % [route.name, route.get_child_count()])])

	var shown := {}
	for node in gallery.get_node("Map").get_children():
		if not String(node.scene_file_path).is_empty():
			shown[node.scene_file_path] = true
	var missing := _prop_scenes().filter(func(path: String) -> bool: return not shown.has(path))
	var world_body := gallery.get_node("Map").find_children("*_worldspawn", "StaticBody3D", false, false)[0] as StaticBody3D
	var texture_names: Array = (world_body.get_meta(Surfaces.META_KEY) as Dictionary).get("texture_names", [])
	var unshown := _set_textures().filter(func(name: String) -> bool:
		return not name in texture_names and not name in ["interior/glass", "industrial/chainlink"])
	_check("The gallery shows every kit prop and lamp and every set texture", missing.is_empty() and unshown.is_empty(),
			"missing props: %s; missing textures: %s" % [missing, unshown] if missing or unshown else "%d props and lamps, %d textures" % [
				_prop_scenes().size(), texture_names.size()])

	var see_through := gallery.get_node("Map").get_children().filter(func(node: Node) -> bool:
		return String(node.name).ends_with("func_glass") or String(node.name).ends_with("func_fence") or String(node.name).ends_with("func_clip"))
	var layers_ok := see_through.size() == 3 and see_through.all(func(node: Node) -> bool:
		return node is StaticBody3D and (node as StaticBody3D).collision_layer == PhysicsLayers.BOTS)
	var glass_visible := see_through.any(func(node: Node) -> bool: return String(node.name).ends_with("func_glass") and not node.find_children("*", "MeshInstance3D").is_empty())
	var clip_invisible := see_through.any(func(node: Node) -> bool: return String(node.name).ends_with("func_clip") and node.find_children("*", "MeshInstance3D").is_empty())
	_check("Glass, fence and clip brushes block only movement (layer 3); glass is drawn, a clip isn't",
			layers_ok and glass_visible and clip_invisible, "%d see-through brushes" % see_through.size())

	var lines: Array[String] = []
	var reachable := true
	for group: String in ["attack_spawns", "defend_spawns"]:
		var start := (counts[group][2] as Node3D).global_position
		for site: Node3D in sites:
			var goal := NavigationServer3D.map_get_closest_point(navigation, site.global_position + Vector3.DOWN * 1.5)
			var nav_path := NavigationServer3D.map_get_path(navigation, start, goal, true)
			var ok := not nav_path.is_empty() and nav_path[-1].distance_to(goal) < 1.0
			reachable = reachable and ok
			lines.append("%s → %s %s" % [group.trim_suffix("_spawns"), site.name.trim_prefix("BombSite"), "ok" if ok else "NO PATH"])
	_check("In the gallery both spawns can walk to both bomb sites", reachable, ", ".join(lines))
	gallery.queue_free()
	await get_tree().process_frame


## Waits until the navigation map uses [param scene]'s navmesh (a few physics
## frames after it enters the tree; like tests/maps_test.gd).
func _wait_for_navigation(scene: Node) -> void:
	var region := scene.find_children("*", "NavigationRegion3D", true, false)[0] as NavigationRegion3D
	var nav: RID = (scene as Node3D).get_world_3d().navigation_map
	var synced_from := -1
	for i in 120:
		await get_tree().physics_frame
		var regions := NavigationServer3D.map_get_regions(nav)
		if not regions.has(region.get_rid()):
			continue
		if synced_from < 0:
			synced_from = NavigationServer3D.map_get_iteration_id(nav)
		elif NavigationServer3D.map_get_iteration_id(nav) >= synced_from + 2:
			return


## The built node of the first entity of [param classname] in [param map].
func _built(map: Node, classname: String) -> Node3D:
	for child in map.get_children():
		if String(child.name).ends_with("_" + classname):
			return child as Node3D
	return null


func _ray_down(world: World3D, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 5.0, at + Vector3.DOWN, PhysicsLayers.WORLD)
	return world.direct_space_state.intersect_ray(query)


func _kind_name(hit: Dictionary) -> String:
	if hit.is_empty():
		return "nothing"
	return Surfaces.Kind.keys()[Surfaces.kind_of(hit.collider, hit.shape, hit.normal)]


## Whether a polygon of [param navigation] at the height of [param point] lies
## under it (seen from above). Polygons on top of props (bots can stand on a
## crate) don't count.
func _on_navmesh(navigation: NavigationMesh, point: Vector3) -> bool:
	var vertices := navigation.get_vertices()
	var flat := Vector2(point.x, point.z)
	for i in navigation.get_polygon_count():
		var polygon := PackedVector2Array()
		var height := 0.0
		for index in navigation.get_polygon(i):
			polygon.append(Vector2(vertices[index].x, vertices[index].z))
			height += vertices[index].y
		height /= maxi(polygon.size(), 1)
		if absf(height - point.y) < 0.5 and Geometry2D.is_point_in_polygon(flat, polygon):
			return true
	return false


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
