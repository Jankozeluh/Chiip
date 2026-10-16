class_name TargetDummy
extends Node3D
## A training dummy with CS-style hit zones (see [Hitbox]).
##
## Shows each hit as a floating damage number and keeps a running total, which
## resets after a few seconds without hits. Can move from side to side.

const HEADSHOT_COLOR := Color(1.0, 0.3, 0.25)
const HIT_COLOR := Color(1.0, 0.9, 0.4)
const PIXEL_FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")

## Shown above the dummy, e.g. its distance from the firing line.
@export var title: String = ""
## How far the dummy moves from side to side, in metres (0 = stands still).
@export var move_distance: float = 0.0
## Side-to-side speed in m/s. A player running with a rifle: 5.5.
@export var move_speed: float = 2.5
## Seconds without hits before the total resets.
@export var total_reset_time: float = 3.0

var _start_position: Vector3
var _travelled: float = 0.0
var _total_damage: float = 0.0
var _hit_count: int = 0
var _time_since_hit: float = 0.0

@onready var _total_label: Label3D = $TotalLabel


func _ready() -> void:
	_start_position = position
	for child in $Hitboxes.get_children():
		if child is Hitbox:
			(child as Hitbox).hit.connect(_on_hit)
	_update_label()


func _physics_process(delta: float) -> void:
	if move_distance > 0.0:
		_travelled += move_speed * delta
		var offset := pingpong(_travelled, move_distance) - move_distance * 0.5
		position = _start_position + basis.x * offset
	if _hit_count > 0:
		_time_since_hit += delta
		if _time_since_hit > total_reset_time:
			_total_damage = 0.0
			_hit_count = 0
			_update_label()


func _on_hit(damage: float, zone: Hitbox.Zone, hit_position: Vector3, _attacker: Node, _penetration: float, _source: WeaponData) -> void:
	_total_damage += damage
	_hit_count += 1
	_time_since_hit = 0.0
	_update_label()
	_show_damage_number(damage, zone, hit_position)


func _update_label() -> void:
	var lines: PackedStringArray = []
	if title != "":
		lines.append(title)
	if _hit_count > 0:
		lines.append("%d dmg · %d hit%s" % [int(_total_damage), _hit_count, "" if _hit_count == 1 else "s"])
	_total_label.text = "\n".join(lines)


## A number that floats up from the hit and fades out. Damage is shown
## rounded down, as CS does.
func _show_damage_number(damage: float, zone: Hitbox.Zone, hit_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = str(int(damage))
	label.modulate = HEADSHOT_COLOR if zone == Hitbox.Zone.HEAD else HIT_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	# Same look as the other labels: pixel font, fixed size on screen, crisp pixels.
	label.font = PIXEL_FONT
	label.font_size = 8
	label.outline_size = 2
	label.fixed_size = true
	label.pixel_size = _total_label.pixel_size
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Moved every frame by a tween, so don't smooth it between physics ticks.
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Added next to the dummy, not to it, so it doesn't move along with a moving dummy.
	get_parent().add_child(label)
	label.global_position = hit_position + Vector3(0.0, 0.15, 0.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", label.global_position + Vector3(0.0, 0.6, 0.0), 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
