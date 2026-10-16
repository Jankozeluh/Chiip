class_name StatsWeapon
extends RefCounted
## One weapon's shooting numbers (M14, D-201): bullets fired, bullets that hit an enemy, and the hits
## by body zone (head, chest, stomach, arms, legs). A match holds one per weapon you fired, the
## lifetime totals add them up. A shotgun's pellets count one by one, so accuracy never goes over
## 100 %.
##
## Reads and writes itself as a plain [Dictionary] for the stats file ([method to_dict],
## [method from_dict]); a damaged dictionary gives an empty or smaller result, never an error.

## The body zones in the stats file, named like [enum Hitbox.Zone] but in lower case.
const ZONES: Array[String] = ["head", "chest", "stomach", "arms", "legs"]

## Bullets fired.
var shots: int = 0
## Bullets that hit an enemy.
var hits: int = 0
## Hits by zone: zone name from [constant ZONES] → count.
var zones: Dictionary = {}
## Enemies killed with this weapon, and the damage it did to enemies (v0.2, D-235: the match detail's weapon table).
var kills: int = 0
var damage: float = 0.0


## The name of a [enum Hitbox.Zone] as the stats file spells it. Takes an [int], not the enum
## (an enum passed between scripts that refer to each other can be rejected).
static func zone_name(zone: int) -> String:
	var names := Hitbox.Zone.keys()
	return String(names[zone]).to_lower() if zone >= 0 and zone < names.size() else ""


## Counts [param count] bullets fired.
func add_shots(count: int = 1) -> void:
	shots += maxi(count, 0)


## Counts one bullet that hit an enemy in [param zone] (an [enum Hitbox.Zone]).
func add_hit(zone: int) -> void:
	hits += 1
	var key := zone_name(zone)
	if key != "":
		zones[key] = int(zones.get(key, 0)) + 1


## Adds all of [param other]'s numbers to these.
func add(other: StatsWeapon) -> void:
	shots += other.shots
	hits += other.hits
	kills += other.kills
	damage += other.damage
	for key: String in other.zones:
		zones[key] = int(zones.get(key, 0)) + int(other.zones[key])


## Hits ÷ shots (0 to 1), 0 without shots.
func accuracy() -> float:
	return StatsMath.ratio(float(hits), float(shots))


## The hits in [param zone] (a name from [constant ZONES]).
func zone_hits(zone: String) -> int:
	return int(zones.get(zone, 0))


## The share of all hits that landed in [param zone] (0 to 1).
func zone_share(zone: String) -> float:
	return StatsMath.ratio(float(zone_hits(zone)), float(hits))


## The share of hits that were headshots (0 to 1).
func head_share() -> float:
	return zone_share("head")


func to_dict() -> Dictionary:
	return {"shots": shots, "hits": hits, "zones": zones.duplicate(), "kills": kills, "damage": snappedf(damage, 0.1)}


## A weapon's numbers read from a dictionary of the stats file. Anything that isn't a dictionary
## gives null; unknown zones are dropped, counts are cleaned, and hits never exceed shots.
static func from_dict(data: Variant) -> StatsWeapon:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var weapon := StatsWeapon.new()
	weapon.shots = StatsMath.clean_count(source.get("shots"))
	weapon.hits = mini(StatsMath.clean_count(source.get("hits")), weapon.shots)
	weapon.kills = StatsMath.clean_count(source.get("kills"))
	weapon.damage = StatsMath.clean_number(source.get("damage"))
	var source_zones: Variant = source.get("zones")
	if source_zones is Dictionary:
		for key: String in ZONES:
			var count := StatsMath.clean_count((source_zones as Dictionary).get(key))
			if count > 0:
				weapon.zones[key] = count
	return weapon
