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
## The scoreboard, the pause menu and the match-end screen (M10 task 11, D-137) are the mockup's: the new
## roles and their sizes, the Tab scoreboard's panel, header (also in Team Deathmatch), titles, team lines, rows,
## class icons and muted dead rows, the pause menu's column and its focus chip, and the match-end screen's page,
## result, score line, compact table and buttons, each also at 1.5 times the size.
## The loading screen (M10 task 15, D-138) is the mockup's: its three lines for a rotation, Bomb and practice, its
## band, margins, gaps and squares (also at 1.5 times the size), and its behaviour: it shows on a launch from the
## menu and on the rotation's next map with the game paused and the HUD hidden, swallows Esc, the console key,
## B, M and Tab, fills its squares and hides itself, and doesn't show on a restart.
## The multiplayer lobby (M9, D-108, restyled as the mockup's "06 Lobby" in M10) adds checks for the main
## menu's Host and Join items and the connect page (fields from and to the settings, Esc, look), hosting
## (the lobby page: "Hosted by you", the addresses friends join at, you as "You" with the Host mark,
## "Empty / Bot" rows from the published slots, team headers colored relative to you with their counts,
## the footer's mode, map and limit, Switch team and full teams, Edit setup opening the online match
## setup over it, Start, Leave and Esc), the layout in pixels and at 1.5 times, a real friend joining the
## host, joining a port where nothing listens, a port in use, a client's view of a host's lobby and its
## host leaving, and the main menu opening the lobby by itself with a running session or with the reason
## an online game ended.
## The shared [Settings] instance never saves in this test (nothing calls
## `load_from_disk()`) and is put back to its defaults after each group; the
## last check makes sure the real `user://settings.cfg` wasn't touched. Quits
## with the number of failed checks as the exit code (0 means everything passed).

const MAP_SCENE := preload("res://maps/test_map.tscn")
## The hidden test map (D-141) by path: the map these tests start their matches on. Settings.DEFAULT_MAP is the Shooting Range now.
const TEST_MAP := "res://maps/test_map.tscn"
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
const BUY_MENU_SCENE := preload("res://ui/buy_menu.tscn")
## The window height the menus are laid out for (720p).
const DESIGN_HEIGHT := 720.0
const LOADING_SCENE := preload("res://ui/loading_screen.tscn")
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
	# match result, the console's line label, the crosshair colour swatches, the dim behind a modal menu.
	"FriendlyScoreLabel": "Label", "EnemyScoreLabel": "Label", "VictoryLabel": "Label", "DefeatLabel": "Label",
	"ConsoleLabel": "Label", "ConsoleLineEdit": "LineEdit", "SwatchRow": "HBoxContainer", "SwatchMargin": "MarginContainer",
	"BackdropPanel": "Panel",
	# M10 task 10 (D-137): the settings screen's roles.
	"SettingsColumn": "VBoxContainer", "FlushRow": "HBoxContainer", "StackBox": "VBoxContainer", "GroupBox": "VBoxContainer",
	"TableRowPanel": "PanelContainer", "WideSegmentButton": "Button", "KeyCapButton": "Button", "KeySlotButton": "Button",
	"ListeningKeyButton": "KeyCapButton", "StrongButton": "Button", "DimButton": "Button", "SwatchButton": "Button",
	# M10 task 11 (D-137): the scoreboard, the pause menu and the match-end screen as in the mockup: 32 px team-coloured
	# scores, the line above the enemy's rows in a tighter table, a row's inside margin, the space under the Tab
	# scoreboard's header, the two centred lines between its scores, big text cut to the mockup's line height, the
	# 48 high buttons of the match-end screen, a centred menu item and its ink chip.
	"FriendlyLargeLabel": "Label", "EnemyLargeLabel": "Label", "TeamHeaderEnemyTight": "PanelContainer",
	"CellMargin": "MarginContainer", "HeaderMargin": "MarginContainer", "ScoreLines": "VBoxContainer",
	"TitleTrim": "MarginContainer", "LargeTrim": "MarginContainer", "HeroTrim": "MarginContainer",
	"TallButton": "Button", "TallPrimaryButton": "PrimaryButton", "CenteredItemButton": "BigButton", "InkChip": "Panel",
	"PageColumn": "VBoxContainer", "MuteLabel": "Label",
	# M10 task 13: the developer console as in mockup 17: its column, the output's margin and line box, the alert-coloured
	# error line, the input row (INK, a LINE edge above) and the row's box.
	"ConsoleBox": "VBoxContainer", "ConsoleOutputMargin": "MarginContainer", "ConsoleLines": "VBoxContainer",
	"ConsoleErrorLabel": "ConsoleLabel", "ConsoleInputRow": "PanelContainer", "ConsoleInputBox": "HBoxContainer",
	# M10 task 15 (D-138): the loading screen's progress squares (done, current, still to come) and its two columns.
	"TextChip": "Panel", "AccentChip": "Panel", "LineChip": "Panel", "LoadingColumn": "VBoxContainer",
	# M10 task 17 (D-139): the multiplayer lobby as in mockup 06: the team header with its line, an empty slot's frame,
	# the footer's edge, the page's side-by-side rows and the lobby's boxes, rows and margins, the alert-coloured text.
	"AlertLabel": "Label", "TeamTitleFriendly": "PanelContainer", "TeamTitleEnemy": "PanelContainer", "EmptySlotPanel": "PanelContainer",
	"FooterPanel": "PanelContainer", "PageRow": "HBoxContainer", "SideColumn": "VBoxContainer", "SideBox": "VBoxContainer",
	"TightBox": "VBoxContainer", "FieldRow": "HBoxContainer", "SlotRow": "HBoxContainer", "SlotMargin": "MarginContainer",
	# M10 task 12 (D-142): the class draft as in mockup 08: the card (a button with a PANEL frame the focus lights), its footer
	# edge, the key chip (empty or lit) and the number on it (ink on the lit one), the perk text on its 24 px lines, the title
	# block, the frame's and the body's margins, the blocks of text and the rows of cards (full size and compact).
	"ClassCardButton": "Button", "ClassFooterPanel": "PanelContainer", "KeyChip": "PanelContainer", "KeyChipLit": "PanelContainer",
	"LargeInkLabel": "Label", "PerkLabel": "Label", "ClassHeaderBox": "VBoxContainer", "FrameMargin": "MarginContainer",
	"ClassBodyMargin": "MarginContainer", "ClassBodyBox": "VBoxContainer", "ClassTextBox": "VBoxContainer",
	"ClassRow": "HBoxContainer", "ClassRowCompact": "HBoxContainer",
	# M10 task 12b (D-143): the buy menu as in mockup 14: the column (its header with a LINE edge, or the accent's for the selected
	# column) and the four looks of an item.
	"BuyColumn": "VBoxContainer", "ColumnHeaderPanel": "PanelContainer", "ColumnHeaderLitPanel": "PanelContainer",
	"BuyItemOk": "Button", "BuyItemFocused": "Button", "BuyItemOwned": "Button", "BuyItemPoor": "Button",
}
## The roles the HUD uses (M10 task 6, D-133; the mockups' look, task 14, D-141): name → the type it varies.
const HUD_VARIATIONS := {
	"HudSmallLabel": "Label", "HudDimLabel": "Label", "HudSlotsLabel": "Label", "HudValueLabel": "Label", "HudLargeLabel": "Label",
	"HudReserveLabel": "Label", "HudFriendlyScoreLabel": "Label", "HudEnemyScoreLabel": "Label", "HudTitleLabel": "Label",
	"HudCountdownLabel": "Label", "HudPlateDimLabel": "Label", "HudPlateMuteLabel": "Label", "HudPlateLabel": "Label",
	"HudPlateNameLabel": "Label", "HudAlertPlateLabel": "Label",
	# M10 task 14: the kill feed, the toasts, the bomb's tag and prompt, the hit marker's sizes (the "Hud" type).
	"HudPlateInkLabel": "Label", "HudPlateAlertLabel": "Label", "HudAlertLabel": "Label",
	"HudStack": "VBoxContainer", "HudStackBlock": "VBoxContainer", "HudStackDeath": "VBoxContainer", "HudStackCentre": "VBoxContainer",
	"HudStackIcon": "VBoxContainer",
	"HudRowStack": "HBoxContainer", "HudRowIcon": "HBoxContainer", "HudRowBlock": "HBoxContainer", "HudRowBarBomb": "HBoxContainer",
	"HudRowBarTdm": "HBoxContainer", "HudRowStats": "HBoxContainer", "HudRowChips": "HBoxContainer",
	"HudCentreMargin": "MarginContainer", "HudBaselineLift": "MarginContainer",
	"HudHealthChip": "Panel", "HudHealthChipEmpty": "Panel", "HudScoreBarBack": "Panel", "HudFriendlyBarFill": "Panel",
	"HudEnemyBarFill": "Panel", "HudFriendlyPipAlive": "Panel", "HudEnemyPipAlive": "Panel", "HudFriendlyPipDead": "Panel",
	"HudEnemyPipDead": "Panel", "HudDeadTint": "Panel", "HudProgressBack": "Panel", "HudProgressFill": "Panel",
	"HudToastChip": "Panel", "HudToastChipInk": "Panel",
	"HudPlate": "PanelContainer", "HudAlertPlate": "PanelContainer", "HudFeedPlate": "PanelContainer", "HudFeedPlateYou": "PanelContainer",
	"HudFeedPlateDeath": "PanelContainer", "HudToastNeutral": "PanelContainer", "HudToastMatchPoint": "PanelContainer",
	"HudToastBomb": "PanelContainer", "HudToastLowAmmo": "PanelContainer",
}
## The HUD's scenes and scripts that must take everything from the theme.
const HUD_SCENES: Array[String] = ["res://ui/hud.tscn", "res://ui/round_hud.tscn", "res://ui/bomb_hud.tscn"]
const HUD_SCRIPTS: Array[String] = ["res://ui/hud.gd", "res://ui/round_hud.gd", "res://ui/bomb_hud.gd", "res://ui/kill_feed.gd",
		"res://ui/toast_stack.gd", "res://ui/hit_marker.gd"]
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
	await _test_mockup_roles()
	await _test_lobby_roles()
	_test_icon_slots()
	_test_scaled_theme()
	await _test_scaling_a_menu()
	await _test_preview()
	await _test_console()
	await _test_scoreboard()
	await _test_scoreboard_header_in_team_deathmatch()
	await _test_match_end_screen()
	await _test_menus_have_no_overrides()
	await _test_stats_menu()
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
	_test_loading_texts()
	await _test_loading_screen_look()
	await _test_loading_screen_in_the_game()
	await _test_lobby_menu()
	_test_class_draft_roles()
	await _test_class_draft_look()
	_test_buy_menu_roles()
	await _test_buy_menu_look()
	await _test_compass()
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


## The multiplayer lobby's roles (M10, the mockup's "06 Lobby"): the team header's line, an empty slot's frame,
## the footer's edge, the gaps of its boxes and rows, a row's margin and the alert-coloured text.
func _test_lobby_roles() -> void:
	var holder := Control.new()
	add_child(holder)
	var friendly_title := _variation_node(PanelContainer.new(), "TeamTitleFriendly", holder)
	var enemy_title := _variation_node(PanelContainer.new(), "TeamTitleEnemy", holder)
	var empty_slot := _variation_node(PanelContainer.new(), "EmptySlotPanel", holder)
	var footer := _variation_node(PanelContainer.new(), "FooterPanel", holder)
	var slot_margin := _variation_node(MarginContainer.new(), "SlotMargin", holder)
	var alert := _variation_node(Label.new(), "AlertLabel", holder)
	await get_tree().process_frame
	var friendly_box := friendly_title.get_theme_stylebox("panel") as StyleBoxFlat
	var enemy_box := enemy_title.get_theme_stylebox("panel") as StyleBoxFlat
	_check("A lobby team's header is a panel with nothing behind it and a 2 px line under it in the UI's team colour (blue for yours, red for the enemy's), no space above the line (unlike the scoreboard's enemy line)",
			friendly_box.border_width_bottom == Tokens.LINE and friendly_box.border_width_top == 0 and friendly_box.border_color == Tokens.FRIENDLY and friendly_box.bg_color.a == 0.0
					and enemy_box.border_width_bottom == Tokens.LINE and enemy_box.border_width_top == 0 and enemy_box.border_color == Tokens.ENEMY and enemy_box.bg_color.a == 0.0
					and friendly_title.get_combined_minimum_size().y == float(Tokens.LINE) and enemy_title.get_combined_minimum_size().y == float(Tokens.LINE),
			"friendly line %d %s, enemy line %d %s, heights %.0f / %.0f" % [friendly_box.border_width_bottom, friendly_box.border_color, enemy_box.border_width_bottom,
					enemy_box.border_color, friendly_title.get_combined_minimum_size().y, enemy_title.get_combined_minimum_size().y])
	var empty_box := empty_slot.get_theme_stylebox("panel") as StyleBoxFlat
	var footer_box := footer.get_theme_stylebox("panel") as StyleBoxFlat
	_check("An empty slot is framed in a 2 px LINE colour with nothing inside (the mockup's is dashed, a StyleBox has no dashes); the footer has a 2 px LINE edge along its top only and its items start %d px under it" % Tokens.LOBBY_FOOTER_PAD_TOP,
			empty_box.border_width_left == Tokens.BORDER and empty_box.border_width_top == Tokens.BORDER and empty_box.border_width_right == Tokens.BORDER
					and empty_box.border_width_bottom == Tokens.BORDER and empty_box.border_color == Tokens.LINE_COLOR and empty_box.bg_color.a == 0.0
					and footer_box.border_width_top == Tokens.LINE and footer_box.border_width_bottom == 0 and footer_box.border_width_left == 0
					and footer_box.border_color == Tokens.LINE_COLOR and footer_box.bg_color.a == 0.0
					and footer_box.content_margin_top == float(Tokens.LINE + Tokens.LOBBY_FOOTER_PAD_TOP) and Tokens.LOBBY_FOOTER_PAD_TOP == 24,
			"empty frame %d %s, footer edge %d, space %.0f" % [empty_box.border_width_left, empty_box.border_color, footer_box.border_width_top, footer_box.content_margin_top])
	var gaps := {"PageRow": [HBoxContainer, Tokens.PAGE_GAP, 32], "SideColumn": [VBoxContainer, Tokens.LOBBY_GROUP_GAP, 36],
			"SideBox": [VBoxContainer, Tokens.LOBBY_SIDE_GAP, 12], "TightBox": [VBoxContainer, Tokens.LOBBY_ROW_GAP, 4],
			"FieldRow": [HBoxContainer, Tokens.LOBBY_FIELD_GAP, 8], "SlotRow": [HBoxContainer, Tokens.LOBBY_SIDE_GAP, 12]}
	var gap_problems: Array[String] = []
	for role: String in gaps:
		var entry: Array = gaps[role]
		var box := _variation_node(entry[0].new(), role, holder)
		if box.get_theme_constant("separation") != int(entry[1]) or int(entry[1]) != int(entry[2]):
			gap_problems.append("%s %d (token %d, mockup %d)" % [role, box.get_theme_constant("separation"), entry[1], entry[2]])
	_check("The lobby's boxes are the mockup's gaps apart: page parts 32, the left column's groups 36 (12 + the margin of 24), a label and its field 12, a team's rows and a footer pair's lines 4, a field and its button 8, the parts of a row 12; a row's margin is 12 at the sides and none above and below",
			gap_problems.is_empty() and slot_margin.get_theme_constant("margin_left") == Tokens.LOBBY_SLOT_PAD_X and slot_margin.get_theme_constant("margin_right") == Tokens.LOBBY_SLOT_PAD_X
					and slot_margin.get_theme_constant("margin_top") == 0 and slot_margin.get_theme_constant("margin_bottom") == 0 and Tokens.LOBBY_SLOT_PAD_X == 12,
			"problems %s, margin %d" % [gap_problems, slot_margin.get_theme_constant("margin_left")])
	_check("Text that needs attention (a connection error) is the ALERT colour",
			alert.get_theme_color("font_color") == Tokens.ALERT, "colour %s" % [alert.get_theme_color("font_color")])
	remove_child(holder)
	holder.queue_free()


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
## result, the console's lines, the crosshair swatches' spacing, the dim behind a modal menu, and the two
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
	var console_error := _variation_node(Label.new(), "ConsoleErrorLabel", holder)
	var plain := Label.new()
	holder.add_child(plain)
	_check("The console roles use the pixel font like all text (the theme's default font, no longer a monospaced system font), at the body size",
			console_label.get_theme_font("font").resource_path == FONT_PATH and console_input.get_theme_font("font").resource_path == FONT_PATH
					and console_error.get_theme_font("font").resource_path == FONT_PATH and plain.get_theme_font("font").resource_path == FONT_PATH
					and console_label.get_theme_font_size("font_size") == Tokens.TEXT_SIZE and console_input.get_theme_font_size("font_size") == Tokens.TEXT_SIZE,
			"label font %s, input font %s" % [console_label.get_theme_font("font").resource_path, console_input.get_theme_font("font").resource_path])
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
	var you_box := _theme.get_stylebox("panel", "YouRowPanel") as StyleBoxFlat
	_check("The table's colours live in the palette and the theme: a living player's class icon is tinted friendly_text or enemy_text, a dead player's `line` (the LINE token; D-137 replaced the old dead_row multiplier, which is gone), and your row is the YOU_ROW band with a BORDER wide accent frame that takes no room (its content margins are 0, so its columns line up with the other rows')",
			_theme.get_color("line", "Palette") == Tokens.LINE_COLOR and not _theme.has_color("dead_row", "Palette")
					and you_box.bg_color == Tokens.YOU_ROW and you_box.border_color == Tokens.ACCENT and you_box.border_width_left == Tokens.BORDER
					and you_box.content_margin_left == 0.0 and you_box.content_margin_top == 0.0,
			"line %s, dead_row %s, your row %s, content margin %.0f" % [_theme.get_color("line", "Palette"), _theme.has_color("dead_row", "Palette"),
					you_box.bg_color, you_box.content_margin_left])
	remove_child(holder)
	holder.queue_free()


## The roles of the scoreboard, the pause menu and the match-end screen (M10 task 11, D-137) take their
## tokens and come out at the mockups' sizes: big text cut to its line height, the lines above the teams, the
## tables' spacing, the 48 high buttons, the centred menu item with its chip, and the chip icon in the theme.
func _test_mockup_roles() -> void:
	var holder := Control.new()
	add_child(holder)
	var friendly_large := _variation_node(Label.new(), "FriendlyLargeLabel", holder)
	var enemy_large := _variation_node(Label.new(), "EnemyLargeLabel", holder)
	_check("The match-end screen's scores are 32 px in the UI's team colours (FriendlyLargeLabel, EnemyLargeLabel)",
			friendly_large.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE and enemy_large.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE
					and friendly_large.get_theme_color("font_color") == Tokens.FRIENDLY and enemy_large.get_theme_color("font_color") == Tokens.ENEMY,
			"friendly %s, enemy %s" % [friendly_large.get_theme_color("font_color"), enemy_large.get_theme_color("font_color")])
	# Big text in a trim container is as high as the mockup's line height (48 / 32 / 96 px), not as the font's line box.
	var trimmed := {}
	for pair: Array in [["TitleTrim", "TitleLabel", Tokens.TEXT_SIZE_TITLE, Tokens.TRIM_TITLE_TOP, Tokens.TRIM_TITLE_BOTTOM],
			["LargeTrim", "LargeLabel", Tokens.TEXT_SIZE_LARGE, Tokens.TRIM_LARGE_TOP, Tokens.TRIM_LARGE_BOTTOM],
			["HeroTrim", "HeroLabel", Tokens.TEXT_SIZE_HERO, Tokens.TRIM_HERO_TOP, Tokens.TRIM_HERO_BOTTOM]]:
		var trim := _variation_node(MarginContainer.new(), pair[0], holder) as MarginContainer
		var label := _variation_node(Label.new(), pair[1], trim) as Label
		label.text = "Aa"
		trimmed[pair[0]] = [trim, label, pair[2], pair[3], pair[4]]
	await get_tree().process_frame
	var heights := {}
	var trims_ok := true
	for trim_name: String in trimmed:
		var entry: Array = trimmed[trim_name]
		var trim := entry[0] as MarginContainer
		heights[trim_name] = trim.get_combined_minimum_size().y
		trims_ok = trims_ok and heights[trim_name] == float(entry[2]) and trim.get_theme_constant("margin_top") == entry[3] \
				and trim.get_theme_constant("margin_bottom") == entry[4] and (entry[1] as Label).position.y == float(entry[3])
	_check("Big text cut to the mockup's line heights (\"line heights: 96/96, 48/48, 32/32\"): a label in a TitleTrim, LargeTrim or HeroTrim is exactly 48, 32 or 96 px high and sits that much above the top, as CSS puts it",
			trims_ok, "heights %s" % [heights])
	var friendly_line := _variation_node(PanelContainer.new(), "TeamHeaderFriendly", holder)
	var enemy_line := _variation_node(PanelContainer.new(), "TeamHeaderEnemy", holder)
	var tight_line := _variation_node(PanelContainer.new(), "TeamHeaderEnemyTight", holder)
	var line_box := tight_line.get_theme_stylebox("panel") as StyleBoxFlat
	var cell_margin := _variation_node(MarginContainer.new(), "CellMargin", holder)
	var header_margin := _variation_node(MarginContainer.new(), "HeaderMargin", holder)
	var lines := _variation_node(VBoxContainer.new(), "ScoreLines", holder)
	var table_box := _variation_node(VBoxContainer.new(), "TableBox", holder)
	var team_box := _variation_node(VBoxContainer.new(), "TeamBox", holder)
	await get_tree().process_frame
	_check("The lines above the teams are empty panels as high as the mockup's gaps plus the 2 px line: your team's 2, the enemy's 16 + 2 on the Tab scoreboard and 12 + 2 on the match-end screen (the space above is transparent, the line is at the bottom)",
			friendly_line.size.y == float(Tokens.LINE) and enemy_line.size.y == float(Tokens.TEAM_LINE_GAP + Tokens.LINE)
					and tight_line.size.y == float(Tokens.TEAM_LINE_GAP_TIGHT + Tokens.LINE)
					and line_box.border_width_bottom == Tokens.LINE and line_box.border_width_top == 0 and line_box.border_color == Tokens.ENEMY
					and line_box.bg_color.a == 0.0,
			"heights %.0f / %.0f / %.0f" % [friendly_line.size.y, enemy_line.size.y, tight_line.size.y])
	_check("A scoreboard row's inside margin is 16 at the sides and none above and below, the Tab scoreboard's header leaves %d under it, its two lines are %d apart, and its table and rows are %d apart (the mockup's flex gap of 8)" % [Tokens.HEADER_GAP, Tokens.SCORE_LINES_GAP, Tokens.TABLE_GAP],
			cell_margin.get_theme_constant("margin_left") == Tokens.CELL_MARGIN_X and cell_margin.get_theme_constant("margin_right") == Tokens.CELL_MARGIN_X
					and cell_margin.get_theme_constant("margin_top") == 0 and cell_margin.get_theme_constant("margin_bottom") == 0
					and header_margin.get_theme_constant("margin_bottom") == Tokens.HEADER_GAP and header_margin.get_theme_constant("margin_top") == 0
					and lines.get_theme_constant("separation") == Tokens.SCORE_LINES_GAP
					and table_box.get_theme_constant("separation") == Tokens.TABLE_GAP and team_box.get_theme_constant("separation") == Tokens.TEAM_ROW_GAP
					and Tokens.TABLE_GAP == 8 and Tokens.TEAM_ROW_GAP == 8 and Tokens.HEADER_GAP == 16 and Tokens.TEAM_LINE_GAP == 16 and Tokens.TEAM_LINE_GAP_TIGHT == 12,
			"margin %d / %d, header %d, lines %d, table %d, rows %d" % [cell_margin.get_theme_constant("margin_left"), cell_margin.get_theme_constant("margin_top"),
					header_margin.get_theme_constant("margin_bottom"), lines.get_theme_constant("separation"),
					table_box.get_theme_constant("separation"), team_box.get_theme_constant("separation")])
	var tall := _variation_node(Button.new(), "TallButton", holder) as Button
	var tall_primary := _variation_node(Button.new(), "TallPrimaryButton", holder) as Button
	tall.text = "Main menu"
	tall_primary.text = "Play again"
	await get_tree().process_frame
	var tall_normal := tall.get_theme_stylebox("normal") as StyleBoxFlat
	var tall_fill := tall_primary.get_theme_stylebox("normal") as StyleBoxFlat
	_check("The match-end screen's buttons are 48 high with 24 either side: the outlined one has the plain button's MUTE frame, the primary one the accent fill with the hard shadow and ink text; both keep the 16 px text",
			tall.size.y == 48.0 and tall_primary.size.y == 48.0 and tall_normal.content_margin_left == Tokens.TALL_BUTTON_PAD_X
					and tall_normal.border_color == Tokens.BUTTON_BORDER and tall_normal.border_width_left == Tokens.BORDER
					and tall_fill.bg_color == Tokens.ACCENT and tall_fill.border_color == Tokens.SHADOW and tall_fill.border_width_bottom == Tokens.SHADOW_OFFSET
					and tall_primary.get_theme_color("font_color") == Tokens.TEXT_ON_FILL and tall.get_theme_font_size("font_size") == Tokens.TEXT_SIZE,
			"heights %.0f and %.0f, padding %.0f, frame %s" % [tall.size.y, tall_primary.size.y, tall_normal.content_margin_left, tall_normal.border_color])
	var item := _variation_node(Button.new(), "CenteredItemButton", holder) as Button
	var big := _variation_node(Button.new(), "BigButton", holder) as Button
	var ink_chip := _variation_node(Panel.new(), "InkChip", holder)
	var chip_states := ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_disabled_color"]
	_check("A centred menu item is a big menu item (32 px, lime fill on hover and focus) whose icon is invisible in every state, because the screen draws the chip next to the text itself with an InkChip (ink on the accent); the plain menu item still shows its chip",
			item.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE and (item.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == Tokens.ACCENT
					and chip_states.all(func(state: String) -> bool: return item.get_theme_color(state) == Color.TRANSPARENT)
					and big.get_theme_color("icon_focus_color") == Tokens.TEXT_ON_FILL
					and (ink_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.TEXT_ON_FILL,
			"focus icon colour %s, plain item %s" % [item.get_theme_color("icon_focus_color"), big.get_theme_color("icon_focus_color")])
	var chip := UiIcons.get_icon(holder, UiIcons.CHIP)
	holder.theme = UiTheme.scaled(1.5)
	var chip_scaled := UiIcons.get_icon(holder, UiIcons.CHIP)
	_check("The chip is in the theme's icons (not one of the 21 slots), 8 px, and 12 px under a theme scaled by 1.5, so a button's chip scales with the UI",
			chip != null and chip.get_size() == Vector2(8, 8) and chip_scaled != null and chip_scaled.get_size() == Vector2(12, 12)
					and not UiIcons.all_slots().has(UiIcons.CHIP),
			"chip %s, scaled %s" % [chip.get_size() if chip != null else "none", chip_scaled.get_size() if chip_scaled != null else "none"])
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


## The console takes its look from the theme and scales with it; its lines are coloured by kind
## (mockup 17), Tab completes a command's name and Up recalls the last command.
func _test_console() -> void:
	var console := CONSOLE_SCENE.instantiate() as DevConsole
	add_child(console)
	# Open: a hidden console's containers don't lay their children out.
	console.set_open(true)
	await get_tree().process_frame
	var panel := console.get_node("Panel") as PanelContainer
	var lines_box := console.get_node("Panel/Box/OutputMargin/Lines") as VBoxContainer
	var input_row := console.get_node("Panel/Box/InputRow") as PanelContainer
	var input := console.get_node("Panel/Box/InputRow/Row/Input") as LineEdit
	var banner := lines_box.get_child(0) as Label
	var banner_color := banner.get_theme_color("font_color")
	var banner_text := banner.text
	var line_count := lines_box.get_child_count()
	for i in 12:
		console.print_line("line %d" % i)
	var base_size := banner.get_theme_font_size("font_size")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var row_style := input_row.get_theme_stylebox("panel") as StyleBoxFlat
	await get_tree().process_frame
	var base_height := panel.size.y
	var base_line := banner.size.y
	var base_row := input_row.size.y
	console.set_ui_scale(1.5)
	await get_tree().process_frame
	var scaled_size := banner.get_theme_font_size("font_size")
	var scaled_input := input.get_theme_font_size("font_size")
	var scaled_height := panel.size.y
	var scaled_line := banner.size.y
	var scaled_caret := input.get_theme_constant("caret_width")
	var scaled_gap := lines_box.get_theme_constant("separation")
	var scaled_minimum := panel.custom_minimum_size.y
	console.set_ui_scale(1.0)
	await get_tree().process_frame
	_check("The developer console is themed as in the mockup (a ConsolePanel strip in the CONSOLE colour with a LINE edge along the bottom, an input row on INK with a LINE edge above it, a themed input line, no overrides of its own), the body size at 1.0 and 1.5 times it at 1.5",
			panel.theme_type_variation == &"ConsolePanel" and style != null and style.bg_color == Tokens.CONSOLE and style.border_color == Tokens.LINE_COLOR
					and style.border_width_bottom == Tokens.BORDER and style.border_width_top == 0
					and input_row.theme_type_variation == &"ConsoleInputRow" and row_style != null and row_style.bg_color == Tokens.INK
					and row_style.border_color == Tokens.LINE_COLOR and row_style.border_width_top == Tokens.LINE and row_style.border_width_bottom == 0
					and input.theme_type_variation == &"ConsoleLineEdit" and not banner.has_theme_font_size_override("font_size")
					and not panel.has_theme_stylebox_override("panel") and not input.has_theme_stylebox_override("normal")
					and (input.get_theme_stylebox("normal") as StyleBoxEmpty) != null
					and base_size == Tokens.TEXT_SIZE and scaled_size == _x(Tokens.TEXT_SIZE, 1.5) and scaled_input == _x(Tokens.TEXT_SIZE, 1.5),
			"font %d → %d, input %d" % [base_size, scaled_size, scaled_input])
	_check("The strip is 384 px high at 720p (CONSOLE_HEIGHT) and 1.5 times that at 1080p with %d lines of 24 px (CONSOLE_LINE_HEIGHT) in it, 2 px apart, so the lines never push it taller; the input row is 48 px (CONSOLE_ROW_HEIGHT), a lime block caret 10 px wide (15 at 1.5)" % line_count,
			line_count == DevConsole.VISIBLE_LINES and panel.custom_minimum_size.y == float(Tokens.CONSOLE_HEIGHT) and is_equal_approx(base_height, float(Tokens.CONSOLE_HEIGHT))
					and base_line == float(Tokens.CONSOLE_LINE_HEIGHT) and base_row == float(Tokens.CONSOLE_ROW_HEIGHT)
					and is_equal_approx(scaled_minimum, float(_x(Tokens.CONSOLE_HEIGHT, 1.5))) and is_equal_approx(scaled_height, float(_x(Tokens.CONSOLE_HEIGHT, 1.5)))
					and scaled_line == float(_x(Tokens.CONSOLE_LINE_HEIGHT, 1.5)) and scaled_gap == _x(Tokens.CONSOLE_LINE_GAP, 1.5)
					and scaled_caret == _x(Tokens.CONSOLE_CARET_WIDTH, 1.5) and input.get_theme_constant("caret_width") == Tokens.CONSOLE_CARET_WIDTH
					and input.get_theme_color("caret_color") == Tokens.ACCENT,
			"panel %.0f (1.5×: %.0f of %.0f), line %.0f (1.5×: %.0f), row %.0f, caret %d (1.5×: %d), %d lines" % [base_height, scaled_height, scaled_minimum,
					base_line, scaled_line, base_row, input.get_theme_constant("caret_width"), scaled_caret, line_count])
	# The colours of the kinds of line: the opening banner MUTE, an echoed command TEXT_DIM, an answer TEXT, an error ALERT.
	console.run("clear")
	console.print_line("Chiip banner", DevConsole.ROLE_NOTE)
	console.run("fov")
	console.run("nosuch 1")
	var shown: Array[Label] = []
	for child in lines_box.get_children():
		if (child as Label).visible:
			shown.append(child as Label)
	var texts := shown.map(func(label: Label) -> String: return label.text)
	var colors := shown.map(func(label: Label) -> Color: return label.get_theme_color("font_color"))
	_check("The console's lines are coloured by kind from the theme: the opening banner reads \"Chiip M10 · Godot x.y.z · type help\" in MUTE, an echoed command (\"> fov\") in TEXT_DIM, an answer in TEXT, \"Unknown command: nosuch\" in ALERT",
			banner_text.begins_with("Chiip %s · Godot %d.%d.%d · type help" % [DevConsole.BANNER_MILESTONE, Engine.get_version_info().major,
					Engine.get_version_info().minor, Engine.get_version_info().patch])
					and banner_color == Tokens.MUTE
					and texts.size() == 5 and texts[1] == "> fov" and colors[1] == Tokens.TEXT_DIM and texts[2].begins_with("fov = ") and colors[2] == Tokens.TEXT
					and texts[3] == "> nosuch 1" and colors[3] == Tokens.TEXT_DIM and texts[4] == "Unknown command: nosuch" and colors[4] == Tokens.ALERT
					and colors[0] == Tokens.MUTE and texts[0] == "Chiip banner" and (shown[-1].theme_type_variation == &"ConsoleErrorLabel"),
			"lines %s, colours %s" % [texts, colors])
	# The lines sit at the bottom of the strip: the newest is the last label shown, just above the padding.
	await get_tree().process_frame
	var last := shown[-1]
	var area := console.get_node("Panel/Box/OutputMargin") as Control
	_check("Few lines stay at the bottom of the output (bottom-aligned): the newest line ends at the output area's bottom padding, the oldest of the few is well below the top",
			is_equal_approx(last.get_global_rect().end.y, area.get_global_rect().end.y - Tokens.CONSOLE_PAD_BOTTOM)
					and shown[0].get_global_rect().position.y > area.get_global_rect().position.y + Tokens.CONSOLE_PAD_TOP + Tokens.CONSOLE_LINE_HEIGHT,
			"newest ends at %.0f, area ends at %.0f, oldest starts at %.0f" % [last.get_global_rect().end.y, area.get_global_rect().end.y, shown[0].get_global_rect().position.y])
	# Tab completes a command's name; it doesn't move the focus; Up recalls the last command.
	var completed: Array[String] = []
	for typed in ["fo", "FO", "settings_r", "set", "zzz", "map de", "bot_"]:
		input.text = typed
		input.caret_column = typed.length()
		_send(_key_event(KEY_TAB))
		_send(_key_event(KEY_TAB, false))
		completed.append(input.text)
	var focus_kept := get_viewport().gui_get_focus_owner() == input
	var listed := shown[0].get_parent().get_children().filter(func(label: Label) -> bool: return label.visible)
	var last_line := (listed[-1] as Label).text
	_check("Tab completes the command's name: \"fo\" → \"fov \" (any case), \"settings_r\" → \"settings_reset \", \"set\" → \"settings\" (what settings and settings_reset share), nothing for \"zzz\" or once there is an argument; on \"bot_\" (nothing more to add) a second Tab lists bot_add, bot_difficulty and bot_kick; the focus stays on the input",
			completed == ["fov ", "fov ", "settings_reset ", "settings", "zzz", "map de", "bot_"] and focus_kept
					and last_line.contains("bot_add") and last_line.contains("bot_difficulty") and last_line.contains("bot_kick")
					and console.complete("") == "" and console.complete("bo") == "bot_" and console.get_matches("m") == ["map", "money", "mp_friendlyfire"],
			"completed %s, focus kept %s, last line '%s'" % [completed, focus_kept, last_line])
	input.text_submitted.emit("fov")
	_send(_key_event(KEY_UP))
	_send(_key_event(KEY_UP, false))
	var recalled := input.text
	_send(_key_event(KEY_DOWN))
	_send(_key_event(KEY_DOWN, false))
	_check("Up recalls the last command typed and Down brings back an empty line", recalled == "fov" and input.text == "", "recalled '%s', after Down '%s'" % [recalled, input.text])
	console.set_open(false)
	MenuState.reset()
	remove_child(console)
	console.queue_free()


## The Tab scoreboard and its table, as the mockup draws them (M10 task 11, D-137, "15 Scoreboard"): the
## panel, the header (scores, mode and map, the clock), the column titles, the team lines, the rows with the
## class icons, your row, the muted dead rows, scaling by 1.5, and that nothing in it takes the mouse.
func _test_scoreboard() -> void:
	await _new_match()
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	await _wait_for_phase(RoundManager.Phase.LIVE)
	# A clock to read: 1:12 left of the round.
	_rounds.time_left = 72.0
	Input.action_press("scoreboard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var table := board.get_table()
	var panel := board.get_panel()
	var viewer := Teams.viewer_team
	var other := Teams.other(viewer)
	var yours := table.get_row(_player)
	var titles := table.get_node("Titles") as PanelContainer
	var friendly_line := table.get_node("Team%d/Header" % viewer) as PanelContainer
	var enemy_line := table.get_node("Team%d/Header" % other) as PanelContainer
	var child_names := table.get_children().map(func(node: Node) -> String: return String(node.name))
	_check("The Tab scoreboard builds the column titles and both teams (3 + 3 rows, your team first) and shows while Tab is held",
			board.visible and table.get_displayed(viewer).size() == 3 and table.get_displayed(other).size() == 3 and yours != null
					and child_names == ["Titles", "Team%d" % viewer, "Team%d" % other],
			"visible %s, rows %d + %d, children %s" % [board.visible, table.get_displayed(viewer).size(), table.get_displayed(other).size(), child_names])

	# The panel: 880 wide, centred, 64 from the top, ink at 88%, 32 of padding.
	var view_width := get_viewport().get_visible_rect().size.x
	_check("The panel is the mockup's: an overlay panel (ink at 88%) 880 wide, centred, 64 px from the top, with 32 px of padding (the table is 816 wide)",
			panel.theme_type_variation == &"OverlayPanel" and (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.PANEL_OVERLAY
					and panel.size.x == 880.0 and panel.global_position.y == 64.0 and absf(panel.get_global_rect().get_center().x - view_width / 2.0) <= 0.5
					and table.global_position.x - panel.global_position.x == float(Tokens.PANEL_MARGIN_X) and table.size.x == 816.0
					and table.global_position.y - panel.global_position.y == float(Tokens.PANEL_MARGIN_Y) + 48.0 + float(Tokens.HEADER_GAP) + float(Tokens.CONTENT_GAP),
			"panel %s at y %.0f, table %s at x %.0f" % [panel.size, panel.global_position.y, table.size, table.global_position.x - panel.global_position.x])

	# The header: your score at the left (48 px, your colour), the opponent's at the right, two centred lines between them.
	var your_score := board.get_your_score_label()
	var their_score := board.get_enemy_score_label()
	var mode_label := board.get_mode_label()
	var clock_label := board.get_clock_label()
	var lines_height := 2.0 * _theme.default_font.get_height(Tokens.TEXT_SIZE) + Tokens.SCORE_LINES_GAP
	_check("The header reads 'Bomb · Test Map' over 'Round 1 · 1:12' (the mode and the map, then the round and its time left, in DIM), your score at the left in your colour and theirs at the right in the enemy's, 48 px, the whole header 48 high and the lines centred between the scores",
			mode_label.text == "Bomb · Test Map" and clock_label.text == "Round 1 · 1:12" and clock_label.theme_type_variation == &"DimLabel"
					and your_score.theme_type_variation == &"FriendlyScoreLabel" and their_score.theme_type_variation == &"EnemyScoreLabel"
					and your_score.get_theme_color("font_color") == Tokens.FRIENDLY and their_score.get_theme_color("font_color") == Tokens.ENEMY
					and your_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE and their_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE
					and your_score.get_parent().size.y == float(Tokens.TEXT_SIZE_TITLE) and mode_label.get_parent().size.y == lines_height and lines_height == 48.0
					and your_score.global_position.x < mode_label.global_position.x and mode_label.global_position.x < their_score.global_position.x
					and mode_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and clock_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
					and absf(mode_label.get_global_rect().get_center().x - panel.get_global_rect().get_center().x) <= 2.0
					and absf(clock_label.get_global_rect().get_center().x - panel.get_global_rect().get_center().x) <= 2.0
					and your_score.text == "0" and their_score.text == "0",
			"'%s' / '%s', scores '%s' - '%s', header height %.0f" % [mode_label.text, clock_label.text, your_score.text, their_score.text, your_score.get_parent().size.y])

	# The column titles: an empty 32 px column for the class icon, PLAYER, K, D, A (64 px each) and DMG (96), right-aligned, in MUTE, 32 high.
	var title_labels := titles.find_children("*", "Label", true, false)
	var expected_titles: Array = ["Player", "K", "D", "A", "DMG", "ADR"]
	if _rounds.has_economy():
		expected_titles.append("Money")
	var title_texts: Array = title_labels.map(func(label: Node) -> String: return (label as Label).text)
	var title_widths: Array = title_labels.map(func(label: Node) -> float: return (label as Label).size.x)
	var title_icon := titles.find_child("Icon", true, false) as Control
	_check("The column titles are 32 high and in MUTE: a 32 px column for the class icon, then PLAYER, K, D, A and DMG; K, D and A are 64 px wide and DMG 96 (ADR, 64, is M14's, for rounds matches; Money, 96, is M7's, for your team's cash), numbers right-aligned",
			title_texts == expected_titles and titles.size.y == 32.0 and title_icon.size.x == 32.0
					and title_labels.all(func(label: Node) -> bool: return (label as Label).theme_type_variation == &"MuteLabel" and (label as Label).get_theme_color("font_color") == Tokens.MUTE)
					and title_widths.slice(1, 4) == [64.0, 64.0, 64.0] and title_widths[4] == 96.0 and title_widths[5] == 64.0
					and title_labels.slice(1).all(func(label: Node) -> bool: return (label as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT),
			"titles %s, widths %s, height %.0f" % [title_texts, title_widths, titles.size.y])

	# The lines: 2 px in your colour under the titles, 2 px in the enemy's with 16 more above it.
	var first_row := table.get_row(table.get_displayed(viewer)[0])
	var second_row := table.get_row(table.get_displayed(viewer)[1])
	var last_row := table.get_row(table.get_displayed(viewer)[2])
	var enemy_first := table.get_row(table.get_displayed(other)[0])
	_check("Your team's rows sit under a 2 px line in your colour, 8 px under the titles, and the enemy's under a 2 px line in theirs, 16 + 8 px under your last row; every row is 40 high and 8 px from the next, and the line is 8 px above its first row",
			friendly_line.theme_type_variation == &"TeamHeaderFriendly" and enemy_line.theme_type_variation == &"TeamHeaderEnemy"
					and (friendly_line.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.FRIENDLY
					and (enemy_line.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.ENEMY
					and friendly_line.size.y == 2.0 and enemy_line.size.y == 18.0
					and friendly_line.global_position.y - (titles.global_position.y + titles.size.y) == 8.0
					and first_row.global_position.y - (friendly_line.global_position.y + 2.0) == 8.0
					and second_row.global_position.y - (first_row.global_position.y + first_row.size.y) == 8.0
					and first_row.size.y == 40.0 and second_row.size.y == 40.0 and last_row.size.y == 40.0
					and enemy_line.global_position.y - (last_row.global_position.y + last_row.size.y) == 8.0
					and enemy_first.global_position.y - (enemy_line.global_position.y + 18.0) == 8.0 and enemy_first.size.y == 40.0,
			"line heights %.0f / %.0f, row heights %.0f / %.0f" % [friendly_line.size.y, enemy_line.size.y, first_row.size.y, enemy_first.size.y])

	# A row: icon, name, K, D, A, DMG; yours is raised and framed in the accent, the others have nothing behind them.
	var your_box := yours.get_theme_stylebox("panel") as StyleBoxFlat
	var other_row := table.get_row(table.get_displayed(viewer).filter(func(member: Character) -> bool: return member != _player)[0])
	var your_labels := yours.find_children("*", "Label", true, false)
	var your_icon := yours.find_child("Icon", true, false) as TextureRect
	_check("Your row is on the RAISED band with a 2 px accent frame (YouRowPanel) and the other rows have no background (RowPanel); the columns line up in both: the icon column from 16 px in, the name 32 px after it, the numbers right-aligned in 64 / 64 / 64 / 96 px (the money, 96 more, ends the row)",
			yours.theme_type_variation == &"YouRowPanel" and your_box.bg_color == Tokens.YOU_ROW and your_box.border_color == Tokens.ACCENT and your_box.border_width_left == Tokens.BORDER
					and other_row.theme_type_variation == &"RowPanel" and other_row.get_theme_stylebox("panel") is StyleBoxEmpty
					and your_icon.global_position.x - yours.global_position.x == 16.0
					and (your_labels[0] as Label).global_position.x - yours.global_position.x == 16.0 + 32.0
					and (other_row.find_children("*", "Label", true, false)[0] as Label).global_position.x == (your_labels[0] as Label).global_position.x
					and (your_labels[-1] as Label).get_global_rect().end.x == yours.get_global_rect().end.x - 16.0
					and (other_row.find_children("*", "Label", true, false)[-1] as Label).get_global_rect().end.x == (your_labels[-1] as Label).get_global_rect().end.x
					and your_labels.slice(1, 4).all(func(label: Node) -> bool: return (label as Label).size.x == 64.0 and (label as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
					and (your_labels[4] as Label).size.x == 96.0 and (your_labels[0] as Label).get_theme_font_size("font_size") == Tokens.TEXT_SIZE,
			"your row at x %.0f, name at %.0f, last column ends at %.0f of %.0f" % [your_icon.global_position.x, (your_labels[0] as Label).global_position.x,
					(your_labels[-1] as Label).get_global_rect().end.x, yours.get_global_rect().end.x])

	# The class icons: the player's class slot, 16 x 16, in the team colour; a dead player's row is muted.
	var wrong_icons := ""
	for team in [viewer, other]:
		for member in table.get_displayed(team):
			var icon := table.get_row(member).find_child("Icon", true, false) as TextureRect
			var expected_icon := UiIcons.get_icon(table, member.class_data.id)
			var colour := Tokens.FRIENDLY if team == viewer else Tokens.ENEMY
			if expected_icon == null or icon.texture != expected_icon or icon.texture.get_size() != Vector2(16, 16) or icon.modulate != colour \
					or icon.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST or icon.size.y != 16.0:
				wrong_icons += "%s (%s) icon %s %s; " % [member.name, member.class_data.id, icon.texture, icon.modulate]
	_check("Every row shows its player's class icon (the slot named after the class id), 16 × 16 with nearest filtering, tinted in your colour for your team and in the enemy's for theirs",
			wrong_icons.is_empty(), "all six match" if wrong_icons.is_empty() else wrong_icons)
	var victim := table.get_displayed(other)[1]
	victim.take_damage(500.0, Hitbox.Zone.CHEST, _player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var dead_row := table.get_row(victim)
	var dead_labels := dead_row.find_children("*", "Label", true, false)
	var dead_icon := dead_row.find_child("Icon", true, false) as TextureRect
	var living_labels := table.get_row(table.get_displayed(other)[0]).find_children("*", "Label", true, false)
	var living_icon := table.get_row(table.get_displayed(other)[0]).find_child("Icon", true, false) as TextureRect
	_check("A dead player's row is muted: all its text MUTE (MuteLabel) and its class icon LINE-coloured; a living player's row keeps white text and its team-coloured icon",
			table.is_muted(victim) and not table.is_muted(table.get_displayed(other)[0]) and not table.is_muted(_player)
					and dead_labels.all(func(label: Node) -> bool: return (label as Label).get_theme_color("font_color") == Tokens.MUTE)
					and dead_icon.modulate == Tokens.LINE_COLOR
					and living_labels.all(func(label: Node) -> bool: return (label as Label).get_theme_color("font_color") == Tokens.TEXT)
					and living_icon.modulate == Tokens.ENEMY,
			"dead text %s, dead icon %s, living text %s, living icon %s" % [(dead_labels[0] as Label).get_theme_color("font_color"), dead_icon.modulate,
					(living_labels[0] as Label).get_theme_color("font_color"), living_icon.modulate])

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
	_check("Nothing in the scoreboard carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	var blocking: Array[String] = []
	for control: Control in board.find_children("*", "Control", true, false):
		if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(String(control.name))
	_check("No part of the scoreboard takes a mouse click, the table's rebuilt rows included", blocking.is_empty(), "controls that would take clicks: %s" % [blocking])

	# Scaled by 1.5 everything is exactly 1.5 times as big, the rebuilt rows and their icons included.
	board.set_ui_scale(1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var scaled_row := table.get_row(_player)
	var scaled_icon := scaled_row.find_child("Icon", true, false) as TextureRect
	var scaled_labels := scaled_row.find_children("*", "Label", true, false)
	_check("Scaled by 1.5 the scoreboard is exactly 1.5 times as big: the panel 880 → 1320 wide and 96 from the top, rows 40 → 60 high with 12 between them, titles 32 → 48, text 16 → 24, the number columns 64 / 96 → 96 / 144, the icons 16 → 24 (the rows are rebuilt for them), the header scores 72 px",
			panel.size.x == 1320.0 and panel.global_position.y == 96.0 and scaled_row.size.y == 60.0 and table.get_node("Titles").size.y == 48.0
					and table.get_theme_constant("separation") == _x(Tokens.TABLE_GAP, 1.5) and (table.get_node("Team%d" % viewer) as Control).get_theme_constant("separation") == _x(Tokens.TEAM_ROW_GAP, 1.5)
					and (scaled_labels[0] as Label).get_theme_font_size("font_size") == 24 and (scaled_labels[1] as Label).size.x == 96.0 and (scaled_labels[4] as Label).size.x == 144.0
					and scaled_icon.texture.get_size() == Vector2(24, 24) and scaled_icon.size.y == 24.0
					and board.get_your_score_label().get_theme_font_size("font_size") == _x(Tokens.TEXT_SIZE_TITLE, 1.5)
					and (table.get_node("Team%d/Header" % Teams.other(viewer)) as Control).size.y == 27.0,
			"panel %s at y %.0f, row %.0f high, text %d, icon %s, enemy line %.0f" % [panel.size, panel.global_position.y, scaled_row.size.y,
					(scaled_labels[0] as Label).get_theme_font_size("font_size"), scaled_icon.texture.get_size(), (table.get_node("Team%d/Header" % Teams.other(viewer)) as Control).size.y])
	board.set_ui_scale(1.0)
	await get_tree().process_frame
	_check("Back at 1.0 the panel is 880 wide again and the rows are 40 high",
			panel.size.x == 880.0 and table.get_row(_player).size.y == 40.0, "panel %.0f, row %.0f" % [panel.size.x, table.get_row(_player).size.y])
	Input.action_release("scoreboard")
	remove_child(board)
	board.queue_free()


## In a Team Deathmatch (a [RespawnMatch]) the Tab scoreboard's header reads 'Team Deathmatch · <map>' over
## 'First to <kill limit> · <time left>', and "Overtime" instead of the time in overtime; the match-end screen's mode line says the same.
func _test_scoreboard_header_in_team_deathmatch() -> void:
	var rules := RespawnMatch.new()
	await _new_match(5, rules)
	rules.settings.kill_limit = 50
	var board := SCOREBOARD_SCENE.instantiate() as Scoreboard
	add_child(board)
	board.set_round_manager(_rounds)
	await _wait_for_phase(RoundManager.Phase.LIVE)
	_rounds.time_left = 462.0
	Input.action_press("scoreboard")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mode_text := board.get_mode_label().text
	var clock_text := board.get_clock_label().text
	(_rounds as RespawnMatch).overtime = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var overtime_text := board.get_clock_label().text
	var titles := board.get_table().get_node("Titles").find_children("*", "Label", true, false).map(func(label: Node) -> String: return (label as Label).text)
	_check("In a Team Deathmatch the header reads 'Team Deathmatch · Test Map' over 'First to 50 · 7:42' and, in overtime, 'First to 50 · Overtime'; there is no money column (a respawn match has no economy)",
			mode_text == "Team Deathmatch · Test Map" and clock_text == "First to 50 · 7:42" and overtime_text == "First to 50 · Overtime"
					and titles == ["Player", "K", "D", "A", "DMG"],
			"'%s' / '%s' / '%s', titles %s" % [mode_text, clock_text, overtime_text, titles])
	Input.action_release("scoreboard")
	remove_child(board)
	board.queue_free()


## The match-end screen as the mockup draws it (M10 task 11, D-137, "16 Match end"): a full ink page, the
## result in 96 px, the final score either side of the mode and the map, the compact table of both teams
## (nobody muted), and the buttons at the bottom; it scales by 1.5 and its buttons report their clicks.
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
	await get_tree().process_frame
	var table := screen.get_table()
	var late_row := table.get_row(_player)
	var late_labels := late_row.find_children("*", "Label", true, false)
	var late_icon := late_row.find_child("Icon", true, false) as TextureRect
	_check("Rows built after the screen was scaled are scaled too: text 24, number columns 96 / 144, the row 54 high (36 × 1.5), the icon 24 px",
			(late_labels[0] as Label).get_theme_font_size("font_size") == 24 and (late_labels[1] as Label).custom_minimum_size.x == 96.0
					and (late_labels[4] as Label).custom_minimum_size.x == 144.0 and late_row.custom_minimum_size.y == 54.0
					and late_icon.texture.get_size() == Vector2(24, 24),
			"font %d, columns %.0f / %.0f, row %.0f, icon %s" % [(late_labels[0] as Label).get_theme_font_size("font_size"), (late_labels[1] as Label).custom_minimum_size.x,
					(late_labels[4] as Label).custom_minimum_size.x, late_row.custom_minimum_size.y, late_icon.texture.get_size()])
	screen.set_ui_scale(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var background := screen.get_node("Background") as Panel
	var result := screen.get_result_label()
	var your_score := screen.get_your_score_label()
	var their_score := screen.get_enemy_score_label()
	var mode_label := screen.get_mode_label()
	var play_again := screen.get_play_again_button()
	var main_menu_button := screen.get_main_menu_button()
	var next_map := screen.get_next_map_button()
	var view := get_viewport().get_visible_rect().size
	_check("The match-end screen shows 'Victory' and the table of both teams (3 + 3 rows), with 'Play again' focused, on a full ink page that stops mouse clicks",
			screen.visible and result.text == "Victory" and table.get_displayed(0).size() == 3 and table.get_displayed(1).size() == 3
					and play_again.has_focus() and background.theme_type_variation == &"InkPanel" and background.mouse_filter == Control.MOUSE_FILTER_STOP
					and (background.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.INK
					and background.anchor_right == 1.0 and background.anchor_bottom == 1.0,
			"visible %s, result '%s', rows %d + %d, focus on Play again: %s" % [screen.visible, result.text, table.get_displayed(0).size(), table.get_displayed(1).size(), play_again.has_focus()])

	# The header: the result 40 from the top, 96 px Bold in your colour; 16 below it your score, the mode and map in MUTE, theirs.
	var result_trim := result.get_parent() as Control
	var score_line := your_score.get_parent().get_parent() as Control
	var your_trim := your_score.get_parent() as Control
	var their_trim := their_score.get_parent() as Control
	_check("The result is 96 px Bold in your colour, 96 high and 40 px from the top, centred; 16 px under it the score line is 32 high: your score (32 px, your colour), the mode and map in MUTE ('Bomb · Test Map'), theirs (32 px, the enemy's colour), 24 px apart, the three centred as one group",
			result.theme_type_variation == &"VictoryLabel" and result.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO
					and result.get_theme_font("font").resource_path == Tokens.FONT_BOLD and result.get_theme_color("font_color") == Tokens.FRIENDLY
					and result_trim.global_position.y == 40.0 and result_trim.size.y == 96.0 and absf(result.get_global_rect().get_center().x - view.x / 2.0) <= 0.5
					and score_line.global_position.y == 40.0 + 96.0 + 16.0 and your_trim.size.y == 32.0 and their_trim.size.y == 32.0
					and your_score.theme_type_variation == &"FriendlyLargeLabel" and their_score.theme_type_variation == &"EnemyLargeLabel"
					and your_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE and their_score.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE
					and your_score.get_theme_color("font_color") == Tokens.FRIENDLY and their_score.get_theme_color("font_color") == Tokens.ENEMY
					and your_score.text == str(_rounds.score[0]) and their_score.text == str(_rounds.score[1])
					and mode_label.text == "Bomb · Test Map" and mode_label.theme_type_variation == &"MuteLabel" and mode_label.get_theme_color("font_color") == Tokens.MUTE
					and mode_label.global_position.x - (your_trim.global_position.x + your_trim.size.x) == 24.0
					and their_trim.global_position.x - (mode_label.global_position.x + mode_label.size.x) == 24.0
					and absf(((your_trim.global_position.x + their_trim.get_global_rect().end.x) / 2.0) - view.x / 2.0) <= 0.5,
			"result at y %.0f (%.0f high), score line at y %.0f, scores '%s' - '%s', '%s'" % [result_trim.global_position.y, result_trim.size.y, score_line.global_position.y,
					your_score.text, their_score.text, mode_label.text])

	# The table: 800 wide, centred, 224 from the top; titles 28 high, rows 36, nothing between the rows, 12 above the enemy's line.
	var titles := table.get_node("Titles") as Control
	var friendly_line := table.get_node("Team0/Header") as Control
	var enemy_line := table.get_node("Team1/Header") as Control
	var rows0 := table.get_displayed(0).map(func(member: Character) -> Control: return table.get_row(member))
	var rows1 := table.get_displayed(1).map(func(member: Character) -> Control: return table.get_row(member))
	var all_rows: Array = rows0 + rows1
	var muted := _rounds.get_participants().filter(func(member: Character) -> bool: return table.is_muted(member))
	var title_labels := titles.find_children("*", "Label", true, false)
	_check("The table is the mockup's compact one: 800 wide, centred, 224 from the top, titles 28 high (PLAYER, K, D, A, DMG, ADR: no money column here), a 2 px line in your colour and 36 high rows with nothing between them, a 2 px line in the enemy's colour 12 px under your last row, and nobody muted although the three enemies are dead",
			table.size.x == 800.0 and absf(table.get_global_rect().get_center().x - view.x / 2.0) <= 0.5 and table.global_position.y == 224.0
					and titles.size.y == 28.0 and title_labels.map(func(label: Node) -> String: return (label as Label).text) == ["Player", "K", "D", "A", "DMG", "ADR"]
					and friendly_line.size.y == 2.0 and enemy_line.size.y == 14.0
					and friendly_line.global_position.y == titles.global_position.y + 28.0
					and all_rows.all(func(row: Control) -> bool: return row.size.y == 36.0)
					and (rows0[0] as Control).global_position.y == friendly_line.global_position.y + 2.0
					and (rows0[1] as Control).global_position.y == (rows0[0] as Control).global_position.y + 36.0
					and enemy_line.global_position.y == (rows0[2] as Control).global_position.y + 36.0
					and (rows1[0] as Control).global_position.y == enemy_line.global_position.y + 14.0
					and (friendly_line.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.FRIENDLY
					and (enemy_line.get_theme_stylebox("panel") as StyleBoxFlat).border_color == Tokens.ENEMY
					and muted.is_empty() and _rounds.get_participants().filter(func(member: Character) -> bool: return not member.is_alive()).size() == 3,
			"table %s at y %.0f, titles %.0f high, rows %.0f, enemy line %.0f, muted %s" % [table.size, table.global_position.y, titles.size.y,
					(rows0[0] as Control).size.y, enemy_line.size.y, _names(muted)])
	var your_row := table.get_row(_player)
	var your_box := your_row.get_theme_stylebox("panel") as StyleBoxFlat
	_check("Your row is raised and framed in the accent here too, with your class icon in your colour",
			your_row.theme_type_variation == &"YouRowPanel" and your_box.bg_color == Tokens.YOU_ROW and your_box.border_color == Tokens.ACCENT
					and (your_row.find_child("Icon", true, false) as TextureRect).modulate == Tokens.FRIENDLY,
			"your row '%s'" % your_row.theme_type_variation)

	# The buttons: 48 high, 40 from the bottom, centred, 16 apart; Play again filled with the chip, the others outlined.
	var buttons := screen.get_node("Buttons") as HBoxContainer
	var chip := play_again.icon
	_check("At the bottom, 40 up and centred, are 'Play again' (the accent fill with the chip), then 'Main menu' (outlined): 48 high, 24 px padding, 16 px apart; 'Next map' stays hidden without a rotation",
			play_again.text == "Play again" and main_menu_button.text == "Main menu" and not next_map.visible
					and play_again.theme_type_variation == &"TallPrimaryButton" and main_menu_button.theme_type_variation == &"TallButton"
					and play_again.size.y == 48.0 and main_menu_button.size.y == 48.0
					and buttons.global_position.y + buttons.size.y == view.y - 40.0
					and absf(buttons.get_global_rect().get_center().x - view.x / 2.0) <= 0.5
					and main_menu_button.global_position.x - (play_again.global_position.x + play_again.size.x) == 16.0
					and (play_again.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Tokens.ACCENT
					and (main_menu_button.get_theme_stylebox("normal") as StyleBoxFlat).border_color == Tokens.BUTTON_BORDER
					and chip != null and chip.get_size() == Vector2(8, 8) and main_menu_button.icon == null
					and play_again.get_theme_color("icon_normal_color") == Tokens.TEXT_ON_FILL,
			"play again %s, main menu %s, bottom %.0f of %.0f" % [play_again.size, main_menu_button.size, buttons.global_position.y + buttons.size.y, view.y])
	screen.set_next_map("Square")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("In a rotation 'Next map · Square' (outlined, 48 high) comes between 'Play again' and 'Main menu', 16 apart from both",
			next_map.visible and next_map.text == "Next map · Square" and next_map.theme_type_variation == &"TallButton" and next_map.size.y == 48.0
					and next_map.global_position.x - (play_again.global_position.x + play_again.size.x) == 16.0
					and main_menu_button.global_position.x - (next_map.global_position.x + next_map.size.x) == 16.0,
			"text '%s', at x %.0f" % [next_map.text, next_map.global_position.x])
	screen.set_next_map("")
	var menu_presses: Array[int] = [0]
	screen.main_menu_pressed.connect(func() -> void: menu_presses[0] += 1)
	main_menu_button.pressed.emit()
	_check("The last button says 'Main menu' (it was Quit) and reports `main_menu_pressed` when clicked; 'Play again' keeps its name",
			main_menu_button.text == "Main menu" and play_again.text == "Play again" and menu_presses[0] == 1 and not screen.has_signal("quit_pressed"),
			"texts '%s' and '%s', presses %d" % [play_again.text, main_menu_button.text, menu_presses[0]])
	var overrides := _style_or_size_overrides(screen)
	_check("Nothing in the match-end screen carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	screen.set_ui_scale(1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Scaled by 1.5: the result 96 → 144 px at 60 from the top, the table 1200 wide at 336 with rows 54 high and titles 42, the buttons 48 → 72 high, text 16 → 24 px",
			result.get_theme_font_size("font_size") == _x(Tokens.TEXT_SIZE_HERO, 1.5) and (result.get_parent() as Control).global_position.y == 60.0
					and table.size.x == 1200.0 and table.global_position.y == 336.0 and table.get_row(_player).size.y == 54.0
					and table.get_node("Titles").size.y == 42.0 and play_again.size.y == 72.0 and play_again.get_theme_font_size("font_size") == 24
					and play_again.icon.get_size() == Vector2(12, 12) and your_score.get_theme_font_size("font_size") == _x(Tokens.TEXT_SIZE_LARGE, 1.5),
			"result %d, table %s at y %.0f, row %.0f, button %.0f high, chip %s" % [result.get_theme_font_size("font_size"), table.size, table.global_position.y,
					table.get_row(_player).size.y, play_again.size.y, play_again.icon.get_size()])
	screen.set_ui_scale(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Back at 1.0 everything returns to its design size (the result 96 px, the table 800 wide, the rows 36 high, the buttons 48)",
			result.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO and table.size.x == 800.0 and table.get_row(_player).size.y == 36.0
					and play_again.size.y == 48.0 and play_again.icon.get_size() == Vector2(8, 8),
			"result %d, table %.0f, row %.0f" % [result.get_theme_font_size("font_size"), table.size.x, table.get_row(_player).size.y])
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
	var buy_menu := BUY_MENU_SCENE.instantiate() as BuyMenu
	add_child(buy_menu)
	await get_tree().process_frame
	found["buy menu"] = _overrides_below(buy_menu)
	remove_child(buy_menu)
	buy_menu.queue_free()
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
	var result := screen.get_result_label()
	var your_score := screen.get_your_score_label()
	var their_score := screen.get_enemy_score_label()
	_check("After a lost match the title is a DefeatLabel in the enemy team's text colour, while the scores keep their own team colours (yours friendly, theirs enemy), all from the theme",
			result.text == "Defeat" and result.theme_type_variation == &"DefeatLabel"
					and result.get_theme_color("font_color") == Tokens.ENEMY
					and your_score.get_theme_color("font_color") == Tokens.FRIENDLY
					and their_score.get_theme_color("font_color") == Tokens.ENEMY,
			"title '%s' %s, yours %s, theirs %s" % [result.text, result.get_theme_color("font_color"), your_score.get_theme_color("font_color"), their_score.get_theme_color("font_color")])
	remove_child(screen)
	screen.queue_free()
	var loading := LOADING_SCENE.instantiate() as LoadingScreen
	add_child(loading)
	loading.show_screen(PackedStringArray(["Map 1 of 3 · Rotation", "Depot", "Team Deathmatch · first to 50"]))
	await get_tree().process_frame
	found["loading screen (shown)"] = _overrides_below(loading)
	loading.advance(loading.hold_time)
	remove_child(loading)
	loading.queue_free()
	var offenders := {}
	for screen_name: String in found:
		if not (found[screen_name] as Array).is_empty():
			offenders[screen_name] = found[screen_name]
	_check("No menu or overlay carries a theme override of its own (colour, font, size, spacing, style or icon): the settings, pause and class menus, the console, the main menu with match setup, the Tab scoreboard, the match-end screen and the loading screen all take their whole look from the theme",
			offenders.is_empty(), "screens checked: %d, overrides found: %s" % [found.size(), offenders])


# --- The HUD (M10 task 6, D-133) ---


## The HUD's roles exist on the right base types and carry the tokens: sizes, colours and hard
## shadows of the labels (no outline), the line boxes trimmed to the mockups' line height, the
## spacing, the boxes (chips, bars, plates, the dead tint), and the custom "Hud" type that code
## reads the game-state colours and the sizes of the drawn parts from.
func _test_hud_roles() -> void:
	var missing: Array[String] = []
	for variation: String in HUD_VARIATIONS:
		if _theme.get_type_variation_base(variation) != StringName(HUD_VARIATIONS[variation]):
			missing.append(variation)
	_check("All %d HUD roles exist, each on the right base type" % HUD_VARIATIONS.size(), missing.is_empty(),
			"missing or on another base: %s" % [missing])
	var holder := Control.new()
	add_child(holder)
	var shadowless: Array[String] = []
	var outlined: Array[String] = []
	var unshadowed: Array[String] = []
	for variation: String in HUD_VARIATIONS:
		if HUD_VARIATIONS[variation] != "Label":
			continue
		var label := _variation_node(Label.new(), variation, holder)
		var on_plate := variation.begins_with("HudPlate") or variation == "HudAlertPlateLabel"
		if label.get_theme_constant("outline_size") != 0:
			outlined.append(variation)
		if on_plate:
			if label.get_theme_color("font_shadow_color").a != 0.0:
				shadowless.append(variation)
		elif label.get_theme_color("font_shadow_color") != Tokens.SHADOW or label.get_theme_constant("shadow_offset_x") != Tokens.SHADOW_OFFSET \
				or label.get_theme_constant("shadow_offset_y") != Tokens.SHADOW_OFFSET:
			unshadowed.append(variation)
	_check("Every HUD label role has a hard %d px VOID shadow down and right and no outline (text on a plate has no shadow at all)" % Tokens.SHADOW_OFFSET,
			outlined.is_empty() and shadowless.is_empty() and unshadowed.is_empty(),
			"outlined %s, plate text with a shadow %s, without the shadow %s" % [outlined, shadowless, unshadowed])
	var value := _variation_node(Label.new(), "HudValueLabel", holder)
	var large := _variation_node(Label.new(), "HudLargeLabel", holder)
	var reserve := _variation_node(Label.new(), "HudReserveLabel", holder)
	var title := _variation_node(Label.new(), "HudTitleLabel", holder)
	var countdown := _variation_node(Label.new(), "HudCountdownLabel", holder)
	var friendly := _variation_node(Label.new(), "HudFriendlyScoreLabel", holder)
	var small := _variation_node(Label.new(), "HudSmallLabel", holder)
	var alert_text := _variation_node(Label.new(), "HudAlertLabel", holder)
	var bold: Font = load(Tokens.FONT_BOLD)
	_check("The HUD's label roles take their tokens: 16 px small text, 32 px for armor, money and time, 48 px for health, magazine and scores (the friendly one in FRIENDLY), 48 px Bold for the banners, 96 px Bold for the countdown, the reserve in TEXT at 70%, the prompt's seconds ALERT",
			small.get_theme_font_size("font_size") == Tokens.TEXT_SIZE and large.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_LARGE
					and value.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE and friendly.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE
					and friendly.get_theme_color("font_color") == Tokens.FRIENDLY and title.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_TITLE
					and (title.get_theme_font("font") as FontVariation).base_font == bold
					and countdown.get_theme_font_size("font_size") == Tokens.TEXT_SIZE_HERO and (countdown.get_theme_font("font") as FontVariation).base_font == bold
					and reserve.get_theme_color("font_color") == Tokens.HUD_RESERVE_TEXT and alert_text.get_theme_color("font_color") == Tokens.ALERT
					and alert_text.get_theme_font_size("font_size") == Tokens.TEXT_SIZE
					and (value.get_theme_font("font") as FontVariation).base_font.resource_path == FONT_PATH,
			"value %d, large %d, title %d, countdown %d, reserve %s" % [value.get_theme_font_size("font_size"), large.get_theme_font_size("font_size"),
					title.get_theme_font_size("font_size"), countdown.get_theme_font_size("font_size"), reserve.get_theme_color("font_color")])
	var trims := [(large.get_theme_font("font") as FontVariation), (value.get_theme_font("font") as FontVariation), (countdown.get_theme_font("font") as FontVariation)]
	_check("The 32, 48 and 96 px fonts have their line box trimmed by the tokens (top, bottom): HUD_TRIM_LARGE, HUD_TRIM_TITLE, HUD_TRIM_HERO",
			trims[0].spacing_top == -Tokens.HUD_TRIM_LARGE.x and trims[0].spacing_bottom == -Tokens.HUD_TRIM_LARGE.y
					and trims[1].spacing_top == -Tokens.HUD_TRIM_TITLE.x and trims[1].spacing_bottom == -Tokens.HUD_TRIM_TITLE.y
					and trims[2].spacing_top == -Tokens.HUD_TRIM_HERO.x and trims[2].spacing_bottom == -Tokens.HUD_TRIM_HERO.y,
			"large %d/%d, value %d/%d, countdown %d/%d" % [trims[0].spacing_top, trims[0].spacing_bottom, trims[1].spacing_top, trims[1].spacing_bottom,
					trims[2].spacing_top, trims[2].spacing_bottom])
	var gaps := {
		"HudStack": ["VBoxContainer", Tokens.HUD_GAP_STACK], "HudStackBlock": ["VBoxContainer", Tokens.HUD_GAP_BLOCK],
		"HudStackDeath": ["VBoxContainer", Tokens.HUD_GAP_DEATH], "HudStackCentre": ["VBoxContainer", Tokens.HUD_GAP_CENTRE],
		"HudRowStack": ["HBoxContainer", Tokens.HUD_GAP_STACK], "HudRowIcon": ["HBoxContainer", Tokens.HUD_GAP_ICON],
		"HudRowBlock": ["HBoxContainer", Tokens.HUD_GAP_BLOCK], "HudRowBarBomb": ["HBoxContainer", Tokens.HUD_GAP_BAR_BOMB],
		"HudRowBarTdm": ["HBoxContainer", Tokens.HUD_GAP_BAR_TDM], "HudRowStats": ["HBoxContainer", Tokens.HUD_GAP_STATS],
		"HudRowChips": ["HBoxContainer", Tokens.HUD_GAP_CHIPS],
	}
	var wrong_gaps: Array[String] = []
	for role: String in gaps:
		var container := _variation_node(ClassDB.instantiate(gaps[role][0]) as Control, role, holder) as Container
		if container.get_theme_constant("separation") != gaps[role][1]:
			wrong_gaps.append(role)
	_check("The HUD's column and row roles take their spacing from the tokens", wrong_gaps.is_empty(), "wrong: %s" % [wrong_gaps])
	var chip := _variation_node(Panel.new(), "HudHealthChip", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var chip_empty := _variation_node(Panel.new(), "HudHealthChipEmpty", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var alive := _variation_node(Panel.new(), "HudFriendlyPipAlive", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var dead := _variation_node(Panel.new(), "HudEnemyPipDead", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var plate := _variation_node(PanelContainer.new(), "HudPlate", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var alert_plate := _variation_node(PanelContainer.new(), "HudAlertPlate", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var tint := _variation_node(Panel.new(), "HudDeadTint", holder).get_theme_stylebox("panel") as StyleBoxFlat
	_check("The HUD's boxes: health chips TEXT and LINE, an alive chip filled with a VOID hard shadow, a dead one a 2 px frame without fill, plates INK (padded 20) and ALERT (padded 12), the dead tint's colour",
			chip.bg_color == Tokens.TEXT and chip_empty.bg_color == Tokens.LINE_COLOR
					and alive.bg_color == Tokens.FRIENDLY and alive.border_color == Tokens.SHADOW and alive.border_width_right == Tokens.SHADOW_OFFSET and alive.border_width_left == 0
					and dead.bg_color.a == 0.0 and dead.border_color == Tokens.ENEMY and dead.border_width_left == Tokens.BORDER
					and plate.bg_color == Tokens.INK and plate.content_margin_left == Tokens.HUD_PLATE_PAD and plate.content_margin_right == Tokens.HUD_PLATE_PAD
					and alert_plate.bg_color == Tokens.ALERT and alert_plate.content_margin_left == Tokens.HUD_ALERT_PLATE_PAD and tint.bg_color == Tokens.HUD_DEAD_TINT,
			"chip %s/%s, alive %s, dead %s, plate %s/%s, alert plate %s, tint %s" % [chip.bg_color, chip_empty.bg_color, alive.bg_color, dead.border_color,
					plate.bg_color, plate.content_margin_left, alert_plate.bg_color, tint.bg_color])
	_check("The custom 'Hud' type holds what code reads: the alert, the notice (both ALERT), and the sizes of the drawn parts (chip, bar, columns, plates, icons)",
			_theme.get_color("alert", "Hud") == Tokens.ALERT and _theme.get_color("notice", "Hud") == Tokens.ALERT
					and _theme.get_constant("pip_size", "Hud") == Tokens.HUD_PIP_SIZE and _theme.get_constant("chip_width", "Hud") == Tokens.HUD_CHIP_SIZE.x
					and _theme.get_constant("chip_height", "Hud") == Tokens.HUD_CHIP_SIZE.y and _theme.get_constant("chip_health", "Hud") == Tokens.HUD_CHIP_HEALTH
					and _theme.get_constant("chip_count", "Hud") == Tokens.HUD_CHIP_COUNT and _theme.get_constant("bar_width", "Hud") == Tokens.HUD_BAR_SIZE.x
					and _theme.get_constant("bar_height", "Hud") == Tokens.HUD_BAR_SIZE.y and _theme.get_constant("score_width", "Hud") == Tokens.HUD_SCORE_WIDTH
					and _theme.get_constant("centre_width", "Hud") == Tokens.HUD_CENTRE_WIDTH and _theme.get_constant("icon_scale", "Hud") == Tokens.HUD_ICON_SCALE
					and _theme.get_constant("plate_height", "Hud") == Tokens.HUD_PLATE_HEIGHT and _theme.get_constant("alert_plate_height", "Hud") == Tokens.HUD_ALERT_PLATE_HEIGHT,
			"alert %s, pip size %d, chip %d x %d" % [_theme.get_color("alert", "Hud"), _theme.get_constant("pip_size", "Hud"), _theme.get_constant("chip_width", "Hud"),
					_theme.get_constant("chip_height", "Hud")])
	# M10 task 14: the kill feed's plates, the toasts', the prompt's bar, the plant tag's text and the sizes of the feed, the toasts and the hit marker.
	var feed_plate := _variation_node(PanelContainer.new(), "HudFeedPlate", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var feed_kill := _variation_node(PanelContainer.new(), "HudFeedPlateYou", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var feed_death := _variation_node(PanelContainer.new(), "HudFeedPlateDeath", holder).get_theme_stylebox("panel") as StyleBoxFlat
	_check("The kill feed's plates: the ink plate at 72%% padded %d, your kill INK with a %d px TEXT frame, your death INK with an ENEMY frame (the padding inside the frame: %d from the edge)" % [Tokens.HUD_FEED_PAD, Tokens.BORDER, Tokens.HUD_FEED_FRAME_PAD + Tokens.BORDER],
			feed_plate.bg_color == Tokens.PLATE and feed_plate.border_width_left == 0 and feed_plate.content_margin_left == Tokens.HUD_FEED_PAD
					and feed_kill.bg_color == Tokens.INK and feed_kill.border_color == Tokens.TEXT and feed_kill.border_width_left == Tokens.BORDER
					and feed_kill.content_margin_left == Tokens.HUD_FEED_FRAME_PAD + Tokens.BORDER
					and feed_death.bg_color == Tokens.INK and feed_death.border_color == Tokens.ENEMY and feed_death.border_width_top == Tokens.BORDER,
			"plate %s, kill %s/%s, death %s/%s" % [feed_plate.bg_color, feed_kill.bg_color, feed_kill.border_color, feed_death.bg_color, feed_death.border_color])
	var neutral := _variation_node(PanelContainer.new(), "HudToastNeutral", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var match_point := _variation_node(PanelContainer.new(), "HudToastMatchPoint", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var bomb_toast := _variation_node(PanelContainer.new(), "HudToastBomb", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var low_ammo := _variation_node(PanelContainer.new(), "HudToastLowAmmo", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var chip_text := _variation_node(Panel.new(), "HudToastChip", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var chip_ink := _variation_node(Panel.new(), "HudToastChipInk", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var ink_label := _variation_node(Label.new(), "HudPlateInkLabel", holder)
	var alert_label := _variation_node(Label.new(), "HudPlateAlertLabel", holder)
	_check("The toasts: news INK, match point TEXT, the bomb ALERT (all padded %d), low ammo INK with a %d px ALERT frame; the chips TEXT and INK; their text INK on a filled plate, ALERT in the frame" % [Tokens.HUD_TOAST_PAD, Tokens.BORDER],
			neutral.bg_color == Tokens.INK and neutral.content_margin_left == Tokens.HUD_TOAST_PAD and match_point.bg_color == Tokens.TEXT and bomb_toast.bg_color == Tokens.ALERT
					and low_ammo.bg_color == Tokens.INK and low_ammo.border_color == Tokens.ALERT and low_ammo.border_width_left == Tokens.BORDER
					and chip_text.bg_color == Tokens.TEXT and chip_ink.bg_color == Tokens.INK
					and ink_label.get_theme_color("font_color") == Tokens.TEXT_ON_FILL and alert_label.get_theme_color("font_color") == Tokens.ALERT,
			"neutral %s, match point %s, bomb %s, low ammo %s/%s" % [neutral.bg_color, match_point.bg_color, bomb_toast.bg_color, low_ammo.bg_color, low_ammo.border_color])
	var progress_back := _variation_node(Panel.new(), "HudProgressBack", holder).get_theme_stylebox("panel") as StyleBoxFlat
	var progress_fill := _variation_node(Panel.new(), "HudProgressFill", holder).get_theme_stylebox("panel") as StyleBoxFlat
	_check("The prompt's bar: INK with a hard VOID shadow, filled with ALERT",
			progress_back.bg_color == Tokens.INK and progress_back.border_color == Tokens.SHADOW and progress_back.border_width_right == Tokens.SHADOW_OFFSET
					and progress_fill.bg_color == Tokens.ALERT,
			"back %s, fill %s" % [progress_back.bg_color, progress_fill.bg_color])
	_check("The 'Hud' type also holds the feed's plate height and lifetime, the toasts' height, chip and lifetime, the prompt bar and the hit marker's geometry and time",
			_theme.get_constant("feed_height", "Hud") == Tokens.HUD_FEED_HEIGHT and _theme.get_constant("feed_time_ms", "Hud") == Tokens.HUD_FEED_TIME_MS
					and _theme.get_constant("toast_height", "Hud") == Tokens.HUD_TOAST_HEIGHT and _theme.get_constant("toast_chip", "Hud") == Tokens.HUD_TOAST_CHIP
					and _theme.get_constant("toast_time_ms", "Hud") == Tokens.HUD_TOAST_TIME_MS
					and _theme.get_constant("prompt_bar_width", "Hud") == Tokens.HUD_PROMPT_BAR.x and _theme.get_constant("prompt_bar_height", "Hud") == Tokens.HUD_PROMPT_BAR.y
					and _theme.get_constant("hit_inner", "Hud") == Tokens.HUD_HIT_INNER and _theme.get_constant("hit_length", "Hud") == Tokens.HUD_HIT_LENGTH
					and _theme.get_constant("hit_thickness", "Hud") == Tokens.HUD_HIT_THICKNESS and _theme.get_constant("hit_time_ms", "Hud") == Tokens.HUD_HIT_TIME_MS,
			"feed %d / %d ms, toast %d / %d ms, hit %d ms" % [_theme.get_constant("feed_height", "Hud"), _theme.get_constant("feed_time_ms", "Hud"),
					_theme.get_constant("toast_height", "Hud"), _theme.get_constant("toast_time_ms", "Hud"), _theme.get_constant("hit_time_ms", "Hud")])
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
		# The [match] section is match setup's and the [online] one the multiplayer lobby's (M9), not the settings menu's.
		if not has_control and key != &"crosshair_color" and not ["match", "online"].has(Settings.SCHEMA[key]["section"]):
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
	_check("The Controls table: a header row ACTION / KEY 1 / KEY 2 in MUTE (32 high, 220 px key columns), rows 34 high with a 2 px line on top in a table-row panel, the action in DIM, key 1 as a key cap, key 2 as plain text, an empty slot as '-'",
			(header.get_child(0) as Label).text == "Action" and (header.get_child(1) as Label).text == "Key 1" and (header.get_child(2) as Label).text == "Key 2"
					and header_muted and header.custom_minimum_size.y == 32.0 and (header.get_child(1) as Control).custom_minimum_size.x == 220.0
					and jump_row.theme_type_variation == &"TableRowPanel" and jump_row.custom_minimum_size.y == 34.0
					and jump_label.theme_type_variation == &"DimLabel" and cap.theme_type_variation == &"KeyCapButton"
					and plain.theme_type_variation == &"KeySlotButton" and plain.text == "Wheel Down" and empty.text == "-"
					and cap.get_parent().custom_minimum_size.x == 220.0 and plain.get_parent().custom_minimum_size.x == 220.0,
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
	var reload_events := _bound_events(&"reload")
	var reload_keys: Array[Key] = []
	for event in reload_events:
		if event is InputEventKey:
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
	var forward_events := _bound_events(&"move_forward")
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
					and _bound_events(&"jump").size() == 1 and menu.get_notice() == "Jump: Space.",
			"slots '%s' / '%s', notice '%s'" % [menu.get_binding_button(&"jump", 0).text, jump_secondary.text, menu.get_notice()])
	# Backspace clears a slot.
	jump_secondary.pressed.emit()
	_send(_key_event(KEY_BACKSPACE))
	_send(_key_event(KEY_BACKSPACE, false))
	_check("Backspace clears the waiting slot (jump has no keys now) instead of binding Backspace",
			settings.get_binding(&"jump", 1) == null and jump_secondary.text == SettingsMenu.EMPTY_SLOT_TEXT
					and _bound_events(&"jump").is_empty() and not menu.is_listening(),
			"slot '%s', %d event(s)" % [jump_secondary.text, _bound_events(&"jump").size()])
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
			back and _bound_events(&"reload").size() == 1 and menu.get_binding_button(&"move_forward", 0).text == "W"
					and menu.get_binding_button(&"jump", 1).text == "Wheel Down" and menu.get_binding_button(&"toggle_console", 0).text == "`"
					and menu.get_notice() == "Keys are back to their defaults.",
			"slots match the settings: %s, reload %d event(s), notice '%s'" % [back, _bound_events(&"reload").size(), menu.get_notice()])
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
	var window_size := get_tree().root.size
	var window_scale := PixelView.ui_scale_for(Vector2(window_size))
	_check("main.gd scales the menu with the window like the other UI: its 400 px row labels are 400 times the UI scale wide (the tighter of the window's width over 1280 and height over 720; the headless window is %s)" % window_size,
			label_minimum == (Vector2(400, 0) * window_scale).round(), "label minimum %s at scale %.3f" % [label_minimum, window_scale])
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
	var full := first_screen.size() == DevConsole.VISIBLE_LINES and first_screen[0] != "> help"
	var as_columns := seen.filter(func(line: String) -> bool: return line.contains(" · ")).size() >= names.size()
	console.scroll_output(-10000)
	_check("`help` lists every command, `settings` included, one line each as \"usage · description\" (no padded columns, the font isn't monospaced), and all of it can be read: the strip shows %d lines at a time and the rest scrolls back to the echo of the command" % DevConsole.VISIBLE_LINES,
			listed and names.has("settings") and full and as_columns and console.get_visible_lines()[0] != "> help",
			"%d commands, %d lines on the first screen, %d page(s) back to the echo, lines with ' · ': %s" % [
					names.size(), first_screen.size(), pages, as_columns])
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
		items_ok = items_ok and not button.disabled and button.theme_type_variation == &"SmallItemButton" \
				and button.get_node_or_null("Soon") == null
	var title := menu.get_node("Page/Logo/Title") as Label
	var side := menu.get_node("Page/Side") as Panel
	var chips: Array = menu.get_node("Page/Logo/Chips").get_children().map(func(chip: Node) -> String: return String((chip as Control).theme_type_variation))
	_check("The main menu is the mockup's column (D-135): CHIIP with a blue, a red and a lime chip; Play (focused), Practice, Stats, Settings and Quit as menu items with the focus chip; Host and Join enabled, small items with no \"Soon\" label (M9); the mouse is free",
			title.text == "CHIIP" and title.theme_type_variation == &"LogoLabel" and side.theme_type_variation == &"SidePanel"
					and chips == ["FriendlyChip", "EnemyChip", "AccentChip"]
					and texts == ["Play", "Practice", "Stats", "Settings", "Quit"] and online == ["Host", "Join"] and items_ok
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
	_check("A click on Practice picks it: only the bots' row shows, the stored match mode stays Bomb, and its summary names the Shooting Range",
			setup.get_picked_mode() == "practice" and practice_rows and stored.match_mode == "rounds" and setup.get_summary().begins_with("Practice: ")
					and setup.get_summary().contains("Shooting Range"),
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
	_check("The map row offers the quick maps that exist (%s) and the rotation, never the hidden test map or the practice-only Shooting Range (D-141); the rotation starts on the chosen map (Square, Spillway, Depot); a stored map that isn't a quick map plays Depot and no map is shown chosen" % [setup.get_map_paths()],
			setup.get_map_paths() == GameLaunch.rotation_maps() and setup.get_map_paths().size() == 3
					and not setup.get_map_paths().has("res://maps/test_map.tscn") and not setup.get_map_paths().has(Settings.DEFAULT_MAP)
					and not _texts(map_buttons).has("Test Map") and not _texts(map_buttons).has("Shooting Range")
					and GameLaunch.list_maps().size() == setup.get_map_paths().size() and GameLaunch.is_hidden_map("res://maps/test_map.tscn")
					and not GameLaunch.is_hidden_map(Settings.DEFAULT_MATCH_MAP)
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
	main.loading_screen = false
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
	practice.loading_screen = false
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
	other_map.loading_screen = false
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
	# The game scene the menu changes to can't be reached before its _ready: switch its loading screen off for all.
	LoadingScreen.enabled = false
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
		_check("The Practice button changes to the game scene in practice mode: the respawning arena (no rounds) on the Shooting Range, with the difficulty last chosen in match setup (Easy here) for the bots the console adds",
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
	# Esc, and since M15 (D-211) the gamepad's Start.
	var on_esc := events.size() == 2 and events[0] is InputEventKey and (events[0] as InputEventKey).physical_keycode == KEY_ESCAPE \
			and events[1] is InputEventJoypadButton and (events[1] as InputEventJoypadButton).button_index == JOY_BUTTON_START
	_check("The `pause` action is on Esc and the pad's Start only; Esc is not rebindable (not one of Settings.BINDABLE_ACTIONS); the old `toggle_mouse` action no longer exists",
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
			texts == ["Resume", "Settings", "Leave match"] and menu.get_resume_button().has_focus() and menu.get_title().text == "Paused",
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


## The pause menu as the mockup draws it (M10 task 11, D-137, "04 Pause"): the game dimmed, no panel, a centred
## column with the 48 px title, 32 px under it three 352 px wide menu items 4 px apart; the focused item is filled
## with the accent and its chip sits beside its text, the two centred together; the online line is there but
## hidden; it blocks clicks, takes no overrides and scales by exactly 1.5.
func _test_pause_menu_look() -> void:
	var menu := PAUSE_MENU_SCENE.instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	var column := menu.get_column()
	var title := menu.get_title()
	var background := menu.get_background()
	var buttons: Array[Button] = [menu.get_resume_button(), menu.get_settings_button(), menu.get_leave_button()]
	var all_big := buttons.all(func(button: Button) -> bool: return button.theme_type_variation == &"CenteredItemButton" and button.get_theme_font_size("font_size") == 32)
	_check("It is hidden until opened; its look comes from variations: a page column, a 48 px Bold title, three 32 px menu items; it sits between the Tab scoreboard (3) and the match-end screen (5), and keeps running while paused",
			not menu.visible and column.theme_type_variation == &"PageColumn" and title.theme_type_variation == &"TitleLabel" and title.get_theme_font_size("font_size") == 48
					and title.get_theme_font("font").resource_path == Tokens.FONT_BOLD and all_big
					and menu.layer == 4 and menu.process_mode == Node.PROCESS_MODE_ALWAYS,
			"visible %s, column '%s', title %d px, menu items %s, layer %d, process mode %d" % [
					menu.visible, column.theme_type_variation, title.get_theme_font_size("font_size"), all_big, menu.layer, menu.process_mode])
	var overrides := _style_or_size_overrides(menu)
	_check("Nothing in the pause menu carries a stylebox or font-size override of its own, so the theme alone decides its look",
			overrides.is_empty(), "controls with overrides: %s" % [overrides])
	_check("A full-screen dim (a backdrop panel: void at 62%) and the column both stop mouse clicks, so no click reaches the player controls behind the menu, and there is no panel (a dimmed game, a column)",
			background.theme_type_variation == &"BackdropPanel" and (background.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.BACKDROP
					and background.mouse_filter == Control.MOUSE_FILTER_STOP and background.anchor_left == 0.0 and background.anchor_top == 0.0
					and background.anchor_right == 1.0 and background.anchor_bottom == 1.0 and column.mouse_filter == Control.MOUSE_FILTER_STOP
					and menu.find_children("*", "PanelContainer", true, false).is_empty(),
			"background filter %d, anchors (%.0f, %.0f, %.0f, %.0f), column filter %d" % [background.mouse_filter, background.anchor_left,
					background.anchor_top, background.anchor_right, background.anchor_bottom, column.mouse_filter])

	# The column: the title, then the items 32 below it, 352 wide, 48 high and 4 apart, the text centred; the online line is hidden.
	menu.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var title_trim := title.get_parent() as Control
	var items := buttons[0].get_parent() as Control
	var online := menu.get_online_note()
	var view := get_viewport().get_visible_rect().size
	_check("The title is 48 high with the items 32 below it; they are 352 wide, 48 high and 4 apart, their text centred; the column is centred on the screen; the mockup's line 'Online · the match keeps running' is in the scene but hidden (single player), and set_online_note_visible() shows it",
			title_trim.size.y == 48.0 and items.size.x == 352.0 and items.global_position.y - (title_trim.global_position.y + title_trim.size.y) == 32.0
					and buttons.all(func(button: Button) -> bool: return button.size.x == 352.0 and button.size.y == 48.0 and button.alignment == HORIZONTAL_ALIGNMENT_CENTER)
					and buttons[1].global_position.y - (buttons[0].global_position.y + 48.0) == 4.0 and buttons[2].global_position.y - (buttons[1].global_position.y + 48.0) == 4.0
					and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and absf(items.get_global_rect().get_center().x - view.x / 2.0) <= 0.5
					and absf(column.get_global_rect().get_center().y - view.y / 2.0) <= 1.0
					and online.text == "Online · the match keeps running" and not online.visible and online.theme_type_variation == &"DimLabel",
			"title %.0f high, items %s, button %s, online visible %s" % [title_trim.size.y, items.size, buttons[0].size, online.visible])
	menu.set_online_note_visible(true)
	var online_shown := online.visible
	menu.set_online_note_visible(false)

	# The focus chip: the focused item has it, the others don't; chip, gap and text are centred as one group.
	var resume := menu.get_resume_button()
	var settings_button := menu.get_settings_button()
	resume.grab_focus()
	await get_tree().process_frame
	var resume_chip := resume.get_node("Chip") as Control
	var settings_chip := settings_button.get_node("Chip") as Control
	var font := resume.get_theme_font("font")
	var text_width := font.get_string_size(resume.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var group_width := 8.0 + float(Tokens.BUTTON_ICON_GAP) + text_width
	var plain_chip_state := resume_chip.visible and not settings_chip.visible and resume.icon != null and settings_button.icon == null
	var inline_chip_size: Vector2 = resume.icon.get_size() if resume.icon != null else Vector2.ZERO
	var chip_left := resume_chip.position.x
	var chip_ok := absf(chip_left - roundf((352.0 - group_width) / 2.0)) <= 1.0 and resume_chip.position.y == 20.0 and resume_chip.size == Vector2(8, 8) \
			and (resume_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Tokens.TEXT_ON_FILL
	settings_button.grab_focus()
	await get_tree().process_frame
	var moved := settings_chip.visible and not resume_chip.visible and settings_button.icon != null and resume.icon == null
	_check("The focused item is filled with the accent and has the chip: 8 px square in ink, 16 px before its text, the group centred in the 352 px item and level with it; when the focus moves on, the chip goes with it and the old item's text is centred on its own again",
			online_shown and plain_chip_state and chip_ok and moved and (resume.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == Tokens.ACCENT
					and resume.get_theme_color("font_focus_color") == Tokens.TEXT_ON_FILL,
			"chip at x %.1f (group %.0f of 352), y %.0f, moved with focus %s" % [chip_left, group_width, resume_chip.position.y, moved])
	var lit_before := settings_chip.visible

	menu.set_ui_scale(1.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var scaled_items := buttons[0].get_parent() as Control
	var settings_chip_size := settings_chip.size
	var scaled := scaled_items.size.x == 528.0 and title.get_theme_font_size("font_size") == 72 and buttons[0].get_theme_font_size("font_size") == 48 \
			and settings_chip_size == Vector2(12, 12) and settings_button.icon != null and settings_button.icon.get_size() == Vector2(12, 12) \
			and scaled_items.global_position.y - ((title.get_parent() as Control).global_position.y + (title.get_parent() as Control).size.y) == 48.0
	menu.set_ui_scale(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored := (buttons[0].get_parent() as Control).size.x == 352.0 and title.get_theme_font_size("font_size") == 48 \
			and buttons[0].get_theme_font_size("font_size") == 32 and settings_chip.size == Vector2(8, 8)
	_check("Scaled by 1.5 the items go 352 → 528 px wide, the title 48 → 72 px, the items' text 32 → 48 px, the gap under the title 32 → 48 and the chip 8 → 12 px; back at 1.0 each returns to its design size",
			scaled and restored and lit_before and inline_chip_size == Vector2(8, 8),
			"scaled %s, restored %s, chip %s" % [scaled, restored, settings_chip_size])
	remove_child(menu)
	menu.queue_free()
	MenuState.reset()


## Leave match (and the console's `disconnect` over the pause menu) change to the
## main menu with the game unpaused, in the real flow through the scenes.
func _test_pause_leaves_the_game() -> void:
	LoadingScreen.enabled = false
	var tree := get_tree()
	var shared := Settings.get_instance()
	_remove_temp_file()
	shared.load_from_disk(TEMP_PATH)
	var holder := Node.new()
	tree.root.add_child(holder)
	tree.current_scene = holder
	var rules := MatchSettings.new()
	rules.freeze_time = 0.3
	GameLaunch.start_match(MAP_SCENE.resource_path, rules)
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


# --- The loading screen (M10 task 15, D-138) ---


## The three lines, built by [MatchText] from the rules alone: Team Deathmatch in a rotation (the map's number, the
## kill limit), Bomb (the rounds to win), practice, and a missing rule set.
func _test_loading_texts() -> void:
	var deathmatch := MatchSettings.new()
	deathmatch.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	var bomb := MatchSettings.new()
	bomb.rounds_to_win = 7
	var rotation := MatchText.loading_lines(deathmatch, false, "res://maps/square.tscn", 1, 3)
	_check("A Team Deathmatch in a rotation says \"Map 2 of 3 · Rotation\", the map's title and \"Team Deathmatch · first to 50\" (the kill limit)",
			rotation == PackedStringArray(["Map 2 of 3 · Rotation", "Square", "Team Deathmatch · first to 50"]), "%s" % [rotation])
	deathmatch.kill_limit = 25
	var single := MatchText.loading_lines(bomb, false, "res://maps/depot.tscn")
	_check("The kill limit and the rounds to win come from the rules: first to 25, first to 7 rounds; without a rotation the first line is the mode's name",
			MatchText.loading_mode_line(deathmatch, false) == "Team Deathmatch · first to 25"
					and single == PackedStringArray(["Bomb", "Depot", "Bomb · first to 7 rounds"]) and MatchText.loading_kicker(deathmatch, false) == "Team Deathmatch",
			"%s, %s" % [MatchText.loading_mode_line(deathmatch, false), single])
	var practice := MatchText.loading_lines(bomb, true, "res://maps/test_map.tscn")
	_check("Practice says \"Practice\", the map's title and \"Practice · bots respawn\"; a null rule set doesn't break the lines (Bomb, the default rounds)",
			practice == PackedStringArray(["Practice", "Test Map", "Practice · bots respawn"])
					and MatchText.loading_lines(null, false, "res://maps/depot.tscn") == PackedStringArray(["Bomb", "Depot", "Bomb · first to 5 rounds"]),
			"%s, %s" % [practice, MatchText.loading_lines(null, false, "res://maps/depot.tscn")])


## The band, the two columns and the squares, in design size and at 1.5 times (1080p): the sizes are the tokens,
## the roles carry the tokens' colours, and the squares go done / current / still to come as time passes.
func _test_loading_screen_look() -> void:
	LoadingScreen.enabled = true
	_check("The loading screen's roles carry the tokens: TextChip is the text colour, LineChip the line colour, the column's gap is LOADING_GAP, the squares are CHIP_GAP apart",
			(_theme.get_stylebox("panel", "TextChip") as StyleBoxFlat).bg_color == Tokens.TEXT
					and (_theme.get_stylebox("panel", "LineChip") as StyleBoxFlat).bg_color == Tokens.LINE_COLOR
					and _theme.get_constant("separation", "LoadingColumn") == Tokens.LOADING_GAP and Tokens.CHIP_GAP == 6
					and _theme.get_constant("separation", "ChipRow") == Tokens.CHIP_GAP,
			"gap %d, chip gap %d" % [_theme.get_constant("separation", "LoadingColumn"), _theme.get_constant("separation", "ChipRow")])
	var screen := LOADING_SCENE.instantiate() as LoadingScreen
	screen.hold_time = 12.0
	add_child(screen)
	_check("A new loading screen is hidden, isn't showing and has not paused the game", not screen.visible and not LoadingScreen.is_showing() and not get_tree().paused,
			"visible %s, showing %s" % [screen.visible, LoadingScreen.is_showing()])
	screen.show_screen(MatchText.loading_lines(null, false, "res://maps/square.tscn", 1, 3))
	var view := get_viewport().get_visible_rect().size
	var rows := {}
	for factor: float in [1.0, 1.5]:
		screen.set_ui_scale(factor)
		await get_tree().process_frame
		await get_tree().process_frame
		var left := screen.get_left_column()
		var right := screen.get_right_column()
		var chips := screen.get_chips()
		var name_trim := screen.get_map_name_label().get_parent() as Control
		var kicker := left.get_child(0) as Control
		var mode_line := left.get_child(2) as Control
		var status := right.get_child(0) as Control
		var chip_row := right.get_child(1) as Control
		var gap := roundf(Tokens.LOADING_GAP * factor)
		var margin := roundf(Tokens.LOADING_MARGIN * factor)
		rows[factor] = {
			"band": screen.get_band().size.y == roundf(Tokens.LOADING_BAND_HEIGHT * factor),
			"left": left.position.x == margin and left.position.y + left.size.y == view.y - margin,
			"right": right.position.x + right.size.x == view.x - margin and right.position.y + right.size.y == view.y - margin,
			"left gaps": name_trim.position.y - (kicker.position.y + kicker.size.y) == gap and mode_line.position.y - (name_trim.position.y + name_trim.size.y) == gap,
			"right gap": chip_row.position.y - (status.position.y + status.size.y) == gap,
			"chips": chips.size() == Tokens.LOADING_CHIPS and chips[0].size == Vector2.ONE * roundf(Tokens.LOADING_CHIP * factor)
					and chips[1].position.x - (chips[0].position.x + chips[0].size.x) == roundf(Tokens.CHIP_GAP * factor),
			"right aligned": status.position.x + status.size.x == right.size.x and chip_row.position.x + chip_row.size.x == right.size.x,
			"hero": screen.get_map_name_label().get_theme_font_size("font_size") == roundi(Tokens.TEXT_SIZE_HERO * factor)
					and absf(name_trim.size.y - Tokens.TEXT_SIZE_HERO * factor) <= 1.0,
		}
	for factor: float in rows:
		var failed: Array = []
		for part: String in rows[factor]:
			if not rows[factor][part]:
				failed.append(part)
		_check("At %s times the size the band is %d high, the columns stand %d from the side and bottom edges, the lines and the squares %d apart, the squares are %d with %d between them, the map's name is 96 px (trimmed to 96 high) and the right column is right-aligned"
				% [factor, roundi(Tokens.LOADING_BAND_HEIGHT * factor), roundi(Tokens.LOADING_MARGIN * factor), roundi(Tokens.LOADING_GAP * factor),
				roundi(Tokens.LOADING_CHIP * factor), roundi(Tokens.CHIP_GAP * factor)], failed.is_empty(), "failed parts %s" % [failed])
	screen.set_ui_scale(1.0)
	_check("The band is an ink panel that takes no mouse; the lines are the ones given",
			screen.get_band().theme_type_variation == &"InkPanel" and screen.get_band().mouse_filter == Control.MOUSE_FILTER_IGNORE
					and screen.get_lines() == PackedStringArray(["Map 2 of 3 · Rotation", "Square", "Bomb · first to 5 rounds"]),
			"lines %s" % [screen.get_lines()])
	# The squares: none done at the start (the first is the current one), then they fill evenly over the hold time.
	var start_roles := _chip_roles(screen)
	screen.advance(7.5)
	var middle_roles := _chip_roles(screen)
	var middle_done := screen.get_done_chips()
	var colours_ok := true
	for chip in screen.get_chips():
		var expected := Tokens.TEXT if chip.theme_type_variation == &"TextChip" else (Tokens.ACCENT if chip.theme_type_variation == &"AccentChip" else Tokens.LINE_COLOR)
		colours_ok = colours_ok and (chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == expected
	_check("The squares start with the first one current (lime) and fill with the time: after 7.5 of 12 seconds seven are done (text colour), the eighth is current and four are still to come (line colour)",
			start_roles == ["AccentChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip", "LineChip"]
					and middle_done == 7
					and middle_roles == ["TextChip", "TextChip", "TextChip", "TextChip", "TextChip", "TextChip", "TextChip", "AccentChip", "LineChip", "LineChip", "LineChip", "LineChip"]
					and colours_ok, "start %s, middle %s (%d done)" % [start_roles, middle_roles, middle_done])
	screen.advance(100.0)
	_check("When the hold time is over the screen hides itself and gives the pause back", not screen.visible and not LoadingScreen.is_showing() and not get_tree().paused,
			"visible %s, paused %s" % [screen.visible, get_tree().paused])
	remove_child(screen)
	screen.queue_free()
	await get_tree().process_frame


## The roles of the squares, left to right.
func _chip_roles(screen: LoadingScreen) -> Array:
	var roles: Array = []
	for chip in screen.get_chips():
		roles.append(String(chip.theme_type_variation))
	return roles


## The loading screen in the real game: a launch from the menu (a rotation's Team Deathmatch) and the next map show it
## with the game paused and the HUD hidden, the squares fill, it hides and unpauses; a restart doesn't show it; Esc,
## the console key, B, M and Tab do nothing under it (a Bomb launch), and everything works after; practice's lines.
func _test_loading_screen_in_the_game() -> void:
	LoadingScreen.enabled = true
	var tree := get_tree()
	var rules := MatchSettings.new()
	rules.game_mode = MatchSettings.GameMode.TEAM_RESPAWN
	var rotation: Array[String] = ["res://maps/depot.tscn", "res://maps/square.tscn", "res://maps/spillway.tscn"]
	GameLaunch.start_match(rotation[0], rules, rotation)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	var screen := main.get_node("LoadingScreen") as LoadingScreen
	screen.hold_time = 0.5
	add_child(main)
	await tree.process_frame
	await tree.process_frame
	var hud := main.get_node("HUD") as CanvasLayer
	var manager := main.get_map().get_node_or_null("RespawnMatch") as RoundManager
	var first_lines := screen.get_lines()
	var first_state := LoadingScreen.is_showing() and tree.paused and not hud.visible and screen.get_done_chips() < Tokens.LOADING_CHIPS
	var class_menu_under_band := (main.get_node("ClassMenu") as ClassMenu).is_open()
	var clock := manager.time_left if manager != null else -1.0
	for i in 8:
		await tree.process_frame
	var filled := screen.get_done_chips()
	_check("A map from the menu's launch shows the loading screen over the game: \"Map 1 of 3 · Rotation\", Depot, \"Team Deathmatch · first to 50\"; the tree is paused and the HUD hidden",
			first_state and first_lines == PackedStringArray(["Map 1 of 3 · Rotation", "Depot", "Team Deathmatch · first to 50"]) and manager != null,
			"lines %s, showing %s, paused %s, hud visible %s" % [first_lines, LoadingScreen.is_showing(), tree.paused, hud.visible])
	_check("While it shows the match clock stands still and the squares fill with the time (%d done after a few frames)" % filled,
			manager != null and manager.time_left == clock and filled > 0 and filled < Tokens.LOADING_CHIPS,
			"clock %.3f → %.3f, done %d" % [clock, manager.time_left if manager != null else -1.0, filled])
	for i in 200:
		if not LoadingScreen.is_showing():
			break
		await tree.process_frame
	_check("The class draft doesn't open under the loading band (D-152): it stays closed while the screen shows",
			not class_menu_under_band, "class menu open under the band: %s" % class_menu_under_band)
	_check("After the hold time the screen hides and the game is unpaused, and only then the class draft opens (mockup 08); it keeps the HUD hidden",
			not LoadingScreen.is_showing() and not tree.paused and not hud.visible and (main.get_node("ClassMenu") as ClassMenu).is_open(),
			"showing %s, paused %s, hud %s" % [LoadingScreen.is_showing(), tree.paused, hud.visible])
	_close_class_menu(main)
	_check("Closing the class menu brings the HUD back", hud.visible, "hud %s" % hud.visible)
	# The rotation moves on: the band comes first, then the map is loaded, then the rest of the hold time.
	var before_map: String = main.get_map().scene_file_path
	main.next_map()
	var next_state := LoadingScreen.is_showing() and tree.paused and not hud.visible
	await tree.process_frame
	var still_old: bool = main.get_map().scene_file_path == before_map
	for i in 6:
		await tree.process_frame
	var next_lines := screen.get_lines()
	var next_menu_under_band := LoadingScreen.is_showing() and (main.get_node("ClassMenu") as ClassMenu).is_open()
	_check("next_map() shows the screen at once (paused, HUD hidden), lets a frame draw before it loads the map, and then names the new one: \"Map 2 of 3 · Rotation\", Square",
			next_state and still_old and before_map == "res://maps/depot.tscn" and main.get_map().scene_file_path == "res://maps/square.tscn"
					and next_lines == PackedStringArray(["Map 2 of 3 · Rotation", "Square", "Team Deathmatch · first to 50"]),
			"showing %s, old map first %s, map now %s, lines %s" % [next_state, still_old, main.get_map().scene_file_path, next_lines])
	_check("The new map's class draft doesn't open under the band either", not next_menu_under_band, "open under the band: %s" % next_menu_under_band)
	for i in 200:
		if not LoadingScreen.is_showing():
			break
		await tree.process_frame
	var next_menu_opened := (main.get_node("ClassMenu") as ClassMenu).is_open()
	_close_class_menu(main)
	_check("It hides again after the hold time and the new map's class draft opens then (unpaused, HUD back once it is closed)",
			next_menu_opened and not LoadingScreen.is_showing() and not tree.paused and hud.visible, "menu opened %s, showing %s, paused %s" % [next_menu_opened, LoadingScreen.is_showing(), tree.paused])
	main.restart_match()
	await tree.process_frame
	await tree.process_frame
	# The new match's class menu opens by itself and hides the HUD, as it does; the loading screen hides nothing.
	_close_class_menu(main)
	_check("restart_match() shows no loading screen: the game isn't paused and the HUD stays", not LoadingScreen.is_showing() and not tree.paused and hud.visible,
			"showing %s, paused %s" % [LoadingScreen.is_showing(), tree.paused])
	remove_child(main)
	main.queue_free()
	await tree.process_frame
	Teams.friendly_fire = false
	GameLaunch.clear()
	MenuState.reset()

	# Bomb on the test map: the lines, and the keys that do nothing while it shows.
	var bomb := MatchSettings.new()
	bomb.rounds_to_win = 7
	GameLaunch.start_match(TEST_MAP, bomb)
	var bomb_main := MAIN_SCENE.instantiate()
	bomb_main.load_settings = false
	var bomb_screen := bomb_main.get_node("LoadingScreen") as LoadingScreen
	bomb_screen.hold_time = 100.0
	add_child(bomb_main)
	await tree.process_frame
	await tree.process_frame
	var bomb_lines := bomb_screen.get_lines()
	var pause_menu: PauseMenu = bomb_main.get_pause_menu()
	var buy_menu := bomb_main.get_node("BuyMenu") as BuyMenu
	var class_menu := bomb_main.get_node("ClassMenu") as ClassMenu
	var board := bomb_main.get_node("Scoreboard") as Scoreboard
	# The class menu that opened at the match start would keep the pause menu closed by itself.
	_close_class_menu(bomb_main)
	var class_open := class_menu.is_open()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_send(_action_event("toggle_console"))
	_send(_action_event("buy_menu"))
	_send(_action_event("class_menu"))
	Input.action_press("scoreboard")
	await tree.process_frame
	await tree.process_frame
	var swallowed := not pause_menu.is_open() and not DevConsole.is_open and not buy_menu.is_open() and class_menu.is_open() == class_open and not board.visible \
			and LoadingScreen.is_showing() and tree.paused
	Input.action_release("scoreboard")
	_check("Under the loading screen of a Bomb match (\"Bomb\", \"first to 7 rounds\") Esc, the console key, B, M and Tab do nothing: no pause menu, console, buy menu or scoreboard, and the class menu stays closed",
			bomb_lines == PackedStringArray(["Bomb", "Test Map", "Bomb · first to 7 rounds"]) and swallowed,
			"lines %s, pause %s, console %s, buy %s, board %s, class menu %s (was %s)" % [bomb_lines, pause_menu.is_open(), DevConsole.is_open, buy_menu.is_open(), board.visible, class_menu.is_open(), class_open])
	bomb_screen.advance(100.0)
	_close_class_menu(bomb_main)
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Once it has hidden, Esc opens the pause menu again (and pauses the game by its own right)", not LoadingScreen.is_showing() and pause_menu.is_open() and tree.paused,
			"showing %s, pause menu %s" % [LoadingScreen.is_showing(), pause_menu.is_open()])
	pause_menu.close()
	remove_child(bomb_main)
	bomb_main.queue_free()
	await tree.process_frame
	Teams.friendly_fire = false
	GameLaunch.clear()
	MenuState.reset()
	tree.paused = false

	# Practice, and a game that has the switch off.
	GameLaunch.start_practice(TEST_MAP, GameLaunch.difficulty_named("easy"))
	var practice_main := MAIN_SCENE.instantiate()
	practice_main.load_settings = false
	add_child(practice_main)
	await tree.process_frame
	var practice_screen := practice_main.get_node("LoadingScreen") as LoadingScreen
	var practice_lines := practice_screen.get_lines()
	var practice_showing := LoadingScreen.is_showing()
	practice_screen.advance(100.0)
	remove_child(practice_main)
	practice_main.queue_free()
	await tree.process_frame
	GameLaunch.start_match(TEST_MAP, MatchSettings.new())
	var quiet := MAIN_SCENE.instantiate()
	quiet.load_settings = false
	quiet.loading_screen = false
	add_child(quiet)
	await tree.process_frame
	var quiet_shows := LoadingScreen.is_showing() or tree.paused
	remove_child(quiet)
	quiet.queue_free()
	await tree.process_frame
	_check("Practice says \"Practice\", Test Map, \"Practice · bots respawn\"; a game with loading_screen off shows nothing and stays unpaused",
			practice_showing and practice_lines == PackedStringArray(["Practice", "Test Map", "Practice · bots respawn"]) and not quiet_shows,
			"practice %s, lines %s, quiet shows %s" % [practice_showing, practice_lines, quiet_shows])
	Teams.friendly_fire = false
	GameLaunch.clear()
	MenuState.reset()
	tree.paused = false


# --- The compass (M11, D-180) ---


## The HUD's compass: tokens in the theme, N/E/S/W that follow the view, and a red square where an enemy fires: only
## enemies within gunshot range, one per shooter, moving with your view, fading out after about two seconds.
func _test_compass() -> void:
	_check("The compass's sizes are tokens in the theme's Hud type: arc, tick step and sizes, thickness, the square's size, time and fade",
			_theme.get_constant("compass_arc", "Hud") == Tokens.HUD_COMPASS_ARC and _theme.get_constant("compass_tick_step", "Hud") == Tokens.HUD_COMPASS_TICK_STEP
					and _theme.get_constant("compass_tick_small", "Hud") == Tokens.HUD_COMPASS_TICK_SMALL and _theme.get_constant("compass_tick_large", "Hud") == Tokens.HUD_COMPASS_TICK_LARGE
					and _theme.get_constant("compass_thickness", "Hud") == Tokens.HUD_COMPASS_THICKNESS and _theme.get_constant("compass_marker", "Hud") == Tokens.HUD_COMPASS_MARKER
					and _theme.get_constant("compass_marker_time_ms", "Hud") == Tokens.HUD_COMPASS_MARKER_TIME_MS and _theme.get_constant("compass_fade_ms", "Hud") == Tokens.HUD_COMPASS_FADE_MS,
			"arc %d, step %d, square %d for %d ms" % [_theme.get_constant("compass_arc", "Hud"), _theme.get_constant("compass_tick_step", "Hud"),
					_theme.get_constant("compass_marker", "Hud"), _theme.get_constant("compass_marker_time_ms", "Hud")])
	var main: Node = await _new_game()
	var compass := main.get_node("HUD/Compass") as Compass
	var player := _player
	var enemies: Array[Character] = []
	var mates: Array[Character] = []
	for character in _rounds.get_participants():
		if character == player:
			continue
		(enemies if character.team != player.team else mates).append(character)
	# Heading: 0 looking north (-Z), 90 east (+X), 180 south, 270 west; the letter is in the middle when you look at it.
	var headings: Array[float] = []
	for target in [Vector3(0, 0, -10), Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3(-10, 0, 0)]:
		player.aim_at(player.get_eye_position() + target)
		await get_tree().process_frame
		headings.append(snappedf(compass.get_heading(), 0.1))
	_check("The compass heading follows the view: north 0, east 90, south 180, west 270 degrees",
			headings == [0.0, 90.0, 180.0, 270.0], "headings %s" % [headings])
	# An enemy's shot: a square at its bearing, relative to where you look.
	player.aim_at(player.get_eye_position() + Vector3(0, 0, -10))
	await get_tree().process_frame
	var shooter := enemies[0]
	var east := player.global_position + Vector3(20, 0, 0)
	Noises.announce_shot(east, shooter)
	var offsets := compass.get_marker_offsets()
	var first := offsets[0] if not offsets.is_empty() else 999.0
	_check("An enemy's shot puts a square at its bearing: a shot due east while you look north is 90 degrees to the right",
			compass.get_marker_count() == 1 and is_equal_approx(first, 90.0) and is_equal_approx(compass.get_marker_alpha(), 1.0),
			"%d squares, offsets %s, alpha %.2f" % [compass.get_marker_count(), offsets, compass.get_marker_alpha()])
	# It moves with your view and stays on the strip's edge when it is out of the arc.
	player.aim_at(player.get_eye_position() + Vector3(10, 0, 0))
	await get_tree().process_frame
	var turned := compass.get_marker_offsets()
	var in_middle := turned.size() == 1 and absf(turned[0]) < 0.001
	var rect := compass.get_marker_rects()[0] if compass.get_marker_count() == 1 else Rect2()
	player.aim_at(player.get_eye_position() + Vector3(0, 0, -10))
	await get_tree().process_frame
	var edge := compass.get_marker_rects()[0] if compass.get_marker_count() == 1 else Rect2()
	_check("The square follows your turn: looking at the shot puts it in the middle of the strip; 90 degrees off it sits at the strip's right end (the arc is 120 degrees)",
			in_middle and absf(rect.get_center().x - compass.size.x / 2.0) <= 1.0 and absf(edge.get_center().x - compass.x_for_offset(Tokens.HUD_COMPASS_ARC / 2.0)) <= 1.0,
			"offsets %s, centre %.1f (strip %.0f wide), edge %.1f" % [turned, rect.get_center().x, compass.size.x, edge.get_center().x])
	# One square per shooter: a new shot from the same enemy moves it and restarts its time.
	compass.advance(1.5)
	var faded := compass.get_marker_alpha()
	Noises.announce_shot(player.global_position + Vector3(-20, 0, 0), shooter)
	var moved := compass.get_marker_offsets()
	_check("An enemy has one square: a new shot from him moves it (to the west, 90 degrees to the left) and starts the time over",
			compass.get_marker_count() == 1 and faded < 1.0 and moved.size() == 1 and is_equal_approx(moved[0], -90.0) and is_equal_approx(compass.get_marker_alpha(), 1.0),
			"%d squares, alpha before the shot %.2f, now %s" % [compass.get_marker_count(), faded, moved])
	# A second enemy has a second square.
	Noises.announce_shot(player.global_position + Vector3(0, 0, 20), enemies[1])
	var two := compass.get_marker_count()
	# Fading: full for the first second, then it fades, and it is gone after the 2 seconds.
	compass.advance(1.0)
	var full := compass.get_marker_alpha()
	compass.advance(0.5)
	var half := compass.get_marker_alpha()
	compass.advance(0.6)
	_check("A square stays about 2 seconds: full opacity for the first second, fading over the second, gone after (%d squares with two shooters)" % two,
			two == 2 and full > 0.99 and absf(half - 0.5) < 0.01 and compass.get_marker_count() == 0,
			"two shooters %d, alpha %.2f after 1 s, %.2f after 1.5 s, %d squares after 2.1 s" % [two, full, half, compass.get_marker_count()])
	# Not shown: teammates, you, shots out of range.
	Noises.announce_shot(player.global_position + Vector3(10, 0, 0), mates[0] if not mates.is_empty() else player)
	Noises.announce_shot(player.get_eye_position(), player)
	Noises.announce_shot(player.global_position + Vector3(Noises.GUNSHOT_RANGE + 5.0, 0, 0), shooter)
	var other_world_ignored := compass.get_marker_count() == 0
	# The shot also comes from a real gun (the host, the bots) and from a puppet's replayed shot (a client).
	var gun_owner := enemies[2] if enemies.size() > 2 else shooter
	gun_owner.global_position = player.global_position + Vector3(0, 0, -15)
	Weapon.silent = true
	gun_owner.weapon.call(&"_fire")
	var by_gun := compass.get_marker_count()
	compass.advance(10.0)
	gun_owner.weapon.play_remote_shot(false, Vector3.ZERO)
	var by_puppet := compass.get_marker_count()
	Weapon.silent = false
	_check("The compass shows no teammates, nothing of your own and nothing out of gunshot range (%d m); a real shot from an enemy's gun does show, and so does a puppet's replayed shot (online)" % int(Noises.GUNSHOT_RANGE),
			other_world_ignored and by_gun == 1 and by_puppet == 1,
			"squares after the three shots that don't count: %d, after the enemy's gun: %d, after a puppet's shot: %d" % [other_world_ignored as int, by_gun, by_puppet])
	main.queue_free()
	await get_tree().process_frame
	MenuState.reset()
	GameLaunch.clear()
	Teams.friendly_fire = false

# --- The multiplayer lobby (M9, D-108) ---


## The distances that make the lobby page's layout (pixels, in the window's own scale): where the left column and
## the teams start (from the page's left edge) and how wide the column is, the heights of a team header, a row and the Start button, the gaps
## between rows, under the header, between the two columns and under the columns (Switch team), the footer's edge
## and the space under it. Read after the layout has settled.
func _lobby_geometry(lobby: LobbyMenu) -> Dictionary:
	var side := lobby.get_node("Page/Column/Body/Side") as Control
	var column := lobby.get_team_column(0)
	var rows := lobby.get_team_list(0).get_children()
	var header := lobby.get_team_header(0)
	var items := lobby.get_node("Page/Column/Footer/Items") as Control
	var footer := lobby.get_footer()
	var edge := (footer.get_theme_stylebox("panel") as StyleBoxFlat).border_width_top
	var list_end := maxf(lobby.get_team_list(0).get_global_rect().end.y, lobby.get_team_list(1).get_global_rect().end.y)
	# From the page's own corner: a headless window is 64 px wide, much narrower than the page, which then grows to both sides.
	var origin := (lobby.get_node("Page") as Control).global_position
	return {
		"side_x": side.global_position.x - origin.x, "side_width": side.size.x, "column_x": column.global_position.x - origin.x,
		"column_gap": lobby.get_team_column(1).global_position.x - column.get_global_rect().end.x,
		"header_height": header.size.y, "row_height": (rows[0] as Control).size.y,
		"row_gap": (rows[1] as Control).global_position.y - (rows[0] as Control).get_global_rect().end.y,
		"first_row_gap": (rows[0] as Control).global_position.y - header.get_global_rect().end.y,
		"switch_gap": lobby.get_switch_team_button().global_position.y - list_end,
		"footer_edge": float(edge), "footer_item_gap": items.global_position.y - (footer.global_position.y + edge),
	}


## The multiplayer lobby: opened from the main menu on its own [Settings], hosting on a random port
## with a real friend (a second session in the same process, [NetHarness]) joining it, and a
## client's view of a host's lobby. Every session is closed again at the end.
func _test_lobby_menu() -> void:
	var tree := get_tree()
	MenuState.reset()
	GameLaunch.clear()
	GameLaunch.notice = ""
	var shared := Settings.get_instance()
	shared.reset_to_defaults()
	var stored := Settings.new()
	stored.online_name = "Jan"
	stored.online_address = "10.1.2.3"
	stored.online_port = 27123
	# These checks are about a plain Bomb match on one map (M9's defaults); M10's defaults are Team Deathmatch on the rotation.
	stored.match_mode = "rounds"
	stored.match_map = Settings.DEFAULT_MATCH_MAP
	stored.match_rotation = false
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await tree.process_frame
	await tree.process_frame
	var lobby := menu.get_lobby_menu()
	lobby.set_settings(stored)
	# A headless window is tiny, so the menu was scaled to it: lay the lobby out at 720 pixels.
	lobby.set_ui_scale(1.0)
	var closed_count := [0]
	lobby.closed.connect(func() -> void: closed_count[0] += 1)
	var harness := NetHarness.new()
	add_child(harness)

	# The Join item, the connect page, the fields.
	var host_item := menu.get_online_buttons()[0]
	var join_item := menu.get_online_buttons()[1]
	var hidden_before := not lobby.is_open() and not lobby.visible
	join_item.pressed.emit()
	var fields := [lobby.get_name_field().text, lobby.get_address_field().text, lobby.get_port_field().text]
	var connect_buttons := [lobby.get_host_button().text, lobby.get_join_button().text, lobby.get_back_button().text]
	_check("The main menu's Join item (the small one under the line) opens the lobby on its connect page with the address field focused: titled Join, over the menu with the mouse free, the name (at most 16 characters), host's address and port filled in from the settings (placeholders IP and Port), the buttons Host game, Join and Back, no status text and none of the lobby's teams and footer",
			join_item.text == "Join" and join_item.theme_type_variation == &"SmallItemButton" and hidden_before and lobby.is_open()
					and lobby.get_address_field().has_focus()
					and MenuState.is_top(lobby) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and lobby.get_page() == LobbyMenu.Page.CONNECT
					and lobby.get_title_label().text == "Join"
					and fields == ["Jan", "10.1.2.3", "27123"] and lobby.get_name_field().max_length == 16 and lobby.get_name_field().editable
					and lobby.get_address_field().placeholder_text == "IP" and lobby.get_port_field().placeholder_text == "Port"
					and connect_buttons == ["Host game", "Join", "Back"] and lobby.get_status_label().text == "" and not lobby.get_status_label().visible
					and lobby.get_connect_box().visible and lobby.get_back_button().visible and not lobby.get_leave_button().visible and not lobby.get_info_label().visible
					and not lobby.get_teams_box().visible and not lobby.get_footer().visible and not lobby.get_friends_box().visible and lobby.get_session() == null,
			"fields %s, buttons %s, page %d, top %s" % [fields, connect_buttons, lobby.get_page(), MenuState.is_top(lobby)])

	# Editing a field writes to the settings; the port takes digits only.
	lobby.get_name_field().text = "Anna"
	lobby.get_name_field().text_changed.emit("Anna")
	lobby.get_address_field().text = "192.168.0.7"
	lobby.get_address_field().text_changed.emit("192.168.0.7")
	lobby.get_port_field().text = "28x1y2z"
	lobby.get_port_field().text_changed.emit("28x1y2z")
	_check("Every edit goes to the settings at once: the name, the address, and the port field keeps only the digits (28x1y2z becomes 2812)",
			stored.online_name == "Anna" and stored.online_address == "192.168.0.7" and stored.online_port == 2812
					and lobby.get_port_field().text == "2812" and shared.online_name == "Player" and shared.online_port == 26000,
			"name '%s', address '%s', port %d, field '%s', shared name '%s'" % [stored.online_name, stored.online_address, stored.online_port,
					lobby.get_port_field().text, shared.online_name])

	# Looks: an ink page like the Play screen (header, columns, footer), themed, no overrides, the background blocks clicks.
	var background := lobby.get_node("Background") as Panel
	var page := lobby.get_node("Page") as MarginContainer
	var esc_cap := lobby.get_node("Page/Column/Header/Esc") as Label
	var lobby_overrides := _overrides_below(lobby)
	_check("The lobby is a themed full-screen page as the Play screen is (an InkPanel that blocks the clicks, a PageMargin, a header with the title, the Esc key cap and a text button) with no theme override of its own",
			background.theme_type_variation == &"InkPanel" and background.mouse_filter == Control.MOUSE_FILTER_STOP and page.theme_type_variation == &"PageMargin"
					and page.mouse_filter == Control.MOUSE_FILTER_IGNORE and lobby.layer == 2 and lobby.get_title_label().theme_type_variation == &"TitleLabel"
					and esc_cap.theme_type_variation == &"DimKeyCapLabel" and esc_cap.text == "Esc" and lobby.get_back_button().theme_type_variation == &"TextButton"
					and lobby.get_leave_button().theme_type_variation == &"TextButton" and lobby.get_leave_button().text == "Leave"
					and lobby.get_host_button().theme_type_variation == &"" and lobby.get_join_button().theme_type_variation == &"" and lobby_overrides.is_empty(),
			"background %s (filter %d), page %s, layer %d, overrides %s" % [background.theme_type_variation, background.mouse_filter, page.theme_type_variation, lobby.layer, lobby_overrides])

	# Esc closes the connect page and gives the menu back its focus.
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc closes the lobby while it is on the connect page: it registers with MenuState, closes, the main menu is on top again with the Join item (the one that opened it) focused and the mouse still free",
			not lobby.is_open() and closed_count[0] == 1 and MenuState.is_top(menu) and join_item.has_focus()
					and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"open %s, closed signals %d, menu on top %s, focus %s" % [lobby.is_open(), closed_count[0], MenuState.is_top(menu), join_item.has_focus()])

	# The Host item opens the lobby and hosts at once, on the stored port; closing the lobby focuses Host.
	var host_item_port := 28000 + randi() % 900
	stored.online_name = "Jan"
	stored.online_port = host_item_port
	host_item.pressed.emit()
	var host_item_session := lobby.get_session()
	var hosted_by_item := lobby.is_open() and host_item_session != null and host_item_session.is_host() and host_item_session.is_active() \
			and lobby.get_page() == LobbyMenu.Page.LOBBY and lobby.get_info_label().text.begins_with("Hosted by you · ") and lobby.get_info_label().text.ends_with(str(host_item_port))
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	await tree.process_frame
	_check("The Host item (the first small one) opens the lobby and starts hosting on the stored port without another click; two Esc (leave, close) end the session and give the focus back to Host",
			host_item.text == "Host" and host_item.theme_type_variation == &"SmallItemButton" and not host_item.disabled and hosted_by_item
					and not lobby.is_open() and lobby.get_session() == null and NetLobby.find_session(tree) == null and host_item.has_focus() and MenuState.is_top(menu),
			"hosted %s, open %s, session %s, focus on Host %s" % [hosted_by_item, lobby.is_open(), lobby.get_session(), host_item.has_focus()])

	# Hosting: the lobby page with you in a team, the bot rows from the published slots.
	join_item.pressed.emit()
	var port := 28000 + randi() % 900
	lobby.get_name_field().text = "Jan"
	lobby.get_address_field().text = "127.0.0.1"
	lobby.get_port_field().text = str(port)
	var result := lobby.host_game()
	var session := lobby.get_session()
	var lobby_node := NetLobby.of(session) if session != null else null
	var default_summary := "Rounds · Depot · first to 5 rounds · Normal bots"
	var team_0 := lobby.get_team_texts(0)
	var team_1 := lobby.get_team_texts(1)
	var addresses := LobbyMenu.local_addresses()
	var address_lines: Array[String] = []
	for address in addresses:
		address_lines.append("%s:%d" % [address, port])
	var tailscale := LobbyMenu.tailscale_addresses()
	var hosted_text := "Hosted by you · port %d" % port
	if not address_lines.is_empty():
		hosted_text = "Hosted by you · %s" % address_lines[0]
	elif not tailscale.is_empty():
		hosted_text = "Hosted by you · %s:%d" % [tailscale[0], port]
	var default_facts := {"Mode": "Bomb", "Map": "Depot", "Limit": "First to 5 rounds"}
	_check("Host game opens a session as the host on the port in the field and shows the lobby page: titled Lobby, \"Hosted by you · address:port\" in the header with Leave in place of Back, your name fixed, the addresses friends join at (with the port) under Friends join at, you as \"You\" with the Host mark and \"Empty / Bot\" rows for the other slots of both teams, the match's mode, map and limit in the footer, Edit setup and Start (no waiting line)",
			result == OK and session != null and session.is_host() and session.is_active() and NetLobby.find_session(tree) == session
					and lobby.get_page() == LobbyMenu.Page.LOBBY and lobby.get_title_label().text == "Lobby"
					and lobby.get_info_label().visible and lobby.get_info_label().text == hosted_text and stored.online_port == port
					and lobby.get_leave_button().visible and lobby.get_leave_button().text == "Leave" and not lobby.get_back_button().visible
					and not lobby.get_name_field().editable and lobby.get_name_field().text == "Jan"
					and lobby.get_address_texts() == address_lines and lobby.get_friends_box().visible == (not address_lines.is_empty() or not tailscale.is_empty())
					and not lobby.get_connect_box().visible and lobby.get_teams_box().visible and lobby.get_footer().visible
					and team_0 == ["You Host", "Empty Bot", "Empty Bot"] and team_1 == ["Empty Bot", "Empty Bot", "Empty Bot"]
					and lobby_node.info.get("slots", []) == [3, 3] and lobby_node.info.get("map", "") == Settings.DEFAULT_MATCH_MAP
					and lobby.build_summary() == default_summary and lobby_node.info.get("summary", "") == default_summary
					and lobby.get_footer_facts() == default_facts and lobby_node.info.get("facts", {}) == lobby.build_facts()
					and lobby.get_settings_button().visible and lobby.get_settings_button().text == "Edit setup" and lobby.get_settings_button().theme_type_variation == &"DimButton"
					and lobby.get_start_button().visible and lobby.get_start_button().text == "Start" and lobby.get_start_button().theme_type_variation == &"BigPrimaryButton"
					and lobby.get_start_button().icon != null and not lobby.get_waiting_label().visible,
			"result %d, team 1 %s, team 2 %s, info '%s', header '%s', addresses %s, facts %s" % [result, team_0, team_1, lobby_node.info if lobby_node != null else "none",
					lobby.get_info_label().text, lobby.get_address_texts(), lobby.get_footer_facts()])
	_check("Colors are relative to you: your team's header is \"Your team\" with the blue (friendly) line and the other \"Enemy team\" with the red one, each with its players out of its slots (1 / 3 and 0 / 3), your row is the raised one with a lime chip and the empty slots are framed; Switch team (one button, in place of a Join Team button per team) is on",
			lobby.get_team_header(0).theme_type_variation == &"TeamTitleFriendly" and lobby.get_team_header(1).theme_type_variation == &"TeamTitleEnemy"
					and lobby.get_team_header_texts(0) == ["Your team", "1 / 3"] and lobby.get_team_header_texts(1) == ["Enemy team", "0 / 3"]
					and lobby.get_team_list(0).get_child(0).theme_type_variation == &"RaisedPanel" and lobby.get_team_list(0).get_child(1).theme_type_variation == &"EmptySlotPanel"
					and not lobby.get_team_list(0).get_child(0).find_children("*", "Panel", true, false).filter(func(chip: Node) -> bool: return chip.theme_type_variation == &"AccentChip").is_empty()
					and lobby.get_team_list(1).get_child(0).find_children("*", "Panel", true, false).is_empty()
					and lobby.get_switch_team_button().text == "Switch team" and lobby.get_switch_team_button().theme_type_variation == &""
					and not lobby.get_switch_team_button().disabled,
			"headers %s / %s, texts %s / %s, switch disabled %s" % [lobby.get_team_header(0).theme_type_variation, lobby.get_team_header(1).theme_type_variation,
					lobby.get_team_header_texts(0), lobby.get_team_header_texts(1), lobby.get_switch_team_button().disabled])
	var hosted_overrides := _overrides_below(lobby)
	_check("The lobby page's rows, headers and footer take everything from the theme too: no override on any control of it", hosted_overrides.is_empty(), "overrides %s" % [hosted_overrides])

	# The layout as the mockup draws it, and exactly 1.5 times as big at 1080p.
	await tree.process_frame
	await tree.process_frame
	var at_one := _lobby_geometry(lobby)
	lobby.set_ui_scale(1.5)
	await tree.process_frame
	await tree.process_frame
	var at_one_and_a_half := _lobby_geometry(lobby)
	lobby.set_ui_scale(1.0)
	await tree.process_frame
	await tree.process_frame
	var back_to_one := _lobby_geometry(lobby)
	var scaled_ok := true
	for key: String in at_one:
		scaled_ok = scaled_ok and is_equal_approx(float(at_one_and_a_half[key]), float(at_one[key]) * 1.5)
	var start_height := lobby.get_start_button().size.y
	_check("The lobby's layout is the mockup's at 720p: the left column at x 32 and 336 wide, the teams from x 400 (32 on) with a 34 high header (32 + its 2 px line), rows 40 high 4 apart and 8 under the header, Switch team 32 under the longest column, the footer's items 24 under its 2 px edge",
			at_one["side_x"] == 32.0 and at_one["side_width"] == 336.0 and at_one["column_x"] == 400.0 and at_one["header_height"] == 34.0
					and at_one["row_height"] == 40.0 and at_one["row_gap"] == 4.0 and at_one["first_row_gap"] == 8.0 and at_one["switch_gap"] == 32.0
					and at_one["column_gap"] == 32.0 and at_one["footer_edge"] == 2.0 and at_one["footer_item_gap"] == 24.0 and start_height == 56.0,
			"%s, Start %.0f high" % [at_one, start_height])
	_check("At 1080p (scale 1.5) every one of those is exactly 1.5 times as big (column x 400 to 600, row height 40 to 60, the left column 336 to 504) and back at 720p they are the same again",
			scaled_ok and at_one_and_a_half["column_x"] == 600.0 and at_one_and_a_half["row_height"] == 60.0 and at_one_and_a_half["side_width"] == 504.0
					and back_to_one == at_one,
			"1.0: %s, 1.5: %s" % [at_one, at_one_and_a_half])

	# A real friend joins: they take a slot of the smaller team and get the host's info.
	harness.port = port
	var friend := harness.start_client("Friend", "Anna")
	var friend_lobby := NetLobby.of(friend)
	# Without this the friend's lobby would really change this test's scene when the match starts.
	friend_lobby.change_scene = func(_path: String) -> void: pass
	await harness.wait_until(func() -> bool: return session.get_players().size() == 2 and not friend_lobby.info.is_empty(), 640)
	_check("A friend joining takes a bot's slot in the smaller team (their name replaces one \"Empty / Bot\" row there, and its header counts them: 1 / 3 and 1 / 3) and receives the host's lobby info and the team limits",
			lobby.get_team_texts(0) == ["You Host", "Empty Bot", "Empty Bot"] and lobby.get_team_texts(1) == ["Anna", "Empty Bot", "Empty Bot"]
					and lobby.get_team_header_texts(1) == ["Enemy team", "1 / 3"] and lobby.get_team_list(1).get_child(0).theme_type_variation == &"RowPanel"
					and friend_lobby.info.get("summary", "") == default_summary and friend_lobby.info.get("facts", {}) == lobby_node.info.get("facts", {}) and session.team_limits == [3, 3],
			"team 1 %s, team 2 %s, friend's summary '%s'" % [lobby.get_team_texts(0), lobby.get_team_texts(1), friend_lobby.info.get("summary", "")])

	# The summary and the slots follow the match settings; the host's team gets "your team"'s size.
	stored.match_team_size = 2
	stored.match_enemy_team_size = 4
	var sized := [lobby.get_team_texts(0), lobby.get_team_texts(1), lobby_node.info.get("slots", []), session.team_limits.duplicate()]
	_check("Changing the team sizes republishes at once: the host's team has \"your team\"'s slots (2) and the other the enemy team's (4), the rows and the headers' counts (1 / 2, 1 / 4) follow, and the slots become the limits",
			sized[0] == ["You Host", "Empty Bot"] and sized[1] == ["Anna", "Empty Bot", "Empty Bot", "Empty Bot"] and sized[2] == [2, 4] and sized[3] == [2, 4]
					and lobby.get_team_header_texts(0) == ["Your team", "1 / 2"] and lobby.get_team_header_texts(1) == ["Enemy team", "1 / 4"],
			"team 1 %s, team 2 %s, slots %s, limits %s" % sized)
	stored.match_mode = "respawn"
	stored.match_kill_limit = 75
	stored.match_friendly_fire = true
	stored.match_difficulty = "hard"
	var respawn_summary := lobby.build_summary()
	var respawn_published := String(lobby_node.info.get("summary", ""))
	var respawn_facts := lobby.get_footer_facts()
	stored.match_mode = "rounds"
	stored.match_friendly_fire = false
	stored.match_difficulty = "easy"
	stored.match_rotation = true
	stored.match_map = "res://maps/square.tscn"
	var rotation_summary := lobby.build_summary()
	var rotation_facts := lobby.get_footer_facts()
	await harness.wait_until(func() -> bool: return friend_lobby.info.get("summary", "") == rotation_summary, 320)
	_check("The summary line is built from the choices: mode, map or rotation (starting at the chosen map), length, bot difficulty and friendly fire, and the friend sees the same line",
			respawn_summary == "Team respawn · Depot · first to 75 kills · Hard bots · friendly fire" and respawn_published == respawn_summary
					and rotation_summary == "Rounds · Rotation: Square, Spillway, Depot · first to 5 rounds · Easy bots"
					and friend_lobby.info.get("summary", "") == rotation_summary and lobby_node.info.get("map", "") == "res://maps/square.tscn",
			"respawn '%s', rotation '%s', friend sees '%s'" % [respawn_summary, rotation_summary, friend_lobby.info.get("summary", "")])
	_check("The footer follows the same choices, mode over its name, map (\"Rotation · \" and the map it starts at for the rotation) and limit (kills and minutes, or the rounds to win), and the friend gets the same facts",
			respawn_facts == {"Mode": "Team Deathmatch", "Map": "Depot", "Limit": "75 kills · 10 min"}
					and rotation_facts == {"Mode": "Bomb", "Map": "Rotation · Square", "Limit": "First to 5 rounds"}
					and friend_lobby.info.get("facts", {}) == {"mode": "Bomb", "map": "Rotation · Square", "limit": "First to 5 rounds"},
			"respawn %s, rotation %s, friend %s" % [respawn_facts, rotation_facts, friend_lobby.info.get("facts", {})])
	stored.match_rotation = false
	stored.match_map = Settings.DEFAULT_MATCH_MAP

	# Switch team moves you (the host) to the other team and swaps the slots and the colors; Join Team is still there for code.
	lobby.get_switch_team_button().pressed.emit()
	var moved := [lobby.get_team_texts(0), lobby.get_team_texts(1), lobby_node.info.get("slots", []), session.get_team(1)]
	_check("Switch team moves the host to the other team: the rows follow, the slots swap with the host (4 and 2), your team's header (\"Your team\", 2 / 2) is the blue one now and the other (\"Enemy team\", 0 / 4) the red one, and the button stays on",
			moved[3] == 1 and moved[0] == ["Empty Bot", "Empty Bot", "Empty Bot", "Empty Bot"] and moved[1] == ["You Host", "Anna"] and moved[2] == [4, 2]
					and lobby.get_team_header(1).theme_type_variation == &"TeamTitleFriendly" and lobby.get_team_header(0).theme_type_variation == &"TeamTitleEnemy"
					and lobby.get_team_header_texts(1) == ["Your team", "2 / 2"] and lobby.get_team_header_texts(0) == ["Enemy team", "0 / 4"]
					and not lobby.get_switch_team_button().disabled,
			"team 1 %s, team 2 %s, slots %s, host team %d" % [moved[0], moved[1], moved[2], moved[3]])
	lobby.join_team(0)
	var joined_back := session.get_team(1) == 0 and lobby.get_team_texts(0)[0] == "You Host"
	lobby.get_switch_team_button().pressed.emit()
	_check("join_team(team) still moves you to that team (Switch team is the same call with the other team), and Switch team from team 1 goes back to team 2",
			joined_back and session.get_team(1) == 1, "back in team 1 %s, host team %d" % [joined_back, session.get_team(1)])

	# A full team: the Switch team button is off.
	stored.match_team_size = 1
	stored.match_enemy_team_size = 1
	session.set_player_team(friend.local_peer_id, 0)
	var full := [lobby.get_team_texts(0), lobby.get_team_texts(1), lobby_node.info.get("slots", []), lobby.get_switch_team_button().disabled]
	_check("When the other team has all its slots taken (1 slot, Anna in it; you are on the other team) Switch team is off",
			full[0] == ["Anna"] and full[1] == ["You Host"] and full[2] == [1, 1] and full[3],
			"team 1 %s, team 2 %s, slots %s, button off %s" % full)
	stored.match_team_size = 2
	stored.match_enemy_team_size = 4

	# The match settings over the lobby: Done instead of Start, Esc closes only that panel.
	lobby.get_settings_button().pressed.emit()
	var setup := lobby.get_match_setup()
	var setup_open := setup.is_open() and MenuState.is_top(setup) and setup.get_start_button().text == "Done" and setup.is_online()
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var esc_closed_setup := not setup.is_open() and lobby.is_open() and MenuState.is_top(lobby) and lobby.get_page() == LobbyMenu.Page.LOBBY and session.is_active()
	lobby.get_settings_button().pressed.emit()
	setup.get_start_button().pressed.emit()
	var done_closed_setup := not setup.is_open() and lobby.is_open() and MenuState.is_top(lobby) and lobby.get_settings_button().has_focus()
	_check("Edit setup opens the same match setup panel over the lobby with its Start button reading Done; Esc closes just that panel, Done closes it as well, and the lobby stays open with the session running",
			setup_open and esc_closed_setup and done_closed_setup and setup.get_start_button().text == "Done",
			"open with Done %s, Esc %s, Done %s" % [setup_open, esc_closed_setup, done_closed_setup])

	# The match setup over the lobby is the online one: no Practice card, "Picked" in place of "Click to play", and a click on the
	# picked card only picks (it does not start anything); a click on the other card picks it and the lobby follows.
	lobby.get_settings_button().pressed.emit()
	var online_cards := setup.get_mode_cards()
	var started_clicks := [0]
	setup.started.connect(func() -> void: started_clicks[0] += 1, CONNECT_ONE_SHOT)
	var picked_line := setup.get_card_line("rounds")
	online_cards[1].pressed.emit()
	var still_picked: bool = setup.get_picked_mode() == "rounds" and started_clicks[0] == 0 and setup.is_open()
	online_cards[0].pressed.emit()
	var other_line := setup.get_card_line("respawn")
	var lobby_followed: bool = stored.match_mode == "respawn" and lobby.get_footer_facts()["Mode"] == "Team Deathmatch" \
			and lobby_node.info.get("facts", {}).get("mode", "") == "Team Deathmatch"
	online_cards[1].pressed.emit()
	var practice_click := setup.get_mode_cards()[2]
	practice_click.pressed.emit()
	setup.close()
	var offline := MATCH_SETUP_SCENE.instantiate() as MatchSetup
	offline.settings = Settings.new()
	add_child(offline)
	await tree.process_frame
	var offline_started := [0]
	offline.started.connect(func() -> void: offline_started[0] += 1)
	offline.get_mode_cards()[0].pressed.emit()
	var offline_ok: bool = (offline.get_mode_cards()[2].get_parent() as Control).visible and not offline.is_online() \
			and offline.get_card_line("respawn") == "Click to play" and offline_started[0] == 1
	remove_child(offline)
	offline.queue_free()
	_check("In the lobby the match setup is the online one (set_online): the Practice card is hidden, the picked card's last line reads \"Picked\" and a click on it starts nothing and keeps it picked, a click on the other card picks it (the lobby's footer and published facts follow) and Practice cannot be picked; the Play screen's own is unchanged (Practice shown, \"Click to play\", a click on the picked card plays)",
			setup.is_online() and not (setup.get_mode_cards()[2].get_parent() as Control).visible and picked_line == "Picked" and still_picked
					and other_line == "Picked" and lobby_followed and setup.get_picked_mode() == "rounds" and stored.match_mode == "rounds" and offline_ok,
			"picked line '%s', still picked %s, other line '%s', lobby followed %s, mode %s, offline %s" % [picked_line, still_picked, other_line, lobby_followed,
					stored.match_mode, offline_ok])

	# Start match: the host's choices become the game description on this computer (the scene change is faked).
	var scenes := []
	lobby_node.change_scene = func(path: String) -> void: scenes.append(path)
	stored.match_mode = "respawn"
	stored.match_kill_limit = 25
	lobby.get_start_button().pressed.emit()
	var started_rules := GameLaunch.match_settings
	var started := GameLaunch.is_pending() and GameLaunch.map_path == Settings.DEFAULT_MATCH_MAP and GameLaunch.net_session == session and scenes == [GameLaunch.GAME_SCENE] \
			and started_rules != null and started_rules.team_size == 2 and started_rules.enemy_team_size == 4 \
			and started_rules.game_mode == MatchSettings.GameMode.TEAM_RESPAWN and started_rules.kill_limit == 25 and lobby_node.in_game
	var friend_started := await harness.wait_until(func() -> bool: return friend_lobby.in_game, 320)
	_check("Start asks the lobby to start the match: this computer's game description has the stored map and rules and the session, the game scene is the next scene, and the friend's lobby starts too",
			started and friend_started,
			"pending %s, map %s, scenes %s, rules %s, friend started %s" % [GameLaunch.is_pending(), GameLaunch.map_path, scenes,
					started_rules.team_size if started_rules != null else "none", friend_started])
	lobby_node.in_game = false
	friend_lobby.in_game = false
	GameLaunch.clear()
	stored.match_mode = "rounds"

	# Leave: the connect page is back at once; the session ends for everyone a moment later.
	lobby.get_leave_button().pressed.emit()
	var left_at_once := lobby.get_page() == LobbyMenu.Page.CONNECT and lobby.is_open() and lobby.get_session() == null
	# The host gives its friend a moment to hear it, and hosting again meanwhile would be torn down by the closing.
	var waits := lobby.get_host_button().disabled and lobby.get_join_button().disabled and lobby.host_game() == ERR_BUSY and lobby.get_session() == null
	await harness.wait_until(func() -> bool: return not friend.is_active(), 640)
	await tree.process_frame
	await tree.process_frame
	_check("Leave returns to the connect page at once, with the fields kept; Host game and Join wait while the host's session finishes closing (its friend's connection ends with it) and are on again, with nothing of the session left at the root of the tree",
			left_at_once and waits and NetLobby.find_session(tree) == null and not friend.is_active() and lobby.get_port_field().text == str(port)
					and lobby.get_name_field().text == "Jan" and not lobby.get_host_button().disabled and not lobby.get_join_button().disabled,
			"at once %s, waits %s, session at root %s, friend active %s, port '%s', buttons off %s" % [left_at_once, waits, NetLobby.find_session(tree), friend.is_active(),
					lobby.get_port_field().text, lobby.get_host_button().disabled])
	friend.close()
	await tree.process_frame
	# The friend's lobby kept the host's leaving as the notice the main menu shows; this test isn't that.
	GameLaunch.notice = ""

	# Esc on the lobby page leaves the session; Esc on the connect page closes the menu.
	port = 28000 + randi() % 900
	lobby.get_port_field().text = str(port)
	lobby.host_game()
	var hosting_again := lobby.get_page() == LobbyMenu.Page.LOBBY and lobby.get_session() != null
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	var left_by_esc := lobby.get_page() == LobbyMenu.Page.CONNECT and lobby.is_open() and lobby.get_session() == null and NetLobby.find_session(tree) == null
	_send(_key_event(KEY_ESCAPE))
	_send(_key_event(KEY_ESCAPE, false))
	_check("Esc on the lobby page is Leave (back to the connect page, the session gone) and a second Esc closes the menu",
			hosting_again and left_by_esc and not lobby.is_open() and MenuState.is_top(menu),
			"hosting %s, left by Esc %s, open %s" % [hosting_again, left_by_esc, lobby.is_open()])

	# A port that is in use, an empty address, an unknown host.
	join_item.pressed.emit()
	harness.port = 28000 + randi() % 900
	var other_host := harness.start_host("OtherHost", "Other")
	lobby.get_port_field().text = str(harness.port)
	var busy := lobby.host_game()
	var busy_status := lobby.get_status_label().text
	var busy_ok := busy == ERR_CANT_CREATE and lobby.get_session() == null and NetLobby.find_session(tree) == null \
			and busy_status == "Port %d is in use." % harness.port and lobby.get_page() == LobbyMenu.Page.CONNECT \
			and lobby.get_status_label().theme_type_variation == &"AlertLabel"
	lobby.get_address_field().text = "   "
	var empty := lobby.join_game()
	var empty_ok := empty != OK and lobby.get_session() == null and lobby.get_status_label().text != "" and lobby.get_page() == LobbyMenu.Page.CONNECT
	_check("Hosting on a port that is in use fails with \"Port N is in use.\" on the connect page and leaves no session; joining without an address says so",
			busy_ok and empty_ok, "host error %d, status '%s', empty join error %d, status '%s'" % [busy, busy_status, empty, lobby.get_status_label().text])
	other_host.close()

	# Joining a port where nothing listens: Connecting..., the buttons off, Back cancels.
	var silent_port := 28000 + randi() % 900
	while silent_port == harness.port:
		silent_port = 28000 + randi() % 900
	lobby.get_address_field().text = "127.0.0.1"
	lobby.get_port_field().text = str(silent_port)
	var joined_result := lobby.join_game()
	var connecting_text := lobby.get_status_label().text
	var connecting_ok := joined_result == OK and connecting_text == "Connecting to 127.0.0.1:%d…" % silent_port and lobby.get_host_button().disabled \
			and lobby.get_join_button().disabled and not lobby.get_back_button().disabled and lobby.get_page() == LobbyMenu.Page.CONNECT \
			and lobby.get_session() != null and not lobby.get_session().is_active() and stored.online_address == "127.0.0.1" \
			and lobby.get_status_label().visible and lobby.get_status_label().theme_type_variation == &"DimLabel" and not lobby.get_name_field().editable
	var connecting_session := lobby.get_session()
	lobby.get_back_button().pressed.emit()
	await tree.process_frame
	_check("Joining a port nobody listens on shows \"Connecting to 127.0.0.1:N…\" with Host game and Join off; Back cancels the attempt, closes the lobby and frees the session",
			connecting_ok and not lobby.is_open() and lobby.get_session() == null and NetLobby.find_session(tree) == null
					and (not is_instance_valid(connecting_session) or connecting_session.is_queued_for_deletion()),
			"result %d, status '%s', open %s, session %s" % [joined_result, connecting_text, lobby.is_open(), lobby.get_session()])

	# A client's view: joins a host the lobby doesn't run (a plain session on a side).
	join_item.pressed.emit()
	harness.port = 28000 + randi() % 900
	var remote := harness.start_host("RemoteHost", "Host")
	var remote_lobby := NetLobby.of(remote)
	var remote_facts := {"mode": "Bomb", "map": "Depot", "limit": "First to 5 rounds"}
	remote_lobby.publish("Rounds · Depot · first to 5 rounds · Normal bots", [1, 2], "res://maps/depot.tscn", remote_facts)
	lobby.get_address_field().text = "127.0.0.1"
	lobby.get_port_field().text = str(harness.port)
	lobby.get_name_field().text = "Jan"
	lobby.join_game()
	var joining_editable := lobby.get_name_field().editable
	var in_lobby := await harness.wait_until(func() -> bool: return lobby.get_page() == LobbyMenu.Page.LOBBY, 640)
	remote_lobby.publish("Rounds · Depot · first to 5 rounds · Normal bots", [1, 2], "res://maps/depot.tscn", remote_facts)
	await harness.wait_until(func() -> bool: return not lobby.get_footer_facts()["Mode"].is_empty(), 320)
	var client_session := lobby.get_session()
	_check("Joining a host shows the lobby page as a client: \"Connected to address:port\" in the header, you as \"You\" and the host with its name and the Host mark, \"Empty / Bot\" rows for the free slots of the host's info with the headers' counts (1 / 1, 1 / 2), the host's mode, map and limit in the footer, the line \"Waiting for the host to start\" and neither Edit setup nor Start, no addresses to give out, and Switch team off while the other team is full",
			in_lobby and not joining_editable and client_session != null and not client_session.is_host() and lobby.get_info_label().text == "Connected to 127.0.0.1:%d" % harness.port
					and lobby.get_team_texts(0) == ["Host Host"] and lobby.get_team_texts(1) == ["You", "Empty Bot"]
					and lobby.get_team_header_texts(0) == ["Enemy team", "1 / 1"] and lobby.get_team_header_texts(1) == ["Your team", "1 / 2"]
					and lobby.get_footer_facts() == {"Mode": "Bomb", "Map": "Depot", "Limit": "First to 5 rounds"}
					and lobby.get_waiting_label().visible and lobby.get_waiting_label().text == "Waiting for the host to start"
					and lobby.get_waiting_label().theme_type_variation == &"MuteLabel"
					and not lobby.get_settings_button().visible and not lobby.get_start_button().visible
					and not lobby.get_friends_box().visible and lobby.get_leave_button().visible and not lobby.get_name_field().editable
					and lobby.get_switch_team_button().disabled
					and lobby.get_team_header(1).theme_type_variation == &"TeamTitleFriendly" and lobby.get_team_header(0).theme_type_variation == &"TeamTitleEnemy",
			"in lobby %s, info '%s', team 1 %s, team 2 %s, facts %s" % [in_lobby, lobby.get_info_label().text, lobby.get_team_texts(0), lobby.get_team_texts(1),
					lobby.get_footer_facts()])

	# The host goes away: back to the connect page with the reason, shown once.
	GameLaunch.notice = ""
	remote.close()
	var dropped := await harness.wait_until(func() -> bool: return lobby.get_page() == LobbyMenu.Page.CONNECT, 1500)
	_check("When the host leaves, the client's lobby goes back to the connect page and says why in the alert colour (the reason is also taken off the notice the main menu would show again), with no session left and the name editable again",
			dropped and lobby.get_status_label().text != "" and lobby.get_status_label().visible and lobby.get_status_label().theme_type_variation == &"AlertLabel"
					and lobby.get_name_field().editable and GameLaunch.notice == "" and lobby.get_session() == null and NetLobby.find_session(tree) == null,
			"dropped %s, status '%s', notice '%s'" % [dropped, lobby.get_status_label().text, GameLaunch.notice])
	lobby.close()

	# Back in the main menu after an online game: a running session reopens the lobby, a reason shows up on the connect page.
	remove_child(menu)
	menu.queue_free()
	await tree.process_frame
	MenuState.reset()
	var kept_session := NetSession.open(tree)
	NetLobby.of(kept_session)
	kept_session.host_game("Jan", port)
	var back := MAIN_MENU_SCENE.instantiate() as MainMenu
	back.load_settings = false
	add_child(back)
	await tree.process_frame
	await tree.process_frame
	var back_lobby := back.get_lobby_menu()
	var reopened := back_lobby.is_open() and back_lobby.get_page() == LobbyMenu.Page.LOBBY and back_lobby.get_session() == kept_session \
			and back_lobby.get_team_texts(0).has("You Host") and MenuState.is_top(back_lobby)
	kept_session.close()
	await tree.process_frame
	remove_child(back)
	back.queue_free()
	await tree.process_frame
	MenuState.reset()
	GameLaunch.notice = "The host ended the game."
	var noticed := MAIN_MENU_SCENE.instantiate() as MainMenu
	noticed.load_settings = false
	add_child(noticed)
	await tree.process_frame
	await tree.process_frame
	var noticed_lobby := noticed.get_lobby_menu()
	var shows_notice := noticed_lobby.is_open() and noticed_lobby.get_page() == LobbyMenu.Page.CONNECT \
			and noticed_lobby.get_status_label().text == "The host ended the game." and GameLaunch.notice == ""
	_check("Coming back to the main menu with an online session still running opens the lobby on the lobby page, and with a reason an online game ended (GameLaunch.notice) it opens the connect page showing it once",
			reopened and shows_notice,
			"reopened %s, notice shown %s (status '%s', notice '%s')" % [reopened, shows_notice, noticed_lobby.get_status_label().text, GameLaunch.notice])

	# Clean up: every session closed, nothing paused, no menu left registered.
	remove_child(noticed)
	noticed.queue_free()
	remove_child(harness)
	harness.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check("The lobby leaves nothing behind: no session at the root of the tree, no open menu, the tree not paused, the shared settings still the defaults",
			NetLobby.find_session(tree) == null and not MenuState.is_any_open() and not tree.paused and shared.online_name == "Player" and shared.online_port == 26000 and GameLaunch.notice == "",
			"session %s, menus open %s, paused %s, shared name '%s'" % [NetLobby.find_session(tree), MenuState.is_any_open(), tree.paused, shared.online_name])
	MenuState.reset()
	GameLaunch.clear()
	GameLaunch.notice = ""
	shared.reset_to_defaults()

## The class draft's roles (M10, the mockup's "08 Class draft"): the card's frame, the key chip, the footer's edge, the
## perk's lines, the gaps and the sizes the menu reads all carry their tokens.
func _test_class_draft_roles() -> void:
	var rest := _theme.get_stylebox("normal", "ClassCardButton") as StyleBoxFlat
	var lit := _theme.get_stylebox("hover", "ClassCardButton") as StyleBoxFlat
	var focus := _theme.get_stylebox("focus", "ClassCardButton") as StyleBoxFlat
	var footer := _theme.get_stylebox("panel", "ClassFooterPanel") as StyleBoxFlat
	_check("A class card is a PANEL block with a 2 px frame of its own colour at rest and in the accent when hovered or focused; its footer has a 2 px LINE edge along the top with 16 px under it",
			rest.bg_color == Tokens.PANEL and rest.border_color == Tokens.PANEL and rest.border_width_left == Tokens.BORDER
					and _theme.get_stylebox("pressed", "ClassCardButton") == rest
					and lit.border_color == Tokens.ACCENT and lit.bg_color == Tokens.PANEL and focus.border_color == Tokens.ACCENT and not focus.draw_center
					and footer.border_color == Tokens.LINE_COLOR and footer.border_width_top == Tokens.LINE and footer.border_width_bottom == 0
					and footer.content_margin_top == Tokens.LINE + Tokens.CLASS_FOOTER_PAD_TOP,
			"rest %s / %s, lit frame %s, footer edge %d, space %.0f" % [rest.bg_color, rest.border_color, lit.border_color, footer.border_width_top, footer.content_margin_top])
	_check("The key chip is empty, or filled with the accent with ink on it (LargeInkLabel: 32 px, the on-fill colour); the perk text is DIM with a 3 px line spacing (24 px lines)",
			_theme.get_stylebox("panel", "KeyChip") is StyleBoxEmpty
					and (_theme.get_stylebox("panel", "KeyChipLit") as StyleBoxFlat).bg_color == Tokens.ACCENT
					and _theme.get_color("font_color", "LargeInkLabel") == Tokens.TEXT_ON_FILL
					and _theme.get_font_size("font_size", "LargeInkLabel") == Tokens.TEXT_SIZE_LARGE
					and _theme.get_color("font_color", "PerkLabel") == Tokens.TEXT_DIM
					and _theme.get_constant("line_spacing", "PerkLabel") == Tokens.CLASS_PERK_LINE_SPACING and Tokens.CLASS_PERK_LINE_SPACING == 3,
			"")
	_check("The gaps are the tokens: 12 under the title, 32 between cards (16 compact), 16 between the body's blocks, 8 inside a block; the body's padding is 24 and the frame's 2",
			_theme.get_constant("separation", "ClassHeaderBox") == Tokens.CLASS_HEADER_GAP and Tokens.CLASS_HEADER_GAP == 12
					and _theme.get_constant("separation", "ClassRow") == Tokens.CLASS_CARD_GAP and Tokens.CLASS_CARD_GAP == 32
					and _theme.get_constant("separation", "ClassRowCompact") == Tokens.CLASS_CARD_GAP_COMPACT and Tokens.CLASS_CARD_GAP_COMPACT == 16
					and _theme.get_constant("separation", "ClassBodyBox") == Tokens.CLASS_BODY_GAP and Tokens.CLASS_BODY_GAP == 16
					and _theme.get_constant("separation", "ClassTextBox") == Tokens.CLASS_TEXT_GAP and Tokens.CLASS_TEXT_GAP == 8
					and _theme.get_constant("margin_left", "ClassBodyMargin") == Tokens.CLASS_BODY_PAD and Tokens.CLASS_BODY_PAD == 24
					and _theme.get_constant("margin_top", "FrameMargin") == Tokens.BORDER,
			"")
	_check("The sizes the menu reads are the tokens: a card 400 x 480 (288 wide when compact) and a row at most 1216 wide, so that four compact cards (4 x 288 + 3 x 16 = 1200) fit the 1280 canvas",
			_theme.get_constant("card_width", "ClassDraft") == Tokens.CLASS_CARD_WIDTH and Tokens.CLASS_CARD_WIDTH == 400
					and _theme.get_constant("card_height", "ClassDraft") == Tokens.CLASS_CARD_HEIGHT and Tokens.CLASS_CARD_HEIGHT == 480
					and _theme.get_constant("card_width_compact", "ClassDraft") == Tokens.CLASS_CARD_WIDTH_COMPACT and Tokens.CLASS_CARD_WIDTH_COMPACT == 288
					and _theme.get_constant("row_max_width", "ClassDraft") == Tokens.CLASS_ROW_MAX_WIDTH
					and 4 * Tokens.CLASS_CARD_WIDTH_COMPACT + 3 * Tokens.CLASS_CARD_GAP_COMPACT <= Tokens.CLASS_ROW_MAX_WIDTH
					and 3 * Tokens.CLASS_CARD_WIDTH + 2 * Tokens.CLASS_CARD_GAP > Tokens.CLASS_ROW_MAX_WIDTH
					and 2 * Tokens.CLASS_CARD_WIDTH + Tokens.CLASS_CARD_GAP <= Tokens.CLASS_ROW_MAX_WIDTH,
			"")


## A match on the test map with the class draft on or off and a long freeze time, so that the class menu that opens by
## itself stays open. Returns the game; its class menu is scaled by 1.0 (a headless window is tiny).
func _class_draft_game(draft: bool) -> Node:
	if _map != null and is_instance_valid(_map):
		remove_child(_map)
		_map.queue_free()
		_map = null
	var rules := MatchSettings.new()
	rules.freeze_time = 60.0
	rules.class_draft = draft
	GameLaunch.start_match(TEST_MAP, rules)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.loading_screen = false
	add_child(main)
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
	_rounds = main.get_map().get_node("RoundManager") as RoundManager
	_player = main.get_map().get_node("Player") as Character
	for character in _rounds.get_participants():
		_silence(character)
	return main


## The class draft as in the mockup's "08 Class draft", at 720p and at 1.5 times (1080p): two cards (a draft) are 400 x 480
## and 32 apart, four (no draft) the compact 288 wide and 16 apart; the parts stand where the mockup has them; the focused card is
## lit (lime key chip), hovering moves it, the number keys pick; the title block and the hint say what the game says.
func _test_class_draft_look() -> void:
	GameLaunch.clear()
	MenuState.reset()
	for case: Array in [[true, 2, Tokens.CLASS_CARD_WIDTH, Tokens.CLASS_CARD_GAP], [false, 4, Tokens.CLASS_CARD_WIDTH_COMPACT, Tokens.CLASS_CARD_GAP_COMPACT]]:
		var draft: bool = case[0]
		var count: int = case[1]
		var card_width: int = case[2]
		var gap: int = case[3]
		var main := await _class_draft_game(draft)
		var menu := main.get_node("ClassMenu") as ClassMenu
		var view := get_viewport().get_visible_rect().size
		var classes := menu.get_classes()
		_check("%s: the class menu opened by itself in freeze time with %d cards, your class (the first of a draft) is the lit one, and the title block says \"%d of 4 offered · starts in N\""
				% ["A draft" if draft else "Without the draft", count, count],
				menu.is_open() and classes.size() == count and menu.get_lit_index() == classes.find(_player.class_data) and menu.get_title_label().text == "Pick a class"
						and menu.get_subtitle_label().text.begins_with("%d of 4 offered · starts in " % count),
				"open %s, cards %d, lit %d, subtitle '%s'" % [menu.is_open(), classes.size(), menu.get_lit_index(), menu.get_subtitle_label().text])
		var rows := {}
		for factor: float in [1.0, 1.5]:
			menu.set_ui_scale(factor)
			for i in 4:
				await get_tree().process_frame
			var row := menu.get_card_row()
			var parts: Dictionary = {}
			var cards := menu.get_cards()
			var first := cards[0].get_global_rect()
			var width := roundf(card_width * factor)
			var lit_ok := true
			var detail_ok := true
			var text_ok := true
			var icon_ok := true
			for i in count:
				var data := classes[i]
				var rect := cards[i].get_global_rect()
				var picture := cards[i].find_child("Picture", true, false) as Control
				var pic := picture.get_global_rect()
				var chip := menu.get_part(i, "Chip").get_global_rect()
				var height_rect := menu.get_part(i, "Height").get_global_rect()
				var icon := menu.get_part(i, "Icon") as TextureRect
				var gun_icon := menu.get_part(i, "GunIcon") as TextureRect
				var inner := roundf(Tokens.BORDER * factor)
				# The mockup's numbers, times the scale: the picture area, the chip's corner, the height's corner, the icons.
				detail_ok = detail_ok and rect.size.x == width and rect.size.y >= roundf(Tokens.CLASS_CARD_HEIGHT * factor) \
						and pic.position == rect.position + Vector2.ONE * inner and pic.size.y == roundf(Tokens.CLASS_PICTURE_HEIGHT * factor) \
						and pic.size.x == width - 2.0 * inner \
						and chip == Rect2(pic.position + Vector2.ONE * roundf(Tokens.CLASS_CHIP_INSET * factor), Vector2.ONE * roundf(Tokens.CLASS_CHIP_SIZE * factor)) \
						and height_rect.end.x == pic.end.x - roundf(Tokens.CLASS_HEIGHT_INSET * factor) and height_rect.position.y == pic.position.y + roundf(Tokens.CLASS_HEIGHT_TOP * factor) \
						and icon.get_global_rect().size == Vector2.ONE * roundf(Tokens.CLASS_ICON_SIZE * factor) and icon.get_global_rect().end.y == pic.end.y \
						and absf(icon.get_global_rect().get_center().x - pic.get_center().x) <= 1.0 \
						and gun_icon.get_global_rect().size == Vector2(Tokens.CLASS_GUN_ICON) * factor \
						and gun_icon.get_global_rect().end.x == rect.end.x - roundf((Tokens.BORDER + Tokens.CLASS_BODY_PAD) * factor)
				text_ok = text_ok and (menu.get_part(i, "Key") as Label).text == str(i + 1) and (menu.get_part(i, "Name") as Label).text == data.display_name \
						and (menu.get_part(i, "Role") as Label).text == data.role and (menu.get_part(i, "PerkName") as Label).text == data.perk_name \
						and (menu.get_part(i, "Perk") as Label).text == data.perk_description and (menu.get_part(i, "Gun") as Label).text == data.signature_weapon \
						and (menu.get_part(i, "Height") as Label).text == "%.2f m" % data.height
				# The class icon is the class's slot in the friendly colour, the gun's is the first weapon's slot in the text colour.
				icon_ok = icon_ok and icon.texture == UiIcons.get_icon(icon, data.id) and icon.texture != null and icon.modulate == Tokens.FRIENDLY \
						and gun_icon.texture == UiIcons.get_icon(gun_icon, data.loadout[0].id) and gun_icon.texture != null and gun_icon.modulate == Tokens.TEXT
				var is_lit := i == menu.get_lit_index()
				lit_ok = lit_ok and menu.get_part(i, "Chip").theme_type_variation == (&"KeyChipLit" if is_lit else &"KeyChip") \
						and menu.get_part(i, "Key").theme_type_variation == (&"LargeInkLabel" if is_lit else &"LargeLabel") \
						and (menu.get_part(i, "Key") as Label).get_theme_color("font_color") == (Tokens.TEXT_ON_FILL if is_lit else Tokens.TEXT)
			parts["row top"] = row.get_global_rect().position.y == roundf(Tokens.CLASS_ROW_TOP * factor)
			parts["cards"] = cards.size() >= count and cards[count - 1].visible and (count == 4 or not cards[2].visible)
			parts["gap"] = count < 2 or cards[1].get_global_rect().position.x - first.end.x == roundf(gap * factor)
			parts["centred"] = absf(first.position.x + (cards[count - 1].get_global_rect().end.x - first.position.x) / 2.0 - view.x / 2.0) <= 1.0
			parts["fits"] = cards[count - 1].get_global_rect().end.x - first.position.x <= roundf(Tokens.CLASS_ROW_MAX_WIDTH * factor)
			parts["variation"] = row.theme_type_variation == (&"ClassRow" if draft else &"ClassRowCompact")
			parts["title"] = menu.get_title_label().get_theme_font_size("font_size") == roundi(Tokens.TEXT_SIZE_TITLE * factor)
			var hint_rect := menu.get_hint_label().get_global_rect()
			var trim := menu.get_title_label().get_parent() as Control
			parts["hint"] = hint_rect.end.y == view.y - roundf(Tokens.CLASS_HINT_BOTTOM * factor) \
					and cards[0].get_global_rect().end.y <= roundf(DESIGN_HEIGHT * factor) - hint_rect.size.y - roundf(Tokens.CLASS_HINT_BOTTOM * factor)
			parts["header"] = trim.get_parent().get_global_rect().position.y == roundf(Tokens.CLASS_TITLE_TOP * factor) \
					and absf(trim.get_global_rect().size.y - Tokens.TEXT_SIZE_TITLE * factor) <= 1.0 \
					and absf(menu.get_subtitle_label().get_global_rect().position.y - trim.get_global_rect().end.y - Tokens.CLASS_HEADER_GAP * factor) <= 1.0
			parts["details"] = detail_ok
			parts["texts"] = text_ok
			parts["icons"] = icon_ok
			parts["lit"] = lit_ok
			rows[factor] = parts
			print("  [%s cards at %s] card %s, first at %s, row %s, hint %s, header %s" % [count, factor, cards[0].get_global_rect().size,
					first.position, row.get_global_rect(), menu.get_hint_label().get_global_rect(), menu.get_title_label().get_global_rect()])
		for factor: float in rows:
			var failed: Array = []
			for part: String in rows[factor]:
				if not rows[factor][part]:
					failed.append(part)
			_check("%d cards at %s times the size: %d wide (at least %d high), %d apart, centred in the window, the picture, key chip, height, icons, texts and lit chip where the mockup has them, the hint %d from the bottom"
					% [count, factor, roundi(card_width * factor), roundi(Tokens.CLASS_CARD_HEIGHT * factor), roundi(gap * factor), roundi(Tokens.CLASS_HINT_BOTTOM * factor)],
					failed.is_empty(), "failed parts %s" % [failed])
		menu.set_ui_scale(1.0)
		await get_tree().process_frame
		await get_tree().process_frame
		if draft:
			await _check_class_draft_input(menu)
		else:
			_check("Without the draft the hint lists all four keys and the gun icons are by weapon id: the Rifleman's rifle, the Bulwark's shotgun, the Marksman's sniper, the Scout's smg",
					menu.get_hint_label().text == "Click or press 1 / 2 / 3 / 4 · Esc keeps your class"
							and menu.get_gun_id(ClassData.find(&"rifleman")) == &"rifle" and menu.get_gun_id(ClassData.find(&"bulwark")) == &"shotgun"
							and menu.get_gun_id(ClassData.find(&"marksman")) == &"sniper" and menu.get_gun_id(ClassData.find(&"scout")) == &"smg",
					menu.get_hint_label().text)
		remove_child(main)
		main.queue_free()
		await get_tree().process_frame
		MenuState.reset()
		GameLaunch.clear()


## The buy menu's roles (mockup 14): the four looks of an item cover every state of the button (a 2 px frame, no corner), the
## column header's edge is LINE or, for the selected column, the accent, and the sizes the menu reads are the tokens.
func _test_buy_menu_roles() -> void:
	var looks := {}
	for role in ["BuyItemOk", "BuyItemFocused", "BuyItemOwned", "BuyItemPoor"]:
		looks[role] = _theme.get_stylebox("normal", role) as StyleBoxFlat
	var hover := _theme.get_stylebox("hover", "BuyItemOk") as StyleBoxFlat
	var every_state := true
	for role: String in looks:
		for state in ["normal", "pressed", "disabled", "hover", "hover_pressed", "focus"]:
			var box := _theme.get_stylebox(state, role) as StyleBoxFlat
			every_state = every_state and box != null and box.border_width_left == Tokens.BORDER and box.border_width_bottom == Tokens.BORDER \
					and box.corner_radius_top_left == 0 and not box.anti_aliasing
	_check("The four looks of a buy item are frames of %d px in every button state: ok a PANEL fill and frame (the accent frame on hover), focused RAISED with the accent frame, owned no fill and a LINE frame, poor INK all over" % Tokens.BORDER,
			every_state and (looks["BuyItemOk"] as StyleBoxFlat).bg_color == Tokens.PANEL and (looks["BuyItemOk"] as StyleBoxFlat).border_color == Tokens.PANEL
					and hover.border_color == Tokens.ACCENT and hover.bg_color == Tokens.PANEL
					and (looks["BuyItemFocused"] as StyleBoxFlat).bg_color == Tokens.PANEL_RAISED and (looks["BuyItemFocused"] as StyleBoxFlat).border_color == Tokens.ACCENT
					and (looks["BuyItemOwned"] as StyleBoxFlat).bg_color.a == 0.0 and (looks["BuyItemOwned"] as StyleBoxFlat).border_color == Tokens.LINE_COLOR
					and (looks["BuyItemPoor"] as StyleBoxFlat).bg_color == Tokens.INK and (looks["BuyItemPoor"] as StyleBoxFlat).border_color == Tokens.INK,
			"ok %s, focused %s, owned %s, poor %s" % [(looks["BuyItemOk"] as StyleBoxFlat).bg_color, (looks["BuyItemFocused"] as StyleBoxFlat).bg_color,
					(looks["BuyItemOwned"] as StyleBoxFlat).border_color, (looks["BuyItemPoor"] as StyleBoxFlat).bg_color])
	var edge := _theme.get_stylebox("panel", "ColumnHeaderPanel") as StyleBoxFlat
	var lit := _theme.get_stylebox("panel", "ColumnHeaderLitPanel") as StyleBoxFlat
	_check("A column header has a 2 px bottom edge in LINE (the accent when its column is selected) and nothing else; the column leaves %d px between the header and its items" % Tokens.BUY_HEADER_GAP,
			edge.border_width_bottom == Tokens.LINE and edge.border_width_top == 0 and edge.border_color == Tokens.LINE_COLOR and edge.bg_color.a == 0.0
					and lit.border_width_bottom == Tokens.LINE and lit.border_color == Tokens.ACCENT
					and _theme.get_constant("separation", "BuyColumn") == Tokens.BUY_HEADER_GAP and Tokens.BUY_HEADER_GAP == 16 and Tokens.LINE == 2,
			"edge %s, lit %s" % [edge.border_color, lit.border_color])
	_check("The sizes the menu reads are the tokens: a column header 32 high, an item 64 high, its icon box 64 x 32 (the 32 x 16 icons at scale 2)",
			_theme.get_constant("header_height", "BuyMenu") == Tokens.BUY_HEADER_HEIGHT and Tokens.BUY_HEADER_HEIGHT == 32
					and _theme.get_constant("item_height", "BuyMenu") == Tokens.BUY_ITEM_HEIGHT and Tokens.BUY_ITEM_HEIGHT == 64
					and _theme.get_constant("icon_box_width", "BuyMenu") == Tokens.BUY_ICON_BOX.x and _theme.get_constant("icon_box_height", "BuyMenu") == Tokens.BUY_ICON_BOX.y
					and Tokens.BUY_ICON_BOX == Vector2i(64, 32),
			"")


## The buy menu as in the mockup's "14 Buy menu", at 720p and at 1.5 times (1080p): the header, the four columns (their keys,
## names and items), the four looks of an item with their icons (by id) and texts, the footer with what you hold, and the
## HUD that steps aside while the buy menu or the class menu is open (and only then).
func _test_buy_menu_look() -> void:
	GameLaunch.clear()
	MenuState.reset()
	var main := await _class_draft_game(true)
	var menu := main.get_node("BuyMenu") as BuyMenu
	var class_menu := main.get_node("ClassMenu") as ClassMenu
	var hud := main.get_node("HUD") as CanvasLayer
	var crosshair := hud.get_node("Crosshair") as Control
	var pause_menu: PauseMenu = main.get_pause_menu()
	var view := get_viewport().get_visible_rect().size

	# The HUD steps aside for the class menu and the buy menu, and for nothing else.
	var hidden_for_class := class_menu.is_open() and not hud.visible and not crosshair.is_visible_in_tree()
	menu.open()
	await get_tree().process_frame
	var hidden_for_buy := menu.is_open() and not class_menu.is_open() and not hud.visible and not crosshair.is_visible_in_tree()
	menu.close()
	var back_after_buy := not menu.is_open() and hud.visible and crosshair.is_visible_in_tree()
	pause_menu.open()
	await get_tree().process_frame
	var stays_for_pause := pause_menu.is_open() and hud.visible
	pause_menu.close()
	get_tree().paused = false
	_check("While the class menu or the buy menu is open the HUD and its crosshair are hidden (the mockups 08 and 14 show only the dimmed world) and they are back when it closes; the pause menu leaves them",
			hidden_for_class and hidden_for_buy and back_after_buy and stays_for_pause,
			"class %s, buy %s, back %s, pause %s" % [hidden_for_class, hidden_for_buy, back_after_buy, stays_for_pause])
	_close_class_menu(main)

	# The state to look at: $2400 less a vest and two flashbangs; the sniper rifle is too dear, the Verdict has the focus.
	_rounds.add_money(_player, 3000, "test")
	_rounds.request_buy(_player, Shop.VEST)
	_rounds.request_buy(_player, &"flashbang")
	_rounds.request_buy(_player, &"flashbang")
	_rounds.add_money(_player, 2400 - _rounds.get_money(_player), "test")
	menu.open()
	await get_tree().process_frame
	menu.get_item_button(&"hand_cannon").mouse_entered.emit()
	await get_tree().process_frame
	var columns := [[&"pistol", &"hand_cannon"], [&"smg", &"shotgun", &"rifle", &"carbine", &"sniper"], [&"vest", &"vest_helmet", &"kit"], [&"frag", &"flashbang", &"smoke"]]
	var names := ["Pistols", "Primaries", "Gear", "Grenades"]
	var side := "Defending" if _rounds.get_side(_player.team) == Teams.Side.DEFENDING else "Attacking"
	var texts_ok := menu.get_title_label().text == "Buy" and menu.get_money_label().text == "$2400" \
			and menu.get_situation_label().text.begins_with("%s · closes in " % side) \
			and menu.get_hint_label().text == "Click, or 1-4 then 1-5 · B closes" and menu.get_hint_label().theme_type_variation == &"MuteLabel" \
			and menu.get_hint_label().get_theme_color("font_color") == Tokens.MUTE
	var columns_ok := menu.get_columns_row().get_child_count() == 4
	var items_ok := true
	var looks_ok := true
	var states_seen := {}
	var expected_roles := {BuyMenu.ItemState.OK: &"BuyItemOk", BuyMenu.ItemState.FOCUSED: &"BuyItemFocused", BuyMenu.ItemState.OWNED: &"BuyItemOwned", BuyMenu.ItemState.POOR: &"BuyItemPoor"}
	var expected_text := {BuyMenu.ItemState.OK: &"BrightLabel", BuyMenu.ItemState.FOCUSED: &"BrightLabel", BuyMenu.ItemState.OWNED: &"DimLabel", BuyMenu.ItemState.POOR: &"MuteLabel"}
	var expected_price := {BuyMenu.ItemState.OK: &"BrightLabel", BuyMenu.ItemState.FOCUSED: &"HeaderLabel", BuyMenu.ItemState.OWNED: &"DimLabel", BuyMenu.ItemState.POOR: &"MuteLabel"}
	var expected_tint := {BuyMenu.ItemState.OK: Tokens.TEXT, BuyMenu.ItemState.FOCUSED: Tokens.TEXT, BuyMenu.ItemState.OWNED: Tokens.TEXT_DIM, BuyMenu.ItemState.POOR: Tokens.MUTE}
	var expected_color := {BuyMenu.ItemState.OK: Tokens.TEXT, BuyMenu.ItemState.FOCUSED: Tokens.TEXT, BuyMenu.ItemState.OWNED: Tokens.TEXT_DIM, BuyMenu.ItemState.POOR: Tokens.MUTE}
	for column in 4:
		columns_ok = columns_ok and (menu.get_column_part(column, "Key") as Label).text == str(column + 1) and (menu.get_column_part(column, "Name") as Label).text == names[column] \
				and menu.get_column_part(column, "Header").theme_type_variation == &"ColumnHeaderPanel" and menu.get_column_part(column, "Key").theme_type_variation == &"MuteLabel" \
				and menu.get_column_part(column, "Name").theme_type_variation == &"BrightLabel"
		for id: StringName in columns[column]:
			var button := menu.get_item_button(id)
			var state := menu.get_item_state(id)
			states_seen[state] = true
			var icon := menu.get_item_part(id, "Icon") as TextureRect
			var price := menu.get_item_part(id, "Price") as Label
			var name_label := menu.get_item_part(id, "Name") as Label
			items_ok = items_ok and button != null and menu.get_columns_row().get_child(column).find_child(String(id), true, false) != null \
					and name_label.text == Shop.find(id).name \
					and icon.texture != null and icon.texture == UiIcons.get_icon(icon, Shop.icon_slot(id))
			# The slot is the weapon's id, or the gear's: armor, helmet, defuse_kit.
			items_ok = items_ok and (Shop.icon_slot(id) == id or id in [Shop.VEST, Shop.VEST_HELMET, Shop.KIT])
			var expected_state := BuyMenu.ItemState.OWNED if Shop.is_owned(_player, id) else (BuyMenu.ItemState.POOR if _rounds.get_buy_refusal(_player, id) != "" \
					else (BuyMenu.ItemState.FOCUSED if id == &"hand_cannon" else BuyMenu.ItemState.OK))
			looks_ok = looks_ok and state == expected_state and button.theme_type_variation == expected_roles[state] \
					and name_label.theme_type_variation == expected_text[state] and price.theme_type_variation == expected_price[state] \
					and icon.modulate == expected_tint[state] and name_label.get_theme_color("font_color") == expected_color[state] \
					and button.disabled == (state == BuyMenu.ItemState.OWNED or state == BuyMenu.ItemState.POOR) \
					and (price.text == "Owned") == (state == BuyMenu.ItemState.OWNED) and (state == BuyMenu.ItemState.OWNED or price.text == "$%d" % _rounds.get_price(_player, id)) \
					and (state != BuyMenu.ItemState.FOCUSED or price.get_theme_color("font_color") == Tokens.ACCENT)
	_check("The buy menu says \"Buy\", your side and the buy time, $2400, and the keys' hint; it has four columns (1 Pistols, 2 Primaries, 3 Gear, 4 Grenades: key MUTE, name TEXT) with the shop's items in order",
			texts_ok and columns_ok and items_ok, "texts %s (%s, '%s'), columns %s, items %s" % [texts_ok, menu.get_money_label().text, menu.get_situation_label().text, columns_ok, items_ok])
	_check("Each item has the role of its state (ok, focused, owned, poor: button, name, price, icon tint; \"Owned\" in place of the price, owned and poor ones disabled) and all four are on show",
			looks_ok and states_seen.size() == 4, "looks %s, states seen %s" % [looks_ok, states_seen.keys()])

	# What you hold: the long gun and the pistol, the vest, the grenades (the flashbang twice), at scale 2.
	var held := menu.get_held_slots()
	var flashbangs := _player.inventory.find(WeaponData.find(&"flashbang")).magazine
	var held_ok := held.has(&"armor") and held.count(&"flashbang") == flashbangs and flashbangs >= 1 and held.size() == menu.get_held_icons().size() and not held.has(&"knife")
	var weapon_order: Array[StringName] = []
	for slot in [WeaponData.Slot.PRIMARY, WeaponData.Slot.PISTOL]:
		var weapon := _player.inventory.get_in_slot(slot)
		if weapon != null:
			weapon_order.append(weapon.data.id)
	held_ok = held_ok and held.slice(0, weapon_order.size()) == weapon_order
	for i in menu.get_held_icons().size():
		var rect := menu.get_held_icons()[i]
		held_ok = held_ok and rect.texture == UiIcons.get_icon(rect, held[i]) and rect.texture != null and rect.modulate == Tokens.TEXT
	_check("The footer's \"You hold\" shows the icons of the weapons, the vest and the grenades you carry, in that order (a grenade once for each)",
			held_ok and (menu.get_hold_row().get_child(0) as Label).text == "You hold", "held %s" % [held])

	# The layout, at 720p and at 1.5 times: the mockup's numbers times the scale.
	var area := Rect2()
	for factor: float in [1.0, 1.5]:
		menu.set_ui_scale(factor)
		for i in 4:
			await get_tree().process_frame
		area = (menu.get_node("Margin") as Control).get_global_rect()
		var parts := {}
		var inset := roundf(32.0 * factor)
		var title_trim := menu.get_title_label().get_parent() as Control
		var money_trim := menu.get_money_label().get_parent() as Control
		parts["header"] = title_trim.get_global_rect().position == area.position + Vector2.ONE * inset and absf(title_trim.get_global_rect().size.y - Tokens.TEXT_SIZE_TITLE * factor) <= 1.0 \
				and menu.get_title_label().get_theme_font_size("font_size") == roundi(Tokens.TEXT_SIZE_TITLE * factor) \
				and money_trim.get_global_rect().end.x == area.end.x - inset and absf(money_trim.get_global_rect().end.y - title_trim.get_global_rect().end.y) <= 1.0
		# The line beside the title stands 24 right of it, on the same baseline (their bottoms are the same distance below it).
		parts["situation"] = absf(menu.get_situation_label().get_global_rect().position.x - title_trim.get_global_rect().end.x - roundf(Tokens.SCORE_GAP * factor)) <= 1.0 \
				and absf(menu.get_situation_label().get_global_rect().end.y - title_trim.get_global_rect().end.y) <= 1.0
		var row := menu.get_columns_row().get_global_rect()
		var width := (area.size.x - 2.0 * inset - 3.0 * roundf(Tokens.CARD_GAP * factor)) / 4.0
		parts["row"] = row.position.x == area.position.x + inset and row.end.x == area.end.x - inset and absf(row.position.y - area.position.y - roundf(112.0 * factor)) <= 1.0 \
				and absf(menu.get_title_label().get_parent().get_global_rect().end.y + roundf(Tokens.PAGE_GAP * factor) - row.position.y) <= 1.0
		var column_ok := true
		var item_ok := true
		var inner_ok := true
		for column in 4:
			var rect := menu.get_column_part(column, "Column").get_global_rect()
			var header := menu.get_column_part(column, "Header").get_global_rect()
			column_ok = column_ok and absf(rect.size.x - width) <= 1.0 and absf(rect.position.x - (row.position.x + column * (width + roundf(Tokens.CARD_GAP * factor)))) <= 1.0 \
					and header.size == Vector2(rect.size.x, roundf(Tokens.BUY_HEADER_HEIGHT * factor)) and header.position == rect.position
			var key := menu.get_column_part(column, "Key").get_global_rect()
			var label := menu.get_column_part(column, "Name").get_global_rect()
			column_ok = column_ok and key.position.x == header.position.x and absf(label.position.x - key.end.x - roundf(Tokens.LOBBY_SIDE_GAP * factor)) <= 1.0
			var top := header.end.y + roundf(Tokens.BUY_HEADER_GAP * factor)
			for index in (columns[column] as Array).size():
				var id: StringName = columns[column][index]
				var holder := menu.get_item_part(id, "Holder").get_global_rect()
				var icon := menu.get_item_part(id, "Icon").get_global_rect()
				var name_rect := menu.get_item_part(id, "Name").get_global_rect()
				var price_rect := menu.get_item_part(id, "Price").get_global_rect()
				var pad := roundf((Tokens.BORDER + Tokens.LOBBY_SLOT_PAD_X) * factor)
				item_ok = item_ok and holder.position.y == top + index * (roundf(Tokens.BUY_ITEM_HEIGHT * factor) + roundf(Tokens.CONTENT_GAP * factor)) \
						and holder.size == Vector2(rect.size.x, roundf(Tokens.BUY_ITEM_HEIGHT * factor)) and holder.position.x == rect.position.x
				inner_ok = inner_ok and icon.position.x == holder.position.x + pad and icon.size == Vector2(Tokens.BUY_ICON_BOX) * factor \
						and absf(icon.get_center().y - holder.get_center().y) <= 1.0 \
						and name_rect.position.x == icon.end.x + roundf(Tokens.LOBBY_SIDE_GAP * factor) and price_rect.end.x == holder.end.x - pad \
						and price_rect.position.x - name_rect.end.x == roundf(Tokens.LOBBY_SIDE_GAP * factor)
		parts["columns"] = column_ok
		parts["items"] = item_ok
		parts["inner"] = inner_ok
		# An item's icon is its box's width and the icon at scale 2: the 32 x 16 weapon is 64 x 32, the 16 x 16 vest 32 x 32.
		var pistol_icon := menu.get_item_part(&"hand_cannon", "Icon") as TextureRect
		var vest_icon := menu.get_item_part(&"vest", "Icon") as TextureRect
		parts["icon scale"] = pistol_icon.texture.get_size() * 2.0 == Vector2(Tokens.BUY_ICON_BOX) * factor and vest_icon.texture.get_size() * 2.0 == Vector2(32, 32) * factor
		# The footer: its LINE edge, 16 above the icons, the keys' hint at the right edge, 32 from the bottom of the page.
		var footer := menu.get_footer().get_global_rect()
		var hint := menu.get_hint_label().get_global_rect()
		var footer_style := menu.get_footer().get_theme_stylebox("panel") as StyleBoxFlat
		var held_icons := menu.get_held_icons()
		var first := held_icons[0].get_global_rect()
		parts["footer"] = footer.position.x == area.position.x + inset and footer.end.x == area.end.x - inset and absf(footer.end.y - (area.end.y - inset)) <= 1.0 \
				and footer_style.border_width_top == roundi(Tokens.LINE * factor) and footer_style.border_color == Tokens.LINE_COLOR \
				and absf(first.position.y - (footer.position.y + roundf((Tokens.LINE + Tokens.CLASS_FOOTER_PAD_TOP) * factor))) <= 1.0 \
				and hint.end.x == footer.end.x and held_icons[0].get_global_rect().size == held_icons[0].texture.get_size() * 2.0 \
				and absf((menu.get_hold_row().get_child(1) as Control).get_global_rect().position.x - (menu.get_hold_row().get_child(0) as Control).get_global_rect().end.x - roundf(Tokens.SCORE_GAP * factor)) <= 1.0
		if factor == 1.0:
			parts["fits the window"] = area == Rect2(Vector2.ZERO, view) and footer.end.y == view.y - 32.0 and row.position.y == 112.0
		var failed: Array = []
		for part: String in parts:
			if not parts[part]:
				failed.append(part)
		_check("At %s times the size the header, the four columns (a header 32 and items 64 high 8 apart, an icon box 64 x 32, texts at the mockup's gaps), the icons at scale 2 and the footer are where the mockup has them times the scale" % factor,
				failed.is_empty(), "failed parts %s" % [failed])
		print("  [buy at %s] area %s, columns %s, footer %s, first held %s" % [factor, area, menu.get_columns_row().get_global_rect(), menu.get_footer().get_global_rect(), first])
	menu.set_ui_scale(1.0)
	await get_tree().process_frame

	# The keys and the mouse: a number selects a column (its key and edge light up, the others' names dim), the hover moves the focus.
	menu.select_category(Shop.Category.GEAR)
	var gear_lit := menu.get_column_part(2, "Header").theme_type_variation == &"ColumnHeaderLitPanel" and menu.get_column_part(2, "Key").theme_type_variation == &"HeaderLabel" \
			and menu.get_column_part(2, "Name").theme_type_variation == &"BrightLabel" and menu.get_column_part(0, "Name").theme_type_variation == &"DimLabel" \
			and menu.get_column_part(0, "Key").theme_type_variation == &"MuteLabel" and menu.get_column_part(0, "Header").theme_type_variation == &"ColumnHeaderPanel"
	menu.select_category(-1)
	var all_rest := menu.get_column_part(0, "Name").theme_type_variation == &"BrightLabel" and menu.get_column_part(2, "Header").theme_type_variation == &"ColumnHeaderPanel"
	var before := menu.get_item_state(&"hand_cannon")
	var other_id: StringName = &""
	var poor_id: StringName = &""
	for id in [&"smg", &"shotgun", &"frag", &"smoke", &"vest_helmet"]:
		if other_id == &"" and menu.get_item_state(id) == BuyMenu.ItemState.OK:
			other_id = id
	for id in [&"sniper", &"carbine", &"rifle"]:
		if poor_id == &"" and menu.get_item_state(id) == BuyMenu.ItemState.POOR:
			poor_id = id
	menu.get_item_button(other_id).mouse_entered.emit()
	menu.get_item_button(poor_id).mouse_entered.emit()
	await get_tree().process_frame
	var moved := before == BuyMenu.ItemState.FOCUSED and other_id != &"" and poor_id != &"" and menu.get_item_state(other_id) == BuyMenu.ItemState.FOCUSED \
			and menu.get_item_state(&"hand_cannon") == BuyMenu.ItemState.OK and menu.get_item_state(poor_id) == BuyMenu.ItemState.POOR and not menu.get_item_button(poor_id).has_focus()
	_check("A selected column lights its key and edge in the accent and dims the others' names; hovering an item that can be bought gives it the focus look (and takes it from the one before), a poor item takes none",
			gear_lit and all_rest and moved, "gear lit %s, rest %s, moved %s" % [gear_lit, all_rest, moved])
	_check("Nothing in the buy menu, in a game, carries a theme override (the item looks and the footer's icons come from the theme's roles and palette)",
			_overrides_below(menu).is_empty(), "%s" % [_overrides_below(menu)])
	menu.close()
	remove_child(main)
	main.queue_free()
	await get_tree().process_frame
	MenuState.reset()
	GameLaunch.clear()


## Hovering a card lights it (the focus follows the mouse and the lime key chip with it), and the number keys pick.
func _check_class_draft_input(menu: ClassMenu) -> void:
	var before := menu.get_lit_index()
	var other := 1 - before
	(menu.get_part(other, "Select") as Button).mouse_entered.emit()
	await get_tree().process_frame
	var hovered := menu.get_lit_index() == other and menu.get_part(other, "Chip").theme_type_variation == &"KeyChipLit" \
			and menu.get_part(before, "Chip").theme_type_variation == &"KeyChip" and menu.get_part(other, "Select").has_focus()
	var classes := menu.get_classes()
	_send(_key_event(KEY_2))
	_send(_key_event(KEY_2, false))
	await get_tree().process_frame
	var picked_second := not menu.is_open() and _player.class_data == classes[1]
	menu.open()
	await get_tree().process_frame
	_send(_key_event(KEY_1))
	_send(_key_event(KEY_1, false))
	await get_tree().process_frame
	var picked_first := not menu.is_open() and _player.class_data == classes[0]
	_check("Hovering the other card moves the focus, the lime frame and the lime key chip to it; key 2 then picks the second class and key 1 the first (the menu closes each time)",
			hovered and picked_second and picked_first,
			"hovered %s, second %s, first %s, lit before %d" % [hovered, picked_second, picked_first, before])



## The real settings file is exactly as it was when the test started.
func _test_real_file_untouched() -> void:
	var now := FileAccess.get_md5(Settings.SETTINGS_PATH) if FileAccess.file_exists(Settings.SETTINGS_PATH) else ""
	_check("The real user://settings.cfg was not read, created or changed by any of this",
			Settings.real_file_accesses == 0 and Settings.get_instance().save_path == "", "accesses %d, shared instance saves to '%s' (checksum before '%s', after '%s')" % [
					Settings.real_file_accesses, Settings.get_instance().save_path, _real_file_md5, now])


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
	GameLaunch.start_match(MAP_SCENE.resource_path, rules)
	var main := MAIN_SCENE.instantiate()
	main.load_settings = false
	main.loading_screen = false
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
## [param rules] is the round manager to play it with (a [RespawnMatch] for Team Deathmatch).
func _new_match(rounds_to_win: int = 5, rules: RoundManager = null) -> void:
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
	_rounds = rules if rules != null else RoundManager.new()
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


## The names of [param characters], in order.
func _names(characters: Array) -> Array:
	return characters.map(func(character: Character) -> String: return String(character.name))


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


## The Stats screen (M14, D-204): opened by the main menu's Stats button, four tabs built from a
## book of three matches (an empty book shows a note on each), the Overview's tiles and win bars,
## the weapons table, the history newest first, the training bests, no theme override anywhere
## (the rows are built in code), Reset asking twice and Esc closing it.
func _test_stats_menu() -> void:
	MenuState.reset()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.load_settings = false
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var stats := menu.get_stats_menu()
	var empty := StatsBook.new()
	stats.book = empty
	_check("The Stats button sits between Practice and Settings and opens the Stats screen over the menu: four tabs (Overview, Weapons, History, Training), the screen on top",
			menu.get_buttons()[2] == menu.get_stats_button() and menu.get_stats_button().text == "Stats" and not stats.is_open(), "closed at the start")
	menu.get_stats_button().pressed.emit()
	await get_tree().process_frame
	var tabs := stats.get_tabs()
	var names: Array[String] = []
	for index in tabs.get_tab_count():
		names.append(tabs.get_tab_title(index))
	_check("It opens with the four tabs and the Back button focused",
			stats.is_open() and MenuState.is_top(stats) and names == StatsMenu.TAB_NAMES and stats.get_back_button().has_focus(),
			"open %s, tabs %s" % [stats.is_open(), names])
	var notes := 0
	for index in 4:
		var column := tabs.get_child(index).get_child(0)
		notes += 1 if column.get_child_count() == 1 and column.get_child(0).theme_type_variation == &"DimLabel" else 0
	_check("With no matches every tab shows one note saying what will appear there", notes == 4, "%d of 4 tabs" % notes)
	# Three matches: a bomb win and a loss on Depot, a Team Deathmatch win on Square.
	var populated := StatsBook.new()
	for sample: Array in [["rounds", "depot", "win", 14, 9, 1800.0, 20, 300, 90, 5], ["rounds", "depot", "loss", 9, 14, 1200.0, 18, 250, 60, 2], ["respawn", "square", "win", 25, 20, 3300.0, 0, 500, 130, 7]]:
		var record := StatsMatch.new()
		record.date = 1_792_000_000 + 1000 * populated.history.size()
		record.mode = sample[0]
		record.map = sample[1]
		record.result = sample[2]
		record.kills = sample[3]
		record.deaths = sample[4]
		record.damage = sample[5]
		record.rounds = sample[6]
		record.duration = 600.0
		record.headshot_kills = sample[9]
		var gun := StatsWeapon.new()
		gun.add_shots(sample[7])
		for hit in sample[8]:
			gun.add_hit(Hitbox.Zone.HEAD if hit < 10 else Hitbox.Zone.CHEST)
		record.weapons["rifle"] = gun
		populated.add_match(record)
	populated.submit_best("aim_flick_rifle", 4200.0, {"hits": 31})
	stats.book = populated
	stats.refresh()
	await get_tree().process_frame
	var overview := tabs.get_child(0).get_child(0)
	var tiles := overview.find_children("*", "PanelContainer", true, false).filter(func(node: Node) -> bool: return node.theme_type_variation == &"InsetPanel")
	var tile_texts: Array = tiles.map(func(tile: Node) -> String: return "%s %s" % [tile.find_child("Caption", true, false).text, tile.find_child("Value", true, false).text])
	var bars := overview.find_children("*", "ProgressBar", true, false)
	_check("The Overview has ten tiles from the lifetime numbers and a bar for each mode and map won (2 modes, 2 maps)",
			tiles.size() == 10 and tile_texts[0] == "K/D 1.12" and tile_texts[1] == "ADR 79" and tile_texts[5] == "Matches 3" and tile_texts[6] == "Kills 48"
			and bars.size() == 4, "tiles %s, %d bars" % [tile_texts, bars.size()])
	var weapons := tabs.get_child(1).get_child(0)
	var history := tabs.get_child(2).get_child(0)
	var training := tabs.get_child(3).get_child(0)
	var first_row := (history.get_child(2).find_children("*", "Label", true, false).map(func(label: Node) -> String: return (label as Label).text))
	_check("Weapons has the title, the header and a row for the one gun; History a title, a header and a row per match with the newest first; Training a title, a header and one best",
			weapons.get_child_count() >= 3 and history.get_child_count() == 5 and training.get_child_count() == 3
			and first_row[1] == "Team Deathmatch · Square" and first_row[2] == "Win" and first_row[4] == "25" and first_row[7] == "-",
			"weapons %d, history %d (first row %s), training %d" % [weapons.get_child_count(), history.get_child_count(), first_row, training.get_child_count()])
	var overrides := _overrides_below(stats)
	_check("Nothing on the Stats screen, the rows built in code included, carries a theme override", overrides.is_empty(), "%s" % [overrides])
	# Scaled to 2x the rows are twice as high.
	stats.set_ui_scale(2.0)
	await get_tree().process_frame
	var scaled_row := (tabs.get_child(2).get_child(0).get_child(2) as Control).custom_minimum_size.y
	stats.set_ui_scale(1.0)
	_check("Scaled by 2 the History rows are twice as high (64 instead of 32)", is_equal_approx(scaled_row, 64.0), "%.0f" % scaled_row)
	# Export CSV.
	stats.export_csv()
	var csv_lines := FileAccess.get_file_as_string(StatsMenu.EXPORT_PATH).strip_edges().split("\n")
	DirAccess.remove_absolute(StatsMenu.EXPORT_PATH)
	_check("Export CSV writes the history (a header and three rows) and says where", csv_lines.size() == 4 and stats.get_status().begins_with("Saved "), "%d lines, '%s'" % [csv_lines.size(), stats.get_status()])
	# Reset asks twice.
	stats.get_reset_button().pressed.emit()
	var armed := stats.is_reset_armed() and stats.get_reset_button().text == StatsMenu.RESET_CONFIRM_TEXT and populated.history.size() == 3
	stats.get_reset_button().pressed.emit()
	await get_tree().process_frame
	_check("Reset stats asks again on the first press and deletes everything on the second",
			armed and not stats.is_reset_armed() and populated.history.is_empty() and populated.lifetime.matches == 0 and populated.training.is_empty()
			and stats.get_reset_button().text == StatsMenu.RESET_TEXT and stats.get_status() == "Stats deleted.", "armed %s, %d matches left" % [armed, populated.history.size()])
	# The first press is forgotten when the screen closes; Esc closes the screen and gives the focus back.
	stats.get_reset_button().pressed.emit()
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Esc closes the Stats screen, forgets a first press of Reset and puts the focus back on the Stats button",
			not stats.is_open() and not stats.is_reset_armed() and MenuState.is_top(menu) and menu.get_stats_button().has_focus(),
			"open %s, armed %s, focus %s" % [stats.is_open(), stats.is_reset_armed(), menu.get_stats_button().has_focus()])
	remove_child(menu)
	menu.queue_free()
	await get_tree().process_frame
	MenuState.reset()


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


## The key and mouse events of an action: its gamepad events (D-211) have their own checks (access_test).
func _bound_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			events.append(event)
	return events
