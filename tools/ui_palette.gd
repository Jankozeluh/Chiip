extends RefCounted
## The design tokens of Chiip's UI (D-057, D-131): every colour, font, text
## size, line width, padding and spacing the UI theme uses, by name, in one
## place. Used by the two tools that build the UI look:
## tools/generate_ui_icons.gd (the pixel-art icons) and tools/make_ui_theme.gd
## (ui/chiip_theme.tres), which has no numbers of its own. To restyle the UI
## (for example from a mockup's colours, sizes and spacing), change the values
## here and run both tools (see CLAUDE.md, Commands); every menu follows.
##
## Sizes are in pixels for a 720-pixel-tall window; [UiTheme] scales them for
## bigger windows. Keep text sizes on Silkscreen's grid (multiples of 16 stay
## crisp at 1×, 1.5× and 2×) and lines and paddings even.
##
## Today's look (D-057): a cool, dark blue-grey with one icy accent, square
## shapes with crisp 2 px borders. Team blue and red are not here: they stay
## in [Teams].

# --- Colours ---

## The deepest tone: text fields, slider and scroll tracks, the area behind a list.
const INSET := Color("0b1017")
## Frame of an inset area.
const INSET_BORDER := Color("38465b")
## A panel's background, a little see-through so the game shows through.
const PANEL := Color("141b25", 0.96)
## The same, more see-through (the Tab scoreboard over a live round).
const PANEL_OVERLAY := Color("141b25", 0.88)
## A panel that must hide what is behind it: drop-down lists and popups.
const PANEL_OPAQUE := Color("141b25")
## A panel's frame.
const PANEL_BORDER := Color("46546b")
## Something sitting a step above its panel: the page of a tab container, the selected tab.
const PANEL_RAISED := Color("1b2432")
## The developer console's strip.
const CONSOLE := Color("0b1017", 0.92)
## A tooltip's background.
const TOOLTIP := Color("0b1017", 0.96)

## A button at rest, hovered, pressed (also a toggle that is on: a dark teal) and disabled.
const BUTTON := Color("232d3d")
const BUTTON_HOVER := Color("303d54")
const BUTTON_PRESSED := Color("12384a")
const BUTTON_DISABLED := Color("171d27")
## A button's frame at rest, and disabled.
const BUTTON_BORDER := Color("5b6b85")
const BUTTON_BORDER_DISABLED := Color("2b3544")
## A faint band behind a hovered check box or check button.
const TOGGLE_HOVER := Color(1, 1, 1, 0.07)

## The dimming behind a modal menu (settings, pause, class, match setup, match end):
## it keeps the game or the page visible but out of the way, and takes the clicks.
const BACKDROP := Color(0, 0, 0, 0.62)
## The light band behind your own row in a scoreboard table.
const YOU_ROW := Color(1, 1, 1, 0.16)
## What a dead player's row in a scoreboard table is multiplied by (the Tab
## scoreboard dims them); its alpha is how visible the row stays.
const DEAD_ROW := Color(1, 1, 1, 0.4)

## The accent: focus rings, selection, slider fill, check marks, active tab.
const ACCENT := Color("4cc9f0")
## The accent lit up (hovered knobs, pressed text) and sunk into a fill (selected rows).
const ACCENT_BRIGHT := Color("a6ebff")
const ACCENT_DARK := Color("1e6a86")
## Between the two: the frame of a hovered button.
const ACCENT_MID := Color("2f93b4")
## The frame of the main button of a screen (Start, Resume, Play again) at rest.
const PRIMARY_BORDER := ACCENT

## Normal text, headings and highlights, secondary text, disabled text.
const TEXT := Color("e6ecf5")
const TEXT_BRIGHT := Color("ffffff")
const TEXT_DIM := Color("9aa8bd")
const TEXT_DISABLED := Color("5f6c80")
## The thin outline some text gets (labels, buttons; 0 wide unless a role asks for one).
const TEXT_OUTLINE := Color("0b1017")
## How wide that outline is where a role uses one (tabs, drop-down lists: none).
const TEXT_OUTLINE_SIZE := 0

## A light tone for knobs and handles (slider grabber, scroll bar grabber).
const HANDLE := Color("c7d2e2")
const HANDLE_DISABLED := Color("54647d")
## A slider knob's grooves are the handle colour darkened by this much.
const HANDLE_GROOVE_DARKEN := 0.3

# --- Fonts ---

## The pixel font (D-026).
const FONT := "res://assets/fonts/Silkscreen-Regular.ttf"
## Its bold cut, there for a mockup that asks for it; no role uses it yet.
const FONT_BOLD := "res://assets/fonts/Silkscreen-Bold.ttf"
## The monospace font of the developer console, as the names the system is asked
## for in order (the first one installed wins; macOS has Menlo). A system font,
## so nothing is shipped; the console isn't part of the game's look. (An array,
## because a PackedStringArray can't be a constant; the theme tool converts it.)
const FONT_MONO_NAMES: Array[String] = ["Menlo", "Monaco", "Courier New", "monospace"]

# --- Text sizes ---

## Body text: everything that isn't a title or a number to read at a glance.
const TEXT_SIZE := 16
## Big text: scores, big buttons, the titles of the mode choices.
const TEXT_SIZE_LARGE := 32
## Screen titles.
const TEXT_SIZE_TITLE := 48
## The biggest text: the game's name, the match result.
const TEXT_SIZE_HERO := 48

# --- Lines ---

## Every border and frame.
const BORDER := 2
## A separator line.
const LINE := 2
## The text caret of a field.
const CARET_WIDTH := 2

# --- Paddings (space between a control's edge and its content) ---

## Buttons, option buttons.
const BUTTON_PAD_X := 14
const BUTTON_PAD_Y := 8
## The big buttons of the main menu and the pause menu.
const BIG_BUTTON_PAD_X := 28
const BIG_BUTTON_PAD_Y := 16
## The big mode choices of the main menu (a title and a line of detail inside: ModeMargin).
const MODE_BUTTON_PAD_X := 24
const MODE_BUTTON_PAD_Y := 14
## Text buttons (a word to click, no box).
const TEXT_BUTTON_PAD_X := 8
const TEXT_BUTTON_PAD_Y := 6
## Check boxes and check buttons.
const TOGGLE_PAD_X := 8
const TOGGLE_PAD_Y := 4
## Text fields.
const FIELD_PAD_X := 10
const FIELD_PAD_Y := 6
## How many characters wide a text field is at least.
const FIELD_MIN_CHARACTERS := 4
## Tabs, and the page under them.
const TAB_PAD_X := 18
const TAB_PAD_Y := 8
const TAB_PAGE_PAD := 12
## Slider tracks, progress bars and scroll tracks (also how thick they look).
const SLIDER_PAD := 4
const PROGRESS_PAD := 4
const SCROLL_PAD := 4
## The bar you drag in a scroll track.
const SCROLL_GRABBER_PAD := 8
## Drop-down lists.
const POPUP_PAD := 4
## Tooltips.
const TOOLTIP_PAD_X := 10
const TOOLTIP_PAD_Y := 6

# --- Spacing ---

## Between a button's icon and its text.
const BUTTON_ICON_GAP := 8
## Between an option button's text and its arrow.
const ARROW_GAP := 8
## Between a check box and its text.
const TOGGLE_ICON_GAP := 12
## Between tabs.
const TAB_GAP := 4
## Around a separator line.
const SEPARATOR_SPACE := 8
## Drop-down list entries: between icon and text, between entries, at both ends.
const POPUP_ICON_GAP := 8
const POPUP_ENTRY_GAP := 8
const POPUP_ITEM_PAD := 8
## Around a full-screen page (the main menu's), from the window's edges: PageMargin.
const PAGE_MARGIN_X := 72
const PAGE_MARGIN_Y := 48
## Inside a panel: PanelMargin, PanelMarginWide (big screens) and RowMargin (table rows).
const PANEL_MARGIN_X := 16
const PANEL_MARGIN_Y := 12
const PANEL_MARGIN_WIDE_X := 24
const PANEL_MARGIN_WIDE_Y := 18
const ROW_MARGIN_X := 8
const ROW_MARGIN_Y := 2
## Between the rows of a menu (ContentBox), the parts of a table (TableBox) and its rows (TeamBox).
const CONTENT_GAP := 8
const TABLE_GAP := 12
const TEAM_ROW_GAP := 2
## Between two scores (ScoreRow), a form's label and its controls (FormRow) and buttons in a row (ButtonRow).
const SCORE_GAP := 14
const FORM_GAP := 16
const BUTTON_ROW_GAP := 24
## Between the buttons of a segmented choice (1 2 3 4 5), so they read as one strip.
const SEGMENT_GAP := 4
## Between the mode choices of the main menu, and between a mode's title and its detail line.
const MODE_GAP := 12
const MODE_LINE_GAP := 4
## Between the colour swatches of the settings menu's crosshair colour row, and
## the margin around the colour inside each swatch button (SwatchRow, SwatchMargin).
const SWATCH_GAP := 6
const SWATCH_MARGIN := 6

# --- HUD (the overlay of a running game; D-133) ---
#
# The HUD takes its look from the same theme as the menus, through the roles
# (type variations) that tools/make_ui_theme.gd builds from these tokens. It is
# scaled by [UiScale] rather than [UiTheme], and it was laid out before the menus'
# 16 px grid, so its text sizes are today's numbers (40, 28, 24...) until a
# mockup replaces them. The tokens are the HUD's own, so changing a menu token
# never moves the HUD.

## The outline of all HUD text (black, so it reads over any scenery).
const HUD_OUTLINE := Color(0, 0, 0)

## HUD text: the weapon name, health, ammo, the top bar's scores and the bomb prompt.
const HUD_TEXT := Color("e6ecf5")
## Brighter HUD text: the round timer, the centre messages and the respawn count.
const HUD_TEXT_BRIGHT := Color("ffffff")
## The small line under the round timer ("Round 3", "First to 50").
const HUD_TEXT_DIM := Color(0.75, 0.77, 0.8)
## Something wrong: the timer in the last seconds, bomb planted and overtime, the "Killed by" message.
const HUD_ALERT := Color(1.0, 0.4, 0.3)
## The timer during freeze time.
const HUD_FREEZE_TIMER := Color(1.0, 0.85, 0.4)
## The title notices in the middle of the screen ("Switching sides", "Overtime").
const HUD_NOTICE := Color(1.0, 0.85, 0.4)
## The bomb: its tag, its messages and the progress bar's fill.
const HUD_GOLD := Color(1.0, 0.82, 0.35)
## The bomb's progress bar: the strip behind the fill, and the fill.
const HUD_BAR_BACK := Color(0.05, 0.06, 0.08, 0.8)
const HUD_BAR_FILL := Color(1.0, 0.82, 0.35)
## A player's square in the top bar once they are dead (a living player's is their team's colour).
const HUD_PIP_DEAD := Color(0.22, 0.23, 0.26)
## The round timer's box.
const HUD_TIMER_BOX := Color(0.06, 0.07, 0.09, 0.85)
## A team's score box is the team's colour (from [Teams]) darkened by this much, at this opacity.
const HUD_SCORE_BOX_DARKEN := 0.55
const HUD_SCORE_BOX_ALPHA := 0.9

## Text sizes, each with the width of its outline: health and ammo; the "Killed by"
## message and the main line of the centre messages; the "Spectating" line; the
## weapon name, bomb tag and prompts and the lower lines of the centre messages;
## the centre messages' title; the top bar's scores and timer (no outline) and
## the small line under the timer.
const HUD_SIZE_VALUE := 40
const HUD_OUTLINE_VALUE := 8
const HUD_SIZE_HEADLINE := 32
const HUD_OUTLINE_HEADLINE := 8
const HUD_SIZE_SPECTATE := 28
const HUD_OUTLINE_SPECTATE := 6
const HUD_SIZE_TEXT := 24
const HUD_OUTLINE_TEXT := 6
const HUD_SIZE_TITLE := 48
const HUD_OUTLINE_TITLE := 10
const HUD_SIZE_SCORE := 32
const HUD_OUTLINE_SCORE := 0
const HUD_SIZE_SMALL := 16

## Side of a player's square in the top bar.
const HUD_PIP_SIZE := 12
## Between the three boxes of the top bar, between a box's score and its squares, and between the squares.
const HUD_BAR_GAP := 4
const HUD_BOX_GAP := 2
const HUD_PIP_GAP := 3
## Inside a top bar box: left and right, top, bottom.
const HUD_BOX_PAD_X := 12
const HUD_BOX_PAD_TOP := 4
const HUD_BOX_PAD_BOTTOM := 8
## Between the lines of the centre messages, and between the lines of the kill feed.
const HUD_MESSAGE_GAP := 4
const HUD_FEED_GAP := 3
