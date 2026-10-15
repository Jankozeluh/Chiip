class_name MenuFlight
extends Node3D
## The slow camera flight behind the main menu (D-064): a camera that drifts
## around the test map on a closed loop, looking ahead and a little toward the
## middle of the level, with a slow sway to the left and right.
##
## It holds the rig as scene nodes: [code]Path[/code] ([Path3D], a curve through
## [member waypoints]), [code]Path/Follow[/code] ([PathFollow3D], which slides
## along the curve at a constant speed) and [code]Path/Follow/Camera[/code]
## (the [Camera3D]). The curve is built in code from the waypoint list, so the
## route is one table to tune. Nothing here is gameplay: the map has no player and no
## rules, only geometry, light and sky.
##
## The camera's position is the follower's; its direction is computed each frame
## from the curve: toward the point [member look_ahead] metres further along,
## at [member look_height], turned toward the inside of the loop by
## [member look_bias_degrees] plus a sway of [member sway_degrees] every
## [member sway_seconds]. That keeps turns as gentle as the path itself, and
## nothing can make the view jerk.

## Seconds for one full loop. 60 to 90 is calm.
@export_range(30.0, 180.0) var loop_seconds: float = 80.0
## The route, clockwise seen from above, as camera positions in metres. The
## default flies around the test map (66 × 120 m, walls 6 m high) at 4 to 6 m,
## above the peek walls, the platform and the tunnel, and keeps clear of the
## spray wall on the west side.
@export var waypoints: PackedVector3Array = PackedVector3Array([
	Vector3(-20.0, 4.6, -22.0), Vector3(0.0, 5.6, -25.0), Vector3(20.0, 4.6, -22.0),
	Vector3(22.0, 5.2, 8.0), Vector3(20.0, 4.4, 40.0), Vector3(22.0, 5.2, 70.0),
	Vector3(10.0, 5.6, 79.0), Vector3(-10.0, 4.6, 79.0), Vector3(-25.0, 5.2, 70.0),
	Vector3(-26.0, 4.4, 40.0), Vector3(-26.0, 5.2, 8.0),
])
## How far ahead on the path the camera looks, in metres.
@export_range(5.0, 60.0) var look_ahead: float = 24.0
## The height of the point it looks at, in metres: the level's floor and its low walls.
@export_range(0.0, 6.0) var look_height: float = 1.2
## Turns the view toward the inside of the loop (to the right, for a clockwise loop), in degrees.
@export_range(0.0, 90.0) var look_bias_degrees: float = 48.0
## How far the view sways to either side of that, in degrees.
@export_range(0.0, 60.0) var sway_degrees: float = 30.0
## Seconds for one sway to the left and back to the right.
@export_range(5.0, 120.0) var sway_seconds: float = 26.0
## The camera's vertical field of view in degrees.
@export_range(30.0, 110.0) var camera_fov: float = 70.0

## Seconds flown so far (the loop starts again after [member loop_seconds]).
var _time: float = 0.0

@onready var _path: Path3D = $Path
@onready var _follow: PathFollow3D = $Path/Follow
@onready var _camera: Camera3D = $Path/Follow/Camera


func _ready() -> void:
	# The flight moves in _process, not in the physics tick: switch the
	# physics interpolation (on for the whole project) off, or it would smear the motion.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_path.curve = make_curve(waypoints)
	_camera.fov = camera_fov
	_camera.current = true
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


## A smooth closed curve through [param points]: every point's handles point
## along the line between its neighbours (a Catmull-Rom spline written as a
## Bézier curve), so the path has no corners.
static func make_curve(points: PackedVector3Array) -> Curve3D:
	var curve := Curve3D.new()
	var count := points.size()
	for index in count:
		var tangent := (points[(index + 1) % count] - points[(index - 1 + count) % count]) / 6.0
		curve.add_point(points[index], -tangent, tangent)
	curve.closed = true
	return curve


## The camera.
func get_camera() -> Camera3D:
	return _camera


## The length of the loop in metres.
func get_loop_length() -> float:
	return _path.curve.get_baked_length()


## Seconds flown so far, counted from the start of the first loop.
func get_time() -> float:
	return _time


## Jumps to [param seconds] into the flight (tests, screenshots) and moves the camera there.
func set_time(seconds: float) -> void:
	_time = seconds
	_update()


## The position and direction of the camera at the flight's current time.
func _update() -> void:
	var length := get_loop_length()
	_follow.progress = fposmod(_time / loop_seconds, 1.0) * length
	var eye := _follow.global_position
	var ahead := _path.curve.sample_baked(fposmod(_follow.progress + look_ahead, length), true)
	var target := Vector3(ahead.x, look_height, ahead.z)
	var turn := deg_to_rad(sway_degrees * sin(TAU * _time / sway_seconds) - look_bias_degrees)
	var forward := (target - eye).normalized().rotated(Vector3.UP, turn)
	_camera.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), eye)
