class_name SmokeCloud
extends Node3D
## A smoke grenade's cloud (M7, D-097): a cluster of low-poly grey puffs about 7 m across and
## 3 m high that grows for a second, stays for [constant LIFETIME] seconds in all and thins out
## over the last two. While it's thick it blocks the bots' sight ([method blocks], through
## [Smokes]), and a camera inside it sees grey (the HUD asks [method density_at]). Bullets pass
## through, as in CS. It counts its time in physics ticks, so it stands still while paused.

## Seconds from popping to gone (CS:GO: 18).
const LIFETIME := 18.0
## Seconds it takes to grow to full size, and to thin out at the end.
const GROW_TIME := 1.2
const FADE_TIME := 2.0
## The blocking shape: an ellipsoid with these radii (metres), its middle this high above the
## spot it popped on.
const RADII := Vector3(3.4, 2.0, 3.4)
const CENTER_HEIGHT := 1.6
## A line blocks sight where it passes this deep inside the ellipsoid (1 = its surface).
const BLOCK_DEPTH := 0.85
## The cloud only blocks while at least this thick (growing and thinning out don't).
const BLOCK_STRENGTH := 0.5
## How many puffs make the cloud, and their size range (metres).
const PUFFS := 14
const PUFF_RADIUS := Vector2(1.3, 1.9)
const COLOR := Color(0.62, 0.63, 0.65, 0.94)

## Seconds since it popped.
var age: float = 0.0
## Randomness for the puffs' places (seeded per cloud, so a test sees the same cloud).
var rng := RandomNumberGenerator.new()

var _material: StandardMaterial3D
var _puffs: Node3D


func _ready() -> void:
	add_to_group("smoke_clouds")
	_build()
	Smokes.add(self)
	_update_look()


func _exit_tree() -> void:
	Smokes.remove(self)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		Smokes.remove(self)
		queue_free()
		return
	_update_look()


## 0 to 1: how thick the cloud is overall now (growing, full, thinning out).
func get_strength() -> float:
	var grow := clampf(age / GROW_TIME, 0.0, 1.0)
	var fade := clampf((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
	return minf(grow, fade)


## The middle of the blocking ellipsoid.
func get_center() -> Vector3:
	return global_position + Vector3.UP * CENTER_HEIGHT


## True if the line from [param from] to [param to] passes through the thick part of the cloud.
func blocks(from: Vector3, to: Vector3) -> bool:
	if get_strength() < BLOCK_STRENGTH:
		return false
	# In the ellipsoid's own space it's a unit sphere: find the line's closest point to its middle.
	var a := (from - get_center()) / RADII
	var b := (to - get_center()) / RADII
	var along := b - a
	var t := 0.0
	if along.length_squared() > 0.000001:
		t = clampf(-a.dot(along) / along.length_squared(), 0.0, 1.0)
	return (a + along * t).length() < BLOCK_DEPTH


## How thick the smoke is at [param point]: 1 deep inside, 0 outside.
func density_at(point: Vector3) -> float:
	var depth := ((point - get_center()) / RADII).length()
	return clampf((1.0 - depth) / 0.3, 0.0, 1.0) * get_strength()


func _build() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 1.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_puffs = Node3D.new()
	_puffs.name = "Puffs"
	_puffs.position = Vector3.UP * CENTER_HEIGHT
	add_child(_puffs)
	for i in PUFFS:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var radius := rng.randf_range(PUFF_RADIUS.x, PUFF_RADIUS.y)
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 5
		puff.mesh = sphere
		puff.material_override = _material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Inside the ellipsoid, a little flatter at the top, none below the floor.
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		puff.position = direction * Vector3(2.4, 0.9, 2.4) * rng.randf_range(0.2, 1.0)
		_puffs.add_child(puff)


func _update_look() -> void:
	var grow := clampf(age / GROW_TIME, 0.0, 1.0)
	_puffs.scale = Vector3.ONE * lerpf(0.3, 1.0, sqrt(grow))
	var fade := clampf((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
	_material.albedo_color.a = COLOR.a * fade
