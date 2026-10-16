extends CanvasLayer
## The in-game HUD: crosshair, health, armor, ammo counter and weapon name.
## Listens to the player's weapon through its signals. While you spectate a
## teammate (see [PlayerController]), health, ammo and weapon are theirs and a
## "Spectating" line shows whose view you are in. In a match the [RoundHud]
## child adds the top bar, countdown, round-end banners and kill feed, and in
## bomb rounds the [BombHud] child the bomb tag, prompts and messages.

## Magazine counts at or below this fraction of a full magazine are shown in red.
const LOW_AMMO_FRACTION := 0.25
const LOW_AMMO_COLOR := Color(1.0, 0.4, 0.3)
## Health at or below this is shown in red.
const LOW_HEALTH := 25.0
## Seconds the weapon list shows after a change, and how long it then takes to fade.
const SLOTS_SHOW_TIME := 2.5
const SLOTS_FADE_TIME := 0.5

## The player whose weapon the HUD shows. Set with [method set_player].
var player: Character
## The character whose health, ammo and weapon the HUD shows right now: the
## player, or the teammate being spectated.
var shown: Character
## Say "Respawning..." under the death message (practice mode brings you back;
## in a match the dead wait for the next round).
var respawn_hint: bool = true

## The weapon whose ammo the labels follow.
var _watched_weapon: Weapon
## Seconds the weapon list keeps showing.
var _slots_show_left: float = 0.0
## The player is dead: no crosshair until the respawn.
var _player_dead: bool = false

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _health_label: Label = $HealthLabel
@onready var _armor_icon: ArmorIcon = $ArmorIcon
@onready var _slots_label: Label = $SlotsLabel
@onready var _scope_overlay: ScopeOverlay = $ScopeOverlay
@onready var _armor_label: Label = $ArmorLabel
@onready var _death_label: Label = $DeathLabel
@onready var _spectate_label: Label = $SpectateLabel
@onready var _round_hud: RoundHud = $RoundHud
@onready var _bomb_hud: BombHud = $BombHud


## Shows this player's weapon on the HUD.
func set_player(new_player: Character) -> void:
	player = new_player
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	_crosshair.camera = player.get_camera()
	set_view_target(player)


## Shows the round HUD (top bar, countdown, banners, kill feed) for the match
## run by [param manager], or hides it when null (practice mode). Called on
## every map load; the previous manager is dropped.
func set_round_manager(manager: RoundManager) -> void:
	_round_hud.set_round_manager(manager)
	_bomb_hud.set_round_manager(manager)


## Shows the health, ammo and weapon of [param target] instead of the player's
## own, and the "Spectating" line when it is somebody else. The player's
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
	var spectating := shown != player
	_spectate_label.visible = spectating
	if spectating:
		# Their view replaces the "Killed by …" message.
		_death_label.visible = false
	_update_health()
	_update_armor()
	_update_slots()
	_show_weapon()


## Scales the HUD layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiScale.apply(_ammo_label, factor)
	UiScale.apply(_weapon_label, factor)
	UiScale.apply(_health_label, factor)
	UiScale.apply(_armor_icon, factor)
	UiScale.apply(_armor_label, factor)
	UiScale.apply(_slots_label, factor)
	UiScale.apply(_death_label, factor)
	UiScale.apply(_spectate_label, factor)
	_crosshair.set_ui_scale(factor)
	_scope_overlay.set_ui_scale(factor)
	_round_hud.set_ui_scale(factor)
	_bomb_hud.set_ui_scale(factor)


func _process(delta: float) -> void:
	if _slots_show_left > 0.0:
		_slots_show_left -= delta
		_slots_label.modulate.a = clampf(_slots_show_left / SLOTS_FADE_TIME, 0.0, 1.0)
	# A scope shows its own view; a sniper rifle has no crosshair unscoped either, as in CS.
	var weapon := shown.weapon if shown != null and is_instance_valid(shown) else null
	_scope_overlay.visible = weapon != null and weapon.is_scoped()
	_crosshair.visible = not _player_dead and not (weapon != null and weapon.data.has_scope())
	if player != null and player.weapon != null and _crosshair.dynamic:
		_crosshair.spread_degrees = player.weapon.get_inaccuracy()
		_crosshair.queue_redraw()


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


## Shows the ammo and name of the weapon in the shown character's hand.
func _show_weapon() -> void:
	var weapon := shown.weapon
	if weapon == null:
		_ammo_label.text = ""
		_weapon_label.text = ""
		return
	_on_ammo_changed(weapon.magazine, weapon.reserve)
	_update_weapon_label()


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	var weapon := shown.weapon
	if weapon == null or weapon.data.is_melee():
		_ammo_label.text = ""
		return
	if weapon.data.is_grenade():
		_ammo_label.text = "× %d" % magazine
		_ammo_label.modulate = Color.WHITE
		return
	_ammo_label.text = "%d / %d" % [magazine, reserve]
	var low := magazine <= weapon.data.magazine_size * LOW_AMMO_FRACTION
	_ammo_label.modulate = LOW_AMMO_COLOR if low else Color.WHITE


func _update_weapon_label() -> void:
	var weapon := shown.weapon
	if weapon == null:
		_weapon_label.text = ""
		return
	_weapon_label.text = weapon.data.display_name + ("  ·  reloading" if weapon.is_reloading() else "")


## Lists what the shown character carries, one line per slot, the held one bright (D-094). It
## shows for a few seconds after a change, as CS's weapon list does.
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
## as 1 while alive, and tells whether the teammate you watch is still alive.
func _update_health() -> void:
	_health_label.text = "+ %d" % ceili(shown.health)
	_health_label.modulate = LOW_AMMO_COLOR if shown.health <= LOW_HEALTH else Color.WHITE
	if shown != player:
		_spectate_label.text = "Spectating %s  ·  %s" % [shown.name, "click for next" if shown.is_alive() else "dead"]


## Shows the armor of the character on show: its points (rounded up, like health) and the
## shield, with the helmet's mark when it has one (D-093).
func _update_armor() -> void:
	_armor_label.text = "%d" % ceili(shown.armor)
	_armor_label.modulate = Color(1, 1, 1, 1.0 if shown.armor > 0.0 else ArmorIcon.EMPTY_ALPHA)
	_armor_icon.points = shown.armor
	_armor_icon.helmet = shown.has_helmet


func _on_player_died(killer: Character) -> void:
	_death_label.text = ("Killed by %s" % killer.name if killer != null else "You died") + ("\nRespawning..." if respawn_hint else "")
	_death_label.visible = true
	_player_dead = true
	_crosshair.visible = false


func _on_player_respawned() -> void:
	_death_label.visible = false
	_player_dead = false
	_crosshair.visible = true
	_update_health()
