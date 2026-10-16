class_name LicensesMenu
extends CanvasLayer
## The Licences screen (M12, D-170): the licence of the game's code, of its art,
## and the notices of everything it is made with, readable inside the game, as the
## licences of Godot, the Silkscreen font and FuncGodot ask for. It opens from the
## settings menu's footer (so the main menu and the pause menu both reach it).
##
## A list of documents on the left, the picked one's text on the right (a scrolling
## [RichTextLabel], plain text). The texts are the files shipped inside every build
## ([code]LICENSE[/code], [code]LICENSE-ASSETS[/code], [code]THIRD_PARTY_NOTICES.md[/code],
## the font's and the addon's licence) plus two that are made here: the overview, and
## "Godot Engine", which the engine writes itself ([method Engine.get_license_text],
## [method Engine.get_license_info], [method Engine.get_copyright_info]), so it always
## matches the engine in the build, third-party libraries included. A file that is
## missing from a build shows a line saying so, never an empty page (the export presets'
## include filters decide which files ship).
##
## Like every menu it registers with [MenuState] while open, takes its look from the
## UI theme (type variations, no overrides, D-057) and has [code]process_mode = Always[/code]
## so it works over the paused game.

## Emitted when the screen closes (Back or Esc).
signal closed

## Where the source code lives (the overview names it).
const SOURCE_URL := "https://github.com/Jankozeluh/Chiip"
## The height of a row of the list, in design pixels.
const ROW_HEIGHT := 40.0
## The documents in the list: [code]id[/code], the button's [code]title[/code] and the
## [code]path[/code] of the file in the project (empty: the text is made here).
const DOCUMENTS: Array[Dictionary] = [
	{"id": &"overview", "title": "Chiip", "kind": "Overview", "path": ""},
	{"id": &"code", "title": "Game code", "kind": "GPL-3.0", "path": "res://LICENSE"},
	{"id": &"assets", "title": "Art and sounds", "kind": "CC BY-NC-SA", "path": "res://LICENSE-ASSETS"},
	{"id": &"notices", "title": "Third-party notices", "kind": "List", "path": "res://THIRD_PARTY_NOTICES.md"},
	{"id": &"font", "title": "Silkscreen", "kind": "OFL 1.1", "path": "res://assets/fonts/Silkscreen-OFL.txt"},
	{"id": &"func_godot", "title": "FuncGodot", "kind": "MIT", "path": "res://addons/func_godot/LICENSE"},
	{"id": &"godot", "title": "Godot Engine", "kind": "MIT", "path": ""},
]

## The button of each document, by id, in list order, and the dot that marks the picked one.
var _buttons: Dictionary = {}
var _dots: Dictionary = {}
## The id of the document on show.
var _current: StringName = &""
## The texts already read (the engine's is long to build).
var _cache: Dictionary = {}

@onready var _docs: VBoxContainer = %Docs
@onready var _doc_name: Label = %DocName
@onready var _doc_kind: Label = %DocKind
@onready var _mark: TextureRect = %Mark
@onready var _text: RichTextLabel = %Text
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	_mark.texture = BootScreen.load_mono_logo()
	_mark.visible = _mark.texture != null
	var group := ButtonGroup.new()
	for document in DOCUMENTS:
		_docs.add_child(_make_row(document, group))
	_back_button.pressed.connect(close)


func _exit_tree() -> void:
	# Freed or removed while open: don't leave the game waiting for a menu.
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and MenuState.is_top(self):
		close()
		get_viewport().set_input_as_handled()


## A row of the list (the designer's "31 Credits"): a [Button] with the document's picked state over which a dot, its
## name and its licence's name are laid; the picked row has the accent dot.
func _make_row(document: Dictionary, group: ButtonGroup) -> Control:
	var row := MarginContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.theme_type_variation = &"CreditItem"
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(show_document.bind(document["id"]))
	row.add_child(button)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CreditMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.theme_type_variation = &"FormRow"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(line)
	var dot := Panel.new()
	dot.theme_type_variation = &"StatBarFill"
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = Color.TRANSPARENT
	line.add_child(dot)
	var name_label := Label.new()
	name_label.text = document["title"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	var kind := Label.new()
	kind.theme_type_variation = &"MuteLabel"
	kind.text = document["kind"]
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(kind)
	_buttons[document["id"]] = button
	_dots[document["id"]] = dot
	return row


## Shows the screen with the overview and the mouse. It stays open until the player
## closes it ([signal closed]).
func open() -> void:
	visible = true
	MenuState.open(self)
	show_document(DOCUMENTS[0]["id"])
	_back_button.grab_focus()


## Hides the screen, hands the mouse back (if it was the last menu open) and emits
## [signal closed]. Does nothing when it isn't open.
func close() -> void:
	if not visible:
		return
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the screen is shown.
func is_open() -> bool:
	return visible


## Scales the screen; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


## Shows the document [param id] (one of [constant DOCUMENTS]'s ids): its text, scrolled to the top.
func show_document(id: StringName) -> void:
	if not _buttons.has(id):
		return
	_current = id
	var accent := _docs.get_theme_color(&"accent", &"Palette")
	for key: StringName in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == id)
		(_dots[key] as Control).modulate = accent if key == id else Color.TRANSPARENT
	for document in DOCUMENTS:
		if document["id"] == id:
			_doc_name.text = document["title"]
			_doc_kind.text = document["kind"]
	_text.text = get_document_text(id)
	_text.scroll_to_line(0)


## The text of the document [param id]: the file's content, or what is made here
## (the overview, the engine's), or a line saying the file is missing from this build.
func get_document_text(id: StringName) -> String:
	if _cache.has(id):
		return _cache[id]
	var text := ""
	for document in DOCUMENTS:
		if document["id"] != id:
			continue
		if id == &"overview":
			text = overview_text()
		elif id == &"godot":
			text = engine_text()
		else:
			text = read_file(document["path"])
	_cache[id] = text
	return text


## The overview: the version, what is under which licence, and where the source is.
static func overview_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var lines: Array[String] = []
	lines.append("Chiip%s" % ((" " + version) if not version.is_empty() else ""))
	lines.append("Created by JK · Divocakos")
	lines.append("© 2026 Divocakos")
	lines.append("A tactical shooter against bots with a retro Quake look. Online games run by IP address over a LAN or Tailscale.")
	lines.append("")
	lines.append("Game code: GNU General Public License, version 3 (the file LICENSE).")
	lines.append("Art, models, maps and sounds: Creative Commons BY-NC-SA 4.0 (the file LICENSE-ASSETS).")
	lines.append("The studio's name and logo: all rights reserved.")
	lines.append("Made with the Godot Engine (MIT), the Silkscreen font (SIL Open Font License 1.1) and FuncGodot (MIT).")
	lines.append("")
	lines.append("Source code and downloads: %s" % SOURCE_URL)
	lines.append("")
	lines.append("Pick a document on the left for the full text of each licence.")
	return "\n".join(lines)


## What the engine says about itself: its licence, the list of its parts with their
## copyright lines, and the text of every licence they use.
static func engine_text() -> String:
	var parts: Array[String] = []
	parts.append("Godot Engine %s" % Engine.get_version_info().get("string", ""))
	parts.append(Engine.get_license_text())
	parts.append("Third-party components in the engine")
	parts.append("-----------------------------------")
	for component: Dictionary in Engine.get_copyright_info():
		parts.append(str(component.get("name", "")))
		for part: Dictionary in component.get("parts", []):
			var copyright := ", ".join(PackedStringArray(part.get("copyright", [])))
			parts.append("    %s: %s (%s)" % [", ".join(PackedStringArray(part.get("files", []))), copyright, part.get("license", "")])
	parts.append("")
	parts.append("Licence texts")
	parts.append("-------------")
	var licenses := Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for license_name: String in names:
		parts.append("%s\n\n%s" % [license_name, licenses[license_name]])
	return "\n\n".join(parts)


## The text of the project file [param path], or a line saying it is missing from this
## build (a file that doesn't ship has to be listed in the export presets' include filter).
static func read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "This licence file is not in this build (%s). The full texts are in the source repository: %s" % [path, SOURCE_URL]
	return FileAccess.get_file_as_string(path)


## The id of the document on show.
func get_current() -> StringName:
	return _current


## The list's buttons, top to bottom.
func get_document_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for button: Button in _buttons.values():
		found.append(button)
	return found


## The button of the document [param id] (null for an unknown id).
func get_document_button(id: StringName) -> Button:
	return _buttons.get(id)


## The text area.
func get_text_label() -> RichTextLabel:
	return _text


## The Back button.
func get_back_button() -> Button:
	return _back_button
