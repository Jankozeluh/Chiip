class_name Compass
extends Control
## The HUD's compass (M11, D-180): a thin strip at the top centre that turns with your view, as simple as it
## gets. N, E, S and W stand on the strip with small ticks every 15 degrees (taller at the 45-degree points), a
## short pointer marks where you look, and when an enemy fires a small red square appears at that bearing
## and fades after about two seconds. Nothing else is marked: no teammates, no bomb, no footsteps.
##
## The strip shows [code]compass_arc[/code] degrees across (120). An enemy shot from further to the side than
## that sits on the strip's edge, so you know which way to turn. A shooter has one square: a new shot from the
## same enemy moves it and starts its time over. Only shots within [constant Noises.GUNSHOT_RANGE] show (the
## range bots hear them from), and not your own team's or yours.
##
## It reads [signal Noises.shot_fired]: the host's own shots, the bots' and, on a client, the other players'
## shots as the host reported them ([method Weapon.play_remote_shot]), so it needs nothing from the host. A
## pure view, drawn with [method _draw] from the theme's "Hud" type (the sizes are tokens in tools/ui_palette.gd)
## and the palette; it scales with the HUD ([method set_ui_scale]) and takes no mouse clicks. Time is counted in
## [method _process] deltas, so a pause freezes the squares.

## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## The labels' type whose font size the letters use.
const LETTER_TYPE := &"HudSmallLabel"
## The letters at 0, 90, 180 and 270 degrees.
const LETTERS: Array[String] = ["N", "E", "S", "W"]

## The character whose view the strip shows (the player, or the teammate being spectated).
var _view: Character
## The enemies' squares, by the shooter's instance id: {"position": where the shot came from, "left": seconds}.
var _markers: Dictionary = {}
var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Noises.get_bus().shot_fired.connect(_on_shot_fired)


func _exit_tree() -> void:
	var bus := Noises.get_bus()
	if bus.shot_fired.is_connected(_on_shot_fired):
		bus.shot_fired.disconnect(_on_shot_fired)


func _process(delta: float) -> void:
	advance(delta)


## Shows the view of [param target] (the HUD hands over the player or the spectated teammate).
func set_view_target(target: Character) -> void:
	_view = target
	_markers.clear()
	queue_redraw()


## Scales the strip with the HUD (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	queue_redraw()


## Counts [param seconds] more of the squares' time and redraws. [code]_process[/code] calls it every frame; tests call it to skip ahead.
func advance(seconds: float) -> void:
	for id: int in _markers.keys():
		_markers[id]["left"] -= seconds
		if _markers[id]["left"] <= 0.0:
			_markers.erase(id)
	if visible:
		queue_redraw()


## Where you look, in degrees clockwise from north (north is the map's -Z), 0 to 360.
func get_heading() -> float:
	if not is_instance_valid(_view):
		return 0.0
	var camera := _view.get_camera()
	if camera != null and camera.is_inside_tree():
		var forward := -camera.global_basis.z
		return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)
	return fposmod(-rad_to_deg(_view.get_aim_angles().x), 360.0)


## The x of a direction [param offset] degrees to the right of where you look, in this control's own pixels
## (the middle of the strip for 0). Not limited to the strip: past half the arc it lies outside.
func x_for_offset(offset: float) -> float:
	return size.x / 2.0 + offset * size.x / float(get_theme_constant(&"compass_arc", THEME_TYPE))


## How many enemy squares show.
func get_marker_count() -> int:
	return _markers.size()


## The squares showing, as how many degrees to the right of your view each lies (negative: to the left), -180 to 180,
## in the order they appeared.
func get_marker_offsets() -> Array[float]:
	var offsets: Array[float] = []
	for id: int in _markers:
		offsets.append(_offset_of(_markers[id]["position"]))
	return offsets


## The opacity (0 to 1) of the first square, or 0 with none: 1 until the fade starts.
func get_marker_alpha() -> float:
	for id: int in _markers:
		return _alpha(_markers[id]["left"])
	return 0.0


## The squares' rectangles in this control's pixels, as drawn (clamped to the strip's ends).
func get_marker_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var side := _scaled(&"compass_marker")
	var half_arc := get_theme_constant(&"compass_arc", THEME_TYPE) / 2.0
	for id: int in _markers:
		var offset := clampf(_offset_of(_markers[id]["position"]), -half_arc, half_arc)
		rects.append(Rect2(Vector2(roundf(x_for_offset(offset) - side / 2.0), size.y - side), Vector2(side, side)))
	return rects


func _on_shot_fired(shot_position: Vector3, source: Character) -> void:
	if not is_instance_valid(_view) or not is_instance_valid(source) or source == _view or source.team == Teams.viewer_team:
		return
	# Another game in the same process (the online tests) has its own world.
	if source.get_world_3d() != _view.get_world_3d():
		return
	if shot_position.distance_to(_view.global_position) > Noises.GUNSHOT_RANGE:
		return
	_markers[source.get_instance_id()] = {"position": shot_position, "left": get_theme_constant(&"compass_marker_time_ms", THEME_TYPE) / 1000.0}
	queue_redraw()


## How many degrees to the right of your view a world position lies, -180 to 180.
func _offset_of(world_position: Vector3) -> float:
	var away := world_position - _view.global_position
	return wrapf(rad_to_deg(atan2(away.x, -away.z)) - get_heading(), -180.0, 180.0)


## A square's opacity: full until the last [code]compass_fade_ms[/code], then down to nothing.
func _alpha(left: float) -> float:
	return clampf(left * 1000.0 / get_theme_constant(&"compass_fade_ms", THEME_TYPE), 0.0, 1.0)


@warning_ignore("integer_division")
func _draw() -> void:
	if not is_instance_valid(_view):
		return
	var arc := float(get_theme_constant(&"compass_arc", THEME_TYPE))
	var step := get_theme_constant(&"compass_tick_step", THEME_TYPE)
	var heading := get_heading()
	var thickness := _scaled(&"compass_thickness")
	var shadow := Vector2.ONE * _scaled(&"shadow_offset")
	var shadow_colour := get_theme_color(&"shadow", PALETTE_TYPE)
	var font := get_theme_font(&"font", &"Label")
	var font_size := maxi(1, roundi(get_theme_font_size(&"font_size", LETTER_TYPE) * _ui_scale))
	# Ticks and letters: every [step] degrees from just left of the strip to just right of it.
	var first := floori((heading - arc / 2.0) / step) * step
	var angle := first
	while angle <= heading + arc / 2.0 + step:
		var x := roundf(x_for_offset(angle - heading))
		var turn := posmod(angle, 360)
		if turn % 90 == 0:
			var letter := LETTERS[turn / 90]
			var letter_width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if x - letter_width / 2.0 >= 0.0 and x + letter_width / 2.0 <= size.x:
				var origin := Vector2(roundf(x - letter_width / 2.0), font.get_ascent(font_size))
				draw_string(font, origin + shadow, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_colour)
				draw_string(font, origin, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"text_bright" if turn == 0 else &"text", PALETTE_TYPE))
		elif x >= 0.0 and x <= size.x:
			var tall := _scaled(&"compass_tick_large" if turn % 45 == 0 else &"compass_tick_small")
			var tick := Rect2(x - thickness / 2.0, size.y - tall, thickness, tall)
			draw_rect(Rect2(tick.position + shadow, tick.size), shadow_colour)
			draw_rect(tick, get_theme_color(&"mute", PALETTE_TYPE))
		angle += step
	# The pointer: where you look, a short bar at the top of the middle.
	var pointer := Rect2(roundf(size.x / 2.0 - thickness / 2.0), 0.0, thickness, _scaled(&"compass_tick_small"))
	draw_rect(Rect2(pointer.position + shadow, pointer.size), shadow_colour)
	draw_rect(pointer, get_theme_color(&"text_bright", PALETTE_TYPE))
	# The enemies' squares, red, fading out.
	var rects := get_marker_rects()
	var index := 0
	for id: int in _markers:
		var colour := get_theme_color(&"enemy_text", PALETTE_TYPE)
		colour.a = _alpha(_markers[id]["left"])
		var square := rects[index]
		draw_rect(Rect2(square.position + shadow, square.size), Color(shadow_colour, shadow_colour.a * colour.a))
		draw_rect(square, colour)
		index += 1


## A size of the HUD's theme type, scaled with the HUD and rounded to whole pixels.
func _scaled(constant_name: StringName) -> float:
	return roundf(get_theme_constant(constant_name, THEME_TYPE) * _ui_scale)
