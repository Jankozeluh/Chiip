class_name CrewBody
extends Node3D
## The visible body of a generated crew model (M6, D-053, D-072, D-073): it puts the
## class's model under itself and paints it in a team colour.
##
## Every mesh of the model gets the class's shared [ShaderMaterial] (see [method material_for]
## and characters/crew/crew.gdshader), and the team colour goes into a per-instance shader
## parameter. That is Godot's answer to Unity's MaterialPropertyBlock: the material is shared,
## so all characters of a class cost the same, but each [MeshInstance3D] carries its own
## colour for the parameter declared [code]instance uniform[/code] in the shader.
##
## The body also carries the character's hit zones (D-055, D-074). They are built from the
## class's [HitZones] resource: one [Hitbox] area per box, each under a [BoneAttachment3D] on
## the model's [Skeleton3D], so the zones follow the bones. That is "what you see is what you
## hit": a taller class has a taller head zone, and bots aim at the zones' centres.
##
## A [Character] drives the body through [method set_team_color], [method update_pose] and
## [method reset_pose], and finds its hit zones through [method get_hitboxes].

## The shader every crew model uses.
const SHADER := preload("res://characters/crew/crew.gdshader")

## INTERIM: how far the upper arms swing down from the T-pose, in degrees (75: 15 degrees off vertical).
const INTERIM_ARM_DEGREES := 75.0

## The generated class model, a [code].glb[/code] from assets/models/crew/ (see tools/modelgen).
## Its textures are found next to it: [code]rifleman.glb[/code] uses [code]rifleman_albedo.png[/code]
## and [code]rifleman_mask.png[/code].
@export var model: PackedScene

## The class's hit-zone boxes, a [code]*_hit_zones.tres[/code] written by tools/modelgen. When it
## is empty, the file next to the model is used: [code]rifleman.glb[/code] uses
## [code]rifleman_hit_zones.tres[/code].
@export var hit_zones: HitZones

## One shared material per class model, by model path.
static var _materials: Dictionary = {}

## The colour to paint the team parts in, kept until the model is built.
var _team_color: Color = Teams.FRIENDLY_COLOR
## Every mesh of the instantiated model; they all get the colour.
var _meshes: Array[MeshInstance3D] = []
## The model's skeleton, or null before the model is built.
var _skeleton: Skeleton3D
## Every hit zone box built from [member hit_zones].
var _hitboxes: Array[Hitbox] = []
## The collision shape of each hit zone, parallel to [member _hitboxes].
var _hitbox_shapes: Array[CollisionShape3D] = []
## The bone the crouch sinks (the root of the skeleton), and where it rests.
var _hips_bone: int = -1
var _hips_rest_position: Vector3 = Vector3.ZERO
## How far the hips are lowered right now (negative when crouched), to skip redundant pose updates.
var _crouch_offset: float = 0.0


func _ready() -> void:
	if model == null:
		return
	var instance := model.instantiate() as Node3D
	instance.name = "Model"
	add_child(instance)
	var material := material_for(model.resource_path)
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		_meshes.append(mesh)
	set_team_color(_team_color)
	_skeleton = _find_skeleton(instance)
	if _skeleton != null:
		_hips_bone = _skeleton.find_bone("hips")
		if _hips_bone >= 0:
			_hips_rest_position = _skeleton.get_bone_rest(_hips_bone).origin
		_build_hit_zones()
		_set_interim_pose()


## The material for the class model at [param model_path]: the crew shader with the model's
## albedo and mask textures ([code]x.glb[/code] gives [code]x_albedo.png[/code] and
## [code]x_mask.png[/code]). It is made once per model and shared by every character of
## that class; the team colour is not in it but per instance, see [method set_team_color].
static func material_for(model_path: String) -> ShaderMaterial:
	if _materials.has(model_path):
		return _materials[model_path]
	var texture_base := model_path.get_basename()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", load(texture_base + "_albedo.png"))
	material.set_shader_parameter("mask_texture", load(texture_base + "_mask.png"))
	_materials[model_path] = material
	return material


## Paints the team parts of this body in [param color] (see [method Teams.color_for]).
## Only this character changes: the colour is a per-instance shader parameter on each mesh,
## the shared material isn't touched. Safe to call before the model is built.
func set_team_color(color: Color) -> void:
	_team_color = color
	for mesh in _meshes:
		mesh.set_instance_shader_parameter("team_color", color)


## The colour the team parts are painted in.
func get_team_color() -> Color:
	return _team_color


## Every hit zone of this body (15 on the Rifleman). A [Character] listens to their
## [signal Hitbox.hit] signals.
func get_hitboxes() -> Array[Hitbox]:
	return _hitboxes


## True if the body has a hit zone of [param zone].
func has_zone(zone: Hitbox.Zone) -> bool:
	return _first_shape_of(zone) != null


## The centre of the first hit zone box of [param zone], in world space, as of the last
## skeleton update. Zero if the body has none (check [method has_zone]).
func get_zone_center(zone: Hitbox.Zone) -> Vector3:
	var shape := _first_shape_of(zone)
	return shape.global_position if shape != null else Vector3.ZERO


## Moves the body for this physics tick. The [Character] calls it every tick.
##
## INTERIM (until the AnimationTree of M6 task 6): only the crouch is animated. The hips
## sink by [param crouch_offset] (negative when crouched), and the head, chest and stomach
## zones sink with them, as in CS. The legs sink with the hips too, so crouched feet are
## below the floor for now. The other parameters (speed, top speed, on the ground, time step)
## are for the walk animation and unused yet.
func update_pose(_speed: float, _run_speed: float, crouch_offset: float, _on_ground: bool, _delta: float) -> void:
	if _hips_bone < 0 or is_equal_approx(_crouch_offset, crouch_offset):
		return
	_crouch_offset = crouch_offset
	_skeleton.set_bone_pose_position(_hips_bone, _hips_rest_position + Vector3(0.0, crouch_offset, 0.0))


## Back to standing upright (on respawn): the hips at rest, and the death fall undone.
func reset_pose() -> void:
	rotation = Vector3.ZERO
	if _hips_bone < 0:
		return
	_crouch_offset = 0.0
	_skeleton.set_bone_pose_position(_hips_bone, _hips_rest_position)


## Finds the first [Skeleton3D] under [param root] (the model's).
func _find_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


## Builds one [Hitbox] per box of the class's [HitZones]. Each sits under a [BoneAttachment3D]
## (a child of the skeleton that copies one bone's pose every time the skeleton updates), with
## a box-shaped [CollisionShape3D] at the box's centre in the bone's frame.
func _build_hit_zones() -> void:
	var zones := hit_zones
	if zones == null:
		var path := model.resource_path.get_basename() + "_hit_zones.tres"
		if not ResourceLoader.exists(path):
			push_warning("CrewBody: no hit zones found at %s" % path)
			return
		zones = load(path) as HitZones
	for i in zones.size():
		if _skeleton.find_bone(zones.bones[i]) < 0:
			push_warning("CrewBody: the model has no bone \"%s\"" % zones.bones[i])
			continue
		var hitbox := Hitbox.new()
		hitbox.zone = zones.zones[i] as Hitbox.Zone
		hitbox.name = hitbox.get_zone_name()
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = zones.sizes[i]
		shape.shape = box
		shape.position = zones.centers[i]
		hitbox.add_child(shape)
		var attachment := BoneAttachment3D.new()
		attachment.name = "%s_%s" % [hitbox.name, zones.bones[i]]
		attachment.bone_name = zones.bones[i]
		attachment.add_child(hitbox)
		_skeleton.add_child(attachment)
		_hitboxes.append(hitbox)
		_hitbox_shapes.append(shape)


## INTERIM: the model is in a T-pose, so lower the upper arms until they hang at the sides.
## The AnimationTree of M6 task 6 poses the whole body and replaces this.
func _set_interim_pose() -> void:
	# The bones' rest rotations are the identity, so a pose rotation about Z swings an arm in
	# the model's XY plane: the right arm points +X, and a negative angle swings it down.
	var right_arm := _skeleton.find_bone("upper_arm_r")
	var left_arm := _skeleton.find_bone("upper_arm_l")
	if right_arm >= 0:
		_skeleton.set_bone_pose_rotation(right_arm, Quaternion(Vector3.BACK, deg_to_rad(-INTERIM_ARM_DEGREES)))
	if left_arm >= 0:
		_skeleton.set_bone_pose_rotation(left_arm, Quaternion(Vector3.BACK, deg_to_rad(INTERIM_ARM_DEGREES)))


## The collision shape of the first hit zone of [param zone], or null.
func _first_shape_of(zone: Hitbox.Zone) -> CollisionShape3D:
	for i in _hitboxes.size():
		if _hitboxes[i].zone == zone:
			return _hitbox_shapes[i]
	return null
