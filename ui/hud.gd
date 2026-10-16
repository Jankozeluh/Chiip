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

## The player whose weapon the HUD shows. Set with [method set_player].
var player: Character
## The character whose health, ammo and weapon the HUD shows right now: the
## player, or the teammate being spectated.
var shown: Character
## Say "Respawning..." under the death message (practice mode brings you back;
## in a match the dead wait for the next round).
var respawn_hint: bool = true

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _health_label: Label = $HealthLabel
@onready var _armor_icon: ArmorIcon = $ArmorIcon
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
		shown.weapon.ammo_changed.disconnect(_on_ammo_changed)
		shown.weapon.reload_started.disconnect(_update_weapon_label)
		shown.weapon.reload_finished.disconnect(_update_weapon_label)
		shown.damaged.disconnect(_on_shown_damaged)
		shown.gear_changed.disconnect(_update_armor)
	shown = target
	_bomb_hud.set_view_target(target)
	shown.weapon.ammo_changed.connect(_on_ammo_changed)
	shown.weapon.reload_started.connect(_update_weapon_label)
	shown.weapon.reload_finished.connect(_update_weapon_label)
	shown.damaged.connect(_on_shown_damaged)
	shown.gear_changed.connect(_update_armor)
	var spectating := shown != player
	_spectate_label.visible = spectating
	if spectating:
		# Their view replaces the "Killed by …" message.
		_death_label.visible = false
	_update_health()
	_update_armor()
	_on_ammo_changed(shown.weapon.magazine, shown.weapon.reserve)
	_update_weapon_label()


## Scales the HUD layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiScale.apply(_ammo_label, factor)
	UiScale.apply(_weapon_label, factor)
	UiScale.apply(_health_label, factor)
	UiScale.apply(_armor_icon, factor)
	UiScale.apply(_armor_label, factor)
	UiScale.apply(_death_label, factor)
	UiScale.apply(_spectate_label, factor)
	_crosshair.set_ui_scale(factor)
	_round_hud.set_ui_scale(factor)
	_bomb_hud.set_ui_scale(factor)


func _process(_delta: float) -> void:
	if player != null and _crosshair.dynamic:
		_crosshair.spread_degrees = player.weapon.get_inaccuracy()
		_crosshair.queue_redraw()


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [magazine, reserve]
	var low := magazine <= shown.weapon.data.magazine_size * LOW_AMMO_FRACTION
	_ammo_label.modulate = LOW_AMMO_COLOR if low else Color.WHITE


func _update_weapon_label() -> void:
	var weapon := shown.weapon
	_weapon_label.text = weapon.data.display_name + ("  ·  reloading" if weapon.is_reloading() else "")


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
	_crosshair.visible = false


func _on_player_respawned() -> void:
	_death_label.visible = false
	_crosshair.visible = true
	_update_health()
