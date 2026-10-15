class_name UiTheme
extends RefCounted
## Scales Chiip's UI theme for the window, so a menu looks the same at 720
## pixels tall and exactly 1.5× as big at 1080 (D-057).
##
## Menus are laid out for a 720-pixel-tall window. Everything they draw with
## comes from the theme ([code]ui/chiip_theme.tres[/code]): font sizes, borders,
## margins, spacing, icon sizes. [method scaled] makes a copy of the theme with
## all of these multiplied by a factor, and [method apply] hands that copy to a
## menu. That is the whole trick: every control below the menu looks up its
## style in the copy, so nothing else needs to know about scaling. What a
## theme can't hold, a node's own [code]custom_minimum_size[/code] and any
## per-node font-size or spacing override, [method apply] scales too, remembering
## the original values so it can run again with another factor.
##
## The HUD (not a menu) is still scaled by [UiScale].
##
## Use it from a menu's [code]set_ui_scale(factor)[/code]:
## [codeblock]
## func set_ui_scale(factor: float) -> void:
##     UiTheme.apply(self, factor)
## [/codeblock]
## A menu's parts should take their look from theme type variations (see
## tools/make_ui_theme.gd) rather than from stylebox overrides on nodes: a
## stylebox override is not scaled.

## Where the theme is.
const THEME_PATH := "res://ui/chiip_theme.tres"
## How many scaled copies are kept. Resizing a window asks for many factors.
const MAX_CACHED := 4
## Meta key under which a control's unscaled sizes are remembered.
const BASE_META := "ui_theme_base"
## Meta key marking a control that [method apply] gave a theme.
const THEME_META := "ui_theme_assigned"
## Theme constants that are switches or counts, not sizes in pixels, so scaling leaves them alone.
const UNSCALED_CONSTANTS: Array[String] = [
	"center_grabber", "modulate_arrow", "draw_guides", "draw_relationship_lines", "scrollbar_margin",
]
## Per-node constant overrides that [method apply] scales (spacing, margins, outlines).
const SCALED_OVERRIDES: Array[String] = [
	"separation", "h_separation", "v_separation", "margin_left", "margin_top", "margin_right",
	"margin_bottom", "outline_size",
]

## Scaled copies already made: factor in thousandths → Theme (oldest first).
static var _cache: Dictionary = {}


## The unscaled theme (the project theme).
static func get_base() -> Theme:
	return load(THEME_PATH) as Theme


## The theme scaled by [param factor]: font sizes, spacing, margins, borders
## and icon sizes multiplied (rounded to whole pixels). For 1.0 it is the
## base theme itself. Copies are kept for reuse.
static func scaled(factor: float) -> Theme:
	if is_equal_approx(factor, 1.0):
		return get_base()
	var key := roundi(factor * 1000.0)
	if _cache.has(key):
		return _cache[key]
	var theme := scale_theme(get_base(), factor)
	if _cache.size() >= MAX_CACHED:
		_cache.erase(_cache.keys()[0])
	_cache[key] = theme
	return theme


## Makes a scaled copy of [param base]. Type variations, colors and fonts are
## copied as they are; font sizes, constants (except the switches in
## [constant UNSCALED_CONSTANTS]), styleboxes (borders, corners, margins) and
## icons (nearest-neighbor, so pixel art stays crisp) are multiplied.
static func scale_theme(base: Theme, factor: float) -> Theme:
	var theme := Theme.new()
	theme.default_font = base.default_font
	theme.default_font_size = base.default_font_size if base.default_font_size <= 0 \
			else scale_pixels(base.default_font_size, factor)
	theme.default_base_scale = base.default_base_scale
	# One scaled copy per resource, so items that share a stylebox or icon still share it.
	var made := {}
	for type in base.get_type_list():
		var variation_base := base.get_type_variation_base(type)
		if variation_base != &"":
			theme.set_type_variation(type, variation_base)
		for item in base.get_color_list(type):
			theme.set_color(item, type, base.get_color(item, type))
		for item in base.get_font_list(type):
			theme.set_font(item, type, base.get_font(item, type))
		for item in base.get_font_size_list(type):
			theme.set_font_size(item, type, scale_pixels(base.get_font_size(item, type), factor))
		for item in base.get_constant_list(type):
			var value := base.get_constant(item, type)
			theme.set_constant(item, type, value if item in UNSCALED_CONSTANTS else scale_pixels(value, factor))
		for item in base.get_icon_list(type):
			var icon := base.get_icon(item, type)
			if not made.has(icon):
				made[icon] = _scale_icon(icon, factor)
			theme.set_icon(item, type, made[icon])
		for item in base.get_stylebox_list(type):
			var box := base.get_stylebox(item, type)
			if not made.has(box):
				made[box] = _scale_stylebox(box, factor)
			theme.set_stylebox(item, type, made[box])
	return theme


## [param value] times [param factor], rounded to a whole pixel (never below 1 for a positive value).
static func scale_pixels(value: int, factor: float) -> int:
	var result := roundi(value * factor)
	return maxi(1, result) if value > 0 else result


## Gives the menu [param root] the theme scaled by [param factor], and scales
## the sizes the theme can't hold: every control's [code]custom_minimum_size[/code]
## and its font-size and spacing overrides (originals remembered on first use).
## [param root] can be a control, or a node such as a [CanvasLayer] whose
## controls get the theme. Calling it again, also on a part of a menu that was
## already handled, with the same or another factor is fine.
static func apply(root: Node, factor: float) -> void:
	_assign_theme(root, scaled(factor))
	apply_sizes(root, factor)


## Only the second half of [method apply]: scales the controls' own
## [code]custom_minimum_size[/code] and font-size and spacing overrides below
## [param root], without touching any theme. For controls added to a menu later
## (the scoreboard's rows), which inherit the menu's theme already.
static func apply_sizes(root: Node, factor: float) -> void:
	_scale_sizes(root, factor)


## Gives the controls at the top of [param node] the [param theme] (children inherit it).
static func _assign_theme(node: Node, theme: Theme) -> void:
	if node is Control:
		var control := node as Control
		control.theme = theme
		control.set_meta(THEME_META, true)
		# Pixel art must not be smoothed, not even at half-pixel positions.
		control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for child in control.get_children():
			_forget_nested_themes(child)
		return
	for child in node.get_children():
		_assign_theme(child, theme)


## A control inside a menu may have been handed its own theme by an earlier
## [method apply] of just that part; drop it, so the menu's theme (which can
## have another factor now) is the one that counts.
static func _forget_nested_themes(node: Node) -> void:
	if node is Control and node.has_meta(THEME_META):
		(node as Control).theme = null
		node.remove_meta(THEME_META)
	for child in node.get_children():
		_forget_nested_themes(child)


static func _scale_sizes(node: Node, factor: float) -> void:
	if node is Control:
		_scale_control(node as Control, factor)
	for child in node.get_children():
		_scale_sizes(child, factor)


static func _scale_control(control: Control, factor: float) -> void:
	if not control.has_meta(BASE_META):
		var base := {"minimum_size": control.custom_minimum_size, "constants": {}}
		if control.has_theme_font_size_override("font_size"):
			base["font_size"] = control.get_theme_font_size("font_size")
		for constant_name in SCALED_OVERRIDES:
			if control.has_theme_constant_override(constant_name):
				base["constants"][constant_name] = control.get_theme_constant(constant_name)
		control.set_meta(BASE_META, base)
	var original: Dictionary = control.get_meta(BASE_META)
	var minimum_size: Vector2 = original["minimum_size"]
	control.custom_minimum_size = (minimum_size * factor).round()
	if original.has("font_size"):
		control.add_theme_font_size_override("font_size", scale_pixels(int(original["font_size"]), factor))
	var constants: Dictionary = original["constants"]
	for constant_name: String in constants:
		control.add_theme_constant_override(constant_name, scale_pixels(int(constants[constant_name]), factor))


## A copy of [param box] with its borders, corners, margins and shadow multiplied.
static func _scale_stylebox(box: StyleBox, factor: float) -> StyleBox:
	var copy := box.duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var margin := box.get_content_margin(side)
		if margin >= 0.0:
			copy.set_content_margin(side, roundf(margin * factor))
	if copy is StyleBoxFlat:
		var flat := copy as StyleBoxFlat
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			flat.set_border_width(side, scale_pixels(flat.get_border_width(side), factor))
			flat.set_expand_margin(side, roundf(flat.get_expand_margin(side) * factor))
		for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_RIGHT, CORNER_BOTTOM_LEFT]:
			flat.set_corner_radius(corner, scale_pixels(flat.get_corner_radius(corner), factor))
		flat.shadow_size = scale_pixels(flat.shadow_size, factor)
		flat.shadow_offset = (flat.shadow_offset * factor).round()
	elif copy is StyleBoxLine:
		var line := copy as StyleBoxLine
		line.thickness = scale_pixels(line.thickness, factor)
		line.grow_begin = roundf(line.grow_begin * factor)
		line.grow_end = roundf(line.grow_end * factor)
	elif copy is StyleBoxTexture:
		var textured := copy as StyleBoxTexture
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			textured.set_texture_margin(side, roundf(textured.get_texture_margin(side) * factor))
			textured.set_expand_margin(side, roundf(textured.get_expand_margin(side) * factor))
	return copy


## [param texture] resized by [param factor] with nearest-neighbor sampling.
static func _scale_icon(texture: Texture2D, factor: float) -> Texture2D:
	if texture == null:
		return null
	var source := texture.get_image()
	if source == null or source.is_compressed():
		return texture
	# get_image() can hand out the texture's own image, which resizing would change for everyone.
	var image := source.duplicate() as Image
	image.resize(scale_pixels(image.get_width(), factor), scale_pixels(image.get_height(), factor), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
