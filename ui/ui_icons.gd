class_name UiIcons
extends RefCounted
## The icon slots of the UI (D-131): named places for the pixel icon set the
## mockups ask for (weapons, grenades, gear, the bomb, classes, the headshot
## mark, health), filled before the icons themselves exist.
##
## An icon fills its slot when a PNG named after the slot is in
## [constant FOLDER] (for example [code]assets/ui/icons/headshot.png[/code])
## and the UI theme is rebuilt (tools/make_ui_theme.gd puts every one it finds
## into the theme type [constant THEME_TYPE]). Screens ask with
## [method get_icon], which goes through the theme, so icons scale with the UI
## like every other theme icon (nearest-neighbor, crisp, D-057). An empty slot
## answers null and the screen shows its text instead ("HS", "+"), so nothing
## breaks while the icons are missing. (M7's generator renders weapon and gear
## icons into its weapon data; a screen that has one of those should prefer
## the slot's icon when the slot is filled, so a drawn icon set replaces the
## rendered one.)
##
## Draw icons on a grid of 2 × 2 px cells at the size they appear at 720p
## (16 × 16 for a mark next to 16 px text, 32 × 32 next to 32 px numbers;
## weapons may be wider), with nearest filtering (the import preset of
## assets/ui/).

## Where the icon PNGs go.
const FOLDER := "res://assets/ui/icons/"
## The theme type that holds them (a custom type, like "Palette").
const THEME_TYPE := &"Icons"
## The focus chip, the 8 px square (assets/ui/chip.png). It is in the same theme type but is not a slot:
## a button that shows it only while it is focused or hovered (the pause menu, the match-end screen) asks
## for it with [code]UiIcons.get_icon(button, UiIcons.CHIP)[/code], so it is scaled with the UI like the
## slots (a button's own [code]icon[/code] property is not).
const CHIP := &"chip"

## Every slot, by group (UI_MOCKUPS.md, item 16). A slot's name is the PNG's
## file name without ".png". Weapons and grenades are named like M7's weapon
## ids ([code]WeaponData.id[/code]), classes like [member ClassData.id].
const WEAPONS: Array[StringName] = [
	&"rifle", &"carbine", &"smg", &"shotgun", &"sniper", &"pistol", &"hand_cannon", &"knife",
]
const GRENADES: Array[StringName] = [&"frag", &"flashbang", &"smoke"]
const GEAR: Array[StringName] = [&"armor", &"helmet", &"defuse_kit", &"bomb"]
const CLASSES: Array[StringName] = [&"rifleman", &"bulwark", &"marksman", &"scout"]
const MARKS: Array[StringName] = [&"headshot", &"health"]


## Every slot name, in the order of the groups above.
static func all_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	for group: Array[StringName] in [WEAPONS, GRENADES, GEAR, CLASSES, MARKS]:
		slots.append_array(group)
	return slots


## The icon in [param slot], as [param control] sees it (scaled with the menu
## or HUD it is in), or null while the slot is empty.
static func get_icon(control: Control, slot: StringName) -> Texture2D:
	if not control.has_theme_icon(slot, THEME_TYPE):
		return null
	return control.get_theme_icon(slot, THEME_TYPE)


## True when [param slot] has an icon for [param control].
static func has_icon(control: Control, slot: StringName) -> bool:
	return control.has_theme_icon(slot, THEME_TYPE)


## The PNG path of [param slot] (whether it exists or not).
static func path_for(slot: StringName) -> String:
	return "%s%s.png" % [FOLDER, slot]


## A [TextureRect] for a row of the HUD that shows [param texture], [param factor] times its own size (the HUD's scale),
## tinted [param tint] (the icons are white). Crisp, takes no mouse clicks, and [UiScale] leaves its size alone: call
## [method fit_rect] when the scale changes.
static func make_rect(texture: Texture2D, tint: Color, factor: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.set_meta(UiScale.SKIP_SIZE_META, true)
	fit_rect(rect, factor)
	return rect


## Sizes [param rect] to its texture times [param factor], in whole pixels.
static func fit_rect(rect: TextureRect, factor: float) -> void:
	rect.custom_minimum_size = (rect.texture.get_size() * factor).round()
