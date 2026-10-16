class_name BuyMenu
extends CanvasLayer
## The buy menu, as the mockup's "14 Buy menu" (M7 task 11, D-098; the look: M10, D-142): the world dimmed, a header ("Buy" and how
## long the buy time lasts, your money), four columns side by side, one per [enum Shop.Category] (Pistols, Primaries, Gear,
## Grenades) with an item for each thing on sale (its icon, its name, its price), and a footer (the icons of what you hold, the
## keys). Click an item to buy it, or press the column's number (1 to 4) and then the item's place in it (1 to 5). The
## [code]buy_menu[/code] key (B) or Esc closes it.
##
## **When it shows:** in a match with money ([RoundManager]) it opens with B during freeze time
## (the buy time) and closes by itself when freeze time ends; in practice ([ArenaRules]) it opens
## at any time and everything is free. Team respawn has no money ([method RoundManager.has_economy]
## is false), so the menu never opens there, and with no rules at all (a free-roam map) it never
## opens either. It also closes when the player dies. The rules decide every purchase
## ([method RoundManager.request_buy], [method ArenaRules.request_buy]); the menu only asks and shows the answer.
##
## **The items** have four looks ([enum ItemState], each a theme type variation of its own): [code]OK[/code] (can be bought; the
## accent frame on hover), [code]FOCUSED[/code] (the one that has the keyboard focus, which the mouse moves to the item it
## is over, as in the class menu; Enter or Space buys it, the arrow keys move it), [code]OWNED[/code] ("Owned" where the price
## was: you have it, or all of a grenade you may carry) and [code]POOR[/code] (not enough money, or not for you: a kit
## for the attackers). Owned and poor items are disabled, with the reason as their tooltip.
##
## **Keys:** a column number selects that column (its header's key lights up in the accent and its line too, the other headers
## dim) and the next number buys that item. A number the selected column has no item for selects
## another column instead (2 items in Pistols: 3 and 4 jump to Gear and Grenades), and 0 or
## Backspace deselects it. A successful buy deselects too, as in CS, so each item is two key
## presses; a refused one keeps the column so you can try another item. The weapon-slot keys
## (1 to 4) do nothing while a menu is open, and these presses are consumed anyway.
##
## **Buying** plays [code]buy.wav[/code] and refreshes the menu; a refusal plays
## [code]buy_denied.wav[/code] and shows its reason in the footer (in the alert colour, in place of the keys' hint) for
## [constant MESSAGE_TIME] seconds. The menu stays open to buy more.
##
## It registers with [MenuState] like every other menu (D-059): while it is open the mouse is
## free, the player controls stand still, Esc closes it instead of opening the pause menu, and it
## won't open over another menu. The dimmed background takes every click, and the character can't
## shoot until it is closed ([method PlayerController.block_shooting]), so a click on an item is
## never also a shot. It stays shut while the developer console is open, and ignores keys the
## console would be typing. While it is open the HUD is hidden ([code]main.gd[/code] listens to
## [signal CanvasLayer.visibility_changed]), as the mockup shows only the dimmed world.
##
## Its look comes from the UI theme (D-057): theme type variations only (the numbers are the "Buy menu" tokens in
## tools/ui_palette.gd, read from the theme's "BuyMenu" type), and [method set_ui_scale] hands it a theme scaled for the
## window ([UiTheme]), so at 1080 p it is exactly 1.5 times as big. The icons come from the theme's icon slots
## ([UiIcons]), at scale 2.

## How an item looks and is: what its button, texts and icon take their type variations from.
enum ItemState { OK, FOCUSED, OWNED, POOR }

## Seconds a refusal's reason stays in the footer.
const MESSAGE_TIME := 2.0
## The key that goes back to "no category selected".
const BACK_KEYS: Array[Key] = [KEY_0, KEY_BACKSPACE]
## The physical number keys, in order: 1 is the first (a category or an item).
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const BUY_SOUND := preload("res://assets/sounds/buy.wav")
const DENIED_SOUND := preload("res://assets/sounds/buy_denied.wav")

## The theme type that holds the sizes the menu reads (a header's and an item's height, the box of an item's icon).
const SIZES_TYPE := &"BuyMenu"
## The theme type of the palette's named colours (an icon's tint).
const PALETTE_TYPE := &"Palette"
## The type variation of the selected column's header edge, and of the others'.
const HEADER_LIT := &"ColumnHeaderLitPanel"
const HEADER_UNLIT := &"ColumnHeaderPanel"
## The type variations of a column's key and name: at rest, selected, and unselected while another one is.
const KEY_REST := &"MuteLabel"
const KEY_LIT := &"HeaderLabel"
const NAME_REST := &"BrightLabel"
const NAME_UNLIT := &"DimLabel"
## The footer's hint at rest and a refusal's reason in its place.
const HINT_REST := &"MuteLabel"
const HINT_REASON := &"AlertLabel"
## What each look of an item takes: the button's type variation, those of the name and the price, and the palette
## colour that tints the icon (the icons are white).
const ITEM_LOOKS := {
	ItemState.OK: {"button": &"BuyItemOk", "name": &"BrightLabel", "price": &"BrightLabel", "tint": &"text"},
	ItemState.FOCUSED: {"button": &"BuyItemFocused", "name": &"BrightLabel", "price": &"HeaderLabel", "tint": &"text"},
	ItemState.OWNED: {"button": &"BuyItemOwned", "name": &"DimLabel", "price": &"DimLabel", "tint": &"text_dim"},
	ItemState.POOR: {"button": &"BuyItemPoor", "name": &"MuteLabel", "price": &"MuteLabel", "tint": &"mute"},
}

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
## Each item's parts by item id: "Holder" (the item's box), "Select" (the button), "Icon", "Name" and "Price".
var _parts: Dictionary = {}
## Each column's parts, in category order: "Column", "Header" (the panel with the edge), "Key" and "Name" (the labels).
var _column_parts: Array[Dictionary] = []
## The state each item showed last, by item id.
var _states: Dictionary = {}
## The held icons in the footer now.
var _held_icons: Array[TextureRect] = []

@onready var _columns: HBoxContainer = $Margin/Page/Columns
@onready var _title: Label = $Margin/Page/Header/Left/TitleTrim/Title
@onready var _situation: Label = $Margin/Page/Header/Left/Situation
@onready var _money_label: Label = $Margin/Page/Header/MoneyTrim/Money
@onready var _footer: PanelContainer = $Margin/Page/Footer
@onready var _hold_row: HBoxContainer = $Margin/Page/Footer/FooterRow/Hold
@onready var _hint: Label = $Margin/Page/Footer/FooterRow/Hint
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	visible = false
	set_process(false)
	_build_columns()
	_fit()
	_update_icons()
	_update_message()
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
	# The apply gave the boxes back their scene sizes (none): the sizes come from the theme. The
	# icons are the new theme's (scaled) ones.
	_fit()
	_update_icons()
	_update_held()


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
	# An item that keeps the keyboard focus would take the next Space (jump) as a click.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
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
	_selected_category = index if index >= 0 and index < _column_parts.size() else -1
	_update_headers()


## The selected category, or -1 for none.
func get_selected_category() -> int:
	return _selected_category


## Buys [param item_id] through the rules ([method RoundManager.request_buy]). Plays the buy sound
## or, when refused, the denied sound and shows the reason in the footer. Returns "" when bought,
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
	return get_item_part(item_id, "Select") as Button


## One part of [param item_id]'s item by its node name ("Holder", "Select", "Icon", "Name", "Price"), or null.
func get_item_part(item_id: StringName, part: String) -> Control:
	return (_parts.get(item_id, {}) as Dictionary).get(part) as Control


## How [param item_id] looks and is now (see [enum ItemState]).
func get_item_state(item_id: StringName) -> ItemState:
	return _states.get(item_id, ItemState.OK)


## One part of column [param index] ("Column", "Header", "Key", "Name").
func get_column_part(index: int, part: String) -> Control:
	return _column_parts[index][part] as Control


## The row the columns stand in.
func get_columns_row() -> HBoxContainer:
	return _columns


## The title ("Buy"), the line beside it ("Defending · closes in 9"), the money and the footer's hint (or the refusal in its place).
func get_title_label() -> Label:
	return _title


func get_situation_label() -> Label:
	return _situation


func get_money_label() -> Label:
	return _money_label


func get_hint_label() -> Label:
	return _hint


## The footer's panel and the row of what you hold.
func get_footer() -> PanelContainer:
	return _footer


func get_hold_row() -> HBoxContainer:
	return _hold_row


## The icons in the footer's "You hold" row, in order.
func get_held_icons() -> Array[TextureRect]:
	return _held_icons


## The icon slots of what the player holds, in the order the footer shows them: the long gun, the pistol, the vest, the
## helmet, the defuse kit, then each grenade (a kind twice if two are carried). The knife is not shown: everyone has one.
func get_held_slots() -> Array[StringName]:
	var slots: Array[StringName] = []
	if not is_instance_valid(_player):
		return slots
	for slot in [WeaponData.Slot.PRIMARY, WeaponData.Slot.PISTOL]:
		var weapon := _player.inventory.get_in_slot(slot)
		if weapon != null:
			slots.append(weapon.data.id)
	if _player.armor > 0.0:
		slots.append(&"armor")
	if _player.has_helmet:
		slots.append(&"helmet")
	if _player.has_defuse_kit:
		slots.append(&"defuse_kit")
	for grenade in _player.inventory.get_grenades():
		for i in grenade.magazine:
			slots.append(grenade.data.id)
	return slots


## The reason line's text while a refusal shows, "" otherwise (the footer shows the keys' hint then).
func get_message() -> String:
	return _message


## Builds the columns from the shop: a header and an item per thing on sale, in menu order.
func _build_columns() -> void:
	for _name in Shop.CATEGORY_NAMES:
		_category_items.append([])
	for item in Shop.items():
		_item_by_id[item.id] = item
		_category_items[item.category].append(item.id)
	for category in Shop.CATEGORY_NAMES.size():
		var column := VBoxContainer.new()
		column.name = Shop.CATEGORY_NAMES[category]
		column.theme_type_variation = &"BuyColumn"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_columns.add_child(column)
		var header := PanelContainer.new()
		header.name = "Header"
		header.theme_type_variation = HEADER_UNLIT
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(header)
		var header_row := HBoxContainer.new()
		header_row.theme_type_variation = &"SlotRow"
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(header_row)
		var key := _make_label("Key", str(category + 1), KEY_REST)
		var column_name := _make_label("Name", Shop.CATEGORY_NAMES[category], NAME_REST)
		header_row.add_child(key)
		header_row.add_child(column_name)
		_column_parts.append({"Column": column, "Header": header, "Key": key, "Name": column_name})
		var items := VBoxContainer.new()
		items.name = "Items"
		items.theme_type_variation = &"ContentBox"
		items.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(items)
		for item_id: StringName in _category_items[category]:
			items.add_child(_make_item(_item_by_id[item_id]))


## One item: a button that is only the frame, and on top of it (clicks go through) a row with the icon in its box, the name
## and the price, padded by the frame's width and the item's own padding.
func _make_item(item: Dictionary) -> Control:
	var holder := MarginContainer.new()
	holder.name = str(item.id)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.name = "Select"
	# Numbers, the mouse and the focus buy; the focus follows the mouse, and it is what makes an item "focused".
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(buy.bind(item.id))
	button.mouse_entered.connect(_on_item_hovered.bind(item.id))
	button.focus_entered.connect(_update_items)
	button.focus_exited.connect(_update_items)
	holder.add_child(button)
	var frame := MarginContainer.new()
	frame.theme_type_variation = &"FrameMargin"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	var padding := MarginContainer.new()
	padding.theme_type_variation = &"SlotMargin"
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(padding)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"SlotRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_child(row)
	var icon := _make_icon_rect("Icon")
	var item_name := _make_label("Name", item.name, NAME_REST)
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A name that is too long for the item is cut rather than making its column wider than the others.
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var price := _make_label("Price", "", NAME_REST)
	row.add_child(icon)
	row.add_child(item_name)
	row.add_child(price)
	_parts[item.id] = {"Holder": holder, "Select": button, "Icon": icon, "Name": item_name, "Price": price}
	return holder


## A label with the type variation [param role], centred between the top and bottom of its row.
func _make_label(label_name: String, text: String, role: StringName) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.theme_type_variation = role
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A picture that takes no clicks: the texture at its own size times the box it stands in, centred, crisp.
func _make_icon_rect(rect_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = rect_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Gives the headers, items and icon boxes their sizes: the theme's "BuyMenu" sizes, scaled with the UI.
func _fit() -> void:
	for parts in _column_parts:
		(parts["Header"] as Control).custom_minimum_size.y = _size_of(&"header_height")
	for item_id: StringName in _parts:
		(_parts[item_id]["Holder"] as Control).custom_minimum_size.y = _size_of(&"item_height")
		(_parts[item_id]["Icon"] as Control).custom_minimum_size = Vector2(_size_of(&"icon_box_width"), _size_of(&"icon_box_height"))


## One of the theme's "BuyMenu" sizes, scaled for the menu's scale.
func _size_of(item: StringName) -> int:
	return _columns.get_theme_constant(item, SIZES_TYPE)


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


## A price as the items show it: "$500", or "FREE".
func _price_text(price: int) -> String:
	return "FREE" if price <= 0 else "$%d" % price


## A number key was pressed ([param number] is 0 for the key 1): it buys that item of the selected
## category, or selects the category of that number.
func _press_number(number: int) -> void:
	if _selected_category >= 0 and number < _category_items[_selected_category].size():
		buy(_category_items[_selected_category][number])
	elif number < _column_parts.size():
		select_category(number)


## Refreshes everything that depends on what the player has and can afford: the items' looks, prices and tooltips, the
## headers, the money, the buy time, what you hold, the reason line.
func _refresh() -> void:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return
	_update_items()
	_update_headers()
	_update_header_line()
	_update_held()
	_update_message()


## The items: each one's state and, with it, its look (the button's and the texts' type variations, the icon's tint), its
## price (or "Owned") and the reason it can't be bought as its tooltip.
func _update_items() -> void:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return
	for item_id: StringName in _parts:
		var parts: Dictionary = _parts[item_id]
		var button := parts["Select"] as Button
		var reason := _refusal(item_id)
		var state := _state_of(item_id, button, reason)
		_states[item_id] = state
		var look: Dictionary = ITEM_LOOKS[state]
		button.theme_type_variation = look["button"]
		button.disabled = reason != ""
		button.tooltip_text = reason
		(parts["Name"] as Control).theme_type_variation = look["name"]
		var price := parts["Price"] as Label
		price.theme_type_variation = look["price"]
		price.text = "Owned" if state == ItemState.OWNED else _price_text(_price(item_id))
		(parts["Icon"] as Control).modulate = button.get_theme_color(look["tint"], PALETTE_TYPE)


## How [param item_id] looks: owned when the player has it, poor when it can't be bought ([param reason] says why not),
## focused when it can and its button has the focus, else ok.
func _state_of(item_id: StringName, button: Button, reason: String) -> ItemState:
	if Shop.is_owned(_player, item_id):
		return ItemState.OWNED
	if reason != "":
		return ItemState.POOR
	return ItemState.FOCUSED if button.has_focus() else ItemState.OK


## The category headers: with nothing selected the key is MUTE and the name TEXT; with a selection, that header's key and edge
## are the accent and the others' names dim.
func _update_headers() -> void:
	for category in _column_parts.size():
		var parts := _column_parts[category]
		var selected := category == _selected_category
		(parts["Header"] as Control).theme_type_variation = HEADER_LIT if selected else HEADER_UNLIT
		(parts["Key"] as Control).theme_type_variation = KEY_LIT if selected else KEY_REST
		(parts["Name"] as Control).theme_type_variation = NAME_UNLIT if _selected_category >= 0 and not selected else NAME_REST


## The header: your money (or "Free" in practice) and your side with the buy time left ("Defending · closes in 9";
## "Practice · any time" there).
func _update_header_line() -> void:
	if not is_instance_valid(_rules) or not is_instance_valid(_player):
		return
	if _rules is RoundManager:
		var manager := _rules as RoundManager
		_money_label.text = "$%d" % manager.get_money(_player)
		var side := "Defending" if manager.get_side(_player.team) == Teams.Side.DEFENDING else "Attacking"
		_situation.text = "%s · closes in %d" % [side, ceili(manager.get_buy_time_left())]
	else:
		_money_label.text = "Free"
		_situation.text = "Practice · any time"


## The footer's right side: the last refusal's reason (in the alert colour), else how the keys work.
func _update_message() -> void:
	_hint.text = _message if _message != "" else "Click, or 1-%d then 1-%d · %s closes" % [_column_parts.size(), _most_items(), _buy_key_name()]
	_hint.theme_type_variation = HINT_REASON if _message != "" else HINT_REST


## The most items any column has (the keys' hint says "1-5").
func _most_items() -> int:
	var most := 0
	for items in _category_items:
		most = maxi(most, items.size())
	return most


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


## Gives the items their icon from the UI's icon slots, as the current theme (the UI scale) has them.
func _update_icons() -> void:
	for item_id: StringName in _parts:
		var rect := _parts[item_id]["Icon"] as TextureRect
		rect.texture = UiIcons.get_icon(rect, Shop.icon_slot(item_id))


## Rebuilds the footer's icons: what the player holds ([method get_held_slots]), each at scale 2 (the theme's icon, at the
## UI's scale, times the icon box's height over the icon's own height).
func _update_held() -> void:
	for icon in _held_icons:
		_hold_row.remove_child(icon)
		icon.queue_free()
	_held_icons.clear()
	for slot in get_held_slots():
		var rect := _make_icon_rect("Held_%s" % slot)
		_hold_row.add_child(rect)
		var texture := UiIcons.get_icon(rect, slot)
		if texture == null:
			rect.queue_free()
			continue
		rect.texture = texture
		rect.custom_minimum_size = Vector2(texture.get_size()) * (float(_size_of(&"icon_box_height")) / maxf(texture.get_height(), 1.0))
		rect.modulate = rect.get_theme_color(&"text", PALETTE_TYPE)
		_held_icons.append(rect)


func _get_controller() -> PlayerController:
	if not is_instance_valid(_player):
		return null
	return _player.get_node_or_null("PlayerController") as PlayerController


## The mouse is over an item: it takes the keyboard focus (and with it the focused look) if it can be bought.
func _on_item_hovered(item_id: StringName) -> void:
	var button := get_item_button(item_id)
	if _is_open and not button.disabled:
		button.grab_focus()


func _on_money_changed(_character: Character, _amount: int, _reason: String) -> void:
	if _is_open:
		_refresh()


func _on_phase_changed(phase: RoundManager.Phase) -> void:
	# The buy time is the freeze time: it is over.
	if phase != RoundManager.Phase.FREEZE:
		close()


func _on_player_died(_killer: Character) -> void:
	close()
