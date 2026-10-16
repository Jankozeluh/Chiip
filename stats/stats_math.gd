class_name StatsMath
extends RefCounted
## The small maths of the stats (M14, D-201), in one place so every screen and the tests use the same
## definitions, and the readers of the stats file (which is a text file anyone can edit or damage).
##
## - **K/D** is kills ÷ deaths, with deaths counted as at least 1 (a match without a death shows
##   the kills, not infinity).
## - **ADR** (average damage per round) is damage ÷ rounds, over round matches only: a Team
##   respawn match is one long round, so its damage says nothing about a "round".
## - **HS %** is headshot kills ÷ kills, as in CS.
## - **Accuracy** is bullets that hit an enemy ÷ bullets fired; a shotgun's pellets count one by one.
##
## Every function is static and pure. The `clean_*` readers turn any value from a file into a safe
## one (the right type, in range) instead of trusting it.

## Biggest number any counter is allowed to hold when read from a file (about a billion).
const MAX_COUNT := 1_000_000_000
## Longest text (a map or mode id, a weapon id) read from a file.
const MAX_TEXT := 64


## [param part] ÷ [param whole], or 0.0 when [param whole] is not above zero.
static func ratio(part: float, whole: float) -> float:
	return part / whole if whole > 0.0 else 0.0


## [param part] as a percentage of [param whole] (0 to 100 for a part that is within it).
static func percent(part: float, whole: float) -> float:
	return ratio(part, whole) * 100.0


## Kills per death, deaths counted as at least 1.
static func kill_death_ratio(kills: int, deaths: int) -> float:
	return float(kills) / float(maxi(deaths, 1))


## Average damage per round: [param damage] over [param rounds], 0 without rounds.
static func average_damage_per_round(damage: float, rounds: int) -> float:
	return ratio(damage, float(rounds))


## A count read from a file: a whole number between 0 and [constant MAX_COUNT], else [param fallback].
static func clean_count(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return clampi(value, 0, MAX_COUNT)
	if value is float and is_finite(value):
		return clampi(int(value), 0, MAX_COUNT)
	return fallback


## A non-negative decimal number read from a file (a damage total, a time), else [param fallback].
static func clean_number(value: Variant, fallback: float = 0.0) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return clampf(float(value), 0.0, float(MAX_COUNT))
	return fallback


## A short text read from a file (at most [constant MAX_TEXT] characters), else [param fallback].
static func clean_text(value: Variant, fallback: String = "") -> String:
	if value is String:
		return (value as String).strip_edges().left(MAX_TEXT)
	return fallback


## A whole number read from a file between [param low] and [param high] (the unix time of a date, for
## one), else [param fallback].
static func clean_range(value: Variant, low: int, high: int, fallback: int) -> int:
	if value is int:
		return clampi(value, low, high)
	if value is float and is_finite(value):
		return clampi(int(value), low, high)
	return fallback
