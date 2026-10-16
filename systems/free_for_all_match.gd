class_name FreeForAllMatch
extends RespawnMatch
## Free-for-all deathmatch (M17, D-240): Team Deathmatch with nobody on your side.
##
## Everyone fights everyone. A kill is a point for the killer alone (its [member RoundManager.Stats.kills]),
## and the first to [member MatchSettings.kill_limit] kills wins the match. When the time runs out the one
## with the most kills wins; a tie at the top goes to overtime, which ends with the first kill that leaves
## one player alone at the top. Respawns as in Team Deathmatch, at the respawn point farthest from
## everyone ([method RespawnMatch.pick_spawn] counts everybody as an enemy here), and the start spreads
## everyone over the respawn points instead of the two team ends.
##
## Characters keep the team number the join gave them (the lobby, the join order and the protocol use it),
## but [member Teams.free_for_all] makes every other character an enemy: hostility goes through
## [method Teams.are_allies], never through comparing team numbers. [member RoundManager.score] stays at
## 0–0; the standings are [method get_standings], made from the scoreboard's numbers, so a client's replica
## (which gets those from the host) shows the same leader and winner without anything new on the wire.
##
## Every bot hunts alone, with a [HuntPlan] of its own: no shared sightings, no callouts, no trades.

## The bot's [Character] → its own [HuntPlan].
var _plans_by_bot: Dictionary = {}


func is_free_for_all() -> bool:
	return true


## Everyone in the match, best first: most kills, then fewest deaths, then the join order.
func get_standings() -> Array[Character]:
	var order: Array[Character] = []
	for character in _participants:
		if is_instance_valid(character) and _stats.has(character):
			order.append(character)
	var joined := _participants.duplicate()
	order.sort_custom(func(a: Character, b: Character) -> bool:
		var stats_a := get_stats(a)
		var stats_b := get_stats(b)
		if stats_a.kills != stats_b.kills:
			return stats_a.kills > stats_b.kills
		if stats_a.deaths != stats_b.deaths:
			return stats_a.deaths < stats_b.deaths
		return joined.find(a) < joined.find(b))
	return order


## The one player with the most kills, or null while two or more share the top (or nobody plays).
func get_leader() -> Character:
	var order := get_standings()
	if order.is_empty():
		return null
	if order.size() > 1 and get_stats(order[1]).kills == get_stats(order[0]).kills:
		return null
	return order[0]


## Who won the match: the leader once the match is over, otherwise null.
func get_winner() -> Character:
	return get_leader() if phase == Phase.MATCH_END else null


## [param character]'s kills: its score in this mode.
func get_kills(character: Character) -> int:
	var stats := get_stats(character)
	return stats.kills if stats != null else 0


# --- The match ---


## Spreads everyone over the respawn points, each as far from the ones already placed as it can be
## ([method RespawnMatch.pick_spawn]), instead of putting [param team] at its end of the map.
func _spawn_team(team: int) -> void:
	for member in get_members(team):
		var spot := pick_spawn(member)
		member.respawn(spot.origin, spot.basis.get_euler().y)


## No team score: the standings are the kills.
func _score_kill(_victim: Character, _killer: Character) -> void:
	pass


## The match ends at the kill that brings someone to the kill limit, or in overtime at the kill that
## leaves one player alone at the top.
func _check_match_point(_killer: Character, _victim: Character) -> void:
	var leader := get_leader()
	if leader == null:
		return
	if get_kills(leader) >= settings.kill_limit:
		_end_round(leader.team, EndReason.KILL_LIMIT)
	elif overtime:
		_end_round(leader.team, EndReason.TIME_LIMIT)


func _on_time_up() -> void:
	var leader := get_leader()
	if leader == null:
		overtime = true
		time_left = 0.0
		overtime_started.emit()
		return
	_end_round(leader.team, EndReason.TIME_LIMIT)


func _after_round_end() -> void:
	_respawn_left.clear()
	var leader := get_leader()
	_end_match(leader.team if leader != null else -1)


# --- The bots ---


## Each bot hunts alone: a plan of its own for every bot (no groups, no shared sightings).
func _plan_bots() -> void:
	_hunt_plans.clear()
	_plans_by_bot.clear()
	for character in _participants:
		if not is_instance_valid(character) or character.get_node_or_null("BotController") == null:
			continue
		_hunt_plan_for(character)


## [param character]'s own plan, made the first time it's needed (a bot that joined later gets one too).
func _hunt_plan_for(character: Character) -> HuntPlan:
	if not _plans_by_bot.has(character):
		var alone: Array[Character] = [character]
		var plan := BotTactics.plan_hunt(alone, get_parent(), rng)
		_hunt_plans.append(plan)
		_plans_by_bot[character] = plan
	return _plans_by_bot[character]
