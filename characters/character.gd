class_name Character
extends CharacterBody3D
## A character that moves and fights by Counter-Strike's rules. The player
## and every bot use this same script.
##
## It never reads the keyboard. Every physics tick it asks its
## [CharacterController] (a child node) for a [CharacterInput] command and
## simulates it, the way a CS server simulates each client's "usercmd". So
## bots follow exactly the same movement and shooting rules as the player, and
## network players in M9 will too.
##
## Movement follows the Quake/Source engine model that CS is built on:
## friction slows you down on the ground, acceleration pushes you toward the
## direction you hold, and in the air you only get a little control, which is
## what makes air strafing possible.
##
## Distances are in metres and speeds in metres per second. CS values are
## converted with [constant UNITS_TO_METRES]. See docs/GAME_DESIGN.md, section 4.1.

## Emitted when the character takes damage.
signal damaged(amount: float, zone: Hitbox.Zone, attacker: Character)
## Emitted once when health reaches 0. [param killer] may be null.
signal died(killer: Character)
## Emitted for each footstep. [param loud] is false when walking or crouching (silent, as in CS).
signal footstep(loud: bool)
## Emitted after [method respawn] brings the character back.
signal respawned

## CS/Source distance units to metres (1 unit ≈ 1 inch).
const UNITS_TO_METRES := 0.0254
## Distance covered per footstep, in metres (about 3 steps per second at full run).
const STEP_DISTANCE := 1.8
## Where the eyes (and a player's camera) end up after dying: close to the floor.
const DEAD_EYE_HEIGHT := 0.35
## Seconds the body takes to fall over.
const DEATH_FALL_TIME := 0.45

@export_group("Speed")
## Top running speed with nothing in hand. CS: 250 units/s with the knife out.
## A held weapon sets its own top speed; see [method get_max_speed].
@export var max_speed: float = 250.0 * UNITS_TO_METRES
## Walking (Shift) speed as a fraction of the top speed. CS: 0.52.
@export var walk_speed_factor: float = 0.52
## Crouching speed as a fraction of the top speed. CS: 0.34.
@export var crouch_speed_factor: float = 0.34

@export_group("Ground")
## How quickly you speed up on the ground. CS:GO: sv_accelerate 5.5.
@export var ground_acceleration: float = 5.5
## How quickly you slow down on the ground. CS:GO: sv_friction 5.2.
@export var friction: float = 5.2
## Below this speed, friction acts as if you were moving this fast, so you come
## to a full stop quickly. CS: sv_stopspeed 80 units/s.
@export var stop_speed: float = 80.0 * UNITS_TO_METRES

@export_group("Air")
## How much control you have in the air. CS:GO: sv_airaccelerate 12.
@export var air_acceleration: float = 12.0
## The most speed you can add in any one direction while in the air. It's low,
## which is why you can't run in the air but can air strafe. Source: 30 units/s.
@export var air_speed_cap: float = 30.0 * UNITS_TO_METRES

@export_group("Jump")
## How high your feet rise in a standing jump. CS: about 57 units.
@export var jump_height: float = 57.0 * UNITS_TO_METRES
## Jumping caps your horizontal speed at this multiple of the top speed, so bunny
## hopping can't build up speed. Source engine: 1.2.
@export var bunny_hop_cap: float = 1.2

@export_group("Crouch")
## Standing eye height above the feet. CS: 64 units.
@export var stand_eye_height: float = 64.0 * UNITS_TO_METRES
## Crouched eye height above the feet. CS: 46 units.
@export var crouch_eye_height: float = 46.0 * UNITS_TO_METRES
## Seconds for the view to move between standing and crouched height.
@export var crouch_transition_time: float = 0.15

@export_group("Health")
## Health at spawn. CS: 100.
@export var max_health: float = 100.0

@export_group("Team")
## Which team this character is on: 0 or 1. Teams have no names (see [Teams]).
## Characters only fight the other team, and the clothes are blue for the
## viewer's own team and red for the other. Changing it recolors the body.
@export var team: int = 0:
	set(value):
		team = value
		# Before _ready the body doesn't exist yet; _set_up_body colors it then.
		if is_node_ready():
			update_team_color()

@export_group("Sound")
## Played for each loud footstep (walking and crouching are silent). Tests set it to null.
@export var footstep_sound: AudioStream = preload("res://assets/sounds/footsteps.tres")

@export_group("")
## The gun this character holds.
@export var weapon: Weapon

## Current health; 0 means dead. Read-only for other scripts (use [method take_damage]).
var health: float = 0.0
## Takes no damage (console: god).
var god_mode: bool = false
## Flies through walls in the direction it looks, ignoring gravity (console: noclip).
var noclip: bool = false

## True while crouched (the smaller collision capsule is active). Read-only for other scripts.
var is_crouching: bool = false

## The command being simulated this tick, from the controller.
var _input := CharacterInput.new()
## Whatever drives this character: the first CharacterController among its children.
var _controller: CharacterController
## The damage zones on the body.
var _hitboxes: Array[Hitbox] = []
## Distance walked since the last footstep.
var _distance_since_step: float = 0.0
## The body's physics layer while alive (dead bodies don't block anyone).
var _alive_collision_layer: int = 0
## Current eye height above the feet. Moves smoothly toward the standing or crouched height.
var _eye_height: float = 0.0
## How much taller the standing capsule is than the crouching one (CS: 18 units).
var _hull_height_difference: float = 0.0
## The clothes material on chest and arms, colored by [method update_team_color].
var _clothes := StandardMaterial3D.new()

## The eyes: shots start here, and a first-person camera follows it.
@onready var head: Node3D = $Head
## The visible body with its hit zones and walk animation (characters/soldier_body.tscn).
@onready var body: SoldierBody = $Body
@onready var _footstep_audio: AudioStreamPlayer = $FootstepAudio
@onready var _footstep_audio_3d: AudioStreamPlayer3D = $FootstepAudio3D
@onready var _standing_collision: CollisionShape3D = $StandingCollision
@onready var _crouching_collision: CollisionShape3D = $CrouchingCollision


func _ready() -> void:
	_input.yaw = rotation.y
	_eye_height = stand_eye_height
	head.position.y = _eye_height
	var standing_shape := _standing_collision.shape as CapsuleShape3D
	var crouching_shape := _crouching_collision.shape as CapsuleShape3D
	_hull_height_difference = standing_shape.height - crouching_shape.height
	_set_crouch_hull(false)
	health = max_health
	_alive_collision_layer = collision_layer
	add_to_group("characters")
	_set_up_body()
	for child in get_children():
		if child is CharacterController:
			_controller = child
			break
	if _controller != null:
		_controller.set_look_angles(_input.yaw, _input.pitch)
	if weapon != null:
		weapon.equip(self)


func _physics_process(delta: float) -> void:
	if _controller != null and is_alive():
		_input = _controller.get_input(delta)
	elif not is_alive():
		# Dead characters don't act: keep facing the same way, press nothing.
		var still := CharacterInput.new()
		still.yaw = _input.yaw
		still.pitch = _input.pitch
		_input = still
	# Face where the command looks, so "forward" is where you look. The head
	# tilts up and down, which points a third-person gun (bots) at the target.
	rotation.y = _input.yaw
	head.rotation.x = _input.pitch
	if weapon != null:
		# The weapon processes after the character (children run after their
		# parent), so it sees this tick's trigger state.
		weapon.trigger_held = _input.shoot
		if _input.reload:
			weapon.reload()
	if noclip:
		_fly(delta)
		return

	var on_ground := is_on_floor()
	# As in CS, you jump only on the tick you press jump while on the ground.
	# Holding jump doesn't jump again when you land.
	if on_ground and _input.jump:
		_jump()
		on_ground = false

	_update_crouch(on_ground, delta)

	var wish_direction := _get_wish_direction()
	var wish_speed := _get_wish_speed()
	if on_ground:
		velocity.y = 0.0
		_apply_friction(delta)
		_accelerate(wish_direction, wish_speed, _get_stance_factor() * max_speed, delta)
		move_and_slide()
	else:
		_air_accelerate(wish_direction, wish_speed, delta)
		# Half the gravity before moving and half after (as the Source engine
		# does) makes the jump height exact at any tick rate.
		var half_gravity := get_gravity() * delta * 0.5
		velocity += half_gravity
		move_and_slide()
		velocity += half_gravity
	_update_footsteps(on_ground, delta)


## True while health is above 0.
func is_alive() -> bool:
	return health > 0.0


## Lowers health and reports it; at 0 the character dies. [param attacker] may be null.
## Damage from a teammate is scaled by [method Teams.damage_factor] (nothing
## unless friendly fire is on). The rule lives here, in the code that owns the
## health, so a network client can't skip it.
func take_damage(amount: float, zone: Hitbox.Zone, attacker: Character) -> void:
	if not is_alive() or god_mode:
		return
	var factor := Teams.damage_factor(self, attacker)
	if factor <= 0.0:
		return
	amount *= factor
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, zone, attacker)
	if health <= 0.0:
		_die(attacker)


## True for the player at this computer (see [method CharacterController.is_local]).
func is_local_player() -> bool:
	return _controller != null and _controller.is_local()


## Points other characters check for line of sight: head and chest.
func get_visibility_points() -> Array[Vector3]:
	return [get_eye_position(), global_position + Vector3.UP * (_eye_height - 0.35)]


## Gives the clothes the color of this character's team as the viewer sees it
## (see [method Teams.color_for]). Call it after the viewer's team changes.
func update_team_color() -> void:
	_clothes.albedo_color = Teams.color_for(team)


## Physics IDs of this character's hit zones, so its own shots can ignore them.
func get_hitbox_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for hitbox in _hitboxes:
		rids.append(hitbox.get_rid())
	return rids


## The camera this character is seen through (the player's), or null for bots.
func get_camera() -> Camera3D:
	return _controller.get_camera() if _controller != null else null


## Where shots start from: the eyes, as of this physics tick.
func get_eye_position() -> Vector3:
	return head.global_position


## Where the character is aiming as (yaw, pitch) in radians, without any recoil.
func get_aim_angles() -> Vector2:
	return Vector2(_input.yaw, _input.pitch)


## Turns the view to look at a world position. Used by tests.
func aim_at(target: Vector3) -> void:
	var direction := (target - get_eye_position()).normalized()
	_input.yaw = atan2(-direction.x, -direction.z)
	_input.pitch = asin(direction.y)
	rotation.y = _input.yaw
	if _controller != null:
		_controller.set_look_angles(_input.yaw, _input.pitch)


## Top running speed right now: set by the held weapon (CS: rifles 215 u/s),
## or [member max_speed] with nothing in hand.
func get_max_speed() -> float:
	if weapon != null and weapon.data != null:
		return weapon.data.max_speed_units * UNITS_TO_METRES
	return max_speed


## Noclip: moves straight where the movement keys point relative to the view
## (looking up and pressing forward flies up), at twice running speed, through walls.
func _fly(delta: float) -> void:
	var view := Basis.from_euler(Vector3(_input.pitch, _input.yaw, 0.0))
	var direction := view * Vector3(_input.move.x, 0.0, _input.move.y)
	velocity = direction.limit_length(1.0) * max_speed * 2.0
	global_position += velocity * delta


## Counts distance walked on the ground and takes a step every STEP_DISTANCE.
## Steps faster than walking speed are loud and can be heard by bots.
func _update_footsteps(on_ground: bool, delta: float) -> void:
	if not on_ground:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_distance_since_step += speed * delta
	if _distance_since_step < STEP_DISTANCE:
		return
	_distance_since_step = 0.0
	var loud := not is_crouching and speed > get_max_speed() * walk_speed_factor * 1.05
	footstep.emit(loud)
	if loud:
		Noises.make_noise(global_position, Noises.FOOTSTEP_RANGE, self)
		_play_footstep()


## Your own steps play in both ears; everyone else's come from where they are.
func _play_footstep() -> void:
	if footstep_sound == null:
		return
	if is_local_player():
		_footstep_audio.stream = footstep_sound
		_footstep_audio.play()
	else:
		_footstep_audio_3d.stream = footstep_sound
		_footstep_audio_3d.play()


## Brings the character back at [param at], facing [param yaw], with full
## health and a full weapon.
func respawn(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	health = max_health
	is_crouching = false
	_set_crouch_hull(false)
	_eye_height = stand_eye_height
	head.position.y = _eye_height
	body.reset_pose()
	collision_layer = _alive_collision_layer
	for hitbox in _hitboxes:
		hitbox.collision_layer = PhysicsLayers.HITBOXES
	_input = CharacterInput.new()
	_input.yaw = yaw
	if _controller != null:
		_controller.set_look_angles(yaw, 0.0)
		_controller.on_respawned()
	if weapon != null:
		weapon.refill()
	reset_physics_interpolation()
	respawned.emit()


func _die(killer: Character) -> void:
	if weapon != null:
		weapon.trigger_held = false
	# Dead bodies can't be hit again, and don't block anyone.
	for hitbox in _hitboxes:
		hitbox.set_deferred("collision_layer", 0)
	set_deferred("collision_layer", 0)
	# Tip the body over backwards around the feet. Run the tween on physics
	# ticks so physics interpolation smooths it like any other movement.
	var fall := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	fall.tween_property(body, "rotation:x", -PI / 2.0, DEATH_FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	died.emit(killer)


## Finds the body's hit zones and gives the clothes this character's team color.
func _set_up_body() -> void:
	update_team_color()
	for node in body.find_children("*", "", true, false):
		if node is Hitbox:
			_hitboxes.append(node)
			(node as Hitbox).hit.connect(_on_hitbox_hit)
		elif node is MeshInstance3D and node.is_in_group("team_colored"):
			(node as MeshInstance3D).material_override = _clothes


func _on_hitbox_hit(damage: float, zone: Hitbox.Zone, _hit_position: Vector3, attacker: Node) -> void:
	take_damage(damage, zone, attacker as Character)


## Returns the horizontal direction the movement keys point to, relative to where you look.
func _get_wish_direction() -> Vector3:
	return (transform.basis * Vector3(_input.move.x, 0.0, _input.move.y)).normalized()


## Returns the top speed for the current stance and weapon.
func _get_wish_speed() -> float:
	return get_max_speed() * _get_stance_factor()


## Returns the speed fraction for the current stance: crouching, walking or running.
func _get_stance_factor() -> float:
	if is_crouching:
		return crouch_speed_factor
	if _input.walk:
		return walk_speed_factor
	return 1.0


## Slows you down on the ground (Quake/Source friction).
func _apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# Slow speeds lose as much as stop_speed would, so you stop crisply instead of sliding.
	var control := maxf(speed, stop_speed)
	var new_speed := maxf(speed - control * friction * delta, 0.0)
	velocity.x *= new_speed / speed
	velocity.z *= new_speed / speed


## Speeds you up on the ground toward wish_direction until you reach
## wish_speed in that direction (Quake/Source acceleration). Speed in other
## directions isn't capped, which is what makes counter-strafing work.
##
## How hard you accelerate comes from [param acceleration_speed]: CS:GO uses
## the empty-handed top speed (250 u/s) scaled for walking or crouching, not
## the weapon's speed. Otherwise crouch-walking with a rifle (73 u/s) couldn't
## overcome friction at all.
func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration_speed: float, delta: float) -> void:
	var current_speed := velocity.dot(wish_direction)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(ground_acceleration * acceleration_speed * delta, add_speed)
	velocity += wish_direction * accel_speed


## Air control (Source's AirAccelerate). Like _accelerate, but you can only
## build up air_speed_cap in the direction you hold. Turning your view while
## holding a strafe key keeps that small push pointing sideways, so you can
## curve and even gain speed: air strafing.
func _air_accelerate(wish_direction: Vector3, wish_speed: float, delta: float) -> void:
	var capped_wish_speed := minf(wish_speed, air_speed_cap)
	var current_speed := velocity.dot(wish_direction)
	var add_speed := capped_wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(air_acceleration * wish_speed * delta, add_speed)
	velocity += wish_direction * accel_speed


## Launches you upward and caps horizontal speed (CS's bunny hop limit).
func _jump() -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed_cap := get_max_speed() * bunny_hop_cap
	if horizontal.length() > speed_cap:
		horizontal = horizontal.normalized() * speed_cap
	# The upward speed needed to rise exactly jump_height: v = √(2 · g · h).
	velocity = horizontal + Vector3.UP * sqrt(2.0 * get_gravity().length() * jump_height)


## Crouches or stands up to match the crouch command, and moves the eyes smoothly.
func _update_crouch(on_ground: bool, delta: float) -> void:
	if _input.crouch and not is_crouching:
		_crouch(on_ground)
	elif not _input.crouch and is_crouching:
		_try_stand_up(on_ground)

	var target_eye_height := crouch_eye_height if is_crouching else stand_eye_height
	if not is_alive():
		target_eye_height = DEAD_EYE_HEIGHT
	var eye_speed := (stand_eye_height - crouch_eye_height) / crouch_transition_time
	_eye_height = move_toward(_eye_height, target_eye_height, eye_speed * delta)
	head.position.y = _eye_height
	if is_alive():
		# Head, chest, stomach and arms sink when crouching (as in CS), and the
		# limbs swing with walking speed.
		var speed := Vector2(velocity.x, velocity.z).length()
		body.update_pose(speed, get_max_speed(), _eye_height - stand_eye_height, on_ground, delta)


func _crouch(on_ground: bool) -> void:
	is_crouching = true
	_set_crouch_hull(true)
	if not on_ground:
		# In the air, crouching pulls your legs up instead of lowering your
		# head (CS's crouch-jump): lift the body so the head stays in place.
		global_position.y += _hull_height_difference
		_eye_height -= _hull_height_difference


func _try_stand_up(on_ground: bool) -> void:
	if on_ground:
		# Standing up raises your head, so there must be room above.
		if test_move(global_transform, Vector3.UP * _hull_height_difference):
			return
	else:
		# In the air your legs come back down, so there must be room below.
		if test_move(global_transform, Vector3.DOWN * _hull_height_difference):
			return
		global_position.y -= _hull_height_difference
		_eye_height += _hull_height_difference
	is_crouching = false
	_set_crouch_hull(false)


## Switches between the standing and the crouching collision capsule.
func _set_crouch_hull(crouched: bool) -> void:
	_standing_collision.disabled = crouched
	_crouching_collision.disabled = not crouched
