extends Node
## The game's root scene: loads a map, renders the 3D world at a low
## resolution inside a SubViewport and scales it up with sharp pixels, with
## the HUD, debug overlay, hold-Tab scoreboard and match-end screen on top.
##
## Every map scene must contain a [Character] node named "Player" (the local player).
## Maps hold only the level: geometry, navigation and markers. The game rules
## are added here, depending on [member mode]: a match on maps with attack and
## defend spawns (a [RoundManager], or a [RespawnMatch] when
## [member MatchSettings.game_mode] is team respawn), practice ([ArenaRules]:
## bots that respawn) on other maps with navigation, and nothing (free roaming)
## on the rest.
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
const UI_DESIGN_HEIGHT := 720.0

## The map to play. Can be overridden from the command line:
## [code]Godot --path . -- --map res://maps/comparison/csg_room.tscn[/code]
@export var map_scene: PackedScene = preload("res://maps/test_map.tscn")
## Match or practice. [code]-- --practice[/code] on the command line picks practice.
@export var mode: Mode = Mode.MATCH
## The rules of a match: team sizes, bot skill, length, friendly fire.
@export var match_settings: MatchSettings = MatchSettings.new()
## Height of the world image in pixels; the width follows the window's shape.
## 480 gives 853 × 480 in a 16:9 window. Pixels are scaled by whole numbers, so
## the real height is the closest whole fraction of the window: 480 on a
## 1440-pixel screen (3 × 3 pixels), 540 on 1080, 360 on 720 (D-048).
@export var pixel_height: int = 480
## Pixelate the HUD too, by rendering the whole window at the low resolution.
@export var pixelate_hud: bool = false
## Limit the world's colors with the retro palette effect (shaders/palette_limit.gdshader).
@export var palette_effect: bool = true

@onready var _world: SubViewportContainer = $World
@onready var _viewport: SubViewport = $World/SubViewport
@onready var _hud: Node = $HUD
@onready var _debug_overlay: Node = $DebugOverlay
@onready var _palette_effect: CanvasLayer = $World/SubViewport/PaletteEffect
@onready var _console: DevConsole = $DevConsole
@onready var _scoreboard: Scoreboard = $Scoreboard
@onready var _match_end_screen: MatchEndScreen = $MatchEndScreen

## The map currently loaded.
var _map: Node


func _ready() -> void:
	_console.main = self
	_match_end_screen.play_again_pressed.connect(restart_match)
	_match_end_screen.quit_pressed.connect(get_tree().quit)
	_load_map()
	get_tree().root.size_changed.connect(apply_pixel_settings)
	apply_pixel_settings()


## The map currently loaded.
func get_map() -> Node:
	return _map


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


## Loads the map from the command line (-- --map ...) or [member map_scene].
func _load_map() -> void:
	var scene := map_scene
	var args := OS.get_cmdline_user_args()
	var map_arg := args.find("--map")
	if map_arg >= 0 and map_arg + 1 < args.size():
		scene = load(args[map_arg + 1])
	if args.has("--practice"):
		mode = Mode.PRACTICE
	if args.has("--respawn"):
		match_settings.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	_spawn_map(scene)


## Puts the map into the world viewport, adds the game rules, and connects
## its player and its round manager (in a match) to the HUD and overlay.
func _spawn_map(scene: PackedScene) -> void:
	_map = scene.instantiate()
	_viewport.add_child(_map)
	var player := _map.get_node("Player") as Character
	Teams.friendly_fire = false
	var rules := _add_game_rules()
	# Hides the match-end screen of the previous map; it opens when this match ends.
	_match_end_screen.set_round_manager(rules as RoundManager)
	# The round HUD (top bar, kill feed, banners) shows only in a match; null hides it.
	_hud.set_round_manager(rules as RoundManager)
	# The hold-Tab scoreboard also exists only in a match.
	_scoreboard.set_round_manager(rules as RoundManager)
	_hud.set_player(player)
	# Practice and team respawn bring you back; in rounds the dead watch a teammate instead.
	var respawning := rules is ArenaRules or rules is RespawnMatch
	_hud.respawn_hint = respawning
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
		rules = rounds
	elif has_navigation:
		rules = ArenaRules.new()
	if rules != null:
		# Named like the class, so the console finds it ("ArenaRules").
		rules.name = rules.get_script().get_global_name()
		_map.add_child(rules)
	return rules


func _map_has_group(group: String) -> bool:
	return get_tree().get_nodes_in_group(group).any(func(node: Node) -> bool: return _map.is_ancestor_of(node))


## Applies [member pixel_height], [member pixelate_hud] and [member palette_effect].
## Call it again after changing them.
func apply_pixel_settings() -> void:
	_palette_effect.visible = palette_effect
	var window := get_tree().root
	var ui_height: float
	if pixelate_hud:
		var aspect := float(window.size.x) / window.size.y
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = Vector2i(roundi(pixel_height * aspect), pixel_height)
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		_world.stretch_shrink = 1
		ui_height = pixel_height
	else:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		# The SubViewport renders at the container's size divided by this.
		_world.stretch_shrink = maxi(1, roundi(float(window.size.y) / pixel_height))
		ui_height = window.size.y
	_hud.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_debug_overlay.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_console.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_scoreboard.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
	_match_end_screen.set_ui_scale(ui_height / UI_DESIGN_HEIGHT)
