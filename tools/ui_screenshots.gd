extends SceneTree
## Tool: screenshots of every screen of the UI, taken through the real scenes
## (the main menu over its flight, match setup, the settings menu's five tabs, and a real
## match on Depot: class menu, HUD in freeze time and in a live round with kills,
## the Tab scoreboard, the pause menu, the console and the match-end screen, then
## a Team Deathmatch HUD on Square and the same after you die, with the respawn
## countdown), for judging the look before and after a
## change (M10). Run with a window (rendering needs one):
##
##     Godot --path . --resolution 1280x720 --quit-after 20000 --script res://tools/ui_screenshots.gd -- --out <folder>
##
## Add [code]--resolution 1920x1080[/code] for the scaled look. It never takes the
## mouse: the mouse is made visible again every frame and, except for the shots
## that need it off, the developer console is flagged open, so the player
## controller ignores all input. Kills are scripted (real damage through
## [method Character.take_damage]), and the match end is announced by the round
## manager's own signal, so the screens show what they would in a game. The
## settings are the defaults, never the player's file. Each shot is saved as
## [code]<number>_<name>.png[/code] at the window's size.

## The map of the bomb-rounds match, and of the Team Deathmatch one.
const ROUNDS_MAP := "res://maps/depot.tscn"
const RESPAWN_MAP := "res://maps/square.tscn"

var _out_folder: String = "user://ui_screenshots"
## While true, the console flag is set every frame (the player ignores input).
var _block_input: bool = true
var _count: int = 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_index := args.find("--out")
	if out_index >= 0 and out_index + 1 < args.size():
		_out_folder = args[out_index + 1]
	DirAccess.make_dir_recursive_absolute(_out_folder)
	process_frame.connect(_keep_input_away)
	await _menu_shots()
	await _match_shots()
	await _respawn_shots()
	print("Saved %d screenshots to %s" % [_count, _out_folder])
	quit()


func _keep_input_away() -> void:
	if _block_input:
		DevConsole.is_open = true
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _menu_shots() -> void:
	var menu: Node = load(GameLaunch.MENU_SCENE).instantiate()
	menu.set("load_settings", false)
	root.add_child(menu)
	await _frames(40)
	await _shot("main_menu")
	menu.call("open_match_setup")
	await _frames(4)
	await _shot("match_setup")
	(menu.call("get_match_setup") as MatchSetup).close()
	menu.call("open_settings")
	await _frames(4)
	await _shot("settings_game")
	var settings_menu: SettingsMenu = menu.call("get_settings_menu")
	settings_menu.get_tabs().current_tab = settings_menu.get_tab_names().find("Crosshair")
	await _frames(4)
	await _shot("settings_crosshair")
	settings_menu.get_tabs().current_tab = settings_menu.get_tab_names().find("Controls")
	# One slot waits for a key, as the mockup shows it.
	settings_menu.start_listening(&"jump", 0)
	await _frames(4)
	await _shot("settings_controls")
	settings_menu.stop_listening()
	settings_menu.get_tabs().current_tab = settings_menu.get_tab_names().find("Video")
	await _frames(4)
	await _shot("settings_video")
	settings_menu.get_tabs().current_tab = settings_menu.get_tab_names().find("Audio")
	await _frames(4)
	await _shot("settings_audio")
	settings_menu.close()
	root.remove_child(menu)
	menu.free()
	await _frames(2)


func _match_shots() -> void:
	var rules := MatchSettings.new()
	GameLaunch.start_match(ROUNDS_MAP, rules)
	var main: Node = await _start_game()
	var manager := _find_rules(main) as RoundManager
	var player := _find_player(main)
	# The class menu opens by itself in the first freeze time, unless the console flag stops it.
	_block_input = false
	DevConsole.is_open = false
	var class_menu := main.get_node("ClassMenu") as ClassMenu
	for i in 30:
		if class_menu.is_open():
			break
		await process_frame
	if not class_menu.is_open():
		class_menu.open()
	await _frames(4)
	await _shot("class_menu")
	class_menu.close()
	_block_input = true
	await _frames(20)
	await _shot("hud_freeze")
	await _skip_freeze_time(manager)
	var you := Teams.viewer_team
	var friends := manager.get_members(you).filter(func(c: Character) -> bool: return c != player)
	var enemies := manager.get_members(Teams.other(you))
	# A few kills for the feed and the alive squares: yours with a headshot, a teammate's, a lost teammate.
	enemies[0].take_damage(500.0, Hitbox.Zone.HEAD, player)
	await _frames(10)
	if friends.size() > 0:
		enemies[1].take_damage(500.0, Hitbox.Zone.CHEST, friends[0])
		await _frames(10)
		friends[0].take_damage(500.0, Hitbox.Zone.CHEST, enemies[2])
	player.take_damage(38.0, Hitbox.Zone.CHEST, null)
	await _frames(30)
	await _shot("hud_live")
	# The Tab scoreboard (the console flag would hide it).
	_block_input = false
	DevConsole.is_open = false
	Input.action_press("scoreboard")
	await _frames(6)
	await _shot("scoreboard")
	Input.action_release("scoreboard")
	await _frames(2)
	var pause := main.call("get_pause_menu") as PauseMenu
	pause.open()
	await _frames(6)
	await _shot("pause_menu")
	pause.close()
	paused = false
	await _frames(2)
	var console := main.get_node("DevConsole") as DevConsole
	console.set_open(true)
	console.run("help")
	await _frames(6)
	await _shot("console")
	console.set_open(false)
	_block_input = true
	await _frames(2)
	# The end of the match, as the round manager announces it.
	manager.score[you] = 5
	manager.score[Teams.other(you)] = 3
	manager.match_ended.emit(you)
	await _frames(10)
	await _shot("match_end")
	await _stop_game(main)


func _respawn_shots() -> void:
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	GameLaunch.start_match(RESPAWN_MAP, rules)
	var main: Node = await _start_game()
	var manager := _find_rules(main) as RoundManager
	var player := _find_player(main)
	var class_menu := main.get_node("ClassMenu") as ClassMenu
	if class_menu.is_open():
		class_menu.close()
	await _skip_freeze_time(manager)
	var enemies := manager.get_members(Teams.other(Teams.viewer_team))
	enemies[0].take_damage(500.0, Hitbox.Zone.HEAD, player)
	await _frames(30)
	await _shot("hud_team_deathmatch")
	# You die: "Killed by ..." with the respawn countdown under it.
	player.take_damage(500.0, Hitbox.Zone.CHEST, enemies[1])
	await _frames(30)
	await _shot("hud_respawn_countdown")
	await _stop_game(main)


## Ends the freeze time at once (the round manager counts [member RoundManager.time_left]
## down and goes live at zero) and waits for the live round.
func _skip_freeze_time(manager: RoundManager) -> void:
	while manager.phase == RoundManager.Phase.FREEZE:
		manager.time_left = minf(manager.time_left, 0.01)
		await physics_frame


func _start_game() -> Node:
	var main: Node = load(GameLaunch.GAME_SCENE).instantiate()
	main.set("load_settings", false)
	root.add_child(main)
	await _frames(10)
	return main


func _stop_game(main: Node) -> void:
	paused = false
	root.remove_child(main)
	main.free()
	MenuState.reset()
	await _frames(2)


func _find_rules(main: Node) -> Node:
	var map: Node = main.call("get_map")
	for child in map.get_children():
		if child is RoundManager:
			return child
	return null


func _find_player(main: Node) -> Character:
	return (main.call("get_map") as Node).get_node("Player") as Character


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	_count += 1
	var path := _out_folder.path_join("%02d_%s.png" % [_count, shot_name])
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)
