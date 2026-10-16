class_name Killcam
extends Node3D
## The killcam (M17, D-241): after you die in Team Deathmatch or free-for-all, the last few seconds
## before the kill play again through your killer's eyes, like Call of Duty's.
##
## [constant BEAT] seconds after the death (you see yourself fall first) it plays the
## [KillcamRecorder]'s notes from [constant BEFORE] seconds before the kill to [constant AFTER]
## seconds after it, at normal speed: a camera at the killer's eyes with the killer's gun in first
## person (its shots flash and sound), and everyone else as a *ghost*, a [CrewBody] without hit zones
## posed from the notes (walking, aiming, shooting, falling). The real characters' bodies hide
## meanwhile (purely visual: their hit zones and the game go on). Jump (Space) skips it.
##
## The respawn waits for it: the host keeps a player (not a bot) killed by someone else dead until the
## killcam is over ([constant TOTAL] seconds, [method RespawnMatch.skip_killcam]); skipping it, or
## having it off, asks for the plain respawn delay back. Only the respawn modes have it (main.gd adds
## it there): in rounds you'd learn where an enemy is and could tell your living teammates.
##
## Online it plays on each computer from that computer's own recorder: nothing new on the wire but the
## skip request.

## Emitted when the replay starts, with the killer it shows.
signal started(killer: Character)
## Emitted when the replay is over (it ended, was skipped, or you came back).
signal finished

## Seconds between the death and the replay's start.
const BEAT := 1.0
## Seconds before the kill the replay starts.
const BEFORE := 4.0
## Seconds after the kill it ends.
const AFTER := 0.5
## From the death to the end of the replay: how long the host keeps a player dead for it.
const TOTAL := BEAT + BEFORE + AFTER
## The body every ghost is (loaded at run time: the respawn match names this script).
const BODY_SCENE_PATH := "res://characters/crew/crew_body.tscn"

## The notes it plays.
var recorder: KillcamRecorder
## The match whose kills it watches (a [RespawnMatch]; it asks it for the skip).
var rules: RoundManager
## Whose deaths it shows: the player at this computer.
var player: Character
## Off (the player's setting), there is no replay and no wait for it.
var enabled: bool = true:
	set(value):
		enabled = value
		_tell_rules()

var _wait_left: float = 0.0
var _playing: bool = false
var _killer: Character
var _death_time: float = 0.0
## The recorder's notes being played, and the time shown (on the recorder's clock).
var _frames: Array[KillcamRecorder.Frame] = []
var _time: float = 0.0
## Index of the last note already shown (its shots and deaths played).
var _shown: int = -1
var _camera: Camera3D
var _previous_camera: Camera3D
var _viewmodel: Weapon
## Character → its ghost [CrewBody].
var _ghosts: Dictionary = {}
## The real bodies hidden during the replay.
var _hidden: Array[Node3D] = []


## Watches [param match_rules] for [param local_player]'s deaths and replays them from [param notes].
func setup(match_rules: RoundManager, local_player: Character, notes: KillcamRecorder) -> void:
	rules = match_rules
	player = local_player
	recorder = notes
	rules.character_killed.connect(_on_character_killed)
	player.respawned.connect(stop)
	_tell_rules()


## True from the death until the replay is over.
func is_active() -> bool:
	return _wait_left > 0.0 or _playing


## True while the replay plays.
func is_playing() -> bool:
	return _playing


## The killer being shown (null when nothing plays).
func get_killer() -> Character:
	return _killer if _playing else null


## How far the replay is: 0 at its start, 1 at its end.
func get_progress() -> float:
	if not _playing or _frames.is_empty():
		return 0.0
	return clampf((_time - _frames[0].time) / maxf(_frames[-1].time - _frames[0].time, 0.001), 0.0, 1.0)


## The camera of the replay (null when nothing plays).
func get_camera() -> Camera3D:
	return _camera


## The ghost of [param character] in the replay, or null.
func get_ghost(character: Character) -> CrewBody:
	return _ghosts.get(character)


## Stops the replay (or the wait for it) and asks for the plain respawn delay back.
func skip() -> void:
	if not is_active():
		return
	stop()
	_ask_to_skip()


## Ends the replay (or the wait for it) and puts everything back as it was.
func stop() -> void:
	_wait_left = 0.0
	var was_playing := _playing
	_playing = false
	for ghost: CrewBody in _ghosts.values():
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghosts.clear()
	for body in _hidden:
		if is_instance_valid(body):
			body.visible = true
	_hidden.clear()
	if _viewmodel != null and is_instance_valid(_viewmodel):
		_viewmodel.queue_free()
	_viewmodel = null
	if _camera != null and is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
	_camera = null
	if _previous_camera != null and is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.current = true
	_previous_camera = null
	_frames.clear()
	_killer = null
	if was_playing:
		finished.emit()


func _exit_tree() -> void:
	stop()


func _unhandled_input(event: InputEvent) -> void:
	if is_active() and event.is_action_pressed("jump"):
		skip()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_wait_left = 0.0
			_start()
		return
	if not _playing:
		return
	_time += delta
	if _time >= _frames[-1].time:
		stop()
		return
	_show(delta)


func _on_character_killed(victim: Character, killer: Character, _headshot: bool) -> void:
	if victim != player or killer == null or killer == victim or not is_instance_valid(killer):
		return
	if not enabled:
		_ask_to_skip()
		return
	stop()
	_killer = killer
	_death_time = recorder.get_time()
	_wait_left = BEAT


## Offline and on the host the match keeps a player dead for the replay only while its killcam is on
## (online, the host waits for every friend, and a client with the killcam off asks to skip at each death).
func _tell_rules() -> void:
	if rules is RespawnMatch and not rules.replica and is_instance_valid(player):
		(rules as RespawnMatch).set_killcam_watcher(player, enabled)
	if not enabled:
		stop()


func _ask_to_skip() -> void:
	if rules is RespawnMatch and is_instance_valid(player):
		(rules as RespawnMatch).skip_killcam(player)


func _start() -> void:
	var killer := _killer
	_frames = recorder.get_frames(_death_time - BEFORE, _death_time + AFTER)
	# From the first note with the killer in it (online, a puppet appears with the host's welcome).
	while not _frames.is_empty() and not _frames[0].poses.has(killer):
		_frames.pop_front()
	if _frames.size() < 2 or not is_instance_valid(killer):
		stop()
		return
	_time = _frames[0].time
	_shown = -1
	for character: Character in Character.all_in_world(self):
		if character.body != null and character.body.visible:
			character.body.visible = false
			_hidden.append(character.body)
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "KillcamCamera"
	if _previous_camera != null:
		_camera.fov = _previous_camera.fov
		_camera.near = _previous_camera.near
		_camera.far = _previous_camera.far
	add_child(_camera)
	_camera.current = true
	_playing = true
	_killer = killer
	_show(0.0)
	started.emit(killer)


## Poses the camera, the killer's gun and the ghosts at [member _time], and plays the shots and
## deaths of the notes passed since the last call.
func _show(delta: float) -> void:
	var index := 0
	while index + 1 < _frames.size() - 1 and _frames[index + 1].time <= _time:
		index += 1
	var a := _frames[index]
	var b := _frames[mini(index + 1, _frames.size() - 1)]
	var weight := clampf((_time - a.time) / maxf(b.time - a.time, 0.001), 0.0, 1.0)
	for j in range(_shown + 1, index + 1):
		_play_events(_frames[j])
	_shown = maxi(_shown, index)
	for character: Character in a.poses:
		if not is_instance_valid(character):
			continue
		var from: KillcamRecorder.Pose = a.poses[character]
		var to: KillcamRecorder.Pose = b.poses.get(character, from)
		if character == _killer:
			_pose_camera(from, to, weight)
		else:
			_pose_ghost(character, from, to, weight, delta)


func _pose_camera(from: KillcamRecorder.Pose, to: KillcamRecorder.Pose, weight: float) -> void:
	var eye := from.position.lerp(to.position, weight) + Vector3.UP * lerpf(from.eye_height, to.eye_height, weight)
	_camera.global_position = eye
	_camera.global_rotation = Vector3(lerpf(from.pitch, to.pitch, weight), lerp_angle(from.yaw, to.yaw, weight), 0.0)
	var data := from.weapon
	if _viewmodel == null or not is_instance_valid(_viewmodel) or _viewmodel.data != data:
		_show_viewmodel(data)


## The killer's gun in first person, with their class's arms in their colour.
func _show_viewmodel(data: WeaponData) -> void:
	if _viewmodel != null and is_instance_valid(_viewmodel):
		_viewmodel.queue_free()
	_viewmodel = null
	if data == null or data.model == null:
		return
	_viewmodel = Weapon.create(data)
	_camera.add_child(_viewmodel)
	if is_instance_valid(_killer) and _killer.class_data != null and _killer.class_data.arms_model != null:
		_viewmodel.set_arms(_killer.class_data.arms_model, CrewBody.material_for(_killer.class_data.model.resource_path))
		_viewmodel.set_arms_team_color(Teams.color_of(_killer))
	_viewmodel.set_viewmodel_visible(true)


func _pose_ghost(character: Character, from: KillcamRecorder.Pose, to: KillcamRecorder.Pose, weight: float, delta: float) -> void:
	var ghost: CrewBody = _ghosts.get(character)
	if ghost == null:
		ghost = _make_ghost(character)
		if ghost == null:
			return
		ghost.visible = from.alive
		if not from.alive:
			ghost.play_death("backward")
	var yaw := lerp_angle(from.yaw, to.yaw, weight)
	ghost.global_transform = Transform3D(Basis(Vector3.UP, yaw), from.position.lerp(to.position, weight))
	ghost.show_weapon(from.weapon)
	var local := Basis(Vector3.UP, yaw).inverse() * from.velocity.lerp(to.velocity, weight)
	ghost.update_animation_state(Vector2(local.x, -local.z), from.crouching, from.on_floor, rad_to_deg(from.pitch), delta)


## A body for [param character] in the replay: its class, its colour as you see it, no hit zones.
func _make_ghost(character: Character) -> CrewBody:
	if character.class_data == null:
		return null
	var ghost := (load(BODY_SCENE_PATH) as PackedScene).instantiate() as CrewBody
	ghost.name = "Ghost_%s" % character.name
	ghost.with_hit_zones = false
	ghost.model = character.class_data.model
	ghost.hit_zones = character.class_data.hit_zones
	add_child(ghost)
	ghost.set_team_color(Teams.color_of(character))
	_ghosts[character] = ghost
	return ghost


## The shots and deaths of one note: the killer's gun fires in first person, the ghosts kick and fall.
func _play_events(frame: KillcamRecorder.Frame) -> void:
	for character: Character in frame.poses:
		var pose: KillcamRecorder.Pose = frame.poses[character]
		if character == _killer:
			if pose.fired and _viewmodel != null and is_instance_valid(_viewmodel):
				_viewmodel.replay_shot()
			continue
		var ghost: CrewBody = _ghosts.get(character)
		if ghost == null:
			continue
		if pose.fired and pose.alive:
			ghost.play_shot()
		if not pose.alive and ghost.visible and not ghost.is_dead():
			ghost.play_death("backward")
		elif pose.alive and (not ghost.visible or ghost.is_dead()):
			ghost.visible = true
			ghost.play_alive()
