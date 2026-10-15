extends Node3D
## Automated checks that the hit zones follow the animated body (M6 task 10, D-074, D-076).
## Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/zone_test.tscn
##
## crew_test.gd measures the zones on a still body (the rest pose). Here every class
## (Rifleman, Bulwark, Marksman, Scout) runs its animation tree, driven with
## [method CrewBody.update_animation_state] on every physics tick as a character would, and the
## test looks at the zones while the body moves:
##
## - Every zone stays on its bone while running: the [CollisionShape3D] of each of the 15 boxes
##   is where [code]skeleton * bone pose * the box's centre[/code] says, within 1 cm. A zone may
##   lag the bone by one physics tick, so each sample is compared with the pose of this tick and
##   the one before, and the closer one counts.
## - The shins really swing over a run cycle (over 0.5 m front to back) and stand still when the
##   body stands (under 2 cm).
## - Aiming up 60 degrees raises both hands (over 15 cm) and tilts the head box (over 20 degrees).
## - Crouching lowers the head zone by 0.35 to 0.55 m.
## - Rays hit the body where it is: while it runs sideways past a fixed ray, a ray at the shin
##   zones' centres hits a legs zone and one at the head zone's centre hits the head, every tick.
##
## Quits with the number of failed checks as the exit code (0 means everything passed).

const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")
## Every class, by the name of its files in assets/models/crew/.
const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
const TICK := 1.0 / 128.0
## The run speed the clips are made for: CS's rifle run, 215 units/s.
const RUN_SPEED := 215.0 * 0.0254
## How far a zone may be from where its bone puts it, in metres.
const FOLLOW_TOLERANCE := 0.01
## Seconds of running the zones are followed for.
const RUN_SECONDS := 2.0
## The shins must swing at least this far front to back over a run cycle, in metres.
const MIN_SHIN_TRAVEL := 0.5
## Standing still, a shin may not move more than this, in metres.
const MAX_SHIN_IDLE_MOVE := 0.02
## Aiming this far up must raise the hands by at least [constant MIN_HAND_RISE] and turn the
## head box by at least [constant MIN_HEAD_TILT] degrees.
const AIM_UP := 60.0
const MIN_HAND_RISE := 0.15
const MIN_HEAD_TILT := 20.0
## Crouching must lower the head zone by an amount in this range, in metres.
const CROUCH_DROP_MIN := 0.35
const CROUCH_DROP_MAX := 0.55
## Where the rays start in front of the body (it faces -Z), in metres.
const RAY_DISTANCE := 3.0

var _failures: int = 0


func _ready() -> void:
	await _run_all()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


func _run_all() -> void:
	await _test_zones_follow_bones()
	await _test_shins_swing()
	await _test_shins_stand_still()
	await _test_aim_up()
	await _test_crouch()
	await _test_rays_hit_animated_body()


## Running for two seconds, every zone box stays where its bone puts it.
func _test_zones_follow_bones() -> void:
	for class_id in CLASSES:
		# Not at the origin and turned, so a mistake with the body's own transform shows up.
		var body := _add_body(class_id, Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)), Vector3(2.0, 0.0, -3.0)))
		await _wait_ticks(2)
		var skeleton := body.get_skeleton()
		var zones := load("res://assets/models/crew/%s_hit_zones.tres" % class_id) as HitZones
		var hitboxes := body.get_hitboxes()
		var mapped := hitboxes.size() == zones.size() and zones.size() > 0
		for i in mini(hitboxes.size(), zones.size()):
			var attachment := hitboxes[i].get_parent() as BoneAttachment3D
			if attachment == null or attachment.bone_name != zones.bones[i]:
				mapped = false
		var worst := -1.0
		var worst_zone := "none"
		# How far the zones are from the bone poses of the tick before: what a tick of lag would show.
		var stale := 0.0
		var on_current := 0
		var on_previous := 0
		var samples := 0
		var previous: Array[Transform3D] = []
		for tick in roundi(RUN_SECONDS / TICK):
			body.update_animation_state(Vector2(0.0, RUN_SPEED), false, true, 0.0, TICK)
			await get_tree().physics_frame
			var now: Array[Transform3D] = []
			for i in mini(hitboxes.size(), zones.size()):
				var bone := skeleton.get_bone_global_pose(skeleton.find_bone(zones.bones[i]))
				now.append(skeleton.global_transform * bone)
			if not previous.is_empty():
				for i in now.size():
					var actual := (hitboxes[i].get_child(0) as CollisionShape3D).global_position
					var from_now := actual.distance_to(now[i] * zones.centers[i])
					var from_previous := actual.distance_to(previous[i] * zones.centers[i])
					var error := minf(from_now, from_previous)
					stale = maxf(stale, from_previous)
					samples += 1
					if from_now <= from_previous:
						on_current += 1
					else:
						on_previous += 1
					if error > worst:
						worst = error
						worst_zone = "%s zone on bone %s" % [hitboxes[i].name, zones.bones[i]]
			previous = now
		_check("[%s] Running, every hit zone stays within 1 cm of its bone (a tick's lag allowed)" % class_id,
				mapped and samples > 0 and worst <= FOLLOW_TOLERANCE,
				"worst error %.2f mm (%s) over %d samples (%d boxes, 2 s); closest to this tick's bone pose %d times, to the previous one %d times (the bones move up to %.0f mm in a tick, so a lagging zone would show)%s" % [
						maxf(worst, 0.0) * 1000.0, worst_zone, samples, hitboxes.size(), on_current, on_previous, stale * 1000.0,
						"" if mapped else "; BOXES DON'T MATCH THE HIT ZONES RESOURCE"])
		body.queue_free()
		await _wait_ticks(2)


## Running, each shin zone's centre swings through more than half a metre, front to back.
func _test_shins_swing() -> void:
	for class_id in CLASSES:
		var body := _add_body(class_id, Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)), Vector3(-1.0, 0.0, 2.0)))
		await _drive(body, Vector2(0.0, RUN_SPEED), false, 0.0, 40)
		var shins := _shins(body)
		var low := [INF, INF]
		var high := [-INF, -INF]
		for tick in roundi(RUN_SECONDS / TICK):
			await _drive(body, Vector2(0.0, RUN_SPEED), false, 0.0, 1)
			for i in shins.size():
				var z := _in_body(body, shins[i]).z
				low[i] = minf(low[i], z)
				high[i] = maxf(high[i], z)
		var least := INF
		var detail := ""
		for i in shins.size():
			least = minf(least, high[i] - low[i])
			detail += "%s %.2f m (z from %.2f to %.2f); " % [_bone_of(shins[i]), high[i] - low[i], low[i], high[i]]
		_check("[%s] Running, each shin zone's centre travels over 0.5 m front to back" % class_id,
				shins.size() == 2 and least > MIN_SHIN_TRAVEL, detail)
		body.queue_free()
		await _wait_ticks(2)


## Standing still, the shins stay put.
func _test_shins_stand_still() -> void:
	for class_id in CLASSES:
		var body := _add_body(class_id, Transform3D(Basis(Vector3.UP, deg_to_rad(15.0)), Vector3(0.0, 0.0, 1.0)))
		await _drive(body, Vector2.ZERO, false, 0.0, 60)
		var shins := _shins(body)
		var low: Array[Vector3] = [Vector3.INF, Vector3.INF]
		var high: Array[Vector3] = [-Vector3.INF, -Vector3.INF]
		for tick in 256:
			await _drive(body, Vector2.ZERO, false, 0.0, 1)
			for i in shins.size():
				var local := _in_body(body, shins[i])
				low[i] = low[i].min(local)
				high[i] = high[i].max(local)
		var most := 0.0
		var detail := ""
		for i in shins.size():
			var moved := (high[i] - low[i]).length()
			most = maxf(most, moved)
			detail += "%s moved %.1f mm in 2 s; " % [_bone_of(shins[i]), moved * 1000.0]
		_check("[%s] Standing still, the shin zones move less than 2 cm" % class_id,
				shins.size() == 2 and most < MAX_SHIN_IDLE_MOVE, detail)
		body.queue_free()
		await _wait_ticks(2)


## Aiming up 60 degrees raises the hands and tilts the head, compared with aiming level.
func _test_aim_up() -> void:
	for class_id in CLASSES:
		var body := _add_body(class_id, Transform3D.IDENTITY)
		await _drive(body, Vector2.ZERO, false, 0.0, 60)
		var hands := _zones_on_bones(body, ["hand_l", "hand_r"])
		var head := _first_shape(body, Hitbox.Zone.HEAD)
		var level_hands: Array[Vector3] = []
		for hand in hands:
			level_hands.append(hand.global_position)
		var level_up := head.global_basis.y.normalized()
		await _drive(body, Vector2.ZERO, false, AIM_UP, 60)
		var least_rise := INF
		var detail := ""
		for i in hands.size():
			var rise := hands[i].global_position.y - level_hands[i].y
			least_rise = minf(least_rise, rise)
			detail += "%s up %.2f m; " % [_bone_of(hands[i]), rise]
		var tilt := rad_to_deg(level_up.angle_to(head.global_basis.y.normalized()))
		_check("[%s] Aiming up 60 degrees raises both hand zones over 15 cm and tilts the head zone over 20 degrees" % class_id,
				hands.size() == 2 and head != null and least_rise > MIN_HAND_RISE and tilt > MIN_HEAD_TILT,
				"%shead box tilted %.1f degrees" % [detail, tilt])
		body.queue_free()
		await _wait_ticks(2)


## Crouching lowers the head zone, as it does the eyes in CS (0.457 m).
func _test_crouch() -> void:
	for class_id in CLASSES:
		var body := _add_body(class_id, Transform3D.IDENTITY)
		await _drive(body, Vector2.ZERO, false, 0.0, 40)
		var standing := body.get_zone_center(Hitbox.Zone.HEAD).y
		await _drive(body, Vector2.ZERO, true, 0.0, 60)
		var crouched := body.get_zone_center(Hitbox.Zone.HEAD).y
		var drop := standing - crouched
		_check("[%s] Crouching lowers the head zone by 0.35 to 0.55 m" % class_id,
				drop > CROUCH_DROP_MIN and drop < CROUCH_DROP_MAX,
				"head zone %.3f m standing, %.3f m crouched, %.3f m lower" % [standing, crouched, drop])
		body.queue_free()
		await _wait_ticks(2)


## Running sideways past fixed rays: a ray at a shin zone's centre hits a legs zone and one at
## the head zone's centre hits the head, on every tick, wherever the animation has put them.
func _test_rays_hit_animated_body() -> void:
	for class_id in CLASSES:
		var body := _add_body(class_id, Transform3D.IDENTITY)
		await _drive(body, Vector2(RUN_SPEED, 0.0), false, 0.0, 40)
		var shins := _shins(body)
		var head := _first_shape(body, Hitbox.Zone.HEAD)
		var rays := 0
		var leg_rays := 0
		var leg_hits := 0
		var exact_leg_hits := 0
		var head_hits := 0
		var wrong := {}
		var low := INF
		var high := -INF
		for tick in roundi(RUN_SECONDS / TICK) * 3 / 4:
			await _drive(body, Vector2(RUN_SPEED, 0.0), false, 0.0, 1)
			for shin in shins:
				var hit := _ray_at(shin.global_position)
				leg_rays += 1
				var zone := (hit.collider as Hitbox).zone if not hit.is_empty() else -1
				if zone == Hitbox.Zone.LEGS:
					leg_hits += 1
					if hit.collider == shin.get_parent():
						exact_leg_hits += 1
				else:
					wrong["shin->" + _zone_name(zone)] = wrong.get("shin->" + _zone_name(zone), 0) + 1
				low = minf(low, shin.global_position.x)
				high = maxf(high, shin.global_position.x)
			var head_hit := _ray_at(head.global_position)
			rays += 1
			var head_zone := (head_hit.collider as Hitbox).zone if not head_hit.is_empty() else -1
			if head_zone == Hitbox.Zone.HEAD:
				head_hits += 1
			else:
				wrong["head->" + _zone_name(head_zone)] = wrong.get("head->" + _zone_name(head_zone), 0) + 1
		_check("[%s] Running sideways past fixed rays, a ray at a shin zone hits a legs zone and one at the head zone hits the head" % class_id,
				shins.size() == 2 and head != null and leg_hits == leg_rays and head_hits == rays and high - low > 0.2,
				"%d of %d shin rays hit legs (%d the very shin box), %d of %d head rays hit the head; the shins moved %.2f m sideways%s" % [
						leg_hits, leg_rays, exact_leg_hits, head_hits, rays, high - low,
						"" if wrong.is_empty() else "; misses: " + str(wrong)])
		body.queue_free()
		await _wait_ticks(2)


# --- Helpers ---


## A body of [param class_id] at [param placement] running its animation tree. The model is
## set before the body enters the tree, which builds it.
func _add_body(class_id: String, placement: Transform3D) -> CrewBody:
	var body := BODY_SCENE.instantiate() as CrewBody
	body.model = load("res://assets/models/crew/%s.glb" % class_id)
	body.animated = true
	body.transform = placement
	add_child(body)
	return body


## Feeds [param body] the same state for [param ticks] physics ticks (what a character's state
## does every tick), then waits for the tick.
func _drive(body: CrewBody, velocity: Vector2, crouching: bool, aim: float, ticks: int) -> void:
	for i in ticks:
		body.update_animation_state(velocity, crouching, true, aim, TICK)
		await get_tree().physics_frame


## The box shapes of the shin zones (one per leg).
func _shins(body: CrewBody) -> Array[CollisionShape3D]:
	return _zones_on_bones(body, ["shin_l", "shin_r"])


## The box shapes of the zones on [param bones], in the order of [param bones].
func _zones_on_bones(body: CrewBody, bones: Array[String]) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for bone in bones:
		for hitbox in body.get_hitboxes():
			if (hitbox.get_parent() as BoneAttachment3D).bone_name == bone:
				found.append(hitbox.get_child(0) as CollisionShape3D)
	return found


## The name of the bone a zone's box shape is on (shape, then its [Hitbox], then the
## [BoneAttachment3D]).
func _bone_of(shape: CollisionShape3D) -> String:
	return (shape.get_parent().get_parent() as BoneAttachment3D).bone_name


## The box shape of the first zone of [param zone].
func _first_shape(body: CrewBody, zone: Hitbox.Zone) -> CollisionShape3D:
	for hitbox in body.get_hitboxes():
		if hitbox.zone == zone:
			return hitbox.get_child(0) as CollisionShape3D
	return null


## A shape's centre in the body's own frame (x right, y up, -z forward).
func _in_body(body: CrewBody, shape: CollisionShape3D) -> Vector3:
	return body.global_transform.affine_inverse() * shape.global_position


## Casts a ray at the hit zones along +Z, from [constant RAY_DISTANCE] in front of the body
## (it faces -Z) to the same distance behind, through [param point]'s height and sideways
## position. Returns the physics result: empty when nothing was hit.
func _ray_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, point.y, -RAY_DISTANCE), Vector3(point.x, point.y, RAY_DISTANCE), PhysicsLayers.HITBOXES)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty() or not result.collider is Hitbox:
		return {}
	return result


func _zone_name(zone: int) -> String:
	return "nothing" if zone < 0 else String(Hitbox.Zone.keys()[zone]).to_lower()


func _wait_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
