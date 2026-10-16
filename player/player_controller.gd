class_name PlayerController
extends CharacterController
## Drives a [Character] with the keyboard and mouse, and runs the first-person
## camera.
##
## Mouse look updates the view every rendered frame, so it has no delay. Keys
## and buttons are turned into a [CharacterInput] command once per physics
## tick, when the character asks for it.
##
## In a match, once you are dead the same camera shows a living teammate's view
## instead (first-person spectating, like CS): see [method spectate_next].
## That is presentation only: no game rule depends on it.
##
## While a menu or the developer console is open ([method MenuState.blocks_gameplay])
## the controller ignores keys, buttons and mouse movement: the character stands
## still and doesn't shoot, and the view stays where it was. Esc is not handled
## here: it opens the [PauseMenu], which pauses the whole tree (D-065), so this
## node doesn't run at all until the game is resumed. The only mouse rule left is
## the click that captures a free mouse (after alt-tab, say) without firing.

## Emitted when the view moves to a teammate you now watch, or back to your own
## body. [param target] is the character the view belongs to, you included. The
## HUD shows that character's health and ammo.
signal view_target_changed(target: Character)

## Degrees turned per mouse count at sensitivity 1, the same as CS's m_yaw and m_pitch.
const DEGREES_PER_MOUSE_COUNT := 0.022
## How far up or down you can look, in degrees (CS: 89).
const MAX_PITCH_DEGREES := 89.0

## The first-person camera.
@export var camera: Camera3D

@export_group("Spectating")
## Watch a living teammate after you die. [code]main.gd[/code] turns it on in
## a match; practice mode brings you back after 3 s instead, so it stays off.
@export var spectating_enabled: bool = false
## Seconds after your death before the view moves to a teammate: time to see who killed you.
@export var spectate_delay: float = 2.0
## Seconds after the teammate you watch dies before the view moves to the next
## living one.
@export var spectate_switch_delay: float = 1.5

## Mouse sensitivity on CS's scale: each mouse count turns sensitivity × 0.022°.
## Copied from [Settings] when the node is ready and whenever the setting changes.
var sensitivity: float = 1.0
## Flip vertical mouse look. Copied from [Settings] like [member sensitivity].
var invert_y: bool = false

## Horizontal look angle (left/right) in radians.
var _yaw: float = 0.0
## Vertical look angle (up/down) in radians.
var _pitch: float = 0.0
## Set when jump is pressed and used up by the next command.
var _jump_queued: bool = false
## Set when reload is pressed and used up by the next command.
var _reload_queued: bool = false
## True while a click shouldn't shoot: for the click that captures a free mouse
## again, and after the game is resumed with the fire button still held, until
## the button is released.
var _shooting_blocked: bool = false
## True while a menu or the console was open at the last frame (see [MenuState]).
var _was_blocked: bool = false
## The teammate whose eyes the camera uses, or null for your own view.
var _view_target: Character
## Seconds left until the view moves to a living teammate. Only counts down
## while there is nobody being watched who is alive.
var _switch_wait: float = 0.0


func _ready() -> void:
	# The camera is placed by code every rendered frame (see _process) instead
	# of following its parent, so mouse look has no physics-tick delay.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	character.died.connect(_on_character_died)
	Settings.get_instance().changed.connect(_on_setting_changed)
	_apply_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	# The pause menu pauses the whole tree (D-065), and this node pauses with it:
	# its _process and get_input() don't run meanwhile, so what they would clear
	# when a menu closes is done here, when the pause starts and ends.
	if what == NOTIFICATION_PAUSED:
		# A jump or reload pressed just before Esc shouldn't happen after Resume.
		_jump_queued = false
		_reload_queued = false
	elif what == NOTIFICATION_UNPAUSED:
		# A fire button still held (Esc pressed mid-burst) waits until it is let go.
		_shooting_blocked = Input.is_action_pressed("shoot")


func _unhandled_input(event: InputEvent) -> void:
	if MenuState.blocks_gameplay():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("jump"):
		# Remember the press; the next command decides whether you jump.
		# This also catches mouse-wheel jumps, which press and release instantly.
		_jump_queued = true
	elif event.is_action_pressed("reload"):
		_reload_queued = true
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# This click only captures the mouse; it shouldn't also fire a shot.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_shooting_blocked = true
	elif event.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Once you watch a teammate, a click means "next teammate". Earlier clicks
		# (the first seconds after your death) are ignored, so a click you were
		# still spamming when you died doesn't skip the view of your killer.
		if _view_target != null:
			spectate_next()
	elif event.is_action_released("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_shooting_blocked = false


func get_input(_delta: float) -> CharacterInput:
	var input := CharacterInput.new()
	if MenuState.blocks_gameplay():
		# Typing in the console or clicking in a menu shouldn't move or shoot,
		# and a jump or reload pressed just before it opened shouldn't happen after.
		_jump_queued = false
		_reload_queued = false
		input.yaw = _yaw
		input.pitch = _pitch
		return input
	input.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input.yaw = _yaw
	input.pitch = _pitch
	input.jump = _jump_queued
	input.reload = _reload_queued
	_jump_queued = false
	_reload_queued = false
	input.crouch = Input.is_action_pressed("crouch")
	input.walk = Input.is_action_pressed("walk")
	input.use = Input.is_action_pressed("use")
	input.shoot = Input.is_action_pressed("shoot") and not _shooting_blocked
	return input


func set_look_angles(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func get_camera() -> Camera3D:
	return camera


func is_local() -> bool:
	return true


func on_respawned() -> void:
	_jump_queued = false
	_reload_queued = false
	# A new round: back to your own eyes, with your rifle in hand again.
	_set_view_target(null)
	if character.weapon != null:
		character.weapon.visible = true


## Stops the character from shooting until [method unblock_shooting]: for a menu that opens over
## the game (the class menu), so a click on it is not also a shot.
func block_shooting() -> void:
	_shooting_blocked = true


## Lets the character shoot again after [method block_shooting]. If the fire button is held down
## right now (the click that closed the menu), shooting stays blocked until it is released.
func unblock_shooting() -> void:
	_shooting_blocked = Input.is_action_pressed("shoot")


## The character whose eyes the camera shows: a teammate while you spectate,
## otherwise yourself.
func get_view_target() -> Character:
	if _view_target != null and is_instance_valid(_view_target):
		return _view_target
	return character


## True while the camera shows a teammate instead of you.
func is_spectating() -> bool:
	return get_view_target() != character


## Moves the view to the next living teammate after the one you watch (in a
## fixed order, wrapping around), or to the first one if you watch nobody yet.
## Does nothing while you are alive, when spectating is off, or when no
## teammate is alive. A click does this once you watch someone.
func spectate_next() -> void:
	if not spectating_enabled or character.is_alive():
		return
	var next := _find_next_teammate()
	if next != null:
		_set_view_target(next)


func _physics_process(delta: float) -> void:
	if not spectating_enabled or character.is_alive():
		return
	if _view_target != null and not is_instance_valid(_view_target):
		_view_target = null
	if _view_target != null and _view_target.is_alive():
		# Wait the full delay again if they die.
		_switch_wait = spectate_switch_delay
		return
	# Nobody (alive) to watch: after the delay, move on to a living teammate. With
	# none left, the camera stays with the last one, at the place where they fell.
	_switch_wait -= delta
	if _switch_wait <= 0.0:
		spectate_next()


func _process(_delta: float) -> void:
	var blocked := MenuState.blocks_gameplay()
	if _was_blocked and not blocked:
		# A menu or the console just closed and the mouse is captured again: the
		# button that closed it must not fire a shot (and a stale block from before goes).
		_shooting_blocked = Input.is_action_pressed("shoot")
	_was_blocked = blocked
	var source := get_view_target()
	var head := source.head.get_global_transform_interpolated()
	# Position: where the head is drawn this frame (smoothed between physics ticks), and online
	# the fading share of a prediction correction (zero offline).
	camera.global_position = head.origin + source.view_offset
	# Rotation: your own view comes straight from the mouse, so looking around is
	# instant. A teammate's is the way their head is drawn this frame, which is
	# their aim smoothed between physics ticks like the position (the head turns
	# to the aim each tick). Plus the weapon's recoil kick, which moves the view
	# but not the aim.
	var angles := Vector3(_pitch, _yaw, 0.0)
	if source != character:
		angles = head.basis.get_euler()
	var punch := source.weapon.view_punch if source.weapon != null else Vector2.ZERO
	camera.global_rotation = Vector3(angles.x + deg_to_rad(punch.y), angles.y - deg_to_rad(punch.x), 0.0)


## Takes the mouse sensitivity, Y inversion and field of view from the settings.
## The field of view is the camera's vertical one, from CS's horizontal one at 4:3.
func _apply_settings() -> void:
	var settings := Settings.get_instance()
	sensitivity = settings.sensitivity
	invert_y = settings.invert_y
	camera.fov = Settings.vertical_fov(settings.fov)


func _on_setting_changed(key: StringName) -> void:
	if key == &"sensitivity" or key == &"invert_y" or key == &"fov":
		_apply_settings()


## Turns the view by a mouse movement measured in mouse counts.
func _look(mouse_motion: Vector2) -> void:
	var radians_per_count := deg_to_rad(sensitivity * DEGREES_PER_MOUSE_COUNT)
	var vertical_sign := -1.0 if invert_y else 1.0
	_yaw -= mouse_motion.x * radians_per_count
	_pitch -= mouse_motion.y * radians_per_count * vertical_sign
	_pitch = clampf(_pitch, deg_to_rad(-MAX_PITCH_DEGREES), deg_to_rad(MAX_PITCH_DEGREES))


func _on_character_died(_killer: Character) -> void:
	# Show your killer's view for a moment before moving to a teammate.
	_switch_wait = spectate_delay
	# The dead don't hold a gun: hide your first-person rifle, as CS does.
	if character.weapon != null:
		character.weapon.visible = false


## The living teammate after the current view target in the order they stand in
## the scene tree (so the order is the same every time), wrapping around; null
## if none is alive. The current target itself comes back when it is the only
## one alive.
func _find_next_teammate() -> Character:
	var teammates: Array[Character] = []
	for other in Character.all_in_world(character):
		if other != character and other.team == character.team:
			teammates.append(other)
	var start := teammates.find(_view_target)
	for step in range(1, teammates.size() + 1):
		var candidate := teammates[(start + step) % teammates.size()]
		if candidate.is_alive():
			return candidate
	return null


## Points the camera at [param target], or back at yourself with null. The
## teammate is shown first person ([method Character.set_first_person]): their
## body is hidden and their rifle's viewmodel shows, with their muzzle flash and
## kick, as it would on their screen. Your own rifle (a child of the camera) is
## hidden meanwhile. Both are switched back when the view moves on.
func _set_view_target(target: Character) -> void:
	if target == _view_target:
		return
	if _view_target != null and is_instance_valid(_view_target):
		_view_target.set_first_person(false)
	_view_target = target
	if target != null:
		target.set_first_person(true)
	if character.weapon != null:
		character.weapon.visible = target == null
	view_target_changed.emit(get_view_target())
