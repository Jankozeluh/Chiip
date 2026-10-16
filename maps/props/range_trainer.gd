class_name RangeTrainer
extends Node3D
## The aim trainer of the Shooting Range (M14, D-205 to D-207): a gold pad on the wall that starts
## a timed run of flick targets when you shoot it (the range_trainer entity; the console's `aim`
## command does the same).
##
## A run: three seconds of countdown, then [member run_time] seconds in which **one lime ball at a
## time** pops up at a random spot in front of you, at the gun you hold: [member min_distance] to
## [member max_distance] metres away, up to [member half_angle]° to each side of where you looked when
## you started, between [member min_height] and [member max_height] above the floor, always at least
## [member min_flick]° from the last one and in plain view (a spot a wall or a dummy hides is
## skipped, and a ball something walks in front of moves to another spot). Every ball is the same size on your screen ([member target_degrees]). A ball lives
## [member target_lifetime] seconds; hit it for points (the quicker the better), let it time out
## for nothing; every shot that hits no ball costs points ([AimScore]). When the time is up the
## score, hits, accuracy and average reaction are shown, and a better score than your best for that
## gun is saved in your stats ([StatsBook.submit_best], key `aim_flick_<gun>`, shown in Stats ›
## Training). Shooting the pad during a run stops it without a score. A run needs a gun in hand.
##
## It follows the shooter ([signal Hitbox.hit]'s attacker) and counts their [signal Weapon.fired]
## shots while the run is on. The live readout is a pixel-font [Label3D] on the shooter's camera,
## which the world's low-resolution view draws like the damage numbers over the dummies.

## Emitted when a run starts counting (after the countdown); [param weapon_id] is the gun in hand.
signal run_started(weapon_id: StringName)
## Emitted when a run is over: its [param result] and whether it is a new personal best.
signal run_finished(result: AimScore, new_best: bool)
## Emitted when the state changes.
signal state_changed(state: State)

## What the trainer is doing.
enum State { IDLE, COUNTDOWN, RUNNING, RESULT }

const PIXEL_FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
## The pad's colour (the range's gold, like the gun stands' rings).
const PAD_COLOR := Color(1.0, 0.62, 0.15)
## Stats key prefix of a personal best; the gun's id follows.
const BEST_PREFIX := "aim_flick_"
## Tries at finding a spot in plain view before the target waits a moment.
const SPOT_TRIES := 40
## The run length the plain best key stands for, in seconds.
const DEFAULT_SECONDS := 30.0

## Seconds a run lasts (after the countdown).
@export var run_time: float = 30.0
## Seconds of "3, 2, 1" before a run starts.
@export var countdown_time: float = 3.0
## Seconds a ball stays up if nobody hits it.
@export var target_lifetime: float = 1.5
## Seconds between a ball going and the next one appearing.
@export var target_gap: float = 0.12
## The nearest and farthest a ball appears from your eyes, in metres.
@export var min_distance: float = 7.0
@export var max_distance: float = 20.0
## How far to each side of your starting view a ball can appear, in degrees.
@export var half_angle: float = 45.0
## The lowest and highest a ball appears above the floor under you, in metres.
@export var min_height: float = 0.6
@export var max_height: float = 2.3
## The least angle between one ball and the next one, in degrees, so every one is a flick.
@export var min_flick: float = 12.0
## How big a ball looks on your screen, as an angle across, in degrees.
@export var target_degrees: float = 3.2
## Seconds the result stays up.
@export var result_time: float = 8.0

## Where a personal best is saved: the shared book when empty (a test gives its own).
var book: StatsBook
## The generator of the spots; seed it for repeatable tests.
var rng := RandomNumberGenerator.new()

var _state: State = State.IDLE
var _clock: float = 0.0
var _trainee: Character
var _weapon: Weapon
var _weapon_id: StringName = &""
var _score: AimScore
var _target: AimTarget
var _gap_left: float = 0.0
var _last_direction: Vector3 = Vector3.ZERO
var _origin_eye: Vector3 = Vector3.ZERO
var _origin_yaw: float = 0.0
var _origin_floor: float = 0.0
var _notice: String = ""
## How long the run now lasts, and the length the player chose in the start panel (0: the entity's [member run_time]).
var _run_seconds: float = 0.0
var _chosen_seconds: float = 0.0
var _readout: Label3D
var _pad_label: Label3D
var _pad: Hitbox


## Takes the values of a range_trainer entity placed in TrenchBroom (D-207): the run time, a
## ball's life and how far away the balls appear.
func _func_godot_apply_properties(properties: Dictionary) -> void:
	run_time = float(properties.get("run_time", run_time))
	target_lifetime = float(properties.get("target_lifetime", target_lifetime))
	min_distance = float(properties.get("min_distance", min_distance))
	max_distance = float(properties.get("max_distance", max_distance))
	half_angle = float(properties.get("half_angle", half_angle))


func _ready() -> void:
	rng.randomize()
	_build_pad()
	_update_pad_label()


func _exit_tree() -> void:
	_forget_readout()
	if TrainingHub.trainer == self:
		TrainingHub.trainer = null


func _physics_process(delta: float) -> void:
	match _state:
		State.COUNTDOWN:
			_clock -= delta
			_show_readout("%d" % ceili(maxf(_clock, 0.0)), 48)
			if _clock <= 0.0:
				_begin_run()
		State.RUNNING:
			_run_tick(delta)
		State.RESULT:
			_clock -= delta
			if _clock <= 0.0:
				_set_state(State.IDLE)
				_forget_readout()
				_update_pad_label()
		State.IDLE:
			pass


## The state of the trainer.
func get_state() -> State:
	return _state


## Seconds left: of the countdown, of the run or of the result's time on screen.
func get_time_left() -> float:
	return maxf(_clock, 0.0)


## The tally of the run going on or of the last one (null before the first).
func get_score() -> AimScore:
	return _score


## The ball up now, or null.
func get_target() -> AimTarget:
	return _target


## The weapon the run was started with (its best is the one that can change).
func get_weapon_id() -> StringName:
	return _weapon_id


## What the pad last told the player ("Take a gun first", the result...), empty when nothing.
func get_notice() -> String:
	return _notice


## The pad's hit zone: what a bullet must hit to start or stop a run.
func get_pad() -> Hitbox:
	return _pad


## The text on the shooter's screen now (the countdown, the run's time and score, the result), or empty.
func get_readout() -> String:
	return _readout.text if _readout != null else ""


## The key of the personal best for [param weapon_id] in the stats file. A run of a length chosen in the start panel
## ([param seconds], not the 30 of the entity) keeps its best apart: `aim_flick_rifle_60`.
static func best_key(weapon_id: StringName, seconds: float = 0.0) -> String:
	var key := BEST_PREFIX + String(weapon_id)
	return key if seconds <= 0.0 or is_equal_approx(seconds, DEFAULT_SECONDS) else "%s_%d" % [key, roundi(seconds)]


## True while the countdown or a run is on.
func is_active() -> bool:
	return _state == State.COUNTDOWN or _state == State.RUNNING


## How many seconds the run now on (or the last one) lasts.
func get_run_seconds() -> float:
	return _run_seconds if _run_seconds > 0.0 else run_time


## Starts a run for [param character] (what shooting the pad does): the countdown first. A run
## needs a gun in hand: without one it says so and nothing starts. Returns whether it started.
func start(character: Character, seconds: float = 0.0) -> bool:
	if _state == State.COUNTDOWN or _state == State.RUNNING:
		return false
	_chosen_seconds = seconds
	_run_seconds = seconds if seconds > 0.0 else run_time
	var weapon := character.weapon
	if weapon == null or weapon.data == null or weapon.data.category == WeaponData.Category.KNIFE \
			or weapon.data.category == WeaponData.Category.GRENADE:
		_notice = "Take a gun first"
		_update_pad_label()
		return false
	_forget_readout()
	_trainee = character
	_weapon_id = weapon.data.id
	_score = AimScore.new()
	_last_direction = Vector3.ZERO
	_notice = ""
	_clock = countdown_time
	_follow_weapon(true)
	_make_readout(character)
	_set_state(State.COUNTDOWN)
	_update_pad_label()
	return true


## Stops the run (or the countdown) without a score. Does nothing when nothing is on.
func stop() -> void:
	if _state != State.COUNTDOWN and _state != State.RUNNING:
		return
	_clear_target()
	_follow_weapon(false)
	_forget_readout()
	_set_state(State.IDLE)
	_update_pad_label()


# --- The run ---


func _begin_run() -> void:
	# The balls come around where the shooter looks now, after the countdown (they will have turned
	# from the pad back to the range), not where they looked when they shot the pad.
	if _trainee != null and is_instance_valid(_trainee):
		_origin_eye = _trainee.get_eye_position()
		_origin_yaw = _trainee.get_aim_angles().x
		_origin_floor = _trainee.global_position.y
	_clock = get_run_seconds()
	_gap_left = 0.0
	_set_state(State.RUNNING)
	run_started.emit(_weapon_id)


func _run_tick(delta: float) -> void:
	_clock -= delta
	if _target != null:
		if _target.age >= target_lifetime:
			_score.add_expired()
			_remove_target(false)
			_gap_left = target_gap
		elif not _target_in_view():
			# Something walked in front of it (the range's moving dummy, say): it moves to a spot you can see.
			_remove_target(false)
			_gap_left = 0.0
	elif _gap_left > 0.0:
		_gap_left -= delta
	else:
		_spawn_target()
		if _target == null:
			# Nowhere in plain view right now: look again in a moment.
			_gap_left = 0.25
	_show_readout("%4.1f s   %d pts" % [maxf(_clock, 0.0), _score.score()], 20)
	if _clock <= 0.0:
		_finish()


## The run is over: the result, a new best if there is one, and the result on screen.
func _finish() -> void:
	_clear_target()
	_follow_weapon(false)
	var new_best := false
	if _score.hits > 0:
		new_best = _book().submit_best(best_key(_weapon_id, _chosen_seconds), float(_score.score()), _score.details())
	_clock = result_time
	_set_state(State.RESULT)
	var lines := PackedStringArray([
		"SCORE %d%s" % [_score.score(), "  NEW BEST!" if new_best else ""],
		"HITS %d   MISSES %d   EXPIRED %d" % [_score.hits, _score.misses(), _score.expired],
		"ACCURACY %d %%   REACTION %d MS" % [roundi(_score.accuracy() * 100.0), roundi(_score.average_reaction() * 1000.0)],
	])
	_show_readout("\n".join(lines))
	_update_pad_label()
	run_finished.emit(_score, new_best)


## Puts a ball at a random spot in plain view; none if no spot was found.
func _spawn_target() -> void:
	if _trainee == null or not is_instance_valid(_trainee):
		stop()
		return
	var eye := _trainee.get_eye_position()
	var spot := _pick_spot(eye)
	if spot == Vector3.INF:
		return
	var distance := eye.distance_to(spot)
	_target = AimTarget.new()
	_target.name = "AimTarget"
	add_child(_target)
	_target.setup(distance * tan(deg_to_rad(target_degrees * 0.5)))
	_target.global_position = spot
	_target.shot.connect(_on_target_shot)
	_target.pop()
	_last_direction = (spot - _origin_eye).normalized()


## A random spot for the next ball, or Vector3.INF. [param eye] is where the shooter's eyes are now:
## the spot must be in plain view from there.
func _pick_spot(eye: Vector3) -> Vector3:
	var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, _origin_yaw)
	var space := get_world_3d().direct_space_state
	var exclude := _trainee.get_hitbox_rids()
	for attempt in SPOT_TRIES:
		var turn := deg_to_rad(rng.randf_range(-half_angle, half_angle))
		var distance := rng.randf_range(min_distance, max_distance)
		var height := rng.randf_range(min_height, max_height)
		var floor_point := Vector3(_origin_eye.x, _origin_floor, _origin_eye.z)
		var spot := floor_point + forward.rotated(Vector3.UP, turn) * distance + Vector3.UP * height
		if _last_direction != Vector3.ZERO and rad_to_deg((spot - _origin_eye).angle_to(_last_direction)) < min_flick:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, spot, PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
		query.collide_with_areas = true
		query.exclude = exclude
		if space.intersect_ray(query).is_empty():
			return spot
	return Vector3.INF


## True while nothing stands between the shooter's eyes and the ball (the ray stops at the ball's own surface).
func _target_in_view() -> bool:
	if _trainee == null or not is_instance_valid(_trainee):
		return true
	var eye := _trainee.get_eye_position()
	var to_ball := _target.global_position - eye
	var query := PhysicsRayQueryParameters3D.create(eye, _target.global_position - to_ball.normalized() * (_target.radius + 0.02),
			PhysicsLayers.WORLD | PhysicsLayers.HITBOXES)
	query.collide_with_areas = true
	query.exclude = _trainee.get_hitbox_rids()
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_target_shot(attacker: Node) -> void:
	if _state != State.RUNNING or _target == null or attacker != _trainee:
		return
	_score.add_hit(_target.age, target_lifetime)
	_remove_target(true)
	_gap_left = target_gap


## Takes the ball away; [param was_hit] makes it burst instead of just going.
func _remove_target(was_hit: bool) -> void:
	if _target == null:
		return
	if was_hit:
		_target.burst()
	else:
		_target.queue_free()
	_target = null


func _clear_target() -> void:
	if _target != null:
		_target.queue_free()
		_target = null


# --- Counting shots ---


## Starts or stops counting the shooter's shots (and follows their weapon changes).
func _follow_weapon(on: bool) -> void:
	if _trainee == null or not is_instance_valid(_trainee):
		return
	if on:
		if not _trainee.weapon_changed.is_connected(_on_weapon_changed):
			_trainee.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(_trainee.weapon)
		return
	if _trainee.weapon_changed.is_connected(_on_weapon_changed):
		_trainee.weapon_changed.disconnect(_on_weapon_changed)
	_on_weapon_changed(null)


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and is_instance_valid(_weapon) and _weapon.fired.is_connected(_on_fired):
		_weapon.fired.disconnect(_on_fired)
	_weapon = weapon
	if weapon != null:
		weapon.fired.connect(_on_fired)


## A shot of the shooter's: counted only while the run is on (the shot that starts it, or one in the
## countdown, doesn't count).
func _on_fired(_spray_shot: int) -> void:
	if _state == State.RUNNING:
		_score.add_shots(1)


# --- The pad and the readout ---


func _build_pad() -> void:
	var coin := MeshInstance3D.new()
	coin.name = "Coin"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.16
	mesh.height = 0.05
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = PAD_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	coin.mesh = mesh
	# The coin's flat side faces along the entity's angle (the cylinder stands on its end).
	coin.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coin)
	_pad = Hitbox.new()
	_pad.name = "Pad"
	_pad.zone = Hitbox.Zone.CHEST
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.22
	cylinder.height = 0.08
	shape.shape = cylinder
	shape.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_pad.add_child(shape)
	add_child(_pad)
	_pad.hit.connect(_on_pad_hit)
	_pad_label = Label3D.new()
	_pad_label.name = "Label"
	# The same look as the dummies' labels: a fixed size on the screen, so it reads from anywhere.
	_pad_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pad_label.font = PIXEL_FONT
	_pad_label.font_size = 8
	_pad_label.pixel_size = 1.0 / 240.0
	_pad_label.fixed_size = true
	_pad_label.outline_size = 2
	_pad_label.outline_modulate = Color(0.08, 0.08, 0.08)
	_pad_label.modulate = Color(0.92, 0.9, 0.82)
	_pad_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_pad_label.position = Vector3(0.0, 0.3, 0.0)
	_pad_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_pad_label)


func _on_pad_hit(_damage: float, _zone: Hitbox.Zone, _position: Vector3, attacker: Node, _penetration: float, _source: WeaponData) -> void:
	var shooter := attacker as Character
	# Only the person at this computer starts it, not a bot whose bullet strays.
	if shooter == null or not shooter.is_local_player():
		return
	if _state == State.COUNTDOWN or _state == State.RUNNING:
		stop()
	elif not TrainingHub.request_start(self, shooter):
		start(shooter)


## What the pad says: how to start, the notice, and the best score with the gun in hand.
func _update_pad_label() -> void:
	if _pad_label == null:
		return
	var lines := PackedStringArray(["AIM TRAINER"])
	match _state:
		State.COUNTDOWN, State.RUNNING:
			lines.append("SHOOT TO STOP")
		_:
			lines.append("SHOOT TO START · %d S" % roundi(run_time))
			if _notice != "":
				lines.append(_notice.to_upper())
			elif _weapon_id != &"":
				var best := _book().get_best_score(best_key(_weapon_id))
				if best > 0.0:
					lines.append("BEST %d (%s)" % [roundi(best), StatsMenu.weapon_name(String(_weapon_id)).to_upper()])
	_pad_label.text = "\n".join(lines)


func _make_readout(character: Character) -> void:
	var camera := character.get_camera()
	# With the game's 2D screens (TrainingHud) the numbers are on the HUD, not in the world.
	if camera == null or TrainingHub.hud_active:
		return
	_readout = Label3D.new()
	_readout.name = "AimReadout"
	_readout.font = PIXEL_FONT
	_readout.font_size = 16
	# Fixed size: 1/240 of the screen's height per font pixel, so it is the same everywhere.
	_readout.fixed_size = true
	_readout.pixel_size = 1.0 / 240.0
	_readout.outline_size = 4
	_readout.outline_modulate = Color(0.08, 0.08, 0.08)
	_readout.modulate = AimTarget.COLOR
	_readout.no_depth_test = true
	_readout.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_readout.position = Vector3(0.0, 0.42, -1.0)
	_readout.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.add_child(_readout)


func _show_readout(text: String, size: int = 16) -> void:
	if _readout != null:
		_readout.text = text
		_readout.font_size = size


func _forget_readout() -> void:
	if _readout != null and is_instance_valid(_readout):
		_readout.queue_free()
	_readout = null


func _set_state(state: State) -> void:
	_state = state
	if state == State.IDLE:
		if TrainingHub.trainer == self:
			TrainingHub.trainer = null
	else:
		TrainingHub.trainer = self
	state_changed.emit(state)


func _book() -> StatsBook:
	return book if book != null else StatsBook.get_instance()


## The book the bests are kept in (the shared one unless a test gave another).
func get_book() -> StatsBook:
	return _book()
