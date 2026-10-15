class_name BotSenses
extends Node
## What a bot knows about its enemies: what it can see, what it has heard, and
## where it last noticed them. A child of the bot's [Character].
##
## Fair by design: vision needs line of sight (no wallhacks), hearing only picks
## up noises within range (running and shooting, not walking), and memory fades.

## Emitted when the bot starts seeing an enemy it wasn't seeing before.
signal enemy_spotted(enemy: Character)

## Width of the view cone, in degrees.
@export var field_of_view_degrees: float = 110.0
## How far the bot can see, in metres.
@export var sight_range: float = 80.0
## How long the bot remembers where it last saw or heard an enemy, in seconds.
@export var memory_seconds: float = 8.0
## How often vision is checked, in seconds. People don't react instantly either.
@export var check_interval: float = 0.1

## The enemy the bot can see right now, or null.
var visible_enemy: Character = null
## Where the bot last saw or heard an enemy. Only meaningful while [method has_lead] is true.
var last_known_position: Vector3 = Vector3.ZERO

var _character: Character
var _time_since_lead: float = INF
var _time_until_check: float = 0.0


func _enter_tree() -> void:
	_character = get_parent() as Character


func _ready() -> void:
	Noises.get_bus().noise_made.connect(_on_noise_made)


func _physics_process(delta: float) -> void:
	_time_since_lead += delta
	_time_until_check -= delta
	if _time_until_check > 0.0:
		return
	_time_until_check = check_interval
	_look_for_enemies()


## True while the bot knows (from sight, sound or recent memory) where an enemy might be.
func has_lead() -> bool:
	return _time_since_lead <= memory_seconds


## Forgets what the bot knew, e.g. after it searched the last known position.
func forget() -> void:
	_time_since_lead = INF


## Forgets everything, including what it sees right now (e.g. after respawning).
func reset() -> void:
	forget()
	visible_enemy = null
	_time_until_check = 0.0


## True if [param other] is an enemy the bot could see right now: alive, in
## range, inside the view cone and not hidden behind the world.
func can_see(other: Character) -> bool:
	if other == null or other == _character or not other.is_alive() or other.team == _character.team:
		return false
	var eye := _character.get_eye_position()
	var to_other := other.get_eye_position() - eye
	if to_other.length() > sight_range:
		return false
	var aim := _character.get_aim_angles()
	var view_direction := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	if rad_to_deg(view_direction.angle_to(to_other)) > field_of_view_degrees / 2.0:
		return false
	# Visible if a ray from the eyes reaches the head or the chest.
	for target in other.get_visibility_points():
		var query := PhysicsRayQueryParameters3D.create(eye, target, PhysicsLayers.WORLD)
		if _character.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _look_for_enemies() -> void:
	var closest: Character = null
	var closest_distance := INF
	for node in get_tree().get_nodes_in_group("characters"):
		var other := node as Character
		if can_see(other):
			var distance := _character.global_position.distance_to(other.global_position)
			if distance < closest_distance:
				closest = other
				closest_distance = distance
	var was_seeing := visible_enemy
	visible_enemy = closest
	if visible_enemy != null:
		_remember(visible_enemy.global_position)
		if visible_enemy != was_seeing:
			enemy_spotted.emit(visible_enemy)


func _on_noise_made(noise_position: Vector3, hearing_range: float, source: Character) -> void:
	if source == null or source == _character or source.team == _character.team or not _character.is_alive():
		return
	if _character.global_position.distance_to(noise_position) <= hearing_range:
		_remember(noise_position)


func _remember(position: Vector3) -> void:
	last_known_position = position
	_time_since_lead = 0.0
