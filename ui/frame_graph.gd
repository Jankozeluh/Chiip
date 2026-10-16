class_name FrameGraph
extends Control
## The developer overlay's frame-time graph (v0.2, D-233, the designer's "28 Debug developer"): one bar per frame
## for the last 64 frames, newest on the right, [code]graph_scale[/code] hundredths of a pixel per millisecond up to
## [code]graph_max[/code] pixels, a thin line at the length of a 60 FPS frame (16.7 ms) with its number, a rule along
## the bottom. Frames longer than that line are drawn in the alert colour, the others dim. Drawn with [method _draw]
## from the theme's "Hud" type and the palette; it scales with the HUD like the rest of the overlay.

## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"

## The frame times in milliseconds, oldest first (at most one per bar).
var _frames: Array[float] = []
var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = get_theme_constant(&"graph_height", THEME_TYPE)


## Adds one frame of [param milliseconds] and forgets the oldest past the bar count.
func add_frame(milliseconds: float) -> void:
	_frames.append(milliseconds)
	while _frames.size() > get_theme_constant(&"graph_bars", THEME_TYPE):
		_frames.pop_front()
	queue_redraw()


## Scales the graph with the overlay (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	custom_minimum_size.y = roundf(get_theme_constant(&"graph_height", THEME_TYPE) * factor)
	queue_redraw()


## The frames kept, in milliseconds, oldest first.
func get_frames() -> Array[float]:
	return _frames


## How tall a frame of [param milliseconds] is drawn, in this control's pixels (a whole number, never past the maximum).
func bar_height(milliseconds: float) -> float:
	return minf(roundf(milliseconds * get_theme_constant(&"graph_scale", THEME_TYPE) / 100.0 * _ui_scale), roundf(get_theme_constant(&"graph_max", THEME_TYPE) * _ui_scale))


## The shortest and the longest frame kept, in milliseconds, or (0, 0) with none.
func get_range() -> Vector2:
	if _frames.is_empty():
		return Vector2.ZERO
	return Vector2(_frames.min(), _frames.max())


func _draw() -> void:
	var rule := roundf(get_theme_constant(&"compass_thickness", THEME_TYPE) * _ui_scale)
	var floor_y := size.y - rule
	draw_rect(Rect2(0.0, floor_y, size.x, rule), get_theme_color(&"line", PALETTE_TYPE))
	var bars := get_theme_constant(&"graph_bars", THEME_TYPE)
	var gap := maxf(1.0, roundf(_ui_scale))
	var width := maxf(1.0, floorf((size.x - gap * (bars - 1)) / bars))
	var limit := get_theme_constant(&"graph_limit", THEME_TYPE) / 10.0
	var first := bars - _frames.size()
	for i in _frames.size():
		var height := bar_height(_frames[i])
		var colour := get_theme_color(&"alert" if _frames[i] > limit else &"text_dim", PALETTE_TYPE)
		draw_rect(Rect2((first + i) * (width + gap), floor_y - height, width, height), colour)
	var line_y := floor_y - bar_height(limit)
	draw_rect(Rect2(0.0, line_y, size.x, maxf(1.0, roundf(_ui_scale))), get_theme_color(&"mute", PALETTE_TYPE))
	var font := get_theme_font(&"font", &"Label")
	var font_size := maxi(1, roundi(get_theme_font_size(&"font_size", &"HudSmallLabel") * _ui_scale))
	var text := "%.1f" % limit
	draw_string(font, Vector2(size.x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, line_y - roundf(2.0 * _ui_scale)),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"mute", PALETTE_TYPE))
