extends CanvasLayer
## On-screen readout of the player's movement and weapon, like CS's cl_showpos.
## Toggle it with F3 (the toggle_debug action).

## The player to show information about. Set by the main scene.
var player: Character

## Feet height the last time the player stood on the ground.
var _ground_height: float = 0.0
## How high the feet rose above the ground during the current or last jump.
var _jump_peak: float = 0.0
var _was_on_floor: bool = true

@onready var _label: Label = $Label


## Scales the overlay text; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	UiScale.apply(_label, factor)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# Measure jump height per physics tick, relative to the ground you jumped from.
	var on_floor := player.is_on_floor()
	var feet_height := player.global_position.y
	if on_floor:
		_ground_height = feet_height
	else:
		if _was_on_floor:
			_jump_peak = 0.0
		_jump_peak = maxf(_jump_peak, feet_height - _ground_height)
	_was_on_floor = on_floor


func _process(_delta: float) -> void:
	if player == null or not visible:
		return
	var player_velocity := player.velocity
	var speed := Vector2(player_velocity.x, player_velocity.z).length()
	var feet := player.global_position
	_label.text = "\n".join([
		"FPS        %d" % Engine.get_frames_per_second(),
		"Speed      %5.2f m/s  %4.0f u/s" % [speed, speed / Character.UNITS_TO_METRES],
		"Vertical   %5.2f m/s" % player_velocity.y,
		"Position   %6.2f %6.2f %6.2f" % [feet.x, feet.y, feet.z],
		"Jump peak  %5.2f m    %4.0f u" % [_jump_peak, _jump_peak / Character.UNITS_TO_METRES],
		"On floor   %s" % _yes_no(player.is_on_floor()),
		"Crouching  %s" % _yes_no(player.is_crouching),
		"Walking    %s" % _yes_no(Input.is_action_pressed("walk")),
		"Shoot/Aim  %s / %s" % [_yes_no(Input.is_action_pressed("shoot")), _yes_no(Input.is_action_pressed("aim"))],
		"",
		"Inaccuracy %5.2f°" % player.weapon.get_inaccuracy(),
		"Recoil     %d shot(s) built up" % (player.weapon.get_spray_shot() - 1),
		"Last hit   %s" % _describe_hit(player.weapon.last_hit),
		"",
		"F3 hide · Esc pause menu",
	])


## One-line summary of a bullet hit, e.g. "Head 142 dmg at 5.0 m".
func _describe_hit(hit: Dictionary) -> String:
	if hit.is_empty():
		return "-"
	if hit.zone == "":
		return "world at %.1f m" % hit.distance
	return "%s %d dmg at %.1f m" % [hit.zone, int(hit.damage), hit.distance]


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
