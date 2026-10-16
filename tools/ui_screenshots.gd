extends SceneTree
## Tool: screenshots of every screen of the UI, taken through the real scenes
## (the main menu over its flight, match setup, the settings menu's five tabs, and a real
## match on Depot: class menu, HUD in freeze time and in a live round with kills,
## the Tab scoreboard, the pause menu, the console and the match-end screen, then
## a Team Deathmatch HUD on Square and the same after you die, with the respawn
## countdown, and its Tab scoreboard, the loading screen over a rotation's second map, and the multiplayer
## lobby (the connect page, then hosting: this opens a real UDP port for a moment), for judging the look before and after a
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
	# The studio's boot screen (M11) would cover every menu shot: it is checked by layout_test.
	BootScreen.enabled = false
	process_frame.connect(_keep_input_away)
	if args.has("--stats-only"):
		await _stats_shots()
		print("Saved %d screenshots to %s" % [_count, _out_folder])
		quit()
		return
	await _menu_shots()
	await _match_shots()
	await _respawn_shots()
	await _loading_shots()
	await _lobby_shots()
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
	await _stats_shots()


## The Stats screen (M14) with a book of made-up matches, one shot per tab (also alone, with --stats-only).
func _stats_shots() -> void:
	var menu: Node = load(GameLaunch.MENU_SCENE).instantiate()
	menu.set("load_settings", false)
	root.add_child(menu)
	await _frames(10)
	var stats: StatsMenu = menu.call("get_stats_menu")
	var book := StatsBook.new()
	var guns := ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol"]
	for index in 14:
		var record := StatsMatch.new()
		record.date = 1_792_000_000 + index * 86_400 + index * 977
		record.mode = StatsMatch.MODE_ROUNDS if index % 3 != 0 else StatsMatch.MODE_RESPAWN
		record.map = ["depot", "square", "spillway"][index % 3]
		record.result = StatsMatch.LOSS if index % 4 == 1 else StatsMatch.WIN
		record.score_us = 5 if record.result == StatsMatch.WIN else 3
		record.score_them = 3 if record.result == StatsMatch.WIN else 5
		record.kills = 9 + (index * 7) % 13
		record.deaths = 6 + (index * 5) % 9
		record.damage = 1400.0 + (index * 113) % 700
		record.rounds = 8 if record.mode == StatsMatch.MODE_ROUNDS else 0
		record.duration = 840.0 + index * 31
		record.headshot_kills = record.kills / 3
		for gun_index in guns.size():
			var weapon := StatsWeapon.new()
			weapon.add_shots(220 - gun_index * 30 + index)
			for hit in 60 - gun_index * 7:
				weapon.add_hit(Hitbox.Zone.HEAD if hit % 5 == 0 else Hitbox.Zone.values()[1 + hit % 4])
			weapon.kills = 3 + index % 5
			weapon.damage = 400.0 + gun_index * 90.0
			record.weapons[guns[gun_index]] = weapon
		record.kills_per_minute = [3, 2, 4, 1, 3, 2, 3, 2, 2, 2] as Array[int]
		record.deaths_per_minute = [1, 2, 1, 2, 2, 1, 2, 1, 2, 1] as Array[int]
		book.add_match(record)
	book.submit_best("aim_flick_rifle", 4200.0, {"hits": 31, "accuracy": 62.5})
	book.submit_best("aim_flick_smg", 3900.0, {"hits": 28, "accuracy": 55.0})
	stats.book = book
	stats.open()
	await _frames(4)
	await _shot("stats")
	stats.open_match(book.history.size() - 1)
	await _frames(4)
	await _shot("stats_match_detail")
	stats.get_back_button().pressed.emit()
	stats.set_filter("training")
	await _frames(4)
	await _shot("stats_training")
	stats.close()
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
	# The buy menu in freeze time with all four looks: $1800 left after a vest and a flashbang (owned, and the Ram, Warden
	# and Heron too dear), the Hornet's item with the focus.
	manager.add_money(player, 1500, "screenshot")
	manager.request_buy(player, Shop.VEST)
	manager.request_buy(player, &"flashbang")
	var buy_menu := main.get_node("BuyMenu") as BuyMenu
	buy_menu.open()
	buy_menu.get_item_button(&"smg").grab_focus()
	await _frames(4)
	await _shot("buy_menu")
	buy_menu.close()
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
	await _hud_extras_shot(main, manager, player, enemies)
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
	# You die with a teammate alive: the spectate view (their health, armor and weapon over the plate with their name), after the 2 s delay.
	player.take_damage(500.0, Hitbox.Zone.CHEST, enemies[1])
	await _frames(200)
	await _shot("hud_spectate")
	# The end of the match, as the round manager announces it (in a rotation, so the third button shows).
	(main.get_node("MatchEndScreen") as MatchEndScreen).set_next_map("Square")
	manager.score[you] = 5
	manager.score[Teams.other(you)] = 3
	manager.match_ended.emit(you)
	await _frames(10)
	await _shot("match_end")
	await _stop_game(main)


## The kill feed with every kind of line (yours with a headshot, your death, a kill between others, the bomb's), a
## few toasts, the hit marker and the bomb tag with the plant prompt, staged straight on the HUD: the feed and the
## toasts only show what they are told. The shot follows the hit marker's flash by one frame.
func _hud_extras_shot(main: Node, manager: RoundManager, player: Character, enemies: Array) -> void:
	var hud := main.get_node("HUD")
	var feed := hud.get_node("RoundHud/KillFeed") as KillFeed
	var toasts := hud.get_node("%Toasts") as ToastStack
	feed.clear()
	var gun := player.weapon.data
	feed.add_kill(enemies[0], player, true, gun)
	feed.add_kill(player, enemies[1], false, enemies[1].weapon.data)
	feed.add_kill(enemies[1], enemies[2], false, enemies[2].weapon.data)
	feed.add_kill(enemies[2], null, false, null, &"bomb")
	toasts.show_toast(ToastStack.Kind.NEUTRAL, "Switching sides")
	toasts.show_toast(ToastStack.Kind.MATCH_POINT, "Match point")
	toasts.show_toast(ToastStack.Kind.BOMB, "Bomb planted at A")
	toasts.show_toast(ToastStack.Kind.LOW_AMMO, "Low ammo · R reload")
	if manager.bomb != null:
		manager.bomb.start_round(player, manager.bomb.attacking_team)
	await _frames(3)
	(hud.get_node("HitMarker") as HitMarker).show_hit(true)
	await _shot("hud_feed_toasts")
	# The plant prompt: in a bomb site with the bomb, first what to hold, then holding it for half a second.
	if manager.bomb == null:
		return
	toasts.clear()
	feed.clear()
	var site := manager.bomb.get_sites()[0]
	player.global_position = site.global_position + Vector3.DOWN * 1.5
	await _frames(20)
	await _shot("hud_bomb_hold")
	_block_input = false
	DevConsole.is_open = false
	Input.action_press("use")
	await _frames(40)
	await _shot("hud_bomb_planting")
	Input.action_release("use")
	_block_input = true


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
	# The Tab scoreboard of a Team Deathmatch (the kill limit and the clock under the mode), with you dead.
	_block_input = false
	DevConsole.is_open = false
	Input.action_press("scoreboard")
	await _frames(6)
	await _shot("scoreboard_team_deathmatch")
	Input.action_release("scoreboard")
	_block_input = true
	await _stop_game(main)


## Ends the freeze time at once (the round manager counts [member RoundManager.time_left]
## down and goes live at zero) and waits for the live round.
func _skip_freeze_time(manager: RoundManager) -> void:
	while manager.phase == RoundManager.Phase.FREEZE:
		manager.time_left = minf(manager.time_left, 0.01)
		await physics_frame


## The loading screen as the mockup draws it: Square, the rotation's second map, over the game, with seven of the
## twelve squares done. The game starts on Depot (its launch shows the screen too), the screen is skipped over, and
## "Next map" moves on, which shows it again; the hold time is long so it waits for the picture.
func _loading_shots() -> void:
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	GameLaunch.start_match(ROUNDS_MAP, rules, GameLaunch.rotation_maps())
	var main: Node = await _start_game(true)
	var screen := main.get_node("LoadingScreen") as LoadingScreen
	screen.advance(screen.hold_time)
	await _frames(2)
	main.call("next_map")
	await _frames(10)
	screen.advance(screen.hold_time * 0.59)
	await _frames(4)
	await _shot("loading")
	screen.advance(screen.hold_time)
	await _stop_game(main)


## The multiplayer lobby as the mockup's "06 Lobby" draws it: hosting on a random port (nobody joins, so every other
## slot shows as "Empty / Bot"), then the connect page ("Join") once the session has closed.
func _lobby_shots() -> void:
	var menu: Node = load(GameLaunch.MENU_SCENE).instantiate()
	menu.set("load_settings", false)
	root.add_child(menu)
	await _frames(10)
	menu.call("open_lobby")
	var lobby := menu.call("get_lobby_menu") as LobbyMenu
	lobby.get_name_field().text = "Mara"
	lobby.get_port_field().text = str(28000 + randi() % 900)
	lobby.host_game()
	await _frames(10)
	await _shot("lobby")
	lobby.leave()
	await _frames(60)
	lobby.get_address_field().text = "192.168.1.24"
	await _shot("join")
	lobby.close()
	await _frames(4)
	root.remove_child(menu)
	menu.free()
	MenuState.reset()
	await _frames(2)


## Starts the game scene with what [GameLaunch] says. With [param loading], its loading screen stays on (a long hold time).
func _start_game(loading: bool = false) -> Node:
	var main: Node = load(GameLaunch.GAME_SCENE).instantiate()
	main.set("load_settings", false)
	main.set("loading_screen", loading)
	if loading:
		(main.get_node("LoadingScreen") as LoadingScreen).hold_time = 100.0
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
