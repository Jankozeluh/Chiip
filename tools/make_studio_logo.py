"""Makes the studio logo files the UI uses from the studio's source picture (D-153).

    ~/miniconda3/envs/chiip/bin/python -I tools/make_studio_logo.py <source png, 112 x 112>

Writes assets/ui/studio_logo.png (the picture as it is: the boot screen shows it at whole
multiples of its size) and assets/ui/studio_logo_small.png (half the size, Lanczos-reduced:
the main menu's corner mark shows it at whole multiples). Then run the import command.
The logo and the name "Divocakos" are the studio's own, all rights reserved (docs/CREDITS.md).
"""
import sys
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    logo = Image.open(sys.argv[1]).convert("RGBA")
    if logo.size != (112, 112):
        sys.exit("The logo must be 112 x 112, this one is %dx%d" % logo.size)
    logo.save(OUT / "studio_logo.png")
    logo.resize((56, 56), Image.LANCZOS).save(OUT / "studio_logo_small.png")
    print("wrote", OUT / "studio_logo.png", "and", OUT / "studio_logo_small.png")


main()
