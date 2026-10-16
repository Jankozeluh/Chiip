class_name ClassMenu
extends CanvasLayer
## The class menu (D-052, D-078): four cards side by side, one per class, with its key (1 to 4),
## name, height, role, perk and signature gun. Click a card or press its key to take that class;
## the card of your current class is pressed. Esc, or the [code]class_menu[/code] key (M), closes
## it without a change.
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
## Its look comes from the UI theme (D-057): the panel, title, cards and labels use theme type
## variations, and [method set_ui_scale] hands it a theme scaled for the window ([UiTheme]).

## The physical keys that pick a class, in menu order.
const PICK_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

## The class resources in menu order (the same order as the cards).
var _classes: Array[ClassData] = []
## The rules that decide class changes: a [RoundManager], an [ArenaRules] or null.
var _rules: Node
## The character whose class the menu changes (the map's Player).
var _player: Character
var _is_open: bool = false

@onready var _card_row: HBoxContainer = $Panel/Margin/Content/Classes


func _ready() -> void:
	visible = false
	_classes = ClassData.all()
	var cards := _card_row.get_children()
	for i in mini(cards.size(), _classes.size()):
		var card := cards[i] as Control
		_fill_card(card, i, _classes[i])
		(card.get_node("Select") as Button).pressed.connect(pick.bind(i))


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
	if _rules is RoundManager and is_instance_valid(_rules):
		var old := _rules as RoundManager
		old.round_started.disconnect(_on_round_started)
		old.phase_changed.disconnect(_on_phase_changed)
	_rules = rules
	_player = player
	if rules is RoundManager:
		var manager := rules as RoundManager
		manager.round_started.connect(_on_round_started)
		manager.phase_changed.connect(_on_phase_changed)
		if manager.round_number == 1:
			open()


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiTheme.apply(self, factor)


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
	# MenuState frees the mouse and makes the player controls stand still.
	MenuState.open(self)
	var controller := _get_controller()
	if controller != null:
		controller.block_shooting()
	_refresh()
	return true


## Closes the menu and gives the mouse and the trigger back. Does nothing if it is closed.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
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


## Gives the player the class on card [param index] (0 to 3), if the rules allow it, and closes
## the menu. Returns false, leaving the menu open, when the menu is closed, the index is no
## class or the rules refuse (not freeze time).
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


## Shows the texts of one class on its card.
func _fill_card(card: Control, index: int, data: ClassData) -> void:
	var content := card.get_node("Margin/Content")
	(content.get_node("Top/Key") as Label).text = str(index + 1)
	(content.get_node("Name") as Label).text = data.display_name
	(content.get_node("Height") as Label).text = "%.2f m" % data.height
	(content.get_node("Role") as Label).text = data.role
	(content.get_node("PerkName") as Label).text = data.perk_name
	(content.get_node("Perk") as Label).text = data.perk_description
	# The loadout it spawns with where there's no money (team respawn, practice); in rounds
	# everyone starts with the knife and the Sparrow and buys (D-090).
	var loadout: PackedStringArray = []
	for weapon in data.loadout:
		loadout.append(weapon.display_name)
	(content.get_node("Weapon") as Label).text = "Loadout: %s" % ", ".join(loadout) if not loadout.is_empty() \
			else "Gun: %s" % data.signature_weapon
	# The look is too long for the card: it is the hover text.
	(card.get_node("Select") as Button).tooltip_text = data.look


## Marks the player's current class: its card is pressed and says "current".
func _refresh() -> void:
	var cards := _card_row.get_children()
	var current: Button = null
	for i in mini(cards.size(), _classes.size()):
		var is_current := is_instance_valid(_player) and _player.class_data == _classes[i]
		var select := cards[i].get_node("Select") as Button
		select.set_pressed_no_signal(is_current)
		(cards[i].get_node("Margin/Content/Top/Current") as Label).text = "current" if is_current else ""
		if is_current:
			current = select
	if current != null:
		current.grab_focus()


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
