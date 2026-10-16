extends SceneTree
## Tool: measures map textures against the look rules (D-063, D-121) and
## draws a contact sheet of them, so a new texture is checked by numbers
## instead of by eye:
##
##     Godot --headless --path . --quit-after 100 --script res://tools/texture_report.gd -- res://assets/textures/industrial [more folders or PNGs] [--sheet <out.png>]
##
## For every PNG it prints the average brightness and colour strength
## (saturation), and the share of pixels that are a strong red or blue, the
## team colours (D-042). A texture fails when more than [constant MAX_TEAM_SHARE]
## of its pixels are strong red or blue, or its average saturation is above
## [constant MAX_SATURATION]. Wood (the warm accent, 0.44), rust and muted
## greens pass; the old bricks_red fails with 21 % strong reds, as it should
## (MAPS.md, "Look rules").
##
## [code]--sheet[/code] writes all textures side by side, scaled up 2× with sharp
## pixels and their names underneath, for reviews and docs/MAPPING.md.

## Highest average saturation (HSV, 0–1) a map texture may have.
const MAX_SATURATION := 0.45
## Highest share of pixels that may look like a team colour.
const MAX_TEAM_SHARE := 0.03
## A pixel this saturated (and not too dark) counts as a strong colour.
const STRONG_SATURATION := 0.3
const STRONG_VALUE := 0.2
## Hue ranges (degrees) of the team colours: red around 0°, blue around 220°.
## Wood sits at 20–40°, so it doesn't count as red; bricks_red's darker bricks (18–20°) do.
const RED_HUES := [[0.0, 20.0], [340.0, 360.0]]
const BLUE_HUES := [[190.0, 255.0]]
## Contact sheet layout.
const TILE := 128
const LABEL_HEIGHT := 14
const COLUMNS := 8


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sheet_path := ""
	var sheet_index := args.find("--sheet")
	if sheet_index >= 0:
		sheet_path = args[sheet_index + 1] if sheet_index + 1 < args.size() else ""
		args = args.slice(0, sheet_index) + args.slice(sheet_index + 2)
	if args.is_empty():
		printerr("Usage: -- <folder or PNG> [more] [--sheet <out.png>]")
		quit(1)
		return
	var files: Array[String] = []
	for arg in args:
		if arg.ends_with(".png"):
			files.append(arg)
		else:
			for file in DirAccess.get_files_at(arg):
				if file.ends_with(".png"):
					files.append(arg.path_join(file))
	var failures := 0
	print("%-48s %6s %6s %6s %6s  %s" % ["texture", "bright", "sat", "red%", "blue%", "verdict"])
	var images: Array[Image] = []
	for path in files:
		# Read the file's bytes, not the imported texture: works before an import, without warnings.
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			printerr("Could not load ", path)
			failures += 1
			continue
		var stats := measure(image)
		var passed := passes(stats)
		if not passed:
			failures += 1
		print("%-48s %6.2f %6.2f %6.1f %6.1f  %s" % [path.trim_prefix("res://assets/textures/"),
				stats.brightness, stats.saturation, stats.red * 100.0, stats.blue * 100.0,
				"ok" if passed else "FAILS the look rules"])
		images.append(image)
	if not sheet_path.is_empty():
		_write_sheet(images, files, sheet_path)
	print("%d texture(s), %d failing" % [files.size(), failures])
	quit(failures)


## Average brightness and saturation, and the share of strong red and blue
## pixels, over the opaque pixels of [param image].
static func measure(image: Image) -> Dictionary:
	var count := 0
	var brightness := 0.0
	var saturation := 0.0
	var red := 0
	var blue := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			count += 1
			brightness += color.get_luminance()
			saturation += color.s
			if color.s >= STRONG_SATURATION and color.v >= STRONG_VALUE:
				var hue := color.h * 360.0
				if _in_ranges(hue, RED_HUES):
					red += 1
				elif _in_ranges(hue, BLUE_HUES):
					blue += 1
	count = maxi(count, 1)
	return {brightness = brightness / count, saturation = saturation / count,
			red = red / float(count), blue = blue / float(count)}


## Whether measured [param stats] keep the look rules.
static func passes(stats: Dictionary) -> bool:
	return stats.saturation <= MAX_SATURATION and stats.red <= MAX_TEAM_SHARE and stats.blue <= MAX_TEAM_SHARE


static func _in_ranges(hue: float, ranges: Array) -> bool:
	for range: Array in ranges:
		if hue >= range[0] and hue <= range[1]:
			return true
	return false


func _write_sheet(images: Array[Image], files: Array[String], path: String) -> void:
	var rows := ceili(images.size() / float(COLUMNS))
	var sheet := Image.create(COLUMNS * (TILE + 4), rows * (TILE + LABEL_HEIGHT + 6), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.12, 0.13))
	for i in images.size():
		var tile := images[i].duplicate() as Image
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
		var corner := Vector2i((i % COLUMNS) * (TILE + 4) + 2, (i / COLUMNS) * (TILE + LABEL_HEIGHT + 6) + 2)
		sheet.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), corner)
		draw_label(sheet, files[i].get_file().get_basename(), corner + Vector2i(0, TILE + 2), TILE)
	sheet.save_png(path)
	print("Contact sheet: ", path)


## Draws [param text] into [param sheet] with the tiny 3 × 5 pixel alphabet
## below (a headless run has no renderer to draw the game's font into an
## Image), cut off at [param max_width] pixels. Also used by tools/kit_sheet.gd.
static func draw_label(sheet: Image, text: String, corner: Vector2i, max_width: int) -> void:
	var x := corner.x
	for character in text.to_upper():
		var glyph: Array = GLYPHS.get(character, GLYPHS["?"])
		for row in 5:
			for column in 3:
				if glyph[row] & (4 >> column):
					sheet.set_pixel(x + column, corner.y + row, Color(0.85, 0.87, 0.9))
		x += 4
		if x > corner.x + max_width - 4:
			break


## A 3 × 5 pixel alphabet for the sheet's labels: each row is 3 bits, left to right.
const GLYPHS := {
	"A": [2, 5, 7, 5, 5], "B": [6, 5, 6, 5, 6], "C": [3, 4, 4, 4, 3], "D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7], "F": [7, 4, 6, 4, 4], "G": [3, 4, 5, 5, 3], "H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7], "J": [1, 1, 1, 5, 2], "K": [5, 5, 6, 5, 5], "L": [4, 4, 4, 4, 7],
	"M": [5, 7, 7, 5, 5], "N": [6, 5, 5, 5, 5], "O": [2, 5, 5, 5, 2], "P": [6, 5, 6, 4, 4],
	"Q": [2, 5, 5, 6, 3], "R": [6, 5, 6, 5, 5], "S": [3, 4, 2, 1, 6], "T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7], "V": [5, 5, 5, 5, 2], "W": [5, 5, 7, 7, 5], "X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2], "Z": [7, 1, 2, 4, 7], "0": [7, 5, 5, 5, 7], "1": [2, 6, 2, 2, 7],
	"2": [6, 1, 2, 4, 7], "3": [6, 1, 2, 1, 6], "4": [5, 5, 7, 1, 1], "5": [7, 4, 6, 1, 6],
	"6": [3, 4, 7, 5, 7], "7": [7, 1, 2, 2, 2], "8": [7, 5, 7, 5, 7], "9": [7, 5, 7, 1, 6],
	"_": [0, 0, 0, 0, 7], "-": [0, 0, 7, 0, 0], " ": [0, 0, 0, 0, 0], "?": [6, 1, 2, 0, 2],
}
