class_name ClassData
extends Resource
## One crew class (D-052, D-078): its name and look, the model and hit zones that make up its
## body, and the numbers of its passive perk. There is one resource per class in
## characters/crew/classes/ (the same idea as [WeaponData], one data file per weapon): a
## [Character] has a [member Character.class_data], and [CrewBody] builds the body from
## [member model] and [member hit_zones].
##
## The four classes are looked up through [method all] and [method find]. The numbers come from
## docs/GAME_DESIGN.md, section 4.9.
##
## The perk values are only [i]stored[/i] for now: the perks switch on in M7, when armour, scopes
## and weapon switching exist (D-052). Until then the classes differ in their looks and in the
## size of their hit zones, and every perk factor of every class is applied nowhere.

## The class resources, in menu order. They are loaded when asked for (not preloaded: these
## files refer back to this script, and a preload would be a cycle).
const PATHS: Array[String] = [
	"res://characters/crew/classes/rifleman.tres",
	"res://characters/crew/classes/bulwark.tres",
	"res://characters/crew/classes/marksman.tres",
	"res://characters/crew/classes/scout.tres",
]

## A short stable name for code and the console ("rifleman"). Also the model's file name.
@export var id: StringName = &""
## The name shown in menus ("Rifleman").
@export var display_name: String = ""
## What the class is for, in one line ("Stocky and upright: the all-rounder").
@export var role: String = ""
## How tall the body is, in metres (the top of the head zone). The model is made exactly this
## tall by tools/modelgen. Eye height and the collision hull are the same for every class.
@export var height: float = 1.82
## The generated model ([code].glb[/code] in assets/models/crew/): skeleton, mesh and animation
## clips. Its textures are found next to it (see [method CrewBody.material_for]).
@export var model: PackedScene
## The class's hit-zone boxes, made by the generator for the same body (see [HitZones]).
@export var hit_zones: HitZones
## The first-person arms and gloves the class shows in its own view (a generated
## [code]<class>_arms.glb[/code], D-079); [Character] puts them into its weapon's viewmodel.
@export var arms_model: PackedScene
## The gun the class is meant to carry, as text for the class menu ("AK-style rifle"). Classes
## don't restrict weapons (D-052), and in M6 everyone carries the AK-style rifle.
@export var signature_weapon: String = ""
## What the class wears, in a sentence or two (the concept sheets' description).
@export_multiline var look: String = ""
## The name of the passive perk ("Quick Hands").
@export var perk_name: String = ""
## What the perk does, in plain words, as the menu shows it.
@export_multiline var perk_description: String = ""

@export_group("Perk values (stored, applied from M7)")
## Multiplies the reload time. Rifleman: 0.85 (reloads 15% faster).
@export var reload_time_factor: float = 1.0
## Multiplies the time to switch weapons. Rifleman: 0.85.
@export var weapon_switch_time_factor: float = 1.0
## Multiplies the damage taken while wearing armour. Bulwark: 0.9. No effect without armour.
@export var armor_damage_factor: float = 1.0
## Multiplies how fast armour wears down. Bulwark: 0.7.
@export var armor_wear_factor: float = 1.0
## Multiplies the time a scoped shot needs to become accurate again after moving, as a speed:
## above 1.0 recovers faster. Marksman: 1.3 (30% faster).
@export var scoped_recovery_factor: float = 1.0
## Multiplies the time it takes to scope in. Marksman: 0.8 (20% faster).
@export var scope_in_time_factor: float = 1.0
## Multiplies how far the sound of running footsteps carries. Scout: 0.7 (the exception to D-038).
@export var running_footstep_range_factor: float = 1.0


## The four classes in menu order: Rifleman, Bulwark, Marksman, Scout.
static func all() -> Array[ClassData]:
	var classes: Array[ClassData] = []
	for path in PATHS:
		classes.append(load(path) as ClassData)
	return classes


## The class with this [param id], or null if there is none.
static func find(class_id: StringName) -> ClassData:
	for data in all():
		if data.id == class_id:
			return data
	return null
