extends CanvasLayer
## The in-game HUD (mockups 09 to 13): crosshair, the bottom corners, the death view and the
## spectate view. Listens to the player's weapon through its signals.
##
## Bottom left: health (icon, number, and under it ten chips, one per 10 health, in Team Deathmatch
## and practice), armor (the helmet's icon when you wear one; hidden at 0), the defuse kit, and in a
## match with money the money with a hint for the buy key. Bottom right: the weapon's name and icon,
## the magazine and the reserve. Low health (and a low magazine) turn to the alert colour.
##
## When you die the corners give way to the death view: the world is tinted, a respawn countdown
## (team respawn matches) and a plate saying who killed you with what, and how much health they
## have left. While you spectate a teammate (see [PlayerController]) a row with their health, armor
## and weapon, over a plate with their name, replaces the corners. In a match the [RoundHud] child
## adds the top bar, banners and kill feed, and in bomb rounds the [BombHud] child the bomb tag,
## prompts and messages.
##
## A pure view: it only reads the game's state. The look comes from the UI theme (D-133, D-141):
## the scene's controls pick roles, the sizes of the drawn parts and the state colours come from
## the theme's "Hud" type and the palette ("Palette" type), and the icons from [UiIcons].
## Everything is scaled by [UiScale].

## Magazine counts at or below this fraction of a full magazine are shown in the alert colour.
const LOW_AMMO_FRACTION := 0.25
## Health at or below this is shown in the alert colour.
const LOW_HEALTH := 25.0
## The ringing in your ears after a flashbang (D-097), as loud as the flash was strong.
const FLASH_RING := preload("res://assets/sounds/flash_ring.wav")
## How grey the view gets inside a smoke cloud at its thickest (1 = nothing shows through).
const SMOKE_OPACITY := 0.97
## How many reward lines show at once, and for how long each (seconds).
const REWARD_LINES := 3
const REWARD_TIME := 3.0
## Seconds the weapon list shows after a change, and how long it then takes to fade (the list itself is hidden).
const SLOTS_SHOW_TIME := 2.5
const SLOTS_FADE_TIME := 0.5
## The theme types that hold the HUD's sizes and state colours, and the palette's named colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## The countdown to your respawn in a team respawn match; %d is the seconds left.
const RESPAWN_TEXT := "Respawning in %d"
## Practice brings you back at once: the plate just says so.
const PRACTICE_RESPAWN_TEXT := "Respawning..."
## The scale of the small icons (the spectate row, the killer's weapon): the icon set's own size. The corners'
## icons are [code]icon_scale[/code] times that (the theme's "Hud" type).
const ICON_NORMAL := 1
## The roles of a health chip: full while that 10 HP is there, empty when gone.
const CHIP_FULL := &"HudHealthChip"
const CHIP_EMPTY := &"HudHealthChipEmpty"

## The player whose weapon the HUD shows. Set with [method set_player].
var player: Character
## The character whose health, ammo and weapon the HUD shows right now: the
## player, or the teammate being spectated.
var shown: Character
## Say "Respawning..." on the death plate (practice mode brings you back;
## in a match the dead wait for the next round or the countdown).
var respawn_hint: bool = true

## The weapon whose ammo the labels follow.
var _watched_weapon: Weapon
## The match whose money the HUD shows (null: none).
var _manager: RoundManager
## The reward lines showing: [text, seconds left].
var _rewards: Array = []
## Seconds the weapon list keeps showing.
var _slots_show_left: float = 0.0
## The player is dead: no crosshair until the respawn.
var _player_dead: bool = false
## Who killed the player, and with which weapon (null: nobody, or something that isn't a weapon).
var _killer: Character
var _killer_weapon: WeaponData
var _ring_audio: AudioStreamPlayer
var _ui_scale: float = 1.0
var _chips: Array[Panel] = []

@onready var _crosshair: Crosshair = $Crosshair
@onready var _dead_tint: Panel = %DeadTint
@onready var _bottom_left: Control = %BottomLeft
@onready var _bottom_right: Control = %BottomRight
@onready var _money_row: Control = %MoneyRow
@onready var _money_label: Label = %MoneyLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _buy_hint: Control = %BuyHint
@onready var _buy_key: Label = %BuyKey
@onready var _health_icon: TextureRect = %HealthIcon
@onready var _health_label: Label = %HealthLabel
@onready var _health_chips: HBoxContainer = %HealthChips
@onready var _armor_block: Control = %ArmorBlock
@onready var _armor_icon: TextureRect = %ArmorIcon
@onready var _armor_label: Label = %ArmorLabel
@onready var _kit_icon: TextureRect = %KitIcon
@onready var _weapon_label: Label = %WeaponLabel
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _ammo_row: Control = %AmmoRow
@onready var _mag_label: Label = %MagLabel
@onready var _reserve_label: Label = %ReserveLabel
@onready var _slots_label: Label = $SlotsLabel
@onready var _spectate_box: Control = %SpectateBox
@onready var _mini_health_icon: TextureRect = %MiniHealthIcon
@onready var _mini_health_label: Label = %MiniHealthLabel
@onready var _mini_armor_icon: TextureRect = %MiniArmorIcon
@onready var _mini_armor_label: Label = %MiniArmorLabel
@onready var _mini_gun_icon: TextureRect = %MiniGunIcon
@onready var _mini_gun_label: Label = %MiniGunLabel
@onready var _spectate_plate: Control = %SpectatePlate
@onready var _spectate_name: Label = %SpectateName
@onready var _death_column: Control = %DeathColumn
@onready var _countdown_label: Label = %Countdown
@onready var _death_plate: Control = %DeathPlate
@onready var _killed_label: Label = %KilledLabel
@onready var _killer_label: Label = %KillerLabel
@onready var _killer_icon: TextureRect = %KillerIcon
@onready var _death_dot: Label = %DeathDot
@onready var _respawn_label: Label = %RespawnLabel
@onready var _killer_hp: Label = %KillerHp
@onready var _scope_overlay: ScopeOverlay = $ScopeOverlay
@onready var _smoke_overlay: ColorRect = $SmokeOverlay
@onready var _flash_overlay: ColorRect = $FlashOverlay
@onready var _round_hud: RoundHud = $RoundHud
@onready var _bomb_hud: BombHud = $BombHud


func _ready() -> void:
	_build_chips()
	var plate_height := float(_theme_size(&"plate_height"))
	_death_plate.custom_minimum_size.y = plate_height
	_spectate_plate.custom_minimum_size.y = plate_height
	# The icons are sized from their textures (see _set_icon), not by UiScale; they are white and take a tint.
	for rect in [_health_icon, _armor_icon, _kit_icon, _weapon_icon, _mini_health_icon, _mini_armor_icon,
			_mini_gun_icon, _killer_icon]:
		var icon_rect: TextureRect = rect
		icon_rect.set_meta(UiScale.SKIP_SIZE_META, true)
		icon_rect.modulate = _palette(&"text")


## Shows this player's weapon on the HUD.
func set_player(new_player: Character) -> void:
	player = new_player
	player.flashed.connect(_on_player_flashed)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	_crosshair.camera = player.get_camera()
	set_view_target(player)
	_update_money()


## Shows the round HUD (top bar, countdown, banners, kill feed) for the match
## run by [param manager], or hides it when null (practice mode). Called on
## every map load; the previous manager is dropped.
func set_round_manager(manager: RoundManager) -> void:
	_round_hud.set_round_manager(manager)
	_bomb_hud.set_round_manager(manager)
	if is_instance_valid(_manager) and _manager.money_changed.is_connected(_on_money_changed):
		_manager.money_changed.disconnect(_on_money_changed)
	_manager = manager
	_rewards.clear()
	_reward_label.text = ""
	if manager != null:
		manager.money_changed.connect(_on_money_changed)
	_update_money()


## Shows the health, ammo and weapon of [param target] instead of the player's
## own, and the spectate view when it is somebody else. The player's
## [signal PlayerController.view_target_changed] is connected to this.
func set_view_target(target: Character) -> void:
	if shown != null and is_instance_valid(shown):
		_watch_weapon(null)
		shown.weapon_changed.disconnect(_on_shown_weapon_changed)
		shown.damaged.disconnect(_on_shown_damaged)
		shown.gear_changed.disconnect(_update_armor)
		shown.inventory.changed.disconnect(_update_slots)
	shown = target
	_bomb_hud.set_view_target(target)
	_watch_weapon(shown.weapon)
	shown.weapon_changed.connect(_on_shown_weapon_changed)
	shown.damaged.connect(_on_shown_damaged)
	shown.gear_changed.connect(_update_armor)
	shown.inventory.changed.connect(_update_slots)
	_update_health()
	_update_armor()
	_update_slots()
	_show_weapon()
	_update_view()


## Scales the HUD layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	for root: Control in [_bottom_left, _bottom_right, _spectate_box, _death_column, _slots_label]:
		UiScale.apply_tree(root, factor)
	_crosshair.set_ui_scale(factor)
	_scope_overlay.set_ui_scale(factor)
	_round_hud.set_ui_scale(factor)
	_bomb_hud.set_ui_scale(factor)
	# The icons are sized from their textures and the scale.
	if shown != null and is_instance_valid(shown):
		_update_health()
		_update_armor()
		_show_weapon()
		_update_death()


## The text of the respawn countdown ("Respawning in 3"), or "" while there is none (alive, practice,
## a rounds match, or the round or match is over). For tests.
func get_respawn_text() -> String:
	return RESPAWN_TEXT % ceili(_respawn_time_left()) if _death_column.visible and _respawn_time_left() > 0.0 else ""


func _process(delta: float) -> void:
	if not _rewards.is_empty():
		for reward: Array in _rewards:
			reward[1] -= delta
		var before := _rewards.size()
		_rewards = _rewards.filter(func(reward: Array) -> bool: return reward[1] > 0.0)
		if _rewards.size() != before:
			_show_rewards()
	if _slots_show_left > 0.0:
		_slots_show_left -= delta
		_slots_label.modulate.a = clampf(_slots_show_left / SLOTS_FADE_TIME, 0.0, 1.0)
	# Blinded by a flashbang: white, fading (also a spectated teammate's). Inside smoke: grey.
	var flash := shown.get_flash_alpha() if shown != null and is_instance_valid(shown) else 0.0
	_flash_overlay.color.a = flash
	_flash_overlay.visible = flash > 0.0
	var camera := player.get_camera() if player != null and is_instance_valid(player) else null
	var smoke := Smokes.density_at(camera.global_position) * SMOKE_OPACITY if camera != null else 0.0
	_smoke_overlay.color.a = smoke
	_smoke_overlay.visible = smoke > 0.0
	# A scope shows its own view; a sniper rifle has no crosshair unscoped either, as in CS.
	var weapon := shown.weapon if shown != null and is_instance_valid(shown) else null
	_scope_overlay.visible = weapon != null and weapon.is_scoped()
	_crosshair.visible = not _player_dead and not (weapon != null and weapon.data.has_scope())
	if player != null and player.weapon != null and _crosshair.dynamic:
		_crosshair.spread_degrees = player.weapon.get_inaccuracy()
		_crosshair.queue_redraw()
	_update_buy_hint()
	if _player_dead:
		_update_death()


## The player has to see the buy hint only while the rules let them buy.
func _update_buy_hint() -> void:
	var can_buy := _money_row.visible and is_instance_valid(_manager) and player != null \
			and is_instance_valid(player) and shown == player and _manager.can_buy_now(player)
	_buy_hint.visible = can_buy
	if can_buy:
		_buy_key.text = _buy_key_name()


## The name of the key bound to the buy menu action ("B"), as the hint shows it.
func _buy_key_name() -> String:
	for event in InputMap.action_get_events("buy_menu"):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "B"


## Connects the ammo and reload labels to [param weapon] (null: to nothing), dropping the old one.
func _watch_weapon(weapon: Weapon) -> void:
	if _watched_weapon != null and is_instance_valid(_watched_weapon):
		_watched_weapon.ammo_changed.disconnect(_on_ammo_changed)
		_watched_weapon.reload_started.disconnect(_update_weapon_label)
		_watched_weapon.reload_finished.disconnect(_update_weapon_label)
	_watched_weapon = weapon
	if weapon != null:
		weapon.ammo_changed.connect(_on_ammo_changed)
		weapon.reload_started.connect(_update_weapon_label)
		weapon.reload_finished.connect(_update_weapon_label)


## The character on show took out another weapon (D-094).
func _on_shown_weapon_changed(weapon: Weapon) -> void:
	_watch_weapon(weapon)
	_show_weapon()
	_update_slots()


## Shows the ammo, name and icon of the weapon in the shown character's hand.
func _show_weapon() -> void:
	var weapon := shown.weapon
	if weapon == null:
		_mag_label.text = ""
		_reserve_label.text = ""
		_ammo_row.visible = false
		_weapon_label.text = ""
		_set_icon(_weapon_icon, &"", ICON_NORMAL)
		_set_icon(_mini_gun_icon, &"", ICON_NORMAL)
		_mini_gun_label.text = ""
		return
	_on_ammo_changed(weapon.magazine, weapon.reserve)
	_update_weapon_label()


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	var weapon := shown.weapon
	if weapon == null or weapon.data.is_melee():
		_mag_label.text = ""
		_reserve_label.text = ""
		_ammo_row.visible = false
		_mini_gun_label.text = ""
		return
	_ammo_row.visible = true
	if weapon.data.is_grenade():
		_mag_label.text = "× %d" % magazine
		_reserve_label.visible = false
		_mini_gun_label.text = _mag_label.text
		_tint_label(_mag_label, false)
		return
	_mag_label.text = "%d" % magazine
	_reserve_label.text = "/ %d" % reserve
	_reserve_label.visible = true
	_mini_gun_label.text = "%d / %d" % [magazine, reserve]
	_tint_label(_mag_label, magazine <= weapon.data.magazine_size * LOW_AMMO_FRACTION)


## The weapon's name (with "reloading" while it reloads) and its icon, big in the corner and small in the spectate row.
func _update_weapon_label() -> void:
	var weapon := shown.weapon
	if weapon == null:
		_weapon_label.text = ""
		return
	_weapon_label.text = weapon.data.display_name + ("  ·  reloading" if weapon.is_reloading() else "")
	_set_icon(_weapon_icon, weapon.data.id, _theme_size(&"icon_scale"))
	_set_icon(_mini_gun_icon, weapon.data.id, ICON_NORMAL)


## Lists what the shown character carries, one line per slot, the held one bright (D-094). It
## shows for a few seconds after a change, as CS's weapon list does; the list is not in the
## mockups, so its label stays hidden (the data is kept for a test).
func _update_slots() -> void:
	var lines: PackedStringArray = []
	var held := shown.weapon
	for slot in [WeaponData.Slot.PRIMARY, WeaponData.Slot.PISTOL, WeaponData.Slot.KNIFE, WeaponData.Slot.GRENADE]:
		var text := ""
		var holding := false
		if slot == WeaponData.Slot.GRENADE:
			var names: PackedStringArray = []
			for grenade in shown.inventory.get_grenades():
				names.append(grenade.data.display_name + (" ×%d" % grenade.magazine if grenade.magazine > 1 else ""))
				holding = holding or grenade == held
			text = ", ".join(names)
		else:
			var weapon := shown.inventory.get_in_slot(slot)
			if weapon != null:
				text = weapon.data.display_name
				holding = weapon == held
		if text != "":
			lines.append(("» " if holding else "") + "%d  %s" % [slot + 1, text])
	_slots_label.text = "\n".join(lines)
	_slots_label.modulate.a = 1.0
	_slots_show_left = SLOTS_SHOW_TIME


func _on_shown_damaged(_amount: float, _zone: Hitbox.Zone, _attacker: Character) -> void:
	_update_health()


## Shows the health of the character on show, rounded up so 0.4 HP still shows
## as 1 while alive: the number, the chips (one per 10 health, a started 10 counts) and the
## small number in the spectate row. Health at or below [constant LOW_HEALTH] turns the icon
## and the number to the alert colour.
func _update_health() -> void:
	var low := shown.health <= LOW_HEALTH
	_health_label.text = "%d" % ceili(shown.health)
	_mini_health_label.text = _health_label.text
	_tint_label(_health_label, low)
	_health_icon.modulate = _palette(&"alert" if low else &"text")
	_set_icon(_health_icon, &"health", _theme_size(&"icon_scale"))
	_set_icon(_mini_health_icon, &"health", ICON_NORMAL)
	var filled := ceili(shown.health / _theme_size(&"chip_health"))
	for i in _chips.size():
		var role := CHIP_FULL if i < filled else CHIP_EMPTY
		if _chips[i].theme_type_variation != role:
			_chips[i].theme_type_variation = role
			UiScale.apply_tree(_chips[i], _ui_scale)
	if shown != player:
		_update_spectate_name()


## Shows the armor of the character on show: its points (rounded up, like health) next to the
## shield (the helmet's icon when it has one, D-093); the whole block is hidden at 0. The defuse
## kit (defenders, D-098) is an icon after it.
func _update_armor() -> void:
	var has_armor := shown.armor > 0.0
	_armor_block.visible = has_armor
	_armor_label.text = "%d" % ceili(shown.armor)
	_mini_armor_label.text = _armor_label.text
	var slot := &"helmet" if shown.has_helmet else &"armor"
	_set_icon(_armor_icon, slot, _theme_size(&"icon_scale"))
	_set_icon(_mini_armor_icon, slot, ICON_NORMAL)
	_mini_armor_icon.visible = has_armor and _mini_armor_icon.texture != null
	_mini_armor_label.visible = has_armor
	_set_icon(_kit_icon, &"defuse_kit", ICON_NORMAL, shown.has_defuse_kit)


## Shows your money (D-098) in a match with an economy; hidden otherwise (and then the health
## chips are shown: the Bomb layout has none).
func _update_money() -> void:
	var shows := is_instance_valid(_manager) and _manager.has_economy() and player != null and is_instance_valid(player)
	_money_row.visible = shows
	_health_chips.visible = not shows
	if shows:
		_money_label.text = "$%d" % _manager.get_money(player)
	_reward_label.visible = shows and not _rewards.is_empty()


## Your money changed: the new total, and a line saying why ("+$200  Kill"), newest at the bottom.
func _on_money_changed(character: Character, amount: int, reason: String) -> void:
	if character != player:
		return
	_update_money()
	if reason == "New half" or amount == 0:
		return
	var sign := "+" if amount > 0 else "-"
	_rewards.append(["%s$%d  %s" % [sign, absi(amount), reason], REWARD_TIME])
	while _rewards.size() > REWARD_LINES:
		_rewards.pop_front()
	_show_rewards()


func _show_rewards() -> void:
	_reward_label.text = "\n".join(_rewards.map(func(reward: Array) -> String: return reward[0]))
	_reward_label.visible = _money_row.visible and not _rewards.is_empty()


# --- Deciding what shows: the corners, the death view, the spectate view ---


## The corners show while you are alive and watching yourself; the spectate view while you watch
## a teammate; the death view (the tint and the plate) while you are dead and watching nobody.
func _update_view() -> void:
	var spectating := shown != player
	var dead_view := _player_dead and not spectating
	_bottom_left.visible = not spectating and not _player_dead
	_bottom_right.visible = not spectating and not _player_dead
	_spectate_box.visible = spectating
	_dead_tint.visible = dead_view
	_death_column.visible = dead_view
	if spectating:
		_update_spectate_name()
	if dead_view:
		_update_death()


## The spectated teammate's name in their team's colour on the plate.
func _update_spectate_name() -> void:
	_spectate_name.text = shown.name
	_spectate_name.add_theme_color_override("font_color", _team_color(shown.team))


## The death plate and the countdown: "Killed by", the killer's name in their team's colour and
## weapon icon, then (when you will come back) the respawn text; under it the killer's health.
func _update_death() -> void:
	var has_killer := is_instance_valid(_killer)
	_killed_label.text = "Killed by" if has_killer else "You died"
	_killer_label.visible = has_killer
	if has_killer:
		_killer_label.text = _killer.name
		_killer_label.add_theme_color_override("font_color", _team_color(_killer.team))
	var weapon_id := &""
	if _killer_weapon != null:
		weapon_id = _killer_weapon.id
	elif has_killer and _killer.weapon != null:
		weapon_id = _killer.weapon.data.id
	_set_icon(_killer_icon, weapon_id if has_killer else &"", ICON_NORMAL)
	var left := _respawn_time_left()
	_countdown_label.visible = left > 0.0
	if left > 0.0:
		_countdown_label.text = "%d" % ceili(left)
	var respawn_text := ""
	if left > 0.0:
		respawn_text = RESPAWN_TEXT % ceili(left)
	elif respawn_hint:
		respawn_text = PRACTICE_RESPAWN_TEXT
	_respawn_label.text = respawn_text
	_respawn_label.visible = not respawn_text.is_empty()
	_death_dot.visible = _respawn_label.visible
	_killer_hp.visible = has_killer and _killer.is_alive()
	if _killer_hp.visible:
		_killer_hp.text = "%s · %d HP left" % [_killer.name, ceili(_killer.health)]


## Seconds until the player comes back in a live team respawn match, or -1 when they aren't waiting to.
func _respawn_time_left() -> float:
	var respawn_match := _manager as RespawnMatch
	if respawn_match == null or _manager.phase != RoundManager.Phase.LIVE:
		return -1.0
	if player == null or not is_instance_valid(player) or player.is_alive():
		return -1.0
	return respawn_match.get_respawn_time_left(player)


# --- Helpers ---


## Builds the row of health chips (their size and number come from the theme).
func _build_chips() -> void:
	for i in _theme_size(&"chip_count"):
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(_theme_size(&"chip_width"), _theme_size(&"chip_height"))
		chip.theme_type_variation = CHIP_FULL
		_health_chips.add_child(chip)
		_chips.append(chip)


## Puts the icon of [param slot] in [param rect], [param icon_scale] times its size and the HUD's scale, and
## shows it when [param show] and the slot has an icon (an empty slot, or "", hides the rect: the text is enough).
func _set_icon(rect: TextureRect, slot: StringName, icon_scale: int, show: bool = true) -> void:
	var icon := UiIcons.get_icon(rect, slot) if slot != &"" else null
	rect.texture = icon
	rect.visible = show and icon != null
	if icon != null:
		rect.custom_minimum_size = (icon.get_size() * icon_scale * _ui_scale).round()


## Colours a number in the alert colour when [param low], in its role's usual one otherwise.
func _tint_label(label: Label, low: bool) -> void:
	if low:
		label.add_theme_color_override("font_color", _palette(&"alert"))
	else:
		label.remove_theme_color_override("font_color")


func _theme_size(constant_name: StringName) -> int:
	return _bottom_left.get_theme_constant(constant_name, THEME_TYPE)


func _palette(color_name: StringName) -> Color:
	return _bottom_left.get_theme_color(color_name, PALETTE_TYPE)


## The palette's UI colour of [param team]: friendly for the viewer's team, enemy for the other.
func _team_color(team: int) -> Color:
	return _palette(&"friendly_text" if team == Teams.viewer_team else &"enemy_text")


## Your ears ring after a flashbang, as long as it blinds you.
func _on_player_flashed(full: float, fade: float) -> void:
	if Weapon.silent or DisplayServer.get_name() == "headless":
		return
	if _ring_audio == null:
		_ring_audio = AudioStreamPlayer.new()
		_ring_audio.stream = FLASH_RING
		_ring_audio.bus = &"Effects"
		add_child(_ring_audio)
	_ring_audio.volume_db = linear_to_db(clampf((full + fade) / Grenade.FLASH_MAX, 0.2, 1.0))
	_ring_audio.play()


func _on_player_died(killer: Character) -> void:
	_player_dead = true
	_killer = killer
	_killer_weapon = player.last_damage_source
	_crosshair.visible = false
	_update_view()


func _on_player_respawned() -> void:
	_player_dead = false
	_killer = null
	_killer_weapon = null
	_crosshair.visible = true
	_update_health()
	_update_view()
