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
## shrink factor and the palette effect, and returns the height the UI is laid
## out for, so the caller can scale its menus.

## The menus and the HUD are laid out for a window this many pixels tall.
const UI_DESIGN_HEIGHT := 720.0


## Applies [member Settings.pixel_height], [member Settings.pixelate_hud] and
## [member Settings.palette_effect] from [param settings] to [param window],
## [param world] and [param palette_effect], and returns the UI height in pixels
## (divide it by [constant UI_DESIGN_HEIGHT] for the UI scale factor).
##
## The world image is [code]pixel_height[/code] pixels tall (the width follows
## the window's shape; 480 gives 853 × 480 in a 16:9 window); pixels are scaled
## by whole numbers, so the real height is the closest whole fraction of the
## window: 480 on a 1440-pixel screen, 540 on 1080, 360 on 720. With the HUD
## pixelated the whole window renders at the low resolution and the UI height is
## the pixel height; otherwise only the world is low-res and the UI uses the
## window's height.
static func apply(settings: Settings, window: Window, world: SubViewportContainer, palette_effect: CanvasLayer) -> float:
	var pixel_height := settings.pixel_height
	palette_effect.visible = settings.palette_effect
	if settings.pixelate_hud:
		var aspect := float(window.size.x) / window.size.y
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = Vector2i(roundi(pixel_height * aspect), pixel_height)
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		world.stretch_shrink = 1
		return pixel_height
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# The SubViewport renders at the container's size divided by this.
	world.stretch_shrink = maxi(1, roundi(float(window.size.y) / pixel_height))
	return window.size.y
