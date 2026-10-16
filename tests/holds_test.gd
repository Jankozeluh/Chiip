extends Node
## Automated checks for how weapons look and move (M11 "Weapons and models", D-155 to D-164). Run
## without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/holds_test.tscn
##
## The viewmodel layer (D-155): every class's arms with every weapon draw with viewmodel materials,
## and standing pressed against a wall the whole viewmodel stays in front of the wall in the depth
## buffer, although the gun reaches past it.
##
## Holds (D-156): in third person every class keeps its left hand on every gun's foregrip in the
## poses the game blends (aim pitches, crouching, running, strafing, the kick, a flinch), within
## [constant GRIP_TOLERANCE]; the numbers without the hand IK are printed for comparison. In first
## person the arms' idle, kick and draw clips hold the foregrip too.
##
## Reloads (D-158), every class with every gun, in first and in third person: the reload clip lasts
## exactly the reload; the magazine leaves the gun with the left hand and comes back into its seat
## (the clips and GunModel's moments agree); the shotgun's shell is in the hand and reaches the
## loading port; the sounds come on their cues; a shot cuts a shotgun reload short, and the
## animations stop with it. Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const CHARACTER_SCENE := preload("res://characters/character.tscn")
## How near its seat the magazine must come back, and the shell to the loading port (metres).
const SEAT_TOLERANCE := 0.03
## How far out of the gun the magazine must go during a reload (metres).
const MAGAZINE_OUT := 0.10
const CLASS_DIR := "res://characters/crew/classes/"
const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
const WEAPONS: Array[String] = ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol", "hand_cannon", "knife",
		"frag", "flashbang", "smoke"]

## How far the left wrist may be from where it holds the foregrip (metres), and its rotation (degrees).
const GRIP_TOLERANCE := 0.015
const GRIP_ANGLE_TOLERANCE := 10.0
## The guns the left hand holds (the knife and the grenades leave it free).
const TWO_HANDED: Array[String] = ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol", "hand_cannon"]
## Third-person states: [name, velocity (x right, y forward, m/s), crouching, aim degrees, one-shot].
const STATES := [["aim -80", Vector2.ZERO, false, -80.0, ""], ["aim -50", Vector2.ZERO, false, -50.0, ""],
		["aim -20", Vector2.ZERO, false, -20.0, ""], ["aim 0", Vector2.ZERO, false, 0.0, ""],
		["aim 20", Vector2.ZERO, false, 20.0, ""], ["aim 50", Vector2.ZERO, false, 50.0, ""],
		["aim 80", Vector2.ZERO, false, 80.0, ""], ["run", Vector2(0, 5.4), false, 10.0, ""],
		["strafe", Vector2(2.8, 0), false, -15.0, ""], ["run back-left", Vector2(-3.0, -3.0), false, 30.0, ""],
		["crouch", Vector2.ZERO, true, 25.0, ""], ["crouch-walk", Vector2(0, 1.8), true, -30.0, ""],
		["kick", Vector2.ZERO, false, 5.0, "Fire"], ["flinch", Vector2(0, 2.0), false, 0.0, "Flinch"]]

var _failures: int = 0
var _main: Node


func _ready() -> void:
	Weapon.silent = true
	_test_viewmodel_materials()
	await _test_against_wall()
	_free_main()
	await _test_third_person_holds()
	_test_first_person_holds()
	await _test_reloads()
	_free_main()
	GameLaunch.clear()
	MenuState.reset()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The viewmodel layer (D-155) ---


## Every mesh in every class's viewmodel with every weapon draws with a viewmodel material.
func _test_viewmodel_materials() -> void:
	var meshes := 0
	var wrong: Array[String] = []
	var holder := Node3D.new()
	add_child(holder)
	for class_id in CLASSES:
		var class_data := load(CLASS_DIR + class_id + ".tres") as ClassData
		for weapon_id in WEAPONS:
			var weapon := Weapon.create(load("res://weapons/%s.tres" % weapon_id) as WeaponData)
			holder.add_child(weapon)
			weapon.set_arms(class_data.arms_model, CrewBody.material_for(class_data.model.resource_path))
			for node in weapon.get_node("Viewmodel").find_children("*", "MeshInstance3D", true, false):
				var mesh := node as MeshInstance3D
				meshes += 1
				if not _draws_as_viewmodel(mesh) or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					wrong.append("%s/%s/%s" % [class_id, weapon_id, mesh.name])
			weapon.free()
	holder.free()
	_check("Every class's arms with every weapon (and the muzzle flash) draw in the viewmodel layer, without shadows",
			meshes >= CLASSES.size() * WEAPONS.size() * 3 and wrong.is_empty(),
			"%d meshes, not in the layer: %s" % [meshes, ", ".join(wrong.slice(0, 6))])
	var flash := (load(Weapon.SCENE_PATH) as PackedScene).instantiate()
	var flash_mesh := flash.get_node("Viewmodel/MuzzleFlash/Flash") as MeshInstance3D
	_check("The muzzle flash is drawn by the viewmodel's flash shader (it stays on the muzzle at any FOV)",
			Viewmodel.is_viewmodel_material(flash_mesh.mesh.surface_get_material(0)), "")
	flash.free()


## True when every surface of [param mesh] uses a viewmodel shader.
func _draws_as_viewmodel(mesh: MeshInstance3D) -> bool:
	if mesh.material_override != null:
		return Viewmodel.is_viewmodel_material(mesh.material_override)
	if mesh.mesh == null:
		return false
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_surface_override_material(surface)
		if material == null:
			material = mesh.mesh.surface_get_material(surface)
		if not Viewmodel.is_viewmodel_material(material):
			return false
	return true


## The player walks into a wall of the Shooting Range: the gun reaches past the wall, but every
## point of the viewmodel gets a nearer depth than the wall, so the wall can't cover it.
func _test_against_wall() -> void:
	GameLaunch.start_practice(Settings.DEFAULT_MAP, GameLaunch.difficulty_named("normal"))
	_main = MAIN_SCENE.instantiate()
	_main.load_settings = false
	_main.loading_screen = false
	add_child(_main)
	for i in 10:
		await get_tree().physics_frame
	var map := _main.get_map() as Node3D
	var player := map.get_node("Player") as Character
	var camera := player.get_camera()
	var space := player.get_world_3d().direct_space_state
	# The nearest wall around the player's start.
	var eye := camera.global_position
	var to_wall := Vector3.ZERO
	var wall_point := Vector3.ZERO
	for k in 36:
		var direction := Vector3(sin(TAU * k / 36.0), 0.0, cos(TAU * k / 36.0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + direction * 40.0, PhysicsLayers.WORLD))
		if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.2:
			continue
		if to_wall == Vector3.ZERO or eye.distance_to(hit.position) < eye.distance_to(wall_point):
			to_wall = -(hit.normal as Vector3)
			wall_point = hit.position
	var yaw := atan2(-to_wall.x, -to_wall.z)
	# Stand a little into the wall: the physics pushes the body back out, flat against it.
	var feet := wall_point - to_wall * 0.2
	feet.y = player.global_position.y
	player.respawn(feet, yaw)
	var controller := player.get_node("PlayerController") as PlayerController
	# Respawning draws the gun again: wait until it's up.
	for i in 200:
		controller.set_look_angles(yaw, 0.0)
		await get_tree().physics_frame
	await get_tree().process_frame
	eye = camera.global_position
	var forward := -camera.global_basis.z
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + forward * 5.0, PhysicsLayers.WORLD))
	var wall_distance: float = eye.distance_to(hit.position) if not hit.is_empty() else INF
	# How far the gun's vertices reach in front of the eye (the arms run back past the camera,
	# out of sight; their skinned bounding box is the T-pose's).
	var nearest := INF
	var farthest := 0.0
	var view := camera.global_transform.affine_inverse()
	var mount := player.weapon.get_node("Viewmodel").find_child("Gun", true, false) as Node3D
	for node in mount.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.name == "Flash":
			continue
		var to_view := view * mesh.global_transform
		for point in mesh.mesh.get_faces():
			var depth := -(to_view * point).z
			nearest = minf(nearest, depth)
			farthest = maxf(farthest, depth)
	var wall_depth := Viewmodel.world_depth(wall_distance, camera.near, camera.far)
	_check("Pressed against a wall, the gun reaches past it (so without its own layer it would poke through)",
			wall_distance < 0.6 and farthest > wall_distance,
			"wall %.2f m ahead, viewmodel up to %.2f m" % [wall_distance, farthest])
	_check("...but every point of the gun is nearer in the depth buffer than the wall, and none of it is cut by the viewmodel's near plane",
			Viewmodel.clip_depth(farthest) > wall_depth and nearest > Viewmodel.NEAR,
			"gun depth %.4f to %.4f, wall %.4f (camera near %.2f m), nearest point %.3f m" % [
					Viewmodel.clip_depth(farthest), Viewmodel.clip_depth(nearest), wall_depth, camera.near, nearest])
	# Even a wall at the camera's near plane loses against the farthest of the viewmodel.
	_check("The viewmodel's whole depth range lies in front of anything beyond the camera's near plane",
			Viewmodel.clip_depth(1000.0) > Viewmodel.world_depth(camera.near * 1.05, camera.near, camera.far),
			"%.4f vs %.4f" % [Viewmodel.clip_depth(1000.0), Viewmodel.world_depth(camera.near * 1.05, camera.near, camera.far)])


# --- Holds (D-156) ---


## Every class with every two-handed gun, in every state of [constant STATES]: the left wrist is
## where it holds the foregrip.
func _test_third_person_holds() -> void:
	var worst := {"on": 0.0, "off": 0.0, "angle": 0.0}
	var worst_where := ""
	var off_where := ""
	var measured := 0
	for class_id in CLASSES:
		var class_data := load(CLASS_DIR + class_id + ".tres") as ClassData
		for weapon_id in TWO_HANDED:
			var data := load("res://weapons/%s.tres" % weapon_id) as WeaponData
			var body := (load("res://characters/crew/crew_body.tscn") as PackedScene).instantiate() as CrewBody
			body.model = class_data.model
			add_child(body)
			body._show_gun(data)
			body._set_hold(data)
			var tree := body.get_animation_tree()
			var ik := body.get_hand_ik()
			var skeleton := body.get_skeleton()
			var hand := skeleton.find_bone("hand_l")
			for state: Array in STATES:
				for i in 24:
					body.update_animation_state(state[1], state[2], true, state[3], 1.0 / 128.0)
					await get_tree().physics_frame
				if state[4] != "":
					tree.set("parameters/%s/request" % state[4], AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
					for i in 4:
						body.update_animation_state(state[1], state[2], true, state[3], 1.0 / 128.0)
						await get_tree().physics_frame
				for with_ik: bool in [false, true]:
					ik.active = with_ik
					# A modifier's result is in the poses only while the skeleton draws.
					var seen := {}
					var read := func() -> void:
						seen.want = ik.get_target_pose()
						seen.pose = skeleton.get_bone_global_pose(hand)
					skeleton.skeleton_updated.connect(read, CONNECT_ONE_SHOT)
					body.update_animation_state(state[1], state[2], true, state[3], 1.0 / 128.0)
					await get_tree().physics_frame
					await get_tree().process_frame
					if seen.is_empty():
						continue
					var want: Transform3D = seen.want
					var pose: Transform3D = seen.pose
					var distance := pose.origin.distance_to(want.origin)
					var angle := rad_to_deg(pose.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion()))
					var where := "%s/%s/%s" % [class_id, weapon_id, state[0]]
					if with_ik:
						measured += 1
						if distance > worst.on:
							worst.on = distance
							worst_where = where
						worst.angle = maxf(worst.angle, angle)
					elif distance > worst.off:
						worst.off = distance
						off_where = where
				ik.active = true
			body.free()
	_check("Third person: every class keeps its left hand on every gun's foregrip in every blended pose (aim, crouch, run, strafe, kick, flinch)",
			measured == CLASSES.size() * TWO_HANDED.size() * STATES.size() and worst.on <= GRIP_TOLERANCE
					and worst.angle <= GRIP_ANGLE_TOLERANCE,
			"%d poses, worst %.1f cm (%s), %.1f° off; without the hand IK up to %.1f cm (%s)" % [measured,
					worst.on * 100.0, worst_where, worst.angle, worst.off * 100.0, off_where])


## The first-person arms' idle, kick and draw (at its end) hold the foregrip, for every class and gun.
func _test_first_person_holds() -> void:
	var worst := 0.0
	var worst_angle := 0.0
	var worst_where := ""
	var measured := 0
	var holder := Node3D.new()
	add_child(holder)
	for class_id in CLASSES:
		var class_data := load(CLASS_DIR + class_id + ".tres") as ClassData
		for weapon_id in TWO_HANDED:
			var data := load("res://weapons/%s.tres" % weapon_id) as WeaponData
			var weapon := Weapon.create(data)
			holder.add_child(weapon)
			weapon.set_arms(class_data.arms_model, CrewBody.material_for(class_data.model.resource_path))
			var arms := weapon.get_node("Viewmodel/Arms") as Node3D
			var player := arms.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var skeleton := arms.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var model := (arms.find_child("Gun", true, false) as Node3D).get_child(0) as Node3D
			if model == weapon.get_node("Viewmodel").find_child("MuzzleFlash", true, false):
				model = (arms.find_child("Gun", true, false) as Node3D).get_child(1) as Node3D
			var target := GunModel.left_hand_target(model)
			var set_name := String(data.get_anim_set())
			var prefix := "fp_" if set_name == "rifle" else "fp_%s_" % set_name
			for action: String in ["idle", "fire", "draw"]:
				var clip: String = prefix + action
				if not player.has_animation(clip):
					clip = "fp_" + action
				var length := player.get_animation(clip).length
				for t: float in ([0.0, 0.03, 0.08] if action == "fire" else [length] if action == "draw" else [0.0, length * 0.5]):
					player.play(clip)
					player.seek(t, true)
					skeleton.force_update_all_bone_transforms()
					var want := skeleton.get_bone_global_pose(skeleton.find_bone("weapon")) * target
					var pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
					var distance := pose.origin.distance_to(want.origin)
					measured += 1
					worst_angle = maxf(worst_angle, rad_to_deg(pose.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion())))
					if distance > worst:
						worst = distance
						worst_where = "%s/%s/%s@%.2f" % [class_id, weapon_id, clip, t]
			weapon.free()
	holder.free()
	_check("First person: every class's arms hold every gun's foregrip in the idle, the kick and the end of the draw",
			measured > 0 and worst <= GRIP_TOLERANCE and worst_angle <= GRIP_ANGLE_TOLERANCE,
			"%d frames, worst %.1f cm (%s), %.1f° off" % [measured, worst * 100.0, worst_where, worst_angle])


# --- Reloads (D-158) ---


## Every class reloads every gun in first and third person: lengths, the magazine, the shell, the
## sound cues; then a shotgun reload cut short by a shot.
func _test_reloads() -> void:
	var length_errors: Array[String] = []
	var magazine_errors: Array[String] = []
	var cue_errors: Array[String] = []
	var reloads := 0
	var worst_seat := 0.0
	var least_out := INF
	for class_id in CLASSES:
		var character := CHARACTER_SCENE.instantiate() as Character
		character.class_data = load(CLASS_DIR + class_id + ".tres") as ClassData
		add_child(character)
		await _ticks(2)
		for weapon_id in TWO_HANDED:
			var data := load("res://weapons/%s.tres" % weapon_id) as WeaponData
			character.inventory.set_loadout([data] as Array[WeaponData])
			for first_person: bool in [true, false]:
				character.set_first_person(first_person)
				await _ticks(int(data.draw_time * 128.0) + 8)
				var weapon := character.weapon
				# One round short (a shotgun: one shell), plenty in reserve.
				weapon.magazine = data.magazine_size - 1
				weapon.reserve = data.magazine_size
				var cues: Array = []
				var on_cue := func(step: int) -> void: cues.append([step, weapon.get_reload_progress()])
				weapon.reload_cue.connect(on_cue)
				weapon.reload()
				await get_tree().process_frame
				reloads += 1
				var where := "%s/%s/%s" % [class_id, weapon_id, "fp" if first_person else "tp"]
				var expected := weapon.get_reload_time()
				if data.reload_per_shell:
					expected += data.reload_start_time * weapon._class_factor(&"reload_time_factor")
				var shown := _shown_reload_length(character, weapon, first_person)
				if absf(shown - expected) > 0.02:
					length_errors.append("%s %.2f s instead of %.2f" % [where, shown, expected])
				var result := await _follow_reload(character, weapon, first_person)
				weapon.reload_cue.disconnect(on_cue)
				worst_seat = maxf(worst_seat, result.back_at)
				if not data.reload_per_shell:
					least_out = minf(least_out, result.out)
				if result.back_at > SEAT_TOLERANCE or result.out < MAGAZINE_OUT or result.after > 0.001:
					magazine_errors.append("%s: back %.1f cm, out %.1f cm, after %.1f cm" % [where,
							result.back_at * 100.0, result.out * 100.0, result.after * 100.0])
				var wanted := GunModel.SHELL_SOUNDS if data.reload_per_shell else GunModel.MAGAZINE_SOUNDS
				var cues_ok := cues.size() == wanted.size()
				for i in mini(cues.size(), wanted.size()):
					cues_ok = cues_ok and cues[i][0] == i and absf(float(cues[i][1]) - wanted[i]) < 0.03
				if not cues_ok:
					cue_errors.append("%s %s" % [where, str(cues)])
		character.free()
	_check("Reloads last exactly the reload time in first and third person (the clip is stretched to it), every class × gun",
			reloads == CLASSES.size() * TWO_HANDED.size() * 2 and length_errors.is_empty(),
			"%d reloads%s" % [reloads, "; " + ", ".join(length_errors.slice(0, 4)) if not length_errors.is_empty() else ""])
	_check("The magazine (the shotgun's shell) goes with the left hand and back into its seat (the loading port), in first and third person",
			magazine_errors.is_empty(), "worst %.1f cm from the seat, out at least %.1f cm%s" % [worst_seat * 100.0,
					least_out * 100.0, "; " + ", ".join(magazine_errors.slice(0, 4)) if not magazine_errors.is_empty() else ""])
	_check("The reload sounds come on their cues (magazine out, in, handle; a shell going in)",
			cue_errors.is_empty(), ", ".join(cue_errors.slice(0, 4)))
	await _test_shotgun_interrupt()


## How long the reload being shown lasts: the arms' clip in first person, the body's in third.
func _shown_reload_length(character: Character, weapon: Weapon, first_person: bool) -> float:
	if first_person:
		var player := weapon.get_node("Viewmodel/Arms").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		return player.current_animation_length / maxf(player.get_playing_speed(), 0.001)
	var tree := character.body.get_animation_tree()
	var clip := String(tree.get("parameters/ReloadKind/current_state"))
	var player := character.body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not player.has_animation(clip):
		return -1.0
	return player.get_animation(clip).length / maxf(float(tree.get("parameters/ReloadSpeed/scale")), 0.001)


## Steps through a reload in progress: how far the magazine (or the shell) is from its seat (the
## loading port) just before it goes in, the farthest it gets out, and where it is afterwards.
func _follow_reload(character: Character, weapon: Weapon, first_person: bool) -> Dictionary:
	var parts := _parts_of(character, weapon, first_person)
	var model := _model_of(character, weapon, first_person)
	var shell := weapon.data.reload_per_shell
	var part := parts.get_shell() if shell else parts.get_magazine()
	var result := {"back_at": INF, "out": 0.0, "after": 0.0}
	var insert: float = GunModel.events_for(weapon.data)[&"insert"]
	while weapon.is_reloading():
		await get_tree().physics_frame
		await get_tree().process_frame
		var progress := weapon.get_reload_progress()
		var seat_position := model.get_parent_node_3d().global_transform * GunModel.point_transform(model, "magazine").origin
		var distance := part.global_position.distance_to(seat_position)
		if (part.visible or not shell) and progress < insert and progress > insert - 0.06:
			result.back_at = distance
		if part.visible:
			result.out = maxf(result.out, distance)
	await get_tree().process_frame
	if not shell:
		result.after = part.global_position.distance_to(model.get_parent_node_3d().global_transform
				* GunModel.point_transform(model, "magazine").origin)
	elif part.visible:
		result.after = 1.0
	if shell:
		result.out = MAGAZINE_OUT
	return result


func _parts_of(character: Character, weapon: Weapon, first_person: bool) -> GunModel:
	return weapon._gun_parts if first_person else character.body.get_gun_parts()


func _model_of(character: Character, weapon: Weapon, first_person: bool) -> Node3D:
	if not first_person:
		return character.body.get_gun_model()
	var mount := weapon.get_node("Viewmodel/Arms").find_child("Gun", true, false) as Node3D
	for child in mount.get_children():
		if child.name != "MuzzleFlash":
			return child as Node3D
	return null


## A shot stops a shotgun's reload once a shell is in: the weapon stops reloading, and neither the
## arms nor the body keep showing it; the shell in the hand goes away.
func _test_shotgun_interrupt() -> void:
	var character := CHARACTER_SCENE.instantiate() as Character
	character.class_data = load(CLASS_DIR + "rifleman.tres") as ClassData
	add_child(character)
	await _ticks(2)
	var data := load("res://weapons/shotgun.tres") as WeaponData
	character.inventory.set_loadout([data] as Array[WeaponData])
	character.set_first_person(true)
	await _ticks(int(data.draw_time * 128.0) + 8)
	var weapon := character.weapon
	weapon.magazine = data.magazine_size - 4
	weapon.reserve = 10
	weapon.reload()
	# The first shell (brought up, then in) and half of the second.
	var wait := data.reload_start_time + data.reload_time * 1.5
	await _ticks(int(wait * 128.0))
	var loading := weapon.is_reloading()
	character._input.shoot = true
	await _ticks(3)
	character._input.shoot = false
	await _ticks(40)
	var arms := weapon.get_node("Viewmodel/Arms").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var tree := character.body.get_animation_tree()
	var fp_clip := String(arms.current_animation)
	_check("A shot cuts a shotgun reload short: the weapon stops loading, the arms and the body stop showing the reload, the shell leaves the hand",
			loading and not weapon.is_reloading() and not fp_clip.contains("reload")
					and not bool(tree.get("parameters/Reload/active")) and not weapon._gun_parts.get_shell().visible,
			"was loading %s, still %s, arms play %s, body reload active %s" % [loading, weapon.is_reloading(), fp_clip,
					tree.get("parameters/Reload/active")])
	character.free()


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
