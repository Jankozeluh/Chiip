extends Node3D
## A turntable for the generated crew models (M6, D-054): every class model that exists in
## [constant MODEL_DIR] stands in a row in the game's daylight and turns slowly.
##
## Run it with [code]Godot --path . res://characters/crew/crew_preview.tscn[/code].
## Space pauses the turning; the left and right arrow keys turn the models by hand.

## Where tools/modelgen/modelgen.py writes the class models.
const MODEL_DIR := "res://assets/models/crew/"
## The classes, left to right.
const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]

## Distance between two models, in metres.
@export var spacing: float = 1.9
## How fast the models turn, in degrees per second.
@export var turn_speed_degrees: float = 30.0

var _turning: bool = true

@onready var _models: Node3D = $Models


func _ready() -> void:
	var found: Array[Node3D] = []
	for class_id in CLASSES:
		var path := MODEL_DIR + class_id + ".glb"
		if ResourceLoader.exists(path):
			var model := (load(path) as PackedScene).instantiate() as Node3D
			_models.add_child(model)
			found.append(model)
	for i in found.size():
		found[i].position.x = (i - (found.size() - 1) / 2.0) * spacing
		# Models face -Z (Godot's forward); turn them to face the camera.
		found[i].rotation.y = PI


func _process(delta: float) -> void:
	var turn := turn_speed_degrees if _turning else 0.0
	if Input.is_key_pressed(KEY_LEFT):
		turn = -90.0
	elif Input.is_key_pressed(KEY_RIGHT):
		turn = 90.0
	for model in _models.get_children():
		(model as Node3D).rotate_y(deg_to_rad(turn) * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE:
		_turning = not _turning
