class_name BotTactics
extends RefCounted
## Gives the bots of both teams their plan for a round, like a CS team's call
## at the start of a round. The [RoundManager] calls [method plan_round] after
## everyone has respawned (and the bomb has a carrier).
##
## - [b]Attackers[/b] split into loose groups of about two. Each group takes one
##   of the map's attack routes toward the defenders' end; its members start a
##   moment apart and keep a little spread. At the end of the route they clear
##   the defenders' end: they check the hold spots and the defenders' spawn.
## - [b]Defenders[/b] each take a different hold spot near their end and hold
##   its angle. They leave it only for fights they hear close by (rotating).
## - [b]Bomb rounds[/b] (D-081): the attackers pick one site at random. The
##   carrier's group takes the route that ends nearest to it, and after their
##   routes everyone clears the spots around that site instead of the whole
##   end. The rest (planting, fetching a dropped bomb, guarding, retaking and
##   defusing) each bot works out itself from the [Bomb] ([BotController]).
##
## The map provides the plan's places: [constant ROUTE_GROUP] nodes whose
## Marker3D children are the route's waypoints in order, and Marker3D nodes in
## [constant HOLD_GROUP] facing the angle to hold. On a map without them, bots
## patrol as in practice mode.

## Group of the attack routes: Node3D nodes with their waypoints as Marker3D children, in order.
const ROUTE_GROUP := "attack_routes"
## Group of the spots defenders hold: Marker3D nodes facing the angle to watch.
const HOLD_GROUP := "hold_points"
## Attackers per group, roughly: 3 attackers make groups of 2 and 1.
const GROUP_SIZE := 2
## Seconds between group members setting off, so they don't walk in single file
## right on each other's heels.
const START_SPACING := 0.6
## Extra random delay per attacker, in seconds.
const START_JITTER := 0.4
## In bomb rounds, attackers clear the hold spots this close to the target site (metres).
const SITE_CLEAR_RADIUS := 15.0
## How far each attacker's waypoints are shifted at random, in metres (a loose group, not a line).
const WAYPOINT_SPREAD := 1.2


## Plans the round for the bots among [param attackers] and [param defenders]
## (the player, if listed, is skipped: nobody gives you orders). [param map] is
## the node whose markers are used; [param rng] makes the plan repeatable.
## [param round_time] is how long the live round lasts, so a bomb carrier knows
## when to stop following its route and go plant.
static func plan_round(attackers: Array[Character], defenders: Array[Character], map: Node, rng: RandomNumberGenerator, round_time: float = INF) -> void:
	var routes := _find_in_map(map, ROUTE_GROUP)
	var holds := _find_in_map(map, HOLD_GROUP)
	var defender_spawns := _find_in_map(map, Teams.DEFEND_SPAWN_GROUP)
	# Places attackers check once their route is done: where defenders hold, and their spawn.
	var clear_points: Array[Vector3] = []
	for marker in holds + defender_spawns:
		clear_points.append((marker as Node3D).global_position)
	var bomb := _find_bomb(map)
	var target_site: Area3D = null
	if bomb != null and not bomb.get_sites().is_empty():
		var sites := bomb.get_sites()
		target_site = sites[rng.randi_range(0, sites.size() - 1)]
		clear_points = _site_clear_points(target_site, holds)
	var carrier := bomb.carrier if bomb != null else null
	_plan_attack(_bots_of(attackers), routes, clear_points, rng, target_site, carrier, round_time - BotController.PLANT_RESERVE)
	_plan_defence(_bots_of(defenders), holds, rng)


static func _plan_attack(bots: Array[BotController], routes: Array[Node], clear_points: Array[Vector3], rng: RandomNumberGenerator,
		target_site: Area3D = null, carrier: Character = null, plant_deadline: float = INF) -> void:
	if bots.is_empty():
		return
	if routes.is_empty():
		for bot in bots:
			bot.patrol()
		return
	_shuffle(bots, rng)
	_shuffle(routes, rng)
	if target_site != null:
		# The carrier's group (group 0) takes the route that ends nearest the target site.
		routes.sort_custom(func(a: Node, b: Node) -> bool: return _route_end_distance(a, target_site) < _route_end_distance(b, target_site))
		for i in bots.size():
			if bots[i].character == carrier:
				var swap := bots[0]
				bots[0] = bots[i]
				bots[i] = swap
	var group_count := clampi(ceili(bots.size() / float(GROUP_SIZE)), 1, routes.size())
	for i in bots.size():
		var group := i % group_count
		var place_in_group: int = floori(float(i) / group_count)
		var route: Array[Vector3] = []
		for waypoint in routes[group].get_children():
			if waypoint is Marker3D:
				var spread := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * WAYPOINT_SPREAD
				route.append((waypoint as Node3D).global_position + spread)
		var delay := place_in_group * START_SPACING + rng.randf() * START_JITTER
		bots[i].attack(route, clear_points, delay, target_site, plant_deadline)


static func _plan_defence(bots: Array[BotController], holds: Array[Node], rng: RandomNumberGenerator) -> void:
	if holds.is_empty():
		for bot in bots:
			bot.patrol()
		return
	_shuffle(holds, rng)
	var spots: Array[Transform3D] = []
	for marker in holds:
		spots.append((marker as Node3D).global_transform)
	for i in bots.size():
		bots[i].defend(spots[i % spots.size()], spots)


## The round's bomb on [param map], or null.
static func _find_bomb(map: Node) -> Bomb:
	for node in _find_in_map(map, Bomb.GROUP):
		return node as Bomb
	return null


## Where attackers clear around [param site]: its middle and the hold spots
## within [constant SITE_CLEAR_RADIUS] of it.
static func _site_clear_points(site: Area3D, holds: Array[Node]) -> Array[Vector3]:
	var floor_point := Bomb.get_site_floor(site)
	var points: Array[Vector3] = [floor_point]
	for marker in holds:
		var position := (marker as Node3D).global_position
		if Vector2(position.x - floor_point.x, position.z - floor_point.z).length() <= SITE_CLEAR_RADIUS:
			points.append(position)
	return points


## Flat distance from the last waypoint of [param route] to [param site].
static func _route_end_distance(route: Node, site: Area3D) -> float:
	var last := Vector3.INF
	for waypoint in route.get_children():
		if waypoint is Marker3D:
			last = (waypoint as Node3D).global_position
	return Vector2(last.x - site.global_position.x, last.z - site.global_position.z).length()


## The bot brains among [param characters] (the player has none).
static func _bots_of(characters: Array[Character]) -> Array[BotController]:
	var bots: Array[BotController] = []
	for character in characters:
		var brain := character.get_node_or_null("BotController") as BotController
		if brain != null:
			bots.append(brain)
	return bots


## Nodes of [param group] that belong to [param map].
static func _find_in_map(map: Node, group: String) -> Array[Node]:
	var found: Array[Node] = []
	for node in map.get_tree().get_nodes_in_group(group):
		if map.is_ancestor_of(node):
			found.append(node)
	return found


## Fisher–Yates shuffle with a seeded generator (Array.shuffle() uses the global one).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
