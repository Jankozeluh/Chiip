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
## are off without a window.
##
## M13 (D-190 to D-199): the bus layout (a limiter last on Master, the muffled buses feeding the
## reverb on Effects) and the mix table, and that guns, steps and impacts play by the table, your
## own without position and everyone else's from where they are.
## Quits with the number of failed checks as the exit code.

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
	_test_buses()
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
	_test_routing(bot)
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


## Your own gun plays without position at the table's own level; a bot's from where it is, with
## the table's level, range and panning (M13, D-190).
func _test_routing(bot: Character) -> void:
	var own := _player.weapon.get_node("ShotAudio") as AudioStreamPlayer
	_player.weapon.call("_play", _player.weapon.data.shot_sound, false)
	var own_shot: bool = own.volume_db == SoundMix.TABLE[SoundMix.SHOT].own_db and own.bus == SoundMix.BUS_EFFECTS
	bot.weapon.call("_play", bot.weapon.data.shot_sound, false)
	bot.weapon.call("_play", bot.weapon.data.reload_sound, true)
	var shot := bot.weapon.get_node("ShotAudio3D") as AudioStreamPlayer3D
	var handling := bot.weapon.get_node("HandlingAudio3D") as AudioStreamPlayer3D
	var values: Dictionary = SoundMix.TABLE[SoundMix.SHOT]
	var bot_shot: bool = shot.stream == bot.weapon.data.shot_sound and shot.volume_db == values.volume_db and shot.unit_size == values.unit_size \
			and shot.max_distance == values.max_distance and is_equal_approx(shot.panning_strength, SoundMix.PANNING_STRENGTH)
	var bot_handling: bool = handling.stream == bot.weapon.data.reload_sound and handling.unit_size == SoundMix.TABLE[SoundMix.HANDLING].unit_size
	_check("Guns play by the mix table: yours without position, a bot's shot and reload from where it is",
			own_shot and bot_shot and bot_handling, "own %.1f dB on %s; bot shot %.1f dB, %.0f m unit, %.0f m max, pan %.1f; reload unit %.0f m" % [
				own.volume_db, own.bus, shot.volume_db, shot.unit_size, shot.max_distance, shot.panning_strength, handling.unit_size])
	own.stop()
	shot.stop()
	handling.stop()


## The bus layout (M13, D-190): a limiter last on Master so the mix can't clip, the reverb on
## Effects, the two muffled buses low-passing into Effects (the heavy one lower), Interface and
## Music straight to Master; and every category of the mix table complete.
func _test_buses() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	var last := AudioServer.get_bus_effect_count(master) - 1
	var limiter := AudioServer.get_bus_effect(master, last) as AudioEffectHardLimiter if last >= 0 else null
	_check("A hard limiter is the last effect on Master, below full scale, so the mix never clips",
			limiter != null and limiter.ceiling_db < 0.0 and AudioServer.is_bus_effect_enabled(master, last),
			"ceiling %s dB" % (str(limiter.ceiling_db) if limiter != null else "none"))
	var sends := {}
	for bus in AudioServer.bus_count:
		sends[AudioServer.get_bus_name(bus)] = AudioServer.get_bus_send(bus)
	var muffled := _low_pass_of(SoundMix.BUS_MUFFLED)
	var heavy := _low_pass_of(SoundMix.BUS_MUFFLED_HEAVY)
	var effects := AudioServer.get_bus_index(SoundMix.BUS_EFFECTS)
	var reverb := AudioServer.get_bus_effect(effects, 0) is AudioEffectReverb if AudioServer.get_bus_effect_count(effects) > 0 else false
	_check("The buses: reverb on Effects, Muffled and MuffledHeavy low-pass into Effects (heavy lower), Interface and Music to Master",
			reverb and sends.get(&"Effects") == &"Master" and sends.get(&"Muffled") == &"Effects" and sends.get(&"MuffledHeavy") == &"Effects"
			and sends.get(&"Interface") == &"Master" and sends.get(&"Music") == &"Master" and muffled > heavy and heavy > 0.0,
			"%s, low-pass %.0f / %.0f Hz, reverb %s" % [sends, muffled, heavy, reverb])
	var broken: Array[String] = []
	for category: StringName in SoundMix.TABLE:
		var values: Dictionary = SoundMix.TABLE[category]
		if not (values.has("volume_db") and values.get("unit_size", 0.0) > 0.0 and values.get("max_distance", 0.0) > values.unit_size
				and values.get("occlusion", -1.0) >= 0.0 and values.occlusion <= 1.0):
			broken.append(String(category))
	_check("Every category of the mix table has a volume, a range beyond its unit size and an occlusion share", broken.is_empty(), str(broken))


## The cutoff of the low-pass filter on the bus named [param bus_name] (0 if none).
func _low_pass_of(bus_name: StringName) -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return 0.0
	for index in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, index) as AudioEffectLowPassFilter
		if effect != null:
			return effect.cutoff_hz
	return 0.0


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
