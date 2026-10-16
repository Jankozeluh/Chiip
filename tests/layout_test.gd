extends Node
## Automated checks that the UI fits any window (M11 "UI in any window and fullscreen", D-151 to D-154).
## Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/layout_test.tscn
##
## The root window is resized to 1280 × 720, 1920 × 1080, 2560 × 1440, 2920 × 1753 (the user's
## editor view that cut the Play screen's sides off), 3440 × 1440, 2560 × 1600 and 1440 × 1080, the
## way a fullscreen switch or a dragged window edge does: by setting [member Window.size], which
## emits [signal Window.size_changed] and so reaches the menus' own wiring (no call to a
## [code]apply_pixel_settings()[/code] here). For each size, in the main menu and in a real game:
##
## - The UI scale is the tighter of width / 1280 and height / 720 ([method PixelView.ui_scale_for]),
##   so a window narrower than 16:9 still gets the whole 1280-wide layout.
## - Every visible control of every menu and of the HUD lies inside the window. Menus are opened one
##   at a time (main page, Play with each mode, every settings tab, the Licences screen, the Stats screen, the lobby; class draft, buy menu,
##   pause, scoreboard, match end, console, loading, boot); a scroll box's contents may run past its
##   edge, the box itself may not.
## - After loading nothing covers the class draft: the loading screen is gone (and the game
##   unpaused) when the draft opens, and no visible layer sits above it.
## - A resize at runtime re-lays everything out: the same menu has the new size's scale after it.
##
## Quits with the number of failed checks as the exit code (0 means everything passed).

const MAIN_MENU_SCENE := preload("res://ui/main_menu.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const BOOT_SCENE := preload("res://ui/boot_screen.tscn")
const TEST_MAP := "res://maps/test_map.tscn"
## The window sizes of the user's screens and the ones a window can be dragged to.
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2920, 1753),
	Vector2i(3440, 1440), Vector2i(2560, 1600), Vector2i(1440, 1080), Vector2i(3840, 2160),
]
## What [method PixelView.ui_scale_for] must answer for each of [constant SIZES].
const SCALES: Array[float] = [1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 1.0, 3.0]
## How far a control may reach past the window, in pixels (rounding of scaled sizes).
const TOLERANCE := 1.5
## How many offenders a failure message lists.
const MAX_LISTED := 4

var _failures: int = 0
## Every window size with the UI scale settings Auto, 50 and 100 percent: [size, percent].
var _cases: Array = []


func _ready() -> void:
	# The shared settings: never read or write the player's file (nothing here calls load_from_disk).
	Settings.get_instance().reset_to_defaults()
	for size in SIZES:
		# Auto, the smallest and the biggest scale (the steps between are the same code).
		for percent in [0, Settings.UI_SCALES[1], Settings.UI_SCALES[-1]]:
			_cases.append([size, percent])
	_test_scale_rule()
	await _test_main_menu(false)
	await _test_main_menu(true)
	await _test_game_rounds()
	await _test_game_respawn()
	await _test_loading_then_draft()
	await _test_boot_screen()
	await _test_studio_mark()
	await _test_resize_relays_out()
	_resize(Vector2i(64, 64))
	Settings.get_instance().reset_to_defaults()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- The scale rule ---


func _test_scale_rule() -> void:
	var wrong: Array[String] = []
	for i in SIZES.size():
		var factor := PixelView.ui_scale_for(Vector2(SIZES[i]))
		if not is_equal_approx(factor, SCALES[i]):
			wrong.append("%s: %.3f instead of %.3f" % [SIZES[i], factor, SCALES[i]])
		# The 1280 × 720 layout always fits: at least 1280 design pixels across and 720 up and down.
		if SIZES[i].x / factor < 1280.0 - 0.01 or SIZES[i].y / factor < 720.0 - 0.01 or fposmod(factor * 2.0, 1.0) > 0.0:
			wrong.append("%s: the layout would be %.0f × %.0f" % [SIZES[i], SIZES[i].x / factor, SIZES[i].y / factor])
	# The UI scale setting (D-181): 100 fills the window exactly, 75 and 50 are smaller, none ever overflows.
	var percents: Array[String] = []
	for size in SIZES:
		var fit := minf(size.x / 1280.0, size.y / 720.0)
		var auto := PixelView.ui_scale_for(Vector2(size), 0)
		var fill := PixelView.ui_scale_for(Vector2(size), 100)
		var three_quarters := PixelView.ui_scale_for(Vector2(size), 75)
		var half := PixelView.ui_scale_for(Vector2(size), 50)
		if not (is_equal_approx(fill, fit) and half <= three_quarters and three_quarters <= auto and auto <= fill and half >= 0.47 and auto >= fit * 0.66):
			percents.append("%s: 50 %% %.2f, 75 %% %.2f, Auto %.2f, 100 %% %.2f (fit %.2f)" % [size, half, three_quarters, auto, fill, fit])
	_check("The UI scale setting: 100 %% is the exact fit, Auto is at most one half step below it (and never under two thirds of it), 75 %% and 50 %% are smaller, none under 0.47 (D-181)",
			percents.is_empty(), "wrong: %s" % [percents])
	_check("The UI scale is the tighter of width / 1280 and height / 720 in half steps (1.5 at 1080p, 2 at 1440p, on the ultrawide and at 2920 × 1753, 1 at 1440 × 1080), so the 1280 × 720 layout always fits and the pixel font stays even",
			wrong.is_empty(), "wrong: %s" % [wrong])


# --- The main menu ---


## The main menu's screens at every size: the page, Play with each mode, every settings tab, the lobby.
## With [param pixelated], the whole window is rendered at the low resolution (the "pixelate HUD" setting).
func _test_main_menu(pixelated: bool) -> void:
	var settings := Settings.get_instance()
	settings.reset_to_defaults()
	settings.pixelate_hud = pixelated
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await _settle(SIZES[0])
	var failures := {}
	var screens := {
		"main page": func() -> void: pass,
		"Play, Team Deathmatch": func() -> void: menu.open_match_setup(); menu.get_match_setup().pick("respawn"),
		"Play, Free-for-all": func() -> void: menu.get_match_setup().pick("ffa"),
		"Play, Bomb": func() -> void: menu.get_match_setup().pick("rounds"),
		"Play, Practice": func() -> void: menu.get_match_setup().pick("practice"),
		"lobby": func() -> void: menu.get_match_setup().close(); menu.open_lobby(),
	}
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		for screen_name: String in screens:
			screens[screen_name].call()
			await _settle(size)
			_collect(failures, "%s at %s" % [screen_name, size], [menu], size)
		menu.get_lobby_menu().close()
		# Every settings tab.
		menu.open_settings()
		var settings_menu := menu.get_settings_menu()
		for tab in settings_menu.get_tab_names().size():
			settings_menu.get_tabs().current_tab = tab
			await _settle(size)
			_collect(failures, "settings tab %d at %s" % [tab, size], [menu], size)
		# With the pad as the device used last the title row gets the LB RB hints and the buttons their glyphs (v0.2, D-238).
		LastInput.gamepad = true
		for tab in [0, settings_menu.get_tab_names().find("Controller")]:
			settings_menu.get_tabs().current_tab = tab
			await _settle(size)
			await get_tree().process_frame
			_collect(failures, "settings tab %d with the pad hints at %s" % [tab, size], [menu], size)
		LastInput.gamepad = false
		# The Licences screen over the settings (M12): the longest document, the GPL, and the engine's.
		var licences := settings_menu.get_licenses_menu()
		licences.open()
		for document in [&"code", &"godot"]:
			licences.show_document(document)
			await _settle(size)
			_collect(failures, "licences (%s) at %s" % [document, size], [menu], size)
		licences.close()
		settings_menu.close()
		# The Stats screen (M14) with a book of matches: every tab (the History table is the widest).
		var stats_menu := menu.get_stats_menu()
		stats_menu.book = _sample_book()
		stats_menu.open()
		for filter in ["all", "rounds", "training"]:
			stats_menu.set_filter(filter)
			await _settle(size)
			_collect(failures, "stats (%s) at %s" % [filter, size], [menu], size)
		stats_menu.set_filter("all")
		stats_menu.open_match(stats_menu.book.history.size() - 1)
		await _settle(size)
		_collect(failures, "stats match detail at %s" % [size], [menu], size)
		stats_menu.close()
		stats_menu.book = null
		menu.get_match_setup().close()
	var label := "pixelated HUD, " if pixelated else ""
	_check("Main menu (%severy screen: main page, Play with each mode, the lobby, all settings tabs, the Licences screen, the Stats page, detail and training) lies inside the window at all %d sizes × UI scales" % [label, _cases.size()],
			failures.is_empty(), _describe(failures))
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame
	settings.reset_to_defaults()
	MenuState.reset()


# --- The game ---


## A bomb game: the HUD with the round bar, the class draft, buy menu, pause menu, scoreboard, match end, console.
func _test_game_rounds() -> void:
	var rules := MatchSettings.new()
	rules.rounds_to_win = 7
	await _test_game("Bomb game", rules)


## A Team Deathmatch game: the HUD with its kill bar, the class draft, the scoreboard.
func _test_game_respawn() -> void:
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	await _test_game("Team Deathmatch game", rules)


func _test_game(game_name: String, rules: MatchSettings) -> void:
	var tree := get_tree()
	GameLaunch.start_match(TEST_MAP, rules)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.loading_screen = false
	add_child(main)
	await _settle(SIZES[0])
	var hud := main.get_node("HUD") as CanvasLayer
	var class_menu := main.get_node("ClassMenu") as ClassMenu
	var buy_menu := main.get_node("BuyMenu") as BuyMenu
	var pause_menu := main.get_pause_menu() as PauseMenu
	var console := main.get_node("DevConsole") as DevConsole
	var board := main.get_node("Scoreboard") as Scoreboard
	var end_screen := main.get_node("MatchEndScreen") as MatchEndScreen
	var failures := {}
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		# 1. The class draft (opens by itself at the match start; M brings it back).
		if not class_menu.is_open():
			class_menu.open()
		await _settle(size)
		_collect(failures, "class draft at %s" % [size], [class_menu], size)
		class_menu.close()
		# 2. The HUD alone.
		await _settle(size)
		_collect(failures, "HUD at %s" % [size], [hud], size)
		# 2b. The compass strip stands clear of the top bar, the toasts and the kill feed (D-180).
		(hud.get_node("Toasts") as ToastStack).show_toast(ToastStack.Kind.MATCH_POINT, "Match point")
		await _settle(size)
		var compass := hud.get_node("Compass") as Control
		var crowded: Array[String] = []
		if not compass.is_visible_in_tree() or compass.size.x <= 0.0:
			crowded.append("the compass isn't showing")
		for other_path in ["RoundHud/TdmBar", "RoundHud/BombBar", "Toasts", "RoundHud/KillFeed", "RoundHud/Center"]:
			var other := hud.get_node(other_path) as Control
			if other.is_visible_in_tree() and other.get_global_rect().size.y > 0.0 and other.get_global_rect().intersects(compass.get_global_rect()):
				crowded.append("%s %s over the compass %s" % [other_path, other.get_global_rect(), compass.get_global_rect()])
		if not crowded.is_empty():
			failures["compass at %s" % [size]] = crowded
		# 2c. The FPS counter and the developer readout (F3), online rows included (v0.2, D-233).
		var overlay := main.get_node("DebugOverlay") as DebugOverlay
		for mode in ["player", "developer"]:
			overlay.set_mode(mode)
			overlay.get_net_row().visible = true
			await _settle(size)
			await get_tree().process_frame
			_collect(failures, "%s overlay at %s" % [mode, size], [overlay], size)
		overlay.set_mode("off")
		# 2d. The Shooting Range's training screens: the run, the result, the spray panel and the start panel (D-236).
		var training_hud := main.get_node("TrainingHud") as TrainingHud
		for screen in ["run", "result", "spray"]:
			training_hud.preview(screen)
			await _settle(size)
			_collect(failures, "training %s at %s" % [screen, size], [training_hud], size)
		training_hud.follow_hub()
		var training_menu := main.get_node("TrainingMenu") as TrainingMenu
		training_menu.visible = true
		await _settle(size)
		_collect(failures, "training start panel at %s" % [size], [training_menu], size)
		training_menu.visible = false
		# 3. The buy menu (freeze time), in a match with rounds.
		if buy_menu.open():
			await _settle(size)
			_collect(failures, "buy menu at %s" % [size], [buy_menu], size)
			buy_menu.close()
		# 4. The pause menu, which also pauses the tree: the test goes on (it is process_mode Always).
		pause_menu.open()
		await _settle(size)
		_collect(failures, "pause menu at %s" % [size], [pause_menu], size)
		pause_menu.close()
		# 5. The Tab scoreboard.
		Input.action_press("scoreboard")
		await _settle(size)
		_collect(failures, "scoreboard at %s" % [size], [board], size)
		Input.action_release("scoreboard")
		# 6. The console.
		console.set_open(true)
		await _settle(size)
		_collect(failures, "console at %s" % [size], [console], size)
		console.set_open(false)
		# 7. The match-end screen.
		var manager := _get_manager(main)
		if manager != null:
			manager.match_ended.emit(Teams.viewer_team)
			await _settle(size)
			_collect(failures, "match end at %s" % [size], [end_screen], size)
			end_screen.visible = false
	_check("%s: the HUD (its compass clear of the top bar and the toasts), the FPS counter and developer overlay, the training screens, class draft, buy menu, pause menu, scoreboard, console and match-end screen lie inside the window at all %d sizes × UI scales" % [game_name, _cases.size()],
			failures.is_empty(), _describe(failures))
	remove_child(main)
	main.queue_free()
	await tree.process_frame
	_reset_game_state()


## The round manager of the game's map (a RoundManager, or its RespawnMatch), or null.
func _get_manager(main: Node) -> RoundManager:
	for child in main.get_map().get_children():
		if child is RoundManager:
			return child as RoundManager
	return null


func _reset_game_state() -> void:
	Input.action_release("scoreboard")
	Teams.friendly_fire = false
	GameLaunch.clear()
	MenuState.reset()
	get_tree().paused = false


# --- Loading, then the class draft ---


## After loading the screen is gone and nothing covers the class draft (D-152), and in every window size
## the loading screen itself lies inside the window.
func _test_loading_then_draft() -> void:
	var tree := get_tree()
	LoadingScreen.enabled = true
	var rotation: Array[String] = ["res://maps/depot.tscn", "res://maps/square.tscn", "res://maps/spillway.tscn"]
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	GameLaunch.start_match(rotation[1], rules, rotation)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	var screen := main.get_node("LoadingScreen") as LoadingScreen
	screen.hold_time = 0.5
	add_child(main)
	await _settle(SIZES[3])
	var class_menu := main.get_node("ClassMenu") as ClassMenu
	var showing := LoadingScreen.is_showing()
	var draft_under_band := class_menu.is_open()
	var failures := {}
	# The band at every size (the game is paused under it; the test goes on).
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		await _settle(size)
		_collect(failures, "loading screen at %s" % [size], [screen], size)
	_check("The loading screen (\"Map 1 of 3 · Rotation\", Square) lies inside the window at all %d sizes × UI scales and the class draft is still closed under it" % _cases.size(),
			showing and not draft_under_band and failures.is_empty(), "showing %s, draft open under the band %s, %s" % [showing, draft_under_band, _describe(failures)])
	screen.advance(100.0)
	await _settle(SIZES[3])
	var covering := _layers_above(main, class_menu.layer)
	_check("Once the map is loaded the loading screen is gone and the game unpaused, the class draft is open, and no visible layer sits above it",
			not LoadingScreen.is_showing() and not screen.visible and not tree.paused and class_menu.is_open() and covering.is_empty(),
			"showing %s, paused %s, draft open %s, visible layers above the draft (layer %d): %s" % [LoadingScreen.is_showing(), tree.paused, class_menu.is_open(), class_menu.layer, covering])
	var layers_ok := screen.layer > class_menu.layer
	_check("The loading screen is a layer above every menu (it hides them while it is up) and the boot screen above that", layers_ok
			and (BOOT_SCENE.instantiate() as CanvasLayer).layer > screen.layer, "loading layer %d, draft layer %d" % [screen.layer, class_menu.layer])
	remove_child(main)
	main.queue_free()
	await tree.process_frame
	LoadingScreen.enabled = true
	_reset_game_state()


## The visible canvas layers of [param root] above [param layer] (the loading and boot screens are
## hidden after their time; a layer that is visible there would cover the draft).
func _layers_above(root: Node, layer: int) -> Array[String]:
	var found: Array[String] = []
	for child in root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible and (child as CanvasLayer).layer > layer:
			found.append("%s (layer %d)" % [child.name, (child as CanvasLayer).layer])
	return found


# --- The boot screen ---


## The boot screen lies inside the window at every size, shows the game's name while the logo file is
## missing and the picture when there is one, fills its squares and finishes on a key.
func _test_boot_screen() -> void:
	var screen := BOOT_SCENE.instantiate() as BootScreen
	add_child(screen)
	# The studio's own logo (112 × 112) is in the project, with its half-size copy.
	var big := BootScreen.load_logo()
	var small := BootScreen.load_small_logo()
	_check("The studio's logo files are in the project: studio_logo.png 112 × 112 and its half-size copy 56 × 56",
			big != null and small != null and big.get_size() == Vector2(112, 112) and small.get_size() == Vector2(56, 56),
			"big %s, small %s" % [big, small])
	var failures := {}
	screen.show_screen()
	var shows_logo := screen.get_logo().visible and not screen.get_wordmark().visible and screen.get_studio_name_label().text == "DIVOCAKOS"
	var whole_steps: Array[String] = []
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		screen.set_ui_scale(PixelView.ui_scale_for(Vector2(size), percent))
		await _settle(size)
		_collect(failures, "boot screen at %s" % [size], [screen], size)
		# The picture is a whole multiple of its 112 pixels at every UI scale of the half steps: 224 design pixels × scale.
		var multiple := screen.get_logo().get_global_rect().size.x / 112.0
		if percent == 0 and not is_equal_approx(multiple, roundf(multiple)):
			whole_steps.append("%s: %.2f×" % [size, multiple])
	_check("The boot screen (the logo with \"Divocakos\" under it) lies inside the window at all %d sizes × UI scales, and (at Auto) the logo is a whole multiple of its pixels at each" % _cases.size(),
			failures.is_empty() and shows_logo and whole_steps.is_empty(), "logo shown %s, uneven: %s, %s" % [shows_logo, whole_steps, _describe(failures)])
	screen.finish()
	# Without the logo file the game's name stands in.
	BootScreen.logo_path = "res://assets/ui/no_such_logo.png"
	screen.show_screen()
	var wordmark_without_logo := screen.get_wordmark().visible and not screen.get_logo().visible
	failures = {}
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		screen.set_ui_scale(PixelView.ui_scale_for(Vector2(size), percent))
		await _settle(size)
		_collect(failures, "boot screen without a logo at %s" % [size], [screen], size)
	_check("Without the logo file the boot screen shows the game's name instead and still lies inside the window at all %d sizes × UI scales (D-153)" % _cases.size(),
			failures.is_empty() and wordmark_without_logo, "wordmark shown without a logo: %s, %s" % [wordmark_without_logo, _describe(failures)])
	screen.finish()
	BootScreen.logo_path = "res://icon.svg"
	screen.show_screen()
	await _settle(SIZES[0])
	var picture_with_logo := screen.get_logo().visible and screen.get_logo().texture != null and not screen.get_wordmark().visible
	var edge := screen.get_logo().get_global_rect()
	var square := is_equal_approx(edge.size.x, edge.size.y)
	screen.advance(screen.hold_time * 0.5)
	var half := screen.get_done_chips()
	var finished := [false]
	screen.finished.connect(func() -> void: finished[0] = true)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check("With a logo file the picture shows (square, no game's name), the squares fill with time (2 of 4 at half time), and a key skips the screen",
			picture_with_logo and square and half == 2 and finished[0] and not screen.visible and not screen.is_showing(),
			"picture %s, square %s, %d done at half, finished %s" % [picture_with_logo, square, half, finished[0]])
	BootScreen.logo_path = "res://assets/ui/studio_logo.png"
	remove_child(screen)
	screen.queue_free()


## The main menu's corner mark: 56 pixels times the whole part of the UI scale, from the half-size logo at odd
## steps and the full logo at even ones (so the picture is drawn at a whole multiple), the map's name beside it,
## both inside the window.
func _test_studio_mark() -> void:
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await _settle(SIZES[0])
	var mark := menu.get_node("Page/StudioMark") as TextureRect
	var name_label := menu.get_node("Page/MapName") as Label
	var wrong: Array[String] = []
	for case in _cases:
		var size: Vector2i = case[0]
		var percent: int = case[1]
		Settings.get_instance().ui_scale = percent
		_resize(size)
		await _settle(size)
		var steps := maxi(1, floori(PixelView.ui_scale_for(Vector2(size), percent)))
		var rect := mark.get_global_rect()
		var texture := mark.texture
		var multiple := rect.size.x / texture.get_size().x if texture != null else 0.0
		var beside := name_label.get_global_rect().end.x <= rect.position.x and name_label.get_global_rect().end.y <= rect.end.y
		if not mark.visible or rect.size != Vector2(56 * steps, 56 * steps) or not is_equal_approx(multiple, roundf(multiple)) or not beside:
			wrong.append("%s: visible %s, %s, %.2f×, name beside %s" % [size, mark.visible, rect.size, multiple, beside])
	var credit := menu.get_node("Page/Build") as Label
	_check("The main menu's corner mark is the studio logo at a whole multiple of its picture (56 px × the UI scale's whole part), with the map's name beside it, and the footer names \"Divocakos\"",
			wrong.is_empty() and credit.text.contains("Divocakos"), "wrong: %s, footer '%s'" % [wrong, credit.text])
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame
	MenuState.reset()


# --- A resize at runtime ---


## Resizing the window (a fullscreen switch does the same) re-lays out the menus without anybody calling them.
func _test_resize_relays_out() -> void:
	var settings := Settings.get_instance()
	settings.reset_to_defaults()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await _settle(SIZES[0])
	var play := menu.get_buttons()[0]
	var sizes_seen: Dictionary = {}
	for size in SIZES:
		_resize(size)
		sizes_seen[size] = play.get_theme_font_size("font_size")
	var grows: bool = sizes_seen[SIZES[1]] > sizes_seen[SIZES[0]] and sizes_seen[SIZES[2]] > sizes_seen[SIZES[1]]
	# Half steps: the user's 2920 × 1753 (width-bound, 2.28) gets 2×, the same text as 1440p; 1440 × 1080 (1.125) gets 1×.
	var bound_by_width: bool = sizes_seen[SIZES[3]] == sizes_seen[SIZES[2]] and sizes_seen[SIZES[6]] == sizes_seen[SIZES[0]]
	# A narrower window back at 16:9 gives the 1280 × 720 text size again.
	_resize(SIZES[0])
	var back: bool = play.get_theme_font_size("font_size") == sizes_seen[SIZES[0]]
	# Going fullscreen is a mode switch: in a headless run it keeps the size, but the same signal path runs.
	get_tree().root.size_changed.emit()
	_check("A runtime resize re-lays the menu out by itself (item text %s px at 1280 × 720, %s at 1080p, %s at 1440p, %s at 2920 × 1753 and 1440p alike, 1440 × 1080 as 720p), and going back restores it" % [
			sizes_seen[SIZES[0]], sizes_seen[SIZES[1]], sizes_seen[SIZES[2]], sizes_seen[SIZES[3]]],
			grows and bound_by_width and back, "grows %s, whole steps %s, back %s" % [grows, bound_by_width, back])
	# The UI scale setting reaches the menu live (no restart, no resize): Auto 2×, 100 % fills 2.28×, 70 % 1.5×, 50 % 1×.
	_resize(SIZES[3])
	var by_percent: Array[int] = []
	for percent in [0, 50, 70, 100]:
		Settings.get_instance().ui_scale = percent
		by_percent.append(play.get_theme_font_size("font_size"))
	Settings.get_instance().ui_scale = 0
	var auto_again := play.get_theme_font_size("font_size")
	_check("Changing the UI scale setting re-lays the menu out at once: at 2920 × 1753 the item text is %s px for Auto, 50, 70 and 100 %% (fills the window: 2.28×), and Auto again gives %d" % [by_percent, auto_again],
			by_percent[0] == 64 and by_percent[1] == 32 and by_percent[2] == 48 and by_percent[3] == roundi(32.0 * 2920.0 / 1280.0) and auto_again == 64,
			"item text %s, Auto again %d" % [by_percent, auto_again])
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame
	MenuState.reset()


# --- Helpers ---


## Sets the root window's size the way a user does: [member Window.size] emits [signal Window.size_changed].
func _resize(size: Vector2i) -> void:
	get_tree().root.size = size


## Waits for the layout to settle, putting the window size back when a headless run has snapped it back.
func _settle(size: Vector2i) -> void:
	# A real window says "resized" again once it has its new size; setting the size here says it inside the setter.
	get_tree().root.size_changed.emit()
	for i in 3:
		await get_tree().process_frame
		if get_tree().root.size != size:
			_resize(size)


## Adds to [param failures] ([param label] → the offenders) the visible controls below [param roots] that
## are not inside the root window's visible area.
func _collect(failures: Dictionary, label: String, roots: Array, size: Vector2i) -> void:
	var bounds := get_tree().root.get_visible_rect()
	var percent := Settings.get_instance().ui_scale
	if percent != 0:
		label += ", UI scale %d %%" % percent
	var offenders: Array[String] = []
	for root: Node in roots:
		_scan(root, bounds.grow(TOLERANCE), offenders)
	if get_tree().root.size != size:
		offenders.append("the window is %s, not %s" % [get_tree().root.size, size])
	if not offenders.is_empty():
		failures[label] = offenders


func _scan(node: Node, bounds: Rect2, offenders: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	# The 3D world and the popups are other viewports.
	if node is Viewport:
		return
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0 and not bounds.encloses(rect):
			offenders.append("%s %s" % [_short_path(control), rect])
		# A scroll box's contents may run past its edge; the box itself was checked.
		if control is ScrollContainer:
			return
	for child in node.get_children():
		_scan(child, bounds, offenders)


## A node's path from its scene's root, for messages.
func _short_path(node: Node) -> String:
	var names: Array[String] = []
	var current := node
	while current != null and current != self and names.size() < 6:
		names.push_front(String(current.name))
		current = current.get_parent()
	return "/".join(names)


func _describe(failures: Dictionary) -> String:
	if failures.is_empty():
		return "all inside"
	var lines: Array[String] = []
	for label: String in failures:
		var offenders: Array = failures[label]
		lines.append("%s: %s%s" % [label, ", ".join(offenders.slice(0, MAX_LISTED)), " ..." if offenders.size() > MAX_LISTED else ""])
	return "%d screens outside — %s" % [failures.size(), " | ".join(lines.slice(0, 3))]


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1


## A book of twelve matches (bomb and Team Deathmatch, wins and losses, six guns) and two training
## bests, for the Stats screen to lay out: every tab has its widest content.
func _sample_book() -> StatsBook:
	var book := StatsBook.new()
	var guns := ["rifle", "carbine", "smg", "shotgun", "sniper", "pistol"]
	for index in 12:
		var record := StatsMatch.new()
		record.date = 1_792_000_000 + index * 5000
		record.mode = StatsMatch.MODE_ROUNDS if index % 2 == 0 else StatsMatch.MODE_RESPAWN
		record.map = ["depot", "square", "spillway"][index % 3]
		record.result = StatsMatch.WIN if index % 3 != 0 else StatsMatch.LOSS
		record.kills = 10 + index
		record.deaths = 8 + index % 5
		record.damage = 1500.0 + index * 40.0
		record.rounds = 20 if index % 2 == 0 else 0
		record.duration = 900.0
		record.headshot_kills = index
		for gun: String in guns:
			var weapon := StatsWeapon.new()
			weapon.add_shots(100 + index)
			for hit in 30 + index:
				weapon.add_hit(Hitbox.Zone.values()[hit % Hitbox.Zone.size()])
			weapon.kills = 4 + index
			weapon.damage = 600.0
			record.weapons[gun] = weapon
		record.kills_per_minute = [3, 2, 4, 1, 3, 2, 3, 2, 2, 2, 3, 1, 2, 4, 2] as Array[int]
		record.deaths_per_minute = [1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 2, 2, 1, 2, 1] as Array[int]
		book.add_match(record)
	book.submit_best("aim_flick_rifle", 4200.0, {"hits": 31, "accuracy": 62.5})
	book.submit_best("aim_flick_smg", 3900.0, {"hits": 28})
	return book
