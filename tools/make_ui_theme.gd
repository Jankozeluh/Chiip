extends SceneTree
## Tool: builds Chiip's UI theme and saves it as ui/chiip_theme.tres (D-057).
##
## Run from the project folder (the icons must exist and be imported, see
## tools/generate_ui_icons.gd):
##
##     Godot --headless --path . --quit-after 100 --script res://tools/make_ui_theme.gd
##
## The theme is the one place that says how every menu looks: the pixel font,
## the colors, the shapes of buttons, sliders, check boxes, tabs and so on, and
## the *type variations* for recurring roles (a title label, a section header,
## a team header...). It is the project's theme (Project Settings > GUI >
## Theme > Custom), so every Control gets it. ui/chiip_theme.tres is generated,
## so change the look here and run the tool again (editing the .tres in the
## editor works too, but the next run overwrites it).
##
## Every colour, font, size and spacing comes from the design tokens in
## tools/ui_palette.gd (D-131): this script only decides which token goes
## where and has no numbers of its own (ui_test checks that), so a new look is
## a change of tokens. All sizes are for a 720-pixel-tall window; [UiTheme]
## makes scaled copies of this theme for bigger windows. Nothing is anti-aliased.
##
## It also fills the icon slots ([UiIcons]): every PNG in assets/ui/icons/
## named after a slot goes into the theme type "Icons".
##
## How a theme works (Unity: like a USS style sheet): a Control looks up each of
## its colors, fonts, sizes, styleboxes and icons by name in a "theme type",
## usually the class name ("Button"). A *type variation* is a named copy of a
## type with a few items changed ("TitleLabel" is a "Label" with a big font);
## a node picks one with its Theme Type Variation property.

const Palette := preload("res://tools/ui_palette.gd")

const OUTPUT_PATH := "res://ui/chiip_theme.tres"
const ICON_FOLDER := "res://assets/ui/"

## Content margins meaning "as wide as the border" (a StyleBox's default).
const BORDER_MARGINS := Vector4(-1, -1, -1, -1)

var _theme := Theme.new()


func _init() -> void:
	_theme.default_font = load(Palette.FONT)
	_theme.default_font_size = Palette.TEXT_SIZE
	_palette()
	_labels()
	_panels()
	_containers()
	_hud()
	_console()
	_buttons()
	_toggles()
	_line_edit()
	_sliders()
	_progress_bar()
	_tabs()
	_scroll_bars()
	_separators()
	_popup_menu()
	_tooltip()
	_rich_text()
	_icon_slots()
	var error := ResourceSaver.save(_theme, OUTPUT_PATH)
	print("%s %s: %d types" % ["saved" if error == OK else "FAILED to save", OUTPUT_PATH, _theme.get_type_list().size()])
	quit(0 if error == OK else 1)


## Named colors for code that needs one (a node asks with
## get_theme_color("accent", "Palette")), so the palette lives in the theme too.
## Team colors are copied from [Teams], which owns them. Colors that no control
## can hold as a theme item (a table row is dimmed by multiplying it, "dead_row")
## are named here too.
func _palette() -> void:
	_colors("Palette", {
		"accent": Palette.ACCENT, "accent_bright": Palette.ACCENT_BRIGHT, "accent_dark": Palette.ACCENT_DARK,
		"text": Palette.TEXT, "text_bright": Palette.TEXT_BRIGHT, "text_dim": Palette.TEXT_DIM,
		"text_disabled": Palette.TEXT_DISABLED,
		"panel": Palette.PANEL, "panel_border": Palette.PANEL_BORDER, "inset": Palette.INSET,
		"friendly": Teams.FRIENDLY_COLOR, "enemy": Teams.ENEMY_COLOR,
		# Team colours lightened for text on dark panels (scores, names, the match result).
		"friendly_text": _team_text(Teams.FRIENDLY_COLOR),
		"enemy_text": _team_text(Teams.ENEMY_COLOR),
		# What a dead player's row is multiplied by (a row's modulate is not a theme item).
		"dead_row": Palette.DEAD_ROW,
	})


## [param color] lightened the way [method Teams.text_color_for] does it, so text
## in a team's colour stays readable on a dark panel.
func _team_text(color: Color) -> Color:
	return color.lightened(Teams.TEXT_LIGHTEN)


func _labels() -> void:
	_colors("Label", {"font_color": Palette.TEXT, "font_outline_color": Palette.TEXT_OUTLINE})
	# Recurring roles. A variation only lists what differs from "Label".
	_variation("TitleLabel", "Label")
	_font_sizes("TitleLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("TitleLabel", {"font_color": Palette.TEXT_BRIGHT})
	_variation("ScoreLabel", "Label")
	_font_sizes("ScoreLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("ScoreLabel", {"font_color": Palette.TEXT_BRIGHT})
	_variation("HeaderLabel", "Label")
	_colors("HeaderLabel", {"font_color": Palette.ACCENT})
	_variation("DimLabel", "Label")
	_colors("DimLabel", {"font_color": Palette.TEXT_DIM})
	_variation("BrightLabel", "Label")
	_colors("BrightLabel", {"font_color": Palette.TEXT_BRIGHT})
	# The biggest text: the game's name, the match result.
	_variation("HeroLabel", "Label")
	_font_sizes("HeroLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_colors("HeroLabel", {"font_color": Palette.TEXT_BRIGHT})
	# Inside a mode choice of the main menu: the mode's name, and the line saying what you'll get.
	_variation("ModeTitleLabel", "Label")
	_font_sizes("ModeTitleLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("ModeTitleLabel", {"font_color": Palette.TEXT_BRIGHT})
	_variation("ModeDetailLabel", "Label")
	_colors("ModeDetailLabel", {"font_color": Palette.TEXT_DIM})
	# Scores in a team's colour. Colours are relative to the viewer, so "your" team is
	# always the friendly one: the left score of a scoreboard says Friendly, the right Enemy.
	_variation("FriendlyScoreLabel", "Label")
	_font_sizes("FriendlyScoreLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("FriendlyScoreLabel", {"font_color": _team_text(Teams.FRIENDLY_COLOR)})
	_variation("EnemyScoreLabel", "Label")
	_font_sizes("EnemyScoreLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("EnemyScoreLabel", {"font_color": _team_text(Teams.ENEMY_COLOR)})
	# The match result: "Victory" in your team's colour, "Defeat" in the enemy's.
	_variation("VictoryLabel", "Label")
	_font_sizes("VictoryLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("VictoryLabel", {"font_color": _team_text(Teams.FRIENDLY_COLOR)})
	_variation("DefeatLabel", "Label")
	_font_sizes("DefeatLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("DefeatLabel", {"font_color": _team_text(Teams.ENEMY_COLOR)})


func _panels() -> void:
	var panel := _box("panel", Palette.PANEL, Palette.PANEL_BORDER, Palette.BORDER)
	_styles("Panel", {"panel": panel})
	# The dimming behind a modal menu: a full-screen Panel that keeps the clicks from the game.
	_variation("BackdropPanel", "Panel")
	_styles("BackdropPanel", {"panel": _box("backdrop_panel", Palette.BACKDROP)})
	_styles("PanelContainer", {"panel": panel})
	_styles("PopupPanel", {"panel": _box("popup_panel", Palette.PANEL_OPAQUE, Palette.PANEL_BORDER, Palette.BORDER)})
	# A screen that wants your attention: the match-end screen.
	_variation("ModalPanel", "PanelContainer")
	_styles("ModalPanel", {"panel": _box("modal_panel", Palette.PANEL, Palette.ACCENT, Palette.BORDER)})
	# Over the live game: the Tab scoreboard.
	_variation("OverlayPanel", "PanelContainer")
	_styles("OverlayPanel", {"panel": _box("overlay_panel", Palette.PANEL_OVERLAY, Palette.PANEL_BORDER, Palette.BORDER)})
	# The developer console, a dark strip under the top edge of the screen.
	_variation("ConsolePanel", "PanelContainer")
	var console := _box("console_panel", Palette.CONSOLE, Palette.ACCENT)
	console.border_width_bottom = Palette.BORDER
	_styles("ConsolePanel", {"panel": console})
	# A sunken area: a list, a preview.
	_variation("InsetPanel", "PanelContainer")
	_styles("InsetPanel", {"panel": _box("inset_panel", Palette.INSET, Palette.INSET_BORDER, Palette.BORDER)})
	# Scoreboard rows: nothing behind a row, a light band behind your own.
	_variation("RowPanel", "PanelContainer")
	_styles("RowPanel", {"panel": _empty("row_panel", BORDER_MARGINS)})
	_variation("YouRowPanel", "PanelContainer")
	_styles("YouRowPanel", {"panel": _box("you_row_panel", Palette.YOU_ROW)})
	# The colored bar above a team's rows. Team colors come from Teams.
	_variation("TeamHeaderFriendly", "PanelContainer")
	_styles("TeamHeaderFriendly", {"panel": _box("team_header_friendly", Teams.FRIENDLY_COLOR)})
	_variation("TeamHeaderEnemy", "PanelContainer")
	_styles("TeamHeaderEnemy", {"panel": _box("team_header_enemy", Teams.ENEMY_COLOR)})


## Spacing for recurring layouts. Plain containers keep Godot's defaults, so
## the HUD (which relies on them) doesn't change.
func _containers() -> void:
	_variation("PageMargin", "MarginContainer")
	_margins("PageMargin", Palette.PAGE_MARGIN_X, Palette.PAGE_MARGIN_Y)
	_variation("PanelMargin", "MarginContainer")
	_margins("PanelMargin", Palette.PANEL_MARGIN_X, Palette.PANEL_MARGIN_Y)
	_variation("PanelMarginWide", "MarginContainer")
	_margins("PanelMarginWide", Palette.PANEL_MARGIN_WIDE_X, Palette.PANEL_MARGIN_WIDE_Y)
	_variation("RowMargin", "MarginContainer")
	_margins("RowMargin", Palette.ROW_MARGIN_X, Palette.ROW_MARGIN_Y)
	# The rows of a menu, and its smaller groups.
	_variation("ContentBox", "VBoxContainer")
	_constants("ContentBox", {"separation": Palette.CONTENT_GAP})
	_variation("TableBox", "VBoxContainer")
	_constants("TableBox", {"separation": Palette.TABLE_GAP})
	_variation("TeamBox", "VBoxContainer")
	_constants("TeamBox", {"separation": Palette.TEAM_ROW_GAP})
	_variation("ScoreRow", "HBoxContainer")
	_constants("ScoreRow", {"separation": Palette.SCORE_GAP})
	_variation("FormRow", "HBoxContainer")
	_constants("FormRow", {"separation": Palette.FORM_GAP})
	_variation("ButtonRow", "HBoxContainer")
	_constants("ButtonRow", {"separation": Palette.BUTTON_ROW_GAP})
	# The buttons of a segmented choice (1 2 3 4 5), close enough to read as one strip.
	_variation("SegmentRow", "HBoxContainer")
	_constants("SegmentRow", {"separation": Palette.SEGMENT_GAP})
	# The main menu's mode choices, and the two lines inside each.
	_variation("ModeList", "VBoxContainer")
	_constants("ModeList", {"separation": Palette.MODE_GAP})
	_variation("ModeMargin", "MarginContainer")
	_margins("ModeMargin", Palette.MODE_BUTTON_PAD_X, Palette.MODE_BUTTON_PAD_Y)
	_variation("ModeText", "VBoxContainer")
	_constants("ModeText", {"separation": Palette.MODE_LINE_GAP})
	# The settings menu's crosshair colour swatches, and the margin that frames each colour inside its button.
	_variation("SwatchRow", "HBoxContainer")
	_constants("SwatchRow", {"separation": Palette.SWATCH_GAP})
	_variation("SwatchMargin", "MarginContainer")
	_margins("SwatchMargin", Palette.SWATCH_MARGIN, Palette.SWATCH_MARGIN)


## The HUD's roles (D-133): the labels of the weapon, health and ammo, the death
## and spectate messages, the top bar and the centre messages, the bomb's text,
## the top bar's boxes and spacing, and the bomb's progress bar. The HUD is scaled
## by [UiScale], which reads the sizes and spacing these roles give a control and
## scales them, so a role's numbers are for a 720-pixel-tall window like the rest.
## The custom type "Hud" holds what code reads: the colours of game states (the
## timer in freeze time and in the last seconds, a notice, the bomb's gold, a dead
## player's square) and the size of a player's square, so a screen asks
## get_theme_color("alert", "Hud") instead of keeping a colour of its own.
func _hud() -> void:
	_colors("Hud", {
		"freeze_timer": Palette.HUD_FREEZE_TIMER, "alert": Palette.HUD_ALERT, "notice": Palette.HUD_NOTICE,
		"gold": Palette.HUD_GOLD, "pip_dead": Palette.HUD_PIP_DEAD,
	})
	_constants("Hud", {"pip_size": Palette.HUD_PIP_SIZE})
	# Bottom corners: the weapon name, and health and ammo. The death and spectate lines.
	_hud_label("HudWeaponLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_TEXT)
	_hud_label("HudValueLabel", Palette.HUD_SIZE_VALUE, Palette.HUD_OUTLINE_VALUE, Palette.HUD_TEXT)
	_hud_label("HudDeathLabel", Palette.HUD_SIZE_HEADLINE, Palette.HUD_OUTLINE_HEADLINE, Palette.HUD_ALERT)
	_hud_label("HudSpectateLabel", Palette.HUD_SIZE_SPECTATE, Palette.HUD_OUTLINE_SPECTATE, Palette.HUD_TEXT)
	# Under the death message in a respawning match: "Respawning in 3".
	_hud_label("HudRespawnLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_TEXT_BRIGHT)
	# The top bar: scores, the timer (game states recolour it) and the line under it.
	_hud_label("HudScoreLabel", Palette.HUD_SIZE_SCORE, Palette.HUD_OUTLINE_SCORE, Palette.HUD_TEXT)
	_hud_label("HudTimerLabel", Palette.HUD_SIZE_SCORE, Palette.HUD_OUTLINE_SCORE, Palette.HUD_TEXT_BRIGHT)
	_hud_label("HudRoundLabel", Palette.HUD_SIZE_SMALL, Palette.HUD_OUTLINE_SCORE, Palette.HUD_TEXT_DIM)
	# The centre messages: the title, the main line, and the lower lines.
	_hud_label("HudTitleLabel", Palette.HUD_SIZE_TITLE, Palette.HUD_OUTLINE_TITLE, Palette.HUD_TEXT_BRIGHT)
	_hud_label("HudLineLabel", Palette.HUD_SIZE_HEADLINE, Palette.HUD_OUTLINE_HEADLINE, Palette.HUD_TEXT_BRIGHT)
	_hud_label("HudNoteLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_TEXT_BRIGHT)
	# The bomb: its tag, the prompt under the crosshair and the message under the top bar.
	_hud_label("HudBombTagLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_GOLD)
	_hud_label("HudPromptLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_TEXT)
	_hud_label("HudBombMessageLabel", Palette.HUD_SIZE_TEXT, Palette.HUD_OUTLINE_TEXT, Palette.HUD_GOLD)
	# The top bar: its spacing, the boxes (each team's colour comes from Teams, darkened) and what is inside them.
	_variation("HudTopBar", "HBoxContainer")
	_constants("HudTopBar", {"separation": Palette.HUD_BAR_GAP})
	_variation("HudFriendlyBox", "PanelContainer")
	_styles("HudFriendlyBox", {"panel": _box("hud_friendly_box", _team_box(Teams.FRIENDLY_COLOR))})
	_variation("HudEnemyBox", "PanelContainer")
	_styles("HudEnemyBox", {"panel": _box("hud_enemy_box", _team_box(Teams.ENEMY_COLOR))})
	_variation("HudTimerBox", "PanelContainer")
	_styles("HudTimerBox", {"panel": _box("hud_timer_box", Palette.HUD_TIMER_BOX)})
	_variation("HudBoxMargin", "MarginContainer")
	_constants("HudBoxMargin", {
		"margin_left": Palette.HUD_BOX_PAD_X, "margin_top": Palette.HUD_BOX_PAD_TOP,
		"margin_right": Palette.HUD_BOX_PAD_X, "margin_bottom": Palette.HUD_BOX_PAD_BOTTOM,
	})
	_variation("HudBoxContent", "VBoxContainer")
	_constants("HudBoxContent", {"separation": Palette.HUD_BOX_GAP})
	_variation("HudPips", "HBoxContainer")
	_constants("HudPips", {"separation": Palette.HUD_PIP_GAP})
	# The centre messages' lines, and the kill feed's.
	_variation("HudMessages", "VBoxContainer")
	_constants("HudMessages", {"separation": Palette.HUD_MESSAGE_GAP})
	_variation("HudKillFeed", "VBoxContainer")
	_constants("HudKillFeed", {"separation": Palette.HUD_FEED_GAP})
	# The bomb's progress bar: a strip and the fill on it (both plain Panels with one flat colour).
	_variation("HudBarBack", "Panel")
	_styles("HudBarBack", {"panel": _box("hud_bar_back", Palette.HUD_BAR_BACK)})
	_variation("HudBarFill", "Panel")
	_styles("HudBarFill", {"panel": _box("hud_bar_fill", Palette.HUD_BAR_FILL)})


## A HUD text role: a [Label] with a size, an outline width (the outline is
## [constant Palette.HUD_OUTLINE]) and a colour.
func _hud_label(role: String, size: int, outline: int, color: Color) -> void:
	_variation(role, "Label")
	_font_sizes(role, {"font_size": size})
	_colors(role, {"font_color": color, "font_outline_color": Palette.HUD_OUTLINE})
	_constants(role, {"outline_size": outline})


## A team's colour as the top bar's score box shows it: darkened, a little see-through.
func _team_box(color: Color) -> Color:
	return Color(color.darkened(Palette.HUD_SCORE_BOX_DARKEN), Palette.HUD_SCORE_BOX_ALPHA)


## The developer console's text is monospace, so its columns line up. A system
## font made from the names in the tokens; one font shared by the output and the
## input line (the size is the body size, as everywhere).
func _console() -> void:
	var mono := SystemFont.new()
	mono.resource_scene_unique_id = "mono_font"
	mono.font_names = PackedStringArray(Palette.FONT_MONO_NAMES)
	_variation("ConsoleLabel", "Label")
	_fonts("ConsoleLabel", {"font": mono})
	_variation("ConsoleLineEdit", "LineEdit")
	_fonts("ConsoleLineEdit", {"font": mono})


func _buttons() -> void:
	_button_styles("Button", Palette.BUTTON_PAD_X, Palette.BUTTON_PAD_Y)
	_colors("Button", {
		"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT_BRIGHT,
		"font_pressed_color": Palette.ACCENT_BRIGHT, "font_hover_pressed_color": Palette.ACCENT_BRIGHT,
		"font_focus_color": Palette.TEXT_BRIGHT, "font_disabled_color": Palette.TEXT_DISABLED,
		"font_outline_color": Palette.TEXT_OUTLINE,
	})
	_constants("Button", {"h_separation": Palette.BUTTON_ICON_GAP})
	# The main menu's and the pause menu's buttons.
	_variation("BigButton", "Button")
	_font_sizes("BigButton", {"font_size": Palette.TEXT_SIZE_LARGE})
	_button_styles("BigButton", Palette.BIG_BUTTON_PAD_X, Palette.BIG_BUTTON_PAD_Y)
	# The main button of a screen (Start, Resume, Play again): framed in the accent at rest.
	_variation("PrimaryButton", "Button")
	_button_styles("PrimaryButton", Palette.BUTTON_PAD_X, Palette.BUTTON_PAD_Y, Palette.PRIMARY_BORDER)
	# A mode choice of the main menu: a big button whose text is two labels inside it.
	_variation("ModeButton", "Button")
	_button_styles("ModeButton", Palette.MODE_BUTTON_PAD_X, Palette.MODE_BUTTON_PAD_Y)
	# A word to click, without a box until it is hovered (Custom match, Settings, Quit).
	_variation("TextButton", "Button")
	_text_button_styles("TextButton", Palette.TEXT_BUTTON_PAD_X, Palette.TEXT_BUTTON_PAD_Y)
	_colors("TextButton", {"font_color": Palette.TEXT_DIM})
	# Option buttons and menu buttons share the button look; the arrow is an icon.
	_icons("OptionButton", {"arrow": "arrow_down"})
	_constants("OptionButton", {"arrow_margin": Palette.ARROW_GAP, "h_separation": Palette.BUTTON_ICON_GAP})


## The five looks of a button: rest, hover, pressed, focus ring and disabled.
## [param rest_border] is the frame at rest.
func _button_styles(type: String, pad_x: int, pad_y: int, rest_border: Color = Palette.BUTTON_BORDER) -> void:
	var margins := Vector4(pad_x, pad_y, pad_x, pad_y)
	var prefix := type.to_snake_case()
	_styles(type, {
		"normal": _box("%s_normal" % prefix, Palette.BUTTON, rest_border, Palette.BORDER, margins),
		"hover": _box("%s_hover" % prefix, Palette.BUTTON_HOVER, Palette.ACCENT_MID, Palette.BORDER, margins),
		"pressed": _box("%s_pressed" % prefix, Palette.BUTTON_PRESSED, Palette.ACCENT, Palette.BORDER, margins),
		"hover_pressed": _box("%s_hover_pressed" % prefix, Palette.BUTTON_PRESSED, Palette.ACCENT, Palette.BORDER, margins),
		"disabled": _box("%s_disabled" % prefix, Palette.BUTTON_DISABLED, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, margins),
		# Drawn on top of the current look while the control has the keyboard focus.
		"focus": _ring("%s_focus" % prefix, Palette.ACCENT, margins),
	})


## A button that is only its text at rest and when disabled, with a fill when
## hovered or pressed, and the usual focus ring.
func _text_button_styles(type: String, pad_x: int, pad_y: int) -> void:
	var margins := Vector4(pad_x, pad_y, pad_x, pad_y)
	var prefix := type.to_snake_case()
	_styles(type, {
		"normal": _empty("%s_normal" % prefix, margins),
		"hover": _box("%s_hover" % prefix, Palette.BUTTON_HOVER, Color.TRANSPARENT, 0, margins),
		"pressed": _box("%s_pressed" % prefix, Palette.BUTTON_PRESSED, Color.TRANSPARENT, 0, margins),
		"hover_pressed": _box("%s_hover_pressed" % prefix, Palette.BUTTON_PRESSED, Color.TRANSPARENT, 0, margins),
		"disabled": _empty("%s_disabled" % prefix, margins),
		"focus": _ring("%s_focus" % prefix, Palette.ACCENT, margins),
	})


## Check boxes and check buttons. Godot would otherwise draw them like buttons
## (it looks in "Button" before its built-in "CheckBox"), so they get their own
## styles: nothing at rest, a faint band when hovered, the accent ring on focus.
func _toggles() -> void:
	var margins := Vector4(Palette.TOGGLE_PAD_X, Palette.TOGGLE_PAD_Y, Palette.TOGGLE_PAD_X, Palette.TOGGLE_PAD_Y)
	for type in ["CheckBox", "CheckButton"]:
		var prefix: String = type.to_snake_case()
		var faint := _box("%s_hover" % prefix, Palette.TOGGLE_HOVER, Color.TRANSPARENT, 0, margins)
		_styles(type, {
			"normal": _empty("%s_normal" % prefix, margins),
			"pressed": _empty("%s_pressed" % prefix, margins),
			"disabled": _empty("%s_disabled" % prefix, margins),
			"hover": faint,
			"hover_pressed": faint,
			"focus": _ring("%s_focus" % prefix, Palette.ACCENT, margins),
		})
		_colors(type, {
			"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT_BRIGHT,
			"font_pressed_color": Palette.TEXT_BRIGHT, "font_hover_pressed_color": Palette.TEXT_BRIGHT,
			"font_focus_color": Palette.TEXT_BRIGHT, "font_disabled_color": Palette.TEXT_DISABLED,
			"font_outline_color": Palette.TEXT_OUTLINE,
		})
		_constants(type, {"h_separation": Palette.TOGGLE_ICON_GAP, "check_v_offset": 0})
	_icons("CheckBox", {
		"unchecked": "checkbox_off", "checked": "checkbox_on",
		"unchecked_disabled": "checkbox_off_disabled", "checked_disabled": "checkbox_on_disabled",
		"radio_unchecked": "radio_off", "radio_checked": "radio_on",
		"radio_unchecked_disabled": "radio_off_disabled", "radio_checked_disabled": "radio_on_disabled",
	})
	_icons("CheckButton", {
		"unchecked": "switch_off", "checked": "switch_on",
		"unchecked_disabled": "switch_off_disabled", "checked_disabled": "switch_on_disabled",
	})


func _line_edit() -> void:
	var margins := Vector4(Palette.FIELD_PAD_X, Palette.FIELD_PAD_Y, Palette.FIELD_PAD_X, Palette.FIELD_PAD_Y)
	_styles("LineEdit", {
		"normal": _box("line_edit_normal", Palette.INSET, Palette.INSET_BORDER, Palette.BORDER, margins),
		"focus": _box("line_edit_focus", Palette.INSET, Palette.ACCENT, Palette.BORDER, margins),
		"read_only": _box("line_edit_read_only", Palette.BUTTON_DISABLED, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, margins),
	})
	_colors("LineEdit", {
		"font_color": Palette.TEXT, "font_selected_color": Palette.TEXT_BRIGHT,
		"font_uneditable_color": Palette.TEXT_DISABLED, "font_placeholder_color": Palette.TEXT_DISABLED,
		"caret_color": Palette.ACCENT_BRIGHT, "selection_color": Palette.ACCENT_DARK,
		"font_outline_color": Palette.TEXT_OUTLINE,
	})
	_constants("LineEdit", {"caret_width": Palette.CARET_WIDTH, "minimum_character_width": Palette.FIELD_MIN_CHARACTERS})


## Sliders: a sunken track, an accent fill up to the knob, a knob icon.
func _sliders() -> void:
	var margins := _even(Palette.SLIDER_PAD)
	var track := _box("slider_track", Palette.INSET, Palette.INSET_BORDER, Palette.BORDER, margins)
	var fill := _box("slider_fill", Palette.ACCENT_DARK, Palette.INSET_BORDER, Palette.BORDER, margins)
	var fill_lit := _box("slider_fill_highlight", Palette.ACCENT, Palette.INSET_BORDER, Palette.BORDER, margins)
	for type in ["HSlider", "VSlider"]:
		_styles(type, {"slider": track, "grabber_area": fill, "grabber_area_highlight": fill_lit})
		_icons(type, {
			"grabber": "slider_grabber", "grabber_highlight": "slider_grabber_highlight",
			"grabber_disabled": "slider_grabber_disabled",
		})
		_constants(type, {"center_grabber": 0, "grabber_offset": 0})


func _progress_bar() -> void:
	_styles("ProgressBar", {
		"background": _box("progress_background", Palette.INSET, Palette.INSET_BORDER, Palette.BORDER, _even(Palette.PROGRESS_PAD)),
		"fill": _box("progress_fill", Palette.ACCENT_DARK, Color.TRANSPARENT, 0, _even(Palette.PROGRESS_PAD)),
	})
	_colors("ProgressBar", {"font_color": Palette.TEXT_BRIGHT, "font_outline_color": Palette.TEXT_OUTLINE})


## Tabs: the selected tab is joined to its page and outlined in the accent
## (its bottom edge covers the page's top border); the others are dark.
func _tabs() -> void:
	var margins := Vector4(Palette.TAB_PAD_X, Palette.TAB_PAD_Y, Palette.TAB_PAD_X, Palette.TAB_PAD_Y)
	var selected := _box("tab_selected", Palette.PANEL_RAISED, Palette.ACCENT, Palette.BORDER, margins)
	selected.border_width_bottom = 0
	selected.expand_margin_bottom = Palette.BORDER
	var unselected := _box("tab_unselected", Palette.INSET, Palette.INSET_BORDER, Palette.BORDER, margins)
	unselected.border_width_bottom = 0
	var hovered := _box("tab_hovered", Palette.BUTTON, Palette.BUTTON_BORDER, Palette.BORDER, margins)
	hovered.border_width_bottom = 0
	var disabled := _box("tab_disabled", Palette.BUTTON_DISABLED, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, margins)
	disabled.border_width_bottom = 0
	var page := _box("tab_page", Palette.PANEL_RAISED, Palette.PANEL_BORDER, Palette.BORDER, _even(Palette.TAB_PAGE_PAD))
	for type in ["TabContainer", "TabBar"]:
		_styles(type, {
			"tab_selected": selected, "tab_unselected": unselected, "tab_hovered": hovered,
			"tab_disabled": disabled,
			"tab_focus": _ring("%s_tab_focus" % type.to_snake_case(), Palette.ACCENT, margins),
		})
		_colors(type, {
			"font_selected_color": Palette.TEXT_BRIGHT, "font_unselected_color": Palette.TEXT_DIM,
			"font_hovered_color": Palette.TEXT, "font_disabled_color": Palette.TEXT_DISABLED,
			"font_outline_color": Palette.TEXT_OUTLINE,
		})
		_constants(type, {"h_separation": Palette.TAB_GAP, "outline_size": Palette.TEXT_OUTLINE_SIZE})
		_icons(type, {
			"decrement": "arrow_left", "decrement_highlight": "arrow_left_highlight",
			"increment": "arrow_right", "increment_highlight": "arrow_right_highlight",
		})
	_styles("TabContainer", {"panel": page})
	_constants("TabContainer", {"side_margin": 0})


## Scroll bars have no arrow buttons: a sunken track with a light bar in it.
func _scroll_bars() -> void:
	for type in ["HScrollBar", "VScrollBar"]:
		var prefix: String = type.to_snake_case()
		var track := _even(Palette.SCROLL_PAD)
		var bar := _even(Palette.SCROLL_GRABBER_PAD)
		_styles(type, {
			"scroll": _box("%s_track" % prefix, Palette.INSET, Palette.INSET_BORDER, Palette.BORDER, track),
			"scroll_focus": _box("%s_track_focus" % prefix, Palette.INSET, Palette.ACCENT, Palette.BORDER, track),
			"grabber": _box("%s_grabber" % prefix, Palette.TEXT_DIM, Color.TRANSPARENT, 0, bar),
			"grabber_highlight": _box("%s_grabber_highlight" % prefix, Palette.HANDLE, Color.TRANSPARENT, 0, bar),
			"grabber_pressed": _box("%s_grabber_pressed" % prefix, Palette.ACCENT, Color.TRANSPARENT, 0, bar),
		})


func _separators() -> void:
	_styles("HSeparator", {"separator": _line("h_separator", false)})
	_constants("HSeparator", {"separation": Palette.SEPARATOR_SPACE})
	_styles("VSeparator", {"separator": _line("v_separator", true)})
	_constants("VSeparator", {"separation": Palette.SEPARATOR_SPACE})


## The drop-down list of an option button, and any other popup menu.
func _popup_menu() -> void:
	_styles("PopupMenu", {
		"panel": _box("popup_menu_panel", Palette.PANEL_OPAQUE, Palette.PANEL_BORDER, Palette.BORDER, _even(Palette.POPUP_PAD)),
		"hover": _box("popup_menu_hover", Palette.ACCENT_DARK, Color.TRANSPARENT, 0),
		"separator": _line("popup_menu_separator", false),
		"labeled_separator_left": _line("popup_menu_separator_left", false),
		"labeled_separator_right": _line("popup_menu_separator_right", false),
	})
	_colors("PopupMenu", {
		"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT_BRIGHT,
		"font_disabled_color": Palette.TEXT_DISABLED, "font_accelerator_color": Palette.TEXT_DIM,
		"font_separator_color": Palette.TEXT_DIM, "font_outline_color": Palette.TEXT_OUTLINE,
	})
	_constants("PopupMenu", {
		"h_separation": Palette.POPUP_ICON_GAP, "v_separation": Palette.POPUP_ENTRY_GAP,
		"item_start_padding": Palette.POPUP_ITEM_PAD, "item_end_padding": Palette.POPUP_ITEM_PAD,
		"outline_size": Palette.TEXT_OUTLINE_SIZE,
	})
	_icons("PopupMenu", {
		"unchecked": "checkbox_off", "checked": "checkbox_on",
		"unchecked_disabled": "checkbox_off_disabled", "checked_disabled": "checkbox_on_disabled",
		# Entries chosen from a list (an option button's drop-down) get an arrow, the others nothing.
		"radio_unchecked": "popup_marker_off", "radio_checked": "popup_marker_on",
		"radio_unchecked_disabled": "popup_marker_off", "radio_checked_disabled": "popup_marker_off",
		"submenu": "arrow_right", "submenu_mirrored": "arrow_left",
	})


## Tooltips: Godot builds them from the types "TooltipPanel" and "TooltipLabel".
func _tooltip() -> void:
	_variation("TooltipPanel", "PopupPanel")
	var margins := Vector4(Palette.TOOLTIP_PAD_X, Palette.TOOLTIP_PAD_Y, Palette.TOOLTIP_PAD_X, Palette.TOOLTIP_PAD_Y)
	_styles("TooltipPanel", {"panel": _box("tooltip_panel", Palette.TOOLTIP, Palette.PANEL_BORDER, Palette.BORDER, margins)})
	_variation("TooltipLabel", "Label")
	_colors("TooltipLabel", {"font_color": Palette.TEXT})


func _rich_text() -> void:
	_colors("RichTextLabel", {
		"default_color": Palette.TEXT, "font_selected_color": Palette.TEXT_BRIGHT,
		"selection_color": Palette.ACCENT_DARK, "font_outline_color": Palette.TEXT_OUTLINE,
	})


## The icon slots ([UiIcons]): every slot whose PNG exists in assets/ui/icons/
## goes into the theme type "Icons"; the others stay empty, and the screens show
## text instead.
func _icon_slots() -> void:
	var filled: Array[String] = []
	for slot in UiIcons.all_slots():
		var path := UiIcons.path_for(slot)
		if ResourceLoader.exists(path):
			_theme.set_icon(slot, UiIcons.THEME_TYPE, load(path))
			filled.append(String(slot))
	print("icon slots filled: %d of %d %s" % [filled.size(), UiIcons.all_slots().size(), filled])


# Helpers: build styleboxes, and fill a theme type with items.

## A square, crisp box: [param fill], an optional border and content margins
## ([param margins]: left, top, right, bottom; negative = use the border's width).
## [param id] names it in the saved file.
func _box(id: String, fill: Color, border_color: Color = Color.TRANSPARENT, border: int = 0,
		margins: Vector4 = BORDER_MARGINS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.resource_scene_unique_id = id
	box.bg_color = fill
	box.set_border_width_all(border)
	box.border_color = border_color
	box.anti_aliasing = false
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box


## Only a frame, no fill: the keyboard focus ring drawn over a control.
func _ring(id: String, color: Color, margins: Vector4) -> StyleBoxFlat:
	var ring := _box(id, Color.TRANSPARENT, color, Palette.BORDER, margins)
	ring.draw_center = false
	return ring


## Nothing is drawn, but the content keeps its margins.
func _empty(id: String, margins: Vector4) -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	empty.resource_scene_unique_id = id
	empty.content_margin_left = margins.x
	empty.content_margin_top = margins.y
	empty.content_margin_right = margins.z
	empty.content_margin_bottom = margins.w
	return empty


## A thin line: a separator.
func _line(id: String, vertical: bool) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.resource_scene_unique_id = id
	line.color = Palette.PANEL_BORDER
	line.thickness = Palette.LINE
	line.vertical = vertical
	return line


## The same [param pad] on all four sides.
func _even(pad: int) -> Vector4:
	return Vector4(pad, pad, pad, pad)


## A margin container's four margins: [param x] left and right, [param y] top and bottom.
func _margins(type: String, x: int, y: int) -> void:
	_constants(type, {"margin_left": x, "margin_top": y, "margin_right": x, "margin_bottom": y})


func _variation(type: String, base_type: String) -> void:
	_theme.set_type_variation(type, base_type)


func _styles(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_stylebox(item_name, type, items[item_name])


func _colors(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_color(item_name, type, items[item_name])


func _constants(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_constant(item_name, type, items[item_name])


func _font_sizes(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_font_size(item_name, type, items[item_name])


func _fonts(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_font(item_name, type, items[item_name])


## [param items] maps an icon name to the PNG's name in assets/ui/.
func _icons(type: String, items: Dictionary) -> void:
	for item_name: String in items:
		_theme.set_icon(item_name, type, load("%s%s.png" % [ICON_FOLDER, items[item_name]]))
