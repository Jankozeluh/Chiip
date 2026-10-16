"""Draws the gamepad button glyphs of the v0.2 design (docs/UI_MOCKUPS.md, "Gamepad glyphs") as PNGs.

    ~/miniconda3/envs/chiip/bin/python -I tools/make_pad_glyphs.py [--out <folder>]

Writes <out>/<pad>/<button>.png (16 x 16, coloured: Xbox and PlayStation face buttons in their own
colours) and <out>/<pad>/<button>_mono.png (white, to tint at runtime) for the three pads (xbox, ps,
generic) and 19 buttons. The default folder is assets/ui/glyphs; then run the import command.

This is a port of the designer's Glyph component (Chiip-design/v0.2/Glyph.dc.html): every glyph is a few
rectangles on a 16 x 16 grid, one pixel per cell, like the icon set (tools/generate_ui_icons.gd). Show them
at whole multiples (16, 32 px) with nearest filtering.
"""
import sys
from pathlib import Path

from PIL import Image

FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "X": ["101", "101", "010", "101", "101"], "Y": ["101", "101", "010", "010", "010"],
    "L": ["100", "100", "100", "100", "111"], "R": ["110", "101", "110", "101", "101"],
    "T": ["111", "010", "010", "010", "010"], "S": ["011", "100", "010", "001", "110"],
    "1": ["010", "110", "010", "010", "111"], "2": ["110", "001", "010", "100", "111"],
    "3": ["110", "001", "010", "001", "110"],
}
SYMBOLS = {
    "cross": ["1....1", "11..11", ".1111.", ".1111.", "11..11", "1....1"],
    "circle": [".1111.", "11..11", "1....1", "1....1", "11..11", ".1111."],
    "square": ["111111", "1....1", "1....1", "1....1", "1....1", "111111"],
    "triangle": ["..11..", "..11..", ".1..1.", ".1..1.", "1....1", "111111"],
}
COLOURS = {"a": "#5cc23a", "b": "#ec4c3c", "x": "#3f86ec", "y": "#f2c23a",
           "pcross": "#86aef0", "pcircle": "#f0675e", "psquare": "#ea8ccc", "ptri": "#3ccaa2"}
TEXT, INK = "#e6ecf5", "#0b1017"
BUTTONS = ["south", "east", "west", "north", "lb", "rb", "lt", "rt", "ls", "rs", "l3", "r3",
           "dup", "ddown", "dleft", "dright", "d", "start", "select"]
PADS = ["xbox", "ps", "generic"]


def rows(starts, y0, x0, size):
    return [(x0 + s, y0 + i, size - 2 * s, 1) for i, s in enumerate(starts)]


DISC = rows([5, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5], 0, 0, 16)
IN12 = rows([4, 2, 1, 0, 0, 0, 0, 0, 0, 1, 2, 4], 2, 2, 12)
IN10 = rows([3, 1, 0, 0, 0, 0, 0, 0, 1, 3], 3, 3, 10)
SHAPES = {
    "disc": DISC, "ring": DISC + IN12, "click": DISC + IN12 + IN10,
    "bumper": [(2, 3, 12, 1), (1, 4, 14, 1), (0, 5, 16, 7), (1, 12, 14, 1)],
    "trigger": [(4, 0, 8, 1), (2, 1, 12, 1), (1, 2, 14, 1), (0, 3, 16, 12), (1, 15, 14, 1)],
    "dpad": [(5, 0, 6, 16), (0, 5, 5, 6), (11, 5, 5, 6)],
    "pill": [(1, 3, 14, 1), (0, 4, 16, 8), (1, 12, 14, 1)],
}
EVENODD = {"ring", "click"}


def text(label, y):
    width = len(label) * 4 - 1
    x0 = (16 - width) // 2 + (1 if width % 2 else 0)
    cells = []
    for k, ch in enumerate(label):
        for j, row in enumerate(FONT.get(ch, [])):
            cells += [(x0 + k * 4 + i, y + j, 1, 1) for i, bit in enumerate(row) if bit == "1"]
    return cells


def symbol(name):
    return [(5 + i, 5 + j, 1, 1) for j, row in enumerate(SYMBOLS[name]) for i, bit in enumerate(row) if bit == "1"]


def dots(on):
    small = {"n": (7, 3), "s": (7, 11), "w": (3, 7), "e": (11, 7)}
    big = {"n": (6, 2), "s": (6, 10), "w": (2, 6), "e": (10, 6)}
    return [(*big[k], 4, 4) if k == on else (*small[k], 2, 2) for k in small]


def spec(pad, button):
    """What the designer's spec() answers: the shape, an optional body colour, the mark's cells."""
    face = {"south": "s", "east": "e", "west": "w", "north": "n"}
    if button in face:
        if pad == "xbox":
            letter, colour = {"south": ("A", "a"), "east": ("B", "b"), "west": ("X", "x"), "north": ("Y", "y")}[button]
            return {"shape": "disc", "body": COLOURS[colour], "mark": text(letter, 6)}
        if pad == "ps":
            name, colour = {"south": ("cross", "pcross"), "east": ("circle", "pcircle"),
                            "west": ("square", "psquare"), "north": ("triangle", "ptri")}[button]
            return {"shape": "disc", "body": COLOURS[colour], "mark": symbol(name)}
        return {"shape": "disc", "mark": dots(face[button])}
    labels = {
        "xbox": {"lb": "LB", "rb": "RB", "lt": "LT", "rt": "RT", "ls": "LS", "rs": "RS", "l3": "LS", "r3": "RS"},
        "ps": {"lb": "L1", "rb": "R1", "lt": "L2", "rt": "R2", "ls": "L", "rs": "R", "l3": "L3", "r3": "R3"},
        "generic": {"lb": "L", "rb": "R", "lt": "L", "rt": "R", "ls": "L", "rs": "R", "l3": "L", "r3": "R"},
    }[pad]
    if button in ("lb", "rb"):
        return {"shape": "bumper", "mark": text(labels[button], 6)}
    if button in ("lt", "rt"):
        return {"shape": "trigger", "mark": text(labels[button], 7)}
    if button in ("ls", "rs"):
        return {"shape": "ring", "mark": text(labels[button], 6), "mark_body": True}
    if button in ("l3", "r3"):
        return {"shape": "click", "mark": text(labels[button], 6)}
    if button.startswith("d"):
        arm = {"up": [(5, 0, 6, 5)], "down": [(5, 11, 6, 5)], "left": [(0, 5, 5, 6)], "right": [(11, 5, 5, 6)]}.get(button[1:])
        if arm:
            return {"shape": "dpad", "body": "#5f6c80", "fixed": True, "mark": arm, "mark_colour": TEXT}
        return {"shape": "dpad", "mark": [(7, 7, 2, 2)]}
    if button == "start":
        mark = [(6, 5, 1, 6), (7, 6, 1, 4), (8, 7, 1, 2)] if pad == "generic" else [(5, 5, 6, 1), (5, 7, 6, 1), (5, 9, 6, 1)]
        return {"shape": "pill", "mark": mark}
    mark = {"xbox": [(4, 5, 5, 1), (4, 6, 1, 3), (8, 6, 1, 1), (4, 9, 3, 1), (7, 7, 5, 4)],
            "ps": [(5, 7, 2, 2), (9, 5, 2, 2), (9, 9, 2, 2)], "generic": [(6, 6, 4, 4)]}[pad]
    return {"shape": "pill", "mark": mark}


def paint(grid, cells, colour, even_odd=False):
    """Fills [cells] (x, y, w, h rectangles) with [colour]; for even-odd shapes a pixel covered an odd number of times."""
    counts = {}
    for x, y, w, h in cells:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                counts[(xx, yy)] = counts.get((xx, yy), 0) + 1
    for (x, y), n in counts.items():
        if (n % 2 == 1) if even_odd else n > 0:
            grid.putpixel((x, y), colour)


def draw(pad, button, mono):
    s = spec(pad, button)
    body = s["body"] if s.get("fixed") else (TEXT if mono or "body" not in s else s["body"])
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    paint(image, SHAPES[s["shape"]], _rgba(body), s["shape"] in EVENODD)
    mark_colour = s.get("mark_colour") or (body if s.get("mark_body") else INK)
    if s.get("mark_body"):
        # The mark is drawn in the body's colour, over the ring's hole.
        pass
    paint(image, s["mark"], _rgba(mark_colour))
    return image


def _rgba(hex_colour):
    h = hex_colour.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "assets" / "ui" / "glyphs"
    if "--out" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--out") + 1])
    for pad in PADS:
        (out / pad).mkdir(parents=True, exist_ok=True)
        for button in BUTTONS:
            draw(pad, button, False).save(out / pad / f"{button}.png")
            draw(pad, button, True).save(out / pad / f"{button}_mono.png")
    print("wrote", len(PADS) * len(BUTTONS) * 2, "glyphs to", out)


main()
