extends Node
## Automated checks for the mode choice and the map rotation (M8, D-087). Run
## without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/rotation_test.tscn
##
## The Play screen with a Settings instance of its own (it never saves): the mode
## cards (Team Deathmatch or Bomb, D-135), the match length switching between rounds and kills,
## the map row (a quick map or the rotation) and the rotation's order and summary,
## and what Start leaves for the game. Then the game itself (main.tscn, started
## the way Start does, never touching the real settings file): a rotation starts
## on its first map, the match-end screen offers "Next map · Square", the next map
## is a fresh match by the same rules, the rotation wraps around, "Play again"
## stays on the map, and without a rotation there is no "Next map". Quits with
## the number of failed checks as the exit code.

const MAIN_SCENE := preload("res://main.tscn")
const MATCH_SETUP_SCENE := preload("res://ui/match_setup.tscn")
const DEPOT := "res://maps/depot.tscn"
const SQUARE := "res://maps/square.tscn"
const SPILLWAY := "res://maps/spillway.tscn"

var _failures: int = 0
var _main: Node
## The winner of every match_ended signal of the current map.
var _match_ends: Array[int] = []


func _ready() -> void:
	await _test_setup()
	await _test_rotation_in_game()
	await _test_respawn_launch()
	await _test_single_map()
	_free_main()
	GameLaunch.clear()
	MenuState.reset()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Match setup ---


func _test_setup() -> void:
	# A Settings.new() only holds values: it never saves and never touches the engine.
	var stored := Settings.new()
	var setup := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	setup.settings = stored
	add_child(setup)
	await get_tree().process_frame
	var cards := setup.get_mode_cards()
	var rounds_buttons := setup.get_segment_buttons(&"match_rounds_to_win")
	var kill_buttons := setup.get_segment_buttons(&"match_kill_limit")
	var map_buttons := setup.get_segment_buttons(&"match_map")
	var rules := setup.build_match_settings()
	_check("The Play screen (D-135) offers Team Deathmatch, Bomb and Practice cards and a map row (Depot, Square, Spillway, Rotation); by default Team Deathmatch on the rotation from Depot, the length in kills",
			cards.size() == 3 and _texts(map_buttons) == ["Depot", "Square", "Spillway", "Rotation"]
					and _texts(kill_buttons) == ["25", "50", "75", "100"]
					and setup.get_picked_mode() == "respawn" and (map_buttons[3] as Button).button_pressed
					and not setup.is_row_shown(&"match_rounds_to_win") and setup.is_row_shown(&"match_kill_limit")
					and rules.game_mode == MatchSettings.GameMode.TEAM_RESPAWN and setup.get_rotation_maps() == [DEPOT, SQUARE, SPILLWAY]
					and setup.get_summary().begins_with("Team Deathmatch: ") and setup.get_summary().ends_with("Maps in rotation: Depot, Square, Spillway."),
			"maps %s, kills %s, summary '%s'" % [_texts(map_buttons), _texts(kill_buttons), setup.get_summary()])

	cards[1].pressed.emit()
	var bomb_rules := setup.build_match_settings()
	var bomb_summary := setup.get_summary()
	var bomb_rows := setup.is_row_shown(&"match_rounds_to_win") and not setup.is_row_shown(&"match_kill_limit")
	cards[0].pressed.emit()
	rules = setup.build_match_settings()
	var at_fifty := rules.kill_limit
	(kill_buttons[2] as Button).button_pressed = true
	rules = setup.build_match_settings()
	_check("Bomb counts rounds (rounds mode, \"Bomb: \" in the summary); Team Deathmatch counts kills (50 by default, 75 when picked), the summary says so, and Play plays a team respawn match",
			bomb_rules.game_mode == MatchSettings.GameMode.ROUNDS and bomb_rows and bomb_summary.begins_with("Bomb: ") and bomb_summary.contains("first to 5 rounds")
					and stored.match_mode == "respawn" and rules.game_mode == MatchSettings.GameMode.TEAM_RESPAWN and at_fifty == 50
					and rules.kill_limit == 75 and stored.match_kill_limit == 75
					and not setup.is_row_shown(&"match_rounds_to_win") and setup.is_row_shown(&"match_kill_limit")
					and setup.get_summary().begins_with("Team Deathmatch: ") and setup.get_summary().contains("first to 75 kills"),
			"bomb summary '%s'; stored %s / %d, kill limit %d, summary '%s'" % [bomb_summary, stored.match_mode, stored.match_kill_limit, rules.kill_limit, setup.get_summary()])

	(map_buttons[1] as Button).button_pressed = true
	var one_map := setup.get_rotation_maps()
	(map_buttons[3] as Button).button_pressed = true
	var from_square := setup.get_rotation_maps()
	_check("A map plays alone; Rotation plays Depot, Square, Spillway, starting on the chosen map (Square here); the summary lists them",
			one_map.is_empty() and stored.match_rotation and from_square == [SQUARE, SPILLWAY, DEPOT]
					and setup.get_summary().ends_with("Maps in rotation: Square, Spillway, Depot."),
			"from Square %s, summary '%s'" % [from_square, setup.get_summary()])

	# What Start leaves for the game.
	GameLaunch.start_match(setup.get_map_path(), setup.build_match_settings(), setup.get_rotation_maps())
	_check("Start leaves the rotation for the game: its first map, all three maps, and the team respawn rules",
			GameLaunch.is_pending() and GameLaunch.map_path == SQUARE and GameLaunch.rotation == [SQUARE, SPILLWAY, DEPOT]
					and GameLaunch.match_settings.game_mode == MatchSettings.GameMode.TEAM_RESPAWN,
			"map %s, rotation %s" % [GameLaunch.map_path, GameLaunch.rotation])
	GameLaunch.clear()
	(map_buttons[1] as Button).button_pressed = true
	cards[1].pressed.emit()
	GameLaunch.start_match(setup.get_map_path(), setup.build_match_settings(), setup.get_rotation_maps())
	_check("Back to one map and Bomb: Start leaves just that map and the rounds rules", GameLaunch.map_path == SQUARE and GameLaunch.rotation.is_empty()
			and GameLaunch.match_settings.game_mode == MatchSettings.GameMode.ROUNDS, "map %s, rotation %s" % [GameLaunch.map_path, GameLaunch.rotation])
	GameLaunch.clear()
	remove_child(setup)
	setup.queue_free()
	MenuState.reset()


# --- In the game ---


func _test_rotation_in_game() -> void:
	await _start_game(GameLaunch.rotation_maps(), _quick_rules())
	var end_screen := _main.get_node("MatchEndScreen") as MatchEndScreen
	var next_button := end_screen.get_next_map_button()
	_check("A rotation starts on its first map, Depot; the match-end screen will offer \"Next map · Square\"",
			_map_path() == DEPOT and _main.call("get_next_map") == SQUARE and next_button.text == "Next map · Square"
					and not end_screen.visible,
			"map %s, next %s, button '%s'" % [_map_path(), _main.call("get_next_map"), next_button.text])
	await _win_match()
	_check("After the match the end screen shows \"Next map · Square\" next to Play again, and it has the focus",
			end_screen.visible and next_button.is_visible_in_tree() and next_button.has_focus(),
			"screen %s, button visible %s, focus %s" % [end_screen.visible, next_button.is_visible_in_tree(), next_button.has_focus()])
	next_button.pressed.emit()
	await _wait_ticks(3)
	var rounds := _rounds()
	_check("Next map plays Square: a fresh match by the same rules, the end screen hidden, and Spillway next",
			_map_path() == SQUARE and rounds != null and rounds.round_number == 1 and rounds.score == [0, 0]
					and rounds.settings.rounds_to_win == 1 and not end_screen.visible and next_button.text == "Next map · Spillway",
			"map %s, round %d, score %s, next '%s'" % [_map_path(), rounds.round_number if rounds else -1, rounds.score if rounds else [], next_button.text])
	_main.call("restart_match")
	await _wait_ticks(3)
	_check("Play again stays on the map (Square), and Spillway is still next",
			_map_path() == SQUARE and _main.call("get_next_map") == SPILLWAY, "map %s, next %s" % [_map_path(), _main.call("get_next_map")])
	_main.call("next_map")
	await _wait_ticks(3)
	var on_spillway := _map_path()
	_main.call("next_map")
	await _wait_ticks(3)
	_check("After Spillway the rotation starts over with Depot", on_spillway == SPILLWAY and _map_path() == DEPOT
			and next_button.text == "Next map · Square", "then %s, then %s" % [on_spillway, _map_path()])


func _test_respawn_launch() -> void:
	var rules := _quick_rules()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	rules.kill_limit = 30
	await _start_game(GameLaunch.rotation_maps(SPILLWAY), rules)
	var respawn := _main.call("get_map").get_node_or_null("RespawnMatch") as RespawnMatch
	_check("Team respawn from match setup: a respawn match by those rules, on the rotation's first map (Spillway here), then Depot",
			respawn != null and respawn.settings.kill_limit == 30 and _map_path() == SPILLWAY and _main.call("get_next_map") == DEPOT,
			"rules %s, map %s, next %s" % [respawn, _map_path(), _main.call("get_next_map")])
	_main.call("next_map")
	await _wait_ticks(3)
	_check("The next map keeps the mode: team respawn on Depot", _main.call("get_map").get_node_or_null("RespawnMatch") != null and _map_path() == DEPOT,
			"map %s" % _map_path())


func _test_single_map() -> void:
	await _start_game([], _quick_rules(), DEPOT)
	var end_screen := _main.get_node("MatchEndScreen") as MatchEndScreen
	await _win_match()
	var shown_before := end_screen.visible
	_main.call("next_map")
	await _wait_ticks(3)
	_check("Without a rotation the end screen has no Next map, and next_map() does nothing",
			shown_before and not end_screen.get_next_map_button().visible and _map_path() == DEPOT and _main.call("get_next_map") == "",
			"screen shown %s, button %s, map %s" % [shown_before, end_screen.get_next_map_button().visible, _map_path()])


# --- Helpers ---


## A match of one round each, with short pauses, so a test can finish one quickly.
func _quick_rules() -> MatchSettings:
	var rules := MatchSettings.new()
	rules.rounds_to_win = 1
	rules.freeze_time = 0.3
	rules.round_end_time = 0.3
	return rules


## Starts main.tscn the way match setup's Start does: on [param maps] in
## rotation, or on [param map] alone when [param maps] is empty.
func _start_game(maps: Array[String], rules: MatchSettings, map: String = "") -> void:
	_free_main()
	GameLaunch.start_match(map, rules, maps)
	_main = MAIN_SCENE.instantiate()
	# Never read or write the player's real settings file.
	_main.set("load_settings", false)
	add_child(_main)
	await _wait_ticks(3)
	_silence_everyone()


## Wins the current match for your team: waits for the live round, removes the enemy team, waits for the end screen.
func _win_match() -> void:
	var rounds := _rounds()
	_match_ends.clear()
	rounds.match_ended.connect(func(winner: int) -> void: _match_ends.append(winner))
	var ticks := 0
	while rounds.phase != RoundManager.Phase.LIVE and ticks < 128 * 3:
		await get_tree().physics_frame
		ticks += 1
	var player := _main.call("get_map").get_node("Player") as Character
	for enemy in rounds.get_members(Teams.other(player.team)):
		enemy.take_damage(500.0, Hitbox.Zone.CHEST, player)
	ticks = 0
	while _match_ends.is_empty() and ticks < 128 * 3:
		await get_tree().physics_frame
		ticks += 1
	await _wait_ticks(2)


func _rounds() -> RoundManager:
	var map: Node = _main.call("get_map")
	for child in map.get_children():
		if child is RoundManager:
			return child
	return null


func _map_path() -> String:
	return (_main.call("get_map") as Node).scene_file_path


func _silence_everyone() -> void:
	var rounds := _rounds()
	if rounds == null:
		return
	for character in rounds.get_participants():
		character.footstep_sound = null
		if character.weapon != null:
			var data := character.weapon.data.duplicate() as WeaponData
			data.shot_sound = null
			data.dry_fire_sound = null
			data.reload_sound = null
			character.weapon.data = data
	if rounds.bomb != null:
		for property in ["beep_sound", "plant_sound", "defuse_sound", "explosion_sound"]:
			rounds.bomb.set(property, null)


func _free_main() -> void:
	if _main != null:
		remove_child(_main)
		_main.queue_free()
		_main = null
	MenuState.reset()


func _texts(buttons: Array) -> Array[String]:
	var texts: Array[String] = []
	for button in buttons:
		texts.append((button as Button).text)
	return texts


## True when the row holding [param buttons] (row → strip → buttons) is shown.
func _row_visible(buttons: Array) -> bool:
	return not buttons.is_empty() and ((buttons[0] as Node).get_parent().get_parent() as Control).visible


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
