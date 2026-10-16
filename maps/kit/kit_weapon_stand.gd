class_name KitWeaponStand
extends Node3D
## A gun stand for training maps (the range_weapon entity, D-142): one [WeaponSpot] with the gun
## named by [member weapon_id], which comes back [member refill_time] seconds after someone takes
## it, so every gun can be tried again and again. Walk over the ring to take the gun, or press E to
## swap it for the one in that slot (like any gun on the floor).
##
## For practice maps only (the Shooting Range): in a match guns come from the buy menu and from
## [MapWeapons], never from a fixed place on the map (D-098).

const SPOT_SCENE := preload("res://weapons/weapon_spot.tscn")

## The gun: a [member WeaponData.id] (pistol, hand_cannon, smg, shotgun, carbine, rifle, sniper,
## frag, flashbang, smoke).
@export var weapon_id: StringName = &"rifle"
## Seconds before a taken gun comes back.
@export var refill_time: float = 2.0

var _spot: WeaponSpot


func _func_godot_apply_properties(properties: Dictionary) -> void:
	weapon_id = StringName(str(properties.get("weapon", weapon_id)).strip_edges())
	refill_time = float(properties.get("refill_time", refill_time))


func _ready() -> void:
	if not Engine.is_editor_hint():
		_put_out()


## The spot with the gun on it, or null while the stand waits to put a new one out.
func get_spot() -> WeaponSpot:
	return _spot if is_instance_valid(_spot) and not _spot.is_queued_for_deletion() else null


func _put_out() -> void:
	var data := WeaponData.find(weapon_id)
	if data == null:
		push_warning("%s: no weapon '%s'" % [name, weapon_id])
		return
	_spot = SPOT_SCENE.instantiate() as WeaponSpot
	_spot.weapon = data
	add_child(_spot)
	_spot.taken.connect(_on_taken)


func _on_taken(_by: Character) -> void:
	_spot = null
	# Counts game time only (false: the pause stops it).
	await get_tree().create_timer(refill_time, false).timeout
	if is_inside_tree():
		_put_out()
