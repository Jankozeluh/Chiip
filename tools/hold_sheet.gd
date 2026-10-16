extends SceneTree
## Contact sheets of how every class holds every weapon in third person (M11, D-157): one PNG per
## weapon, the four classes side by side, each in a few poses (aiming from the left and from the
## right, and two moments of the reload, the attack or the throw), straight from the models'
## AnimationPlayer with the weapon's model on the weapon bone, as the game shows it.
##
## Opens a window for a few seconds (it renders):
## [code]Godot --path . --resolution 1024x1060 --script res://tools/hold_sheet.gd -- --out <folder>[/code]
## Add [code]--weapons rifle,knife[/code] for some of them.

const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
const MODEL_DIR := "res://assets/models/crew/"
const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
const WEAPONS: Array[String] = ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol", "hand_cannon", "knife",
		"frag", "flashbang", "smoke"]
const CELL := 256
const HEADER := 36


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


## The poses of one row: [label, clip, time in seconds, camera angle in degrees].
static func rows_for(data: WeaponData) -> Array:
	var set_name := String(data.get_anim_set())
	var aim := "aim_0" if set_name == "rifle" else "aim_%s_0" % set_name
	var rows := [["aim, left", aim, 0.0, 40.0], ["aim, right", aim, 0.0, -75.0]]
	if data.is_melee():
		rows += [["slash", "knife_slash", 0.08, 30.0], ["stab", "knife_stab", 0.3, 50.0]]
	elif data.is_grenade():
		rows += [["throw", "grenade_throw", 0.18, -60.0], ["lob", "grenade_lob", 0.18, -60.0]]
	else:
		var reload := "reload" if set_name == "rifle" else "reload_%s" % set_name
		rows += [["reload: mag out", reload, 0.7, 45.0], ["reload: mag in", reload, 1.65, 45.0]]
		if data.reload_per_shell:
			rows[3] = ["shell in", "reload_shell", 1.8, 45.0]
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
			body.animated = false
			body.rotation.y = PI
			view.add_child(body)
			body._show_gun(data)
			var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			player.play(row[1])
			player.seek(row[2], true)
			player.pause()
			var camera := Camera3D.new()
			camera.fov = 38.0
			view.add_child(camera)
			var skeleton := body.get_skeleton()
			var chest := skeleton.get_bone_global_rest(skeleton.find_bone("chest")).origin + Vector3(0, -0.05, 0)
			var a := deg_to_rad(row[3])
			camera.position = chest + Vector3(sin(a), 0.12, cos(a)) * 2.3
			camera.look_at(chest)
			var label := Label.new()
			label.text = row[0] if c == 0 else ""
			label.position = Vector2(4, 4)
			box.add_child(label)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("hold sheet: ", path)
	ui.queue_free()
	await process_frame


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
