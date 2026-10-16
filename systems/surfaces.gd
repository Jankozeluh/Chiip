class_name Surfaces
extends RefCounted
## What the world is made of where a foot lands or a bullet hits (D-084), so
## footsteps and impacts sound like gravel, metal, wood or hard stone.
##
## TrenchBroom maps are built with Chiip's worldspawn class
## (maps/fgd/chiip_worldspawn.tres), which stores in the map's body the texture
## and normal of every face and which faces belong to which brush (func_godot's
## "func_godot_mesh_data" metadata). A ray hit reports the brush's collision
## shape; its face that points most like the hit normal names the texture, and
## the texture's name gives the kind (D-121): the exact names of the first
## textures, then words in the file name, so a new texture called
## [code]industrial/blue_metal[/code] sounds like metal without a code change. Kit
## props (D-122) say what they're made of in a [code]surface[/code] metadata entry on
## their body. Anything else (CSG test maps, characters) counts as [constant Kind.HARD].
##
## A plain class with static members, like [Noises] and [Teams], so tools and
## tests can use it without an autoload. Lookups are cached per shape.

## The kinds of surface that sound different.
enum Kind { HARD, GRAVEL, METAL, WOOD }

## Texture name → kind, for names the words below don't cover.
const TEXTURE_KINDS := {
	&"gravel_grey": Kind.GRAVEL,
	&"metal_plates": Kind.METAL,
	&"wood_planks": Kind.WOOD,
}
## Words in a texture's file name → kind (D-121), checked in this order. Every
## other texture (concrete, stone, plaster, brick, tiles) is hard.
const NAME_WORDS := [
	["metal", Kind.METAL], ["steel", Kind.METAL], ["iron", Kind.METAL], ["plate", Kind.METAL],
	["grate", Kind.METAL], ["rust", Kind.METAL], ["corrugated", Kind.METAL], ["perforated", Kind.METAL],
	["chainlink", Kind.METAL],
	["wood", Kind.WOOD], ["plank", Kind.WOOD], ["parquet", Kind.WOOD], ["siding", Kind.WOOD],
	["bark", Kind.WOOD],
	["gravel", Kind.GRAVEL], ["dirt", Kind.GRAVEL], ["grass", Kind.GRAVEL], ["ground", Kind.GRAVEL],
	["mud", Kind.GRAVEL], ["sand", Kind.GRAVEL],
]
## Kit props' [code]surface[/code] metadata (D-122) → kind.
const PROP_SURFACES := {"hard": Kind.HARD, "gravel": Kind.GRAVEL, "metal": Kind.METAL, "wood": Kind.WOOD}
## The metadata entry on a kit prop's body that names its surface.
const PROP_META_KEY := "surface"
## The metadata func_godot stores on a built map body.
const META_KEY := "func_godot_mesh_data"
## How far below the feet a footstep looks for the floor (metres).
const FLOOR_PROBE := 0.4

## Footsteps for each kind; HARD uses the character's own footstep sound.
const FOOTSTEPS := {
	Kind.GRAVEL: preload("res://assets/sounds/footsteps_gravel.tres"),
	Kind.METAL: preload("res://assets/sounds/footsteps_metal.tres"),
	Kind.WOOD: preload("res://assets/sounds/footsteps_wood.tres"),
}
## A bullet hitting each kind.
const IMPACTS := {
	Kind.HARD: preload("res://assets/sounds/impact_hard.wav"),
	Kind.GRAVEL: preload("res://assets/sounds/impact_gravel.wav"),
	Kind.METAL: preload("res://assets/sounds/impact_metal.wav"),
	Kind.WOOD: preload("res://assets/sounds/impact_wood.wav"),
}

## How thick a wall of each kind must be to stop a bullet of penetration power 1.0, in metres (D-214):
## a bullet that goes through [code]t[/code] metres of it keeps [code]1 - t / (reach × power)[/code] of its damage.
## Wood gives way easily, metal sheet less, gravel and earth are dense, concrete, brick and plaster stop most
## bullets (a 10 cm wall halves a rifle's damage, a 20 cm one stops it).
const REACH := {
	Kind.HARD: 0.20,
	Kind.GRAVEL: 0.35,
	Kind.METAL: 0.12,
	Kind.WOOD: 0.50,
}

## "body id:shape index:normal" → Kind.
static var _cache: Dictionary = {}


## The kind of floor under [param feet] (a character's position), or HARD if there is none.
static func floor_kind(world: World3D, feet: Vector3) -> Kind:
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.2, feet + Vector3.DOWN * FLOOR_PROBE, PhysicsLayers.WORLD)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Kind.HARD
	return kind_of(hit["collider"], hit["shape"], hit["normal"])


## The kind of surface a ray hit: [param collider] and [param shape_index] as
## [method PhysicsDirectSpaceState3D.intersect_ray] reports them, and the hit's [param normal].
static func kind_of(collider: Object, shape_index: int, normal: Vector3) -> Kind:
	var body := collider as CollisionObject3D
	if body != null and body.has_meta(PROP_META_KEY):
		return PROP_SURFACES.get(String(body.get_meta(PROP_META_KEY)), Kind.HARD)
	if body == null or not body.has_meta(META_KEY):
		return Kind.HARD
	var key := "%d:%d:%s" % [body.get_instance_id(), shape_index, normal.snapped(Vector3.ONE * 0.5)]
	if not _cache.has(key):
		_cache[key] = _look_up(body, shape_index, normal)
	return _cache[key]


## The footsteps for [param kind]; [param hard] (the character's own sound) for hard floors.
static func footstep_sound(kind: Kind, hard: AudioStream) -> AudioStream:
	return FOOTSTEPS.get(kind, hard)


## The kind of a map texture called [param texture_name] (a path below
## the texture folder, e.g. [code]industrial/rust_plates[/code]).
static func kind_for_texture(texture_name: String) -> Kind:
	if TEXTURE_KINDS.has(StringName(texture_name)):
		return TEXTURE_KINDS[StringName(texture_name)]
	var file := texture_name.get_file().to_lower()
	for entry: Array in NAME_WORDS:
		if file.contains(entry[0]):
			return entry[1]
	return Kind.HARD


## How many metres of [param kind] stop a bullet of penetration power 1.0 ([constant REACH]).
static func reach(kind: Kind) -> float:
	return REACH[kind]


## The sound of a bullet hitting [param kind].
static func impact_sound(kind: Kind) -> AudioStream:
	return IMPACTS[kind]


static func _look_up(body: CollisionObject3D, shape_index: int, normal: Vector3) -> Kind:
	var shape_node := body.shape_owner_get_owner(body.shape_find_owner(shape_index)) as Node
	if shape_node == null:
		return Kind.HARD
	var data: Dictionary = body.get_meta(META_KEY)
	var faces: PackedInt32Array = (data.get("collision_shape_to_face_indices_map", {}) as Dictionary).get(String(shape_node.name), PackedInt32Array())
	var normals: PackedVector3Array = data.get("normals", PackedVector3Array())
	var textures: PackedInt32Array = data.get("textures", PackedInt32Array())
	var names: Array = data.get("texture_names", [])
	# The brush's face that points most like the hit (normals are in the body's space).
	var local_normal := (body.global_basis.inverse() * normal).normalized()
	var best := -1
	var best_dot := -INF
	for face in faces:
		if face < normals.size() and normals[face].dot(local_normal) > best_dot:
			best = face
			best_dot = normals[face].dot(local_normal)
	if best < 0 or best >= textures.size() or textures[best] >= names.size():
		return Kind.HARD
	return kind_for_texture(names[textures[best]])
