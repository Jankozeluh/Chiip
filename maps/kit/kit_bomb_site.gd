class_name KitBombSite
extends Area3D
## A bomb site drawn as a brush in TrenchBroom (the trigger_bombsite entity,
## D-125). When the map runs it turns into exactly what a hand-placed site is
## (MAPS.md, "Markers in each map scene"): an Area3D named BombSiteA or
## BombSiteB in the bomb_sites group, on the triggers layer watching players
## and bots, one box shape (the bomb finds the site's floor at the bottom of
## its box) and a floating letter. So the bomb and the bots need no changes.
##
## Draw the brush over the whole site, from the floor up to about 3 m; its
## middle should be open floor (a plant spot).

## Which site this is: "A" or "B". Set as the entity's "site" property.
@export var site: String = "A"

const LETTER_HEIGHT := 0.1
const PIXEL_FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")


func _func_godot_apply_properties(properties: Dictionary) -> void:
	site = str(properties.get("site", site)).strip_edges().to_upper()
	name = "BombSite" + site


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	name = "BombSite" + site
	add_to_group(Bomb.SITE_GROUP)
	collision_layer = PhysicsLayers.TRIGGERS
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.BOTS
	monitoring = false
	monitorable = false
	var box := _replace_shapes_with_box()
	var letter := Label3D.new()
	letter.name = "Letter"
	letter.text = site
	letter.font = PIXEL_FONT
	letter.font_size = 16
	letter.outline_size = 2
	letter.pixel_size = 0.08
	letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letter.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	letter.modulate = Color(1, 0.82, 0.35, 0.85)
	letter.position = Vector3(box.get_center().x, box.position.y + 3.1, box.get_center().z)
	add_child(letter)


## Replaces the brush's convex shapes with one box around them, and returns
## that box in the site's own space.
func _replace_shapes_with_box() -> AABB:
	var bounds := AABB()
	var first := true
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null:
			continue
		var convex := shape_node.shape as ConvexPolygonShape3D
		if convex != null:
			for point in convex.points:
				var local := shape_node.transform * point
				bounds = AABB(local, Vector3.ZERO) if first else bounds.expand(local)
				first = false
		remove_child(shape_node)
		shape_node.queue_free()
	var box_shape := BoxShape3D.new()
	box_shape.size = bounds.size
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box_shape
	shape.position = bounds.get_center()
	add_child(shape)
	return bounds
