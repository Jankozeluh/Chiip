class_name WeaponTable
extends RefCounted
## The weapons' balancing table (M7, D-090): every stat of every weapon in [method WeaponData.all]
## plus derived columns (damage per second, shots to kill with and without armor, whether a
## headshot kills through a helmet) at 10 and 30 metres, as rows and as CSV text.
##
## tools/export_weapon_table.gd writes the text to docs/weapons.csv, and tests/arsenal_test.gd
## checks that the committed file still equals [method csv_text], so the table can't drift from
## the data files. All armor math goes through [Armor] and all zone multipliers through
## [constant Hitbox.MULTIPLIERS], so the table always follows the game's rules.
##
## A static class (no node, no autoload), so tools and tests can use it.

## The distances (in metres) the derived columns are computed at.
const DISTANCES: Array[int] = [10, 30]
## Armor points of the "with armor" columns.
const ARMOR_POINTS := 100.0
## Health of the target the "shots to kill" columns count against.
const TARGET_HEALTH := 100.0
## Longest a "shots to kill" count goes on (the same cap as [method Armor.hits_to_kill]).
const MAX_SHOTS := 1000
## The columns that don't depend on a distance, in order.
const BASE_COLUMNS: Array[String] = [
	"id", "name", "slot", "category", "price", "kill_reward", "damage", "pellets",
	"armor_penetration", "range_modifier", "fire_rate_rpm", "shot_interval_s", "magazine",
	"reserve", "reload_s", "reload_per_shell", "draw_s", "speed_units", "standing_inaccuracy",
	"moving_inaccuracy", "scoped_inaccuracy",
]
## The derived columns of one distance, in order; the table adds "_10m", "_30m" to each.
const DISTANCE_COLUMNS: Array[String] = [
	"body_damage", "dps", "chest_shots", "chest_shots_armor", "ttk_armor", "head_kill",
	"head_kill_helmet",
]
## The last column: the kill reward per dollar of price.
const LAST_COLUMN := "reward_per_price"


## The column names in table order: the base columns, then every [constant DISTANCE_COLUMNS]
## entry for each distance in turn (body_damage_10m ... head_kill_helmet_10m, body_damage_30m ...),
## then "reward_per_price".
static func columns() -> PackedStringArray:
	var names := PackedStringArray(BASE_COLUMNS)
	for distance in DISTANCES:
		for column in DISTANCE_COLUMNS:
			names.append("%s_%dm" % [column, distance])
	names.append(LAST_COLUMN)
	return names


## One row per weapon, in [method WeaponData.all] order. A row maps every column name to its
## text as it appears in the CSV: integers as integers, floats rounded to 2 decimals without
## trailing zeros, booleans as "yes" / "no", and an empty string where a column doesn't apply.
static func rows() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for data in WeaponData.all():
		table.append(_row(data))
	return table


## The whole table as CSV text: a header line, then one line per weapon, "\n" line ends and a
## trailing newline. A field is quoted only when it holds a comma or a quote.
static func csv_text() -> String:
	var names := columns()
	var text := _csv_line(Array(names)) + "\n"
	for row in rows():
		var fields: Array = []
		for column in names:
			fields.append(row[column])
		text += _csv_line(fields) + "\n"
	return text


## How many shots it takes to bring a target with [param health] to 0 when every pellet of every
## shot hits [param zone] at [param distance] metres. Armor wears hit by hit: each pellet goes
## through [method Armor.apply] with the armor the one before left. 0 if the weapon does no damage.
static func shots_to_kill(data: WeaponData, distance: float, zone: int, armor: float = 0.0,
		helmet: bool = false, health: float = TARGET_HEALTH) -> int:
	var multiplier: float = Hitbox.MULTIPLIERS[zone]
	var pellet_damage := data.damage_at(distance) * multiplier
	if pellet_damage <= 0.0:
		return 0
	var shots := 0
	while health > 0.0 and shots < MAX_SHOTS:
		for pellet in data.pellets:
			var result := Armor.apply(pellet_damage, data.armor_penetration, armor,
					helmet and armor > 0.0, zone)
			health -= result.health
			armor = result.armor
			if health <= 0.0:
				break
		shots += 1
	return shots


## Builds one weapon's row (see [method rows]).
static func _row(data: WeaponData) -> Dictionary:
	var row := {}
	for column in columns():
		row[column] = ""
	row["id"] = String(data.id)
	row["name"] = data.display_name
	row["slot"] = String(WeaponData.Slot.keys()[data.slot]).to_lower()
	row["category"] = String(WeaponData.Category.keys()[data.category]).to_lower()
	row["price"] = str(data.price)
	row["kill_reward"] = str(data.kill_reward)
	row["damage"] = _number(data.damage)
	row["pellets"] = str(data.pellets)
	row["armor_penetration"] = _number(data.armor_penetration, 3)
	row["range_modifier"] = _number(data.range_modifier)
	row["fire_rate_rpm"] = _number(data.fire_rate_rpm)
	row["shot_interval_s"] = _number(data.get_shot_interval(), 3)
	row["magazine"] = str(data.magazine_size)
	row["reserve"] = str(data.reserve_ammo)
	row["reload_s"] = _number(data.reload_time)
	row["reload_per_shell"] = _yes_no(data.reload_per_shell)
	row["draw_s"] = _number(data.draw_time)
	row["speed_units"] = _number(data.max_speed_units)
	row["standing_inaccuracy"] = _number(data.standing_inaccuracy)
	row["moving_inaccuracy"] = _number(data.moving_inaccuracy)
	if data.has_scope():
		row["scoped_inaccuracy"] = _number(data.scoped_inaccuracy)
	if data.is_melee() or data.is_grenade():
		# The knife and the grenades don't shoot: only their blast or slash damage is listed.
		if data.damage > 0.0:
			row["body_damage_%dm" % DISTANCES[0]] = _number(data.damage)
		return row
	for distance in DISTANCES:
		_fill_distance(row, data, distance)
	if data.price > 0:
		row[LAST_COLUMN] = _number(float(data.kill_reward) / float(data.price))
	return row


## Fills the derived columns of one distance in [param row].
static func _fill_distance(row: Dictionary, data: WeaponData, distance: int) -> void:
	var suffix := "_%dm" % distance
	var chest_multiplier: float = Hitbox.MULTIPLIERS[Hitbox.Zone.CHEST]
	var body_damage := data.damage_at(distance) * chest_multiplier * data.pellets
	var shots_armor := shots_to_kill(data, distance, Hitbox.Zone.CHEST, ARMOR_POINTS, true)
	row["body_damage" + suffix] = _number(body_damage)
	row["dps" + suffix] = _number(body_damage * data.fire_rate_rpm / 60.0)
	row["chest_shots" + suffix] = str(shots_to_kill(data, distance, Hitbox.Zone.CHEST))
	row["chest_shots_armor" + suffix] = str(shots_armor)
	row["ttk_armor" + suffix] = _number((shots_armor - 1) * data.get_shot_interval())
	row["head_kill" + suffix] = _yes_no(
			shots_to_kill(data, distance, Hitbox.Zone.HEAD) == 1)
	row["head_kill_helmet" + suffix] = _yes_no(
			shots_to_kill(data, distance, Hitbox.Zone.HEAD, ARMOR_POINTS, true) == 1)


## A float rounded to [param decimals] (2 by default) with trailing zeros stripped: "0.95", "36", "111.6".
static func _number(value: float, decimals: int = 2) -> String:
	var text := ("%." + str(decimals) + "f") % value
	text = text.rstrip("0").rstrip(".")
	if text == "-0":
		text = "0"
	return text


## "yes" or "no".
static func _yes_no(value: bool) -> String:
	return "yes" if value else "no"


## One CSV line (without the line end) from a list of field texts.
static func _csv_line(fields: Array) -> String:
	var parts := PackedStringArray()
	for field in fields:
		parts.append(_csv_field(str(field)))
	return ",".join(parts)


## A field as CSV text: in double quotes (a quote doubled) only when it holds a comma, a quote
## or a line break.
static func _csv_field(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text
