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
## Quits with the number of failed checks as the exit code (0 means everything passed).

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
