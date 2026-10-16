class_name TrainingMenu
extends CanvasLayer
## The aim trainer's start panel (v0.2, D-236, the designer's "20 Aim start"): shooting the gold pad on the Shooting Range
## opens it over the dimmed world with the mouse free: the aim trainer's name and one line about it, the length of the
## run (30, 60 or 90 seconds), the best score with the gun in your hand for that length, and **Start**. Enter (or a click
## on Start) starts the run; Esc closes the panel and leaves you at the range. Each length keeps its own best
## ([method RangeTrainer.best_key]); 30 seconds is the trainer's own.
##
## It registers with [MenuState] like every menu (D-059), takes its look from the UI theme (type variations only, D-057),
## and finds the trainer through [TrainingHub]: it puts itself there while it is in the tree. Without it (a map on its own,
## the tests) a shot at the pad starts a run at once.

## The run lengths on offer, in seconds.
const LENGTHS: Array[int] = [30, 60, 90]
## What the panel says about the aim trainer.
const BLURB := "Hit as many targets as you can. Faster hits score more."

## Emitted when the panel closes (Start, Esc or the pad's player leaving).
signal closed

var _trainer: RangeTrainer
var _shooter: Character
var _length: int = 30
var _length_buttons: Dictionary = {}
var _ui_scale: float = 1.0

@onready var _panel: PanelContainer = %Panel
@onready var _lengths_box: HBoxContainer = %Lengths
@onready var _best_caption: Label = %BestCaption
@onready var _best_value: Label = %BestValue
@onready var _best_detail: Label = %BestDetail
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	visible = false
	_build_lengths()
	_start_button.pressed.connect(_start)
	TrainingHub.menu = self


func _exit_tree() -> void:
	if TrainingHub.menu == self:
		TrainingHub.menu = null
	MenuState.close(self)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and MenuState.is_top(self):
		close()
		get_viewport().set_input_as_handled()


## Scales the panel; 1.0 is the size it is designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiTheme.apply(self, factor)


## Opens the panel for [param trainer] and the player who shot its pad.
func open_for(trainer: Node3D, shooter: Node) -> void:
	_trainer = trainer as RangeTrainer
	_shooter = shooter as Character
	if _trainer == null or _shooter == null or visible:
		return
	visible = true
	MenuState.open(self)
	_refresh_best()
	_start_button.grab_focus()


## Closes the panel, hands the mouse back and says so ([signal closed]). Does nothing when it is closed.
func close() -> void:
	if not visible:
		return
	visible = false
	MenuState.close(self)
	closed.emit()


## True while the panel shows.
func is_open() -> bool:
	return visible


## The length picked, in seconds.
func get_length() -> int:
	return _length


## Picks a length (what a click on its segment does).
func set_length(seconds: int) -> void:
	if not LENGTHS.has(seconds):
		return
	_length = seconds
	if _length_buttons.has(seconds):
		(_length_buttons[seconds] as Button).set_pressed_no_signal(true)
	_refresh_best()


## The Start button, for the tests.
func get_start_button() -> Button:
	return _start_button


## The best line: its caption ("Best · 60 s"), the score and the detail ("82% · 14 Oct" or "-").
func get_best_texts() -> Array[String]:
	return [_best_caption.text, _best_value.text, _best_detail.text]


func _start() -> void:
	var trainer := _trainer
	var shooter := _shooter
	close()
	if trainer != null and is_instance_valid(trainer) and shooter != null and is_instance_valid(shooter):
		trainer.start(shooter, float(_length))


func _build_lengths() -> void:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SegmentFrame"
	_lengths_box.add_child(frame)
	var strip := HBoxContainer.new()
	strip.theme_type_variation = &"SegmentRow"
	frame.add_child(strip)
	var group := ButtonGroup.new()
	for seconds in LENGTHS:
		var button := Button.new()
		button.text = "%d s" % seconds
		button.theme_type_variation = &"WideSegmentButton"
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = seconds == _length
		button.toggled.connect(func(on: bool) -> void:
			if on:
				set_length(seconds))
		strip.add_child(button)
		_length_buttons[seconds] = button


## The best score with the gun in hand for the picked length.
func _refresh_best() -> void:
	_best_caption.text = "Best · %d s" % _length
	_best_value.text = "-"
	_best_detail.text = ""
	if _trainer == null or _shooter == null or _shooter.weapon == null or _shooter.weapon.data == null:
		return
	var key := RangeTrainer.best_key(_shooter.weapon.data.id, float(_length))
	var entry := _trainer.get_book().get_best(key)
	if entry.is_empty():
		return
	_best_value.text = TrainingHud._thousands(roundi(float(entry.get("score", 0.0))))
	var parts := PackedStringArray()
	if entry.has("accuracy"):
		parts.append("%d%%" % roundi(float(entry["accuracy"])))
	if entry.has("date"):
		parts.append(StatsMenu.short_date(int(entry["date"])))
	_best_detail.text = " · ".join(parts)
