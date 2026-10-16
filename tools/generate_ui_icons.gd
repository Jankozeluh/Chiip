extends SceneTree
## Tool: draws the small pixel-art icons of Chiip's UI theme (check marks,
## radio dots, the switch of a check button, the slider grabber, arrows) and
## saves them as PNG files into assets/ui/ (D-057).
##
## Run from the project folder, then let Godot import the new files, then
## rebuild the theme, which refers to them:
##
##     Godot --headless --path . --quit-after 100 --script res://tools/generate_ui_icons.gd
##     Godot --headless --path . --import
##     Godot --headless --path . --quit-after 100 --script res://tools/make_ui_theme.gd
##
## Every icon is drawn as a grid of "cells" (a letter per cell, below) and each
## cell becomes a CELL × CELL block of pixels, so one cell is as big as one
## pixel of the pixel font at 16 px (2 × 2). When the UI is scaled for a bigger
## window the theme resizes the icons with nearest-neighbor scaling, so a cell
## stays a perfect square at 1.5× (3 × 3) and 2× (4 × 4). Colors come from
## tools/ui_palette.gd.

const Palette := preload("res://tools/ui_palette.gd")

const OUTPUT_FOLDER := "res://assets/ui/"
## Pixels per cell (the font's pixel at 16 px).
const CELL := 2


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_FOLDER))
	_check_boxes()
	_radio_buttons()
	_switches()
	_slider_grabbers()
	_arrows()
	_popup_markers()
	quit()


## Check boxes: a square frame with a check mark. Also used by popup menus.
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
		"########",
		"#......#",
		"#.....C#",
		"#....C.#",
		"#.C.C..#",
		"#..C...#",
		"#......#",
		"########",
	]
	var enabled := {"#": Palette.BUTTON_BORDER, ".": Palette.INSET, "C": Palette.ACCENT}
	var disabled := {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.BUTTON_DISABLED, "C": Palette.TEXT_DISABLED}
	_save("checkbox_off", box, enabled)
	_save("checkbox_on", checked, enabled)
	_save("checkbox_off_disabled", box, disabled)
	_save("checkbox_on_disabled", checked, disabled)


## Radio buttons: a round frame, with a dot when selected.
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
	var enabled := {"#": Palette.BUTTON_BORDER, "o": Palette.INSET, "D": Palette.ACCENT}
	var disabled := {"#": Palette.BUTTON_BORDER_DISABLED, "o": Palette.BUTTON_DISABLED, "D": Palette.TEXT_DISABLED}
	_save("radio_off", round_box, enabled)
	_save("radio_on", selected, enabled)
	_save("radio_off_disabled", round_box, disabled)
	_save("radio_on_disabled", selected, disabled)


## The switch of a check button: a track with a sliding block, left when off, right when on.
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
	_save("switch_off", off, {"#": Palette.BUTTON_BORDER, ".": Palette.INSET, "K": Palette.TEXT_DIM})
	_save("switch_on", on, {"#": Palette.ACCENT, ".": Palette.ACCENT_DARK, "K": Palette.ACCENT_BRIGHT})
	_save("switch_off_disabled", off, {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.BUTTON_DISABLED, "K": Palette.HANDLE_DISABLED})
	_save("switch_on_disabled", on, {"#": Palette.BUTTON_BORDER_DISABLED, ".": Palette.BUTTON_DISABLED, "K": Palette.HANDLE_DISABLED})


## The knob you drag on a slider.
func _slider_grabbers() -> void:
	var grabber: Array[String] = [
		"######",
		"#HHHH#",
		"#HHHH#",
		"#HHHH#",
		"#GGGG#",
		"#HHHH#",
		"#HHHH#",
		"#GGGG#",
		"#HHHH#",
		"#HHHH#",
		"#HHHH#",
		"######",
	]
	_save("slider_grabber", grabber, {"#": Palette.INSET, "H": Palette.HANDLE, "G": Palette.HANDLE.darkened(Palette.HANDLE_GROOVE_DARKEN)})
	_save("slider_grabber_highlight", grabber, {"#": Palette.INSET, "H": Palette.ACCENT_BRIGHT, "G": Palette.ACCENT})
	_save("slider_grabber_disabled", grabber, {"#": Palette.INSET, "H": Palette.HANDLE_DISABLED, "G": Palette.HANDLE_DISABLED.darkened(Palette.HANDLE_GROOVE_DARKEN)})


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
	var bright := {"#": Palette.TEXT_BRIGHT}
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
