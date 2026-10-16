class_name Smokes
extends RefCounted
## Every smoke cloud in the game, and what they hide (M7, D-097): bots can't see through one
## ([method blocks]) and the HUD greys out the view of a camera inside one ([method density_at]).
## A static list, like [Noises] and [MenuState]: no node, no autoload, so tests and tools can use
## it. A [SmokeCloud] adds itself when it pops and removes itself when it's gone.

## The clouds in the game (untyped: a freed cloud is dropped by itself).
static var _clouds: Array = []


## Registers [param cloud] (a [SmokeCloud]).
static func add(cloud: Node3D) -> void:
	_drop_freed()
	if not _clouds.has(cloud):
		_clouds.append(cloud)


## Unregisters [param cloud].
static func remove(cloud: Node3D) -> void:
	_clouds.erase(cloud)


## Every cloud in the game.
static func get_clouds() -> Array:
	_drop_freed()
	return _clouds.duplicate()


## True if the line from [param from] to [param to] passes through the thick part of a cloud
## (see [method SmokeCloud.blocks]).
static func blocks(from: Vector3, to: Vector3) -> bool:
	_drop_freed()
	for cloud: SmokeCloud in _clouds:
		if cloud.blocks(from, to):
			return true
	return false


## How thick the smoke is at [param point]: 0 (none) to 1 (can't see a thing).
static func density_at(point: Vector3) -> float:
	_drop_freed()
	var most := 0.0
	for cloud: SmokeCloud in _clouds:
		most = maxf(most, cloud.density_at(point))
	return most


## Forgets every cloud (for tests that start over).
static func clear() -> void:
	_clouds.clear()


static func _drop_freed() -> void:
	_clouds = _clouds.filter(func(cloud: Variant) -> bool:
		return is_instance_valid(cloud) and not (cloud as Node).is_queued_for_deletion())
