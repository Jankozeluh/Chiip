class_name PixelView
extends RefCounted
## Applies the pixel settings (D-027, D-030, D-048) to a scene that shows a 3D
## world at a low resolution: the game ([code]main.gd[/code]) and the main menu,
## which flies over the test map, look alike because they share this.
##
## The scene has a [SubViewportContainer] with the world's [SubViewport] and a
## [CanvasLayer] holding the palette effect. [method apply] sets the window's
## scaling (which belongs to the whole window, so it stays when the scene
## changes: whichever scene starts next applies it again), the container's
## shrink factor and the palette effect, and returns the factor the UI is scaled
## by, so the caller can scale its menus.

## The menus and the HUD are laid out for a window this many pixels tall.
const UI_DESIGN_HEIGHT := 720.0
## ...and this many pixels wide (16:9). The UI scales by the tighter of the two (D-151), so a window
## narrower than 16:9 (2920 × 1753, 1440 × 1080) shows the whole layout, and a wider one
## (3440 × 1440) gets more room at the sides.
const UI_DESIGN_WIDTH := 1280.0


## Applies [member Settings.pixel_height], [member Settings.pixelate_hud] and
## [member Settings.palette_effect] from [param settings] to [param window],
## [param world] and [param palette_effect], and returns the UI scale factor: 1.0 is the
## 1280 × 720 layout (see [method ui_scale_for]).
##
## The world image is [code]pixel_height[/code] pixels tall (the width follows
## the window's shape; 480 gives 853 × 480 in a 16:9 window); pixels are scaled
## by whole numbers, so the real height is the closest whole fraction of the
## window: 480 on a 1440-pixel screen, 540 on 1080, 360 on 720. With the HUD
## pixelated the whole window renders at that low resolution (the window's size
## divided by the same whole number) and the UI scale follows that size; otherwise
## only the world is low-res and the UI uses the window's size.
static func apply(settings: Settings, window: Window, world: SubViewportContainer, palette_effect: CanvasLayer) -> float:
	palette_effect.visible = settings.palette_effect
	# How many window pixels one image pixel covers: a whole number, so pixels stay sharp and even.
	var scale := get_pixel_scale(window.size.y, settings.pixel_height)
	if settings.pixelate_hud:
		# Render the whole window at its size divided by the scale (rounded down,
		# so the integer stretch below really scales by that number and fills
		# the window). Asking for exactly pixel_height lines instead would make
		# Godot's integer stretch round 1.5 down to 1 in a 720-pixel window and
		# show a small, unscaled image.
		var low_res := Vector2i(maxi(1, window.size.x / scale), maxi(1, window.size.y / scale))
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = low_res
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		world.stretch_shrink = 1
		return ui_scale_for(Vector2(low_res))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# The SubViewport renders at the container's size divided by this.
	world.stretch_shrink = scale
	return ui_scale_for(Vector2(window.size))


## The UI scale factor for a screen [param size] pixels big (D-151): the tighter of width / 1280 and
## height / 720, so the 1280 × 720 layout always fits, rounded down to a half step from 1.0 up (the
## pixel font draws every one of its pixels as a whole number of screen pixels at 1, 1.5, 2, 2.5 ...;
## in between they come out uneven). 1.0 at 1280 × 720, 1.5 at 1920 × 1080, 2.0 at 2560 × 1440, at
## 3440 × 1440 (the ultrawide's extra width is room at the sides), at 2560 × 1600 and at 2920 × 1753
## (width-bound: the old height-only rule gave 2.43 and a layout 1199 pixels wide, so the sides were
## cut off), and 1.0 at 1440 × 1080. Below 1.0 (a small window, or the pixelated HUD's low-res image)
## it is the exact fit.
static func ui_scale_for(size: Vector2) -> float:
	var fit := maxf(minf(size.x / UI_DESIGN_WIDTH, size.y / UI_DESIGN_HEIGHT), 0.01)
	if fit < 1.0:
		return fit
	return floorf(fit * 2.0 + 0.001) / 2.0


## The whole number of window pixels per image pixel for a window
## [param window_height] tall and the chosen [param pixel_height]: the closest
## whole fraction, at least 1 (then nothing is pixelated: the window is too small
## for that resolution).
static func get_pixel_scale(window_height: int, pixel_height: int) -> int:
	return maxi(1, roundi(float(window_height) / pixel_height))
