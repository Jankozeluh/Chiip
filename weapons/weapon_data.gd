class_name WeaponData
extends Resource
## All the numbers that define one weapon, saved as a data file (e.g.
## weapons/rifle.tres) so weapons can be compared and tuned in the Inspector
## without touching code. Godot's version of a Unity ScriptableObject.
##
## Angles are in degrees. Distances are in metres unless the name says units
## (CS units: 1 unit ≈ 2.54 cm).

@export_group("General")
## Name shown in the HUD.
@export var display_name: String = "Weapon"
## Top running speed while this weapon is held, in CS units per second.
## CS: knife 250, rifles 215–225, snipers 200.
@export var max_speed_units: float = 250.0

@export_group("Damage")
## Damage of a body hit at point-blank range, before hit-zone multipliers.
@export var damage: float = 30.0
## Damage is multiplied by this for every 500 units (12.7 m) the bullet travels.
@export var range_modifier: float = 0.98
## How far bullets reach, in metres. CS: 8192 units ≈ 208 m.
@export var max_range: float = 208.0

@export_group("Ammo")
## Rounds in a full magazine.
@export var magazine_size: int = 30
## Spare rounds carried outside the magazine.
@export var reserve_ammo: int = 90
## Shots per minute while firing continuously.
@export var fire_rate_rpm: float = 600.0
## Seconds a reload takes.
@export var reload_time: float = 2.5
## Keeps firing while the button is held. When off, each shot needs a click.
@export var automatic: bool = true

@export_group("Accuracy")
## Radius of the cone shots land in when standing still, in degrees.
@export var standing_inaccuracy: float = 0.12
## Cone radius when crouched and still.
@export var crouching_inaccuracy: float = 0.08
## Extra cone radius at full running speed. It starts above 34% of top speed
## (slower than that counts as standing still) and grows to this value.
@export var moving_inaccuracy: float = 4.5
## Extra cone radius while in the air.
@export var air_inaccuracy: float = 9.0
## Extra cone radius added by each shot of a spray.
@export var spray_inaccuracy_per_shot: float = 0.1
## The most extra cone radius spraying can add.
@export var max_spray_inaccuracy: float = 1.5

@export_group("Recoil")
## Where each shot of a spray goes relative to your aim, in degrees
## (x = right, y = up). Entry 1 is the first shot. Longer sprays repeat the last entry.
@export var spray_pattern: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
## How much of the recoil moves your view (CS's aim punch). Bullets go the
## full pattern distance, so they land above the crosshair while spraying.
@export_range(0.0, 1.0) var view_punch_fraction: float = 0.5
## How many shots of recoil wear off per second once you stop firing.
@export var recoil_recovery_rate: float = 12.0

@export_group("Sounds")
## Played for every shot.
@export var shot_sound: AudioStream
## Played when you pull the trigger on an empty magazine.
@export var dry_fire_sound: AudioStream
## Played at each step of a reload (magazine out, magazine in, bolt).
@export var reload_sound: AudioStream


## Seconds between two shots.
func get_shot_interval() -> float:
	return 60.0 / fire_rate_rpm


## Where shot number [param spray_position] goes (0 = first shot). Accepts
## fractions so recoil can wear off smoothly between two pattern entries.
func get_spray_offset(spray_position: float) -> Vector2:
	if spray_pattern.is_empty():
		return Vector2.ZERO
	var last := spray_pattern.size() - 1
	var index := clampi(floori(spray_position), 0, last)
	var next := mini(index + 1, last)
	return spray_pattern[index].lerp(spray_pattern[next], clampf(spray_position - index, 0.0, 1.0))
