class_name UiScale
## Scales a Control's font size, outline and position by a factor, so the same
## HUD layout works at different window resolutions. The original values are
## remembered, so it can be applied again with a different factor.
##
## [method apply] is for one control placed by offsets (the old HUD labels);
## [method apply_tree] is for a whole layout built from containers (the round
## HUD). Menus don't use it: they take their look from the UI theme and are
## scaled by [UiTheme] (D-057), which also reaches styleboxes and icons.

## Meta key under which [method apply_tree] remembers a control's unscaled values.
const TREE_META := "ui_tree_base"
## Theme constants that [method apply_tree] scales: a container's spacing and a label's outline.
const SCALED_CONSTANTS: Array[String] = [
	"separation", "margin_left", "margin_top", "margin_right", "margin_bottom", "outline_size",
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
