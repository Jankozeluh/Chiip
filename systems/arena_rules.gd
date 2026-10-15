class_name ArenaRules
extends Node
## Temporary game rules for M4: keeps a number of bots on the map and brings
## anyone who dies back after a few seconds. Proper rounds replace this in M5.
##
## Spawn points are Marker3D nodes in the "bot_spawns" and "player_spawns"
## groups. Without them, bots appear at random walkable spots away from the
## player, and the player respawns where they started.

const BOT_SCENE := preload("res://bots/bot.tscn")
const BOT_SPAWN_GROUP := "bot_spawns"
const PLAYER_SPAWN_GROUP := "player_spawns"
## Random bot spawns stay at least this far from the player, in metres.
const MIN_SPAWN_DISTANCE := 20.0

## How many bots to put on the map at the start.
@export var bot_count: int = 2
## How well new bots fight.
@export var bot_difficulty: BotDifficulty = preload("res://bots/difficulty_normal.tres")
## Seconds between dying and coming back.
@export var respawn_delay: float = 3.0

var _player: Character
var _player_start: Transform3D
var _rng := RandomNumberGenerator.new()
var _bots_made: int = 0


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as Character
	if _player != null:
		_player_start = _player.global_transform
		_player.died.connect(_on_died.bind(_player))
	# Wait for the map (and its navigation) to be ready before placing bots.
	_add_starting_bots.call_deferred()


## Adds a bot at a spawn point and returns it.
func add_bot(difficulty: BotDifficulty = bot_difficulty) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	_bots_made += 1
	bot.name = "Bot%d" % _bots_made
	(bot.get_node("BotController") as BotController).difficulty = difficulty
	var spot := _pick_bot_spawn()
	bot.position = spot.origin
	bot.rotation.y = spot.basis.get_euler().y
	get_parent().add_child(bot)
	bot.died.connect(_on_died.bind(bot))
	return bot


## Removes the most recently added bot. Returns false if there are none.
func remove_bot() -> bool:
	var bots := get_bots()
	if bots.is_empty():
		return false
	bots.back().queue_free()
	return true


## All bots this arena manages, oldest first.
func get_bots() -> Array[Character]:
	var bots: Array[Character] = []
	for node in get_parent().get_children():
		if node is Character and node != _player and not node.is_queued_for_deletion():
			bots.append(node)
	return bots


func _add_starting_bots() -> void:
	for i in bot_count:
		add_bot()


func _on_died(_killer: Character, victim: Character) -> void:
	await get_tree().create_timer(respawn_delay, false, true).timeout
	if not is_instance_valid(victim):
		return
	var spot := _pick_from_group(PLAYER_SPAWN_GROUP, _player_start) if victim == _player else _pick_bot_spawn()
	victim.respawn(spot.origin, spot.basis.get_euler().y)


func _pick_bot_spawn() -> Transform3D:
	var markers := get_tree().get_nodes_in_group(BOT_SPAWN_GROUP)
	if not markers.is_empty():
		return (markers[_rng.randi() % markers.size()] as Node3D).global_transform
	var map := (get_parent() as Node3D).get_world_3d().navigation_map
	var point := Vector3.ZERO
	for attempt in 20:
		point = NavigationServer3D.map_get_random_point(map, 1, true)
		if _player == null or point.distance_to(_player.global_position) >= MIN_SPAWN_DISTANCE:
			break
	return Transform3D(Basis(), point)


func _pick_from_group(group: String, fallback: Transform3D) -> Transform3D:
	var markers := get_tree().get_nodes_in_group(group)
	if markers.is_empty():
		return fallback
	return (markers[_rng.randi() % markers.size()] as Node3D).global_transform
