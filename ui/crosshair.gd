class_name Crosshair
extends Control
## A CS-style crosshair drawn in code: four lines around the screen center
## with a gap, an optional outline and an optional center dot.
##
## Static by default. In dynamic mode the gap opens up to show the current
## inaccuracy cone, so you can see where shots can land.

## Line color. CS green by default.
@export var color: Color = Color(0.2, 1.0, 0.2)
## Length of each line, in pixels.
@export var length: float = 7.0
## Distance from the center to where each line starts, in pixels.
@export var gap: float = 4.0
## Line thickness, in pixels.
@export var thickness: float = 2.0
## Draw a dark 1-pixel outline around the lines.
@export var outline: bool = true
## Draw a dot in the center.
@export var dot: bool = false
## Open the gap to show the current inaccuracy (CS's dynamic crosshair).
@export var dynamic: bool = false

## Current inaccuracy in degrees. The HUD sets it every frame; only used in dynamic mode.
var spread_degrees: float = 0.0


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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var half_screen_height := get_viewport_rect().size.y / 2.0
	return tan(deg_to_rad(spread_degrees)) / tan(deg_to_rad(camera.fov / 2.0)) * half_screen_height
