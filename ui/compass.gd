class_name Compass
extends Control
## The HUD's compass, the designer's "29 Compass callouts" (M11 D-180, redone as v0.2 D-232): a strip under the score
## that turns with your view. It shows 90 degrees each side (180 across 448 pixels): a tick every 15 degrees, a taller
## one at the 45-degree points, N, E, S and W at the 90-degree points, on a dim backing, and a box under the middle
## with the heading in degrees. When an enemy fires, a red mark (4 × 16, a 1 px dark edge) appears at that bearing: full
## for one second, 60 % for the second, 30 % for the third, then gone. A shot from further to the side than the strip
## shows pins to the strip's end as a wider mark (8), so you know which way to turn. One mark per shooter: his next shot moves
## it and starts it over. Only shots within [constant Noises.GUNSHOT_RANGE] show (the range bots hear them from),
## and not your own team's or yours.
##
## **Callouts:** when a bot on your team calls out an enemy ([signal RoundManager.callout_made]), a tag
## ("ENEMY · A", red frame) hangs under that bearing for four seconds, one at a time; the kill feed gets the same
## line ([method KillFeed.add_callout]). The tag steps aside for the heading box.
##
## It reads [signal Noises.shot_fired]: the host's own shots, the bots' and, on a client, the other players'
## shots as the host reported them ([method Weapon.play_remote_shot]), so it needs nothing from the host. A
## pure view, drawn with [method _draw] from the theme's "Hud" type (the sizes are tokens in tools/ui_palette.gd)
## and the palette; it scales with the HUD ([method set_ui_scale]) and takes no mouse clicks. Time is counted in
## [method _process] deltas, so a pause freezes the marks. The Interface settings' Compass switch hides it.

## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## The labels' type whose font size the letters use.
const LETTER_TYPE := &"HudSmallLabel"
## The letters at 0, 90, 180 and 270 degrees.
const LETTERS: Array[String] = ["N", "E", "S", "W"]
## The tag's text, and its side padding and the gap above it (design pixels).
const TAG_TEXT := "ENEMY · %s"
const TAG_PAD := 8
const TAG_GAP := 4
## How far left of its bearing the tag starts (design pixels).
const TAG_LEAD := 10

## The character whose view the strip shows (the player, or the teammate being spectated).
var _view: Character
## The enemies' marks, by the shooter's instance id: {"position": where the shot came from, "age": seconds since it}.
var _marks: Dictionary = {}
## The callout tag showing: {"position": where the enemy is, "text": the tag's text, "left": seconds left}, or empty.
var _tag: Dictionary = {}
var _manager: RoundManager
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
	_marks.clear()
	_tag = {}
	queue_redraw()


## Listens to the callouts of the match run by [param manager] (null: none).
func set_round_manager(manager: RoundManager) -> void:
	if is_instance_valid(_manager) and _manager.callout_made.is_connected(_on_callout_made):
		_manager.callout_made.disconnect(_on_callout_made)
	_manager = manager
	_tag = {}
	if manager != null:
		manager.callout_made.connect(_on_callout_made)


## Scales the strip with the HUD (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	queue_redraw()


## Counts [param seconds] more of the marks' and the tag's time and redraws. [code]_process[/code] calls it every frame;
## tests call it to skip ahead.
func advance(seconds: float) -> void:
	var lifetime := _step_seconds() * 3.0
	for id: int in _marks.keys():
		_marks[id]["age"] += seconds
		if _marks[id]["age"] >= lifetime:
			_marks.erase(id)
	if not _tag.is_empty():
		_tag["left"] -= seconds
		if _tag["left"] <= 0.0:
			_tag = {}
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


## How many enemy marks show.
func get_marker_count() -> int:
	return _marks.size()


## The marks showing, as how many degrees to the right of your view each lies (negative: to the left), -180 to 180,
## in the order they appeared.
func get_marker_offsets() -> Array[float]:
	var offsets: Array[float] = []
	for id: int in _marks:
		offsets.append(_offset_of(_marks[id]["position"]))
	return offsets


## The opacity (0 to 1) of the first mark, or 0 with none: full for the first second, then 60 %, then 30 %.
func get_marker_alpha() -> float:
	for id: int in _marks:
		return _alpha(_marks[id]["age"])
	return 0.0


## The marks' rectangles in this control's pixels, as drawn (a mark past the strip's edge is pinned to the end and wider).
func get_marker_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half_arc := get_theme_constant(&"compass_arc", THEME_TYPE) / 2.0
	var height := _scaled(&"compass_mark_height")
	var top := roundf((_row_height() - height) / 2.0)
	for id: int in _marks:
		var offset := _offset_of(_marks[id]["position"])
		var pinned := absf(offset) > half_arc
		var width := _scaled(&"compass_mark_pinned" if pinned else &"compass_mark_width")
		var x := x_for_offset(clampf(offset, -half_arc, half_arc))
		if pinned:
			x = clampf(x, width / 2.0, size.x - width / 2.0)
		rects.append(Rect2(Vector2(roundf(x - width / 2.0), top), Vector2(width, height)))
	return rects


## The callout tag's text ("ENEMY · A"), or "" while there is none.
func get_tag_text() -> String:
	return "" if _tag.is_empty() else String(_tag["text"])


## The callout tag's rectangle in this control's pixels, or an empty one.
func get_tag_rect() -> Rect2:
	if _tag.is_empty():
		return Rect2()
	var font := get_theme_font(&"font", &"Label")
	var font_size := _letter_size()
	var width := font.get_string_size(String(_tag["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2.0 * _px(TAG_PAD) + 2.0 * _scaled(&"compass_thickness")
	var height := _scaled(&"compass_tag")
	var x := x_for_offset(clampf(_offset_of(_tag["position"]), -90.0, 90.0)) - _px(TAG_LEAD)
	x = clampf(x, 0.0, maxf(size.x - width, 0.0))
	var rect := Rect2(Vector2(roundf(x), _row_height() + _px(TAG_GAP)), Vector2(width, height))
	# The heading box hangs under the middle: the tag goes beside it, on the side of its bearing.
	var box := get_box_rect()
	if rect.intersects(box):
		rect.position.x = box.position.x - width - _px(TAG_GAP) if rect.get_center().x < box.get_center().x else box.end.x + _px(TAG_GAP)
	return rect


## The heading box's rectangle under the middle of the strip.
func get_box_rect() -> Rect2:
	var width := _scaled(&"compass_box_width")
	return Rect2(Vector2(roundf(size.x / 2.0 - width / 2.0), _row_height()), Vector2(width, _scaled(&"compass_box_height")))


func _on_shot_fired(shot_position: Vector3, source: Character) -> void:
	if not is_instance_valid(_view) or not is_instance_valid(source) or source == _view or Teams.is_viewer_ally(source):
		return
	# Another game in the same process (the online tests) has its own world.
	if source.get_world_3d() != _view.get_world_3d():
		return
	if shot_position.distance_to(_view.global_position) > Noises.GUNSHOT_RANGE:
		return
	_marks[source.get_instance_id()] = {"position": shot_position, "age": 0.0}
	queue_redraw()


func _on_callout_made(_team: int, caller: Character, point: Vector3, place: String) -> void:
	if not is_instance_valid(caller) or not Teams.is_viewer_ally(caller) or not is_instance_valid(_view):
		return
	_tag = {"position": point, "text": TAG_TEXT % place, "left": get_theme_constant(&"compass_tag_ms", THEME_TYPE) / 1000.0}
	queue_redraw()


## How many degrees to the right of your view a world position lies, -180 to 180.
func _offset_of(world_position: Vector3) -> float:
	var away := world_position - _view.global_position
	return wrapf(rad_to_deg(atan2(away.x, -away.z)) - get_heading(), -180.0, 180.0)


## A mark's opacity by its age: the theme's three steps, each [code]compass_step_ms[/code] long.
func _alpha(age: float) -> float:
	var step := int(age / _step_seconds())
	return get_theme_constant(&"compass_alpha_%d" % (clampi(step, 0, 2) + 1), THEME_TYPE) / 100.0


func _step_seconds() -> float:
	return get_theme_constant(&"compass_step_ms", THEME_TYPE) / 1000.0


## The strip's height: the heading box's.
func _row_height() -> float:
	return _scaled(&"compass_box_height")


func _letter_size() -> int:
	return maxi(1, roundi(get_theme_font_size(&"font_size", LETTER_TYPE) * _ui_scale))


@warning_ignore("integer_division")
func _draw() -> void:
	if not is_instance_valid(_view):
		return
	var arc := float(get_theme_constant(&"compass_arc", THEME_TYPE))
	var step := get_theme_constant(&"compass_tick_step", THEME_TYPE)
	var heading := get_heading()
	var row := _row_height()
	var thickness := _scaled(&"compass_thickness")
	var shadow_colour := get_theme_color(&"void", PALETTE_TYPE)
	var text_colour := get_theme_color(&"text", PALETTE_TYPE)
	var font := get_theme_font(&"font", &"Label")
	var font_size := _letter_size()
	draw_rect(Rect2(0.0, 0.0, size.x, row), get_theme_color(&"compass_backing", PALETTE_TYPE))
	# Ticks and letters: every [step] degrees from just left of the strip to just right of it.
	var angle := floori((heading - arc / 2.0) / step) * step
	while angle <= heading + arc / 2.0 + step:
		var x := roundf(x_for_offset(angle - heading))
		var turn := posmod(angle, 360)
		if turn % 90 == 0:
			var letter := LETTERS[turn / 90]
			var letter_width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if x - letter_width / 2.0 >= 0.0 and x + letter_width / 2.0 <= size.x:
				var baseline := roundf((row + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
				draw_string(font, Vector2(roundf(x - letter_width / 2.0), baseline), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_colour)
		elif x >= 0.0 and x <= size.x:
			var tall := _scaled(&"compass_tick_large" if turn % 45 == 0 else &"compass_tick_small")
			draw_rect(Rect2(x - thickness / 2.0, roundf((row - tall) / 2.0), thickness, tall), text_colour)
		angle += step
	# The enemies' marks, red, a dark edge, stepping down.
	var rects := get_marker_rects()
	var index := 0
	for id: int in _marks:
		var colour := _enemy_colour()
		colour.a = _alpha(_marks[id]["age"])
		var mark := rects[index]
		draw_rect(mark.grow(1.0), Color(shadow_colour, colour.a))
		draw_rect(mark, colour)
		index += 1
	# The heading box: ink, framed in the text colour except at the top.
	var box := get_box_rect()
	draw_rect(box, get_theme_color(&"ink", PALETTE_TYPE))
	draw_rect(Rect2(box.position.x, box.end.y - thickness, box.size.x, thickness), text_colour)
	draw_rect(Rect2(box.position.x, box.position.y, thickness, box.size.y), text_colour)
	draw_rect(Rect2(box.end.x - thickness, box.position.y, thickness, box.size.y), text_colour)
	var heading_text := str(roundi(heading) % 360)
	var heading_width := font.get_string_size(heading_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(roundf(box.get_center().x - heading_width / 2.0), roundf(box.position.y + (box.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)),
			heading_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_colour)
	# The callout tag: ink, an enemy-coloured frame and text.
	if not _tag.is_empty():
		var tag := get_tag_rect()
		var enemy := _enemy_colour()
		draw_rect(tag, enemy)
		draw_rect(Rect2(tag.position + Vector2.ONE * thickness, tag.size - Vector2.ONE * 2.0 * thickness), get_theme_color(&"ink", PALETTE_TYPE))
		draw_string(font, Vector2(tag.position.x + thickness + _px(TAG_PAD), roundf(tag.position.y + (tag.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)),
				String(_tag["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, enemy)


## The UI colour of an enemy (the colour-blind scheme's when it is on). Every mark is an enemy's (a
## shot by somebody on your side is ignored, [method Teams.is_viewer_ally]; in a free-for-all that is
## everybody but you), so a mark's colour never depends on who fired.
func _enemy_colour() -> Color:
	return Teams.scheme_color(&"enemy_text")


## A size of the HUD's theme type, scaled with the HUD and rounded to whole pixels.
func _scaled(constant_name: StringName) -> float:
	return roundf(get_theme_constant(constant_name, THEME_TYPE) * _ui_scale)


## A design-pixel size scaled with the HUD and rounded.
func _px(design: int) -> float:
	return roundf(design * _ui_scale)
