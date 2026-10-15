extends Node
## Automated UI checks (the UI theme, D-057). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/ui_test.tscn
##
## Checks that the project theme (ui/chiip_theme.tres) is set and gives plain
## controls its fonts, styleboxes and icons, that every type variation the
## menus rely on exists (and that the colors it copies from Teams and the
## scoreboard haven't drifted), that scaling a menu by 1.5 or 2 gives exactly
## 1.5 or 2 times the sizes (fonts, borders, margins, spacing, icons, minimum
## sizes) and back, that the theme preview builds, and that the real menus
## (the match-end screen, the Tab scoreboard and its table, the console) take
## their look from the theme, still build their rows and scale with it. Later
## tasks (settings, menus) add their own checks here. Quits with the number of
## failed checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const MATCH_END_SCENE := preload("res://ui/match_end_screen.tscn")
const CONSOLE_SCENE := preload("res://ui/dev_console.tscn")
const PREVIEW_SCENE := preload("res://ui/theme_preview.tscn")
const THEME_PATH := "res://ui/chiip_theme.tres"
const FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"
## Every type variation the menus use: name → the type it varies. Menus may rely on these.
const VARIATIONS := {
	"TitleLabel": "Label", "ScoreLabel": "Label", "HeaderLabel": "Label", "DimLabel": "Label",
	"BrightLabel": "Label", "TooltipLabel": "Label",
	"ModalPanel": "PanelContainer", "OverlayPanel": "PanelContainer", "InsetPanel": "PanelContainer",
	"ConsolePanel": "PanelContainer", "RowPanel": "PanelContainer", "YouRowPanel": "PanelContainer",
	"TeamHeaderFriendly": "PanelContainer", "TeamHeaderEnemy": "PanelContainer", "TooltipPanel": "PopupPanel",
	"PanelMargin": "MarginContainer", "PanelMarginWide": "MarginContainer", "RowMargin": "MarginContainer",
	"ContentBox": "VBoxContainer", "TableBox": "VBoxContainer", "TeamBox": "VBoxContainer",
	"ScoreRow": "HBoxContainer", "FormRow": "HBoxContainer", "ButtonRow": "HBoxContainer",
	"BigButton": "Button",
}

var _failures: int = 0
var _theme: Theme
var _map: Node3D
var _rounds: RoundManager
var _player: Character


func _ready() -> void:
	_theme = load(THEME_PATH) as Theme
	_test_project_theme()
	_test_styles_in_the_tree()
	_test_variations()
	_test_scaled_theme()
	await _test_scaling_a_menu()
	await _test_preview()
	await _test_console()
	await _test_scoreboard()
	await _test_match_end_screen()
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


## The theme is the project theme, with the pixel font as its default.
func _test_project_theme() -> void:
	var project_theme := ThemeDB.get_project_theme()
	_check("The project theme is ui/chiip_theme.tres, and it loads as a Theme",
			ProjectSettings.get_setting("gui/theme/custom") == THEME_PATH and _theme != null
					and project_theme != null and project_theme.resource_path == THEME_PATH,
			"setting '%s', loaded %s, project theme '%s'" % [
					ProjectSettings.get_setting("gui/theme/custom"), _theme != null,
					project_theme.resource_path if project_theme != null else "none"])
	_check("Its default font is Silkscreen at 16 px (the size every font size is built on)",
			_theme.default_font != null and _theme.default_font.resource_path == FONT_PATH and _theme.default_font_size == 16,
			"font '%s', size %d" % [_theme.default_font.resource_path if _theme.default_font != null else "none", _theme.default_font_size])


## Plain controls added to the tree look up their style in the project theme.
func _test_styles_in_the_tree() -> void:
	var holder := Control.new()
	add_child(holder)
	var button := Button.new()
	var label := Label.new()
	var slider := HSlider.new()
	var check_box := CheckBox.new()
	var line_edit := LineEdit.new()
	var option := OptionButton.new()
	option.add_item("One")
	var tabs := TabContainer.new()
	for control: Control in [button, label, slider, check_box, line_edit, option, tabs]:
		holder.add_child(control)
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var theme_normal := _theme.get_stylebox("normal", "Button") as StyleBoxFlat
	_check("A Button gets the theme's square 2 px framed look in every state, with the pixel font at 16 px",
			normal != null and normal.bg_color == theme_normal.bg_color and normal.border_width_left == 2
					and normal.corner_radius_top_left == 0
					and button.get_theme_stylebox("hover") is StyleBoxFlat and button.get_theme_stylebox("pressed") is StyleBoxFlat
					and button.get_theme_stylebox("focus") is StyleBoxFlat and button.get_theme_stylebox("disabled") is StyleBoxFlat
					and button.get_theme_font("font").resource_path == FONT_PATH and button.get_theme_font_size("font_size") == 16,
			"normal fill %s, border %d, corner %d, font '%s' %d px" % [
					normal.bg_color if normal != null else "none", normal.border_width_left if normal != null else -1,
					normal.corner_radius_top_left if normal != null else -1,
					button.get_theme_font("font").resource_path, button.get_theme_font_size("font_size")])
	_check("A Label gets the theme's text color and font, and a slider its sunken track and pixel-art knob",
			label.get_theme_color("font_color") == _theme.get_color("font_color", "Label")
					and label.get_theme_font("font").resource_path == FONT_PATH and label.get_theme_font_size("font_size") == 16
					and slider.get_theme_stylebox("slider") is StyleBoxFlat and slider.get_theme_stylebox("grabber_area") is StyleBoxFlat
					and slider.get_theme_icon("grabber").get_size() == Vector2(12, 24)
					and slider.get_theme_icon("grabber").resource_path.begins_with("res://assets/ui/"),
			"label color %s, knob %s" % [label.get_theme_color("font_color"), slider.get_theme_icon("grabber").get_size()])
	_check("A check box keeps its own look (no button frame) and gets the pixel-art check marks; a line edit its inset field",
			check_box.get_theme_stylebox("normal") is StyleBoxEmpty
					and check_box.get_theme_icon("checked").resource_path == "res://assets/ui/checkbox_on.png"
					and check_box.get_theme_icon("unchecked").get_size() == Vector2(16, 16)
					and (line_edit.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == _theme.get_stylebox("normal", "LineEdit").bg_color
					and line_edit.get_theme_color("caret_color") == _theme.get_color("caret_color", "LineEdit"),
			"check box normal is %s, checked icon '%s'" % [check_box.get_theme_stylebox("normal").get_class(), check_box.get_theme_icon("checked").resource_path])
	var popup := option.get_popup()
	var tab_selected := tabs.get_theme_stylebox("tab_selected") as StyleBoxFlat
	_check("An option button has the arrow icon and a themed drop-down list; tabs have an accent-framed selected tab joined to the page",
			option.get_theme_icon("arrow").resource_path == "res://assets/ui/arrow_down.png"
					and popup.get_theme_stylebox("panel") is StyleBoxFlat and popup.get_theme_stylebox("hover") is StyleBoxFlat
					and popup.get_theme_font("font").resource_path == FONT_PATH
					and tab_selected != null and tab_selected.border_color == _theme.get_color("accent", "Palette")
					and tab_selected.border_width_bottom == 0,
			"arrow '%s', popup panel %s, selected tab border %s" % [
					option.get_theme_icon("arrow").resource_path, popup.get_theme_stylebox("panel").get_class(),
					tab_selected.border_color if tab_selected != null else "none"])
	var tooltip_panel := _theme.get_stylebox("panel", "TooltipPanel")
	_check("Tooltips and scroll bars are themed: a tooltip panel, and scroll bars with a track and a grabber",
			tooltip_panel is StyleBoxFlat and _theme.get_stylebox("grabber", "VScrollBar") is StyleBoxFlat
					and _theme.get_stylebox("scroll", "VScrollBar") is StyleBoxFlat and _theme.get_stylebox("scroll", "HScrollBar") is StyleBoxFlat,
			"tooltip panel %s" % tooltip_panel.get_class())
	remove_child(holder)
	holder.queue_free()


## The variations exist with the right base type, and the colors copied into the theme match their source.
func _test_variations() -> void:
	var missing: Array[String] = []
	for variation: String in VARIATIONS:
		if _theme.get_type_variation_base(variation) != StringName(VARIATIONS[variation]):
			missing.append(variation)
	_check("All %d type variations the menus use exist, each on the right base type" % VARIATIONS.size(),
			missing.is_empty(), "missing or on another base: %s" % [missing])
	var holder := Control.new()
	add_child(holder)
	var title := _variation_node(Label.new(), "TitleLabel", holder)
	var score := _variation_node(Label.new(), "ScoreLabel", holder)
	var dim := _variation_node(Label.new(), "DimLabel", holder)
	var header := _variation_node(Label.new(), "HeaderLabel", holder)
	var plain := Label.new()
	holder.add_child(plain)
	_check("Label variations change only what they should: title 48 px, score 32 px, dim and header colors; all keep the pixel font",
			title.get_theme_font_size("font_size") == 48 and score.get_theme_font_size("font_size") == 32
					and dim.get_theme_font_size("font_size") == 16 and dim.get_theme_color("font_color") == _theme.get_color("text_dim", "Palette")
					and header.get_theme_color("font_color") == _theme.get_color("accent", "Palette")
					and plain.get_theme_color("font_color") != dim.get_theme_color("font_color")
					and title.get_theme_font("font").resource_path == FONT_PATH,
			"title %d, score %d, dim %d px" % [title.get_theme_font_size("font_size"), score.get_theme_font_size("font_size"), dim.get_theme_font_size("font_size")])
	var friendly := _variation_node(PanelContainer.new(), "TeamHeaderFriendly", holder)
	var enemy := _variation_node(PanelContainer.new(), "TeamHeaderEnemy", holder)
	var you_row := _variation_node(PanelContainer.new(), "YouRowPanel", holder)
	_check("The colors the theme copies still match their source: team headers = Teams.FRIENDLY_COLOR / ENEMY_COLOR, your row = ScoreboardTable.YOU_ROW_COLOR (rerun tools/make_ui_theme.gd if this fails)",
			(friendly.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Teams.FRIENDLY_COLOR
					and (enemy.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Teams.ENEMY_COLOR
					and (you_row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == ScoreboardTable.YOU_ROW_COLOR
					and _theme.get_color("friendly", "Palette") == Teams.FRIENDLY_COLOR and _theme.get_color("enemy", "Palette") == Teams.ENEMY_COLOR,
			"friendly %s, enemy %s, your row %s" % [
					(friendly.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, (enemy.get_theme_stylebox("panel") as StyleBoxFlat).bg_color,
					(you_row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color])
	var button := _variation_node(Button.new(), "BigButton", holder)
	var margin := _variation_node(MarginContainer.new(), "PanelMargin", holder)
	var box := _variation_node(VBoxContainer.new(), "ContentBox", holder)
	var plain_box := VBoxContainer.new()
	var plain_row := HBoxContainer.new()
	var plain_margin := MarginContainer.new()
	for control: Control in [plain_box, plain_row, plain_margin]:
		holder.add_child(control)
	_check("Other variations work: a big button is 32 px, PanelMargin pads 16 / 12, ContentBox spaces by 8, and plain containers keep Godot's spacing (the HUD relies on that)",
			button.get_theme_font_size("font_size") == 32 and margin.get_theme_constant("margin_left") == 16
					and margin.get_theme_constant("margin_top") == 12 and box.get_theme_constant("separation") == 8
					and plain_box.get_theme_constant("separation") == 4
					and plain_row.get_theme_constant("separation") == 4 and plain_margin.get_theme_constant("margin_left") == 0,
			"big button %d px, margin %d / %d, content box %d" % [
					button.get_theme_font_size("font_size"), margin.get_theme_constant("margin_left"),
					margin.get_theme_constant("margin_top"), box.get_theme_constant("separation")])
	remove_child(holder)
	holder.queue_free()


## UiTheme.scaled(): everything the theme holds, multiplied.
func _test_scaled_theme() -> void:
	var scaled := UiTheme.scaled(1.5)
	var twice := UiTheme.scaled(1.5)
	var unscaled_sizes: Array[String] = []
	for type in _theme.get_type_list():
		for item in _theme.get_font_size_list(type):
			if scaled.get_font_size(item, type) != roundi(_theme.get_font_size(item, type) * 1.5):
				unscaled_sizes.append("%s/%s" % [type, item])
	_check("Scaling the theme by 1.5 multiplies every font size (16 → 24, 32 → 48, 48 → 72), and 1.0 is the theme itself; a factor is built once",
			unscaled_sizes.is_empty() and scaled.default_font_size == 24 and scaled.get_font_size("font_size", "TitleLabel") == 72
					and scaled.get_font_size("font_size", "ScoreLabel") == 48 and UiTheme.scaled(1.0) == _theme and scaled == twice
					and scaled != _theme,
			"mismatches: %s, default size %d" % [unscaled_sizes, scaled.default_font_size])
	var base_normal := _theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var scaled_normal := scaled.get_stylebox("normal", "Button") as StyleBoxFlat
	var base_tab := _theme.get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	var scaled_tab := scaled.get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	var base_line := _theme.get_stylebox("separator", "HSeparator") as StyleBoxLine
	var scaled_line := scaled.get_stylebox("separator", "HSeparator") as StyleBoxLine
	_check("Styleboxes scale too: the button's border 2 → 3 and padding 14 / 8 → 21 / 12, a tab's covering edge 2 → 3, a separator 2 → 3; the colors stay, and the original is untouched",
			scaled_normal.border_width_left == 3 and scaled_normal.content_margin_left == 21.0 and scaled_normal.content_margin_top == 12.0
					and scaled_normal.bg_color == base_normal.bg_color and base_normal.border_width_left == 2 and base_normal.content_margin_left == 14.0
					and scaled_tab.expand_margin_bottom == 3.0 and base_tab.expand_margin_bottom == 2.0
					and scaled_line.thickness == 3 and base_line.thickness == 2,
			"button border %d, padding %.0f / %.0f, tab edge %.0f, separator %d" % [
					scaled_normal.border_width_left, scaled_normal.content_margin_left, scaled_normal.content_margin_top,
					scaled_tab.expand_margin_bottom, scaled_line.thickness])
	var base_icon := _theme.get_icon("checked", "CheckBox")
	var scaled_icon := scaled.get_icon("checked", "CheckBox")
	var source_colors := _image_colors(base_icon.get_image())
	var scaled_colors := _image_colors(scaled_icon.get_image())
	var no_new_colors := scaled_colors.all(func(color: Color) -> bool: return source_colors.has(color))
	_check("Icons scale with nearest-neighbor, so pixel art stays crisp: the 16 px check box becomes 24 px with no blended colors; the slider knob 12 × 24 → 18 × 36",
			scaled_icon.get_size() == Vector2(24, 24) and scaled_icon.get_image().get_size() == Vector2i(24, 24) and no_new_colors
					and base_icon.get_size() == Vector2(16, 16)
					and scaled.get_icon("grabber", "HSlider").get_size() == Vector2(18, 36),
			"check box %s, %d colors (source %d), knob %s" % [
					scaled_icon.get_size(), scaled_colors.size(), source_colors.size(), scaled.get_icon("grabber", "HSlider").get_size()])
	# Several factors in a row, as when a window is resized: each starts from the original, which is never changed.
	var at_two := UiTheme.scaled(2.0).get_icon("checked", "CheckBox")
	var at_odd := UiTheme.scaled(1.25).get_icon("checked", "CheckBox")
	var odd_colors := _image_colors(at_odd.get_image())
	_check("Scaling for another factor starts again from the original icon: 2.0 gives 32 px, 1.25 gives 20 px without blended colors, and the original image stays 16 px",
			at_two.get_image().get_size() == Vector2i(32, 32) and at_odd.get_image().get_size() == Vector2i(20, 20)
					and odd_colors.all(func(color: Color) -> bool: return source_colors.has(color))
					and base_icon.get_image().get_size() == Vector2i(16, 16),
			"2.0: %s, 1.25: %s with %d colors, original %s" % [at_two.get_image().get_size(), at_odd.get_image().get_size(), odd_colors.size(), base_icon.get_image().get_size()])
	# A yes/no constant set to 1 must stay 1 (a theme made for this check, as the real one leaves it 0).
	var switches := Theme.new()
	switches.set_constant("center_grabber", "HSlider", 1)
	switches.set_constant("separation", "VBoxContainer", 8)
	var scaled_switches := UiTheme.scale_theme(switches, 1.5)
	var constants_ok := scaled.get_constant("margin_left", "PanelMargin") == 24 and scaled.get_constant("separation", "ContentBox") == 12 \
			and scaled.get_constant("separation", "ScoreRow") == 21 \
			and scaled_switches.get_constant("center_grabber", "HSlider") == 1 and scaled_switches.get_constant("separation", "VBoxContainer") == 12
	_check("Spacing scales (margin 16 → 24, separation 8 → 12, 14 → 21) but a yes/no setting such as the slider's center_grabber doesn't (1 stays 1)",
			constants_ok, "margin %d, separation %d, center_grabber %d" % [
					scaled.get_constant("margin_left", "PanelMargin"), scaled.get_constant("separation", "ContentBox"),
					scaled_switches.get_constant("center_grabber", "HSlider")])


## Handing a menu the theme for a factor scales everything in it, and 1.0 restores it.
func _test_scaling_a_menu() -> void:
	var menu := _make_menu()
	add_child(menu)
	await get_tree().process_frame
	var layout := _menu_sizes(menu)
	UiTheme.apply(menu, 1.5)
	await get_tree().process_frame
	var at_one_and_a_half := _menu_sizes(menu)
	UiTheme.apply(menu, 1.5)
	var again := _menu_sizes(menu)
	UiTheme.apply(menu, 2.0)
	var at_two := _menu_sizes(menu)
	UiTheme.apply(menu, 1.0)
	await get_tree().process_frame
	var back := _menu_sizes(menu)
	_check("A menu at 1.0 uses the theme as designed: body 16 px, title 48 px, padding 16, button minimum 200 × 40, a one-off spacing override of 10 and font override of 20",
			layout == {"body": 16, "title": 48, "margin": 16, "button_min": Vector2(200, 40), "override_separation": 10, "override_font": 20, "popup": 16, "panel_border": 2},
			"%s" % [layout])
	_check("Scaled by 1.5 every size is exactly 1.5 times as big: fonts 24 / 72, padding 24, minimum 300 × 60, the overrides 15 and 30, the drop-down's font, the panel border 3",
			at_one_and_a_half == {"body": 24, "title": 72, "margin": 24, "button_min": Vector2(300, 60), "override_separation": 15, "override_font": 30, "popup": 24, "panel_border": 3},
			"%s" % [at_one_and_a_half])
	_check("Applying the same factor again changes nothing, 2.0 doubles everything, and 1.0 puts the original sizes back",
			again == at_one_and_a_half and at_two == {"body": 32, "title": 96, "margin": 32, "button_min": Vector2(400, 80), "override_separation": 20, "override_font": 40, "popup": 32, "panel_border": 4}
					and back == layout,
			"2.0: %s, back: %s" % [at_two, back])
	# The pixels really are laid out bigger: the panel grows by 1.5 as a whole.
	var panel := menu.get_node("Panel") as Control
	var width_one := panel.size.x
	UiTheme.apply(menu, 1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var width_scaled := panel.size.x
	UiTheme.apply(menu, 1.0)
	await get_tree().process_frame
	_check("The laid-out panel is 1.5 times as wide at 1.5 (a fixed 400 px minimum becomes 600) and the same again at 1.0",
			is_equal_approx(width_scaled, width_one * 1.5) and width_one == 400.0 and is_equal_approx(panel.size.x, width_one),
			"%.0f at 1.0, %.0f at 1.5, %.0f back at 1.0" % [width_one, width_scaled, panel.size.x])
	# Applying a theme to a part of a menu must not stay behind when the whole menu is scaled later.
	var inner := menu.get_node("Panel/Margin/Box/Body") as Label
	UiTheme.apply(inner, 1.5)
	UiTheme.apply(menu, 1.0)
	var inner_size := inner.get_theme_font_size("font_size")
	_check("A part scaled on its own doesn't keep its theme: scaling the whole menu back to 1.0 puts it at 16 px again",
			inner_size == 16, "inner label %d px" % inner_size)
	# A CanvasLayer root (the match-end screen, the HUD) hands the theme to its controls.
	var layer := CanvasLayer.new()
	var layer_control := Label.new()
	layer.add_child(layer_control)
	add_child(layer)
	UiTheme.apply(layer, 1.5)
	var layer_size := layer_control.get_theme_font_size("font_size")
	_check("A CanvasLayer isn't a Control, so UiTheme gives the theme to the controls under it (a label there gets 24 px at 1.5)",
			layer_size == 24 and layer_control.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"label %d px, filter %d" % [layer_size, layer_control.texture_filter])
	remove_child(layer)
	layer.queue_free()
	remove_child(menu)
	menu.queue_free()


## The theme preview builds, shows the styled controls and a menu can be scaled around it.
func _test_preview() -> void:
	var preview := PREVIEW_SCENE.instantiate() as Control
	add_child(preview)
	# The preview opens its drop-down after waiting for the window's focus (up to 90 frames);
	# it must not be freed before that.
	for i in 100:
		await get_tree().process_frame
	var kinds := {}
	for control: Control in preview.find_children("*", "Control", true, false):
		kinds[control.get_class()] = true
	var shown: Array[String] = ["Button", "CheckBox", "CheckButton", "OptionButton", "HSlider", "LineEdit", "TabContainer",
			"ScrollContainer", "ProgressBar", "HSeparator", "Label", "PanelContainer"]
	var absent := shown.filter(func(kind: String) -> bool: return not kinds.has(kind))
	var variations_used := {}
	for control: Control in preview.find_children("*", "Control", true, false):
		if control.theme_type_variation != &"":
			variations_used[String(control.theme_type_variation)] = true
	var hover := preview.get_node("Center/Panel/Margin/Columns/Buttons/Row1/Hover") as Button
	var normal := preview.get_node("Center/Panel/Margin/Columns/Buttons/Row1/Normal") as Button
	var disabled := preview.get_node("Center/Panel/Margin/Columns/Buttons/Row3/Disabled") as Button
	var forced_hover := hover.get_theme_stylebox("normal") as StyleBoxFlat
	var theme_hover := _theme.get_stylebox("hover", "Button") as StyleBoxFlat
	_check("The theme preview builds and shows every kind of styled control (buttons, toggles, option button, slider, line edit, tabs, scroll area, progress bar, separator) and the label variations",
			absent.is_empty() and variations_used.has("TitleLabel") and variations_used.has("ScoreLabel") and variations_used.has("HeaderLabel")
					and variations_used.has("DimLabel") and variations_used.has("BrightLabel"),
			"kinds not shown: %s, variations used: %d" % [absent, variations_used.size()])
	_check("Its Hover sample wears the theme's hover look while the Normal one keeps the resting look, and Disabled is disabled",
			forced_hover.bg_color == theme_hover.bg_color and (normal.get_theme_stylebox("normal") as StyleBoxFlat).bg_color != theme_hover.bg_color
					and disabled.disabled,
			"hover sample fill %s (theme hover %s), normal fill %s" % [
					forced_hover.bg_color, theme_hover.bg_color, (normal.get_theme_stylebox("normal") as StyleBoxFlat).bg_color])
	remove_child(preview)
	preview.queue_free()


## The console takes its look from the theme and scales with it.
func _test_console() -> void:
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	await get_tree().process_frame
	var panel := console.get_node("Panel") as PanelContainer
	var output := console.get_node("Panel/Margin/Box/Output") as Label
	var input := console.get_node("Panel/Margin/Box/Input") as LineEdit
	var base_size := output.get_theme_font_size("font_size")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	console.set_ui_scale(1.5)
	await get_tree().process_frame
	var scaled_size := output.get_theme_font_size("font_size")
	var scaled_input := input.get_theme_font_size("font_size")
	console.set_ui_scale(1.0)
	_check("The developer console is themed (a ConsolePanel with the accent edge, a themed input line, no overrides of its own), 16 px at 1.0 and 24 px at 1.5, its panel 344 → 516 px minimum height",
			panel.theme_type_variation == &"ConsolePanel" and style != null and style.border_color == _theme.get_color("accent", "Palette")
					and not output.has_theme_font_size_override("font_size") and not panel.has_theme_stylebox_override("panel")
					and base_size == 16 and scaled_size == 24 and scaled_input == 24 and panel.custom_minimum_size.y == 344.0
					and (input.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == _theme.get_stylebox("normal", "LineEdit").bg_color,
			"font %d → %d, input %d, panel minimum back at %.0f" % [base_size, scaled_size, scaled_input, panel.custom_minimum_size.y])
	remove_child(console)
	console.queue_free()


## The Tab scoreboard and its table take their look from the theme.
func _test_scoreboard() -> void:
	await _new_match()
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	Input.action_press("scoreboard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var table := board.get_node("Center/Panel/Margin/Content/Table") as ScoreboardTable
	var panel := board.get_node("Center/Panel") as PanelContainer
	var round_label := board.get_node("Center/Panel/Margin/Content/RoundLabel") as Label
	var yours := table.get_row(_player)
	var header := table.get_node("Team%d/Header" % Teams.viewer_team) as PanelContainer
	var enemy_header := table.get_node("Team%d/Header" % Teams.other(Teams.viewer_team)) as PanelContainer
	_check("The Tab scoreboard still builds its rows (3 + 3, your team first) and shows while Tab is held",
			board.visible and table.get_displayed(Teams.viewer_team).size() == 3 and table.get_displayed(Teams.other(Teams.viewer_team)).size() == 3
					and yours != null and round_label.text == "Round 1",
			"visible %s, rows %d + %d, header '%s'" % [
					board.visible, table.get_displayed(Teams.viewer_team).size(), table.get_displayed(Teams.other(Teams.viewer_team)).size(), round_label.text])
	_check("Its look comes from theme variations: an overlay panel, a dim round label, blue and red team headers, your row on the highlight band, 16 px rows",
			panel.theme_type_variation == &"OverlayPanel" and round_label.theme_type_variation == &"DimLabel"
					and header.theme_type_variation == &"TeamHeaderFriendly" and enemy_header.theme_type_variation == &"TeamHeaderEnemy"
					and yours.theme_type_variation == &"YouRowPanel" and (yours.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == ScoreboardTable.YOU_ROW_COLOR
					and (header.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Teams.color_for(Teams.viewer_team)
					and (enemy_header.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Teams.color_for(Teams.other(Teams.viewer_team))
					and (yours.find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size") == 16,
			"panel '%s', header '%s', your row '%s'" % [panel.theme_type_variation, header.theme_type_variation, yours.theme_type_variation])
	var overrides := _style_or_size_overrides(board)
	_check("Nothing in the scoreboard carries a stylebox or font-size override of its own (colors only), so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	board.set_ui_scale(1.5)
	await get_tree().process_frame
	var row_label := yours.find_children("*", "Label", true, false)[0] as Label
	var score := board.get_node("Center/Panel/Margin/Content/Score/YourScore") as Label
	var stat_width := (yours.find_children("*", "Label", true, false)[1] as Label).custom_minimum_size.x
	var separation := (table.get_node("Team0") as VBoxContainer).get_theme_constant("separation")
	_check("Scaled by 1.5 the scoreboard is exactly 1.5 times as big: panel 640 → 960 minimum width, rows 16 → 24 px, scores 32 → 48 px, number columns 96 → 144, the gap between rows 2 → 3",
			panel.custom_minimum_size.x == 960.0 and row_label.get_theme_font_size("font_size") == 24 and score.get_theme_font_size("font_size") == 48
					and stat_width == 144.0 and separation == 3,
			"panel %.0f, row font %d, score font %d, column %.0f, gap %d" % [
					panel.custom_minimum_size.x, row_label.get_theme_font_size("font_size"), score.get_theme_font_size("font_size"), stat_width, separation])
	board.set_ui_scale(1.0)
	Input.action_release("scoreboard")
	remove_child(board)
	board.queue_free()


## The match-end screen takes its look from the theme, builds its table and scales.
func _test_match_end_screen() -> void:
	await _new_match(1)
	var screen := MATCH_END_SCENE.instantiate() as MatchEndScreen
	add_child(screen)
	screen.set_round_manager(_rounds)
	# Scaled before the match is over: the table's rows are built afterwards and must come out scaled.
	screen.set_ui_scale(1.5)
	await _win_round(0)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var late_row := screen.get_node("Panel/Margin/Content/Table").get_node("Team0/%s" % _player.name).find_children("*", "Label", true, false)
	_check("Rows built after the screen was scaled are scaled too (font 24, number columns 144)",
			(late_row[0] as Label).get_theme_font_size("font_size") == 24 and (late_row[1] as Label).custom_minimum_size.x == 144.0,
			"font %d, column %.0f" % [(late_row[0] as Label).get_theme_font_size("font_size"), (late_row[1] as Label).custom_minimum_size.x])
	screen.set_ui_scale(1.0)
	await get_tree().process_frame
	var title := screen.get_node("Panel/Margin/Content/Title") as Label
	var panel := screen.get_node("Panel") as PanelContainer
	var table := screen.get_node("Panel/Margin/Content/Table") as ScoreboardTable
	var play_again := screen.get_node("Panel/Margin/Content/Buttons/PlayAgain") as Button
	var quit := screen.get_node("Panel/Margin/Content/Buttons/Quit") as Button
	_check("The match-end screen still shows 'Victory' and builds its table (3 + 3 rows), with 'Play again' focused",
			screen.visible and title.text == "Victory" and table.get_displayed(0).size() == 3 and table.get_displayed(1).size() == 3
					and play_again.has_focus(),
			"visible %s, title '%s', rows %d + %d, focus on Play again: %s" % [
					screen.visible, title.text, table.get_displayed(0).size(), table.get_displayed(1).size(), play_again.has_focus()])
	_check("Its look comes from theme variations: a modal panel with the accent frame, a 48 px title, 16 px buttons; the buttons are themed in every state",
			panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel"
					and title.get_theme_font_size("font_size") == 48 and play_again.get_theme_font_size("font_size") == 16
					and (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == _theme.get_color("accent", "Palette")
					and (quit.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left == 2
					and (quit.get_theme_stylebox("focus") as StyleBoxFlat).border_color == _theme.get_color("accent", "Palette"),
			"panel '%s', title %d px, button %d px" % [panel.theme_type_variation, title.get_theme_font_size("font_size"), play_again.get_theme_font_size("font_size")])
	var overrides := _style_or_size_overrides(screen)
	_check("Nothing in the match-end screen carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	screen.set_ui_scale(1.5)
	await get_tree().process_frame
	var row_label := table.get_row(_player).find_children("*", "Label", true, false)[0] as Label
	_check("Scaled by 1.5: panel 760 → 1140, title 48 → 72 px, buttons 16 → 24 px and 200 × 40 → 300 × 60, table rows 16 → 24 px",
			panel.custom_minimum_size.x == 1140.0 and title.get_theme_font_size("font_size") == 72
					and play_again.get_theme_font_size("font_size") == 24 and play_again.custom_minimum_size == Vector2(300, 60)
					and row_label.get_theme_font_size("font_size") == 24,
			"panel %.0f, title %d, button %d (%s), row %d" % [
					panel.custom_minimum_size.x, title.get_theme_font_size("font_size"), play_again.get_theme_font_size("font_size"),
					play_again.custom_minimum_size, row_label.get_theme_font_size("font_size")])
	screen.set_ui_scale(1.0)
	await get_tree().process_frame
	_check("Back at 1.0 everything returns to its design size (panel 760, title 48, row 16)",
			panel.custom_minimum_size.x == 760.0 and title.get_theme_font_size("font_size") == 48
					and (table.get_row(_player).find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size") == 16,
			"panel %.0f, title %d" % [panel.custom_minimum_size.x, title.get_theme_font_size("font_size")])
	remove_child(screen)
	screen.queue_free()


## Starts a match first to [param rounds_to_win] on a fresh copy of the test map
## (an earlier map is removed), with short timings, and waits until everyone has joined.
func _new_match(rounds_to_win: int = 5) -> void:
	if _map != null:
		remove_child(_map)
		_map.queue_free()
	_map = MAP_SCENE.instantiate()
	add_child(_map)
	_player = _map.get_node("Player")
	_silence(_player)
	var settings := MatchSettings.new()
	settings.freeze_time = 0.3
	settings.round_time = 30.0
	settings.round_end_time = 0.3
	settings.rounds_to_win = rounds_to_win
	_rounds = RoundManager.new()
	_rounds.settings = settings
	_rounds.rng.seed = 7
	_map.add_child(_rounds)
	# The match starts at the end of the first frame.
	for i in 3:
		await get_tree().physics_frame
	for character in _rounds.get_participants():
		_silence(character)
		if character != _player:
			(character.get_node("BotController") as BotController).hold_position = true


## Plays a round to its end: waits for the live phase, then [param team] kills
## the whole other team, and waits for the round-end pause.
func _win_round(team: int) -> void:
	await _wait_for_phase(RoundManager.Phase.LIVE)
	var killer := _rounds.get_members(team)[0]
	for victim in _rounds.get_members(Teams.other(team)):
		victim.take_damage(500.0, Hitbox.Zone.CHEST, killer)
	await _wait_for_phase(RoundManager.Phase.ROUND_END)


func _wait_for_phase(phase: RoundManager.Phase) -> void:
	var ticks := 0
	while _rounds.phase != phase and ticks < 128 * 10:
		await get_tree().physics_frame
		ticks += 1


## Headless runs have no audio device; sounds that never finish "playing" would
## be reported as leaks when Godot exits.
func _silence(character: Character) -> void:
	character.footstep_sound = null
	if character.weapon != null:
		var data := character.weapon.data.duplicate() as WeaponData
		data.shot_sound = null
		data.dry_fire_sound = null
		data.reload_sound = null
		character.weapon.data = data


## Puts [param node] in the tree below [param parent], using theme type variation [param variation].
func _variation_node(node: Control, variation: String, parent: Control) -> Control:
	node.theme_type_variation = StringName(variation)
	parent.add_child(node)
	return node


## A small menu built the way the real ones are: a panel with a padded column of
## labels and controls, plus a few one-off overrides.
func _make_menu() -> Control:
	# A container, so the panel follows its minimum size when it changes.
	var menu := CenterContainer.new()
	menu.name = "Menu"
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(400, 0)
	menu.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.theme_type_variation = &"PanelMargin"
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.theme_type_variation = &"ContentBox"
	margin.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.text = "Title"
	box.add_child(title)
	var body := Label.new()
	body.name = "Body"
	body.text = "Body text"
	box.add_child(body)
	var button := Button.new()
	button.name = "Button"
	button.custom_minimum_size = Vector2(200, 40)
	button.text = "Go"
	box.add_child(button)
	box.add_child(HSlider.new())
	var option := OptionButton.new()
	option.name = "Option"
	option.add_item("1280 x 720")
	box.add_child(option)
	# One-offs: a row with its own spacing and a label with its own size.
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var custom := Label.new()
	custom.name = "Custom"
	custom.add_theme_font_size_override("font_size", 20)
	custom.text = "One-off"
	row.add_child(custom)
	return menu


## The sizes of a [method _make_menu] menu that scaling must change, by name.
func _menu_sizes(menu: Control) -> Dictionary:
	var body := menu.get_node("Panel/Margin/Box/Body") as Label
	var title := menu.get_node("Panel/Margin/Box/Title") as Label
	var margin := menu.get_node("Panel/Margin") as MarginContainer
	var button := menu.get_node("Panel/Margin/Box/Button") as Button
	var row := menu.get_node("Panel/Margin/Box/Row") as HBoxContainer
	var custom := menu.get_node("Panel/Margin/Box/Row/Custom") as Label
	var option := menu.get_node("Panel/Margin/Box/Option") as OptionButton
	var panel := menu.get_node("Panel") as PanelContainer
	return {
		"body": body.get_theme_font_size("font_size"),
		"title": title.get_theme_font_size("font_size"),
		"margin": margin.get_theme_constant("margin_left"),
		"button_min": button.custom_minimum_size,
		"override_separation": row.get_theme_constant("separation"),
		"override_font": custom.get_theme_font_size("font_size"),
		"popup": option.get_popup().get_theme_font_size("font_size"),
		"panel_border": (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left,
	}


## Names of the controls below [param root] that carry their own stylebox or
## font-size override: in a themed menu the look comes from the theme.
func _style_or_size_overrides(root: Node) -> Array[String]:
	var found: Array[String] = []
	for control: Control in root.find_children("*", "Control", true, false):
		if control.has_theme_stylebox_override("panel") or control.has_theme_stylebox_override("normal") \
				or control.has_theme_font_size_override("font_size"):
			found.append(String(control.name))
	return found


## Every distinct color in [param image].
func _image_colors(image: Image) -> Array[Color]:
	var colors: Array[Color] = []
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if not colors.has(color):
				colors.append(color)
	return colors


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
