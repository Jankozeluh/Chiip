extends Node
## The game's root scene: the 3D world rendered at a low resolution inside a
## SubViewport and scaled up with sharp pixels, with the HUD and debug overlay
## on top.
##
## Two pixel styles (see docs/DECISIONS.md):
## - Pixelated HUD: the whole window renders at the low resolution, HUD included.
## - Sharp HUD: only the world is low-res; the HUD uses the full window resolution.

## The HUD and overlay are laid out for a window this many pixels tall.
const UI_DESIGN_HEIGHT := 720.0

## Height of the world image in pixels; the width follows the window's shape.
## 360 gives 640 × 360 in a 16:9 window.
@export var pixel_height: int = 360
## Pixelate the HUD too, by rendering the whole window at the low resolution.
@export var pixelate_hud: bool = false

@onready var _world: SubViewportContainer = $World
@onready var _hud: Node = $HUD
@onready var _debug_overlay: Node = $DebugOverlay


func _ready() -> void:
	get_tree().root.size_changed.connect(apply_pixel_settings)
	apply_pixel_settings()


## Applies [member pixel_height] and [member pixelate_hud]. Call it again after changing them.
func apply_pixel_settings() -> void:
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
