extends SceneTree
## Tool: writes the weapons' balancing table (every stat of every weapon plus derived columns at
## 10 and 30 m, see [WeaponTable]) to docs/weapons.csv, which opens in Excel or Numbers. Run it
## after changing a weapons/*.tres; tests/arsenal_test.gd fails while the file is out of date.
##
##     /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 100 --script res://tools/export_weapon_table.gd
##
## Godot imports a .csv file as a translation by default, which would clutter the project with
## generated .translation files. A "keep" import file (docs/weapons.csv.import) stops that, so
## the tool also writes it when it's missing, unless docs/ is hidden from Godot by a .gdignore
## (then nothing is imported there anyway).

const CSV_PATH := "res://docs/weapons.csv"
const IMPORT_PATH := "res://docs/weapons.csv.import"
const GDIGNORE_PATH := "res://docs/.gdignore"
## What the import file must say: keep the file as it is, don't import it as a translation.
const IMPORT_TEXT := "[remap]\n\nimporter=\"keep\"\n"


func _init() -> void:
	if not _write_file(CSV_PATH, WeaponTable.csv_text()):
		quit(1)
		return
	if not FileAccess.file_exists(GDIGNORE_PATH) and not FileAccess.file_exists(IMPORT_PATH):
		if not _write_file(IMPORT_PATH, IMPORT_TEXT):
			quit(1)
			return
	print("Wrote docs/weapons.csv (%d weapons)" % WeaponData.PATHS.size())
	quit()


## Writes [param text] to the project file at [param path]; false (with an error printed) when
## the file can't be opened.
func _write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		printerr("Can't write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	return true
