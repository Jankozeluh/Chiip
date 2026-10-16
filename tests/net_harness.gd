class_name NetHarness
extends Node
## Runs a host and clients inside one Godot process for the network tests (M9, D-111).
##
## Each side is its own branch of the tree with its own [SceneMultiplayer], given to the
## branch with [method SceneTree.set_multiplayer]: nodes under the branch talk through it as if
## they were on another computer, over real ENet on localhost. [method open_session] puts a
## [NetSession] on a side. Add the harness as a child of the test and free it at the end; it
## takes the multiplayer branches back when it leaves the tree.

## The port the host listens on: random in a range no real game uses, so a running game or
## another test run on the same computer doesn't get in the way.
var port: int = 0

## The side branches, in the order they were made.
var _sides: Array[Node] = []


func _init() -> void:
	port = 27600 + randi() % 300


func _exit_tree() -> void:
	for side in _sides:
		if is_instance_valid(side) and side.is_inside_tree():
			get_tree().set_multiplayer(null, side.get_path())


## Makes a side called [param side_name] with its own multiplayer API and returns its branch.
func add_side(side_name: String) -> Node:
	var side := Node.new()
	side.name = side_name
	add_child(side)
	get_tree().set_multiplayer(SceneMultiplayer.new(), side.get_path())
	_sides.append(side)
	return side


## Puts a [NetSession] on [param side] (see [method add_side]).
func open_session(side: Node) -> NetSession:
	return NetSession.open(get_tree(), side)


## A host on a new side called [param side_name], hosting as [param player_name].
func start_host(side_name: String = "Host", player_name: String = "Host") -> NetSession:
	var session := open_session(add_side(side_name))
	var result := session.host_game(player_name, port)
	if result != OK:
		push_error("NetHarness: couldn't host on port %d (error %d)." % [port, result])
	return session


## A client on a new side that joins the host on this harness's port. Wait for
## [signal NetSession.joined] (or use [method wait_until]).
func start_client(side_name: String, player_name: String) -> NetSession:
	var session := open_session(add_side(side_name))
	var result := session.join_game("127.0.0.1", player_name, port)
	if result != OK:
		push_error("NetHarness: couldn't start a client (error %d)." % result)
	return session


## Waits [param ticks] physics ticks.
func wait_ticks(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


## Waits until [param condition] returns true, at most [param max_ticks] physics ticks.
## Returns whether it came true.
func wait_until(condition: Callable, max_ticks: int = 1280) -> bool:
	for i in max_ticks:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()
