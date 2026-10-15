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
## A [Character] drives it through [method set_team_color], the same call [SoldierBody] has,
## so the character works with either body.

## The shader every crew model uses.
const SHADER := preload("res://characters/crew/crew.gdshader")

## The generated class model, a [code].glb[/code] from assets/models/crew/ (see tools/modelgen).
## Its textures are found next to it: [code]rifleman.glb[/code] uses [code]rifleman_albedo.png[/code]
## and [code]rifleman_mask.png[/code].
@export var model: PackedScene

## One shared material per class model, by model path.
static var _materials: Dictionary = {}

## The colour to paint the team parts in, kept until the model is built.
var _team_color: Color = Teams.FRIENDLY_COLOR
## Every mesh of the instantiated model; they all get the colour.
var _meshes: Array[MeshInstance3D] = []


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
