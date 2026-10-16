extends SceneTree
## Tool: turns a TrenchBroom .map file into a playable Chiip map in one step
## (D-125): makes its scene from maps/kit/map_template.tscn (sky, sun,
## player, navigation), builds the map into it and bakes the navmesh.
##
##     Godot --headless --path . --quit-after 2000 --script res://tools/new_map.gd -- res://maps/my_map.map
##
## Writes maps/my_map.tscn and maps/my_map_navmesh.tres next to the .map file.
## The markers the game needs (spawns, bomb sites, routes...) come from the
## map's entities (docs/MAPPING.md). Run it once; after that, rebuild with
## tools/build_maps.gd and re-bake with tools/bake_navmesh.gd after edits, so
## the scene keeps whatever you change in it by hand (the sky, the sun).
## An existing scene is never overwritten.

const TEMPLATE := "res://maps/kit/map_template.tscn"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].ends_with(".map"):
		printerr("Usage: -- res://maps/<name>.map")
		quit(1)
		return
	var map_path: String = args[0]
	var scene_path := map_path.get_basename() + ".tscn"
	var navmesh_path := map_path.get_basename() + "_navmesh.tres"
	if not FileAccess.file_exists(map_path):
		printerr("%s doesn't exist" % map_path)
		quit(1)
		return
	if ResourceLoader.exists(scene_path):
		printerr("%s exists already: rebuild it with tools/build_maps.gd instead" % scene_path)
		quit(1)
		return
	var root: Node3D = (load(TEMPLATE) as PackedScene).instantiate()
	root.name = map_path.get_file().get_basename().to_pascal_case()
	var map := root.get_node("Map") as FuncGodotMap
	map.local_map_file = map_path
	# The navmesh lives in its own file, so baking never rewrites the scene.
	var navigation := root.get_node("Navigation") as NavigationRegion3D
	var navmesh := navigation.navigation_mesh.duplicate() as NavigationMesh
	ResourceSaver.save(navmesh, navmesh_path)
	navigation.navigation_mesh = load(navmesh_path)
	map.build()
	for node in map.find_children("*", "", true, false):
		if node.owner == map or node.owner == null:
			node.owner = root
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, scene_path)
	print("%s: %s (%d nodes from %s)" % [scene_path, error_string(error), map.get_child_count(), map_path])
	root.free()
	if error != OK:
		quit(1)
		return
	# Bake in the tree, like tools/bake_navmesh.gd.
	var placed: Node = (load(scene_path) as PackedScene).instantiate()
	get_root().add_child(placed)
	for i in 3:
		await physics_frame
	var region := placed.get_node("Navigation") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	error = ResourceSaver.save(region.navigation_mesh, navmesh_path)
	print("%s: %d polygons (%s)" % [navmesh_path, region.navigation_mesh.get_polygon_count(), error_string(error)])
	placed.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
