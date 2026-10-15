extends Node
## The game's root scene: loads a map, renders the 3D world at a low
## resolution inside a SubViewport and scales it up with sharp pixels, with
## the HUD and debug overlay on top.
##
## Every map scene must contain a [Character] node named "Player" (the local player).
##
## Two pixel styles (see docs/DECISIONS.md):
## - Pixelated HUD: the whole window renders at the low resolution, HUD included.
## - Sharp HUD: only the world is low-res; the HUD uses the full window resolution.

## The HUD and overlay are laid out for a window this many pixels tall.
const UI_DESIGN_HEIGHT := 720.0

## The map to play. Can be overridden from the command line:
## [code]Godot --path . -- --map res://maps/comparison/csg_room.tscn[/code]
@export var map_scene: PackedScene = preload("res://maps/test_map.tscn")
## Height of the world image in pixels; the width follows the window's shape.
## 360 gives 640 × 360 in a 16:9 window.
@export var pixel_height: int = 360
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

## The map currently loaded.
var _map: Node


func _ready() -> void:
	_console.main = self
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


## Loads the map from the command line (-- --map ...) or [member map_scene].
func _load_map() -> void:
	var scene := map_scene
	var args := OS.get_cmdline_user_args()
	var map_arg := args.find("--map")
	if map_arg >= 0 and map_arg + 1 < args.size():
		scene = load(args[map_arg + 1])
	_spawn_map(scene)


## Puts the map into the world viewport and connects its player to the HUD and overlay.
func _spawn_map(scene: PackedScene) -> void:
	_map = scene.instantiate()
	_viewport.add_child(_map)
	var player := _map.get_node("Player") as Character
	_hud.set_player(player)
	_debug_overlay.player = player
	Teams.set_viewer_team(player.team)


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
