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
## of, and are cut out of a navmesh baked around them. Quits with the number
## of failed checks as the exit code.

const TextureReport := preload("res://tools/texture_report.gd")
const TEXTURE_SETS := ["industrial", "urban", "interior", "nature"]
const TEXTURE_FOLDER := "res://assets/textures/"
const MATERIAL_FOLDER := "res://assets/materials/"
const PROP_FOLDERS := ["res://maps/kit/props", "res://maps/kit/lights"]
const KIT_FGD := "res://maps/fgd/chiip_kit_fgd.tres"
const CHIIP_FGD := "res://maps/fgd/chiip_fgd.tres"
const MAP_SETTINGS := "res://maps/chiip_map_settings.tres"
const FIXTURE_MAP := "res://tests/maps/kit_props.map"
## TrenchBroom units per metre (maps/chiip_map_settings.tres).
const TB_SCALE := 39.37

var _failures: int = 0


func _ready() -> void:
	_test_textures()
	_test_texture_sounds()
	_test_prop_scenes()
	_test_prop_entities()
	await _test_props_in_a_map()
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
	_check("The texture library has 28 textures in four sets", names.size() >= 28 and not counts.any(func(c: String) -> bool: return c.ends_with(" 0")),
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
	_check("The chain-link has holes, and its map and CSG materials cut them out (alpha scissor, both sides drawn)",
			holes > 64 * 64 / 3 and map_material != null and csg_material != null
			and map_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and csg_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and map_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
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
	map.queue_free()
	await get_tree().process_frame


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
