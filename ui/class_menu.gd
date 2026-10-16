class_name ClassMenu
extends CanvasLayer
## The class menu, as the mockup's "08 Class draft" (D-052, D-078, D-099): the world dimmed, a title
## ("Pick a class") with how many classes are offered and when the round starts, and cards side by
## side, one per class you may take: a picture area (the class icon, its key, its height), the name
## and role, the perk, and the gun's name and icon. In a match those are the two classes of your draft
## ([method RoundManager.get_draft]: keys 1 and 2, the other cards hidden); in practice, or with the
## draft off, all four (then the cards are the compact size, see [method _fit_cards]).
## Click a card or press its key to take that class. The lit card (lime frame and key chip) is the one
## with the keyboard focus: your current class when the menu opens, then whichever the mouse
## hovers or the arrow keys reach ([method get_lit_index]).
## Esc, or the [code]class_menu[/code] key (M), closes it without a change.
##
## When it shows: in a match it opens by itself once, when round 1's freeze time begins, and M
## opens or closes it during freeze time only; it closes itself when freeze time ends. In
## practice mode (no rounds) M works at any time. With no game rules (a free-roam map) it never
## opens. The rules decide whether a class may change ([method RoundManager.request_class],
## [method ArenaRules.request_class]); the menu only asks and shows the result.
##
## It registers with [MenuState] like every other menu (D-059): while it is open the mouse is free,
## the player controls stand still, Esc closes it instead of opening the pause menu, and it won't
## open over another menu. The dimmed background takes every click (a click must not reach the game); the character can't shoot until it is closed, so a click on a card
## is never also a shot ([method PlayerController.block_shooting]). It stays shut while the
## developer console is open, and ignores keys the console would be typing.
##
## Its look comes from the UI theme (D-057): the title, cards and labels use theme type variations
## (the numbers are the "Class draft" tokens in tools/ui_palette.gd), and [method set_ui_scale] hands
## it a theme scaled for the window ([UiTheme]), so at 1080 p it is exactly 1.5 times as big.

## The physical keys that pick a class, in menu order.
const PICK_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

## The classes on the cards now, in order (your draft in a match, all of them in practice).
var _classes: Array[ClassData] = []
## The rules that decide class changes: a [RoundManager], an [ArenaRules] or null.
var _rules: Node
## The character whose class the menu changes (the map's Player).
var _player: Character
var _is_open: bool = false

## The theme type that holds the sizes the menu reads (card width and height, the widest row).
const SIZES_TYPE := &"ClassDraft"
## The theme type of the palette's named colours.
const PALETTE_TYPE := &"Palette"
## The type variations of a lit and an unlit key chip and of the number on them.
const CHIP_LIT := &"KeyChipLit"
const CHIP_UNLIT := &"KeyChip"
const KEY_LIT := &"LargeInkLabel"
const KEY_UNLIT := &"LargeLabel"
## The type variations of the row of cards at full size and compact.
const ROW_FULL := &"ClassRow"
const ROW_COMPACT := &"ClassRowCompact"

## The card nodes, one per possible class, in order.
var _cards: Array[Control] = []
## Each card's parts by node name ("Select", "Icon", "Chip", "Key", "Height", "Name", "Role", "PerkName",
## "Perk", "Gun", "GunIcon"), found once.
var _parts: Array[Dictionary] = []
## The card that is lit (has the focus), or -1.
var _lit: int = -1

@onready var _card_row: HBoxContainer = $Cards
@onready var _title: Label = $Header/TitleTrim/Title
@onready var _subtitle: Label = $Header/Subtitle
@onready var _hint: Label = $Hint


func _ready() -> void:
	visible = false
	set_process(false)
	for card in _card_row.get_children():
		var parts := {}
		for part in ["Select", "Icon", "Chip", "Key", "Height", "Name", "Role", "PerkName", "Perk", "Gun", "GunIcon"]:
			parts[part] = card.find_child(part, true, false)
		var index := _cards.size()
		_cards.append(card as Control)
		_parts.append(parts)
		var select := parts["Select"] as Button
		select.pressed.connect(pick.bind(index))
		# Hovering a card moves the focus to it, and the focus is what lights a card up.
		select.mouse_entered.connect(_on_card_hovered.bind(index))
	_show_classes()


## The classes the menu offers now: the player's draft in a match, every class otherwise.
func get_classes() -> Array[ClassData]:
	return _classes


func _input(event: InputEvent) -> void:
	# The console is typing text: "m" and the digits belong to it.
	if DevConsole.is_open:
		return
	if event.is_action_pressed("class_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("pause") and MenuState.is_top(self) and not MenuState.capturing_input:
		# Esc closes this menu only; the pause menu doesn't open on the same key press.
		close()
		get_viewport().set_input_as_handled()
	elif _is_open and event is InputEventKey and event.pressed and not event.echo:
		var index := PICK_KEYS.find((event as InputEventKey).physical_keycode)
		if index >= 0:
			pick(index)
			get_viewport().set_input_as_handled()


## Sets the rules that decide class changes and the character whose class the menu changes.
## [param rules] is a [RoundManager] (a match), an [ArenaRules] (practice) or null (no rules: the
## menu never opens). Call it whenever a map is loaded: the menu closes, forgets the previous
## rules and, in a match, opens when round 1's freeze time begins (at once if it already has).
func set_rules(rules: Node, player: Character) -> void:
	close()
	if is_instance_valid(_rules) and _rules is RoundManager:
		var old := _rules as RoundManager
		old.round_started.disconnect(_on_round_started)
		old.phase_changed.disconnect(_on_phase_changed)
	_rules = rules
	_player = player
	_show_classes()
	if rules is RoundManager:
		var manager := rules as RoundManager
		manager.round_started.connect(_on_round_started)
		manager.phase_changed.connect(_on_phase_changed)
		if manager.round_number == 1:
			open()


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	# The apply gave the cards back their scene size (none): the cards' size comes from the theme. The
	# icons are the new theme's (scaled) ones.
	_show_classes()


## True while the menu is showing.
func is_open() -> bool:
	return _is_open


## True if the menu may open now: there are rules and a player, the developer console is closed,
## and either it is practice mode or the match is in freeze time.
func can_open() -> bool:
	if not is_instance_valid(_rules) or not is_instance_valid(_player) or DevConsole.is_open:
		return false
	# Not over the pause menu, the settings menu or any other open menu.
	if MenuState.is_any_open() and not MenuState.is_open(self):
		return false
	if _rules is RespawnMatch:
		# Team respawn: any time; the new class comes with the next respawn (D-099).
		return (_rules as RespawnMatch).phase != RoundManager.Phase.MATCH_END
	if _rules is RoundManager:
		return (_rules as RoundManager).phase == RoundManager.Phase.FREEZE
	return _rules is ArenaRules


## Opens the menu if it [method can_open], with the mouse free and shooting blocked. Returns
## true if the menu is open afterwards.
func open() -> bool:
	if _is_open:
		return true
	if not can_open():
		return false
	_is_open = true
	visible = true
	set_process(true)
	# MenuState frees the mouse and makes the player controls stand still.
	MenuState.open(self)
	var controller := _get_controller()
	if controller != null:
		controller.block_shooting()
	_show_classes()
	_refresh()
	return true


## Closes the menu and gives the mouse and the trigger back. Does nothing if it is closed.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	set_process(false)
	# A card that keeps the keyboard focus would take the next Space (jump) as a click.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	# The last menu to close gives the mouse back to the game.
	MenuState.close(self)
	var controller := _get_controller()
	if controller != null:
		controller.unblock_shooting()


## Opens the menu when it is closed and closes it when it is open (the [code]class_menu[/code] key).
func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## Gives the player the class on card [param index] (from 0), if the rules allow it, and closes
## the menu. Returns false, leaving the menu open, when the menu is closed, the index is no
## card shown or the rules refuse (not freeze time).
func pick(index: int) -> bool:
	if not _is_open or index < 0 or index >= _classes.size():
		return false
	var accepted := _request(_classes[index])
	if accepted:
		close()
	else:
		_refresh()
	return accepted


## Asks the rules to change the player's class.
func _request(data: ClassData) -> bool:
	if _rules is RoundManager:
		return (_rules as RoundManager).request_class(_player, data)
	if _rules is ArenaRules:
		return (_rules as ArenaRules).request_class(_player, data)
	return false


## Shows one class on its card: the texts, and the icons of the class and of its gun.
func _fill_card(index: int, data: ClassData) -> void:
	var parts := _parts[index]
	(parts["Key"] as Label).text = str(index + 1)
	(parts["Name"] as Label).text = data.display_name
	(parts["Height"] as Label).text = "%.2f m" % data.height
	(parts["Role"] as Label).text = data.role
	(parts["PerkName"] as Label).text = data.perk_name
	(parts["Perk"] as Label).text = data.perk_description
	(parts["Gun"] as Label).text = data.signature_weapon
	# The class icon, in the UI's friendly colour; the gun's icon, in the text colour, is the first of the
	# loadout (where there is none, or no icon is drawn for it, the card has no icon).
	_set_icon(parts["Icon"] as TextureRect, data.id, &"friendly_text")
	_set_icon(parts["GunIcon"] as TextureRect, get_gun_id(data), &"text")
	# The look is too long for the card: it is the hover text.
	(parts["Select"] as Button).tooltip_text = data.look


## The id of the gun [param data]'s card shows (the first of its loadout), or an empty name.
func get_gun_id(data: ClassData) -> StringName:
	return data.loadout[0].id if not data.loadout.is_empty() and data.loadout[0] != null else &""


## Puts the icon of [param slot] in [param rect], tinted with the palette colour [param tint]; the
## rect hides when the slot is empty.
func _set_icon(rect: TextureRect, slot: StringName, tint: StringName) -> void:
	var icon := UiIcons.get_icon(rect, slot) if slot != &"" else null
	rect.texture = icon
	rect.visible = icon != null
	rect.modulate = rect.get_theme_color(tint, PALETTE_TYPE)


## Puts the classes the player may take on the cards (see [method get_classes]), hides the
## cards left over, and says in the title block and the hint when a change is allowed.
func _show_classes() -> void:
	if is_instance_valid(_rules) and _rules is RoundManager and is_instance_valid(_player):
		_classes = (_rules as RoundManager).get_draft(_player)
	else:
		_classes = ClassData.all()
	for i in _cards.size():
		_cards[i].visible = i < _classes.size()
		if _cards[i].visible:
			_fill_card(i, _classes[i])
	_fit_cards()
	_update_header()
	_update_hint()


## Sizes the cards and the gaps between them. A card is [code]card_width[/code] by [code]card_height[/code]
## (theme type [constant SIZES_TYPE], scaled with the UI) and the cards stand [code]ClassRow[/code]'s gap
## apart; when the row of the cards shown would be wider than [code]row_max_width[/code] (three or
## four classes, i.e. practice and matches without the draft) they take the compact width and the
## [code]ClassRowCompact[/code] gap instead, so that all four still fit the 1280 px canvas. The card
## grows when its text needs more room than the height.
func _fit_cards() -> void:
	var count := _classes.size()
	var full_width := _size_of(&"card_width")
	var full_gap := _card_row.get_theme_constant(&"separation", ROW_FULL)
	var compact := count * full_width + maxi(count - 1, 0) * full_gap > _size_of(&"row_max_width")
	_card_row.theme_type_variation = ROW_COMPACT if compact else ROW_FULL
	var card_size := Vector2(_size_of(&"card_width_compact" if compact else &"card_width"), _size_of(&"card_height"))
	for card in _cards:
		card.custom_minimum_size = card_size


## One of the theme's "ClassDraft" sizes, scaled for the menu's scale.
func _size_of(item: StringName) -> int:
	return _card_row.get_theme_constant(item, SIZES_TYPE)


## The title block's second line: how many classes are offered and when the round starts
## ("2 of 4 offered · starts in 12", the freeze time left; "any time" where there is no freeze time to wait for).
func _update_header() -> void:
	var offered := "%d of %d offered" % [_classes.size(), ClassData.all().size()]
	var when := "any time"
	if is_instance_valid(_rules) and _rules is RoundManager and not _rules is RespawnMatch and (_rules as RoundManager).phase == RoundManager.Phase.FREEZE:
		when = "starts in %d" % maxi(ceili((_rules as RoundManager).time_left), 0)
	_subtitle.text = "%s · %s" % [offered, when]


## The hint at the bottom of the screen: which keys pick a class (and, with team respawn, when the new class arrives).
func _update_hint() -> void:
	var keys: PackedStringArray = []
	for i in _classes.size():
		keys.append(str(i + 1))
	var hint := "Click or press %s · Esc keeps your class" % " / ".join(keys)
	if is_instance_valid(_rules) and _rules is RespawnMatch:
		hint += " · the new class comes with your next respawn"
	_hint.text = hint


## Marks the player's current class: its card gets the focus (and with it the lime frame and key chip).
func _refresh() -> void:
	var current := -1
	for i in mini(_cards.size(), _classes.size()):
		var is_current := is_instance_valid(_player) and _player.class_data == _classes[i]
		(_parts[i]["Select"] as Button).set_pressed_no_signal(is_current)
		if is_current:
			current = i
	# A class that is not on the cards (it can't be, in a match) lights the first card.
	if current < 0 and not _classes.is_empty():
		current = 0
	if current >= 0:
		(_parts[current]["Select"] as Button).grab_focus()
	_update_lit()


## Lights the card that has the focus: its key chip is filled with the accent (the frame is the
## button's focus ring) and the others' are empty.
func _update_lit() -> void:
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var lit := -1
	for i in _cards.size():
		if _cards[i].visible and focus == _parts[i]["Select"]:
			lit = i
	if lit == _lit:
		return
	_lit = lit
	for i in _cards.size():
		(_parts[i]["Chip"] as Control).theme_type_variation = CHIP_LIT if i == lit else CHIP_UNLIT
		(_parts[i]["Key"] as Control).theme_type_variation = KEY_LIT if i == lit else KEY_UNLIT


func _process(_delta: float) -> void:
	if not _is_open:
		return
	_update_lit()
	_update_header()


func _on_card_hovered(index: int) -> void:
	if _is_open and _cards[index].visible:
		(_parts[index]["Select"] as Button).grab_focus()


## The card nodes, one per class the menu can show (the ones left over are hidden).
func get_cards() -> Array[Control]:
	return _cards


## One part of card [param index] by its node name ("Select", "Icon", "Chip", "Key", "Height", "Name", "Role",
## "PerkName", "Perk", "Gun", "GunIcon").
func get_part(index: int, part: String) -> Control:
	return _parts[index][part] as Control


## The row the cards stand in.
func get_card_row() -> HBoxContainer:
	return _card_row


## The title ("Pick a class"), the line under it ("2 of 4 offered · starts in 12") and the hint at the bottom.
func get_title_label() -> Label:
	return _title


func get_subtitle_label() -> Label:
	return _subtitle


func get_hint_label() -> Label:
	return _hint


## The card that is lit (has the focus: lime frame and key chip), counting from 0, or -1 if none.
func get_lit_index() -> int:
	return _lit


func _get_controller() -> PlayerController:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("PlayerController") as PlayerController


func _on_round_started(round_number: int) -> void:
	# The start of the match: a chance to choose a class. Later rounds don't ask (M does).
	if round_number == 1:
		open()


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	if phase != RoundManager.Phase.FREEZE and not _rules is RespawnMatch:
		close()
