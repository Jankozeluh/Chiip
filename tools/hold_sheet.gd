extends SceneTree
## Contact sheets of how every class holds every weapon in third person (M11, D-156): one PNG per
## weapon, the four classes side by side. The aiming rows run the game's animation graph (blended
## aim pitches, running) with the left-hand IK; the reload, attack and throw rows show moments of
## their clips, with the magazine or the shell where the reload has it (GunModel).
##
## Opens a window for a few seconds (it renders):
## [code]Godot --path . --resolution 1024x1316 --fixed-fps 60 --script res://tools/hold_sheet.gd -- --out <folder>[/code]
## Add [code]--weapons rifle,knife[/code] for some of them.

const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
const MODEL_DIR := "res://assets/models/crew/"
const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
const WEAPONS: Array[String] = ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol", "hand_cannon", "knife",
		"frag", "flashbang", "smoke"]
const CELL := 256
const HEADER := 36
## Frames the animation graph runs before the picture (blends settle).
const SETTLE_FRAMES := 40


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := _arg(args, "--out", "user://hold_sheets")
	var names := WEAPONS
	var picked := _arg(args, "--weapons", "")
	if picked != "":
		names.assign(picked.split(","))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	for weapon_name in names:
		await _sheet(load("res://weapons/%s.tres" % weapon_name) as WeaponData, out.path_join(weapon_name + ".png"))
	quit()


## The rows: [label, camera angle in degrees, and either a graph state ("graph", velocity, aim
## degrees) or a clip moment ("clip", clip name, seconds, reload progress or -1)].
static func rows_for(data: WeaponData) -> Array:
	var set_name := String(data.get_anim_set())
	var rows := [["aim level", 40.0, "graph", Vector2.ZERO, 0.0], ["aim up 50°, blended", -70.0, "graph", Vector2.ZERO, 50.0],
			["running, aim down 30°", 50.0, "graph", Vector2(0, 5.4), -30.0]]
	if data.is_melee():
		rows += [["slash", 30.0, "clip", "knife_slash", 0.08, -1.0], ["stab", 50.0, "clip", "knife_stab", 0.3, -1.0]]
	elif data.is_grenade():
		rows += [["throw", -60.0, "clip", "grenade_throw", 0.18, -1.0], ["lob", -60.0, "clip", "grenade_lob", 0.18, -1.0]]
	elif data.reload_per_shell:
		rows += [["shell from the vest", 45.0, "clip", "reload_shell", 1.0, 0.4], ["shell at the port", 45.0, "clip", "reload_shell", 1.85, 0.74]]
	else:
		var reload := "reload" if set_name == "rifle" else "reload_%s" % set_name
		rows += [["reload: old magazine out", 45.0, "clip", reload, 0.95, 0.38], ["reload: new magazine in", 45.0, "clip", reload, 1.55, 0.62]]
	return rows


func _sheet(data: WeaponData, path: String) -> void:
	var rows := rows_for(data)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var title := Label.new()
	title.text = "%s — %s" % [data.display_name, "   ".join(CLASSES)]
	title.position = Vector2(8, 8)
	ui.add_child(title)
	var graph_bodies: Array = []
	for r in rows.size():
		var row: Array = rows[r]
		for c in CLASSES.size():
			var box := SubViewportContainer.new()
			box.position = Vector2(c * CELL, HEADER + r * CELL)
			box.size = Vector2(CELL, CELL)
			ui.add_child(box)
			# Each cell is its own little world: a light, the body and a camera.
			var view := SubViewport.new()
			view.size = Vector2i(CELL, CELL)
			view.own_world_3d = true
			box.add_child(view)
			_add_lights(view)
			var body := BODY_SCENE.instantiate() as CrewBody
			body.model = load(MODEL_DIR + CLASSES[c] + ".glb") as PackedScene
			body.animated = row[2] == "graph"
			body.rotation.y = PI
			view.add_child(body)
			body._show_gun(data)
			if row[2] == "graph":
				body._set_hold(data)
				graph_bodies.append([body, row[3], row[4]])
			else:
				_pose_clip(body, data, row[3], row[4], row[5])
			var camera := Camera3D.new()
			camera.fov = 38.0
			view.add_child(camera)
			var skeleton := body.get_skeleton()
			var chest := skeleton.get_bone_global_rest(skeleton.find_bone("chest")).origin + Vector3(0, -0.05, 0)
			var a := deg_to_rad(row[1])
			camera.position = chest + Vector3(sin(a), 0.12, cos(a)) * 2.3
			camera.look_at(chest)
			var label := Label.new()
			label.text = row[0] if c == 0 else ""
			label.position = Vector2(4, 4)
			box.add_child(label)
	for i in SETTLE_FRAMES:
		for entry: Array in graph_bodies:
			(entry[0] as CrewBody).update_animation_state(entry[1], false, true, entry[2], 1.0 / 60.0)
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("hold sheet: ", path)
	ui.queue_free()
	await process_frame


## Shows [param clip] at [param time] seconds on [param body], with the magazine or shell where a
## reload [param progress] through has it (from the moment the hand took it).
static func _pose_clip(body: CrewBody, data: WeaponData, clip: String, time: float, progress: float) -> void:
	var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(clip)
	var parts := body.get_gun_parts()
	var skeleton := body.get_skeleton()
	if progress >= 0.0 and parts != null:
		var length := player.get_animation(clip).length
		var start: float = GunModel.events_for(data).values()[0]
		for step: float in [start + 0.001, progress]:
			player.seek(step * length, true)
			skeleton.force_update_all_bone_transforms()
			body._gun_mount.on_skeleton_update()
			parts.update(data, step, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")))
	player.seek(time, true)
	player.pause()


static func _add_lights(view: SubViewport) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	view.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.23, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment.ambient_light_energy = 0.8
	view.add_child(env)


static func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback
