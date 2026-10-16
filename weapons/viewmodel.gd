class_name Viewmodel
extends RefCounted
## The first-person viewmodel's own layer (M11, D-155): the arms, the gun and the muzzle flash are
## drawn by viewmodel shaders ([code]shaders/viewmodel.gdshaderinc[/code]) with their own field of
## view ([constant FOV]) and in the nearest sliver of the depth buffer, so they stay in front of a
## wall you stand against, as in CS. They render in the world's own low-res viewport, so they are
## lit by the map's lights and pixelated and palette-limited like the rest of the picture.
##
## [method prepare] gives every mesh under a viewmodel its viewmodel material: the crew's arms
## [code]characters/crew/crew_viewmodel.gdshader[/code], every gun surface
## [code]weapons/viewmodel_gun.gdshader[/code] with its own texture.

## The viewmodel's vertical field of view in degrees: the camera's at the default FOV (CS's 90 across
## a 4:3 screen), so the gun looks the same at every FOV setting and while zoomed.
const FOV := 73.74
## Must match VIEWMODEL_NEAR and VIEWMODEL_DEPTH_SHARE in shaders/viewmodel.gdshaderinc.
const NEAR := 0.01
const DEPTH_SHARE := 0.02
## How much bigger the viewmodel's meshes count for the camera's culling (metres): with a narrow FOV
## setting the viewmodel's wider view shows parts the camera alone would cull.
const CULL_MARGIN := 1.0

const CREW_SHADER := preload("res://characters/crew/crew_viewmodel.gdshader")
const GUN_SHADER := preload("res://weapons/viewmodel_gun.gdshader")

## Viewmodel materials made so far, by the material they stand in for.
static var _made: Dictionary = {}


## Gives every mesh under [param root] its viewmodel material (crew arms and gun surfaces), no
## shadow and a wider culling margin. Safe to call again on the same nodes.
static func prepare(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = CULL_MARGIN
		if mesh.material_override != null:
			mesh.material_override = material_for(mesh.material_override)
			continue
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_surface_override_material(surface)
			if source == null:
				source = mesh.mesh.surface_get_material(surface)
			if source != null:
				mesh.set_surface_override_material(surface, material_for(source))


## The viewmodel version of [param source]: the crew material's textures on the crew viewmodel
## shader, a gun's imported material's texture and colour on the gun one. Made once per source.
## A material that already is a viewmodel one, or one it can't convert, comes back unchanged.
static func material_for(source: Material) -> Material:
	if is_viewmodel_material(source):
		return source
	if _made.has(source):
		return _made[source]
	var made: Material = source
	if source is ShaderMaterial and (source as ShaderMaterial).shader == CrewBody.SHADER:
		var crew := ShaderMaterial.new()
		crew.shader = CREW_SHADER
		for parameter in [&"albedo_texture", &"mask_texture", &"glow_energy"]:
			var value: Variant = (source as ShaderMaterial).get_shader_parameter(parameter)
			if value != null:
				crew.set_shader_parameter(parameter, value)
		made = crew
	elif source is BaseMaterial3D:
		var gun := ShaderMaterial.new()
		gun.shader = GUN_SHADER
		gun.set_shader_parameter(&"albedo_texture", (source as BaseMaterial3D).albedo_texture)
		gun.set_shader_parameter(&"albedo_color", (source as BaseMaterial3D).albedo_color)
		made = gun
	_made[source] = made
	return made


## True for a material drawn by one of the viewmodel shaders.
static func is_viewmodel_material(material: Material) -> bool:
	if not material is ShaderMaterial:
		return false
	var shader := (material as ShaderMaterial).shader
	return shader != null and shader.code.contains("viewmodel_position(")


## The depth-buffer value (reverse Z: 1 at the near plane, 0 far away) a viewmodel point
## [param distance] metres in front of the camera gets: the shaders' formula, for the checks.
static func clip_depth(distance: float) -> float:
	return 1.0 - DEPTH_SHARE * (1.0 - NEAR / maxf(distance, 1e-4))


## The depth-buffer value the camera gives a world point [param distance] metres in front of it
## (Godot's reverse-Z perspective with near plane [param near] and far plane [param far]).
static func world_depth(distance: float, near: float, far: float) -> float:
	return (near * (far - distance)) / (distance * (far - near))
