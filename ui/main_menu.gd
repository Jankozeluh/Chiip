class_name MainMenu
extends Node
## The main menu, the first thing the game shows (M5 task 11, D-064; it is the
## project's main scene; the mockup's "02 Main menu" since M10, D-135): a dark
## column on the left with the game's name and its three chips, the menu items
## **Play** (focused), **Practice**, **Stats**, **Settings** and **Quit**, a line, and
## **Host** and **Join** (the online games of M9), over a slow camera flight
## across the test map; the build at the bottom left and the map's name at the
## bottom right (the build reads the project's version, M12).
##
## - **Play** opens the Play screen ([MatchSetup]): three mode cards (Team
##   Deathmatch first) and the picked mode's custom rows. Playing a match leaves a
##   [GameLaunch] description (the map and [MatchSettings]) and changes to the
##   game scene; playing Practice starts the respawning bot arena ([ArenaRules])
##   on the test map, with the bot difficulty of the custom rows.
## - **Practice** starts that arena at once.
## - **Host** and **Join** open the lobby ([LobbyMenu], M9). Host opens it and starts
##   hosting at once with the name and port last used (a problem, such as a port in use,
##   shows on the lobby's connect page); Join opens its connect page with the address
##   field focused. Closing the lobby gives the focus back to the item that opened it.
##   When the menu starts with an online session still running (back from an online match)
##   or with a reason an online game ended ([member GameLaunch.notice]), it opens the lobby
##   by itself.
## - **Stats** opens the [StatsMenu] (M14): lifetime numbers, weapons, history and training bests.
## - **Settings** opens the same [SettingsMenu] the game has.
## - **Quit** closes the game.
##
## The background is the test map rendered like the game: a low-resolution world
## in a [SubViewport] with the palette effect, following the video settings
## ([PixelView], shared with main.gd). The map's [code]Player[/code] node is
## removed before the map enters the tree, so there is no player, no camera of
## its own and no mouse capture, and with no rules node nothing happens on the
## map: the bots are never added. A [MenuFlight] moves the camera.
##
## The menu loads the player's settings once at startup ([method Settings.load_from_disk])
## and registers with [MenuState], so the mouse is shown. Esc closes match setup,
## the lobby or the settings menu, whichever is on top ([MenuState] decides); on the main
## page it does nothing.
##
## The command line skips the menu: [code]-- --match[/code], [code]-- --practice[/code]
## or [code]-- --map <scene>[/code] go straight to the game scene, which reads the
## same arguments (once: coming back from that game, the menu shows).

## The map the background shows. Not the map you will play: that is match setup's choice.
@export var map_scene: PackedScene = preload("res://maps/test_map.tscn")
## Read the player's settings file ([method Settings.load_from_disk]) at startup
## unless it was read already, and save every change to it. Tests that load this
## scene turn it off so they never touch the real file.
@export var load_settings: bool = true

## Becomes true once the command line has been looked at, so that a game started
## with a shortcut and left for the menu shows the menu instead of starting again.
static var _command_line_checked: bool = false
## The same for the online shortcuts ([code]--host[/code], [code]--join[/code]).
static var _online_command_line_checked: bool = false

## The map of the background (without a player).
var _background: Node
## The item (Host or Join) that opened the lobby: it gets the focus back when the lobby closes.
var _lobby_opener: Button

@onready var _world: SubViewportContainer = $World
@onready var _viewport: SubViewport = $World/SubViewport
@onready var _palette_effect: CanvasLayer = $World/SubViewport/PaletteEffect
@onready var _flight: MenuFlight = $World/SubViewport/Flight
@onready var _page: CanvasLayer = $Page
@onready var _play_button: Button = %PlayButton
@onready var _practice_button: Button = %PracticeButton
@onready var _stats_button: Button = %StatsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _map_name: Label = %MapName
@onready var _build_label: Label = %Build
@onready var _studio_mark: TextureRect = %StudioMark
@onready var _boot: BootScreen = %BootScreen
@onready var _setup: MatchSetup = $MatchSetup
@onready var _lobby: LobbyMenu = $LobbyMenu
@onready var _settings_menu: SettingsMenu = $SettingsMenu
@onready var _stats_menu: StatsMenu = $StatsMenu


func _ready() -> void:
	var settings := Settings.get_instance()
	# -- --no-settings: scripted runs (the two-process online check) leave your settings file alone.
	if load_settings and not settings.is_loaded() and not OS.get_cmdline_user_args().has("--no-settings"):
		var result := settings.load_from_disk()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			push_warning("Chiip: the settings file couldn't be read (error %d), using the defaults." % result)
		# Your match history (M14, D-200) is read with the settings, under the same guards.
		StatsBook.get_instance().load_from_disk()
	if _skip_for_command_line():
		return
	settings.changed.connect(_on_setting_changed)
	_play_button.pressed.connect(open_match_setup)
	_host_button.pressed.connect(host_online)
	_join_button.pressed.connect(join_online)
	_practice_button.pressed.connect(start_practice)
	_stats_button.pressed.connect(open_stats)
	_settings_button.pressed.connect(open_settings)
	_quit_button.pressed.connect(get_tree().quit)
	_setup.started.connect(start_picked)
	_setup.closed.connect(_play_button.grab_focus)
	_lobby.closed.connect(_on_lobby_closed)
	_settings_menu.closed.connect(_settings_button.grab_focus)
	_stats_menu.closed.connect(_stats_button.grab_focus)
	_map_name.text = GameLaunch.map_title(map_scene.resource_path)
	_build_label.text = "Build %s · Divocakos" % ProjectSettings.get_setting("application/config/version", "")
	_build_background()
	get_tree().root.size_changed.connect(apply_pixel_settings)
	apply_pixel_settings()
	MenuState.open(self)
	_play_button.grab_focus()
	_show_boot_screen()
	# Back from an online match, or from one that ended: the lobby (or the reason) comes first.
	var session := NetLobby.find_session(get_tree())
	if (session != null and session.is_active()) or not GameLaunch.notice.is_empty():
		open_lobby()
	# Deferred: the root is still busy adding the menu, so a session couldn't join it yet.
	_go_online_for_command_line.call_deferred()


func _exit_tree() -> void:
	# The game starts (or the menu is freed): hand the mouse back to the game.
	MenuState.close(self)


## True when the command line [param args] (the arguments after [code]--[/code])
## ask for the game directly: [code]--match[/code], [code]--practice[/code] or [code]--map[/code].
static func wants_game(args: PackedStringArray) -> bool:
	return args.has("--match") or args.has("--practice") or args.has("--map")


## Opens the Play screen (the Play button).
func open_match_setup() -> void:
	_setup.open()


## Opens the multiplayer lobby: the connect page, or the lobby page when an online session is
## running.
func open_lobby() -> void:
	_lobby.open()


## The Host item: opens the lobby and starts hosting with the name and port in its fields. A
## failure (a port in use) shows on the lobby's connect page.
func host_online() -> void:
	_lobby_opener = _host_button
	open_lobby()
	_lobby.host_game()


## The Join item: opens the lobby's connect page with the address field focused.
func join_online() -> void:
	_lobby_opener = _join_button
	open_lobby()
	if _lobby.get_page() == LobbyMenu.Page.CONNECT:
		_lobby.get_address_field().grab_focus()


## Opens the settings menu (the Settings button).
func open_settings() -> void:
	_settings_menu.open()


## Opens the Stats screen (the Stats button, M14).
func open_stats() -> void:
	_stats_menu.open()


## Leaves the description of the chosen match for main.gd ([GameLaunch]), without
## changing scenes. [method start_match] does this and then changes to the game.
func prepare_match() -> void:
	GameLaunch.start_match(_setup.get_map_path(), _setup.build_match_settings(), _setup.get_rotation_maps())


## Leaves the description of practice for main.gd: the practice map (the Shooting Range,
## D-141), with the bot difficulty last chosen in match setup.
func prepare_practice() -> void:
	GameLaunch.start_practice(Settings.DEFAULT_MAP, GameLaunch.difficulty_named(_setup.settings.match_difficulty))


## Leaves the description of a match in [param mode] ("respawn" for Team
## Deathmatch, "rounds" for Bomb) with the other custom choices, and stores the
## mode as the last one chosen, without changing scenes.
func prepare_mode(mode: String) -> void:
	_setup.settings.match_mode = mode
	prepare_match()


## Starts a match in [param mode] with the custom choices (the Team Deathmatch
## and Bomb buttons).
func start_mode(mode: String) -> void:
	prepare_mode(mode)
	_enter_game()


## Plays the mode picked on the Play screen (its Play button, or a click on the
## picked card): practice, or a match with the custom choices.
func start_picked() -> void:
	if _setup.get_picked_mode() == "practice":
		start_practice()
	else:
		start_match()


## Starts the match chosen on the Play screen.
func start_match() -> void:
	prepare_match()
	_enter_game()


## Starts practice (the Practice button).
func start_practice() -> void:
	prepare_practice()
	_enter_game()


## Applies the pixel settings to the background and scales the menus
## ([PixelView], like main.gd does for the game). Runs at startup, when the
## video settings change and when the window is resized.
func apply_pixel_settings() -> void:
	var factor := PixelView.apply(Settings.get_instance(), get_tree().root, _world, _palette_effect)
	UiTheme.apply(_page, factor)
	_setup.set_ui_scale(factor)
	_lobby.set_ui_scale(factor)
	_settings_menu.set_ui_scale(factor)
	_stats_menu.set_ui_scale(factor)
	_boot.set_ui_scale(factor)
	_place_studio_mark(factor)


## Puts the studio's mark in the bottom right corner with the map's name to its left (the mockup's
## 56 × 56 mark, D-153), at a whole multiple of its picture so the pixels stay even: 56 px on the
## half-size logo at UI scales 1 and 1.5, 112 px on the full logo at 2 and 2.5, and so on. Without the logo
## files the mark stays hidden and the name sits in the corner. Runs after every [method UiTheme.apply], which
## puts the scene's own offsets back.
func _place_studio_mark(factor: float) -> void:
	var steps := maxi(1, floori(factor))
	var logo := BootScreen.load_logo() if steps % 2 == 0 else BootScreen.load_small_logo()
	_studio_mark.texture = logo
	_studio_mark.visible = logo != null
	var side := 56.0 * steps
	var edge := roundf(32.0 * factor)
	_studio_mark.offset_right = -edge
	_studio_mark.offset_bottom = -edge
	_studio_mark.offset_left = -edge - side
	_studio_mark.offset_top = -edge - side
	# The name is centred on the mark and 16 px (at 720p) from it.
	var height := roundf(21.0 * factor)
	var right := -edge - ((side + roundf(16.0 * factor)) if logo != null else 0.0)
	var bottom := -edge - (roundf((side - height) / 2.0) if logo != null else 0.0)
	_map_name.offset_right = right
	_map_name.offset_left = right - roundf(400.0 * factor)
	_map_name.offset_bottom = bottom
	_map_name.offset_top = bottom - height


## The boot screen (D-153) shows once per run, over the menu, when the game starts on the menu.
func _show_boot_screen() -> void:
	var args := OS.get_cmdline_user_args()
	if BootScreen.is_due() and not args.has("--host") and not args.has("--join"):
		_boot.show_screen()


## Replaces the menu with the game scene.
func _enter_game() -> void:
	get_tree().change_scene_to_file(GameLaunch.GAME_SCENE)


## With [code]-- --match[/code], [code]--practice[/code] or [code]--map[/code] on
## the command line (the first time the menu starts) the menu goes straight to
## the game. Returns true then.
func _skip_for_command_line() -> bool:
	if _command_line_checked:
		return false
	_command_line_checked = true
	if wants_game(OS.get_cmdline_user_args()):
		_enter_game.call_deferred()
		return true
	return false


## For trying online play with two windows on one Mac (M9): [code]-- --host[/code] opens the
## lobby and hosts, [code]-- --join <address>[/code] joins that host, and [code]--name <name>[/code]
## plays under that name ([code]--port <port>[/code] on another port); [code]--start <players>[/code]
## makes the host start the match by itself once that many players are in the lobby. Only at the
## first start, like the other shortcuts.
func _go_online_for_command_line() -> void:
	if _online_command_line_checked:
		return
	_online_command_line_checked = true
	var args := OS.get_cmdline_user_args()
	var join_at := args.find("--join")
	var joining := join_at >= 0 and join_at + 1 < args.size()
	if not args.has("--host") and not joining:
		return
	# The lobby fills its fields from the settings when it opens: the shortcuts' values go in after.
	open_lobby()
	var name_at := args.find("--name")
	if name_at >= 0 and name_at + 1 < args.size():
		_lobby.get_name_field().text = args[name_at + 1]
	var port_at := args.find("--port")
	if port_at >= 0 and port_at + 1 < args.size():
		_lobby.get_port_field().text = args[port_at + 1]
	if joining:
		_lobby.get_address_field().text = args[join_at + 1]
		_lobby.join_game()
		return
	if _lobby.host_game() != OK:
		return
	var start_at := args.find("--start")
	if start_at >= 0 and start_at + 1 < args.size() and args[start_at + 1].is_valid_int():
		var wanted := int(args[start_at + 1])
		var session := _lobby.get_session()
		session.roster_changed.connect(func() -> void:
			if session.get_players().size() >= wanted and not NetLobby.of(session).in_game:
				_lobby.start_match())


## Puts the test map into the world viewport, without its player: the map is
## taken apart before it enters the tree, so nothing of the player (camera, mouse
## capture, input) ever runs. No game rules are added either: nobody plays.
func _build_background() -> void:
	_background = map_scene.instantiate()
	var player := _background.get_node_or_null("Player")
	if player != null:
		_background.remove_child(player)
		player.free()
	_viewport.add_child(_background)


## The lobby closed: the focus goes back to Host or Join, whichever opened it.
func _on_lobby_closed() -> void:
	(_lobby_opener if _lobby_opener != null else _host_button).grab_focus()


func _on_setting_changed(key: StringName) -> void:
	if key == &"pixel_height" or key == &"pixelate_hud" or key == &"palette_effect" or key == &"ui_scale":
		apply_pixel_settings()


# --- Test hooks ---


## The map of the background, or null before the menu is ready.
func get_background() -> Node:
	return _background


## The camera flight.
func get_flight() -> MenuFlight:
	return _flight


## Match setup.
func get_match_setup() -> MatchSetup:
	return _setup


## The multiplayer lobby.
func get_lobby_menu() -> LobbyMenu:
	return _lobby


## The settings menu.
func get_settings_menu() -> SettingsMenu:
	return _settings_menu


## The Stats screen.
func get_stats_menu() -> StatsMenu:
	return _stats_menu


## The Stats button.
func get_stats_button() -> Button:
	return _stats_button


## The main page's menu items: Play, Practice, Stats, Settings, Quit.
func get_buttons() -> Array[Button]:
	return [_play_button, _practice_button, _stats_button, _settings_button, _quit_button]


## Host and Join, the two small items under the line.
func get_online_buttons() -> Array[Button]:
	return [_host_button, _join_button]


## The Settings button.
func get_settings_button() -> Button:
	return _settings_button
