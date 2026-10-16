class_name RangeSprayWall
extends Node3D
## The spray wall of the Shooting Range (M14, D-208, D-209; the range_spray_wall entity): it draws
## the pattern of the gun in your hand next to where your bullets really land, and tells you how much
## of the recoil you pulled against ([SprayChart]).
##
## - **The ghost:** the gun's spray pattern as grey dots, numbered 1, 5, 10..., from the first shot:
##   where a spray would go if you held the mouse still. Before you shoot it hangs on the wall's middle
##   (sized for your distance, and it follows your gun and your steps); once you shoot it moves to your
##   first hole.
## - **Your holes:** lime dots for the spray you are firing, dim ones for the sprays before it (the last
##   150 holes are kept). Pull the mouse down against the recoil and your holes stay near the first one;
##   hold still and they follow the ghost.
## - **The sign** over the wall's top edge: the gun, the shots, your drift and the pattern's in
##   centimetres, and **control** (0 to 100 %). From [constant SprayChart.MIN_SHOTS] shots on, a finished spray
##   that beats your best control with that gun is saved as a personal best (key `spray_<gun>`, shown
##   in Stats › Training). A spray ends when you stop shooting for [constant SPRAY_END_TIME] s.
## - **Reset:** shoot the orange plate in the wall's top right corner, or type `spray_reset` in the console.
##
## It follows the player's gun ([signal Weapon.hit_landed] for where a bullet landed and
## [signal Weapon.fired] for its number in the spray). One bullet at a time only: a shotgun's pellets
## have no pattern to show. The wall is a flat rectangle at the entity (at its middle) facing the
## entity's angle (the way you stand); the marks sit 1.2 cm in front of it.

## Emitted when a finished spray was saved as a new personal best for [param weapon_id].
signal best_saved(weapon_id: StringName, control: float)

const PIXEL_FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
## Stats key prefix of a personal best; the gun's id follows.
const BEST_PREFIX := "spray_"
## Seconds without a shot that end a spray.
const SPRAY_END_TIME := 0.8
## The least control (percent) a finished spray needs to count as a best: a spray that held still isn't one.
const MIN_CONTROL := 1.0
## How many holes stay on the wall.
const MAX_MARKS := 150
## Marks sit this far in front of the wall (metres), so they don't flicker against it.
const MARK_LIFT := 0.012
## The dots' sizes as the angle they cover on your screen, in degrees: the same at any distance.
const HOLE_DEGREES := 0.5
const GHOST_DEGREES := 0.4
const GHOST_COLOR := Color(0.88, 0.88, 0.82)
const HOLE_COLOR := Color(0.78, 0.94, 0.24)
const OLD_HOLE_COLOR := Color(0.42, 0.48, 0.28)
const PLATE_COLOR := Color(1.0, 0.62, 0.15)
## The shot numbers that get a number next to their ghost dot.
const NUMBERED_SHOTS: Array[int] = [1, 10, 20, 30]
## How often the idle ghost follows the player's distance, in seconds.
const REFERENCE_INTERVAL := 0.25

## The wall's size in metres (the entity's properties).
@export var width: float = 3.2
@export var height: float = 3.0

## Where a personal best is saved: the shared book when empty (a test gives its own).
var book: StatsBook

var _player: Character
var _weapon: Weapon
var _pending_hit: Dictionary = {}
## Wall points of the spray's shots in order (a Vector2, or null for a shot that missed the wall).
var _holes: Array = []
var _active: bool = false
var _ghost: Array[Vector2] = []
var _ghost_origin: Vector2 = Vector2.ZERO
var _distance: float = 10.0
## Every mark left on the wall: {"at": Vector2, "spray": int}.
var _marks: Array[Dictionary] = []
var _spray_number: int = 0
var _idle: float = 0.0
var _reference_clock: float = 0.0
var _control: float = -1.0
var _hole_dots: MultiMeshInstance3D
var _ghost_dots: MultiMeshInstance3D
var _numbers: Array[Label3D] = []
var _sign: Label3D


## Takes the values of a range_spray_wall entity placed in TrenchBroom (D-209): the wall's size.
func _func_godot_apply_properties(properties: Dictionary) -> void:
	width = float(properties.get("width", width))
	height = float(properties.get("height", height))


func _ready() -> void:
	_hole_dots = _make_dots("Holes", MAX_MARKS)
	_ghost_dots = _make_dots("Ghost", 64)
	for shot in NUMBERED_SHOTS:
		var label := Label3D.new()
		label.name = "Number%d" % shot
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = PIXEL_FONT
		label.font_size = 8
		label.pixel_size = 1.0 / 240.0
		label.fixed_size = true
		label.outline_size = 2
		label.outline_modulate = Color(0.08, 0.08, 0.08)
		label.modulate = GHOST_COLOR
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.text = str(shot)
		label.visible = false
		add_child(label)
		_numbers.append(label)
	_build_plate()
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.font = PIXEL_FONT
	_sign.font_size = 8
	_sign.pixel_size = 1.0 / 240.0
	_sign.fixed_size = true
	_sign.outline_size = 2
	_sign.outline_modulate = Color(0.08, 0.08, 0.08)
	_sign.modulate = Color(0.92, 0.9, 0.82)
	_sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Above the wall's top edge, in the air: nothing hides it, whichever side the wall's neighbours are.
	_sign.position = _wall_to_local(Vector2(0.0, height * 0.5 + 0.5))
	add_child(_sign)
	_update_sign()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_find_player()
		return
	_idle += delta
	if _active and _idle >= SPRAY_END_TIME:
		_finish_spray()
	if not _active:
		_reference_clock -= delta
		if _reference_clock <= 0.0:
			_reference_clock = REFERENCE_INTERVAL
			_show_reference()


## The direction the wall faces (toward the people shooting at it), from the entity's angle.
func get_normal() -> Vector3:
	return -global_transform.basis.z.normalized()


## The wall's right as you look at it.
func get_right() -> Vector3:
	return Vector3.UP.cross(get_normal()).normalized()


## The point on the wall ([param at] in metres: right, up from its middle) in the world.
func local_to_world(at: Vector2) -> Vector3:
	return global_position + get_right() * at.x + Vector3.UP * at.y + get_normal() * MARK_LIFT


## Where [param world_position] is on the wall (right, up from its middle in metres), or null when
## it isn't on the wall (too far in front of it or behind it, or outside its edges).
func wall_point(world_position: Vector3) -> Variant:
	var offset := world_position - global_position
	if absf(offset.dot(get_normal())) > 0.3:
		return null
	var at := Vector2(offset.dot(get_right()), offset.dot(Vector3.UP))
	if absf(at.x) > width * 0.5 or absf(at.y) > height * 0.5:
		return null
	return at


## The shots of the spray going on (or the last one) as wall points, null for a shot that missed.
func get_holes() -> Array:
	return _holes.duplicate()


## Seconds since the last shot with the gun in hand (the training screen's panel stays a few seconds).
func get_idle_seconds() -> float:
	return _idle


## The gun in hand that the wall is following, or null.
func get_weapon_data() -> WeaponData:
	return _weapon.data if _weapon != null and is_instance_valid(_weapon) else null


## How many shots the spray now on has (0 before the first) and how many its pattern has.
func get_spray_shots() -> int:
	return _holes.size()


func get_pattern_size() -> int:
	var data := get_weapon_data()
	return data.spray_pattern.size() if data != null else 0


## The ghost: the pattern's points as wall points, from the first shot's place (empty without a pattern).
func get_ghost() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for offset in _ghost:
		points.append(_ghost_origin + offset)
	return points


## True while a spray you fired is the one on the wall (the ghost sits on its first hole).
func is_spray_active() -> bool:
	return _active


## How many holes are on the wall, all sprays together.
func get_mark_count() -> int:
	return _marks.size()


## Control of the spray going on, 0 to 100, or -1 until it has [constant SprayChart.MIN_SHOTS] shots.
func get_control() -> float:
	return _control


## The sign's text.
func get_sign_text() -> String:
	return _sign.text


## The distance used to size the ghost, in metres.
func get_distance() -> float:
	return _distance


## The key of the personal best for [param weapon_id] in the stats file.
static func best_key(weapon_id: StringName) -> String:
	return BEST_PREFIX + String(weapon_id)


## Clears the wall: every hole, and the ghost back to the middle. Does nothing to your bests.
func reset() -> void:
	_finish_spray()
	_marks.clear()
	_holes.clear()
	_active = false
	_control = -1.0
	_show_reference()
	_redraw()


# --- Following the gun ---


func _find_player() -> void:
	for character in Character.all_in_world(self):
		if character.is_local_player():
			_player = character
			_player.weapon_changed.connect(_on_weapon_changed)
			_on_weapon_changed(_player.weapon)
			return


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and is_instance_valid(_weapon):
		if _weapon.hit_landed.is_connected(_on_hit_landed):
			_weapon.hit_landed.disconnect(_on_hit_landed)
		if _weapon.fired.is_connected(_on_fired):
			_weapon.fired.disconnect(_on_fired)
	_finish_spray()
	_weapon = weapon
	_pending_hit = {}
	if weapon != null:
		weapon.hit_landed.connect(_on_hit_landed)
		weapon.fired.connect(_on_fired)
	_show_reference()


func _on_hit_landed(hit: Dictionary) -> void:
	_pending_hit = hit


## A shot of the gun in hand: [param spray_shot] is its number in the spray. Its hit (just before)
## says where it landed.
func _on_fired(spray_shot: int) -> void:
	var hit := _pending_hit
	_pending_hit = {}
	if _weapon == null or _weapon.data.pellets > 1:
		return
	_idle = 0.0
	TrainingHub.wall = self
	# Where the bullet first met something: a bullet that goes through the wall (D-214) still made its hole here.
	var at: Variant = wall_point(hit.get("first_position", hit["position"])) if hit.has("position") else null
	# A bullet in the reset plate clears the wall instead of leaving a hole.
	if at != null and _in_plate(at as Vector2):
		reset()
		return
	if spray_shot == 1:
		_finish_spray()
		_begin_spray(at)
	if not _active:
		return
	while _holes.size() < spray_shot:
		_holes.append(null)
	_holes[spray_shot - 1] = at
	if at != null:
		_marks.append({"at": at, "spray": _spray_number})
		while _marks.size() > MAX_MARKS:
			_marks.pop_front()
	_control = SprayChart.spray_control(_holes, get_ghost_offsets()) if _holes.size() >= SprayChart.MIN_SHOTS else -1.0
	_redraw()


## The ghost relative to the first shot (what [SprayChart] takes).
func get_ghost_offsets() -> Array[Vector2]:
	return _ghost.duplicate()


## A new spray starts at [param first]: the wall point of its first bullet (null when that missed the
## wall, and then there is nothing to draw until the next spray).
func _begin_spray(first: Variant) -> void:
	_holes.clear()
	_spray_number += 1
	_control = -1.0
	if first == null:
		_active = false
		_show_reference()
		return
	_active = true
	_distance = maxf(_player.get_eye_position().distance_to(local_to_world(first as Vector2)), 1.0)
	var pattern := _weapon.data.spray_pattern
	_ghost = SprayChart.ghost(pattern, _distance, pattern.size())
	_ghost_origin = first as Vector2


## Ends the spray going on: a spray of at least [constant SprayChart.MIN_SHOTS] shots with a pattern
## to control that beats the best control with this gun is saved.
func _finish_spray() -> void:
	if not _active:
		return
	_active = false
	if _weapon == null or _holes.size() < SprayChart.MIN_SHOTS:
		return
	var ghost_drift := SprayChart.drift(_ghost_with_gaps())
	if ghost_drift <= 0.0001:
		return
	var control := SprayChart.spray_control(_holes, get_ghost_offsets())
	if control < MIN_CONTROL:
		return
	var your_drift := SprayChart.drift(_holes)
	var id := _weapon.data.id
	if _book().submit_best(best_key(id), snappedf(control, 0.1), {
			"shots": _holes.size(), "drift_cm": snappedf(your_drift * 100.0, 0.1), "pattern_cm": snappedf(ghost_drift * 100.0, 0.1)}):
		best_saved.emit(id, control)
	_update_sign()


## The ghost's points for the shots of this spray, with the shots that missed the wall left out
## (the same shots [method SprayChart.spray_control] compares).
func _ghost_with_gaps() -> Array:
	var counted: Array = []
	for index in mini(_holes.size(), _ghost.size()):
		counted.append(_ghost[index] if index == 0 or _holes[index] != null else null)
	return counted


## With no spray on the wall the ghost hangs on its middle, sized for the player's distance.
func _show_reference() -> void:
	if _active or _weapon == null or _player == null or not is_instance_valid(_player):
		return
	var pattern := _weapon.data.spray_pattern
	_distance = clampf(_player.get_eye_position().distance_to(global_position), 1.0, 60.0)
	_ghost.clear()
	if _weapon.data.pellets <= 1:
		_ghost = SprayChart.ghost(pattern, _distance, pattern.size())
	_ghost_origin = Vector2.ZERO
	_redraw()


# --- Drawing ---


func _make_dots(dots_name: String, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var quad := QuadMesh.new()
	# One metre across: each dot is scaled to its size when it is drawn.
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	multi.mesh = quad
	multi.instance_count = count
	multi.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = dots_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## A point on the wall ([param at]: right, up in metres from its middle) in this node's own space:
## the node's -Z points to the shooter, so a mark [param lift] metres in front of the wall has a
## negative z, and the node's +X is the wall's left (the viewer's right is -X).
func _wall_to_local(at: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(-at.x, at.y, -(MARK_LIFT + lift))


func _build_plate() -> void:
	var plate := MeshInstance3D.new()
	plate.name = "ResetPlate"
	var quad := QuadMesh.new()
	quad.size = _plate_rect().size
	var material := StandardMaterial3D.new()
	material.albedo_color = PLATE_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	plate.mesh = quad
	plate.position = _wall_to_local(_plate_rect().get_center(), 0.002)
	# A QuadMesh faces +Z, the wall's front is this node's -Z: turn it round.
	plate.rotation = Vector3(0.0, PI, 0.0)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)
	var label := Label3D.new()
	label.name = "ResetLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = PIXEL_FONT
	label.font_size = 8
	label.pixel_size = 1.0 / 240.0
	label.fixed_size = true
	label.outline_size = 2
	label.outline_modulate = Color(0.08, 0.08, 0.08)
	label.text = "RESET"
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Under the plate, short enough to stay clear of the ghost's numbers in the middle.
	label.position = _wall_to_local(_plate_rect().get_center() + Vector2(0.0, -0.3), 0.02)
	add_child(label)


## The reset plate: a rectangle in the wall's top corner (the viewer's right, where there is air
## next to the wall for its label), in wall points.
func _plate_rect() -> Rect2:
	var size := Vector2(0.7, 0.4)
	return Rect2(Vector2(width * 0.5 - 0.1 - size.x, height * 0.5 - 0.1 - size.y), size)


func _in_plate(at: Vector2) -> bool:
	return _plate_rect().has_point(at)


## Draws the marks, the ghost, its numbers and the sign from the current state.
func _redraw() -> void:
	var holes := _hole_dots.multimesh
	holes.visible_instance_count = _marks.size()
	var hole_basis := Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3.ONE * _dot_size(HOLE_DEGREES))
	for index in _marks.size():
		var at: Vector2 = _marks[index]["at"]
		holes.set_instance_transform(index, Transform3D(hole_basis, _wall_to_local(at, 0.004)))
		holes.set_instance_color(index, HOLE_COLOR if _marks[index]["spray"] == _spray_number else OLD_HOLE_COLOR)
	var points := get_ghost()
	var ghost := _ghost_dots.multimesh
	ghost.visible_instance_count = mini(points.size(), ghost.instance_count)
	var ghost_basis := Basis.from_euler(Vector3(0.0, PI, 0.0)).scaled(Vector3.ONE * _dot_size(GHOST_DEGREES))
	for index in ghost.visible_instance_count:
		ghost.set_instance_transform(index, Transform3D(ghost_basis, _wall_to_local(points[index])))
		ghost.set_instance_color(index, GHOST_COLOR)
	for slot in _numbers.size():
		var shot := NUMBERED_SHOTS[slot]
		var label := _numbers[slot]
		label.visible = shot <= points.size()
		if label.visible:
			label.position = _wall_to_local(points[shot - 1] + Vector2(0.0, 0.12), 0.02)
	_update_sign()


## How wide a dot of [param degrees] across is on the wall, for the distance it is shot or seen from.
func _dot_size(degrees: float) -> float:
	return _distance * tan(deg_to_rad(degrees))


func _update_sign() -> void:
	if _sign == null:
		return
	var lines := PackedStringArray(["SPRAY WALL"])
	if _weapon == null or _weapon.data == null:
		lines.append("TAKE A GUN")
	elif _weapon.data.pellets > 1:
		lines.append("%s: ONE BULLET AT A TIME ONLY" % _weapon.data.display_name.to_upper())
	elif _weapon.data.spray_pattern.size() < 2:
		lines.append("%s HAS NO PATTERN" % _weapon.data.display_name.to_upper())
	elif _holes.is_empty():
		lines.append("%s · SPRAY AT THE MIDDLE" % _weapon.data.display_name.to_upper())
	else:
		lines.append("%s · %d SHOTS" % [_weapon.data.display_name.to_upper(), _holes.size()])
		if _control >= 0.0:
			var your_drift := SprayChart.drift(_holes) * 100.0
			var pattern_drift := SprayChart.drift(_ghost_with_gaps()) * 100.0
			lines.append("DRIFT %d CM · PATTERN %d CM" % [roundi(your_drift), roundi(pattern_drift)])
			lines.append("CONTROL %d %%" % roundi(_control))
		else:
			lines.append("CONTROL SHOWS FROM %d SHOTS" % SprayChart.MIN_SHOTS)
	if _weapon != null and _weapon.data != null:
		var best := _book().get_best_score(best_key(_weapon.data.id))
		if best > 0.0:
			lines.append("BEST %d %%" % roundi(best))
	_sign.text = "\n".join(lines)


func _book() -> StatsBook:
	return book if book != null else StatsBook.get_instance()
