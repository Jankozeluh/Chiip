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

## Emitted when the character takes damage. [param amount] is the health
## actually lost: a 142-damage headshot on 30 HP reports 30.
signal damaged(amount: float, zone: Hitbox.Zone, attacker: Character)
## Emitted once when health reaches 0. [param killer] may be null.
signal died(killer: Character)
## Emitted for each footstep. [param loud] is false when walking or crouching (silent, as in CS).
signal footstep(loud: bool)
## Emitted after [method respawn] brings the character back.
signal respawned
## Emitted when a flashbang blinds the character: fully white for [param full] seconds, then
## fading for [param fade] (D-097).
signal flashed(full: float, fade: float)
## Emitted when the weapon in hand changes ([member weapon]; null when there is none). Whatever
## follows the held weapon (HUD, body, bot brain) reconnects to the new one.
signal weapon_changed(weapon: Weapon)
## Emitted when [member armor], [member has_helmet] or [member has_defuse_kit] change (bought,
## worn down by a hit, lost on death).
signal gear_changed

## CS/Source distance units to metres (1 unit ≈ 1 inch).
const UNITS_TO_METRES := 0.0254
## Distance covered per footstep, in metres (about 3 steps per second at full run).
const STEP_DISTANCE := 1.8
## Where the eyes (and a player's camera) end up after dying: close to the floor.
const DEAD_EYE_HEIGHT := 0.35
## How far other characters' footsteps can be heard, in metres (the FootstepAudio3D node's range).
const FOOTSTEP_AUDIO_RANGE := 30.0

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
## Characters only fight the other team, and the team parts of the body are blue
## for the viewer's own team and red for the other. Changing it recolors the body.
@export var team: int = 0:
	set(value):
		team = value
		# Before _ready the body doesn't exist yet; _set_up_body colors it then.
		if is_node_ready():
			update_team_color()

@export_group("Class")
## The class this character plays: its body (model and hit zones) and, from M7, its perk
## (D-052, D-078). Bots get theirs from the [RoundManager] at the start of a match, and a class
## change in the middle of a match goes through [method RoundManager.request_class]. Setting it
## on a character that is in the game swaps the body at once: the hit zones are gathered again.
## The default is the Rifleman, whose model the body scene already holds.
@export var class_data: ClassData:
	set(value):
		class_data = value
		# Before _ready the body doesn't exist yet; _ready builds the right one then.
		if is_node_ready():
			_apply_class()

@export_group("Sound")
## Played for each loud footstep (walking and crouching are silent). Tests set it to null.
@export var footstep_sound: AudioStream = preload("res://assets/sounds/footsteps.tres")

@export_group("")
## The weapon in hand (null when there is none). The scene's own weapon is the first one the
## [member inventory] carries; from M7 the inventory changes it ([signal weapon_changed]).
@export var weapon: Weapon

## Current health; 0 means dead. Read-only for other scripts (use [method take_damage]).
var health: float = 0.0
## Takes no damage (console: god).
var god_mode: bool = false
## Flies through walls in the direction it looks, ignoring gravity (console: noclip).
var noclip: bool = false
## Set by the game rules during freeze time: the character can look around,
## crouch and reload, but not move, jump or shoot. The rule is applied here,
## to whatever the controller sends, so it holds for every kind of controller.
var frozen: bool = false
## Set by the bomb while this character plants or defuses it (D-080): like
## [member frozen], it can look around and crouch but not move, jump or shoot.
var busy: bool = false

## Armor points, 0 to [constant Armor.MAX_ARMOR] (D-093). Covered hits lose part of their damage
## to it and wear it down ([Armor]). Bought in the buy menu; lost on death. Set it with
## [method set_armor].
var armor: float = 0.0
## Wears a helmet: head hits count as armored while [member armor] lasts.
var has_helmet: bool = false
## Carries a defuse kit (defenders: the bomb defuses in half the time).
var has_defuse_kit: bool = false
## The weapon of the last hit this character took (null for the bomb or a hit without a gun).
## Set before [signal damaged] and [signal died] are emitted, so their listeners can read it
## (kill rewards and the kill feed's icon).
var last_damage_source: WeaponData

## Blindness from a flashbang (D-097): seconds of full white left, then seconds of fading left
## out of how long the fade is. Counted in physics ticks.
var _flash_full_left: float = 0.0
var _flash_fade_left: float = 0.0
var _flash_fade_time: float = 0.0

## True while crouched (the smaller collision capsule is active). Read-only for other scripts.
var is_crouching: bool = false

## The command being simulated this tick, from the controller.
var _input := CharacterInput.new()
## Whatever drives this character: the first CharacterController among its children.
var _controller: CharacterController
## The damage zones on the body (found in [method _set_up_body]).
var _hitboxes: Array[Hitbox] = []
## Distance walked since the last footstep.
var _distance_since_step: float = 0.0
## The body's physics layer while alive (dead bodies don't block anyone).
var _alive_collision_layer: int = 0
## Current eye height above the feet. Moves smoothly toward the standing or crouched height.
var _eye_height: float = 0.0
## How much taller the standing capsule is than the crouching one (CS: 18 units).
var _hull_height_difference: float = 0.0
## Set by [method respawn]: skip moving for the rest of this tick. The physics
## engine (Jolt) only moves teleported bodies at the next physics step, so
## characters moving in the same tick as a round start would still bump into
## each other's old positions and get pushed off their spawn.
var _respawned_this_tick: bool = false

## The eyes: shots start here, and a first-person camera follows it.
@onready var head: Node3D = $Head
## The weapons carried, in slots (D-094).
@onready var inventory: Inventory = $Inventory
## The visible body with its hit zones and animations (characters/crew/crew_body.tscn, a
## generated class model from M6). It paints its team parts through
## [method CrewBody.set_team_color] and animates from this character's state.
@onready var body: CrewBody = $Body
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
	# The body built the scene's default model in its own _ready (children are ready first):
	# swap it for the class's before the hit zones are gathered, so they are gathered once.
	if class_data != null and not _body_is_of_class(class_data):
		body.set_class(class_data)
	_set_up_body()
	for child in get_children():
		if child is CharacterController:
			_controller = child
			break
	if _controller != null:
		_controller.set_look_angles(_input.yaw, _input.pitch)
	inventory.set_up(self, weapon, head)
	_set_up_arms()
	# Only the player at this computer looks through these eyes; everyone else sees the body.
	set_first_person(is_local_player())


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if _respawned_this_tick:
		_respawned_this_tick = false
		return
	if _controller != null and is_alive():
		_input = _controller.get_input(delta)
	elif not is_alive():
		# Dead characters don't act: keep facing the same way, press nothing.
		var still := CharacterInput.new()
		still.yaw = _input.yaw
		still.pitch = _input.pitch
		_input = still
	if frozen or busy:
		_input.move = Vector2.ZERO
		_input.jump = false
		_input.shoot = false
	if is_alive():
		# Switching, dropping and swapping for a gun on the floor; then walking over guns takes them.
		inventory.handle_input(_input)
		inventory.update_pickups()
	# Face where the command looks, so "forward" is where you look. The head
	# tilts up and down, which points a third-person gun (bots) at the target.
	rotation.y = _input.yaw
	head.rotation.x = _input.pitch
	if weapon != null:
		# The weapon processes after the character (children run after their
		# parent), so it sees this tick's trigger state.
		weapon.trigger_held = _input.shoot
		weapon.aim_held = _input.aim
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
## unless friendly fire is on). Then armor takes its share (CS:GO's rule, [Armor]):
## [param armor_penetration] is the share of a covered hit that reaches health (1.0: armor
## doesn't help, as for the bomb), and the class's perk can soften it (the Bulwark's Plated).
## [param source] is the weapon that hit, if any. The rules live here, in the code that owns
## the health, so a network client can't skip them.
func take_damage(amount: float, zone: Hitbox.Zone, attacker: Character, armor_penetration: float = 1.0,
		source: WeaponData = null) -> void:
	if not is_alive() or god_mode:
		return
	var factor := Teams.damage_factor(self, attacker)
	if factor <= 0.0:
		return
	amount *= factor
	if armor > 0.0:
		var damage_factor := class_data.armor_damage_factor if class_data != null else 1.0
		var wear_factor := class_data.armor_wear_factor if class_data != null else 1.0
		var result := Armor.apply(amount, armor_penetration, armor, has_helmet, zone, damage_factor, wear_factor)
		amount = result.health
		_set_armor_points(result.armor)
	last_damage_source = source
	var lost := minf(amount, health)
	health -= lost
	damaged.emit(lost, zone, attacker)
	if health <= 0.0:
		_die(attacker)


## Blinds the character for [param full] seconds of white and [param fade] more seconds of fading,
## unless it's already blind for longer (a flashbang, D-097). Bots see nothing while it's thick.
func flash(full: float, fade: float) -> void:
	if not is_alive() or full + fade <= _flash_full_left + _flash_fade_left:
		return
	_flash_full_left = full
	_flash_fade_left = fade
	_flash_fade_time = fade
	flashed.emit(full, fade)


## How white the view is: 1 fully blind, fading to 0.
func get_flash_alpha() -> float:
	if _flash_full_left > 0.0:
		return 1.0
	if _flash_fade_left > 0.0 and _flash_fade_time > 0.0:
		return _flash_fade_left / _flash_fade_time
	return 0.0


## Gives the character [param points] of armor (clamped to 0–100) and, with [param helmet], a
## helmet. Armor at 0 loses the helmet too. The buy menu, the respawn mode and the console use it.
func set_armor(points: float, helmet: bool) -> void:
	armor = clampf(points, 0.0, Armor.MAX_ARMOR)
	has_helmet = helmet and armor > 0.0
	gear_changed.emit()


## Gives or takes away a defuse kit.
func set_defuse_kit(on: bool) -> void:
	if has_defuse_kit == on:
		return
	has_defuse_kit = on
	gear_changed.emit()


## True while this tick's command holds Use (plant or defuse the bomb) and the
## character is alive.
func is_holding_use() -> bool:
	return is_alive() and _input.use


## Shows this character as seen through its own eyes ([param on] true: the body is hidden and
## the weapon's first-person viewmodel shows) or from outside (the body shows, holding its gun,
## and the viewmodel is hidden). The player at this computer is first person; spectating a
## teammate switches that teammate too. The hit zones stay active either way.
func set_first_person(on: bool) -> void:
	(get_node("Body") as Node3D).visible = not on
	inventory.set_first_person(on)


## True for the player at this computer (see [method CharacterController.is_local]).
func is_local_player() -> bool:
	return _controller != null and _controller.is_local()


## Points other characters check for line of sight: head and chest.
## They are the centres of the body's hit zones (see [method get_head_position] and
## [method get_chest_position]), so a bot sees what it can hit.
func get_visibility_points() -> Array[Vector3]:
	return [get_head_position(), get_chest_position()]


## The centre of the body's head hit zone, where a bot aims for a headshot. Every class has
## the same eye height (CS's 64 units) but its own height, so the head zone sits a little above
## or below the eyes: aiming at the visible head ("what you see is what you hit", D-055) beats
## aiming at the eye position. Falls back to the eye position when the body has no head zone.
func get_head_position() -> Vector3:
	if body.has_zone(Hitbox.Zone.HEAD):
		return body.get_zone_center(Hitbox.Zone.HEAD)
	return get_eye_position()


## The centre of the body's chest hit zone, where a bot aims for the body. It follows the
## class's build and the crouch like the head does. Falls back to a point 35 cm below the
## eyes when the body has no chest zone.
func get_chest_position() -> Vector3:
	if body.has_zone(Hitbox.Zone.CHEST):
		return body.get_zone_center(Hitbox.Zone.CHEST)
	return global_position + Vector3.UP * (_eye_height - 0.35)


## Paints the body's team parts in the color of this character's team as the
## viewer sees it (see [method Teams.color_for]). Call it after the viewer's team changes.
func update_team_color() -> void:
	body.set_team_color(Teams.color_for(team))
	if inventory != null:
		for carried in inventory.get_weapons():
			carried.set_arms_team_color(Teams.color_for(team))


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
		if weapon.is_scoped():
			return weapon.data.scoped_max_speed_units * UNITS_TO_METRES
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
		Noises.make_noise(global_position, get_footstep_range(), self)
		_play_footstep()


## How far (metres) this character's running steps can be heard: [constant Noises.FOOTSTEP_RANGE],
## 70% of it for the Scout's Light Step (D-052, D-099). Bots hear it that far and the sound fades
## out there for you too, so hearing stays symmetric (D-038's rule, with the Scout's exception).
func get_footstep_range() -> float:
	var factor := class_data.running_footstep_range_factor if class_data != null else 1.0
	return Noises.FOOTSTEP_RANGE * factor


## Your own steps play in both ears; everyone else's come from where they are.
## They sound like the floor: gravel, metal, wood, or [member footstep_sound]
## on hard floors (D-084). No [member footstep_sound] means silent (tests).
func _play_footstep() -> void:
	if footstep_sound == null:
		return
	var sound := Surfaces.footstep_sound(Surfaces.floor_kind(get_world_3d(), global_position), footstep_sound)
	if is_local_player():
		_footstep_audio.stream = sound
		_footstep_audio.play()
	else:
		_footstep_audio_3d.stream = sound
		# The steps fade out where bots stop hearing them (shorter for the Scout's Light Step).
		_footstep_audio_3d.max_distance = FOOTSTEP_AUDIO_RANGE * get_footstep_range() / Noises.FOOTSTEP_RANGE
		_footstep_audio_3d.play()


## Brings the character back at [param at], facing [param yaw], with full
## health and a full weapon.
func respawn(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	_respawned_this_tick = true
	velocity = Vector3.ZERO
	health = max_health
	busy = false
	_flash_full_left = 0.0
	_flash_fade_left = 0.0
	is_crouching = false
	_set_crouch_hull(false)
	_eye_height = stand_eye_height
	head.position.y = _eye_height
	collision_layer = _alive_collision_layer
	for hitbox in _hitboxes:
		hitbox.collision_layer = PhysicsLayers.HITBOXES
	_input = CharacterInput.new()
	_input.yaw = yaw
	if _controller != null:
		_controller.set_look_angles(yaw, 0.0)
		_controller.on_respawned()
	inventory.refill()
	reset_physics_interpolation()
	respawned.emit()


func _update_flash(delta: float) -> void:
	if _flash_full_left > 0.0:
		_flash_full_left = maxf(_flash_full_left - delta, 0.0)
	elif _flash_fade_left > 0.0:
		_flash_fade_left = maxf(_flash_fade_left - delta, 0.0)


func _die(killer: Character) -> void:
	if weapon != null:
		weapon.trigger_held = false
	# The best gun falls to the floor (D-090), once this hit has been fully dealt with.
	inventory.drop_on_death.call_deferred()
	# The dead lose their armor, helmet and kit (CS): they start the next round without them.
	armor = 0.0
	has_helmet = false
	has_defuse_kit = false
	gear_changed.emit()
	# Dead bodies can't be hit again, and don't block anyone.
	for hitbox in _hitboxes:
		hitbox.set_deferred("collision_layer", 0)
	set_deferred("collision_layer", 0)
	died.emit(killer)


## Finds the body's hit zones, gives the body this character's team color, and ties its
## animations to this character (see [method CrewBody.attach]).
## The [CrewBody] builds its hit zones in its own _ready, which runs before this one
## (children are ready first), so they are all there to find.
func _set_up_body() -> void:
	update_team_color()
	body.attach(self)
	_gather_hitboxes()


## Listens to every hit zone of the body (see [method CrewBody.get_hitboxes]).
func _gather_hitboxes() -> void:
	for hitbox in body.get_hitboxes():
		_hitboxes.append(hitbox)
		hitbox.hit.connect(_on_hitbox_hit)


## True if the body already has the model and hit zones of [param data]. A body without
## explicit hit zones takes the file next to its model, which is the class's.
func _body_is_of_class(data: ClassData) -> bool:
	return body.model == data.model and (body.hit_zones == null or body.hit_zones == data.hit_zones)


## Gives the body the new [member class_data]: swaps the model and the hit zones, and listens
## to the new zones instead of the old ones. A dead character's new zones stay switched off.
func _apply_class() -> void:
	if class_data == null or _body_is_of_class(class_data):
		return
	for hitbox in _hitboxes:
		if is_instance_valid(hitbox) and hitbox.hit.is_connected(_on_hitbox_hit):
			hitbox.hit.disconnect(_on_hitbox_hit)
	_hitboxes.clear()
	body.set_class(class_data)
	_gather_hitboxes()
	_set_up_arms()
	if not is_alive():
		for hitbox in _hitboxes:
			hitbox.collision_layer = 0


## Puts the class's first-person arms into every carried weapon's viewmodel (D-079): its own
## sleeves and gloves, painted with the class's material in this character's team colour.
func _set_up_arms() -> void:
	for carried in inventory.get_weapons():
		set_up_arms_for(carried)


## Puts the class's first-person arms into [param carried]'s viewmodel. The [Inventory] calls it
## for every weapon it adds.
func set_up_arms_for(carried: Weapon) -> void:
	if carried == null or class_data == null or class_data.arms_model == null:
		return
	carried.set_arms(class_data.arms_model, CrewBody.material_for(class_data.model.resource_path))
	carried.set_arms_team_color(Teams.color_for(team))


func _on_hitbox_hit(damage: float, zone: Hitbox.Zone, _hit_position: Vector3, attacker: Node,
		armor_penetration: float, source: WeaponData) -> void:
	take_damage(damage, zone, attacker as Character, armor_penetration, source)


## Sets the armor points; at 0 the helmet goes too (it only protects while there is armor).
func _set_armor_points(points: float) -> void:
	var before := armor
	armor = clampf(points, 0.0, Armor.MAX_ARMOR)
	if armor <= 0.0:
		has_helmet = false
	if not is_equal_approx(before, armor):
		gear_changed.emit()


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
