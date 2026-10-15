class_name UiSounds
extends RefCounted
## Interface sounds (D-084): a soft tick when the mouse moves onto a button, a
## click when it is pressed, and the round stingers the HUD plays. Everything
## plays without position on the *Interface* audio bus.
##
## Menus call [method attach] in their [code]_ready()[/code]: it gives every
## button below the menu its hover and click sounds (call it again after adding
## buttons; buttons already wired are skipped). A plain class with static
## members, like [Noises]: the sounds play through one [AudioStreamPlayer] it
## adds to the scene tree's root.

const HOVER := preload("res://assets/sounds/ui_hover.wav")
const CLICK := preload("res://assets/sounds/ui_click.wav")
const ROUND_START := preload("res://assets/sounds/round_start.wav")
const ROUND_WON := preload("res://assets/sounds/round_won.wav")
const ROUND_LOST := preload("res://assets/sounds/round_lost.wav")
const BOMB_PLANTED := preload("res://assets/sounds/bomb_planted_alert.wav")
## The audio bus interface sounds play on (set up by the settings, M5).
const BUS := &"Interface"
## Hover ticks are quieter than clicks, in dB.
const HOVER_VOLUME_DB := -12.0
## Meta key that marks a button already wired.
const WIRED_META := "ui_sounds_wired"

## Interface sounds play only with a window: headless runs (tests, tools) have no
## audio device, and a sound that never finishes is reported as leaked at exit.
static var enabled: bool = DisplayServer.get_name() != "headless"
static var _player: AudioStreamPlayer


## Gives every button below [param root] its hover and click sounds.
static func attach(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		_wire(node as BaseButton)


## Plays [param stream] on the interface bus, [param volume_db] louder or quieter.
static func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not enabled or stream == null:
		return
	if not is_instance_valid(_player):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		_player = AudioStreamPlayer.new()
		_player.name = "UiSounds"
		_player.bus = BUS
		_player.max_polyphony = 4
		tree.root.add_child.call_deferred(_player)
		# The node joins the tree at the end of the frame; play once it's there.
		_player.ready.connect(func() -> void: _play_now(stream, volume_db), CONNECT_ONE_SHOT)
		return
	_play_now(stream, volume_db)


static func _play_now(stream: AudioStream, volume_db: float) -> void:
	if not _player.is_inside_tree():
		return
	_player.volume_db = volume_db
	_player.stream = stream
	_player.play()


static func _wire(button: BaseButton) -> void:
	if button.has_meta(WIRED_META):
		return
	button.set_meta(WIRED_META, true)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play(HOVER, HOVER_VOLUME_DB))
	button.pressed.connect(func() -> void: play(CLICK))
