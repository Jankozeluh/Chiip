class_name ArmorIcon
extends Control
## The HUD's armor symbol (D-093): a pixel-art shield drawn in code, with an "H" on it while a
## helmet is worn, like CS's armor icon. It fills its rectangle with square cells, so it scales
## with the HUD (UiScale scales its offsets) and stays crisp. Dimmed when there is no armor.

## The shield, one letter per cell: "#" is shield.
const SHIELD: Array[String] = [
	"########",
	"########",
	"########",
	"########",
	"########",
	".######.",
	".######.",
	"..####..",
	"...##...",
]
## The helmet's mark on the shield, one letter per cell: "#" is drawn dark.
const HELMET_MARK: Array[String] = [
	"........",
	".#....#.",
	".#....#.",
	".######.",
	".#....#.",
	".#....#.",
	"........",
	"........",
	"........",
]
const FILL := Color(1, 1, 1)
const OUTLINE := Color(0, 0, 0)
## Opacity with no armor at all.
const EMPTY_ALPHA := 0.35

## Draw the helmet's mark.
var helmet: bool = false:
	set(value):
		helmet = value
		queue_redraw()
## Armor points: 0 dims the icon.
var points: float = 0.0:
	set(value):
		points = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cell := floorf(minf(size.x / SHIELD[0].length(), size.y / SHIELD.size()))
	if cell < 1.0:
		return
	var alpha := 1.0 if points > 0.0 else EMPTY_ALPHA
	var outline := maxf(1.0, floorf(cell / 2.0))
	for pass_index in 2:
		for row in SHIELD.size():
			for column in SHIELD[row].length():
				if SHIELD[row][column] != "#":
					continue
				var rect := Rect2(column * cell, row * cell, cell, cell)
				if pass_index == 0:
					draw_rect(rect.grow(outline), Color(OUTLINE, alpha))
				else:
					var mark := helmet and HELMET_MARK[row][column] == "#"
					draw_rect(rect, Color(OUTLINE if mark else FILL, alpha))
