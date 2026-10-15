class_name Hitbox
extends Area3D
## One damage zone of a body: head, chest, stomach, arms or legs.
##
## Bullets hit these areas (they sit on the hitboxes physics layer) instead of
## the body's capsule, and the zone decides the damage multiplier, as in CS.
## Whatever owns the hitbox (a target dummy, later a bot) listens to [signal hit].

## Body parts, from most to least damaging per bullet.
enum Zone { HEAD, STOMACH, CHEST, ARMS, LEGS }

## Damage multiplier per zone (CS:GO values).
const MULTIPLIERS := {
	Zone.HEAD: 4.0,
	Zone.STOMACH: 1.25,
	Zone.CHEST: 1.0,
	Zone.ARMS: 1.0,
	Zone.LEGS: 0.75,
}

## Emitted when a bullet hits this zone. [param damage] already includes the zone multiplier.
signal hit(damage: float, zone: Zone, hit_position: Vector3)

## Which part of the body this is.
@export var zone: Zone = Zone.CHEST


func _ready() -> void:
	collision_layer = PhysicsLayers.HITBOXES
	collision_mask = 0
	monitoring = false


## Applies the zone multiplier to a bullet's damage, tells listeners, and
## returns the final damage.
func receive_hit(base_damage: float, hit_position: Vector3) -> float:
	var damage: float = base_damage * MULTIPLIERS[zone]
	hit.emit(damage, zone, hit_position)
	return damage


## The zone's name for display, e.g. "Head".
func get_zone_name() -> String:
	return String(Zone.keys()[zone]).capitalize()
