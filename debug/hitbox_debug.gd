class_name HitboxDebug
extends Node
## The console's [code]debug_hitboxes[/code] (M16, D-225): draws every character's hit zones as
## half see-through shapes over the world, through walls, in one colour per zone (head red, chest and stomach
## amber, arms and legs green), and sums them up in text ([method describe]). A body without zones
## (v0.1.0's exported builds, D-159) shows nothing and "no hit zones" in the summary.
## Offline only (it shows everyone through walls; D-109). It lives on the map, so a new map starts
## without it; the console adds and removes it ([method toggle]).

## The node's name on the map.
const NODE_NAME := "HitboxDebug"
## The colour of each [enum Hitbox.Zone].
const ZONE_COLORS := {
	Hitbox.Zone.HEAD: Color(1.0, 0.25, 0.25),
	Hitbox.Zone.STOMACH: Color(1.0, 0.7, 0.2),
	Hitbox.Zone.CHEST: Color(1.0, 0.85, 0.3),
	Hitbox.Zone.ARMS: Color(0.4, 1.0, 0.45),
	Hitbox.Zone.LEGS: Color(0.3, 0.85, 1.0),
}
## Seconds between looks for new characters and rebuilt bodies (a class change builds new zones).
const REFRESH_SECONDS := 0.5
## The name of the wireframe added under each zone's shape.
const WIRE_NAME := "HitboxWire"
## How opaque the zones are drawn.
const WIRE_ALPHA := 0.45

## The character whose zones aren't drawn: the player at this computer (they would sit around the camera).
var skip: Character

var _materials: Dictionary = {}
var _refresh_left: float = 0.0


## Turns the drawing on [param map] on or off; returns true when it is now on.
static func toggle(map: Node, local_player: Character) -> bool:
	var existing := map.get_node_or_null(NODE_NAME)
	if existing != null:
		existing.free()
		return false
	var debug := HitboxDebug.new()
	debug.name = NODE_NAME
	debug.skip = local_player
	map.add_child(debug)
	return true


## One line per character: its name and its zones ("Ana: 11 zones (head 1, chest 2, …)"), or
## "no hit zones" for a body without any.
static func describe(characters: Array[Character]) -> PackedStringArray:
	var lines := PackedStringArray()
	for character in characters:
		var counts := {}
		var shapes := 0
		for hitbox in character.body.get_hitboxes():
			var zone_name := hitbox.get_zone_name().to_lower()
			for child in hitbox.get_children():
				if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
					counts[zone_name] = counts.get(zone_name, 0) + 1
					shapes += 1
		if shapes == 0:
			lines.append("%s: no hit zones" % character.name)
			continue
		var parts := PackedStringArray()
		for zone_name: String in counts:
			parts.append("%s %d" % [zone_name, counts[zone_name]])
		lines.append("%s: %d zones (%s)" % [character.name, shapes, ", ".join(parts)])
	return lines


func _ready() -> void:
	for zone: int in ZONE_COLORS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		# Half see-through: the shape's debug mesh has filled faces, and the body should show under them.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(ZONE_COLORS[zone], WIRE_ALPHA)
		material.render_priority = Material.RENDER_PRIORITY_MAX
		_materials[zone] = material
	_refresh()


func _exit_tree() -> void:
	for wire in get_wires():
		wire.queue_free()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh()


## Gives every zone shape of every character in this world a wireframe, and shows only those of
## the living.
func _refresh() -> void:
	_refresh_left = REFRESH_SECONDS
	for character in Character.all_in_world(self):
		if character == skip:
			continue
		for hitbox in character.body.get_hitboxes():
			for child in hitbox.get_children():
				var shape := child as CollisionShape3D
				if shape == null or shape.shape == null:
					continue
				var wire := shape.get_node_or_null(WIRE_NAME) as MeshInstance3D
				if wire == null:
					wire = MeshInstance3D.new()
					wire.name = WIRE_NAME
					wire.mesh = shape.shape.get_debug_mesh()
					wire.material_override = _materials[hitbox.zone]
					wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					shape.add_child(wire)
				wire.visible = character.is_alive()


## Every wireframe this node has added (for tests).
func get_wires() -> Array[MeshInstance3D]:
	var wires: Array[MeshInstance3D] = []
	for character in Character.all_in_world(self):
		for hitbox in character.body.get_hitboxes():
			for child in hitbox.get_children():
				var wire := child.get_node_or_null(WIRE_NAME) as MeshInstance3D
				if wire != null:
					wires.append(wire)
	return wires
