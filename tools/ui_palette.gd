extends RefCounted
## The colors of Chiip's UI (D-057), in one place. Used by the two tools that
## build the UI look: tools/generate_ui_icons.gd (the pixel-art icons) and
## tools/make_ui_theme.gd (ui/chiip_theme.tres). Change a color here, run both
## tools (see CLAUDE.md, Commands) and every menu follows.
##
## A cool, dark blue-grey with one icy accent, to match the daylight look of
## the world (D-031). Deliberately not Counter-Strike's orange/yellow on
## black. Team blue and red are not here: they stay in [Teams].

## The deepest tone: text fields, slider and scroll tracks, the area behind a list.
const INSET := Color("0b1017")
## Frame of an inset area.
const INSET_BORDER := Color("38465b")
## A panel's background, a little see-through so the game shows through.
const PANEL := Color("141b25", 0.96)
## The same, more see-through (the Tab scoreboard over a live round).
const PANEL_OVERLAY := Color("141b25", 0.88)
## A panel's frame.
const PANEL_BORDER := Color("46546b")
## Something sitting a step above its panel: the page of a tab container, the selected tab.
const PANEL_RAISED := Color("1b2432")

## A button at rest, hovered, pressed (also a toggle that is on: a dark teal) and disabled.
const BUTTON := Color("232d3d")
const BUTTON_HOVER := Color("303d54")
const BUTTON_PRESSED := Color("12384a")
const BUTTON_DISABLED := Color("171d27")
## A button's frame at rest, and disabled.
const BUTTON_BORDER := Color("5b6b85")
const BUTTON_BORDER_DISABLED := Color("2b3544")

## The accent: focus rings, selection, slider fill, check marks, active tab.
const ACCENT := Color("4cc9f0")
## The accent lit up (hovered knobs, pressed text) and sunk into a fill (selected rows).
const ACCENT_BRIGHT := Color("a6ebff")
const ACCENT_DARK := Color("1e6a86")
## Between the two: the frame of a hovered button.
const ACCENT_MID := Color("2f93b4")

## Normal text, headings and highlights, secondary text, disabled text.
const TEXT := Color("e6ecf5")
const TEXT_BRIGHT := Color("ffffff")
const TEXT_DIM := Color("9aa8bd")
const TEXT_DISABLED := Color("5f6c80")

## A light tone for knobs and handles (slider grabber, scroll bar grabber).
const HANDLE := Color("c7d2e2")
const HANDLE_DISABLED := Color("54647d")
