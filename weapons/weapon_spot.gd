class_name WeaponSpot
extends Node3D
## A power-weapon spot on a map (M7 task 9, D-098): a glowing gold ring on the floor with
## [member weapon] turning above it and its name over it, so you can see it's there from across
## the area. Walk over it to take the gun (or press E to swap it for the one in that slot), like
## any gun on the floor ([WeaponPickup], [Inventory]). The ring dims while it's empty.
##
## When it comes back: in rounds the [RoundManager] puts a fresh one out at every round start
## ([method refill], [member timed] off); in team respawn and practice it comes back by itself
## [member respawn_time] seconds after being taken. Counted in physics ticks.
##
## Maps put these under a "Pickups" node, in the group [constant GROUP] (docs/MAPS.md).

## Group of every spot.
const GROUP := "weapon_spots"
## How high the gun floats above the floor (metres), and how fast it turns (radians a second).
const FLOAT_HEIGHT := 0.9
const TURN_SPEED := 1.2
const RING_COLOR := Color(1.0, 0.78, 0.25)
## How bright the ring is with a gun on it, and empty.
const FULL_GLOW := 2.0
const EMPTY_GLOW := 0.25

## The gun it puts out.
@export var weapon: WeaponData
## Seconds before it comes back after being taken, when [member timed].
@export var respawn_time: float = 30.0
## Comes back by itself after [member respawn_time] (team respawn, practice). The round manager
## turns it off and refills it at every round start instead.
@export var timed: bool = true

var _pickup: WeaponPickup
var _wait_left: float = -1.0
var _ring_material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group(GROUP)
	_build_marker()
	refill()


func _physics_process(delta: float) -> void:
	if _wait_left >= 0.0 and timed:
		_wait_left -= delta
		if _wait_left < 0.0:
			refill()


## True while a gun waits on it.
func has_weapon() -> bool:
	return is_instance_valid(_pickup) and not _pickup.is_queued_for_deletion() and _pickup.is_in_group(WeaponPickup.GROUP)


## The gun waiting on it, or null.
func get_pickup() -> WeaponPickup:
	return _pickup if has_weapon() else null


## Puts a fresh gun out (with full ammo) unless one is there already.
func refill() -> void:
	_wait_left = -1.0
	if has_weapon() or weapon == null or not is_inside_tree():
		_set_glow(has_weapon())
		return
	_pickup = WeaponPickup.spawn(self, weapon, weapon.magazine_size, weapon.reserve_ammo,
			global_position + Vector3.UP * FLOAT_HEIGHT, global_rotation.y)
	_pickup.floating = true
	_pickup.spot = self
	_set_glow(true)


## Takes the gun away without anyone getting it (a test, or a map that wants it gone).
func clear() -> void:
	if is_instance_valid(_pickup):
		_pickup.remove_from_group(WeaponPickup.GROUP)
		_pickup.queue_free()
	_pickup = null
	_set_glow(false)


## Called by [method Inventory.take] when someone takes the gun: the spot is empty until
## [method refill], or for [member respawn_time] when [member timed].
func on_taken(_by: Character) -> void:
	_pickup = null
	_set_glow(false)
	_wait_left = respawn_time


func _build_marker() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = Vector3.UP * 0.03
	ring.scale = Vector3(1.0, 0.25, 1.0)
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = RING_COLOR
	_ring_material.emission_enabled = true
	_ring_material.emission = RING_COLOR
	ring.material_override = _ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_label = Label3D.new()
	_label.name = "Name"
	_label.text = weapon.display_name.to_upper() if weapon != null else ""
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3.UP * (FLOAT_HEIGHT + 0.55)
	_label.pixel_size = 0.004
	_label.font_size = 32
	_label.outline_size = 8
	_label.modulate = RING_COLOR
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_label)


func _set_glow(full: bool) -> void:
	if _ring_material != null:
		_ring_material.emission_energy_multiplier = FULL_GLOW if full else EMPTY_GLOW
	if _label != null:
		_label.visible = full
