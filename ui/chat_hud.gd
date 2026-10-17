class_name ChatHud
extends Control
## The match's text chat on the HUD (M17, D-243): a feed of the last [constant FEED_LINES] lines bottom left, above the
## health and money block, each line fading [constant LINE_TIME] seconds after it arrived, and an input line the
## [code]chat[/code] action (Enter or the keypad's Enter, rebindable) opens.
##
## [b]The feed[/b] shows [NetChat]'s newest lines (it keeps the history, so the talk of the lobby is there when you open
## the input). A line is a plate like the kill feed's ([code]HudFeedPlate[/code]): the sender's name in their team's UI
## colour ([method Teams.ui_color_of] of the character with that name in this match, a neutral palette colour when there
## is none), then the words, both plain [Label]s: markup in a line is just characters. What the host told you alone (the
## "Slow down" notice) is a dim line of the feed, not kept.
##
## [b]The input[/b]: Enter opens it, the plate with its text field registers with [MenuState] (so the player's movement,
## shooting and looking stop and the mouse shows, like any menu), every recent line shows at full strength while it is
## open, Enter sends the words through the session's chat and closes it, Esc closes it without sending. It opens only
## online ([method set_session]; offline Enter does nothing), while no other menu or the console is open, and not
## while the HUD is hidden or [method set_blocked] says so (the match-end screen). Esc is taken only while the input is
## the menu on top, so the pause menu and the console keep working. The text field is the one control here that
## takes no mouse click either (the keyboard has its focus): the whole HUD stays click-through.
##
## A pure view of the chat; the look is theme roles only (the name colours are the one data colour, as in the kill feed).

## The most lines the feed shows at once.
const FEED_LINES := 6
## Seconds a line stays fully visible, and how long it then takes to fade out.
const LINE_TIME := 8.0
const FADE_TIME := 0.5
## The theme types that hold the HUD's sizes and the palette's named colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## A line shows at most this many lines of text (a full-length message fits in two).
const LINE_ROWS := 2
## The roles of a line: its plate and its texts.
const PLATE_ROLE := &"HudFeedPlate"
const TEXT_ROLE := &"HudSmallLabel"

## The input is open.
var _is_open: bool = false
## Set by [method set_blocked]: no new input while true.
var _blocked: bool = false
var _chat: NetChat
var _ui_scale: float = 1.0
## The lines showing: each [code]{"row": Control, "time": the chat's time it arrived at}[/code], oldest first.
var _entries: Array[Dictionary] = []
## The player's character: the match's characters are looked up through it (the name colours).
var _anchor: Character

@onready var _feed: VBoxContainer = %ChatFeed
@onready var _plate: Control = %ChatInputPlate
@onready var _field: LineEdit = %ChatInput


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.visible = false
	_plate.custom_minimum_size.y = float(get_theme_constant(&"plate_height", THEME_TYPE))
	_field.max_length = NetChat.MAX_CHAT_LENGTH
	_field.text_submitted.connect(_on_text_submitted)


func _exit_tree() -> void:
	# Freed or removed while the input is open: don't leave the game waiting for a menu.
	MenuState.close(self)


## Follows [param session]'s chat (null: no chat, Enter does nothing; the feed empties). Called by the game on every map load.
func set_session(session: NetSession) -> void:
	if _is_open:
		close_input()
	if _chat != null and is_instance_valid(_chat):
		_chat.line_received.disconnect(_on_line_received)
		_chat.notice.disconnect(_on_notice)
	_chat = null
	_clear_feed()
	if session == null or not is_instance_valid(session):
		return
	_chat = NetChat.of(session)
	_chat.line_received.connect(_on_line_received)
	_chat.notice.connect(_on_notice)
	# Lines that arrived a moment before this map loaded (the last of the lobby's talk) still count.
	for line in _chat.lines.slice(maxi(0, _chat.lines.size() - FEED_LINES)):
		if _chat.age_of(line) < LINE_TIME:
			_show_line(int(line["peer_id"]), String(line["name"]), String(line["text"]), float(line["time"]))


## Tells the feed whose match it is: the sender names are matched to the characters in the player's world.
func set_player(character: Character) -> void:
	_anchor = character


## While true the input can't be opened (the match-end screen covers the HUD). Closes an open one.
func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked and _is_open:
		close_input()


## Scales the feed and the input (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(%ChatColumn, factor)


## True when the input could open now: a session, no menu, a visible HUD.
func can_open() -> bool:
	if _is_open or _blocked or _chat == null or not is_instance_valid(_chat) or not _chat.session.is_active():
		return false
	if MenuState.blocks_gameplay() or get_tree().paused:
		return false
	var layer := get_parent() as CanvasLayer
	return layer == null or layer.visible


## Opens the input line (the [code]chat[/code] action does): every recent line shows, the text field has the focus and
## the game's own controls rest. Returns false when it can't open ([method can_open]).
func open_input() -> bool:
	if not can_open():
		return false
	_is_open = true
	MenuState.open(self)
	_plate.visible = true
	_field.clear()
	_field.grab_focus()
	_refresh_fades()
	return true


## Closes the input without sending (Esc does): the controls come back, the lines fade as usual.
func close_input() -> void:
	if not _is_open:
		return
	_is_open = false
	_field.release_focus()
	_field.clear()
	_plate.visible = false
	MenuState.close(self)
	_refresh_fades()


## Sends what the input holds, then closes it (Enter does). Empty words are not sent.
func send_input() -> void:
	if not _is_open:
		return
	var text := _field.text
	if _chat != null and is_instance_valid(_chat) and not text.strip_edges().is_empty():
		_chat.send(text)
	close_input()


## True while the input line is open. For tests.
func is_input_open() -> bool:
	return _is_open


## The text field of the input line. For tests.
func get_input() -> LineEdit:
	return _field


## The lines showing in the feed as "Name: words" (a notice as its text), oldest first. For tests.
func get_line_texts() -> Array[String]:
	var texts: Array[String] = []
	for entry in _entries:
		var row := entry["row"] as Control
		var name_label := row.find_child("Name", true, false) as Label
		var words := row.find_child("Text", true, false) as Label
		texts.append("%s %s" % [name_label.text, words.text] if name_label != null else words.text)
	return texts


## The opacity of the feed line at [param index] (0 = oldest showing), -1 when there is none. For tests.
func get_line_alpha(index: int) -> float:
	if index < 0 or index >= _entries.size():
		return -1.0
	return (_entries[index]["row"] as Control).modulate.a


## The colour of the name of the feed line at [param index] (the plain colour for a notice). For tests.
func get_line_name_color(index: int) -> Color:
	var row := _entries[index]["row"] as Control
	var name_label := row.find_child("Name", true, false) as Label
	return name_label.get_theme_color(&"font_color") if name_label != null else Color.TRANSPARENT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and not event.is_echo():
		if open_input():
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Esc ends the typing, if the input is the menu on top (the console over it, or MenuState's capture, goes first).
	if _is_open and event.is_action_pressed("pause") and MenuState.is_top(self) and not MenuState.capturing_input:
		close_input()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_fades()


## Fades the lines by their age (all at full strength while the input is open) and drops the old ones and the ones
## past [constant FEED_LINES].
func _refresh_fades() -> void:
	if _chat == null or not is_instance_valid(_chat):
		return
	var index := 0
	while index < _entries.size():
		var entry := _entries[index]
		var age := _chat.time - float(entry["time"])
		var row := entry["row"] as Control
		if _is_open:
			row.modulate.a = 1.0
			index += 1
		elif age >= LINE_TIME + FADE_TIME:
			_remove_entry(index)
		else:
			row.modulate.a = clampf(1.0 - (age - LINE_TIME) / FADE_TIME, 0.0, 1.0)
			index += 1


func _on_text_submitted(_text: String) -> void:
	send_input()


func _on_line_received(peer_id: int, name_text: String, text: String) -> void:
	_show_line(peer_id, name_text, text, _chat.time)


func _on_notice(text: String) -> void:
	var row := _make_plate()
	row.get_child(0).add_child(_make_words(text, get_theme_color(&"text_dim", PALETTE_TYPE)))
	_push_entry(row, _chat.time)


## A feed line: [param name_text] in its sender's colour, then [param text].
func _show_line(peer_id: int, name_text: String, text: String, arrived: float) -> void:
	var row := _make_plate()
	var parts := row.get_child(0)
	parts.add_child(_make_label("Name", "%s:" % name_text, _name_color(name_text)))
	parts.add_child(_make_words(text, get_theme_color(&"text", PALETTE_TYPE)))
	_push_entry(row, arrived)


func _make_plate() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.theme_type_variation = PLATE_ROLE
	var parts := HBoxContainer.new()
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parts.theme_type_variation = &"HudRowStack"
	plate.add_child(parts)
	return plate


func _make_label(label_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.theme_type_variation = TEXT_ROLE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label


## The words of a line: wrapped to the column's width, at most [constant LINE_ROWS] rows.
func _make_words(text: String, color: Color) -> Label:
	var label := _make_label("Text", text, color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = LINE_ROWS
	return label


func _push_entry(row: PanelContainer, arrived: float) -> void:
	# In the tree first: the theme is looked up through the parents.
	_feed.add_child(row)
	UiScale.apply_tree(row, _ui_scale)
	_entries.append({"row": row, "time": arrived})
	while _entries.size() > FEED_LINES:
		_remove_entry(0)
	_refresh_fades()


func _remove_entry(index: int) -> void:
	var row := _entries[index]["row"] as Control
	_entries.remove_at(index)
	_feed.remove_child(row)
	row.queue_free()


func _clear_feed() -> void:
	while not _entries.is_empty():
		_remove_entry(0)


## The colour of [param name_text]'s name: their team's UI colour when a character of that name plays in this match
## (the host named every player's character after the roster), else the palette's plain text.
func _name_color(name_text: String) -> Color:
	if _anchor == null or not is_instance_valid(_anchor):
		return get_theme_color(&"text_dim", PALETTE_TYPE)
	for character in Character.all_in_world(_anchor):
		if String(character.name) == name_text:
			return Teams.ui_color_of(character)
	return get_theme_color(&"text_dim", PALETTE_TYPE)
