class_name ScopeOverlay
extends Control
## The sniper scope's view (D-095): the screen goes black except a round window in the middle,
## crossed by thin black lines, like CS's AWP scope. The HUD shows it while the weapon of the
## character on show is scoped. Drawn in code at the window's full resolution (the HUD stays
## sharp), it takes no mouse clicks.

## The round window's radius as a share of the screen's height.
const WINDOW_RADIUS := 0.46
## The cross lines' thickness in pixels at the 720-pixel design height.
const LINE_WIDTH := 2.0
const MASK_COLOR := Color(0, 0, 0)
## The edge of the window: a slightly lighter ring, like the inside of a scope tube.
const RIM_COLOR := Color(0.08, 0.08, 0.08)
const RIM_WIDTH := 3.0

var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Scales the lines with the HUD (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := size.y * WINDOW_RADIUS
	# Above and below the window: two plain bands.
	var top := floorf(center.y - radius)
	var bottom := ceilf(center.y + radius)
	draw_rect(Rect2(0, 0, size.x, top), MASK_COLOR)
	draw_rect(Rect2(0, bottom, size.x, size.y - bottom), MASK_COLOR)
	# Beside it, row by row: black up to where the circle starts on each side.
	for row in range(int(top), int(bottom)):
		var dy := row + 0.5 - center.y
		var half := sqrt(maxf(radius * radius - dy * dy, 0.0))
		draw_rect(Rect2(0, row, center.x - half, 1), MASK_COLOR)
		draw_rect(Rect2(center.x + half, row, size.x - center.x - half, 1), MASK_COLOR)
	draw_arc(center, radius - RIM_WIDTH * _ui_scale * 0.5, 0.0, TAU, 96, RIM_COLOR, RIM_WIDTH * _ui_scale)
	var width := maxf(1.0, roundf(LINE_WIDTH * _ui_scale))
	draw_rect(Rect2(center.x - radius, center.y - width / 2.0, radius * 2.0, width), MASK_COLOR)
	draw_rect(Rect2(center.x - width / 2.0, center.y - radius, width, radius * 2.0), MASK_COLOR)
