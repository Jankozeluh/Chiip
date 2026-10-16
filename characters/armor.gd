class_name Armor
extends RefCounted
## CS:GO's armor rule in one place (D-093): how much of a hit reaches health and how much
## armor it wears off. [Character] applies it to every hit; the balancing table
## (tools/export_weapon_table.gd) uses it to count shots to kill.
##
## Kevlar covers the chest, stomach and arms; the helmet covers the head; the legs are never
## covered. On a covered hit only the weapon's [member WeaponData.armor_penetration] of the
## damage goes to health, and the armor loses half of what it stopped. When there isn't
## enough armor left to stop that much, the rest goes through: each point of armor stops two
## points of damage. Armor at 0 protects nothing, and the helmet goes with it.
##
## A static class (no node, no autoload), so tools and tests can use it.

## Armor points a vest gives (CS: 100).
const MAX_ARMOR := 100.0
## How much armor a covered hit wears off, per point of damage the armor stopped (CS: 0.5).
const WEAR_PER_DAMAGE := 0.5


## True if a hit on [param zone] lands on armor: chest, stomach and arms with any armor, the
## head only with a helmet, the legs never.
static func covers(zone: int, armor: float, helmet: bool) -> bool:
	if armor <= 0.0:
		return false
	match zone:
		Hitbox.Zone.HEAD:
			return helmet
		Hitbox.Zone.LEGS:
			return false
	return true


## One hit of [param damage] (after hit-zone multipliers) on [param zone] by a weapon with
## [param penetration], on a character with [param armor] points and maybe a [param helmet].
## Returns [code]{"health": damage to health, "armor": armor left}[/code].
## [param damage_factor] scales the damage to health while any armor is worn and
## [param wear_factor] the armor worn off: both 1.0, except for the Bulwark's Plated perk
## (0.9 and 0.7, see [ClassData]).
static func apply(damage: float, penetration: float, armor: float, helmet: bool, zone: int,
		damage_factor: float = 1.0, wear_factor: float = 1.0) -> Dictionary:
	var wearing := armor > 0.0
	var health := damage
	var armor_left := armor
	if covers(zone, armor, helmet):
		health = damage * penetration
		var wear := (damage - health) * WEAR_PER_DAMAGE * wear_factor
		if wear > armor:
			# The armor gives out: it stops only what its last points can, the rest goes through.
			health = damage - armor / (WEAR_PER_DAMAGE * wear_factor)
			armor_left = 0.0
		else:
			armor_left = armor - wear
	if wearing:
		health *= damage_factor
	return {"health": health, "armor": armor_left}


## How many hits of [param damage] on [param zone] it takes to bring [param health] to 0
## through [param armor] (and a [param helmet]), the armor wearing down hit by hit. 0 if it
## never would (no damage).
static func hits_to_kill(damage: float, penetration: float, zone: int, health: float = 100.0,
		armor: float = 0.0, helmet: bool = false) -> int:
	if damage <= 0.0:
		return 0
	var hits := 0
	while health > 0.0 and hits < 1000:
		var result := apply(damage, penetration, armor, helmet and armor > 0.0, zone)
		health -= result.health
		armor = result.armor
		hits += 1
	return hits
