extends SceneTree
## Builds the crew's animation graph (M6 task 6, D-076) and saves it as
## [code]characters/crew/crew_animation_tree.tres[/code], an [AnimationNodeBlendTree] that
## every class shares (all classes have the same bones and clip names, tools/modelgen).
## Open the file in the editor's AnimationTree panel to see the graph.
##
## Run: [code]Godot --headless --path . --quit-after 100 --script res://tools/make_crew_animation_tree.gd[/code]
##
## The graph, from the legs up:
## [codeblock]
## Stand (2D blend: idle, walk and run in 8 directions)  ┐
## CrouchMove (2D blend: crouch idle, crouch-walk)       ┴ Crouch ─ LocoSpeed ┐
## Fall / FallCrouch ─ AirPose ──────────────────────────────────────────── Air ─ Jump ─ Land ┐
## Aim (1D blend: aim_d80 ... aim_u80) ─────────────────────────────────────────────────── Upper ─ Fire ─ Flinch ─ Reload ─ Death ─ output
## [/codeblock]
## The legs blend by speed and by direction relative to where the character faces; the upper
## body (filtered to spine, chest, head and arms) aims up and down on its own; fire and the
## flinch are added on top, the reload replaces the arms, and a death replaces everything.
## CrewBody sets the parameters from the character's state every physics tick.

const OUT := "res://characters/crew/crew_animation_tree.tres"
const UNITS_TO_METRES := 0.0254
## Speeds the locomotion clips were made for (tools/modelgen/anims.py): rifle run, walk, crouch.
const RUN_SPEED := 215.0 * UNITS_TO_METRES
const WALK_SPEED := RUN_SPEED * 0.52
const CROUCH_SPEED := RUN_SPEED * 0.34
## The eight directions of the walk/run clips: x is to the right, y forward.
const DIRECTIONS := {
	"f": Vector2(0, 1), "fr": Vector2(0.7071, 0.7071), "r": Vector2(1, 0), "br": Vector2(0.7071, -0.7071),
	"b": Vector2(0, -1), "bl": Vector2(-0.7071, -0.7071), "l": Vector2(-1, 0), "fl": Vector2(-0.7071, 0.7071),
}
## Bones the upper-body layers own.
const UPPER_BONES: Array[String] = ["spine", "chest", "head", "upper_arm_l", "forearm_l", "hand_l",
		"upper_arm_r", "forearm_r", "hand_r"]
const ARM_BONES: Array[String] = ["upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r"]


func _init() -> void:
	var tree := AnimationNodeBlendTree.new()
	var x := 0.0

	var stand := AnimationNodeBlendSpace2D.new()
	_set_space(stand, RUN_SPEED * 1.2)
	stand.add_blend_point(_clip("idle"), Vector2.ZERO, -1, &"idle")
	for dir: String in DIRECTIONS:
		stand.add_blend_point(_clip("walk_" + dir), DIRECTIONS[dir] * WALK_SPEED, -1, StringName("walk_" + dir))
		stand.add_blend_point(_clip("run_" + dir), DIRECTIONS[dir] * RUN_SPEED, -1, StringName("run_" + dir))
	tree.add_node("Stand", stand, Vector2(x, 0))

	var crouch_move := AnimationNodeBlendSpace2D.new()
	_set_space(crouch_move, RUN_SPEED * 1.2)
	crouch_move.add_blend_point(_clip("crouch_idle"), Vector2.ZERO, -1, &"crouch_idle")
	for dir: String in DIRECTIONS:
		crouch_move.add_blend_point(_clip("crouch_walk_" + dir), DIRECTIONS[dir] * CROUCH_SPEED, -1, StringName("crouch_walk_" + dir))
	tree.add_node("CrouchMove", crouch_move, Vector2(x, 200))

	x += 240
	tree.add_node("Crouch", AnimationNodeBlend2.new(), Vector2(x, 100))
	tree.connect_node("Crouch", 0, "Stand")
	tree.connect_node("Crouch", 1, "CrouchMove")
	x += 200
	tree.add_node("LocoSpeed", AnimationNodeTimeScale.new(), Vector2(x, 100))
	tree.connect_node("LocoSpeed", 0, "Crouch")

	tree.add_node("Fall", _clip("fall"), Vector2(0, 400))
	tree.add_node("FallCrouch", _clip("fall_crouch"), Vector2(0, 520))
	tree.add_node("AirPose", AnimationNodeBlend2.new(), Vector2(240, 450))
	tree.connect_node("AirPose", 0, "Fall")
	tree.connect_node("AirPose", 1, "FallCrouch")

	x += 200
	tree.add_node("Air", AnimationNodeBlend2.new(), Vector2(x, 150))
	tree.connect_node("Air", 0, "LocoSpeed")
	tree.connect_node("Air", 1, "AirPose")

	x += 200
	tree.add_node("JumpClip", _clip("jump"), Vector2(x - 100, 400))
	tree.add_node("Jump", _one_shot(0.03, 0.12, false), Vector2(x, 150))
	tree.connect_node("Jump", 0, "Air")
	tree.connect_node("Jump", 1, "JumpClip")
	x += 200
	tree.add_node("LandClip", _clip("land"), Vector2(x - 100, 400))
	tree.add_node("Land", _one_shot(0.02, 0.10, false), Vector2(x, 150))
	tree.connect_node("Land", 0, "Jump")
	tree.connect_node("Land", 1, "LandClip")

	var aim := AnimationNodeBlendSpace1D.new()
	aim.min_space = -90.0
	aim.max_space = 90.0
	for pair: Array in [["aim_d80", -80.0], ["aim_d40", -40.0], ["aim_0", 0.0], ["aim_u40", 40.0], ["aim_u80", 80.0]]:
		aim.add_blend_point(_clip(pair[0]), pair[1], -1, StringName(pair[0]))
	tree.add_node("Aim", aim, Vector2(x, -150))

	x += 200
	# CrewBody keeps its amount at 1: the filtered upper-body bones come from Aim, the rest from the legs.
	var upper := AnimationNodeBlend2.new()
	_filter(upper, UPPER_BONES)
	tree.add_node("Upper", upper, Vector2(x, 100))
	tree.connect_node("Upper", 0, "Land")
	tree.connect_node("Upper", 1, "Aim")

	x += 200
	tree.add_node("FireClip", _clip("fire"), Vector2(x - 100, 400))
	tree.add_node("Fire", _one_shot(0.0, 0.04, true), Vector2(x, 100))
	tree.connect_node("Fire", 0, "Upper")
	tree.connect_node("Fire", 1, "FireClip")
	x += 200
	tree.add_node("FlinchClip", _clip("flinch"), Vector2(x - 100, 400))
	tree.add_node("Flinch", _one_shot(0.0, 0.06, true), Vector2(x, 100))
	tree.connect_node("Flinch", 0, "Fire")
	tree.connect_node("Flinch", 1, "FlinchClip")

	x += 200
	tree.add_node("ReloadClip", _clip("reload"), Vector2(x - 200, 400))
	tree.add_node("ReloadSpeed", AnimationNodeTimeScale.new(), Vector2(x - 60, 400))
	tree.connect_node("ReloadSpeed", 0, "ReloadClip")
	var reload := _one_shot(0.12, 0.15, false)
	_filter(reload, ARM_BONES)
	tree.add_node("Reload", reload, Vector2(x, 100))
	tree.connect_node("Reload", 0, "Flinch")
	tree.connect_node("Reload", 1, "ReloadSpeed")

	x += 220
	var death := AnimationNodeTransition.new()
	death.xfade_time = 0.08
	for state: String in ["alive", "forward", "backward", "headshot"]:
		death.add_input(state)
	tree.add_node("Death", death, Vector2(x, 100))
	tree.connect_node("Death", 0, "Reload")
	var y := 300.0
	for i in 3:
		var style: String = ["forward", "backward", "headshot"][i]
		var node_name := "Death" + style.capitalize()
		tree.add_node(node_name, _clip("death_" + style), Vector2(x - 120, y))
		tree.connect_node("Death", i + 1, node_name)
		y += 120
	tree.connect_node("output", 0, "Death")
	tree.set_node_position("output", Vector2(x + 220, 100))

	var error := ResourceSaver.save(tree, OUT)
	print("Saved %s (%s)" % [OUT, error_string(error)])
	quit(error)


func _clip(animation: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = StringName(animation)
	return node


func _one_shot(fade_in: float, fade_out: float, additive: bool) -> AnimationNodeOneShot:
	var node := AnimationNodeOneShot.new()
	node.fadein_time = fade_in
	node.fadeout_time = fade_out
	node.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD if additive else AnimationNodeOneShot.MIX_MODE_BLEND
	return node


func _filter(node: AnimationNode, bones: Array[String]) -> void:
	node.filter_enabled = true
	for bone in bones:
		node.set_filter_path(NodePath("Skeleton3D:" + bone), true)


## A 2D blend space in m/s on both axes; clips play in step (sync) so the legs stay in phase.
func _set_space(space: AnimationNodeBlendSpace2D, extent: float) -> void:
	space.min_space = Vector2(-extent, -extent)
	space.max_space = Vector2(extent, extent)
	space.sync = true
	space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
