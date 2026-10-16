class_name KillcamRecorder
extends Node
## The killcam's memory (M17, D-241): the last few seconds of everyone in this game's world, as this
## computer shows them, so [Killcam] can play the moments before your death again through your
## killer's eyes.
##
## Every [constant TICKS_PER_FRAME] physics ticks it notes each character's pose (where it is, how
## it moves, where it looks, its stance, whether it's alive, the gun in its hand) and whether it fired
## since the last note, and keeps [constant SECONDS] of them, a ring buffer like a demo file's tail.
## On the host and offline that is the game itself; on a client it is the puppets as the snapshots
## posed them (and [method Weapon.play_remote_shot] fires their guns), so the killcam needs nothing
## new from the network. Add it to the map: it records the characters of the world it is in
## ([method Character.all_in_world]).

## How many seconds of the past it keeps (the killcam shows at most [constant Killcam.BEFORE] +
## [constant Killcam.AFTER], noted [constant Killcam.BEAT] after the death).
const SECONDS := 7.0
## Physics ticks between two notes (128 Hz ticks: 64 notes a second; the killcam blends between them).
const TICKS_PER_FRAME := 2


## One character at one moment.
class Pose:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0
	var eye_height: float = 0.0
	var crouching: bool = false
	var on_floor: bool = true
	var alive: bool = true
	## The gun in its hand (null: none).
	var weapon: WeaponData = null
	## Whether it fired since the note before.
	var fired: bool = false


## Every character at one moment: its [member time] on this recorder's clock and a [Pose] each.
class Frame:
	var time: float = 0.0
	## Character → [Pose].
	var poses: Dictionary = {}


## Notes, oldest first.
var _frames: Array[Frame] = []
## Seconds this recorder has run (paused time doesn't count).
var _clock: float = 0.0
var _ticks: int = 0
## Characters that fired since the last note.
var _fired: Dictionary = {}
## Character → [the [Weapon] whose shots it listens to, the bound listener].
var _followed: Dictionary = {}


func _physics_process(delta: float) -> void:
	_clock += delta
	_ticks += 1
	if _ticks % TICKS_PER_FRAME == 0:
		record()


## The recorder's clock now, in seconds (the times of [method get_frames]).
func get_time() -> float:
	return _clock


## Notes everyone's pose now (the recorder does it by itself every [constant TICKS_PER_FRAME] ticks).
func record() -> void:
	var frame := Frame.new()
	frame.time = _clock
	for character in Character.all_in_world(self):
		_follow(character)
		var pose := Pose.new()
		pose.position = character.global_position
		pose.velocity = character.velocity
		var aim := character.get_aim_angles()
		pose.yaw = aim.x
		pose.pitch = aim.y
		pose.eye_height = character.get_eye_height()
		pose.crouching = character.is_crouching
		pose.on_floor = character.is_grounded()
		pose.alive = character.is_alive()
		pose.weapon = character.weapon.data if character.weapon != null else null
		pose.fired = _fired.has(character)
		frame.poses[character] = pose
	_fired.clear()
	_frames.append(frame)
	while not _frames.is_empty() and _frames[0].time < _clock - SECONDS:
		_frames.pop_front()


## The notes from [param from] to [param to] seconds of this recorder's clock, oldest first.
func get_frames(from: float, to: float) -> Array[Frame]:
	var found: Array[Frame] = []
	for frame in _frames:
		if frame.time >= from and frame.time <= to:
			found.append(frame)
	return found


## Listens to the shots of the gun in [param character]'s hand (it changes with every switch).
func _follow(character: Character) -> void:
	var weapon := character.weapon
	var followed: Array = _followed.get(character, [null, Callable()])
	if followed[0] == weapon:
		return
	var old: Variant = followed[0]
	if is_instance_valid(old) and (old as Weapon).fired.is_connected(followed[1]):
		(old as Weapon).fired.disconnect(followed[1])
	var listener := _on_fired.bind(character)
	_followed[character] = [weapon, listener]
	if weapon != null:
		weapon.fired.connect(listener)


func _on_fired(_spray_shot: int, character: Character) -> void:
	_fired[character] = true
