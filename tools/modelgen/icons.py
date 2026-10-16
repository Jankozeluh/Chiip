"""
icons.py - the arsenal's icons, rendered from the generated models (D-054, M7).

Each item is drawn headless with numpy and Pillow, as an orthographic side view from +X
(the barrel points to the right, +Y is up; the vests face +X, so their side view is the
front). Two icons per item, written to assets/ui/weapons/:
  <id>.png       buy-menu icon, 128 x 48, each triangle in its painted colour with a simple
                 light, a 1 px dark outline, transparent background, hard edges
  <id>_kill.png  kill-feed icon, 16 px tall and at most 64 wide: a white silhouette with a
                 1 px black outline and no anti-aliasing
Both are drawn at 4 times the size and boxed down, then the alpha is thresholded, so edges
stay crisp. The guns are drawn at one scale (at most 150 px per metre) so their sizes can
be compared; grenades and the kit get up to 300 px per metre, or they would be a dot.
contact_sheets() writes two overview images outside the project for checking by eye.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

BUY_SIZE = (128, 48)           # width, height
BUY_MARGIN = 3                 # empty pixels around the outline
BUY_MAX_PPM = 150              # pixels per metre, at most (a pistol stays small)
SMALL_MAX_PPM = 300            # grenades and the kit
SMALL = ('frag', 'flashbang', 'smoke', 'defuse_kit')
KILL_HEIGHT = 16
KILL_MAX_WIDTH = 64
KILL_MIN_WIDTH = 24
KILL_PPM = 54
SUPERSAMPLE = 4
OUTLINE = (0x0b, 0x10, 0x17)
LIGHT = np.array([0.5, 0.75, -0.35])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

# Godot import settings for the icons: lossless, no mipmaps, clean edges.
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
detect_3d/compress_to=0
"""


def item_triangles(meshes, atlas, albedo):
    """every triangle of an item in weapon space: vertices (N, 3, 3), normals (N, 3) and the
    painted colour (N, 3, 0..1) read from the albedo at the triangle's texel centroid."""
    verts, norms, cols = [], [], []
    h, w = albedo.shape[:2]
    for pm in meshes:
        basis = pm.piece.basis()
        for tri, normals, texel in pm.triangles(atlas):
            v = pm.piece.pos + (basis @ np.asarray(tri).T).T
            n = basis @ np.mean(normals, 0)
            n = n / max(np.linalg.norm(n), 1e-9)
            tx, ty = np.mean(texel, 0)
            verts.append(v)
            norms.append(n)
            cols.append(albedo[min(max(int(ty), 0), h - 1), min(max(int(tx), 0), w - 1)] / 255.0)
    return np.array(verts), np.array(norms), np.array(cols)


def project(verts, view='side'):
    """screen x, screen y (down) and depth (larger is nearer) for every vertex, in metres.
    'side' looks from +X with the barrel to the right, 'top' from +Y."""
    x, y, z = verts[..., 0], verts[..., 1], verts[..., 2]
    if view == 'top':
        return np.stack([-z, x, y], -1)
    return np.stack([-z, -y, x], -1)


def rasterize(verts, colors, scale, size, origin, view='side', ss=SUPERSAMPLE):
    """z-buffered flat triangles at `ss` times the size. scale is pixels per metre of the final
    image; origin the screen position (metres) that lands on the top left. Returns (colour
    (H*ss, W*ss, 3), covered (H*ss, W*ss))."""
    w, h = size[0] * ss, size[1] * ss
    p = project(verts, view)
    px = (p[..., 0] - origin[0]) * scale * ss
    py = (p[..., 1] - origin[1]) * scale * ss
    depth = p[..., 2]
    zbuf = np.full((h, w), -np.inf)
    img = np.zeros((h, w, 3))
    cov = np.zeros((h, w), bool)
    for t in range(len(verts)):
        x, y, d = px[t], py[t], depth[t]
        area = (x[1] - x[0]) * (y[2] - y[0]) - (x[2] - x[0]) * (y[1] - y[0])
        if abs(area) < 1e-9:
            continue
        x0, x1 = max(int(np.floor(x.min())), 0), min(int(np.ceil(x.max())) + 1, w)
        y0, y1 = max(int(np.floor(y.min())), 0), min(int(np.ceil(y.max())) + 1, h)
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        w0 = ((x[1] - gx) * (y[2] - gy) - (x[2] - gx) * (y[1] - gy)) / area
        w1 = ((x[2] - gx) * (y[0] - gy) - (x[0] - gx) * (y[2] - gy)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        z = w0 * d[0] + w1 * d[1] + w2 * d[2]
        win = inside & (z > zbuf[y0:y1, x0:x1])
        zbuf[y0:y1, x0:x1][win] = z[win]
        img[y0:y1, x0:x1][win] = colors[t]
        cov[y0:y1, x0:x1] |= win
    return img, cov


def lit(norms, cols):
    """the painted colours with a simple light from the upper front."""
    k = 0.55 + 0.45 * np.maximum(0.0, norms @ LIGHT)
    return np.clip(cols * k[:, None], 0, 1)


def downsample(img, cov, ss=SUPERSAMPLE):
    """box-filters a supersampled render: (colour (H, W, 3) 0..1, coverage (H, W) 0..1)."""
    h, w = cov.shape[0] // ss, cov.shape[1] // ss
    c = cov.reshape(h, ss, w, ss).astype(float)
    n = c.sum((1, 3))
    rgb = (img.reshape(h, ss, w, ss, 3) * c[..., None]).sum((1, 3)) / np.maximum(n, 1)[..., None]
    return rgb, n / (ss * ss)


def outlined(rgb, opaque, outline=OUTLINE):
    """adds a 1 px outline around the opaque pixels: returns an RGBA uint8 image."""
    h, w = opaque.shape
    grown = opaque.copy()
    grown[1:, :] |= opaque[:-1, :]
    grown[:-1, :] |= opaque[1:, :]
    grown[:, 1:] |= opaque[:, :-1]
    grown[:, :-1] |= opaque[:, 1:]
    out = np.zeros((h, w, 4), np.uint8)
    out[grown, :3] = outline
    out[opaque, :3] = np.round(rgb[opaque] * 255).astype(np.uint8)
    out[grown, 3] = 255
    return out


def extents(verts, view='side'):
    """(min, max) of the screen x and y of an item, in metres."""
    p = project(verts, view)
    return p[..., 0].min(), p[..., 0].max(), p[..., 1].min(), p[..., 1].max()


def render(verts, norms, cols, scale, size, view='side', white=False):
    """one icon: the item centred on a canvas of `size`, at `scale` pixels per metre, with its
    outline, as RGBA uint8."""
    x0, x1, y0, y1 = extents(verts, view)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    origin = (cx - size[0] / 2 / scale, cy - size[1] / 2 / scale)
    colors = np.ones_like(cols) if white else lit(norms, cols)
    img, cov = rasterize(verts, colors, scale, size, origin, view)
    rgb, frac = downsample(img, cov)
    return outlined(rgb, frac >= 0.5)


def buy_icon(name, tris):
    verts, norms, cols = tris
    x0, x1, y0, y1 = extents(verts)
    room = (BUY_SIZE[0] - 2 * (BUY_MARGIN + 1), BUY_SIZE[1] - 2 * (BUY_MARGIN + 1))
    top = SMALL_MAX_PPM if name in SMALL else BUY_MAX_PPM
    scale = min(top, room[0] / (x1 - x0), room[1] / (y1 - y0))
    return render(verts, norms, cols, scale, BUY_SIZE)


def kill_icon(name, tris):
    verts, norms, cols = tris
    x0, x1, y0, y1 = extents(verts)
    wm, hm = x1 - x0, y1 - y0
    scale = KILL_PPM
    if wm * scale < KILL_MIN_WIDTH - 2:                  # small items are scaled up
        scale = (KILL_MIN_WIDTH - 2) / wm
    scale = min(scale, (KILL_MAX_WIDTH - 2) / wm, (KILL_HEIGHT - 2) / hm)
    width = int(min(KILL_MAX_WIDTH, max(KILL_MIN_WIDTH, np.ceil(wm * scale) + 2)))
    return render(verts, norms, cols, scale, (width, KILL_HEIGHT), white=True)


def write_png(rgba, path):
    Image.fromarray(rgba, 'RGBA').save(path, optimize=True)
    if not os.path.exists(path + '.import'):
        with open(path + '.import', 'w') as fh:
            fh.write(IMPORT)


def write_icons(items, out_dir, gear_only=()):
    """writes both icons of every item (the kill icon only if the item isn't in `gear_only`).
    `items` maps a name to its (verts, norms, cols) triangles. Returns {name: (buy, kill|None)}."""
    os.makedirs(out_dir, exist_ok=True)
    out = {}
    for name, tris in items.items():
        buy = buy_icon(name, tris)
        write_png(buy, os.path.join(out_dir, f'{name}.png'))
        kill = None
        if name not in gear_only:
            kill = kill_icon(name, tris)
            write_png(kill, os.path.join(out_dir, f'{name}_kill.png'))
        out[name] = (buy, kill)
    return out


def contact_sheets(items, icons, icons_path, guns_path):
    """two overview images for checking by eye (keep them out of the project): every icon on
    mid grey at 3x, and every item side by side at 300 px per metre (side view, then top)."""
    grey = np.array([120, 120, 120, 255], np.uint8)
    cell_w, cell_h = (BUY_SIZE[0] + 70 + 8), BUY_SIZE[1] + 8
    cols = 2
    names = list(icons)
    rows = -(-len(names) // cols)
    sheet = Image.new('RGBA', (cell_w * cols, cell_h * rows), tuple(grey))
    for i, name in enumerate(names):
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        buy, kill = icons[name]
        sheet.alpha_composite(Image.fromarray(buy, 'RGBA'), (x + 4, y + 4))
        if kill is not None:
            sheet.alpha_composite(Image.fromarray(kill, 'RGBA'), (x + BUY_SIZE[0] + 8, y + 12))
        ImageDraw.Draw(sheet).text((x + BUY_SIZE[0] + 8, y + 32), name, fill=(240, 240, 240, 255))
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.convert('RGB').save(icons_path)

    scale, pad, max_w = 300.0, 12, 1800
    sections = []
    for view in ('side', 'top'):
        tiles = []
        for name, (verts, norms, cols_) in items.items():
            x0, x1, y0, y1 = extents(verts, view)
            size = (int(np.ceil((x1 - x0) * scale)) + 2 * pad, int(np.ceil((y1 - y0) * scale)) + 2 * pad)
            origin = (x0 - pad / scale, y0 - pad / scale)
            img, cov = rasterize(verts, lit(norms, cols_), scale, size, origin, view, ss=2)
            rgb, frac = downsample(img, cov, ss=2)
            tile = np.zeros(rgb.shape[:2] + (4,), np.uint8)
            tile[..., :3] = np.round(rgb * 255)
            tile[..., 3] = np.round(frac * 255)
            t = Image.fromarray(tile, 'RGBA')
            ImageDraw.Draw(t).text((2, 2), name, fill=(255, 255, 255, 255))
            tiles.append(t)
        sections.append(_flow(tiles, max_w))
    sheet = Image.new('RGBA', (max_w, sum(s.height for s in sections)), (88, 92, 98, 255))
    y = 0
    for sec in sections:
        sheet.alpha_composite(sec, (0, y))
        y += sec.height
    sheet.convert('RGB').save(guns_path)


def _flow(tiles, max_w):
    """tiles laid out left to right in rows no wider than max_w, on mid grey."""
    spots, x, y, line_h = [], 0, 0, 0
    for t in tiles:
        if x + t.width > max_w:
            x, y, line_h = 0, y + line_h, 0
        spots.append((t, x, y))
        x += t.width
        line_h = max(line_h, t.height)
    sheet = Image.new('RGBA', (max_w, y + line_h), (88, 92, 98, 255))
    for t, x, y in spots:
        sheet.alpha_composite(t, (x, y))
    return sheet
