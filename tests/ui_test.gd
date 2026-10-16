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
## "Main menu" button and the way back to the menu. The pause menu (task 12,
## D-065) adds checks for the `pause` action on Esc, Esc opening and closing the
## menu (and who else takes Esc), the whole game standing still while it is
## open, Resume, Settings over it, Leave, and its look and scaling.
## The HUD (task 6, D-133) takes its look from the theme: the HUD roles exist and
## carry the tokens, the HUD scenes have no theme override and its scripts no colour
## literal, and the F3 overlay starts hidden and F3 shows it.
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
const PAUSE_MENU_SCENE := preload("res://ui/pause_menu.tscn")
const CLASS_MENU_SCENE := preload("res://ui/class_menu.tscn")
const THEME_PATH := "res://ui/chiip_theme.tres"
## The design tokens the theme is built from (D-131). Checks of the look compare
## with them rather than with numbers, so a new look doesn't break them.
const Tokens := preload("res://tools/ui_palette.gd")
const FONT_PATH: String = Tokens.FONT
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
	# M10 (D-131): roles for the mode choice, primary and text buttons, the biggest text.
	"HeroLabel": "Label", "ModeTitleLabel": "Label", "ModeDetailLabel": "Label",
	"PrimaryButton": "Button", "ModeButton": "Button", "TextButton": "Button",
	"SegmentRow": "HBoxContainer", "ModeList": "VBoxContainer", "ModeText": "VBoxContainer",
	"ModeMargin": "MarginContainer", "PageMargin": "MarginContainer",
	# M10 (D-131): roles that replaced the menus' own colours, fonts and spacing: team-coloured scores and
	# match result, the console's monospace font, the crosshair colour swatches, the dim behind a modal menu.
	"FriendlyScoreLabel": "Label", "EnemyScoreLabel": "Label", "VictoryLabel": "Label", "DefeatLabel": "Label",
	"ConsoleLabel": "Label", "ConsoleLineEdit": "LineEdit", "SwatchRow": "HBoxContainer", "SwatchMargin": "MarginContainer",
	"BackdropPanel": "Panel",
	# M10 task 10 (D-137): the settings screen's roles.
	"SettingsColumn": "VBoxContainer", "FlushRow": "HBoxContainer", "StackBox": "VBoxContainer", "GroupBox": "VBoxContainer",
	"TableRowPanel": "PanelContainer", "WideSegmentButton": "Button", "KeyCapButton": "Button", "KeySlotButton": "Button",
	"ListeningKeyButton": "KeyCapButton", "StrongButton": "Button", "DimButton": "Button", "SwatchButton": "Button",
}
## The roles the HUD uses (M10 task 6, D-133): name → the type it varies.
const HUD_VARIATIONS := {
	"HudWeaponLabel": "Label", "HudValueLabel": "Label", "HudDeathLabel": "Label", "HudSpectateLabel": "Label",
	"HudRespawnLabel": "Label", "HudScoreLabel": "Label", "HudTimerLabel": "Label", "HudRoundLabel": "Label",
	"HudTitleLabel": "Label", "HudLineLabel": "Label", "HudNoteLabel": "Label", "HudBombTagLabel": "Label",
	"HudPromptLabel": "Label", "HudBombMessageLabel": "Label",
	"HudTopBar": "HBoxContainer", "HudPips": "HBoxContainer", "HudBoxContent": "VBoxContainer",
	"HudMessages": "VBoxContainer", "HudKillFeed": "VBoxContainer", "HudBoxMargin": "MarginContainer",
	"HudFriendlyBox": "PanelContainer", "HudEnemyBox": "PanelContainer", "HudTimerBox": "PanelContainer",
	"HudBarBack": "Panel", "HudBarFill": "Panel",
}
## The HUD's scenes and scripts that must take everything from the theme (hud.gd and kill_feed.gd
## are not in the list: they still carry their own colours until the HUD work on the M7 branch lands).
const HUD_SCENES: Array[String] = ["res://ui/hud.tscn", "res://ui/round_hud.tscn", "res://ui/bomb_hud.tscn"]
const HUD_SCRIPTS: Array[String] = ["res://ui/round_hud.gd", "res://ui/bomb_hud.gd"]
## The theme overrides a menu must not carry (see [method _override_names]): the names a control's
## properties don't list because the built-in theme has no such item for its class, asked for one by one.
## Kind (the part Godot puts after "theme_override_") → item names.
const OVERRIDE_NAMES := {
	"colors": ["font_color", "font_outline_color", "font_hover_color", "font_pressed_color", "font_disabled_color",
			"font_focus_color", "font_selected_color", "caret_color", "selection_color", "default_color"],
	"fonts": ["font", "normal_font"],
	"font_sizes": ["font_size"],
	"constants": ["separation", "h_separation", "v_separation", "margin_left", "margin_top", "margin_right",
			"margin_bottom", "outline_size", "line_spacing"],
	"styles": ["panel", "normal", "hover", "pressed", "disabled", "focus"],
	"icons": ["icon"],
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
	_test_tokens()
	_test_new_roles()
	_test_settings_roles()
	_test_restyle_roles()
	_test_icon_slots()
	_test_scaled_theme()
	await _test_scaling_a_menu()
	await _test_preview()
	await _test_console()
	await _test_scoreboard()
	await _test_match_end_screen()
	await _test_menus_have_no_overrides()
	_test_hud_roles()
	_test_hud_scenes_use_the_theme()
	await _test_debug_overlay()
	_test_menu_state()
	await _test_settings_menu_building()
	await _test_settings_menu_look()
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
	_test_pause_action()
	await _test_pause_menu()
	await _test_pause_game_stands_still()
	await _test_pause_esc_rules()
	await _test_pause_menu_look()
	await _test_pause_leaves_the_game()
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
	_check("Its default font is the font token at the body text size (the size every font size is built on)",
			_theme.default_font != null and _theme.default_font.resource_path == FONT_PATH and _theme.default_font_size == Tokens.TEXT_SIZE,
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
	_check("A Button gets the theme's square look with the border token in every state, with the pixel font at the body size",
			normal != null and normal.bg_color == theme_normal.bg_color and normal.border_width_left == Tokens.BORDER
					and normal.corner_radius_top_left == 0
					and button.get_theme_stylebox("hover") is StyleBoxFlat and button.get_theme_stylebox("pressed") is StyleBoxFlat
					and button.get_theme_stylebox("focus") is StyleBoxFlat and button.get_theme_stylebox("disabled") is StyleBoxFlat
					and button.get_theme_font("font").resource_path == FONT_PATH and button.get_theme_font_size("font_size") == Tokens.TEXT_SIZE,
			"normal fill %s, border %d, corner %d, font '%s' %d px" % [
					normal.bg_color if normal != null else "none", normal.border_width_left if normal != null else -1,
					normal.corner_radius_top_left if normal != null else -1,
					button.get_theme_font("font").resource_path, button.get_theme_font_size("font_size")])
	_check("A Label gets the theme's text color and font, and a slider its track and square pixel-art knob",
			label.get_theme_color("font_color") == _theme.get_color("font_color", "Label")
					and label.get_theme_font("font").resource_path == FONT_PATH and label.get_theme_font_size("font_size") == Tokens.TEXT_SIZE
					and slider.get_theme_stylebox("slider") is StyleBoxFlat and slider.get_theme_stylebox("grabber_area") is StyleBoxFlat
					and slider.get_theme_icon("grabber").get_size() == Vector2(16, 16)
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
	_check("An option button has the arrow icon and a themed drop-down list; the chosen tab is underlined in the accent (D-134)",
			option.get_theme_icon("arrow").resource_path == "res://assets/ui/arrow_down.png"
					and popup.get_theme_stylebox("panel") is StyleBoxFlat and popup.get_theme_stylebox("hover") is StyleBoxFlat
					and popup.get_theme_font("font").resource_path == FONT_PATH
					and tab_selected != null and tab_selected.border_color == _theme.get_color("accent", "Palette")
					and tab_selected.border_width_bottom == Tokens.TAB_UNDERLINE,
			"arrow '%s', popup panel %s, selected tab border %s" % [
					option.get_theme_icon("arrow").resource_path, popup.get_theme_stylebox("panel").get_class(),
					tab_selected.border_color if tab_selected != null else "none"])
	var tooltip_panel := _theme.get_stylebox("panel", "TooltipPanel")
	_check("Tooltips and scroll bars are themed: a tooltip panel, and scroll bars with a track and a grabber",
			tooltip_panel is StyleBoxFlat and _theme.get_stylebox("grabber", "VScrollBar") is StyleBoxFlat
					and _theme.get_stylebox("scroll", "VScrollBar") != null and _theme.get_stylebox("scroll", "HScrollBar") != null,
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
	_check("Label variations change only what they should: title and score sizes, dim and header colors; titles in the bold cut (D-134), the others in the pixel font",
			title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE and score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE
					and dim.get_theme_font_size("font_size") == Tokens.TEXT_SIZE and dim.get_theme_color("font_color") == _theme.get_color("text_dim", "Palette")
					and header.get_theme_color("font_color") == _theme.get_color("accent", "Palette")
					and plain.get_theme_color("font_color") != dim.get_theme_color("font_color")
					and title.get_theme_font("font").resource_path == Tokens.FONT_BOLD and dim.get_theme_font("font").resource_path == FONT_PATH,
			"title %d, score %d, dim %d px" % [title.get_theme_font_size("font_size"), score.get_theme_font_size("font_size"), dim.get_theme_font_size("font_size")])
	var friendly := _variation_node(PanelContainer.new(), "TeamHeaderFriendly", holder)
	var enemy := _variation_node(PanelContainer.new(), "TeamHeaderEnemy", holder)
	var you_row := _variation_node(PanelContainer.new(), "YouRowPanel", holder)
	_check("The colors the theme copies still match their source: team header lines = the UI's team colours (D-134), your row = the YOU_ROW token, the palette's world team colours = Teams (rerun tools/make_ui_theme.gd if this fails)",
			(friendly.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.FRIENDLY
					and (enemy.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.ENEMY
					and (you_row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.YOU_ROW
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
	_check("Other variations work: a big button has the large size, PanelMargin and ContentBox their tokens, and plain containers keep Godot's spacing (the HUD relies on that)",
			button.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE and margin.get_theme_constant("margin_left") == Tokens.PANEL_MARGIN_X
					and margin.get_theme_constant("margin_top") == Tokens.PANEL_MARGIN_Y and box.get_theme_constant("separation") == Tokens.CONTENT_GAP
					and plain_box.get_theme_constant("separation") == 4
					and plain_row.get_theme_constant("separation") == 4 and plain_margin.get_theme_constant("margin_left") == 0,
			"big button %d px, margin %d / %d, content box %d" % [
					button.get_theme_font_size("font_size"), margin.get_theme_constant("margin_left"),
					margin.get_theme_constant("margin_top"), box.get_theme_constant("separation")])
	remove_child(holder)
	holder.queue_free()


## The theme is built from the design tokens (D-131): the theme tool has no
## numbers of its own, and the tokens arrive in the theme.
func _test_tokens() -> void:
	var numbers := _literal_numbers(FileAccess.get_file_as_string("res://tools/make_ui_theme.gd"))
	_check("The theme tool has no numbers of its own: every size and spacing is a token in tools/ui_palette.gd (D-131)",
			numbers.is_empty(), "numbers in tools/make_ui_theme.gd: %s" % [numbers])
	var button := _theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var arrived := _theme.default_font.resource_path == Tokens.FONT and _theme.default_font_size == Tokens.TEXT_SIZE \
			and button.bg_color == Tokens.BUTTON and button.border_color == Tokens.BUTTON_BORDER \
			and button.content_margin_left == Tokens.BUTTON_PAD_X and button.border_width_top == Tokens.BORDER \
			and _theme.get_color("accent", "Palette") == Tokens.ACCENT and _theme.get_color("font_color", "Label") == Tokens.TEXT \
			and _theme.get_constant("separation", "FormRow") == Tokens.FORM_GAP \
			and _theme.get_constant("margin_top", "PanelMarginWide") == Tokens.PANEL_MARGIN_WIDE_Y \
			and (_theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).bg_color == Tokens.PANEL
	_check("The tokens arrive in the theme (font, sizes, button colours and padding, accent, text, spacing, panels); rerun tools/make_ui_theme.gd if this fails",
			arrived, "button fill %s, padding %.0f, accent %s" % [button.bg_color, button.content_margin_left, _theme.get_color("accent", "Palette")])


## The roles added for the mode choice and the new screens (D-131, D-132).
func _test_new_roles() -> void:
	var holder := Control.new()
	add_child(holder)
	var hero := _variation_node(Label.new(), "HeroLabel", holder)
	var mode_title := _variation_node(Label.new(), "ModeTitleLabel", holder)
	var mode_detail := _variation_node(Label.new(), "ModeDetailLabel", holder)
	var primary := _variation_node(Button.new(), "PrimaryButton", holder)
	var text_button := _variation_node(Button.new(), "TextButton", holder)
	var mode_button := _variation_node(Button.new(), "ModeButton", holder)
	var segments := _variation_node(HBoxContainer.new(), "SegmentRow", holder)
	var modes := _variation_node(VBoxContainer.new(), "ModeList", holder)
	_check("The new roles take their tokens: the hero and mode titles' sizes, the dim mode detail, a primary button framed in its colour, a text button with no box at rest, the mode button's padding, the segment and mode spacing",
			hero.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO and mode_title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE
					and mode_detail.get_theme_color("font_color") == Tokens.TEXT_DIM
					and (primary.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Tokens.ACCENT
					and text_button.get_theme_stylebox("normal") is StyleBoxEmpty and text_button.get_theme_color("font_color") == Tokens.TEXT_DIM
					and text_button.get_theme_stylebox("focus") is StyleBoxFlat
					and mode_button.get_theme_stylebox("normal") is StyleBoxFlat and _theme.get_constant("margin_left", "ModeMargin") == Tokens.MODE_BUTTON_PAD_X
					and segments.get_theme_constant("separation") == Tokens.SEGMENT_GAP and modes.get_theme_constant("separation") == Tokens.MODE_GAP,
			"hero %d px, primary border %s, text button rest %s" % [hero.get_theme_font_size("font_size"),
					(primary.get_theme_stylebox("normal") as StyleBoxFlat).border_color, text_button.get_theme_stylebox("normal").get_class()])
	_check("The palette has the UI's team colours (D-134: the mockup's blue and red, for text and lines on ink)",
			_theme.get_color("friendly_text", "Palette") == Tokens.FRIENDLY
					and _theme.get_color("enemy_text", "Palette") == Tokens.ENEMY,
			"friendly %s, enemy %s" % [_theme.get_color("friendly_text", "Palette"), _theme.get_color("enemy_text", "Palette")])
	remove_child(holder)
	holder.queue_free()


## The roles the settings screen is built from (M10 task 10, D-137) take their tokens: the spacing of its column,
## rows and groups, the wide segments, the Back and Reset buttons, the key slots (a cap, plain text, listening), the
## table row's line, the swatch's frame, and the tab strip the mockup draws (the underline as wide as the word).
func _test_settings_roles() -> void:
	var holder := Control.new()
	add_child(holder)
	var column := _variation_node(VBoxContainer.new(), "SettingsColumn", holder)
	var flush := _variation_node(HBoxContainer.new(), "FlushRow", holder)
	var stack := _variation_node(VBoxContainer.new(), "StackBox", holder)
	var group := _variation_node(VBoxContainer.new(), "GroupBox", holder)
	_check("The settings screen's spacing roles take their tokens: its column 24 apart, rows whose parts sit edge to edge, rows that touch, and a group 16 apart",
			column.get_theme_constant("separation") == Tokens.SETTINGS_GAP and flush.get_theme_constant("separation") == Tokens.FLUSH_GAP
					and stack.get_theme_constant("separation") == Tokens.STACK_GAP and group.get_theme_constant("separation") == Tokens.GROUP_GAP,
			"column %d, flush %d, stack %d, group %d" % [column.get_theme_constant("separation"), flush.get_theme_constant("separation"),
					stack.get_theme_constant("separation"), group.get_theme_constant("separation")])
	var segment := _variation_node(Button.new(), "SegmentButton", holder)
	var wide := _variation_node(Button.new(), "WideSegmentButton", holder)
	var wide_pressed := wide.get_theme_stylebox("pressed") as StyleBoxFlat
	_check("The wide segment is the Play screen's segment with 16 px either side instead of 12: the same chosen fill (TEXT) and text colours",
			segment.get_theme_stylebox("normal").content_margin_left == Tokens.SEGMENT_PAD_X and wide.get_theme_stylebox("normal").content_margin_left == Tokens.SEGMENT_WIDE_PAD_X
					and wide.get_theme_stylebox("normal").content_margin_top == Tokens.SEGMENT_PAD_TOP and wide_pressed.bg_color == Tokens.TEXT
					and wide.get_theme_color("font_color") == Tokens.TEXT_DIM and wide.get_theme_color("font_pressed_color") == Tokens.TEXT_ON_FILL,
			"padding %s / %s, chosen fill %s" % [segment.get_theme_stylebox("normal").content_margin_left, wide.get_theme_stylebox("normal").content_margin_left, wide_pressed.bg_color])
	var dim := _variation_node(Button.new(), "DimButton", holder)
	var strong := _variation_node(Button.new(), "StrongButton", holder)
	var strong_normal := strong.get_theme_stylebox("normal") as StyleBoxFlat
	var plain := Button.new()
	holder.add_child(plain)
	_check("The Reset button is the plain button (a MUTE frame) with DIM text and the Back button has a TEXT frame, TEXT text and 24 px either side; both are 40 high",
			dim.get_theme_color("font_color") == Tokens.TEXT_DIM and (dim.get_theme_stylebox("normal") as StyleBoxFlat).border_color == Tokens.BUTTON_BORDER
					and strong_normal.border_color == Tokens.TEXT and strong_normal.border_width_left == Tokens.BORDER
					and strong_normal.content_margin_left == Tokens.STRONG_BUTTON_PAD_X and strong.get_theme_color("font_color") == Tokens.TEXT
					and strong_normal.content_margin_top + strong_normal.content_margin_bottom == Tokens.BUTTON_PAD_TOP + Tokens.BUTTON_PAD_BOTTOM,
			"reset text %s, back frame %s, back padding %s" % [dim.get_theme_color("font_color"), strong_normal.border_color, strong_normal.content_margin_left])
	var cap := _variation_node(Button.new(), "KeyCapButton", holder)
	var slot := _variation_node(Button.new(), "KeySlotButton", holder)
	var listening := _variation_node(Button.new(), "ListeningKeyButton", holder)
	var cap_normal := cap.get_theme_stylebox("normal") as StyleBoxFlat
	var listening_normal := listening.get_theme_stylebox("normal") as StyleBoxFlat
	_check("A key slot is 26 high (1 + 21 + 4 px with the line box): the first a key cap (a LINE frame, TEXT text, 10 px either side), the second plain MUTE text with no box, the one waiting for a key filled with the accent in ink text",
			cap_normal.border_color == Tokens.LINE_COLOR and cap_normal.border_width_top == Tokens.BORDER and cap.get_theme_color("font_color") == Tokens.TEXT
					and cap_normal.content_margin_left == Tokens.KEY_SLOT_PAD_X
					and cap_normal.content_margin_top + cap_normal.content_margin_bottom + _theme.default_font.get_height(Tokens.TEXT_SIZE) == 26.0
					and slot.get_theme_stylebox("normal") is StyleBoxEmpty and slot.get_theme_color("font_color") == Tokens.MUTE
					and listening_normal.bg_color == Tokens.ACCENT and listening.get_theme_color("font_color") == Tokens.TEXT_ON_FILL
					and (listening.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == Tokens.ACCENT,
			"cap frame %s, slot text %s, listening fill %s" % [cap_normal.border_color, slot.get_theme_color("font_color"), listening_normal.bg_color])
	var row := _variation_node(PanelContainer.new(), "TableRowPanel", holder)
	var row_box := row.get_theme_stylebox("panel") as StyleBoxFlat
	var swatch := _variation_node(Button.new(), "SwatchButton", holder)
	var swatch_margin := _variation_node(MarginContainer.new(), "SwatchMargin", holder)
	_check("A table row has a %d px PANEL line along its top and nothing else; a swatch's cell draws nothing at rest and a %d px accent frame around the chosen colour, with the colour inset by the gap and the frame (%d px)" % [Tokens.LINE, Tokens.BORDER, Tokens.SWATCH_MARGIN],
			row_box.border_width_top == Tokens.LINE and row_box.border_width_bottom == 0 and row_box.border_width_left == 0
					and row_box.border_color == Tokens.PANEL_OPAQUE and row_box.bg_color.a == 0.0
					and swatch.get_theme_stylebox("normal") is StyleBoxEmpty and (swatch.get_theme_stylebox("pressed") as StyleBoxFlat).border_color == Tokens.ACCENT
					and (swatch.get_theme_stylebox("pressed") as StyleBoxFlat).draw_center == false
					and swatch_margin.get_theme_constant("margin_left") == Tokens.SWATCH_MARGIN,
			"row line %s %d px, swatch chosen %s" % [row_box.border_color, row_box.border_width_top, (swatch.get_theme_stylebox("pressed") as StyleBoxFlat).border_color])
	var tabs := TabContainer.new()
	holder.add_child(tabs)
	var tab_selected := tabs.get_theme_stylebox("tab_selected") as StyleBoxFlat
	var line_page := tabs.get_theme_stylebox("panel") as StyleBoxFlat
	_check("The tab strip is the mockup's: 8 above the text and 14 below (12 plus the part of the underline above the line), the underline 4 px in the accent and as wide as the word (the side padding is cut off it), the line under all tabs 2 px LINE, the page's padding putting the first row at y = 176, and the strip starting one padding left of the page so the first word is at its edge",
			tab_selected.content_margin_top == Tokens.TAB_PAD_TOP and tab_selected.content_margin_bottom == Tokens.TAB_PAD_BOTTOM
					and tab_selected.border_width_bottom == Tokens.TAB_UNDERLINE and tab_selected.expand_margin_bottom == Tokens.BORDER
					and tab_selected.expand_margin_left == -Tokens.TAB_PAD_X and tab_selected.expand_margin_right == -Tokens.TAB_PAD_X
					and line_page.border_width_top == Tokens.LINE and line_page.border_color == Tokens.LINE_COLOR
					and line_page.content_margin_top == Tokens.TAB_PAGE_PAD_TOP
					and tabs.get_theme_constant("side_margin") == -Tokens.TAB_PAD_X
					and 104 + Tokens.TAB_PAD_TOP + _theme.default_font.get_height(Tokens.TEXT_SIZE) + Tokens.TAB_PAD_BOTTOM + Tokens.TAB_PAGE_PAD_TOP == 176,
			"underline %d, expand %s / %s, page padding %s, strip ends at %d" % [tab_selected.border_width_bottom, tab_selected.expand_margin_left,
					tab_selected.expand_margin_right, line_page.content_margin_top,
					104 + Tokens.TAB_PAD_TOP + _theme.default_font.get_height(Tokens.TEXT_SIZE) + Tokens.TAB_PAD_BOTTOM])
	remove_child(holder)
	holder.queue_free()


## The roles that replaced what menus once set per node (M10, D-131): team-coloured scores and the match
## result, the console's font, the crosshair swatches' spacing, the dim behind a modal menu, and the two
## palette colours the scoreboard table reads.
func _test_restyle_roles() -> void:
	var holder := Control.new()
	add_child(holder)
	var friendly_score := _variation_node(Label.new(), "FriendlyScoreLabel", holder)
	var enemy_score := _variation_node(Label.new(), "EnemyScoreLabel", holder)
	var victory := _variation_node(Label.new(), "VictoryLabel", holder)
	var defeat := _variation_node(Label.new(), "DefeatLabel", holder)
	var friendly_text := Tokens.FRIENDLY
	var enemy_text := Tokens.ENEMY
	_check("Team-coloured text is a role: friendly and enemy scores are 48 px in the UI's team colours (D-134), 'Victory' and 'Defeat' 96 px Bold in the same two colours",
			friendly_score.get_theme_color("font_color") == friendly_text and enemy_score.get_theme_color("font_color") == enemy_text
					and victory.get_theme_color("font_color") == friendly_text and defeat.get_theme_color("font_color") == enemy_text
					and friendly_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE and enemy_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE
					and victory.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO and defeat.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO
					and victory.get_theme_font("font").resource_path == Tokens.FONT_BOLD,
			"friendly %s, enemy %s, scores %d px, result %d px" % [friendly_score.get_theme_color("font_color"), enemy_score.get_theme_color("font_color"),
					friendly_score.get_theme_font_size("font_size"), victory.get_theme_font_size("font_size")])
	var console_label := _variation_node(Label.new(), "ConsoleLabel", holder)
	var console_input := _variation_node(LineEdit.new(), "ConsoleLineEdit", holder)
	var plain := Label.new()
	holder.add_child(plain)
	var label_font := console_label.get_theme_font("font") as SystemFont
	var input_font := console_input.get_theme_font("font") as SystemFont
	_check("The console roles use a system font built from the FONT_MONO_NAMES token (not the pixel font), at the body size",
			label_font != null and input_font != null and label_font.font_names == PackedStringArray(Tokens.FONT_MONO_NAMES)
					and input_font.font_names == label_font.font_names and plain.get_theme_font("font").resource_path == FONT_PATH
					and console_label.get_theme_font_size("font_size") == Tokens.TEXT_SIZE and console_input.get_theme_font_size("font_size") == Tokens.TEXT_SIZE,
			"label font %s, input font %s" % [label_font.font_names if label_font != null else "none", input_font.font_names if input_font != null else "none"])
	var swatch_row := _variation_node(HBoxContainer.new(), "SwatchRow", holder)
	var swatch_margin := _variation_node(MarginContainer.new(), "SwatchMargin", holder)
	var backdrop := _variation_node(Panel.new(), "BackdropPanel", holder)
	var backdrop_box := backdrop.get_theme_stylebox("panel") as StyleBoxFlat
	_check("The swatch row spaces by SWATCH_GAP and each swatch's margin is SWATCH_MARGIN on all four sides; the backdrop panel is a plain BACKDROP fill with no frame",
			swatch_row.get_theme_constant("separation") == Tokens.SWATCH_GAP
					and [swatch_margin.get_theme_constant("margin_left"), swatch_margin.get_theme_constant("margin_top"),
							swatch_margin.get_theme_constant("margin_right"), swatch_margin.get_theme_constant("margin_bottom")] == [Tokens.SWATCH_MARGIN, Tokens.SWATCH_MARGIN, Tokens.SWATCH_MARGIN, Tokens.SWATCH_MARGIN]
					and backdrop_box != null and backdrop_box.bg_color == Tokens.BACKDROP and backdrop_box.border_width_left == 0,
			"gap %d, margin %d, backdrop %s" % [swatch_row.get_theme_constant("separation"), swatch_margin.get_theme_constant("margin_left"),
					backdrop_box.bg_color if backdrop_box != null else "none"])
	_check("The table's two colours live in the palette: dead_row (a dead player's row is multiplied by it) is the DEAD_ROW token, and the your-row band is the YOU_ROW token",
			_theme.get_color("dead_row", "Palette") == Tokens.DEAD_ROW and (_theme.get_stylebox("panel", "YouRowPanel") as StyleBoxFlat).bg_color == Tokens.YOU_ROW,
			"dead_row %s, your row %s" % [_theme.get_color("dead_row", "Palette"), (_theme.get_stylebox("panel", "YouRowPanel") as StyleBoxFlat).bg_color])
	remove_child(holder)
	holder.queue_free()


## The icon slots (D-131): named, filled from assets/ui/icons/ through the theme, scaled like any theme icon.
func _test_icon_slots() -> void:
	var slots := UiIcons.all_slots()
	var unique := {}
	for slot in slots:
		unique[slot] = true
	var class_ids: Array = ClassData.all().map(func(data: ClassData) -> StringName: return data.id)
	_check("There are 21 icon slots with unique names (8 weapons, 3 grenades, armor, helmet, defuse kit, bomb, the 4 classes by their ids, headshot, health)",
			slots.size() == 21 and unique.size() == 21 and UiIcons.CLASSES.all(func(id: StringName) -> bool: return class_ids.has(id))
					and slots.has(&"headshot") and slots.has(&"health"),
			"%d slots, %d unique, class ids %s" % [slots.size(), unique.size(), class_ids])
	var holder := Label.new()
	add_child(holder)
	var mismatched: Array[String] = []
	for slot in slots:
		if ResourceLoader.exists(UiIcons.path_for(slot)) != UiIcons.has_icon(holder, slot) \
				or (UiIcons.get_icon(holder, slot) == null) == UiIcons.has_icon(holder, slot):
			mismatched.append(String(slot))
	_check("A slot holds an icon exactly when its PNG is in assets/ui/icons/; an empty slot answers null, so the screen shows text",
			mismatched.is_empty(), "slots that disagree with the folder: %s" % [mismatched])
	remove_child(holder)
	holder.queue_free()
	# A theme with one slot filled, as the theme tool makes it when a PNG exists.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var icon := ImageTexture.create_from_image(image)
	var with_icon := Theme.new()
	with_icon.set_icon(&"headshot", UiIcons.THEME_TYPE, icon)
	var menu := Control.new()
	menu.theme = with_icon
	var inside := Label.new()
	menu.add_child(inside)
	add_child(menu)
	var found := UiIcons.get_icon(inside, &"headshot")
	var empty := UiIcons.get_icon(inside, &"no_such_slot")
	menu.theme = UiTheme.scale_theme(with_icon, 1.5)
	var scaled := UiIcons.get_icon(inside, &"headshot")
	_check("A filled slot gives its icon to every control under the theme, an unfilled one null, and in a theme scaled by 1.5 the 16 px icon is 24 px",
			found == icon and empty == null and scaled != null and scaled.get_size() == Vector2(24, 24),
			"found %s, empty %s, scaled %s" % [found, empty, scaled.get_size() if scaled != null else "none"])
	remove_child(menu)
	menu.queue_free()


## UiTheme.scaled(): everything the theme holds, multiplied.
func _test_scaled_theme() -> void:
	var scaled := UiTheme.scaled(1.5)
	var twice := UiTheme.scaled(1.5)
	var unscaled_sizes: Array[String] = []
	for type in _theme.get_type_list():
		for item in _theme.get_font_size_list(type):
			if scaled.get_font_size(item, type) != roundi(_theme.get_font_size(item, type) * 1.5):
				unscaled_sizes.append("%s/%s" % [type, item])
	_check("Scaling the theme by 1.5 multiplies every font size (16 → 24, 32 → 48, 48 → 72 today), and 1.0 is the theme itself; a factor is built once",
			unscaled_sizes.is_empty() and scaled.default_font_size == _x(Tokens.TEXT_SIZE, 1.5)
					and scaled.get_font_size("font_size", "TitleLabel") == _x(Tokens.TEXT_SIZE_TITLE, 1.5)
					and scaled.get_font_size("font_size", "ScoreLabel") == _x(Tokens.TEXT_SIZE_TITLE, 1.5) and UiTheme.scaled(1.0) == _theme and scaled == twice
					and scaled != _theme,
			"mismatches: %s, default size %d" % [unscaled_sizes, scaled.default_font_size])
	var base_normal := _theme.get_stylebox("normal", "Button") as StyleBoxFlat
	var scaled_normal := scaled.get_stylebox("normal", "Button") as StyleBoxFlat
	var base_tab := _theme.get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	var scaled_tab := scaled.get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	var base_line := _theme.get_stylebox("separator", "HSeparator") as StyleBoxLine
	var scaled_line := scaled.get_stylebox("separator", "HSeparator") as StyleBoxLine
	_check("Styleboxes scale too: the button's border and padding (2 → 3, 14 / 8 → 21 / 12 today), a tab's covering edge, a separator; the colors stay, and the original is untouched",
			scaled_normal.border_width_left == _x(Tokens.BORDER, 1.5) and scaled_normal.content_margin_left == _x(Tokens.BUTTON_PAD_X, 1.5)
					and scaled_normal.content_margin_top == _x(Tokens.BUTTON_PAD_TOP, 1.5)
					and scaled_normal.bg_color == base_normal.bg_color and base_normal.border_width_left == Tokens.BORDER
					and base_normal.content_margin_left == Tokens.BUTTON_PAD_X
					and scaled_tab.expand_margin_bottom == _x(Tokens.BORDER, 1.5) and base_tab.expand_margin_bottom == Tokens.BORDER
					and scaled_line.thickness == _x(Tokens.LINE, 1.5) and base_line.thickness == Tokens.LINE,
			"button border %d, padding %.0f / %.0f, tab edge %.0f, separator %d" % [
					scaled_normal.border_width_left, scaled_normal.content_margin_left, scaled_normal.content_margin_top,
					scaled_tab.expand_margin_bottom, scaled_line.thickness])
	var base_icon := _theme.get_icon("checked", "CheckBox")
	var scaled_icon := scaled.get_icon("checked", "CheckBox")
	var source_colors := _image_colors(base_icon.get_image())
	var scaled_colors := _image_colors(scaled_icon.get_image())
	var no_new_colors := scaled_colors.all(func(color: Color) -> bool: return source_colors.has(color))
	_check("Icons scale with nearest-neighbor, so pixel art stays crisp: the 16 px check box becomes 24 px with no blended colors; the 16 px slider knob 24 px",
			scaled_icon.get_size() == Vector2(24, 24) and scaled_icon.get_image().get_size() == Vector2i(24, 24) and no_new_colors
					and base_icon.get_size() == Vector2(16, 16)
					and scaled.get_icon("grabber", "HSlider").get_size() == Vector2(24, 24),
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
	var constants_ok := scaled.get_constant("margin_left", "PanelMargin") == _x(Tokens.PANEL_MARGIN_X, 1.5) \
			and scaled.get_constant("separation", "ContentBox") == _x(Tokens.CONTENT_GAP, 1.5) \
			and scaled.get_constant("separation", "ScoreRow") == _x(Tokens.SCORE_GAP, 1.5) \
			and scaled_switches.get_constant("center_grabber", "HSlider") == 1 and scaled_switches.get_constant("separation", "VBoxContainer") == 12
	_check("Spacing scales (margin 16 → 24, separation 8 → 12, 14 → 21 today) but a yes/no setting such as the slider's center_grabber doesn't (1 stays 1)",
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
	_check("A menu at 1.0 uses the theme as designed: body and title sizes, padding and panel border from the tokens, button minimum 200 × 40, a one-off spacing override of 10 and font override of 20",
			layout == _expected_menu_sizes(1.0), "%s" % [layout])
	_check("Scaled by 1.5 every size is exactly 1.5 times as big: fonts, padding, minimum 300 × 60, the overrides 15 and 30, the drop-down's font, the panel border",
			at_one_and_a_half == _expected_menu_sizes(1.5), "%s" % [at_one_and_a_half])
	_check("Applying the same factor again changes nothing, 2.0 doubles everything, and 1.0 puts the original sizes back",
			again == at_one_and_a_half and at_two == _expected_menu_sizes(2.0) and back == layout,
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
	_check("A part scaled on its own doesn't keep its theme: scaling the whole menu back to 1.0 puts it at the body size again",
			inner_size == Tokens.TEXT_SIZE, "inner label %d px" % inner_size)
	# A CanvasLayer root (the match-end screen, the HUD) hands the theme to its controls.
	var layer := CanvasLayer.new()
	var layer_control := Label.new()
	layer.add_child(layer_control)
	add_child(layer)
	UiTheme.apply(layer, 1.5)
	var layer_size := layer_control.get_theme_font_size("font_size")
	_check("A CanvasLayer isn't a Control, so UiTheme gives the theme to the controls under it (a label there gets 1.5 times the body size)",
			layer_size == _x(Tokens.TEXT_SIZE, 1.5) and layer_control.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
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
			forced_hover.border_color == theme_hover.border_color and (normal.get_theme_stylebox("normal") as StyleBoxFlat).border_color != theme_hover.border_color
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
	_check("The developer console is themed (a ConsolePanel with a line along its bottom edge, a themed input line, no overrides of its own), the body size at 1.0 and 1.5 times it at 1.5, its panel 360 → 540 px minimum height (18 lines, D-065)",
			panel.theme_type_variation == &"ConsolePanel" and style != null and style.border_color == Tokens.LINE_COLOR
					and not output.has_theme_font_size_override("font_size") and not panel.has_theme_stylebox_override("panel")
					and base_size == Tokens.TEXT_SIZE and scaled_size == _x(Tokens.TEXT_SIZE, 1.5) and scaled_input == _x(Tokens.TEXT_SIZE, 1.5)
					and panel.custom_minimum_size.y == 360.0
					and (input.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == _theme.get_stylebox("normal", "LineEdit").bg_color,
			"font %d → %d, input %d, panel minimum back at %.0f" % [base_size, scaled_size, scaled_input, panel.custom_minimum_size.y])
	var output_font := output.get_theme_font("font") as SystemFont
	var input_font := input.get_theme_font("font") as SystemFont
	_check("The console's monospace font comes from the theme (ConsoleLabel and ConsoleLineEdit, the FONT_MONO_NAMES token), not from the scene: the output and the input line use it, with no font override of their own",
			output.theme_type_variation == &"ConsoleLabel" and input.theme_type_variation == &"ConsoleLineEdit"
					and output_font != null and input_font != null and output_font.font_names == PackedStringArray(Tokens.FONT_MONO_NAMES)
					and input_font.font_names == output_font.font_names and not output.has_theme_font_override("font") and not input.has_theme_font_override("font"),
			"output font %s, input font %s" % [output_font.font_names if output_font != null else "none", input_font.font_names if input_font != null else "none"])
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
					and yours.theme_type_variation == &"YouRowPanel" and (yours.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.YOU_ROW
					and (header.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.FRIENDLY
					and (enemy_header.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.ENEMY
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
	var board_yours := board.get_node("Center/Panel/Margin/Content/Score/YourScore") as Label
	var board_theirs := board.get_node("Center/Panel/Margin/Content/Score/EnemyScore") as Label
	_check("Its scores are team-coloured by theme variations, with the colours the per-node overrides once gave: yours a FriendlyScoreLabel in your team's text colour, theirs an EnemyScoreLabel in the enemy's",
			board_yours.theme_type_variation == &"FriendlyScoreLabel" and board_theirs.theme_type_variation == &"EnemyScoreLabel"
					and board_yours.get_theme_color("font_color") == Tokens.FRIENDLY
					and board_theirs.get_theme_color("font_color") == Tokens.ENEMY,
			"yours %s, theirs %s" % [board_yours.get_theme_color("font_color"), board_theirs.get_theme_color("font_color")])
	var overrides := _style_or_size_overrides(board)
	_check("Nothing in the scoreboard carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	board.set_ui_scale(1.5)
	await get_tree().process_frame
	var row_label := yours.find_children("*", "Label", true, false)[0] as Label
	var score := board.get_node("Center/Panel/Margin/Content/Score/YourScore") as Label
	var stat_width := (yours.find_children("*", "Label", true, false)[1] as Label).custom_minimum_size.x
	var separation := (table.get_node("Team0") as VBoxContainer).get_theme_constant("separation")
	_check("Scaled by 1.5 the scoreboard is exactly 1.5 times as big: panel 640 → 960 minimum width, rows 16 → 24 px, scores 32 → 48 px, number columns 96 → 144, the gap between rows 2 → 3",
			panel.custom_minimum_size.x == 960.0 and row_label.get_theme_font_size("font_size") == 24
					and score.get_theme_font_size("font_size") == _x(Tokens.TEXT_SIZE_TITLE, 1.5)
					and stat_width == 144.0 and separation == _x(Tokens.TEAM_ROW_GAP, 1.5),
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
			panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"VictoryLabel"
					and title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO and play_again.get_theme_font_size("font_size") == 16
					and (main_menu_button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left == Tokens.BORDER
					and (main_menu_button.get_theme_stylebox("focus") as StyleBoxFlat).border_color == _theme.get_color("accent", "Palette"),
			"panel '%s', title %d px, button %d px" % [panel.theme_type_variation, title.get_theme_font_size("font_size"), play_again.get_theme_font_size("font_size")])
	var your_score := screen.get_node("Panel/Margin/Content/Score/YourScore") as Label
	var their_score := screen.get_node("Panel/Margin/Content/Score/EnemyScore") as Label
	_check("The result and the scores are team-coloured by theme variations, with the colours the per-node overrides once gave: 'Victory' and your score in your team's text colour (32 px scores, 48 px title), theirs in the enemy's",
			your_score.theme_type_variation == &"FriendlyScoreLabel" and their_score.theme_type_variation == &"EnemyScoreLabel"
					and title.get_theme_color("font_color") == Tokens.FRIENDLY
					and your_score.get_theme_color("font_color") == Tokens.FRIENDLY
					and their_score.get_theme_color("font_color") == Tokens.ENEMY
					and title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO
					and your_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE and their_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE,
			"title %s, yours %s, theirs %s" % [title.get_theme_color("font_color"), your_score.get_theme_color("font_color"), their_score.get_theme_color("font_color")])
	var overrides := _style_or_size_overrides(screen)
	_check("Nothing in the match-end screen carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	screen.set_ui_scale(1.5)
	await get_tree().process_frame
	var row_label := table.get_row(_player).find_children("*", "Label", true, false)[0] as Label
	_check("Scaled by 1.5: panel 760 → 1140, title 48 → 72 px, buttons 16 → 24 px and 200 × 40 → 300 × 60, table rows 16 → 24 px",
			panel.custom_minimum_size.x == 1140.0 and title.get_theme_font_size("font_size") == _x(Tokens.TEXT_SIZE_HERO, 1.5)
					and play_again.get_theme_font_size("font_size") == 24 and play_again.custom_minimum_size == Vector2(300, 60)
					and row_label.get_theme_font_size("font_size") == 24,
			"panel %.0f, title %d, button %d (%s), row %d" % [
					panel.custom_minimum_size.x, title.get_theme_font_size("font_size"), play_again.get_theme_font_size("font_size"),
					play_again.custom_minimum_size, row_label.get_theme_font_size("font_size")])
	screen.set_ui_scale(1.0)
	await get_tree().process_frame
	_check("Back at 1.0 everything returns to its design size (panel 760, title 48, row 16)",
			panel.custom_minimum_size.x == 760.0 and title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO
					and (table.get_row(_player).find_children("*", "Label", true, false)[0] as Label).get_theme_font_size("font_size") == 16,
			"panel %.0f, title %d" % [panel.custom_minimum_size.x, title.get_theme_font_size("font_size")])
	remove_child(screen)
	screen.queue_free()


## M10 (D-131): no menu or overlay carries a theme override of its own (a colour, font, size, spacing,
## style or icon set on a node), so changing the tokens in tools/ui_palette.gd restyles every one of
## them. Builds each screen the way the game does (the match-end screen after its match ended, the Tab
## scoreboard while held) and lists the controls that carry any override.
func _test_menus_have_no_overrides() -> void:
	# The finder itself: it must see overrides of every kind, or a clean result would mean nothing.
	var scratch := Control.new()
	add_child(scratch)
	var label := Label.new()
	var box := HBoxContainer.new()
	var panel := Panel.new()
	var line := LineEdit.new()
	var check_box := CheckBox.new()
	var clean := Label.new()
	for control: Control in [label, box, panel, line, check_box, clean]:
		scratch.add_child(control)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 20)
	box.add_theme_constant_override("separation", 3)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	line.add_theme_font_override("font", ThemeDB.fallback_font)
	check_box.add_theme_icon_override("checked", PlaceholderTexture2D.new())
	var seen: Array[String] = []
	for control: Control in [label, box, panel, line, check_box]:
		seen.append_array(_override_names(control))
	seen.sort()
	_check("The override finder sees a colour, a font size, a spacing, a style, a font and an icon override, and none on a clean control",
			seen == ["colors/font_color", "constants/separation", "font_sizes/font_size", "fonts/font", "icons/checked", "styles/panel"]
					and _override_names(clean).is_empty() and _overrides_below(scratch).size() == 5,
			"found %s" % [seen])
	remove_child(scratch)
	scratch.queue_free()

	var found := {}
	var settings_menu := await _new_menu()
	settings_menu.open()
	await get_tree().process_frame
	found["settings menu"] = _overrides_below(settings_menu)
	settings_menu.close()
	_free_menu(settings_menu)
	var pause_menu := PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(pause_menu)
	await get_tree().process_frame
	found["pause menu"] = _overrides_below(pause_menu)
	remove_child(pause_menu)
	pause_menu.queue_free()
	var class_menu := CLASS_MENU_SCENE.instantiate() as ClassMenu
	add_child(class_menu)
	await get_tree().process_frame
	found["class menu"] = _overrides_below(class_menu)
	remove_child(class_menu)
	class_menu.queue_free()
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	await get_tree().process_frame
	found["console"] = _overrides_below(console)
	remove_child(console)
	console.queue_free()
	var main_menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	main_menu.load_settings = false
	add_child(main_menu)
	await get_tree().process_frame
	await get_tree().process_frame
	found["main menu (with its match setup and settings menu)"] = _overrides_below(main_menu)
	remove_child(main_menu)
	main_menu.queue_free()
	await get_tree().process_frame
	MenuState.reset()
	var setup := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	setup.settings = Settings.new()
	add_child(setup)
	await get_tree().process_frame
	setup.open()
	found["match setup"] = _overrides_below(setup)
	setup.close()
	remove_child(setup)
	setup.queue_free()
	MenuState.reset()
	await _new_match()
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	Input.action_press("scoreboard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	found["Tab scoreboard (shown)"] = _overrides_below(board) if board.visible else ["not shown"]
	Input.action_release("scoreboard")
	remove_child(board)
	board.queue_free()
	# The other team wins, so the screen shows 'Defeat' and the enemy's colours.
	await _new_match(1)
	var screen := MATCH_END_SCENE.instantiate() as MatchEndScreen
	add_child(screen)
	screen.set_round_manager(_rounds)
	await _win_round(1)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	await get_tree().physics_frame
	await get_tree().physics_frame
	found["match-end screen (Defeat)"] = _overrides_below(screen) if screen.visible else ["not shown"]
	var result := screen.get_node("Panel/Margin/Content/Title") as Label
	var your_score := screen.get_node("Panel/Margin/Content/Score/YourScore") as Label
	var their_score := screen.get_node("Panel/Margin/Content/Score/EnemyScore") as Label
	_check("After a lost match the title is a DefeatLabel in the enemy team's text colour, while the scores keep their own team colours (yours friendly, theirs enemy), all from the theme",
			result.text == "Defeat" and result.theme_type_variation == &"DefeatLabel"
					and result.get_theme_color("font_color") == Tokens.ENEMY
					and your_score.get_theme_color("font_color") == Tokens.FRIENDLY
					and their_score.get_theme_color("font_color") == Tokens.ENEMY,
			"title '%s' %s, yours %s, theirs %s" % [result.text, result.get_theme_color("font_color"), your_score.get_theme_color("font_color"), their_score.get_theme_color("font_color")])
	remove_child(screen)
	screen.queue_free()
	var offenders := {}
	for screen_name: String in found:
		if not (found[screen_name] as Array).is_empty():
			offenders[screen_name] = found[screen_name]
	_check("No menu or overlay carries a theme override of its own (colour, font, size, spacing, style or icon): the settings, pause and class menus, the console, the main menu with match setup, the Tab scoreboard and the match-end screen all take their whole look from the theme",
			offenders.is_empty(), "screens checked: %d, overrides found: %s" % [found.size(), offenders])


# --- The HUD (M10 task 6, D-133) ---


## The HUD's roles exist on the right base types and carry the tokens: sizes and
## outlines of the labels, the top bar's boxes (the team colours from Teams, darkened),
## the spacing, and the custom "Hud" type that code reads the game-state colours from.
func _test_hud_roles() -> void:
	var missing: Array[String] = []
	for variation: String in HUD_VARIATIONS:
		if _theme.get_type_variation_base(variation) != StringName(HUD_VARIATIONS[variation]):
			missing.append(variation)
	_check("All %d HUD roles exist, each on the right base type" % HUD_VARIATIONS.size(), missing.is_empty(),
			"missing or on another base: %s" % [missing])
	var holder := Control.new()
	add_child(holder)
	var value := _variation_node(Label.new(), "HudValueLabel", holder)
	var title := _variation_node(Label.new(), "HudTitleLabel", holder)
	var timer := _variation_node(Label.new(), "HudTimerLabel", holder)
	var tag := _variation_node(Label.new(), "HudBombTagLabel", holder)
	_check("The HUD's label roles take their tokens: the health and ammo number is HUD_SIZE_VALUE with its outline, the centre title HUD_SIZE_TITLE, the timer HUD_SIZE_SCORE with no outline, the bomb tag the gold; all outlined in the HUD's outline colour",
			value.get_theme_font_size("font_size") == Tokens.HUD_SIZE_VALUE and value.get_theme_constant("outline_size") == Tokens.HUD_OUTLINE_VALUE
					and title.get_theme_font_size("font_size") == Tokens.HUD_SIZE_TITLE and title.get_theme_constant("outline_size") == Tokens.HUD_OUTLINE_TITLE
					and timer.get_theme_font_size("font_size") == Tokens.HUD_SIZE_SCORE and timer.get_theme_constant("outline_size") == Tokens.HUD_OUTLINE_SCORE
					and tag.get_theme_color("font_color") == Tokens.HUD_GOLD and value.get_theme_color("font_outline_color") == Tokens.HUD_OUTLINE
					and value.get_theme_font("font").resource_path == FONT_PATH,
			"value %d px / %d, title %d px / %d, timer %d px, tag %s" % [value.get_theme_font_size("font_size"), value.get_theme_constant("outline_size"),
					title.get_theme_font_size("font_size"), title.get_theme_constant("outline_size"), timer.get_theme_font_size("font_size"), tag.get_theme_color("font_color")])
	var friendly := _variation_node(PanelContainer.new(), "HudFriendlyBox", holder)
	var enemy := _variation_node(PanelContainer.new(), "HudEnemyBox", holder)
	var friendly_box := friendly.get_theme_stylebox("panel") as StyleBoxFlat
	var enemy_box := enemy.get_theme_stylebox("panel") as StyleBoxFlat
	var margin := _variation_node(MarginContainer.new(), "HudBoxMargin", holder)
	var bar := _variation_node(HBoxContainer.new(), "HudTopBar", holder)
	_check("The top bar's roles: the team boxes are Teams' friendly and enemy colours darkened by the token at the token's opacity, the box margin has its four paddings, the bar its spacing",
			friendly_box.bg_color == Color(Teams.FRIENDLY_COLOR.darkened(Tokens.HUD_SCORE_BOX_DARKEN), Tokens.HUD_SCORE_BOX_ALPHA)
					and enemy_box.bg_color == Color(Teams.ENEMY_COLOR.darkened(Tokens.HUD_SCORE_BOX_DARKEN), Tokens.HUD_SCORE_BOX_ALPHA)
					and margin.get_theme_constant("margin_left") == Tokens.HUD_BOX_PAD_X and margin.get_theme_constant("margin_top") == Tokens.HUD_BOX_PAD_TOP
					and margin.get_theme_constant("margin_right") == Tokens.HUD_BOX_PAD_X and margin.get_theme_constant("margin_bottom") == Tokens.HUD_BOX_PAD_BOTTOM
					and bar.get_theme_constant("separation") == Tokens.HUD_BAR_GAP,
			"friendly %s, enemy %s, margin %d / %d, gap %d" % [friendly_box.bg_color, enemy_box.bg_color, margin.get_theme_constant("margin_left"),
					margin.get_theme_constant("margin_top"), bar.get_theme_constant("separation")])
	_check("The custom 'Hud' type holds what code reads: the freeze-time timer, the alert, the notice, the bomb's gold, the dead square and the square's size",
			_theme.get_color("freeze_timer", "Hud") == Tokens.HUD_FREEZE_TIMER and _theme.get_color("alert", "Hud") == Tokens.HUD_ALERT
					and _theme.get_color("notice", "Hud") == Tokens.HUD_NOTICE and _theme.get_color("gold", "Hud") == Tokens.HUD_GOLD
					and _theme.get_color("pip_dead", "Hud") == Tokens.HUD_PIP_DEAD and _theme.get_constant("pip_size", "Hud") == Tokens.HUD_PIP_SIZE,
			"freeze %s, alert %s, pip size %d" % [_theme.get_color("freeze_timer", "Hud"), _theme.get_color("alert", "Hud"), _theme.get_constant("pip_size", "Hud")])
	remove_child(holder)
	holder.queue_free()


## The HUD's scenes carry no theme override (their looks are roles) and the two
## scripts that colour game states hold no colour literal: whatever colour they use
## comes from the theme or from Teams.
func _test_hud_scenes_use_the_theme() -> void:
	var overrides: Array[String] = []
	for path in HUD_SCENES:
		var count := _theme_override_count(FileAccess.get_file_as_string(path))
		if count > 0:
			overrides.append("%s (%d)" % [path, count])
	_check("The HUD scenes (hud, round HUD, bomb HUD) have no theme_override_ line: sizes, outlines, colours and spacing are roles",
			overrides.is_empty(), "scenes with overrides: %s" % [overrides])
	var literals: Array[String] = []
	for path in HUD_SCRIPTS:
		for line in _color_literal_lines(FileAccess.get_file_as_string(path)):
			literals.append("%s: %s" % [path, line])
	_check("The round HUD and bomb HUD scripts have no Color( literal: every colour comes from the theme or from Teams",
			literals.is_empty(), "literals: %s" % [literals])
	# The scans must see what they look for, or a clean result would mean nothing.
	var made_up := "[node name=\"A\"]\ntheme_override_font_sizes/font_size = 24\nvar c := Color(1, 0, 0)\n# Color(0, 0, 0) in a comment\nvar d := Color.WHITE"
	_check("The two scans do find an override line and a colour literal in a made-up source, and skip comments and named colours",
			_theme_override_count(made_up) == 1 and _color_literal_lines(made_up) == ["var c := Color(1, 0, 0)"],
			"overrides %d, literals %s" % [_theme_override_count(made_up), _color_literal_lines(made_up)])


## How many lines of the scene text [param source] set a theme override.
func _theme_override_count(source: String) -> int:
	return source.count("theme_override_")


## The lines of the GDScript [param source] that write a colour literal, `Color(...)` (comments and
## named colours such as `Color.WHITE` don't count).
func _color_literal_lines(source: String) -> Array[String]:
	var found: Array[String] = []
	for line in source.split("\n"):
		var code := line.strip_edges()
		if not code.begins_with("#") and code.contains("Color("):
			found.append(code)
	return found


## The F3 overlay starts hidden (a first look at the game shows the game, D-133); F3
## (the toggle_debug action) shows it and hides it again.
func _test_debug_overlay() -> void:
	MenuState.reset()
	var main: Node = await _new_game()
	var overlay := main.get_node("DebugOverlay") as CanvasLayer
	var hidden_at_first := not overlay.visible
	_send(_action_event("toggle_debug"))
	var shown := overlay.visible
	_send(_action_event("toggle_debug"))
	var hidden_again := not overlay.visible
	_check("The F3 overlay starts hidden, F3 shows it and F3 hides it again",
			hidden_at_first and shown and hidden_again,
			"hidden at first %s, shown after F3 %s, hidden after F3 again %s" % [hidden_at_first, shown, hidden_again])
	main.queue_free()
	await get_tree().process_frame
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false
	Settings.get_instance().reset_to_defaults()


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
		var has_control := menu.get_slider(key) != null or not menu.get_toggle(key).is_empty() or not menu.get_option(key).is_empty()
		# The [match] section is match setup's, not the settings menu's.
		if not has_control and key != &"crosshair_color" and Settings.SCHEMA[key]["section"] != "match":
			uncovered.append(key)
	var background := menu.get_node("Background") as Panel
	var page := menu.get_node("Page") as MarginContainer
	var title := menu.get_node("Page/Column/TitleBox/Title") as Label
	_check("The settings menu is hidden until opened and builds the tabs Game, Video, Audio, Crosshair and Controls on a full ink page (a click-stopping InkPanel, the page margin) under a 48 px title",
			not menu.visible and menu.get_tab_names() == ["Game", "Video", "Audio", "Crosshair", "Controls"]
					and background.theme_type_variation == &"InkPanel" and background.mouse_filter == Control.MOUSE_FILTER_STOP
					and page.theme_type_variation == &"PageMargin" and page.get_theme_constant("margin_left") == Tokens.PAGE_MARGIN_X
					and title.theme_type_variation == &"TitleLabel" and title.text == "Settings"
					and title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE,
			"visible %s, tabs %s, background '%s', page '%s', title '%s' %d px" % [menu.visible, menu.get_tab_names(),
					background.theme_type_variation, page.theme_type_variation, title.text, title.get_theme_font_size("font_size")])
	var fps_texts := _texts(menu.get_option(&"fps_cap"))
	var pixel_slider := menu.get_slider(&"pixel_height")
	_check("Every setting has a control: sliders with value boxes (sensitivity, FOV, the volumes, the pixel resolution over its %d steps), sliders with plain numbers on the Crosshair tab, OFF / ON segments for the yes / no settings, segments for the frame limit (60, 120, 144, 240, None) and colour swatches with a hex field" % Settings.PIXEL_HEIGHTS.size(),
			uncovered.is_empty() and menu.get_swatches().size() == SettingsMenu.CROSSHAIR_COLORS.size() and menu.get_hex_field() != null
					and menu.get_slider(&"crosshair_opacity") != null and menu.get_field(&"crosshair_opacity") == null
					and menu.get_field(&"sensitivity") != null and menu.get_field(&"master_volume") != null and menu.get_field(&"pixel_height") != null
					and fps_texts == ["60", "120", "144", "240", "None"] and menu.get_toggle(&"fullscreen").size() == 2
					and pixel_slider.min_value == 0.0 and pixel_slider.max_value == Settings.PIXEL_HEIGHTS.size() - 1,
			"settings without a control: %s, %d swatches, frame limits %s, pixel slider 0..%s" % [
					uncovered, menu.get_swatches().size(), fps_texts, pixel_slider.max_value])
	var unnamed: Array[StringName] = []
	var wrong_text: Array[String] = []
	for action: StringName in Settings.BINDABLE_ACTIONS:
		var label := menu.get_action_label(action)
		if not SettingsMenu.ACTION_NAMES.has(action) or label == null or label.text != SettingsMenu.ACTION_NAMES[action] or label.text.contains("_"):
			unnamed.append(action)
		for slot in Settings.BINDING_SLOTS:
			if menu.get_binding_button(action, slot) == null:
				wrong_text.append("%s/%d missing" % [action, slot])
	var forward := [menu.get_binding_button(&"move_forward", 0).text, menu.get_binding_button(&"move_forward", 1).text]
	var jump := [menu.get_binding_button(&"jump", 0).text, menu.get_binding_button(&"jump", 1).text]
	var shoot := menu.get_binding_button(&"shoot", 0).text
	var console_key := menu.get_binding_button(&"toggle_console", 0).text
	_check("The Controls tab has a row per bindable action (all %d) with a readable name and two slots that show the keys: W and an empty slot, Space and Wheel Down, Left Mouse, ` for the console" % Settings.BINDABLE_ACTIONS.size(),
			unnamed.is_empty() and wrong_text.is_empty() and forward == ["W", SettingsMenu.EMPTY_SLOT_TEXT] and jump == ["Space", "Wheel Down"]
					and shoot == "Left Mouse" and console_key == "`",
			"unnamed %s, forward %s, jump %s, shoot '%s', console '%s'" % [unnamed, forward, jump, shoot, console_key])
	_free_menu(menu)


## The settings screen has the mockup's structure (D-137), in design pixels: rows 48 high with a 400 px label and
## controls after it, a slider group 480 px wide with an 80 × 32 value box, OFF / ON segments, the Crosshair tab's
## 240 px labels, 28 px swatches and two 240 px squares, the Controls table's header and 34 px rows with a
## key cap and plain text, and the footer's two buttons; every look is a theme role.
func _test_settings_menu_look() -> void:
	var menu := await _new_menu()
	var row := menu.get_row(&"sensitivity")
	var label := row.get_child(0) as Label
	var group := menu.get_slider(&"sensitivity").get_parent() as HBoxContainer
	var box := menu.get_field(&"sensitivity")
	var pixel_box := menu.get_field(&"pixel_height")
	_check("A slider row is 48 high: a 400 px DimLabel, then a 480 px group with the slider (which fills the room) and an 80 × 32 value box with centred text, 16 px apart; the pixel resolution's box is 112 wide and reads '480 L'",
			row.theme_type_variation == &"FlushRow" and row.custom_minimum_size.y == 48.0 and row.get_combined_minimum_size() == Vector2(880, 48)
					and label.theme_type_variation == &"DimLabel" and label.custom_minimum_size.x == 400.0
					and group.theme_type_variation == &"RowBox" and group.custom_minimum_size.x == 480.0
					and menu.get_slider(&"sensitivity").size_flags_horizontal & Control.SIZE_EXPAND == Control.SIZE_EXPAND
					and box.custom_minimum_size.x == 80.0 and box.get_combined_minimum_size().y == 32.0 and box.alignment == HORIZONTAL_ALIGNMENT_CENTER
					and pixel_box.custom_minimum_size.x == 112.0 and pixel_box.text == "480 L",
			"row %s, label %s, group %s, box %s / %s, pixel box '%s' %s" % [row.get_combined_minimum_size(), label.custom_minimum_size.x,
					group.custom_minimum_size.x, box.custom_minimum_size.x, box.get_combined_minimum_size().y, pixel_box.text, pixel_box.custom_minimum_size.x])
	var off_on := menu.get_toggle(&"invert_y")
	var frame := off_on[0].get_parent().get_parent() as PanelContainer
	var fps := menu.get_option(&"fps_cap")
	var one_group := true
	for button in off_on:
		one_group = one_group and button.toggle_mode and button.theme_type_variation == &"WideSegmentButton" and button.button_group == off_on[0].button_group
	for button in fps:
		one_group = one_group and button.button_group == fps[0].button_group
	_check("A yes / no setting is OFF / ON segments, not a check box: a SegmentFrame around two toggle buttons of the wide segment role in one button group, OFF chosen by default; the frame limit is five segments with None last",
			frame.theme_type_variation == &"SegmentFrame" and off_on[0].text == "Off" and off_on[1].text == "On" and one_group
					and off_on[0].button_pressed and not off_on[1].button_pressed and off_on[0].get_parent().theme_type_variation == &"SegmentRow"
					and fps.size() == 5 and fps[4].text == "None"
					and fps[4].button_pressed and menu.get_custom_segment(&"fps_cap") != null and not menu.get_custom_segment(&"fps_cap").visible,
			"frame '%s', texts %s / %s, frame limit %s" % [frame.theme_type_variation, off_on[0].text, off_on[1].text, _texts(fps)])
	var swatches := menu.get_swatches()
	var colours: Array[Color] = []
	for swatch in swatches:
		colours.append(((swatch.get_child(0) as MarginContainer).get_child(0) as ColorRect).color)
	var crosshair_label := menu.get_row(&"crosshair_gap").get_child(0) as Label
	var crosshair_group := menu.get_slider(&"crosshair_gap").get_parent() as Control
	var number := menu.get_slider(&"crosshair_gap").get_parent().get_child(1) as Label
	var cells_ok := true
	for swatch in swatches:
		cells_ok = cells_ok and swatch.theme_type_variation == &"SwatchButton" and swatch.custom_minimum_size == Vector2(36, 36)
	_check("The Crosshair tab: five swatches in the mockup's colours (#36D07A, #FFFFFF, #FFE14A, #FF5AD1, #48F0E0), each a 28 px colour in a 36 px cell, the chosen one framed by the theme; opacity, size, gap and thickness have 240 px labels and a group that takes the rest of the 640 px column (400 px) and ends in a plain right-aligned 48 px number (no box)",
			swatches.size() == 5 and colours == [Color("36d07a"), Color("ffffff"), Color("ffe14a"), Color("ff5ad1"), Color("48f0e0")] and cells_ok
					and swatches[0].button_pressed and not swatches[1].button_pressed
					and crosshair_label.custom_minimum_size.x == 240.0 and crosshair_group.size_flags_horizontal & Control.SIZE_EXPAND != 0
					and number.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and number.custom_minimum_size.x == 48.0 and number.text == "4"
					and menu.get_field(&"crosshair_gap") == null and menu.get_value_text(&"crosshair_gap") == "4",
			"colours %s, label %s, group flags %s, number '%s' %s" % [colours, crosshair_label.custom_minimum_size.x, crosshair_group.size_flags_horizontal, number.text, number.horizontal_alignment])
	var previews := menu.get_previews()
	var samples: Array[Control] = []
	var fills: Array[Color] = []
	for preview in previews:
		samples.append(preview.get_parent() as Control)
		fills.append(((preview.get_parent() as Control).get_child(0) as ColorRect).color)
	var side_by_side := samples[0].get_parent() == samples[1].get_parent() and samples[0].get_index() + 1 == samples[1].get_index()
	var squares_ok := true
	for sample in samples:
		squares_ok = squares_ok and sample.custom_minimum_size == Vector2(240, 240) and sample.clip_contents
	for preview in previews:
		squares_ok = squares_ok and preview.get_script() == load("res://ui/crosshair.gd") and preview.anchor_right == 1.0 and preview.anchor_bottom == 1.0
	_check("Two preview squares side by side, 240 × 240, dark #23272A and light #C9D0D2, each with a real Crosshair filling it (so it is drawn centred), and a MUTE caption 'Live preview · dark / light' under them",
			previews.size() == 2 and squares_ok and fills[0].is_equal_approx(Color("23272a")) and fills[1].is_equal_approx(Color("c9d0d2")) and side_by_side,
			"%d previews, squares ok %s, fills %s" % [previews.size(), squares_ok, fills])
	var caption := samples[0].get_parent().get_parent().get_child(1) as Label
	_check("The caption reads 'Live preview · dark / light' in the MUTE role",
			caption.text == "Live preview · dark / light" and caption.theme_type_variation == &"MuteLabel", "'%s' %s" % [caption.text, caption.theme_type_variation])
	var jump_label := menu.get_action_label(&"jump")
	var jump_row := jump_label.get_parent().get_parent() as PanelContainer
	var cap := menu.get_binding_button(&"jump", 0)
	var plain := menu.get_binding_button(&"jump", 1)
	var empty := menu.get_binding_button(&"move_forward", 1)
	var header := menu.get_node("Page/Column/Tabs/Controls/Header") as Control
	var header_muted := true
	for index in 3:
		header_muted = header_muted and (header.get_child(index) as Label).theme_type_variation == &"MuteLabel"
	_check("The Controls table: a header row ACTION / KEY 1 / KEY 2 in MUTE (32 high, 240 px key columns), rows 34 high with a 2 px line on top in a table-row panel, the action in DIM, key 1 as a key cap, key 2 as plain text, an empty slot as '-'",
			(header.get_child(0) as Label).text == "Action" and (header.get_child(1) as Label).text == "Key 1" and (header.get_child(2) as Label).text == "Key 2"
					and header_muted and header.custom_minimum_size.y == 32.0 and (header.get_child(1) as Control).custom_minimum_size.x == 240.0
					and jump_row.theme_type_variation == &"TableRowPanel" and jump_row.custom_minimum_size.y == 34.0
					and jump_label.theme_type_variation == &"DimLabel" and cap.theme_type_variation == &"KeyCapButton"
					and plain.theme_type_variation == &"KeySlotButton" and plain.text == "Wheel Down" and empty.text == "-"
					and cap.get_parent().custom_minimum_size.x == 240.0 and plain.get_parent().custom_minimum_size.x == 240.0,
			"header %s, row %s, caps '%s' / '%s', empty '%s'" % [(header.get_child(1) as Label).text, jump_row.theme_type_variation, cap.theme_type_variation, plain.theme_type_variation, empty.text])
	var reset := menu.get_reset_button()
	var back := menu.get_back_button()
	_check("The footer has 'Reset tab to defaults' (the DIM-text, MUTE-frame button) on the left and 'Back' (the TEXT-framed one) on the right, both 40 high",
			reset.text == "Reset tab to defaults" and reset.theme_type_variation == &"DimButton" and back.text == "Back" and back.theme_type_variation == &"StrongButton"
					and reset.get_combined_minimum_size().y == 40.0 and back.get_combined_minimum_size().y == 40.0
					and reset.get_index() < back.get_index() and reset.get_parent() == back.get_parent(),
			"reset '%s' %s %s px, back '%s' %s %s px" % [reset.text, reset.theme_type_variation, reset.get_combined_minimum_size().y, back.text, back.theme_type_variation, back.get_combined_minimum_size().y])
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
	_check("Sensitivity: the slider and the value box write to Settings and agree (2.50 from the slider, 1.25 typed with a comma, 99 clamped to 10.00, text that is no number put back)",
			by_slider and by_field and clamped and refused,
			"slider %s, field %s, clamped %s, refused %s" % [by_slider, by_field, clamped, refused])
	var invert := menu.get_toggle(&"invert_y")
	invert[1].button_pressed = true
	var invert_on := settings.invert_y and invert[1].button_pressed and not invert[0].button_pressed
	invert[0].button_pressed = true
	var invert_off := not settings.invert_y and invert[0].button_pressed and not invert[1].button_pressed
	var fps := menu.get_option(&"fps_cap")
	fps[2].button_pressed = true
	var fps_144 := settings.fps_cap == 144 and Engine.max_fps == 144 and fps[2].button_pressed and not fps[4].button_pressed and fps[2].text == "144"
	fps[4].button_pressed = true
	var fps_unlimited := settings.fps_cap == 0 and fps[4].button_pressed and not fps[2].button_pressed and fps[4].text == "None"
	var pixels := menu.get_slider(&"pixel_height")
	var pixel_box := menu.get_field(&"pixel_height")
	pixels.value = Settings.PIXEL_HEIGHTS.find(360)
	var pixels_360 := settings.pixel_height == 360 and pixel_box.text == "360 L"
	pixel_box.text_submitted.emit("540")
	var pixels_typed := settings.pixel_height == 540 and pixels.value == Settings.PIXEL_HEIGHTS.find(540) and pixel_box.text == "540 L"
	pixel_box.text_submitted.emit("500")
	var pixels_snapped := settings.pixel_height == 480
	_check("OFF / ON segments, the frame-limit segments and the pixel-resolution slider write to Settings: invert Y on and off (one lit at a time), a frame limit of 144 (which reaches the engine) and None, 360 L from the slider, 540 typed, and 500 typed snaps to the nearest real step (480)",
			invert_on and invert_off and fps_144 and fps_unlimited and pixels_360 and pixels_typed and pixels_snapped,
			"invert on %s, off %s, 144 %s, none %s, 360 L %s, 540 typed %s, snapped to %d" % [invert_on, invert_off, fps_144, fps_unlimited, pixels_360, pixels_typed, settings.pixel_height])
	var volume := menu.get_slider(&"master_volume")
	var volume_field := menu.get_field(&"master_volume")
	volume.value = 0.5
	var half := is_equal_approx(settings.master_volume, 0.5) and volume_field.text == "50"
	volume_field.text_submitted.emit("25%")
	var quarter := is_equal_approx(settings.master_volume, 0.25) and is_equal_approx(volume.value, 0.25) and volume_field.text == "25" \
			and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Settings.BUS_MASTER)), linear_to_db(0.25))
	_check("A volume slider is a percentage: 0.5 reads 50, typing 25% sets 0.25 on the slider, the setting and the audio bus",
			half and quarter, "half %s, quarter %s, master %.2f" % [half, quarter, settings.master_volume])
	settings.master_volume = 0.29
	var rounded := volume_field.text == "29"
	settings.crosshair_color = Color(0.2, 1.0, 0.2, 0.9)
	rounded = rounded and menu.get_value_text(&"crosshair_opacity") == "90"
	_check("A whole-number field rounds instead of cutting the decimals off: a volume of 0.29 reads 29 (not 28) and an opacity of 0.9 reads 90",
			rounded, "volume '%s', opacity '%s'" % [volume_field.text, menu.get_value_text(&"crosshair_opacity")])
	settings.reset_to_defaults()
	# The other direction: the settings change, the controls follow.
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	var custom := menu.get_custom_segment(&"fps_cap")
	settings.sensitivity = 2.25
	settings.invert_y = true
	settings.fps_cap = 75
	var custom_text := custom.text
	var custom_shown := custom.visible and custom.button_pressed and not fps.any(func(button: Button) -> bool: return button.button_pressed)
	settings.fps_cap = 60
	var custom_gone := not custom.visible and fps[0].button_pressed
	settings.pixel_height = 270
	settings.master_volume = 0.3
	settings.crosshair_color = Color("ff5ad1")
	var hex := menu.get_hex_field()
	_check("A change to Settings updates the controls: sensitivity (slider and box), invert Y, a hand-set frame limit of 75 shown as its own '75 (custom)' segment and gone again, 270 L, 30, and the crosshair colour (swatch, hex code and opacity)",
			is_equal_approx(slider.value, 2.25) and field.text == "2.25" and invert[1].button_pressed and not invert[0].button_pressed
					and custom_text == "75 (custom)" and custom_shown and custom_gone
					and pixels.value == 0.0 and pixel_box.text == "270 L" and volume_field.text == "30"
					and menu.get_swatches()[3].button_pressed and not menu.get_swatches()[0].button_pressed and hex.text == "#FF5AD1"
					and menu.get_value_text(&"crosshair_opacity") == "100" and is_equal_approx(menu.get_slider(&"crosshair_opacity").value, 1.0),
			"sensitivity %s / '%s', frame limit '%s' shown %s gone %s, hex '%s'" % [slider.value, field.text, custom_text, custom_shown, custom_gone, hex.text])
	console.run("sensitivity 3")
	_check("A console command changes the sensitivity while the menu exists and the slider and box move with it",
			is_equal_approx(slider.value, 3.0) and field.text == "3.00", "slider %s, field '%s'" % [slider.value, field.text])
	# Opening the menu reads everything again.
	slider.set_value_no_signal(9.0)
	field.text = "junk"
	invert[1].set_pressed_no_signal(false)
	invert[0].set_pressed_no_signal(true)
	menu.open()
	_check("Opening the menu reads every value from Settings again (a slider, a box and a segment that had drifted are right)",
			is_equal_approx(slider.value, 3.0) and field.text == "3.00" and invert[1].button_pressed and not invert[0].button_pressed,
			"slider %s, field '%s', invert on %s" % [slider.value, field.text, invert[1].button_pressed])
	menu.close()
	console.queue_free()
	_free_menu(menu)
	settings.reset_to_defaults()


## The live crosshair previews are real Crosshairs that follow the settings.
func _test_crosshair_preview() -> void:
	var settings := Settings.get_instance()
	var menu := await _new_menu()
	var previews := menu.get_previews()
	var preview := menu.get_preview()
	_check("Both previews show the current style (the mockup's green, 7 px lines, gap 4, thickness 2, outlined) and the first one is the dark square's",
			previews.size() == 2 and preview == previews[0] and previews.all(_is_default_crosshair),
			"%d previews, color %s, length %s, gap %s" % [previews.size(), preview.color, preview.length, preview.gap])
	menu.get_swatches()[3].pressed.emit()
	var pink := Color("ff5ad1")
	var chosen := previews.all(func(each: Crosshair) -> bool: return each.color.is_equal_approx(pink)) and settings.crosshair_color.is_equal_approx(pink)
	menu.get_slider(&"crosshair_opacity").value = 0.5
	var faded := previews.all(func(each: Crosshair) -> bool: return is_equal_approx(each.color.a, 0.5) and each.color.is_equal_approx(Color(pink, 0.5)))
	menu.get_hex_field().text_submitted.emit("#336699")
	var typed := previews.all(func(each: Crosshair) -> bool: return each.color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.5))) and menu.get_hex_field().text == "#336699" \
			and not menu.get_swatches().any(func(swatch: Button) -> bool: return swatch.button_pressed)
	menu.get_hex_field().text_submitted.emit("not a color")
	var kept := preview.color.is_equal_approx(Color(0.2, 0.4, 0.6, 0.5))
	_check("The previews follow the colour: a swatch picks pink, the opacity slider fades it to 50 (the number says 50), a typed #336699 keeps the opacity (and lights no swatch), a bad code changes nothing",
			chosen and faded and typed and kept and menu.get_value_text(&"crosshair_opacity") == "50",
			"chosen %s, faded %s, typed %s, kept %s" % [chosen, faded, typed, kept])
	menu.get_slider(&"crosshair_length").value = 12.0
	menu.get_slider(&"crosshair_gap").value = 9.0
	menu.get_slider(&"crosshair_thickness").value = 4.0
	menu.get_toggle(&"crosshair_outline")[0].button_pressed = true
	menu.get_toggle(&"crosshair_dot")[1].button_pressed = true
	menu.get_toggle(&"crosshair_dynamic")[1].button_pressed = true
	_check("They follow the sizes and styles: length 12, gap 9, thickness 4, no outline, a dot, dynamic (and the plain numbers read 12, 9, 4)",
			previews.all(func(each: Crosshair) -> bool: return each.length == 12.0 and each.gap == 9.0 and each.thickness == 4.0 and not each.outline and each.dot and each.dynamic)
					and menu.get_value_text(&"crosshair_length") == "12" and menu.get_value_text(&"crosshair_gap") == "9" and menu.get_value_text(&"crosshair_thickness") == "4",
			"length %s, gap %s, thickness %s, outline %s, dot %s, dynamic %s" % [preview.length, preview.gap, preview.thickness, preview.outline, preview.dot, preview.dynamic])
	# Dynamic mode shows the gap opening while the menu is up.
	menu.open()
	for i in 20:
		await get_tree().process_frame
	var breathing := previews.all(func(each: Crosshair) -> bool: return each.spread_degrees > 0.0 and each._spread_in_pixels() > 0.0)
	menu.close()
	_check("In dynamic mode both previews' gaps open by themselves while the menu is open (their spread comes from the menu's own pulse, as they have no camera)",
			breathing, "spread %.3f°, %.1f px" % [preview.spread_degrees, preview._spread_in_pixels()])
	# "Reset tab" puts back only the tab it is on.
	menu.open()
	settings.sensitivity = 4.0
	menu.get_tabs().current_tab = menu.get_tab_names().find("Crosshair")
	menu.get_reset_button().pressed.emit()
	var crosshair_back := previews.all(_is_default_crosshair)
	var segments_back := menu.get_toggle(&"crosshair_dot")[0].button_pressed and menu.get_toggle(&"crosshair_outline")[1].button_pressed
	_check("'Reset tab to defaults' on the Crosshair tab puts the whole crosshair back (the previews too) and leaves the other tabs alone (sensitivity stays 4.0)",
			crosshair_back and segments_back and settings.sensitivity == 4.0,
			"crosshair back %s, segments back %s, sensitivity %s" % [crosshair_back, segments_back, settings.sensitivity])
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
	_check("Clicking a slot makes it say 'Press a key...' in the listening role (lime fill, ink text) and its action's name brighter, and the menu waits: MenuState says it is capturing input",
			menu.is_listening() and slot.text == SettingsMenu.LISTENING_TEXT and slot.text == "Press a key..." and slot.button_pressed
					and slot.theme_type_variation == &"ListeningKeyButton" and menu.get_action_label(&"reload").theme_type_variation == &"BrightLabel"
					and menu.get_action_label(&"jump").theme_type_variation == &"DimLabel" and MenuState.capturing_input,
			"listening %s, text '%s', role '%s', capturing %s" % [menu.is_listening(), slot.text, slot.theme_type_variation, MenuState.capturing_input])
	_send(_key_event(KEY_T))
	_send(_key_event(KEY_T, false))
	var reload_events := InputMap.action_get_events(&"reload")
	var reload_keys: Array[Key] = []
	for event in reload_events:
		reload_keys.append((event as InputEventKey).physical_keycode)
	_check("The next key press is bound: reload now answers to R and T (in the settings and in the InputMap, for all devices), the slot shows T and the menu stops waiting",
			not menu.is_listening() and not MenuState.capturing_input and slot.text == "T" and not slot.button_pressed
					and slot.theme_type_variation == &"KeySlotButton" and menu.get_action_label(&"reload").theme_type_variation == &"DimLabel"
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


## The menu is exactly 1.5 times as big at 1.5: the theme's sizes, the rows, the columns and the preview squares.
func _test_menu_scaling() -> void:
	var menu := await _new_menu()
	var page := menu.get_node("Page") as MarginContainer
	var title_box := menu.get_node("Page/Column/TitleBox") as Control
	var title := title_box.get_child(0) as Label
	var back := menu.get_back_button()
	var slider := menu.get_slider(&"sensitivity")
	var row := menu.get_row(&"sensitivity")
	var label := row.get_child(0) as Label
	var group := slider.get_parent() as Control
	var swatch_margin := menu.get_swatches()[0].get_child(0) as MarginContainer
	var table_row := menu.get_action_label(&"jump").get_parent().get_parent() as Control
	var sample := menu.get_preview().get_parent() as Control
	menu.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var measure := func() -> Array:
		return [title.get_theme_font_size("font_size"), label.get_theme_font_size("font_size"), page.get_theme_constant("margin_left"),
				title_box.custom_minimum_size.y, row.custom_minimum_size.y, row.get_combined_minimum_size(), label.custom_minimum_size.x,
				group.custom_minimum_size.x, table_row.custom_minimum_size.y, sample.custom_minimum_size,
				swatch_margin.get_theme_constant("margin_left"), (back.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left,
				menu.get_preview().length]
	var at_one: Array = measure.call()
	menu.set_ui_scale(1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var at_one_and_a_half: Array = measure.call()
	var previews_scaled := menu.get_preview().thickness == 3.0 and menu.get_previews()[1].thickness == 3.0
	var overrides := _own_overrides(menu)
	menu.set_ui_scale(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var back_at_one: Array = measure.call()
	_check("At 1.0 the menu is as designed: a 48 px title in a 48 px box, 16 px rows, the 32 px page margin, 48 px rows with 400 px labels and 480 px slider groups (880 × 48 in all), 34 px table rows, 240 px preview squares, a 4 px swatch margin, a 24 px Back button padding, 7 px preview lines",
			at_one == [48, 16, Tokens.PAGE_MARGIN_X, 48.0, 48.0, Vector2(880, 48), 400.0, 480.0, 34.0, Vector2(240, 240), Tokens.SWATCH_MARGIN,
					float(Tokens.STRONG_BUTTON_PAD_X), 7.0],
			"%s" % [at_one])
	_check("Scaled by 1.5 everything is exactly 1.5 times as big: 72 / 24 px text, the 48 px page margin, 72 px rows with 600 px labels and 720 px groups (1320 × 72 in all), 51 px table rows, 360 px squares, the swatch margin 6, the Back padding 36, the previews' lines (thickness 3 px), and back at 1.0 it is as before",
			at_one_and_a_half == [72, 24, _x(Tokens.PAGE_MARGIN_X, 1.5), 72.0, 72.0, Vector2(1320, 72), 600.0, 720.0, 51.0, Vector2(360, 360),
					_x(Tokens.SWATCH_MARGIN, 1.5), float(_x(Tokens.STRONG_BUTTON_PAD_X, 1.5)), 11.0] and previews_scaled and back_at_one == at_one,
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
	await get_tree().physics_frame
	_close_class_menu(main)
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
	var label_minimum := (menu.get_row(&"sensitivity").get_child(0) as Control).custom_minimum_size
	var window_height := get_tree().root.size.y
	_check("main.gd scales the menu with the window like the other UI: its 400 px row labels are 400 times the window's height over 720 wide (the headless window is %d tall)" % window_height,
			label_minimum == (Vector2(400, 0) * (window_height / 720.0)).round(), "label minimum %s" % label_minimum)
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


## The main menu (D-135): the mockup's left column (the game's name and its chips,
## Play, Practice, Settings, Quit, Host and Join marked soon) over a background
## without a player, a calm camera flight, scaled with the window, and Esc.
func _test_main_menu() -> void:
	var settings := Settings.get_instance()
	MenuState.reset()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var texts: Array[String] = []
	var items_ok := true
	for button in menu.get_buttons():
		texts.append(button.text)
		items_ok = items_ok and button.theme_type_variation == &"BigButton" and button.visible and not button.disabled and button.icon != null
	var online: Array[String] = []
	for button in menu.get_online_buttons():
		online.append(button.text)
		items_ok = items_ok and button.disabled and button.theme_type_variation == &"SmallItemButton" \
				and (button.get_node("Soon") as Label).text == "Soon"
	var title := menu.get_node("Page/Logo/Title") as Label
	var side := menu.get_node("Page/Side") as Panel
	var chips: Array = menu.get_node("Page/Logo/Chips").get_children().map(func(chip: Node) -> String: return String((chip as Control).theme_type_variation))
	_check("The main menu is the mockup's column (D-135): CHIIP with a blue, a red and a lime chip; Play (focused), Practice, Settings and Quit as menu items with the focus chip; Host and Join disabled and marked soon; the mouse is free",
			title.text == "CHIIP" and title.theme_type_variation == &"LogoLabel" and side.theme_type_variation == &"SidePanel"
					and chips == ["FriendlyChip", "EnemyChip", "AccentChip"]
					and texts == ["Play", "Practice", "Settings", "Quit"] and online == ["Host", "Join"] and items_ok
					and menu.get_buttons()[0].has_focus() and MenuState.is_top(menu) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"title '%s', chips %s, items %s, online %s, focus on Play %s" % [title.text, chips, texts, online, menu.get_buttons()[0].has_focus()])
	var map_name := menu.get_node("Page/MapName") as Label
	var build := menu.get_node("Page/Build") as Label
	_check("The bottom corners say the build and the background's map (Test Map, with a hard shadow)",
			build.text.begins_with("Build") and map_name.text == "Test Map" and map_name.theme_type_variation == &"ShadowLabel",
			"build '%s', map '%s'" % [build.text, map_name.text])
	# What a match leaves for the game (prepare_* does what start_* does, without changing scenes).
	menu.prepare_mode("rounds")
	var bomb_launch := [GameLaunch.match_settings.game_mode, GameLaunch.map_path, GameLaunch.rotation.size(), settings.match_mode]
	GameLaunch.clear()
	settings.reset_to_defaults()
	menu.prepare_mode("respawn")
	var deathmatch_launch := [GameLaunch.match_settings.game_mode, GameLaunch.map_path, GameLaunch.rotation.duplicate(), settings.match_mode,
			GameLaunch.match_settings.kill_limit, GameLaunch.match_settings.team_size, GameLaunch.match_settings.time_limit]
	GameLaunch.clear()
	_check("Playing Bomb leaves bomb rounds and remembers Bomb; Team Deathmatch with the defaults leaves team respawn, first to 50 or 10 minutes, 3v3, on the rotation from Depot",
			bomb_launch == [MatchSettings.GameMode.ROUNDS, "res://maps/depot.tscn", 3, "rounds"]
					and deathmatch_launch == [MatchSettings.GameMode.TEAM_RESPAWN, "res://maps/depot.tscn",
							["res://maps/depot.tscn", "res://maps/square.tscn", "res://maps/spillway.tscn"], "respawn", 50, 3, 600.0],
			"bomb %s, deathmatch %s" % [bomb_launch, deathmatch_launch])
	settings.reset_to_defaults()

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
	var play_item := menu.get_buttons()[0]
	var items := menu.get_node("Page/Items") as Control
	# A headless window is 64 pixels tall and goes back to that every frame: change it and check in the same frame.
	window.size = Vector2i(1280, 720)
	menu.apply_pixel_settings()
	var at_720 := [world.stretch_shrink, items.offset_top, play_item.get_theme_font_size("font_size"),
			(menu.get_match_setup().get_node("Page/Column/Cards").get_child(0) as Control).custom_minimum_size.y, (menu.get_settings_menu().get_row(&"sensitivity").get_child(0) as Control).custom_minimum_size.x]
	window.size = Vector2i(1920, 1080)
	menu.apply_pixel_settings()
	var at_1080 := [world.stretch_shrink, items.offset_top, play_item.get_theme_font_size("font_size"),
			(menu.get_match_setup().get_node("Page/Column/Cards").get_child(0) as Control).custom_minimum_size.y, (menu.get_settings_menu().get_row(&"sensitivity").get_child(0) as Control).custom_minimum_size.x]
	settings.pixel_height = 270
	var low_res := world.stretch_shrink
	settings.pixel_height = 480
	_check("The background follows the video settings like the game: the palette effect switches with its setting, and in a 720-pixel window the world is 360 lines (scaled 2×), in a 1080 one 540 lines (2×), 270 lines gives 4×",
			effect_on and effect_off and at_720[0] == 2 and at_1080[0] == 2 and low_res == 4,
			"effect on %s, off %s; shrink %s at 720, %s at 1080, %d at 270 lines" % [effect_on, effect_off, at_720[0], at_1080[0], low_res])
	_check("The menus scale with the window like the other menus: at 720 the menu items sit 272 px down in 32 px text, the Play screen's cards are 192 high and the settings' row labels 400 wide; at 1080 exactly 1.5 times that",
			at_720 == [2, 272.0, Tokens.TEXT_SIZE_LARGE, 192.0, 400.0] and at_1080 == [2, 408.0, _x(Tokens.TEXT_SIZE_LARGE, 1.5), 288.0, 600.0],
			"720: %s, 1080: %s" % [at_720, at_1080])
	var overrides := _own_overrides(menu.get_node("Page")) + _own_overrides(menu.get_match_setup())
	_check("Nothing in the main page or the Play screen carries a stylebox or font-size override of its own, so the theme alone decides their look",
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
	var setup_opened := setup.is_open() and MenuState.is_top(setup) and setup.get_mode_cards()[0].has_focus()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var setup_closed := not setup.is_open() and MenuState.is_top(menu) and menu.get_buttons()[0].has_focus()
	menu.get_settings_button().pressed.emit()
	var settings_opened := settings_menu.is_open() and MenuState.is_top(settings_menu) and not setup.is_open()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var settings_closed := not settings_menu.is_open() and MenuState.is_top(menu) and menu.get_settings_button().has_focus()
	menu.get_buttons()[0].pressed.emit()
	setup.get_back_button().pressed.emit()
	var by_back := not setup.is_open() and MenuState.is_top(menu)
	_check("Esc does nothing on the main page; Play opens the Play screen (Team Deathmatch's card focused) and Esc closes it; Settings opens the settings menu and Esc closes it; Back closes match setup; the main menu stays the menu on the bottom of MenuState and the mouse stays free",
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


## The Play screen (D-135) on its own, with a Settings instance of its own: the
## cards, each mode's rows, the defaults, the controls, stored choices, the maps.
func _test_match_setup() -> void:
	# A Settings.new() only holds values: it never saves and never touches the engine.
	var stored := Settings.new()
	var setup := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	setup.settings = stored
	add_child(setup)
	await get_tree().process_frame
	var defaults := MatchSettings.new()
	var rules := setup.build_match_settings()
	var cards := setup.get_mode_cards()
	var team_buttons := setup.get_segment_buttons(&"match_team_size")
	var enemy_buttons := setup.get_segment_buttons(&"match_enemy_team_size")
	var difficulty_buttons := setup.get_segment_buttons(&"match_difficulty")
	var length_buttons := setup.get_segment_buttons(&"match_rounds_to_win")
	var kill_buttons := setup.get_segment_buttons(&"match_kill_limit")
	var time_buttons := setup.get_segment_buttons(&"match_time_limit")
	var fire_buttons := setup.get_segment_buttons(&"match_friendly_fire")
	var map_buttons := setup.get_segment_buttons(&"match_map")
	var card_names: Array = cards.map(func(card: Button) -> String: return (card.get_parent().find_children("Title", "Label", true, false)[0] as Label).text)
	_check("The Play screen is hidden until opened; it offers the three mode cards (Team Deathmatch, marked Default, then Bomb and Practice), and segments: the map (Depot, Square, Spillway, Rotation), kill limit 25 / 50 / 75 / 100, rounds 5 / 10 / 15, 5 / 10 / 15 min, Easy / Normal / Hard, friendly fire Off / On, five chips per team, Back and Play",
			not setup.visible and card_names == ["Team\nDeathmatch", "Bomb", "Practice"]
					and cards[0].get_parent().find_children("Default", "Label", true, false).size() == 1
					and _texts(map_buttons) == ["Depot", "Square", "Spillway", "Rotation"] and _texts(kill_buttons) == ["25", "50", "75", "100"]
					and _texts(length_buttons) == ["5", "10", "15"] and _texts(time_buttons) == ["5 min", "10 min", "15 min"]
					and _texts(difficulty_buttons) == ["Easy", "Normal", "Hard"] and _texts(fire_buttons) == ["Off", "On"]
					and team_buttons.size() == 5 and enemy_buttons.size() == 5
					and setup.get_back_button().text == "Back" and setup.get_start_button().text == "Play",
			"cards %s, map %s, kills %s, rounds %s, time %s" % [card_names, _texts(map_buttons), _texts(kill_buttons), _texts(length_buttons), _texts(time_buttons)])
	_check("The defaults are Team Deathmatch picked (its card framed, \"Click to play\"), 3v3, Normal bots, first to 50 kills or 10 minutes, friendly fire off, on the rotation from Depot; team sizes, difficulty, rounds and friendly fire equal MatchSettings' own (D-041)",
			setup.get_picked_mode() == "respawn" and cards[0].theme_type_variation == &"ModeButtonPicked" and cards[1].theme_type_variation == &"ModeButton"
					and setup.get_card_line("respawn") == "Click to play" and setup.get_card_line("rounds") == "First to 5 rounds"
					and _pressed(team_buttons) == 2 and _pressed(enemy_buttons) == 2 and _pressed(difficulty_buttons) == 1 and _pressed(kill_buttons) == 1
					and _pressed(time_buttons) == 1 and _pressed(fire_buttons) == 0 and _pressed(map_buttons) == 3
					and setup.get_map_path() == Settings.DEFAULT_MATCH_MAP and rules.game_mode == MatchSettings.GameMode.TEAM_RESPAWN
					and rules.kill_limit == 50 and rules.time_limit == 600.0
					and rules.team_size == defaults.team_size and rules.enemy_team_size == defaults.enemy_team_size
					and rules.bot_difficulty == defaults.bot_difficulty and rules.rounds_to_win == defaults.rounds_to_win
					and rules.friendly_fire == defaults.friendly_fire and rules.freeze_time == defaults.freeze_time and rules.round_time == defaults.round_time,
			"picked %s, pressed: team %d, enemy %d, difficulty %d, kills %d, time %d, map %d" % [setup.get_picked_mode(),
					_pressed(team_buttons), _pressed(enemy_buttons), _pressed(difficulty_buttons), _pressed(kill_buttons), _pressed(time_buttons), _pressed(map_buttons)])
	var chips_filled: Array = team_buttons.map(func(chip: Button) -> String: return String(chip.theme_type_variation))
	_check("Team Deathmatch shows its rows (map, kill limit, teams, match length, bots, friendly fire), not the rounds; the team chips are filled up to 3 in your colour, the rest empty",
			setup.is_row_shown(&"match_map") and setup.is_row_shown(&"match_kill_limit") and setup.is_row_shown(&"match_time_limit")
					and setup.is_row_shown(&"match_team_size") and not setup.is_row_shown(&"match_rounds_to_win")
					and chips_filled == ["FriendlyChipButton", "FriendlyChipButton", "FriendlyChipButton", "EmptyChipButton", "EmptyChipButton"]
					and (enemy_buttons[0] as Button).theme_type_variation == &"EnemyChipButton",
			"chips %s" % [chips_filled])
	var summary_before := setup.get_summary()

	# Picking Bomb: its rows, and changing them changes the match and what is stored.
	cards[1].pressed.emit()
	var bomb_rows := setup.is_row_shown(&"match_rounds_to_win") and not setup.is_row_shown(&"match_kill_limit") and not setup.is_row_shown(&"match_time_limit")
	(team_buttons[1] as Button).button_pressed = true
	(enemy_buttons[4] as Button).button_pressed = true
	(difficulty_buttons[2] as Button).button_pressed = true
	(length_buttons[2] as Button).button_pressed = true
	(fire_buttons[1] as Button).button_pressed = true
	rules = setup.build_match_settings()
	_check("A click on Bomb picks it (framed, its rows: rounds, no kill limit or time); pressing chip 2, chip 5, Hard, 15 and On gives 2 against 5, hard bots, first to 15, friendly fire on (the round timings stay at their defaults), each row with exactly one choice",
			setup.get_picked_mode() == "rounds" and stored.match_mode == "rounds" and cards[1].theme_type_variation == &"ModeButtonPicked" and bomb_rows
					and rules.game_mode == MatchSettings.GameMode.ROUNDS
					and rules.team_size == 2 and rules.enemy_team_size == 5 and rules.bot_difficulty.display_name == "hard" and rules.rounds_to_win == 15 and rules.friendly_fire
					and rules.freeze_time == defaults.freeze_time and rules.round_end_time == defaults.round_end_time
					and _pressed(team_buttons) == 1 and _pressed(enemy_buttons) == 4 and _pressed(difficulty_buttons) == 2
					and _pressed_count(team_buttons) == 1 and _pressed_count(enemy_buttons) == 1 and _pressed_count(difficulty_buttons) == 1
					and _pressed_count(length_buttons) == 1 and _pressed_count(fire_buttons) == 1,
			"picked %s, %d v %d, %s, first to %d, friendly fire %s" % [setup.get_picked_mode(), rules.team_size, rules.enemy_team_size,
					rules.bot_difficulty.display_name, rules.rounds_to_win, rules.friendly_fire])
	_check("The choices are stored in the Settings instance (its [match] values), and the summary follows them",
			stored.match_team_size == 2 and stored.match_enemy_team_size == 5 and stored.match_difficulty == "hard" and stored.match_rounds_to_win == 15
					and stored.match_friendly_fire and setup.get_summary() != summary_before and setup.get_summary().begins_with("Bomb: ")
					and setup.get_summary().contains("1 bot ") and setup.get_summary().contains("5 bots") and setup.get_summary().contains("Hard")
					and setup.get_summary().contains("first to 15"),
			"stored %d/%d/%s/%d/%s; summary '%s'" % [stored.match_team_size, stored.match_enemy_team_size, stored.match_difficulty,
					stored.match_rounds_to_win, stored.match_friendly_fire, setup.get_summary()])
	# A change from outside (the console, a loaded file) moves the buttons.
	stored.match_team_size = 5
	stored.match_difficulty = "easy"
	_check("A change made outside the screen moves the controls: team size 5 and Easy are chosen now",
			_pressed(team_buttons) == 4 and _pressed(difficulty_buttons) == 0 and _pressed_count(team_buttons) == 1 and _pressed_count(difficulty_buttons) == 1,
			"team %d, difficulty %d" % [_pressed(team_buttons), _pressed(difficulty_buttons)])
	stored.match_team_size = 2
	stored.match_difficulty = "hard"
	# Practice: only the bots' row; picking it doesn't change the stored match mode.
	cards[2].pressed.emit()
	var practice_rows := setup.is_row_shown(&"match_difficulty") and not setup.is_row_shown(&"match_map") and not setup.is_row_shown(&"match_team_size")
	_check("A click on Practice picks it: only the bots' row shows, the stored match mode stays Bomb, and its summary names the test map",
			setup.get_picked_mode() == "practice" and practice_rows and stored.match_mode == "rounds" and setup.get_summary().begins_with("Practice: "),
			"picked %s, stored %s, summary '%s'" % [setup.get_picked_mode(), stored.match_mode, setup.get_summary()])
	cards[1].pressed.emit()

	# The choices survive a restart: written to a file and read by another instance, they come back.
	_remove_temp_file()
	(map_buttons[1] as Button).button_pressed = true
	var saved := stored.save_to_disk(TEMP_PATH)
	var restarted := Settings.new()
	var loaded := restarted.load_from_disk(TEMP_PATH)
	var second := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	second.settings = restarted
	add_child(second)
	await get_tree().process_frame
	var again := second.build_match_settings()
	_check("After a restart (the choices saved to a file and loaded by a new Settings) the screen offers the same match: Bomb picked, 2 against 5, hard, first to 15, friendly fire on, Square alone",
			saved == OK and loaded == OK and second.get_picked_mode() == "rounds" and again.team_size == 2 and again.enemy_team_size == 5
					and again.bot_difficulty.display_name == "hard" and again.rounds_to_win == 15 and again.friendly_fire
					and _pressed(second.get_segment_buttons(&"match_team_size")) == 1 and _pressed(second.get_segment_buttons(&"match_difficulty")) == 2
					and _pressed(second.get_segment_buttons(&"match_rounds_to_win")) == 2 and _pressed(second.get_segment_buttons(&"match_map")) == 1
					and second.get_rotation_maps().is_empty() and second.get_map_path() == "res://maps/square.tscn",
			"save %d, load %d, %s, %d v %d, %s, first to %d" % [saved, loaded, second.get_picked_mode(), again.team_size, again.enemy_team_size,
					again.bot_difficulty.display_name, again.rounds_to_win])
	_remove_temp_file()
	remove_child(second)
	second.queue_free()

	# The map row: the quick maps (as on disk) and the rotation; a stored map that isn't one of them plays Depot.
	(map_buttons[3] as Button).button_pressed = true
	var rotation_from_square := setup.get_rotation_maps()
	stored.match_map = "res://maps/gone.tscn"
	var fell_back := setup.get_map_path() == Settings.DEFAULT_MATCH_MAP
	stored.match_rotation = false
	var none_pressed := _pressed_count(map_buttons) == 0
	_check("The map row offers the quick maps that exist (%s) and the rotation; the rotation starts on the chosen map (Square, Spillway, Depot); a stored map that isn't a quick map plays Depot and no map is shown chosen" % [setup.get_map_paths()],
			setup.get_map_paths() == GameLaunch.rotation_maps() and setup.get_map_paths().size() == 3
					and rotation_from_square == ["res://maps/square.tscn", "res://maps/spillway.tscn", "res://maps/depot.tscn"]
					and fell_back and none_pressed,
			"rotation %s, fell back %s, none pressed %s" % [rotation_from_square, fell_back, none_pressed])

	# Opening, Esc, Back, Play and a click on the picked card; scaling.
	var signals: Array[String] = []
	setup.started.connect(func() -> void: signals.append("started"))
	setup.closed.connect(func() -> void: signals.append("closed"))
	MenuState.reset()
	setup.open()
	var opened := setup.visible and MenuState.is_top(setup) and MenuState.blocks_gameplay() and cards[1].has_focus()
	setup.get_start_button().pressed.emit()
	cards[1].pressed.emit()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var by_esc := not setup.visible and not MenuState.is_any_open()
	setup.open()
	setup.get_back_button().pressed.emit()
	var by_back := not setup.visible and not MenuState.is_any_open()
	setup.close()
	_check("Opening puts the screen on top of MenuState with the stored mode's card focused; Play and a click on the picked card report `started` (the screen stays for the menu); Esc and Back close it and emit `closed` once each; closing again does nothing",
			opened and by_esc and by_back and signals == ["started", "started", "closed", "closed"],
			"opened %s, Esc %s, Back %s, signals %s" % [opened, by_esc, by_back, signals])
	var card := cards[0].get_parent() as Control
	var title := setup.get_node("Page/Column/Header/Title") as Label
	var segment := length_buttons[0] as Button
	setup.set_ui_scale(1.5)
	var scaled := [card.custom_minimum_size.y, title.get_theme_font_size("font_size"), segment.get_theme_font_size("font_size"), (team_buttons[0] as Button).custom_minimum_size]
	setup.set_ui_scale(1.0)
	var back_at_one := [card.custom_minimum_size.y, title.get_theme_font_size("font_size"), segment.get_theme_font_size("font_size"), (team_buttons[0] as Button).custom_minimum_size]
	_check("The Play screen is a full ink page with a Bold title and scales exactly: cards 192 high, a 48 px title, 16 px segments, 16 px chips at 1.0; 288 / 72 / 24 / 24 at 1.5",
			(setup.get_node("Background") as Control).theme_type_variation == &"InkPanel" and title.theme_type_variation == &"TitleLabel"
					and scaled == [288.0, _x(Tokens.TEXT_SIZE_TITLE, 1.5), _x(Tokens.TEXT_SIZE, 1.5), Vector2(24, 24)]
					and back_at_one == [192.0, Tokens.TEXT_SIZE_TITLE, Tokens.TEXT_SIZE, Vector2(16, 16)],
			"1.5: %s, 1.0: %s" % [scaled, back_at_one])
	remove_child(setup)
	setup.queue_free()
	await get_tree().process_frame
	MenuState.reset()


## The launch description: what the menu leaves and what main.gd builds from it, without changing scenes.
func _test_game_launch() -> void:
	var settings := Settings.new()
	# Bomb (rounds): this check reads the RoundManager; Team Deathmatch is the default since D-132.
	settings.match_mode = "rounds"
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
	# One click on Team Deathmatch (D-132): the game, a team respawn match on the rotation's first map, Depot.
	menu.get_buttons()[0].pressed.emit()
	menu.get_match_setup().get_mode_cards()[0].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	await tree.physics_frame
	var deathmatch := tree.current_scene
	_close_class_menu(deathmatch)
	var respawn_rules: Node = deathmatch.get_map().get_node_or_null("RespawnMatch") if deathmatch != null and deathmatch.has_method("get_map") else null
	_check("The real flow: Play, then a click on the Team Deathmatch card (picked: \"click to play\") changes the scene to the game, which plays a team respawn match on Depot, the rotation's first map, with Square next",
			deathmatch != null and deathmatch.scene_file_path == GameLaunch.GAME_SCENE and not is_instance_valid(menu) and respawn_rules != null
					and deathmatch.get_map().scene_file_path == "res://maps/depot.tscn" and deathmatch.call("get_next_map") == "res://maps/square.tscn"
					and not MenuState.is_any_open(),
			"scene '%s', map '%s', respawn match %s" % [deathmatch.scene_file_path if deathmatch != null else "none",
					deathmatch.get_map().scene_file_path if deathmatch != null and deathmatch.has_method("get_map") else "none", respawn_rules != null])
	if deathmatch != null and deathmatch.has_method("return_to_menu"):
		(deathmatch.get_node("MatchEndScreen") as MatchEndScreen).main_menu_pressed.emit()
		await tree.process_frame
		await tree.process_frame
		await tree.process_frame
	menu = tree.current_scene as MainMenu
	if menu == null:
		_failures += 1
		print("FAIL  The rest of the scene flow skipped: no menu after the Team Deathmatch match")
		tree.current_scene = self
		if is_instance_valid(holder):
			holder.free()
		MenuState.reset()
		GameLaunch.clear()
		shared.reset_to_defaults()
		shared.save_path = ""
		_remove_temp_file()
		return
	# Custom match: Bomb on the test map alone, 2v4, Easy, first to 10.
	var setup := menu.get_match_setup()
	menu.get_buttons()[0].pressed.emit()
	setup.get_mode_cards()[1].pressed.emit()
	(setup.get_segment_buttons(&"match_map")[1] as Button).button_pressed = true
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
	_close_class_menu(game)
	var rounds: RoundManager = game.get_map().get_node_or_null("RoundManager") if game != null and game.has_method("get_map") else null
	_check("The real flow: Play, the Bomb card, Square alone, 2v4 / Easy / first to 10 and the Play button change the scene to the game, which plays exactly that (the menu is gone, and the choices were saved to the settings file)",
			game != null and game.scene_file_path == GameLaunch.GAME_SCENE and not is_instance_valid(menu) and saved_file and rounds != null
					and game.get_map().scene_file_path == "res://maps/square.tscn"
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


# --- The pause menu (D-065) ---


## The `pause` action is Esc, is not one of the rebindable actions, and the old
## `toggle_mouse` is gone.
func _test_pause_action() -> void:
	var events := InputMap.action_get_events(&"pause")
	var on_esc := events.size() == 1 and events[0] is InputEventKey and (events[0] as InputEventKey).physical_keycode == KEY_ESCAPE
	_check("The `pause` action is on Esc alone; Esc is not rebindable (not one of Settings.BINDABLE_ACTIONS); the old `toggle_mouse` action no longer exists",
			on_esc and InputMap.has_action(&"pause") and not InputMap.has_action(&"toggle_mouse") and not Settings.BINDABLE_ACTIONS.has(&"pause")
					and not Settings.get_instance().set_binding(&"pause", _key_event(KEY_T)),
			"%d event(s), on Esc %s, toggle_mouse exists %s" % [events.size(), on_esc, InputMap.has_action(&"toggle_mouse")])


## Esc in a game opens the pause menu, which pauses the tree and registers with
## MenuState; Resume and Esc close it; Settings opens over it and Esc comes back.
func _test_pause_menu() -> void:
	var tree := get_tree()
	MenuState.reset()
	var main: Node = await _new_game()
	var menu := main.get_pause_menu() as PauseMenu
	var settings_menu := main.get_settings_menu() as SettingsMenu
	var closed_at_first := not menu.visible and not menu.is_open() and not tree.paused and not MenuState.is_any_open()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc in a game with nothing else open opens the pause menu: it is shown, registered with MenuState (on top, so the player's controls stop) and the whole tree is paused",
			closed_at_first and menu.visible and menu.is_open() and MenuState.is_open(menu) and MenuState.is_top(menu)
					and MenuState.blocks_gameplay() and tree.paused,
			"closed before %s, visible %s, open %s, paused %s" % [closed_at_first, menu.visible, menu.is_open(), tree.paused])
	var texts := _texts([menu.get_resume_button(), menu.get_settings_button(), menu.get_leave_button()])
	_check("It offers Resume, Settings and Leave match (the game is a match here), with Resume focused so Enter resumes",
			texts == ["Resume", "Settings", "Leave match"] and menu.get_resume_button().has_focus() and (menu.get_node("Panel/Margin/Content/Title") as Label).text == "Paused",
			"buttons %s, focus on Resume %s" % [texts, menu.get_resume_button().has_focus()])

	menu.get_resume_button().pressed.emit()
	var focus_owner := get_viewport().gui_get_focus_owner()
	_check("The Resume button closes the menu and unpauses the game: nothing is open, nothing blocks the player, and no hidden button keeps the keyboard focus (Space must jump, not press it again)",
			not menu.visible and not menu.is_open() and not tree.paused and not MenuState.is_any_open() and not MenuState.blocks_gameplay() and focus_owner == null,
			"visible %s, paused %s, any menu %s, focus owner %s" % [menu.visible, tree.paused, MenuState.is_any_open(), focus_owner])

	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var open_again := menu.is_open() and tree.paused
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc again in the pause menu resumes: closed, unpaused, nothing registered (one press, one step)",
			open_again and not menu.visible and not menu.is_open() and not tree.paused and not MenuState.is_any_open(),
			"reopened %s, then visible %s, paused %s" % [open_again, menu.visible, tree.paused])

	# Settings opens over the pause menu; Esc there comes back to it, still paused.
	menu.open()
	menu.get_settings_button().pressed.emit()
	var over := settings_menu.visible and MenuState.is_top(settings_menu) and menu.is_open() and not menu.visible and tree.paused
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var back := not settings_menu.visible and MenuState.is_top(menu) and menu.visible and menu.is_open() and tree.paused \
			and menu.get_settings_button().has_focus()
	_check("Settings opens the settings menu over the pause menu (the game stays paused, the pause panel steps aside); Esc in the settings menu returns to the pause menu, still paused, with the Settings button focused",
			over and back,
			"settings over %s; back at the pause menu %s (visible %s, paused %s)" % [over, back, menu.visible, tree.paused])
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("One more Esc resumes from there: the settings menu was only a step on the way",
			not menu.is_open() and not tree.paused and not MenuState.is_any_open() and not settings_menu.visible,
			"open %s, paused %s" % [menu.is_open(), tree.paused])

	# The console stays out of it: Esc closes it and nothing else, paused or not.
	var console := main.get_node("DevConsole") as DevConsole
	console.set_open(true)
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var closed_console := not console.visible and not DevConsole.is_open and not menu.is_open() and not tree.paused and not MenuState.is_any_open()
	menu.open()
	console.set_open(true)
	var console_over := console.visible and tree.paused and MenuState.is_top(console)
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var pause_kept := not console.visible and menu.is_open() and tree.paused and MenuState.is_top(menu)
	_check("Esc with the console open closes the console only: in a running game the pause menu doesn't open as well, and over the pause menu the console works (it runs while paused) and the pause menu is still there after",
			closed_console and console_over and pause_kept,
			"closed console %s, console over pause %s, pause kept %s" % [closed_console, console_over, pause_kept])
	menu.close()

	main.queue_free()
	await tree.process_frame
	tree.paused = false
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false
	Settings.get_instance().reset_to_defaults()


## While the menu is open the whole game stands still: the round timer, a
## running character, the sounds, and the Tab scoreboard stays hidden; and each
## part that must keep going does (the menus and the console).
func _test_pause_game_stands_still() -> void:
	var tree := get_tree()
	MenuState.reset()
	var main: Node = await _new_game()
	var menu := main.get_pause_menu() as PauseMenu
	var map: Node = main.get_map()
	var controller := _player.get_node("PlayerController") as PlayerController
	var board := main.get_node("Scoreboard") as Scoreboard
	# A game sound is a plain player in the world (it must pause); a menu sound has to be Always (it must not).
	# (A silent second on a loop: headless runs have a dummy audio driver, where a short real sound can end by itself.)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_8_BITS
	sound.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(8000)
	sound.data = silence
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = 8000
	var game_sound := AudioStreamPlayer3D.new()
	var menu_sound := AudioStreamPlayer.new()
	menu_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	game_sound.stream = sound
	menu_sound.stream = sound
	map.add_child(game_sound)
	add_child(menu_sound)
	game_sound.play()
	menu_sound.play()
	await _wait_for_phase(RoundManager.Phase.LIVE)
	Input.action_press("move_forward")
	Input.action_press("scoreboard")
	var time_before := _rounds.time_left
	var position_before := _player.global_position
	for i in 30:
		await tree.physics_frame
	await tree.process_frame
	var ran := _rounds.time_left < time_before - 0.1 and _player.global_position.distance_to(position_before) > 0.2 and board.visible \
			and game_sound.playing and not game_sound.stream_paused
	var ran_detail := "time %.2f → %.2f, moved %.2f m, scoreboard %s" % [time_before, _rounds.time_left, _player.global_position.distance_to(position_before), board.visible]

	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	await tree.process_frame
	await tree.process_frame
	var bots_before := _positions(_rounds.get_participants())
	var time_paused := _rounds.time_left
	var frames_before := Engine.get_physics_frames()
	for i in 30:
		await tree.physics_frame
	await tree.process_frame
	var still := _rounds.time_left == time_paused and _positions(_rounds.get_participants()) == bots_before
	_check("Before the pause the game runs (the round timer counts down, a character moves, the Tab scoreboard shows); while it is paused for 30 physics ticks the round manager's time_left and every character's position (the player is holding forward) don't change at all",
			ran and still and Engine.get_physics_frames() - frames_before >= 30 and tree.paused,
			"running: %s; paused: time %.4f → %.4f over %d ticks, characters unchanged %s" % [
					ran_detail, time_paused, _rounds.time_left, Engine.get_physics_frames() - frames_before, still])
	_check("The Tab scoreboard stays hidden while paused, though Tab is still held (it was up when Esc was pressed): it keeps running to see that a menu is open",
			not board.visible and board.process_mode == Node.PROCESS_MODE_ALWAYS and Input.is_action_pressed("scoreboard"),
			"visible %s, process mode %d" % [board.visible, board.process_mode])
	var console := main.get_node("DevConsole") as DevConsole
	var settings_menu := main.get_settings_menu() as SettingsMenu
	_check("Paused means the map, the round manager, the player and the HUD can't process, while the pause menu, the settings menu, the console and the scoreboard still can",
			not map.can_process() and not _rounds.can_process() and not controller.can_process() and not main.get_node("HUD").can_process()
					and menu.can_process() and settings_menu.can_process() and console.can_process() and board.can_process(),
			"map %s, rounds %s, player %s, HUD %s; menu %s, settings %s, console %s, scoreboard %s" % [
					map.can_process(), _rounds.can_process(), controller.can_process(), main.get_node("HUD").can_process(),
					menu.can_process(), settings_menu.can_process(), console.can_process(), board.can_process()])
	_check("Sounds follow the pause: a sound playing in the world (an AudioStreamPlayer3D, like footsteps and shots) is paused while the tree is, and a player set to Always (what a menu sound needs) keeps playing",
			game_sound.stream_paused and not menu_sound.stream_paused and menu_sound.playing,
			"world sound: paused %s; Always sound: paused %s, playing %s" % [game_sound.stream_paused, menu_sound.stream_paused, menu_sound.playing])

	# Resume: everything runs again, and a fire button still held waits until it is let go.
	Input.action_press("shoot")
	menu.close()
	var after_resume := controller.get_input(0.0)
	var time_resumed := _rounds.time_left
	var position_resumed := _player.global_position
	for i in 30:
		await tree.physics_frame
	await tree.process_frame
	_check("Resume starts the game again where it stopped: the round timer counts down, the player runs on, the world sound is no longer paused, and the fire button still held doesn't shoot until it is released",
			not tree.paused and _rounds.time_left < time_resumed - 0.1 and _player.global_position.distance_to(position_resumed) > 0.2
					and not game_sound.stream_paused and not after_resume.shoot and after_resume.move.y < 0.0,
			"time %.2f → %.2f, moved %.2f m, sound paused %s, shoot %s, move %s" % [
					time_resumed, _rounds.time_left, _player.global_position.distance_to(position_resumed), game_sound.stream_paused,
					after_resume.shoot, after_resume.move])
	game_sound.stop()
	menu_sound.stop()
	menu_sound.queue_free()
	Input.action_release("shoot")
	Input.action_release("move_forward")
	Input.action_release("scoreboard")

	# A jump pressed just before Esc doesn't happen after Resume.
	controller._unhandled_input(_action_event("jump"))
	menu.open()
	menu.close()
	var jump_after := controller.get_input(0.0).jump
	_check("A jump pressed in the moment before Esc is forgotten by the pause, not carried out after Resume", not jump_after, "jump queued after resume: %s" % jump_after)

	main.queue_free()
	await tree.process_frame
	tree.paused = false
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false
	Settings.get_instance().reset_to_defaults()


## When the match is over Esc does nothing new: the match-end screen has the
## screen, and no pause menu opens behind it.
func _test_pause_esc_rules() -> void:
	var tree := get_tree()
	MenuState.reset()
	var main: Node = await _new_game(1)
	var menu := main.get_pause_menu() as PauseMenu
	var screen := main.get_node("MatchEndScreen") as MatchEndScreen
	await _win_round(Teams.viewer_team)
	await _wait_for_phase(RoundManager.Phase.MATCH_END)
	await tree.process_frame
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	await tree.process_frame
	_check("With the match-end screen up Esc does nothing new: no pause menu, the game is not paused, and the screen is still there",
			screen.visible and not menu.is_open() and not menu.visible and not tree.paused and not MenuState.is_any_open(),
			"screen %s, pause menu %s, paused %s" % [screen.visible, menu.is_open(), tree.paused])
	main.queue_free()
	await tree.process_frame
	tree.paused = false
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false
	Settings.get_instance().reset_to_defaults()


## The menu's look (a modal panel with a title and three big buttons, no style
## overrides, a click-blocking background) and its scaling.
func _test_pause_menu_look() -> void:
	var menu := PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	var panel := menu.get_panel()
	var title := menu.get_node("Panel/Margin/Content/Title") as Label
	var background := menu.get_background()
	var buttons: Array[Button] = [menu.get_resume_button(), menu.get_settings_button(), menu.get_leave_button()]
	var all_big := buttons.all(func(button: Button) -> bool: return button.theme_type_variation == &"BigButton" and button.get_theme_font_size("font_size") == 32)
	_check("It is hidden until opened; its look comes from variations: a modal panel (accent frame), a 48 px title, three 32 px big buttons; it sits between the Tab scoreboard (3) and the match-end screen (5), and keeps running while paused",
			not menu.visible and panel.theme_type_variation == &"ModalPanel" and title.theme_type_variation == &"TitleLabel" and title.get_theme_font_size("font_size") == 48
					and all_big
					and menu.layer == 4 and menu.process_mode == Node.PROCESS_MODE_ALWAYS,
			"visible %s, panel '%s', title %d px, big buttons %s, layer %d, process mode %d" % [
					menu.visible, panel.theme_type_variation, title.get_theme_font_size("font_size"), all_big, menu.layer, menu.process_mode])
	var overrides := _style_or_size_overrides(menu)
	_check("Nothing in the pause menu carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	_check("A full-screen background (a dim backdrop panel) and the panel both stop mouse clicks, so no click reaches the player controls behind the menu",
			background.mouse_filter == Control.MOUSE_FILTER_STOP and background.anchor_left == 0.0 and background.anchor_top == 0.0
					and background.anchor_right == 1.0 and background.anchor_bottom == 1.0 and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
			"background filter %d, anchors (%.0f, %.0f, %.0f, %.0f), panel filter %d" % [background.mouse_filter, background.anchor_left,
					background.anchor_top, background.anchor_right, background.anchor_bottom, panel.mouse_filter])
	menu.set_ui_scale(1.5)
	await get_tree().process_frame
	var scaled := panel.custom_minimum_size.x == 720.0 and title.get_theme_font_size("font_size") == 72 \
			and menu.get_resume_button().get_theme_font_size("font_size") == 48
	menu.set_ui_scale(1.0)
	await get_tree().process_frame
	var restored := panel.custom_minimum_size.x == 480.0 and title.get_theme_font_size("font_size") == 48 \
			and menu.get_resume_button().get_theme_font_size("font_size") == 32
	_check("Scaled by 1.5 the panel goes 480 → 720 px, the title 48 → 72 px and the buttons 32 → 48 px; back at 1.0 each returns to its design size",
			scaled and restored, "scaled %s, restored %s" % [scaled, restored])
	remove_child(menu)
	menu.queue_free()
	MenuState.reset()


## Leave match (and the console's `disconnect` over the pause menu) change to the
## main menu with the game unpaused, in the real flow through the scenes.
func _test_pause_leaves_the_game() -> void:
	var tree := get_tree()
	var shared := Settings.get_instance()
	_remove_temp_file()
	shared.load_from_disk(TEMP_PATH)
	var holder := Node.new()
	tree.root.add_child(holder)
	tree.current_scene = holder
	var rules := MatchSettings.new()
	rules.freeze_time = 0.3
	GameLaunch.start_match(Settings.DEFAULT_MAP, rules)
	tree.change_scene_to_file(GameLaunch.GAME_SCENE)
	for i in 3:
		await tree.process_frame
	var game := tree.current_scene
	var in_game := game != null and game.scene_file_path == GameLaunch.GAME_SCENE
	var menu: PauseMenu = game.get_pause_menu() if in_game else null
	if menu != null:
		for character: Character in game.get_map().find_children("*", "Character", true, false):
			_silence(character)
		_close_class_menu(game)
		_send(_key_event(KEY_ESCAPE))
		_send(_key_event(KEY_ESCAPE, false))
	var paused_in_game := menu != null and menu.is_open() and tree.paused
	var match_text := menu.get_leave_button().text if menu != null else ""
	if menu != null:
		menu.get_leave_button().pressed.emit()
		for i in 3:
			await tree.process_frame
	var back := tree.current_scene as MainMenu
	_check("In a game Esc pauses it; the leave button (\"Leave match\" in a match) changes to the main menu scene, which is not paused, has the mouse free and answers to Esc like before (it does nothing on the main page)",
			paused_in_game and match_text == "Leave match" and back != null and back.scene_file_path == GameLaunch.MENU_SCENE and not tree.paused
					and MenuState.is_top(back) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not is_instance_valid(game),
			"in game %s, paused there %s, text '%s', scene '%s', paused now %s" % [in_game, paused_in_game, match_text,
					tree.current_scene.scene_file_path if tree.current_scene != null else "none", tree.paused])
	if back != null:
		# Practice: the button reads "Leave practice"; the console's `disconnect` over the pause menu leads back as well.
		back.get_buttons()[1].pressed.emit()
		for i in 3:
			await tree.process_frame
		var practice := tree.current_scene
		var practice_menu: PauseMenu = practice.get_pause_menu() if practice != null and practice.has_method("get_pause_menu") else null
		var practice_text := ""
		var practice_paused := false
		if practice_menu != null:
			for character: Character in practice.get_map().find_children("*", "Character", true, false):
				_silence(character)
			_send(_key_event(KEY_ESCAPE))
			_send(_key_event(KEY_ESCAPE, false))
			practice_text = practice_menu.get_leave_button().text
			practice_paused = practice_menu.is_open() and tree.paused
			(practice.get_node("DevConsole") as DevConsole).run("disconnect")
			for i in 3:
				await tree.process_frame
		var again := tree.current_scene as MainMenu
		_check("In practice mode the leave button reads \"Leave practice\"; the console's `disconnect`, run over the pause menu, also lands in an unpaused main menu",
				practice_paused and practice_text == "Leave practice" and again != null and again.scene_file_path == GameLaunch.MENU_SCENE
						and not tree.paused and MenuState.is_top(again) and not is_instance_valid(practice),
				"paused there %s, text '%s', scene '%s', paused now %s" % [practice_paused, practice_text,
						tree.current_scene.scene_file_path if tree.current_scene != null else "none", tree.paused])
		if again != null:
			again.free()
	else:
		_failures += 1
		print("FAIL  The practice and disconnect pause checks were skipped: there was no menu to go back to")
	tree.paused = false
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


## True if a crosshair shows the default style: the mockup's green, 7 px lines, gap 4, thickness 2, outlined, no dot, not dynamic.
func _is_default_crosshair(crosshair: Crosshair) -> bool:
	return crosshair.color.is_equal_approx(Color("36d07a")) and crosshair.length == 7.0 and crosshair.gap == 4.0 \
			and crosshair.thickness == 2.0 and crosshair.outline and not crosshair.dot and not crosshair.dynamic


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


## A game on the test map the way the main menu starts one (a [GameLaunch]
## description with short timings), with every character silenced and the bots
## holding their ground, once the first frames have run. Sets [member _rounds]
## and [member _player].
## Closes the class menu, which opens by itself in a match's first freeze time (M6, D-078), so a
## test of another menu or of Esc starts with nothing open.
func _close_class_menu(game: Node) -> void:
	var class_menu := game.get_node_or_null("ClassMenu") as ClassMenu if game != null else null
	if class_menu != null and class_menu.is_open():
		class_menu.close()


func _new_game(rounds_to_win: int = 5) -> Node:
	# An earlier test's map would share the physics world with this game (the
	# SubViewport has no world of its own), and its bots would shoot at ours.
	if _map != null and is_instance_valid(_map):
		remove_child(_map)
		_map.queue_free()
		_map = null
	var rules := MatchSettings.new()
	rules.freeze_time = 0.3
	rules.round_time = 30.0
	rules.round_end_time = 0.3
	rules.rounds_to_win = rounds_to_win
	GameLaunch.start_match(Settings.DEFAULT_MAP, rules)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	add_child(main)
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
	_rounds = main.get_map().get_node("RoundManager") as RoundManager
	_player = main.get_map().get_node("Player") as Character
	for character in _rounds.get_participants():
		_silence(character)
		if character != _player:
			(character.get_node("BotController") as BotController).hold_position = true
	_close_class_menu(main)
	return main


## The global positions of [param characters], in order.
func _positions(characters: Array[Character]) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for character in characters:
		positions.append(character.global_position)
	return positions


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


## The numbers written in GDScript [param source] outside comments and strings,
## other than 0 and 1 (and the 1 of -1), which are switches and "unset", not sizes.
func _literal_numbers(source: String) -> Array[String]:
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var comments := RegEx.create_from_string("#.*")
	var numbers := RegEx.create_from_string("(?<![A-Za-z_0-9.])[0-9]+(?:\\.[0-9]+)?")
	var found: Array[String] = []
	for line in source.split("\n"):
		var code := comments.sub(strings.sub(line, "\"\"", true), "", true)
		for result in numbers.search_all(code):
			var number := result.get_string()
			if number != "0" and number != "1":
				found.append(number)
	return found


## What [method _menu_sizes] should read for a [method _make_menu] menu scaled by [param factor].
func _expected_menu_sizes(factor: float) -> Dictionary:
	return {
		"body": _x(Tokens.TEXT_SIZE, factor), "title": _x(Tokens.TEXT_SIZE_TITLE, factor),
		"margin": _x(Tokens.PANEL_MARGIN_X, factor), "button_min": Vector2(200, 40) * factor,
		"override_separation": _x(10, factor), "override_font": _x(20, factor),
		"popup": _x(Tokens.TEXT_SIZE, factor),
		"panel_border": _x((_theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).border_width_left, factor),
	}


## [param pixels] scaled by [param factor] the way the theme scales it (whole pixels).
func _x(pixels: int, factor: float) -> int:
	return UiTheme.scale_pixels(pixels, factor)


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


## The theme overrides [param control] carries itself, as "kind/item" ("colors/font_color",
## "constants/separation"...). Godot lists every theme item the built-in theme has for the control's class
## as a "theme_override_<kind>/<item>" property and stores the ones that are overridden, so the property
## list tells them apart; the usual names the built-in theme may not list for the class are asked for one
## by one ([constant OVERRIDE_NAMES]).
func _override_names(control: Control) -> Array[String]:
	var found: Array[String] = []
	for property in control.get_property_list():
		var property_name := String(property["name"])
		if property_name.begins_with("theme_override_") and (int(property["usage"]) & PROPERTY_USAGE_STORAGE) != 0:
			found.append(property_name.trim_prefix("theme_override_"))
	var by_name := {
		"colors": control.has_theme_color_override, "fonts": control.has_theme_font_override,
		"font_sizes": control.has_theme_font_size_override, "constants": control.has_theme_constant_override,
		"styles": control.has_theme_stylebox_override, "icons": control.has_theme_icon_override,
	}
	for kind: String in OVERRIDE_NAMES:
		for item: String in OVERRIDE_NAMES[kind]:
			var override_name := "%s/%s" % [kind, item]
			if (by_name[kind] as Callable).call(item) and not found.has(override_name):
				found.append(override_name)
	return found


## The controls in [param root] and below it (the ones a scene or a script added, not the engine's own
## parts of a TabContainer, an OptionButton and the like) that carry any theme override, as
## "Name (colors/font_color, ...)".
func _overrides_below(root: Node) -> Array[String]:
	var found: Array[String] = []
	if root is Control:
		var names := _override_names(root as Control)
		if not names.is_empty():
			found.append("%s (%s)" % [root.name, ", ".join(names)])
	for child in root.get_children():
		found.append_array(_overrides_below(child))
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
