class_name HuntPlan
extends RefCounted
## One team's shared plan in the team respawn mode (D-083): which bots hunt
## together, where each group is heading, and the latest enemy sighting any of
## them reported, like a callout over the radio.
##
## [BotTactics.plan_hunt] makes one per team at the start of a match; the
## [RespawnMatch] advances [member time] and hands it to every bot that comes
## back. The bots read it and report to it ([BotController], role HUNT).

## A sighting older than this (seconds) isn't worth chasing anymore.
const LEAD_TIME := 6.0
## A roam point is at least this far from where the group is (metres)...
const ROAM_MIN_DISTANCE := 12.0
## ...and at least this far from the other groups' goals, so the team spreads out.
const ROAM_SPREAD := 10.0

## The groups: arrays of [BotController]s that hunt together.
var groups: Array[Array] = []
## Places to roam when nobody knows where the enemy is.
var roam_points: Array[Vector3] = []
## Seconds of live match so far. Advanced by the [RespawnMatch].
var time: float = 0.0

var _lead_position: Vector3 = Vector3.ZERO
var _lead_time: float = -INF
## BotController → when it last came back (its group's longest-living member leads).
var _alive_since: Dictionary = {}
## Group index → the point its leader is heading for.
var _goals: Dictionary = {}


## Tells the team an enemy was seen or heard at [param position].
func report(position: Vector3) -> void:
	_lead_position = position
	_lead_time = time


## True while the latest sighting is fresh enough to chase.
func has_lead() -> bool:
	return time - _lead_time <= LEAD_TIME


## Where the latest sighting was. Only meaningful while [method has_lead] is true.
func get_lead() -> Vector3:
	return _lead_position


## Notes that [param bot] just came back, so a teammate who stayed alive keeps leading.
func note_respawn(bot: BotController) -> void:
	_alive_since[bot] = time


## The group [param bot] hunts with, as an index into [member groups], or -1.
func get_group_index(bot: BotController) -> int:
	for i in groups.size():
		if groups[i].has(bot):
			return i
	return -1


## Who leads [param bot]'s group right now: the living member that has been
## alive the longest (the first one listed on a tie), or null if none is alive.
func get_leader(bot: BotController) -> BotController:
	var index := get_group_index(bot)
	if index < 0:
		return bot
	var leader: BotController = null
	for member: BotController in groups[index]:
		if not is_instance_valid(member) or not member.character.is_alive():
			continue
		if leader == null or _alive_since.get(member, 0.0) < _alive_since.get(leader, 0.0):
			leader = member
	return leader


## The living members of [param bot]'s group other than [param bot].
func get_partners(bot: BotController) -> Array[BotController]:
	var partners: Array[BotController] = []
	var index := get_group_index(bot)
	if index < 0:
		return partners
	for member: BotController in groups[index]:
		if member != bot and is_instance_valid(member) and member.character.is_alive():
			partners.append(member)
	return partners


## Where [param bot]'s group is heading, or [constant Vector3.INF] if it hasn't picked a place.
func get_goal(bot: BotController) -> Vector3:
	return _goals.get(get_group_index(bot), Vector3.INF)


## Picks the next place for [param bot]'s group to roam to: a roam point at
## least [constant ROAM_MIN_DISTANCE] from [param from] and away from the other
## groups' goals if possible, chosen at random with [param rng].
func pick_roam_goal(bot: BotController, from: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var index := get_group_index(bot)
	var good: Array[Vector3] = []
	var fallback: Array[Vector3] = []
	for point in roam_points:
		if _flat(point, from) < ROAM_MIN_DISTANCE:
			continue
		fallback.append(point)
		var crowded := false
		for other in _goals:
			if other != index and _goals[other] != Vector3.INF and _flat(point, _goals[other]) < ROAM_SPREAD:
				crowded = true
		if not crowded:
			good.append(point)
	var choices := good if not good.is_empty() else fallback
	var goal := choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else from
	_goals[index] = goal
	return goal


## Sets where [param bot]'s group is heading (a sighting it chases).
func set_goal(bot: BotController, goal: Vector3) -> void:
	_goals[get_group_index(bot)] = goal


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
