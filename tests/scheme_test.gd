extends Node
## Regression test for the colour-blind option's freeze (found in the v0.2 playtest: "it crashes when I
## pick colour blind"). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 100000 res://tests/scheme_test.tscn
##
## Recolouring the UI theme one item at a time made every control restyle itself for every item: with
## the v0.2 UI, picking Settings → Interface → Team colours froze the game for 7 to 9 seconds (D-210).
## The theme is now recoloured in one merge. In each state the option is switched on and off through the
## real settings menu's own buttons, and the test checks that:
## - a switch takes far less than a second ([constant MAX_SWITCH_MS]; it was 7000);
## - the characters, the theme and the HUD's own copies of styleboxes show the scheme afterwards, and
##   everything is back to the standard look after switching off;
## - nothing prints a script error (the runner fails the suite on one).
## The states: the main menu, Team Deathmatch (with the killcam playing), free-for-all and Bomb rounds.
##
## Quits with the number of failed checks as the exit code (0 means everything passed).

const MAIN_SCENE := preload("res://main.tscn")
const MENU_SCENE := preload("res://ui/main_menu.tscn")
const MAP_SCENE := preload("res://maps/depot.tscn")
## The longest a switch may take, in milliseconds. A switch took 7000 to 9000 before the fix, 20 to 30 after.
const MAX_SWITCH_MS := 1000.0

var _failures: int = 0
var _main: Node


func _ready() -> void:
	Weapon.silent = true
	await _test_menu()
	await _test_match("Team Deathmatch", MatchSettings.GameMode.TEAM_RESPAWN, true)
	await _test_match("free-for-all", MatchSettings.GameMode.FREE_FOR_ALL, false)
	await _test_match("Bomb rounds", MatchSettings.GameMode.ROUNDS, false)
	_free_main()
	Settings.get_instance().team_colors = "standard"
	Weapon.silent = false
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


## The main menu with its settings menu open on the Interface tab.
func _test_menu() -> void:
	var menu: Node = MENU_SCENE.instantiate()
	menu.set("load_settings", false)
	add_child(menu)
	await _wait_frames(10)
	var settings_menu: SettingsMenu = menu.get("_settings_menu")
	var results := await _switch_both_ways(settings_menu)
	_check("Main menu: picking the colour-blind colours and going back each take under a second, and the theme follows both ways",
			results.on_ms < MAX_SWITCH_MS and results.off_ms < MAX_SWITCH_MS and results.themed and results.restored,
			"on %.0f ms, off %.0f ms, themed %s, restored %s" % [results.on_ms, results.off_ms, results.themed, results.restored])
	remove_child(menu)
	menu.queue_free()
	MenuState.reset()
	await _wait_frames(2)


## A running match of [param mode], with the settings menu opened from the pause menu's own instance.
func _test_match(title: String, mode: MatchSettings.GameMode, with_killcam: bool) -> void:
	_free_main()
	var rules := MatchSettings.new()
	rules.game_mode = mode
	rules.team_size = 3
	rules.enemy_team_size = 3
	rules.freeze_time = 0.5
	rules.round_end_time = 1.0
	rules.kill_limit = 50
	rules.time_limit = 300.0
	rules.respawn_delay = 2.0
	rules.bots_buy = false
	_main = MAIN_SCENE.instantiate()
	_main.set("load_settings", false)
	_main.set("loading_screen", false)
	_main.set("map_scene", MAP_SCENE)
	_main.set("match_settings", rules)
	add_child(_main)
	await _wait_frames(30)
	(_main.get_node("ClassMenu") as ClassMenu).close()
	for character in Character.all_in_world(_main):
		character.footstep_sound = null
	await _wait_frames(60)
	var settings_menu: SettingsMenu = _main.get("_settings_menu")
	var results := await _switch_both_ways(settings_menu, _main)
	_check("%s: both switches take under a second; the characters, the theme and the HUD follow, and it all comes back" % title,
			results.on_ms < MAX_SWITCH_MS and results.off_ms < MAX_SWITCH_MS and results.themed and results.restored and results.bodies,
			"on %.0f ms, off %.0f ms, themed %s, restored %s, bodies %s, HUD %s" % [results.on_ms, results.off_ms, results.themed,
					results.restored, results.bodies, results.hud])
	if with_killcam:
		await _test_killcam(settings_menu)


## The option picked while the killcam plays: your killer's replay is on, and the switch must not hang or error.
func _test_killcam(settings_menu: SettingsMenu) -> void:
	var killcam := _main.call("get_killcam") as Killcam
	var player := (_main.call("get_map") as Node).get_node("Player") as Character
	var rules := (_main.call("get_map") as Node).get_node("RespawnMatch") as RespawnMatch
	var ticks := 0
	while rules.phase != RoundManager.Phase.LIVE and ticks < 128 * 5:
		await get_tree().physics_frame
		ticks += 1
	var killer: Character = null
	for member in rules.get_participants():
		if member != player:
			member.frozen = true
			if not Teams.are_allies(member, player):
				killer = member
	await get_tree().create_timer(Killcam.BEFORE + 0.5, false).timeout
	player.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await get_tree().create_timer(Killcam.BEAT + 0.3, false).timeout
	var playing := killcam != null and killcam.is_playing()
	var results := await _switch_both_ways(settings_menu, _main)
	_check("Team Deathmatch, killcam playing: both switches take under a second and the match goes on",
			playing and results.on_ms < MAX_SWITCH_MS and results.off_ms < MAX_SWITCH_MS and results.restored and killcam.is_active(),
			"playing %s, on %.0f ms, off %.0f ms, restored %s" % [playing, results.on_ms, results.off_ms, results.restored])
	killcam.skip()
	await _wait_frames(4)


## Picks "Colour-blind" and then "Normal" with the settings menu's own segment buttons (the Team colours row on
## the Interface tab); measures each and looks at what shows the scheme afterwards. [param game] is the game
## scene, if any: its characters and HUD are checked too.
func _switch_both_ways(settings_menu: SettingsMenu, game: Node = null) -> Dictionary:
	settings_menu.open()
	settings_menu.get_tabs().current_tab = settings_menu.get_tab_names().find("Interface")
	await _wait_frames(3)
	var buttons := settings_menu.get_option(&"team_colors")
	var safe := Teams.SCHEMES[Teams.ColorScheme.COLORBLIND]
	var standard := Teams.SCHEMES[Teams.ColorScheme.STANDARD]
	var began := Time.get_ticks_usec()
	buttons[1].button_pressed = true
	var on_ms := (Time.get_ticks_usec() - began) / 1000.0
	await _wait_frames(3)
	var themed := Teams.color_scheme == Teams.ColorScheme.COLORBLIND \
			and _near(UiTheme.get_base().get_color(&"enemy_text", "Palette"), safe[&"enemy_text"]) \
			and _near((UiTheme.get_base().get_stylebox(&"panel", "EnemyChip") as StyleBoxFlat).bg_color, safe[&"enemy_text"])
	var bodies := true
	var hud := true
	if game != null:
		for character in Character.all_in_world(game):
			bodies = bodies and character.body.get_team_color() == Teams.color_of(character) \
					and (Teams.color_of(character) == safe[&"friendly"] or Teams.color_of(character) == safe[&"enemy"])
		hud = _hud_boxes_are(game, safe)
	began = Time.get_ticks_usec()
	buttons[0].button_pressed = true
	var off_ms := (Time.get_ticks_usec() - began) / 1000.0
	await _wait_frames(3)
	var restored := Teams.color_scheme == Teams.ColorScheme.STANDARD \
			and _near(UiTheme.get_base().get_color(&"enemy_text", "Palette"), standard[&"enemy_text"]) \
			and _near((UiTheme.get_base().get_stylebox(&"panel", "EnemyChip") as StyleBoxFlat).bg_color, standard[&"enemy_text"])
	if game != null:
		for character in Character.all_in_world(game):
			restored = restored and (Teams.color_of(character) == standard[&"friendly"] or Teams.color_of(character) == standard[&"enemy"]) \
					and character.body.get_team_color() == Teams.color_of(character)
		restored = restored and _hud_boxes_are(game, standard)
	settings_menu.close()
	return {"on_ms": on_ms, "off_ms": off_ms, "themed": themed, "restored": restored, "bodies": bodies, "hud": hud}


## True if every HUD panel in the team's colours (a bar fill or a pip, which keep a scaled copy of their stylebox of
## their own) shows [param scheme]'s fill or text colour for its side.
func _hud_boxes_are(game: Node, scheme: Dictionary) -> bool:
	for panel in game.find_children("*", "Panel", true, false):
		var variation := (panel as Panel).theme_type_variation
		var expected: Color
		match variation:
			&"HudFriendlyBarFill", &"HudFriendlyPipAlive":
				expected = scheme[&"friendly_text"]
			&"HudEnemyBarFill", &"HudEnemyPipAlive":
				expected = scheme[&"enemy_text"]
			_:
				continue
		var box := (panel as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
		if box == null or not _near(box.bg_color, expected):
			return false
	return true


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
