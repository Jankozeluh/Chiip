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
## "friendly" / "enemy" are the 3D world's team colours from [Teams]; the UI's
## own team colours (D-134) are "friendly_text" / "enemy_text" and their fills.
## Colors that no control can hold as a theme item (a table row is dimmed by
## multiplying it, "dead_row") are named here too.
func _palette() -> void:
	_colors("Palette", {
		"accent": Palette.ACCENT, "accent_bright": Palette.ACCENT_BRIGHT, "accent_dark": Palette.SELECTION,
		"text": Palette.TEXT, "text_bright": Palette.TEXT_BRIGHT, "text_dim": Palette.TEXT_DIM,
		"text_disabled": Palette.TEXT_DISABLED, "text_on_fill": Palette.TEXT_ON_FILL,
		"panel": Palette.PANEL, "panel_border": Palette.PANEL_BORDER, "inset": Palette.INSET,
		"void": Palette.VOID, "ink": Palette.INK, "raised": Palette.PANEL_RAISED, "line": Palette.LINE_COLOR,
		"mute": Palette.MUTE, "alert": Palette.ALERT, "plate": Palette.PLATE, "shadow": Palette.SHADOW,
		"friendly": Teams.FRIENDLY_COLOR, "enemy": Teams.ENEMY_COLOR,
		"friendly_text": Palette.FRIENDLY, "enemy_text": Palette.ENEMY,
		"friendly_fill": Palette.FRIENDLY_FILL, "enemy_fill": Palette.ENEMY_FILL,
		# What a dead player's row is multiplied by (a row's modulate is not a theme item).
		"dead_row": Palette.DEAD_ROW,
	})


func _labels() -> void:
	_colors("Label", {"font_color": Palette.TEXT, "font_outline_color": Palette.TEXT_OUTLINE, "font_shadow_color": Palette.SHADOW})
	var bold: Font = load(Palette.FONT_BOLD)
	# Recurring roles. A variation only lists what differs from "Label".
	# Screen titles: 48 px Bold ("SETTINGS", "PAUSED", "PLAY").
	_variation("TitleLabel", "Label")
	_font_sizes("TitleLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_fonts("TitleLabel", {"font": bold})
	_colors("TitleLabel", {"font_color": Palette.TEXT})
	# Big numbers (48 px, regular).
	_variation("ScoreLabel", "Label")
	_font_sizes("ScoreLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("ScoreLabel", {"font_color": Palette.TEXT})
	# A section header in the accent (a perk's name).
	_variation("HeaderLabel", "Label")
	_colors("HeaderLabel", {"font_color": Palette.ACCENT})
	_variation("DimLabel", "Label")
	_colors("DimLabel", {"font_color": Palette.TEXT_DIM})
	# Hints and column titles (MUTE).
	_variation("MuteLabel", "Label")
	_colors("MuteLabel", {"font_color": Palette.MUTE})
	_variation("BrightLabel", "Label")
	_colors("BrightLabel", {"font_color": Palette.TEXT})
	# 32 px text: a card's or a section's name.
	_variation("LargeLabel", "Label")
	_font_sizes("LargeLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	# The biggest text, 96 px Bold: the game's name, the match result, a map's name.
	_variation("HeroLabel", "Label")
	_font_sizes("HeroLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_fonts("HeroLabel", {"font": bold})
	_colors("HeroLabel", {"font_color": Palette.TEXT})
	# The Play screen's mode cards: the mode's name (32 px) and its lines (dim).
	_variation("ModeTitleLabel", "Label")
	_font_sizes("ModeTitleLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("ModeTitleLabel", {"font_color": Palette.TEXT})
	_constants("ModeTitleLabel", {"line_spacing": Palette.LARGE_LINE_SPACING})
	_variation("ModeDetailLabel", "Label")
	_colors("ModeDetailLabel", {"font_color": Palette.TEXT_DIM})
	# Text in the UI's team colours (D-134). Colours are relative to the viewer, so
	# "your" team is always the friendly one.
	_variation("FriendlyLabel", "Label")
	_colors("FriendlyLabel", {"font_color": Palette.FRIENDLY})
	_variation("EnemyLabel", "Label")
	_colors("EnemyLabel", {"font_color": Palette.ENEMY})
	_variation("FriendlyScoreLabel", "Label")
	_font_sizes("FriendlyScoreLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("FriendlyScoreLabel", {"font_color": Palette.FRIENDLY})
	_variation("EnemyScoreLabel", "Label")
	_font_sizes("EnemyScoreLabel", {"font_size": Palette.TEXT_SIZE_TITLE})
	_colors("EnemyScoreLabel", {"font_color": Palette.ENEMY})
	# The match result: "VICTORY" in your colour, "DEFEAT" in the enemy's, 96 px Bold.
	_variation("VictoryLabel", "Label")
	_font_sizes("VictoryLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_fonts("VictoryLabel", {"font": bold})
	_colors("VictoryLabel", {"font_color": Palette.FRIENDLY})
	_variation("DefeatLabel", "Label")
	_font_sizes("DefeatLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_fonts("DefeatLabel", {"font": bold})
	_colors("DefeatLabel", {"font_color": Palette.ENEMY})
	# A key cap: the key's name in a 2 px TEXT frame on ink ("ESC", "E", "TAB").
	_variation("KeyCapLabel", "Label")
	var margins := Vector4(Palette.KEY_CAP_PAD_X, Palette.KEY_CAP_PAD_TOP, Palette.KEY_CAP_PAD_X, Palette.KEY_CAP_PAD_BOTTOM)
	_styles("KeyCapLabel", {"normal": _box("key_cap", Palette.INK, Palette.TEXT, Palette.BORDER, margins)})
	# A dim key cap (the Play screen's "ESC": a DIM frame).
	_variation("DimKeyCapLabel", "Label")
	_styles("DimKeyCapLabel", {"normal": _box("dim_key_cap", Color.TRANSPARENT, Palette.TEXT_DIM, Palette.BORDER, margins)})
	_colors("DimKeyCapLabel", {"font_color": Palette.TEXT_DIM})
	# The game's name on the main menu: 96 px Bold with the mockup's letter spacing.
	var logo := FontVariation.new()
	logo.resource_scene_unique_id = "logo_font"
	logo.base_font = bold
	logo.spacing_glyph = Palette.HERO_LETTER_SPACING
	_variation("LogoLabel", "Label")
	_font_sizes("LogoLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_fonts("LogoLabel", {"font": logo})
	# Text over the game world with a hard shadow (the main menu's map name).
	_variation("ShadowLabel", "Label")
	_constants("ShadowLabel", {"shadow_offset_x": Palette.SHADOW_OFFSET, "shadow_offset_y": Palette.SHADOW_OFFSET, "shadow_outline_size": 0})
	# A tag on the accent ("DEFAULT").
	_variation("TagLabel", "Label")
	var tag := Vector4(Palette.TAG_PAD_X, Palette.TAG_PAD_Y, Palette.TAG_PAD_X, Palette.TAG_PAD_Y)
	_styles("TagLabel", {"normal": _box("tag", Palette.ACCENT, Color.TRANSPARENT, 0, tag)})
	_colors("TagLabel", {"font_color": Palette.TEXT_ON_FILL})


func _panels() -> void:
	var panel := _box("panel", Palette.PANEL)
	_styles("Panel", {"panel": panel})
	# The dimming behind a modal menu: a full-screen Panel that keeps the clicks from the game.
	_variation("BackdropPanel", "Panel")
	_styles("BackdropPanel", {"panel": _box("backdrop_panel", Palette.BACKDROP)})
	# A full-screen menu's ink background (settings, the Play screen, the match end).
	_variation("InkPanel", "Panel")
	_styles("InkPanel", {"panel": _box("ink_panel", Palette.INK)})
	# The main menu's dark column on the left (ink, 92%).
	_variation("SidePanel", "Panel")
	_styles("SidePanel", {"panel": _box("side_panel", Palette.SIDE_PANEL)})
	_styles("PanelContainer", {"panel": panel})
	_styles("PopupPanel", {"panel": _box("popup_panel", Palette.PANEL_OPAQUE, Palette.LINE_COLOR, Palette.BORDER)})
	# A screen that wants your attention (no frame in this design: flat panel).
	_variation("ModalPanel", "PanelContainer")
	_styles("ModalPanel", {"panel": _box("modal_panel", Palette.PANEL)})
	# Over the live game: the Tab scoreboard (ink, 88%).
	_variation("OverlayPanel", "PanelContainer")
	_styles("OverlayPanel", {"panel": _box("overlay_panel", Palette.PANEL_OVERLAY)})
	# The developer console, a void strip under the top edge of the screen with a line under it.
	_variation("ConsolePanel", "PanelContainer")
	var console := _box("console_panel", Palette.CONSOLE, Palette.LINE_COLOR)
	console.border_width_bottom = Palette.BORDER
	_styles("ConsolePanel", {"panel": console})
	# A sunken area: a value box, a preview.
	_variation("InsetPanel", "PanelContainer")
	_styles("InsetPanel", {"panel": _box("inset_panel", Palette.INSET, Palette.LINE_COLOR, Palette.BORDER)})
	# A raised area (a class card's picture).
	_variation("RaisedPanel", "PanelContainer")
	_styles("RaisedPanel", {"panel": _box("raised_panel", Palette.PANEL_RAISED)})
	# A plate on the game (ink, 72%): kill-feed lines, toasts.
	_variation("PlatePanel", "PanelContainer")
	_styles("PlatePanel", {"panel": _box("plate_panel", Palette.PLATE)})
	# Table rows: nothing behind a row; your own row raised and framed in the accent.
	_variation("RowPanel", "PanelContainer")
	_styles("RowPanel", {"panel": _empty("row_panel", BORDER_MARGINS)})
	_variation("YouRowPanel", "PanelContainer")
	_styles("YouRowPanel", {"panel": _box("you_row_panel", Palette.YOU_ROW, Palette.ACCENT, Palette.BORDER)})
	# The line under a team's column titles: 2 px in the UI's team colour.
	_variation("TeamHeaderFriendly", "PanelContainer")
	_styles("TeamHeaderFriendly", {"panel": _underline("team_header_friendly", Palette.FRIENDLY)})
	_variation("TeamHeaderEnemy", "PanelContainer")
	_styles("TeamHeaderEnemy", {"panel": _underline("team_header_enemy", Palette.ENEMY)})
	# The chips (Foundations: "one square pixel is the whole brand"): flat squares in a team colour or the accent.
	_variation("FriendlyChip", "Panel")
	_styles("FriendlyChip", {"panel": _box("friendly_chip", Palette.FRIENDLY)})
	_variation("EnemyChip", "Panel")
	_styles("EnemyChip", {"panel": _box("enemy_chip", Palette.ENEMY)})
	_variation("AccentChip", "Panel")
	_styles("AccentChip", {"panel": _box("accent_chip", Palette.ACCENT)})
	# A segmented choice's frame: 2 px LINE around the choices, nothing inside.
	_variation("SegmentFrame", "PanelContainer")
	_styles("SegmentFrame", {"panel": _box("segment_frame", Color.TRANSPARENT, Palette.LINE_COLOR, Palette.BORDER)})


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
	# The choices of a segmented choice, side by side in one frame.
	_variation("SegmentRow", "HBoxContainer")
	_constants("SegmentRow", {"separation": Palette.SEGMENT_GAP})
	# A list of menu items, the lines inside a card, the Play screen's cards.
	_variation("ModeList", "VBoxContainer")
	_constants("ModeList", {"separation": Palette.MODE_GAP})
	_variation("ModeMargin", "MarginContainer")
	_margins("ModeMargin", Palette.MODE_BUTTON_PAD_X, Palette.MODE_BUTTON_PAD_Y)
	_variation("ModeText", "VBoxContainer")
	_constants("ModeText", {"separation": Palette.MODE_LINE_GAP})
	_variation("CardRow", "HBoxContainer")
	_constants("CardRow", {"separation": Palette.CARD_GAP})
	# A full-screen page's column of sections, and a row's parts.
	_variation("PageColumn", "VBoxContainer")
	_constants("PageColumn", {"separation": Palette.PAGE_GAP})
	_variation("RowBox", "HBoxContainer")
	_constants("RowBox", {"separation": Palette.ROW_GAP})
	# The Play screen's custom rows: two columns.
	_variation("FormGrid", "GridContainer")
	_constants("FormGrid", {"h_separation": Palette.FORM_GRID_H, "v_separation": Palette.FORM_GRID_V})
	# The main menu's line between its items and Host / Join (16 in from the sides, 12 above and below), and the line itself.
	_variation("DividerMargin", "MarginContainer")
	_margins("DividerMargin", Palette.DIVIDER_MARGIN_X, Palette.DIVIDER_MARGIN_Y)
	_variation("LineSeparator", "HSeparator")
	_constants("LineSeparator", {"separation": Palette.LINE})
	# The brand chips under the game's name, and a team's size chips.
	_variation("ChipRow", "HBoxContainer")
	_constants("ChipRow", {"separation": Palette.CHIP_GAP})
	_variation("TeamChipRow", "HBoxContainer")
	_constants("TeamChipRow", {"separation": Palette.TEAM_CHIP_GAP})
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
	# Buttons (Foundations: BUTTON): outlined, 40 high. Rest: a 2 px MUTE frame and TEXT;
	# hover and focus: the frame and the text in the accent; held down: filled with the
	# accent; disabled: a LINE frame and MUTE text.
	var pads := Vector4(Palette.BUTTON_PAD_X, Palette.BUTTON_PAD_TOP, Palette.BUTTON_PAD_X, Palette.BUTTON_PAD_BOTTOM)
	_outlined_button_styles("Button", pads)
	_colors("Button", {
		"font_color": Palette.TEXT, "font_hover_color": Palette.ACCENT,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
		"font_focus_color": Palette.ACCENT, "font_disabled_color": Palette.TEXT_DISABLED,
		"font_outline_color": Palette.TEXT_OUTLINE,
		"icon_normal_color": Palette.TEXT, "icon_hover_color": Palette.ACCENT, "icon_focus_color": Palette.ACCENT,
		"icon_pressed_color": Palette.TEXT_ON_FILL, "icon_hover_pressed_color": Palette.TEXT_ON_FILL,
		"icon_disabled_color": Palette.TEXT_DISABLED,
	})
	_constants("Button", {"h_separation": Palette.BUTTON_ICON_GAP})
	# Menu items (Foundations: MENU ITEM): 48 high, 32 px, no box at rest; hover and focus
	# fill it with the accent, the text turns ink and the chip (the button's icon) appears.
	var item := Vector4(Palette.BIG_BUTTON_PAD_X, Palette.BIG_BUTTON_PAD_TOP, Palette.BIG_BUTTON_PAD_X, Palette.BIG_BUTTON_PAD_BOTTOM)
	_menu_item_styles("BigButton", item)
	_font_sizes("BigButton", {"font_size": Palette.TEXT_SIZE_LARGE})
	# Host and Join: a small, disabled-looking menu item (40 high, 16 px).
	var small := Vector4(Palette.SMALL_ITEM_PAD_X, Palette.BUTTON_PAD_TOP, Palette.SMALL_ITEM_PAD_X, Palette.BUTTON_PAD_BOTTOM)
	_menu_item_styles("SmallItemButton", small)
	# The main button of a screen (Play, Start, Resume, Play again): filled with the accent,
	# ink text, a hard shadow; hover lights it up.
	_variation("PrimaryButton", "Button")
	_styles("PrimaryButton", {
		"normal": _shadowed("primary_button_normal", Palette.ACCENT, pads),
		"hover": _shadowed("primary_button_hover", Palette.ACCENT_BRIGHT, pads),
		"pressed": _shadowed("primary_button_pressed", Palette.ACCENT, pads),
		"hover_pressed": _shadowed("primary_button_hover_pressed", Palette.ACCENT_BRIGHT, pads),
		"disabled": _box("primary_button_disabled", Color.TRANSPARENT, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, pads),
		"focus": _ring("primary_button_focus", Palette.TEXT, pads),
	})
	_colors("PrimaryButton", {
		"font_color": Palette.TEXT_ON_FILL, "font_hover_color": Palette.TEXT_ON_FILL, "font_focus_color": Palette.TEXT_ON_FILL,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
		"icon_normal_color": Palette.TEXT_ON_FILL, "icon_hover_color": Palette.TEXT_ON_FILL, "icon_focus_color": Palette.TEXT_ON_FILL,
		"icon_pressed_color": Palette.TEXT_ON_FILL, "icon_hover_pressed_color": Palette.TEXT_ON_FILL,
	})
	# A big primary button (the Play screen's PLAY: 56 high, 32 px).
	_variation("BigPrimaryButton", "PrimaryButton")
	_font_sizes("BigPrimaryButton", {"font_size": Palette.TEXT_SIZE_LARGE})
	var big := Vector4(Palette.BIG_PRIMARY_PAD_X, Palette.BIG_PRIMARY_PAD_TOP, Palette.BIG_PRIMARY_PAD_X, Palette.BIG_PRIMARY_PAD_BOTTOM)
	_styles("BigPrimaryButton", {
		"normal": _shadowed("big_primary_button_normal", Palette.ACCENT, big),
		"hover": _shadowed("big_primary_button_hover", Palette.ACCENT_BRIGHT, big),
		"pressed": _shadowed("big_primary_button_pressed", Palette.ACCENT, big),
		"hover_pressed": _shadowed("big_primary_button_hover_pressed", Palette.ACCENT_BRIGHT, big),
		"focus": _ring("big_primary_button_focus", Palette.TEXT, big),
	})
	# The team-size chips of the Play screen (Foundations: TEAM SIZE): a square per player,
	# filled in the team's colour up to the team's size, framed in LINE after it.
	for chip in [["FriendlyChipButton", Palette.FRIENDLY], ["EnemyChipButton", Palette.ENEMY], ["EmptyChipButton", Color.TRANSPARENT]]:
		var role: String = chip[0]
		var fill: Color = chip[1]
		var frame: Color = Palette.LINE_COLOR if fill == Color.TRANSPARENT else fill
		var lit: Color = Palette.TEXT_DIM if fill == Color.TRANSPARENT else fill.lightened(Palette.CHIP_HOVER_LIGHTEN)
		var prefix := role.to_snake_case()
		var rest := _box("%s_rest" % prefix, fill, frame, Palette.BORDER, _even(0))
		var hover := _box("%s_hover" % prefix, fill if fill == Color.TRANSPARENT else lit, lit, Palette.BORDER, _even(0))
		_variation(role, "Button")
		_styles(role, {
			"normal": rest, "pressed": rest, "disabled": rest, "hover": hover, "hover_pressed": hover,
			"focus": _ring("%s_focus" % prefix, Palette.ACCENT, _even(0)),
		})
	# A mode card of the Play screen: a panel that the accent frames on hover and focus (and when chosen).
	_variation("ModeButton", "Button")
	var card := _even(0)
	_styles("ModeButton", {
		"normal": _box("mode_button_normal", Palette.PANEL_OPAQUE, Palette.PANEL_OPAQUE, Palette.BORDER, card),
		"hover": _box("mode_button_hover", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
		"pressed": _box("mode_button_pressed", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
		"hover_pressed": _box("mode_button_hover_pressed", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
		"disabled": _box("mode_button_disabled", Palette.PANEL_OPAQUE, Palette.PANEL_OPAQUE, Palette.BORDER, card),
		"focus": _ring("mode_button_focus", Palette.ACCENT, card),
	})
	# The picked mode card: framed in the accent at rest too ("click to play").
	_variation("ModeButtonPicked", "ModeButton")
	_styles("ModeButtonPicked", {
		"normal": _box("mode_button_picked", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
		"disabled": _box("mode_button_picked_disabled", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
	})
	# A segment of a segmented choice (Foundations: SEGMENTS): DIM text with nothing behind;
	# the chosen one (a pressed toggle) filled with TEXT, ink text; the focus underlined in the accent.
	_variation("SegmentButton", "Button")
	var segment := Vector4(Palette.SEGMENT_PAD_X, Palette.SEGMENT_PAD_TOP, Palette.SEGMENT_PAD_X, Palette.SEGMENT_PAD_BOTTOM)
	var focus := _box("segment_button_focus", Color.TRANSPARENT, Palette.ACCENT, 0, segment)
	focus.draw_center = false
	focus.border_width_bottom = Palette.BORDER
	_styles("SegmentButton", {
		"normal": _empty("segment_button_normal", segment),
		"hover": _empty("segment_button_hover", segment),
		"pressed": _box("segment_button_pressed", Palette.TEXT, Color.TRANSPARENT, 0, segment),
		"hover_pressed": _box("segment_button_hover_pressed", Palette.TEXT, Color.TRANSPARENT, 0, segment),
		"disabled": _empty("segment_button_disabled", segment),
		"focus": focus,
	})
	_colors("SegmentButton", {
		"font_color": Palette.TEXT_DIM, "font_hover_color": Palette.TEXT, "font_focus_color": Palette.TEXT,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
		"font_disabled_color": Palette.TEXT_DISABLED,
	})
	# A word to click, without a box (a link).
	_variation("TextButton", "Button")
	var text_pads := Vector4(Palette.TEXT_BUTTON_PAD_X, Palette.TEXT_BUTTON_PAD_Y, Palette.TEXT_BUTTON_PAD_X, Palette.TEXT_BUTTON_PAD_Y)
	_styles("TextButton", {
		"normal": _empty("text_button_normal", text_pads), "hover": _empty("text_button_hover", text_pads),
		"pressed": _empty("text_button_pressed", text_pads), "hover_pressed": _empty("text_button_hover_pressed", text_pads),
		"disabled": _empty("text_button_disabled", text_pads),
		"focus": _ring("text_button_focus", Palette.ACCENT, text_pads),
	})
	_colors("TextButton", {"font_color": Palette.TEXT_DIM, "font_pressed_color": Palette.ACCENT, "font_hover_pressed_color": Palette.ACCENT})
	# Option buttons and menu buttons share the button look; the arrow is an icon.
	_icons("OptionButton", {"arrow": "arrow_down"})
	_constants("OptionButton", {"arrow_margin": Palette.ARROW_GAP, "h_separation": Palette.BUTTON_ICON_GAP})


## The five looks of an outlined button: a 2 px frame (MUTE at rest, the accent
## when hovered, focused or held down, LINE when disabled), filled only while held.
func _outlined_button_styles(type: String, margins: Vector4) -> void:
	var prefix := type.to_snake_case()
	_styles(type, {
		"normal": _box("%s_normal" % prefix, Palette.BUTTON, Palette.BUTTON_BORDER, Palette.BORDER, margins),
		"hover": _box("%s_hover" % prefix, Palette.BUTTON, Palette.ACCENT, Palette.BORDER, margins),
		"pressed": _box("%s_pressed" % prefix, Palette.BUTTON_PRESSED, Palette.BUTTON_PRESSED, Palette.BORDER, margins),
		"hover_pressed": _box("%s_hover_pressed" % prefix, Palette.BUTTON_PRESSED, Palette.BUTTON_PRESSED, Palette.BORDER, margins),
		"disabled": _box("%s_disabled" % prefix, Palette.BUTTON, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, margins),
		# Drawn on top of the current look while the control has the keyboard focus.
		"focus": _ring("%s_focus" % prefix, Palette.ACCENT, margins),
	})


## A menu item: nothing at rest, filled with the accent on hover, focus and
## press (the focus fill is drawn under the text, so a focused item looks
## hovered); the chip icon is only visible then (its colour is see-through at rest).
func _menu_item_styles(type: String, margins: Vector4) -> void:
	_variation(type, "Button")
	var prefix := type.to_snake_case()
	var lit := _box("%s_lit" % prefix, Palette.ACCENT, Color.TRANSPARENT, 0, margins)
	_styles(type, {
		"normal": _empty("%s_normal" % prefix, margins), "disabled": _empty("%s_disabled" % prefix, margins),
		"hover": lit, "pressed": lit, "hover_pressed": lit, "focus": lit,
	})
	_colors(type, {
		"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT_ON_FILL, "font_focus_color": Palette.TEXT_ON_FILL,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
		"font_disabled_color": Palette.TEXT_DISABLED,
		"icon_normal_color": Color.TRANSPARENT, "icon_disabled_color": Color.TRANSPARENT,
		"icon_hover_color": Palette.TEXT_ON_FILL, "icon_focus_color": Palette.TEXT_ON_FILL,
		"icon_pressed_color": Palette.TEXT_ON_FILL, "icon_hover_pressed_color": Palette.TEXT_ON_FILL,
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
			"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT,
			"font_pressed_color": Palette.TEXT, "font_hover_pressed_color": Palette.TEXT,
			"font_focus_color": Palette.TEXT, "font_disabled_color": Palette.TEXT_DISABLED,
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


## Text fields and value boxes (Foundations: the "1.10" box): void, a 2 px LINE
## frame, the accent frame while typing.
func _line_edit() -> void:
	var margins := Vector4(Palette.FIELD_PAD_X, Palette.FIELD_PAD_TOP, Palette.FIELD_PAD_X, Palette.FIELD_PAD_BOTTOM)
	_styles("LineEdit", {
		"normal": _box("line_edit_normal", Palette.INSET, Palette.LINE_COLOR, Palette.BORDER, margins),
		"focus": _box("line_edit_focus", Palette.INSET, Palette.ACCENT, Palette.BORDER, margins),
		"read_only": _box("line_edit_read_only", Palette.INSET, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, margins),
	})
	_colors("LineEdit", {
		"font_color": Palette.TEXT, "font_selected_color": Palette.TEXT,
		"font_uneditable_color": Palette.TEXT_DISABLED, "font_placeholder_color": Palette.TEXT_DISABLED,
		"caret_color": Palette.ACCENT, "selection_color": Palette.SELECTION,
		"font_outline_color": Palette.TEXT_OUTLINE,
	})
	_constants("LineEdit", {"caret_width": Palette.CARET_WIDTH, "minimum_character_width": Palette.FIELD_MIN_CHARACTERS})


## Sliders (Foundations: SLIDER): a 4 px LINE track, filled with TEXT up to the
## knob (with the accent while hovered or focused), a 16 px square TEXT knob.
func _sliders() -> void:
	var margins := _even(Palette.SLIDER_PAD)
	var track := _box("slider_track", Palette.LINE_COLOR, Color.TRANSPARENT, 0, margins)
	var fill := _box("slider_fill", Palette.TEXT, Color.TRANSPARENT, 0, margins)
	var fill_lit := _box("slider_fill_highlight", Palette.ACCENT, Color.TRANSPARENT, 0, margins)
	for type in ["HSlider", "VSlider"]:
		_styles(type, {"slider": track, "grabber_area": fill, "grabber_area_highlight": fill_lit})
		_icons(type, {
			"grabber": "slider_grabber", "grabber_highlight": "slider_grabber_highlight",
			"grabber_disabled": "slider_grabber_disabled",
		})
		_constants(type, {"center_grabber": 0, "grabber_offset": 0})


## Progress bars (Foundations: PROGRESS): a LINE strip with a TEXT fill.
func _progress_bar() -> void:
	_styles("ProgressBar", {
		"background": _box("progress_background", Palette.LINE_COLOR, Color.TRANSPARENT, 0, _even(Palette.PROGRESS_PAD)),
		"fill": _box("progress_fill", Palette.TEXT, Color.TRANSPARENT, 0, _even(Palette.PROGRESS_PAD)),
	})
	_colors("ProgressBar", {"font_color": Palette.TEXT, "font_outline_color": Palette.TEXT_OUTLINE})


## Tabs (the settings mockup): text only, DIM, TEXT when hovered; the chosen tab
## TEXT with a 4 px accent underline that sits on the 2 px LINE under all tabs
## (the page's top edge).
func _tabs() -> void:
	var margins := Vector4(Palette.TAB_PAD_X, Palette.TAB_PAD_TOP, Palette.TAB_PAD_X, Palette.TAB_PAD_BOTTOM)
	var selected := _box("tab_selected", Color.TRANSPARENT, Palette.ACCENT, 0, margins)
	selected.border_width_bottom = Palette.TAB_UNDERLINE
	selected.expand_margin_bottom = Palette.BORDER
	var unselected := _empty("tab_unselected", margins)
	var hovered := _empty("tab_hovered", margins)
	var disabled := _empty("tab_disabled", margins)
	var page := _box("tab_page", Color.TRANSPARENT, Palette.LINE_COLOR, 0,
			Vector4(Palette.TAB_PAGE_PAD, Palette.TAB_PAGE_PAD_TOP, Palette.TAB_PAGE_PAD, Palette.TAB_PAGE_PAD))
	page.border_width_top = Palette.LINE
	for type in ["TabContainer", "TabBar"]:
		var focus := _box("%s_tab_focus" % type.to_snake_case(), Color.TRANSPARENT, Palette.ACCENT, 0, margins)
		focus.draw_center = false
		focus.border_width_bottom = Palette.TAB_UNDERLINE
		_styles(type, {
			"tab_selected": selected, "tab_unselected": unselected, "tab_hovered": hovered,
			"tab_disabled": disabled, "tab_focus": focus,
		})
		_colors(type, {
			"font_selected_color": Palette.TEXT, "font_unselected_color": Palette.TEXT_DIM,
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


## Scroll bars have no arrow buttons: a slim LINE bar in an empty track.
func _scroll_bars() -> void:
	for type in ["HScrollBar", "VScrollBar"]:
		var prefix: String = type.to_snake_case()
		var track := _even(Palette.SCROLL_PAD)
		var bar := _even(Palette.SCROLL_GRABBER_PAD)
		_styles(type, {
			"scroll": _empty("%s_track" % prefix, track),
			"scroll_focus": _empty("%s_track_focus" % prefix, track),
			"grabber": _box("%s_grabber" % prefix, Palette.LINE_COLOR, Color.TRANSPARENT, 0, bar),
			"grabber_highlight": _box("%s_grabber_highlight" % prefix, Palette.MUTE, Color.TRANSPARENT, 0, bar),
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
		"panel": _box("popup_menu_panel", Palette.PANEL_OPAQUE, Palette.LINE_COLOR, Palette.BORDER, _even(Palette.POPUP_PAD)),
		"hover": _box("popup_menu_hover", Palette.ACCENT, Color.TRANSPARENT, 0),
		"separator": _line("popup_menu_separator", false),
		"labeled_separator_left": _line("popup_menu_separator_left", false),
		"labeled_separator_right": _line("popup_menu_separator_right", false),
	})
	_colors("PopupMenu", {
		"font_color": Palette.TEXT, "font_hover_color": Palette.TEXT_ON_FILL,
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
	_styles("TooltipPanel", {"panel": _box("tooltip_panel", Palette.TOOLTIP, Palette.LINE_COLOR, Palette.BORDER, margins)})
	_variation("TooltipLabel", "Label")
	_colors("TooltipLabel", {"font_color": Palette.TEXT})


func _rich_text() -> void:
	_colors("RichTextLabel", {
		"default_color": Palette.TEXT, "font_selected_color": Palette.TEXT,
		"selection_color": Palette.SELECTION, "font_outline_color": Palette.TEXT_OUTLINE,
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


## A box with a hard shadow (Foundations: 2 px down-right in VOID): the box grows
## by the shadow on its right and bottom, and those two edges are drawn as a
## VOID border, so the fill covers exactly the control.
func _shadowed(id: String, fill: Color, margins: Vector4) -> StyleBoxFlat:
	var box := _box(id, fill, Palette.SHADOW, 0, margins)
	box.border_width_right = Palette.SHADOW_OFFSET
	box.border_width_bottom = Palette.SHADOW_OFFSET
	box.expand_margin_right = Palette.SHADOW_OFFSET
	box.expand_margin_bottom = Palette.SHADOW_OFFSET
	return box


## Nothing behind, a 2 px line in [param color] along the bottom edge.
func _underline(id: String, color: Color) -> StyleBoxFlat:
	var box := _box(id, Color.TRANSPARENT, color)
	box.border_width_bottom = Palette.LINE
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
	line.color = Palette.LINE_COLOR
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
