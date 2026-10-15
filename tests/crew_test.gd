extends Node3D
## Automated crew model checks (M6 task 3). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/crew_test.tscn
##
## Checks that a [CrewBody] builds its model with the shared team-colour material (crew.gdshader,
## both textures), that the team colour is a per-instance parameter (two bodies of a class share
## one material but can differ in colour), that the generated textures follow the contract of
## tools/modelgen/paint.py (team texels are neutral grey, no glow on the Rifleman), and that a
## [Character] recolours its body when the viewer's team changes (Teams.set_viewer_team).
## Quits with the number of failed checks as the exit code (0 means everything passed).

const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const SHADER_PATH := "res://characters/crew/crew.gdshader"
const MODEL_PATH := "res://assets/models/crew/rifleman.glb"
const ALBEDO_PATH := "res://assets/models/crew/rifleman_albedo.png"
const MASK_PATH := "res://assets/models/crew/rifleman_mask.png"

var _failures: int = 0


func _ready() -> void:
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_model_and_material()
	await _test_team_color_per_instance()
	_test_textures()
	await _test_character_recolours()


func _test_model_and_material() -> void:
	var first := _add_body()
	var second := _add_body()
	await _wait_ticks(2)
	var meshes := _meshes(first)
	_check("The rifleman model is built under the body", first.has_node("Model") and not meshes.is_empty(),
			"%d mesh(es) under \"Model\"" % meshes.size())
	var all_ok := not meshes.is_empty()
	var details := "every mesh has the crew shader with both textures"
	for mesh in meshes:
		var material := mesh.material_override as ShaderMaterial
		if material == null or material.shader == null or material.shader.resource_path != SHADER_PATH:
			all_ok = false
			details = "%s has no crew ShaderMaterial" % mesh.name
		elif not (material.get_shader_parameter("albedo_texture") is Texture2D
				and material.get_shader_parameter("mask_texture") is Texture2D):
			all_ok = false
			details = "%s is missing a texture" % mesh.name
	_check("Every mesh uses the crew shader with its albedo and mask", all_ok, details)
	var other := _meshes(second)
	_check("Two bodies of a class share one material",
			not other.is_empty() and other[0].material_override == meshes[0].material_override,
			"same ShaderMaterial object")
	_check("material_for gives the same material every time",
			CrewBody.material_for(MODEL_PATH) == meshes[0].material_override, "cached per model path")
	first.queue_free()
	second.queue_free()
	await _wait_ticks(2)


func _test_team_color_per_instance() -> void:
	var first := _add_body()
	var second := _add_body()
	await _wait_ticks(2)
	first.set_team_color(Teams.FRIENDLY_COLOR)
	second.set_team_color(Teams.ENEMY_COLOR)
	var mesh := _meshes(first)[0]
	var other := _meshes(second)[0]
	_check("Team colour blue is set on the mesh",
			mesh.get_instance_shader_parameter("team_color") == Teams.FRIENDLY_COLOR
			and first.get_team_color() == Teams.FRIENDLY_COLOR,
			"team_color == FRIENDLY_COLOR")
	_check("Team colour red is set on the mesh",
			other.get_instance_shader_parameter("team_color") == Teams.ENEMY_COLOR
			and second.get_team_color() == Teams.ENEMY_COLOR,
			"team_color == ENEMY_COLOR")
	_check("Bodies of one class can have different colours",
			mesh.material_override == other.material_override
			and mesh.get_instance_shader_parameter("team_color") != other.get_instance_shader_parameter("team_color"),
			"one shared material, blue and red instances")
	first.set_team_color(Teams.ENEMY_COLOR)
	_check("The colour can change later",
			mesh.get_instance_shader_parameter("team_color") == Teams.ENEMY_COLOR, "blue became red")
	first.queue_free()
	second.queue_free()
	await _wait_ticks(2)


func _test_textures() -> void:
	var albedo := _load_image(ALBEDO_PATH)
	var mask := _load_image(MASK_PATH)
	_check("The albedo and the mask are the same size",
			albedo != null and mask != null and albedo.get_size() == mask.get_size(),
			"%s and %s" % [albedo.get_size() if albedo else "?", mask.get_size() if mask else "?"])
	if albedo == null or mask == null or albedo.get_size() != mask.get_size():
		return
	var team_texels := 0
	var coloured_team_texels := 0
	var glow_texels := 0
	for y in mask.get_height():
		for x in mask.get_width():
			var m := mask.get_pixel(x, y)
			if m.g8 > 128:
				glow_texels += 1
			if m.r8 > 128:
				team_texels += 1
				var a := albedo.get_pixel(x, y)
				if not (a.r8 == a.g8 and a.g8 == a.b8):
					coloured_team_texels += 1
	_check("The mask marks team texels", team_texels > 0, "%d texels with red above 128" % team_texels)
	_check("Every team texel in the albedo is neutral grey", coloured_team_texels == 0,
			"%d of %d are coloured" % [coloured_team_texels, team_texels])
	_check("The Rifleman has no glowing texels", glow_texels == 0, "%d texels with green above 128" % glow_texels)


func _test_character_recolours() -> void:
	var own := _add_bot(0)
	var enemy := _add_bot(1)
	await _wait_ticks(2)
	Teams.set_viewer_team(0)
	_check("Viewer on team 0: team 0 is blue, team 1 is red",
			own.body.get_team_color() == Teams.FRIENDLY_COLOR and enemy.body.get_team_color() == Teams.ENEMY_COLOR,
			"%s / %s" % [own.body.get_team_color(), enemy.body.get_team_color()])
	Teams.set_viewer_team(1)
	_check("Viewer on team 1: the colours swap",
			own.body.get_team_color() == Teams.ENEMY_COLOR and enemy.body.get_team_color() == Teams.FRIENDLY_COLOR,
			"%s / %s" % [own.body.get_team_color(), enemy.body.get_team_color()])
	Teams.set_viewer_team(0)
	own.team = 1
	_check("Changing a character's team recolours it", own.body.get_team_color() == Teams.ENEMY_COLOR,
			"team 0 -> 1 with the viewer on team 0 is red")
	own.queue_free()
	enemy.queue_free()
	await _wait_ticks(2)


## A crew body with the default model (the Rifleman) in the scene.
func _add_body() -> CrewBody:
	var body := BODY_SCENE.instantiate() as CrewBody
	add_child(body)
	return body


## A bot on [param team], with its sounds off (headless runs have no audio device).
func _add_bot(team: int) -> Character:
	var bot := BOT_SCENE.instantiate() as Character
	bot.footstep_sound = null
	var weapon: Weapon = bot.get_node(bot.get_path_to(bot.weapon)) if bot.weapon else null
	if weapon != null:
		var data := weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		weapon.data = data
	bot.team = team
	add_child(bot)
	return bot


## Every MeshInstance3D under the body's model.
func _meshes(body: CrewBody) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes


## Loads a PNG's pixels straight from the file, not through the importer.
func _load_image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
