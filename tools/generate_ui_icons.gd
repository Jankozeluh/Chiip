extends SceneTree
## Tool: draws the pixel-art icons of Chiip's UI and saves them as PNG files
## (D-057, D-139):
## - the theme's control icons into assets/ui/ (check marks, radio dots, the
##   switch of a check button, the slider knob, arrows, the list marker, and the
##   "chip", the 8 px square that marks the focused menu item);
## - the icon set of the user's mockups into assets/ui/icons/: 8 weapons, 3
##   grenades, armor, helmet, defuse kit, bomb, the 4 classes, headshot and
##   health, named after their slots ([UiIcons]).
##
## Run from the project folder, then let Godot import the new files, then
## rebuild the theme, which refers to them:
##
##     Godot --headless --path . --quit-after 100 --script res://tools/generate_ui_icons.gd
##     Godot --headless --path . --import
##     Godot --headless --path . --quit-after 100 --script res://tools/make_ui_theme.gd
##
## Control icons are drawn as a grid of "cells" (a letter per cell, below) and
## each cell becomes a CELL × CELL block of pixels, so one cell is as big as one
## pixel of the pixel font at 16 px (2 × 2). When the UI is scaled for a bigger
## window the theme resizes the icons with nearest-neighbor scaling, so a cell
## stays a perfect square at 1.5× (3 × 3) and 2× (4 × 4). Colors come from
## tools/ui_palette.gd.
##
## The icon set is copied from the mockup ("Icon.dc.html"): each icon is a list
## of rectangles [x, y, width, height] on a 32 × 16 (weapons) or 16 × 16 grid,
## one colour, one image pixel per grid cell. They are drawn white so a screen
## can tint them (a node's modulate) to any colour, as the mockup does. The
## headshot mark is drawn "even-odd": where rectangles overlap, they cut a hole.

const Palette := preload("res://tools/ui_palette.gd")

const OUTPUT_FOLDER := "res://assets/ui/"
## Where the icon set goes (the slots of [UiIcons]).
const ICON_FOLDER := "res://assets/ui/icons/"
## Pixels per cell of a control icon (the font's pixel at 16 px).
const CELL := 2

## The mockup's icons, by slot name: [grid width, grid height, even-odd, rectangles].
## (The mockup calls hand_cannon "handcannon", frag "he", flashbang "flash" and defuse_kit "kit".)
const ICON_SET := {
	&"rifle": [32, 16, false, [[0,5,2,5],[2,6,6,2],[2,8,3,1],[8,5,11,3],[19,5,6,2],[25,6,7,1],[27,4,1,2],[12,4,2,1],[13,8,3,2],[14,10,3,2],[15,12,3,1],[9,8,2,3],[8,10,2,2]]],
	&"carbine": [32, 16, false, [[0,5,2,4],[2,6,5,2],[7,6,1,1],[8,5,10,3],[9,4,8,1],[18,5,7,2],[25,6,6,1],[23,3,1,2],[12,8,3,5],[8,8,2,3],[7,10,2,2]]],
	&"smg": [32, 16, false, [[0,5,6,1],[0,8,6,1],[0,6,1,2],[6,5,13,3],[19,6,5,1],[8,4,1,1],[17,4,1,1],[11,8,2,6],[7,8,2,3],[6,10,2,2]]],
	&"shotgun": [32, 16, false, [[0,5,2,4],[2,6,6,2],[2,8,2,1],[8,5,7,3],[15,5,16,2],[15,7,12,1],[17,7,6,2],[8,8,2,2],[10,8,3,1]]],
	&"sniper": [32, 16, false, [[0,5,2,4],[2,6,7,2],[2,8,4,1],[9,6,8,2],[10,3,8,2],[12,5,1,1],[16,5,1,1],[17,6,15,1],[15,8,1,1],[13,8,2,2],[9,8,2,2]]],
	&"pistol": [32, 16, false, [[10,5,12,3],[21,4,1,1],[11,8,3,2],[10,10,3,3],[14,8,2,1],[15,9,1,1]]],
	&"hand_cannon": [32, 16, false, [[11,4,6,4],[10,3,2,1],[17,5,10,2],[26,4,1,1],[11,8,2,2],[9,8,2,1],[9,9,3,4],[13,8,2,1]]],
	&"knife": [32, 16, false, [[2,5,1,3],[3,5,9,3],[12,4,2,6],[14,5,13,3],[27,6,2,2],[29,7,1,1]]],
	&"frag": [16, 16, false, [[6,3,4,2],[10,2,3,1],[12,3,1,4],[2,2,3,1],[2,3,1,2],[5,5,6,1],[4,6,8,7],[5,13,6,1]]],
	&"flashbang": [16, 16, false, [[6,2,4,2],[10,3,2,1],[11,4,1,4],[5,4,6,3],[5,8,6,2],[5,11,6,3]]],
	&"smoke": [16, 16, false, [[6,2,4,2],[4,4,8,2],[4,7,8,7],[11,0,2,2],[13,1,2,2]]],
	&"armor": [16, 16, false, [[2,2,4,3],[10,2,4,3],[2,5,12,8],[3,13,10,1]]],
	&"helmet": [16, 16, false, [[5,3,6,1],[3,4,10,2],[2,6,12,4],[1,10,14,2],[3,12,1,2],[12,12,1,2]]],
	&"defuse_kit": [16, 16, false, [[6,3,4,1],[5,4,1,1],[10,4,1,1],[2,5,12,3],[2,9,12,4]]],
	&"bomb": [16, 16, false, [[11,2,3,1],[12,3,1,4],[2,7,12,2],[2,9,2,3],[9,9,5,3],[2,12,12,2],[5,5,1,2],[6,4,4,1]]],
	&"rifleman": [16, 16, false, [[5,1,6,2],[4,3,8,2],[5,5,6,3],[6,8,4,1],[2,9,12,7]]],
	&"bulwark": [16, 16, false, [[4,1,8,7],[6,8,4,2],[1,9,4,1],[11,9,4,1],[0,10,16,6]]],
	&"marksman": [16, 16, false, [[6,0,4,1],[5,1,6,1],[4,2,8,7],[5,9,6,1],[3,10,10,2],[2,12,12,4]]],
	&"scout": [16, 16, false, [[7,0,2,1],[5,1,6,2],[5,3,6,5],[6,8,4,2],[13,4,1,6],[3,10,10,6]]],
	&"headshot": [16, 16, true, [[5,1,6,1],[4,2,8,1],[3,3,10,7],[4,10,8,1],[5,11,6,1],[6,12,4,2],[7,5,2,2]]],
	&"health": [16, 16, false, [[6,2,4,12],[2,6,4,4],[10,6,4,4]]],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_FOLDER))
	_check_boxes()
	_radio_buttons()
	_switches()
	_slider_grabbers()
	_arrows()
	_popup_markers()
	_chip()
	_icon_set()
	quit()


## Check boxes: a square LINE frame; checked, the accent with an ink check mark. Also used by popup menus.
func _check_boxes() -> void:
	var box: Array[String] = [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########",
	]
	var checked: Array[String] = [
		"AAAAAAAA",
		"AAAAAAAA",
		"AAAAAACA",
		"AAAAACAA",
		"AACACAAA",
		"AAACAAAA",
		"AAAAAAAA",
		"AAAAAAAA",
	]
	var enabled := {"#": Palette.LINE_COLOR, ".": Palette.INSET, "A": Palette.ACCENT, "C": Palette.TEXT_ON_FILL}
	var disabled := {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.INSET, "A": Palette.MUTE, "C": Palette.INSET}
	_save("checkbox_off", box, enabled)
	_save("checkbox_on", checked, enabled)
	_save("checkbox_off_disabled", box, disabled)
	_save("checkbox_on_disabled", checked, disabled)


## Radio buttons: a round LINE frame, with an accent dot when selected.
func _radio_buttons() -> void:
	var round_box: Array[String] = [
		"..####..",
		".#....#.",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		".#....#.",
		"..####..",
	]
	var selected: Array[String] = [
		"..####..",
		".#....#.",
		"#......#",
		"#..DD..#",
		"#..DD..#",
		"#......#",
		".#....#.",
		"..####..",
	]
	# '.' outside the circle is transparent, so the corners need their own letter.
	round_box = _fill_inside(round_box)
	selected = _fill_inside(selected)
	var enabled := {"#": Palette.LINE_COLOR, "o": Palette.INSET, "D": Palette.ACCENT}
	var disabled := {"#": Palette.BUTTON_BORDER_DISABLED, "o": Palette.INSET, "D": Palette.MUTE}
	_save("radio_off", round_box, enabled)
	_save("radio_on", selected, enabled)
	_save("radio_off_disabled", round_box, disabled)
	_save("radio_on_disabled", selected, disabled)


## The switch of a check button: a framed track with a square block, left when off, right (on the accent) when on.
func _switches() -> void:
	var off: Array[String] = [
		"################",
		"#KKKKKK........#",
		"#KKKKKK........#",
		"#KKKKKK........#",
		"#KKKKKK........#",
		"#KKKKKK........#",
		"#KKKKKK........#",
		"################",
	]
	var on: Array[String] = [
		"################",
		"#........KKKKKK#",
		"#........KKKKKK#",
		"#........KKKKKK#",
		"#........KKKKKK#",
		"#........KKKKKK#",
		"#........KKKKKK#",
		"################",
	]
	_save("switch_off", off, {"#": Palette.LINE_COLOR, ".": Palette.INSET, "K": Palette.MUTE})
	_save("switch_on", on, {"#": Palette.ACCENT, ".": Palette.ACCENT, "K": Palette.TEXT_ON_FILL})
	_save("switch_off_disabled", off, {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.INSET, "K": Palette.HANDLE_DISABLED})
	_save("switch_on_disabled", on, {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.INSET, "K": Palette.HANDLE_DISABLED})


## The knob you drag on a slider: a flat 16 px square (Foundations: SLIDER).
func _slider_grabbers() -> void:
	var grabber: Array[String] = [
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
		"HHHHHHHH",
	]
	_save("slider_grabber", grabber, {"H": Palette.HANDLE})
	_save("slider_grabber_highlight", grabber, {"H": Palette.HANDLE})
	_save("slider_grabber_disabled", grabber, {"H": Palette.HANDLE_DISABLED})


## Triangles: the drop-down arrow of an option button, and the arrows of a tab bar that is too narrow.
func _arrows() -> void:
	var colors := {"#": Palette.TEXT}
	_save("arrow_down", [
		"#######",
		".#####.",
		"..###..",
		"...#...",
	], colors)
	_save("arrow_left", [
		"...#",
		"..##",
		".###",
		"####",
		".###",
		"..##",
		"...#",
	], colors)
	_save("arrow_right", [
		"#...",
		"##..",
		"###.",
		"####",
		"###.",
		"##..",
		"#...",
	], colors)
	var bright := {"#": Palette.ACCENT}
	_save("arrow_left_highlight", [
		"...#",
		"..##",
		".###",
		"####",
		".###",
		"..##",
		"...#",
	], bright)
	_save("arrow_right_highlight", [
		"#...",
		"##..",
		"###.",
		"####",
		"###.",
		"##..",
		"#...",
	], bright)


## The mark beside the chosen entry of a drop-down list (popup menus draw their
## "radio" items with it): a small accent arrow, and an empty one of the same
## size for the entries that aren't chosen, so the text lines up.
func _popup_markers() -> void:
	_save("popup_marker_on", [
		"#..",
		"##.",
		"###",
		"##.",
		"#..",
	], {"#": Palette.ACCENT})
	_save("popup_marker_off", [
		"...",
		"...",
		"...",
		"...",
		"...",
	], {})


## The chip (Foundations: "one square pixel is the whole brand"): an 8 px square,
## white so a button's icon colours tint it (ink on a focused menu item).
func _chip() -> void:
	_save("chip", [
		"####",
		"####",
		"####",
		"####",
	], {"#": Color.WHITE})


## The mockup's icon set, white, one image pixel per grid cell, into assets/ui/icons/.
func _icon_set() -> void:
	for slot: StringName in ICON_SET:
		var icon: Array = ICON_SET[slot]
		var width: int = icon[0]
		var height: int = icon[1]
		var even_odd: bool = icon[2]
		var coverage := PackedInt32Array()
		coverage.resize(width * height)
		for rect: Array in icon[3]:
			for y in range(rect[1], rect[1] + rect[3]):
				for x in range(rect[0], rect[0] + rect[2]):
					coverage[y * width + x] += 1
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		for y in height:
			for x in width:
				var count := coverage[y * width + x]
				if (count % 2 == 1) if even_odd else (count > 0):
					image.set_pixel(x, y, Color.WHITE)
		var path := "%s%s.png" % [ICON_FOLDER, slot]
		var error := image.save_png(path)
		print("%s %s (%d x %d)" % ["saved" if error == OK else "FAILED to save", path, width, height])


## Marks the '.' cells inside a round shape as 'o' (filled), and leaves the ones
## outside (before the first or after the last '#' of a row) transparent.
func _fill_inside(rows: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for row in rows:
		var first := row.find("#")
		var last := row.rfind("#")
		var out := ""
		for i in row.length():
			var letter := row[i]
			out += "o" if letter == "." and i > first and i < last else (" " if letter == "." else letter)
		result.append(out)
	return result


## Saves [param rows] (one string per row of cells, one letter per cell) as a PNG.
## A letter found in [param colors] is drawn in that color; anything else stays transparent.
func _save(file_name: String, rows: Array[String], colors: Dictionary) -> void:
	var image := Image.create(rows[0].length() * CELL, rows.size() * CELL, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var letter := rows[y][x]
			if colors.has(letter):
				image.fill_rect(Rect2i(x * CELL, y * CELL, CELL, CELL), colors[letter])
	var path := "%s%s.png" % [OUTPUT_FOLDER, file_name]
	var error := image.save_png(path)
	print("%s %s (%d x %d)" % ["saved" if error == OK else "FAILED to save", path, image.get_width(), image.get_height()])
