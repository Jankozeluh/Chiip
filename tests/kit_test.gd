extends Node
## Automated checks for the map kit (M10, D-121 to D-129). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/kit_test.tscn
##
## The texture library: every texture of the four sets is 64 × 64, keeps the
## look rules (measured like tools/texture_report.gd), has its material, and
## footsteps and impacts know what it's made of from its name. Quits with the
## number of failed checks as the exit code.

const TextureReport := preload("res://tools/texture_report.gd")
const TEXTURE_SETS := ["industrial", "urban", "interior", "nature"]
const TEXTURE_FOLDER := "res://assets/textures/"
const MATERIAL_FOLDER := "res://assets/materials/"

var _failures: int = 0


func _ready() -> void:
	_test_textures()
	_test_texture_sounds()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Texture library (D-121) ---


## Every PNG of the four sets, as "set/name".
func _set_textures() -> Array[String]:
	var names: Array[String] = []
	for set_name: String in TEXTURE_SETS:
		for file in DirAccess.get_files_at(TEXTURE_FOLDER + set_name):
			if file.ends_with(".png"):
				names.append(set_name.path_join(file.get_basename()))
	return names


func _test_textures() -> void:
	var names := _set_textures()
	var counts: Array[String] = []
	for set_name: String in TEXTURE_SETS:
		counts.append("%s %d" % [set_name, names.filter(func(n: String) -> bool: return n.begins_with(set_name + "/")).size()])
	_check("The texture library has 28 textures in four sets", names.size() >= 28 and not counts.any(func(c: String) -> bool: return c.ends_with(" 0")),
			", ".join(counts))

	var wrong_size: Array[String] = []
	var failing_rules: Array[String] = []
	var no_material: Array[String] = []
	for texture_name in names:
		var image := Image.new()
		image.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_FOLDER + texture_name + ".png"))
		if image.get_size() != Vector2i(64, 64):
			wrong_size.append("%s %s" % [texture_name, image.get_size()])
		var stats := TextureReport.measure(image)
		if not TextureReport.passes(stats):
			failing_rules.append("%s (sat %.2f, red %.0f%%, blue %.0f%%)" % [texture_name, stats.saturation, stats.red * 100, stats.blue * 100])
		var material := load(MATERIAL_FOLDER + texture_name + ".tres") as StandardMaterial3D
		if material == null or material.albedo_texture == null \
				or material.albedo_texture.resource_path != TEXTURE_FOLDER + texture_name + ".png" or not material.uv1_world_triplanar:
			no_material.append(texture_name)
	_check("Every set texture is 64 × 64", wrong_size.is_empty(), ", ".join(wrong_size) if wrong_size else "%d textures" % names.size())
	_check("Every set texture keeps the look rules (no team red or blue, muted colours)", failing_rules.is_empty(),
			", ".join(failing_rules) if failing_rules else "all within saturation %.2f and %.0f%% team colours" % [
				TextureReport.MAX_SATURATION, TextureReport.MAX_TEAM_SHARE * 100])
	_check("Every set texture has a world-triplanar material in assets/materials/<set>/", no_material.is_empty(),
			", ".join(no_material) if no_material else "%d materials" % names.size())

	# The chain-link is see-through: holes in the texture, alpha scissor in both of its materials.
	var chainlink := Image.new()
	chainlink.load_png_from_buffer(FileAccess.get_file_as_bytes(TEXTURE_FOLDER + "industrial/chainlink.png"))
	var holes := 0
	for y in chainlink.get_height():
		for x in chainlink.get_width():
			if chainlink.get_pixel(x, y).a < 0.5:
				holes += 1
	var map_material := load(TEXTURE_FOLDER + "industrial/chainlink.tres") as StandardMaterial3D
	var csg_material := load(MATERIAL_FOLDER + "industrial/chainlink.tres") as StandardMaterial3D
	_check("The chain-link has holes, and its map and CSG materials cut them out (alpha scissor, both sides drawn)",
			holes > 64 * 64 / 3 and map_material != null and csg_material != null
			and map_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and csg_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			and map_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
			"%d%% holes" % roundi(holes * 100.0 / (64 * 64)))


func _test_texture_sounds() -> void:
	var expected := {
		"gravel_grey": Surfaces.Kind.GRAVEL, "metal_plates": Surfaces.Kind.METAL, "wood_planks": Surfaces.Kind.WOOD,
		"concrete_floor": Surfaces.Kind.HARD, "painted_plaster": Surfaces.Kind.HARD,
		"industrial/corrugated_grey": Surfaces.Kind.METAL, "industrial/diamond_plate": Surfaces.Kind.METAL,
		"industrial/grate": Surfaces.Kind.METAL, "industrial/rust_plates": Surfaces.Kind.METAL,
		"industrial/concrete_worn": Surfaces.Kind.HARD, "urban/wood_siding": Surfaces.Kind.WOOD,
		"urban/cobbles": Surfaces.Kind.HARD, "urban/asphalt": Surfaces.Kind.HARD,
		"interior/parquet": Surfaces.Kind.WOOD, "interior/wood_floor_dark": Surfaces.Kind.WOOD,
		"interior/tiles_checker": Surfaces.Kind.HARD, "nature/grass": Surfaces.Kind.GRAVEL,
		"nature/dirt": Surfaces.Kind.GRAVEL, "nature/rock_moss": Surfaces.Kind.HARD,
		"industrial/blue_metal": Surfaces.Kind.METAL,
	}
	var wrong: Array[String] = []
	for texture_name: String in expected:
		var kind := Surfaces.kind_for_texture(texture_name)
		if kind != expected[texture_name]:
			wrong.append("%s is %s" % [texture_name, Surfaces.Kind.keys()[kind]])
	_check("Footsteps know textures by name: metal, wood and ground words, the old names unchanged", wrong.is_empty(),
			", ".join(wrong) if wrong else "%d names" % expected.size())


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
