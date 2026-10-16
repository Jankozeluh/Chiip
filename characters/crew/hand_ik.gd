class_name HandIK
extends SkeletonModifier3D
## Keeps a crew body's left hand on its gun's foregrip (M11, D-156): a two-bone IK for the left
## arm that runs after the animation, every tick. The clips already put the hand there (the
## generator solves the same IK), but the game blends them (aim pitches, locomotion, crouching,
## the kick), and a blend of two arm poses doesn't keep a hand on a point: without it the hand
## drifts a few centimetres off the gun.
##
## [member target] is where the hand bone (its wrist) goes, in the weapon bone's space
## ([method GunModel.left_hand_target]). The elbow stays on the side the animation put it. The
## body fades [member SkeletonModifier3D.influence] out while the left hand has other work
## (reloads, the knife, grenades) and in again afterwards.

## Where the left hand goes, in the weapon bone's space (wrist position and hand rotation).
var target: Transform3D = Transform3D.IDENTITY

var _upper: int = -1
var _fore: int = -1
var _hand: int = -1
var _weapon: int = -1


## Finds the arm's bones; the skeleton must be this node's parent.
func set_up() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_upper = skeleton.find_bone("upper_arm_l")
	_fore = skeleton.find_bone("forearm_l")
	_hand = skeleton.find_bone("hand_l")
	_weapon = skeleton.find_bone("weapon")


## Where the left hand should be now, in skeleton space.
func get_target_pose() -> Transform3D:
	var skeleton := get_skeleton()
	if skeleton == null or _weapon < 0:
		return Transform3D.IDENTITY
	return skeleton.get_bone_global_pose(_weapon) * target


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _upper < 0 or _fore < 0 or _hand < 0 or _weapon < 0:
		return
	var want := get_target_pose()
	var upper := skeleton.get_bone_global_pose(_upper)
	var fore := skeleton.get_bone_global_pose(_fore)
	var hand := skeleton.get_bone_global_pose(_hand)
	var shoulder := upper.origin
	var a := shoulder.distance_to(fore.origin)
	var b := fore.origin.distance_to(hand.origin)
	if a < 1e-4 or b < 1e-4:
		return
	var to_target := want.origin - shoulder
	var reach := clampf(to_target.length(), absf(a - b) + 1e-4, a + b - 1e-4)
	var along := to_target.normalized()
	# The elbow bends to the side the animation put it on.
	var bend := (fore.origin - shoulder) - along * (fore.origin - shoulder).dot(along)
	if bend.length_squared() < 1e-8:
		bend = Vector3.DOWN - along * Vector3.DOWN.dot(along)
	bend = bend.normalized()
	var x := (a * a - b * b + reach * reach) / (2.0 * reach)
	var elbow := shoulder + along * x + bend * sqrt(maxf(a * a - x * x, 0.0))
	var wrist := shoulder + along * reach
	upper.basis = Basis(_turn(fore.origin - shoulder, elbow - shoulder)) * upper.basis
	skeleton.set_bone_global_pose(_upper, upper)
	fore = skeleton.get_bone_global_pose(_fore)
	hand = skeleton.get_bone_global_pose(_hand)
	fore.basis = Basis(_turn(hand.origin - fore.origin, wrist - fore.origin)) * fore.basis
	skeleton.set_bone_global_pose(_fore, fore)
	hand = skeleton.get_bone_global_pose(_hand)
	skeleton.set_bone_global_pose(_hand, Transform3D(want.basis.orthonormalized(), hand.origin))


## The shortest rotation from direction [param from] to [param to].
static func _turn(from: Vector3, to: Vector3) -> Quaternion:
	if from.length_squared() < 1e-10 or to.length_squared() < 1e-10:
		return Quaternion.IDENTITY
	return Quaternion(from.normalized(), to.normalized())
