extends Node3D
## Automated checks for M15's accessibility options: the colour-blind-safe team colours (D-210) and
## the gamepad (D-211 to D-213). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/access_test.tscn
##
## Team colours:
## - The standard scheme's UI colours are the UI theme's (tools/ui_palette.gd's FRIENDLY, ENEMY and fills).
## - Under a simulation of protanopia, deuteranopia and tritanopia (Machado 2009, full severity),
##   the colour-blind scheme's two teams stay far apart (CIELAB distance), in the models, the UI's
##   text and its fills; the models and fills also differ in lightness, so they stay apart in
##   greyscale. The standard pair's models are equally light, which is why the option exists.
## - Picking the scheme through the shared settings recolours a character in the world, the
##   theme's colours and styleboxes (the base theme and a scaled copy), and switching back restores them.
##
## Gamepad (D-211 to D-213):
## - The stick response: dead zone, curve, full push and direction ([method PlayerController.pad_response]).
## - Every default pad binding, none shared; the input map has the sticks and Start; injected pad events
##   press the actions (buttons, triggers, Start) and the sticks give the stick vectors.
## - A real player: the left stick moves (dead zone cut), the right stick turns the view at the set rate,
##   sensitivity, curve, invert and dead zone act, a menu stops it, a scope slows it.
## - Pad bindings: bind, clash (the later bind wins), Start and sticks refused, saved and loaded, a damaged
##   file falls back to the defaults, reset.
## - Menus: B backs out of a menu like Esc (not in the game, not while a key is being bound), the first
##   pad press gives a menu without focus its first button; prompts follow the device used last.
##
## Quits with the number of failed checks as the exit code (0 means everything passed).

const PLAYER_SCENE := preload("res://player/player.tscn")
const TEMP_PATH := "user://test_access_settings.cfg"
## The default pad binding of every action that has one, as [method Settings.pad_text] writes it.
const PAD_DEFAULTS := {
	&"jump": "A", &"crouch": "B", &"walk": "L3", &"shoot": "RT", &"aim": "LT", &"reload": "X", &"use": "LB",
	&"scoreboard": "Back", &"class_menu": "R3", &"buy_menu": "RB", &"slot_primary": "D-Up", &"slot_pistol": "D-Right",
	&"slot_knife": "D-Down", &"slot_grenade": "D-Left", &"last_weapon": "Y",
}
const BOT_SCENE := preload("res://bots/bot.tscn")
## The least CIELAB distance (ΔE76) the two teams of one role must have under every simulated deficiency.
const MIN_DISTANCE := 70.0
## The least lightness (CIELAB L*) gap between the models' colours and between the fills'.
const MIN_LIGHTNESS_GAP := 15.0
## The deficiencies: Machado et al. 2009, severity 1.0, on linear RGB (rows of a 3 × 3 matrix).
const DEFICIENCIES := {
	"normal": [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
	"protanopia": [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	"deuteranopia": [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	"tritanopia": [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900],
}

var _failures: int = 0


func _ready() -> void:
	Weapon.silent = true
	_test_standard_matches_theme()
	_test_scheme_distances()
	await _test_scheme_reaches_everything()
	_test_pad_response()
	_test_pad_defaults()
	_test_pad_events()
	await _test_pad_player()
	_test_pad_bindings()
	await _test_pad_menus()
	_test_prompts()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Team colours ---


## The standard scheme's table repeats the theme's team colours; they must agree.
func _test_standard_matches_theme() -> void:
	var theme := UiTheme.get_base()
	var standard := Teams.SCHEMES[Teams.ColorScheme.STANDARD]
	var wrong: Array[String] = []
	for role: StringName in standard:
		var in_theme := theme.get_color(role, "Palette")
		if not _near(in_theme, standard[role]):
			wrong.append("%s %s vs %s" % [role, in_theme, standard[role]])
	_check("The standard scheme's six colours are the theme's Palette colours", wrong.is_empty(), "; ".join(wrong))
	_check("Standard FRIENDLY_COLOR and ENEMY_COLOR are the scheme's models",
			standard[&"friendly"] == Teams.FRIENDLY_COLOR and standard[&"enemy"] == Teams.ENEMY_COLOR, "constants agree")


## The colour-blind pair's distance and lightness gap under every deficiency.
func _test_scheme_distances() -> void:
	var standard := Teams.SCHEMES[Teams.ColorScheme.STANDARD]
	var safe := Teams.SCHEMES[Teams.ColorScheme.COLORBLIND]
	for role in ["", "_text", "_fill"]:
		var worst := INF
		var least_gap := INF
		var detail := ""
		for deficiency: String in DEFICIENCIES:
			var a := _lab(_simulate(safe[StringName("friendly" + role)], DEFICIENCIES[deficiency]))
			var b := _lab(_simulate(safe[StringName("enemy" + role)], DEFICIENCIES[deficiency]))
			var distance := a.distance_to(b)
			var gap := absf(a.x - b.x)
			worst = minf(worst, distance)
			least_gap = minf(least_gap, gap)
			detail += " %s ΔE %.0f ΔL %.0f;" % [deficiency, distance, gap]
		var label := {"": "models", "_text": "UI text", "_fill": "UI fills"}[role] as String
		_check("Colour-blind %s stay %.0f ΔE apart under every deficiency" % [label, MIN_DISTANCE], worst >= MIN_DISTANCE, detail)
		if role != "_text":
			_check("Colour-blind %s differ by %.0f L* or more in lightness" % [label, MIN_LIGHTNESS_GAP],
					least_gap >= MIN_LIGHTNESS_GAP, "least gap %.1f" % least_gap)
	var standard_gap := absf(_lab(standard[&"friendly"]).x - _lab(standard[&"enemy"]).x)
	_check("The standard models are about equally light (why the option exists)", standard_gap < MIN_LIGHTNESS_GAP,
			"ΔL %.1f" % standard_gap)


## Picking the scheme in the shared settings recolours a character, and the theme, and back.
func _test_scheme_reaches_everything() -> void:
	var settings := Settings.get_instance()
	var before := settings.team_colors
	Teams.set_viewer_team(0)
	var own := _add_bot(0)
	var enemy := _add_bot(1)
	var scaled := UiTheme.scaled(1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var standard := Teams.SCHEMES[Teams.ColorScheme.STANDARD]
	var safe := Teams.SCHEMES[Teams.ColorScheme.COLORBLIND]
	settings.team_colors = "colorblind"
	_check("The scheme is on", Teams.color_scheme == Teams.ColorScheme.COLORBLIND, "color_scheme %d" % Teams.color_scheme)
	_check("Your team's clothes are the colour-blind blue, the enemy's the orange",
			own.body.get_team_color() == safe[&"friendly"] and enemy.body.get_team_color() == safe[&"enemy"],
			"%s / %s" % [own.body.get_team_color(), enemy.body.get_team_color()])
	_check("The UI colour of a team follows the scheme",
			Teams.ui_color_for(0) == safe[&"friendly_text"] and Teams.ui_color_for(1, &"fill") == safe[&"enemy_fill"], "text / fill")
	for pair: Array in [["the base theme", UiTheme.get_base()], ["a scaled copy", scaled]]:
		var theme: Theme = pair[1]
		_check("Recoloured: %s's Palette colours" % pair[0],
				_near(theme.get_color(&"friendly_text", "Palette"), safe[&"friendly_text"])
				and _near(theme.get_color(&"enemy_text", "Palette"), safe[&"enemy_text"])
				and _near(theme.get_color(&"enemy", "Palette"), safe[&"enemy"]), "palette items")
		_check("Recoloured: %s's team-coloured label and stylebox" % pair[0],
				_near(theme.get_color(&"font_color", "EnemyLabel"), safe[&"enemy_text"])
				and _near((theme.get_stylebox(&"panel", "EnemyChip") as StyleBoxFlat).bg_color, safe[&"enemy_text"]),
				"EnemyLabel and EnemyChip")
		_check("Not touched: %s's other colours (the accent and the alert)" % pair[0],
				_near(theme.get_color(&"accent", "Palette"), Color("c8f03c")) and _near(theme.get_color(&"alert", "Palette"), Color("ffb02e")),
				"accent, alert")
	settings.team_colors = "standard"
	_check("Back to standard: the character, the base theme and the copy",
			own.body.get_team_color() == standard[&"friendly"] and enemy.body.get_team_color() == standard[&"enemy"]
			and _near(UiTheme.get_base().get_color(&"enemy_text", "Palette"), standard[&"enemy_text"])
			and _near(scaled.get_color(&"font_color", "EnemyLabel"), standard[&"enemy_text"])
			and _near((scaled.get_stylebox(&"panel", "EnemyChip") as StyleBoxFlat).bg_color, standard[&"enemy_text"]),
			"all standard again")
	settings.team_colors = before
	own.queue_free()
	enemy.queue_free()
	await get_tree().physics_frame


# --- Gamepad ---


func _test_pad_response() -> void:
	var response := PlayerController.pad_response
	_check("A push inside the dead zone is nothing", response.call(Vector2(0.1, 0.05), 0.15, 1.5) == Vector2.ZERO
			and response.call(Vector2.ZERO, 0.0, 1.0) == Vector2.ZERO, "0.11 long, dead zone 0.15")
	_check("A full push is full whatever the dead zone and curve (and a push past 1 is clamped)",
			(response.call(Vector2(1.0, 0.0), 0.15, 1.5) as Vector2).is_equal_approx(Vector2(1.0, 0.0))
			and (response.call(Vector2(0.0, -1.5), 0.3, 3.0) as Vector2).is_equal_approx(Vector2(0.0, -1.0)), "right, up")
	# Length 0.575 with a 0.15 dead zone is exactly half way through the live range.
	var half: Vector2 = response.call(Vector2(0.575, 0.0), 0.15, 2.0)
	_check("Half way through the live range, a curve of 2 gives a quarter and a straight curve a half",
			is_equal_approx(half.x, 0.25) and is_equal_approx((response.call(Vector2(0.575, 0.0), 0.15, 1.0) as Vector2).x, 0.5),
			"curve 2: %.3f" % half.x)
	var diagonal: Vector2 = response.call(Vector2(0.6, 0.6), 0.1, 1.5)
	_check("The direction survives the curve", is_equal_approx(diagonal.x, diagonal.y) and diagonal.x > 0.0, "%s" % diagonal)


func _test_pad_defaults() -> void:
	var settings := Settings.new()
	var wrong: Array[String] = []
	for action: StringName in PAD_DEFAULTS:
		var text := Settings.pad_text(settings.get_pad_binding(action))
		if text != PAD_DEFAULTS[action]:
			wrong.append("%s %s" % [action, text])
	_check("Every action has its default pad button (jump A, fire RT, aim LT, reload X, D-pad for the weapons...)",
			wrong.is_empty(), ", ".join(wrong))
	var seen := {}
	var shared := 0
	for action in Settings.PAD_BINDABLE_ACTIONS:
		var text := Settings.pad_text(settings.get_pad_binding(action))
		if text != "":
			shared += 1 if seen.has(text) else 0
			seen[text] = true
	_check("No two actions share a default pad button, and the console, debug and drop have none",
			shared == 0 and settings.get_pad_binding(&"toggle_console") == null and settings.get_pad_binding(&"drop_weapon") == null
			and settings.get_pad_binding(&"toggle_debug") == null, "%d shared" % shared)
	_check("Movement and looking are the sticks: they can't be bound",
			settings.get_pad_binding(&"move_forward") == null and not settings.set_pad_binding(&"move_forward", _button(JOY_BUTTON_A)), "move_forward")


func _test_pad_events() -> void:
	var pairs := [[&"pad_move_left", JOY_AXIS_LEFT_X, -1.0], [&"pad_move_right", JOY_AXIS_LEFT_X, 1.0],
			[&"pad_move_forward", JOY_AXIS_LEFT_Y, -1.0], [&"pad_move_back", JOY_AXIS_LEFT_Y, 1.0],
			[&"pad_look_left", JOY_AXIS_RIGHT_X, -1.0], [&"pad_look_right", JOY_AXIS_RIGHT_X, 1.0],
			[&"pad_look_up", JOY_AXIS_RIGHT_Y, -1.0], [&"pad_look_down", JOY_AXIS_RIGHT_Y, 1.0]]
	var missing: Array[String] = []
	for pair: Array in pairs:
		var found := false
		for event in InputMap.action_get_events(pair[0]):
			var motion := event as InputEventJoypadMotion
			found = found or (motion != null and motion.axis == pair[1] and is_equal_approx(motion.axis_value, pair[2]))
		if not found:
			missing.append(String(pair[0]))
	_check("The sticks are in the input map: left for moving, right for looking", missing.is_empty(), ", ".join(missing))
	var pressed: Array[String] = []
	for case: Array in [[&"jump", _button(JOY_BUTTON_A)], [&"reload", _button(JOY_BUTTON_X)], [&"slot_primary", _button(JOY_BUTTON_DPAD_UP)],
			[&"pause", _button(JOY_BUTTON_START)], [&"shoot", _trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0)], [&"aim", _trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)]]:
		_send(case[1])
		if not Input.is_action_pressed(case[0]):
			pressed.append("%s did not press" % case[0])
		var release: InputEvent = case[1].duplicate()
		if release is InputEventJoypadButton:
			(release as InputEventJoypadButton).pressed = false
		else:
			(release as InputEventJoypadMotion).axis_value = 0.0
		_send(release)
		if Input.is_action_pressed(case[0]):
			pressed.append("%s stuck" % case[0])
	_check("Pad buttons, triggers and Start press and release their actions (jump, reload, weapon 1, pause, fire, aim)",
			pressed.is_empty(), ", ".join(pressed))
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	var stick := Input.get_vector("pad_move_left", "pad_move_right", "pad_move_forward", "pad_move_back", 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check("The left stick pushed up reads as forward", stick.is_equal_approx(Vector2(0.0, -1.0)), "%s" % stick)


func _test_pad_player() -> void:
	var settings := Settings.get_instance()
	var player := PLAYER_SCENE.instantiate() as Character
	player.footstep_sound = null
	add_child(player)
	var controller := player.get_node("PlayerController") as PlayerController
	await get_tree().physics_frame
	settings.pad_deadzone = 0.15
	settings.pad_curve = 1.0
	settings.pad_sensitivity = 1.0
	settings.pad_invert_y = false
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	var forward := controller.get_input(0.0).move
	_axis(JOY_AXIS_LEFT_Y, -0.1)
	var drift := controller.get_input(0.0).move
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_check("The left stick moves the character: forward when pushed, still inside the dead zone",
			forward.is_equal_approx(Vector2(0.0, -1.0)) and drift == Vector2.ZERO, "pushed %s, drift %s" % [forward, drift])
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var turned := rad_to_deg(-controller.get_input(0.0).yaw)
	_check("A full push right turns the view PAD_DEGREES_PER_SECOND × time to the right (22° in 0.1 s)",
			is_equal_approx(turned, PlayerController.PAD_DEGREES_PER_SECOND * 0.1), "%.2f°" % turned)
	settings.pad_sensitivity = 2.0
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var faster := rad_to_deg(-controller.get_input(0.0).yaw)
	settings.pad_sensitivity = 1.0
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, 1.0)
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var down := rad_to_deg(controller.get_input(0.0).pitch)
	settings.pad_invert_y = true
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var inverted := rad_to_deg(controller.get_input(0.0).pitch)
	settings.pad_invert_y = false
	_check("The pad sensitivity scales the turn, a stick pushed down looks down, and the pad's Y inversion flips it",
			is_equal_approx(faster, turned * 2.0) and down < 0.0 and is_equal_approx(down, -inverted), "×2: %.1f°, down %.2f°, inverted %.2f°" % [faster, down, inverted])
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 0.1)
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var inside := controller.get_input(0.0).yaw
	settings.pad_deadzone = 0.0
	controller.set_look_angles(0.0, 0.0)
	controller._look_with_stick(0.1)
	var outside := controller.get_input(0.0).yaw
	settings.pad_deadzone = 0.15
	_check("A push inside the dead zone doesn't turn the view; the same push with no dead zone does",
			inside == 0.0 and outside < 0.0, "inside %s, none %s" % [inside, outside])
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	var dummy := Node.new()
	add_child(dummy)
	MenuState.open(dummy)
	controller.set_look_angles(0.0, 0.0)
	controller._process(0.1)
	var in_menu := controller.get_input(0.0).yaw
	MenuState.close(dummy)
	dummy.free()
	controller.set_look_angles(0.0, 0.0)
	controller._process(0.1)
	var after_menu := controller.get_input(0.0).yaw
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_check("An open menu stops the right stick turning the view, and it turns again when it closes",
			in_menu == 0.0 and after_menu < 0.0, "in menu %s, after %s" % [in_menu, after_menu])
	settings.reset_to_defaults()
	player.free()


func _test_pad_bindings() -> void:
	var settings := Settings.new()
	var lost := settings.bind_pad_exclusive(&"reload", _button(JOY_BUTTON_Y))
	_check("Binding Y to reload takes it from last weapon (the later bind wins)",
			Settings.pad_text(settings.get_pad_binding(&"reload")) == "Y" and lost == [&"last_weapon"]
			and settings.get_pad_binding(&"last_weapon") == null, "lost %s" % [lost])
	_check("A trigger can be bound (LT for walk); Start, the sticks and a key can't",
			settings.set_pad_binding(&"walk", _trigger(JOY_AXIS_TRIGGER_LEFT, 0.8)) and Settings.pad_text(settings.get_pad_binding(&"walk")) == "LT"
			and not Settings.can_bind_pad(_button(JOY_BUTTON_START)) and not Settings.can_bind_pad(_trigger(JOY_AXIS_LEFT_X, 1.0))
			and not Settings.can_bind_pad(_key(KEY_E)) and settings.find_pad_action_using(_trigger(JOY_AXIS_TRIGGER_LEFT, 1.0)) == &"walk",
			"walk %s" % Settings.pad_text(settings.get_pad_binding(&"walk")))
	settings.clear_pad_binding(&"jump")
	settings.save_to_disk(TEMP_PATH)
	var reader := Settings.new()
	reader.load_from_disk(TEMP_PATH)
	_check("Pad bindings are saved and loaded (reload Y, walk LT, jump unbound, the rest as before)",
			Settings.pad_text(reader.get_pad_binding(&"reload")) == "Y" and Settings.pad_text(reader.get_pad_binding(&"walk")) == "LT"
			and reader.get_pad_binding(&"jump") == null and Settings.pad_text(reader.get_pad_binding(&"shoot")) == "RT", "reload, walk, jump")
	var file := ConfigFile.new()
	file.load(TEMP_PATH)
	file.set_value("pad", "crouch", "pad:999")
	file.set_value("pad", "reload", "trigger:0")
	file.set_value("pad", "use", 17)
	file.set_value("pad", "aim", "nonsense")
	file.save(TEMP_PATH)
	var damaged := Settings.new()
	damaged.load_from_disk(TEMP_PATH)
	_check("A damaged pad section falls back to the defaults (crouch B, reload X, use LB, aim LT)",
			Settings.pad_text(damaged.get_pad_binding(&"crouch")) == "B" and Settings.pad_text(damaged.get_pad_binding(&"reload")) == "X"
			and Settings.pad_text(damaged.get_pad_binding(&"use")) == "LB" and Settings.pad_text(damaged.get_pad_binding(&"aim")) == "LT", "damaged file")
	reader.reset_bindings()
	_check("Resetting the bindings puts the pad's back too",
			Settings.pad_text(reader.get_pad_binding(&"reload")) == "X" and Settings.pad_text(reader.get_pad_binding(&"jump")) == "A", "reload X, jump A")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
	# The shared instance puts the pad bindings in the input map next to the keys.
	var shared := Settings.get_instance()
	shared.set_pad_binding(&"use", _button(JOY_BUTTON_B))
	shared.bind_pad_exclusive(&"use", _button(JOY_BUTTON_B))
	var has_b := false
	for event in InputMap.action_get_events(&"use"):
		has_b = has_b or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	var kept_key := false
	for event in InputMap.action_get_events(&"use"):
		kept_key = kept_key or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_E)
	_check("The shared settings put a pad binding in the input map and keep the key (use: E and B)", has_b and kept_key, "B %s, E %s" % [has_b, kept_key])
	shared.reset_bindings()


func _test_pad_menus() -> void:
	var pad := PadInput.new()
	add_child(pad)
	var menu := Control.new()
	var first := Button.new()
	var second := Button.new()
	menu.add_child(first)
	menu.add_child(second)
	add_child(menu)
	var accept_has_pad := false
	for event in InputMap.action_get_events(&"ui_accept"):
		accept_has_pad = accept_has_pad or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A)
	_check("A presses the focused button in menus (ui_accept has the pad's A)", accept_has_pad, "ui_accept")
	var back := _button(JOY_BUTTON_B)
	pad._input(back)
	_check("B does nothing while no menu is open (it is crouch in the game)", not pad._release_pending, "no pause sent")
	MenuState.open(menu)
	MenuState.capturing_input = true
	pad._input(back)
	var while_binding := pad._release_pending
	MenuState.capturing_input = false
	pad._input(back)
	Input.flush_buffered_events()
	var sent := pad._release_pending and Input.is_action_pressed("pause")
	pad._process(0.0)
	Input.flush_buffered_events()
	_check("With a menu open B presses pause (Esc) once and lets go; not while a key is being bound",
			sent and not while_binding and not Input.is_action_pressed("pause"), "sent %s, while binding %s" % [sent, while_binding])
	get_viewport().gui_release_focus()
	pad._input(_button(JOY_BUTTON_DPAD_DOWN))
	_check("The first pad press in a menu with no focus gives its first button the focus",
			get_viewport().gui_get_focus_owner() == first, "focus: %s" % get_viewport().gui_get_focus_owner())
	MenuState.close(menu)
	MenuState.reset()
	menu.free()
	pad.free()


func _test_prompts() -> void:
	var settings := Settings.new()
	LastInput.gamepad = false
	LastInput.note(_trigger(JOY_AXIS_RIGHT_X, 0.2))
	var drift_ignored := not LastInput.gamepad
	LastInput.note(_button(JOY_BUTTON_A))
	var pad_used := LastInput.gamepad
	var prompts := [LastInput.prompt_for(&"use", settings), LastInput.prompt_for(&"shoot", settings), LastInput.prompt_for(&"move_forward", settings),
			LastInput.prompt_for(&"toggle_console", settings)]
	LastInput.note(_key(KEY_W))
	var key_used := not LastInput.gamepad
	var key_prompts := [LastInput.prompt_for(&"use", settings), LastInput.prompt_for(&"move_forward", settings)]
	LastInput.note(_trigger(JOY_AXIS_TRIGGER_LEFT, 1.0))
	var trigger_used := LastInput.gamepad
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(10.0, 0.0)
	LastInput.note(mouse)
	var mouse_used := not LastInput.gamepad
	_check("Prompts follow the device used last: a resting stick is ignored, a pad press switches to the pad (LB, RT, L-Stick), a key or the mouse back (E, W)",
			drift_ignored and pad_used and prompts == ["LB", "RT", "L-Stick", "`"] and key_used and key_prompts == ["E", "W"] and trigger_used and mouse_used,
			"pad %s, keys %s" % [prompts, key_prompts])
	LastInput.gamepad = false


# --- Colour maths ---


## [param color] as a person with the given [param matrix] deficiency sees it (linear RGB, clamped).
static func _simulate(color: Color, matrix: Array) -> Color:
	var r := _to_linear(color.r)
	var g := _to_linear(color.g)
	var b := _to_linear(color.b)
	return Color(
			_to_srgb(clampf(matrix[0] * r + matrix[1] * g + matrix[2] * b, 0.0, 1.0)),
			_to_srgb(clampf(matrix[3] * r + matrix[4] * g + matrix[5] * b, 0.0, 1.0)),
			_to_srgb(clampf(matrix[6] * r + matrix[7] * g + matrix[8] * b, 0.0, 1.0)))


static func _to_linear(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


static func _to_srgb(value: float) -> float:
	return value * 12.92 if value <= 0.0031308 else 1.055 * pow(value, 1.0 / 2.4) - 0.055


## [param color] (sRGB) in CIELAB, D65: x is L*, y is a*, z is b*.
static func _lab(color: Color) -> Vector3:
	var r := _to_linear(color.r)
	var g := _to_linear(color.g)
	var b := _to_linear(color.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func _button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index as JoyButton
	event.pressed = true
	return event


static func _trigger(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = value
	return event


static func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = true
	return event


## Moves a stick or trigger axis of every pad, as the hardware would.
static func _axis(axis: int, value: float) -> void:
	_send(_trigger(axis, value))


## Sends [param event] through [method Input.parse_input_event] and applies it at once (the Input
## singleton buffers events until the next frame).
static func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


# --- Helpers ---


func _add_bot(team: int) -> Character:
	var bot := BOT_SCENE.instantiate() as Character
	bot.footstep_sound = null
	bot.team = team
	add_child(bot)
	return bot


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
