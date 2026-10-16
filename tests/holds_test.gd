extends Node
## Automated checks for how weapons look and move (M11 "Weapons and models", D-155 to D-164). Run
## without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/holds_test.tscn
##
## The viewmodel layer (D-155): every class's arms with every weapon draw with viewmodel materials,
## and standing pressed against a wall the whole viewmodel stays in front of the wall in the depth
## buffer, although the gun reaches past it. Quits with the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const CLASS_DIR := "res://characters/crew/classes/"
const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
const WEAPONS: Array[String] = ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol", "hand_cannon", "knife",
		"frag", "flashbang", "smoke"]

var _failures: int = 0
var _main: Node


func _ready() -> void:
	Weapon.silent = true
	_test_viewmodel_materials()
	await _test_against_wall()
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
