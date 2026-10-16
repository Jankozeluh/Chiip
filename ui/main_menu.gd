class_name MainMenu
extends Node
## The main menu, the first thing the game shows (M5 task 11, D-064; it is the
## project's main scene): the game's title and the mode choice (D-132) over a
## slow camera flight across the test map.
##
## - **Team Deathmatch** (first, focused, the default), **Bomb** and **Practice**
##   are big buttons with a line under each saying what they play; one click
##   starts it. The two match modes play your last custom choices (team sizes,
##   difficulty, length, friendly fire, map or rotation) in that mode: they leave
##   a [GameLaunch] description (the map and [MatchSettings]) and change to the
##   game scene. Practice starts the respawning bot arena ([ArenaRules]) on the
##   test map, with the bot difficulty of the custom choices.
## - **Custom match** opens match setup ([MatchSetup]) for those choices; its
##   Start plays them.
## - **Settings** opens the same [SettingsMenu] the game has.
## - **Quit** closes the game.
##
## A mode button is a container holding a [Button] (the click, the focus, the
## look) and, on top of it, two labels that ignore the mouse (the mode's name and
## its line), because a [Button] can only draw one line of text in one size.
## The row of text buttons ([code]Links[/code]) has room for M9's Host and Join.
##
## The background is the test map rendered like the game: a low-resolution world
## in a [SubViewport] with the palette effect, following the video settings
## ([PixelView], shared with main.gd). The map's [code]Player[/code] node is
## removed before the map enters the tree, so there is no player, no camera of
## its own and no mouse capture, and with no rules node nothing happens on the
## map: the bots are never added. A [MenuFlight] moves the camera.
##
## The menu loads the player's settings once at startup ([method Settings.load_from_disk])
## and registers with [MenuState], so the mouse is shown. Esc closes match setup
## or the settings menu, whichever is on top ([MenuState] decides); on the main
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

## The map of the background (without a player).
var _background: Node

@onready var _world: SubViewportContainer = $World
@onready var _viewport: SubViewport = $World/SubViewport
@onready var _palette_effect: CanvasLayer = $World/SubViewport/PaletteEffect
@onready var _flight: MenuFlight = $World/SubViewport/Flight
@onready var _page: CanvasLayer = $Page
@onready var _deathmatch_button: Button = %DeathmatchButton
@onready var _bomb_button: Button = %BombButton
@onready var _practice_button: Button = %PracticeButton
@onready var _custom_button: Button = %CustomButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _setup: MatchSetup = $MatchSetup
@onready var _settings_menu: SettingsMenu = $SettingsMenu


func _ready() -> void:
	var settings := Settings.get_instance()
	if load_settings and not settings.is_loaded():
		var result := settings.load_from_disk()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			push_warning("Chiip: the settings file couldn't be read (error %d), using the defaults." % result)
	if _skip_for_command_line():
		return
	settings.changed.connect(_on_setting_changed)
	_deathmatch_button.pressed.connect(start_mode.bind("respawn"))
	_bomb_button.pressed.connect(start_mode.bind("rounds"))
	_practice_button.pressed.connect(start_practice)
	_custom_button.pressed.connect(open_match_setup)
	_settings_button.pressed.connect(open_settings)
	_quit_button.pressed.connect(get_tree().quit)
	_setup.started.connect(start_match)
	_setup.closed.connect(_custom_button.grab_focus)
	_settings_menu.closed.connect(_settings_button.grab_focus)
	if _setup.settings != settings:
		_setup.settings.changed.connect(_on_setting_changed)
	_build_background()
	get_tree().root.size_changed.connect(apply_pixel_settings)
	apply_pixel_settings()
	_refresh_details()
	MenuState.open(self)
	_deathmatch_button.grab_focus()


func _exit_tree() -> void:
	# The game starts (or the menu is freed): hand the mouse back to the game.
	MenuState.close(self)


## True when the command line [param args] (the arguments after [code]--[/code])
## ask for the game directly: [code]--match[/code], [code]--practice[/code] or [code]--map[/code].
static func wants_game(args: PackedStringArray) -> bool:
	return args.has("--match") or args.has("--practice") or args.has("--map")


## Opens match setup (the Custom match button).
func open_match_setup() -> void:
	_setup.open()


## Opens the settings menu (the Settings button).
func open_settings() -> void:
	_settings_menu.open()


## Leaves the description of the chosen match for main.gd ([GameLaunch]), without
## changing scenes. [method start_match] does this and then changes to the game.
func prepare_match() -> void:
	GameLaunch.start_match(_setup.get_map_path(), _setup.build_match_settings(), _setup.get_rotation_maps())


## Leaves the description of practice for main.gd: the test map, with the bot
## difficulty last chosen in match setup.
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


## Starts the match chosen in match setup (its Start button).
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
	var ui_height := PixelView.apply(Settings.get_instance(), get_tree().root, _world, _palette_effect)
	var factor := ui_height / PixelView.UI_DESIGN_HEIGHT
	UiTheme.apply(_page, factor)
	_setup.set_ui_scale(factor)
	_settings_menu.set_ui_scale(factor)


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


## Writes the line under each mode button from the custom choices.
func _refresh_details() -> void:
	var stored := _setup.settings
	_detail_label(_deathmatch_button).text = MatchSetup.describe_mode(stored, "respawn")
	_detail_label(_bomb_button).text = MatchSetup.describe_mode(stored, "rounds")
	_detail_label(_practice_button).text = "%s%s%s bots\n%s" % ["Bots respawn", MatchSetup.DETAIL_SEPARATOR,
			stored.match_difficulty.capitalize(), GameLaunch.map_title(Settings.DEFAULT_MAP)]


## The line of detail that sits on a mode button.
func _detail_label(button: Button) -> Label:
	return button.get_parent().get_node("Text/Lines/Detail") as Label


func _on_setting_changed(key: StringName) -> void:
	if key == &"pixel_height" or key == &"pixelate_hud" or key == &"palette_effect":
		apply_pixel_settings()
	elif String(key).begins_with("match_"):
		_refresh_details()


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


## The settings menu.
func get_settings_menu() -> SettingsMenu:
	return _settings_menu


## Every button of the main page: the three modes, then Custom match, Settings, Quit.
func get_buttons() -> Array[Button]:
	return [_deathmatch_button, _bomb_button, _practice_button, _custom_button, _settings_button, _quit_button]


## The mode buttons: Team Deathmatch, Bomb, Practice.
func get_mode_buttons() -> Array[Button]:
	return [_deathmatch_button, _bomb_button, _practice_button]


## The name shown on a mode button.
func get_mode_title(button: Button) -> String:
	return (button.get_parent().get_node("Text/Lines/Title") as Label).text


## The line under a mode button.
func get_mode_detail(button: Button) -> String:
	return _detail_label(button).text


## The Custom match button.
func get_custom_button() -> Button:
	return _custom_button


## The Settings button.
func get_settings_button() -> Button:
	return _settings_button
