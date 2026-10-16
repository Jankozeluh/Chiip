class_name StickPreview
extends Control
## The Controller tab's stick box (v0.2, D-234, the designer's "25 Settings controller"): an 80 × 80 square with a dim
## square in the middle that is the dead zone (a push inside it does nothing) and a small bright dot that is the right
## stick, live: with no pad plugged in it rests in the middle. The dead zone's size follows [member Settings.pad_deadzone].
## Drawn from the theme's palette; it scales with the menu by its minimum size.

## The theme type of the palette's colours.
const PALETTE_TYPE := &"Palette"
## The box's side, the dot's side and the frame's width, in design pixels.
const BOX := 80
const DOT := 8
const FRAME := 2

var _deadzone: float = 0.15


func _ready() -> void:
	custom_minimum_size = Vector2(BOX, BOX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())


## Sets the dead zone to show, 0 to 1 (the share of the stick's travel).
func set_deadzone(value: float) -> void:
	_deadzone = clampf(value, 0.0, 1.0)
	queue_redraw()


## The dead zone shown, 0 to 1.
func get_deadzone() -> float:
	return _deadzone


## Where the right stick is now, -1 to 1 each way (0, 0 with no pad).
func get_stick() -> Vector2:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Vector2.ZERO
	return Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y)).limit_length(1.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var frame := maxf(1.0, roundf(size.x / BOX * FRAME))
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"line", PALETTE_TYPE))
	draw_rect(Rect2(Vector2.ONE * frame, size - Vector2.ONE * 2.0 * frame), get_theme_color(&"void", PALETTE_TYPE))
	var inner := size - Vector2.ONE * 2.0 * frame
	var zone := (inner * _deadzone).round()
	draw_rect(Rect2((size - zone) / 2.0, zone).abs(), get_theme_color(&"raised", PALETTE_TYPE))
	var dot := roundf(size.x / BOX * DOT)
	var centre := size / 2.0 + get_stick() * (inner / 2.0 - Vector2.ONE * dot / 2.0)
	draw_rect(Rect2((centre - Vector2.ONE * dot / 2.0).round(), Vector2.ONE * dot), get_theme_color(&"text", PALETTE_TYPE))
