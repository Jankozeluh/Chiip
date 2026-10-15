extends SceneTree
## Tool: renders screenshots of a map through the real game (main.tscn, so the
## low-resolution world, palette effect and lighting are exactly what you play),
## for reviews and the docs. Run with a window (rendering needs one):
##
##     Godot --path . --resolution 1280x720 --quit-after 3000 --script res://tools/map_screenshots.gd -- --map res://maps/depot.tscn --out <folder>
##
## It doesn't react to the mouse: the developer console is flagged open every
## frame (the player controller then ignores all input) and the mouse is kept
## free. The image is read straight from the World SubViewport, set to a fixed
## size, so the HUD isn't in it. Shots are taken during the first round's
## freeze time, from places every map has: an overview from above the
## attackers' end, each spawn, each bomb site and the middle of the mid route.
## Each is saved as a PNG scaled up 2× with sharp pixels.

## Size of the world image: the game's 480 lines at 16:9 (D-048).
const WORLD_SIZE := Vector2i(854, 480)
## Standing eye height (CS: 64 units).
const EYE_HEIGHT := 64.0 * 0.0254

var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_index := args.find("--out")
	var out_folder: String = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else "user://screenshots"
	DirAccess.make_dir_recursive_absolute(out_folder)
	process_frame.connect(_keep_input_away)
	# main.gd reads "--map" from the same command line.
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	for i in 10:
		await process_frame
	var container := _main.get_node("World") as SubViewportContainer
	var viewport := _main.get_node("World/SubViewport") as SubViewport
	container.stretch = false
	viewport.size = WORLD_SIZE
	var map: Node3D = _main.get_map()
	var camera := Camera3D.new()
	camera.fov = 73.74
	map.add_child(camera)
	camera.make_current()
	for shot in _plan_shots(map):
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2])
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(WORLD_SIZE.x * 2, WORLD_SIZE.y * 2, Image.INTERPOLATE_NEAREST)
		var path := out_folder.path_join("%s.png" % shot[0])
		image.save_png(path)
		print("Saved ", path)
	quit()


## Every frame: the console counts as open (the game ignores mouse and keys)
## and the mouse stays free, in case the player controller captured it.
func _keep_input_away() -> void:
	DevConsole.is_open = true
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## [name, camera position, point to look at, field of view] for each shot.
func _plan_shots(map: Node3D) -> Array:
	var shots: Array = []
	var attack := _marker(map, "attack_spawns", 2)
	var defend := _marker(map, "defend_spawns", 2)
	shots.append(["overview", Vector3(0, 40, attack.global_position.z + 14), Vector3(0, 0, -3), 62.0])
	for spawn: Node3D in [attack, defend]:
		var name := "attackers" if spawn == attack else "defenders"
		var eye := spawn.global_position + Vector3.UP * EYE_HEIGHT
		shots.append([name, eye, eye - spawn.global_basis.z * 20.0, 73.74])
	for site in _in_map(map, "bomb_sites"):
		var floor_centre := (site as Node3D).global_position + Vector3.DOWN * 1.5
		var toward_middle := Vector3(-floor_centre.x, 0, -floor_centre.z).normalized()
		var eye := floor_centre + toward_middle * 8.0 + Vector3.UP * (EYE_HEIGHT + 0.6)
		shots.append(["site_" + site.name.trim_prefix("BombSite").to_lower(), eye, floor_centre + Vector3.UP, 73.74])
	for route in _in_map(map, "attack_routes"):
		if route.name == "RouteMid" and route.get_child_count() >= 2:
			var middle := route.get_child_count() / 2
			var from := (route.get_child(middle - 1) as Node3D).global_position + Vector3.UP * EYE_HEIGHT
			var to := (route.get_child(middle) as Node3D).global_position + Vector3.UP * EYE_HEIGHT
			shots.append(["mid", from, to, 73.74])
	return shots


func _marker(map: Node3D, group: String, index: int) -> Node3D:
	return _in_map(map, group)[index] as Node3D


func _in_map(map: Node, group: String) -> Array[Node]:
	return get_nodes_in_group(group).filter(func(node: Node) -> bool: return map.is_ancestor_of(node))
