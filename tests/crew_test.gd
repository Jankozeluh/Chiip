extends Node3D
## Automated crew model checks (M6 tasks 3 and 4). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/crew_test.tscn
##
## Checks that a [CrewBody] builds its model with the shared team-colour material (crew.gdshader,
## both textures), that the team colour is a per-instance parameter (two bodies of a class share
## one material but can differ in colour), that the generated textures follow the contract of
## tools/modelgen/paint.py (team texels are neutral grey, no glow on the Rifleman), and that a
## [Character] recolours its body when the viewer's team changes (Teams.set_viewer_team).
##
## Task 4 added the hit zones: a [CrewBody] builds one [Hitbox] per box of its HitZones resource
## on a BoneAttachment3D, the zones are stacked like a standing body (the head zone's top is the
## class's height), rays hit the right zone, the zones follow the bones (bending the spine moves
## the chest) and sink when the body crouches, and a [Character] takes its head and chest
## positions from them.
## Quits with the number of failed checks as the exit code (0 means everything passed).

const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const SHADER_PATH := "res://characters/crew/crew.gdshader"
const MODEL_PATH := "res://assets/models/crew/rifleman.glb"
const ALBEDO_PATH := "res://assets/models/crew/rifleman_albedo.png"
const MASK_PATH := "res://assets/models/crew/rifleman_mask.png"
## The Rifleman's height in metres (the top of the head zone, within HEIGHT_TOLERANCE).
const RIFLEMAN_HEIGHT := 1.82
const HEIGHT_TOLERANCE := 0.02

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
	await _test_hit_zones_built()
	await _test_hit_zones_shape_and_rays()
	await _test_hit_zones_follow_bones()
	await _test_character_aim_points()


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


## Hit zones: 15 boxes (1 head, 1 chest, 1 stomach, 6 arms, 6 legs), each on a bone attachment.
func _test_hit_zones_built() -> void:
	var body := _add_body()
	await _wait_ticks(3)
	var skeleton := _skeleton(body)
	var hitboxes := body.get_hitboxes()
	var counts := {}
	for hitbox in hitboxes:
		counts[hitbox.zone] = counts.get(hitbox.zone, 0) + 1
	var expected := {
		Hitbox.Zone.HEAD: 1, Hitbox.Zone.CHEST: 1, Hitbox.Zone.STOMACH: 1,
		Hitbox.Zone.ARMS: 6, Hitbox.Zone.LEGS: 6,
	}
	_check("The Rifleman has 15 hit zones: 1 head, 1 chest, 1 stomach, 6 arms, 6 legs",
			hitboxes.size() == 15 and counts == expected, "%d boxes, by zone %s" % [hitboxes.size(), counts])
	var on_bones := not hitboxes.is_empty() and skeleton != null
	var details := "every box has a BoneAttachment3D parent on a bone of the skeleton"
	for hitbox in hitboxes:
		var attachment := hitbox.get_parent() as BoneAttachment3D
		if attachment == null or attachment.get_parent() != skeleton or skeleton.find_bone(attachment.bone_name) < 0:
			on_bones = false
			details = "%s is not under a BoneAttachment3D on a bone" % hitbox.name
			break
	_check("Every hit zone sits under a BoneAttachment3D whose bone exists in the skeleton", on_bones, details)
	var shapes_ok := not hitboxes.is_empty()
	for hitbox in hitboxes:
		var shape := hitbox.get_child(0) as CollisionShape3D if hitbox.get_child_count() > 0 else null
		if shape == null or not shape.shape is BoxShape3D or hitbox.collision_layer != PhysicsLayers.HITBOXES:
			shapes_ok = false
	_check("Every hit zone is a Hitbox area on the hitboxes layer with a box shape", shapes_ok,
			"%d hit zones" % hitboxes.size())
	body.queue_free()
	await _wait_ticks(2)


## Zones are stacked like a standing body, the head's top is the class's height, and rays from
## the front hit the head, the chest and the stomach at their centres' heights.
func _test_hit_zones_shape_and_rays() -> void:
	var body := _add_body()
	await _wait_ticks(3)
	var head := body.get_zone_center(Hitbox.Zone.HEAD)
	var chest := body.get_zone_center(Hitbox.Zone.CHEST)
	var stomach := body.get_zone_center(Hitbox.Zone.STOMACH)
	var thigh_top := INF
	for hitbox in body.get_hitboxes():
		if hitbox.zone == Hitbox.Zone.LEGS and (hitbox.get_parent() as BoneAttachment3D).bone_name.begins_with("thigh"):
			thigh_top = minf(thigh_top, (hitbox.get_child(0) as CollisionShape3D).global_position.y)
	_check("Zone heights make sense: head above chest above stomach above the thighs",
			head.y > chest.y and chest.y > stomach.y and stomach.y > thigh_top and thigh_top < INF,
			"head %.3f, chest %.3f, stomach %.3f, highest thigh centre %.3f m" % [head.y, chest.y, stomach.y, thigh_top])
	var head_top := 0.0
	for hitbox in body.get_hitboxes():
		if hitbox.zone == Hitbox.Zone.HEAD:
			var shape := hitbox.get_child(0) as CollisionShape3D
			head_top = shape.global_position.y + (shape.shape as BoxShape3D).size.y / 2.0
	_check("The head zone's top is the Rifleman's height (1.82 m, within 2 cm)",
			absf(head_top - RIFLEMAN_HEIGHT) <= HEIGHT_TOLERANCE, "top at %.3f m" % head_top)
	var head_hit := await _ray_hits(head)
	var chest_hit := await _ray_hits(chest)
	var stomach_hit := await _ray_hits(stomach)
	_check("A ray from the front at head height hits the head zone",
			head_hit == Hitbox.Zone.HEAD, "zone %d (head is %d)" % [head_hit, Hitbox.Zone.HEAD])
	_check("A ray from the front at chest height hits the chest zone",
			chest_hit == Hitbox.Zone.CHEST, "zone %d (chest is %d)" % [chest_hit, Hitbox.Zone.CHEST])
	_check("A ray from the front at stomach height hits the stomach zone",
			stomach_hit == Hitbox.Zone.STOMACH, "zone %d (stomach is %d)" % [stomach_hit, Hitbox.Zone.STOMACH])
	# The interim pose: the arms hang at the sides, so the hands are well below the shoulders.
	var hands_down := true
	var hand_details := ""
	for hitbox in body.get_hitboxes():
		if (hitbox.get_parent() as BoneAttachment3D).bone_name.begins_with("hand"):
			var hand := (hitbox.get_child(0) as CollisionShape3D).global_position
			hand_details += " %.2f/%.2f" % [hand.x, hand.y]
			if hand.y > chest.y - 0.3 or absf(hand.x) > 0.45:
				hands_down = false
	_check("The interim pose lets the arms hang at the sides (hands below the chest, near the body)",
			hands_down, "hand x/y:%s, chest y %.2f" % [hand_details, chest.y])
	body.queue_free()
	await _wait_ticks(2)


## The zones follow the bones: bending the spine moves the chest zone, and crouching sinks the head.
func _test_hit_zones_follow_bones() -> void:
	var body := _add_body()
	await _wait_ticks(3)
	var skeleton := _skeleton(body)
	var spine := skeleton.find_bone("spine")
	var chest_before := body.get_zone_center(Hitbox.Zone.CHEST)
	skeleton.set_bone_pose_rotation(spine, Quaternion(Vector3.RIGHT, deg_to_rad(60.0)))
	await _wait_ticks(1)
	skeleton.force_update_all_bone_transforms()
	await _wait_ticks(1)
	var moved := body.get_zone_center(Hitbox.Zone.CHEST).distance_to(chest_before)
	_check("The hit zones follow the bones: bending the spine 60 degrees moves the chest zone by over 10 cm",
			moved > 0.1, "moved %.3f m" % moved)
	skeleton.set_bone_pose_rotation(spine, Quaternion.IDENTITY)
	await _wait_ticks(2)
	skeleton.force_update_all_bone_transforms()
	await _wait_ticks(1)
	_check("Resetting the spine puts the chest zone back",
			body.get_zone_center(Hitbox.Zone.CHEST).distance_to(chest_before) < 0.001,
			"%.4f m off" % body.get_zone_center(Hitbox.Zone.CHEST).distance_to(chest_before))

	var head_before := body.get_zone_center(Hitbox.Zone.HEAD)
	var crouch := (64.0 - 46.0) * Character.UNITS_TO_METRES
	body.update_pose(0.0, 5.0, -crouch, true, 0.016)
	await _wait_ticks(2)
	skeleton.force_update_all_bone_transforms()
	await _wait_ticks(1)
	var drop := head_before.y - body.get_zone_center(Hitbox.Zone.HEAD).y
	_check("Crouching sinks the head zone by 0.45 to 0.47 m (CS: 64 to 46 units)",
			drop >= 0.45 and drop <= 0.47, "dropped %.3f m" % drop)
	body.reset_pose()
	await _wait_ticks(2)
	skeleton.force_update_all_bone_transforms()
	await _wait_ticks(1)
	var back := body.get_zone_center(Hitbox.Zone.HEAD).distance_to(head_before)
	_check("reset_pose brings the head zone back", back < 0.001, "%.4f m off" % back)
	body.queue_free()
	await _wait_ticks(2)


## A Character has all 15 zones as its own, and aims and looks at the zones' centres.
func _test_character_aim_points() -> void:
	var bot := _add_bot(1)
	await _wait_ticks(3)
	var head := bot.body.get_zone_center(Hitbox.Zone.HEAD)
	var chest := bot.body.get_zone_center(Hitbox.Zone.CHEST)
	_check("A Character finds all 15 hit zones of its body", bot.get_hitbox_rids().size() == 15,
			"%d hit zone RIDs" % bot.get_hitbox_rids().size())
	var expected_points: Array[Vector3] = [head, chest]
	_check("A Character's head and chest positions are its zone centres",
			bot.get_head_position() == head and bot.get_chest_position() == chest
			and bot.get_visibility_points() == expected_points,
			"head %s, chest %s" % [bot.get_head_position(), bot.get_chest_position()])
	_check("The head zone is near the eyes, the chest zone below them",
			absf(bot.get_head_position().y - bot.get_eye_position().y) < 0.1
			and bot.get_chest_position().y < bot.get_eye_position().y - 0.1,
			"head %.3f, eyes %.3f, chest %.3f m" % [bot.get_head_position().y, bot.get_eye_position().y, bot.get_chest_position().y])
	bot.queue_free()
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


## The Skeleton3D of the body's model.
func _skeleton(body: CrewBody) -> Skeleton3D:
	return body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


## The zone of the hit zone a ray hits when it travels from 2 m in front of the body (it faces -Z)
## toward +Z at the height and sideways position of [param point]; -1 if it hits none.
func _ray_hits(point: Vector3) -> int:
	await _wait_ticks(2)
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, point.y, -2.0), Vector3(point.x, point.y, 2.0), PhysicsLayers.HITBOXES)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty() or not result.collider is Hitbox:
		return -1
	return (result.collider as Hitbox).zone


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
