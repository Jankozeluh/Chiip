class_name WeaponData
extends Resource
## All the numbers that define one weapon, saved as a data file (e.g.
## weapons/rifle.tres) so weapons can be compared and tuned in the Inspector
## without touching code. Godot's version of a Unity ScriptableObject.
##
## Every weapon of the arsenal (D-056, D-090) has one file in weapons/, listed in [constant PATHS]
## in buy-menu order. Files are named after the weapon's role ([member id]: rifle, carbine...);
## only [member display_name] carries the weapon's name, so a name can change without touching
## anything else. tools/export_weapon_table.gd turns them all into docs/weapons.csv, the
## balancing table.
##
## Angles are in degrees. Distances are in metres unless the name says units
## (CS units: 1 unit ≈ 2.54 cm).

## Which slot of the inventory a weapon goes into (keys 1 to 4).
enum Slot { PRIMARY, PISTOL, KNIFE, GRENADE }
## What kind of weapon it is: decides the buy-menu category, how bots use it, and the kill feed.
enum Category { RIFLE, SMG, SHOTGUN, SNIPER, PISTOL, KNIFE, GRENADE }
## How the hands hold it: decides the body's and the first-person arms' animations.
enum Hold { RIFLE, PISTOL, KNIFE, GRENADE }

## Every weapon's data file, in buy-menu order. Loaded when asked for (see [method all]).
const PATHS: Array[String] = [
	"res://weapons/pistol.tres",
	"res://weapons/hand_cannon.tres",
	"res://weapons/smg.tres",
	"res://weapons/shotgun.tres",
	"res://weapons/rifle.tres",
	"res://weapons/carbine.tres",
	"res://weapons/sniper.tres",
	"res://weapons/knife.tres",
	"res://weapons/frag.tres",
	"res://weapons/flashbang.tres",
	"res://weapons/smoke.tres",
]

@export_group("General")
## A short stable name for code, files and the console: the weapon's role ("rifle", "carbine").
@export var id: StringName = &""
## Name shown in the HUD, the buy menu and the kill feed (provisional names: D-090).
@export var display_name: String = "Weapon"
## The inventory slot it goes into.
@export var slot: Slot = Slot.PRIMARY
## What kind of weapon it is.
@export var category: Category = Category.RIFLE
## How it's held (animations).
@export var hold: Hold = Hold.RIFLE
## Top running speed while this weapon is held, in CS units per second.
## CS: knife 250, pistols 230–240, SMGs 240, rifles 215–225, snipers 200.
@export var max_speed_units: float = 250.0
## Seconds after switching to it before it can fire (CS's deploy time). The Rifleman's
## Quick Hands makes it shorter ([member ClassData.weapon_switch_time_factor]).
@export var draw_time: float = 1.0

@export_group("Economy")
## What it costs in the buy menu, in dollars. 0 = never sold (the knife).
@export var price: int = 0
## Money for a kill with it: $200, $500 with the knife (the light economy, D-090).
@export var kill_reward: int = 300

@export_group("Damage")
## Damage of a body hit at point-blank range, before hit-zone multipliers. For a shotgun, per pellet.
@export var damage: float = 30.0
## Damage is multiplied by this for every 500 units (12.7 m) the bullet travels.
@export var range_modifier: float = 0.98
## How far bullets reach, in metres. CS: 8192 units ≈ 208 m.
@export var max_range: float = 208.0
## The share of the damage that reaches health when the hit lands on armor (CS's armor ratio
## halved: the AK's 1.55 is 0.775). See [Armor].
@export_range(0.0, 1.0) var armor_penetration: float = 0.5
## Bullets per shot: 1, or the shotgun's pellets. Each pellet is its own hitscan ray.
@export var pellets: int = 1
## The shotgun's fixed spread: pellets land at random within this cone radius, on top of the
## weapon's inaccuracy.
@export var pellet_spread: float = 0.0

@export_group("Ammo")
## Rounds in a full magazine.
@export var magazine_size: int = 30
## Spare rounds carried outside the magazine.
@export var reserve_ammo: int = 90
## Shots per minute while firing continuously.
@export var fire_rate_rpm: float = 600.0
## Seconds a reload takes. For a weapon that loads shell by shell, the time per shell.
@export var reload_time: float = 2.5
## Loads one shell at a time ([member reload_time] each, after [member reload_start_time]);
## firing interrupts the reload once a shell is in.
@export var reload_per_shell: bool = false
## Seconds before the first shell goes in (bringing the gun up to load).
@export var reload_start_time: float = 0.0
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

@export_group("Scope")
## Zoom steps of the scope as fractions of the normal field of view (the sniper rifle: 40/90
## and 15/90, CS's AWP). Empty: no scope. The aim button (right mouse) steps through them.
@export var zoom_levels: PackedFloat32Array = PackedFloat32Array()
## Cone radius while scoped and standing still (replaces [member standing_inaccuracy]; crouched
## it's two thirds of this).
@export var scoped_inaccuracy: float = 0.0
## Seconds from pressing the aim button until the scope is fully accurate (the Marksman's
## Steady makes it shorter: [member ClassData.scope_in_time_factor]).
@export var scope_in_time: float = 0.3
## Seconds for the extra cone from moving to wear off once you stop while scoped (the
## Marksman's Steady makes it faster: [member ClassData.scoped_recovery_factor]).
@export var scoped_recovery_time: float = 0.35
## Top speed while scoped, in CS units per second (CS: the AWP's 100).
@export var scoped_max_speed_units: float = 100.0
## Drops out of the scope after each shot and goes back in once the next shot is ready (CS's AWP).
@export var unscope_after_shot: bool = true

@export_group("Melee")
## The knife: how far the slash (fire) reaches from the eyes, in metres. 0 = not a melee weapon.
@export var melee_range: float = 0.0
## The stab (aim button): damage, reach in metres, and seconds before the next attack.
@export var stab_damage: float = 0.0
@export var stab_range: float = 0.0
@export var stab_interval: float = 1.0
## Damage of a slash and of a stab that hit the victim from behind (CS's backstabs).
@export var backstab_damage: float = 0.0
@export var stab_backstab_damage: float = 0.0

@export_group("Grenade")
## The projectile a throw creates (grenades/*.tscn); it knows its own effect.
@export var grenade_scene: PackedScene
## How many of this grenade one player can carry (CS: 2 flashbangs, 1 of the others).
@export var max_carried: int = 1
## Throw speeds in m/s: fire throws hard, the aim button lobs gently.
@export var throw_speed: float = 15.0
@export var lob_speed: float = 7.0

@export_group("Model")
## The generated model (tools/modelgen/weapons.py, weapon space: grip at the origin, barrel
## along −Z). The same model is the first-person gun, the gun in a body's hand and the gun
## lying on the floor (D-090).
@export var model: PackedScene
## Where the model's muzzle is, in weapon space: the muzzle flash goes there.
@export var muzzle_point: Vector3 = Vector3(0.0, 0.022, -0.58)
## The buy-menu icon (a shaded side view) and the kill-feed icon (a white silhouette), rendered
## by the generator.
@export var icon: Texture2D
@export var kill_icon: Texture2D

@export_group("Sounds")
## Played for every shot.
@export var shot_sound: AudioStream
## Played when you pull the trigger on an empty magazine.
@export var dry_fire_sound: AudioStream
## Played at each step of a reload (magazine out, magazine in, bolt).
@export var reload_sound: AudioStream
## Played when a melee attack lands on someone (the knife).
@export var hit_sound: AudioStream
## Played a moment after each shot (the shotgun's pump, the sniper rifle's bolt), at
## [member cycle_sound_delay] seconds.
@export var cycle_sound: AudioStream
@export var cycle_sound_delay: float = 0.3


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


## True for a weapon with a scope (the sniper rifle).
func has_scope() -> bool:
	return not zoom_levels.is_empty()


## True for a melee weapon (the knife).
func is_melee() -> bool:
	return melee_range > 0.0


## True for a grenade.
func is_grenade() -> bool:
	return slot == Slot.GRENADE


## Damage of one bullet (or pellet) at [param distance] metres, before hit zones and armor:
## [member damage] times [member range_modifier] for every 500 units (12.7 m), as in CS.
func damage_at(distance: float) -> float:
	return damage * pow(range_modifier, distance / 0.0254 / 500.0)


## Every weapon of the arsenal, in buy-menu order.
static func all() -> Array[WeaponData]:
	var weapons: Array[WeaponData] = []
	for path in PATHS:
		weapons.append(load(path) as WeaponData)
	return weapons


## The weapon with this [param weapon_id], or null if there is none.
static func find(weapon_id: StringName) -> WeaponData:
	for data in all():
		if data.id == weapon_id:
			return data
	return null
