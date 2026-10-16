class_name AimScore
extends RefCounted
## The tally and the score of one aim-trainer run (M14, D-205, D-206): the maths only, so it can be
## checked without a map ([RangeTrainer] plays the run and feeds this).
##
## A run is a list of flick targets, one at a time. Each target that is hit earns
## [constant HIT_POINTS] plus up to [constant SPEED_POINTS] for how fast: the full amount for a hit
## the moment it pops up, falling in a straight line to nothing at the end of its life. A target that
## times out earns nothing. Every shot that hit no target costs [constant MISS_PENALTY], so spraying
## at the targets doesn't pay. The score never goes below 0.
##
##     score = Σ (HIT_POINTS + SPEED_POINTS × (1 − reaction ÷ lifetime)) − MISS_PENALTY × misses

## Points for a hit, whatever its speed.
const HIT_POINTS := 100
## The most a hit can add for speed (a hit at the moment the target appears).
const SPEED_POINTS := 100
## Taken off for every shot that hit no target.
const MISS_PENALTY := 25

## Targets hit.
var hits: int = 0
## Targets that timed out before being hit.
var expired: int = 0
## Shots fired during the run (trigger pulls of the gun in hand).
var shots: int = 0
## The points earned by the hits, before the misses are taken off.
var points: int = 0
## The sum of the hits' reaction times in seconds.
var reaction_total: float = 0.0


## The points of one hit that came [param reaction] seconds after its target appeared, for a target
## that lives [param lifetime] seconds: [constant HIT_POINTS] plus the speed points, rounded.
static func hit_value(reaction: float, lifetime: float) -> int:
	var speed := 1.0 - clampf(reaction / lifetime, 0.0, 1.0) if lifetime > 0.0 else 0.0
	return HIT_POINTS + roundi(SPEED_POINTS * speed)


## Counts a hit [param reaction] seconds after its target appeared (the target lives [param lifetime]).
func add_hit(reaction: float, lifetime: float) -> void:
	hits += 1
	points += hit_value(reaction, lifetime)
	reaction_total += clampf(reaction, 0.0, lifetime)


## Counts a target that timed out.
func add_expired() -> void:
	expired += 1


## Counts [param count] shots fired.
func add_shots(count: int = 1) -> void:
	shots += maxi(count, 0)


## Shots that hit no target: the shots fired minus the hits.
func misses() -> int:
	return maxi(shots - hits, 0)


## The run's score: the hits' points minus the misses' penalty, at least 0.
func score() -> int:
	return maxi(points - MISS_PENALTY * misses(), 0)


## Hits ÷ shots (0 to 1), 0 without shots.
func accuracy() -> float:
	return minf(StatsMath.ratio(float(hits), float(shots)), 1.0)


## The average seconds from a target appearing to its hit, 0 without hits.
func average_reaction() -> float:
	return reaction_total / float(hits) if hits > 0 else 0.0


## The numbers saved with a personal best.
func details() -> Dictionary:
	return {
		"hits": hits, "misses": misses(), "expired": expired, "accuracy": snappedf(accuracy() * 100.0, 0.1),
		"reaction_ms": roundi(average_reaction() * 1000.0),
	}
