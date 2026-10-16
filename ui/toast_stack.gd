class_name ToastStack
extends VBoxContainer
## The toasts (Foundations: TOASTS; mockups 11 and 12): short plates stacked in the middle under the top
## bar, newest at the bottom, each for [code]toast_time_ms[/code] (the theme's "Hud" type). They carry the news that is
## too small for a banner: "Switching sides", "Match point", the bomb picked up, dropped or planted, "Low ammo".
##
## Four kinds ([enum Kind]): news (INK plate, a small TEXT chip), match point (TEXT plate, INK chip and text),
## the bomb planted (ALERT plate, the bomb's icon) and low ammo (INK plate with an ALERT frame). The look is all
## roles of the UI theme ([code]HudToast*[/code]); this script only picks the role, the text and the lifetime.
## The same kind with the same text shown again just starts that toast's time over.
##
## Time is counted in [method _process] deltas, so a pause freezes the toasts where they are. Everything ignores the
## mouse. [RoundHud], [BombHud] and the HUD itself ([code]hud.gd[/code]) are handed this node and call [method show_toast].

## What a toast is about; it decides the plate's look.
enum Kind {
	## News: INK plate, a TEXT chip ("Switching sides", "You picked up the bomb").
	NEUTRAL,
	## A team is one round from winning: TEXT plate, INK chip and text.
	MATCH_POINT,
	## The bomb was planted: ALERT plate with the bomb's icon.
	BOMB,
	## The magazine is nearly empty: INK plate with an ALERT frame.
	LOW_AMMO,
}

## The most toasts showing at once; a newer one pushes the oldest out.
const MAX_TOASTS := 4
## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## Per kind: the plate's role, the chip's role ("" for none), the text's role, and the icon slot ("" for none).
const LOOKS := {
	Kind.NEUTRAL: [&"HudToastNeutral", &"HudToastChip", &"HudPlateLabel", &""],
	Kind.MATCH_POINT: [&"HudToastMatchPoint", &"HudToastChipInk", &"HudPlateInkLabel", &""],
	Kind.BOMB: [&"HudToastBomb", &"", &"HudPlateInkLabel", &"bomb"],
	Kind.LOW_AMMO: [&"HudToastLowAmmo", &"", &"HudPlateAlertLabel", &""],
}

## The toasts showing, oldest first: {"plate": Control, "kind": Kind, "text": String, "left": seconds, "icon": TextureRect or null}.
var _toasts: Array[Dictionary] = []
var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Shows [param text] as a toast of [param kind] (see [enum Kind]).
func show_toast(kind: Kind, text: String) -> void:
	var lifetime := _lifetime()
	for toast in _toasts:
		if toast["kind"] == kind and toast["text"] == text:
			toast["left"] = lifetime
			return
	var look: Array = LOOKS[kind]
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.theme_type_variation = look[0]
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.custom_minimum_size.y = get_theme_constant(&"toast_height", THEME_TYPE)
	# In the tree first: the theme is looked up through the parents.
	add_child(plate)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = &"HudRowIcon"
	plate.add_child(row)
	if look[1] != &"":
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.theme_type_variation = look[1]
		var chip_size := get_theme_constant(&"toast_chip", THEME_TYPE)
		chip.custom_minimum_size = Vector2(chip_size, chip_size)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
	var icon: TextureRect = null
	if look[3] != &"":
		var texture := UiIcons.get_icon(self, look[3])
		if texture != null:
			icon = UiIcons.make_rect(texture, get_theme_color(&"text_on_fill", PALETTE_TYPE), _ui_scale)
			row.add_child(icon)
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.theme_type_variation = look[2]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	UiScale.apply_tree(plate, _ui_scale)
	_toasts.append({"plate": plate, "kind": kind, "text": text, "left": lifetime, "icon": icon})
	while _toasts.size() > MAX_TOASTS:
		_remove(_toasts[0])
	set_process(true)


## Removes every toast at once.
func clear() -> void:
	while not _toasts.is_empty():
		_remove(_toasts[0])


## The texts showing, oldest first. For tests.
func get_texts() -> Array[String]:
	var texts: Array[String] = []
	for toast in _toasts:
		texts.append(toast["text"])
	return texts


## The plate of the toast with [param text] (null when none shows). For tests.
func get_plate(text: String) -> Control:
	for toast in _toasts:
		if toast["text"] == text:
			return toast["plate"]
	return null


## Seconds a toast stays, from the theme.
func get_lifetime() -> float:
	return _lifetime()


## Scales the toasts showing and the ones to come (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(self, factor)
	for toast in _toasts:
		if toast["icon"] != null:
			UiIcons.fit_rect(toast["icon"], factor)


func _process(delta: float) -> void:
	for toast in _toasts.duplicate():
		toast["left"] -= delta
		if toast["left"] <= 0.0:
			_remove(toast)
	if _toasts.is_empty():
		set_process(false)


func _lifetime() -> float:
	return get_theme_constant(&"toast_time_ms", THEME_TYPE) / 1000.0


func _remove(toast: Dictionary) -> void:
	_toasts.erase(toast)
	var plate: Control = toast["plate"]
	if plate.get_parent() == self:
		remove_child(plate)
	plate.queue_free()
