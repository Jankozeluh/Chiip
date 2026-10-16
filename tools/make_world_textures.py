"""
make_world_textures.py - paints Chiip's map textures the way the crew is painted (D-140).

    ~/miniconda3/envs/chiip/bin/python -I tools/make_world_textures.py [--out <folder>] [names...]

The crew (tools/modelgen, D-054) is flat colour from 16-shade palette ramps, with a little
+-1 shade grain, a darker rim along edges and simple pixel patterns (webbing, ribs, planks).
Photo textures, even made retro, look busier and more realistic next to it, so every map
texture is drawn here instead: a base shade on one of the same ramps (tools/concept/spritegen.py
and the prop ramps in tools/modelgen/props.py), a pattern that says what the surface is (boards,
blocks, panels, tiles, ribs, gravel) with one-texel joints, and only a little grain.

A texture is 64 x 64 and covers 64 TrenchBroom units (1.63 m), like before, so every built map
keeps its texture scale. Deterministic: the same files on every run. Writes
assets/textures/<name>.png (or into --out for comparisons), a .import beside a new file and, for a
new set texture, its world-triplanar material in assets/materials/<set>/. The chain-link's and the
glass's special materials (.tres next to their PNG) are kept as they are.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'modelgen'))
import props  # noqa: E402  (the prop ramps: rust, safety, leaf, dirt, cardboard, concrete, teal)
from paint import concept  # noqa: E402  (the crew's ramps: grey, charcoal, olive, moss, stone, wood...)

N = 64
TEXTURES = os.path.join(ROOT, 'assets', 'textures')

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}.png"

[params]

compress/mode=0
mipmaps/generate=true
mipmaps/limit=-1
detect_3d/compress_to=0
"""


def ramp(name):
    """the 16 shades (sRGB bytes) of a crew or prop ramp."""
    if name in props.RAMPS:
        return props.RAMPS[name].astype(np.float32)
    i = concept.RAMP_ID[name]
    return concept.PAL8[i * 16:(i + 1) * 16].astype(np.float32)


class Canvas:
    """a 64 x 64 grid of shades (floats) on one ramp, plus per-texel ramp overrides."""

    def __init__(self, ramp_name, base, seed, mute=0.0):
        self.mute = mute
        self.rng = np.random.default_rng(seed)
        self.shade = np.full((N, N), float(base))
        self.ramp = np.full((N, N), ramp_name, dtype=object)
        self.alpha = None           # 0..255 per texel for see-through textures (chain-link, glass)
        y, x = np.mgrid[0:N, 0:N]
        self.x, self.y = x, y

    def grain(self, amount):
        """the crew's speckle: amount of the texels one shade lighter or darker."""
        r = self.rng.random((N, N))
        self.shade += 1.0 * (r < amount / 2) - 1.0 * ((r >= amount / 2) & (r < amount))

    def patches(self, cell, amount, strength=1.0):
        """large soft unevenness: cells of `cell` texels, `amount` of them a shade off (tiles)."""
        k = N // cell
        r = self.rng.random((k, k))
        delta = strength * ((r > 1 - amount / 2) * 1.0 - (r < amount / 2) * 1.0)
        self.shade += np.kron(delta, np.ones((cell, cell)))

    def image(self):
        out = np.zeros((N, N, 3), np.uint8)
        idx = np.clip(np.round(self.shade), 0, 15).astype(int)
        for name in set(self.ramp.ravel()):
            sel = self.ramp == name
            out[sel] = ramp(name)[idx[sel]]
        if self.mute > 0:           # toward grey, like the crew's muted kit: big surfaces stay calm
            rgb = out.astype(np.float32)
            grey = (rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
            out = np.clip(rgb * (1 - self.mute) + grey * self.mute, 0, 255).astype(np.uint8)
        if self.alpha is not None:
            out = np.dstack([out, self.alpha.astype(np.uint8)])
        return out


def wrap(v):
    return v % N


# ---------------------------------------------------------------- pattern helpers
def running_bond(c, w, h, mortar=-3, face=(-1, 1), offset_rows=True, top_light=1, bottom_dark=1):
    """bricks or blocks w x h texels in a running bond, one-texel joints."""
    rows = c.y // h
    shift = np.where(offset_rows & (rows % 2 == 1), w // 2, 0)
    cols = (c.x + shift) // w
    lx, ly = (c.x + shift) % w, c.y % h
    ids = rows * 97 + cols
    r = (np.vectorize(lambda i: (i * 2654435761) % 1000)(ids)) / 1000.0
    c.shade += np.where(r < 0.3, face[0], np.where(r > 0.75, face[1], 0))
    c.shade += top_light * (ly == 1) - bottom_dark * (ly == h - 1)
    joint = (lx == 0) | (ly == 0)
    c.shade = np.where(joint, c.shade + mortar, c.shade)
    return joint


def grid_joints(c, size, line=-2, face=1):
    """square tiles or slabs `size` texels across with one-texel joints, faces a shade apart."""
    ids = (c.y // size) * 31 + c.x // size
    r = (np.vectorize(lambda i: (i * 40503 + 7) % 100)(ids)) / 100.0
    c.shade += np.where(r < 0.33, -face, np.where(r > 0.7, face, 0))
    joint = (c.x % size == 0) | (c.y % size == 0)
    c.shade = np.where(joint, c.shade + line, c.shade)


def boards(c, height, gap=-3, end_every=None, streaks=0.12, horizontal=True):
    """boards `height` texels wide with dark gaps, staggered end joints and a few grain streaks."""
    across = c.y if horizontal else c.x
    along = c.x if horizontal else c.y
    board = across // height
    r = c.rng.random(N // height + 1)
    c.shade += np.where(r[board] < 0.33, -1, np.where(r[board] > 0.7, 1, 0))
    gapmask = across % height == 0
    if end_every:
        offset = (board * 23) % end_every
        gapmask |= (along + offset) % end_every == 0
    streak_rows = c.rng.random((N, N // 8 + 1)) < streaks
    streak = streak_rows[across, along // 8] & (across % height != 0)
    c.shade -= 1.0 * streak
    c.shade = np.where(gapmask, c.shade + gap, c.shade)


def voronoi(c, count, gap=-3, face=(-1, 1), seed=0, edge=1.2):
    """irregular stones or cobbles: `count` cells on a tiling torus, dark gaps between them."""
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * N
    best = np.full((N, N), 1e9)
    second = np.full((N, N), 1e9)
    owner = np.zeros((N, N), int)
    for i, (px, py) in enumerate(pts):
        for ox in (-N, 0, N):
            for oy in (-N, 0, N):
                d = np.hypot(c.x - px - ox, c.y - py - oy)
                closer = d < best
                second = np.where(closer, best, np.minimum(second, d))
                owner = np.where(closer, i, owner)
                best = np.where(closer, d, best)
    r = rng.random(count)
    c.shade += np.where(r[owner] < 0.33, face[0], np.where(r[owner] > 0.7, face[1], 0))
    # light on the side facing up-left, the gap's rim darker: chunky, like a bevel
    c.shade = np.where(second - best < edge, c.shade + gap, c.shade)
    return owner


def ribs(c, period=4, light=1, dark=-1, vertical=True):
    """corrugation: a light and a dark band per rib."""
    a = (c.x if vertical else c.y) % period
    c.shade += np.where(a == 0, light, np.where(a == period // 2, dark, 0))


def panels(c, size, seam=-2, rivets=True, face=1):
    grid_joints(c, size, line=seam, face=face)
    if rivets:
        lx, ly = c.x % size, c.y % size
        dot = ((lx == 2) | (lx == size - 2)) & ((ly == 2) | (ly == size - 2))
        c.shade = np.where(dot, c.shade - 2, c.shade)


def specks(c, amount, lo=-2, hi=2, size=1, ramp_name=None):
    """scattered pebbles or aggregate: `amount` of the cells (size x size texels) a few shades off."""
    k = N // size
    r = c.rng.random((k, k))
    v = c.rng.integers(lo, hi + 1, (k, k))
    mask = np.kron((r < amount).astype(int), np.ones((size, size), int)).astype(bool)
    val = np.kron(v, np.ones((size, size), int))
    c.shade = np.where(mask, c.shade + val, c.shade)
    if ramp_name:
        c.ramp = np.where(mask, ramp_name, c.ramp)


# ---------------------------------------------------------------- the textures
def concrete_floor(c):
    c.grain(0.10)
    specks(c, 0.03, -1, 1, size=2)
    c.shade = np.where((c.x == 0) | (c.y == 0), c.shade - 1, c.shade)       # one slab joint per 1.6 m


def concrete_worn(c):
    c.grain(0.12)
    specks(c, 0.05, -1, 1, size=2)
    c.shade = np.where(c.y % 32 == 0, c.shade - 1, c.shade)                 # formwork seams
    tie = ((c.x % 32 == 8) | (c.x % 32 == 24)) & ((c.y % 32 == 8) | (c.y % 32 == 24))
    c.shade = np.where(tie, c.shade - 3, c.shade)                           # form-tie holes
    stain = c.rng.random((N // 8, N // 8)) < 0.15
    c.shade -= np.kron(stain.astype(float), np.ones((8, 8))) * (c.y % 8 > 3)


def plaster(c):
    c.grain(0.07)
    specks(c, 0.02, -1, 1, size=2)


def stone_blocks(c):
    running_bond(c, 32, 16, mortar=-3)
    c.grain(0.10)


def blocks(c):
    running_bond(c, 16, 8, mortar=-2)
    c.grain(0.08)


def bricks(c):
    joint = running_bond(c, 12, 6, mortar=0, face=(-1, 1))
    c.ramp = np.where(joint, 'concrete', c.ramp)              # light mortar between muted brown bricks
    c.shade = np.where(joint, 9.0, c.shade)
    c.grain(0.08)


def rubble(c):
    voronoi(c, 18, gap=-3, seed=5, edge=1.4)
    c.grain(0.08)


def cobbles(c):
    voronoi(c, 52, gap=-2, seed=9, edge=1.1)
    c.grain(0.06)


def slabs(c):
    grid_joints(c, 32, line=-2)
    c.grain(0.08)


def asphalt(c):
    c.grain(0.10)
    specks(c, 0.06, 1, 2)


def gravel(c):
    specks(c, 0.30, -1, 1, size=2)
    specks(c, 0.03, -2, 1, size=2)
    c.grain(0.06)


def dirt(c):
    specks(c, 0.25, -1, 1, size=2)
    specks(c, 0.05, -2, 1, size=2)
    c.grain(0.10)


def grass(c):
    specks(c, 0.3, -1, 0, size=2)
    # short vertical blades: a light texel over a dark one
    r = c.rng.random((N, N))
    blade = r < 0.12
    c.shade = np.where(blade, c.shade + 2, c.shade)
    c.shade = np.where(np.roll(blade, 1, 0), c.shade - 1, c.shade)


def rock_moss(c):
    owner = voronoi(c, 9, gap=-3, seed=21, edge=1.6)
    moss = (np.vectorize(lambda o: (o * 7) % 3 == 0)(owner)) & (c.rng.random((N, N)) < 0.7)
    c.ramp = np.where(moss, 'leaf', c.ramp)
    c.grain(0.10)


def bark(c):
    wobble = (np.sin(c.y / 5.0) * 1.5).astype(int)
    furrow = (c.x + wobble) % 7 == 0
    c.shade = np.where(furrow, c.shade - 3, c.shade)
    c.shade = np.where((c.x + wobble) % 7 == 1, c.shade + 1, c.shade)
    c.grain(0.12)


def wood_planks(c):
    boards(c, 10, gap=-3, streaks=0.10)
    c.grain(0.06)


def wood_siding(c):
    boards(c, 10, gap=-2, streaks=0.08)
    c.shade = np.where(c.y % 10 == 1, c.shade - 2, c.shade)                  # the shadow under each lap
    c.shade = np.where(c.y % 10 == 9, c.shade + 1, c.shade)


def planks_old(c):
    boards(c, 12, gap=-4, end_every=40, streaks=0.18)
    nail = ((c.x % 40 == 3) | (c.x % 40 == 37)) & (c.y % 12 == 6)
    c.shade = np.where(nail, c.shade - 3, c.shade)
    c.grain(0.10)


def wood_floor(c):
    boards(c, 6, gap=-2, end_every=32, streaks=0.08)
    c.grain(0.05)


def parquet(c):
    # basket weave: 16 x 16 squares of four 4-texel strips, turning every square
    sq = ((c.x // 16) + (c.y // 16)) % 2 == 0
    strip = np.where(sq, c.y % 4, c.x % 4)
    c.shade = np.where(strip == 0, c.shade - 2, c.shade)
    ids = np.where(sq, (c.y // 4) * 7 + c.x // 16, (c.x // 4) * 7 + c.y // 16)
    c.shade += np.where(ids % 3 == 0, -1, np.where(ids % 3 == 1, 1, 0))
    c.grain(0.05)


def metal_plates(c):
    panels(c, 32, seam=-3)
    c.grain(0.08)


def corrugated(c):
    ribs(c, 4)
    c.shade = np.where(c.y == 0, c.shade - 1, c.shade)
    c.grain(0.06)


def diamond_plate(c):
    lug_a = ((c.x % 8 == 2) & (c.y % 8 >= 1) & (c.y % 8 <= 3)) | ((c.x % 8 == 3) & (c.y % 8 >= 2) & (c.y % 8 <= 4))
    lug_b = (((c.x + 4) % 8 == 2) & ((c.y + 4) % 8 >= 1) & ((c.y + 4) % 8 <= 2)) | (((c.x + 4) % 8 >= 1) & ((c.x + 4) % 8 <= 3) & ((c.y + 4) % 8 == 2))
    c.shade = np.where(lug_a | lug_b, c.shade + 2, c.shade)
    c.shade = np.where(np.roll(lug_a | lug_b, -1, 0) & ~(lug_a | lug_b), c.shade - 1, c.shade)
    c.grain(0.05)


def grate(c):
    bar = (c.x % 8 <= 1) | (c.y % 8 <= 1)
    c.shade = np.where(bar, c.shade, 2.0)
    c.shade = np.where((c.x % 8 == 0) | (c.y % 8 == 0), c.shade + 1, c.shade)


def perforated(c):
    hole = ((c.x % 6 == 2) & (c.y % 6 == 2)) | (((c.x + 3) % 6 == 2) & ((c.y + 3) % 6 == 2))
    c.shade = np.where(hole, 2.0, c.shade)
    c.shade = np.where(np.roll(hole, 1, 0) & ~hole, c.shade + 1, c.shade)
    c.shade = np.where((c.x == 0) | (c.y == 0), c.shade - 2, c.shade)
    c.grain(0.05)


def rust_plates(c):
    panels(c, 32, seam=-3)
    specks(c, 0.2, -1, 1, size=2)
    c.grain(0.10)


def tiles(size, grout=-3):
    def f(c):
        grid_joints(c, size, line=grout, face=1)
        c.grain(0.04)
    return f


def checker(c):
    dark = ((c.x // 16) + (c.y // 16)) % 2 == 0
    c.ramp = np.where(dark, 'charcoal', c.ramp)
    c.shade = np.where(dark, 4.0, 11.0)
    c.shade = np.where((c.x % 16 == 0) | (c.y % 16 == 0), 7.0, c.shade)
    c.grain(0.04)


def terrazzo(c):
    specks(c, 0.10, -4, -2)
    specks(c, 0.05, 1, 2)
    specks(c, 0.03, -1, 1, ramp_name='olive')
    grid_joints(c, 32, line=-1, face=0)


def ceiling_tiles(c):
    grid_joints(c, 32, line=-3, face=0)
    dots = (c.x % 4 == 2) & (c.y % 4 == 2) & (c.x % 32 > 2) & (c.y % 32 > 2)
    c.shade = np.where(dots & (c.rng.random((N, N)) < 0.5), c.shade - 1, c.shade)


def roof_slate(c):
    rows = c.y // 8
    shift = np.where(rows % 2 == 1, 8, 0)
    lx, ly = (c.x + shift) % 16, c.y % 8
    ids = rows * 13 + (c.x + shift) // 16
    c.shade += np.where(ids % 3 == 0, -1, np.where(ids % 3 == 1, 1, 0))
    c.shade = np.where(ly >= 6, c.shade - 2, c.shade)                       # the overlap's shadow
    c.shade = np.where(lx == 0, c.shade - 2, c.shade)
    c.grain(0.06)


def hazard(c):
    stripe = ((c.x + c.y) % 16) < 7
    c.ramp = np.where(stripe, 'safety', c.ramp)
    c.shade = np.where(stripe, 9.0, 3.0)
    c.grain(0.10)
    chip = np.kron(c.rng.random((16, 16)) < 0.08, np.ones((4, 4))).astype(bool)
    c.ramp = np.where(chip & stripe, 'charcoal', c.ramp)
    c.shade = np.where(chip & stripe, 4.0, c.shade)


def chainlink(c):
    # a diamond lattice of wire, 8 diamonds across, the rest see-through (1-bit alpha)
    d1 = (c.x + c.y) % 8
    d2 = (c.x - c.y) % 8
    wire = (d1 == 0) | (d2 == 0)
    c.shade = np.where((c.x + c.y) % 16 < 8, c.shade + 1, c.shade)
    c.alpha = np.where(wire, 255, 0)


def glass(c):
    # see-through grey glass with two light streaks; alpha blended (interior/glass.tres)
    streak = ((c.x + c.y) % 64 < 3) | (((c.x + c.y) + 20) % 64 < 1)
    c.shade = np.where(streak, 14.0, c.shade)
    c.alpha = np.where(streak, 130, 70)


def floor_line(c):
    concrete_floor(c)
    line = (c.x >= 29) & (c.x <= 34)
    c.ramp = np.where(line, 'safety', c.ramp)
    c.shade = np.where(line, 8.0 + (c.rng.random((N, N)) < 0.15) * -1, c.shade)


# name: (ramp, base shade, painter[, mute]). Neutral like the crew's kit (D-031, D-063); wood and
# the safety yellow are the warm accents, greens stay olive and moss. mute (0..1) takes a ramp's
# colour toward grey: wood on a whole wall is calmer than on a gun's stock.
TABLE = {
    'concrete_floor': ('concrete', 8, concrete_floor),
    'plaster_wall': ('stone', 11, plaster),
    'painted_plaster': ('stone', 12, plaster),
    'stone_grey': ('stone', 8, stone_blocks),
    'gravel_grey': ('grey', 8, gravel),
    'metal_plates': ('grey', 6, metal_plates),
    'wood_planks': ('wood', 7, wood_planks, 0.5),
    'bricks_red': ('cardboard', 6, bricks, 0.3),
    'industrial/concrete_worn': ('concrete', 7, concrete_worn),
    'industrial/corrugated_grey': ('grey', 8, corrugated),
    'industrial/corrugated_green': ('olive', 7, corrugated, 0.0),
    'industrial/corrugated_rust': ('cardboard', 7, corrugated, 0.55),
    'industrial/corrugated_teal': ('teal', 7, corrugated),
    'industrial/diamond_plate': ('grey', 7, diamond_plate),
    'industrial/grate': ('grey', 8, grate),
    'industrial/perforated': ('grey', 7, perforated),
    'industrial/rust_plates': ('cardboard', 6, rust_plates, 0.5),
    'industrial/hazard_stripes': ('charcoal', 3, hazard),
    'industrial/floor_line': ('concrete', 8, floor_line),
    'industrial/chainlink': ('grey', 9, chainlink),
    'interior/glass': ('concrete', 11, glass),
    'urban/asphalt': ('charcoal', 6, asphalt),
    'urban/blocks_grey': ('concrete', 9, blocks),
    'urban/cobbles': ('stone', 9, cobbles),
    'urban/slabs': ('concrete', 9, slabs),
    'urban/rubble_wall': ('stone', 8, rubble),
    'urban/roof_slate': ('charcoal', 6, roof_slate),
    'urban/plaster_olive': ('olive', 10, plaster),
    'urban/wood_siding': ('wood', 5, wood_siding, 0.55),
    'interior/tiles_white': ('stone', 12, tiles(16)),
    'interior/tiles_dark': ('charcoal', 6, tiles(16, -2)),
    'interior/tiles_checker': ('stone', 11, checker),
    'interior/terrazzo': ('stone', 11, terrazzo),
    'interior/ceiling_tiles': ('stone', 12, ceiling_tiles),
    'interior/wood_floor_dark': ('wood', 5, wood_floor, 0.55),
    'interior/parquet': ('wood', 8, parquet, 0.5),
    'interior/planks_old': ('dirt', 7, planks_old),
    'nature/grass': ('leaf', 7, grass, 0.3),
    'nature/dirt': ('dirt', 6, dirt),
    'nature/rock_moss': ('stone', 8, rock_moss),
    'nature/bark': ('dirt', 6, bark),
}


CSG_MATERIAL = """[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="res://assets/textures/{name}.png" id="albedo"]

[resource]
albedo_texture = ExtResource("albedo")
metallic_specular = 0.2
roughness = 1.0
uv1_scale = Vector3(0.6152, 0.6152, 0.6152)
uv1_triplanar = true
uv1_triplanar_sharpness = 20.0
uv1_world_triplanar = true
texture_filter = 4
"""


def make(name):
    ramp_name, base, painter, *rest = TABLE[name]
    c = Canvas(ramp_name, base, seed=sum(map(ord, name)), mute=rest[0] if rest else 0.0)
    painter(c)
    return c.image()


def main():
    args = sys.argv[1:]
    out = TEXTURES
    if '--out' in args:
        i = args.index('--out')
        out = args[i + 1]
        args = args[:i] + args[i + 2:]
    names = args or list(TABLE)
    for name in names:
        path = os.path.join(out, name + '.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(make(name)).save(path, optimize=True)
        if out == TEXTURES and not os.path.exists(path + '.import'):
            with open(path + '.import', 'w') as fh:
                fh.write(IMPORT.format(name=name))
        material = os.path.join(ROOT, 'assets', 'materials', name + '.tres')
        if out == TEXTURES and '/' in name and not os.path.exists(material):
            # a set texture also gets a world-triplanar material for CSG maps and props (kit test)
            os.makedirs(os.path.dirname(material), exist_ok=True)
            with open(material, 'w') as fh:
                fh.write(CSG_MATERIAL.format(name=name))
    print(f'{len(names)} textures written to {out}')


if __name__ == '__main__':
    main()
