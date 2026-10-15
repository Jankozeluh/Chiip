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

static var _bus: Noises


## The shared bus to connect to.
static func get_bus() -> Noises:
	if _bus == null:
		_bus = Noises.new()
	return _bus


## Announces a noise at [param noise_position] that carries [param hearing_range] metres.
static func make_noise(noise_position: Vector3, hearing_range: float, source: Character) -> void:
	get_bus().noise_made.emit(noise_position, hearing_range, source)
