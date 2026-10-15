extends Node3D
## A turntable for the generated crew models (M6, D-054): every class model that exists in
## [constant MODEL_DIR] stands in a row in the game's daylight and turns slowly, painted by
## the team-colour shader (D-073) as a [CrewBody].
##
## Run it with [code]Godot --path . res://characters/crew/crew_preview.tscn[/code].
## Space pauses the turning; the left and right arrow keys turn the models by hand; T switches
## every model between your team's blue and the enemies' red. Start in red with
## [code]-- --enemy[/code] after the scene path.

## Where tools/modelgen/modelgen.py writes the class models.
const MODEL_DIR := "res://assets/models/crew/"
## The classes, left to right.
const CLASSES: Array[String] = ["rifleman", "bulwark", "marksman", "scout"]
## The body scene each class model is shown in.
const BODY_SCENE := preload("res://characters/crew/crew_body.tscn")

## Distance between two models, in metres.
@export var spacing: float = 1.9
## How fast the models turn, in degrees per second.
@export var turn_speed_degrees: float = 30.0

var _turning: bool = true
## True while the models wear the enemy colour (red) instead of your team's (blue).
var _showing_enemies: bool = false
var _label: Label

@onready var _models: Node3D = $Models


func _ready() -> void:
	var found: Array[CrewBody] = []
	for class_id in CLASSES:
		var path := MODEL_DIR + class_id + ".glb"
		if ResourceLoader.exists(path):
			var body := BODY_SCENE.instantiate() as CrewBody
			# The model is built in the body's _ready, so choose it before adding the body.
			body.model = load(path) as PackedScene
			_models.add_child(body)
			found.append(body)
	for i in found.size():
		found[i].position.x = (i - (found.size() - 1) / 2.0) * spacing
		# Models face -Z (Godot's forward); turn them to face the camera.
		found[i].rotation.y = PI
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)
	_show_team(OS.get_cmdline_user_args().has("--enemy"))


func _process(delta: float) -> void:
	var turn := turn_speed_degrees if _turning else 0.0
	if Input.is_key_pressed(KEY_LEFT):
		turn = -90.0
	elif Input.is_key_pressed(KEY_RIGHT):
		turn = 90.0
	for model in _models.get_children():
		(model as Node3D).rotate_y(deg_to_rad(turn) * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				_turning = not _turning
			KEY_T:
				_show_team(not _showing_enemies)


## Paints every model in the enemy colour or in your team's, and says which in the label.
func _show_team(enemies: bool) -> void:
	_showing_enemies = enemies
	var color := Teams.ENEMY_COLOR if enemies else Teams.FRIENDLY_COLOR
	for body in _models.get_children():
		(body as CrewBody).set_team_color(color)
	_label.text = "Enemies (red) — T: show your team" if enemies else "Your team (blue) — T: show enemies"
