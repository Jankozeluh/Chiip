class_name SoundMix
extends RefCounted
## The mix (M13, D-190, D-194): one table of how loud every kind of game sound plays, how
## far it carries and how much walls muffle it. Players don't keep their own numbers in
## their scenes any more: [method Acoustics.play] sets a player up from its category every
## time it plays, so the whole game's balance is here and `sound_test` can check it.
##
## A category's [code]volume_db[/code], [code]unit_size[/code] and [code]max_distance[/code]
## are the 3D player's (Godot's inverse-distance falloff: full volume within
## [code]unit_size[/code] metres, -6 dB for every doubling beyond, silent at
## [code]max_distance[/code]). [code]own_db[/code] is the volume when the sound is your own
## (your gun, your steps), played without position; a category without it is never yours.
## [code]occlusion[/code] (0 to 1) is how much of the muffling walls cause it gets (D-192).

## Shots of guns.
const SHOT := &"shot"
## A gun's distant shot, crossfaded in by distance (D-191).
const SHOT_FAR := &"shot_far"
## A knife swing.
const MELEE := &"melee"
## Reload steps, empty clicks, pumps and bolts, grenade pins and throws, a knife's hit.
const HANDLING := &"handling"
## Running footsteps (walking and crouching are silent, D-038).
const FOOTSTEP := &"footstep"
## A bullet landing on a surface.
const IMPACT := &"impact"
## A bullet hitting a body.
const HIT := &"hit"
## A bullet hitting a head: louder and carries farther, like CS's headshot sound (D-084).
const HEADSHOT := &"headshot"
## A grenade bouncing off something.
const BOUNCE := &"bounce"
## A frag grenade going off.
const EXPLOSION := &"explosion"
## A frag or the bomb heard from far away (D-191).
const EXPLOSION_FAR := &"explosion_far"
## A flashbang going off.
const FLASH := &"flash"
## A smoke grenade's hiss.
const SMOKE := &"smoke"
## The planted bomb's beep: heard from far, and walls only half muffle it.
const BOMB_BEEP := &"bomb_beep"
## Planting and defusing: key presses and wire clicks.
const BOMB_ACTION := &"bomb_action"
## The bomb going off.
const BOMB_EXPLOSION := &"bomb_explosion"

const TABLE := {
	SHOT: {"volume_db": 0.0, "own_db": -6.0, "unit_size": 20.0, "max_distance": 120.0, "occlusion": 1.0},
	SHOT_FAR: {"volume_db": 0.0, "unit_size": 40.0, "max_distance": 180.0, "occlusion": 1.0},
	MELEE: {"volume_db": -4.0, "own_db": -6.0, "unit_size": 4.0, "max_distance": 25.0, "occlusion": 1.0},
	HANDLING: {"volume_db": -6.0, "own_db": -6.0, "unit_size": 3.0, "max_distance": 15.0, "occlusion": 1.0},
	FOOTSTEP: {"volume_db": 2.0, "own_db": -12.0, "unit_size": 10.0, "max_distance": 30.0, "occlusion": 1.0},
	IMPACT: {"volume_db": -4.0, "unit_size": 4.0, "max_distance": 35.0, "occlusion": 1.0},
	HIT: {"volume_db": -4.0, "unit_size": 4.0, "max_distance": 35.0, "occlusion": 1.0},
	HEADSHOT: {"volume_db": 2.0, "unit_size": 8.0, "max_distance": 35.0, "occlusion": 1.0},
	BOUNCE: {"volume_db": -6.0, "unit_size": 6.0, "max_distance": 40.0, "occlusion": 1.0},
	EXPLOSION: {"volume_db": 0.0, "unit_size": 20.0, "max_distance": 120.0, "occlusion": 1.0},
	EXPLOSION_FAR: {"volume_db": 0.0, "unit_size": 50.0, "max_distance": 220.0, "occlusion": 1.0},
	FLASH: {"volume_db": 0.0, "unit_size": 15.0, "max_distance": 100.0, "occlusion": 1.0},
	SMOKE: {"volume_db": -12.0, "unit_size": 4.0, "max_distance": 25.0, "occlusion": 1.0},
	BOMB_BEEP: {"volume_db": 0.0, "unit_size": 6.0, "max_distance": 60.0, "occlusion": 0.5},
	BOMB_ACTION: {"volume_db": -4.0, "unit_size": 3.0, "max_distance": 25.0, "occlusion": 1.0},
	BOMB_EXPLOSION: {"volume_db": 4.0, "unit_size": 30.0, "max_distance": 200.0, "occlusion": 1.0},
}

## The bus every game sound plays on, and the two it is moved to behind walls (D-192): they
## low-pass it and send it on to Effects, so the reverb still applies.
const BUS_EFFECTS := &"Effects"
const BUS_MUFFLED := &"Muffled"
const BUS_MUFFLED_HEAVY := &"MuffledHeavy"
## Interface sounds (menus, the bomb-planted alert) and the music with its stingers (D-195).
const BUS_INTERFACE := &"Interface"
const BUS_MUSIC := &"Music"

## Where a sound with a distant variant (a gun, an explosion) starts turning into it, and
## where it is all distant, in metres (D-191). The close one is [constant CLOSE_AT_FAR_DB]
## quieter (on top of its own falloff) once the far one is in fully.
const FAR_FROM := 15.0
const FAR_TO := 40.0
const CLOSE_AT_FAR_DB := -9.0

## How strongly 3D sounds pan between the ears: this times the project's
## [code]audio/general/3d_panning_strength[/code] (0.5), so 0.8. Godot's 0.5 leaves a sound
## at your side only 6 dB louder in the near ear; 0.8 makes it 14 dB, so you hear which side
## a step came from, as in CS; 1.0 would put it in one ear only (measured, D-190).
const PANNING_STRENGTH := 1.6


## The values of [param category] (empty if there is no such category).
static func get_values(category: StringName) -> Dictionary:
	return TABLE.get(category, {})


## Sets [param player] up as a 3D sound of [param category], [param offset_db] louder.
static func apply_3d(player: AudioStreamPlayer3D, category: StringName, offset_db: float = 0.0) -> void:
	var values := get_values(category)
	if values.is_empty():
		push_error("SoundMix: no category %s" % category)
		return
	player.volume_db = values.volume_db + offset_db
	player.unit_size = values.unit_size
	player.max_distance = values.max_distance
	player.panning_strength = PANNING_STRENGTH
	player.bus = BUS_EFFECTS


## Sets [param player] up as your own sound of [param category] (no position), [param offset_db] louder.
static func apply_2d(player: AudioStreamPlayer, category: StringName, offset_db: float = 0.0) -> void:
	var values := get_values(category)
	if not values.has("own_db"):
		push_error("SoundMix: %s is never your own sound" % category)
		return
	player.volume_db = values.own_db + offset_db
	player.bus = BUS_EFFECTS


## How much of a sound with a distant variant is the distant one at [param distance] metres:
## 0 up to [constant FAR_FROM], 1 from [constant FAR_TO], smooth in between.
static func far_share(distance: float) -> float:
	return smoothstep(FAR_FROM, FAR_TO, distance)
