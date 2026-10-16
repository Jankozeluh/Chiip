@tool
class_name KitTextSign
extends Label3D
## A text sign placed in TrenchBroom (the sign_text entity, D-142): pixel-font letters at the
## entity, read from the side its angle points to (the arrow in TrenchBroom), or always facing the
## camera with [member billboard_text]. For distance markers, hints and names on a map ("20 m",
## "SPRAY WALL"). Write "\n" in the text for a new line. A tool script, so the sign also shows in
## Godot's editor.
##
## A [Label3D] is Godot's text drawn in the 3D world (Unity: a TextMeshPro object in world space).

const PIXEL_FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
## The pixel font is drawn at this size and scaled with [member pixel_size].
const FONT_SIZE := 16

## The words on the sign.
@export var sign_text: String = "TEXT"
## How tall a capital letter is, in metres.
@export var letter_height: float = 0.3
## The letters' colour. Keep it light and plain (no team red or blue, D-031).
@export var sign_color: Color = Color(0.92, 0.9, 0.82)
## Always turn to the camera (true) or face the entity's angle like a sign on a wall (false).
@export var billboard_text: bool = false


func _func_godot_apply_properties(properties: Dictionary) -> void:
	sign_text = str(properties.get("text", sign_text)).replace("\\n", "\n")
	letter_height = float(properties.get("letter_height", letter_height))
	var color: Variant = properties.get("color", sign_color)
	if color is Color:
		sign_color = color
	billboard_text = int(properties.get("billboard", 1 if billboard_text else 0)) != 0
	# func_godot turns a point entity so its -Z points along the angle; a label is read from +Z.
	rotate_y(PI)
	_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	text = sign_text
	font = PIXEL_FONT
	font_size = FONT_SIZE
	outline_size = 4
	outline_modulate = Color(0.08, 0.08, 0.08)
	modulate = sign_color
	# Silkscreen's capitals fill about 0.7 of the font size.
	pixel_size = letter_height / (FONT_SIZE * 0.7)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard_text else BaseMaterial3D.BILLBOARD_DISABLED
	# A sign on a wall is read from the front only; one that turns to the camera always is.
	double_sided = billboard_text
	shaded = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
