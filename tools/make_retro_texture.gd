extends SceneTree
## Tool: turns any image (e.g. a CC0 photo texture) into a retro texture for Chiip (D-024).
##
## Run from the project folder, then let Godot import the result:
##
##     Godot --headless --path . --script res://tools/make_retro_texture.gd -- <source image> <name> [size] [colors] [contrast]
##     Godot --headless --path . --import
##
## - <source image>: path to a PNG or JPG anywhere on disk.
## - <name>: output file name without extension; saved as res://assets/textures/<name>.png.
## - [size]: output width and height in pixels (default 64, Quake-style).
## - [colors]: how many colors the texture keeps (default 16).
## - [contrast]: how far colors are pushed away from the average (default 1.0 =
##   unchanged). Photos of smooth surfaces turn almost flat at 64 × 64; 2–3
##   brings back the punchy look of 90s textures.
##
## Steps: crop to a square, shrink in halving steps (like mipmaps, so detail
## averages out instead of flickering), boost contrast, reduce to a small
## palette with k-means, then save the PNG and import settings for sharp
## pixels (lossless, with mipmaps).

const OUTPUT_FOLDER := "res://assets/textures/"
const K_MEANS_ROUNDS := 12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: -- <source image> <name> [size] [colors] [contrast]")
		quit(1)
		return
	var size := int(args[2]) if args.size() > 2 else 64
	var color_count := int(args[3]) if args.size() > 3 else 16
	var contrast := float(args[4]) if args.size() > 4 else 1.0
	var image := Image.load_from_file(args[0])
	if image == null:
		printerr("Could not load ", args[0])
		quit(1)
		return
	image.convert(Image.FORMAT_RGB8)
	image = _crop_to_square(image)
	_shrink(image, size)
	_boost_contrast(image, contrast)
	_reduce_colors(image, color_count)
	var path := OUTPUT_FOLDER + args[1] + ".png"
	var error := image.save_png(path)
	_write_import_settings(path)
	print("%s: %s (%d × %d, %d colors, contrast %.1f)" % [path, error_string(error), size, size, color_count, contrast])
	quit(0 if error == OK else 1)


func _crop_to_square(image: Image) -> Image:
	var side := mini(image.get_width(), image.get_height())
	var corner := Vector2i((image.get_width() - side) / 2, (image.get_height() - side) / 2)
	return image.get_region(Rect2i(corner, Vector2i(side, side)))


## Halves the size step by step until close to the target, then resizes exactly.
func _shrink(image: Image, size: int) -> void:
	while image.get_width() / 2 >= size:
		image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	if image.get_width() != size:
		image.resize(size, size, Image.INTERPOLATE_BILINEAR)


## Moves every pixel's color away from the image's average color by [param amount].
func _boost_contrast(image: Image, amount: float) -> void:
	if is_equal_approx(amount, 1.0):
		return
	var average := Color(0, 0, 0)
	for y in image.get_height():
		for x in image.get_width():
			average += image.get_pixel(x, y)
	average /= image.get_width() * image.get_height()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(
					clampf(average.r + (color.r - average.r) * amount, 0.0, 1.0),
					clampf(average.g + (color.g - average.g) * amount, 0.0, 1.0),
					clampf(average.b + (color.b - average.b) * amount, 0.0, 1.0)))


## Replaces every pixel with the nearest of [param color_count] palette colors,
## found with k-means clustering: start with colors spread across the image's
## brightness range, then repeatedly move each palette color to the average of
## the pixels closest to it.
func _reduce_colors(image: Image, color_count: int) -> void:
	var pixels: Array[Color] = []
	for y in image.get_height():
		for x in image.get_width():
			pixels.append(image.get_pixel(x, y))
	var by_brightness := pixels.duplicate()
	by_brightness.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var palette: Array[Color] = []
	for i in color_count:
		palette.append(by_brightness[int((i + 0.5) * by_brightness.size() / color_count)])

	var nearest := PackedInt32Array()
	nearest.resize(pixels.size())
	for round in K_MEANS_ROUNDS:
		var sums: Array[Vector3] = []
		var counts := PackedInt32Array()
		sums.resize(color_count)
		sums.fill(Vector3.ZERO)
		counts.resize(color_count)
		for i in pixels.size():
			var index := _nearest_color(pixels[i], palette)
			nearest[i] = index
			sums[index] += Vector3(pixels[i].r, pixels[i].g, pixels[i].b)
			counts[index] += 1
		for c in color_count:
			if counts[c] > 0:
				var average := sums[c] / counts[c]
				palette[c] = Color(average.x, average.y, average.z)

	var width := image.get_width()
	for i in pixels.size():
		image.set_pixel(i % width, i / width, palette[_nearest_color(pixels[i], palette)])


func _nearest_color(color: Color, palette: Array[Color]) -> int:
	var best := 0
	var best_distance := INF
	for i in palette.size():
		var c := palette[i]
		var distance := (color.r - c.r) ** 2 + (color.g - c.g) ** 2 + (color.b - c.b) ** 2
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


## Import settings for pixel textures: lossless (no compression smearing the
## pixels), mipmaps on, and never switched to compressed GPU formats when used in 3D.
func _write_import_settings(texture_path: String) -> void:
	var file := FileAccess.open(texture_path + ".import", FileAccess.WRITE)
	file.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=0
mipmaps/generate=true
mipmaps/limit=-1
detect_3d/compress_to=0
""" % texture_path)
