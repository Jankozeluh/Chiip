class_name WeaponSpot
extends Node3D
## A map weapon (M7 tasks 9 and 16, D-098): a gun floating and turning over a glowing gold ring on
## the floor, with its name over it and a thin beam of light, so you can see it's there from across
## the area. Walk over it to take the gun (or press E to swap it for the one in that slot), like
## any gun on the floor ([WeaponPickup], [Inventory]). Once the gun is taken the spot emits
## [signal taken] and goes away.
##
## [MapWeapons] puts these out at random places (no map places them any more) and decides when
## new ones come.

## Emitted when [param by] took the gun; the spot frees itself right after.
signal taken(by: Character)

## Group of every spot.
const GROUP := "weapon_spots"
## How high the gun floats above the floor (metres), and how fast it turns (radians a second).
const FLOAT_HEIGHT := 0.9
const TURN_SPEED := 1.2
const RING_COLOR := Color(1.0, 0.78, 0.25)
## How bright the ring is with a gun on it, and empty.
const FULL_GLOW := 2.0
const EMPTY_GLOW := 0.25

## The beam of light rises from above the name (so it never hides the gun) this high (metres),
## and how strongly it shows.
const BEAM_BOTTOM := 1.8
const BEAM_HEIGHT := 2.8
const BEAM_ALPHA := 0.22

## The gun it puts out. Set before it enters the tree.
@export var weapon: WeaponData
## Online, on a client (M9, D-113): only the ring, the name and the light of the host's spot; the
## gun floating over it is the host's too (a copied [WeaponPickup]). Set before it enters the tree.
var replica: bool = false

var _pickup: WeaponPickup
var _ring_material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group(GROUP)
	_build_marker()
	refill()


## True while a gun waits on it.
func has_weapon() -> bool:
	return is_instance_valid(_pickup) and not _pickup.is_queued_for_deletion() and _pickup.is_in_group(WeaponPickup.GROUP)


## The gun waiting on it, or null.
func get_pickup() -> WeaponPickup:
	return _pickup if has_weapon() else null


## Puts a fresh gun out (with full ammo) unless one is there already.
func refill() -> void:
	if replica:
		_set_glow(true)
		return
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


## Called by [method Inventory.take] when someone takes the gun: tells [signal taken] and goes away.
func on_taken(by: Character) -> void:
	_pickup = null
	_set_glow(false)
	remove_from_group(GROUP)
	taken.emit(by)
	queue_free()


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
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.035
	cylinder.bottom_radius = 0.06
	cylinder.height = BEAM_HEIGHT
	cylinder.radial_segments = 6
	cylinder.rings = 1
	beam.mesh = cylinder
	beam.position = Vector3.UP * (BEAM_BOTTOM + BEAM_HEIGHT * 0.5)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(RING_COLOR, BEAM_ALPHA)
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_label = Label3D.new()
	_label.name = "Name"
	_label.text = weapon.display_name.to_upper() if weapon != null else ""
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3.UP * (FLOAT_HEIGHT + 0.55)
	_label.pixel_size = 0.006
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
