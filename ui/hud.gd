extends CanvasLayer
## The in-game HUD: crosshair, health, ammo counter and weapon name.
## Listens to the player's weapon through its signals.

## Magazine counts at or below this fraction of a full magazine are shown in red.
const LOW_AMMO_FRACTION := 0.25
const LOW_AMMO_COLOR := Color(1.0, 0.4, 0.3)
## Health at or below this is shown in red.
const LOW_HEALTH := 25.0

## The player whose weapon the HUD shows. Set with [method set_player].
var player: Character

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _health_label: Label = $HealthLabel
@onready var _death_label: Label = $DeathLabel


## Shows this player's weapon on the HUD.
func set_player(new_player: Character) -> void:
	player = new_player
	var weapon := player.weapon
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_update_weapon_label)
	weapon.reload_finished.connect(_update_weapon_label)
	player.damaged.connect(func(_amount: float, _zone: Hitbox.Zone, _attacker: Character) -> void: _update_health())
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	_crosshair.camera = player.get_camera()
	_update_health()
	_on_ammo_changed(weapon.magazine, weapon.reserve)
	_update_weapon_label()


## Scales the HUD layout; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiScale.apply(_ammo_label, factor)
	UiScale.apply(_weapon_label, factor)
	UiScale.apply(_health_label, factor)
	UiScale.apply(_death_label, factor)
	_crosshair.set_ui_scale(factor)


func _process(_delta: float) -> void:
	if player != null and _crosshair.dynamic:
		_crosshair.spread_degrees = player.weapon.get_inaccuracy()
		_crosshair.queue_redraw()


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [magazine, reserve]
	var low := magazine <= player.weapon.data.magazine_size * LOW_AMMO_FRACTION
	_ammo_label.modulate = LOW_AMMO_COLOR if low else Color.WHITE


func _update_weapon_label() -> void:
	var weapon := player.weapon
	_weapon_label.text = weapon.data.display_name + ("  ·  reloading" if weapon.is_reloading() else "")


## Shows the player's health, rounded up so 0.4 HP still shows as 1 while alive.
func _update_health() -> void:
	_health_label.text = "+ %d" % ceili(player.health)
	_health_label.modulate = LOW_AMMO_COLOR if player.health <= LOW_HEALTH else Color.WHITE


func _on_player_died(killer: Character) -> void:
	_death_label.text = ("Killed by %s" % killer.name if killer != null else "You died") + "\nRespawning..."
	_death_label.visible = true
	_crosshair.visible = false


func _on_player_respawned() -> void:
	_death_label.visible = false
	_crosshair.visible = true
	_update_health()
