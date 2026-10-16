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
	_class_draft()
	_buy_menu()
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
## Colours that no control can hold as a theme item (an icon's tint, a team's colour in
## code) are named here too: a scoreboard row tints its class icon with "friendly_text",
## "enemy_text" or, for a dead player, "line".
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
		"compass_backing": Palette.COMPASS_BACKING,
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
	# Something went wrong or needs attention (ALERT): the lobby's connection errors.
	_variation("AlertLabel", "Label")
	_colors("AlertLabel", {"font_color": Palette.ALERT})
	# 32 px text: a card's or a section's name.
	_variation("LargeLabel", "Label")
	_font_sizes("LargeLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	# The biggest text, 96 px Bold: the game's name, the match result, a map's name.
	_variation("HeroLabel", "Label")
	_font_sizes("HeroLabel", {"font_size": Palette.TEXT_SIZE_HERO})
	_fonts("HeroLabel", {"font": bold})
	_colors("HeroLabel", {"font_color": Palette.TEXT})
	# 32 px text in ink: the number on a lit key chip (the class draft).
	_variation("LargeInkLabel", "Label")
	_font_sizes("LargeInkLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("LargeInkLabel", {"font_color": Palette.TEXT_ON_FILL})
	# A class's perk text: dim, with the draft's 24 px lines (the line box and a little space between lines).
	_variation("PerkLabel", "Label")
	_colors("PerkLabel", {"font_color": Palette.TEXT_DIM})
	_constants("PerkLabel", {"line_spacing": Palette.CLASS_PERK_LINE_SPACING})
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
	# The match-end screen's scores: 32 px in the team colours.
	_variation("FriendlyLargeLabel", "Label")
	_font_sizes("FriendlyLargeLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("FriendlyLargeLabel", {"font_color": Palette.FRIENDLY})
	_variation("EnemyLargeLabel", "Label")
	_font_sizes("EnemyLargeLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_colors("EnemyLargeLabel", {"font_color": Palette.ENEMY})
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
	# The studio's name on the boot screen: 32 px with the same letter spacing (v0.2 screen 30).
	var spaced := FontVariation.new()
	spaced.resource_scene_unique_id = "spaced_font"
	spaced.base_font = load(Palette.FONT)
	spaced.spacing_glyph = Palette.HERO_LETTER_SPACING
	_variation("SpacedLabel", "Label")
	_font_sizes("SpacedLabel", {"font_size": Palette.TEXT_SIZE_LARGE})
	_fonts("SpacedLabel", {"font": spaced})
	_colors("SpacedLabel", {"font_color": Palette.TEXT})
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
	# The boot screen's background: the deepest dark (VOID, opaque).
	_variation("VoidPanel", "Panel")
	_styles("VoidPanel", {"panel": _box("void_panel", Palette.VOID)})
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
	# The class draft's key chip: nothing behind the number, or (the focused card's) filled with the accent.
	_variation("KeyChip", "PanelContainer")
	_styles("KeyChip", {"panel": _empty("key_chip", _even(0))})
	_variation("KeyChipLit", "PanelContainer")
	_styles("KeyChipLit", {"panel": _box("key_chip_lit", Palette.ACCENT, Color.TRANSPARENT, 0, _even(0))})
	# A class card's footer: a 2 px LINE edge along its top and the space between that line and the gun's name.
	_variation("ClassFooterPanel", "PanelContainer")
	var class_footer := _box("class_footer_panel", Color.TRANSPARENT, Palette.LINE_COLOR)
	class_footer.border_width_top = Palette.LINE
	class_footer.content_margin_top = Palette.LINE + Palette.CLASS_FOOTER_PAD_TOP
	_styles("ClassFooterPanel", {"panel": class_footer})
	# A plate on the game (ink, 72%): kill-feed lines, toasts.
	_variation("PlatePanel", "PanelContainer")
	_styles("PlatePanel", {"panel": _box("plate_panel", Palette.PLATE)})
	# Table rows: nothing behind a row; your own row raised and framed in the accent.
	_variation("RowPanel", "PanelContainer")
	_styles("RowPanel", {"panel": _empty("row_panel", BORDER_MARGINS)})
	# (The frame is drawn inside the row and takes no room, so your row's columns line up with the others.)
	_variation("YouRowPanel", "PanelContainer")
	_styles("YouRowPanel", {"panel": _box("you_row_panel", Palette.YOU_ROW, Palette.ACCENT, Palette.BORDER, _even(0))})
	# A row of a table of settings (the Controls tab's keys): a 2 px PANEL line along its top.
	_variation("TableRowPanel", "PanelContainer")
	var table_row := _box("table_row_panel", Color.TRANSPARENT, Palette.PANEL_OPAQUE)
	table_row.border_width_top = Palette.LINE
	_styles("TableRowPanel", {"panel": table_row})
	# The line above a team's rows: 2 px in the UI's team colour (an empty panel, as high as the line). The
	# enemy's carries the space above it, 16 px on the Tab scoreboard and 12 on the match-end screen.
	_variation("TeamHeaderFriendly", "PanelContainer")
	_styles("TeamHeaderFriendly", {"panel": _underline("team_header_friendly", Palette.FRIENDLY)})
	_variation("TeamHeaderEnemy", "PanelContainer")
	_styles("TeamHeaderEnemy", {"panel": _underline("team_header_enemy", Palette.ENEMY, Palette.TEAM_LINE_GAP)})
	_variation("TeamHeaderEnemyTight", "PanelContainer")
	_styles("TeamHeaderEnemyTight", {"panel": _underline("team_header_enemy_tight", Palette.ENEMY, Palette.TEAM_LINE_GAP_TIGHT)})
	# The lobby's team header (the mockup's "YOUR TEAM 3 / 5"): a row of text with the 2 px team line under it, no space above.
	_variation("TeamTitleFriendly", "PanelContainer")
	_styles("TeamTitleFriendly", {"panel": _underline("team_title_friendly", Palette.FRIENDLY)})
	_variation("TeamTitleEnemy", "PanelContainer")
	_styles("TeamTitleEnemy", {"panel": _underline("team_title_enemy", Palette.ENEMY)})
	# A lobby slot nobody has taken: a 2 px LINE frame, nothing inside (the mockup's is dashed; a StyleBox has no dashes).
	_variation("EmptySlotPanel", "PanelContainer")
	_styles("EmptySlotPanel", {"panel": _box("empty_slot_panel", Color.TRANSPARENT, Palette.LINE_COLOR, Palette.BORDER)})
	# The lobby's footer: a 2 px LINE edge along its top, and the space between that line and its items.
	_variation("FooterPanel", "PanelContainer")
	var footer := _box("footer_panel", Color.TRANSPARENT, Palette.LINE_COLOR)
	footer.border_width_top = Palette.LINE
	footer.content_margin_top = Palette.LINE + Palette.LOBBY_FOOTER_PAD_TOP
	_styles("FooterPanel", {"panel": footer})
	# The chips (Foundations: "one square pixel is the whole brand"): flat squares in a team colour or the accent.
	_variation("FriendlyChip", "Panel")
	_styles("FriendlyChip", {"panel": _box("friendly_chip", Palette.FRIENDLY)})
	_variation("EnemyChip", "Panel")
	_styles("EnemyChip", {"panel": _box("enemy_chip", Palette.ENEMY)})
	_variation("AccentChip", "Panel")
	_styles("AccentChip", {"panel": _box("accent_chip", Palette.ACCENT)})
	# The loading screen's progress squares: done ones in the text colour, the current one AccentChip, the rest LINE.
	_variation("TextChip", "Panel")
	_styles("TextChip", {"panel": _box("text_chip", Palette.TEXT)})
	_variation("LineChip", "Panel")
	_styles("LineChip", {"panel": _box("line_chip", Palette.LINE_COLOR)})
	# The chip on a lit menu item: ink on the accent fill.
	_variation("InkChip", "Panel")
	_styles("InkChip", {"panel": _box("ink_chip", Palette.TEXT_ON_FILL)})
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
	# The inside of a scoreboard row, and the space under the Tab scoreboard's header.
	_variation("CellMargin", "MarginContainer")
	_margins("CellMargin", Palette.CELL_MARGIN_X, Palette.CELL_MARGIN_Y)
	_variation("HeaderMargin", "MarginContainer")
	_constants("HeaderMargin", {"margin_bottom": Palette.HEADER_GAP})
	# Big text cut to the mockups' line heights (negative margins, see the tokens): 48, 32 and 96 px.
	_variation("TitleTrim", "MarginContainer")
	_constants("TitleTrim", {"margin_top": Palette.TRIM_TITLE_TOP, "margin_bottom": Palette.TRIM_TITLE_BOTTOM})
	_variation("LargeTrim", "MarginContainer")
	_constants("LargeTrim", {"margin_top": Palette.TRIM_LARGE_TOP, "margin_bottom": Palette.TRIM_LARGE_BOTTOM})
	_variation("HeroTrim", "MarginContainer")
	_constants("HeroTrim", {"margin_top": Palette.TRIM_HERO_TOP, "margin_bottom": Palette.TRIM_HERO_BOTTOM})
	# The rows of a menu, and its smaller groups.
	_variation("ContentBox", "VBoxContainer")
	_constants("ContentBox", {"separation": Palette.CONTENT_GAP})
	_variation("TableBox", "VBoxContainer")
	_constants("TableBox", {"separation": Palette.TABLE_GAP})
	_variation("TeamBox", "VBoxContainer")
	_constants("TeamBox", {"separation": Palette.TEAM_ROW_GAP})
	_variation("ScoreRow", "HBoxContainer")
	_constants("ScoreRow", {"separation": Palette.SCORE_GAP})
	# The two centred lines between the scoreboard's scores.
	_variation("ScoreLines", "VBoxContainer")
	_constants("ScoreLines", {"separation": Palette.SCORE_LINES_GAP})
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
	# The class draft: the title block, a card's frame (the 2 px the focus colours), its body and its blocks of text,
	# and the row of cards (full size, or compact when all four classes are shown).
	_variation("ClassHeaderBox", "VBoxContainer")
	_constants("ClassHeaderBox", {"separation": Palette.CLASS_HEADER_GAP})
	_variation("FrameMargin", "MarginContainer")
	_margins("FrameMargin", Palette.BORDER, Palette.BORDER)
	_variation("ClassBodyMargin", "MarginContainer")
	_margins("ClassBodyMargin", Palette.CLASS_BODY_PAD, Palette.CLASS_BODY_PAD)
	_variation("ClassBodyBox", "VBoxContainer")
	_constants("ClassBodyBox", {"separation": Palette.CLASS_BODY_GAP})
	_variation("ClassTextBox", "VBoxContainer")
	_constants("ClassTextBox", {"separation": Palette.CLASS_TEXT_GAP})
	_variation("ClassRow", "HBoxContainer")
	_constants("ClassRow", {"separation": Palette.CLASS_CARD_GAP})
	_variation("ClassRowCompact", "HBoxContainer")
	_constants("ClassRowCompact", {"separation": Palette.CLASS_CARD_GAP_COMPACT})
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
	# A full-screen page's parts side by side, 32 apart (the lobby's left column and teams, its two teams, its footer).
	_variation("PageRow", "HBoxContainer")
	_constants("PageRow", {"separation": Palette.PAGE_GAP})
	# The lobby's left column: its groups apart, a label and its field close, a field and its button, a team's rows,
	# the parts of a row, and a row's own margin.
	_variation("SideColumn", "VBoxContainer")
	_constants("SideColumn", {"separation": Palette.LOBBY_GROUP_GAP})
	_variation("SideBox", "VBoxContainer")
	_constants("SideBox", {"separation": Palette.LOBBY_SIDE_GAP})
	_variation("TightBox", "VBoxContainer")
	_constants("TightBox", {"separation": Palette.LOBBY_ROW_GAP})
	_variation("FieldRow", "HBoxContainer")
	_constants("FieldRow", {"separation": Palette.LOBBY_FIELD_GAP})
	_variation("SlotRow", "HBoxContainer")
	_constants("SlotRow", {"separation": Palette.LOBBY_SIDE_GAP})
	_variation("SlotMargin", "MarginContainer")
	_constants("SlotMargin", {"margin_left": Palette.LOBBY_SLOT_PAD_X, "margin_right": Palette.LOBBY_SLOT_PAD_X})
	# The brand chips under the game's name, and a team's size chips.
	_variation("ChipRow", "HBoxContainer")
	_constants("ChipRow", {"separation": Palette.CHIP_GAP})
	# The loading screen's two columns (the map's lines; "Loading" over its squares).
	_variation("LoadingColumn", "VBoxContainer")
	_constants("LoadingColumn", {"separation": Palette.LOADING_GAP})
	_variation("TeamChipRow", "HBoxContainer")
	_constants("TeamChipRow", {"separation": Palette.TEAM_CHIP_GAP})
	# The settings screen: the gaps between its title, tabs and footer, rows whose parts sit edge to edge
	# (a 400 px label, then the control), rows that touch, and a small group (preview squares and caption).
	_variation("SettingsColumn", "VBoxContainer")
	_constants("SettingsColumn", {"separation": Palette.SETTINGS_GAP})
	_variation("FlushRow", "HBoxContainer")
	_constants("FlushRow", {"separation": Palette.FLUSH_GAP})
	_variation("StackBox", "VBoxContainer")
	_constants("StackBox", {"separation": Palette.STACK_GAP})
	_variation("GroupBox", "VBoxContainer")
	_constants("GroupBox", {"separation": Palette.GROUP_GAP})
	# A page's parts side by side that wrap under each other when the window is narrow (the crosshair tab's rows and preview).
	_variation("FlowBox", "HFlowContainer")
	_constants("FlowBox", {"h_separation": Palette.FLUSH_GAP, "v_separation": Palette.PAGE_GAP})
	# The settings menu's crosshair colour swatches, and the margin that frames each colour inside its button.
	_variation("SwatchRow", "HBoxContainer")
	_constants("SwatchRow", {"separation": Palette.SWATCH_GAP})
	_variation("SwatchMargin", "MarginContainer")
	_margins("SwatchMargin", Palette.SWATCH_MARGIN, Palette.SWATCH_MARGIN)


## The HUD's roles (D-133, D-141), as in the mockups 09 to 13. Every label of the HUD has a hard
## 2 px SHADOW shadow instead of an outline (the plates, which are ink, none), in the menus' text
## sizes; the 32, 48 and 96 px roles use a font with its line box trimmed to the size (the mockups'
## line height), so the gaps in the layout are the mockups'. The HUD is scaled by [UiScale], which
## reads the sizes, spacing, shadows and boxes these roles give a control and scales them, so a
## role's numbers are for a 720-pixel-tall window like the rest.
## The custom type "Hud" holds what code reads: the colours of game states (the alert of the timer
## in the last seconds, a notice, the bomb's gold) and the sizes of the drawn parts (chips, bars,
## columns, plates, icons), so a screen asks get_theme_color("alert", "Hud") or
## get_theme_constant("chip_width", "Hud") instead of keeping a number of its own.
func _hud() -> void:
	_colors("Hud", {"alert": Palette.ALERT, "notice": Palette.ALERT})
	_constants("Hud", {
		"pip_size": Palette.HUD_PIP_SIZE, "chip_width": Palette.HUD_CHIP_SIZE.x, "chip_height": Palette.HUD_CHIP_SIZE.y,
		"chip_health": Palette.HUD_CHIP_HEALTH, "chip_count": Palette.HUD_CHIP_COUNT,
		"bar_width": Palette.HUD_BAR_SIZE.x, "bar_height": Palette.HUD_BAR_SIZE.y,
		"score_width": Palette.HUD_SCORE_WIDTH, "centre_width": Palette.HUD_CENTRE_WIDTH,
		"icon_scale": Palette.HUD_ICON_SCALE, "plate_height": Palette.HUD_PLATE_HEIGHT,
		"alert_plate_height": Palette.HUD_ALERT_PLATE_HEIGHT,
		"feed_height": Palette.HUD_FEED_HEIGHT, "feed_time_ms": Palette.HUD_FEED_TIME_MS,
		"toast_height": Palette.HUD_TOAST_HEIGHT, "toast_chip": Palette.HUD_TOAST_CHIP, "toast_time_ms": Palette.HUD_TOAST_TIME_MS,
		"prompt_bar_width": Palette.HUD_PROMPT_BAR.x, "prompt_bar_height": Palette.HUD_PROMPT_BAR.y,
		"hit_inner": Palette.HUD_HIT_INNER, "hit_length": Palette.HUD_HIT_LENGTH, "hit_thickness": Palette.HUD_HIT_THICKNESS,
		"hit_time_ms": Palette.HUD_HIT_TIME_MS, "shadow_offset": Palette.SHADOW_OFFSET,
		"compass_arc": Palette.HUD_COMPASS_ARC, "compass_tick_step": Palette.HUD_COMPASS_TICK_STEP,
		"compass_tick_small": Palette.HUD_COMPASS_TICK_SMALL, "compass_tick_large": Palette.HUD_COMPASS_TICK_LARGE,
		"compass_thickness": Palette.HUD_COMPASS_THICKNESS, "compass_box_width": Palette.HUD_COMPASS_BOX.x,
		"compass_box_height": Palette.HUD_COMPASS_BOX.y, "compass_mark_width": Palette.HUD_COMPASS_MARK.x,
		"compass_mark_height": Palette.HUD_COMPASS_MARK.y, "compass_mark_pinned": Palette.HUD_COMPASS_MARK_PINNED,
		"compass_step_ms": Palette.HUD_COMPASS_STEP_MS, "compass_alpha_1": Palette.HUD_COMPASS_ALPHA_1,
		"compass_alpha_2": Palette.HUD_COMPASS_ALPHA_2, "compass_alpha_3": Palette.HUD_COMPASS_ALPHA_3,
		"compass_tag": Palette.HUD_COMPASS_TAG, "compass_tag_ms": Palette.HUD_COMPASS_TAG_MS,
		"callout_edge": Palette.HUD_CALLOUT_EDGE,
	})
	var regular: Font = load(Palette.FONT)
	var bold: Font = load(Palette.FONT_BOLD)
	var large := _trimmed("hud_font_large", regular, Palette.HUD_TRIM_LARGE)
	var title := _trimmed("hud_font_title", regular, Palette.HUD_TRIM_TITLE)
	var title_bold := _trimmed("hud_font_title_bold", bold, Palette.HUD_TRIM_TITLE)
	var hero_bold := _trimmed("hud_font_hero_bold", bold, Palette.HUD_TRIM_HERO)
	# 16 px text: the weapon name, "Buy", the side line, the mini row; dim: the reward; the unseen slot list.
	_hud_label("HudSmallLabel", Palette.TEXT_SIZE, Palette.TEXT)
	_hud_label("HudDimLabel", Palette.TEXT_SIZE, Palette.TEXT_DIM)
	_hud_label("HudSlotsLabel", Palette.TEXT_SIZE, Palette.TEXT)
	# The big numbers: health and magazine (48), armor, money, the time and the reserve (32, the reserve 70%).
	_hud_label("HudValueLabel", Palette.TEXT_SIZE_TITLE, Palette.TEXT, title)
	_hud_label("HudLargeLabel", Palette.TEXT_SIZE_LARGE, Palette.TEXT, large)
	_hud_label("HudReserveLabel", Palette.TEXT_SIZE_LARGE, Palette.HUD_RESERVE_TEXT, large)
	# The top bars' scores in the UI's team colours, the banners (48 Bold) and the respawn countdown (96 Bold).
	_hud_label("HudFriendlyScoreLabel", Palette.TEXT_SIZE_TITLE, Palette.FRIENDLY, title)
	_hud_label("HudEnemyScoreLabel", Palette.TEXT_SIZE_TITLE, Palette.ENEMY, title)
	_hud_label("HudTitleLabel", Palette.TEXT_SIZE_TITLE, Palette.TEXT, title_bold)
	_hud_label("HudCountdownLabel", Palette.TEXT_SIZE_HERO, Palette.TEXT, hero_bold)
	# On a plate (ink, no text shadow): the dim words, the dot, the plain words, a name, the alert plate's word.
	_hud_label("HudPlateDimLabel", Palette.TEXT_SIZE, Palette.TEXT_DIM, null, false)
	_hud_label("HudPlateMuteLabel", Palette.TEXT_SIZE, Palette.MUTE, null, false)
	_hud_label("HudPlateLabel", Palette.TEXT_SIZE, Palette.TEXT, null, false)
	_hud_label("HudPlateNameLabel", Palette.TEXT_SIZE_LARGE, Palette.TEXT, large, false)
	_hud_label("HudAlertPlateLabel", Palette.TEXT_SIZE_LARGE, Palette.TEXT_ON_FILL, large, false)
	# 16 px text on a plate in the ink of a filled plate (a TEXT or ALERT one: the match point toast, the bomb's tag) or in
	# ALERT (the low ammo toast), no shadow; and the prompt's seconds in ALERT on the world, with the shadow.
	_hud_label("HudPlateInkLabel", Palette.TEXT_SIZE, Palette.TEXT_ON_FILL, null, false)
	_hud_label("HudPlateAlertLabel", Palette.TEXT_SIZE, Palette.ALERT, null, false)
	_hud_label("HudAlertLabel", Palette.TEXT_SIZE, Palette.ALERT)
	# Spacing: stacked blocks (columns) and rows of parts.
	_hud_gap("HudStack", "VBoxContainer", Palette.HUD_GAP_STACK)
	_hud_gap("HudStackBlock", "VBoxContainer", Palette.HUD_GAP_BLOCK)
	_hud_gap("HudStackDeath", "VBoxContainer", Palette.HUD_GAP_DEATH)
	_hud_gap("HudStackCentre", "VBoxContainer", Palette.HUD_GAP_CENTRE)
	_hud_gap("HudStackIcon", "VBoxContainer", Palette.HUD_GAP_ICON)
	_hud_gap("HudRowStack", "HBoxContainer", Palette.HUD_GAP_STACK)
	_hud_gap("HudRowIcon", "HBoxContainer", Palette.HUD_GAP_ICON)
	_hud_gap("HudRowBlock", "HBoxContainer", Palette.HUD_GAP_BLOCK)
	_hud_gap("HudRowBarBomb", "HBoxContainer", Palette.HUD_GAP_BAR_BOMB)
	_hud_gap("HudRowBarTdm", "HBoxContainer", Palette.HUD_GAP_BAR_TDM)
	_hud_gap("HudRowStats", "HBoxContainer", Palette.HUD_GAP_STATS)
	_hud_gap("HudRowChips", "HBoxContainer", Palette.HUD_GAP_CHIPS)
	# The Team Deathmatch centre column hangs 8 px lower than the score columns (HUD_GAP_STACK).
	_variation("HudCentreMargin", "MarginContainer")
	_constants("HudCentreMargin", {"margin_top": Palette.HUD_GAP_STACK})
	# The reserve ammo is lifted to share the magazine's baseline.
	_variation("HudBaselineLift", "MarginContainer")
	_constants("HudBaselineLift", {"margin_bottom": Palette.HUD_BASELINE_LIFT})
	# The health chips (TEXT while that 10 HP is there, LINE when gone) and the score bars (a VOID shadow behind).
	_hud_panel("HudHealthChip", _box("hud_health_chip", Palette.TEXT))
	_hud_panel("HudHealthChipEmpty", _box("hud_health_chip_empty", Palette.LINE_COLOR))
	_hud_panel("HudScoreBarBack", _shadowed("hud_score_bar_back", Palette.INK, Vector4.ZERO))
	_hud_panel("HudFriendlyBarFill", _box("hud_friendly_bar_fill", Palette.FRIENDLY))
	_hud_panel("HudEnemyBarFill", _box("hud_enemy_bar_fill", Palette.ENEMY))
	# A player's chip in the Bomb top bar: filled with a hard shadow while alive, a 2 px frame when dead.
	_hud_panel("HudFriendlyPipAlive", _shadowed("hud_friendly_pip_alive", Palette.FRIENDLY, Vector4.ZERO))
	_hud_panel("HudEnemyPipAlive", _shadowed("hud_enemy_pip_alive", Palette.ENEMY, Vector4.ZERO))
	_hud_panel("HudFriendlyPipDead", _box("hud_friendly_pip_dead", Color.TRANSPARENT, Palette.FRIENDLY, Palette.BORDER))
	_hud_panel("HudEnemyPipDead", _box("hud_enemy_pip_dead", Color.TRANSPARENT, Palette.ENEMY, Palette.BORDER))
	# The dead tint over the whole screen (mockup 10).
	_hud_panel("HudDeadTint", _box("hud_dead_tint", Palette.HUD_DEAD_TINT))
	# Plates: ink, padded at the sides (their height is the "plate_height" constant); the alert plate of the planted bomb.
	_variation("HudPlate", "PanelContainer")
	_styles("HudPlate", {"panel": _box("hud_plate", Palette.INK, Color.TRANSPARENT, 0, Vector4(Palette.HUD_PLATE_PAD, 0, Palette.HUD_PLATE_PAD, 0))})
	_variation("HudAlertPlate", "PanelContainer")
	_styles("HudAlertPlate", {"panel": _box("hud_alert_plate", Palette.ALERT, Color.TRANSPARENT, 0, Vector4(Palette.HUD_ALERT_PLATE_PAD, 0, Palette.HUD_ALERT_PLATE_PAD, 0))})
	# The kill feed's lines (a PLATE; yours: INK with a TEXT frame, your death: INK with an ENEMY frame). A frame's padding is
	# inside it, so every line's text starts at the same distance from the edge.
	var feed_margin := Vector4(Palette.HUD_FEED_PAD, 0, Palette.HUD_FEED_PAD, 0)
	var feed_frame := Palette.HUD_FEED_FRAME_PAD + Palette.BORDER
	_hud_plate("HudFeedPlate", _box("hud_feed_plate", Palette.PLATE, Color.TRANSPARENT, 0, feed_margin))
	_hud_plate("HudFeedPlateCall", _box("hud_feed_plate_call", Palette.PLATE, Color.TRANSPARENT, 0, Vector4(0, 0, Palette.HUD_FEED_PAD, 0)))
	_hud_plate("HudFeedPlateYou", _box("hud_feed_plate_you", Palette.INK, Palette.TEXT, Palette.BORDER, Vector4(feed_frame, 0, feed_frame, 0)))
	_hud_plate("HudFeedPlateDeath", _box("hud_feed_plate_death", Palette.INK, Palette.ENEMY, Palette.BORDER, Vector4(feed_frame, 0, feed_frame, 0)))
	# The toasts' plates (news: INK, match point: TEXT, the bomb planted: ALERT, low ammo: INK with an ALERT frame) and their chips.
	var toast_margin := Vector4(Palette.HUD_TOAST_PAD, 0, Palette.HUD_TOAST_PAD, 0)
	var toast_frame := Palette.HUD_TOAST_PAD + Palette.BORDER
	_hud_plate("HudToastNeutral", _box("hud_toast_neutral", Palette.INK, Color.TRANSPARENT, 0, toast_margin))
	_hud_plate("HudToastMatchPoint", _box("hud_toast_match_point", Palette.TEXT, Color.TRANSPARENT, 0, toast_margin))
	_hud_plate("HudToastBomb", _box("hud_toast_bomb", Palette.ALERT, Color.TRANSPARENT, 0, toast_margin))
	_hud_plate("HudToastLowAmmo", _box("hud_toast_low_ammo", Palette.INK, Palette.ALERT, Palette.BORDER, Vector4(toast_frame, 0, toast_frame, 0)))
	_hud_panel("HudToastChip", _box("hud_toast_chip", Palette.TEXT))
	_hud_panel("HudToastChipInk", _box("hud_toast_chip_ink", Palette.INK))
	# The plant and defuse bar: INK with a hard shadow, and the fill on it.
	_hud_panel("HudProgressBack", _shadowed("hud_progress_back", Palette.INK, Vector4.ZERO))
	_hud_panel("HudProgressFill", _box("hud_progress_fill", Palette.ALERT))


## A HUD text role: a [Label] with a size, a colour, a font (null: the usual one) and a hard shadow
## ([constant Palette.SHADOW_OFFSET] down and right in [constant Palette.SHADOW]), or none for text on a plate.
func _hud_label(role: String, size: int, color: Color, font: Font = null, shadow: bool = true) -> void:
	_variation(role, "Label")
	_font_sizes(role, {"font_size": size})
	if font != null:
		_fonts(role, {"font": font})
	_colors(role, {"font_color": color, "font_shadow_color": Palette.SHADOW if shadow else Color.TRANSPARENT})
	_constants(role, {
		"outline_size": Palette.TEXT_OUTLINE_SIZE, "shadow_outline_size": 0,
		"shadow_offset_x": Palette.SHADOW_OFFSET, "shadow_offset_y": Palette.SHADOW_OFFSET,
	})


## A box role: a [Panel] with one stylebox.
func _hud_panel(role: String, box: StyleBoxFlat) -> void:
	_variation(role, "Panel")
	_styles(role, {"panel": box})


## A plate role: a [PanelContainer] with one box.
func _hud_plate(role: String, box: StyleBoxFlat) -> void:
	_variation(role, "PanelContainer")
	_styles(role, {"panel": box})


## A container role that only sets the space between its children.
func _hud_gap(role: String, base_type: String, gap: int) -> void:
	_variation(role, base_type)
	_constants(role, {"separation": gap})


## [param font] with its line box trimmed by [param trim] (x off the top, y off the bottom).
func _trimmed(id: String, font: Font, trim: Vector2i) -> FontVariation:
	var trimmed := FontVariation.new()
	trimmed.resource_scene_unique_id = id
	trimmed.base_font = font
	trimmed.spacing_top = -trim.x
	trimmed.spacing_bottom = -trim.y
	return trimmed


## The class draft's sizes that code reads (the custom type "ClassDraft", scaled with the UI like every constant): a
## card's size at full and compact width, and the widest row of cards, so that the menu picks the compact cards when
## the full ones would not fit.
func _class_draft() -> void:
	_constants("ClassDraft", {
		"card_width": Palette.CLASS_CARD_WIDTH, "card_height": Palette.CLASS_CARD_HEIGHT,
		"card_width_compact": Palette.CLASS_CARD_WIDTH_COMPACT, "row_max_width": Palette.CLASS_ROW_MAX_WIDTH,
	})


## The buy menu (mockup 14): the sizes code reads (the custom type "BuyMenu": a column header's and an item's height and the box
## an item's icon stands in), the column (a header, [constant Palette.BUY_HEADER_GAP] of space, the items), the header's line (LINE,
## or the accent for the selected column) and the four looks of an item, a button that is only a frame: ok, focused, owned, poor.
## Each look covers every state of the button, so that the menu changes an item's look by changing its type variation alone.
func _buy_menu() -> void:
	_constants("BuyMenu", {
		"header_height": Palette.BUY_HEADER_HEIGHT, "item_height": Palette.BUY_ITEM_HEIGHT,
		"icon_box_width": Palette.BUY_ICON_BOX.x, "icon_box_height": Palette.BUY_ICON_BOX.y,
	})
	_variation("BuyColumn", "VBoxContainer")
	_constants("BuyColumn", {"separation": Palette.BUY_HEADER_GAP})
	_variation("ColumnHeaderPanel", "PanelContainer")
	_styles("ColumnHeaderPanel", {"panel": _underline("column_header_panel", Palette.LINE_COLOR)})
	_variation("ColumnHeaderLitPanel", "PanelContainer")
	_styles("ColumnHeaderLitPanel", {"panel": _underline("column_header_lit_panel", Palette.ACCENT)})
	var pad := _even(0)
	var ok := _box("buy_item_ok", Palette.PANEL, Palette.PANEL, Palette.BORDER, pad)
	var ok_hover := _box("buy_item_ok_hover", Palette.PANEL, Palette.ACCENT, Palette.BORDER, pad)
	_buy_item_look("BuyItemOk", ok, ok_hover)
	var focused := _box("buy_item_focused", Palette.PANEL_RAISED, Palette.ACCENT, Palette.BORDER, pad)
	_buy_item_look("BuyItemFocused", focused, focused)
	var owned := _box("buy_item_owned", Color.TRANSPARENT, Palette.LINE_COLOR, Palette.BORDER, pad)
	_buy_item_look("BuyItemOwned", owned, owned)
	var poor := _box("buy_item_poor", Palette.INK, Palette.INK, Palette.BORDER, pad)
	_buy_item_look("BuyItemPoor", poor, poor)


## One look of a buy-menu item: [param rest] in every state but hovered and focused, which show [param lit].
func _buy_item_look(role: String, rest: StyleBoxFlat, lit: StyleBoxFlat) -> void:
	_variation(role, "Button")
	_styles(role, {
		"normal": rest, "pressed": rest, "disabled": rest, "hover": lit, "hover_pressed": lit, "focus": lit,
	})


## The developer console (mockup 17), on top of the ConsolePanel strip: the output's lines in the
## pixel font like all text, in four colours (normal TEXT here, echoed commands DimLabel, notes
## MuteLabel, errors ALERT), and an input row on INK with a lime prompt, a flat input with a block
## caret and a MUTE hint. The input line has no frame of its own: the row is its box.
func _console() -> void:
	_variation("ConsoleBox", "VBoxContainer")
	_constants("ConsoleBox", {"separation": Palette.FLUSH_GAP})
	_variation("ConsoleOutputMargin", "MarginContainer")
	_constants("ConsoleOutputMargin", {"margin_left": Palette.CONSOLE_PAD_X, "margin_top": Palette.CONSOLE_PAD_TOP,
			"margin_right": Palette.CONSOLE_PAD_X, "margin_bottom": Palette.CONSOLE_PAD_BOTTOM})
	_variation("ConsoleLines", "VBoxContainer")
	_constants("ConsoleLines", {"separation": Palette.CONSOLE_LINE_GAP})
	_variation("ConsoleLabel", "Label")
	_colors("ConsoleLabel", {"font_color": Palette.TEXT})
	_variation("ConsoleErrorLabel", "ConsoleLabel")
	_colors("ConsoleErrorLabel", {"font_color": Palette.ALERT})
	_variation("ConsoleInputRow", "PanelContainer")
	var row := _box("console_input_row", Palette.INK, Palette.LINE_COLOR)
	row.border_width_top = Palette.LINE
	row.content_margin_left = Palette.CONSOLE_PAD_X
	row.content_margin_right = Palette.CONSOLE_PAD_X
	_styles("ConsoleInputRow", {"panel": row})
	_variation("ConsoleInputBox", "HBoxContainer")
	_constants("ConsoleInputBox", {"separation": Palette.CONSOLE_ROW_GAP})
	_variation("ConsoleLineEdit", "LineEdit")
	var bare := _empty("console_input", Vector4.ZERO)
	_styles("ConsoleLineEdit", {"normal": bare, "focus": bare, "read_only": bare})
	_constants("ConsoleLineEdit", {"caret_width": Palette.CONSOLE_CARET_WIDTH})


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
	# A centred menu item (the pause menu's): in the mockup the chip and the text are one group that is centred, while a
	# button draws its icon at the left edge and centres the text beside it. So here the icon is only a spacer (invisible
	# in every state) that moves the text over, and the screen puts the chip (an InkChip) next to the text itself.
	_variation("CenteredItemButton", "BigButton")
	_colors("CenteredItemButton", {
		"icon_normal_color": Color.TRANSPARENT, "icon_hover_color": Color.TRANSPARENT, "icon_focus_color": Color.TRANSPARENT,
		"icon_pressed_color": Color.TRANSPARENT, "icon_hover_pressed_color": Color.TRANSPARENT, "icon_disabled_color": Color.TRANSPARENT,
	})
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
	# The match-end screen's buttons: 48 high, 24 either side. The primary one is Play again, the others are outlined.
	var tall := Vector4(Palette.TALL_BUTTON_PAD_X, Palette.TALL_BUTTON_PAD_TOP, Palette.TALL_BUTTON_PAD_X, Palette.TALL_BUTTON_PAD_BOTTOM)
	_variation("TallButton", "Button")
	_outlined_button_styles("TallButton", tall)
	_variation("TallPrimaryButton", "PrimaryButton")
	_styles("TallPrimaryButton", {
		"normal": _shadowed("tall_primary_button_normal", Palette.ACCENT, tall),
		"hover": _shadowed("tall_primary_button_hover", Palette.ACCENT_BRIGHT, tall),
		"pressed": _shadowed("tall_primary_button_pressed", Palette.ACCENT, tall),
		"hover_pressed": _shadowed("tall_primary_button_hover_pressed", Palette.ACCENT_BRIGHT, tall),
		"focus": _ring("tall_primary_button_focus", Palette.TEXT, tall),
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
	# A class card of the draft: a panel whose 2 px frame is the panel's own colour at rest and the accent on hover and
	# focus (the focus ring; the card that has the focus is the lit one). The current class's pressed card looks like the rest.
	_variation("ClassCardButton", "Button")
	var class_rest := _box("class_card_rest", Palette.PANEL, Palette.PANEL, Palette.BORDER, card)
	var class_lit := _box("class_card_lit", Palette.PANEL, Palette.ACCENT, Palette.BORDER, card)
	_styles("ClassCardButton", {
		"normal": class_rest, "pressed": class_rest, "disabled": class_rest, "hover": class_lit, "hover_pressed": class_lit,
		"focus": _ring("class_card_focus", Palette.ACCENT, card),
	})
	# The picked mode card: framed in the accent at rest too ("click to play").
	_variation("ModeButtonPicked", "ModeButton")
	_styles("ModeButtonPicked", {
		"normal": _box("mode_button_picked", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
		"disabled": _box("mode_button_picked_disabled", Palette.PANEL_OPAQUE, Palette.ACCENT, Palette.BORDER, card),
	})
	# A segment of a segmented choice (Foundations: SEGMENTS): DIM text with nothing behind;
	# the chosen one (a pressed toggle) filled with TEXT, ink text; the focus underlined in the accent.
	# The settings screen's segments (on / off, frame limit) are wider.
	_segment_styles("SegmentButton", Palette.SEGMENT_PAD_X)
	_segment_styles("WideSegmentButton", Palette.SEGMENT_WIDE_PAD_X)
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
	# The settings screen's buttons. Reset: a MUTE frame and DIM text (the quieter of the two). Back: a TEXT frame
	# and TEXT text (the stronger); both 40 high.
	_variation("DimButton", "Button")
	_colors("DimButton", {"font_color": Palette.TEXT_DIM})
	_variation("StrongButton", "Button")
	var strong := Vector4(Palette.STRONG_BUTTON_PAD_X, Palette.BUTTON_PAD_TOP, Palette.STRONG_BUTTON_PAD_X, Palette.BUTTON_PAD_BOTTOM)
	_styles("StrongButton", {
		"normal": _box("strong_button_normal", Palette.BUTTON, Palette.TEXT, Palette.BORDER, strong),
		"hover": _box("strong_button_hover", Palette.BUTTON, Palette.ACCENT, Palette.BORDER, strong),
		"pressed": _box("strong_button_pressed", Palette.BUTTON_PRESSED, Palette.BUTTON_PRESSED, Palette.BORDER, strong),
		"hover_pressed": _box("strong_button_hover_pressed", Palette.BUTTON_PRESSED, Palette.BUTTON_PRESSED, Palette.BORDER, strong),
		"disabled": _box("strong_button_disabled", Palette.BUTTON, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, strong),
		"focus": _ring("strong_button_focus", Palette.ACCENT, strong),
	})
	# A key slot of the Controls tab (26 high). The first is a key cap: a LINE frame and TEXT text. The second is
	# plain MUTE text, still a button. The one waiting for a key is filled with the accent, ink text.
	var cap := Vector4(Palette.KEY_SLOT_PAD_X, Palette.KEY_SLOT_PAD_TOP, Palette.KEY_SLOT_PAD_X, Palette.KEY_SLOT_PAD_BOTTOM)
	var plain := Vector4(0, Palette.KEY_SLOT_PAD_TOP, 0, Palette.KEY_SLOT_PAD_BOTTOM)
	var lit := _box("key_slot_lit", Palette.ACCENT, Color.TRANSPARENT, 0, cap)
	_variation("KeyCapButton", "Button")
	_styles("KeyCapButton", {
		"normal": _box("key_cap_button_normal", Palette.BUTTON, Palette.LINE_COLOR, Palette.BORDER, cap),
		"hover": _box("key_cap_button_hover", Palette.BUTTON, Palette.ACCENT, Palette.BORDER, cap),
		"pressed": lit, "hover_pressed": lit,
		"disabled": _box("key_cap_button_disabled", Palette.BUTTON, Palette.BUTTON_BORDER_DISABLED, Palette.BORDER, cap),
		"focus": _ring("key_cap_button_focus", Palette.ACCENT, cap),
	})
	_colors("KeyCapButton", {"font_color": Palette.TEXT, "font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL})
	_variation("KeySlotButton", "Button")
	_styles("KeySlotButton", {
		"normal": _empty("key_slot_button_normal", plain), "hover": _empty("key_slot_button_hover", plain),
		"pressed": lit, "hover_pressed": lit, "disabled": _empty("key_slot_button_disabled", plain),
		"focus": _ring("key_slot_button_focus", Palette.ACCENT, plain),
	})
	_colors("KeySlotButton", {"font_color": Palette.MUTE, "font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL})
	_variation("ListeningKeyButton", "KeyCapButton")
	_styles("ListeningKeyButton", {"normal": lit, "hover": lit, "pressed": lit, "hover_pressed": lit, "focus": lit})
	_colors("ListeningKeyButton", {
		"font_color": Palette.TEXT_ON_FILL, "font_hover_color": Palette.TEXT_ON_FILL, "font_focus_color": Palette.TEXT_ON_FILL,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
	})
	# A crosshair colour swatch's cell: nothing at rest, a 2 px frame around the chosen colour in the accent
	# (the colour itself is a child, inset by SwatchMargin), a MUTE one when hovered.
	_variation("SwatchButton", "Button")
	var swatch := _even(0)
	var swatch_chosen := _ring("swatch_button_chosen", Palette.ACCENT, swatch)
	_styles("SwatchButton", {
		"normal": _empty("swatch_button_normal", swatch), "disabled": _empty("swatch_button_disabled", swatch),
		"hover": _ring("swatch_button_hover", Palette.MUTE, swatch),
		"pressed": swatch_chosen, "hover_pressed": swatch_chosen, "focus": _ring("swatch_button_focus", Palette.TEXT_DIM, swatch),
	})
	# Option buttons and menu buttons share the button look; the arrow is an icon.
	_icons("OptionButton", {"arrow": "arrow_down"})
	_constants("OptionButton", {"arrow_margin": Palette.ARROW_GAP, "h_separation": Palette.BUTTON_ICON_GAP})


## The looks of a segment of a segmented choice: DIM text with nothing behind, TEXT when hovered,
## the chosen one (a pressed toggle) filled with TEXT and ink text, the focus underlined in the
## accent. [param pad_x] is the space either side of its text.
func _segment_styles(type: String, pad_x: int) -> void:
	_variation(type, "Button")
	var prefix := type.to_snake_case()
	var segment := Vector4(pad_x, Palette.SEGMENT_PAD_TOP, pad_x, Palette.SEGMENT_PAD_BOTTOM)
	var focus := _box("%s_focus" % prefix, Color.TRANSPARENT, Palette.ACCENT, 0, segment)
	focus.draw_center = false
	focus.border_width_bottom = Palette.BORDER
	_styles(type, {
		"normal": _empty("%s_normal" % prefix, segment),
		"hover": _empty("%s_hover" % prefix, segment),
		"pressed": _box("%s_pressed" % prefix, Palette.TEXT, Color.TRANSPARENT, 0, segment),
		"hover_pressed": _box("%s_hover_pressed" % prefix, Palette.TEXT, Color.TRANSPARENT, 0, segment),
		"disabled": _empty("%s_disabled" % prefix, segment),
		"focus": focus,
	})
	_colors(type, {
		"font_color": Palette.TEXT_DIM, "font_hover_color": Palette.TEXT, "font_focus_color": Palette.TEXT,
		"font_pressed_color": Palette.TEXT_ON_FILL, "font_hover_pressed_color": Palette.TEXT_ON_FILL,
		"font_disabled_color": Palette.TEXT_DISABLED,
	})


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
	# The underline is as wide as the word: the tab's side padding (which spaces the words 32 apart) is cut off it.
	selected.expand_margin_left = -Palette.TAB_PAD_X
	selected.expand_margin_right = -Palette.TAB_PAD_X
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
		focus.expand_margin_left = -Palette.TAB_PAD_X
		focus.expand_margin_right = -Palette.TAB_PAD_X
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
	# The first word starts at the page's edge, like the title above it: the tab strip begins one tab padding to its left.
	_constants("TabContainer", {"side_margin": -Palette.TAB_PAD_X})


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
	# The focus chip, for buttons that show it only while focused or hovered ([constant UiIcons.CHIP]): in
	# the theme so that it scales with the UI like the slots.
	_icons(String(UiIcons.THEME_TYPE), {String(UiIcons.CHIP): "chip"})


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


## Nothing behind, a 2 px line in [param color] along the bottom edge, and [param space_above] of
## empty room over it (an empty panel with this style is that high).
func _underline(id: String, color: Color, space_above: int = 0) -> StyleBoxFlat:
	var box := _box(id, Color.TRANSPARENT, color)
	box.border_width_bottom = Palette.LINE
	box.content_margin_top = space_above
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
