extends Node
## Automated settings checks (M5 task 9, D-058). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/settings_test.tscn
##
## Checks the [Settings] class on its own (defaults equal the game's behaviour
## before there were settings; values are clamped; a change emits `changed`
## once), that every user of a setting really applies it the moment it changes
## (the player controller's sensitivity, Y inversion and field of view, the
## crosshair, the audio buses and the routing of the game's sounds to them, the
## frame rate limit, the InputMap bindings, main.gd's pixel settings and the
## console commands), and the saving: a file written by one instance loads into
## another with the same values and keys, a hand-edited file is clamped and its
## gaps filled with defaults, an unreadable file leaves the defaults, and
## `reset_to_defaults()` puts everything back.
##
## Tests run on the shared instance's defaults and never read or write the real
## `user://settings.cfg` (the last check makes sure of it): saving is tried on
## separate `Settings.new()` instances with `user://test_settings.cfg`, deleted
## afterwards, and main.tscn is loaded with `load_settings` off. Godot prints
## one "ConfigFile parse error" line for the unreadable-file check, on purpose.
## Window settings (fullscreen, V-Sync) have no effect in a headless run, so only
## their values are checked. Quits with the number of failed checks as the exit
## code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MAIN_SCENE := preload("res://main.tscn")
## The temporary file the saving checks use.
const TEMP_PATH := "user://test_settings.cfg"
## The camera's field of view in player.tscn: CS's 90 across 4:3, as an editor value.
const SCENE_CAMERA_FOV := 73.74
## What the settings must start at: the game's behaviour before settings existed.
const DEFAULTS := {
	&"sensitivity": 1.0, &"invert_y": false, &"fov": 90.0,
	&"fullscreen": false, &"vsync": true, &"fps_cap": 0, &"pixel_height": 480,
	&"palette_effect": true, &"pixelate_hud": false, &"ui_scale": 0, &"compass": true, &"team_colors": "standard",
	&"pad_sensitivity": 1.0, &"pad_deadzone": 0.15, &"pad_curve": 1.5, &"pad_invert_y": false,
	&"master_volume": 1.0, &"effects_volume": 1.0, &"interface_volume": 1.0, &"music_volume": 1.0,
	&"crosshair_color": Color("36d07a"), &"crosshair_length": 7.0, &"crosshair_gap": 4.0,
	&"crosshair_thickness": 2.0, &"crosshair_outline": true, &"crosshair_dot": false, &"crosshair_dynamic": false,
	# The last match setup (D-064): D-041's match.
	&"match_team_size": 3, &"match_enemy_team_size": 3, &"match_difficulty": "normal", &"match_rounds_to_win": 5,
	&"match_friendly_fire": false,
	# M8 (D-087): team respawn's kill limit is D-083's 50. M10 (D-132): Team Deathmatch on the rotation, from Depot.
	&"match_map": "res://maps/depot.tscn", &"match_mode": "respawn", &"match_kill_limit": 50, &"match_rotation": true,
	# M10 (D-135): Team Deathmatch lasts 10 minutes unless chosen otherwise.
	&"match_time_limit": 10,
	# M9 (D-108): online name, the last host joined, Quake's port.
	&"online_name": "Player", &"online_address": "127.0.0.1", &"online_port": 26000,
}

var _failures: int = 0
## The shared instance, the one the game's systems listen to.
var _settings: Settings
## The MD5 of the real settings file when the test started ("" if there was none).
var _real_file_md5: String = ""
## Keys of every `changed` signal of the shared instance since the last _forget_changes().
var _changes: Array[StringName] = []


func _ready() -> void:
	_real_file_md5 = FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
	_remove_temp_file()
	_settings = Settings.get_instance()
	var baseline_connections := _settings.changed.get_connections().size()
	_settings.changed.connect(func(key: StringName) -> void: _changes.append(key))
	_test_defaults()
	_test_audio_layout()
	_test_values()
	_test_player()
	_test_crosshair()
	_test_engine_settings()
	await _test_bindings()
	_test_saving()
	_test_unreadable_values()
	_test_reset()
	await _test_main_and_console()
	_test_nothing_left_connected(baseline_connections + 1)
	_test_real_file_untouched()
	_remove_temp_file()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The class on its own ---


## A fresh instance, the shared one and the project's input map all start at today's behaviour.
func _test_defaults() -> void:
	var fresh := Settings.new()
	var wrong: Array[String] = []
	for key: StringName in DEFAULTS:
		if not _same(fresh.get_value(key), DEFAULTS[key]) or not _same(_settings.get_value(key), DEFAULTS[key]):
			wrong.append("%s = %s (expected %s)" % [key, fresh.get_value(key), DEFAULTS[key]])
	_check("Every setting starts at today's value (CS sensitivity 1, 90° FOV, 480 lines, palette on, green crosshair...)",
			wrong.is_empty() and Settings.SCHEMA.size() == DEFAULTS.size() and not fresh.applies_to_engine and _settings.applies_to_engine,
			"%d settings checked%s" % [DEFAULTS.size(), "" if wrong.is_empty() else ", wrong: " + ", ".join(wrong)])
	_check("get_instance() always returns the same shared instance, new instances are separate",
			Settings.get_instance() == _settings and fresh != _settings and not fresh.save_path,
			"shared %s, fresh %s" % [_settings == Settings.get_instance(), fresh != _settings])
	var by_property := (fresh.sensitivity == 1.0 and fresh.fov == 90.0 and fresh.pixel_height == 480 and fresh.palette_effect
			and not fresh.pixelate_hud and fresh.fps_cap == 0 and fresh.master_volume == 1.0 and fresh.crosshair_length == 7.0)
	_check("The typed properties read the same values as get_value()", by_property,
			"sensitivity %s, fov %s, pixel_height %s" % [fresh.sensitivity, fresh.fov, fresh.pixel_height])
	var expected_keys := _default_bindings()
	var problems: Array[String] = []
	for action: StringName in Settings.BINDABLE_ACTIONS:
		var texts := _binding_texts(_settings, action)
		var live := _bound_events(action)
		var live_texts: Array[String] = []
		for event in live:
			live_texts.append(_event_text(event))
			if event.device != -1:
				problems.append("%s has an event for device %d" % [action, event.device])
		if texts != expected_keys[action] or live_texts != _non_empty(expected_keys[action]):
			problems.append("%s: settings %s, input map %s, expected %s" % [action, texts, live_texts, expected_keys[action]])
	_check("The key bindings start as the project's: WASD, Space and wheel down, Ctrl, Shift, mouse buttons, R, Tab, F3, `",
			problems.is_empty() and expected_keys.size() == Settings.BINDABLE_ACTIONS.size(),
			"%d actions%s" % [Settings.BINDABLE_ACTIONS.size(), "" if problems.is_empty() else ": " + "; ".join(problems)])
	var fov := Settings.vertical_fov(90.0)
	_check("90° across a 4:3 screen is the camera's 73.74° vertical (and back); 110° is wider, 70° narrower",
			absf(fov - SCENE_CAMERA_FOV) < 0.01 and absf(Settings.horizontal_fov(fov) - 90.0) < 0.001
					and Settings.vertical_fov(110.0) > fov and Settings.vertical_fov(70.0) < fov,
			"90 → %.4f°, back → %.4f°, 110 → %.2f°, 70 → %.2f°" % [fov, Settings.horizontal_fov(fov), Settings.vertical_fov(110.0), Settings.vertical_fov(70.0)])


## The bus layout has its seven buses (M13, D-190; `sound_test` checks their effects and the
## muffled buses' sends), sends Effects and Interface to Master and ships with nothing muted.
func _test_audio_layout() -> void:
	var names: Array[String] = []
	var problems: Array[String] = []
	for bus in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(bus))
		if AudioServer.is_bus_mute(bus) or not is_zero_approx(AudioServer.get_bus_volume_db(bus)):
			problems.append("%s: mute %s, %.1f dB" % [AudioServer.get_bus_name(bus), AudioServer.is_bus_mute(bus), AudioServer.get_bus_volume_db(bus)])
	var sends := (AudioServer.get_bus_send(AudioServer.get_bus_index(Settings.BUS_EFFECTS)) == Settings.BUS_MASTER
			and AudioServer.get_bus_send(AudioServer.get_bus_index(Settings.BUS_INTERFACE)) == Settings.BUS_MASTER)
	_check("The audio buses are Master, Effects, MuffledLight, Muffled, MuffledHeavy, Interface and Music, Effects and Interface sending to Master, none muted, all at 0 dB",
			names == ["Master", "Effects", "MuffledLight", "Muffled", "MuffledHeavy", "Interface", "Music"] and sends and problems.is_empty(),
			"buses %s, sends to Master %s%s" % [names, sends, "" if problems.is_empty() else ", problems: " + ", ".join(problems)])


## Clamping, snapping, wrong types, and the `changed` signal.
func _test_values() -> void:
	var fresh := Settings.new()
	var emitted: Array[StringName] = []
	fresh.changed.connect(func(key: StringName) -> void: emitted.append(key))
	fresh.sensitivity = 2.5
	fresh.sensitivity = 2.5
	fresh.invert_y = true
	_check("A change emits `changed` with the setting's name, setting the same value again emits nothing",
			emitted == [&"sensitivity", &"invert_y"] and fresh.sensitivity == 2.5 and fresh.invert_y,
			"emitted %s" % [emitted])
	fresh.sensitivity = 100.0
	var high := fresh.sensitivity
	fresh.sensitivity = -3.0
	var low := fresh.sensitivity
	fresh.fov = 500.0
	var wide := fresh.fov
	fresh.fov = 10.0
	var narrow := fresh.fov
	_check("Numbers outside their range are clamped (sensitivity 0.05 to 10, FOV 70 to 110)",
			high == 10.0 and is_equal_approx(low, 0.05) and wide == 110.0 and narrow == 70.0,
			"sensitivity 100 → %s, -3 → %s; fov 500 → %s, 10 → %s" % [high, low, wide, narrow])
	fresh.pixel_height = 500
	var nearest := fresh.pixel_height
	fresh.pixel_height = 1000
	var biggest := fresh.pixel_height
	fresh.fps_cap = 10
	var slow := fresh.fps_cap
	fresh.fps_cap = -4
	var unlimited := fresh.fps_cap
	fresh.fps_cap = 99999
	var capped := fresh.fps_cap
	_check("The pixel height snaps to the nearest allowed value (500 → 480), the frame rate limit is 0 or 30 to 1000",
			nearest == 480 and biggest == 720 and slow == 30 and unlimited == 0 and capped == 1000,
			"pixel height 500 → %d, 1000 → %d; fps 10 → %d, -4 → %d, 99999 → %d" % [nearest, biggest, slow, unlimited, capped])
	fresh.ui_scale = 60
	var near_fifty := fresh.ui_scale
	fresh.ui_scale = 90
	var near_hundred := fresh.ui_scale
	fresh.ui_scale = 500
	var most := fresh.ui_scale
	fresh.ui_scale = -5
	var least := fresh.ui_scale
	_check("The UI scale snaps to the nearest of Auto (0), 50, 75 and 100 percent (D-181): 60 → 50, 90 → 100, 500 → 100, -5 → Auto",
			near_fifty == 50 and near_hundred == 100 and most == 100 and least == 0, "60 → %d, 90 → %d, 500 → %d, -5 → %d" % [near_fifty, near_hundred, most, least])
	fresh.master_volume = 2.0
	var loud := fresh.master_volume
	fresh.master_volume = -1.0
	var silent := fresh.master_volume
	fresh.crosshair_color = Color(2.0, 0.5, -1.0, 5.0)
	fresh.crosshair_gap = -3.0
	fresh.crosshair_length = 99.0
	_check("Volumes stay between 0 and 1, the crosshair color's channels between 0 and 1, its sizes within their limits",
			loud == 1.0 and silent == 0.0 and fresh.crosshair_color == Color(1.0, 0.5, 0.0, 1.0)
					and fresh.crosshair_gap == 0.0 and fresh.crosshair_length == 30.0,
			"volume 2 → %s, -1 → %s; color %s; gap %s, length %s" % [loud, silent, fresh.crosshair_color, fresh.crosshair_gap, fresh.crosshair_length])
	fresh.set_value(&"sensitivity", "fast")
	fresh.set_value(&"invert_y", 7)
	fresh.set_value(&"fov", NAN)
	fresh.set_value(&"pixel_height", Vector2.ZERO)
	_check("A value of the wrong type (text, a number for a switch, NaN) falls back to the default",
			fresh.sensitivity == 1.0 and not fresh.invert_y and fresh.fov == 90.0 and fresh.pixel_height == 480,
			"sensitivity %s, invert_y %s, fov %s, pixel_height %s" % [fresh.sensitivity, fresh.invert_y, fresh.fov, fresh.pixel_height])
	var range_ok: bool = Settings.get_range(&"sensitivity") == Vector2(0.05, 10.0) and Settings.get_range(&"pixel_height") == Vector2(270, 720) \
			and Settings.get_range(&"vsync") == Vector2.ZERO and Settings.get_default(&"fov") == 90.0 and Settings.has_setting(&"fov") \
			and not Settings.has_setting(&"nonsense")
	_check("get_range(), get_default() and has_setting() describe the settings for a menu", range_ok,
			"sensitivity %s, pixel height %s, vsync %s" % [Settings.get_range(&"sensitivity"), Settings.get_range(&"pixel_height"), Settings.get_range(&"vsync")])


# --- Users of the settings ---


## The player controller: sensitivity, Y inversion and the camera's field of view, live.
func _test_player() -> void:
	var player := _add_player()
	var controller := player.get_node("PlayerController") as PlayerController
	var camera := controller.camera
	_check("On defaults the camera's field of view is 73.74° (CS's 90°) and the sensitivity 1",
			absf(camera.fov - SCENE_CAMERA_FOV) < 0.01 and controller.sensitivity == 1.0 and not controller.invert_y,
			"camera %.3f°, sensitivity %s" % [camera.fov, controller.sensitivity])
	_check("100 mouse counts turn the view 2.200° at sensitivity 1", is_equal_approx(_turn_per_100_counts(controller), 2.2),
			"%.4f°" % _turn_per_100_counts(controller))
	_forget_changes()
	_settings.sensitivity = 2.0
	_check("Changing the sensitivity reaches the controller at once: 100 counts now turn 4.400°",
			controller.sensitivity == 2.0 and is_equal_approx(_turn_per_100_counts(controller), 4.4) and _changes == [&"sensitivity"],
			"%.4f°, signals %s" % [_turn_per_100_counts(controller), _changes])
	_settings.sensitivity = 1.0
	var pitch_before := _pitch_after_100_counts_down(controller)
	_settings.invert_y = true
	var pitch_inverted := _pitch_after_100_counts_down(controller)
	_check("Inverting Y flips the vertical look",
			is_equal_approx(pitch_before, -pitch_inverted) and pitch_inverted > 0.0 and pitch_before < 0.0,
			"mouse down 100 counts: pitch %.3f° normal, %.3f° inverted" % [pitch_before, pitch_inverted])
	_settings.invert_y = false
	_settings.fov = 100.0
	var expected := Settings.vertical_fov(100.0)
	_check("Changing the field of view moves the camera: 100° across 4:3 is %.2f° vertical" % expected,
			is_equal_approx(camera.fov, expected) and camera.fov > SCENE_CAMERA_FOV, "camera %.3f°" % camera.fov)
	_settings.reset_to_defaults()
	_check("Resetting gives the camera its 73.74° and the mouse its sensitivity back",
			absf(camera.fov - SCENE_CAMERA_FOV) < 0.01 and controller.sensitivity == 1.0 and not controller.invert_y,
			"camera %.3f°, sensitivity %s" % [camera.fov, controller.sensitivity])
	# The players' sounds: every audio player of the character and its rifle starts on Effects (walls
	# move a sound to a muffled bus as it plays, M13 D-192; those send into Effects).
	var players: Array[Node] = player.find_children("*", "AudioStreamPlayer", true, false)
	players.append_array(player.find_children("*", "AudioStreamPlayer3D", true, false))
	var off_bus: Array[String] = []
	for audio in players:
		if audio.get("bus") != Settings.BUS_EFFECTS:
			off_bus.append("%s on %s" % [audio.name, audio.get("bus")])
	_check("Every sound player of a character and its rifle (7: footsteps, shots, far shots, handling, 2D and 3D) starts on the Effects bus",
			players.size() == 7 and off_bus.is_empty(), "%d players%s" % [players.size(), "" if off_bus.is_empty() else ", not on Effects: " + ", ".join(off_bus)])
	player.free()


## The crosshair of the real HUD: every style setting, also together with the UI scale.
func _test_crosshair() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	var crosshair := hud.get_node("Crosshair") as Crosshair
	_check("On defaults the crosshair is green, 7 px lines, a 4 px gap, 2 px thick, outlined, no dot, not dynamic",
			crosshair.color == Color("36d07a") and crosshair.length == 7.0 and crosshair.gap == 4.0 and crosshair.thickness == 2.0
					and crosshair.outline and not crosshair.dot and not crosshair.dynamic,
			"color %s, length %s, gap %s, thickness %s, outline %s, dot %s, dynamic %s" % [crosshair.color, crosshair.length, crosshair.gap,
					crosshair.thickness, crosshair.outline, crosshair.dot, crosshair.dynamic])
	_settings.crosshair_color = Color(1.0, 0.2, 0.4, 0.8)
	_settings.crosshair_length = 10.0
	_settings.crosshair_gap = 1.0
	_settings.crosshair_thickness = 3.0
	_settings.crosshair_outline = false
	_settings.crosshair_dot = true
	_settings.crosshair_dynamic = true
	_check("Every crosshair setting reaches the crosshair the moment it changes",
			crosshair.color == Color(1.0, 0.2, 0.4, 0.8) and crosshair.length == 10.0 and crosshair.gap == 1.0 and crosshair.thickness == 3.0
					and not crosshair.outline and crosshair.dot and crosshair.dynamic,
			"color %s, length %s, gap %s, thickness %s, outline %s, dot %s, dynamic %s" % [crosshair.color, crosshair.length, crosshair.gap,
					crosshair.thickness, crosshair.outline, crosshair.dot, crosshair.dynamic])
	crosshair.set_ui_scale(2.0)
	var scaled := crosshair.length == 20.0 and crosshair.gap == 2.0 and crosshair.thickness == 6.0
	_settings.crosshair_length = 5.0
	_settings.crosshair_gap = 0.0
	_check("The settings are sizes at 720p: at UI scale 2 the lines are twice as big, also after a change, and a gap of 0 stays 0",
			scaled and crosshair.length == 10.0 and crosshair.gap == 0.0 and crosshair.thickness == 6.0,
			"scaled %s, then length %s, gap %s, thickness %s" % [scaled, crosshair.length, crosshair.gap, crosshair.thickness])
	_settings.sensitivity = 3.0
	_check("A setting outside the crosshair doesn't disturb it", crosshair.length == 10.0 and crosshair.dot, "length %s" % crosshair.length)
	_settings.reset_to_defaults()
	_check("Resetting restores the default crosshair (scaled 2×: 14 px lines, 8 px gap, 4 px thick)",
			crosshair.color == Color("36d07a") and crosshair.length == 14.0 and crosshair.gap == 8.0 and crosshair.thickness == 4.0
					and crosshair.outline and not crosshair.dot and not crosshair.dynamic,
			"length %s, gap %s, thickness %s" % [crosshair.length, crosshair.gap, crosshair.thickness])
	hud.free()


## Audio buses and the frame rate limit; the window settings only keep their values here.
func _test_engine_settings() -> void:
	var master := AudioServer.get_bus_index(Settings.BUS_MASTER)
	var effects := AudioServer.get_bus_index(Settings.BUS_EFFECTS)
	var interface := AudioServer.get_bus_index(Settings.BUS_INTERFACE)
	var music := AudioServer.get_bus_index(Settings.BUS_MUSIC)
	_settings.master_volume = 0.5
	_settings.effects_volume = 0.25
	_settings.interface_volume = 0.1
	_settings.music_volume = 0.3
	_check("Volumes go to their buses as dB: 0.5 on Master, 0.25 on Effects, 0.1 on Interface, 0.3 on Music, none muted",
			is_equal_approx(AudioServer.get_bus_volume_db(master), linear_to_db(0.5)) and is_equal_approx(AudioServer.get_bus_volume_db(effects), linear_to_db(0.25))
					and is_equal_approx(AudioServer.get_bus_volume_db(interface), linear_to_db(0.1)) and is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.3))
					and not AudioServer.is_bus_mute(master) and not AudioServer.is_bus_mute(effects) and not AudioServer.is_bus_mute(interface) and not AudioServer.is_bus_mute(music),
			"%.2f / %.2f / %.2f / %.2f dB" % [AudioServer.get_bus_volume_db(master), AudioServer.get_bus_volume_db(effects), AudioServer.get_bus_volume_db(interface), AudioServer.get_bus_volume_db(music)])
	_settings.master_volume = 0.0
	var muted := AudioServer.is_bus_mute(master)
	_settings.master_volume = 1.0
	_check("Volume 0 mutes a bus, and raising it again unmutes it at 0 dB",
			muted and not AudioServer.is_bus_mute(master) and is_zero_approx(AudioServer.get_bus_volume_db(master)),
			"muted at 0: %s, then mute %s at %.2f dB" % [muted, AudioServer.is_bus_mute(master), AudioServer.get_bus_volume_db(master)])
	_settings.fps_cap = 144
	var capped := Engine.max_fps
	_settings.fps_cap = 0
	_check("The frame rate limit sets Engine.max_fps (144) and 0 removes it", capped == 144 and Engine.max_fps == 0,
			"limit %d, then %d" % [capped, Engine.max_fps])
	_settings.fullscreen = true
	_settings.vsync = false
	_check("Fullscreen and V-Sync keep their values (the window itself isn't touched in a headless run)",
			_settings.fullscreen and not _settings.vsync, "fullscreen %s, vsync %s" % [_settings.fullscreen, _settings.vsync])
	_settings.reset_to_defaults()


## Rebinding: the InputMap follows, with device -1; a real key press triggers the new binding.
func _test_bindings() -> void:
	_forget_changes()
	var rebound := _settings.set_binding(&"reload", _key(KEY_T))
	var events := _bound_events(&"reload")
	var event := events[0] as InputEventKey if not events.is_empty() else null
	_check("set_binding() puts the new key into the InputMap (physical key T, all devices) and emits `changed`(bindings)",
			rebound and events.size() == 1 and event != null and event.physical_keycode == KEY_T and event.device == -1 and _changes == [&"bindings"],
			"%d event(s), key %s, device %s, signals %s" % [events.size(), event.physical_keycode if event != null else "none", event.device if event != null else "none", _changes])
	_forget_changes()
	_settings.set_binding(&"reload", _key(KEY_T))
	_check("Binding the same key again changes nothing", _changes.is_empty(), "signals %s" % [_changes])
	var states: Array[bool] = []
	for code: Key in [KEY_T, KEY_R]:
		var press := _key(code)
		press.pressed = true
		Input.parse_input_event(press)
		await _wait_ticks(2)
		states.append(Input.is_action_pressed(&"reload"))
		var release := _key(code)
		release.pressed = false
		Input.parse_input_event(release)
		await _wait_ticks(2)
	_check("A real T press triggers reload now, and the old R doesn't", states == [true, false], "T held: %s, R held: %s" % [states[0], states[1]])
	_settings.set_binding(&"jump", _mouse(MOUSE_BUTTON_XBUTTON1), 1)
	var jump_events := _bound_events(&"jump")
	_check("A second slot binds a second key: jump now answers to Space and mouse button 4, not the wheel",
			jump_events.size() == 2 and _event_text(jump_events[0]) == _k(KEY_SPACE) and _event_text(jump_events[1]) == _m(MOUSE_BUTTON_XBUTTON1)
					and _binding_texts(_settings, &"jump") == [_k(KEY_SPACE), _m(MOUSE_BUTTON_XBUTTON1)],
			"input map %s, settings %s" % [_event_texts(jump_events), _binding_texts(_settings, &"jump")])
	_settings.clear_binding(&"crouch")
	_check("clear_binding() leaves an action without keys", _bound_events(&"crouch").is_empty() and _settings.get_binding(&"crouch") == null,
			"%d event(s)" % _bound_events(&"crouch").size())
	var clash := _settings.find_action_using(_key(KEY_W))
	_check("find_action_using() names the action a key is already bound to (W: move_forward), not counting the one asked about",
			clash == &"move_forward" and _settings.find_action_using(_key(KEY_W), &"move_forward") == &"" and _settings.find_action_using(_key(KEY_F12)) == &"",
			"W is bound to '%s'" % clash)
	var refused := not _settings.set_binding(&"reload", InputEventJoypadButton.new()) and not _settings.set_binding(&"pause", _key(KEY_T)) \
			and not _settings.set_binding(&"reload", _key(KEY_T), 2)
	_check("Only keys and mouse buttons can be bound, only to the bindable actions (not Esc), in slots 0 and 1", refused, "refused %s" % refused)
	_check("binding_text() names keys and buttons for a menu",
			Settings.binding_text(_key(KEY_W)) == "W" and Settings.binding_text(_key(KEY_SPACE)) == "Space"
					and Settings.binding_text(_mouse(MOUSE_BUTTON_LEFT)) == "Left Mouse" and Settings.binding_text(_mouse(MOUSE_BUTTON_WHEEL_DOWN)) == "Wheel Down"
					and Settings.binding_text(null) == "",
			"W '%s', Space '%s', left '%s', wheel '%s'" % [Settings.binding_text(_key(KEY_W)), Settings.binding_text(_key(KEY_SPACE)),
					Settings.binding_text(_mouse(MOUSE_BUTTON_LEFT)), Settings.binding_text(_mouse(MOUSE_BUTTON_WHEEL_DOWN))])
	_settings.set_binding(&"reload", _key(KEY_T))
	_settings.reset_binding(&"reload")
	var reload_events := _bound_events(&"reload")
	_check("reset_binding() restores one action (reload is R again, jump stays rebound)",
			reload_events.size() == 1 and _event_text(reload_events[0]) == _k(KEY_R) and _binding_texts(_settings, &"jump")[1] == _m(MOUSE_BUTTON_XBUTTON1),
			"reload %s" % [_event_texts(reload_events)])
	_settings.reset_bindings()
	var back := true
	for action: StringName in Settings.BINDABLE_ACTIONS:
		back = back and _event_texts(_bound_events(action)) == _non_empty(_default_bindings()[action])
	_check("reset_bindings() puts every action back to the project's keys", back, "all %d actions checked" % Settings.BINDABLE_ACTIONS.size())


# --- Saving and loading ---


## One instance writes every kind of setting and key to a file, another loads them back.
func _test_saving() -> void:
	var writer := Settings.new()
	var result := writer.load_from_disk(TEMP_PATH)
	_check("Loading a missing file gives ERR_FILE_NOT_FOUND, leaves the defaults and creates no file until something changes",
			result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(TEMP_PATH) and writer.sensitivity == 1.0 and writer.save_path == TEMP_PATH,
			"result %d, file exists %s" % [result, FileAccess.file_exists(TEMP_PATH)])
	_check("Without a file to save to, save_to_disk() reports it", Settings.new().save_to_disk() == ERR_UNCONFIGURED, "an instance that never loaded")
	_check("is_loaded() is false until load_from_disk() has run (a missing file counts), so the menu and main.gd read the file once between them",
			not Settings.new().is_loaded() and writer.is_loaded() and not _settings.is_loaded(), "fresh %s, writer %s, shared %s" % [Settings.new().is_loaded(), writer.is_loaded(), _settings.is_loaded()])
	writer.sensitivity = 2.31
	var saved := _read_cfg(TEMP_PATH)
	_check("The first change creates the file, with the value in its section",
			FileAccess.file_exists(TEMP_PATH) and saved != null and is_equal_approx(saved.get_value("game", "sensitivity", -1.0), 2.31),
			"file exists %s" % FileAccess.file_exists(TEMP_PATH))
	writer.invert_y = true
	writer.fov = 103.0
	writer.fullscreen = true
	writer.vsync = false
	writer.fps_cap = 144
	writer.pixel_height = 360
	writer.palette_effect = false
	writer.pixelate_hud = true
	writer.ui_scale = 75
	writer.compass = false
	writer.team_colors = "colorblind"
	writer.pad_sensitivity = 1.8
	writer.pad_deadzone = 0.25
	writer.pad_curve = 2.0
	writer.pad_invert_y = true
	writer.master_volume = 0.4
	writer.effects_volume = 0.7
	writer.interface_volume = 0.1
	writer.music_volume = 0.3
	writer.crosshair_color = Color(1.0, 0.5, 0.25, 0.8)
	writer.crosshair_length = 12.0
	writer.crosshair_gap = 2.0
	writer.crosshair_thickness = 3.0
	writer.crosshair_outline = false
	writer.crosshair_dot = true
	writer.crosshair_dynamic = true
	writer.match_team_size = 5
	writer.match_enemy_team_size = 2
	writer.match_difficulty = "hard"
	writer.match_rounds_to_win = 10
	writer.match_friendly_fire = true
	writer.match_map = "res://maps/comparison/csg_room.tscn"
	writer.match_mode = "rounds"
	writer.match_kill_limit = 75
	writer.match_rotation = false
	writer.match_time_limit = 15
	writer.online_name = "Jan"
	writer.online_address = "192.168.1.20"
	writer.online_port = 27015
	writer.set_binding(&"reload", _key(KEY_T))
	writer.set_binding(&"jump", _mouse(MOUSE_BUTTON_XBUTTON1), 1)
	writer.clear_binding(&"crouch")
	writer.set_binding(&"shoot", _key(KEY_F), 1)
	saved = _read_cfg(TEMP_PATH)
	var sections := saved.get_sections() if saved != null else PackedStringArray()
	_check("Every change is saved at once, in the sections game, video, audio, crosshair, match, online, controls and pad (the crosshair's keys without their prefix)",
			sections == PackedStringArray(["game", "video", "audio", "crosshair", "match", "online", "controls", "pad"]) and saved.has_section_key("crosshair", "gap")
					and is_equal_approx(saved.get_value("crosshair", "gap", -1.0), 2.0) and saved.get_value("video", "pixel_height", 0) == 360 and saved.get_value("video", "ui_scale", -1) == 75
					and saved.get_value("controls", "reload") == ["key:%d" % KEY_T, ""],
			"sections %s" % [sections])
	_check("The last match setup is the [match] section: team_size, enemy_team_size, difficulty, rounds_to_win, friendly_fire, map, mode, kill_limit and rotation, without the prefix, and the section's setup_version (D-132)",
			saved.get_value("match", "team_size", 0) == 5 and saved.get_value("match", "enemy_team_size", 0) == 2
					and saved.get_value("match", "difficulty", "") == "hard" and saved.get_value("match", "rounds_to_win", 0) == 10
					and saved.get_value("match", "friendly_fire", false) == true
					and saved.get_value("match", "map", "") == "res://maps/comparison/csg_room.tscn"
					and saved.get_value("match", "mode", "") == "rounds" and saved.get_value("match", "kill_limit", 0) == 75
					and saved.get_value("match", "rotation", true) == false
					and saved.get_value("match", "setup_version", 0) == Settings.MATCH_SETUP_VERSION
					and saved.get_section_keys("match").size() == 11,
			"keys %s" % [saved.get_section_keys("match")])
	_check("Your online name and the last host are the [online] section: name, address and port (M9)",
			saved.get_value("online", "name", "") == "Jan" and saved.get_value("online", "address", "") == "192.168.1.20"
					and saved.get_value("online", "port", 0) == 27015 and saved.get_section_keys("online").size() == 3,
			"keys %s" % [saved.get_section_keys("online")])
	var reader := Settings.new()
	var loaded := reader.load_from_disk(TEMP_PATH)
	var differing: Array[String] = []
	for key: StringName in DEFAULTS:
		if not _same(reader.get_value(key), writer.get_value(key)):
			differing.append("%s: %s vs %s" % [key, reader.get_value(key), writer.get_value(key)])
	_check("A new instance loading the file gets all %d settings back exactly" % DEFAULTS.size(), loaded == OK and differing.is_empty(),
			"result %d%s" % [loaded, "" if differing.is_empty() else ", different: " + "; ".join(differing)])
	var same_keys := true
	for action: StringName in Settings.BINDABLE_ACTIONS:
		same_keys = same_keys and _binding_texts(reader, action) == _binding_texts(writer, action)
	_check("... and the key bindings too (T for reload, mouse 4 as jump's second key, crouch unbound, F as shoot's second key)",
			same_keys and _binding_texts(reader, &"reload") == [_k(KEY_T), ""] and _binding_texts(reader, &"crouch") == ["", ""]
					and _binding_texts(reader, &"jump")[1] == _m(MOUSE_BUTTON_XBUTTON1) and _binding_texts(reader, &"shoot") == [_m(MOUSE_BUTTON_LEFT), _k(KEY_F)],
			"reload %s, crouch %s, jump %s, shoot %s" % [_binding_texts(reader, &"reload"), _binding_texts(reader, &"crouch"),
					_binding_texts(reader, &"jump"), _binding_texts(reader, &"shoot")])
	_check("A separate instance never touches the engine: the Master bus, the frame limit and reload's key are as before",
			is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Settings.BUS_MASTER))) and Engine.max_fps == 0
					and _event_texts(_bound_events(&"reload")) == [_k(KEY_R)],
			"max fps %d" % Engine.max_fps)
	reader.sensitivity = 3.0
	var reloaded := Settings.new()
	reloaded.load_from_disk(TEMP_PATH)
	_check("After loading, further changes are saved to the same file", reloaded.sensitivity == 3.0 and reloaded.fov == 103.0, "sensitivity %s" % reloaded.sensitivity)
	var load_signals := _sorted(_load_signals(TEMP_PATH))
	var expected_signals := _sorted(DEFAULTS.keys() + [&"bindings"])
	_check("Loading emits `changed` once for every value that differs from the defaults (all %d here, and the keys), so listeners already in the scene apply them" % DEFAULTS.size(),
			load_signals == expected_signals, "%d signals" % load_signals.size())
	_remove_temp_file()


## A hand-edited file: out-of-range values clamped, wrong types and gaps defaulted, unknown keys ignored;
## a file that doesn't parse leaves the defaults.
func _test_unreadable_values() -> void:
	_write_text(TEMP_PATH, "\n".join([
		"[game]", "sensitivity = 999", "invert_y = \"yes\"", "fov = \"wide\"", "bogus_key = 5",
		"[video]", "fullscreen = true", "fps_cap = -5", "pixel_height = 500",
		"[audio]", "master_volume = -3", "effects_volume = 0.25",
		"[crosshair]", "color = Color(2, 2, -1, 5)", "length = 0.0", "dot = 1",
		"[controls]", "jump = [\"key:abc\", \"mouse:99\"]", "crouch = [\"\", \"\"]", "shoot = \"left\"", "reload = [\"key:%d\"]" % KEY_T,
		"[unknown_section]", "x = 1", ""]))
	var settings := Settings.new()
	var result := settings.load_from_disk(TEMP_PATH)
	_check("A hand-edited file loads: too big or small numbers clamped, wrong types and missing keys default, unknown ones ignored",
			result == OK and settings.sensitivity == 10.0 and not settings.invert_y and settings.fov == 90.0 and settings.fullscreen and settings.vsync
					and settings.fps_cap == 0 and settings.pixel_height == 480 and settings.master_volume == 0.0 and settings.effects_volume == 0.25
					and settings.interface_volume == 1.0 and settings.crosshair_color == Color(1.0, 1.0, 0.0, 1.0) and settings.crosshair_length == 1.0
					and settings.crosshair_gap == 4.0 and not settings.crosshair_dot,
			"sensitivity %s, fov %s, fps %s, pixel height %s, master %s, color %s, length %s, gap %s, dot %s" % [settings.sensitivity, settings.fov, settings.fps_cap,
					settings.pixel_height, settings.master_volume, settings.crosshair_color, settings.crosshair_length, settings.crosshair_gap, settings.crosshair_dot])
	_check("Hand-edited keys: unreadable ones keep the default, an empty list unbinds, text instead of a list defaults, a short list leaves slot 2 empty, other actions are untouched",
			_binding_texts(settings, &"jump") == [_k(KEY_SPACE), _m(MOUSE_BUTTON_WHEEL_DOWN)] and _binding_texts(settings, &"crouch") == ["", ""]
					and _binding_texts(settings, &"shoot") == [_m(MOUSE_BUTTON_LEFT), ""] and _binding_texts(settings, &"reload") == [_k(KEY_T), ""]
					and _binding_texts(settings, &"move_back") == [_k(KEY_S), ""],
			"jump %s, crouch %s, shoot %s, reload %s" % [_binding_texts(settings, &"jump"), _binding_texts(settings, &"crouch"),
					_binding_texts(settings, &"shoot"), _binding_texts(settings, &"reload")])
	settings.sensitivity = 2.0
	var rewritten := _read_cfg(TEMP_PATH)
	_check("The next change rewrites the file with valid values (no 999 left)",
			rewritten != null and is_equal_approx(rewritten.get_value("game", "sensitivity", 0.0), 2.0) and not rewritten.has_section("unknown_section")
					and rewritten.get_value("audio", "master_volume", -1.0) == 0.0,
			"sensitivity in file %s" % [rewritten.get_value("game", "sensitivity", "none") if rewritten != null else "no file"])
	_write_text(TEMP_PATH, "\n".join([
		"[match]", "team_size = 9", "enemy_team_size = \"many\"", "difficulty = \"impossible\"", "rounds_to_win = 7",
		"friendly_fire = 1", "map = 5", ""]))
	var match_settings := Settings.new()
	match_settings.load_from_disk(TEMP_PATH)
	_check("A hand-edited [match] section is forgiven: a team of 9 is clamped to 5, text for a number, an unknown difficulty, a number for a bool and a number for the map fall back to the defaults, 7 rounds snaps to 5",
			match_settings.match_team_size == 5 and match_settings.match_enemy_team_size == 3 and match_settings.match_difficulty == "normal"
					and match_settings.match_rounds_to_win == 5 and not match_settings.match_friendly_fire
					and match_settings.match_map == Settings.DEFAULT_MATCH_MAP,
			"team %d, enemy %d, difficulty %s, rounds %d, friendly fire %s, map %s" % [match_settings.match_team_size, match_settings.match_enemy_team_size,
					match_settings.match_difficulty, match_settings.match_rounds_to_win, match_settings.match_friendly_fire, match_settings.match_map])
	_write_text(TEMP_PATH, "[match]\nrounds_to_win = 12\ndifficulty = \"hard\"\nteam_size = 0\n")
	match_settings.load_from_disk(TEMP_PATH)
	_check("... a length between the offered ones snaps to the nearest (12 → 10), a valid difficulty is kept, a team of 0 is raised to 1, and a missing key keeps its default",
			match_settings.match_rounds_to_win == 10 and match_settings.match_difficulty == "hard" and match_settings.match_team_size == 1
					and match_settings.match_enemy_team_size == 3,
			"rounds %d, difficulty %s, team %d" % [match_settings.match_rounds_to_win, match_settings.match_difficulty, match_settings.match_team_size])
	# A file from before M10 (no setup_version): its mode, map and rotation were the old menu's defaults.
	_write_text(TEMP_PATH, "[match]\nteam_size = 4\nmode = \"rounds\"\nrotation = false\nmap = \"res://maps/test_map.tscn\"\n")
	var old_file := Settings.new()
	old_file.load_from_disk(TEMP_PATH)
	_write_text(TEMP_PATH, "[match]\nsetup_version = %d\nteam_size = 4\nmode = \"rounds\"\nrotation = false\nmap = \"res://maps/square.tscn\"\n" % Settings.MATCH_SETUP_VERSION)
	var new_file := Settings.new()
	new_file.load_from_disk(TEMP_PATH)
	_check("A match setup saved before M10 (no setup_version) gets today's mode, map and rotation once (Team Deathmatch on the rotation from Depot) and keeps the rest; a current file keeps Bomb on Square (D-132)",
			old_file.match_mode == "respawn" and old_file.match_rotation and old_file.match_map == Settings.DEFAULT_MATCH_MAP and old_file.match_team_size == 4
					and new_file.match_mode == "rounds" and not new_file.match_rotation and new_file.match_map == "res://maps/square.tscn" and new_file.match_team_size == 4,
			"old file: %s / %s / %s / %d; current file: %s / %s / %s" % [old_file.match_mode, old_file.match_rotation, old_file.match_map, old_file.match_team_size,
					new_file.match_mode, new_file.match_rotation, new_file.match_map])
	print("(Godot prints a ConfigFile parse error next: the check loads a broken file on purpose.)")
	_write_text(TEMP_PATH, "[game]\nsensitivity = 3.5\nthis is not a settings file [[[\nfov = abc\n")
	var broken := Settings.new()
	var broken_result := broken.load_from_disk(TEMP_PATH)
	var untouched := true
	for key: StringName in DEFAULTS:
		untouched = untouched and _same(broken.get_value(key), DEFAULTS[key])
	_check("A file that can't be parsed gives ERR_PARSE_ERROR and leaves every setting on its default", broken_result == ERR_PARSE_ERROR and untouched,
			"result %d, all defaults %s" % [broken_result, untouched])
	_remove_temp_file()


## reset_to_defaults() on the shared instance: values, engine state and keys, one `changed` per setting that was different.
func _test_reset() -> void:
	_settings.sensitivity = 3.0
	_settings.fps_cap = 120
	_settings.master_volume = 0.2
	_settings.crosshair_dot = true
	_settings.set_binding(&"reload", _key(KEY_T))
	_forget_changes()
	_settings.reset_to_defaults()
	var back := true
	for key: StringName in DEFAULTS:
		back = back and _same(_settings.get_value(key), DEFAULTS[key])
	var master := AudioServer.get_bus_index(Settings.BUS_MASTER)
	_check("reset_to_defaults() restores every value, the frame limit, the bus volume and the keys",
			back and Engine.max_fps == 0 and is_zero_approx(AudioServer.get_bus_volume_db(master))
					and _event_texts(_bound_events(&"reload")) == [_k(KEY_R)],
			"all defaults %s, max fps %d, master %.2f dB" % [back, Engine.max_fps, AudioServer.get_bus_volume_db(master)])
	_check("... and announces exactly the five things that were different, once each",
			_sorted(_changes) == _sorted([&"bindings", &"crosshair_dot", &"fps_cap", &"master_volume", &"sensitivity"]), "signals %s" % [_sorted(_changes)])
	var writer := Settings.new()
	writer.load_from_disk(TEMP_PATH)
	writer.sensitivity = 4.0
	writer.set_binding(&"reload", _key(KEY_T))
	writer.reset_to_defaults()
	var saved := _read_cfg(TEMP_PATH)
	_check("On an instance with a file, the reset is saved too (sensitivity 1, reload R)",
			saved != null and is_equal_approx(saved.get_value("game", "sensitivity", 0.0), 1.0) and saved.get_value("controls", "reload") == ["key:%d" % KEY_R, ""],
			"sensitivity in file %s" % [saved.get_value("game", "sensitivity", "none") if saved != null else "no file"])
	_remove_temp_file()


## main.gd applies the pixel settings and the console commands change settings, in the real main scene.
func _test_main_and_console() -> void:
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	add_child(main)
	await _wait_ticks(2)
	var world := main.get_node("World") as SubViewportContainer
	var palette := main.get_node("World/SubViewport/PaletteEffect") as CanvasLayer
	var window := get_tree().root
	# A headless window is 64 pixels tall and goes back to that every frame, so each
	# group of changes below first makes it a 1280 × 720 window and finishes in the same frame.
	window.size = Vector2i(1280, 720)
	main.apply_pixel_settings()
	_check("main.gd applies the defaults: in a 720-pixel window the world is rendered at 360 lines (480 rounded to a whole scale of 2), the palette effect on, the HUD at full resolution",
			world.stretch_shrink == 2 and palette.visible and window.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,
			"window %d tall: stretch shrink %d, palette %s" % [window.size.y, world.stretch_shrink, palette.visible])
	_settings.pixel_height = 270
	var low_res: int = world.stretch_shrink
	_settings.pixel_height = 720
	var full_res: int = world.stretch_shrink
	_check("Changing the pixel height changes how much the world image is scaled up (270 lines: 3 × 3, 720 lines: 1 × 1)",
			low_res == 3 and full_res == 1, "shrink %d at 270, %d at 720" % [low_res, full_res])
	_settings.palette_effect = false
	var palette_off := not palette.visible
	_settings.palette_effect = true
	_check("The palette effect switches off and on with its setting", palette_off and palette.visible, "off: %s, on again: %s" % [palette_off, palette.visible])
	window.size = Vector2i(1280, 720)
	_settings.pixel_height = 360
	_settings.pixelate_hud = true
	var pixelated := window.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and window.content_scale_size == Vector2i(640, 360) and world.stretch_shrink == 1
	_settings.pixelate_hud = false
	_check("Pixelating the HUD renders the whole window at the low resolution (640 × 360), and switching it off goes back",
			pixelated and window.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED and world.stretch_shrink == 2,
			"pixelated %s, then mode %d, shrink %d" % [pixelated, window.content_scale_mode, world.stretch_shrink])
	# The default 480 lines with the HUD pixelated: the whole window must be scaled
	# by the same whole number as the world-only style, so it fills the window
	# (asking for exactly 480 lines in a 720-pixel window gave an unscaled image).
	_settings.pixel_height = 480
	var sizes := []
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1281, 721)]:
		window.size = window_size
		_settings.pixelate_hud = true
		main.apply_pixel_settings()
		var content: Vector2i = window.content_scale_size
		var fills: bool = content.x * PixelView.get_pixel_scale(window_size.y, 480) <= window_size.x and content.y * PixelView.get_pixel_scale(window_size.y, 480) <= window_size.y
		sizes.append([window_size, content, fills])
		_settings.pixelate_hud = false
	var expected := [Vector2i(640, 360), Vector2i(960, 540), Vector2i(853, 480), Vector2i(640, 360)]
	var all_right := true
	for i in sizes.size():
		all_right = all_right and sizes[i][1] == expected[i] and sizes[i][2]
	_check("Pixelated HUD at the default 480 lines uses a whole scale that fills the window (720p: 640 × 360, 1080p: 960 × 540, 1440p: 853 × 480)",
			all_right, "window → image: %s" % ", ".join(sizes.map(func(entry: Array) -> String: return "%s → %s" % [entry[0], entry[1]])))
	_settings.reset_to_defaults()
	var console := main.get_node("DevConsole") as DevConsole
	console.run("sensitivity 2.5")
	var sensitivity_set := _settings.sensitivity == 2.5 and console.get_output_text().contains("sensitivity = 2.5")
	console.run("sensitivity")
	console.run("fov 200")
	console.run("volume 0.3")
	console.run("fps_max 120")
	_check("The console commands sensitivity, fov, volume and fps_max change the setting (clamped: fov 200 gives 110) and say what it is now",
			sensitivity_set and _settings.fov == 110.0 and is_equal_approx(_settings.master_volume, 0.3) and _settings.fps_cap == 120 and Engine.max_fps == 120
					and console.get_output_text().contains("fov = 110.0") and console.get_output_text().contains("volume = 0.3") and console.get_output_text().contains("fps_max = 120"),
			"sensitivity %s, fov %s, volume %s, fps cap %s" % [_settings.sensitivity, _settings.fov, _settings.master_volume, _settings.fps_cap])
	console.run("clear")
	console.run("sensitivity")
	console.run("fov")
	console.run("sensitivity fast")
	_check("Without a value a command shows the current one, and a value that isn't a number gets the usage line",
			console.get_output_text().contains("sensitivity = 2.5") and console.get_output_text().contains("fov = 110.0") and console.get_output_text().contains("Usage: sensitivity [value]") and _settings.sensitivity == 2.5,
			"output: %s" % console.get_output_text().replace("\n", " | "))
	console.run("settings_reset")
	var back := true
	for key: StringName in DEFAULTS:
		back = back and _same(_settings.get_value(key), DEFAULTS[key])
	_check("settings_reset puts everything back", back and Engine.max_fps == 0 and console.get_output_text().contains("back to their defaults"), "all defaults %s, max fps %d" % [back, Engine.max_fps])
	main.queue_free()
	await _wait_ticks(2)


## Players, HUDs and main scenes that were freed no longer listen to the shared instance.
func _test_nothing_left_connected(expected: int) -> void:
	var connections := _settings.changed.get_connections().size()
	_check("Freed nodes drop their connections: only the test's own listener is left on `changed`", connections == expected,
			"%d connection(s), expected %d" % [connections, expected])


## The real settings file is exactly as it was when the test started.
func _test_real_file_untouched() -> void:
	var now := FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
	_check("The real user://settings.cfg was not read, created or changed by any of this",
			Settings.real_file_accesses == 0 and not _settings.save_path, "accesses %d, shared instance saves to '%s' (checksum before '%s', after '%s')" % [Settings.real_file_accesses, _settings.save_path, _real_file_md5, now])


# --- Helpers ---


## A player in the tree (no floor needed: only its controller and sounds are looked at).
func _add_player() -> Character:
	var player := PLAYER_SCENE.instantiate() as Character
	player.footstep_sound = null
	add_child(player)
	return player


## How many degrees 100 mouse counts to the right turn the view (the sign of the yaw dropped).
func _turn_per_100_counts(controller: PlayerController) -> float:
	controller.set_look_angles(0.0, 0.0)
	# The same call a mouse movement makes; real motion events are ignored in a
	# headless run, which can't capture the mouse.
	controller._look(Vector2(100.0, 0.0))
	return rad_to_deg(-controller.get_input(0.0).yaw)


## The look-up angle in degrees after the mouse moved 100 counts down.
func _pitch_after_100_counts_down(controller: PlayerController) -> float:
	controller.set_look_angles(0.0, 0.0)
	controller._look(Vector2(0.0, 100.0))
	return rad_to_deg(controller.get_input(0.0).pitch)


## The signals a load of [param path] emits, by a new instance.
func _load_signals(path: String) -> Array[StringName]:
	var settings := Settings.new()
	var keys: Array[StringName] = []
	settings.changed.connect(func(key: StringName) -> void: keys.append(key))
	settings.load_from_disk(path)
	return keys


func _forget_changes() -> void:
	_changes.clear()


## Setting names as text in alphabetical order (sorting StringNames compares their addresses, not their letters).
func _sorted(keys: Array) -> Array[String]:
	var names: Array[String] = []
	for key: StringName in keys:
		names.append(String(key))
	names.sort()
	return names


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


## The file's text for a key: "key:87".
func _k(code: Key) -> String:
	return "key:%d" % code


## The file's text for a mouse button: "mouse:1".
func _m(button: MouseButton) -> String:
	return "mouse:%d" % button


func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		return _k((event as InputEventKey).physical_keycode)
	if event is InputEventMouseButton:
		return _m((event as InputEventMouseButton).button_index)
	return ""


func _event_texts(events: Array) -> Array[String]:
	var texts: Array[String] = []
	for event: InputEvent in events:
		# The gamepad's buttons (D-211) have their own bindings and tests.
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			texts.append(_event_text(event))
	return texts


## The texts of an action's two slots in [param settings], "" for an empty one.
func _binding_texts(settings: Settings, action: StringName) -> Array[String]:
	var texts: Array[String] = []
	for slot in Settings.BINDING_SLOTS:
		texts.append(_event_text(settings.get_binding(action, slot)))
	return texts


func _non_empty(texts: Array) -> Array[String]:
	var result: Array[String] = []
	for text: String in texts:
		if text != "":
			result.append(text)
	return result


## The project's bindings: action → the two slots' texts.
func _default_bindings() -> Dictionary:
	return {
		&"move_forward": [_k(KEY_W), ""], &"move_back": [_k(KEY_S), ""], &"move_left": [_k(KEY_A), ""], &"move_right": [_k(KEY_D), ""],
		&"jump": [_k(KEY_SPACE), _m(MOUSE_BUTTON_WHEEL_DOWN)], &"crouch": [_k(KEY_CTRL), ""], &"walk": [_k(KEY_SHIFT), ""],
		&"shoot": [_m(MOUSE_BUTTON_LEFT), ""], &"aim": [_m(MOUSE_BUTTON_RIGHT), ""], &"reload": [_k(KEY_R), ""], &"use": [_k(KEY_E), ""],
		&"scoreboard": [_k(KEY_TAB), ""], &"class_menu": [_k(KEY_M), ""], &"toggle_debug": [_k(KEY_F3), ""], &"toggle_console": [_k(KEY_QUOTELEFT), ""],
		&"slot_primary": [_k(KEY_1), ""], &"slot_pistol": [_k(KEY_2), ""], &"slot_knife": [_k(KEY_3), ""], &"slot_grenade": [_k(KEY_4), ""],
		&"last_weapon": [_k(KEY_Q), ""], &"drop_weapon": [_k(KEY_G), ""], &"buy_menu": [_k(KEY_B), ""],
	}


## Equal, allowing the tiny rounding of floats and colors that went through a file.
func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if typeof(a) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	if typeof(a) == TYPE_COLOR:
		return (a as Color).is_equal_approx(b)
	return a == b


func _read_cfg(path: String) -> ConfigFile:
	var file := ConfigFile.new()
	return file if file.load(path) == OK else null


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_temp_file() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


## The key and mouse events of an action: its gamepad events (D-211) have their own checks (access_test).
func _bound_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			events.append(event)
	return events
