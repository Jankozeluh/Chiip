class_name Grenade
extends Node3D
## A thrown grenade (M7, D-097): it flies under a light gravity, bounces off walls, floors and
## people, and goes off by its kind ([member data]'s id):
## - [b]frag[/b]: [constant FRAG_FUSE] seconds after the throw, a blast whose damage falls off
##   like a bell curve (98 at the middle, about 59 at 3 m, nothing past 9 m); walls stop it, armor
##   takes its share ([member WeaponData.armor_penetration]); the kill is the thrower's.
## - [b]flashbang[/b]: [constant FLASH_FUSE] seconds after the throw, a flash that blinds everyone
##   with a clear line to it (teammates and the thrower too), longer the more they face it and the
##   closer they are ([method get_flash_amount], [method Character.flash]).
## - [b]smoke[/b]: once it has come to rest (or after [constant SMOKE_MAX_FUSE] seconds), a
##   [SmokeCloud] for 18 s.
##
## Flight is computed here, tick by tick, with rays (deterministic, no rigid body), so a seeded
## test or a network host gets the same path every time. Authority code: in M9 the host runs it.

## Gravity on a grenade, m/s²: CS uses 0.4 of the world's 800 units/s².
const GRAVITY := 20.32 * 0.4
## How much speed a bounce keeps, across the surface and along it.
const BOUNCE_NORMAL := 0.45
const BOUNCE_ALONG := 0.75
## Below this speed (m/s) on a floor it stops rolling and rests.
const REST_SPEED := 0.25
## The grenade's radius for collisions (metres).
const RADIUS := 0.05
## It doesn't collide with its thrower for this long after leaving the hand (seconds).
const THROWER_GRACE := 0.25
const FRAG_FUSE := 1.6
const FLASH_FUSE := 1.6
## A smoke pops once it rests after this long, or at [constant SMOKE_MAX_FUSE] whatever it does.
const SMOKE_MIN_FUSE := 1.0
const SMOKE_MAX_FUSE := 3.5
## The frag's blast: damage falls off like a bell curve with this width (metres), to nothing at
## [constant FRAG_RANGE].
const FRAG_SIGMA := 3.0
const FRAG_RANGE := 9.0
## The flash: who is farther than this sees nothing of it (metres); full strength up to
## [constant FLASH_FULL_DISTANCE], down to [constant FLASH_FAR_STRENGTH] at the edge.
const FLASH_RANGE := 45.0
const FLASH_FULL_DISTANCE := 8.0
const FLASH_FAR_STRENGTH := 0.35
## The longest blindness, in seconds (a flash in your face up close), of which the last
## [constant FLASH_FADE] fade out (CS: about 4.9 s at most).
const FLASH_MAX := 4.5
const FLASH_FADE := 2.0
const BOUNCE_SOUND := preload("res://assets/sounds/grenade_bounce.wav")

## Emitted when it goes off, where it is.
signal detonated(at: Vector3)

## The grenade's data (its id decides what it does).
var data: WeaponData
## Who threw it: the frag's kills are theirs.
var thrower: Character
## Current velocity, m/s.
var velocity: Vector3 = Vector3.ZERO
## Seconds since it left the hand.
var age: float = 0.0
## True once it lies still.
var resting: bool = false

## Online, on a client (M9, D-113): a copy of the host's grenade, moved by the snapshots; it
## neither flies nor goes off by itself.
var replica: bool = false

var _done: bool = false
var _model: Node3D
var _audio: AudioStreamPlayer3D


## Throws [param weapon_data] from [param from] with [param initial_velocity], as a child of
## [param parent]. Returns the grenade in flight.
static func throw(parent: Node, weapon_data: WeaponData, from: Vector3, initial_velocity: Vector3,
		by: Character) -> Grenade:
	var grenade := Grenade.new()
	grenade.name = "Grenade_%s" % String(weapon_data.id)
	grenade.data = weapon_data
	grenade.thrower = by
	grenade.velocity = initial_velocity
	parent.add_child(grenade)
	grenade.global_position = from
	return grenade


## The velocity of a throw from someone aiming at [param aim] (yaw, pitch in radians) at
## [param speed] m/s while moving at [param mover_velocity]: CS aims a little higher than the
## view (10° up when looking level) and adds 1.25 times the thrower's own speed.
static func throw_velocity(aim: Vector2, speed: float, mover_velocity: Vector3) -> Vector3:
	var pitch := rad_to_deg(aim.y)
	var thrown_pitch := 10.0 + pitch * (80.0 / 90.0 if pitch >= 0.0 else 100.0 / 90.0)
	var direction := -Basis.from_euler(Vector3(deg_to_rad(thrown_pitch), aim.x, 0.0)).z
	return direction * speed + mover_velocity * 1.25


func _ready() -> void:
	add_to_group("grenades")
	if data != null and data.model != null:
		_model = data.model.instantiate() as Node3D
		add_child(_model)
	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)


func _physics_process(delta: float) -> void:
	if _done:
		return
	age += delta
	if replica:
		# Online, on a client: the host's snapshots move it and its events set it off.
		if _model != null and not resting:
			_model.rotate_x(-delta * 12.0)
		return
	if not resting:
		_fly(delta)
	if _model != null and not resting:
		_model.rotate_x(-delta * 12.0)
	match data.id:
		&"frag":
			if age >= FRAG_FUSE:
				_explode()
		&"flashbang":
			if age >= FLASH_FUSE:
				_flash()
		&"smoke":
			if (resting and age >= SMOKE_MIN_FUSE) or age >= SMOKE_MAX_FUSE:
				_smoke()


## One tick of flight: gravity, then a ray along the move; a hit bounces it off the surface.
func _fly(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var motion := velocity * delta
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + motion + motion.normalized() * RADIUS,
			PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.BOTS)
	if age < THROWER_GRACE and is_instance_valid(thrower):
		query.exclude = [thrower.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = from + motion
		return
	var normal: Vector3 = hit.normal
	global_position = hit.position + normal * RADIUS
	var into := velocity.dot(normal)
	var across := normal * into
	var along := velocity - across
	velocity = along * BOUNCE_ALONG - across * BOUNCE_NORMAL
	if absf(into) > 2.0:
		_play(BOUNCE_SOUND, SoundMix.BOUNCE)
	if normal.y > 0.7 and velocity.length() < REST_SPEED:
		velocity = Vector3.ZERO
		resting = true


## How much a flash at [param at] blinds [param viewer]: 0 (not at all: too far, behind a wall)
## to 1 (in their face up close). Facing it counts fully; from the side less; behind them it only
## whitens the edges a little (0.2).
static func get_flash_amount(viewer: Character, at: Vector3) -> float:
	if not viewer.is_alive():
		return 0.0
	var eye := viewer.get_eye_position()
	var to_flash := at - eye
	var distance := to_flash.length()
	if distance > FLASH_RANGE:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(at, eye, PhysicsLayers.WORLD)
	if not viewer.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	var aim := viewer.get_aim_angles()
	var look := -Basis.from_euler(Vector3(aim.y, aim.x, 0.0)).z
	var facing := look.dot(to_flash.normalized()) if distance > 0.01 else 1.0
	var angle_factor := 0.2
	if facing >= 0.7:
		angle_factor = 1.0
	elif facing >= -0.3:
		angle_factor = lerpf(0.35, 1.0, (facing + 0.3) / 1.0)
	var distance_factor := 1.0
	if distance > FLASH_FULL_DISTANCE:
		distance_factor = lerpf(1.0, FLASH_FAR_STRENGTH, (distance - FLASH_FULL_DISTANCE) / (FLASH_RANGE - FLASH_FULL_DISTANCE))
	return angle_factor * distance_factor


## The frag's damage at [param distance] metres from the blast, before armor.
static func frag_damage_at(base_damage: float, distance: float) -> float:
	if distance > FRAG_RANGE:
		return 0.0
	return base_damage * exp(-distance * distance / (2.0 * FRAG_SIGMA * FRAG_SIGMA))


func _explode() -> void:
	_done = true
	var at := global_position + Vector3.UP * 0.15
	var space := get_world_3d().direct_space_state
	for victim in Character.all_in_world(self):
		if not victim.is_alive():
			continue
		var target := victim.get_chest_position()
		var distance := at.distance_to(target)
		var damage := frag_damage_at(data.damage, distance)
		if damage <= 0.5:
			continue
		# Walls stop it: the blast needs a clear line to the chest or the head.
		var seen := false
		for point in [target, victim.get_head_position()]:
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, point, PhysicsLayers.WORLD)).is_empty():
				seen = true
				break
		if seen:
			victim.take_damage(damage, Hitbox.Zone.CHEST, thrower if is_instance_valid(thrower) else null,
					data.armor_penetration, data)
	Noises.make_noise(at, Noises.GUNSHOT_RANGE, thrower if is_instance_valid(thrower) else null)
	_spawn_effect(Explosion.Kind.FRAG, at)
	_finish(at)


func _flash() -> void:
	_done = true
	var at := global_position + Vector3.UP * 0.1
	for viewer in Character.all_in_world(self):
		var amount := get_flash_amount(viewer, at)
		if amount > 0.0:
			var total := FLASH_MAX * amount
			var fade := minf(FLASH_FADE, total)
			viewer.flash(total - fade, fade)
	Noises.make_noise(at, Noises.GUNSHOT_RANGE * 0.5, thrower if is_instance_valid(thrower) else null)
	_spawn_effect(Explosion.Kind.FLASH, at)
	_finish(at)


func _smoke() -> void:
	_done = true
	var cloud := SmokeCloud.new()
	cloud.name = "SmokeCloud"
	cloud.rng.seed = hash(global_position)
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	_spawn_effect(Explosion.Kind.SMOKE, global_position)
	_finish(global_position)


func _spawn_effect(kind: Explosion.Kind, at: Vector3) -> void:
	var effect := Explosion.new()
	effect.kind = kind
	effect.silent = Weapon.silent
	get_parent().add_child(effect)
	effect.global_position = at


func _finish(at: Vector3) -> void:
	detonated.emit(at)
	queue_free()


func _play(stream: AudioStream, category: StringName) -> void:
	if Weapon.silent:
		return
	Acoustics.play(_audio, stream, category)
