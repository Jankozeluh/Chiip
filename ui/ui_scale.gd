class_name UiScale
## Scales a Control's font size, outline and position by a factor, so the same
## HUD layout works at different window resolutions. The original values are
## remembered, so it can be applied again with a different factor.


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
