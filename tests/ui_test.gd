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
## their look from the theme, still build their rows and scale with it. The
## settings menu (task 10, D-059) adds checks for [MenuState], the tabs and
## controls and how they follow [Settings], the crosshair preview, rebinding
## (listening, Esc, the click that started it, the clash rule, Backspace, the
## console key, reset), closing, the player ignoring input while a menu is
## open, scaling by 1.5, and the console's `settings` command, `help` and
## scrollback. The main menu and match setup (task 11, D-064) add checks for
## the menu's buttons and its background without a player, the camera flight,
## Esc, match setup's defaults, controls, stored choices and map list, the
## launch description and what main.gd builds from it, the match-end screen's
## "Main menu" button and the way back to the menu. The pause menu (task 12)
## adds its own checks here.
## The shared [Settings] instance never saves in this test (nothing calls
## `load_from_disk()`) and is put back to its defaults after each group; the
## last check makes sure the real `user://settings.cfg` wasn't touched. Quits
## with the number of failed checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
const SCOREBOARD_SCENE := preload("res://ui/scoreboard.tscn")
const MATCH_END_SCENE := preload("res://ui/match_end_screen.tscn")
const CONSOLE_SCENE := preload("res://ui/dev_console.tscn")
const PREVIEW_SCENE := preload("res://ui/theme_preview.tscn")
const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const MAIN_MENU_SCENE := preload("res://ui/main_menu.tscn")
const MATCH_SETUP_SCENE := preload("res://ui/match_setup.tscn")
const THEME_PATH := "res://ui/chiip_theme.tres"
const FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"
## The file the match setup and scene-change checks store settings in instead of the real one.
const TEMP_PATH := "user://test_ui_settings.cfg"
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
## The MD5 of the real settings file when the test started ("" if there was none).
var _real_file_md5: String = ""


func _ready() -> void:
	_real_file_md5 = FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
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
	_test_menu_state()
	await _test_settings_menu_building()
	await _test_settings_menu_controls()
	await _test_crosshair_preview()
	await _test_rebinding()
	await _test_menu_closing()
	await _test_menu_blocks_the_player()
	await _test_menu_scaling()
	await _test_console_and_menus()
	await _test_main_menu()
	await _test_match_setup()
	await _test_game_launch()
	await _test_scene_flow()
	_test_real_file_untouched()
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
	# A menu on top of the game (the settings menu, the pause menu) takes the keyboard: no scoreboard then.
	var menu_stand_in := Node.new()
	MenuState.open(menu_stand_in)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var with_menu := board.visible
	MenuState.close(menu_stand_in)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("Tab is ignored while any menu is open (MenuState), and counts again when it closes",
			not with_menu and board.visible, "visible with a menu open: %s, after closing it: %s" % [with_menu, board.visible])
	menu_stand_in.free()
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
	var main_menu_button := screen.get_node("Panel/Margin/Content/Buttons/MainMenu") as Button
	_check("The match-end screen still shows 'Victory' and builds its table (3 + 3 rows), with 'Play again' focused",
			screen.visible and title.text == "Victory" and table.get_displayed(0).size() == 3 and table.get_displayed(1).size() == 3
					and play_again.has_focus(),
			"visible %s, title '%s', rows %d + %d, focus on Play again: %s" % [
					screen.visible, title.text, table.get_displayed(0).size(), table.get_displayed(1).size(), play_again.has_focus()])
	var menu_presses: Array[int] = [0]
	screen.main_menu_pressed.connect(func() -> void: menu_presses[0] += 1)
	main_menu_button.pressed.emit()
	_check("The second button says 'Main menu' (it was Quit) and reports `main_menu_pressed` when clicked; 'Play again' keeps its name",
			main_menu_button.text == "Main menu" and play_again.text == "Play again" and menu_presses[0] == 1 and not screen.has_signal("quit_pressed"),
			"texts '%s' and '%s', presses %d" % [play_again.text, main_menu_button.text, menu_presses[0]])
	_check("Its look comes from theme variations: a modal panel with the accent frame, a 48 px title, 16 px buttons; the buttons are themed in every state",
			panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel"
					and title.get_theme_font_size("font_size") == 48 and play_again.get_theme_font_size("font_size") == 16
					and (panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == _theme.get_color("accent", "Palette")
					and (main_menu_button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left == 2
					and (main_menu_button.get_theme_stylebox("focus") as StyleBoxFlat).border_color == _theme.get_color("accent", "Palette"),
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


# --- The settings menu (D-059) ---


## MenuState: the shared list of open menus.
func _test_menu_state() -> void:
	MenuState.reset()
	var first := Node.new()
	var second := Node.new()
	var empty_at_first := not MenuState.is_any_open() and not MenuState.blocks_gameplay()
	MenuState.open(first)
	MenuState.open(second)
	var both_open := MenuState.is_open(first) and MenuState.is_open(second) and MenuState.is_top(second) \
			and not MenuState.is_top(first) and MenuState.blocks_gameplay()
	MenuState.close(second)
	var first_on_top := MenuState.is_top(first) and MenuState.is_any_open()
	MenuState.close(second)
	var still_one := MenuState.is_open(first)
	MenuState.close(first)
	var empty_again := not MenuState.is_any_open() and not MenuState.blocks_gameplay()
	_check("MenuState keeps a list of open menus: the last one opened is on top, closing one leaves the others, closing a menu that isn't open does nothing, and with none left nothing is blocked",
			empty_at_first and both_open and first_on_top and still_one and empty_again,
			"empty %s, both %s, first on top %s, still one %s, empty again %s" % [empty_at_first, both_open, first_on_top, still_one, empty_again])
	MenuState.open(first)
	MenuState.open(second)
	MenuState.open(first)
	var reordered := MenuState.is_top(first)
	second.free()
	var after_free := MenuState.is_any_open() and MenuState.is_top(first)
	first.free()
	var all_freed := not MenuState.is_any_open()
	DevConsole.is_open = true
	var console_flag := MenuState.blocks_gameplay() and not MenuState.is_any_open()
	DevConsole.is_open = false
	_check("Opening a menu again brings it to the top, a menu freed while open drops out by itself, and the console flag alone also blocks the game",
			reordered and after_free and all_freed and console_flag,
			"reordered %s, after one freed %s, all freed %s, console flag %s" % [reordered, after_free, all_freed, console_flag])
	MenuState.reset()


## The menu builds its five tabs and a control for every setting and every key.
func _test_settings_menu_building() -> void:
	var menu := await _new_menu()
	var uncovered: Array[StringName] = []
	for key: StringName in Settings.SCHEMA:
		var has_control := menu.get_slider(key) != null or menu.get_check(key) != null or menu.get_option(key) != null
		# The [match] section is match setup's, not the settings menu's.
		if not has_control and key != &"crosshair_color" and Settings.SCHEMA[key]["section"] != "match":
			uncovered.append(key)
	var panel := menu.get_node("Panel") as PanelContainer
	var title := menu.get_node("Panel/Margin/Content/Title") as Label
	_check("The settings menu is hidden until opened and builds the tabs Game, Video, Audio, Crosshair and Controls, on a themed panel",
			not menu.visible and menu.get_tab_names() == ["Game", "Video", "Audio", "Crosshair", "Controls"]
					and panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel" and title.text == "Settings",
			"visible %s, tabs %s" % [menu.visible, menu.get_tab_names()])
	_check("Every setting has a control: sliders with number fields (sensitivity, FOV, volumes, crosshair sizes and opacity), check boxes, option buttons for the frame limit and pixel resolution, and color swatches with a hex field",
			uncovered.is_empty() and menu.get_swatches().size() == SettingsMenu.CROSSHAIR_COLORS.size() and menu.get_hex_field() != null
					and menu.get_slider(&"crosshair_opacity") != null and menu.get_option(&"fps_cap").item_count == Settings.FPS_CAPS.size()
					and menu.get_option(&"pixel_height").item_count == Settings.PIXEL_HEIGHTS.size(),
			"settings without a control: %s, %d swatches, %d frame limits, %d resolutions" % [
					uncovered, menu.get_swatches().size(), menu.get_option(&"fps_cap").item_count, menu.get_option(&"pixel_height").item_count])
	var unnamed: Array[StringName] = []
	var wrong_text: Array[String] = []
	for action: StringName in Settings.BINDABLE_ACTIONS:
		var label := menu.get_binding_button(action, 0).get_parent().get_child(0) as Label
		if not SettingsMenu.ACTION_NAMES.has(action) or label.text != SettingsMenu.ACTION_NAMES[action] or label.text.contains("_"):
			unnamed.append(action)
		for slot in Settings.BINDING_SLOTS:
			if menu.get_binding_button(action, slot) == null:
				wrong_text.append("%s/%d missing" % [action, slot])
	var forward := [menu.get_binding_button(&"move_forward", 0).text, menu.get_binding_button(&"move_forward", 1).text]
	var jump := [menu.get_binding_button(&"jump", 0).text, menu.get_binding_button(&"jump", 1).text]
	var shoot := menu.get_binding_button(&"shoot", 0).text
	var console_key := menu.get_binding_button(&"toggle_console", 0).text
	_check("The Controls tab has a row per bindable action (all 13) with a readable name and two slots that show the keys: W and an empty slot, Space and Wheel Down, Left Mouse, ` for the console",
			unnamed.is_empty() and wrong_text.is_empty() and forward == ["W", SettingsMenu.EMPTY_SLOT_TEXT] and jump == ["Space", "Wheel Down"]
					and shoot == "Left Mouse" and console_key == "`",
			"unnamed %s, forward %s, jump %s, shoot '%s', console '%s'" % [unnamed, forward, jump, shoot, console_key])
	_free_menu(menu)


## Controls write to Settings, and Settings changes show in the controls.
func _test_settings_menu_controls() -> void:
	var settings := Settings.get_instance()
	var menu := await _new_menu()
	var slider := menu.get_slider(&"sensitivity")
	var field := menu.get_field(&"sensitivity")
	slider.value = 2.5
	var by_slider := is_equal_approx(settings.sensitivity, 2.5) and field.text == "2.50"
	field.text_submitted.emit("1,25")
	var by_field := is_equal_approx(settings.sensitivity, 1.25) and is_equal_approx(slider.value, 1.25) and field.text == "1.25"
	field.text_submitted.emit("99")
	var clamped := settings.sensitivity == 10.0 and slider.value == 10.0 and field.text == "10.00"
	field.text_submitted.emit("fast")
	var refused := settings.sensitivity == 10.0 and field.text == "10.00"
	_check("Sensitivity: the slider and the number field write to Settings and agree (2.50 from the slider, 1.25 typed with a comma, 99 clamped to 10.00, text that is no number put back)",
			by_slider and by_field and clamped and refused,
			"slider %s, field %s, clamped %s, refused %s" % [by_slider, by_field, clamped, refused])
	var invert := menu.get_check(&"invert_y")
	invert.button_pressed = true
	var invert_on := settings.invert_y
	var fps := menu.get_option(&"fps_cap")
	fps.item_selected.emit(fps.get_item_index(144))
	var fps_144 := settings.fps_cap == 144 and Engine.max_fps == 144 and fps.get_item_text(fps.selected) == "144 fps"
	fps.item_selected.emit(fps.get_item_index(0))
	var fps_unlimited := settings.fps_cap == 0 and fps.get_item_text(fps.selected) == "Unlimited"
	var pixels := menu.get_option(&"pixel_height")
	pixels.item_selected.emit(pixels.get_item_index(360))
	var pixels_360 := settings.pixel_height == 360 and pixels.get_item_text(pixels.selected) == "360 lines"
	_check("A check box and the option buttons write to Settings: invert Y, a frame limit of 144 (which reaches the engine) and back to unlimited, 360 lines",
			invert_on and fps_144 and fps_unlimited and pixels_360,
			"invert %s, 144 %s, unlimited %s, 360 lines %s" % [invert_on, fps_144, fps_unlimited, pixels_360])
	var volume := menu.get_slider(&"master_volume")
	var volume_field := menu.get_field(&"master_volume")
	volume.value = 0.5
	var half := is_equal_approx(settings.master_volume, 0.5) and volume_field.text == "50%"
	volume_field.text_submitted.emit("25%")
	var quarter := is_equal_approx(settings.master_volume, 0.25) and is_equal_approx(volume.value, 0.25) and volume_field.text == "25%" \
			and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Settings.BUS_MASTER)), linear_to_db(0.25))
	_check("A volume slider is a percentage: 0.5 reads 50%, typing 25% sets 0.25 on the slider, the setting and the audio bus",
			half and quarter, "half %s, quarter %s, master %.2f" % [half, quarter, settings.master_volume])
	settings.master_volume = 0.29
	var rounded := volume_field.text == "29%"
	settings.crosshair_color = Color(0.2, 1.0, 0.2, 0.9)
	var opacity_field := menu.get_field(&"crosshair_opacity")
	rounded = rounded and opacity_field.text == "90%"
	_check("A whole-number field rounds instead of cutting the decimals off: a volume of 0.29 reads 29% (not 28%) and an opacity of 0.9 reads 90%",
			rounded, "volume '%s', opacity '%s'" % [volume_field.text, opacity_field.text])
	settings.reset_to_defaults()
	# The other direction: the settings change, the controls follow.
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	settings.sensitivity = 2.25
	settings.invert_y = true
	settings.fps_cap = 75
	var custom_text := fps.get_item_text(fps.selected)
	var custom_items := fps.item_count
	settings.fps_cap = 60
	settings.pixel_height = 270
	settings.master_volume = 0.3
	settings.crosshair_color = Color(1.0, 0.2, 0.2, 0.5)
	var hex := menu.get_hex_field()
	_check("A change to Settings updates the controls: sensitivity (slider and field), invert Y, a hand-set frame limit of 75 shown as '75 fps (custom)' and gone again, 270 lines, 30%, and the crosshair color (swatch, hex code and opacity)",
			is_equal_approx(slider.value, 2.25) and field.text == "2.25" and invert.button_pressed
					and custom_text == "75 fps (custom)" and custom_items == Settings.FPS_CAPS.size() + 1
					and fps.get_item_text(fps.selected) == "60 fps" and fps.item_count == Settings.FPS_CAPS.size()
					and pixels.get_item_text(pixels.selected) == "270 lines" and volume_field.text == "30%"
					and menu.get_swatches()[3].button_pressed and not menu.get_swatches()[0].button_pressed and hex.text == "#FF3333"
					and menu.get_field(&"crosshair_opacity").text == "50%" and is_equal_approx(menu.get_slider(&"crosshair_opacity").value, 0.5),
			"sensitivity %s / '%s', frame limit '%s' (%d items), hex '%s'" % [slider.value, field.text, custom_text, custom_items, hex.text])
	console.run("sensitivity 3")
	_check("A console command changes the sensitivity while the menu exists and the slider and field move with it",
			is_equal_approx(slider.value, 3.0) and field.text == "3.00", "slider %s, field '%s'" % [slider.value, field.text])
	# Opening the menu reads everything again.
	slider.set_value_no_signal(9.0)
	field.text = "junk"
	invert.set_pressed_no_signal(false)
	menu.open()
	_check("Opening the menu reads every value from Settings again (a slider, a field and a check box that had drifted are right)",
			is_equal_approx(slider.value, 3.0) and field.text == "3.00" and invert.button_pressed,
			"slider %s, field '%s', invert %s" % [slider.value, field.text, invert.button_pressed])
	menu.close()
	console.queue_free()
	_free_menu(menu)
	settings.reset_to_defaults()


## The live crosshair preview is a real Crosshair that follows the settings.
func _test_crosshair_preview() -> void:
	var settings := Settings.get_instance()
	var menu := await _new_menu()
	var preview := menu.get_preview()
	var sample := preview.get_parent()
	var patches: Array[Color] = []
	for child in sample.get_children():
		if child is ColorRect:
			patches.append((child as ColorRect).color)
	var contrast := patches.size() == 2 and absf(patches[0].get_luminance() - patches[1].get_luminance()) > 0.5
	_check("The preview is a real Crosshair control on a sample with a dark and a light patch, showing the current style (green, 7 px lines, gap 4, thickness 2, outlined)",
			preview.get_script() == load("res://ui/crosshair.gd") and contrast and preview.color.is_equal_approx(Color(0.2, 1.0, 0.2))
					and preview.length == 7.0 and preview.gap == 4.0 and preview.thickness == 2.0 and preview.outline and not preview.dot and not preview.dynamic,
			"%d patches, color %s, length %s, gap %s" % [patches.size(), preview.color, preview.length, preview.gap])
	menu.get_swatches()[3].pressed.emit()
	var red := preview.color.is_equal_approx(Color(1.0, 0.2, 0.2)) and settings.crosshair_color.is_equal_approx(Color(1.0, 0.2, 0.2))
	menu.get_slider(&"crosshair_opacity").value = 0.5
	var faded := is_equal_approx(preview.color.a, 0.5) and preview.color.is_equal_approx(Color(1.0, 0.2, 0.2, 0.5))
	menu.get_hex_field().text_submitted.emit("#336699")
	var typed := preview.color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.5)) and menu.get_hex_field().text == "#336699" \
			and not menu.get_swatches().any(func(swatch: Button) -> bool: return swatch.button_pressed)
	menu.get_hex_field().text_submitted.emit("not a color")
	var kept := preview.color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.5))
	_check("The preview follows the color: a swatch picks red, the opacity slider fades it to 50%, a typed #336699 keeps the opacity (and lights no swatch), a bad code changes nothing",
			red and faded and typed and kept, "red %s, faded %s, typed %s, kept %s" % [red, faded, typed, kept])
	menu.get_slider(&"crosshair_length").value = 12.0
	menu.get_slider(&"crosshair_gap").value = 9.0
	menu.get_slider(&"crosshair_thickness").value = 4.0
	menu.get_check(&"crosshair_outline").button_pressed = false
	menu.get_check(&"crosshair_dot").button_pressed = true
	menu.get_check(&"crosshair_dynamic").button_pressed = true
	_check("It follows the sizes and styles: length 12, gap 9, thickness 4, no outline, a dot, dynamic",
			preview.length == 12.0 and preview.gap == 9.0 and preview.thickness == 4.0 and not preview.outline and preview.dot and preview.dynamic,
			"length %s, gap %s, thickness %s, outline %s, dot %s, dynamic %s" % [preview.length, preview.gap, preview.thickness, preview.outline, preview.dot, preview.dynamic])
	# Dynamic mode shows the gap opening while the menu is up.
	menu.open()
	for i in 20:
		await get_tree().process_frame
	var breathing := preview.spread_degrees > 0.0 and preview._spread_in_pixels() > 0.0
	menu.close()
	_check("In dynamic mode the preview's gap opens by itself while the menu is open (its spread comes from the menu's own pulse, as it has no camera)",
			breathing, "spread %.3f°, %.1f px" % [preview.spread_degrees, preview._spread_in_pixels()])
	# "Reset tab" puts back only the tab it is on.
	menu.open()
	settings.sensitivity = 4.0
	menu.get_tabs().current_tab = menu.get_tab_names().find("Crosshair")
	menu.get_reset_button().pressed.emit()
	var crosshair_back := preview.color.is_equal_approx(Color(0.2, 1.0, 0.2)) and preview.length == 7.0 and preview.outline and not preview.dot and not preview.dynamic
	_check("'Reset tab to defaults' on the Crosshair tab puts the whole crosshair back (the preview too) and leaves the other tabs alone (sensitivity stays 4.0)",
			crosshair_back and settings.sensitivity == 4.0 and menu.get_check(&"crosshair_dot").button_pressed == false,
			"crosshair back %s, sensitivity %s" % [crosshair_back, settings.sensitivity])
	menu.close()
	_free_menu(menu)
	settings.reset_to_defaults()


## Click a slot, press a key: binding, cancelling, clearing, clashes.
func _test_rebinding() -> void:
	var settings := Settings.get_instance()
	var menu := await _new_menu()
	menu.open()
	var slot := menu.get_binding_button(&"reload", 1)
	slot.pressed.emit()
	_check("Clicking a slot makes it say 'Press a key…' (lit), and the menu waits: MenuState says it is capturing input",
			menu.is_listening() and slot.text == SettingsMenu.LISTENING_TEXT and slot.button_pressed and MenuState.capturing_input,
			"listening %s, text '%s', capturing %s" % [menu.is_listening(), slot.text, MenuState.capturing_input])
	_send(_key_event(KEY_T))
	_send(_key_event(KEY_T, false))
	var reload_events := InputMap.action_get_events(&"reload")
	var reload_keys: Array[Key] = []
	for event in reload_events:
		reload_keys.append((event as InputEventKey).physical_keycode)
	_check("The next key press is bound: reload now answers to R and T (in the settings and in the InputMap, for all devices), the slot shows T and the menu stops waiting",
			not menu.is_listening() and not MenuState.capturing_input and slot.text == "T" and not slot.button_pressed
					and settings.get_binding(&"reload", 1) != null and reload_keys == [KEY_R, KEY_T] and (reload_events[1] as InputEventKey).device == -1
					and menu.get_notice() == "Reload: T.",
			"listening %s, slot '%s', keys %s, notice '%s'" % [menu.is_listening(), slot.text, reload_keys, menu.get_notice()])
	# Esc cancels, and does not close the menu.
	menu.get_binding_button(&"crouch", 1).pressed.emit()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc cancels the waiting without binding anything, and the menu stays open",
			not menu.is_listening() and menu.visible and settings.get_binding(&"crouch", 1) == null
					and menu.get_binding_button(&"crouch", 1).text == SettingsMenu.EMPTY_SLOT_TEXT and not MenuState.capturing_input,
			"listening %s, menu open %s, slot '%s'" % [menu.is_listening(), menu.visible, menu.get_binding_button(&"crouch", 1).text])
	# The click that started it is not the binding; the next one is.
	var shoot_slot := menu.get_binding_button(&"aim", 1)
	shoot_slot.pressed.emit()
	_send(_mouse_event(MOUSE_BUTTON_LEFT))
	var ignored := menu.is_listening() and settings.get_binding(&"aim", 1) == null
	await get_tree().process_frame
	_send(_mouse_event(MOUSE_BUTTON_MIDDLE))
	_send(_mouse_event(MOUSE_BUTTON_MIDDLE, false))
	var bound := not menu.is_listening() and settings.get_binding(&"aim", 1) is InputEventMouseButton \
			and (settings.get_binding(&"aim", 1) as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE and shoot_slot.text == "Middle Mouse"
	_check("A mouse press in the frame that started the waiting is the click on the slot itself and is ignored; the next click binds (middle mouse, shown as 'Middle Mouse')",
			ignored and bound, "ignored the first press %s, bound the next %s, slot '%s'" % [ignored, bound, shoot_slot.text])
	# The clash rule: the other action loses the key.
	var forward := menu.get_binding_button(&"move_forward", 0)
	var scoreboard_slot := menu.get_binding_button(&"scoreboard", 1)
	scoreboard_slot.pressed.emit()
	_send(_key_event(KEY_W))
	_send(_key_event(KEY_W, false))
	var forward_events := InputMap.action_get_events(&"move_forward")
	_check("A key belongs to one action: binding W to the scoreboard takes it from 'Move forward' (its slot shows —, its InputMap entry is gone) and a line says so",
			settings.get_binding(&"scoreboard", 1) != null and settings.get_binding(&"move_forward", 0) == null
					and forward.text == SettingsMenu.EMPTY_SLOT_TEXT and forward_events.is_empty() and scoreboard_slot.text == "W"
					and menu.get_notice() == "Scoreboard (hold): W. Move forward no longer has it.",
			"forward slot '%s', %d event(s), notice '%s'" % [forward.text, forward_events.size(), menu.get_notice()])
	# Binding a key to the other slot of the same action moves it.
	var jump_secondary := menu.get_binding_button(&"jump", 1)
	jump_secondary.pressed.emit()
	_send(_key_event(KEY_SPACE))
	_send(_key_event(KEY_SPACE, false))
	_check("Binding Space to jump's second slot moves it there: the first slot is empty again and nothing else is said to have lost it",
			jump_secondary.text == "Space" and menu.get_binding_button(&"jump", 0).text == SettingsMenu.EMPTY_SLOT_TEXT
					and InputMap.action_get_events(&"jump").size() == 1 and menu.get_notice() == "Jump: Space.",
			"slots '%s' / '%s', notice '%s'" % [menu.get_binding_button(&"jump", 0).text, jump_secondary.text, menu.get_notice()])
	# Backspace clears a slot.
	jump_secondary.pressed.emit()
	_send(_key_event(KEY_BACKSPACE))
	_send(_key_event(KEY_BACKSPACE, false))
	_check("Backspace clears the waiting slot (jump has no keys now) instead of binding Backspace",
			settings.get_binding(&"jump", 1) == null and jump_secondary.text == SettingsMenu.EMPTY_SLOT_TEXT
					and InputMap.action_get_events(&"jump").is_empty() and not menu.is_listening(),
			"slot '%s', %d event(s)" % [jump_secondary.text, InputMap.action_get_events(&"jump").size()])
	# While waiting, the console key is a key like any other.
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	var wheel_slot := menu.get_binding_button(&"walk", 1)
	wheel_slot.pressed.emit()
	_send(_key_event(KEY_QUOTELEFT))
	_send(_key_event(KEY_QUOTELEFT, false))
	var console_stayed_closed := not DevConsole.is_open and not MenuState.is_open(console)
	_check("While a slot waits, the console key doesn't open the console: it becomes the binding (and the console loses it)",
			console_stayed_closed and wheel_slot.text == "`" and menu.get_binding_button(&"toggle_console", 0).text == SettingsMenu.EMPTY_SLOT_TEXT
					and menu.get_notice() == "Walk (silent): `. Console no longer has it.",
			"console open %s, slot '%s', console slot '%s', notice '%s'" % [DevConsole.is_open, wheel_slot.text,
					menu.get_binding_button(&"toggle_console", 0).text, menu.get_notice()])
	# The tab's reset button puts every key back.
	menu.get_tabs().current_tab = menu.get_tab_names().find("Controls")
	menu.get_reset_button().pressed.emit()
	var back := true
	for action: StringName in Settings.BINDABLE_ACTIONS:
		var texts: Array[String] = []
		for index in Settings.BINDING_SLOTS:
			texts.append(Settings.binding_text(settings.get_binding(action, index)))
		back = back and menu.get_binding_button(action, 0).text == (texts[0] if texts[0] != "" else SettingsMenu.EMPTY_SLOT_TEXT)
	_check("'Reset tab to defaults' on the Controls tab puts every key back (reload is R again, W moves forward, jump has Space and Wheel Down, ` opens the console)",
			back and InputMap.action_get_events(&"reload").size() == 1 and menu.get_binding_button(&"move_forward", 0).text == "W"
					and menu.get_binding_button(&"jump", 1).text == "Wheel Down" and menu.get_binding_button(&"toggle_console", 0).text == "`"
					and menu.get_notice() == "Keys are back to their defaults.",
			"slots match the settings: %s, reload %d event(s), notice '%s'" % [back, InputMap.action_get_events(&"reload").size(), menu.get_notice()])
	# A change from outside shows in the slots.
	settings.set_binding(&"reload", _key_event(KEY_G), 1)
	var outside := menu.get_binding_button(&"reload", 1).text == "G"
	settings.reset_to_defaults()
	_check("A binding changed from outside the menu (settings, or settings_reset in the console) shows in the slots at once",
			outside and menu.get_binding_button(&"reload", 1).text == SettingsMenu.EMPTY_SLOT_TEXT,
			"slot showed '%s' after the change" % ["G" if outside else "something else"])
	console.queue_free()
	menu.close()
	_free_menu(menu)


## Esc and Back close the menu; the menu on top is the only one that reacts.
func _test_menu_closing() -> void:
	var menu := await _new_menu()
	var closes: Array[int] = [0]
	menu.closed.connect(func() -> void: closes[0] += 1)
	menu.open()
	var opened := menu.visible and MenuState.is_top(menu) and MenuState.blocks_gameplay()
	menu.get_back_button().pressed.emit()
	var by_back := not menu.visible and not MenuState.is_any_open() and closes[0] == 1
	menu.open()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var by_esc := not menu.visible and not MenuState.is_any_open() and closes[0] == 2
	menu.close()
	_check("Opening the menu puts it on top of MenuState; Back and Esc close it, emit `closed` once each and leave nothing open (closing a closed menu does nothing)",
			opened and by_back and by_esc and closes[0] == 2, "opened %s, Back %s, Esc %s, closed %d times" % [opened, by_back, by_esc, closes[0]])
	# A menu that is removed while it is open (or waiting for a key) lets go of everything.
	var doomed := await _new_menu()
	doomed.open()
	doomed.start_listening(&"jump", 0)
	var registered := MenuState.is_open(doomed) and MenuState.capturing_input
	remove_child(doomed)
	doomed.queue_free()
	_check("A menu removed while it is open, or waiting for a key, lets go: nothing stays open and nothing keeps capturing keys",
			registered and not MenuState.is_any_open() and not MenuState.capturing_input,
			"registered %s, still open %s, still capturing %s" % [registered, MenuState.is_any_open(), MenuState.capturing_input])
	# With the console on top, Esc belongs to the console.
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	menu.open()
	console.set_open(true)
	var console_on_top := MenuState.is_top(console) and not MenuState.is_top(menu)
	# Whatever the order of the two in the tree, the menu itself leaves Esc to the console.
	menu._input(_key_event(KEY_ESCAPE))
	var menu_ignored := menu.visible
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var menu_stayed := menu_ignored and menu.visible and not DevConsole.is_open
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Over an open menu the console is on top: Esc closes the console first (the menu stays), the next Esc closes the menu",
			console_on_top and menu_stayed and not menu.visible and not DevConsole.is_open and not MenuState.is_any_open(),
			"console on top %s, menu stayed %s, menu open now %s" % [console_on_top, menu_stayed, menu.visible])
	console.queue_free()
	menu.close()
	_free_menu(menu)


## While a menu is open the player stands still, can't shoot and the scoreboard stays away.
func _test_menu_blocks_the_player() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	var player := map.get_node("Player") as Character
	_silence(player)
	var controller := player.get_node("PlayerController") as PlayerController
	await get_tree().process_frame
	var menu := await _new_menu()
	Input.action_press("move_forward")
	Input.action_press("shoot")
	controller._unhandled_input(_action_event("jump"))
	var free_input := controller.get_input(0.0)
	# A jump and a reload pressed just before the menu opens, not yet used by a command.
	controller._unhandled_input(_action_event("jump"))
	controller._unhandled_input(_action_event("reload"))
	menu.open()
	await get_tree().process_frame
	var blocked_input := controller.get_input(0.0)
	menu.close()
	var just_closed := controller.get_input(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_input := controller.get_input(0.0)
	_check("Without a menu the controller turns keys into a command (forward, shoot, jump); with the settings menu open the same keys give no movement, no shot and no jump or reload",
			free_input.move.y < 0.0 and free_input.shoot and free_input.jump
					and blocked_input.move == Vector2.ZERO and not blocked_input.shoot and not blocked_input.jump and not blocked_input.reload,
			"free: move %s, shoot %s, jump %s; menu open: move %s, shoot %s, jump %s, reload %s" % [
					free_input.move, free_input.shoot, free_input.jump, blocked_input.move, blocked_input.shoot, blocked_input.jump, blocked_input.reload])
	_check("When the menu closes, a jump pressed while it was open doesn't happen afterwards, and a fire button still held (the click that closed it) doesn't shoot until it is let go",
			not just_closed.jump and not just_closed.reload and not after_input.jump and after_input.shoot == false and after_input.move.y < 0.0,
			"just after: jump %s, reload %s; a moment later: shoot %s, move %s" % [just_closed.jump, just_closed.reload, after_input.shoot, after_input.move])
	Input.action_release("move_forward")
	Input.action_release("shoot")
	# The console counts as a menu too, with the same effect.
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	Input.action_press("move_forward")
	console.set_open(true)
	var with_console := controller.get_input(0.0)
	var console_registered := MenuState.is_open(console) and MenuState.blocks_gameplay()
	console.set_open(false)
	var closed_again := not MenuState.is_any_open() and not MenuState.blocks_gameplay()
	Input.action_release("move_forward")
	_check("The developer console registers with MenuState too: while it is open the player gets no movement, and closing it unblocks everything",
			console_registered and with_console.move == Vector2.ZERO and closed_again,
			"registered %s, move while open %s, unblocked after %s" % [console_registered, with_console.move, closed_again])
	console.queue_free()
	_free_menu(menu)
	remove_child(map)
	map.queue_free()
	MenuState.reset()


## The menu is exactly 1.5 times as big at 1.5 and keeps its panel size whatever the tabs hold.
func _test_menu_scaling() -> void:
	var menu := await _new_menu()
	var panel := menu.get_node("Panel") as PanelContainer
	var title := menu.get_node("Panel/Margin/Content/Title") as Label
	var back := menu.get_back_button()
	var slider := menu.get_slider(&"sensitivity")
	var label := menu.get_slider(&"sensitivity").get_parent().get_child(0) as Label
	var swatch_margin := menu.get_swatches()[0].get_child(0) as MarginContainer
	menu.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var at_one := [await _panel_sizes(menu), title.get_theme_font_size("font_size"), label.get_theme_font_size("font_size"), back.custom_minimum_size,
			label.custom_minimum_size.x, swatch_margin.get_theme_constant("margin_left"), menu.get_preview().length]
	menu.set_ui_scale(1.5)
	var at_one_and_a_half := [await _panel_sizes(menu), title.get_theme_font_size("font_size"), label.get_theme_font_size("font_size"), back.custom_minimum_size,
			label.custom_minimum_size.x, swatch_margin.get_theme_constant("margin_left"), menu.get_preview().length]
	var preview_gap_scaled := menu.get_preview().thickness == 3.0
	var overrides := _own_overrides(menu)
	menu.set_ui_scale(1.0)
	var back_at_one := [await _panel_sizes(menu), title.get_theme_font_size("font_size"), label.get_theme_font_size("font_size"), back.custom_minimum_size,
			label.custom_minimum_size.x, swatch_margin.get_theme_constant("margin_left"), menu.get_preview().length]
	var sizes_one: Array[Vector2] = [Vector2(960, 660), Vector2(960, 660), Vector2(960, 660), Vector2(960, 660), Vector2(960, 660)]
	var sizes_one_and_a_half: Array[Vector2] = [Vector2(1440, 990), Vector2(1440, 990), Vector2(1440, 990), Vector2(1440, 990), Vector2(1440, 990)]
	_check("At 1.0 the menu is as designed: a 960 × 660 panel on every one of the five tabs (no tab's rows make it wider), 48 px title, 16 px rows, 200 px labels, a 200 × 40 Back button",
			at_one == [sizes_one, 48, 16, Vector2(200, 40), 200.0, 6, 7.0], "%s" % [at_one])
	_check("Scaled by 1.5 everything is exactly 1.5 times as big: a 1440 × 990 panel on every tab, 72 / 24 px text, 300 labels, a 300 × 60 Back button, the swatch margin 9, the preview crosshair (thickness 3 px), and back at 1.0 it is as before",
			at_one_and_a_half == [sizes_one_and_a_half, 72, 24, Vector2(300, 60), 300.0, 9, 11.0] and preview_gap_scaled and back_at_one == at_one,
			"1.5: %s, back: %s" % [at_one_and_a_half, back_at_one])
	_check("Nothing in the menu carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty() and slider.get_theme_stylebox("slider") is StyleBoxFlat, "controls with overrides: %s" % [overrides])
	menu.close()
	_free_menu(menu)


## The console's `settings` command, a `help` that fits, and scrolling back.
func _test_console_and_menus() -> void:
	var settings := Settings.get_instance()
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var console := main.get_node("DevConsole") as DevConsole
	var menu := main.get_settings_menu() as SettingsMenu
	console.set_open(true)
	console.run("settings")
	var opened := menu.visible and MenuState.is_top(menu) and not DevConsole.is_open and not console.visible
	_check("The console command `settings` opens the settings menu over the game and closes the console, so the menu has the keyboard and the mouse",
			opened, "menu open %s, console open %s" % [menu.visible, DevConsole.is_open])
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc closes it again and the game is free: nothing is open",
			not menu.visible and not MenuState.is_any_open() and not MenuState.blocks_gameplay(), "menu open %s" % menu.visible)
	var panel_minimum := (menu.get_node("Panel") as Control).custom_minimum_size
	var window_height := get_tree().root.size.y
	_check("main.gd scales the menu with the window like the other UI: its panel minimum is 960 × 660 times the window's height over 720 (the headless window is %d tall)" % window_height,
			panel_minimum == (Vector2(960, 660) * (window_height / 720.0)).round(), "panel minimum %s" % panel_minimum)
	console.run("clear")
	console.run("help")
	var names := console.get_command_names()
	var first_screen := console.get_visible_lines()
	# Page back to the start of the answer, collecting every line seen on the way.
	var seen: Array[String] = []
	seen.append_array(first_screen)
	var pages := 0
	while console.get_visible_lines()[0] != "> help" and pages < 20:
		console.scroll_output(DevConsole.VISIBLE_LINES - 2)
		seen.append_array(console.get_visible_lines())
		pages += 1
	var listed := names.all(func(command_name: String) -> bool: return seen.any(func(line: String) -> bool: return line.begins_with(command_name)))
	var fits := first_screen[0] == "> help" and first_screen.size() == names.size() + 1
	console.scroll_output(-10000)
	_check("`help` lists every command, `settings` included, and all of it can be read: the echo and %d command lines %s (room for %d lines, the rest scrolls back)" % [
			names.size(), "fit on the screen at once" if fits else "need scrolling", DevConsole.VISIBLE_LINES],
			listed and names.has("settings") and fits, "%d commands, %d lines on the first screen, %d page(s) back to the echo, fits at once: %s" % [
					names.size(), first_screen.size(), pages, fits])
	for i in 40:
		console.print_line("line %d" % i)
	var at_end := console.get_visible_lines()
	console.scroll_output(10)
	var scrolled := console.get_visible_lines()
	console.scroll_output(10000)
	var oldest := console.get_visible_lines()
	console.scroll_output(-10000)
	var back_at_end := console.get_visible_lines()
	console.scroll_output(5)
	console.print_line("new line")
	var after_new := console.get_visible_lines()
	_check("The console output scrolls back: the last %d lines show, 10 lines back shows older ones, scrolling stops at the oldest and at the newest, and a new line jumps back to the end" % DevConsole.VISIBLE_LINES,
			at_end.size() == DevConsole.VISIBLE_LINES and at_end[-1] == "line 39" and scrolled[-1] == "line 29" and oldest[0] != at_end[0]
					and back_at_end == at_end and after_new[-1] == "new line",
			"end '%s', 10 back '%s', oldest first line '%s', after a new line '%s'" % [at_end[-1], scrolled[-1], oldest[0], after_new[-1]])
	main.queue_free()
	await get_tree().process_frame
	MenuState.reset()
	settings.reset_to_defaults()


# --- The main menu and match setup (D-064) ---


## The main menu: four themed buttons over a background without a player, a calm
## camera flight, scaled with the window, and Esc.
func _test_main_menu() -> void:
	var settings := Settings.get_instance()
	MenuState.reset()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array[String] = []
	var big := true
	for button in menu.get_buttons():
		texts.append(button.text)
		big = big and button.theme_type_variation == &"BigButton" and button.visible
	var title := menu.get_node("Page/Margin/Column/Panel/PanelMargin/Content/Title") as Label
	var panel := menu.get_node("Page/Margin/Column/Panel") as PanelContainer
	_check("The main menu shows the title CHIIP and the buttons Play, Practice, Settings and Quit (big themed buttons on an overlay panel), with Play focused, and the mouse is free",
			title.text == "CHIIP" and texts == ["Play", "Practice", "Settings", "Quit"] and big and panel.theme_type_variation == &"OverlayPanel"
					and menu.get_buttons()[0].has_focus() and MenuState.is_top(menu) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"title '%s', buttons %s, focus on Play %s, on top %s" % [title.text, texts, menu.get_buttons()[0].has_focus(), MenuState.is_top(menu)])

	# The background: the test map without its player, so nothing plays.
	var background := menu.get_background()
	var viewport := menu.get_node("World/SubViewport") as SubViewport
	var flight := menu.get_flight()
	var players := background.find_children("Player", "", true, false)
	var characters := background.find_children("*", "Character", true, false)
	var controllers := background.find_children("*", "PlayerController", true, false)
	var rules := background.get_children().filter(func(node: Node) -> bool: return node is RoundManager or node is ArenaRules)
	var cameras := viewport.find_children("*", "Camera3D", true, false)
	_check("The background is the test map rendered in the low-res world viewport, and its Player node was removed before it entered the tree: no player, no character, no controller, no game rules",
			background != null and background.scene_file_path == "res://maps/test_map.tscn" and background.get_parent() == viewport
					and background.get_node_or_null("Player") == null and players.is_empty() and characters.is_empty() and controllers.is_empty() and rules.is_empty(),
			"map '%s', players %d, characters %d, controllers %d, rules %d" % [
					background.scene_file_path if background != null else "none", players.size(), characters.size(), controllers.size(), rules.size()])
	_check("The only camera is the flight's, and it is the one the viewport renders (the map's player camera went with the player)",
			cameras.size() == 1 and cameras[0] == flight.get_camera() and viewport.get_camera_3d() == flight.get_camera() and flight.get_camera().current,
			"%d camera(s), the viewport's is the flight's: %s" % [cameras.size(), viewport.get_camera_3d() == flight.get_camera()])

	# The flight: slow, smooth, closed, inside the level.
	var camera := flight.get_camera()
	flight.set_time(0.0)
	var start := camera.global_position
	var previous := start
	var previous_yaw := 0.0
	var max_speed := 0.0
	var max_turn := 0.0
	var lowest := INF
	var highest := -INF
	var inside := true
	var step := 0.25
	var time := step
	while time <= flight.loop_seconds + 0.01:
		flight.set_time(time)
		var position := camera.global_position
		var forward := -camera.global_basis.z
		var yaw := atan2(-forward.x, -forward.z)
		max_speed = maxf(max_speed, position.distance_to(previous) / step)
		if time > step:
			max_turn = maxf(max_turn, absf(rad_to_deg(wrapf(yaw - previous_yaw, -PI, PI))) / step)
		lowest = minf(lowest, position.y)
		highest = maxf(highest, position.y)
		inside = inside and absf(position.x) < 31.0 and position.z > -31.0 and position.z < 87.0
		previous = position
		previous_yaw = yaw
		time += step
	var closed := camera.global_position.distance_to(start) < 0.05
	flight.set_time(flight.loop_seconds * 0.5)
	var halfway := camera.global_position
	_check("The camera flies a calm loop across the map: one lap in %.0f s (60 to 90), never faster than 5 m/s or turning faster than 30°/s, 4 to 6 m up, inside the walls, and the loop closes where it began" % flight.loop_seconds,
			flight.loop_seconds >= 60.0 and flight.loop_seconds <= 90.0 and max_speed < 5.0 and max_turn < 30.0 and lowest >= 3.6 and highest <= 6.4
					and inside and closed and halfway.distance_to(start) > 20.0 and flight.get_loop_length() > 150.0,
			"%.1f m/s at most, %.1f°/s at most, %.1f to %.1f m up, inside %s, closed %s, %.0f m long, halfway %.0f m from the start" % [
					max_speed, max_turn, lowest, highest, inside, closed, flight.get_loop_length(), halfway.distance_to(start)])
	var before_time := flight.get_time()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("It keeps flying by itself: the clock runs while the menu is shown", flight.get_time() > before_time, "%.3f s → %.3f s" % [before_time, flight.get_time()])

	# Rendered like the game: the video settings reach the background and the menus scale with the window.
	var effect := menu.get_node("World/SubViewport/PaletteEffect") as CanvasLayer
	var world := menu.get_node("World") as SubViewportContainer
	var window := get_tree().root
	var effect_on := effect.visible
	settings.palette_effect = false
	var effect_off := not effect.visible
	settings.palette_effect = true
	var start_button := menu.get_buttons()[0]
	# A headless window is 64 pixels tall and goes back to that every frame: change it and check in the same frame.
	window.size = Vector2i(1280, 720)
	menu.apply_pixel_settings()
	var at_720 := [world.stretch_shrink, panel.custom_minimum_size.x, start_button.get_theme_font_size("font_size"),
			menu.get_match_setup().get_node("Panel").custom_minimum_size.x, menu.get_settings_menu().get_node("Panel").custom_minimum_size.x]
	window.size = Vector2i(1920, 1080)
	menu.apply_pixel_settings()
	var at_1080 := [world.stretch_shrink, panel.custom_minimum_size.x, start_button.get_theme_font_size("font_size"),
			menu.get_match_setup().get_node("Panel").custom_minimum_size.x, menu.get_settings_menu().get_node("Panel").custom_minimum_size.x]
	settings.pixel_height = 270
	var low_res := world.stretch_shrink
	settings.pixel_height = 480
	_check("The background follows the video settings like the game: the palette effect switches with its setting, and in a 720-pixel window the world is 360 lines (scaled 2×), in a 1080 one 540 lines (2×), 270 lines gives 4×",
			effect_on and effect_off and at_720[0] == 2 and at_1080[0] == 2 and low_res == 4,
			"effect on %s, off %s; shrink %s at 720, %s at 1080, %d at 270 lines" % [effect_on, effect_off, at_720[0], at_1080[0], low_res])
	_check("The menus scale with the window like the other menus: at 720 the page panel is 380 wide with 32 px buttons, match setup 780 and settings 960 wide; at 1080 exactly 1.5 times that (570, 48 px, 1170, 1440)",
			at_720 == [2, 380.0, 32, 780.0, 960.0] and at_1080 == [2, 570.0, 48, 1170.0, 1440.0], "720: %s, 1080: %s" % [at_720, at_1080])
	var overrides := _own_overrides(menu.get_node("Page")) + _own_overrides(menu.get_match_setup())
	_check("Nothing in the main page or match setup carries a stylebox or font-size override of its own, so the theme alone decides their look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	window.size = Vector2i(1280, 720)
	menu.apply_pixel_settings()
	settings.reset_to_defaults()

	# Esc: closes match setup or the settings menu, whichever is on top; on the main page it does nothing.
	var setup := menu.get_match_setup()
	var settings_menu := menu.get_settings_menu()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var nothing_happened := MenuState.is_top(menu) and not setup.is_open() and not settings_menu.is_open() and menu.get_buttons().all(func(b: Button) -> bool: return b.visible)
	menu.get_buttons()[0].pressed.emit()
	var setup_opened := setup.is_open() and MenuState.is_top(setup) and setup.get_start_button().has_focus()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var setup_closed := not setup.is_open() and MenuState.is_top(menu) and menu.get_buttons()[0].has_focus()
	menu.get_buttons()[2].pressed.emit()
	var settings_opened := settings_menu.is_open() and MenuState.is_top(settings_menu) and not setup.is_open()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var settings_closed := not settings_menu.is_open() and MenuState.is_top(menu) and menu.get_buttons()[2].has_focus()
	menu.get_buttons()[0].pressed.emit()
	setup.get_back_button().pressed.emit()
	var by_back := not setup.is_open() and MenuState.is_top(menu)
	_check("Esc does nothing on the main page; Play opens match setup (Start focused) and Esc closes it; Settings opens the settings menu and Esc closes it; Back closes match setup; the main menu stays the menu on the bottom of MenuState and the mouse stays free",
			nothing_happened and setup_opened and setup_closed and settings_opened and settings_closed and by_back and MenuState.is_any_open()
					and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"Esc on the page %s, setup opened %s, closed by Esc %s, settings opened %s, closed by Esc %s, Back %s" % [
					nothing_happened, setup_opened, setup_closed, settings_opened, settings_closed, by_back])
	_check("Only the command line skips the menu: --match, --practice and --map ask for the game, nothing else does",
			MainMenu.wants_game(PackedStringArray(["--match"])) and MainMenu.wants_game(PackedStringArray(["--practice"]))
					and MainMenu.wants_game(PackedStringArray(["--map", "res://maps/test_map.tscn"])) and not MainMenu.wants_game(PackedStringArray())
					and not MainMenu.wants_game(PackedStringArray(["--verbose"])),
			"match %s, practice %s, map %s, none %s" % [MainMenu.wants_game(PackedStringArray(["--match"])), MainMenu.wants_game(PackedStringArray(["--practice"])),
					MainMenu.wants_game(PackedStringArray(["--map", "x"])), MainMenu.wants_game(PackedStringArray())])
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame
	_check("When the main menu goes away it lets go of everything: nothing stays open",
			not MenuState.is_any_open(), "open menus: %s" % MenuState.is_any_open())
	MenuState.reset()
	settings.reset_to_defaults()


## Match setup on its own, with a Settings instance of its own: defaults, controls, stored choices, maps.
func _test_match_setup() -> void:
	# A Settings.new() only holds values: it never saves and never touches the engine.
	var stored := Settings.new()
	var setup := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	setup.settings = stored
	add_child(setup)
	await get_tree().process_frame
	var defaults := MatchSettings.new()
	var rules := setup.build_match_settings()
	var team_buttons := setup.get_segment_buttons(&"match_team_size")
	var enemy_buttons := setup.get_segment_buttons(&"match_enemy_team_size")
	var difficulty_buttons := setup.get_segment_buttons(&"match_difficulty")
	var length_buttons := setup.get_segment_buttons(&"match_rounds_to_win")
	var fire_buttons := setup.get_segment_buttons(&"match_friendly_fire")
	_check("Match setup is hidden until opened, and offers team sizes 1 to 5 (yours and the enemy's), Easy / Normal / Hard, First to 5 / 10 / 15, friendly fire Off / On, a map, Back and Start",
			not setup.visible and team_buttons.size() == 5 and enemy_buttons.size() == 5 and _texts(difficulty_buttons) == ["Easy", "Normal", "Hard"]
					and _texts(length_buttons) == ["First to 5", "First to 10", "First to 15"] and _texts(fire_buttons) == ["Off", "On"]
					and _texts(team_buttons) == ["1", "2", "3", "4", "5"] and setup.get_map_option() != null
					and setup.get_back_button().text == "Back" and setup.get_start_button().text == "Start",
			"team %s, difficulty %s, length %s, friendly fire %s" % [_texts(team_buttons), _texts(difficulty_buttons), _texts(length_buttons), _texts(fire_buttons)])
	_check("The defaults are 3v3, Normal bots, first to 5, friendly fire off, on the test map, and they equal MatchSettings' own defaults (D-041)",
			_pressed(team_buttons) == 2 and _pressed(enemy_buttons) == 2 and _pressed(difficulty_buttons) == 1 and _pressed(length_buttons) == 0 and _pressed(fire_buttons) == 0
					and setup.get_map_path() == Settings.DEFAULT_MAP and rules.team_size == 3 and rules.enemy_team_size == 3
					and rules.bot_difficulty.display_name == "normal" and rules.rounds_to_win == 5 and not rules.friendly_fire
					and rules.team_size == defaults.team_size and rules.enemy_team_size == defaults.enemy_team_size
					and rules.bot_difficulty == defaults.bot_difficulty and rules.rounds_to_win == defaults.rounds_to_win
					and rules.friendly_fire == defaults.friendly_fire and rules.freeze_time == defaults.freeze_time and rules.round_time == defaults.round_time,
			"pressed: team %d, enemy %d, difficulty %d, length %d, fire %d; map %s; %d v %d, %s, first to %d" % [
					_pressed(team_buttons), _pressed(enemy_buttons), _pressed(difficulty_buttons), _pressed(length_buttons), _pressed(fire_buttons),
					setup.get_map_path(), rules.team_size, rules.enemy_team_size, rules.bot_difficulty.display_name, rules.rounds_to_win])
	var summary_before := setup.get_summary()

	# Changing the controls changes the match, and what is stored.
	(team_buttons[1] as Button).button_pressed = true
	(enemy_buttons[4] as Button).button_pressed = true
	(difficulty_buttons[2] as Button).button_pressed = true
	(length_buttons[2] as Button).button_pressed = true
	(fire_buttons[1] as Button).button_pressed = true
	rules = setup.build_match_settings()
	_check("Pressing 2, 5, Hard, First to 15 and friendly fire On gives a match of 2 against 5, hard bots, first to 15, friendly fire on (the round timings stay at their defaults), and each row has exactly one button pressed",
			rules.team_size == 2 and rules.enemy_team_size == 5 and rules.bot_difficulty.display_name == "hard" and rules.rounds_to_win == 15 and rules.friendly_fire
					and rules.freeze_time == defaults.freeze_time and rules.round_end_time == defaults.round_end_time
					and _pressed(team_buttons) == 1 and _pressed(enemy_buttons) == 4 and _pressed(difficulty_buttons) == 2
					and _pressed_count(team_buttons) == 1 and _pressed_count(enemy_buttons) == 1 and _pressed_count(difficulty_buttons) == 1
					and _pressed_count(length_buttons) == 1 and _pressed_count(fire_buttons) == 1,
			"%d v %d, %s, first to %d, friendly fire %s" % [rules.team_size, rules.enemy_team_size, rules.bot_difficulty.display_name, rules.rounds_to_win, rules.friendly_fire])
	_check("The choices are stored in the Settings instance (its [match] values), and the summary line follows them",
			stored.match_team_size == 2 and stored.match_enemy_team_size == 5 and stored.match_difficulty == "hard" and stored.match_rounds_to_win == 15
					and stored.match_friendly_fire and setup.get_summary() != summary_before and setup.get_summary().contains("1 bot ")
					and setup.get_summary().contains("5 bots") and setup.get_summary().contains("Hard") and setup.get_summary().contains("first to 15"),
			"stored %d/%d/%s/%d/%s; summary '%s'" % [stored.match_team_size, stored.match_enemy_team_size, stored.match_difficulty,
					stored.match_rounds_to_win, stored.match_friendly_fire, setup.get_summary()])
	# A change from outside (the console, a loaded file) moves the buttons.
	stored.match_team_size = 5
	stored.match_difficulty = "easy"
	_check("A change made outside the panel moves the buttons: team size 5 and Easy are pressed now",
			_pressed(team_buttons) == 4 and _pressed(difficulty_buttons) == 0 and _pressed_count(team_buttons) == 1 and _pressed_count(difficulty_buttons) == 1,
			"team %d, difficulty %d" % [_pressed(team_buttons), _pressed(difficulty_buttons)])
	stored.match_team_size = 2
	stored.match_difficulty = "hard"

	# The choices survive a restart: written to a file and read by another instance, they come back.
	_remove_temp_file()
	stored.match_map = "res://maps/comparison/csg_room.tscn"
	var saved := stored.save_to_disk(TEMP_PATH)
	var restarted := Settings.new()
	var loaded := restarted.load_from_disk(TEMP_PATH)
	var second := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	second.settings = restarted
	add_child(second)
	await get_tree().process_frame
	var again := second.build_match_settings()
	_check("After a restart (the choices saved to a file and loaded by a new Settings) the panel offers the same match: 2 against 5, hard, first to 15, friendly fire on, with the same buttons pressed",
			saved == OK and loaded == OK and again.team_size == 2 and again.enemy_team_size == 5 and again.bot_difficulty.display_name == "hard"
					and again.rounds_to_win == 15 and again.friendly_fire
					and _pressed(second.get_segment_buttons(&"match_team_size")) == 1 and _pressed(second.get_segment_buttons(&"match_difficulty")) == 2
					and _pressed(second.get_segment_buttons(&"match_rounds_to_win")) == 2 and _pressed(second.get_segment_buttons(&"match_friendly_fire")) == 1,
			"save %d, load %d, %d v %d, %s, first to %d" % [saved, loaded, again.team_size, again.enemy_team_size, again.bot_difficulty.display_name, again.rounds_to_win])
	_remove_temp_file()
	remove_child(second)
	second.queue_free()

	# The map list.
	var on_disk: Array[String] = []
	for file in DirAccess.get_files_at("res://maps/"):
		if file.ends_with(".tscn"):
			on_disk.append("res://maps/" + file)
	on_disk.sort()
	var option := setup.get_map_option()
	var shown: Array[String] = []
	for index in option.item_count:
		shown.append(option.get_item_text(index))
	_check("The map list is every scene directly in res://maps/ (like the console's map command), test_map among them, listed by name: %s" % [shown],
			setup.get_map_paths() == on_disk and on_disk.has("res://maps/test_map.tscn") and option.item_count == on_disk.size()
					and GameLaunch.list_maps() == on_disk and shown.has("Test Map"),
			"on disk %s, offered %s" % [on_disk, setup.get_map_paths()])
	var other := 1 - maxi(0, setup.get_map_paths().find("res://maps/test_map.tscn"))
	var picked_other := setup.get_map_paths().size() > 1
	if picked_other:
		option.select(other)
		option.item_selected.emit(other)
	var map_stored := not picked_other or (stored.match_map == setup.get_map_paths()[other] and setup.get_map_path() == setup.get_map_paths()[other])
	stored.match_map = "res://maps/gone.tscn"
	var fell_back := setup.get_map_path() == Settings.DEFAULT_MAP and option.selected == setup.get_map_paths().find(Settings.DEFAULT_MAP)
	_check("Choosing another map (when there is one) is stored, and a stored map that no longer exists falls back to the test map",
			map_stored and fell_back, "stored %s, with a missing map the panel offers %s" % [map_stored, setup.get_map_path()])

	# Opening, Esc, Back, Start; scaling.
	var signals: Array[String] = []
	setup.started.connect(func() -> void: signals.append("started"))
	setup.closed.connect(func() -> void: signals.append("closed"))
	MenuState.reset()
	setup.open()
	var opened := setup.visible and MenuState.is_top(setup) and MenuState.blocks_gameplay() and setup.get_start_button().has_focus()
	setup.get_start_button().pressed.emit()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var by_esc := not setup.visible and not MenuState.is_any_open()
	setup.open()
	setup.get_back_button().pressed.emit()
	var by_back := not setup.visible and not MenuState.is_any_open()
	setup.close()
	_check("Opening puts match setup on top of MenuState with Start focused; Start reports `started` (and leaves the panel to the menu), Esc and Back close it and emit `closed` once each, closing it again does nothing",
			opened and by_esc and by_back and signals == ["started", "closed", "closed"],
			"opened %s, Esc %s, Back %s, signals %s" % [opened, by_esc, by_back, signals])
	var panel := setup.get_node("Panel") as PanelContainer
	var title := setup.get_node("Panel/Margin/Content/Title") as Label
	var segment := team_buttons[0] as Button
	setup.set_ui_scale(1.5)
	var scaled := [panel.custom_minimum_size.x, title.get_theme_font_size("font_size"), segment.custom_minimum_size.x, setup.get_start_button().custom_minimum_size]
	setup.set_ui_scale(1.0)
	var back_at_one := [panel.custom_minimum_size.x, title.get_theme_font_size("font_size"), segment.custom_minimum_size.x, setup.get_start_button().custom_minimum_size]
	_check("Match setup is a themed modal panel and scales exactly: 780 / 48 px title / 56 px buttons / 200 × 40 Start at 1.0, 1170 / 72 / 84 / 300 × 60 at 1.5",
			panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel"
					and scaled == [1170.0, 72, 84.0, Vector2(300, 60)] and back_at_one == [780.0, 48, 56.0, Vector2(200, 40)],
			"1.5: %s, 1.0: %s" % [scaled, back_at_one])
	remove_child(setup)
	setup.queue_free()
	await get_tree().process_frame
	MenuState.reset()


## The launch description: what the menu leaves and what main.gd builds from it, without changing scenes.
func _test_game_launch() -> void:
	var settings := Settings.new()
	settings.match_team_size = 2
	settings.match_enemy_team_size = 4
	settings.match_difficulty = "hard"
	settings.match_rounds_to_win = 10
	settings.match_friendly_fire = true
	var rules := GameLaunch.match_settings_from(settings)
	_check("GameLaunch turns the stored choices into MatchSettings (2 v 4, hard, first to 10, friendly fire), and an unknown difficulty name gives Normal",
			rules.team_size == 2 and rules.enemy_team_size == 4 and rules.bot_difficulty.display_name == "hard" and rules.rounds_to_win == 10
					and rules.friendly_fire and GameLaunch.difficulty_named("bogus").display_name == "normal" and GameLaunch.difficulty_named("easy").display_name == "easy",
			"%d v %d, %s, first to %d" % [rules.team_size, rules.enemy_team_size, rules.bot_difficulty.display_name, rules.rounds_to_win])

	# A match: main.gd reads the description once and builds a round manager with those exact settings.
	_check("Nothing is pending until the menu leaves a description", not GameLaunch.is_pending(), "pending %s" % GameLaunch.is_pending())
	GameLaunch.start_match("res://maps/test_map.tscn", rules)
	var pending := GameLaunch.is_pending() and not GameLaunch.practice and GameLaunch.match_settings == rules
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var round_manager := main.get_map().get_node_or_null("RoundManager") as RoundManager
	var player_team := Teams.viewer_team
	_check("main.gd started with a match description builds a RoundManager with those settings on that map: 2 on your team (you and a bot), 4 enemy bots, hard, first to 10, friendly fire on",
			pending and round_manager != null and round_manager.settings == rules and main.mode == main.Mode.MATCH
					and main.get_map().scene_file_path == "res://maps/test_map.tscn" and round_manager.get_members(player_team).size() == 2
					and round_manager.get_members(Teams.other(player_team)).size() == 4 and Teams.friendly_fire
					and main.get_map().get_node_or_null("ArenaRules") == null,
			"pending %s, manager %s, members %d + %d, friendly fire %s" % [pending, round_manager != null,
					round_manager.get_members(player_team).size() if round_manager != null else -1,
					round_manager.get_members(Teams.other(player_team)).size() if round_manager != null else -1, Teams.friendly_fire])
	_check("The description is used once: after main.gd read it nothing is pending, and its player and settings are cleared",
			not GameLaunch.is_pending() and GameLaunch.match_settings == null and GameLaunch.map_path == Settings.DEFAULT_MAP,
			"pending %s" % GameLaunch.is_pending())
	var main_menu_connected := (main.get_node("MatchEndScreen") as MatchEndScreen).main_menu_pressed.is_connected(main.return_to_menu)
	var console := main.get_node("DevConsole") as DevConsole
	_check("The match-end screen's Main menu button and the console command `disconnect` lead back to the menu (main.return_to_menu)",
			main_menu_connected and console.get_command_names().has("disconnect"),
			"button connected %s, commands %s" % [main_menu_connected, console.get_command_names()])
	main.queue_free()
	await get_tree().process_frame
	Teams.friendly_fire = false
	MenuState.reset()

	# Practice: the respawning arena, with the chosen difficulty.
	GameLaunch.start_practice("res://maps/test_map.tscn", GameLaunch.difficulty_named("hard"))
	var practice := MAIN_SCENE.instantiate()
	practice.load_settings = false
	add_child(practice)
	await get_tree().process_frame
	await get_tree().process_frame
	var arena := practice.get_map().get_node_or_null("ArenaRules") as ArenaRules
	_check("A practice description gives ArenaRules (no round manager) with the chosen difficulty: hard bots in the respawning arena on the test map",
			arena != null and practice.get_map().get_node_or_null("RoundManager") == null and practice.mode == practice.Mode.PRACTICE
					and arena.bot_difficulty.display_name == "hard" and not GameLaunch.is_pending(),
			"arena %s, difficulty %s, mode %d" % [arena != null, arena.bot_difficulty.display_name if arena != null else "none", practice.mode])
	practice.queue_free()
	await get_tree().process_frame
	MenuState.reset()

	# Another map from the description, and the defaults when there is none.
	GameLaunch.start_match("res://maps/comparison/csg_room.tscn", rules)
	var other_map := MAIN_SCENE.instantiate()
	other_map.load_settings = false
	add_child(other_map)
	await get_tree().process_frame
	var other_path: String = other_map.get_map().scene_file_path
	other_map.queue_free()
	await get_tree().process_frame
	var direct := MAIN_SCENE.instantiate()
	direct.load_settings = false
	add_child(direct)
	await get_tree().process_frame
	await get_tree().physics_frame
	var direct_rounds := direct.get_map().get_node_or_null("RoundManager") as RoundManager
	_check("The description also picks the map (the CSG room here), and a main.tscn started without one (the tests, -- --match) plays today's default: a 3v3 match on the test map",
			other_path == "res://maps/comparison/csg_room.tscn" and direct.get_map().scene_file_path == "res://maps/test_map.tscn"
					and direct_rounds != null and direct_rounds.settings.team_size == 3 and direct_rounds.settings.enemy_team_size == 3
					and direct_rounds.settings.bot_difficulty.display_name == "normal" and direct_rounds.settings.rounds_to_win == 5,
			"first map %s, default map %s, manager %s" % [other_path, direct.get_map().scene_file_path, direct_rounds != null])
	direct.queue_free()
	await get_tree().process_frame
	Teams.friendly_fire = false
	GameLaunch.clear()
	MenuState.reset()
	Settings.get_instance().reset_to_defaults()


## The real way through the scenes, in a scene of its own so the test scene stays:
## the menu's Start changes to the game scene, which plays what was chosen, and
## the match-end screen's Main menu button changes back. The settings are loaded
## from a temporary file first, so neither scene reads or writes the real one.
func _test_scene_flow() -> void:
	var tree := get_tree()
	var shared := Settings.get_instance()
	_remove_temp_file()
	shared.load_from_disk(TEMP_PATH)
	var holder := Node.new()
	tree.root.add_child(holder)
	tree.current_scene = holder
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	holder.add_child(menu)
	await tree.process_frame
	await tree.process_frame
	var setup := menu.get_match_setup()
	menu.get_buttons()[0].pressed.emit()
	(setup.get_segment_buttons(&"match_team_size")[1] as Button).button_pressed = true
	(setup.get_segment_buttons(&"match_enemy_team_size")[3] as Button).button_pressed = true
	(setup.get_segment_buttons(&"match_difficulty")[0] as Button).button_pressed = true
	(setup.get_segment_buttons(&"match_rounds_to_win")[1] as Button).button_pressed = true
	var saved_file := FileAccess.file_exists(TEMP_PATH)
	setup.get_start_button().pressed.emit()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.physics_frame
	var game := tree.current_scene
	var rounds: RoundManager = game.get_map().get_node_or_null("RoundManager") if game != null and game.has_method("get_map") else null
	_check("The real flow: Play, the chosen 2v4 / Easy / first to 10 and Start change the scene to the game, which plays exactly that (the menu is gone, and the choices were saved to the settings file)",
			game != null and game.scene_file_path == GameLaunch.GAME_SCENE and not is_instance_valid(menu) and saved_file and rounds != null
					and rounds.settings.team_size == 2 and rounds.settings.enemy_team_size == 4 and rounds.settings.bot_difficulty.display_name == "easy"
					and rounds.settings.rounds_to_win == 10 and not MenuState.is_any_open(),
			"scene '%s', menu freed %s, manager %s, settings file written %s" % [game.scene_file_path if game != null else "none", not is_instance_valid(menu), rounds != null, saved_file])
	if game != null and game.has_method("return_to_menu"):
		(game.get_node("MatchEndScreen") as MatchEndScreen).main_menu_pressed.emit()
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
	var back := tree.current_scene as MainMenu
	_check("The match-end screen's Main menu button changes back to the main menu scene, which shows the same choices and has the mouse free",
			back != null and back.scene_file_path == GameLaunch.MENU_SCENE and MenuState.is_top(back)
					and _pressed(back.get_match_setup().get_segment_buttons(&"match_team_size")) == 1
					and _pressed(back.get_match_setup().get_segment_buttons(&"match_enemy_team_size")) == 3
					and _pressed(back.get_match_setup().get_segment_buttons(&"match_difficulty")) == 0
					and _pressed(back.get_match_setup().get_segment_buttons(&"match_rounds_to_win")) == 1
					and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"scene '%s'" % [tree.current_scene.scene_file_path if tree.current_scene != null else "none"])
	if back != null:
		# Practice from the menu: the arena with the difficulty chosen before (Easy), and the console's `disconnect` leads back.
		back.get_buttons()[1].pressed.emit()
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
		var practice := tree.current_scene
		var arena: ArenaRules = practice.get_map().get_node_or_null("ArenaRules") if practice != null and practice.has_method("get_map") else null
		_check("The Practice button changes to the game scene in practice mode: the respawning arena (no rounds) on the test map, with the difficulty last chosen in match setup (Easy here)",
				practice != null and practice.scene_file_path == GameLaunch.GAME_SCENE and not is_instance_valid(back) and arena != null
						and arena.bot_difficulty.display_name == "easy" and practice.get_map().scene_file_path == Settings.DEFAULT_MAP
						and practice.get_map().get_node_or_null("RoundManager") == null,
				"scene '%s', arena %s, difficulty %s" % [practice.scene_file_path if practice != null else "none", arena != null,
						arena.bot_difficulty.display_name if arena != null else "none"])
		if practice != null and practice.has_node("DevConsole"):
			(practice.get_node("DevConsole") as DevConsole).run("disconnect")
			await tree.process_frame
			await tree.process_frame
			await tree.process_frame
		var again := tree.current_scene as MainMenu
		_check("The console command `disconnect` leaves the game for the main menu too",
				again != null and again.scene_file_path == GameLaunch.MENU_SCENE and MenuState.is_top(again),
				"scene '%s'" % [tree.current_scene.scene_file_path if tree.current_scene != null else "none"])
		if again != null:
			again.free()
	else:
		_failures += 1
		print("FAIL  Practice and disconnect checks skipped: there was no menu to go back to")
	tree.current_scene = self
	if is_instance_valid(holder):
		holder.free()
	await tree.process_frame
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false
	shared.reset_to_defaults()
	shared.save_path = ""
	_remove_temp_file()


## The real settings file is exactly as it was when the test started.
func _test_real_file_untouched() -> void:
	var now := FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
	_check("The real user://settings.cfg was not read, created or changed by any of this",
			now == _real_file_md5 and Settings.get_instance().save_path == "", "before '%s', after '%s', shared instance saves to '%s'" % [
					_real_file_md5, now, Settings.get_instance().save_path])


## The size of the menu's panel with each tab selected in turn (a tab container is
## as big as the page it shows needs), ending on the first tab.
func _panel_sizes(menu: SettingsMenu) -> Array[Vector2]:
	var panel := menu.get_node("Panel") as Control
	var sizes: Array[Vector2] = []
	for index in menu.get_tabs().get_tab_count():
		menu.get_tabs().current_tab = index
		await get_tree().process_frame
		await get_tree().process_frame
		sizes.append(panel.size)
	menu.get_tabs().current_tab = 0
	await get_tree().process_frame
	return sizes


## A settings menu in the tree, one frame after it was built.
func _new_menu() -> SettingsMenu:
	var menu := SETTINGS_MENU_SCENE.instantiate() as SettingsMenu
	add_child(menu)
	await get_tree().process_frame
	return menu


func _free_menu(menu: SettingsMenu) -> void:
	remove_child(menu)
	menu.queue_free()


## A key press (or release) the way the keyboard sends it: the key by position and by label.
func _key_event(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _mouse_event(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## Sends an event through the real input path and makes it arrive now.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


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


## Like [method _style_or_size_overrides], but only for the controls a scene or
## a script added: the engine's own parts of a TabContainer or ScrollContainer (the
## tab bar, the focus frame) carry overrides of their own and aren't children in this sense.
func _own_overrides(root: Node) -> Array[String]:
	var found: Array[String] = []
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.has_theme_stylebox_override("panel") or control.has_theme_stylebox_override("normal") \
					or control.has_theme_font_size_override("font_size"):
				found.append(String(control.name))
		found.append_array(_own_overrides(child))
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


## The texts of buttons.
func _texts(buttons: Array) -> Array[String]:
	var texts: Array[String] = []
	for button: Button in buttons:
		texts.append(button.text)
	return texts


## The index of the first pressed button (-1 if none).
func _pressed(buttons: Array) -> int:
	for index in buttons.size():
		if (buttons[index] as Button).button_pressed:
			return index
	return -1


## How many of the buttons are pressed.
func _pressed_count(buttons: Array) -> int:
	return buttons.filter(func(button: Button) -> bool: return button.button_pressed).size()


func _remove_temp_file() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
