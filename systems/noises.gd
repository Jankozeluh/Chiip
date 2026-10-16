class_name Noises
extends RefCounted
## Global "noise bus": anything that makes a sound bots could hear announces it
## here with [method make_noise], and bots listen to [signal noise_made] on
## [method get_bus].
##
## Only gameplay noise goes through here (footsteps, gunshots), not every
## sound effect. Walking and crouch-walking make no noise, as in CS.
##
## This is a plain class with one shared instance (a static variable) rather
## than an autoload, because autoloads aren't loaded when Godot runs a
## [code]--script[/code] (our tools and checks).

## How far running footsteps carry, in metres.
const FOOTSTEP_RANGE := 25.0
## How far a gunshot carries, in metres.
const GUNSHOT_RANGE := 60.0

## Emitted for every noise: where, how far it carries, and who made it.
signal noise_made(noise_position: Vector3, hearing_range: float, source: Character)
## Emitted for every gunshot (not footsteps, grenades or the bomb) by [method announce_shot]: where it was
## fired from and by whom. The HUD's compass shows enemy shots from it (D-180). Separate from [signal noise_made]
## because a client sees other players' shots as replays ([method Weapon.play_remote_shot]) that must never reach
## the bots' ears, which belong to the host.
signal shot_fired(shot_position: Vector3, source: Character)

static var _bus: Noises


## The shared bus to connect to.
static func get_bus() -> Noises:
	if _bus == null:
		_bus = Noises.new()
	return _bus


## Announces a noise at [param noise_position] that carries [param hearing_range] metres.
static func make_noise(noise_position: Vector3, hearing_range: float, source: Character) -> void:
	get_bus().noise_made.emit(noise_position, hearing_range, source)


## Announces that [param source] fired a gun at [param shot_position] ([signal shot_fired]). A real shot calls it next to
## [method make_noise]; a puppet's shot on a client (the host said so) calls it alone.
static func announce_shot(shot_position: Vector3, source: Character) -> void:
	get_bus().shot_fired.emit(shot_position, source)
