extends Node
## Automated checks for the sound pass (M8, D-084). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 20000 res://tests/sound_test.tscn
##
## On Depot: the surface under the feet (gravel in the spawn yard, hard
## concrete on the dock, metal on a container and wood on a crate, found from
## the map's own texture data), the footsteps each surface plays, the impact
## sound of each surface, and the sounds of the real rifle's bullets hitting
## gravel, a body and a head (a headshot is louder and carries farther), with a
## silent weapon making no impact sounds. Also that menu buttons get their sounds and interface sounds
## are off without a window. Quits with the number of failed checks as the exit code.

const MAP_SCENE := preload("res://maps/depot.tscn")
const BOT_SCENE := preload("res://bots/bot.tscn")

var _map: Node3D
var _player: Character
var _failures: int = 0


func _ready() -> void:
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_player.footstep_sound = preload("res://assets/sounds/footsteps.tres")
	await _wait_ticks(30)
	_test_floors()
	_test_footsteps()
	await _test_impacts()
	_test_ui_sounds()
	# Let every sound end before quitting: the map and its impacts go first.
	remove_child(_map)
	_map.queue_free()
	await _wait_ticks(5)
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _test_floors() -> void:
	var world := _map.get_world_3d()
	var spawn := _map.get_node("Spawns/AttackSpawn3").global_position as Vector3
	var dock := (_map.get_node("Objectives/BombSiteB") as Node3D).global_position + Vector3.DOWN * 1.5
	var metal_top := _top_of_brush_with(&"metal_plates")
	var wood_top := _top_of_brush_with(&"wood_planks")
	var kinds := [Surfaces.floor_kind(world, spawn), Surfaces.floor_kind(world, dock),
			Surfaces.floor_kind(world, metal_top), Surfaces.floor_kind(world, wood_top)]
	_check("The floor under the feet: gravel in the spawn yard, hard on the dock, metal on a metal roof, wood on a crate",
			kinds == [Surfaces.Kind.GRAVEL, Surfaces.Kind.HARD, Surfaces.Kind.METAL, Surfaces.Kind.WOOD],
			"%s (metal top at %s, crate top at %s)" % [kinds.map(func(kind: int) -> String: return Surfaces.Kind.keys()[kind]), metal_top, wood_top])
	_check("No floor at all counts as hard", Surfaces.floor_kind(world, Vector3(0.0, 200.0, 0.0)) == Surfaces.Kind.HARD, "")


func _test_footsteps() -> void:
	var hard := _player.footstep_sound
	var sounds := [Surfaces.footstep_sound(Surfaces.Kind.HARD, hard), Surfaces.footstep_sound(Surfaces.Kind.GRAVEL, hard),
			Surfaces.footstep_sound(Surfaces.Kind.METAL, hard), Surfaces.footstep_sound(Surfaces.Kind.WOOD, hard)]
	var files := sounds.map(func(sound: AudioStream) -> String: return sound.resource_path.get_file())
	_check("Each surface has its own footsteps; hard floors keep the character's own",
			files == ["footsteps.tres", "footsteps_gravel.tres", "footsteps_metal.tres", "footsteps_wood.tres"]
			and sounds.all(func(sound: AudioStream) -> bool: return (sound as AudioStreamRandomizer).streams_count == 3),
			str(files))


func _test_impacts() -> void:
	var weapon := _player.weapon
	weapon.rng.seed = 1
	# A bot to shoot at, standing still 6 m in front of the attackers' spawn.
	var bot: Character = BOT_SCENE.instantiate()
	bot.team = 1
	bot.footstep_sound = null
	(bot.get_node("BotController") as BotController).hold_position = true
	_map.add_child(bot)
	var spawn := _map.get_node("Spawns/AttackSpawn3").global_position as Vector3
	_player.respawn(spawn, 0.0)
	bot.respawn(spawn + Vector3(0.0, 0.0, -6.0), 0.0)
	(bot.get_node("BotSenses") as BotSenses).process_mode = Node.PROCESS_MODE_DISABLED
	await _wait_ticks(4)
	var results := {}
	results["gravel"] = await _shoot_at(spawn + Vector3(1.5, 0.0, -3.0))
	results["body"] = await _shoot_at(bot.global_position + Vector3.UP * 1.1)
	bot.health = bot.max_health
	results["head"] = await _shoot_at(bot.get_eye_position())
	var names := {}
	for key in results:
		names[key] = (results[key][0] as AudioStream).resource_path.get_file() if results[key][0] != null else "none"
	var impacts := Surfaces.Kind.values().map(func(kind: int) -> String: return Surfaces.impact_sound(kind).resource_path.get_file())
	_check("Each surface has its own bullet impact sound",
			impacts == ["impact_hard.wav", "impact_gravel.wav", "impact_metal.wav", "impact_wood.wav"], str(impacts))
	_check("The rifle's bullets sound like what they hit: gravel, a body, a head",
			names == {"gravel": "impact_gravel.wav", "body": "hit_body.wav", "head": "hit_head.wav"}, str(names))
	_check("A headshot is louder and carries farther than a body hit",
			results["head"][1] > results["body"][1] and results["head"][2] > results["body"][2],
			"head %.0f dB / %.0f m, body %.0f dB / %.0f m" % [results["head"][1], results["head"][2], results["body"][1], results["body"][2]])
	# The tests' silent weapon (no shot sound) makes no impact sound either.
	var silent := weapon.data.duplicate() as WeaponData
	var loud := weapon.data
	silent.shot_sound = null
	weapon.data = silent
	var quiet: Array = await _shoot_at(spawn + Vector3(-1.5, 0.0, -3.0))
	weapon.data = loud
	_check("A silent weapon (tests) makes no impact sounds", quiet[0] == null, str(quiet))
	bot.queue_free()


func _test_ui_sounds() -> void:
	var box := VBoxContainer.new()
	var button := Button.new()
	box.add_child(button)
	add_child(box)
	UiSounds.attach(box)
	var wired := button.has_meta(UiSounds.WIRED_META) and button.pressed.get_connections().size() == 1
	UiSounds.attach(box)
	_check("Menu buttons get hover and click sounds (once, even if attached twice); they are off without a window",
			wired and button.pressed.get_connections().size() == 1 and not UiSounds.enabled,
			"wired %s, click connections %d, enabled %s" % [wired, button.pressed.get_connections().size(), UiSounds.enabled])
	box.queue_free()


# --- Helpers ---


## Fires one shot from the player at [param point] (standing still after a
## pause, so the first-shot accuracy lands it where aimed) and returns [the
## impact's stream (null if none), its volume in dB, its unit size].
func _shoot_at(point: Vector3) -> Array:
	_player.weapon.refill()
	await _wait_ticks(64)
	_player.aim_at(point)
	var before: int = _player.weapon.get("_impacts").size()
	Input.action_press("shoot")
	await _wait_ticks(2)
	Input.action_release("shoot")
	await _wait_ticks(20)
	var impacts: Array = _player.weapon.get("_impacts")
	if impacts.size() == before:
		return [null, 0.0, 0.0]
	var audio := (impacts.back() as Node).get_node("Audio") as AudioStreamPlayer3D
	var result := [audio.stream, audio.volume_db, audio.unit_size]
	audio.stop()
	return result


## The middle of the top face of the first brush of the map whose top face has
## [param texture], read from the map's texture data, a little above it.
func _top_of_brush_with(texture: StringName) -> Vector3:
	var body := _map.find_children("*", "StaticBody3D", true, false).filter(func(node: Node) -> bool: return node.has_meta(Surfaces.META_KEY))[0] as StaticBody3D
	var data: Dictionary = body.get_meta(Surfaces.META_KEY)
	var faces_of: Dictionary = data["collision_shape_to_face_indices_map"]
	var normals: PackedVector3Array = data["normals"]
	var textures: PackedInt32Array = data["textures"]
	var names: Array = data["texture_names"]
	for shape_name in faces_of:
		for face in faces_of[shape_name] as PackedInt32Array:
			if normals[face].y > 0.9 and StringName(names[textures[face]]) == texture:
				var shape := body.get_node(NodePath(shape_name)) as CollisionShape3D
				var points := (shape.shape as ConvexPolygonShape3D).points
				var top := -INF
				var centre := Vector3.ZERO
				for point in points:
					top = maxf(top, point.y)
					centre += point
				centre /= points.size()
				return shape.global_transform * Vector3(centre.x, top, centre.z) + Vector3.UP * 0.05
	return Vector3.INF


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
