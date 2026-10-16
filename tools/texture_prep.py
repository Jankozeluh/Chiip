"""
texture_prep.py - bakes the source images for the eight kit textures whose ambientCG colour
map alone doesn't make a good retro texture (D-121). The result goes into
tools/make_retro_texture.gd like any other source (settings in docs/CREDITS.md).

    ~/miniconda3/envs/chiip/bin/python -I tools/texture_prep.py <downloads> <out>

<downloads> holds one folder per ambientCG asset with its extracted 1K-JPG maps
(<downloads>/CorrugatedSteel005/CorrugatedSteel005_1K-JPG_Color.jpg, ..._Displacement.jpg),
<out> receives corrugated_grey.png, corrugated_green.png, diamond_plate.png, perforated.png,
roof_slate.png, tiles_dark.png, rust_plates.png, chainlink.png and chainlink_opacity.png.

Why each one needs it:
- corrugated steel, diamond plate, perforated sheet, dark tiles: the colour map is flat; the
  ribs, lugs, holes and grout live in the Displacement map, which is multiplied in. Diamond
  plate, perforated sheet and dark tiles are cropped to the top-left quarter (the pattern
  repeats a whole number of times, so the crop still tiles) so they read at 64 x 64.
- corrugated_green: hue turned -38 degrees, from grass green to olive.
- rust_plates: hue turned +12 degrees, from red-orange to brown (the texture report counted
  the original's rust as 36 % team red).
- roof_slate: the asset's shingles become plaid at 64 x 64, so the shingles are drawn here
  (8 staggered rows of 4) with the asset's colour map as the stone grain.
- chainlink: Fence007A's square mesh is finer than a pixel at 64 x 64, so a diamond lattice
  (8 across) is drawn as the opacity map over the asset's metal colour.
Written for the M10 map kit by a Sonnet subagent, kept so the textures can be recreated.
"""
import os
import sys

import numpy as np
from PIL import Image

S = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def load(asset, kind):
    return Image.open(f"{S}/{asset}/{asset}_1K-JPG_{kind}.jpg")


def rgb(asset):
    return np.asarray(load(asset, "Color").convert("RGB"), dtype=np.float32) / 255.0


def disp(asset):
    return np.asarray(load(asset, "Displacement").convert("L"), dtype=np.float32) / 255.0


def save(name, arr):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(f"{OUT}/{name}.png")


def shift_hue(arr, degrees):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).convert("HSV")
    hsv = np.asarray(img).copy().astype(np.int32)
    hsv[..., 0] = (hsv[..., 0] + int(round(degrees / 360.0 * 256))) % 256
    return np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB"), dtype=np.float32) / 255.0


def crop(a, n):
    return a[:n, :n]


# corrugated: ribs from the displacement map (10 ribs / 4 wide ribs across the tile)
d = disp("CorrugatedSteel005")
save("corrugated_grey", rgb("CorrugatedSteel005") * (0.62 + 0.50 * d)[..., None])
d = disp("CorrugatedSteel006A")
green = shift_hue(rgb("CorrugatedSteel006A"), -38)
save("corrugated_green", green * (0.60 + 0.50 * d)[..., None])

# diamond plate: lugs from displacement; the top-left half = 10 lug periods (instead of 20) so they read at 64 px
d = crop(disp("DiamondPlate008B"), 512)
save("diamond_plate", crop(rgb("DiamondPlate008B"), 512) * (0.50 + 0.90 * d)[..., None])

# perforated: dark plate with triangular holes (displacement 1 on the plate, 0 in the holes); top-left quarter
# = 16 x 9 hole periods, which divides the tile exactly in both directions
d = crop(disp("SheetMetal004"), 512)
c = crop(rgb("SheetMetal004"), 512)
plate = np.clip(c * 1.6 + 0.20, 0, 1)
plate = plate * (0.12 + 0.88 * np.clip((d - 0.25) / 0.5, 0, 1))[..., None]
save("perforated", plate)

# roof slate: the ambientCG displacement has 13 fine shingle columns/rows (5 px at 64, plaid-like) and does not tile
# at any smaller crop, so lay out our own staggered slate shingles (8 rows of 4, tileable) and use the Roofing
# colour map for the stone grain.
rng = np.random.default_rng(7)
c = rgb("RoofingTiles013A")
rows, cols = 8, 4
rh, cw = 1024 // rows, 1024 // cols
shade = np.zeros((1024, 1024), np.float32)
yy, xx = np.mgrid[0:1024, 0:1024]
for r in range(rows):
    off = (cw // 2) if r % 2 else 0
    for k in range(cols):
        tone = 0.80 + 0.40 * rng.random()
        y0, x0 = r * rh, k * cw + off
        ys = np.arange(rh)
        grad = 0.65 + 0.55 * (ys / rh) ** 1.5           # darker under the overlap, lit lower edge
        block = (tone * grad)[:, None] * np.ones((1, cw), np.float32)
        block[:, :6] *= 0.35                           # vertical joint
        block[-10:, :] *= 0.30                         # shadow gap below the row
        for dx in range(cw):
            shade[y0:y0 + rh, (x0 + dx) % 1024] = block[:, dx]
slate = np.clip(c * 1.6 + 0.04, 0, 1) * shade[..., None]
save("roof_slate", slate)

# dark tiles: the top-left half = 6 of the 12 tiles across; grout from the displacement map
d = disp("Tiles138")
lo, hi = np.percentile(d, 1), np.percentile(d, 60)
dn = np.clip((d - lo) / (hi - lo), 0, 1)
tiles = np.clip(rgb("Tiles138") * 1.3, 0, 1) * (0.35 + 0.8 * dn)[..., None]
save("tiles_dark", crop(tiles, 512))

# rust plates: hue moved from red-orange to brown/ochre
save("rust_plates", shift_hue(rgb("MetalPlates011"), 12))

# chain-link: a diamond lattice (period divides 1024) over the Fence007A colour map
size = 1024
P = 128.0
yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
t = 22.0  # wire thickness (perpendicular), px in the 1K source
d1 = np.abs(((xx + yy + P / 2) % P) - P / 2) / np.sqrt(2)
d2 = np.abs(((xx - yy + P / 2) % P) - P / 2) / np.sqrt(2)
wire = (np.minimum(d1, d2) < t / 2).astype(np.uint8) * 255
Image.fromarray(wire, "L").save(f"{OUT}/chainlink_opacity.png")
# make the colour flat-ish so Fence007A's own square grid lines do not interfere
c = rgb("Fence007A")
blur = np.asarray(Image.fromarray((c * 255).astype(np.uint8)).resize((64, 64), Image.BILINEAR).resize((size, size), Image.BICUBIC), dtype=np.float32) / 255.0
save("chainlink", 0.5 * c + 0.5 * blur)
