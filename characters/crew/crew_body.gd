class_name CrewBody
extends Node3D
## The visible body of a generated crew model (M6, D-053, D-072 to D-076): it puts the
## class's model under itself, paints it in a team colour, carries the hit zones and animates.
##
## Team colour: every mesh of the model gets the class's shared [ShaderMaterial] (see
## [method material_for] and characters/crew/crew.gdshader), and the colour goes into a
## per-instance shader parameter, Godot's answer to Unity's MaterialPropertyBlock.
##
## Hit zones (D-055, D-074): one [Hitbox] area per box of the class's [HitZones], each under a
## [BoneAttachment3D] on the model's [Skeleton3D], so the zones follow the animated bones.
##
## Animation (D-076): an [AnimationTree] runs the shared graph
## (characters/crew/crew_animation_tree.tres, made by tools/make_crew_animation_tree.gd) on the
## model's clips. Every physics tick the body reads its [Character]'s *state*: velocity relative
## to where it faces, crouching, on the ground or not, and the aim pitch, never the input, so
## in M9 a network player animates from the same replicated state. The character's events (a
## shot, a reload, a hit, death, respawn) play their layers. The tree runs on physics ticks, so
## the hit zones move in step with the game's simulation.
##
## The body also holds the third-person gun on the [code]weapon[/code] bone, with its own muzzle
## flash. Whoever looks through a character's eyes sees its first-person viewmodel instead (see
## [method Character.set_first_person]).

## The shader every crew model uses.
const SHADER := preload("res://characters/crew/crew.gdshader")
## The animation graph every class shares.
const ANIMATION_TREE := preload("res://characters/crew/crew_animation_tree.tres")
## The gun in the hands before a character is attached (the Ram); then the held weapon's own model.
const GUN_SCENE := preload("res://assets/models/weapons/rifle.glb")
## The third-person muzzle flash.
const GUN_FLASH_SCENE := preload("res://characters/crew/gun_flash.tscn")
## Where the gun's muzzle is, in weapon space (tools/modelgen/weapons.py).
const GUN_MUZZLE := Vector3(0.0, 0.022, -0.58)
## How long the muzzle flash shows, in seconds (as long as the first-person one).
const GUN_FLASH_TIME := 0.04
## Speeds the locomotion clips were made for, in m/s (tools/modelgen/anims.py): CS's rifle run
## (215 units/s), walk (x0.52) and crouch-walk (x0.34). The clips play faster or slower so the
## feet keep up with the real speed.
const RUN_SPEED := 215.0 * 0.0254
const WALK_SPEED := RUN_SPEED * 0.52
const CROUCH_SPEED := RUN_SPEED * 0.34
## Length of the reload clip in seconds (the rifle's reload time when it was made); it is
## stretched to the held weapon's own reload time.
const RELOAD_CLIP_TIME := 2.5
## Seconds to blend into or out of crouching (the character's crouch takes 0.15 s).
const CROUCH_BLEND_TIME := 0.15
## Seconds to blend between the ground poses and the falling pose.
const AIR_BLEND_TIME := 0.12
## Time in the air before landing plays the landing (smaller hops just blend back).
const LAND_AFTER_AIR_TIME := 0.25
## Upward speed in m/s that counts as a jump when the feet leave the ground.
const JUMP_SPEED := 0.5

## The generated class model, a [code].glb[/code] from assets/models/crew/ (see tools/modelgen).
## Its textures are found next to it: [code]rifleman.glb[/code] uses [code]rifleman_albedo.png[/code]
## and [code]rifleman_mask.png[/code].
@export var model: PackedScene

## The class's hit-zone boxes, a [code]*_hit_zones.tres[/code] written by tools/modelgen. When it
## is empty, the file next to the model is used: [code]rifleman.glb[/code] uses
## [code]rifleman_hit_zones.tres[/code].
@export var hit_zones: HitZones

## Run the animation graph. Off, the model keeps its rest pose (the T-pose), which tests use to
## measure the hit zones as the generator made them.
@export var animated: bool = true

## One shared material per class model, by model path.
static var _materials: Dictionary = {}
## What the hands show while the character holds nothing: a weapon without a model.
static var _NO_GUN := WeaponData.new()

## The colour to paint the team parts in, kept until the model is built.
var _team_color: Color = Teams.FRIENDLY_COLOR
## Every mesh of the instantiated model; they all get the colour.
var _meshes: Array[MeshInstance3D] = []
## The model's skeleton, or null before the model is built.
var _skeleton: Skeleton3D
## Every hit zone box built from [member hit_zones].
var _hitboxes: Array[Hitbox] = []
## The collision shape of each hit zone, parallel to [member _hitboxes].
var _hitbox_shapes: Array[CollisionShape3D] = []
## The character whose state the animations follow (see [method attach]).
var _character: Character
var _tree: AnimationTree
var _gun_flash: Node3D
## The bone attachment the gun hangs on, and the gun's data shown there (the held weapon's, M7).
var _gun_mount: BoneAttachment3D
var _gun_data: WeaponData
## The weapon whose shots and reloads the body plays (the character's held one).
var _weapon: Weapon
var _flash_time_left: float = 0.0
## Smoothed 0..1 amounts for the crouch and the falling pose.
var _crouch: float = 0.0
var _air: float = 0.0
## Seconds since the feet left the ground.
var _air_time: float = 0.0
var _was_on_ground: bool = true
## The zone of the last hit taken, to pick the death (a headshot crumples).
var _last_hit_zone: int = -1
var _dead: bool = false
## The style of the last death played, to play it again after a class change.
var _death_style: String = "backward"


func _ready() -> void:
	_build()


## Builds the model, its hit zones, the gun and the animation tree from [member model] and
## [member hit_zones]. [method _ready] and [method set_class] both use it.
func _build() -> void:
	if model == null:
		return
	var instance := model.instantiate() as Node3D
	instance.name = "Model"
	add_child(instance)
	var material := material_for(model.resource_path)
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = material
		_meshes.append(mesh)
	set_team_color(_team_color)
	_skeleton = _find_skeleton(instance)
	if _skeleton == null:
		return
	# Update the bones on physics ticks, like the AnimationTree, so the hit zones keep step.
	_skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	_build_hit_zones()
	_build_gun()
	if animated:
		_build_animation_tree(instance)


func _physics_process(delta: float) -> void:
	if _character == null or _tree == null or _dead:
		return
	var local := _character.global_basis.inverse() * _character.velocity
	update_animation_state(Vector2(local.x, -local.z), _character.is_crouching, _character.is_on_floor(),
			rad_to_deg(_character.get_aim_angles().y), delta)


func _process(delta: float) -> void:
	if _flash_time_left > 0.0:
		_flash_time_left -= delta
		_gun_flash.visible = _flash_time_left > 0.0


## Ties the body to [param character]: the animations follow its state from now on, and its
## shots, reloads, hits, death and respawn play their animations. [Character] calls it once.
func attach(character: Character) -> void:
	_character = character
	character.damaged.connect(_on_damaged)
	character.died.connect(_on_died)
	character.respawned.connect(_on_respawned)
	character.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(character.weapon)


## Makes this body that of another class: the model and the hit zones are replaced by those of
## [param data] ([member ClassData.model] and [member ClassData.hit_zones]). The team colour, the
## attached character and the [member animated] setting stay; the animation tree and the hit
## zones are built again, so whoever listens to the old [Hitbox] nodes must look for the new
## ones ([method Character] does).
##
## The old model leaves the tree at once ([method Node.remove_child], so the new one can be
## called "Model" too) but is freed only at the end of the frame ([method Node.queue_free]): a
## class can change while one of its hit zones is still announcing a hit, and freeing an object
## inside its own signal would crash. A dead body gets its death animation again, from the start.
func set_class(data: ClassData) -> void:
	var was_dead := _dead
	var old := get_node_or_null("Model")
	if old != null:
		remove_child(old)
		old.queue_free()
	_meshes.clear()
	_hitboxes.clear()
	_hitbox_shapes.clear()
	_skeleton = null
	_tree = null
	_gun_flash = null
	_gun_mount = null
	_flash_time_left = 0.0
	model = data.model
	hit_zones = data.hit_zones
	_build()
	if was_dead:
		play_death(_death_style)


## Sets the animation graph from a character's state for this physics tick:
## [param velocity] in m/s relative to where the character faces (x right, y forward),
## [param crouching], [param on_ground], and the aim pitch in degrees (up is positive).
## [method _physics_process] calls it with the attached character's state; tests call it directly.
func update_animation_state(velocity: Vector2, crouching: bool, on_ground: bool, aim_degrees: float, delta: float) -> void:
	if _tree == null:
		return
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta / CROUCH_BLEND_TIME)
	_air = move_toward(_air, 0.0 if on_ground else 1.0, delta / AIR_BLEND_TIME)
	if on_ground:
		if not _was_on_ground and _air_time >= LAND_AFTER_AIR_TIME:
			_tree.set("parameters/Land/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_air_time = 0.0
	else:
		if _was_on_ground and _character != null and _character.velocity.y > JUMP_SPEED:
			_tree.set("parameters/Jump/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_air_time += delta
	_was_on_ground = on_ground
	_tree.set("parameters/Stand/blend_position", velocity)
	_tree.set("parameters/CrouchMove/blend_position", velocity)
	_tree.set("parameters/Crouch/blend_amount", _crouch)
	_tree.set("parameters/AirPose/blend_amount", _crouch)
	_tree.set("parameters/Air/blend_amount", _air)
	_tree.set("parameters/LocoSpeed/scale", _locomotion_speed_scale(velocity.length(), crouching))
	_tree.set("parameters/Aim/blend_position", aim_degrees)


## Plays a death: [param style] is "forward", "backward" or "headshot". The body holds the last
## frame, lying on the floor, until [method play_alive].
func play_death(style: String) -> void:
	_dead = true
	_death_style = style
	if _tree == null:
		return
	_tree.set("parameters/Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_tree.set("parameters/Death/transition_request", style)


## Back to the living animations (on respawn), standing.
func play_alive() -> void:
	_dead = false
	_crouch = 0.0
	_air = 0.0
	_air_time = 0.0
	_was_on_ground = true
	_last_hit_zone = -1
	if _tree == null:
		return
	_tree.set("parameters/Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_tree.set("parameters/Death/transition_request", "alive")


## Which way a character falls when [param killer] kills it: a headshot crumples, otherwise
## it falls away from the shooter (backward when shot from the front).
func death_style(killer: Character) -> String:
	if _last_hit_zone == Hitbox.Zone.HEAD:
		return "headshot"
	if killer == null or _character == null or killer == _character:
		return "backward"
	var to_killer := killer.global_position - _character.global_position
	var facing := -_character.global_basis.z
	return "backward" if facing.dot(to_killer) >= 0.0 else "forward"


## The meshes of the class model (they wear the team colour; the gun isn't one of them).
func get_meshes() -> Array[MeshInstance3D]:
	return _meshes


## The animation tree, for tests and debugging (null if the body isn't animated).
func get_animation_tree() -> AnimationTree:
	return _tree


## The model's skeleton (null before the model is built).
func get_skeleton() -> Skeleton3D:
	return _skeleton


## The material for the class model at [param model_path]: the crew shader with the model's
## albedo and mask textures ([code]x.glb[/code] gives [code]x_albedo.png[/code] and
## [code]x_mask.png[/code]). It is made once per model and shared by every character of
## that class; the team colour is not in it but per instance, see [method set_team_color].
static func material_for(model_path: String) -> ShaderMaterial:
	if _materials.has(model_path):
		return _materials[model_path]
	var texture_base := model_path.get_basename()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", load(texture_base + "_albedo.png"))
	material.set_shader_parameter("mask_texture", load(texture_base + "_mask.png"))
	_materials[model_path] = material
	return material


## Paints the team parts of this body in [param color] (see [method Teams.color_for]).
## Only this character changes: the colour is a per-instance shader parameter on each mesh,
## the shared material isn't touched. Safe to call before the model is built.
func set_team_color(color: Color) -> void:
	_team_color = color
	for mesh in _meshes:
		mesh.set_instance_shader_parameter("team_color", color)


## The colour the team parts are painted in.
func get_team_color() -> Color:
	return _team_color


## Every hit zone of this body (15 on the Rifleman). A [Character] listens to their
## [signal Hitbox.hit] signals.
func get_hitboxes() -> Array[Hitbox]:
	return _hitboxes


## True if the body has a hit zone of [param zone].
func has_zone(zone: Hitbox.Zone) -> bool:
	return _first_shape_of(zone) != null


## The centre of the first hit zone box of [param zone], in world space, as of the last
## skeleton update. Zero if the body has none (check [method has_zone]).
func get_zone_center(zone: Hitbox.Zone) -> Vector3:
	var shape := _first_shape_of(zone)
	return shape.global_position if shape != null else Vector3.ZERO


## How fast the locomotion clips play so the feet keep up with [param speed]: between the walk
## and run speeds the blend itself matches; slower than walking, the clips slow down a little;
## faster than running (the knife), they speed up.
func _locomotion_speed_scale(speed: float, crouching: bool) -> float:
	if speed < 0.2:
		return 1.0
	var made_for := CROUCH_SPEED if crouching else clampf(speed, WALK_SPEED, RUN_SPEED)
	return clampf(speed / made_for, 0.5, 1.5)


## Finds the first [Skeleton3D] under [param root] (the model's).
func _find_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


## Builds one [Hitbox] per box of the class's [HitZones]. Each sits under a [BoneAttachment3D]
## (a child of the skeleton that copies one bone's pose every time the skeleton updates), with
## a box-shaped [CollisionShape3D] at the box's centre in the bone's frame.
func _build_hit_zones() -> void:
	var zones := hit_zones
	if zones == null:
		var path := model.resource_path.get_basename() + "_hit_zones.tres"
		if not ResourceLoader.exists(path):
			push_warning("CrewBody: no hit zones found at %s" % path)
			return
		zones = load(path) as HitZones
	for i in zones.size():
		if _skeleton.find_bone(zones.bones[i]) < 0:
			push_warning("CrewBody: the model has no bone \"%s\"" % zones.bones[i])
			continue
		var hitbox := Hitbox.new()
		hitbox.zone = zones.zones[i] as Hitbox.Zone
		hitbox.name = hitbox.get_zone_name()
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = zones.sizes[i]
		shape.shape = box
		shape.position = zones.centers[i]
		hitbox.add_child(shape)
		var attachment := BoneAttachment3D.new()
		attachment.name = "%s_%s" % [hitbox.name, zones.bones[i]]
		attachment.bone_name = zones.bones[i]
		attachment.add_child(hitbox)
		_skeleton.add_child(attachment)
		_hitboxes.append(hitbox)
		_hitbox_shapes.append(shape)


## Puts the gun on the weapon bone (the grip), with a muzzle flash at its muzzle.
func _build_gun() -> void:
	if _skeleton.find_bone("weapon") < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "Gun"
	mount.bone_name = "weapon"
	_skeleton.add_child(mount)
	_gun_mount = mount
	_gun_flash = GUN_FLASH_SCENE.instantiate()
	_gun_flash.position = GUN_MUZZLE
	mount.add_child(_gun_flash)
	_show_gun(_gun_data)


## Shows [param data]'s model in the hands (the rifle's for null data, as the body scene was made
## with; nothing for a weapon without a model), with the muzzle flash at its muzzle.
func _show_gun(data: WeaponData) -> void:
	_gun_data = data
	if _gun_mount == null:
		return
	var old := _gun_mount.get_node_or_null("GunModel")
	if old != null:
		_gun_mount.remove_child(old)
		old.queue_free()
	var scene: PackedScene = GUN_SCENE if data == null else data.model
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.name = "GunModel"
	_gun_mount.add_child(model)
	_gun_flash.position = data.muzzle_point if data != null else GUN_MUZZLE


## The gun in the hands, for tests: the model node on the weapon bone (null if none).
func get_gun_model() -> Node3D:
	return _gun_mount.get_node_or_null("GunModel") as Node3D if _gun_mount != null else null


## Adds the AnimationTree next to the model's AnimationPlayer. Its root node is the model's root
## (where the clips' tracks, "Skeleton3D:hips" and so on, start), the same as the player's.
func _build_animation_tree(instance: Node3D) -> void:
	var found := instance.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	var player := found[0] as AnimationPlayer
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = ANIMATION_TREE
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	instance.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.set("parameters/Upper/blend_amount", 1.0)
	_tree.set("parameters/ReloadSpeed/scale", 1.0)
	_tree.set("parameters/LocoSpeed/scale", 1.0)
	# A Transition starts with no state at all (and then outputs nothing): pick "alive".
	_tree.set("parameters/Death/transition_request", "alive")
	_tree.active = true


func _first_shape_of(zone: Hitbox.Zone) -> CollisionShape3D:
	for i in _hitboxes.size():
		if _hitboxes[i].zone == zone:
			return _hitbox_shapes[i]
	return null


## The character took out another weapon: play its shots and reloads, and hold its model.
func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and is_instance_valid(_weapon):
		if _weapon.fired.is_connected(_on_fired):
			_weapon.fired.disconnect(_on_fired)
			_weapon.reload_started.disconnect(_on_reload_started)
	_weapon = weapon
	if weapon != null:
		weapon.fired.connect(_on_fired)
		weapon.reload_started.connect(_on_reload_started)
	var data := weapon.data if weapon != null else _NO_GUN
	if data != _gun_data:
		_show_gun(data)


func _on_fired(_spray_shot: int) -> void:
	if _tree != null:
		_tree.set("parameters/Fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if _gun_flash != null:
		_gun_flash.visible = true
		_gun_flash.rotation.z = randf() * TAU
		_flash_time_left = GUN_FLASH_TIME


func _on_reload_started() -> void:
	if _tree == null or _character == null or _character.weapon == null:
		return
	_tree.set("parameters/ReloadSpeed/scale", RELOAD_CLIP_TIME / maxf(_character.weapon.data.reload_time, 0.1))
	_tree.set("parameters/Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_damaged(_amount: float, zone: Hitbox.Zone, _attacker: Character) -> void:
	_last_hit_zone = zone
	if _tree != null and not _dead:
		_tree.set("parameters/Flinch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_died(killer: Character) -> void:
	play_death(death_style(killer))


func _on_respawned() -> void:
	play_alive()
