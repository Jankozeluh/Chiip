extends SceneTree
## Tool: builds every FuncGodotMap node in a scene from its TrenchBroom .map
## file and saves the scene, the same as clicking "Build Map" in the editor
## and saving. Run it after editing a .map file:
##
##     Godot --headless --path . --script res://tools/build_maps.gd -- res://maps/comparison/trenchbroom_room.tscn
##
## The built geometry (meshes with lightmap UVs, collision shapes) is stored in
## the scene, so lightmaps can be baked and the map loads without rebuilding.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <scene path> [more scene paths]")
		quit(1)
		return
	var failures := 0
	for scene_path in args:
		if not _build_scene(scene_path):
			failures += 1
	quit(failures)


func _build_scene(scene_path: String) -> bool:
	var root: Node = load(scene_path).instantiate()
	var maps := root.find_children("*", "Node3D", true, false).filter(
			func(node: Node) -> bool: return node is FuncGodotMap)
	if maps.is_empty():
		printerr("%s: no FuncGodotMap nodes" % scene_path)
		return false
	for map: FuncGodotMap in maps:
		map.build()
		if map.get_child_count() == 0:
			printerr("%s: %s built nothing" % [scene_path, map.name])
			return false
		# Outside the editor, func_godot makes the map node the owner of what it
		# builds; the scene root has to own it to be saved into the scene file.
		for node in map.find_children("*", "", true, false):
			node.owner = root
		print("%s: %s built %d nodes" % [scene_path, map.name, map.find_children("*", "", true, false).size()])
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, scene_path)
	print("%s: saved (%s)" % [scene_path, error_string(error)])
	root.free()
	return error == OK
