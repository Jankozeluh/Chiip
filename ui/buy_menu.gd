class_name BuyMenu
extends CanvasLayer
## The buy menu (M7 task 11, D-098): five columns side by side, one per [enum Shop.Category]
## (Pistols, Mid-tier, Rifles, Gear, Grenades), each with a button per item showing its icon, its
## key, its name and its price. Click an item to buy it, or press the column's number (1 to 5)
## and then the item's number in it. The [code]buy_menu[/code] key (B) or Esc closes it.
##
## **When it shows:** in a match with money ([RoundManager]) it opens with B during freeze time
## (the buy time) and closes by itself when freeze time ends; in practice ([ArenaRules]) it opens
## at any time and everything is free. Team respawn has no money ([method RoundManager.has_economy]
## is false) and with no rules at all (a free-roam map) it never opens. It also closes when the
## player dies. The rules decide every purchase ([method RoundManager.request_buy],
## [method ArenaRules.request_buy]); the menu only asks and shows the answer.
##
## **Keys:** a category number selects that category (its header lights up, the other headers dim)
## and the next number buys that item. A number the selected category has no item for selects
## another category instead (3 items in Rifles: 4 and 5 jump to Gear and Grenades), and 0 or
## Backspace deselects it. A successful buy deselects too, as in CS, so each item is two key
## presses; a refused one keeps the category so you can try another item. The weapon-slot keys
## (1 to 4) do nothing while a menu is open, and these presses are consumed anyway.
##
## **Buying** plays [code]buy.wav[/code] and refreshes the menu; a refusal plays
## [code]buy_denied.wav[/code] and shows its reason at the bottom for [constant MESSAGE_TIME]
## seconds. The menu stays open to buy more. Items you can't buy right now (no money, already
## carried, not enough room) are disabled, with the reason as their tooltip.
##
## It registers with [MenuState] like every other menu (D-059): while it is open the mouse is
## free, the player controls stand still, Esc closes it instead of opening the pause menu, and it
## won't open over another menu. The dimmed background takes every click, and the character can't
## shoot until it is closed ([method PlayerController.block_shooting]), so a click on an item is
## never also a shot. It stays shut while the developer console is open, and ignores keys the
## console would be typing.
##
## Its look comes from the UI theme (D-057): theme type variations only, and [method set_ui_scale]
## hands it a theme scaled for the window ([UiTheme]); the icons are scaled with it, nearest-neighbour.

## Seconds a refusal's reason stays at the bottom of the panel.
const MESSAGE_TIME := 2.0
## The key that goes back to "no category selected".
const BACK_KEYS: Array[Key] = [KEY_0, KEY_BACKSPACE]
## The physical number keys, in order: 1 is the first (a category or an item).
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const BUY_SOUND := preload("res://assets/sounds/buy.wav")
const DENIED_SOUND := preload("res://assets/sounds/buy_denied.wav")

## The rules that decide purchases: a [RoundManager], an [ArenaRules] or null.
var _rules: Node
## The character who buys (the map's Player).
var _player: Character
var _is_open: bool = false
## The selected category (an index into [enum Shop.Category]), or -1 for none.
var _selected_category: int = -1
## Seconds the reason line still shows, and the reason it shows ("" = the hint).
var _message_left: float = 0.0
var _message: String = ""
## The shop's items by id (see [method Shop.items]).
var _item_by_id: Dictionary = {}
## The item ids of each category, in menu order (index = [enum Shop.Category]).
var _category_items: Array[Array] = []
## The item buttons by item id.
var _buttons: Dictionary = {}
## The category headers, in category order.
var _headers: Array[Label] = []
## How much the icons are scaled (the UI scale, see [method set_ui_scale]).
var _icon_scale: float = 1.0

@onready var _columns: HBoxContainer = $Panel/Margin/Content/Columns
@onready var _money_label: Label = $Panel/Margin/Content/TopRow/Money
@onready var _time_label: Label = $Panel/Margin/Content/TopRow/BuyTime
@onready var _message_label: Label = $Panel/Margin/Content/Message
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	visible = false
	set_process(false)
	_build_columns()
	_update_icons()
	# The buttons exist now: hover ticks and click sounds.
	UiSounds.attach(self)


func _process(delta: float) -> void:
	# Closes when the rules stop letting this character buy (it died, the freeze time ended).
	if not _allows_buying():
		close()
		return
	_update_header_line()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message = ""
			_update_message()


func _input(event: InputEvent) -> void:
	# The console is typing text: "b" and the digits belong to it.
	if DevConsole.is_open:
		return
	if event.is_action_pressed("buy_menu"):
		var was_open := _is_open
		toggle()
		# Nothing to open (no money in this mode, not freeze time): the key isn't ours.
		if was_open != _is_open:
			get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("pause") and MenuState.is_top(self) and not MenuState.capturing_input:
		# Esc closes this menu only; the pause menu doesn't open on the same key press.
		close()
		get_viewport().set_input_as_handled()
	elif _is_open and event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		if code in BACK_KEYS:
			select_category(-1)
			get_viewport().set_input_as_handled()
			return
		var number := NUMBER_KEYS.find(code)
		if number >= 0:
			_press_number(number)
			get_viewport().set_input_as_handled()


## Sets the rules that decide purchases and the character who buys. [param rules] is a
## [RoundManager] (a match), an [ArenaRules] (practice) or null (no rules: the menu never opens).
## Call it whenever a map is loaded: the menu closes and forgets the previous rules.
func set_rules(rules: Node, player: Character) -> void:
	close()
	if is_instance_valid(_rules) and _rules is RoundManager:
		var old := _rules as RoundManager
		old.money_changed.disconnect(_on_money_changed)
		old.phase_changed.disconnect(_on_phase_changed)
	if is_instance_valid(_player):
		_player.died.disconnect(_on_player_died)
	_rules = rules
	_player = player
	if rules is RoundManager:
		var manager := rules as RoundManager
		manager.money_changed.connect(_on_money_changed)
		manager.phase_changed.connect(_on_phase_changed)
	if is_instance_valid(player):
		player.died.connect(_on_player_died)


## Scales the layout and the icons; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)
	_icon_scale = factor
	_update_icons()


## True while the menu is showing.
func is_open() -> bool:
	return _is_open


## True if the menu may open now: the rules let the player buy (a match with money in freeze
## time, or practice), the developer console is closed and no other menu is open.
func can_open() -> bool:
	if DevConsole.is_open or not _allows_buying():
		return false
	# Not over the pause menu, the settings menu or any other open menu; from the class menu
	# (it opens by itself when a match starts) B switches straight to buying.
	return not MenuState.is_any_open() or MenuState.is_open(self) or MenuState.get_top() is ClassMenu


## Opens the menu if it [method can_open], with the mouse free and shooting blocked. Returns
## true if the menu is open afterwards.
func open() -> bool:
	if _is_open:
		return true
	if not can_open():
		return false
	var top := MenuState.get_top()
	if top is ClassMenu:
		(top as ClassMenu).close()
	_is_open = true
	visible = true
	_selected_category = -1
	_message = ""
	_message_left = 0.0
	# MenuState frees the mouse and makes the player controls stand still.
	MenuState.open(self)
	var controller := _get_controller()
	if controller != null:
		controller.block_shooting()
	set_process(true)
	_refresh()
	return true


## Closes the menu and gives the mouse and the trigger back. Does nothing if it is closed.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	set_process(false)
	# The last menu to close gives the mouse back to the game.
	MenuState.close(self)
	var controller := _get_controller()
	if controller != null:
		controller.unblock_shooting()


## Opens the menu when it is closed and closes it when it is open (the [code]buy_menu[/code] key).
func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## Selects the category [param index] (an index into [enum Shop.Category]): its header lights up
## and the next number key buys that category's item. -1 (or an index that is no category)
## deselects.
func select_category(index: int) -> void:
	_selected_category = index if index >= 0 and index < _headers.size() else -1
	_update_headers()


## The selected category, or -1 for none.
func get_selected_category() -> int:
	return _selected_category


## Buys [param item_id] through the rules ([method RoundManager.request_buy]). Plays the buy sound
## or, when refused, the denied sound and shows the reason at the bottom. Returns "" when bought,
## else the reason. The menu stays open and refreshes.
func buy(item_id: StringName) -> String:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return "Nothing to buy with"
	var reason := _request(item_id)
	if reason == "":
		_play(BUY_SOUND)
		# Done with this item: the next number picks a category again.
		_selected_category = -1
		_show_message("")
	else:
		_play(DENIED_SOUND)
		_show_message(reason)
	_refresh()
	return reason


## The button of [param item_id], or null if the shop has no such item.
func get_item_button(item_id: StringName) -> Button:
	return _buttons.get(item_id) as Button


## The reason line's text while a refusal shows, "" otherwise (the line shows a hint then).
func get_message() -> String:
	return _message


## Builds the five columns from the shop: a header and a button per item, in menu order.
func _build_columns() -> void:
	for _name in Shop.CATEGORY_NAMES:
		_category_items.append([])
	for item in Shop.items():
		_item_by_id[item.id] = item
		_category_items[item.category].append(item.id)
	for category in Shop.CATEGORY_NAMES.size():
		var column := VBoxContainer.new()
		column.name = Shop.CATEGORY_NAMES[category].replace("-", "")
		column.theme_type_variation = &"ContentBox"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_columns.add_child(column)
		var header := Label.new()
		header.name = "Header"
		header.text = "%d  %s" % [category + 1, Shop.CATEGORY_NAMES[category]]
		header.theme_type_variation = &"HeaderLabel"
		column.add_child(header)
		_headers.append(header)
		for index in _category_items[category].size():
			column.add_child(_make_button(_item_by_id[_category_items[category][index]], index))


## One item's button: its icon above its key and name, then its price.
func _make_button(item: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = str(item.id)
	button.text = "%d  %s\n%s" % [index + 1, item.name, _price_text(item.price)]
	button.icon = item.icon
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	# Numbers and the mouse buy; a focused button would also buy again on Space or Enter.
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(buy.bind(item.id))
	_buttons[item.id] = button
	return button


## Whether the rules let the player buy now (the menu's own checks come on top: [method can_open]).
func _allows_buying() -> bool:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return false
	if _rules is RoundManager:
		var manager := _rules as RoundManager
		return manager.has_economy() and manager.can_buy_now(_player)
	if _rules is ArenaRules:
		return (_rules as ArenaRules).can_buy_now(_player)
	return false


## True in practice, where nothing costs money.
func _is_free() -> bool:
	return not _rules is RoundManager


## Asks the rules to sell [param item_id] to the player; "" when sold, else why not.
func _request(item_id: StringName) -> String:
	if _rules is RoundManager:
		return (_rules as RoundManager).request_buy(_player, item_id)
	if _rules is ArenaRules:
		return (_rules as ArenaRules).request_buy(_player, item_id)
	return "Nothing to buy with"


## Why the player can't have [param item_id] now, or "".
func _refusal(item_id: StringName) -> String:
	if _rules is RoundManager:
		return (_rules as RoundManager).get_buy_refusal(_player, item_id)
	if _rules is ArenaRules:
		return (_rules as ArenaRules).get_buy_refusal(_player, item_id)
	return "Nothing to buy with"


## What [param item_id] costs the player now.
func _price(item_id: StringName) -> int:
	if _rules is RoundManager:
		return (_rules as RoundManager).get_price(_player, item_id)
	if _rules is ArenaRules:
		return (_rules as ArenaRules).get_price(_player, item_id)
	return 0


## A price as the buttons show it: "$500", or "FREE".
func _price_text(price: int) -> String:
	return "FREE" if price <= 0 else "$%d" % price


## A number key was pressed ([param number] is 0 for the key 1): it buys that item of the selected
## category, or selects the category of that number.
func _press_number(number: int) -> void:
	if _selected_category >= 0 and number < _category_items[_selected_category].size():
		buy(_category_items[_selected_category][number])
	elif number < _headers.size():
		select_category(number)


## Refreshes everything that depends on what the player has and can afford: the buttons' prices,
## whether they are disabled and why, the headers, the money and the time.
func _refresh() -> void:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return
	for item_id: StringName in _buttons:
		var button := _buttons[item_id] as Button
		var item: Dictionary = _item_by_id[item_id]
		var key := _category_items[item.category].find(item_id) + 1
		button.text = "%d  %s\n%s" % [key, item.name, _price_text(_price(item_id))]
		var reason := _refusal(item_id)
		button.disabled = reason != ""
		button.tooltip_text = reason
	_update_headers()
	_update_header_line()
	_update_message()


## The category headers: all in the accent colour with nothing selected; with a selection, that
## header is bright and the others dim.
func _update_headers() -> void:
	for category in _headers.size():
		var variation := &"HeaderLabel"
		if _selected_category >= 0:
			variation = &"BrightLabel" if category == _selected_category else &"DimLabel"
		_headers[category].theme_type_variation = variation


## The top row: the player's money (or "Free in practice") and the buy time left.
func _update_header_line() -> void:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return
	if _rules is RoundManager:
		var manager := _rules as RoundManager
		_money_label.text = "$ %d" % manager.get_money(_player)
		_time_label.text = "Buy time %d s" % ceili(manager.get_buy_time_left())
		_time_label.visible = true
	else:
		_money_label.text = "Free in practice"
		_time_label.visible = false


## The line at the bottom: the last refusal's reason, else how the keys work.
func _update_message() -> void:
	_message_label.text = _message if _message != "" else \
			"1-5: category, then the item's number.  0: back.  %s or Esc: close." % _buy_key_name()


## The name of the key bound to the buy menu action ("B"), as the hint shows it.
func _buy_key_name() -> String:
	for event in InputMap.action_get_events("buy_menu"):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "B"


func _show_message(reason: String) -> void:
	_message = reason
	_message_left = MESSAGE_TIME
	_update_message()


## Plays a buy sound on the interface bus. Headless runs have no audio device (UiSounds.enabled).
func _play(stream: AudioStream) -> void:
	if not UiSounds.enabled:
		return
	_sound.stream = stream
	_sound.play()


## Gives the buttons their icon at the current UI scale (a theme can't scale a button's icon).
func _update_icons() -> void:
	for item_id: StringName in _buttons:
		var icon := (_item_by_id[item_id] as Dictionary).icon as Texture2D
		(_buttons[item_id] as Button).icon = icon if is_equal_approx(_icon_scale, 1.0) else _scale_icon(icon)


## [param texture] enlarged by the UI scale, nearest-neighbour so it stays as crisp as the theme's.
func _scale_icon(texture: Texture2D) -> Texture2D:
	var source := texture.get_image() if texture != null else null
	if source == null or source.is_compressed():
		return texture
	var image := source.duplicate() as Image
	image.resize(UiTheme.scale_pixels(image.get_width(), _icon_scale), UiTheme.scale_pixels(image.get_height(), _icon_scale),
			Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _get_controller() -> PlayerController:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("PlayerController") as PlayerController


func _on_money_changed(_character: Character, _amount: int, _reason: String) -> void:
	if _is_open:
		_refresh()


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	# The buy time is the freeze time: it is over.
	if phase != RoundManager.Phase.FREEZE:
		close()


func _on_player_died(_killer: Character) -> void:
	close()
