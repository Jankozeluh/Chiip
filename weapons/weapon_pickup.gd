class_name WeaponPickup
extends Node3D
## A gun lying on the floor (M7, D-094): dropped with G, by someone who died, or put out by a
## power-weapon spot. It keeps the gun's ammo. A character takes it by walking over it into a
## free slot, or with Use (E) while looking at it to swap it for the gun in that slot (see
## [method Inventory.update_pickups] and [method Inventory.try_swap]). It only shows the gun:
## it has no collision, so it never blocks movement or bullets.
##
## Pickups are found through the group [constant GROUP]. The [RoundManager] clears them at every
## round start (a fresh loadout, D-090). Authority code decides who takes one; the node itself is
## what everyone sees.

## Group of every gun lying on the floor.
const GROUP := "weapon_pickups"
## Seconds a gun you dropped ignores you before you can walk over it and take it back.
const DROPPER_DELAY := 1.0
## How fast a dropped gun falls to the floor, in m/s² (CS's 800 units/s², like everything).
const FALL_GRAVITY := 20.3
## How far below its drop point it looks for the floor (metres).
const FLOOR_SEARCH := 6.0
## How high above the floor its middle rests (it lies on its side).
const REST_HEIGHT := 0.04

## The gun.
var data: WeaponData
## Its ammo, as it was when it was dropped.
var magazine: int = 0
var reserve: int = 0
## Who dropped it: they can't take it back for [constant DROPPER_DELAY] seconds.
var dropped_by: Character
## The power-weapon spot that put it out, if any (it shows the spot is empty once taken).
var spot: Node

var _ignore_dropper_left: float = 0.0
var _fall_speed: float = 0.0
var _floor_y: float = NAN


## Puts [param weapon_data] on the floor under [param at] (it falls there), turned to [param yaw],
## with [param mag] rounds in the magazine and [param spare] in reserve, as a child of [param parent].
static func spawn(parent: Node, weapon_data: WeaponData, mag: int, spare: int, at: Vector3, yaw: float,
		dropper: Character = null) -> WeaponPickup:
	var pickup := WeaponPickup.new()
	pickup.name = "Pickup_%s" % String(weapon_data.id)
	pickup.data = weapon_data
	pickup.magazine = mag
	pickup.reserve = spare
	pickup.dropped_by = dropper
	parent.add_child(pickup)
	pickup.global_position = at
	pickup.global_rotation = Vector3(0.0, yaw, 0.0)
	return pickup


func _ready() -> void:
	add_to_group(GROUP)
	_ignore_dropper_left = DROPPER_DELAY if dropped_by != null else 0.0
	_build_model()
	_find_floor.call_deferred()


func _physics_process(delta: float) -> void:
	_ignore_dropper_left = maxf(_ignore_dropper_left - delta, 0.0)
	if is_nan(_floor_y) or global_position.y <= _floor_y:
		return
	_fall_speed += FALL_GRAVITY * delta
	global_position.y = maxf(global_position.y - _fall_speed * delta, _floor_y)


## True if [param character] may take it now (not the one who just dropped it).
func can_be_taken_by(character: Character) -> bool:
	return not (character == dropped_by and _ignore_dropper_left > 0.0)


## True once it lies on the floor.
func has_landed() -> bool:
	return not is_nan(_floor_y) and global_position.y <= _floor_y + 0.001


## The point to look at to swap for it: its middle.
func get_center() -> Vector3:
	return global_position


## Finds the floor under the drop point; the gun falls there.
func _find_floor() -> void:
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_SEARCH, PhysicsLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_floor_y = (hit.position.y if not hit.is_empty() else global_position.y - REST_HEIGHT) + REST_HEIGHT
	if global_position.y < _floor_y:
		global_position.y = _floor_y


## The gun's generated model lying on its right side (barrel along the pickup's −Z), or a plain
## grey bar for a weapon without a model.
func _build_model() -> void:
	var model: Node3D
	if data != null and data.model != null:
		model = data.model.instantiate() as Node3D
	else:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.08, 0.6)
		bar.mesh = mesh
		model = bar
	model.name = "Model"
	# On its side: roll 90 degrees, so the gun lies flat with the grip pointing sideways.
	model.rotation = Vector3(0.0, 0.0, PI * 0.5)
	add_child(model)
