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
## own without position and everyone else's from where they are. Every gun's own shot (any two
## differ), its far variant (duller, longer) and its three reload sounds, and a bot's shot
## crossfading into the far one with distance. Muffling (D-192) behind walls built by the test,
## a box and a trimesh: none in the open, light round a corner, more for one wall, heavy for two,
## the bomb's beep only half and never heavy, and a real shot behind a wall played muffled.
## Quits with the number of failed checks as the exit code.

const MAP_SCENE := preload("res://maps/depot.tscn")
## The guns, one per family (M13, D-191).
const GUNS: Array[StringName] = [&"pistol", &"hand_cannon", &"smg", &"carbine", &"rifle", &"shotgun", &"sniper"]
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
	_test_signatures()
	_test_floors()
	_test_footsteps()
	await _test_impacts()
	await _test_occlusion()
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
	# 50 m away the close shot is turned down and the far one plays (only the node moves: the
	# sound starts at once, before physics would notice).
	var far := bot.weapon.get_node("ShotFarAudio3D") as AudioStreamPlayer3D
	var near_far_stream := far.stream
	var home := bot.global_position
	var camera := Acoustics.get_listener(bot)
	bot.global_position = camera.global_position + Vector3(0.0, 50.0, 0.0) if camera != null else home
	bot.weapon.call("_play", bot.weapon.data.shot_sound, false)
	var far_volume := far.volume_db
	var close_volume := shot.volume_db
	bot.global_position = home
	_check("Far away a bot's shot crossfades into the gun's far variant: none at 6 m, all of it at 50 m, the close one turned down",
			camera != null and near_far_stream == null and far.stream == bot.weapon.data.shot_far_sound
			and is_equal_approx(far_volume, SoundMix.TABLE[SoundMix.SHOT_FAR].volume_db)
			and is_equal_approx(close_volume, values.volume_db + SoundMix.CLOSE_AT_FAR_DB),
			"listener %s, far stream at 6 m %s, at 50 m %s at %.1f dB, close %.1f dB" % [camera != null, near_far_stream,
				far.stream.resource_path.get_file() if far.stream != null else "none", far_volume, close_volume])
	far.stop()
	_check("Guns play by the mix table: yours without position, a bot's shot and reload from where it is",
			own_shot and bot_shot and bot_handling, "own %.1f dB on %s; bot shot %.1f dB, %.0f m unit, %.0f m max, pan %.1f; reload unit %.0f m" % [
				own.volume_db, own.bus, shot.volume_db, shot.unit_size, shot.max_distance, shot.panning_strength, handling.unit_size])
	own.stop()
	shot.stop()
	handling.stop()


## Every gun family sounds like itself (M13, D-191), measured from the files: any two close
## shots differ in where their energy sits (bands) or in length; each far variant is duller (70%
## below 1 kHz, at most 8% above 4 kHz) and at least 1.5 times as long; every magazine gun has
## three reload sounds of its own (out, in, charge), none longer than 0.35 s.
func _test_signatures() -> void:
	var close := {}
	var dull: Array[String] = []
	var reloads: Array[String] = []
	var used := {}
	for id in GUNS:
		var data := WeaponData.find(id)
		close[id] = SoundLevels.measure(data.shot_sound.resource_path)
		var far := SoundLevels.measure(data.shot_far_sound.resource_path) if data.shot_far_sound != null else {}
		if far.is_empty() or far.bands[0] + far.bands[1] < 0.7 or far.bands[3] > 0.08 \
				or far.audible_seconds < 1.5 * close[id].audible_seconds:
			dull.append(String(id))
		if data.reload_per_shell:
			continue
		if data.reload_sounds.size() != GunModel.MAGAZINE_SOUNDS.size():
			reloads.append("%s has %d" % [id, data.reload_sounds.size()])
		for sound in data.reload_sounds:
			var levels := SoundLevels.measure(sound.resource_path) if sound != null else {}
			if levels.is_empty() or levels.seconds > 0.35 or used.has(sound.resource_path):
				reloads.append("%s: %s" % [id, sound.resource_path.get_file() if sound != null else "none"])
			elif sound != null:
				used[sound.resource_path] = true
	var alike: Array[String] = []
	for i in GUNS.size():
		for j in range(i + 1, GUNS.size()):
			var a: Dictionary = close[GUNS[i]]
			var b: Dictionary = close[GUNS[j]]
			var distance := 0.0
			for k in 4:
				distance += absf(a.bands[k] - b.bands[k])
			var ratio := maxf(a.audible_seconds, b.audible_seconds) / maxf(minf(a.audible_seconds, b.audible_seconds), 0.001)
			if distance < 0.25 and ratio < 1.5:
				alike.append("%s/%s (bands %.2f apart, %.1f× as long)" % [GUNS[i], GUNS[j], distance, ratio])
	_check("Every gun's shot is its own: any two differ by a quarter of their energy across the bands, or one is 1.5× as long",
			alike.is_empty(), str(alike))
	_check("Every gun has a far variant: 70% below 1 kHz, at most 8% above 4 kHz, at least 1.5× as long as the close shot",
			dull.is_empty(), str(dull))
	_check("Every magazine gun has its own three reload sounds (out, in, charge), none longer than 0.35 s, none shared",
			reloads.is_empty(), str(reloads))


## Muffling through walls (M13, D-192), on walls the test builds high above the map: a 10 m
## listener-to-sound line in the open, round a 1 m wide pillar, through one 0.3 m box wall and
## through that and a 2 m trimesh wall; then the bomb's beep and a real 3D player behind them.
func _test_occlusion() -> void:
	var space := _map.get_world_3d().direct_space_state
	var source := Vector3(0.0, 300.0, 0.0)
	var listener := Vector3(0.0, 300.3, 10.0)
	var open := Acoustics.occlusion(space, source, listener)
	var pillar := _add_wall(Vector3(0.0, 300.0, 5.0), Vector3(1.0, 8.0, 0.3), false)
	await _wait_ticks(2)
	var around := Acoustics.occlusion(space, source, listener)
	pillar.queue_free()
	var first := _add_wall(Vector3(0.0, 300.0, 4.0), Vector3(12.0, 8.0, 0.3), false)
	await _wait_ticks(2)
	var one := Acoustics.occlusion(space, source, listener)
	var second := _add_wall(Vector3(0.0, 300.0, 7.0), Vector3(12.0, 8.0, 2.0), true)
	await _wait_ticks(2)
	var two := Acoustics.occlusion(space, source, listener)
	_check("Muffling: none in the open, light round a corner, then more for one wall and heavy for two (a box and a trimesh)",
			open.loss_db == 0.0 and open.bus == SoundMix.BUS_EFFECTS
			and around.around and around.bus == SoundMix.BUS_MUFFLED_LIGHT
			and one.walls == 1 and absf(one.thickness - 0.3) < 0.05 and one.bus == SoundMix.BUS_MUFFLED
			and two.walls == 2 and absf(two.thickness - 2.3) < 0.05 and two.bus == SoundMix.BUS_MUFFLED_HEAVY
			and 0.0 < around.loss_db and around.loss_db < one.loss_db and one.loss_db < two.loss_db,
			"open %s, corner %s, one wall %s, two walls %s" % [_describe(open), _describe(around), _describe(one), _describe(two)])
	# Real players: a camera listens from the listener's place, the sounds play from the source.
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = listener
	camera.make_current()
	var beep := AudioStreamPlayer3D.new()
	var shot := AudioStreamPlayer3D.new()
	var step := AudioStreamPlayer3D.new()
	for player in [beep, shot, step]:
		add_child(player)
		player.global_position = source
	Acoustics.play(beep, preload("res://assets/sounds/bomb_beep.wav"), SoundMix.BOMB_BEEP)
	Acoustics.play(shot, preload("res://assets/sounds/rifle_shot.wav"), SoundMix.SHOT)
	Acoustics.play(step, preload("res://assets/sounds/footstep_1.wav"), SoundMix.FOOTSTEP)
	var beep_db := beep.volume_db
	var shot_db := shot.volume_db
	var step_db := step.volume_db
	_check("Behind two walls (11.5 dB) a step loses it all, filtered hard; a shot three quarters and the bomb's beep half, both filtered less",
			is_equal_approx(beep_db, SoundMix.TABLE[SoundMix.BOMB_BEEP].volume_db - two.loss_db * 0.5) and beep.bus == SoundMix.BUS_MUFFLED
			and is_equal_approx(shot_db, SoundMix.TABLE[SoundMix.SHOT].volume_db - two.loss_db * 0.75) and shot.bus == SoundMix.BUS_MUFFLED
			and is_equal_approx(step_db, SoundMix.TABLE[SoundMix.FOOTSTEP].volume_db - two.loss_db) and step.bus == SoundMix.BUS_MUFFLED_HEAVY,
			"beep %.1f dB on %s, shot %.1f dB on %s, step %.1f dB on %s" % [beep_db, beep.bus, shot_db, shot.bus, step_db, step.bus])
	for node: Node in [beep, shot, step, camera, first, second]:
		node.queue_free()
	(_player.get_node("Head/Camera3D") as Camera3D).make_current()
	await _wait_ticks(2)


## A wall of the map's layer at [param center], [param size] big: a box, or a trimesh (as a
## built map's faces) when [param concave].
func _add_wall(center: Vector3, size: Vector3, concave: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	if concave:
		var mesh := BoxMesh.new()
		mesh.size = size
		shape.shape = mesh.create_trimesh_shape()
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center
	return body


## A short line about an [method Acoustics.occlusion] result.
func _describe(heard: Dictionary) -> String:
	return "%d walls, %.2f m, around %s, -%.1f dB on %s" % [heard.walls, heard.thickness, heard.around, heard.loss_db, heard.bus]


## The bus layout (M13, D-190): a limiter last on Master so the mix can't clip, the reverb on
## Effects, the three muffled buses low-passing into Effects (each lower), Interface and
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
	var light := _low_pass_of(SoundMix.BUS_MUFFLED_LIGHT)
	var muffled := _low_pass_of(SoundMix.BUS_MUFFLED)
	var heavy := _low_pass_of(SoundMix.BUS_MUFFLED_HEAVY)
	var effects := AudioServer.get_bus_index(SoundMix.BUS_EFFECTS)
	var reverb := AudioServer.get_bus_effect(effects, 0) is AudioEffectReverb if AudioServer.get_bus_effect_count(effects) > 0 else false
	_check("The buses: reverb on Effects, MuffledLight, Muffled and MuffledHeavy low-pass into Effects (each lower), Interface and Music to Master",
			reverb and sends.get(&"Effects") == &"Master" and sends.get(&"MuffledLight") == &"Effects" and sends.get(&"Muffled") == &"Effects"
			and sends.get(&"MuffledHeavy") == &"Effects" and sends.get(&"Interface") == &"Master" and sends.get(&"Music") == &"Master"
			and light > muffled and muffled > heavy and heavy > 0.0,
			"%s, low-pass %.0f / %.0f / %.0f Hz, reverb %s" % [sends, light, muffled, heavy, reverb])
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
