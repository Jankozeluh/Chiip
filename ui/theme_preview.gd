extends Control
## Developer tool, not part of the game: shows every control the UI theme
## (ui/chiip_theme.tres) styles, in one window, so a change to the theme can be
## judged from a single screenshot.
##
## Run it like any scene (the window is 1280 × 720, like the game):
##
##     Godot --path . res://ui/theme_preview.tscn
##
## Add [code]--resolution 1920x1080[/code] to see the theme scaled for a bigger
## window (exactly 1.5×, see [UiTheme]). A button can't be hovered or pressed on
## a still screenshot, so the "Hover" and "Pressed" samples are normal buttons
## given the theme's hover and pressed look. The option button opens its list
## when the scene starts. Everything else is live: hover, click, type, drag.

## The layout is designed for a window this many pixels tall.
const DESIGN_HEIGHT := 720.0
## How many frames the window must keep the focus before the drop-down opens...
const STABLE_FOCUS_FRAMES := 10
## ...and how long to wait for that before opening it anyway (a window with no focus never gets there).
const MAX_FOCUS_WAIT_FRAMES := 90

@onready var _hover: Button = $Center/Panel/Margin/Columns/Buttons/Row1/Hover
@onready var _pressed: Button = $Center/Panel/Margin/Columns/Buttons/Row2/Pressed
@onready var _focus: Button = $Center/Panel/Margin/Columns/Buttons/Row2/Focus
@onready var _option: OptionButton = $Center/Panel/Margin/Columns/Tabs/Option


func _ready() -> void:
	get_window().size_changed.connect(_apply_scale)
	_apply_scale()
	# Open the drop-down once the window has had the keyboard focus for a while: a
	# popup closes when the focus changes, and a new window's focus flickers at first.
	var focused_frames := 0
	for i in MAX_FOCUS_WAIT_FRAMES:
		await get_tree().process_frame
		focused_frames = focused_frames + 1 if get_window().has_focus() else 0
		if focused_frames >= STABLE_FOCUS_FRAMES:
			break
	_option.show_popup()


## Scales the preview for the window, then re-applies the forced states (they
## copy styles out of the scaled theme).
func _apply_scale() -> void:
	UiTheme.apply(self, get_window().size.y / DESIGN_HEIGHT)
	_force_state(_hover, "hover")
	_force_state(_pressed, "pressed")
	_force_focus(_focus)


## Makes [param button] look as it does in [param state] ("hover" or "pressed")
## by using that stylebox and text color as its resting look.
func _force_state(button: Button, state: String) -> void:
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox(state))
	button.add_theme_color_override("font_color", button.get_theme_color("font_%s_color" % state))


## The focus ring is drawn over the resting look, which a still sample can't do
## with an override; the same picture is the resting box with the ring's border color.
func _force_focus(button: Button) -> void:
	button.remove_theme_stylebox_override("normal")
	var resting := (button.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	resting.border_color = (button.get_theme_stylebox("focus") as StyleBoxFlat).border_color
	button.add_theme_stylebox_override("normal", resting)
	button.add_theme_color_override("font_color", button.get_theme_color("font_focus_color"))
