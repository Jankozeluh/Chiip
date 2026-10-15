class_name BotTactics
extends RefCounted
## Gives the bots of both teams their plan for a round, like a CS team's call
## at the start of a round. The [RoundManager] calls [method plan_round] after
## everyone has respawned.
##
## - [b]Attackers[/b] split into loose groups of about two. Each group takes one
##   of the map's attack routes toward the defenders' end; its members start a
##   moment apart and keep a little spread. At the end of the route they clear
##   the defenders' end: they check the hold spots and the defenders' spawn.
## - [b]Defenders[/b] each take a different hold spot near their end and hold
##   its angle. They leave it only for fights they hear close by (rotating).
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
## How far each attacker's waypoints are shifted at random, in metres (a loose group, not a line).
const WAYPOINT_SPREAD := 1.2


## Plans the round for the bots among [param attackers] and [param defenders]
## (the player, if listed, is skipped: nobody gives you orders). [param map] is
## the node whose markers are used; [param rng] makes the plan repeatable.
static func plan_round(attackers: Array[Character], defenders: Array[Character], map: Node, rng: RandomNumberGenerator) -> void:
	var routes := _find_in_map(map, ROUTE_GROUP)
	var holds := _find_in_map(map, HOLD_GROUP)
	var defender_spawns := _find_in_map(map, Teams.DEFEND_SPAWN_GROUP)
	# Places attackers check once their route is done: where defenders hold, and their spawn.
	var clear_points: Array[Vector3] = []
	for marker in holds + defender_spawns:
		clear_points.append((marker as Node3D).global_position)
	_plan_attack(_bots_of(attackers), routes, clear_points, rng)
	_plan_defence(_bots_of(defenders), holds, rng)


static func _plan_attack(bots: Array[BotController], routes: Array[Node], clear_points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	if bots.is_empty():
		return
	if routes.is_empty():
		for bot in bots:
			bot.patrol()
		return
	_shuffle(bots, rng)
	_shuffle(routes, rng)
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
		bots[i].attack(route, clear_points, delay)


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
