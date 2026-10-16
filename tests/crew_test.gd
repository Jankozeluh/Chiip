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
##
## Task 6 added the animations: an animated body runs the shared AnimationTree on physics ticks;
## standing, the left hand holds the foregrip; the gun points at the aim pitch; running and
## strafing move the feet through a full stride; crouching lowers the head zone like CS's
## crouch; a shot kicks the gun back and it settles; the reload moves the left hand off the
## gun but leaves the torso aiming; deaths lie on the floor and respawning stands up again; a
## character picks the death from the last hit and where the killer stood; and only whoever
## looks through a character's eyes sees its viewmodel. Task 7 checks that every class has its
## model, textures, hit zones and clips, and that the hit zones grow with the class. Task 9 checks
## the first-person arms: each class's own arms in the weapon's viewmodel with the gun on their
## weapon bone and the muzzle flash at its muzzle, sleeves in the team colour, shots and reloads
## playing their clips, and hidden arms not animating. These checks put a still body
## (animated = false, the rest pose) under the older ones, which measure the zones as made.
## Quits with the number of failed checks as the exit code (0 means everything passed).

const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")
const SHADER_PATH := "res://characters/crew/crew.gdshader"
## Clips in every class model (41 in M6, plus the arsenal's holds in M7, D-096) and in the arms.
const BODY_CLIPS := 129
const ARMS_CLIPS := 38
const MODEL_PATH := "res://assets/models/crew/rifleman.glb"
const ALBEDO_PATH := "res://assets/models/crew/rifleman_albedo.png"
const MASK_PATH := "res://assets/models/crew/rifleman_mask.png"
## The Rifleman's height in metres (the top of the head zone, within HEIGHT_TOLERANCE).
const RIFLEMAN_HEIGHT := 1.82
const HEIGHT_TOLERANCE := 0.02
## Gun points in weapon space (tools/modelgen/weapons.py, rig.py): the AK's foregrip and where
## the left wrist sits relative to it.
const FOREGRIP := Vector3(0.0, -0.008, -0.31)
const LEFT_WRIST_FROM_FOREGRIP := Vector3(-0.035, -0.035, 0.045)
const RUN_SPEED := 215.0 * 0.0254
## Every class and its height in metres (GAME_DESIGN.md 4.9, D-070).
const CLASS_HEIGHTS := {"rifleman": 1.82, "bulwark": 1.92, "marksman": 1.88, "scout": 1.72}

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
	await _test_animation_tree()
	await _test_aiming()
	await _test_strides()
	await _test_crouch_animation()
	await _test_fire_and_reload()
	await _test_deaths()
	await _test_character_deaths()
	await _test_first_person()
	await _test_classes()
	await _test_first_person_arms()
	await _test_holds()


func _test_model_and_material() -> void:
	var first := _add_body()
	var second := _add_body()
	await _wait_ticks(2)
	var meshes := first.get_meshes()
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
	var other := second.get_meshes()
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
	var mesh := first.get_meshes()[0]
	var other := second.get_meshes()[0]
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
	body.queue_free()
	await _wait_ticks(2)


## The zones follow the bones: bending the spine moves the chest zone.
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


## Task 6: an animated body runs the shared graph, and both hands hold the gun.
func _test_animation_tree() -> void:
	var body := _add_body(true)
	await _wait_ticks(2)
	var tree := body.get_animation_tree()
	_check("An animated body runs the shared crew animation graph on physics ticks",
			tree != null and tree.active and tree.tree_root == load("res://characters/crew/crew_animation_tree.tres")
			and tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,
			"tree %s" % tree)
	await _drive(body, Vector2.ZERO, false, 0.0, 40)
	var gun := _bone(body, "weapon")
	var wrist := gun * (FOREGRIP + LEFT_WRIST_FROM_FOREGRIP)
	var off := _bone(body, "hand_l").origin.distance_to(wrist)
	_check("Standing still, the left hand holds the gun's foregrip (within 3 cm)", off < 0.03, "%.3f m off" % off)
	body.queue_free()
	await _wait_ticks(2)


## The upper body aims on its own: the gun points at the aim pitch, whatever the legs do.
func _test_aiming() -> void:
	var body := _add_body(true)
	var results := ""
	var worst := 0.0
	for aim: float in [0.0, 40.0, -40.0, 70.0]:
		await _drive(body, Vector2(0, RUN_SPEED), false, aim, 30)
		var forward := -_bone(body, "weapon").basis.z.normalized()
		var pitch := rad_to_deg(asin(forward.y))
		worst = maxf(worst, absf(pitch - aim))
		results += " %+.0f->%+.1f" % [aim, pitch]
	_check("Running, the gun points at the aim pitch (within 4 degrees at 0, +-40 and +70)", worst < 4.0,
			"aim -> gun pitch:%s" % results)
	body.queue_free()
	await _wait_ticks(2)


## Running forward moves the feet through a full stride along the run; strafing turns the legs
## and moves the feet sideways.
func _test_strides() -> void:
	var body := _add_body(true)
	await _drive(body, Vector2(0, RUN_SPEED), false, 0.0, 20)
	var foot := body.get_skeleton().find_bone("foot_l")
	var lo := INF
	var hi := -INF
	for i in 90:
		await _drive(body, Vector2(0, RUN_SPEED), false, 0.0, 1)
		var z := body.get_skeleton().get_bone_global_pose(foot).origin.z
		lo = minf(lo, z)
		hi = maxf(hi, z)
	_check("Running, the left foot swings through a stride of over 0.6 m front to back", hi - lo > 0.6,
			"foot z from %.2f to %.2f m" % [lo, hi])
	var tree := body.get_animation_tree()
	_check("The legs blend by velocity relative to the facing (blend position = local velocity)",
			tree.get("parameters/Stand/blend_position") == Vector2(0, RUN_SPEED)
			and is_equal_approx(tree.get("parameters/LocoSpeed/scale"), 1.0),
			"blend %s, speed scale %.2f" % [tree.get("parameters/Stand/blend_position"), tree.get("parameters/LocoSpeed/scale")])
	await _drive(body, Vector2(RUN_SPEED, 0), false, 0.0, 30)
	lo = INF
	hi = -INF
	for i in 90:
		await _drive(body, Vector2(RUN_SPEED, 0), false, 0.0, 1)
		var x := body.get_skeleton().get_bone_global_pose(foot).origin.x
		lo = minf(lo, x)
		hi = maxf(hi, x)
	_check("Strafing right, the left foot moves sideways by over 0.4 m", hi - lo > 0.4,
			"foot x from %.2f to %.2f m" % [lo, hi])
	body.queue_free()
	await _wait_ticks(2)


## Crouching lowers the head zone about as much as CS lowers the eyes (18 units, 0.457 m).
func _test_crouch_animation() -> void:
	var body := _add_body(true)
	await _drive(body, Vector2.ZERO, false, 0.0, 40)
	var standing := body.get_zone_center(Hitbox.Zone.HEAD).y
	await _drive(body, Vector2.ZERO, true, 0.0, 60)
	var crouched := body.get_zone_center(Hitbox.Zone.HEAD).y
	_check("Crouching lowers the head zone by 0.35 to 0.55 m (CS lowers the eyes 0.457 m)",
			standing - crouched > 0.35 and standing - crouched < 0.55,
			"head zone %.2f m standing, %.2f m crouched" % [standing, crouched])
	await _drive(body, Vector2.ZERO, false, 0.0, 60)
	var back := body.get_zone_center(Hitbox.Zone.HEAD).y
	_check("Standing up raises it again", absf(back - standing) < 0.01, "%.2f m" % back)
	body.queue_free()
	await _wait_ticks(2)


## A shot kicks the gun back, added on top of the aim; the reload moves the left hand off the
## gun while the torso keeps aiming.
func _test_fire_and_reload() -> void:
	var body := _add_body(true)
	await _drive(body, Vector2.ZERO, false, 20.0, 40)
	var tree := body.get_animation_tree()
	var rest := _bone(body, "weapon")
	tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var kick := 0.0
	for i in 8:
		await _drive(body, Vector2.ZERO, false, 20.0, 1)
		kick = maxf(kick, (_bone(body, "weapon").origin - rest.origin).dot(rest.basis.z))
	await _drive(body, Vector2.ZERO, false, 20.0, 50)
	var settle := _bone(body, "weapon").origin.distance_to(rest.origin)
	_check("A shot kicks the gun back by 1 to 6 cm and it settles again (within 5 mm)",
			kick > 0.01 and kick < 0.06 and settle < 0.005, "kick %.3f m, %.4f m off afterwards" % [kick, settle])
	var chest_before := _bone(body, "chest").basis.get_rotation_quaternion()
	var wrist := rest * (FOREGRIP + LEFT_WRIST_FROM_FOREGRIP)
	tree.set("parameters/ReloadSpeed/scale", 1.0)
	tree.set("parameters/Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var away := 0.0
	var chest_turn := 0.0
	for i in 160:
		await _drive(body, Vector2.ZERO, false, 20.0, 1)
		away = maxf(away, _bone(body, "hand_l").origin.distance_to(wrist))
		chest_turn = maxf(chest_turn, rad_to_deg(chest_before.angle_to(_bone(body, "chest").basis.get_rotation_quaternion())))
	_check("The reload takes the left hand off the gun (over 15 cm) but leaves the torso aiming (under 1 degree)",
			away > 0.15 and chest_turn < 1.0, "left hand up to %.2f m away, chest turned %.2f degrees" % [away, chest_turn])
	body.queue_free()
	await _wait_ticks(2)


## Every death ends lying on the floor, and respawning stands up again.
func _test_deaths() -> void:
	var results := ""
	var all_down := true
	for style: String in ["forward", "backward", "headshot"]:
		var body := _add_body(true)
		await _drive(body, Vector2.ZERO, false, 0.0, 20)
		body.play_death(style)
		await _wait_ticks(170)
		var head := body.get_zone_center(Hitbox.Zone.HEAD).y
		var lowest := INF
		for hitbox in body.get_hitboxes():
			lowest = minf(lowest, (hitbox.get_child(0) as CollisionShape3D).global_position.y)
		results += " %s: head %.2f m, lowest zone centre %.2f m;" % [style, head, lowest]
		if head > 0.45 or lowest < -0.05:
			all_down = false
		if style == "headshot":
			body.play_alive()
			await _drive(body, Vector2.ZERO, false, 0.0, 40)
			var up := body.get_zone_center(Hitbox.Zone.HEAD).y
			_check("After a death, play_alive stands the body up again", up > 1.5, "head zone at %.2f m" % up)
		body.queue_free()
		await _wait_ticks(2)
	_check("Each of the three deaths ends lying on the floor (head zone under 0.45 m, nothing below it)", all_down, results)


## A character picks its death from its last hit and from where its killer stood, and comes back
## to life on respawn.
func _test_character_deaths() -> void:
	var victim := _add_bot(1)
	var in_front := _add_bot(0)
	var behind := _add_bot(0)
	await _wait_ticks(3)
	victim.respawn(Vector3(0, 0, 0), 0.0)
	in_front.respawn(Vector3(0, 0, -6), 0.0)
	behind.respawn(Vector3(0, 0, 6), 0.0)
	await _wait_ticks(3)
	victim.take_damage(1.0, Hitbox.Zone.CHEST, in_front)
	var from_front := victim.body.death_style(in_front)
	var from_behind := victim.body.death_style(behind)
	victim.take_damage(1.0, Hitbox.Zone.HEAD, behind)
	var headshot := victim.body.death_style(behind)
	_check("Shot from the front a character falls backward, from behind forward, and a headshot crumples",
			from_front == "backward" and from_behind == "forward" and headshot == "headshot",
			"%s, %s, %s" % [from_front, from_behind, headshot])
	victim.take_damage(500.0, Hitbox.Zone.STOMACH, in_front)
	await _wait_ticks(2)
	var dead_state: String = victim.body.get_animation_tree().get("parameters/Death/current_state")
	victim.respawn(Vector3(0, 0, 0), 0.0)
	await _wait_ticks(2)
	var alive_state: String = victim.body.get_animation_tree().get("parameters/Death/current_state")
	_check("Dying plays the death, respawning plays the living animations again",
			dead_state == "backward" and alive_state == "alive", "dead: %s, after respawn: %s" % [dead_state, alive_state])
	for bot: Character in [victim, in_front, behind]:
		bot.queue_free()
	await _wait_ticks(2)


## Only whoever looks through a character's eyes sees its viewmodel; everyone else sees its body.
func _test_first_person() -> void:
	var bot := _add_bot(1)
	await _wait_ticks(2)
	var viewmodel := bot.weapon.get_node("Viewmodel") as Node3D
	var outside := bot.body.visible and not viewmodel.visible
	bot.set_first_person(true)
	var inside := not bot.body.visible and viewmodel.visible
	bot.set_first_person(false)
	_check("A bot shows its body and hides its viewmodel; first person swaps them",
			outside and inside and bot.body.visible and not viewmodel.visible,
			"from outside: %s, first person: %s" % [outside, inside])
	bot.queue_free()
	await _wait_ticks(2)


## Task 7: every class has its model, textures, hit zones and clips, and its hit zones grow with
## its body: the head zone's top is the class's height, the Scout is the smallest target and the
## Bulwark the biggest.
func _test_classes() -> void:
	var complete := true
	var details := ""
	var volumes := {}
	var heights_ok := true
	for class_id: String in CLASS_HEIGHTS:
		var base := "res://assets/models/crew/" + class_id
		var files_ok := ResourceLoader.exists(base + ".glb") and ResourceLoader.exists(base + "_albedo.png") \
				and ResourceLoader.exists(base + "_mask.png") and ResourceLoader.exists(base + "_hit_zones.tres")
		if not files_ok:
			complete = false
			details += " %s: files missing;" % class_id
			continue
		var body := BODY_SCENE.instantiate() as CrewBody
		body.model = load(base + ".glb")
		body.animated = false
		add_child(body)
		await _wait_ticks(3)
		var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var bones := body.get_skeleton().get_bone_count()
		var clips := player.get_animation_list().size()
		var zones := body.get_hitboxes().size()
		if bones != 17 or clips != BODY_CLIPS or zones != 15:
			complete = false
		details += " %s: %d bones, %d clips, %d zones;" % [class_id, bones, clips, zones]
		var top := 0.0
		var volume := 0.0
		for hitbox in body.get_hitboxes():
			var shape := hitbox.get_child(0) as CollisionShape3D
			var size := (shape.shape as BoxShape3D).size
			volume += size.x * size.y * size.z
			if hitbox.zone == Hitbox.Zone.HEAD:
				top = shape.global_position.y + size.y / 2.0
		volumes[class_id] = volume
		if absf(top - CLASS_HEIGHTS[class_id]) > HEIGHT_TOLERANCE:
			heights_ok = false
		details += " head top %.3f m, zones %.0f L;" % [top, volume * 1000.0]
		body.queue_free()
		await _wait_ticks(2)
	_check("Every class has its model, textures and hit zones, 17 bones, %d clips (41 since M6, 52 more for the arsenal's holds in M7, 36 more aim poses every 20° in M11) and 15 hit zones" % BODY_CLIPS, complete, details)
	_check("Each class's head zone reaches its height (1.72 to 1.92 m, within 2 cm)", heights_ok, details)
	_check("The hit zones grow with the body: the Scout is the smallest target, the Bulwark the biggest",
			volumes.size() == 4 and volumes["scout"] == volumes.values().min() and volumes["bulwark"] == volumes.values().max(),
			str(volumes))


## Task 9: a character's weapon holds its class's first-person arms, with the gun and the muzzle
## flash on their weapon bone, the sleeves in the team colour, and clips for shots and reloads.
func _test_first_person_arms() -> void:
	var ok := true
	var details := ""
	for class_data in ClassData.all():
		var bot := BOT_SCENE.instantiate() as Character
		bot.footstep_sound = null
		bot.class_data = class_data
		add_child(bot)
		await _wait_ticks(2)
		var arms := bot.weapon.get_node_or_null("Viewmodel/Arms") as Node3D
		var gun := arms.find_child("Gun", true, false) as BoneAttachment3D if arms != null else null
		var flash := bot.weapon.find_child("MuzzleFlash", true, false) as Node3D
		var right_arms := arms != null and arms.scene_file_path == class_data.arms_model.resource_path
		var gun_ok := gun != null and gun.bone_name == "weapon" and flash != null and flash.get_parent() == gun
		details += " %s: arms %s, gun on weapon bone %s;" % [class_data.id, right_arms, gun_ok]
		if not right_arms or not gun_ok:
			ok = false
		bot.queue_free()
		await _wait_ticks(2)
	_check("Every class's weapon holds that class's first-person arms, with the gun and the muzzle flash on their weapon bone",
			ok, details)

	# The player's arms (the bot's controller would let go of the trigger every tick).
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Character
	player.footstep_sound = null
	var silent := (player.get_node("Head/Camera3D/Weapon") as Weapon).data.duplicate() as WeaponData
	silent.shot_sound = null
	silent.dry_fire_sound = null
	silent.reload_sound = null
	(player.get_node("Head/Camera3D/Weapon") as Weapon).data = silent
	player.team = 1
	add_child(player)
	await _wait_ticks(2)
	player.set_first_person(false)
	await _wait_ticks(1)
	var weapon := player.weapon
	var arms_player := weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hidden_idle := arms_player != null and not arms_player.active
	player.set_first_person(true)
	var sleeve_color: Color = (weapon.get_node("Viewmodel/Arms").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D) \
			.get_instance_shader_parameter("team_color")
	Teams.set_viewer_team(player.team)
	var friendly: Color = (weapon.get_node("Viewmodel/Arms").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D) \
			.get_instance_shader_parameter("team_color")
	_check("The sleeves wear the team colour (your own team blue), and hidden arms don't animate",
			friendly == Teams.FRIENDLY_COLOR and hidden_idle and arms_player.active,
			"sleeves %s with the viewer on its team (were %s before), arms player idle while hidden: %s" % [friendly, sleeve_color, hidden_idle])
	await _wait_ticks(70)
	Input.action_press("shoot")
	await _wait_ticks(3)
	var after_shot := String(arms_player.current_animation)
	Input.action_release("shoot")
	await _wait_ticks(2)
	weapon.magazine = 3
	weapon.reload()
	await _wait_ticks(2)
	var reloading := String(arms_player.current_animation)
	var reload_speed := arms_player.get_playing_speed()
	_check("A shot plays the arms' kick and a reload plays their reload, stretched to the holder's reload time (the Rifleman's is 15% shorter, M7)",
			after_shot.begins_with("fp_") and after_shot.ends_with("fire") and reloading.begins_with("fp_") and reloading.ends_with("reload")
					and is_equal_approx(reload_speed, 2.5 / weapon.get_reload_time()),
			"after a shot: %s, after reload(): %s at speed %.2f" % [after_shot, reloading, reload_speed])
	Teams.set_viewer_team(0)
	player.queue_free()
	await _wait_ticks(2)


## A crew body with the default model (the Rifleman) in the scene: still, in its rest pose,
## unless [param animated].
## M7 task 7 (D-096): the body and the first-person arms follow the held weapon's animation set:
## the hold, the fire kick, attacks and reloads, and models held with their hold offset.
func _test_holds() -> void:
	Weapon.silent = true
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Character
	player.footstep_sound = null
	add_child(player)
	await _wait_ticks(3)
	var tree := player.body.get_animation_tree()
	var inventory := player.inventory
	var arms_player := func() -> AnimationPlayer:
		return player.weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	inventory.give(load("res://weapons/pistol.tres"))
	inventory.give(load("res://weapons/knife.tres"))
	inventory.give(load("res://weapons/frag.tres"))
	inventory.hold(inventory.get_in_slot(WeaponData.Slot.PISTOL), true)
	await _wait_ticks(30)
	var pistol_hold := String(tree.get("parameters/Hold/current_state")) == "pistol"
	Input.action_press("shoot")
	await _wait_ticks(3)
	Input.action_release("shoot")
	# The kick's kind is picked when the shot plays (the node only runs then).
	var pistol_fire := String(arms_player.call().current_animation) == "fp_pistol_fire" and bool(tree.get("parameters/Fire/active")) \
			and String(tree.get("parameters/FireKind/current_state")) == "fire_pistol"
	await _wait_ticks(30)
	player.weapon.magazine = 5
	player.weapon.reload()
	await _wait_ticks(2)
	var reload_ok := String(tree.get("parameters/ReloadKind/current_state")) == "reload_pistol" \
			and String(arms_player.call().current_animation) == "fp_pistol_reload" \
			and is_equal_approx(arms_player.call().get_playing_speed(), arms_player.call().get_animation(&"fp_pistol_reload").length / player.weapon.get_reload_time())
	_check("With the Sparrow the body takes the pistol hold and kick; its shot and its reload play the pistol's clips",
			pistol_hold and pistol_fire and reload_ok, "hold %s, fire %s, reload %s" % [pistol_hold, pistol_fire, reload_ok])
	await _wait_seconds_ticks(3.0)
	var knife := inventory.get_in_slot(WeaponData.Slot.KNIFE)
	inventory.hold(knife, true)
	await _wait_ticks(30)
	var knife_hold := String(tree.get("parameters/Hold/current_state")) == "knife"
	Input.action_press("shoot")
	await _wait_ticks(3)
	Input.action_release("shoot")
	var slash := String(tree.get("parameters/AttackKind/current_state")) == "knife_slash" and bool(tree.get("parameters/Attack/active")) \
			and String(arms_player.call().current_animation) == "fp_knife_slash"
	await _wait_ticks(140)
	Input.action_press("aim")
	await _wait_ticks(3)
	Input.action_release("aim")
	var stab := String(tree.get("parameters/AttackKind/current_state")) == "knife_stab" and String(arms_player.call().current_animation) == "fp_knife_stab"
	var gun := player.body.get_gun_model()
	var fp_gun := knife.find_child("Gun", true, false).get_child(0) as Node3D if knife.find_child("Gun", true, false) != null else null
	var offset_ok := gun != null and gun.transform.is_equal_approx(knife.data.hold_offset) and fp_gun != null \
			and fp_gun.transform.is_equal_approx(knife.data.hold_offset)
	_check("With the knife: the knife hold, a slash and a stab on the body and the arms, and the knife turned in the fist (its hold offset)",
			knife_hold and slash and stab and offset_ok, "hold %s, slash %s, stab %s, offset %s" % [knife_hold, slash, stab, offset_ok])
	inventory.hold(inventory.get_grenades()[0], true)
	await _wait_ticks(30)
	_check("A grenade has its own hold, shared by every grenade", String(tree.get("parameters/Hold/current_state")) == "grenade",
			"hold %s" % tree.get("parameters/Hold/current_state"))
	var shotgun := inventory.give(load("res://weapons/shotgun.tres")) if inventory.get_in_slot(WeaponData.Slot.PRIMARY) == null else null
	if shotgun == null:
		inventory.remove(inventory.get_in_slot(WeaponData.Slot.PRIMARY))
		shotgun = inventory.give(load("res://weapons/shotgun.tres"))
	inventory.hold(shotgun, true)
	await _wait_ticks(30)
	shotgun.magazine = 4
	shotgun.reload()
	await _wait_ticks(2)
	var first := String(arms_player.call().current_animation) == "fp_shotgun_reload" and String(tree.get("parameters/ReloadKind/current_state")) == "reload_shotgun"
	await _wait_seconds_ticks(1.0)
	var next := String(arms_player.call().current_animation) == "fp_shotgun_reload_shell"
	_check("The Breaker's reload: bring it up and the first shell, then a shell at a time, on the body and the arms",
			first and next and String(tree.get("parameters/Hold/current_state")) == "shotgun", "first %s, next %s" % [first, next])
	var arms_clips := (player.weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_list().size()
	_check("The first-person arms have every weapon's clips (%d)" % ARMS_CLIPS, arms_clips == ARMS_CLIPS, "%d clips" % arms_clips)
	player.queue_free()
	Weapon.silent = false
	await _wait_ticks(2)


func _wait_seconds_ticks(seconds: float) -> void:
	await _wait_ticks(ceili(seconds * 128.0))


func _add_body(animated: bool = false) -> CrewBody:
	var body := BODY_SCENE.instantiate() as CrewBody
	body.animated = animated
	add_child(body)
	return body


## Feeds [param body] the same state for [param ticks] physics ticks.
func _drive(body: CrewBody, velocity: Vector2, crouching: bool, aim: float, ticks: int) -> void:
	for i in ticks:
		body.update_animation_state(velocity, crouching, true, aim, 1.0 / 128.0)
		await get_tree().physics_frame


## A bone's transform in world space.
func _bone(body: CrewBody, bone: String) -> Transform3D:
	var skeleton := body.get_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))


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
