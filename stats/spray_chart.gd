class_name SprayChart
extends RefCounted
## The maths of the spray wall (M14, D-208, D-209), all static and in metres on the wall, so it can be
## checked without a map ([RangeSprayWall] draws what this works out).
##
## A weapon's spray pattern ([member WeaponData.spray_pattern]) says where each shot of a spray goes
## relative to your aim, in degrees (x to the right, y up). On a wall [param distance] metres away
## that is a point `distance × tan(angle)` to the right and up. **The ghost** is the pattern drawn
## that way, from the first shot: where the spray would go if you held the mouse still. **Your holes**
## are where your bullets really landed. **Drift** is how far your holes are from your first one on
## average, the ghost's drift is how far the pattern would have put them, and **control** is how much
## of that you cancelled by pulling the mouse against the recoil:
##
##     control = 100 × (1 − drift ÷ ghost drift), between 0 and 100
##
## Holding still gives about 0, a perfect pull gives 100. (The random spread of the gun adds some drift
## that no pull can take away, so 100 is out of reach with a gun that isn't perfectly accurate.)

## The fewest shots a spray needs before its control is worth showing and saving as a best.
const MIN_SHOTS := 10


## Where each of the first [param count] shots of [param pattern] goes on a wall [param distance] metres
## away, as (right, up) in metres from the first shot. The first is (0, 0); a spray longer than the
## pattern repeats its last entry (as the weapon does).
static func ghost(pattern: PackedVector2Array, distance: float, count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if pattern.is_empty():
		return points
	var first := pattern[0]
	for index in count:
		var entry := pattern[mini(index, pattern.size() - 1)]
		points.append(Vector2(
				distance * tan(deg_to_rad(entry.x - first.x)),
				distance * tan(deg_to_rad(entry.y - first.y))))
	return points


## The average distance of the points from the first one, over the second point and later (0 for fewer
## than two points). Entries that are null (shots that missed the wall) are skipped.
static func drift(points: Array) -> float:
	if points.size() < 2 or points[0] == null:
		return 0.0
	var first: Vector2 = points[0]
	var total := 0.0
	var counted := 0
	for index in range(1, points.size()):
		if points[index] != null:
			total += first.distance_to(points[index] as Vector2)
			counted += 1
	return total / float(counted) if counted > 0 else 0.0


## Control, 0 to 100: how much of the pattern's drift [param your_drift] cancelled. 0 when the
## pattern has no drift (a pistol's single point): there is nothing to control.
static func control(your_drift: float, ghost_drift: float) -> float:
	if ghost_drift <= 0.0001:
		return 0.0
	return clampf(100.0 * (1.0 - your_drift / ghost_drift), 0.0, 100.0)


## Control of a spray: [param holes] are the wall points of the shots in order (null for a shot that
## missed the wall), [param ghost_points] the ghost for at least as many shots. The ghost's drift is
## taken over the same shots as the holes', so a spray that missed the wall now and then is compared
## fairly.
static func spray_control(holes: Array, ghost_points: Array[Vector2]) -> float:
	var counted_ghost: Array = []
	for index in mini(holes.size(), ghost_points.size()):
		counted_ghost.append(ghost_points[index] if index == 0 or holes[index] != null else null)
	return control(drift(holes), drift(counted_ghost))
