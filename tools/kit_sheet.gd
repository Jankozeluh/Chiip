extends SceneTree
## Tool: renders every kit prop (or any folder of scenes) into one labelled
## contact sheet, for reviews and docs/MAPPING.md. Rendering needs a window:
##
##     Godot --path . --resolution 1280x720 --quit-after 6000 --script res://tools/kit_sheet.gd -- --out <sheet.png> [--dir res://maps/kit/props] [--dir res://maps/kit/lights] [--columns 8] [--names bench,prop_tree_pine]
##
## [code]--names[/code] renders only the scenes with those names (with or
## without the [code]prop_[/code] prefix).
## Each scene is shown from the front-left and a little above (its front faces
## -Z), in grey daylight on a neutral floor, rendered at a low resolution and
## scaled up 2× with sharp pixels like the game's 480 lines. It never touches
## the mouse or any game state: the scenes render in a SubViewport with a
## world of its own.

## Size of one picture before scaling up.
const TILE := 144
const LABEL_HEIGHT := 12
const DEFAULT_DIRS := ["res://maps/kit/props", "res://maps/kit/lights"]
const TextureReport := preload("res://tools/texture_report.gd")

var _viewport: SubViewport
var _camera: Camera3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://kit_sheet.png"
	var dirs: Array[String] = []
	var columns := 8
	var names: PackedStringArray = []
	var i := 0
	while i < args.size():
		match args[i]:
			"--out":
				out = args[i + 1]
				i += 1
			"--dir":
				dirs.append(args[i + 1])
				i += 1
			"--columns":
				columns = int(args[i + 1])
				i += 1
			"--names":
				names = args[i + 1].split(",")
				i += 1
		i += 1
	if dirs.is_empty():
		dirs.assign(DEFAULT_DIRS)
	var scenes: Array[String] = []
	for dir in dirs:
		for file in ResourceLoader.list_directory(dir):
			var base := file.get_basename()
			if file.ends_with(".tscn") and (names.is_empty() or base in names or base.trim_prefix("prop_") in names):
				scenes.append(dir.path_join(file))
	_set_up_stage()
	await process_frame
	var pictures: Array[Image] = []
	for path in scenes:
		pictures.append(await _render(load(path) as PackedScene))
	_write_sheet(pictures, scenes, columns, out)
	quit()


func _set_up_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(TILE, TILE)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.32, 0.34, 0.36)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.63, 0.64)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	_viewport.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.42, 0.42, 0.42)
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	_viewport.add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	_viewport.add_child(_camera)
	_camera.make_current()


## A picture of one scene, framed to its meshes.
func _render(scene: PackedScene) -> Image:
	var node := scene.instantiate() as Node3D
	_viewport.add_child(node)
	await process_frame
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_box := mesh.global_transform * mesh.get_aabb()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	var centre := box.get_center()
	var radius := maxf(box.size.length() / 2.0, 0.3)
	var distance := radius / sin(deg_to_rad(_camera.fov / 2.0)) * 1.05
	var direction := Vector3(-0.62, 0.42, -0.66).normalized()      # front-left, above: the front faces -Z
	_camera.look_at_from_position(centre + direction * distance, centre)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	node.queue_free()
	await process_frame
	return image


func _write_sheet(pictures: Array[Image], paths: Array[String], columns: int, out: String) -> void:
	var cell := Vector2i(TILE * 2 + 4, TILE * 2 + LABEL_HEIGHT + 4)
	var rows := ceili(pictures.size() / float(columns))
	var sheet := Image.create(columns * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.12, 0.13))
	for i in pictures.size():
		var picture := pictures[i]
		picture.convert(Image.FORMAT_RGBA8)
		picture.resize(TILE * 2, TILE * 2, Image.INTERPOLATE_NEAREST)
		var corner := Vector2i((i % columns) * cell.x + 2, (i / columns) * cell.y + 2)
		sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), corner)
		TextureReport.draw_label(sheet, paths[i].get_file().get_basename(), corner + Vector2i(0, TILE * 2 + 3), TILE * 2)
	sheet.save_png(out)
	print("Kit sheet: %s (%d scenes)" % [out, pictures.size()])
