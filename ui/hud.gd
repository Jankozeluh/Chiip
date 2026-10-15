extends CanvasLayer
## The in-game HUD: crosshair, ammo counter and weapon name.
## Listens to the player's weapon through its signals.

## Magazine counts at or below this fraction of a full magazine are shown in red.
const LOW_AMMO_FRACTION := 0.25
const LOW_AMMO_COLOR := Color(1.0, 0.4, 0.3)

## The player whose weapon the HUD shows.
@export var player: Player

@onready var _crosshair: Crosshair = $Crosshair
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel


func _ready() -> void:
	var weapon := player.weapon
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_update_weapon_label)
	weapon.reload_finished.connect(_update_weapon_label)
	_on_ammo_changed(weapon.magazine, weapon.reserve)
	_update_weapon_label()


func _process(_delta: float) -> void:
	if _crosshair.dynamic:
		_crosshair.spread_degrees = player.weapon.get_inaccuracy()
		_crosshair.queue_redraw()


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [magazine, reserve]
	var low := magazine <= player.weapon.data.magazine_size * LOW_AMMO_FRACTION
	_ammo_label.modulate = LOW_AMMO_COLOR if low else Color.WHITE


func _update_weapon_label() -> void:
	var weapon := player.weapon
	_weapon_label.text = weapon.data.display_name + ("  ·  reloading" if weapon.is_reloading() else "")
