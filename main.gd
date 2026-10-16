extends Node
## The game's root scene: loads a map, renders the 3D world at a low
## resolution inside a SubViewport and scales it up with sharp pixels, with
## the HUD, debug overlay, hold-Tab scoreboard, class menu, pause menu, match-end screen,
## settings menu and developer console on top.
##
## The game starts from the main menu (ui/main_menu.tscn, the project's main
## scene), which leaves a [GameLaunch] description for [method _load_map] to read
## (D-064); started directly, with the command-line shortcuts or by a test, it
## uses its exported values below. The pause menu's "Leave" button, the match-end
## screen's "Main menu" button and the console's [code]disconnect[/code] come back
## to the menu with [method return_to_menu].
##
## With a map rotation (D-087: match setup's "Rotation", or [code]-- --rotation[/code])
## the match-end screen also offers "Next map": [method next_map] plays the
## rotation's next map, a fresh match by the same rules.
##
## Every map scene must contain a [Character] node named "Player" (the local player).
## Maps hold only the level: geometry, navigation and markers. The game rules
## are added here, depending on [member mode]: a match on maps with attack and
## defend spawns (a [RoundManager], or a [RespawnMatch] when
## [member MatchSettings.game_mode] is team respawn), practice ([ArenaRules]:
## bots that respawn) on other maps with navigation, and nothing (free roaming)
## on the rest.
##
## Online (M9, D-100): with a [member net_session] the match is played over the network. On
## the host the rules run as offline and a [NetHost] adds the friends' characters and keeps the
## clients up to date; on a client the rules are a replica (D-105) and a [NetClient] shows the
## host's game and drives this computer's player. The map's "Player" node is renamed after the
## player then.
##
## Two pixel styles (see docs/DECISIONS.md):
## - Pixelated HUD: the whole window renders at the low resolution, HUD included.
## - Sharp HUD: only the world is low-res; the HUD uses the full window resolution.

## What to play on the map.
enum Mode {
	## Rounds with two teams (you plus bot teammates against bots).
	MATCH,
	## Today's bot arena: bots respawn, no rounds. For warm-ups and testing.
	PRACTICE,
}

## The HUD and overlay are laid out for a window this many pixels tall.
const UI_DESIGN_HEIGHT := PixelView.UI_DESIGN_HEIGHT

## The map to play. The main menu's match setup overrides it with its choice
## ([GameLaunch]); from the command line, [code]-- --map <scene>[/code] does:
## [code]Godot --path . -- --map res://maps/comparison/csg_room.tscn[/code]
@export var map_scene: PackedScene = preload("res://maps/test_map.tscn")
## Match or practice. The menu's Play and Practice choose; [code]-- --practice[/code]
## on the command line picks practice (a match is the default).
@export var mode: Mode = Mode.MATCH
## The rules of a match: team sizes, bot skill, length, friendly fire.
@export var match_settings: MatchSettings = MatchSettings.new()
## Read the player's settings file ([method Settings.load_from_disk]) when the
## game starts (unless the main menu already did), and save every change to it.
## Tests that load this scene turn it off so they never touch the real file.
@export var load_settings: bool = true

## Online (M9): the session this match is played in, or null offline. The lobby leaves it in
## [member GameLaunch.net_session]; the network tests set it before the scene enters the tree.
var net_session: NetSession

@onready var _world: SubViewportContainer = $World
@onready var _viewport: SubViewport = $World/SubViewport
@onready var _hud: Node = $HUD
@onready var _debug_overlay: Node = $DebugOverlay
@onready var _palette_effect: CanvasLayer = $World/SubViewport/PaletteEffect
@onready var _console: DevConsole = $DevConsole
@onready var _scoreboard: Scoreboard = $Scoreboard
@onready var _match_end_screen: MatchEndScreen = $MatchEndScreen
@onready var _pause_menu: PauseMenu = $PauseMenu
@onready var _settings_menu: SettingsMenu = $SettingsMenu
@onready var _class_menu: ClassMenu = $ClassMenu

## The map currently loaded.
var _map: Node
## The map's player node (the player at this computer).
var _player: Character
## Online: the [NetHost] or [NetClient] of the current map, or null offline.
var _net_game: Node
## The maps of the rotation (empty without one), and which of them is playing.
var _rotation: Array[String] = []
var _rotation_index: int = 0


func _ready() -> void:
	var settings := Settings.get_instance()
	if load_settings and not settings.is_loaded():
		var result := settings.load_from_disk()
		if result != OK and result != ERR_FILE_NOT_FOUND:
			push_warning("Chiip: the settings file couldn't be read (error %d), using the defaults." % result)
	settings.changed.connect(_on_setting_changed)
	_console.main = self
	# Menu buttons tick and click (D-084).
	UiSounds.attach(_match_end_screen)
	_match_end_screen.play_again_pressed.connect(restart_match)
	_match_end_screen.next_map_pressed.connect(next_map)
	_match_end_screen.main_menu_pressed.connect(return_to_menu)
	# The pause menu (D-065): Settings opens the settings menu over it, Leave goes
	# back to the main menu, and the menu comes back when the settings close.
	_pause_menu.settings_pressed.connect(open_settings)
	_pause_menu.leave_pressed.connect(return_to_menu)
	_settings_menu.closed.connect(_pause_menu.settings_closed)
	_load_map()
	get_tree().root.size_changed.connect(apply_pixel_settings)
	apply_pixel_settings()


## The map currently loaded.
func get_map() -> Node:
	return _map


## The player at this computer: the map's player node (online it is renamed after the player).
func get_player() -> Character:
	return _player


## Online: the current map's [NetHost] (on the host) or [NetClient] (on a client); null offline.
func get_net_game() -> Node:
	return _net_game


## Opens the settings menu over the game (console: settings, and the pause
## menu's Settings button). The main menu opens the same menu; it reports back
## with its [signal SettingsMenu.closed].
func open_settings() -> void:
	_settings_menu.open()


## The settings menu, so a menu that wants to know when it closes can connect to it.
func get_settings_menu() -> SettingsMenu:
	return _settings_menu


## The pause menu (Esc).
func get_pause_menu() -> PauseMenu:
	return _pause_menu


## Replaces the current map with the scene at [param path] (console: map).
func change_map(path: String) -> void:
	if _map != null:
		_viewport.remove_child(_map)
		_map.queue_free()
	_spawn_map(load(path))


## Plays the current map again in the current mode, with a fresh match
## (the match-end screen's "Play again" button).
func restart_match() -> void:
	change_map(_map.scene_file_path)


## Plays the next map of the rotation, a fresh match by the same rules (the
## match-end screen's "Next map"); after the last map comes the first again.
## Does nothing without a rotation.
func next_map() -> void:
	if _rotation.is_empty():
		return
	_rotation_index = (_rotation_index + 1) % _rotation.size()
	change_map(_rotation[_rotation_index])


## The scene path of the map [method next_map] would play, or "" without a rotation.
func get_next_map() -> String:
	return _rotation[(_rotation_index + 1) % _rotation.size()] if not _rotation.is_empty() else ""


## Leaves the game for the main menu (the pause menu's Leave button, the
## match-end screen's "Main menu" button, console: disconnect). The game scene is
## freed and the menu scene starts; the menus and the console in the game close
## with it. The game is unpaused first: the pause is a property of the tree, not
## of the scene, so the main menu would otherwise start frozen (and deaf to clicks).
func return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GameLaunch.MENU_SCENE)


## Loads the map from the command line (-- --map ...) or [member map_scene],
## unless the main menu left a [GameLaunch] description: that one wins (the
## command line is ignored then, so a game started with [code]-- --map[/code]
## and left for the menu plays what the menu says). [code]-- --practice[/code]
## picks practice; [code]-- --match[/code] needs no code here (a match is the
## default of [member mode]), it only tells the main menu to skip itself.
func _load_map() -> void:
	if GameLaunch.is_pending():
		_spawn_map(_take_launch())
		return
	var scene := map_scene
	var args := OS.get_cmdline_user_args()
	var map_arg := args.find("--map")
	if map_arg >= 0 and map_arg + 1 < args.size():
		scene = load(args[map_arg + 1])
	if args.has("--practice"):
		mode = Mode.PRACTICE
	if args.has("--respawn"):
		match_settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	if args.has("--rotation"):
		_rotation = GameLaunch.rotation_maps()
		_rotation_index = 0
		scene = load(_rotation[0])
	_spawn_map(scene)


## Takes over the [GameLaunch] description (once: it is cleared): sets [member mode]
## and [member match_settings] from it and returns its map scene.
func _take_launch() -> PackedScene:
	mode = Mode.PRACTICE if GameLaunch.practice else Mode.MATCH
	match_settings = GameLaunch.match_settings
	net_session = GameLaunch.net_session
	_rotation = GameLaunch.rotation.duplicate()
	_rotation_index = 0
	var scene := load(GameLaunch.map_path) as PackedScene
	GameLaunch.clear()
	return scene


## Puts the map into the world viewport, adds the game rules, and connects
## its player and its round manager (in a match) to the HUD and overlay.
func _spawn_map(scene: PackedScene) -> void:
	_map = scene.instantiate()
	_viewport.add_child(_map)
	var player := _map.get_node("Player") as Character
	_player = player
	Teams.friendly_fire = false
	var rules := _add_game_rules()
	_net_game = null
	if net_session != null and rules is RoundManager:
		_start_online(rules as RoundManager, player)
	# Hides the match-end screen of the previous map; it opens when this match ends,
	# with "Next map" when there is a rotation.
	_match_end_screen.set_round_manager(rules as RoundManager)
	_match_end_screen.set_next_map(GameLaunch.map_title(get_next_map()) if not _rotation.is_empty() else "")
	# The round HUD (top bar, kill feed, banners) shows only in a match; null hides it.
	_hud.set_round_manager(rules as RoundManager)
	# The hold-Tab scoreboard also exists only in a match.
	_scoreboard.set_round_manager(rules as RoundManager)
	# The class menu opens at the start of a match, and on M during freeze time (any time in practice).
	_class_menu.set_rules(rules, player)
	_hud.set_player(player)
	# Practice and team respawn bring you back; in rounds the dead watch a teammate instead.
	var respawning := rules is ArenaRules or rules is RespawnMatch
	_hud.respawn_hint = respawning
	_pause_menu.set_leave_text("Leave match" if rules is RoundManager else ("Leave practice" if rules is ArenaRules else "Leave"))
	_set_up_spectating(player, rules is RoundManager and not respawning)
	_debug_overlay.player = player
	Teams.set_viewer_team(player.team)


## In a match, the dead player watches a living teammate (and the HUD shows
## that teammate's health and ammo). Practice mode brings the player back after
## 3 s instead, so there is nothing to watch. Purely presentation: the rules
## don't know about it.
func _set_up_spectating(player: Character, in_match: bool) -> void:
	var controller := player.get_node_or_null("PlayerController") as PlayerController
	if controller == null:
		return
	controller.spectating_enabled = in_match
	controller.view_target_changed.connect(_hud.set_view_target)


## Adds the node that runs the game on the current map (see [enum Mode]) and returns it, or null.
func _add_game_rules() -> Node:
	var has_navigation := not _map.find_children("*", "NavigationRegion3D").is_empty()
	var has_spawns := _map_has_group(Teams.ATTACK_SPAWN_GROUP) and _map_has_group(Teams.DEFEND_SPAWN_GROUP)
	var rules: Node = null
	if mode == Mode.MATCH and has_navigation and has_spawns:
		var team_respawn := match_settings.game_mode == MatchSettings.GameMode.TEAM_RESPAWN
		var rounds: RoundManager = RespawnMatch.new() if team_respawn else RoundManager.new()
		rounds.settings = match_settings
		if net_session != null:
			# Online: the host starts when everyone has loaded; a client only shows the host's match.
			rounds.player_team = maxi(net_session.get_team(net_session.local_peer_id), 0)
			rounds.autostart = false
			rounds.replica = not net_session.is_host()
		rules = rounds
	elif has_navigation:
		var arena := ArenaRules.new()
		# The difficulty chosen in the menu (Normal, like ArenaRules' own default, otherwise).
		arena.bot_difficulty = match_settings.bot_difficulty
		rules = arena
	if rules != null:
		# Named like the class, so the console finds it ("ArenaRules").
		rules.name = rules.get_script().get_global_name()
		_map.add_child(rules)
	return rules


## Online: adds the [NetHost] (host) or [NetClient] (client) to the map and starts it.
func _start_online(rules: RoundManager, player: Character) -> void:
	if net_session.is_host():
		var host := NetHost.new()
		_map.add_child(host)
		host.setup(net_session, _map, rules, player)
		_net_game = host
	else:
		var client := NetClient.new()
		_map.add_child(client)
		client.setup(net_session, _map, rules, player)
		_net_game = client


func _map_has_group(group: String) -> bool:
	return get_tree().get_nodes_in_group(group).any(func(node: Node) -> bool: return _map.is_ancestor_of(node))


## Applies the pixel settings (D-027, D-030, D-048): [member Settings.pixel_height],
## the height of the world image in pixels (the width follows the window's
## shape; 480 gives 853 × 480 in a 16:9 window; pixels are scaled by whole
## numbers, so the real height is the closest whole fraction of the window: 480
## on a 1440-pixel screen, 540 on 1080, 360 on 720), [member Settings.pixelate_hud]
## (render the whole window at the low resolution, HUD included) and
## [member Settings.palette_effect] (the retro color limit,
## shaders/palette_limit.gdshader). Runs when one of them changes and when the
## window is resized.
func apply_pixel_settings() -> void:
	var ui_height := PixelView.apply(Settings.get_instance(), get_tree().root, _world, _palette_effect)
	_hud.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_debug_overlay.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_console.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_scoreboard.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_match_end_screen.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_pause_menu.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_settings_menu.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_class_menu.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)


func _on_setting_changed(key: StringName) -> void:
	if key == &"pixel_height" or key == &"pixelate_hud" or key == &"palette_effect":
		apply_pixel_settings()
