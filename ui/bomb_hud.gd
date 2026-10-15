class_name BombHud
extends Control
## The bomb part of the HUD (D-080), shown in bomb rounds only:
## - a gold "BOMB" tag above the weapon name while the character on show carries it;
## - a prompt under the crosshair: "Hold E to plant" inside a bomb site with the
##   bomb, "Hold E to defuse" next to the planted bomb as a defender, and
##   "Planting" / "Defusing" with a progress bar while it happens;
## - short messages under the top bar: you have the bomb, it was dropped or
##   picked up (for the attackers), and where it was planted (for everyone).
##
## A pure view: it reads the round manager's [Bomb] every frame and listens to
## its signals, and never changes it. [method set_round_manager] hands it the
## manager (null hides everything); [method set_view_target] the character on
## show (you, or the teammate you spectate). Nothing here takes mouse clicks.

## Seconds a message stays before it fades.
const MESSAGE_TIME := 4.0
## Seconds the fade takes.
const MESSAGE_FADE := 0.5
const GOLD := Color(1.0, 0.82, 0.35)
const BAR_BACK := Color(0.05, 0.06, 0.08, 0.8)
const BAR_FILL := Color(1.0, 0.82, 0.35)

var _manager: RoundManager
var _bomb: Bomb
## The character the HUD shows: the player, or the teammate being spectated.
var _viewer: Character
var _message_left: float = 0.0

@onready var _carry_label: Label = $CarryLabel
@onready var _prompt: Label = $Prompt
@onready var _bar: Control = $Bar
@onready var _bar_fill: ColorRect = $Bar/Fill
@onready var _message: Label = $Message


func _ready() -> void:
	($Bar/Back as ColorRect).color = BAR_BACK
	_bar_fill.color = BAR_FILL
	_carry_label.add_theme_color_override("font_color", GOLD)
	_hide_all()


## Shows the bomb of the match run by [param manager], or nothing when it is
## null (practice mode) or the map has no bomb sites.
func set_round_manager(manager: RoundManager) -> void:
	_manager = manager
	_connect_bomb(null)
	_hide_all()


## The character whose bomb state is shown (you, or the teammate you spectate).
func set_view_target(target: Character) -> void:
	_viewer = target


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiScale.apply_tree(self, factor)


## The prompt text shown right now (empty when hidden). For tests.
func get_prompt() -> String:
	return _prompt.text if _prompt.visible else ""


## The message shown right now (empty when hidden). For tests.
func get_message() -> String:
	return _message.text if _message.visible else ""


## True while the gold "BOMB" tag shows. For tests.
func is_carry_shown() -> bool:
	return _carry_label.visible


## The progress bar's fill, 0 to 1, or -1 while it is hidden. For tests.
func get_progress_shown() -> float:
	return _bar_fill.anchor_right if _bar.visible else -1.0


## The name of the key bound to [param action], e.g. "E" for use. Keys are
## bound by their position (D-012), and this is the name of that position on a
## US keyboard, which is also what CS shows.
static func key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return String(action)


func _process(delta: float) -> void:
	var bomb := _manager.bomb if is_instance_valid(_manager) else null
	if bomb != _bomb:
		_connect_bomb(bomb)
	if _bomb == null or not is_instance_valid(_viewer):
		_hide_all()
		return
	visible = true
	_carry_label.visible = _bomb.carrier == _viewer and _bomb.state == Bomb.State.CARRIED
	_update_prompt()
	if _message_left > 0.0:
		_message_left -= delta
		_message.modulate.a = clampf(_message_left / MESSAGE_FADE, 0.0, 1.0)
		_message.visible = _message_left > 0.0


func _update_prompt() -> void:
	var text := ""
	var progress := -1.0
	if _bomb.actor == _viewer:
		if _bomb.is_planting(_viewer):
			text = "Planting"
		else:
			text = "Defusing with kit" if _bomb.kit_check.call(_viewer) else "Defusing"
		progress = clampf(_bomb.progress, 0.0, 1.0)
	elif _viewer.is_local_player() and _viewer.is_alive() and _bomb.active:
		var use_key := key_name(&"use")
		if _bomb.carrier == _viewer and _bomb.get_site_of(_viewer) != null:
			text = "Hold %s to plant" % use_key
		elif _bomb.is_planted() and _viewer.team != _bomb.attacking_team and _near_bomb():
			text = "Hold %s to defuse" % use_key
	_prompt.text = text
	_prompt.visible = not text.is_empty()
	_bar.visible = progress >= 0.0
	if _bar.visible:
		_bar_fill.set_anchor(SIDE_RIGHT, progress, true)


## Close enough to the planted bomb to see the defuse prompt (a little more than the defuse reach).
func _near_bomb() -> bool:
	var offset := _viewer.global_position - _bomb.global_position
	return Vector2(offset.x, offset.z).length() <= Bomb.DEFUSE_DISTANCE * 1.5 and absf(offset.y) <= Bomb.PICKUP_HEIGHT


func _connect_bomb(bomb: Bomb) -> void:
	if is_instance_valid(_bomb):
		for pair in _bomb_connections():
			var signal_to_drop: Signal = pair[0]
			if signal_to_drop.is_connected(pair[1]):
				signal_to_drop.disconnect(pair[1])
	_bomb = bomb
	_message_left = 0.0
	if _bomb == null:
		return
	for pair in _bomb_connections():
		var signal_to_use: Signal = pair[0]
		signal_to_use.connect(pair[1])


func _bomb_connections() -> Array[Array]:
	return [
		[_bomb.picked_up, _on_picked_up],
		[_bomb.dropped, _on_dropped],
		[_bomb.planted, _on_planted],
	]


func _on_picked_up(carrier: Character) -> void:
	if not is_instance_valid(_viewer):
		return
	if carrier == _viewer and _viewer.is_local_player():
		_show_message("You have the bomb", GOLD)
	elif Teams.viewer_team == _bomb.attacking_team and _manager.phase == RoundManager.Phase.LIVE:
		_show_message("%s picked up the bomb" % carrier.name, GOLD)


func _on_dropped(_at: Vector3) -> void:
	if Teams.viewer_team == _bomb.attacking_team:
		_show_message("The bomb was dropped", GOLD)


func _on_planted(site: Area3D, _planter: Character) -> void:
	_show_message("Bomb planted at %s" % Bomb.site_letter(site), Teams.text_color_for(_bomb.attacking_team))
	UiSounds.play(UiSounds.BOMB_PLANTED)


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message.modulate.a = 1.0
	_message.visible = true
	_message_left = MESSAGE_TIME


func _hide_all() -> void:
	if _carry_label == null:
		return
	_carry_label.visible = false
	_prompt.visible = false
	_bar.visible = false
	if _message_left <= 0.0:
		_message.visible = false
