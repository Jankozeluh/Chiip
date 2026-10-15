extends SceneTree
## Tool: bakes the navigation mesh of every NavigationRegion3D in the given
## scenes and saves it to its resource file, the same as clicking
## "Bake NavigationMesh" in the editor. Run it after changing a map's layout:
##
##     Godot --headless --path . --script res://tools/bake_navmesh.gd -- res://maps/test_map.tscn
##
## The navigation mesh must be saved as its own resource file (e.g.
## maps/test_map_navmesh.tres), so baking doesn't rewrite the map scene.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <scene path> [more scene paths]")
		quit(1)
		return
	var failures := 0
	for scene_path in args:
		var map: Node = load(scene_path).instantiate()
		root.add_child(map)
		# CSG shapes build their geometry a frame after entering the tree.
		for i in 3:
			await physics_frame
		var regions := map.find_children("*", "NavigationRegion3D", true, false)
		if regions.is_empty():
			printerr("%s: no NavigationRegion3D" % scene_path)
			failures += 1
		for region: NavigationRegion3D in regions:
			region.bake_navigation_mesh(false)
			var mesh := region.navigation_mesh
			if mesh.resource_path.is_empty() or mesh.resource_path.contains("::"):
				printerr("%s: %s's navigation mesh isn't saved in its own file" % [scene_path, region.name])
				failures += 1
				continue
			var error := ResourceSaver.save(mesh, mesh.resource_path)
			print("%s: %s baked %d polygons -> %s (%s)" % [
					scene_path, region.name, mesh.get_polygon_count(), mesh.resource_path, error_string(error)])
			if error != OK:
				failures += 1
		map.queue_free()
		await process_frame
	quit(failures)
