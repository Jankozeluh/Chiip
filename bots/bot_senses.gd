class_name BotSenses
extends Node
## What a bot knows about its enemies: what it notices, what it has heard, and
## where it last noticed them. A child of the bot's [Character].
##
## Fair by design: vision needs line of sight (no wallhacks), and an enemy has
## to stay in view for a moment before the bot notices it. That takes longer
## far away and at the edge of vision, like for a person. Hearing only picks
## up noises within range (running and shooting, not walking), getting shot
## reveals where the shot came from, and memory fades.

## Emitted when the bot notices an enemy it wasn't fighting before.
signal enemy_spotted(enemy: Character)

## Width of the view cone, in degrees.
@export var field_of_view_degrees: float = 110.0
## Width of the central part of vision where enemies are noticed fastest, in degrees.
@export var focus_degrees: float = 50.0
## How far the bot can see, in metres.
@export var sight_range: float = 60.0
## Seconds to notice an enemy straight ahead and close by.
@export var base_notice_time: float = 0.25
## Every this many metres of distance add one second of noticing time.
@export var notice_metres_per_second: float = 35.0
## Noticing outside the central part of vision takes this many times longer.
@export var peripheral_slowdown: float = 2.5
## How long the bot remembers where it last saw or heard an enemy, in seconds.
@export var memory_seconds: float = 8.0
## How often vision is checked, in seconds.
@export var check_interval: float = 0.1

## The enemy the bot has noticed and can see right now, or null.
var visible_enemy: Character = null
## Where the bot last saw or heard an enemy. Only meaningful while [method has_lead] is true.
var last_known_position: Vector3 = Vector3.ZERO
## Multiplies all noticing times; set from the bot's difficulty (higher = slower).
var notice_time_scale: float = 1.0

var _character: Character
var _time_since_lead: float = INF
## How long the current lead lasts when it is shorter than the memory (a teammate's call), in seconds.
var _lead_limit: float = INF
var _time_until_check: float = 0.0
## How aware the bot is of each enemy it can see: 0 = not at all, 1 = noticed.
var _awareness: Dictionary = {}


func _enter_tree() -> void:
	_character = get_parent() as Character


func _ready() -> void:
	Noises.get_bus().noise_made.connect(_on_noise_made)
	_character.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	_time_since_lead += delta
	_time_until_check -= delta
	if _time_until_check > 0.0:
		return
	_time_until_check = check_interval
	_look_for_enemies(check_interval)


## True while the bot knows (from sight, sound or recent memory) where an enemy might be.
func has_lead() -> bool:
	return _time_since_lead <= minf(memory_seconds, _lead_limit)


## A teammate's call ([BotSquad], D-216): an enemy at [param position], a lead for only [param seconds] (a trade
## or a callout is worth a quick look, not a long hunt), unless the bot sees or hears something itself.
func hear_call(position: Vector3, seconds: float) -> void:
	_remember(position)
	_lead_limit = seconds


## Seconds since the bot last saw or heard an enemy (INF if it knows of none).
func get_lead_age() -> float:
	return _time_since_lead


## Forgets what the bot knew, e.g. after it searched the last known position.
func forget() -> void:
	_time_since_lead = INF


## Forgets everything, including what it sees right now (e.g. after respawning).
func reset() -> void:
	forget()
	visible_enemy = null
	_awareness.clear()
	_time_until_check = 0.0


## True if [param other] is an enemy in the bot's view right now: alive, in
## range, inside the view cone and not hidden behind the world. (Seeing isn't
## noticing yet; see [member visible_enemy].)
func can_see(other: Character) -> bool:
	if other == null or not other.is_alive() or Teams.are_allies(other, _character):
		return false
	# Blinded by a flashbang: nothing at all (D-097).
	if _character.get_flash_alpha() > 0.5:
		return false
	var to_other := other.get_eye_position() - _character.get_eye_position()
	if to_other.length() > sight_range:
		return false
	if _angle_from_view(to_other) > field_of_view_degrees / 2.0:
		return false
	# Visible if a ray from the eyes reaches the head or the chest.
	for target in other.get_visibility_points():
		# A smoke cloud hides what's behind or inside it (D-097).
		if Smokes.blocks(_character.get_eye_position(), target):
			continue
		var query := PhysicsRayQueryParameters3D.create(_character.get_eye_position(), target, PhysicsLayers.WORLD)
		if _character.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


## Seconds of continuous view the bot needs to notice [param other] where it is now.
func get_notice_time(other: Character) -> float:
	var to_other := other.get_eye_position() - _character.get_eye_position()
	var seconds := base_notice_time + to_other.length() / notice_metres_per_second
	if _angle_from_view(to_other) > focus_degrees / 2.0:
		seconds *= peripheral_slowdown
	return seconds * notice_time_scale


func _look_for_enemies(step: float) -> void:
	var closest: Character = null
	var closest_distance := INF
	for other in Character.all_in_world(_character):
		var awareness: float = _awareness.get(other, 0.0)
		if can_see(other):
			# Keep noticing an enemy already being fought; build up awareness of new ones.
			awareness = 1.0 if other == visible_enemy else minf(awareness + step / get_notice_time(other), 1.0)
		else:
			awareness = maxf(awareness - step, 0.0)
		if awareness <= 0.0:
			_awareness.erase(other)
			continue
		_awareness[other] = awareness
		if awareness >= 1.0 and can_see(other):
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


## Angle between where the bot looks and a direction, in degrees.
func _angle_from_view(direction: Vector3) -> float:
	var aim := _character.get_aim_angles()
	var view_direction := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	return rad_to_deg(view_direction.angle_to(direction))


func _on_noise_made(noise_position: Vector3, hearing_range: float, source: Character) -> void:
	if source == null or Teams.are_allies(source, _character) or not _character.is_alive():
		return
	if _character.global_position.distance_to(noise_position) <= hearing_range:
		_remember(noise_position)


## Getting shot tells the bot roughly where the shooter is.
func _on_damaged(_amount: float, _zone: Hitbox.Zone, attacker: Character) -> void:
	if attacker != null and not Teams.are_allies(attacker, _character):
		_remember(attacker.global_position)


func _remember(position: Vector3) -> void:
	last_known_position = position
	_time_since_lead = 0.0
	_lead_limit = INF
