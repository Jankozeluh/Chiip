class_name Crosshair
extends Control
## A CS-style crosshair drawn in code: four lines around the screen center
## with a gap, an optional outline and an optional center dot.
##
## Static by default. In dynamic mode the gap opens up to show the current
## inaccuracy cone, so you can see where shots can land.
##
## The style comes from the crosshair settings ([Settings]): it is read when
## the node is ready and again whenever one of them changes, so this node
## always shows the player's crosshair (the settings menu's preview is another
## instance of it). The variables below hold the values being drawn.

## Line color.
var color: Color = Settings.get_default(&"crosshair_color")
## Length of each line, in pixels.
var length: float = Settings.get_default(&"crosshair_length")
## Distance from the center to where each line starts, in pixels.
var gap: float = Settings.get_default(&"crosshair_gap")
## Line thickness, in pixels.
var thickness: float = Settings.get_default(&"crosshair_thickness")
## Draw a dark 1-pixel outline around the lines.
var outline: bool = Settings.get_default(&"crosshair_outline")
## Draw a dot in the center.
var dot: bool = Settings.get_default(&"crosshair_dot")
## Open the gap to show the current inaccuracy (CS's dynamic crosshair).
var dynamic: bool = Settings.get_default(&"crosshair_dynamic")

## Current inaccuracy in degrees. The HUD sets it every frame; only used in dynamic mode.
var spread_degrees: float = 0.0
## The camera whose field of view converts degrees to pixels (dynamic mode).
var camera: Camera3D

## Line length, gap and thickness at scale 1, as the settings give them.
var _base_sizes: Vector3 = Vector3(length, gap, thickness)
## The factor [method set_ui_scale] was last given.
var _ui_scale: float = 1.0


func _ready() -> void:
	Settings.get_instance().changed.connect(_on_setting_changed)
	apply_settings()


## Takes the whole style from the crosshair settings.
func apply_settings() -> void:
	var settings := Settings.get_instance()
	color = settings.crosshair_color
	outline = settings.crosshair_outline
	dot = settings.crosshair_dot
	dynamic = settings.crosshair_dynamic
	_base_sizes = Vector3(settings.crosshair_length, settings.crosshair_gap, settings.crosshair_thickness)
	_scale_sizes()
	queue_redraw()


## Scales line length, gap and thickness for the current resolution (a line is at
## least 1 pixel; the gap can be 0).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	_scale_sizes()
	queue_redraw()


## Sets length, gap and thickness from their size at scale 1 and the UI scale, in whole pixels.
func _scale_sizes() -> void:
	length = maxf(1.0, roundf(_base_sizes.x * _ui_scale))
	gap = maxf(0.0, roundf(_base_sizes.y * _ui_scale))
	thickness = maxf(1.0, roundf(_base_sizes.z * _ui_scale))


func _on_setting_changed(key: StringName) -> void:
	if key.begins_with("crosshair_"):
		apply_settings()


func _draw() -> void:
	var center := (size / 2.0).floor()
	var current_gap := gap + _spread_in_pixels() if dynamic else gap
	var half := thickness / 2.0
	var lines: Array[Rect2] = [
		Rect2(center.x - half, center.y - current_gap - length, thickness, length),
		Rect2(center.x - half, center.y + current_gap, thickness, length),
		Rect2(center.x - current_gap - length, center.y - half, length, thickness),
		Rect2(center.x + current_gap, center.y - half, length, thickness),
	]
	if dot:
		lines.append(Rect2(center - Vector2(half, half), Vector2(thickness, thickness)))
	if outline:
		for line in lines:
			draw_rect(line.grow(1.0), Color(0.0, 0.0, 0.0, color.a * 0.8))
	for line in lines:
		draw_rect(line, color)


## How many pixels the inaccuracy cone covers on screen, from the camera's field of view.
func _spread_in_pixels() -> float:
	if camera == null:
		return 0.0
	var half_screen_height := get_viewport_rect().size.y / 2.0
	return tan(deg_to_rad(spread_degrees)) / tan(deg_to_rad(camera.fov / 2.0)) * half_screen_height
