class_name StatsTotals
extends RefCounted
## Everything you ever played, added up (M14, D-200): matches and results, kills, deaths, damage,
## the accuracy of each weapon, and the wins per mode and per map. [StatsBook] keeps one and adds
## each finished match to it ([method add_match]), so the lifetime numbers stay right even after the
## oldest matches have dropped out of the history list.
##
## Reads and writes itself as a plain [Dictionary] ([method to_dict], [method from_dict]).

var matches: int = 0
var wins: int = 0
var losses: int = 0
var draws: int = 0
## Rounds played in round matches, and the damage dealt in those matches: ADR is their ratio.
var rounds: int = 0
var round_damage: float = 0.0
## Seconds played in matches.
var duration: float = 0.0
var kills: int = 0
var deaths: int = 0
var assists: int = 0
## Damage dealt to enemies, in every kind of match.
var damage: float = 0.0
var headshot_kills: int = 0
## Weapon id → [StatsWeapon].
var weapons: Dictionary[String, StatsWeapon] = {}
## Mode id ([constant StatsMatch.MODE_ROUNDS]...) → {"matches": n, "wins": n}.
var modes: Dictionary = {}
## Map name → {"matches": n, "wins": n}.
var maps: Dictionary = {}


## Adds a finished match to the totals.
func add_match(record: StatsMatch) -> void:
	matches += 1
	match record.result:
		StatsMatch.WIN:
			wins += 1
		StatsMatch.LOSS:
			losses += 1
		_:
			draws += 1
	if record.rounds > 0:
		rounds += record.rounds
		round_damage += record.damage
	duration += record.duration
	kills += record.kills
	deaths += record.deaths
	assists += record.assists
	damage += record.damage
	headshot_kills += record.headshot_kills
	for id in record.weapons:
		if not weapons.has(id):
			weapons[id] = StatsWeapon.new()
		weapons[id].add(record.weapons[id])
	_count_win(modes, record.mode, record.result == StatsMatch.WIN)
	if record.map != "":
		_count_win(maps, record.map, record.result == StatsMatch.WIN)


func kd() -> float:
	return StatsMath.kill_death_ratio(kills, deaths)


## Average damage per round over the round matches, 0 without any.
func adr() -> float:
	return StatsMath.average_damage_per_round(round_damage, rounds)


func hs_percent() -> float:
	return StatsMath.percent(float(headshot_kills), float(kills))


## Matches won as a percentage of matches played (draws count as played).
func win_percent() -> float:
	return StatsMath.percent(float(wins), float(matches))


## Accuracy over every gun (0 to 1).
func accuracy() -> float:
	var all := StatsWeapon.new()
	for weapon: StatsWeapon in weapons.values():
		all.add(weapon)
	return all.accuracy()


## Matches played in [param key] of [param table] ([member modes] or [member maps]).
static func played_in(table: Dictionary, key: String) -> int:
	return int((table.get(key, {}) as Dictionary).get("matches", 0))


## Matches won in [param key] of [param table].
static func won_in(table: Dictionary, key: String) -> int:
	return int((table.get(key, {}) as Dictionary).get("wins", 0))


func to_dict() -> Dictionary:
	var guns := {}
	for id in weapons:
		guns[id] = weapons[id].to_dict()
	return {
		"matches": matches, "wins": wins, "losses": losses, "draws": draws, "rounds": rounds,
		"round_damage": snappedf(round_damage, 0.1), "duration": snappedf(duration, 0.1),
		"kills": kills, "deaths": deaths, "assists": assists, "damage": snappedf(damage, 0.1),
		"headshot_kills": headshot_kills, "weapons": guns, "modes": modes.duplicate(true),
		"maps": maps.duplicate(true),
	}


## Totals read from a dictionary of the stats file; null when it isn't one.
static func from_dict(data: Variant) -> StatsTotals:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var totals := StatsTotals.new()
	totals.matches = StatsMath.clean_count(source.get("matches"))
	totals.wins = StatsMath.clean_count(source.get("wins"))
	totals.losses = StatsMath.clean_count(source.get("losses"))
	totals.draws = StatsMath.clean_count(source.get("draws"))
	totals.rounds = StatsMath.clean_count(source.get("rounds"))
	totals.round_damage = StatsMath.clean_number(source.get("round_damage"))
	totals.duration = StatsMath.clean_number(source.get("duration"))
	totals.kills = StatsMath.clean_count(source.get("kills"))
	totals.deaths = StatsMath.clean_count(source.get("deaths"))
	totals.assists = StatsMath.clean_count(source.get("assists"))
	totals.damage = StatsMath.clean_number(source.get("damage"))
	totals.headshot_kills = mini(StatsMath.clean_count(source.get("headshot_kills")), totals.kills)
	var guns: Variant = source.get("weapons")
	if guns is Dictionary:
		for id: Variant in guns:
			var weapon := StatsWeapon.from_dict((guns as Dictionary)[id])
			var key := StatsMath.clean_text(id)
			if weapon != null and key != "":
				totals.weapons[key] = weapon
	totals.modes = _clean_table(source.get("modes"))
	totals.maps = _clean_table(source.get("maps"))
	return totals


static func _count_win(table: Dictionary, key: String, won: bool) -> void:
	var entry: Dictionary = table.get_or_add(key, {"matches": 0, "wins": 0})
	entry["matches"] = int(entry["matches"]) + 1
	if won:
		entry["wins"] = int(entry["wins"]) + 1


## A table of {"matches", "wins"} entries read from a file: bad entries are dropped, wins never
## exceed matches.
static func _clean_table(value: Variant) -> Dictionary:
	var clean := {}
	if value is Dictionary:
		for key: Variant in value:
			var entry: Variant = (value as Dictionary)[key]
			var name := StatsMath.clean_text(key)
			if name == "" or not entry is Dictionary:
				continue
			var played := StatsMath.clean_count((entry as Dictionary).get("matches"))
			clean[name] = {"matches": played, "wins": mini(StatsMath.clean_count((entry as Dictionary).get("wins")), played)}
	return clean
