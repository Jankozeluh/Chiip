class_name TrainingHud
extends CanvasLayer
## The Shooting Range's training on the HUD (v0.2, D-236, the designer's pages 21, 22 and 23). It only reads
## [TrainingHub], every frame, and shows what the aim trainer and the spray wall are doing:
##
## - **A run** (21): at the top, your hits, the time left with a bar, and your score; the countdown's number
##   in the time's place before it; "Esc stop" at the bottom right.
## - **The result** (22): a panel with the score (and "New best" or the best there was), accuracy, hits out of the
##   targets shown, the average time and the best streak, for the few seconds the trainer keeps it.
## - **The spray wall** (23): a panel at the top right with your gun, the shots of the spray, how much of the
##   pattern you are on (the control), the legend of the wall's two kinds of dots, and the plate that clears it,
##   for a few seconds after your last shot.
##
## It sets [member TrainingHub.hud_active] while it is in the tree, so the props keep their in-world readouts quiet.
## Time counts in [method _process] deltas. Takes no mouse clicks; sizes scale with the HUD ([UiScale]).

## The theme type of the HUD's sizes.
const THEME_TYPE := &"Hud"
## Seconds the spray panel stays after the last shot at the wall.
const SPRAY_SHOW_TIME := 6.0
## The result's lines: how many targets there were is the hits plus the misses and expired ones.
const SPRAY_HINT := "Shoot the orange plate to clear the wall"

var _run: HBoxContainer
var _hits_value: Label
var _time_value: Label
var _time_bar: Control
var _time_fill: Panel
var _score_value: Label
var _stop_hint: Label
var _result: PanelContainer
var _result_head: Label
var _result_tag: Label
var _result_score: Label
var _result_best: Label
var _result_cells: Dictionary = {}
var _spray: PanelContainer
var _spray_name: Label
var _spray_icon: TextureRect
var _spray_shots: Label
var _spray_pattern: Label
var _spray_hint: Label
var _ui_scale: float = 1.0
## The last run's numbers, kept for the result panel after the trainer moves on.
var _best_before: float = 0.0
var _last_new_best: bool = false


func _ready() -> void:
	layer = 3
	TrainingHub.hud_active = true
	_build_run()
	_build_result()
	_build_spray()
	_hide_all()


func _exit_tree() -> void:
	TrainingHub.hud_active = false


func _process(_delta: float) -> void:
	var trainer := TrainingHub.trainer as RangeTrainer if is_instance_valid(TrainingHub.trainer) else null
	var showing_trainer := trainer != null and trainer.get_state() != RangeTrainer.State.IDLE
	_run.visible = showing_trainer and trainer.get_state() != RangeTrainer.State.RESULT
	_stop_hint.visible = _run.visible
	_result.visible = showing_trainer and trainer.get_state() == RangeTrainer.State.RESULT
	if showing_trainer:
		if _run.visible:
			_update_run(trainer)
		else:
			_update_result(trainer)
	var wall := TrainingHub.wall as RangeSprayWall if is_instance_valid(TrainingHub.wall) else null
	_spray.visible = wall != null and wall.get_weapon_data() != null and wall.get_idle_seconds() < SPRAY_SHOW_TIME and not showing_trainer
	if _spray.visible:
		_update_spray(wall)


## Scales the panels with the HUD (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	for root: Control in [_run, _stop_hint, _result, _spray, _spray_hint]:
		UiScale.apply_tree(root, factor)


## Shows one of the three screens with sample numbers (the layout test and the screenshots): "run", "result" or "spray".
func preview(screen: String) -> void:
	_hide_all()
	set_process(false)
	match screen:
		"run":
			_run.visible = true
			_stop_hint.visible = true
			_hits_value.text = "34"
			_time_value.text = "0:42"
			_score_value.text = "3 410"
			_time_fill.size_flags_stretch_ratio = 0.7
		"result":
			_result.visible = true
			_result_head.text = "RUN COMPLETE · 60 S"
			_result_tag.visible = true
			_result_score.text = "5 140"
			_result_best.text = "BEST WAS 4 820"
			_set_cells(["79%", "41 / 52", "0.48 S", "17"])
		"spray":
			_spray.visible = true
			_spray_name.text = "RIFLE"
			_spray_shots.text = "18 / 30"
			_spray_pattern.text = "64%"


## Back to following the hub (after a [method preview]).
func follow_hub() -> void:
	_hide_all()
	set_process(true)


## The screens' states, for the tests: which are showing.
func get_state() -> Dictionary:
	return {"run": _run.visible, "result": _result.visible, "spray": _spray.visible}


## The run panel's texts: hits, time, score.
func get_run_texts() -> Array[String]:
	return [_hits_value.text, _time_value.text, _score_value.text]


## The result panel's score line and its four cells (accuracy, hits, average time, best streak), and whether it says new best.
func get_result_texts() -> Dictionary:
	return {"score": _result_score.text, "best": _result_best.text, "new_best": _result_tag.visible,
			"cells": _result_cells.values().map(func(label: Label) -> String: return label.text)}


## The spray panel's texts: the gun, the shots, the pattern share.
func get_spray_texts() -> Array[String]:
	return [_spray_name.text, _spray_shots.text, _spray_pattern.text]


func _hide_all() -> void:
	_run.visible = false
	_stop_hint.visible = false
	_result.visible = false
	_spray.visible = false


func _update_run(trainer: RangeTrainer) -> void:
	var score := trainer.get_score()
	if trainer.get_state() == RangeTrainer.State.COUNTDOWN:
		_time_value.text = str(ceili(trainer.get_time_left()))
		_time_bar.visible = false
		_hits_value.text = "0"
		_score_value.text = "0"
		return
	_time_bar.visible = true
	var left := trainer.get_time_left()
	_time_value.text = "%d:%02d" % [floori(left / 60.0), ceili(left) % 60 if ceili(left) % 60 != 0 or left <= 0.0 else 0]
	_time_fill.size_flags_stretch_ratio = maxf(left / maxf(trainer.get_run_seconds(), 0.001), 0.0001)
	_hits_value.text = str(score.hits)
	_score_value.text = _thousands(score.score())


func _update_result(trainer: RangeTrainer) -> void:
	var score := trainer.get_score()
	var seconds := trainer.get_run_seconds()
	var key := RangeTrainer.best_key(trainer.get_weapon_id(), seconds)
	var best := trainer.get_book().get_best_score(key)
	_result_head.text = "RUN COMPLETE · %d S" % roundi(seconds)
	var is_best := best > 0.0 and is_equal_approx(best, float(score.score()))
	_result_tag.visible = is_best
	_result_score.text = _thousands(score.score())
	_result_best.text = "" if is_best else ("BEST %s" % _thousands(roundi(best)) if best > 0.0 else "")
	var targets := score.hits + score.expired
	_set_cells(["%d%%" % roundi(score.accuracy() * 100.0), "%d / %d" % [score.hits, maxi(targets, score.hits)],
			"%.2f S" % score.average_reaction(), str(score.best_streak)])


func _set_cells(values: Array) -> void:
	var index := 0
	for label: Label in _result_cells.values():
		label.text = String(values[index])
		index += 1


func _update_spray(wall: RangeSprayWall) -> void:
	var data := wall.get_weapon_data()
	_spray_name.text = String(data.display_name).to_upper()
	var icon := UiIcons.get_icon(_spray_icon, data.id)
	_spray_icon.texture = icon
	_spray_icon.visible = icon != null
	_spray_shots.text = "%d / %d" % [wall.get_spray_shots(), wall.get_pattern_size()]
	var control := wall.get_control()
	_spray_pattern.text = "-" if control < 0.0 else "%d%%" % roundi(control)


## 3410 as "3 410".
static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return ("-" if value < 0 else "") + out


# --- Building ---


func _label(text: String, role: StringName, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_run() -> void:
	_run = HBoxContainer.new()
	_run.theme_type_variation = &"HudRunRow"
	_run.alignment = BoxContainer.ALIGNMENT_CENTER
	_run.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_run)
	_run.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_run.offset_top = 24.0
	for part: Array in [["hits", "HITS", HORIZONTAL_ALIGNMENT_RIGHT], ["time", "", HORIZONTAL_ALIGNMENT_CENTER], ["score", "SCORE", HORIZONTAL_ALIGNMENT_LEFT]]:
		var block := VBoxContainer.new()
		block.theme_type_variation = &"HudStack"
		block.custom_minimum_size.x = 160.0
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_run.add_child(block)
		if part[0] == "time":
			_time_value = _label("0:00", &"HudValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
			block.add_child(_time_value)
			_time_bar = HBoxContainer.new()
			_time_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(_time_bar)
			var back := Panel.new()
			back.theme_type_variation = &"HudScoreBarBack"
			back.custom_minimum_size = Vector2(160, 8)
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_time_bar.add_child(back)
			_time_fill = Panel.new()
			_time_fill.theme_type_variation = &"HudBarFillText"
			_time_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_time_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back.add_child(_time_fill)
		else:
			var value := _label("0", &"HudLargeLabel", part[2])
			block.add_child(value)
			block.add_child(_label(part[1], &"HudSmallLabel", part[2]))
			if part[0] == "hits":
				_hits_value = value
			else:
				_score_value = value
	_stop_hint = _label("Esc stop", &"HudSmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_stop_hint)
	_stop_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Over the ammo counter, not on it.
	_stop_hint.offset_left = -232.0
	_stop_hint.offset_top = -133.0
	_stop_hint.offset_right = -32.0
	_stop_hint.offset_bottom = -112.0


func _build_result() -> void:
	_result = PanelContainer.new()
	_result.theme_type_variation = &"TrainingPanel"
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_result)
	_result.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_result.custom_minimum_size.x = 480.0
	_result.offset_left = -240.0
	_result.offset_right = 240.0
	_result.offset_top = 128.0
	var column := VBoxContainer.new()
	column.theme_type_variation = &"PageColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_result_head = _label("RUN COMPLETE", &"DimLabel")
	_result_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_result_head)
	_result_tag = _label("NEW BEST", &"TagLabel")
	head.add_child(_result_tag)
	var score := VBoxContainer.new()
	score.theme_type_variation = &"ContentBox"
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(score)
	_result_score = _label("0", &"TitleLabel")
	score.add_child(_result_score)
	_result_best = _label("", &"MuteLabel")
	score.add_child(_result_best)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.theme_type_variation = &"ResultGrid"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for caption in ["ACCURACY", "HITS", "AVG TIME", "BEST STREAK"]:
		var cell := VBoxContainer.new()
		cell.theme_type_variation = &"ContentBox"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		cell.add_child(_label(caption, &"DimLabel"))
		var value := _label("-", &"LargeLabel")
		cell.add_child(value)
		_result_cells[caption] = value
	column.add_child(_label("Shoot the pad to go again", &"MuteLabel"))


func _build_spray() -> void:
	_spray = PanelContainer.new()
	_spray.theme_type_variation = &"OverlayPanel"
	_spray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spray.custom_minimum_size.x = 288.0
	add_child(_spray)
	_spray.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_spray.offset_left = -320.0
	_spray.offset_right = -32.0
	_spray.offset_top = 32.0
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"SprayMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spray.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"FormColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_spray_name = _label("RIFLE", &"LargeLabel")
	_spray_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_spray_name)
	_spray_icon = TextureRect.new()
	_spray_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_spray_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spray_icon.set_meta(UiScale.SKIP_SIZE_META, true)
	head.add_child(_spray_icon)
	for line: Array in [["SHOTS", "0 / 0"], ["ON PATTERN", "-"]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		var caption := _label(line[0], &"DimLabel")
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var value := _label(line[1], &"Label", HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(value)
		if line[0] == "SHOTS":
			_spray_shots = value
		else:
			_spray_pattern = value
	var rule := Panel.new()
	rule.theme_type_variation = &"StatBarLine"
	rule.custom_minimum_size.y = 2.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	for legend: Array in [["PATTERN", &"PatternDot"], ["YOUR SHOTS", &"ShotDot"]]:
		var row := HBoxContainer.new()
		row.theme_type_variation = &"FormRow"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		var dot := Panel.new()
		dot.theme_type_variation = legend[1]
		dot.custom_minimum_size = Vector2(10, 10) if legend[1] == &"PatternDot" else Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		row.add_child(_label(legend[0], &"DimLabel"))
	_spray_hint = _label(SPRAY_HINT, &"HudSmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_spray_hint)
	_spray_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_spray_hint.offset_left = -300.0
	_spray_hint.offset_right = 300.0
	_spray_hint.offset_top = -53.0
	_spray_hint.offset_bottom = -32.0
	_spray.visibility_changed.connect(func() -> void: _spray_hint.visible = _spray.visible)
