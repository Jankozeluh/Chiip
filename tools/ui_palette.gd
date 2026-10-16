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
## The big mode choices of the main menu (a title and a line of detail inside).
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
