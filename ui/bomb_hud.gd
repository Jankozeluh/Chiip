class_name BombHud
extends Control
## The bomb part of the HUD (D-080; mockups 11 and 12), shown in bomb rounds only:
## - the "Bomb" tag (an ALERT plate with the bomb's icon) above the weapon row in the bottom-right column while the
##   character on show carries the bomb: the plate is part of [code]hud.tscn[/code]'s column, handed over with
##   [method set_carry_plate], and this node only shows and hides it;
## - a prompt under the crosshair: the E key cap and "Hold · plant the bomb" inside a bomb site with the bomb,
##   "Hold · defuse the bomb" next to the planted bomb as a defender; while it happens the key cap gives way to the
##   bomb's (or the kit's) icon, the text says "Planting" or "Defusing", the seconds left show in ALERT and a bar
##   fills under it;
## - toasts ([ToastStack], handed over with [method set_toasts]): you picked up the bomb, it was dropped (for the
##   attackers), and where it was planted (for everyone).
##
## A pure view: it reads the round manager's [Bomb] every frame and listens to its signals, and never changes it.
## [method set_round_manager] hands it the manager (null hides everything); [method set_view_target] the character on
## show (you, or the teammate you spectate). Nothing here takes mouse clicks.
##
## The look comes from the UI theme (D-133): the labels pick roles ([code]KeyCapLabel[/code], [code]HudSmallLabel[/code],
## [code]HudAlertLabel[/code]), the bar's two panels [code]HudProgressBack[/code] and [code]HudProgressFill[/code], and
## its size and the icons' tint come from the theme's "Hud" type and the palette.

## The theme types that hold the HUD's sizes and the palette's named colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## The prompt's texts. "Hold" and the key cap say how, so the key is not in the text.
const PLANT_TEXT := "Hold · plant the bomb"
const DEFUSE_TEXT := "Hold · defuse the bomb"
const PLANTING_TEXT := "Planting"
const DEFUSING_TEXT := "Defusing"
## The toasts' texts; %s is a name or a site's letter.
const PICKED_UP_TEXT := "You picked up the bomb"
const TEAMMATE_PICKED_UP_TEXT := "%s picked up the bomb"
const DROPPED_TEXT := "Bomb dropped"
const PLANTED_TEXT := "Bomb planted at %s"

var _manager: RoundManager
var _bomb: Bomb
## The character the HUD shows: the player, or the teammate being spectated.
var _viewer: Character
var _ui_scale: float = 1.0
## The tag in the bottom-right column (null until the HUD hands it over) and whether it shows.
var _carry_plate: Control
var _carrying: bool = false
var _toasts: ToastStack
## The icon slot the prompt's icon shows now ("" while it is hidden).
var _icon_slot: StringName = &""

@onready var _prompt: Control = $Prompt
@onready var _key: Label = $Prompt/Row/Key
@onready var _key_glyph: TextureRect = $Prompt/Row/KeyGlyph
@onready var _icon: TextureRect = $Prompt/Row/Icon
@onready var _text: Label = $Prompt/Row/Text
@onready var _seconds: Label = $Prompt/Row/Seconds
@onready var _bar: Control = $Prompt/Bar
@onready var _bar_fill: Panel = $Prompt/Bar/Fill


func _ready() -> void:
	_bar.custom_minimum_size = Vector2(_theme_size(&"prompt_bar_width"), _theme_size(&"prompt_bar_height"))
	_icon.set_meta(UiScale.SKIP_SIZE_META, true)
	_icon.modulate = get_theme_color(&"text", PALETTE_TYPE)
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


## The "Bomb" tag this node shows while the character on show carries the bomb (the plate in the HUD's bottom-right column).
func set_carry_plate(plate: Control) -> void:
	_carry_plate = plate
	_carry_plate.visible = _carrying


## The toasts this node announces the bomb's news on (null: no news).
func set_toasts(toasts: ToastStack) -> void:
	_toasts = toasts


## Scales the layout; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(self, factor)
	if _icon.texture != null:
		UiIcons.fit_rect(_icon, factor)


## The prompt text shown right now (empty when hidden). For tests.
func get_prompt() -> String:
	return _text.text if _prompt.visible else ""


## The seconds left of a plant or defuse as the prompt shows them ("2.4"), or "" while nothing is happening. For tests.
func get_seconds() -> String:
	return _seconds.text if _prompt.visible and _seconds.visible else ""


## True while the key cap shows (the prompt says what to hold; it is the icon's instead while it happens). For tests.
func is_key_shown() -> bool:
	return _prompt.visible and (_key.visible or _key_glyph.visible)


## The icon slot of the prompt's icon ("bomb", "defuse_kit"), or "" while it is hidden. For tests.
func get_prompt_icon() -> StringName:
	return _icon_slot if _prompt.visible and _icon.visible else &""


## True while the "Bomb" tag shows. For tests.
func is_carry_shown() -> bool:
	return _carrying


## The progress bar's fill, 0 to 1, or -1 while it is hidden. For tests.
func get_progress_shown() -> float:
	return _bar_fill.anchor_right if _prompt.visible and _bar.visible else -1.0


## The name of the key bound to [param action], e.g. "E" for use. Keys are
## bound by their position (D-012), and this is the name of that position on a
## US keyboard, which is also what CS shows.
static func key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return String(action)


func _process(_delta: float) -> void:
	var bomb := _manager.bomb if is_instance_valid(_manager) else null
	if bomb != _bomb:
		_connect_bomb(bomb)
	if _bomb == null or not is_instance_valid(_viewer):
		_hide_all()
		return
	visible = true
	_set_carrying(_bomb.carrier == _viewer and _bomb.state == Bomb.State.CARRIED)
	_update_prompt()


## The prompt: what to hold (the key cap and the text) when you can plant or defuse, what is happening (the
## icon, the text, the seconds left and the bar) while you do.
func _update_prompt() -> void:
	var text := ""
	var progress := -1.0
	var slot := &""
	var total := 0.0
	if _bomb.actor == _viewer:
		if _bomb.is_planting(_viewer):
			text = PLANTING_TEXT
			slot = &"bomb"
			total = _bomb.settings.plant_time
		else:
			text = DEFUSING_TEXT
			slot = &"defuse_kit" if _bomb.kit_check.call(_viewer) else &"bomb"
			total = _bomb.get_defuse_time(_viewer)
		progress = clampf(_bomb.progress, 0.0, 1.0)
	elif _viewer.is_local_player() and _viewer.is_alive() and _bomb.active:
		if _bomb.carrier == _viewer and _bomb.get_site_of(_viewer) != null:
			text = PLANT_TEXT
		elif _bomb.is_planted() and _viewer.team != _bomb.attacking_team and _near_bomb():
			text = DEFUSE_TEXT
	_prompt.visible = not text.is_empty()
	_text.text = text
	var holding := progress >= 0.0
	_bar.visible = holding
	_seconds.visible = holding
	_set_icon(slot)
	# The key cap follows the device used last (D-213): LB on a gamepad, as the pad's glyph when there is one (v0.2, D-238).
	_key.text = LastInput.prompt_for(&"use") if LastInput.gamepad else key_name(&"use")
	var glyph := PadGlyphs.get_scaled_texture(PadGlyphs.style_for(Settings.get_instance().pad_prompts),
			PadGlyphs.button_for_event(Settings.get_instance().get_pad_binding(&"use")), maxi(1, floori(_ui_scale))) if LastInput.gamepad else null
	_key_glyph.texture = glyph
	_key_glyph.visible = glyph != null and not holding
	_key.visible = not holding and glyph == null
	if holding:
		_bar_fill.set_anchor(SIDE_RIGHT, progress, true)
		_seconds.text = "%.1f" % maxf(0.0, (1.0 - progress) * total)


## Puts the icon of [param slot] in the prompt (hidden for "" or while the slot is empty).
func _set_icon(slot: StringName) -> void:
	if slot == _icon_slot and (slot == &"" or _icon.texture != null):
		return
	_icon_slot = slot
	var texture := UiIcons.get_icon(_icon, slot) if slot != &"" else null
	_icon.texture = texture
	_icon.visible = texture != null
	if texture != null:
		UiIcons.fit_rect(_icon, _ui_scale)


## Shows or hides the "Bomb" tag in the bottom-right column.
func _set_carrying(carrying: bool) -> void:
	_carrying = carrying
	if _carry_plate != null:
		_carry_plate.visible = carrying


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
		_toast(PICKED_UP_TEXT)
	elif Teams.viewer_team == _bomb.attacking_team and _manager.phase == RoundManager.Phase.LIVE:
		_toast(TEAMMATE_PICKED_UP_TEXT % carrier.name)


func _on_dropped(_at: Vector3) -> void:
	if Teams.viewer_team == _bomb.attacking_team:
		_toast(DROPPED_TEXT)


func _on_planted(site: Area3D, _planter: Character) -> void:
	if _toasts != null:
		_toasts.show_toast(ToastStack.Kind.BOMB, PLANTED_TEXT % Bomb.site_letter(site))
	UiSounds.play(UiSounds.BOMB_PLANTED)


## News of the bomb, on a toast.
func _toast(text: String) -> void:
	if _toasts != null:
		_toasts.show_toast(ToastStack.Kind.NEUTRAL, text)


func _theme_size(constant_name: StringName) -> int:
	return get_theme_constant(constant_name, THEME_TYPE)


func _hide_all() -> void:
	if _prompt == null:
		return
	_set_carrying(false)
	_prompt.visible = false
	_bar.visible = false
