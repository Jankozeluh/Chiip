"""
make_kit_textures.py - draws the map kit's own textures, the ones no photo gives (D-121, D-125).

    ~/miniconda3/envs/chiip/bin/python -I tools/make_kit_textures.py

Writes into assets/textures/ (then run Godot's import, CLAUDE.md):
    industrial/hazard_stripes.png   worn diagonal safety-yellow and charcoal stripes, for edges
                                    and trims in small doses (D-127)
    industrial/floor_line.png       the base concrete floor with a painted yellow line along it
    industrial/corrugated_rust.png  industrial/corrugated_grey recoloured into a rusty brown (kept
    industrial/corrugated_teal.png  off the team red's hue) and into the props' grey-green paint, so
                                    containers come in four colours with the same ribs
    interior/glass.png + glass.tres see-through grey glass with two streaks (alpha blended), for
                                    func_glass brushes
and a world-triplanar material for each in assets/materials/ (for CSG maps and props).

64 x 64 like every map texture, drawn from the prop palette's ramps (tools/modelgen/props.py)
so the yellow is the same as on the kit's props. Deterministic: the same files every run.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'modelgen'))
import props  # noqa: E402  (the prop palette)

SIZE = 64
TEXTURES = os.path.join(ROOT, 'assets', 'textures')

# The same import settings tools/make_retro_texture.gd writes: lossless, mipmaps, never compressed.
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

GLASS_MATERIAL = """[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="res://assets/textures/interior/glass.png" id="albedo"]

[resource]
transparency = 1
albedo_texture = ExtResource("albedo")
metallic_specular = 0.6
roughness = 0.25
texture_filter = 4
"""


CSG_MATERIAL = """[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="res://assets/textures/{name}.png" id="albedo"]

[resource]
albedo_texture = ExtResource("albedo")
{extra}uv1_scale = Vector3(0.6152, 0.6152, 0.6152)
uv1_triplanar = true
uv1_triplanar_sharpness = 20.0
uv1_world_triplanar = true
texture_filter = 4
"""


def ramp(name):
    return props.RAMPS[name].astype(np.float32)


def save(image, name):
    path = os.path.join(TEXTURES, name + '.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(image).save(path, optimize=True)
    if not os.path.exists(path + '.import'):          # keep the settings Godot completed
        with open(path + '.import', 'w') as fh:
            fh.write(IMPORT.format(name=name))
    print('wrote', path)


def grain(rng, shape, amount):
    """-1, 0 or +1 shade steps at random, `amount` of the pixels changed."""
    r = rng.random(shape)
    return (r < amount / 2) * 1 - ((r >= amount / 2) & (r < amount)) * 1


def hazard_stripes():
    rng = np.random.default_rng(11)
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    stripe = ((x + y) % 16) < 7                               # 7 yellow, 9 dark: period 16 tiles in 64
    yellow, dark = ramp('safety'), dark_ramp()
    shade = 8 + grain(rng, (SIZE, SIZE), 0.35)
    wear = rng.random((SIZE // 4, SIZE // 4)).repeat(4, 0).repeat(4, 1) < 0.12   # chipped paint patches
    img = np.where(stripe[..., None], yellow[np.clip(shade, 0, 15)], dark[np.clip(shade - 4, 0, 15)])
    img = np.where((wear & stripe)[..., None], dark[np.clip(shade - 2, 0, 15)], img)
    return img.astype(np.uint8)


def dark_ramp():
    """the concept palette's charcoal ramp (the props' dark metal)."""
    from paint import concept
    return concept.PAL8[concept.RAMP_ID['charcoal'] * 16:(concept.RAMP_ID['charcoal'] + 1) * 16].astype(np.float32)


def floor_line():
    base = np.asarray(Image.open(os.path.join(TEXTURES, 'concrete_floor.png')).convert('RGB')).astype(np.float32)
    rng = np.random.default_rng(12)
    yellow = ramp('safety')
    line = np.zeros((SIZE, SIZE), bool)
    line[:, 29:35] = True                                     # a 6-pixel line (15 cm) down the middle
    shade = 7 + grain(rng, (SIZE, SIZE), 0.4)
    worn = rng.random((SIZE, SIZE)) < 0.15                    # concrete showing through
    paint = yellow[np.clip(shade, 0, 15)]
    img = np.where((line & ~worn)[..., None], paint, base)
    return img.astype(np.uint8)


def recolour(source, ramp_name, low, high, grey_mix):
    """`source`'s brightness mapped onto shades low..high of a prop ramp, mixed with grey by
    `grey_mix` (0..1) to keep the colour muted."""
    src = np.asarray(Image.open(os.path.join(TEXTURES, source + '.png')).convert('RGB')).astype(np.float32) / 255.0
    lum = src @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    t = (lum - lum.min()) / max(float(lum.max() - lum.min()), 1e-6)
    shades = np.clip(np.round(low + t * (high - low)), 0, 15).astype(int)
    colour = ramp(ramp_name)[shades]
    grey = (colour @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None].repeat(3, -1)
    return np.clip(colour * (1 - grey_mix) + grey * grey_mix, 0, 255).astype(np.uint8)


def glass():
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    tint = np.array([150, 160, 156], np.float32)              # a neutral grey-green, not blue
    img = np.zeros((SIZE, SIZE, 4), np.uint8)
    img[..., :3] = tint
    img[..., 3] = 70                                          # about 27 % opaque
    streak = (((x + y) % 64) < 3) | ((((x + y) + 20) % 64) < 1)
    img[streak, :3] = (205, 212, 208)
    img[streak, 3] = 130
    return img


def main():
    save(hazard_stripes(), 'industrial/hazard_stripes')
    save(floor_line(), 'industrial/floor_line')
    save(recolour('industrial/corrugated_grey', 'cardboard', 3, 11, 0.3), 'industrial/corrugated_rust')
    save(recolour('industrial/corrugated_grey', 'teal', 4, 12, 0.2), 'industrial/corrugated_teal')
    save(glass(), 'interior/glass')
    with open(os.path.join(TEXTURES, 'interior', 'glass.tres'), 'w') as fh:
        fh.write(GLASS_MATERIAL)
    print('wrote', os.path.join(TEXTURES, 'interior', 'glass.tres'))
    # A world-triplanar material each, like every library texture (for CSG maps and props).
    for name, extra in (('industrial/hazard_stripes', ''), ('industrial/floor_line', ''),
                        ('industrial/corrugated_rust', ''), ('industrial/corrugated_teal', ''),
                        ('interior/glass', 'transparency = 1\nmetallic_specular = 0.6\nroughness = 0.25\n')):
        path = os.path.join(ROOT, 'assets', 'materials', name + '.tres')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as fh:
            fh.write(CSG_MATERIAL.format(name=name, extra=extra or 'metallic_specular = 0.2\nroughness = 1.0\n'))
        print('wrote', path)


if __name__ == '__main__':
    main()
