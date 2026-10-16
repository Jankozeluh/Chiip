class_name GunModel
extends RefCounted
## A weapon's model in someone's hands (M11, D-156 to D-158): where its points are, and the
## magazine and the shotgun shell moving with the left hand during a reload, in first and third
## person alike.
##
## The generated models (tools/modelgen/weapons.py) carry their points as empty child nodes
## ([code]point_foregrip[/code], [code]point_magazine[/code], [code]point_handle[/code]...), the
## magazine as a child node [code]Magazine[/code] whose origin is the magazine point, and the
## shotgun a [code]Shell[/code]. Make models with [method instantiate] (it hides the shell).
##
## A [GunModel] made for a model in the hands ([code]GunModel.new(model)[/code]) moves those
## parts: [method update] every frame with the reload's progress and the left hand's transform. The moments
## are [constant MAGAZINE_EVENTS] and [constant SHELL_EVENTS], fractions of the reload that the
## generator's reload clips are keyed to (holds.py RELOAD_EVENTS; change both together).

## The left hand on a foregrip, in weapon space relative to the foregrip point: its rotation and
## where its wrist (the hand bone's origin) sits. From tools/modelgen/rig.py: hand_in_weapon('l').
const LEFT_HAND_ON_GRIP := Transform3D(
		Basis(Vector3(-0.45284, -0.25158, 0.85536), Vector3(-0.28054, -0.87043, -0.40453),
				Vector3(0.84631, -0.42315, 0.32359)),
		Vector3(-0.035, -0.035, 0.045))
## A magazine reload, as fractions of the reload time: the left hand takes the magazine, swaps
## it for a fresh one at the vest, puts that in, and works the charging handle, bolt or slide.
const MAGAZINE_EVENTS := {&"grab": 0.24, &"swap": 0.38, &"insert": 0.66, &"handle": 0.80}
## When a magazine reload's sound plays: magazine out, magazine in, the handle.
const MAGAZINE_SOUNDS: Array[float] = [0.28, 0.66, 0.80]
## One shotgun shell, as fractions of the shell's time: the left hand takes it from the vest and
## pushes it into the loading port.
const SHELL_EVENTS := {&"take": 0.28, &"insert": 0.80}
## When a shell's sound plays: as it goes in.
const SHELL_SOUNDS: Array[float] = [0.80]

var _model: Node3D
var _magazine: Node3D
var _shell: Node3D
## Where the magazine sits in the gun, and where it sits in the left hand while held.
var _seat: Transform3D
var _in_hand: Transform3D
var _held: bool = false


## A [GunModel] for [param model], a weapon model in someone's hands.
func _init(model: Node3D) -> void:
	_model = model
	_magazine = model.find_child("Magazine", true, false) as Node3D if model != null else null
	_shell = model.find_child("Shell", true, false) as Node3D if model != null else null
	if _magazine != null:
		_seat = _magazine.transform


## A new node of the weapon model [param scene], with the parts that only show during a reload
## hidden.
static func instantiate(scene: PackedScene) -> Node3D:
	var model := scene.instantiate() as Node3D
	var shell := model.find_child("Shell", true, false) as Node3D
	if shell != null:
		shell.visible = false
	return model


## The point [param point_name] (foregrip, magazine, handle, muzzle, butt...) of [param model], as
## a transform relative to the model's parent (so including the model's own transform, the
## weapon's hold offset). Identity if the model has no such point.
static func point_transform(model: Node3D, point_name: String) -> Transform3D:
	var node := model.find_child("point_" + point_name, true, false) as Node3D if model != null else null
	if node == null:
		return Transform3D.IDENTITY
	var transform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != model.get_parent():
		transform = parent.transform * transform
		parent = parent.get_parent() as Node3D
	return transform


## True if [param model] has the point [param point_name].
static func has_point(model: Node3D, point_name: String) -> bool:
	return model != null and model.find_child("point_" + point_name, true, false) != null


## Where the left hand's wrist and rotation go when it holds [param model]'s foregrip, relative to
## the model's parent (the weapon bone).
static func left_hand_target(model: Node3D) -> Transform3D:
	var grip := Transform3D(Basis.IDENTITY, point_transform(model, "foregrip").origin)
	return grip * LEFT_HAND_ON_GRIP


## The reload's moments for [param data]'s weapon.
static func events_for(data: WeaponData) -> Dictionary:
	return SHELL_EVENTS if data.reload_per_shell else MAGAZINE_EVENTS


## Moves the magazine and the shell for a reload of a [param data] weapon that is
## [param progress] through ([method Weapon.get_reload_progress]; -1 when not reloading), now that
## the left hand's bone is at [param left_hand] (a global transform). Outside a reload the magazine
## is in the gun and the shell hidden.
func update(data: WeaponData, progress: float, left_hand: Transform3D) -> void:
	if _model == null or data == null:
		return
	if _magazine != null:
		var follow: bool = progress >= MAGAZINE_EVENTS[&"grab"] and progress < MAGAZINE_EVENTS[&"insert"]
		if follow and not _held:
			# Take it as it is: from then on it moves with the hand.
			_in_hand = left_hand.affine_inverse() * _magazine.global_transform
			_held = true
		elif not follow and _held:
			_magazine.transform = _seat
			_held = false
		if _held:
			_magazine.global_transform = left_hand * _in_hand
	if _shell != null:
		var shown: bool = data.reload_per_shell and progress >= SHELL_EVENTS[&"take"] \
				and progress < SHELL_EVENTS[&"insert"]
		_shell.visible = shown
		if shown:
			# In the palm, lying along the gun as it will go in.
			_shell.global_transform = left_hand * LEFT_HAND_ON_GRIP.affine_inverse()


## True while the magazine is out of the gun, in the hand.
func is_magazine_in_hand() -> bool:
	return _held


## The magazine node, or null.
func get_magazine() -> Node3D:
	return _magazine


## The shell node, or null.
func get_shell() -> Node3D:
	return _shell
