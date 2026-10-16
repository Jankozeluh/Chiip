class_name DebugOverlay
extends CanvasLayer
## The FPS counter and the developer overlay (v0.2, D-233, the designer's pages "27 FPS player" and "28 Debug developer");
## F3 (the toggle_debug action) steps [member Settings.fps_counter] through off, player and developer, and the
## Settings → Interface row sets it too. It starts off (a first look at the game shows the game, D-133).
##
## **Player:** a small block at the top left on a dim backing: the frame rate and the frame time, and online (with the
## Net stats switch on) the ping and the share of snapshots lost. Values turn the alert colour below 60 FPS, above
## 100 ms of ping and above 1 % loss. It can stay on through a whole match.
##
## **Developer:** a panel with four sections like CS's cl_showpos: PERFORMANCE (FPS and its lowest, frame time and its
## highest over the last 64 frames, and their [FrameGraph]), NETWORK (online only), MOVEMENT (speed in m/s and in
## Quake-style units, vertical speed, position, the last jump's height, stance) and WEAPON (inaccuracy, the recoil built
## up, the last bullet hit's zone, damage and distance). While off it does no work.
##
## Its look is the theme's (HudFpsPanel, HudDebugPanel and the HUD's labels); the numbers come from tokens (the
## "Hud" type).

## The theme type that holds the sizes.
const THEME_TYPE := &"Hud"
## The FPS below which, the ping above which and the loss above which (percent) the player block shows its number in the alert colour.
const LOW_FPS := 60.0
const HIGH_PING := 100.0
const HIGH_LOSS := 1.0
## Seconds between two updates of the player block's numbers (they would flicker every frame).
const PLAYER_REFRESH := 0.25

## The player to show information about. Set by the main scene.
var player: Character
## Online (M9): the [NetHost] or [NetClient] whose ping, loss and corrections are shown; null offline.
var net_game: Node

## Feet height the last time the player stood on the ground.
var _ground_height: float = 0.0
## How high the feet rose above the ground during the current or last jump.
var _jump_peak: float = 0.0
var _was_on_floor: bool = true
var _ui_scale: float = 1.0
## What is showing now: "off", "player" or "developer".
var _mode: String = "off"
## The frame times of the last 64 frames in milliseconds, for the minimum and maximum.
var _frame_times: Array[float] = []
## Time and frames since the player block's last refresh.
var _refresh_time: float = 0.0
var _refresh_frames: int = 0
var _refresh_ms: float = 0.0
## The developer panel's value labels by "section/key", and each section's aside label.
var _values: Dictionary = {}
var _asides: Dictionary = {}
var _sections: Array[String] = []

@onready var _player_panel: PanelContainer = %PlayerPanel
@onready var _developer_panel: PanelContainer = %DeveloperPanel
@onready var _fps_value: Label = %FpsValue
@onready var _ms_value: Label = %MsValue
@onready var _net_row: HBoxContainer = %NetRow
@onready var _ping_value: Label = %PingValue
@onready var _loss_value: Label = %LossValue
@onready var _sections_box: VBoxContainer = %Sections
@onready var _graph: FrameGraph = %Graph


func _ready() -> void:
	_build_sections()
	var settings := Settings.get_instance()
	settings.changed.connect(_on_setting_changed)
	_apply_mode(settings.fps_counter)


## Scales the overlay; 1.0 is the size it's designed for (a 720-pixel-tall window).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	for panel: Control in [_player_panel, _developer_panel]:
		UiScale.apply_tree(panel, factor)
	_graph.set_ui_scale(factor)


## Shows [param mode] ("off", "player" or "developer") now, whatever the setting says.
func set_mode(mode: String) -> void:
	_apply_mode(mode)


## What is showing: "off", "player" or "developer".
func get_mode() -> String:
	return _mode


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		var settings := Settings.get_instance()
		var modes := Settings.FPS_COUNTER_MODES
		settings.fps_counter = modes[(modes.find(settings.fps_counter) + 1) % modes.size()]


func _on_setting_changed(key: StringName) -> void:
	if key == &"fps_counter":
		_apply_mode(Settings.get_instance().fps_counter)
	elif key == &"net_stats":
		_net_row.visible = _shows_net()


func _apply_mode(mode: String) -> void:
	_mode = mode
	visible = mode != "off"
	_player_panel.visible = mode == "player"
	_developer_panel.visible = mode == "developer"
	set_process(visible)
	_net_row.visible = _shows_net()
	if visible:
		_refresh_player(true)


func _shows_net() -> bool:
	return net_game != null and is_instance_valid(net_game) and Settings.get_instance().net_stats


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


func _process(delta: float) -> void:
	var milliseconds := delta * 1000.0
	_frame_times.append(milliseconds)
	while _frame_times.size() > _const(&"graph_bars"):
		_frame_times.pop_front()
	_refresh_time += delta
	_refresh_frames += 1
	_refresh_ms += milliseconds
	if _mode == "developer":
		_graph.add_frame(milliseconds)
		_refresh_developer()
	elif _refresh_time >= PLAYER_REFRESH:
		_refresh_player(false)


## The player block's numbers: the average frame rate and frame time since the last refresh, and the net numbers.
func _refresh_player(now: bool) -> void:
	var frames := maxi(_refresh_frames, 1)
	var average_ms := _refresh_ms / frames if _refresh_frames > 0 else 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)
	var fps := 1000.0 / maxf(average_ms, 0.001)
	if now and _refresh_frames == 0:
		fps = float(Engine.get_frames_per_second())
	_fps_value.text = str(roundi(fps))
	_ms_value.text = "%.1f" % average_ms
	_set_alert(_fps_value, roundi(fps) < LOW_FPS)
	var net := get_net_numbers()
	if net.x >= 0.0:
		_ping_value.text = str(roundi(net.x))
		_loss_value.text = "%d%%" % roundi(net.y)
		_set_alert(_ping_value, net.x > HIGH_PING)
		_set_alert(_loss_value, net.y > HIGH_LOSS)
	_refresh_time = 0.0
	_refresh_frames = 0
	_refresh_ms = 0.0


## The ping in milliseconds and the snapshot loss in percent as (ping, loss); (-1, -1) offline. A host has no network
## in front of its own player: 0 and 0.
func get_net_numbers() -> Vector2:
	if net_game == null or not is_instance_valid(net_game):
		return Vector2(-1.0, -1.0)
	if net_game is NetClient:
		var client := net_game as NetClient
		return Vector2(maxf(client.ping_ms, 0.0), client.snapshot_loss * 100.0)
	return Vector2.ZERO


func _set_alert(label: Label, alert: bool) -> void:
	label.theme_type_variation = &"HudAlertLabel" if alert else &"HudSmallLabel"


# --- The developer panel ---


## The sections of the developer panel: title, and its rows' keys.
const SECTION_ROWS := {
	"PERFORMANCE": ["FPS", "FRAME"],
	"NETWORK": ["PING", "LOSS", "SNAPSHOT"],
	"MOVEMENT": ["SPEED", "VERTICAL", "POSITION", "JUMP PEAK", "STANCE"],
	"WEAPON": ["INACCURACY", "RECOIL", "LAST HIT"],
}


func _build_sections() -> void:
	for title: String in SECTION_ROWS:
		var section := VBoxContainer.new()
		section.name = title.capitalize()
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sections_box.add_child(section)
		# Before the footer, in the order of the table.
		_sections_box.move_child(section, _sections.size())
		var rule := PanelContainer.new()
		rule.theme_type_variation = &"HudDebugRule"
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(rule)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.add_child(heading)
		var name_label := _label(&"HudPlateMuteLabel", title)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		var aside := _label(&"HudPlateMuteLabel", "")
		heading.add_child(aside)
		_asides[title] = aside
		for key: String in SECTION_ROWS[title]:
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			section.add_child(row)
			var key_label := _label(&"HudPlateDimLabel", key)
			key_label.custom_minimum_size.x = _const(&"debug_key_width")
			row.add_child(key_label)
			var value := _label(&"HudPlateLabel", "")
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
			_values["%s/%s" % [title, key]] = value
		_sections.append(title)
		if title == "PERFORMANCE":
			_graph.get_parent().remove_child(_graph)
			section.add_child(_graph)
	_asides["PERFORMANCE"].text = "LAST %d FRAMES" % _const(&"graph_bars")


## A size of the theme's "Hud" type.
func _const(constant_name: StringName) -> int:
	return _developer_panel.get_theme_constant(constant_name, THEME_TYPE)


func _label(role: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_developer() -> void:
	var lowest_fps := 0.0
	var highest_ms := 0.0
	if not _frame_times.is_empty():
		highest_ms = _frame_times.max()
		lowest_fps = 1000.0 / maxf(highest_ms, 0.001)
	_set_value("PERFORMANCE/FPS", "%d   MIN %d" % [Engine.get_frames_per_second(), roundi(lowest_fps)])
	var last_ms: float = _frame_times.back() if not _frame_times.is_empty() else 0.0
	_set_value("PERFORMANCE/FRAME", "%.1f MS   MAX %.1f" % [last_ms, highest_ms])
	var net := get_net_numbers()
	var online := net.x >= 0.0
	(_sections_box.get_node("Network") as Control).visible = online
	if online:
		_asides["NETWORK"].text = "ONLINE"
		_set_value("NETWORK/PING", "%d MS" % roundi(net.x))
		_set_value("NETWORK/LOSS", "%.1f%%" % net.y)
		_set_value("NETWORK/SNAPSHOT", "%d B   AVG %d" % [net_game.get("snapshot_bytes"), roundi(net_game.get("snapshot_bytes_average"))])
	if player == null:
		return
	var velocity := player.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var feet := player.global_position
	_set_value("MOVEMENT/SPEED", "%.2f M/S   %d U/S" % [speed, roundi(speed / Character.UNITS_TO_METRES)])
	_set_value("MOVEMENT/VERTICAL", "%.2f M/S" % velocity.y)
	_set_value("MOVEMENT/POSITION", "%.2f  %.2f  %.2f" % [feet.x, feet.y, feet.z])
	_set_value("MOVEMENT/JUMP PEAK", "%.2f M   %d U" % [_jump_peak, roundi(_jump_peak / Character.UNITS_TO_METRES)])
	_set_value("MOVEMENT/STANCE", "%s · %s · %s" % ["CROUCH" if player.is_crouching else "STAND", "ON FLOOR" if player.is_on_floor() else "IN AIR",
			"WALK" if Input.is_action_pressed("walk") else "RUN"])
	var weapon := player.weapon
	_asides["WEAPON"].text = String(weapon.data.display_name).to_upper() if weapon != null and weapon.data != null else ""
	_set_value("WEAPON/INACCURACY", "%.2f°" % (weapon.get_inaccuracy() if weapon != null else 0.0))
	var built := (weapon.get_spray_shot() - 1) if weapon != null else 0
	_set_value("WEAPON/RECOIL", "%d SHOT%s BUILT UP" % [built, "" if built == 1 else "S"])
	_set_value("WEAPON/LAST HIT", _describe_hit(weapon.last_hit if weapon != null else {}))


func _set_value(key: String, text: String) -> void:
	(_values[key] as Label).text = text


## One-line summary of a bullet hit, e.g. "HEAD 142 DMG AT 5.0 M".
func _describe_hit(hit: Dictionary) -> String:
	if hit.is_empty():
		return "-"
	if hit.zone == "":
		return "WORLD AT %.1f M" % hit.distance
	return "%s %d DMG AT %.1f M" % [String(hit.zone).to_upper(), int(hit.damage), hit.distance]


# --- Test hooks ---


## The player block (FPS, frame time, ping and loss).
func get_player_panel() -> PanelContainer:
	return _player_panel


## The developer panel.
func get_developer_panel() -> PanelContainer:
	return _developer_panel


## The text of a developer row ("MOVEMENT/SPEED"), or "".
func get_value_text(key: String) -> String:
	return (_values[key] as Label).text if _values.has(key) else ""


## The names of the developer panel's sections, in order.
func get_section_titles() -> Array[String]:
	return _sections


## The frame-time graph.
func get_graph() -> FrameGraph:
	return _graph


## The labels of the player block: FPS, frame time, ping and loss.
func get_player_labels() -> Array[Label]:
	return [_fps_value, _ms_value, _ping_value, _loss_value]


## The player block's net row.
func get_net_row() -> HBoxContainer:
	return _net_row


## Refreshes the player block's numbers at once (a test does not wait a quarter of a second).
func refresh_now() -> void:
	_refresh_player(true)
