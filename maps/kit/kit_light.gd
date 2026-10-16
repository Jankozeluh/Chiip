@tool
class_name KitLight
extends Node3D
## A lamp of the map kit (D-124): the lamp's model plus a real-time light,
## built from these exported values when the lamp enters the tree. The values
## come from the lamp's generated scene (maps/kit/lights/, tools/modelgen
## props) and, for a lamp placed in TrenchBroom, from the entity's properties
## (light_color, light_energy, light_range, shadows), which func_godot hands to
## [method _func_godot_apply_properties] when the map is built. A tool script,
## so the light also shows in Godot's editor.
##
## Lamps are cheap without shadows: Godot's clustered renderer lights each
## pixel only with the lamps that reach it. Shadows are off by default; a map
## should give only a few lamps shadows (docs/MAPPING.md, D-126).

## The two kinds of light a lamp can have.
enum Kind { OMNI, SPOT }

## Omni light (all around, Unity's point light) or spot light (a cone).
@export var light_kind: Kind = Kind.OMNI
## The light's colour. Warm or neutral only (D-031).
@export var light_color: Color = Color(1.0, 0.75, 0.45)
## Brightness (1 is a normal lamp).
@export var light_energy: float = 1.4
## How far the light reaches, in metres.
@export var light_range: float = 7.0
## Whether it casts shadows (costly; a few per map).
@export var shadows: bool = false
## Where the light sits, in the lamp's space (the bulb).
@export var light_offset: Vector3 = Vector3.ZERO
## Spot lights: how far the beam tilts down from straight ahead (-Z), in degrees.
@export var light_pitch: float = 0.0
## Spot lights: the cone's half angle in degrees.
@export var spot_angle: float = 40.0
## Distance from the camera where the light starts fading out, in metres
## (Godot skips lights that have faded completely).
@export var fade_begin: float = 45.0

var _light: Light3D


func _ready() -> void:
	_build_light()


## Applies a TrenchBroom entity's properties (func_godot calls this on map build).
func _func_godot_apply_properties(properties: Dictionary) -> void:
	if properties.get("light_color") is Color:
		light_color = properties["light_color"]
	if properties.has("light_energy"):
		light_energy = float(properties["light_energy"])
	if properties.has("light_range"):
		light_range = float(properties["light_range"])
	if properties.has("shadows"):
		var value: Variant = properties["shadows"]
		shadows = value == true or str(value) == "1" or str(value).to_lower() == "true"
	if is_inside_tree():
		_build_light()


func _build_light() -> void:
	if _light != null:
		_light.queue_free()
	if light_kind == Kind.SPOT:
		var spot := SpotLight3D.new()
		spot.spot_range = light_range
		spot.spot_angle = spot_angle
		spot.spot_attenuation = 0.8
		spot.rotation_degrees.x = -light_pitch
		_light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = light_range
		_light = omni
	_light.name = "Light"
	_light.position = light_offset
	_light.light_color = light_color
	_light.light_energy = light_energy
	_light.shadow_enabled = shadows
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = fade_begin
	_light.distance_fade_length = 10.0
	# Not saved into any scene: the light is rebuilt from the values above every time.
	add_child(_light, false, Node.INTERNAL_MODE_BACK)


## The light this lamp made (null before it entered the tree).
func get_light() -> Light3D:
	return _light
