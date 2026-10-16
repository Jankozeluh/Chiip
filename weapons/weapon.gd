class_name Weapon
extends Node3D
## A gun held by the player: firing, ammo and reloading.
##
## All numbers come from [member data]. The holder sets [member trigger_held]
## every physics tick and calls [method reload]. Other nodes (HUD, debug
## overlay) listen to the signals instead of polling.
##
## First person (M6, D-079): the [code]Viewmodel[/code] holds the holder's class arms
## ([method set_arms], a generated [code]<class>_arms.glb[/code]) with [member gun_model] on their
## weapon bone. Their clips play the draw, the shot kick and the reload; sway (the gun lags
## when you turn) and bob (it rocks when you run) are added in code.
##
## Online (M9) the holder's network code can step the weapon itself ([member manual],
## [method step]); a puppet's weapon only shows what the host reports ([member remote]:
## [method play_remote_shot], [method start_remote_reload], [method set_remote_ammo]).

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
## How long the muzzle flash stays visible, in seconds.
const MUZZLE_FLASH_TIME := 0.04
## Sway: how far the first-person gun lags behind the view when you turn, in metres per
## radian per second of turning, at most SWAY_LIMIT, and how fast it catches up (per second).
const SWAY_PER_TURN_SPEED := 0.006
const SWAY_LIMIT := 0.025
const SWAY_RETURN := 12.0
## Bob: how far the first-person gun rocks sideways and dips at full running speed, in metres,
## over one cycle of two steps (Character.STEP_DISTANCE × 2).
const BOB_SIDEWAYS := 0.007
const BOB_DOWN := 0.005
const BOB_CYCLE_DISTANCE := 3.6
## Length of the arms' reload clip in seconds; it is stretched to the weapon's reload time.
const ARMS_RELOAD_CLIP_TIME := 2.5
## Bullet holes kept per weapon; the oldest disappear first.
const MAX_IMPACTS := 100
const IMPACT_SCENE := preload("res://weapons/bullet_impact.tscn")
## A bullet hitting a body, and a head (as recognisable as CS's headshot sound, D-084).
const HIT_BODY_SOUND := preload("res://assets/sounds/hit_body.wav")
const HIT_HEAD_SOUND := preload("res://assets/sounds/hit_head.wav")
## How much louder a headshot sounds than other hits, in dB, and how far it carries (unit size, metres).
const HEADSHOT_VOLUME_DB := 6.0
const HEADSHOT_UNIT_SIZE := 8.0

## The weapon's stats.
@export var data: WeaponData
## The gun model in first person, held on the arms' weapon bone (tools/modelgen/weapons.py).
@export var gun_model: PackedScene
## Where that model's muzzle is, in weapon space: the muzzle flash goes there.
@export var muzzle_point: Vector3 = Vector3(0.0, 0.022, -0.58)

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
## Online (M9, D-103): stepped by the holder's [method Character.step] instead of the engine's
## physics tick.
var manual: bool = false
## Online, on a client (M9, D-104): a puppet's weapon. It fires, reloads and counts ammo only
## as the host reports; on its own it just lets the recoil wear off and plays a reload's sounds.
var remote: bool = false

var _wielder: Character
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
## Seconds the muzzle flash stays visible.
var _flash_time_left: float = 0.0
## The first-person arms (a class's arms model) and their clips, once set.
var _arms: Node3D
var _arms_player: AnimationPlayer
var _arms_meshes: Array[MeshInstance3D] = []
## The team colour of the arms' sleeves.
var _arms_color: Color = Teams.FRIENDLY_COLOR
## Sway offset (x right, y up) and the view angles of the last frame it was measured at.
var _sway: Vector2 = Vector2.ZERO
var _last_view_angles: Vector2 = Vector2.ZERO
var _bob_phase: float = 0.0

@onready var _shot_audio: AudioStreamPlayer = $ShotAudio
@onready var _handling_audio: AudioStreamPlayer = $HandlingAudio
@onready var _shot_audio_3d: AudioStreamPlayer3D = $ShotAudio3D
@onready var _handling_audio_3d: AudioStreamPlayer3D = $HandlingAudio3D
@onready var _viewmodel: Node3D = $Viewmodel
@onready var _muzzle_flash: Node3D = $Viewmodel/MuzzleFlash


func _ready() -> void:
	magazine = data.magazine_size
	reserve = data.reserve_ammo


## Shows or hides the first-person model (gun, muzzle flash, kick). Only whoever looks through
## the holder's eyes sees it; from outside, the holder's body shows its own gun
## ([method Character.set_first_person]).
func set_viewmodel_visible(on: bool) -> void:
	$Viewmodel.visible = on
	# Nobody sees hidden arms, so their clips needn't run (a bot's, until someone spectates it).
	if _arms_player != null:
		_arms_player.active = on


## Puts a class's first-person arms into the viewmodel: [param arms_scene] is a generated
## [code]<class>_arms.glb[/code] and [param material] the class's crew material (the arms share the
## body's texture, see [method CrewBody.material_for]). The gun goes on their weapon bone with the
## muzzle flash at its muzzle, and the arms draw the gun. Calling it again swaps the arms.
func set_arms(arms_scene: PackedScene, material: ShaderMaterial) -> void:
	if _arms != null:
		_muzzle_flash.reparent(_viewmodel, false)
		_viewmodel.remove_child(_arms)
		_arms.queue_free()
	_arms_meshes.clear()
	_arms = arms_scene.instantiate() as Node3D
	_arms.name = "Arms"
	_viewmodel.add_child(_arms)
	for node in _arms.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arms_meshes.append(mesh)
	set_arms_team_color(_arms_color)
	var skeletons := _arms.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty() and gun_model != null:
		var mount := BoneAttachment3D.new()
		mount.name = "Gun"
		mount.bone_name = "weapon"
		(skeletons[0] as Skeleton3D).add_child(mount)
		var gun := gun_model.instantiate()
		mount.add_child(gun)
		for node in gun.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_muzzle_flash.reparent(mount, false)
		_muzzle_flash.position = muzzle_point
	var players := _arms.find_children("*", "AnimationPlayer", true, false)
	_arms_player = players[0] as AnimationPlayer if not players.is_empty() else null
	if _arms_player != null:
		_arms_player.active = _viewmodel.visible
	_play_arms("fp_draw")


## Paints the arms' sleeves in [param color] (the holder's team as the viewer sees it).
func set_arms_team_color(color: Color) -> void:
	_arms_color = color
	for mesh in _arms_meshes:
		mesh.set_instance_shader_parameter("team_color", color)


## Hands the weapon to its holder, who supplies aim and movement state.
func equip(wielder: Character) -> void:
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
	if not _wielder.is_grounded():
		inaccuracy += data.air_inaccuracy
	inaccuracy += minf(_spray_position * data.spray_inaccuracy_per_shot, data.max_spray_inaccuracy)
	return inaccuracy


## The number the next shot would have within the current spray (1 = first shot).
func get_spray_shot() -> int:
	return floori(_spray_position) + 1


## True while a reload is in progress.
func is_reloading() -> bool:
	return _reload_time_left > 0.0


## Full magazine and reserve again, no reload or recoil in progress (on respawn).
func refill() -> void:
	magazine = data.magazine_size
	reserve = data.reserve_ammo
	_reload_time_left = 0.0
	_spray_position = 0.0
	_cooldown = 0.0
	trigger_held = false
	_sway = Vector2.ZERO
	ammo_changed.emit(magazine, reserve)
	reload_finished.emit()
	_play_arms("fp_draw")


## Starts a reload if the magazine isn't full and there are spare rounds.
func reload() -> void:
	if is_reloading() or magazine >= data.magazine_size or reserve <= 0:
		return
	_reload_time_left = data.reload_time
	reload_started.emit()
	_play_arms("fp_reload", ARMS_RELOAD_CLIP_TIME / maxf(data.reload_time, 0.1))


func _physics_process(delta: float) -> void:
	if remote:
		_remote_tick(delta)
	elif not manual:
		step(delta)


## One tick of firing, reloading and recoil: the engine runs it every physics tick, or the
## holder's [method Character.step] runs it once per command online ([member manual]).
func step(delta: float) -> void:
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
	_update_viewmodel(delta)


## Hides the muzzle flash after a moment, and moves the first-person gun: it lags behind the
## view when you turn (sway) and rocks with your steps (bob).
func _update_viewmodel(delta: float) -> void:
	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		_muzzle_flash.visible = _flash_time_left > 0.0
	var view := get_parent() as Node3D
	if view == null or delta <= 0.0:
		return
	var angles := Vector2(view.global_rotation.y, view.global_rotation.x)
	var turn := Vector2(wrapf(angles.x - _last_view_angles.x, -PI, PI), angles.y - _last_view_angles.y) / delta
	_last_view_angles = angles
	var target := (Vector2(turn.x, -turn.y) * SWAY_PER_TURN_SPEED).limit_length(SWAY_LIMIT)
	_sway = _sway.lerp(target, 1.0 - exp(-SWAY_RETURN * delta))
	var bob := Vector2.ZERO
	if _wielder != null and _wielder.is_grounded():
		var speed := Vector2(_wielder.velocity.x, _wielder.velocity.z).length()
		_bob_phase = fmod(_bob_phase + speed * delta * TAU / BOB_CYCLE_DISTANCE, TAU)
		var strength := clampf(speed / maxf(_wielder.get_max_speed(), 0.1), 0.0, 1.0)
		bob = Vector2(sin(_bob_phase) * BOB_SIDEWAYS, -absf(sin(_bob_phase)) * BOB_DOWN) * strength
	var offset := _sway + bob
	_viewmodel.transform = Transform3D(Basis.from_euler(Vector3(_sway.y * 1.5, -_sway.x * 1.5, 0.0)),
			Vector3(offset.x, offset.y, 0.0))


## Muzzle flash and the arms' kick.
func _play_shot_effects() -> void:
	_muzzle_flash.visible = true
	_muzzle_flash.rotation.z = randf() * TAU
	_flash_time_left = MUZZLE_FLASH_TIME
	_play_arms("fp_fire")


## Plays a clip of the first-person arms (from the start, at [param speed]) and goes back to
## idling after it.
func _play_arms(clip: StringName, speed: float = 1.0) -> void:
	if _arms_player == null or not _arms_player.has_animation(clip):
		return
	_arms_player.play(clip, 0.03, speed)
	_arms_player.seek(0.0, true)
	_arms_player.queue(&"fp_idle")


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
			_play(data.dry_fire_sound, true)
			reload()
		_trigger_released = false
		return
	_trigger_released = false
	_cooldown += data.get_shot_interval()
	_fire()


func _fire() -> void:
	magazine -= 1
	var spray_shot := get_spray_shot()
	_play(data.shot_sound, false)
	_play_shot_effects()
	Noises.make_noise(_wielder.get_eye_position(), Noises.GUNSHOT_RANGE, _wielder)
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
	# Online, a player's numbered command rolls its spread from its number, so the shooter's
	# computer and the host roll the same (D-103). Bots and single-player use the generator as is.
	var command_tick := _wielder.get_last_input().tick
	if _wielder.net_id != 0 and command_tick > 0:
		rng.seed = hash([_wielder.net_id, command_tick])
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
	var result: Dictionary
	if _wielder.lag_compensation != null:
		# Online, a friend's shot on the host: against the hit zones where the friend saw them (D-107).
		result = _wielder.lag_compensation.trace(_wielder, from, from + direction * data.max_range, _get_passable_hitbox_rids())
	else:
		var query := PhysicsRayQueryParameters3D.create(
				from, from + direction * data.max_range, PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
		query.collide_with_areas = true
		# The ray starts inside your own head hitbox; never hit yourself.
		query.exclude = _get_passable_hitbox_rids()
		result = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var hit_position: Vector3 = result.position
	var distance := from.distance_to(hit_position)
	var zone := ""
	var damage := 0.0
	if result.collider is Hitbox:
		var hitbox := result.collider as Hitbox
		damage = hitbox.receive_hit(data.damage * _get_damage_falloff(distance), hit_position, _wielder)
		zone = hitbox.get_zone_name()
	last_hit = {
		"position": hit_position,
		"distance": distance,
		"zone": zone,
		"damage": damage,
	}
	# A rewound hit (lag compensation) leaves its hole where that spot of the body is now.
	_spawn_impact(result.get("impact_position", hit_position), result.get("impact_normal", result.normal), result.collider)
	_play_impact_sound(result)
	hit_landed.emit(last_hit)


## Hit zones a bullet passes through: your own, and with friendly fire off also
## those of your living teammates, so a teammate walking through your spray
## doesn't eat your bullets (as in CS). With friendly fire on, teammates get hit.
func _get_passable_hitbox_rids() -> Array[RID]:
	var rids := _wielder.get_hitbox_rids()
	if Teams.friendly_fire:
		return rids
	for other in Character.all_in_world(self):
		if other != _wielder and other.team == _wielder.team and other.is_alive():
			rids.append_array(other.get_hitbox_rids())
	return rids


## How much damage is left after the bullet travels [param distance] metres:
## [member WeaponData.range_modifier] for every 500 units (12.7 m), as in CS.
func _get_damage_falloff(distance: float) -> float:
	return pow(data.range_modifier, distance / Character.UNITS_TO_METRES / 500.0)


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


## The sound of the bullet landing, from where it hit, for everyone nearby: the
## surface it hit (gravel, metal, wood or hard, see [Surfaces]), a thwack on a
## body, a louder "dink" on a head. A weapon without a shot sound (tests) is silent here too.
func _play_impact_sound(hit: Dictionary) -> void:
	if data.shot_sound == null or _impacts.is_empty():
		return
	var audio := _impacts.back().get_node_or_null("Audio") as AudioStreamPlayer3D
	if audio == null:
		return
	var hitbox := hit.collider as Hitbox
	if hitbox != null:
		var head := hitbox.zone == Hitbox.Zone.HEAD
		audio.stream = HIT_HEAD_SOUND if head else HIT_BODY_SOUND
		if head:
			audio.volume_db += HEADSHOT_VOLUME_DB
			audio.unit_size = HEADSHOT_UNIT_SIZE
	else:
		audio.stream = Surfaces.impact_sound(Surfaces.kind_of(hit.collider, hit.shape, hit.normal))
	audio.play()


## Turns a yaw/pitch pair (radians) into a direction. Yaw 0, pitch 0 looks along −Z.
static func _direction_from_angles(yaw: float, pitch: float) -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


# --- Online: a puppet's weapon (M9, D-104) ---


## A puppet's shot, as the host reported it: the sound, the muzzle flash and kick, the recoil
## (for whoever spectates it) and [signal fired] (the body's flash and fire animation). With
## [param hit] true the bullet landed at [param hit_position]: the ray from the holder's eyes is
## traced again here to find what it hit, for the hole and the impact sound. No damage: the
## host decides that.
func play_remote_shot(hit: bool, hit_position: Vector3) -> void:
	if _wielder == null:
		return
	var spray_shot := get_spray_shot()
	_play(data.shot_sound, false)
	_play_shot_effects()
	_spray_position += 1.0
	_time_since_shot = 0.0
	fired.emit(spray_shot)
	if not hit:
		return
	var from := _wielder.get_eye_position()
	var direction := (hit_position - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, hit_position + direction * 0.25, PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
	query.collide_with_areas = true
	query.exclude = _wielder.get_hitbox_rids()
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty() or (result.position as Vector3).distance_to(hit_position) > 1.0:
		# The body it hit has moved on here (it is shown a little in the past): a hole in the air
		# helps nobody, so only the sound plays, from where the bullet landed.
		result = {"position": hit_position, "normal": -direction, "collider": null}
	if result.collider != null:
		_spawn_impact(result.position, result.normal, result.collider)
		_play_impact_sound(result)


## A puppet starts reloading (the host said so): the arms' clip, [signal reload_started] and,
## over the weapon's reload time, the reload sounds. The magazine fills when the host says.
func start_remote_reload() -> void:
	_reload_time_left = data.reload_time
	reload_started.emit()
	_play_arms("fp_reload", ARMS_RELOAD_CLIP_TIME / maxf(data.reload_time, 0.1))


## A puppet's ammo, as the host reported it. Emits [signal ammo_changed] when it changed.
func set_remote_ammo(new_magazine: int, new_reserve: int) -> void:
	if new_magazine == magazine and new_reserve == reserve:
		return
	magazine = new_magazine
	reserve = new_reserve
	ammo_changed.emit(magazine, reserve)


## Online, your own weapon on a client (M9, D-106): the host counted [param magazine_difference]
## and [param reserve_difference] rounds more than this computer predicted for the same command
## (a refill, a shot the host didn't see): adds them.
func correct_ammo(magazine_difference: int, reserve_difference: int) -> void:
	if magazine_difference == 0 and reserve_difference == 0:
		return
	magazine = clampi(magazine + magazine_difference, 0, data.magazine_size)
	reserve = maxi(reserve + reserve_difference, 0)
	ammo_changed.emit(magazine, reserve)


## The seconds of the current reload still to go (0 when not reloading).
func get_reload_time_left() -> float:
	return _reload_time_left


## A puppet weapon's tick: recoil wears off, and a reload plays its sounds and ends on time.
func _remote_tick(delta: float) -> void:
	_time_since_shot += delta
	_recover_recoil(delta)
	if _reload_time_left <= 0.0:
		return
	var time_left_before := _reload_time_left
	_reload_time_left -= delta
	for step_fraction in RELOAD_SOUND_STEPS:
		var step_time_left := data.reload_time * (1.0 - step_fraction)
		if time_left_before > step_time_left and _reload_time_left <= step_time_left:
			_play(data.reload_sound, true)
	if _reload_time_left <= 0.0:
		_reload_time_left = 0.0
		reload_finished.emit()


func _update_reload(delta: float) -> void:
	var time_left_before := _reload_time_left
	_reload_time_left -= delta
	for step in RELOAD_SOUND_STEPS:
		var step_time_left := data.reload_time * (1.0 - step)
		if time_left_before > step_time_left and _reload_time_left <= step_time_left:
			_play(data.reload_sound, true)
	if _reload_time_left <= 0.0:
		_reload_time_left = 0.0
		var loaded := mini(data.magazine_size - magazine, reserve)
		magazine += loaded
		reserve -= loaded
		ammo_changed.emit(magazine, reserve)
		reload_finished.emit()


## Plays a weapon sound. The player hears their own gun without position;
## other characters' guns sound from where they are. [param handling] is for
## clicks and reloads, otherwise it's a shot.
func _play(stream: AudioStream, handling: bool) -> void:
	if stream == null:
		return
	# Changing the stream stops sounds that are still playing (e.g. the previous
	# shot), so only change it when it's a different sound.
	if _wielder == null or _wielder.is_local_player():
		var audio := _handling_audio if handling else _shot_audio
		if audio.stream != stream:
			audio.stream = stream
		audio.play()
	else:
		var audio_3d := _handling_audio_3d if handling else _shot_audio_3d
		if audio_3d.stream != stream:
			audio_3d.stream = stream
		audio_3d.play()
