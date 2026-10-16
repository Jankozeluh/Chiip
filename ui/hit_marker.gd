class_name HitMarker
extends Control
## The hit marker (Foundations: HIT MARKER): when the weapon on show hits a character, four L-shaped corners
## flash around the crosshair's centre for [code]hit_time_ms[/code] (the theme's "Hud" type): white for a hit on the
## body, ALERT for a headshot. Each corner is two bars (the length and the thickness of the "Hud" type's
## [code]hit_length[/code] and [code]hit_thickness[/code]) and starts [code]hit_inner[/code] pixels from the centre, with a
## hard VOID shadow like the rest of the HUD text. It is drawn with [method _draw] (a pixel-exact shape no
## theme box makes), takes its colours from the palette and its sizes from the theme, and scales with the HUD.
##
## [method show_hit] starts it; [code]hud.gd[/code] calls it from the shown weapon's [signal Weapon.hit_landed]. Time is
## counted in [method _process] deltas, so a pause freezes it. Takes no mouse clicks.

## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"

## Seconds left of the marker (0 while hidden).
var _left: float = 0.0
## The marker showing is a headshot's.
var _headshot: bool = false
var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Flashes the marker: ALERT when [param headshot], white otherwise. A hit while it shows starts it over.
func show_hit(headshot: bool) -> void:
	_headshot = headshot
	_left = get_theme_constant(&"hit_time_ms", THEME_TYPE) / 1000.0
	set_process(true)
	queue_redraw()


## True while the marker shows. For tests.
func is_showing() -> bool:
	return _left > 0.0


## The colour of the marker in showing (the palette's white or alert). For tests.
func get_color() -> Color:
	return _color()


## Scales the marker with the HUD (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	queue_redraw()


func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	if _left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _left <= 0.0:
		return
	var bars := get_bars()
	var shadow := Vector2.ONE * _scaled(&"shadow_offset")
	var shadow_colour := get_theme_color(&"shadow", PALETTE_TYPE)
	for bar in bars:
		draw_rect(Rect2(bar.position + shadow, bar.size), shadow_colour)
	var colour := _color()
	for bar in bars:
		draw_rect(bar, colour)


## The eight bars the marker is drawn from (two per corner), in this control's own coordinates around the crosshair's centre.
func get_bars() -> Array[Rect2]:
	var centre := (size / 2.0).floor()
	var inner := _scaled(&"hit_inner")
	var length := _scaled(&"hit_length")
	var thickness := _scaled(&"hit_thickness")
	var outer := inner + length
	var bars: Array[Rect2] = []
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			# The L's corner is the outer one: a bar along the horizontal edge and one along the vertical edge.
			bars.append(_span(centre, Vector2(sign_x * inner, sign_y * outer), Vector2(sign_x * outer, sign_y * (outer - thickness))))
			bars.append(_span(centre, Vector2(sign_x * (outer - thickness), sign_y * inner), Vector2(sign_x * outer, sign_y * outer)))
	return bars


func _color() -> Color:
	return get_theme_color(&"alert" if _headshot else &"text_bright", PALETTE_TYPE)


## The rectangle between two corners given relative to [param centre].
func _span(centre: Vector2, from: Vector2, to: Vector2) -> Rect2:
	return Rect2(centre + from.min(to), (to - from).abs())


## A size of the HUD's theme type, scaled with the HUD and rounded to whole pixels.
func _scaled(constant_name: StringName) -> float:
	return roundf(get_theme_constant(constant_name, THEME_TYPE) * _ui_scale)
