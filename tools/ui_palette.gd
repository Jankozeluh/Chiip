extends RefCounted
## The design tokens of Chiip's UI (D-057, D-131): every colour, font, text
## size, line width, padding and spacing the UI theme uses, by name, in one
## place. Used by the two tools that build the UI look:
## tools/generate_ui_icons.gd (the pixel-art icons) and tools/make_ui_theme.gd
## (ui/chiip_theme.tres), which has no numbers of its own. To restyle the UI,
## change the values here and run both tools (see CLAUDE.md, Commands); every
## menu follows.
##
## The values are the user's Claude Design mockups (D-134, "Chiip UI 0 -
## Foundations"): flat ink surfaces, 2 px lines, square corners, one lime
## accent for focus only, Silkscreen at 16 / 32 / 48 / 96 px (Bold for titles),
## an 8 px grid and 32 px from every screen edge. Sizes are in pixels for a
## 720-pixel-tall window (the mockups' 1280 x 720 canvas); [UiTheme] scales them
## for bigger windows.

# --- Colours (Foundations: COLOUR) ---

## VOID: the deepest tone. Value boxes, the console, hard shadows.
const VOID := Color("07090d")
## INK: full-screen menus (settings, Play, match end), plates, the dim behind a menu.
const INK := Color("0b1017")
## PANEL: a surface on top of the game or the ink (cards, panels), 94% opaque.
const PANEL := Color("141b25", 0.94)
## RAISED: a step above a panel (your row in a table, a card's picture area).
const PANEL_RAISED := Color("1c2533")
## LINE: every 2 px line and frame (segments, value boxes, separators, slider tracks).
const LINE_COLOR := Color("33405a")
## MUTE: disabled text, hints, the frame of a resting button.
const MUTE := Color("5f6c80")
## DIM: labels and secondary text.
const TEXT_DIM := Color("9aa8bd")
## TEXT: normal text, the chosen segment's fill, slider knobs.
const TEXT := Color("e6ecf5")
## The brightest text (used sparingly: the hit marker, a few highlights).
const TEXT_BRIGHT := Color("ffffff")
## ACCENT: lime, for focus only (the focused item, the chosen tab's underline, the primary button).
const ACCENT := Color("c8f03c")
## The accent lit up: a hovered primary button.
const ACCENT_BRIGHT := Color("e6ff8a")
## Selected text in a field: the accent, see-through.
const SELECTION := Color("c8f03c", 0.35)
## Your team and the enemy in the UI (D-134: the 3D world keeps [Teams]' own colours), and their fills.
const FRIENDLY := Color("5a94ff")
const FRIENDLY_FILL := Color("1f4a9e")
const ENEMY := Color("ff4d3d")
const ENEMY_FILL := Color("8f2216")
## ALERT: the bomb, low health and ammo.
const ALERT := Color("ffb02e")

## Derived surfaces.
## The Tab scoreboard over a live round: ink, 88%.
const PANEL_OVERLAY := Color("0b1017", 0.88)
## A panel that must hide what is behind it: drop-down lists and popups.
const PANEL_OPAQUE := Color("141b25")
## The developer console's strip: void, 94%.
const CONSOLE := Color("07090d", 0.94)
## A tooltip's background.
const TOOLTIP := Color("0b1017")
## The main menu's column on the left: ink, 92%.
const SIDE_PANEL := Color("0b1017", 0.92)
## The dim behind a modal menu (the mockup's dimmed world: void, 62%).
const BACKDROP := Color("07090d", 0.62)
## A kill-feed line or toast plate: ink, 72%.
const PLATE := Color("0b1017", 0.72)
## Your own row in a table: raised (it also gets an accent frame).
const YOU_ROW := Color("1c2533")
## Kept for older names: the frame of an inset area and of a panel are the line colour.
const INSET := Color("07090d")
const INSET_BORDER := LINE_COLOR
const PANEL_BORDER := LINE_COLOR

## Buttons (Foundations: BUTTON). Outlined: no fill, a 2 px frame.
const BUTTON := Color(0, 0, 0, 0)
## The frame at rest (MUTE) and disabled (LINE); focus and hover use the accent.
const BUTTON_BORDER := Color("5f6c80")
const BUTTON_BORDER_DISABLED := Color("33405a")
## A button while it is held down: filled with the accent.
const BUTTON_PRESSED := ACCENT
## The text of a disabled control.
const TEXT_DISABLED := Color("5f6c80")
## Text on the accent or on a TEXT fill (a focused menu item, the chosen segment, the primary button).
const TEXT_ON_FILL := Color("0b1017")
## How much lighter a team chip gets when hovered.
const CHIP_HOVER_LIGHTEN := 0.25
## A faint band behind a hovered check box or check button.
const TOGGLE_HOVER := Color(1, 1, 1, 0.06)

## Hard shadows (Foundations: "hard shadow 2 px down-right in VOID").
const SHADOW := Color("07090d")
## The thin outline some text gets (none in this design).
const TEXT_OUTLINE := Color("07090d")
const TEXT_OUTLINE_SIZE := 0

## Knobs and handles: the slider's square knob is TEXT, a disabled one MUTE.
const HANDLE := Color("e6ecf5")
const HANDLE_DISABLED := Color("5f6c80")
## A slider knob's grooves are the handle colour darkened by this much (the flat knob has none).
const HANDLE_GROOVE_DARKEN := 0.0

# --- Fonts ---

## The pixel font (D-026).
const FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
## Its bold cut: the 48 and 96 px titles (D-134).
const FONT_BOLD := "res://assets/fonts/Silkscreen-Bold.ttf"

# --- Text sizes (Foundations: TYPE) ---

## Body text: everything that isn't a title or a number to read at a glance.
const TEXT_SIZE := 16
## Big text: menu items, card titles, secondary numbers.
const TEXT_SIZE_LARGE := 32
## Screen titles (Bold), and the big numbers (regular).
const TEXT_SIZE_TITLE := 48
## The biggest text (Bold): the game's name, the match result, a map's name.
const TEXT_SIZE_HERO := 96
## Space between the lines of a two-line 32 px title (the mockup's line height 32 = Silkscreen's 41 px line - 9).
const LARGE_LINE_SPACING := -9
## Extra space between the letters of the game's name on the main menu (the mockup's letter-spacing 4).
const HERO_LETTER_SPACING := 4

# --- Lines ---

## Every border and frame.
const BORDER := 2
## A separator line.
const LINE := 2
## The text caret of a field.
const CARET_WIDTH := 2
## The accent underline of the chosen tab (the mockup's 4 px, overlapping the 2 px tab line).
const TAB_UNDERLINE := 4
## How far a hard shadow falls, down and right.
const SHADOW_OFFSET := 2

# --- Paddings (space between a control's edge and its content) ---
# Silkscreen's line box is 21 px at 16 px with the capitals sitting low (ascent 17), so rows are
# centred on the capitals: 40 px = 8 above + 21 + 11 below; 48 px at 32 px = 1 + 41 + 6.

## Buttons (Foundations: 40 high, text centred): left/right, above, below.
const BUTTON_PAD_X := 16
const BUTTON_PAD_TOP := 8
const BUTTON_PAD_BOTTOM := 11
## Menu items (48 high, 32 px text).
const BIG_BUTTON_PAD_X := 16
const BIG_BUTTON_PAD_TOP := 1
const BIG_BUTTON_PAD_BOTTOM := 6
## A small menu item (40 high, 16 px: Host and Join).
const SMALL_ITEM_PAD_X := 16
## The big Play button of the Play screen (56 high, 32 px text).
const BIG_PRIMARY_PAD_X := 32
const BIG_PRIMARY_PAD_TOP := 5
const BIG_PRIMARY_PAD_BOTTOM := 10
## The Play screen's mode cards (24 all round).
const MODE_BUTTON_PAD_X := 24
const MODE_BUTTON_PAD_Y := 24
## Text buttons (a word to click, no box).
const TEXT_BUTTON_PAD_X := 8
const TEXT_BUTTON_PAD_Y := 6
## A segment of a segmented choice (inside its 2 px frame: 32 high). The Play screen's
## are 12 either side, the settings screen's (on / off, frame limit) 16.
const SEGMENT_PAD_X := 12
const SEGMENT_WIDE_PAD_X := 16
const SEGMENT_PAD_TOP := 4
const SEGMENT_PAD_BOTTOM := 7
## Check boxes and check buttons.
const TOGGLE_PAD_X := 8
const TOGGLE_PAD_Y := 4
## Text fields and value boxes (32 high).
const FIELD_PAD_X := 8
const FIELD_PAD_TOP := 4
const FIELD_PAD_BOTTOM := 7
## How many characters wide a text field is at least.
const FIELD_MIN_CHARACTERS := 4
## Tabs (the mockup's padding 8 0 12) and the page under them. A tab's bottom is
## 12 plus the 2 px of its underline that stands above the 2 px tab line, so the
## strip is 43 high; the page's top padding then puts the first row at y = 176.
const TAB_PAD_X := 16
const TAB_PAD_TOP := 8
const TAB_PAD_BOTTOM := 14
const TAB_PAGE_PAD := 0
const TAB_PAGE_PAD_TOP := 29
## Slider tracks (4 px: 2 above and below the line), progress bars and scroll tracks.
const SLIDER_PAD := 2
const PROGRESS_PAD := 4
const SCROLL_PAD := 2
## The bar you drag in a scroll track. A scroll bar is as wide as the track's two paddings (4 px),
## which the settings screen's Controls tab leaves room for above its key list.
const SCROLL_GRABBER_PAD := 2
## Drop-down lists.
const POPUP_PAD := 4
## Tooltips.
const TOOLTIP_PAD_X := 12
const TOOLTIP_PAD_Y := 8
## A key cap (Foundations: 32 high, 8 px either side, a 2 px TEXT frame).
const KEY_CAP_PAD_X := 8
const KEY_CAP_PAD_TOP := 4
const KEY_CAP_PAD_BOTTOM := 3
## A key slot of the settings' Controls tab (26 high: 1 + 21 + 4, the capitals centred): 10 either side.
const KEY_SLOT_PAD_X := 10
const KEY_SLOT_PAD_TOP := 1
const KEY_SLOT_PAD_BOTTOM := 4
## The Back button of the settings screen (a TEXT frame, 40 high): 24 either side.
const STRONG_BUTTON_PAD_X := 24
## The match-end screen's buttons (48 high, 24 either side; 16 px text centred on its capitals: 12 + 21 + 15).
const TALL_BUTTON_PAD_X := 24
const TALL_BUTTON_PAD_TOP := 12
const TALL_BUTTON_PAD_BOTTOM := 15
## A tag (the lime DEFAULT on the Team Deathmatch card: padding 2 6).
const TAG_PAD_X := 6
const TAG_PAD_Y := 2

# --- Spacing ---

## Between a button's icon (the focus chip) and its text (Foundations: 16).
const BUTTON_ICON_GAP := 16
## Between an option button's text and its arrow.
const ARROW_GAP := 8
## Between a check box and its text.
const TOGGLE_ICON_GAP := 12
## Between a tab's icon and text (tabs are spaced by their padding: 16 + 16 = the mockup's 32).
const TAB_GAP := 8
## Around a separator line.
const SEPARATOR_SPACE := 8
## Drop-down list entries: between icon and text, between entries, at both ends.
const POPUP_ICON_GAP := 8
const POPUP_ENTRY_GAP := 8
const POPUP_ITEM_PAD := 8
## Around a full-screen page, from the window's edges: PageMargin (the mockups' 32).
const PAGE_MARGIN_X := 32
const PAGE_MARGIN_Y := 32
## Inside a panel: PanelMargin (32, the scoreboard), PanelMarginWide (big screens) and RowMargin (table rows).
const PANEL_MARGIN_X := 32
const PANEL_MARGIN_Y := 32
const PANEL_MARGIN_WIDE_X := 32
const PANEL_MARGIN_WIDE_Y := 32
const ROW_MARGIN_X := 16
const ROW_MARGIN_Y := 9
## Inside a scoreboard row (CellMargin; the mockup's "padding 0 16"): the row's height comes from its own
## minimum size and its cells centre themselves, so there is no space above or below.
const CELL_MARGIN_X := 16
const CELL_MARGIN_Y := 0
## Between the rows of a menu (ContentBox), the parts of a table (TableBox: the column titles and the teams)
## and its rows (TeamBox). The Tab scoreboard's are the mockup's flex gap of 8.
const CONTENT_GAP := 8
const TABLE_GAP := 8
const TEAM_ROW_GAP := 8
## Above the enemy team's line in a table: the mockup's 16 for the Tab scoreboard and 12 for the match-end screen
## (the line's own box carries it, so a row of the table needs no spacer).
const TEAM_LINE_GAP := 16
const TEAM_LINE_GAP_TIGHT := 12
## Under the Tab scoreboard's header (scores and mode), on top of the 8 between its parts.
const HEADER_GAP := 16
## Between two scores (ScoreRow), a form's label and its controls (FormRow) and buttons in a row (ButtonRow).
const SCORE_GAP := 24
const FORM_GAP := 16
const BUTTON_ROW_GAP := 16
## Between the two centred lines of a scoreboard's header ("Team Deathmatch · Depot" and "First to 50 · 7:42").
const SCORE_LINES_GAP := 6
## Between the segments of a segmented choice: none, they share one frame.
const SEGMENT_GAP := 0
## Between the menu items of a list (the mockup's 4), and the cards of the Play screen (24).
const MODE_GAP := 4
const MODE_LINE_GAP := 8
const CARD_GAP := 24
## The main menu's line under its items: 16 in from the sides, 12 above and below.
const DIVIDER_MARGIN_X := 16
const DIVIDER_MARGIN_Y := 12
## A full-screen page's sections (the Play screen: header, cards, custom rows, footer).
const PAGE_GAP := 32
## The Play screen's custom rows: two columns 64 apart, rows 16 apart.
const FORM_GRID_H := 64
const FORM_GRID_V := 16
## Inside a row: between its parts (Foundations: "inside a row: 16").
const ROW_GAP := 16
## The three brand chips under the game's name, and a team's size chips.
const CHIP_GAP := 6
const TEAM_CHIP_GAP := 4
## The crosshair colour swatches. A swatch's cell is the 28 px colour plus the room
## for the frame around the chosen one (a 2 px gap and the 2 px outline, SWATCH_MARGIN),
## so the cells touch (SWATCH_GAP) and the colours are 8 px apart.
const SWATCH_GAP := 0
const SWATCH_MARGIN := 4

# --- The settings screen (the mockup's "05 Settings", D-137) ---

## Between the settings screen's title, its tabs and its footer.
const SETTINGS_GAP := 24
## Edge to edge: the parts of a settings row (a 400 px label, then the control) and of a table row.
const FLUSH_GAP := 0
## Rows that touch (the crosshair tab's rows are 48 high and have no gap).
const STACK_GAP := 0
## The parts of a small group, 16 apart (the two preview squares and the caption under them).
const GROUP_GAP := 16

# --- Line boxes of big text (the mockups' line heights, D-137) ---
# Silkscreen's line box is a bit more than three times the text size (62 px at 48, 41 at 32, 123 at 96), while the
# mockup sets the line height to the text size ("line heights: 96/96, 48/48, 32/32"). A label inside a
# TitleTrim, LargeTrim or HeroTrim (a MarginContainer with negative margins) is cut to that height, as much off
# the top as off the bottom, which is where CSS puts the cut, so a score or a result sits where the mockup has it.

## 48 px text: 62 - 14 = 48.
const TRIM_TITLE_TOP := -7
const TRIM_TITLE_BOTTOM := -7
## 32 px text: 41 - 9 = 32.
const TRIM_LARGE_TOP := -5
const TRIM_LARGE_BOTTOM := -4
## 96 px text: 123 - 27 = 96.
const TRIM_HERO_TOP := -14
const TRIM_HERO_BOTTOM := -13

# --- The multiplayer lobby (the mockup's "06 Lobby", M9 on the M10 look) ---
# A page like the Play screen: a left column (336 wide, your name and the way in) and, 64 further right, the two
# teams side by side (a 32 high header with a 2 px team line, then 40 high rows 4 apart), a "Switch team" button,
# and a footer (a LINE edge, then the match's facts, "Edit setup" and "Start").

## Between a label and the field or buttons under it in the left column (the mockup's flex gap of 12), and between the
## parts of a lobby row (a chip, a name, "Host": the mockup's gap of 12).
const LOBBY_SIDE_GAP := 12
## Between the left column's groups ("Your name", "Join by IP", "Or host a game"): the 12 above plus the mockup's margin of 24.
const LOBBY_GROUP_GAP := 36
## Between a team's rows, and between the two lines of a footer pair (a caption over its value).
const LOBBY_ROW_GAP := 4
## Between a field and the button beside it ("Join by IP": address, port, Join).
const LOBBY_FIELD_GAP := 8
## Inside a lobby row (the mockup's "padding 0 12"): left and right.
const LOBBY_SLOT_PAD_X := 12
## Above the footer's items, under its LINE edge.
const LOBBY_FOOTER_PAD_TOP := 24

# --- Loading screen (the mockup's "07 Loading / Map change", D-138) ---
# An INK band across the bottom of the game, with the map's name and the mode on its left and a row of progress
# squares on its right, both columns the same distance in from their edges.

## The band's height.
const LOADING_BAND_HEIGHT := 240
## How far the two columns stand from the side edge and from the bottom edge of the screen.
const LOADING_MARGIN := 64
## Between the lines of the left column (the kicker, the map's name, the mode), and between the right column's "Loading" and its squares.
const LOADING_GAP := 16
## The side of a progress square (the scene gives each Panel this minimum size; the squares are CHIP_GAP apart).
const LOADING_CHIP := 12
## How many progress squares there are: the hold time is shared out between them.
const LOADING_CHIPS := 12

# --- Developer console (mockup 17) ---
# A strip across the top of the screen: the output (Silkscreen 16 on a 24 px line, bottom-aligned) over an
# input row on INK. The strip's colour and its LINE edge are CONSOLE and the ConsolePanel role.

## The strip's height at 720p: the output has room for 11 lines (11 x 24 + 10 x 2 = 284) between the paddings and the input row.
const CONSOLE_HEIGHT := 384
## The output's space to the left and right edge, and the input row's.
const CONSOLE_PAD_X := 32
## The output's space above its lines and below them.
const CONSOLE_PAD_TOP := 24
const CONSOLE_PAD_BOTTOM := 8
## The height of one output line (the 16 px text is centred in it) and the space between two lines.
const CONSOLE_LINE_HEIGHT := 24
const CONSOLE_LINE_GAP := 2
## The input row's height, its top edge (a LINE) included, and the space between the prompt, the input and the hint.
const CONSOLE_ROW_HEIGHT := 48
const CONSOLE_ROW_GAP := 12
## The input's caret is a 10 px wide block (the mockup's lime block, 10 x 18).
const CONSOLE_CARET_WIDTH := 10

# --- HUD (the overlay of a running game; D-133, D-141) ---
#
# The HUD takes its look from the same theme as the menus, through the roles
# (type variations) that tools/make_ui_theme.gd builds from these tokens, and the
# mockups' (09 to 13) sizes, colours and 8 px grid: the text sizes are the menus'
# (TEXT_SIZE, TEXT_SIZE_LARGE, TEXT_SIZE_TITLE, TEXT_SIZE_HERO), the colours the
# palette's, and HUD text gets a hard SHADOW_OFFSET shadow in SHADOW instead of an
# outline. The HUD is scaled by [UiScale] rather than [UiTheme]; the numbers here
# are for a 720-pixel-tall window like every other token.

## The dead tint (mockup 10): ink-grey over the whole screen while you wait to respawn.
const HUD_DEAD_TINT := Color("282c32", 0.55)
## The reserve ammo ("/ 90") is TEXT at 70% opacity.
const HUD_RESERVE_TEXT := Color("e6ecf5", 0.7)

## Line boxes. Silkscreen's line box is much taller than its size (41 px at 32, 62 at 48, 123 at 96),
## and the mockups set the line height equal to the size. These trim a label's font by that much:
## x pixels off the top and y off the bottom of the line box (at 32 px, 48 px and 96 px).
const HUD_TRIM_LARGE := Vector2i(5, 4)
const HUD_TRIM_TITLE := Vector2i(7, 7)
const HUD_TRIM_HERO := Vector2i(14, 13)

## Gaps (the 8 px grid). Between stacked parts of a block (health and its chips, the weapon and its ammo,
## a TDM score and its bar); between an icon and its number, a name and its icon, magazine and reserve;
## between the big blocks (money and health, the banner's lines, the plate's parts, the spectate plate and the row above it).
const HUD_GAP_STACK := 8
const HUD_GAP_ICON := 12
const HUD_GAP_BLOCK := 16
## The Bomb top bar's items and the spectate row's three groups; the Team Deathmatch top bar's three columns.
const HUD_GAP_BAR_BOMB := 24
const HUD_GAP_BAR_TDM := 32
## Between the health block and the armor block in the bottom-left corner.
const HUD_GAP_STATS := 40
## Between the time and the round in the Bomb top bar; between the countdown and the death plate.
const HUD_GAP_CENTRE := 6
const HUD_GAP_DEATH := 24
## Between the health chips, and between a team's alive chips.
const HUD_GAP_CHIPS := 4

## Sizes of the drawn parts. The health chip (one per 10 health, ten of them), the HP one chip stands for;
## a player's chip in the Bomb top bar; a Team Deathmatch score bar.
const HUD_CHIP_SIZE := Vector2i(12, 8)
const HUD_CHIP_HEALTH := 10
const HUD_CHIP_COUNT := 10
const HUD_PIP_SIZE := 12
const HUD_BAR_SIZE := Vector2i(160, 8)
## The Bomb top bar's score boxes (the number is right- or left-aligned in them) and its centre column.
const HUD_SCORE_WIDTH := 64
const HUD_CENTRE_WIDTH := 120
## How many times bigger the bottom corners' icons are drawn than the 16 px icon set (the mini row uses 1).
const HUD_ICON_SCALE := 2
## The plate under the countdown and in the spectate view: its height and its side padding (INK, no text shadow);
## the alert plate that replaces the Bomb timer once the bomb is planted, and the "Bomb" tag above the weapon row.
const HUD_PLATE_HEIGHT := 48
const HUD_PLATE_PAD := 20
const HUD_ALERT_PLATE_HEIGHT := 32
const HUD_ALERT_PLATE_PAD := 12
## The magazine (48 px) and the reserve (32 px) share a baseline: with the line boxes trimmed the reserve's
## baseline is this much nearer its bottom than the magazine's, so it is lifted by it.
const HUD_BASELINE_LIFT := 1

## The kill feed (Foundations: KILL FEED; mockup 09): a line is a plate this high, [constant PLATE] (ink at 72%), with this padding at
## its sides. Your own kill and death are solid INK with a [constant BORDER] frame (TEXT for a kill, ENEMY for a death) and this padding
## inside the frame. A line stays this many milliseconds (counted in the game's own time, so a pause freezes it); the lines are
## [constant HUD_GAP_STACK] apart, the parts of a line [constant HUD_GAP_ICON].
const HUD_FEED_HEIGHT := 32
const HUD_FEED_PAD := 12
const HUD_FEED_FRAME_PAD := 10
const HUD_FEED_TIME_MS := 6000

## Toasts (Foundations: TOASTS; centred under the top bar): a plate this high with this padding at its sides, a chip this big, and how
## long one stays (milliseconds, counted in the game's own time). The kinds: INK with a TEXT chip (news), TEXT with an INK chip (match
## point), ALERT with the bomb's icon (the bomb planted) and INK with an ALERT frame (low ammo; the padding is inside the frame).
const HUD_TOAST_HEIGHT := 40
const HUD_TOAST_PAD := 16
const HUD_TOAST_CHIP := 8
const HUD_TOAST_TIME_MS := 2500

## The plant and defuse prompt (mockup 12): the progress bar's size, on INK with a hard shadow, filled with ALERT.
const HUD_PROMPT_BAR := Vector2i(320, 8)

## The hit marker (Foundations: HIT MARKER): four L-shaped corners around the crosshair's centre, each two bars of this length and
## thickness, from this far from the centre to that plus the length, with a hard shadow; it shows this many milliseconds.
const HUD_HIT_INNER := 14
const HUD_HIT_LENGTH := 12
const HUD_HIT_THICKNESS := 4
const HUD_HIT_TIME_MS := 150
