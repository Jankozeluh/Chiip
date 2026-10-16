class_name AimTarget
extends Node3D
## One flick target of the aim trainer (M14, D-205): a lime ball that pops up in the air and can be
## shot. It is a plain [Hitbox] under a ball mesh, so bullets hit it like any hit zone; [RangeTrainer]
## places it, counts how long it has been up ([member age]) and removes it. The first bullet that
## hits it emits [signal shot]; further pellets of the same shot are ignored.
##
## The ball keeps the same size on your screen wherever it is (the trainer gives it a radius from its
## distance), so skill, not distance, decides how hard it is.

## Emitted by the first bullet that hits the target; [param attacker] is who fired.
signal shot(attacker: Node)

## The ball's colour: the UI's lime accent (never team blue or red, D-031).
const COLOR := Color(0.78, 0.94, 0.24)

## Seconds since the target appeared (counted in physics ticks, so a pause stops it).
var age: float = 0.0
## The ball's radius in metres.
var radius: float = 0.25

var _hitbox: Hitbox
var _ball: MeshInstance3D
var _hit_taken: bool = false


## Builds the ball and its hit zone with [param ball_radius] (metres).
func setup(ball_radius: float) -> void:
	radius = ball_radius
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	# A chunky ball, in keeping with the retro look.
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	_ball.mesh = mesh
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_hitbox = Hitbox.new()
	_hitbox.name = "Hitbox"
	_hitbox.zone = Hitbox.Zone.CHEST
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	_hitbox.add_child(shape)
	add_child(_hitbox)
	_hitbox.hit.connect(_on_hit)


func _physics_process(delta: float) -> void:
	age += delta


## The target's hit zone (for the tests).
func get_hitbox() -> Hitbox:
	return _hitbox


## Pops the ball up: the picture grows from small in a blink (the hit zone is full size at once,
## so a flick that lands in that blink still counts).
func pop() -> void:
	_ball.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_ball, "scale", Vector3.ONE, 0.08)


## Hit: the ball swells and is gone. The hit zone is switched off at once so nothing else hits it.
func burst() -> void:
	_hitbox.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(_ball, "scale", Vector3.ONE * 1.6, 0.07)
	tween.tween_callback(queue_free)


func _on_hit(_damage: float, _zone: Hitbox.Zone, _position: Vector3, attacker: Node, _penetration: float, _source: WeaponData) -> void:
	if _hit_taken:
		return
	_hit_taken = true
	shot.emit(attacker)
