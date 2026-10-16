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
## the bomb's beep only half and never heavy, and a real shot behind a wall played muffled. The
## listener's zone (D-193): a room, a hall, a walled yard and the open, built by the test, and
## Depot's own rooms and yards; the Effects reverb set to the zone at once, gliding to the next
## and put back when the game ends. The mix (D-194): every sound the game plays at its
## category's loudness, no gain above 0 dB, and the readability rules (your shot against near and
## far ones, steps in a fight, the bomb's beep, nothing louder farther away). The music (D-195):
## the menu track loops and sits under the menus, six distinct stingers at their loudness, the
## right one for each round end, the Music volume reaching its bus, no music without a window.
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
	_test_mix()
	_test_music()
	_test_floors()
	_test_footsteps()
	await _test_impacts()
	await _test_occlusion()
	await _test_zones()
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


## The mix (M13, D-194). Every sound file the game plays, found from the game's own data (the
## arsenal, the floors, the impacts, grenades, the bomb, the menus), is within 1.5 dB of its
## category's loudness, peaks below -0.5 dBFS, has no DC and ends quietly; no category plays
## louder than its file; and the readability rules hold by [method SoundMix.level_at].
func _test_mix() -> void:
	var files := {}
	for data in WeaponData.all():
		var shot := SoundMix.MELEE if data.is_melee() else (SoundMix.HANDLING if data.is_grenade() else SoundMix.SHOT)
		_add_file(files, data.shot_sound, shot)
		_add_file(files, data.shot_far_sound, SoundMix.SHOT_FAR)
		for sound in [data.dry_fire_sound, data.reload_sound, data.cycle_sound, data.pin_sound, data.hit_sound]:
			_add_file(files, sound, SoundMix.HANDLING)
		for sound in data.reload_sounds:
			_add_file(files, sound, SoundMix.HANDLING)
	for kind in Surfaces.Kind.values():
		_add_file(files, Surfaces.footstep_sound(kind, preload("res://assets/sounds/footsteps.tres")), SoundMix.FOOTSTEP)
		_add_file(files, Surfaces.impact_sound(kind), SoundMix.IMPACT)
	_add_file(files, Weapon.HIT_BODY_SOUND, SoundMix.HIT)
	_add_file(files, Weapon.HIT_HEAD_SOUND, SoundMix.HEADSHOT)
	_add_file(files, Grenade.BOUNCE_SOUND, SoundMix.BOUNCE)
	_add_file(files, Explosion.FRAG_SOUND, SoundMix.EXPLOSION)
	_add_file(files, Explosion.FRAG_FAR_SOUND, SoundMix.EXPLOSION_FAR)
	_add_file(files, Explosion.FLASH_SOUND, SoundMix.FLASH)
	_add_file(files, Explosion.SMOKE_SOUND, SoundMix.SMOKE)
	var bomb := Bomb.new()
	_add_file(files, bomb.beep_sound, SoundMix.BOMB_BEEP)
	_add_file(files, bomb.plant_sound, SoundMix.BOMB_ACTION)
	_add_file(files, bomb.defuse_sound, SoundMix.BOMB_ACTION)
	_add_file(files, bomb.explosion_sound, SoundMix.BOMB_EXPLOSION)
	_add_file(files, bomb.explosion_far_sound, SoundMix.EXPLOSION_FAR)
	bomb.free()
	for sound in [UiSounds.HOVER, UiSounds.CLICK, UiSounds.BOMB_PLANTED, BuyMenu.BUY_SOUND, BuyMenu.DENIED_SOUND]:
		_add_file(files, sound, &"interface")
	var off: Array[String] = []
	var steps := PackedFloat32Array()
	for path: String in files:
		var category: StringName = files[path]
		var target: float = SoundMix.INTERFACE_FILE_DB if category == &"interface" else SoundMix.TABLE[category].file_db
		var levels := SoundLevels.measure(path)
		if levels.is_empty() or absf(levels.short_term_db - target) > 1.5 or levels.peak_db > -0.5 or absf(levels.dc) > 0.005 or levels.end_db > -30.0:
			off.append("%s (%s): %s" % [path.get_file(), category, "unreadable" if levels.is_empty() else "%.1f dB (target %.0f), peak %.1f, dc %.3f, end %.0f" % [
				levels.short_term_db, target, levels.peak_db, levels.dc, levels.end_db]])
		elif category == SoundMix.FOOTSTEP:
			steps.append(levels.short_term_db)
	_check("Every sound the game plays (%d files) is at its category's loudness (±1.5 dB), peaks below -0.5 dBFS, no DC, ends quietly" % files.size(),
			off.is_empty() and files.size() >= 60, "%d off: %s" % [off.size(), "; ".join(off.slice(0, 12))])
	steps.sort()
	_check("Footsteps are equally loud on every floor (within 1.5 dB of each other)",
			steps.size() >= 12 and steps[steps.size() - 1] - steps[0] <= 1.5, "%d steps, %s" % [steps.size(), steps])
	# No gain above 0 dB, and no boost up close: a single sound never plays louder than its file.
	var loud: Array[String] = []
	for category: StringName in SoundMix.TABLE:
		var values: Dictionary = SoundMix.TABLE[category]
		if values.volume_db > 0.0 or values.get("own_db", 0.0) > 0.0:
			loud.append(String(category))
	for data in WeaponData.all():
		if SoundMix.TABLE[SoundMix.SHOT].volume_db + data.shot_volume_db > 0.0 or SoundMix.TABLE[SoundMix.SHOT].own_db + data.shot_volume_db > 0.0:
			loud.append(String(data.id))
	var probe := AudioStreamPlayer3D.new()
	SoundMix.apply_3d(probe, SoundMix.SHOT)
	_check("No category or gun plays above 0 dB and 3D sounds get no boost up close, so nothing alone can clip",
			loud.is_empty() and probe.max_db == 0.0, "%s, max_db %.1f" % [loud, probe.max_db])
	probe.free()
	# Readability, by the model of Godot's falloff.
	var own_shot := SoundMix.own_level(SoundMix.SHOT)
	var near_shot := SoundMix.shot_level_at(10.0)
	var far_shot := SoundMix.shot_level_at(40.0)
	_check("Your own rifle shot is within 3 dB of an enemy's at 10 m, and at least 10 dB louder than one at 40 m",
			absf(own_shot - near_shot) <= 3.0 and own_shot - far_shot >= 10.0,
			"own %.1f, 10 m %.1f, 40 m %.1f dB" % [own_shot, near_shot, far_shot])
	var step_8 := SoundMix.level_at(SoundMix.FOOTSTEP, 8.0)
	var own_step := SoundMix.own_level(SoundMix.FOOTSTEP)
	_check("In a fight an enemy's step 8 m away is at most 10 dB below your own shot; your own steps are quieter than an enemy's at 5 m",
			own_shot - step_8 <= 10.0 and own_step < SoundMix.level_at(SoundMix.FOOTSTEP, 5.0),
			"step at 8 m %.1f, own step %.1f, step at 5 m %.1f dB" % [step_8, own_step, SoundMix.level_at(SoundMix.FOOTSTEP, 5.0)])
	var beep_15 := SoundMix.level_at(SoundMix.BOMB_BEEP, 15.0)
	_check("The bomb's beep is 6 dB above a step at 15 m and still audible at 50 m",
			beep_15 - SoundMix.level_at(SoundMix.FOOTSTEP, 15.0) >= 6.0 and SoundMix.level_at(SoundMix.BOMB_BEEP, 50.0) > -50.0,
			"beep %.1f at 15 m, %.1f at 50 m; step at 15 m %.1f dB" % [beep_15, SoundMix.level_at(SoundMix.BOMB_BEEP, 50.0), SoundMix.level_at(SoundMix.FOOTSTEP, 15.0)])
	var rising: Array[String] = []
	for category: StringName in SoundMix.TABLE:
		var last := INF
		for metres in range(1, int(SoundMix.TABLE[category].max_distance)):
			var level := SoundMix.shot_level_at(metres) if category == SoundMix.SHOT else SoundMix.level_at(category, metres)
			if level > last + 0.25:
				rising.append("%s at %d m" % [category, metres])
				break
			last = level
	_check("Nothing gets louder farther away (every category, and a shot with its far crossfade)", rising.is_empty(), str(rising))


## The music (M13, D-195): the menu track (30 to 45 s, looping, at the music's loudness), six
## different stingers (at most 3.5 s, at their loudness), which one a round end picks,
## the Music volume setting moving the Music bus, and nothing playing without a window.
func _test_music() -> void:
	var theme := SoundLevels.measure(Music.MENU_THEME.resource_path)
	var looping := (Music.MENU_THEME as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check("The menu track loops, lasts 30 to 45 s and sits at the music's loudness (±2 dB), peaking below -0.5 dBFS",
			looping and not theme.is_empty() and theme.seconds >= 30.0 and theme.seconds <= 45.0
			and absf(theme.short_term_db - SoundMix.MUSIC_FILE_DB) <= 2.0 and theme.peak_db <= -0.5,
			"loop %s, %.1f s, %.1f dB, peak %.1f" % [looping, theme.get("seconds", 0.0), theme.get("short_term_db", 0.0), theme.get("peak_db", 0.0)])
	var stingers := [Music.ROUND_START, Music.ROUND_WON, Music.ROUND_LOST, Music.BOMB_DEFUSED, Music.MATCH_WON, Music.MATCH_LOST]
	var off: Array[String] = []
	for stinger: AudioStream in stingers:
		var measured := SoundLevels.measure(stinger.resource_path)
		if measured.is_empty() or measured.seconds > 3.5 or absf(measured.short_term_db - SoundMix.STINGER_FILE_DB) > 1.5 \
				or measured.peak_db > -0.5 or measured.end_db > -30.0:
			off.append(stinger.resource_path.get_file())
	# Same instruments, different melodies: the bands can't tell them apart, so compare the files.
	var sums := {}
	for stinger: AudioStream in stingers:
		sums[FileAccess.get_md5(stinger.resource_path)] = true
	_check("Six different stingers, each at most 3.5 s at the stingers' loudness (±1.5 dB), ending quietly",
			off.is_empty() and sums.size() == stingers.size(), "%s, %d different" % [off, sums.size()])
	var picks := [Music.stinger_for_round(true, RoundManager.EndReason.ELIMINATION), Music.stinger_for_round(false, RoundManager.EndReason.TIME),
			Music.stinger_for_round(true, RoundManager.EndReason.BOMB_DEFUSED), Music.stinger_for_round(false, RoundManager.EndReason.BOMB_DEFUSED),
			Music.stinger_for_round(false, RoundManager.EndReason.BOMB_EXPLODED), Music.stinger_for_match(true), Music.stinger_for_match(false)]
	_check("Round ends pick their stinger: won, lost, a defused bomb for both teams, an explosion by who won; the match's end by result",
			picks == [Music.ROUND_WON, Music.ROUND_LOST, Music.BOMB_DEFUSED, Music.BOMB_DEFUSED, Music.ROUND_LOST, Music.MATCH_WON, Music.MATCH_LOST],
			str(picks.map(func(stream: AudioStream) -> String: return stream.resource_path.get_file())))
	# The shared settings reach the bus (this test never loads or saves the settings file).
	var settings := Settings.get_instance()
	var music_bus := AudioServer.get_bus_index(SoundMix.BUS_MUSIC)
	settings.music_volume = 0.5
	var half := AudioServer.get_bus_volume_db(music_bus)
	settings.music_volume = settings.get_default(&"music_volume")
	Music.play_menu()
	Music.play_stinger(Music.ROUND_WON)
	_check("The Music volume moves the Music bus (0.5 → -6 dB, back to 0 dB); without a window no music plays",
			is_equal_approx(half, linear_to_db(0.5)) and is_zero_approx(AudioServer.get_bus_volume_db(music_bus)) and not Music.enabled
			and not Music.is_playing_menu() and get_tree().root.get_node_or_null("MusicTrack") == null,
			"half %.1f dB, now %.1f dB, enabled %s" % [half, AudioServer.get_bus_volume_db(music_bus), Music.enabled])


## Adds every file of [param stream] (each one of a randomizer) to [param files] as [param category].
func _add_file(files: Dictionary, stream: AudioStream, category: StringName) -> void:
	if stream is AudioStreamRandomizer:
		var randomizer := stream as AudioStreamRandomizer
		for index in randomizer.streams_count:
			_add_file(files, randomizer.get_stream(index), category)
	elif stream != null and stream.resource_path.ends_with(".wav"):
		files[stream.resource_path] = category


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


## The listener's zone (M13, D-193): rooms the test builds high above the map (a 4 × 3 × 4 m room,
## a 20 × 8 × 20 m hall, a 16 m yard walled 3 m high, nothing at all), Depot's markers (rooms and
## yards both found), and an [Acoustics] node setting the Effects reverb from them.
func _test_zones() -> void:
	var space := _map.get_world_3d().direct_space_state
	var built: Array[Node] = []
	built.append_array(_add_room(Vector3(40.0, 300.0, 0.0), Vector3(4.0, 3.0, 4.0), true))
	built.append_array(_add_room(Vector3(100.0, 300.0, 0.0), Vector3(20.0, 8.0, 20.0), true))
	built.append_array(_add_room(Vector3(200.0, 300.0, 0.0), Vector3(16.0, 3.0, 16.0), false))
	await _wait_ticks(2)
	var ear := Vector3.UP * 1.6
	var zones := []
	for center in [Vector3(40.0, 300.0, 0.0), Vector3(100.0, 300.0, 0.0), Vector3(200.0, 300.0, 0.0), Vector3(400.0, 300.0, 0.0)]:
		zones.append(SoundMix.Zone.keys()[Acoustics.probe(space, center + ear).zone])
	_check("Zones from rays: a small room, a hall, a walled yard and the open", zones == ["ROOM", "HALL", "YARD", "OPEN"], str(zones))
	var counts := {}
	for marker in _map.find_children("*", "Marker3D", true, false):
		var zone: String = SoundMix.Zone.keys()[Acoustics.probe(space, (marker as Node3D).global_position + ear).zone]
		counts[zone] = counts.get(zone, 0) + 1
	_check("Depot's rooms and yards are found at run time (its markers: at least 3 indoors, 30 outdoors)",
			counts.get("ROOM", 0) + counts.get("HALL", 0) >= 3 and counts.get("YARD", 0) + counts.get("OPEN", 0) >= 30, str(counts))
	# The node: in the room the reverb is the room's at once, in the yard it glides to the yard's.
	var effects := AudioServer.get_bus_index(SoundMix.BUS_EFFECTS)
	var reverb := AudioServer.get_bus_effect(effects, 0) as AudioEffectReverb
	var dry_wet := reverb.wet
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(40.0, 300.0, 0.0) + ear
	camera.make_current()
	var acoustics := Acoustics.new()
	add_child(acoustics)
	await _wait_ticks(3)
	var room_zone := acoustics.zone
	var room_wet := reverb.wet
	camera.global_position = Vector3(200.0, 300.0, 0.0) + ear
	await _wait_ticks(64)
	var gliding := reverb.wet
	await _wait_ticks(320)
	var yard_zone := acoustics.zone
	var yard_wet := reverb.wet
	var room_size := reverb.room_size
	acoustics.queue_free()
	await _wait_ticks(1)
	var wet_after := reverb.wet
	var room: Dictionary = SoundMix.REVERB[SoundMix.Zone.ROOM]
	var yard: Dictionary = SoundMix.REVERB[SoundMix.Zone.YARD]
	_check("The reverb follows the listener: the room's at once, gliding to the yard's, dry again when the game ends",
			room_zone == SoundMix.Zone.ROOM and is_equal_approx(room_wet, room.wet) and yard_zone == SoundMix.Zone.YARD
			and gliding < room_wet and gliding > yard_wet and absf(yard_wet - yard.wet) < 0.005 and absf(room_size - yard.room_size) < 0.01
			and is_equal_approx(wet_after, dry_wet),
			"room %s wet %.3f, 0.5 s later %.3f, yard %s wet %.3f size %.2f, after %.3f (layout %.3f)" % [
				SoundMix.Zone.keys()[room_zone], room_wet, gliding, SoundMix.Zone.keys()[yard_zone], yard_wet, room_size, wet_after, dry_wet])
	camera.queue_free()
	for node in built:
		node.queue_free()
	(_player.get_node("Head/Camera3D") as Camera3D).make_current()
	await _wait_ticks(2)


## A box room of 0.3 m walls around [param center] (its floor's middle), [param inside] its
## inner size, with a roof when [param roofed] and no floor (the probe looks up and sideways).
func _add_room(center: Vector3, inside: Vector3, roofed: bool) -> Array[Node]:
	var walls: Array[Node] = []
	var half := inside / 2.0
	var middle := center + Vector3.UP * half.y
	walls.append(_add_wall(middle + Vector3(half.x + 0.15, 0.0, 0.0), Vector3(0.3, inside.y, inside.z + 0.6), false))
	walls.append(_add_wall(middle - Vector3(half.x + 0.15, 0.0, 0.0), Vector3(0.3, inside.y, inside.z + 0.6), false))
	walls.append(_add_wall(middle + Vector3(0.0, 0.0, half.z + 0.15), Vector3(inside.x + 0.6, inside.y, 0.3), false))
	walls.append(_add_wall(middle - Vector3(0.0, 0.0, half.z + 0.15), Vector3(inside.x + 0.6, inside.y, 0.3), false))
	if roofed:
		walls.append(_add_wall(center + Vector3.UP * (inside.y + 0.15), Vector3(inside.x + 0.6, 0.3, inside.z + 0.6), false))
	return walls


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
