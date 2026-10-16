class_name BotSquad
extends RefCounted
## Team play between bots (M15, D-216, D-217): trades, callouts, and coming at one place from more than one side.
## Static helpers: the [RoundManager] calls [method call_team] when someone dies (a trade: the place is where the
## killer stood) and when a bot calls out an enemy it just spotted ([signal BotController.called_out]); a defending
## [BotController] asks [method flank_point] for its way into a retake.
##
## A call goes to at most [constant MAX_ANSWERS] bots of the caller's team that are free (not fighting or searching,
## not on a bomb job: [method BotController.can_answer_call]) and within [constant REACH] metres of the place along
## the navigation mesh, nearest first, each with the chance [member BotDifficulty.team_play]. They go there for at
## most [constant ANSWER_TIME] seconds, looking that way ([method BotController.answer_call]); the second one comes
## in from the side, so the two don't run the same lane.
##
## A callout also tells the player on that team, as a toast ([RoundHud]): [method callout_text] names the bomb
## site near the enemy ("Enemy spotted near A"), or else the compass direction from the player ("... north-west").

## The most bots that answer one call.
const MAX_ANSWERS := 2
## Only bots this close to the place (metres, walking along the navigation mesh) answer.
const REACH := 25.0
## Seconds a call keeps a bot busy if it finds nobody (its lead runs out; see [method BotSenses.hear_call]).
const ANSWER_TIME := 6.0
## A bot that comes in from the side goes first to a point this far to the side of the place (metres).
const FLANK_OFFSET := 7.0
## ...unless walking there is this much longer than walking straight to the place (metres).
const FLANK_DETOUR := 15.0
## Seconds between two callouts of one bot.
const CALLOUT_WAIT := 6.0
## A callout names a bomb site when the enemy is this close to its middle (metres).
const SITE_NEAR := 15.0
## The callout toasts: at a bomb site, or a compass direction (see [constant DIRECTIONS]).
const SITE_TEXT := "Enemy spotted near %s"
const DIRECTION_TEXT := "Enemy spotted %s"
## Compass directions every 45 degrees from north, the way the HUD's compass turns (north is -Z, east is +X).
const DIRECTIONS: Array[String] = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
## The same, abbreviated for the compass's tag.
const SHORT_DIRECTIONS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


## Hands [param point] to the free bots on [param caller]'s team near it (see the class description); the
## caller itself never answers. Returns the bots that answered, nearest first.
static func call_team(caller: Character, point: Vector3) -> Array[BotController]:
	var candidates: Array[Array] = []
	for other in Character.all_in_world(caller):
		if other == caller or not Teams.are_allies(other, caller) or not other.is_alive():
			continue
		var brain := other.get_node_or_null("BotController") as BotController
		if brain == null or not brain.can_answer_call(point):
			continue
		var distance := path_length(other, other.global_position, point)
		if distance <= REACH:
			candidates.append([distance, brain])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var answered: Array[BotController] = []
	for candidate in candidates:
		var brain: BotController = candidate[1]
		if answered.size() >= MAX_ANSWERS:
			break
		if brain.rng.randf() > brain.difficulty.team_play:
			continue
		var lead_from := answered[0].character.global_position if not answered.is_empty() else brain.character.global_position
		brain.answer_call(point, flank_point(brain.character, point, lead_from, answered.size()))
		answered.append(brain)
	return answered


## Where [param bot], the [param rank]th to head for [param point] (0 = the first), goes first so the team
## comes in from more than one side (D-217): the first goes straight to the point. The others go to a point
## [constant FLANK_OFFSET] metres to the side of the line from [param lead_from] (where the first comes from):
## the second on its own side of that line, the third on the other side, and so on. Straight to the point too
## when the side is a wall or a detour of more than [constant FLANK_DETOUR] metres.
static func flank_point(bot: Character, point: Vector3, lead_from: Vector3, rank: int) -> Vector3:
	var along := Vector3(point.x - lead_from.x, 0.0, point.z - lead_from.z)
	var map := bot.get_world_3d().navigation_map
	if rank == 0 or along.length() < 0.1 or NavigationServer3D.map_get_iteration_id(map) == 0:
		return point
	var side := along.normalized().cross(Vector3.UP)
	if side.dot(bot.global_position - lead_from) < 0.0:
		side = -side
	if rank % 2 == 0:
		side = -side
	var flank := NavigationServer3D.map_get_closest_point(map, point + side * FLANK_OFFSET)
	var here := bot.global_position
	if _flat(flank, point) < FLANK_OFFSET * 0.5 or path_length(bot, here, flank) > path_length(bot, here, point) + FLANK_DETOUR:
		return point
	return flank


## The living bots on [param character]'s team, nearest to [param point] first (flat distance).
static func bots_by_distance(character: Character, point: Vector3) -> Array[BotController]:
	var bots: Array[BotController] = []
	for other in Character.all_in_world(character):
		var brain := other.get_node_or_null("BotController") as BotController
		if brain != null and Teams.are_allies(other, character) and other.is_alive():
			bots.append(brain)
	bots.sort_custom(func(a: BotController, b: BotController) -> bool:
		return _flat(a.character.global_position, point) < _flat(b.character.global_position, point))
	return bots


## The walking distance from [param from] to [param to] on the navigation mesh of [param node]'s world, plus the
## steps on and off it; the straight line while the map's navigation isn't ready, INF when there is no path.
static func path_length(node: Node3D, from: Vector3, to: Vector3) -> float:
	var map := node.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return from.distance_to(to)
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		return INF
	var length := from.distance_to(path[0]) + path[path.size() - 1].distance_to(to)
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## The toast for a callout of an enemy at [param point] on [param map] (see the class description), for a
## player at [param listener].
static func callout_text(point: Vector3, map: Node, listener: Node3D) -> String:
	var place := callout_place(point, map, listener)
	if place["site"] != "":
		return SITE_TEXT % place["site"]
	return DIRECTION_TEXT % place["direction"]


## Where a callout of an enemy at [param point] puts it, for a player at [param listener]: {"site": the bomb site's
## letter or "", "direction": the compass direction from the listener as [constant DIRECTIONS] spells it,
## "short": the letter or the direction's abbreviation ("A", "NW"), for the compass tag (v0.2, D-232)}.
static func callout_place(point: Vector3, map: Node, listener: Node3D) -> Dictionary:
	var nearest: Area3D = null
	for node in map.get_tree().get_nodes_in_group(Bomb.SITE_GROUP):
		var site := node as Area3D
		if site == null or not map.is_ancestor_of(site) or _flat(Bomb.get_site_floor(site), point) > SITE_NEAR:
			continue
		if nearest == null or _flat(Bomb.get_site_floor(site), point) < _flat(Bomb.get_site_floor(nearest), point):
			nearest = site
	var away := point - listener.global_position
	var bearing := rad_to_deg(atan2(away.x, -away.z))
	var index := posmod(roundi(bearing / 45.0), DIRECTIONS.size())
	var site_letter: String = Bomb.site_letter(nearest) if nearest != null else ""
	return {"site": site_letter, "direction": DIRECTIONS[index], "short": site_letter if nearest != null else SHORT_DIRECTIONS[index]}


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
