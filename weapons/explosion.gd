class_name Explosion
extends Node3D
## What a grenade going off looks and sounds like (M7, D-097): presentation only, the damage and
## the blindness are dealt by [Grenade]. A frag: an orange light, a fireball that swells and fades,
## debris and a puff of dark smoke ([GPUParticles3D], Godot's GPU particle system, like Unity's
## Particle System); a flashbang: a white burst of light; a smoke: the hiss (the cloud is its own
## node, [SmokeCloud]). It frees itself after [constant LIFETIME] seconds, counted in physics
## ticks so it stops while paused.

enum Kind { FRAG, FLASH, SMOKE }

const FRAG_SOUND := preload("res://assets/sounds/frag_explosion.wav")
const FLASH_SOUND := preload("res://assets/sounds/flash_pop.wav")
const SMOKE_SOUND := preload("res://assets/sounds/smoke_hiss.wav")
## Seconds before the node frees itself.
const LIFETIME := 2.5
## Seconds the light and the fireball last.
const FLASH_TIME := 0.25

## Which grenade went off.
var kind: Kind = Kind.FRAG
## No sound (tests).
var silent: bool = false

var _age: float = 0.0
var _light: OmniLight3D
var _ball: MeshInstance3D
var _ball_material: StandardMaterial3D


func _ready() -> void:
	match kind:
		Kind.FRAG:
			_add_light(Color(1.0, 0.6, 0.25), 6.0, 9.0)
			_add_ball(Color(1.0, 0.65, 0.2), 0.6)
			_add_particles(24, Color(0.18, 0.17, 0.16), Vector2(5.0, 10.0), 0.9, Vector3(0.06, 0.06, 0.06), true)
			_add_particles(10, Color(0.32, 0.31, 0.3, 0.85), Vector2(0.8, 2.0), 1.6, Vector3(0.7, 0.7, 0.7), false)
			_play(FRAG_SOUND, 0.0, 20.0, 120.0)
		Kind.FLASH:
			_add_light(Color(1.0, 1.0, 0.95), 12.0, 16.0)
			_add_ball(Color(1.0, 1.0, 1.0), 0.35)
			_play(FLASH_SOUND, 0.0, 15.0, 100.0)
		Kind.SMOKE:
			_play(SMOKE_SOUND, -12.0, 4.0, 25.0)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / FLASH_TIME, 0.0, 1.0)
	if _light != null:
		_light.light_energy *= 1.0 - t * 0.5
		_light.visible = t < 1.0
	if _ball != null:
		_ball.scale = Vector3.ONE * lerpf(0.3, 1.6, t)
		_ball_material.albedo_color.a = 1.0 - t
		_ball.visible = t < 1.0
	if _age >= LIFETIME:
		queue_free()


func _add_light(color: Color, energy: float, light_range: float) -> void:
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = energy
	_light.omni_range = light_range
	add_child(_light)


func _add_ball(color: Color, radius: float) -> void:
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 5
	_ball.mesh = sphere
	_ball_material = StandardMaterial3D.new()
	_ball_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ball_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ball_material.albedo_color = color
	_ball.material_override = _ball_material
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)


## A one-shot burst of [param amount] boxes of [param size] flying out at [param speed] (min, max)
## m/s for [param lifetime] seconds, falling ([param heavy]) or drifting up.
func _add_particles(amount: int, color: Color, speed: Vector2, lifetime: float, size: Vector3, heavy: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 80.0 if heavy else 60.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = Vector3(0, -9.0, 0) if heavy else Vector3(0, 0.6, 0)
	process.damping_min = 0.0 if heavy else 1.5
	process.damping_max = 0.0 if heavy else 2.5
	process.scale_min = 0.6
	process.scale_max = 1.4
	particles.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.emitting = true
	add_child(particles)


func _play(stream: AudioStream, volume: float, unit_size: float, max_distance: float) -> void:
	if silent:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volume
	audio.unit_size = unit_size
	audio.max_distance = max_distance
	audio.bus = &"Effects"
	add_child(audio)
	audio.play()
