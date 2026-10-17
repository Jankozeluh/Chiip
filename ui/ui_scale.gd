class_name UiScale
## Scales a Control's font size, outline, shadow and position by a factor, so the same
## HUD layout works at different window resolutions. The original values are
## remembered, so it can be applied again with a different factor.
##
## [method apply] is for one control placed by offsets;
## [method apply_tree] is for a whole layout built from containers (the HUD).
## Besides sizes and spacing it scales a label's shadow offset, the box of a
## panel or of a label with a frame (its borders, hard shadow and padding: the
## HUD's chips, bars and plates), and the trimmed line box of a label's font
## (D-141). Menus don't use it: they take their look from the UI theme and are
## scaled by [UiTheme] (D-057), which also reaches styleboxes and icons.

## Meta key under which [method apply_tree] remembers a control's unscaled values.
const TREE_META := "ui_tree_base"
## A control with this meta set has its minimum size set by its owner (an icon sized from its
## texture): [method apply_tree] leaves its minimum size alone.
const SKIP_SIZE_META := "ui_scale_skip_size"
## Metas marking the box and the font override that [method apply_tree] put on a control itself.
const OWN_BOX_META := "ui_scale_own_box"
const OWN_FONT_META := "ui_scale_own_font"
## Theme constants that [method apply_tree] scales: a container's spacing, a label's outline and
## the offset of its hard shadow.
const SCALED_CONSTANTS: Array[String] = [
	"separation", "margin_left", "margin_top", "margin_right", "margin_bottom", "outline_size",
	"shadow_offset_x", "shadow_offset_y",
]


## Scales one control placed by offsets: its font size, outline and offsets.
static func apply(control: Control, factor: float) -> void:
	if not control.has_meta("ui_base"):
		control.set_meta("ui_base", {
			"font_size": control.get_theme_font_size("font_size"),
			"outline": control.get_theme_constant("outline_size"),
			"offsets": [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
		})
	var base: Dictionary = control.get_meta("ui_base")
	control.add_theme_font_size_override("font_size", maxi(1, roundi(base.font_size * factor)))
	control.add_theme_constant_override("outline_size", maxi(0, roundi(base.outline * factor)))
	var offsets: Array = base.offsets
	control.offset_left = roundf(offsets[0] * factor)
	control.offset_top = roundf(offsets[1] * factor)
	control.offset_right = roundf(offsets[2] * factor)
	control.offset_bottom = roundf(offsets[3] * factor)


## Scales [param root] and every control below it: font sizes (labels and
## buttons), minimum sizes, container spacing and label outlines, and the
## offsets of controls that sit directly in a plain node rather than in a
## container (containers place their own children). Each control's original
## values are remembered the first time, so this can run again with another
## factor, and controls made later can be passed in too.
static func apply_tree(root: Node, factor: float) -> void:
	if root is Control:
		_scale_control(root as Control, factor)
	for child in root.get_children():
		apply_tree(child, factor)


static func _scale_control(control: Control, factor: float) -> void:
	if not control.has_meta(TREE_META):
		var base := {"minimum_size": control.custom_minimum_size, "constants": {}}
		if control is Label or control is Button:
			base["font_size"] = control.get_theme_font_size("font_size")
		for constant_name in SCALED_CONSTANTS:
			if control.has_theme_constant(constant_name):
				base["constants"][constant_name] = control.get_theme_constant(constant_name)
		if not control.get_parent() is Container:
			base["offsets"] = [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]
		control.set_meta(TREE_META, base)
	var original: Dictionary = control.get_meta(TREE_META)
	if not control.has_meta(SKIP_SIZE_META):
		var minimum_size: Vector2 = original["minimum_size"]
		control.custom_minimum_size = (minimum_size * factor).round()
	if original.has("font_size"):
		control.add_theme_font_size_override("font_size", maxi(1, roundi(int(original["font_size"]) * factor)))
	var constants: Dictionary = original["constants"]
	for constant_name: String in constants:
		control.add_theme_constant_override(constant_name, roundi(int(constants[constant_name]) * factor))
	if original.has("offsets"):
		var offsets: Array = original["offsets"]
		control.offset_left = roundf(offsets[0] * factor)
		control.offset_top = roundf(offsets[1] * factor)
		control.offset_right = roundf(offsets[2] * factor)
		control.offset_bottom = roundf(offsets[3] * factor)
	_scale_look(control, original, factor)


## The part of [method _scale_control] that the theme holds as resources: the box of a panel (or
## the frame of a label) and a label's trimmed font. The unscaled ones are remembered with the role
## ([member Control.theme_type_variation]) they came from, so a control whose role changed (a
## chip that died) is read again; call [method apply_tree] on it after changing its role. A box
## or font that code set on the control itself (an override of its own) is left alone.
static func _scale_look(control: Control, original: Dictionary, factor: float) -> void:
	var box_item := _box_item(control)
	var role := control.theme_type_variation
	# The box is read again when the role changed, or when the theme was recoloured (its boxes are copies then, D-210).
	if original.get("role") != role or original.get("epoch", 0) != UiTheme.scheme_epoch:
		original["role"] = role
		original["epoch"] = UiTheme.scheme_epoch
		original["box"] = null
		original["font"] = null
		if box_item != &"":
			if control.has_meta(OWN_BOX_META):
				control.remove_theme_stylebox_override(box_item)
				control.remove_meta(OWN_BOX_META)
			if not control.has_theme_stylebox_override(box_item):
				var box := control.get_theme_stylebox(box_item)
				original["box"] = box if box is StyleBoxFlat else null
		if control is Label:
			if control.has_meta(OWN_FONT_META):
				control.remove_theme_font_override("font")
				control.remove_meta(OWN_FONT_META)
			if not control.has_theme_font_override("font"):
				var font := control.get_theme_font("font") as FontVariation
				original["font"] = font if font != null and (font.spacing_top != 0 or font.spacing_bottom != 0) else null
	if original["box"] != null:
		control.add_theme_stylebox_override(box_item, UiTheme.scale_box(original["box"], factor))
		control.set_meta(OWN_BOX_META, true)
	if original["font"] != null:
		var scaled := (original["font"] as FontVariation).duplicate() as FontVariation
		scaled.spacing_top = roundi(scaled.spacing_top * factor)
		scaled.spacing_bottom = roundi(scaled.spacing_bottom * factor)
		control.add_theme_font_override("font", scaled)
		control.set_meta(OWN_FONT_META, true)


## The name of the stylebox item that draws a control's box, or "" for a control without one.
static func _box_item(control: Control) -> StringName:
	if control is Panel or control is PanelContainer:
		return &"panel"
	if control is Label:
		return &"normal"
	return &""
