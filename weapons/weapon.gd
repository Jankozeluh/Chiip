class_name Weapon
extends Node3D
## A gun held by the player: firing, ammo and reloading.
##
## All numbers come from [member data]. The holder sets [member trigger_held]
## every physics tick and calls [method reload]. Other nodes (HUD, debug
## overlay) listen to the signals instead of polling.
##
## Every weapon a character carries is one of these nodes (M7, D-094): the character's [Inventory]
## makes them with [method create] from a [WeaponData] (the generic scene weapons/weapon.tscn),
## keeps the ones it isn't holding hidden and idle ([method holster]), and [method draw]s the one it
## switches to: it can't fire until its draw time has passed.
##
## How each kind works (M7 task 6, D-095): automatic and semi-automatic guns fire hitscan bullets;
## the shotgun fires [member WeaponData.pellets] at once and loads shell by shell (firing stops the
## reload once a shell is in); the sniper rifle's scope steps through its zoom levels with the aim
## button, is accurate only after scoping in and standing still a moment, and drops out after each
## shot until the next one is ready; the knife slashes (fire) and stabs (aim), harder from behind.
## The holder's class can shorten the reload (Rifleman), the scope-in and the scoped recovery
## (Marksman).
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
## Emitted when the scope steps to another zoom level (0 = unscoped).
signal zoom_changed(level: int)
## Emitted when a shotgun starts loading the next shell (after the first: [signal reload_started]).
signal shell_loading
## Emitted when the weapon is taken out (also a grenade after the one before it was thrown).
signal drawn
## Emitted when a reload reaches one of its cues, as its sound plays (M11, D-158): for a magazine
## 0 out, 1 in, 2 the handle; for a shotgun 0, a shell going in ([constant GunModel.MAGAZINE_SOUNDS]).
signal reload_cue(step: int)

## The generic weapon scene [method create] instantiates (loaded when needed: it uses this script).
const SCENE_PATH := "res://weapons/weapon.tscn"

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
## Bullet holes kept per weapon; the oldest disappear first.
const MAX_IMPACTS := 100
const IMPACT_SCENE := preload("res://weapons/bullet_impact.tscn")
## A bullet hitting a body, and a head (as recognisable as CS's headshot sound, D-084).
const HIT_BODY_SOUND := preload("res://assets/sounds/hit_body.wav")
const HIT_HEAD_SOUND := preload("res://assets/sounds/hit_head.wav")
## How much louder a headshot sounds than other hits, in dB, and how far it carries (unit size, metres).
const HEADSHOT_VOLUME_DB := 6.0
const HEADSHOT_UNIT_SIZE := 8.0

## Plays no sounds at all, for every weapon (tests: headless runs have no audio device, and
## sounds that never finish "playing" would be reported as leaks at exit).
static var silent: bool = false

## The weapon's stats.
@export var data: WeaponData
## The gun model in first person, held on the arms' weapon bone (tools/modelgen/weapons.py).
@export var gun_model: PackedScene
## Where that model's muzzle is, in weapon space: the muzzle flash goes there.
@export var muzzle_point: Vector3 = Vector3(0.0, 0.022, -0.58)

## Set by the holder: true while the fire button is held.
var trigger_held: bool = false
## Set by the holder: true while the aim button is held (the scope's steps, the knife's stab).
var aim_held: bool = false
## The scope's zoom step: 0 unscoped, then 1 to the number of [member WeaponData.zoom_levels].
var zoom_level: int = 0
## What the last attack was, for the body's animation: "shot", "slash", "stab", "throw" or "lob".
var last_attack: StringName = &"shot"
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
## physics tick, because its holder is ([member Character.manual]).
var manual: bool:
	get: return _wielder != null and _wielder.manual
## Online, on a client (M9, D-104): a puppet's weapon ([member Character.remote]). It fires,
## reloads and counts ammo only as the host reports; on its own it just lets the recoil wear off
## and plays a reload's sounds.
var remote: bool:
	get: return _wielder != null and _wielder.remote
## A puppet's reload: how long the one being shown lasts, for its sounds.
var _reload_length: float = 0.0

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
## The gun model on the arms, for its magazine and shell during reloads (M11, D-158).
var _gun_parts: GunModel
## The team colour of the arms' sleeves.
var _arms_color: Color = Teams.FRIENDLY_COLOR
## Sway offset (x right, y up) and the view angles of the last frame it was measured at.
var _sway: Vector2 = Vector2.ZERO
var _last_view_angles: Vector2 = Vector2.ZERO
var _bob_phase: float = 0.0
## Seconds until a freshly drawn weapon can fire (see [method draw]).
var _draw_left: float = 0.0
## A grenade's state (D-097): ready, the pin being pulled, or just thrown.
enum GrenadeState { READY, PRIMING, THROWN }
## Seconds the pin takes to pull before a grenade can leave the hand, and the arm's recovery after.
const PIN_TIME := 0.3
const THROW_RECOVERY := 0.45
## Where a throw leaves the hand: this far in front of the eyes (metres, CS: 16 units).
const THROW_START := 0.4

var _grenade_state: GrenadeState = GrenadeState.READY
var _grenade_time: float = 0.0
## The throw will be a lob (the aim button was held, not fire).
var _grenade_lob: bool = false
## Arms handed over before the weapon was ready: [scene, material], put in by _ready.
var _pending_arms: Array = []
## The aim button was held last tick (a scope step or a stab needs a fresh press).
var _aim_was_held: bool = false
## 0 to 1: how far the scope has settled since zooming in (accuracy blends in over the scope-in time).
var _scope_progress: float = 0.0
## The zoom step to go back to once the next shot is ready (after dropping out to fire).
var _rezoom_level: int = 0
## The extra cone from moving, remembered while it wears off (scoped weapons recover over time).
var _move_memory: float = 0.0
## Whoever looks through the holder's eyes wants the viewmodel shown (it hides while scoped).
var _viewmodel_wanted: bool = true
## Seconds until the pump or bolt sound after a shot plays (negative: none waiting).
var _cycle_sound_left: float = -1.0

@onready var _shot_audio: AudioStreamPlayer = $ShotAudio
@onready var _handling_audio: AudioStreamPlayer = $HandlingAudio
@onready var _shot_audio_3d: AudioStreamPlayer3D = $ShotAudio3D
@onready var _handling_audio_3d: AudioStreamPlayer3D = $HandlingAudio3D
@onready var _viewmodel: Node3D = $Viewmodel
@onready var _muzzle_flash: Node3D = $Viewmodel/MuzzleFlash


func _ready() -> void:
	magazine = data.magazine_size
	reserve = data.reserve_ammo
	if not _pending_arms.is_empty():
		set_arms(_pending_arms[0], _pending_arms[1])
		_pending_arms.clear()


## A new weapon node for [param weapon_data]: the generic scene with the weapon's own model and
## muzzle. Its magazine and reserve fill up when it enters the tree.
static func create(weapon_data: WeaponData) -> Weapon:
	var weapon := (load(SCENE_PATH) as PackedScene).instantiate() as Weapon
	weapon.name = String(weapon_data.id).to_pascal_case() if weapon_data.id != &"" else "Weapon"
	weapon.data = weapon_data
	weapon.gun_model = weapon_data.model
	weapon.muzzle_point = weapon_data.muzzle_point
	return weapon


## Takes the weapon out (on a switch): it can't fire or start a reload for [param seconds], and
## the first-person arms play the draw.
func draw(seconds: float) -> void:
	_draw_left = maxf(seconds, 0.0)
	_aim_was_held = aim_held
	_grenade_state = GrenadeState.READY
	_set_gun_visible(true)
	_play_arms("draw", _draw_left)
	drawn.emit()


## Puts the weapon away (on a switch): the trigger is let go and a reload in progress is lost,
## as in CS. Its ammo and recoil stay as they were.
func holster() -> void:
	_cycle_sound_left = -1.0
	# A grenade with its pin pulled goes back in the pocket (it isn't thrown).
	_grenade_state = GrenadeState.READY
	trigger_held = false
	aim_held = false
	_reload_time_left = 0.0
	_draw_left = 0.0
	_rezoom_level = 0
	_set_zoom(0)


## True while the weapon is being drawn and can't fire yet.
func is_drawing() -> bool:
	return _draw_left > 0.0


## Shows or hides the first-person model (gun, muzzle flash, kick). Only whoever looks through
## the holder's eyes sees it; from outside, the holder's body shows its own gun
## ([method Character.set_first_person]).
func set_viewmodel_visible(on: bool) -> void:
	_viewmodel_wanted = on
	# Looking through a scope hides the gun, as in CS.
	on = on and zoom_level == 0
	$Viewmodel.visible = on
	# Nobody sees hidden arms, so their clips needn't run (a bot's, until someone spectates it).
	if _arms_player != null:
		_arms_player.active = on


## Puts a class's first-person arms into the viewmodel: [param arms_scene] is a generated
## [code]<class>_arms.glb[/code] and [param material] the class's crew material (the arms share the
## body's texture, see [method CrewBody.material_for]). The gun goes on their weapon bone with the
## muzzle flash at its muzzle, and the arms draw the gun. Calling it again swaps the arms.
## Everything in the viewmodel gets its viewmodel material ([method Viewmodel.prepare]), so it never
## pokes into walls.
func set_arms(arms_scene: PackedScene, material: ShaderMaterial) -> void:
	if not is_node_ready():
		# Not in the game yet (a character outside the tree got a weapon): put them in on _ready.
		_pending_arms = [arms_scene, material]
		return
	if _arms != null:
		_muzzle_flash.reparent(_viewmodel, false)
		_viewmodel.remove_child(_arms)
		_arms.queue_free()
	_arms_meshes.clear()
	_gun_parts = null
	_arms = arms_scene.instantiate() as Node3D
	var model := gun_model if gun_model != null else (data.model if data != null else null)
	_arms.name = "Arms"
	_viewmodel.add_child(_arms)
	for node in _arms.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		_arms_meshes.append(mesh)
	set_arms_team_color(_arms_color)
	var skeletons := _arms.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty() and model != null:
		var mount := BoneAttachment3D.new()
		mount.name = "Gun"
		mount.bone_name = "weapon"
		(skeletons[0] as Skeleton3D).add_child(mount)
		var gun := GunModel.instantiate(model)
		gun.transform = data.hold_offset if data != null else Transform3D.IDENTITY
		mount.add_child(gun)
		_muzzle_flash.reparent(mount, false)
		_muzzle_flash.position = muzzle_point
		_gun_parts = GunModel.new(gun)
		var skeleton := skeletons[0] as Skeleton3D
		# After the clip has posed the arms (and the gun's mount has followed), the magazine follows the hand.
		skeleton.skeleton_updated.connect(func() -> void:
			if not skeleton.is_inside_tree():
				return
			_gun_parts.update(data, get_reload_progress(),
					skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))))
	# Its own layer in front of the world, with its own field of view (M11, D-155).
	Viewmodel.prepare(_viewmodel)
	var players := _arms.find_children("*", "AnimationPlayer", true, false)
	_arms_player = players[0] as AnimationPlayer if not players.is_empty() else null
	if _arms_player != null:
		_arms_player.active = _viewmodel.visible
	_play_arms("draw")


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
	if _wielder == null or data.is_melee() or data.is_grenade():
		return 0.0
	var inaccuracy := data.crouching_inaccuracy if _wielder.is_crouching else data.standing_inaccuracy
	var moving := _get_moving_inaccuracy()
	if is_scoped():
		# Scoping in blends the cone down to the scoped one; moving costs accuracy that only
		# wears off over the recovery time (faster for the Marksman).
		var scoped := data.scoped_inaccuracy * (2.0 / 3.0 if _wielder.is_crouching else 1.0)
		inaccuracy = lerpf(inaccuracy, scoped, _scope_progress)
		moving = maxf(moving, _move_memory)
	inaccuracy += moving
	if not _wielder.is_grounded():
		inaccuracy += data.air_inaccuracy
	inaccuracy += minf(_spray_position * data.spray_inaccuracy_per_shot, data.max_spray_inaccuracy)
	return inaccuracy


## True while looking through the scope.
func is_scoped() -> bool:
	return zoom_level > 0


## The field of view through the scope, as a fraction of the normal one (1.0 unscoped).
func get_zoom_fraction() -> float:
	if zoom_level <= 0 or zoom_level > data.zoom_levels.size():
		return 1.0
	return data.zoom_levels[zoom_level - 1]


## Seconds a reload takes for this holder (for a shotgun: one shell): the weapon's, 15% shorter
## for the Rifleman's Quick Hands.
func get_reload_time() -> float:
	return data.reload_time * _class_factor(&"reload_time_factor")


## The number the next shot would have within the current spray (1 = first shot).
func get_spray_shot() -> int:
	return floori(_spray_position) + 1


## True while a reload is in progress.
func is_reloading() -> bool:
	return _reload_time_left > 0.0


## How far the current reload is, from 0 to 1: for a shotgun, how far the current shell is (below
## 0 while the gun is still being brought up for the first one). -1 when not reloading. The
## magazine's and the shell's moves and the reload sounds follow it ([GunModel], M11 D-158).
func get_reload_progress() -> float:
	if not is_reloading():
		return -1.0
	var length := get_reload_time()
	if not data.reload_per_shell and remote:
		length = _reload_length
	return 1.0 - _reload_time_left / maxf(length, 0.001)


## Full magazine and reserve again, no reload or recoil in progress (on respawn). A grenade keeps
## its count (its "magazine" is how many you carry).
func refill() -> void:
	if not data.is_grenade():
		magazine = data.magazine_size
		reserve = data.reserve_ammo
	_draw_left = 0.0
	_reload_time_left = 0.0
	_spray_position = 0.0
	_cooldown = 0.0
	trigger_held = false
	_sway = Vector2.ZERO
	ammo_changed.emit(magazine, reserve)
	reload_finished.emit()
	_play_arms("draw")


## Starts a reload if the magazine isn't full and there are spare rounds. A shotgun loads one
## shell at a time after bringing the gun up. Reloading drops out of the scope.
func reload() -> void:
	if is_reloading() or is_drawing() or magazine >= data.magazine_size or reserve <= 0:
		return
	_rezoom_level = 0
	_set_zoom(0)
	if data.reload_per_shell:
		_reload_time_left = data.reload_start_time * _class_factor(&"reload_time_factor") + get_reload_time()
	else:
		_reload_time_left = get_reload_time()
	_play_arms("reload", _reload_time_left)
	reload_started.emit()


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
	if _cycle_sound_left >= 0.0:
		_cycle_sound_left -= delta
		if _cycle_sound_left < 0.0:
			_play(data.cycle_sound, true)
	var aim_pressed := aim_held and not _aim_was_held
	_aim_was_held = aim_held
	_update_scope(delta, aim_pressed)
	if _draw_left > 0.0:
		_draw_left = maxf(_draw_left - delta, 0.0)
		if not trigger_held:
			_trigger_released = true
		_recover_recoil(delta)
		_cooldown = maxf(_cooldown, 0.0)
		return
	if data.is_melee():
		_update_melee(aim_pressed)
		_cooldown = maxf(_cooldown, 0.0)
		return
	if data.is_grenade():
		_update_grenade(delta)
		return
	if is_reloading() and data.reload_per_shell and trigger_held and magazine > 0 and _trigger_released:
		# Firing stops a shotgun's reload once a shell is in (CS).
		_reload_time_left = 0.0
		reload_finished.emit()
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
	_play_arms("fire")


## Plays the first-person arms' clip for [param action] ("draw", "fire", "reload", "slash"...)
## from the start, stretched to last [param duration] seconds (0: its own length), then goes back
## to idling. Each animation set has its own clips, [code]fp_<set>_<action>[/code]; the rifle's
## are [code]fp_<action>[/code], also the fallback (D-096).
func _play_arms(action: String, duration: float = 0.0) -> void:
	if _arms_player == null:
		return
	var set_name := data.get_anim_set() if data != null else &"rifle"
	var clip := StringName("fp_%s_%s" % [set_name, action])
	if set_name == &"rifle" or not _arms_player.has_animation(clip):
		clip = StringName("fp_" + action)
	if not _arms_player.has_animation(clip):
		return
	var length := _arms_player.get_animation(clip).length
	var speed := length / duration if duration > 0.0 else 1.0
	_arms_player.play(clip, 0.03, speed)
	_arms_player.seek(0.0, true)
	var idle := StringName("fp_%s_idle" % set_name)
	_arms_player.queue(idle if set_name != &"rifle" and _arms_player.has_animation(idle) else &"fp_idle")


## Lets the spray pattern wear off once you stop firing. While firing
## continuously the gap between shots stays below 1.5 shot intervals, so a
## full-auto spray follows the pattern exactly.
func _recover_recoil(delta: float) -> void:
	if _time_since_shot > data.get_shot_interval() * 1.5:
		_spray_position = maxf(_spray_position - data.recoil_recovery_rate * delta, 0.0)


func _try_fire() -> void:
	if _cooldown > 0.0:
		return
	if data.is_melee() or data.is_grenade():
		return  # The knife and grenades attack their own way (M7 tasks 6 and 8).
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
	last_attack = &"shot"
	_play(data.shot_sound, false)
	if data.cycle_sound != null and magazine > 0:
		_cycle_sound_left = data.cycle_sound_delay
	_play_shot_effects()
	Noises.make_noise(_wielder.get_eye_position(), Noises.GUNSHOT_RANGE, _wielder)
	# Online, a player's numbered command rolls the shot's spread (every pellet's) from its number,
	# so the shooter's computer and the host roll the same (D-103). Bots and single-player use the
	# generator as it is.
	var command_tick := _wielder.get_last_input().tick
	if _wielder.net_id != 0 and command_tick > 0:
		rng.seed = hash([_wielder.net_id, command_tick])
	for pellet in maxi(data.pellets, 1):
		var direction := _get_shot_direction()
		if data.pellets > 1:
			direction = _spread(direction, data.pellet_spread)
		_shoot_bullet(direction)
	if is_scoped() and data.unscope_after_shot:
		# Out of the scope after the shot, back in once the next one is ready (CS's AWP).
		_rezoom_level = zoom_level
		_set_zoom(0)
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


## [param direction] pushed a random amount within a cone of [param degrees] (uniform over the
## cone's disk, so a shotgun's pellets fill it evenly).
func _spread(direction: Vector3, degrees: float) -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(direction).normalized()
	var angle := rng.randf() * TAU
	var radius := tan(deg_to_rad(degrees)) * sqrt(rng.randf())
	return (direction + (side * cos(angle) + up * sin(angle)) * radius).normalized()


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
		damage = hitbox.receive_hit(data.damage * _get_damage_falloff(distance), hit_position, _wielder, data)
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
	if silent or data.shot_sound == null or _impacts.is_empty():
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
	if data.reload_per_shell:
		_reload_time_left = data.reload_start_time * _class_factor(&"reload_time_factor") + get_reload_time()
	else:
		_reload_time_left = get_reload_time()
	_reload_length = _reload_time_left
	_play_arms("reload", _reload_time_left)
	reload_started.emit()


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
	var before := get_reload_progress()
	_reload_time_left -= delta
	_play_reload_cues(before, get_reload_progress() if _reload_time_left > 0.0 else 1.0)
	if _reload_time_left <= 0.0:
		_reload_time_left = 0.0
		reload_finished.emit()


func _update_reload(delta: float) -> void:
	if data.reload_per_shell:
		_update_shell_reload(delta)
		return
	var before := get_reload_progress()
	_reload_time_left -= delta
	_play_reload_cues(before, get_reload_progress() if _reload_time_left > 0.0 else 1.0)
	if _reload_time_left <= 0.0:
		_reload_time_left = 0.0
		var loaded := mini(data.magazine_size - magazine, reserve)
		magazine += loaded
		reserve -= loaded
		ammo_changed.emit(magazine, reserve)
		reload_finished.emit()


## Plays the reload sound for every cue the reload passed between progress [param before] and
## [param after] ([method get_reload_progress]), and emits [signal reload_cue].
func _play_reload_cues(before: float, after: float) -> void:
	var cues := GunModel.SHELL_SOUNDS if data.reload_per_shell else GunModel.MAGAZINE_SOUNDS
	for step in cues.size():
		if before < cues[step] and after >= cues[step]:
			_play(data.reload_sound, true)
			reload_cue.emit(step)


## A shotgun's reload: a shell goes in every reload time until the magazine is full or the
## reserve is empty. Its sound plays as the hand pushes it in; it counts at the end of its time.
func _update_shell_reload(delta: float) -> void:
	var before := get_reload_progress()
	_reload_time_left -= delta
	_play_reload_cues(before, get_reload_progress() if _reload_time_left > 0.0 else 1.0)
	if _reload_time_left > 0.0:
		return
	magazine += 1
	reserve -= 1
	ammo_changed.emit(magazine, reserve)
	if magazine < data.magazine_size and reserve > 0:
		_reload_time_left = get_reload_time()
		_play_arms("reload_shell", _reload_time_left)
		shell_loading.emit()
	else:
		_reload_time_left = 0.0
		reload_finished.emit()


# --- The scope (D-095) ---


## Steps the scope with a fresh press of aim, settles it, brings it back after a shot, and keeps
## the memory of moving that a scoped shot pays for.
func _update_scope(delta: float, aim_pressed: bool) -> void:
	if not data.has_scope():
		return
	var recovery := data.scoped_recovery_time / maxf(_class_factor(&"scoped_recovery_factor"), 0.01)
	_move_memory = maxf(_get_moving_inaccuracy(), _move_memory - data.moving_inaccuracy * delta / maxf(recovery, 0.01))
	if aim_pressed and _draw_left <= 0.0 and not is_reloading():
		_rezoom_level = 0
		_set_zoom((zoom_level + 1) % (data.zoom_levels.size() + 1))
	elif _rezoom_level > 0 and _cooldown <= 0.0 and not is_reloading() and magazine > 0:
		_set_zoom(_rezoom_level)
		_rezoom_level = 0
	if zoom_level > 0:
		var scope_in := data.scope_in_time * _class_factor(&"scope_in_time_factor")
		_scope_progress = minf(_scope_progress + delta / maxf(scope_in, 0.001), 1.0)


## Goes to zoom step [param level] (0 = out of the scope). Zooming in from out starts settling
## the scope again.
func _set_zoom(level: int) -> void:
	if level == zoom_level:
		return
	if zoom_level == 0 or level == 0:
		_scope_progress = 0.0
	zoom_level = level
	set_viewmodel_visible(_viewmodel_wanted)
	zoom_changed.emit(level)


## The extra cone from moving right now: nothing below 34% of top speed, the full
## [member WeaponData.moving_inaccuracy] at top speed.
func _get_moving_inaccuracy() -> float:
	if _wielder == null:
		return 0.0
	var top_speed := _wielder.get_max_speed()
	var speed := Vector2(_wielder.velocity.x, _wielder.velocity.z).length()
	var move_fraction := clampf(inverse_lerp(top_speed * ACCURATE_SPEED_FRACTION, top_speed, speed), 0.0, 1.0)
	return data.moving_inaccuracy * move_fraction


## A factor of the holder's class (1.0 without one): see [ClassData]'s perk values.
func _class_factor(factor: StringName) -> float:
	if _wielder == null or _wielder.class_data == null:
		return 1.0
	return float(_wielder.class_data.get(factor))


# --- Grenades (D-097) ---


## Fire or aim pulls the pin; letting go when it's out throws (fire) or lobs (aim). Then the arm
## recovers, and the next grenade of the kind comes out, or the weapon held before.
func _update_grenade(delta: float) -> void:
	match _grenade_state:
		GrenadeState.READY:
			if (trigger_held or aim_held) and magazine > 0:
				_grenade_state = GrenadeState.PRIMING
				_grenade_time = PIN_TIME
				_grenade_lob = aim_held and not trigger_held
				_play(data.pin_sound, true)
				_play_arms("pull")
		GrenadeState.PRIMING:
			_grenade_time -= delta
			if trigger_held or aim_held:
				_grenade_lob = aim_held and not trigger_held
			elif _grenade_time <= 0.0:
				_throw()
		GrenadeState.THROWN:
			_grenade_time -= delta
			if _grenade_time <= 0.0:
				_grenade_state = GrenadeState.READY
				if magazine <= 0:
					# The last of the kind: it leaves the inventory, the weapon held before comes out.
					_wielder.inventory.remove.call_deferred(self, true)
				else:
					draw(_wielder.inventory.get_draw_time(data))


## The grenade leaves the hand: a [Grenade] flies from in front of the eyes (never through a wall
## right there), at the throw or lob speed, plus the thrower's own movement.
func _throw() -> void:
	var aim := _wielder.get_aim_angles()
	var look := _direction_from_angles(aim.x, aim.y)
	var eye := _wielder.get_eye_position()
	var from := eye + look * THROW_START
	var query := PhysicsRayQueryParameters3D.create(eye, from, PhysicsLayers.WORLD)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		from = wall.position - look * 0.1
	var speed := data.lob_speed if _grenade_lob else data.throw_speed
	# Online, on a client, the host throws the real one (M9, D-113); your hands still throw here.
	if not _wielder.replica:
		Grenade.throw(_wielder.get_parent(), data, from, Grenade.throw_velocity(aim, speed, _wielder.velocity), _wielder)
	magazine -= 1
	last_attack = &"lob" if _grenade_lob else &"throw"
	_play(data.shot_sound, true)
	_play_arms("lob" if _grenade_lob else "throw")
	_set_gun_visible(false)
	_grenade_state = GrenadeState.THROWN
	_grenade_time = THROW_RECOVERY
	fired.emit(1)
	ammo_changed.emit(magazine, reserve)
	if _wielder.inventory != null:
		_wielder.inventory.changed.emit()


## True while a grenade's pin is being pulled or held, ready to throw.
func is_priming() -> bool:
	return _grenade_state == GrenadeState.PRIMING


## Shows or hides the gun in the first-person hands (a thrown grenade is gone until the next).
func _set_gun_visible(on: bool) -> void:
	if _arms == null:
		return
	var mount := _arms.find_child("Gun", true, false) as Node3D
	if mount != null:
		var model := mount.get_child(0) as Node3D
		if model != null and model != _muzzle_flash:
			model.visible = on


# --- The knife (D-095) ---


## Slashes while fire is held, stabs while aim is held, when the last attack has recovered.
func _update_melee(_aim_pressed: bool) -> void:
	if _cooldown > 0.0:
		return
	if trigger_held:
		_melee(false)
	elif aim_held:
		_melee(true)


## One knife attack: a short trace from the eyes (a small fan of rays, so it forgives a little),
## flat damage on whatever zone it finds (the knife ignores hit-zone multipliers, as in CS),
## more from behind.
func _melee(stab: bool) -> void:
	var reach := data.stab_range if stab else data.melee_range
	_cooldown = data.stab_interval if stab else data.get_shot_interval()
	_time_since_shot = 0.0
	_play(data.shot_sound, false)
	_play_arms("stab" if stab else "slash")
	last_attack = &"stab" if stab else &"slash"
	fired.emit(1)
	var result := _melee_trace(reach)
	if result.is_empty():
		return
	var hit_position: Vector3 = result.position
	var zone := ""
	var damage := 0.0
	if result.collider is Hitbox:
		var hitbox := result.collider as Hitbox
		var victim := _owner_of(hitbox)
		var behind := victim != null and _is_behind(victim)
		if stab:
			damage = data.stab_backstab_damage if behind else data.stab_damage
		else:
			damage = data.backstab_damage if behind else data.damage
		hitbox.receive_hit(damage / Hitbox.MULTIPLIERS[hitbox.zone], hit_position, _wielder, data)
		zone = hitbox.get_zone_name()
		_play(data.hit_sound, true)
	else:
		_spawn_impact(hit_position, result.normal, result.collider)
		_play_impact_sound(result)
	last_hit = {"position": hit_position, "distance": _wielder.get_eye_position().distance_to(hit_position),
			"zone": zone, "damage": damage}
	hit_landed.emit(last_hit)


## The first thing a knife reaches within [param reach] metres: straight ahead first, then a few
## rays 3 degrees around it. A hit zone wins over a wall further out on another ray.
func _melee_trace(reach: float) -> Dictionary:
	var aim := _wielder.get_aim_angles()
	var from := _wielder.get_eye_position()
	var exclude := _get_passable_hitbox_rids()
	var space := get_world_3d().direct_space_state
	var first_wall: Dictionary = {}
	for offset: Vector2 in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		var direction := _direction_from_angles(aim.x + deg_to_rad(offset.x), aim.y + deg_to_rad(offset.y))
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach, PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
		query.collide_with_areas = true
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		if hit.collider is Hitbox:
			return hit
		if first_wall.is_empty():
			first_wall = hit
	return first_wall


## The character a hit zone belongs to, or null (a target dummy).
func _owner_of(hitbox: Hitbox) -> Character:
	var node: Node = hitbox
	while node != null and not node is Character:
		node = node.get_parent()
	return node as Character


## True when the holder is behind [param victim]: the victim faces away from them (CS's backstab).
func _is_behind(victim: Character) -> bool:
	var to_victim := victim.global_position - _wielder.global_position
	to_victim.y = 0.0
	if to_victim.length_squared() < 0.0001:
		return false
	var facing := -victim.global_basis.z
	facing.y = 0.0
	return facing.normalized().dot(to_victim.normalized()) > 0.5


## Plays a weapon sound. The player hears their own gun without position;
## other characters' guns sound from where they are. [param handling] is for
## clicks and reloads, otherwise it's a shot.
func _play(stream: AudioStream, handling: bool) -> void:
	if stream == null or silent:
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
