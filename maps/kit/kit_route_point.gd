class_name KitRoutePoint
extends Marker3D
## One waypoint of a bot attack route, placed in TrenchBroom (the info_route
## entity, D-125). Every point names its route ("west", "mid", ...) and its
## place in it (1, 2, 3 ...). When the map runs, the points of each route
## gather under a Node3D in the attack_routes group, in order, which is what
## BotTactics reads (MAPS.md, "Markers in each map scene"). Routes are read
## when a round goes live, long after this has happened.

## The route this point belongs to. Points with the same name form one route.
@export var route: String = "mid"
## The point's place along its route, from the attackers' spawn (1) onwards.
@export var order: int = 1


func _func_godot_apply_properties(properties: Dictionary) -> void:
	route = str(properties.get("route", route)).strip_edges()
	order = int(properties.get("order", order))


func _ready() -> void:
	if not Engine.is_editor_hint():
		_join_route.call_deferred()


func _join_route() -> void:
	var map := get_parent()
	if map == null or map.is_in_group(BotTactics.ROUTE_GROUP):
		return
	var holder_name := "Route_" + route.validate_node_name()
	var holder := map.get_node_or_null(holder_name) as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = holder_name
		holder.add_to_group(BotTactics.ROUTE_GROUP)
		map.add_child(holder)
	reparent(holder)
	var points := holder.get_children().filter(func(node: Node) -> bool: return node is KitRoutePoint)
	points.sort_custom(func(a: KitRoutePoint, b: KitRoutePoint) -> bool: return a.order < b.order)
	for i in points.size():
		holder.move_child(points[i], i)
