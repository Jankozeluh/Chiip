class_name StatsMatch
extends RefCounted
## One finished match in your history (M14, D-200): when, which mode and map, how it ended and your
## own numbers. Saved on your computer only, in the stats file ([StatsBook]).
##
## Reads and writes itself as a plain [Dictionary] ([method to_dict], [method from_dict]).

## [member mode] of a bomb round match.
const MODE_ROUNDS := "rounds"
## [member mode] of a Team respawn match.
const MODE_RESPAWN := "respawn"
const WIN := "win"
const LOSS := "loss"
const DRAW := "draw"
## Dates outside this range (unix seconds: 2020 to 2100) are not dates a game could have written.
const MIN_DATE := 1_577_836_800
const MAX_DATE := 4_102_444_800

## When the match ended, in unix seconds.
var date: int = 0
## [constant MODE_ROUNDS] or [constant MODE_RESPAWN].
var mode: String = MODE_RESPAWN
## The map's short name ("depot", "square", "spillway").
var map: String = ""
## [constant WIN], [constant LOSS] or [constant DRAW] for your team.
var result: String = DRAW
## Your team's score and the other team's: rounds won, or kills in a respawn match.
var score_us: int = 0
var score_them: int = 0
## Rounds played (0 in a respawn match: ADR is only for round matches).
var rounds: int = 0
## Seconds the match lasted, from its start to its end.
var duration: float = 0.0
## True when it was played online (a joined or hosted game).
var online: bool = false
var kills: int = 0
var deaths: int = 0
var assists: int = 0
## Damage you dealt to enemies.
var damage: float = 0.0
## Kills whose last bullet hit the head.
var headshot_kills: int = 0
## Weapon id → [StatsWeapon], for the guns you fired.
var weapons: Dictionary[String, StatsWeapon] = {}


## Kills per death (deaths counted as at least 1).
func kd() -> float:
	return StatsMath.kill_death_ratio(kills, deaths)


## Average damage per round, or -1.0 in a match without rounds (nothing to average).
func adr() -> float:
	return StatsMath.average_damage_per_round(damage, rounds) if rounds > 0 else -1.0


## Headshot kills as a percentage of kills (0 to 100).
func hs_percent() -> float:
	return StatsMath.percent(float(headshot_kills), float(kills))


## Your accuracy over every gun (0 to 1).
func accuracy() -> float:
	var all := StatsWeapon.new()
	for weapon: StatsWeapon in weapons.values():
		all.add(weapon)
	return all.accuracy()


func to_dict() -> Dictionary:
	var guns := {}
	for id in weapons:
		guns[id] = weapons[id].to_dict()
	return {
		"date": date, "mode": mode, "map": map, "result": result, "score_us": score_us,
		"score_them": score_them, "rounds": rounds, "duration": snappedf(duration, 0.1),
		"online": online, "kills": kills, "deaths": deaths, "assists": assists,
		"damage": snappedf(damage, 0.1), "headshot_kills": headshot_kills, "weapons": guns,
	}


## A match read from a dictionary of the stats file; null when it isn't one a game could have
## written (not a dictionary, no valid date, an unknown mode or result).
static func from_dict(data: Variant) -> StatsMatch:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var record := StatsMatch.new()
	var when: Variant = source.get("date")
	record.date = int(when) if (when is int or when is float) and is_finite(float(when)) and float(when) >= MIN_DATE and float(when) <= MAX_DATE else 0
	record.mode = StatsMath.clean_text(source.get("mode"))
	record.result = StatsMath.clean_text(source.get("result"))
	if record.date == 0 or not [MODE_ROUNDS, MODE_RESPAWN].has(record.mode) \
			or not [WIN, LOSS, DRAW].has(record.result):
		return null
	record.map = StatsMath.clean_text(source.get("map"))
	record.score_us = StatsMath.clean_count(source.get("score_us"))
	record.score_them = StatsMath.clean_count(source.get("score_them"))
	record.rounds = StatsMath.clean_count(source.get("rounds"))
	record.duration = StatsMath.clean_number(source.get("duration"))
	record.online = source.get("online") == true
	record.kills = StatsMath.clean_count(source.get("kills"))
	record.deaths = StatsMath.clean_count(source.get("deaths"))
	record.assists = StatsMath.clean_count(source.get("assists"))
	record.damage = StatsMath.clean_number(source.get("damage"))
	record.headshot_kills = mini(StatsMath.clean_count(source.get("headshot_kills")), record.kills)
	var guns: Variant = source.get("weapons")
	if guns is Dictionary:
		for id: Variant in guns:
			var weapon := StatsWeapon.from_dict((guns as Dictionary)[id])
			var key := StatsMath.clean_text(id)
			if weapon != null and key != "":
				record.weapons[key] = weapon
	return record
