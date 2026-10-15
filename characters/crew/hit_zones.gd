class_name HitZones
extends Resource
## The hit-zone boxes of one crew class (D-055), written by tools/modelgen/modelgen.py as
## [code]assets/models/crew/<class>_hit_zones.tres[/code]. Don't edit those files by hand.
##
## Each box belongs to one bone of the class's skeleton and covers the pieces of the part
## list that sit on that bone, so a taller or broader class gets bigger boxes. Entry
## [code]i[/code] of every array describes box [code]i[/code]: [CrewBody] puts a [Hitbox]
## of zone [code]zones[i][/code] with a box of [code]sizes[i][/code] at [code]centers[i][/code]
## on bone [code]bones[i][/code], so the hit zones follow the animated body.

## The bone each box follows (a bone name of the class's Skeleton3D).
@export var bones: PackedStringArray = []
## The zone of each box, as a [enum Hitbox.Zone] value.
@export var zones: PackedInt32Array = []
## The centre of each box in its bone's frame, in metres.
@export var centers: PackedVector3Array = []
## The full size of each box, in metres.
@export var sizes: PackedVector3Array = []


## How many boxes there are.
func size() -> int:
	return bones.size()
