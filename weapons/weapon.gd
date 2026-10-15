class_name Weapon
extends Node3D
## A gun held by the player: firing, ammo and reloading.
##
## All numbers come from [member data]. The holder sets [member trigger_held]
## every physics tick and calls [method reload]. Other nodes (HUD, debug
## overlay) listen to the signals instead of polling.

## Emitted for every shot. [param spray_shot] is the shot's number within the current spray (1 = first).
signal fired(spray_shot: int)
## Emitted when the magazine or reserve count changes.
signal ammo_changed(magazine: int, reserve: int)
## Emitted when a reload begins.
signal reload_started
## Emitted when a reload completes and the magazine is refilled.
signal reload_finished
## Emitted when a bullet hits something. See [member last_hit] for the keys.
signal hit_landed(hit: Dictionary)

## When the reload sound plays, as fractions of the reload time: magazine out, magazine in, bolt.
const RELOAD_SOUND_STEPS: Array[float] = [0.1, 0.6, 0.85]
## Below this fraction of top speed you count as standing still (CS: about 34%).
const ACCURATE_SPEED_FRACTION := 0.34
## How quickly the view follows the recoil kick (higher = snappier).
const VIEW_PUNCH_SMOOTHING := 30.0
## Bullet holes kept per weapon; the oldest disappear first.
const MAX_IMPACTS := 100
const IMPACT_SCENE := preload("res://weapons/bullet_impact.tscn")

## The weapon's stats.
@export var data: WeaponData

## Set by the holder: true while the fire button is held.
var trigger_held: bool = false
## Rounds in the magazine. Read-only for other scripts.
var magazine: int = 0
## Spare rounds. Read-only for other scripts.
var reserve: int = 0
## Random numbers for bullet spread. Tests give it a fixed seed so shots are repeatable.
var rng := RandomNumberGenerator.new()
## The most recent bullet hit: [code]position[/code], [code]distance[/code] (metres),
## [code]zone[/code] (hit zone name, or "" for the world) and [code]damage[/code].
var last_hit: Dictionary = {}
## How far recoil currently kicks the view, in degrees (x = right, y = up).
## The player adds it to the camera; it doesn't change where you aim.
var view_punch: Vector2 = Vector2.ZERO

var _wielder: Player
## Seconds until the next shot is allowed.
var _cooldown: float = 0.0
## Seconds of reload left; 0 when not reloading.
var _reload_time_left: float = 0.0
## True once the trigger has been let go since the last shot or empty click.
var _trigger_released: bool = true
## How far into the spray pattern the next shot is (0 = first shot). Goes up
## by 1 per shot and wears off again once you stop firing, so short pauses
## partly reset the pattern, as in CS.
var _spray_position: float = 0.0
## Seconds since the last shot.
var _time_since_shot: float = 0.0
## Bullet holes this weapon made, oldest first.
var _impacts: Array[Node3D] = []

@onready var _shot_audio: AudioStreamPlayer = $ShotAudio
@onready var _handling_audio: AudioStreamPlayer = $HandlingAudio


func _ready() -> void:
	magazine = data.magazine_size
	reserve = data.reserve_ammo
	_shot_audio.stream = data.shot_sound


## Hands the weapon to its holder, who supplies aim and movement state.
func equip(wielder: Player) -> void:
	_wielder = wielder
	ammo_changed.emit(magazine, reserve)


## The current radius of the cone shots land in, in degrees. Stance,
## movement speed and being in the air all add to it.
func get_inaccuracy() -> float:
	if _wielder == null:
		return 0.0
	var inaccuracy := data.crouching_inaccuracy if _wielder.is_crouching else data.standing_inaccuracy
	var top_speed := _wielder.get_max_speed()
	var speed := Vector2(_wielder.velocity.x, _wielder.velocity.z).length()
	var move_fraction := clampf(inverse_lerp(top_speed * ACCURATE_SPEED_FRACTION, top_speed, speed), 0.0, 1.0)
	inaccuracy += data.moving_inaccuracy * move_fraction
	if not _wielder.is_on_floor():
		inaccuracy += data.air_inaccuracy
	inaccuracy += minf(_spray_position * data.spray_inaccuracy_per_shot, data.max_spray_inaccuracy)
	return inaccuracy


## The number the next shot would have within the current spray (1 = first shot).
func get_spray_shot() -> int:
	return floori(_spray_position) + 1


## True while a reload is in progress.
func is_reloading() -> bool:
	return _reload_time_left > 0.0


## Starts a reload if the magazine isn't full and there are spare rounds.
func reload() -> void:
	if is_reloading() or magazine >= data.magazine_size or reserve <= 0:
		return
	_reload_time_left = data.reload_time
	reload_started.emit()


func _physics_process(delta: float) -> void:
	if _wielder == null:
		return
	_cooldown -= delta
	_time_since_shot += delta
	if is_reloading():
		_update_reload(delta)
	elif trigger_held:
		_try_fire()
	if not trigger_held:
		_trigger_released = true
		if magazine == 0:
			reload()  # Auto-reload once you let go of an empty gun, like CS.
	_recover_recoil(delta)
	# A negative cooldown only carries over between back-to-back shots, which keeps the fire rate exact.
	_cooldown = maxf(_cooldown, 0.0)


func _process(delta: float) -> void:
	if data == null:
		return
	# The view kicks toward where the next shot would go, by view_punch_fraction
	# of the pattern, and follows smoothly instead of jumping.
	var target := data.get_spray_offset(_spray_position) * data.view_punch_fraction
	view_punch = view_punch.lerp(target, 1.0 - exp(-VIEW_PUNCH_SMOOTHING * delta))


## Lets the spray pattern wear off once you stop firing. While firing
## continuously the gap between shots stays below 1.5 shot intervals, so a
## full-auto spray follows the pattern exactly.
func _recover_recoil(delta: float) -> void:
	if _time_since_shot > data.get_shot_interval() * 1.5:
		_spray_position = maxf(_spray_position - data.recoil_recovery_rate * delta, 0.0)


func _try_fire() -> void:
	if _cooldown > 0.0:
		return
	if not data.automatic and not _trigger_released:
		return
	if magazine <= 0:
		if _trigger_released:
			_play(_handling_audio, data.dry_fire_sound)
			reload()
		_trigger_released = false
		return
	_trigger_released = false
	_cooldown += data.get_shot_interval()
	_fire()


func _fire() -> void:
	magazine -= 1
	var spray_shot := get_spray_shot()
	_shot_audio.play()
	_shoot_bullet(_get_shot_direction())
	_spray_position += 1.0
	_time_since_shot = 0.0
	fired.emit(spray_shot)
	ammo_changed.emit(magazine, reserve)


## The direction this shot travels: your aim, pushed by the spray pattern,
## plus random spread.
func _get_shot_direction() -> Vector3:
	var aim := _wielder.get_aim_angles()
	# Recoil: the pattern says where this shot goes relative to your aim.
	# x is right (a smaller yaw), y is up (a bigger pitch).
	var recoil := data.get_spray_offset(_spray_position)
	var yaw := aim.x - deg_to_rad(recoil.x)
	var pitch := aim.y + deg_to_rad(recoil.y)
	# Random spread: pick a random direction around that point and a random
	# distance up to the inaccuracy. As in CS, the distance is uniform, so
	# most shots land near the middle of the cone.
	var spread_direction := rng.randf() * TAU
	var spread := deg_to_rad(get_inaccuracy()) * rng.randf()
	yaw += cos(spread_direction) * spread
	pitch += sin(spread_direction) * spread
	return _direction_from_angles(yaw, pitch)


## Hitscan: finds the first thing on the bullet's path, instantly (no travel time).
func _shoot_bullet(direction: Vector3) -> void:
	var from := _wielder.get_eye_position()
	var query := PhysicsRayQueryParameters3D.create(
			from, from + direction * data.max_range, PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var hit_position: Vector3 = result.position
	last_hit = {
		"position": hit_position,
		"distance": from.distance_to(hit_position),
		"zone": "",
		"damage": 0.0,
	}
	_spawn_impact(hit_position, result.normal, result.collider)
	hit_landed.emit(last_hit)


## Leaves a bullet hole and sparks, attached to what was hit so it moves along with it.
func _spawn_impact(hit_position: Vector3, normal: Vector3, collider: Object) -> void:
	var impact: Node3D = IMPACT_SCENE.instantiate()
	var parent: Node = collider if collider is Node3D else get_tree().root
	parent.add_child(impact)
	impact.global_position = hit_position + normal * 0.002
	# Point the hole's back (−Z) into the surface so its front faces out.
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	impact.look_at(impact.global_position - normal, up)
	impact.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	impact.reset_physics_interpolation()
	_impacts.append(impact)
	while _impacts.size() > MAX_IMPACTS:
		var oldest: Node3D = _impacts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## Turns a yaw/pitch pair (radians) into a direction. Yaw 0, pitch 0 looks along −Z.
static func _direction_from_angles(yaw: float, pitch: float) -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


func _update_reload(delta: float) -> void:
	var time_left_before := _reload_time_left
	_reload_time_left -= delta
	for step in RELOAD_SOUND_STEPS:
		var step_time_left := data.reload_time * (1.0 - step)
		if time_left_before > step_time_left and _reload_time_left <= step_time_left:
			_play(_handling_audio, data.reload_sound)
	if _reload_time_left <= 0.0:
		_reload_time_left = 0.0
		var loaded := mini(data.magazine_size - magazine, reserve)
		magazine += loaded
		reserve -= loaded
		ammo_changed.emit(magazine, reserve)
		reload_finished.emit()


func _play(audio: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	audio.stream = stream
	audio.play()
