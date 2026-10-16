class_name SoundMix
extends RefCounted
## The mix (M13, D-190, D-194): one table of how loud every kind of game sound plays, how
## far it carries and how much walls muffle it. Players don't keep their own numbers in
## their scenes any more: [method Acoustics.play] sets a player up from its category every
## time it plays, so the whole game's balance is here and `sound_test` can check it.
##
## A category's [code]file_db[/code] is how loud its sound files are (their short-term
## loudness, D-194: the generator levels them, `sound_test` measures them). Its
## [code]volume_db[/code], [code]unit_size[/code] and [code]max_distance[/code] are the 3D
## player's (Godot's inverse-distance falloff: full volume within [code]unit_size[/code] metres,
## -6 dB for every doubling beyond, faded out linearly to silence at [code]max_distance[/code];
## no boost up close, so a sound never plays louder than its file). [code]own_db[/code] is the
## volume when the sound is your own (your gun, your steps), played without position; a category
## without it is never yours. No volume is above 0 dB, so nothing alone can clip (D-194).
## [code]occlusion[/code] (0 to 1) is how much of the muffling walls cause it gets (D-192): all of
## it for steps, reloads and impacts, three quarters for shots and explosions (a fight across the
## map stays audible, as in CS), half for the bomb's beep.

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
	SHOT: {"file_db": -9.0, "volume_db": -3.0, "own_db": -6.0, "unit_size": 10.0, "max_distance": 120.0, "occlusion": 0.75},
	SHOT_FAR: {"file_db": -12.0, "volume_db": -6.0, "unit_size": 20.0, "max_distance": 180.0, "occlusion": 0.75},
	MELEE: {"file_db": -12.0, "volume_db": -4.0, "own_db": -8.0, "unit_size": 4.0, "max_distance": 25.0, "occlusion": 1.0},
	HANDLING: {"file_db": -14.0, "volume_db": -3.0, "own_db": -8.0, "unit_size": 4.0, "max_distance": 15.0, "occlusion": 1.0},
	FOOTSTEP: {"file_db": -15.0, "volume_db": -2.0, "own_db": -12.0, "unit_size": 8.0, "max_distance": 30.0, "occlusion": 1.0},
	IMPACT: {"file_db": -14.0, "volume_db": -4.0, "unit_size": 4.0, "max_distance": 35.0, "occlusion": 1.0},
	HIT: {"file_db": -13.0, "volume_db": -6.0, "unit_size": 4.0, "max_distance": 35.0, "occlusion": 1.0},
	HEADSHOT: {"file_db": -13.0, "volume_db": 0.0, "unit_size": 8.0, "max_distance": 35.0, "occlusion": 1.0},
	BOUNCE: {"file_db": -15.0, "volume_db": -2.0, "unit_size": 6.0, "max_distance": 40.0, "occlusion": 1.0},
	EXPLOSION: {"file_db": -8.0, "volume_db": 0.0, "unit_size": 20.0, "max_distance": 120.0, "occlusion": 0.75},
	EXPLOSION_FAR: {"file_db": -11.0, "volume_db": -6.0, "unit_size": 30.0, "max_distance": 220.0, "occlusion": 0.75},
	FLASH: {"file_db": -10.0, "volume_db": 0.0, "unit_size": 15.0, "max_distance": 100.0, "occlusion": 0.75},
	SMOKE: {"file_db": -14.0, "volume_db": -6.0, "unit_size": 4.0, "max_distance": 25.0, "occlusion": 1.0},
	BOMB_BEEP: {"file_db": -6.0, "volume_db": -7.0, "unit_size": 10.0, "max_distance": 60.0, "occlusion": 0.5},
	BOMB_ACTION: {"file_db": -14.0, "volume_db": -2.0, "unit_size": 3.0, "max_distance": 25.0, "occlusion": 1.0},
	BOMB_EXPLOSION: {"file_db": -8.0, "volume_db": 0.0, "unit_size": 30.0, "max_distance": 200.0, "occlusion": 0.75},
}

## The bus every game sound plays on, and the three it is moved to when something is in the
## way (D-192): around a corner, through a wall, through more or thicker walls. They low-pass it
## (3.5 kHz, 1.5 kHz, 600 Hz) and send it on to Effects, so the reverb still applies.
const BUS_EFFECTS := &"Effects"
const BUS_MUFFLED_LIGHT := &"MuffledLight"
const BUS_MUFFLED := &"Muffled"
const BUS_MUFFLED_HEAVY := &"MuffledHeavy"

## How walls muffle a sound (D-192): this many dB quieter for every wall crossed and for every
## metre of wall, at most [constant MAX_WALL_LOSS_DB]; from [constant HEAVY_FROM_DB] it is
## also low-passed hard. A sound that gets around a corner is only [constant AROUND_DB] quieter.
const WALL_DB := 4.0
const WALL_METRE_DB := 1.5
const MAX_WALL_LOSS_DB := 18.0
const HEAVY_FROM_DB := 10.0
const AROUND_DB := 3.0
## Interface sounds (menus, the bomb-planted alert) and the music with its stingers (D-195).
const BUS_INTERFACE := &"Interface"
const BUS_MUSIC := &"Music"

## Where a sound with a distant variant (a gun, an explosion) starts turning into it, and
## where it is all distant, in metres (D-191). The close one is [constant CLOSE_AT_FAR_DB]
## quieter (on top of its own falloff) once the far one is in fully.
const FAR_FROM := 15.0
const FAR_TO := 40.0
const CLOSE_AT_FAR_DB := -9.0

## The listener's zones (D-193) and the Effects bus's reverb in each: an open yard (almost dry,
## a faint late slap), a yard between walls (a short slap echo), a small room (short and close)
## and a hall (bigger and longer). Kept light: you must still hear every step (D-038). The keys
## are [AudioEffectReverb]'s properties; dry stays 1.
enum Zone { OPEN, YARD, ROOM, HALL }
const REVERB := {
	Zone.OPEN: {"room_size": 0.15, "damping": 0.8, "wet": 0.03, "predelay_msec": 70.0, "predelay_feedback": 0.1, "hipass": 0.35},
	Zone.YARD: {"room_size": 0.35, "damping": 0.6, "wet": 0.09, "predelay_msec": 45.0, "predelay_feedback": 0.3, "hipass": 0.3},
	Zone.ROOM: {"room_size": 0.3, "damping": 0.5, "wet": 0.15, "predelay_msec": 12.0, "predelay_feedback": 0.0, "hipass": 0.2},
	Zone.HALL: {"room_size": 0.7, "damping": 0.35, "wet": 0.2, "predelay_msec": 25.0, "predelay_feedback": 0.1, "hipass": 0.2},
}

## Menu sounds' loudness (clicks, the buy menu's blips) and the stingers' and music's (D-194, D-195).
const INTERFACE_FILE_DB := -12.0
const STINGER_FILE_DB := -12.0
const MUSIC_FILE_DB := -18.0
## Godot's distance filter on 3D sounds (a high shelf above 5 kHz that deepens as a sound fades
## with distance): half its default, as the far shots already sound distant (D-194).
const DISTANCE_FILTER_DB := -12.0
## A centred 3D sound plays this much below the same sound without position (equal-power
## panning, measured with the real audio driver, D-190).
const CENTRE_DB := -3.0

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
	player.max_db = 0.0
	player.attenuation_filter_db = DISTANCE_FILTER_DB
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


## How loud a sound of [param category] is in each ear at [param distance] metres in front of you,
## in dB (short-term, like [code]file_db[/code]), when its file is [param file_db] loud
## ([code]NAN[/code]: the category's own). Godot's falloff as [method apply_3d] sets it up, with
## the centre's [constant CENTRE_DB]; [code]-INF[/code] out of range. No walls and no far crossfade.
static func level_at(category: StringName, distance: float, file_db: float = NAN) -> float:
	var values := get_values(category)
	var fade: float = 1.0 - distance / values.max_distance
	if fade <= 0.0:
		return -INF
	var falloff := minf(0.0, linear_to_db(values.unit_size / maxf(distance, 0.001)))
	return (values.file_db if is_nan(file_db) else file_db) + values.volume_db + falloff + linear_to_db(fade) + CENTRE_DB


## The same for your own sound of [param category] (no position, both ears).
static func own_level(category: StringName, file_db: float = NAN) -> float:
	var values := get_values(category)
	return (values.file_db if is_nan(file_db) else file_db) + values.own_db


## How loud another player's shot is at [param distance] metres, close and far crossfaded as
## [method Acoustics.play_with_far] does (the files at their categories' loudness), [param offset_db]
## its gun's own loudness.
static func shot_level_at(distance: float, offset_db: float = 0.0) -> float:
	var share := far_share(distance)
	var close := level_at(SHOT, distance) + CLOSE_AT_FAR_DB * share
	var far := level_at(SHOT_FAR, distance) + linear_to_db(share) if share > 0.0 else -INF
	# Two different sounds add up by their power, not their amplitude.
	return offset_db + linear_to_db(sqrt(pow(db_to_linear(close), 2.0) + pow(db_to_linear(far), 2.0)))
