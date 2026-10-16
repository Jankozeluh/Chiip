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
## A spawn marker counts as taken if someone stands closer than this, in metres.
const SPAWN_CLEARANCE := 3.0

## Metadata on a map scene's root: how many bots practice starts with there, instead of
## [member bot_count] (main.gd reads it; the Shooting Range has 0, D-141). The console's
## bot_add adds more.
const START_BOTS_META := &"practice_bots"

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
## Which class the next bot gets: the bots cycle through the classes from a random one.
var _next_class: int = _rng.randi_range(0, ClassData.all().size() - 1)


func _ready() -> void:
	# Practice is never free-for-all (a free-for-all match before it set the shared flag).
	Teams.free_for_all = false
	_player = get_parent().get_node_or_null("Player") as Character
	if _player != null:
		_player_start = _player.global_transform
		_player.died.connect(_on_died.bind(_player))
	# Wait for the map (and its navigation) to be ready before placing bots.
	_add_starting_bots.call_deferred()


## Adds a bot at a spawn point and returns it. [param team] is the bot's team:
## 1 (the enemies of a team-0 player) unless told otherwise; a bot with the
## player's team is a teammate. The scene is the same for both.
func add_bot(difficulty: BotDifficulty = bot_difficulty, team: int = 1) -> Character:
	var bot: Character = BOT_SCENE.instantiate()
	_bots_made += 1
	bot.name = "Bot%d" % _bots_made
	bot.team = team  # Before add_child, so the body gets the right color from the start.
	var classes := ClassData.all()
	bot.class_data = classes[_next_class % classes.size()]
	_next_class += 1
	(bot.get_node("BotController") as BotController).difficulty = difficulty
	var spot := _pick_bot_spawn()
	bot.position = spot.origin
	bot.rotation.y = spot.basis.get_euler().y
	get_parent().add_child(bot)
	bot.died.connect(_on_died.bind(bot))
	give_loadout(bot)
	return bot


## Gives [param character] its class's loadout (D-090: practice has no money; the buy menu gives
## anything for free). A class without a loadout keeps what it carries.
func give_loadout(character: Character) -> void:
	if character.class_data != null and not character.class_data.loadout.is_empty():
		character.inventory.set_loadout(character.class_data.loadout)


## Gives [param character] the class [param data]. Practice mode has no freeze time, so it
## always works (the same call as [method RoundManager.request_class], which only allows it
## during freeze time). Returns false only when there is nothing to change.
func request_class(character: Character, data: ClassData) -> bool:
	if data == null or not is_instance_valid(character):
		return false
	character.class_data = data
	return true


## Practice buys anything for free, any time (D-090): the buy menu's questions answered for it.
func can_buy_now(character: Character) -> bool:
	return is_instance_valid(character) and character.is_alive()


func get_buy_time_left() -> float:
	return 0.0


## Everything is free in practice.
func get_price(_character: Character, _item_id: StringName) -> int:
	return 0


func get_buy_refusal(character: Character, item_id: StringName) -> String:
	if not can_buy_now(character):
		return "You're dead"
	return Shop.refusal(character, item_id, true, false)


## Hands [param item_id] over for free. Returns "" when given, else why not.
func request_buy(character: Character, item_id: StringName) -> String:
	var reason := get_buy_refusal(character, item_id)
	if reason == "":
		Shop.give(character, item_id)
	return reason


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
	if _player != null:
		give_loadout(_player)
	for i in bot_count:
		add_bot()


func _on_died(_killer: Character, victim: Character) -> void:
	await get_tree().create_timer(respawn_delay, false, true).timeout
	if not is_instance_valid(victim):
		return
	var spot := _pick_from_group(PLAYER_SPAWN_GROUP, _player_start) if victim == _player else _pick_bot_spawn()
	victim.respawn(spot.origin, spot.basis.get_euler().y)
	give_loadout(victim)


func _pick_bot_spawn() -> Transform3D:
	var markers := get_tree().get_nodes_in_group(BOT_SPAWN_GROUP)
	if not markers.is_empty():
		return _pick_free_marker(markers)
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
	return _pick_free_marker(markers)


## A random marker with nobody standing on it (any marker if all are taken).
func _pick_free_marker(markers: Array[Node]) -> Transform3D:
	var free: Array[Node] = markers.filter(func(marker: Node) -> bool:
		for character in Character.all_in_world(self):
			if character.is_alive() and character.global_position.distance_to((marker as Node3D).global_position) < SPAWN_CLEARANCE:
				return false
		return true)
	var choices := free if not free.is_empty() else markers
	return (choices[_rng.randi() % choices.size()] as Node3D).global_transform
