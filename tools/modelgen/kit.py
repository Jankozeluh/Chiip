"""
kit.py - writes the map kit's props (D-122): for every prop in props.py its glTF model and
texture, a Godot scene with collision, and one func_godot entity file listing them all.

Run through modelgen.py:
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py props            # every prop
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py props crate_wood # just these

Writes:
    assets/models/props/<name>.glb + <name>_albedo.png      the model (Godot imports it)
    maps/kit/props/prop_<name>.tscn (lamps: maps/kit/lights/<name>.tscn)
        a StaticBody3D (or a Node3D for decoration) with the model, box collision shapes
        from the part list and a "surface" metadata entry for footsteps and impacts
    maps/fgd/chiip_kit_fgd.tres
        a FuncGodotFGDFile with a point class per prop: classname, description, the scene
        to place and the .glb TrenchBroom shows. Always lists every prop, also when only some
        were rebuilt.
Then run Godot's import (CLAUDE.md) so the game sees the new files.
"""
import math
import os

import numpy as np

import props
import props_urban  # noqa: F401  (registers the urban, interior, nature and debris props)
from geometry import Atlas, PieceMesh
from gltf import Glb
from paint import Painter

PROJECT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
MODEL_DIR = 'assets/models/props'
PROP_SCENE_DIR = 'maps/kit/props'
LIGHT_SCENE_DIR = 'maps/kit/lights'
FGD_PATH = 'maps/fgd/chiip_kit_fgd.tres'
LIGHT_SCRIPT = 'res://maps/kit/kit_light.gd'
# TrenchBroom units per metre (1 unit = 1 inch, like CS: maps/chiip_map_settings.tres).
TB_SCALE = 39.37
ATLAS_WIDTHS = (128, 256, 512)

# Godot import settings for a prop's .glb: no automatic LODs (simplifying a 100-triangle
# box model only breaks its shape) and nothing else changed.
GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

meshes/generate_lods=false
"""

TEXTURE_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=true
process/fix_alpha_border=false
detect_3d/compress_to=0
"""

# StaticBody3D collision layers (systems/physics_layers.gd): WORLD blocks movement, bullets
# and sight; layer 3 (value 4, "bots") blocks only movement (D-123).
LAYERS = {'world': 1, 'seethrough': 4}


def build(spec):
    """pieces, meshes, atlas and painted texture of one prop."""
    pieces = spec['build']()
    density = spec['density']
    widest = 0.0
    for p in pieces:            # the widest side decides the atlas width (and maybe the density)
        pm = PieceMesh(p, Atlas(), density)
        widest = max(widest, max(s['size'][0] for s in pm.sides), max(s['size'][1] for s in pm.sides))
    width = next((w for w in ATLAS_WIDTHS if widest + 2 <= w), ATLAS_WIDTHS[-1])
    if widest + 2 > width:
        density *= (width - 2) / (widest + 2)
    atlas = Atlas(width)
    meshes = [PieceMesh(p, atlas, density) for p in pieces]
    atlas.pack()
    albedo, mask = Painter({}, 'skin_l', seed=sum(map(ord, spec['name'])), materials=props.MATERIALS,
                           ramps=props.RAMPS).paint(meshes, atlas)
    return dict(spec=spec, pieces=pieces, meshes=meshes, atlas=atlas, albedo=albedo, mask=mask, density=density)


def triangles(model):
    """yields (piece, points (3,3), normals (3,3), uv (3,2)) in prop space."""
    atlas = model['atlas']
    tw, th = atlas.width, atlas.height()
    for pm in model['meshes']:
        p = pm.piece
        basis = p.basis()
        for tri, normals, texel in pm.triangles(atlas):
            pts = np.array([p.pos + basis @ q for q in tri])
            nrm = np.array([basis @ n / np.linalg.norm(basis @ n) for n in normals])
            uv = np.column_stack([texel[:, 0] / tw, texel[:, 1] / th])
            yield p, pts, nrm, uv


def bounds(model):
    pts = np.array([q for _, tri, _, _ in triangles(model) for q in tri])
    return pts.min(0), pts.max(0)


def write_glb(model, path):
    """the model as one mesh: lit pieces and glowing pieces (bulbs) as two primitives."""
    name = model['spec']['name']
    groups = {False: ([], [], [], [], {}), True: ([], [], [], [], {})}
    for p, pts, nrm, uv in triangles(model):
        pos, nor, uvs, idx, seen = groups[bool(props.MATERIALS[p.mat].get('glow'))]
        for k in range(3):
            key = tuple(np.round(pts[k], 5)) + tuple(np.round(nrm[k], 4)) + tuple(np.round(uv[k], 6))
            if key not in seen:
                seen[key] = len(pos)
                pos.append(pts[k])
                nor.append(nrm[k])
                uvs.append(uv[k])
            idx.append(seen[key])
    g = Glb()
    tex = g.texture(f'{name}_albedo.png')
    prims = []
    for glow in (False, True):
        pos, nor, uvs, idx, _ = groups[glow]
        if idx:
            mat = g.material(name + ('_glow' if glow else ''), tex, emissive=glow)
            prims.append((np.array(pos), np.array(nor), np.array(uvs), np.array(idx, np.uint32), mat))
    mesh = g.static_mesh(name, prims)
    g.root(g.node(name, mesh=mesh))
    g.write(path)
    return sum(len(p[3]) for p in prims) // 3


def collision_boxes(model):
    """[(centre, size, yaw degrees)] in prop space."""
    collide = model['spec']['collide']
    if collide == 'none':
        return []
    if collide == 'auto':
        lo, hi = bounds(model)
        return [((lo + hi) / 2, hi - lo, 0.0)]
    return [(np.asarray(b[0], float), np.asarray(b[1], float), float(b[2]) if len(b) > 2 else 0.0) for b in collide]


def _f(v):
    return f'{v:.4g}'


def _transform(centre, yaw):
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    # the basis row by row (Godot's text format), a turn about +Y like geometry.rot(), then the origin
    vals = [c, 0, s, 0, 1, 0, -s, 0, c, centre[0], centre[1], centre[2]]
    return 'Transform3D(' + ', '.join(_f(v) for v in vals) + ')'


def scene_path(spec):
    folder = LIGHT_SCENE_DIR if spec.get('light') else PROP_SCENE_DIR
    return f'{folder}/{props.classname(spec["name"])}.tscn'


def write_scene(model, boxes, path):
    """the prop's Godot scene in text form (a hand-written .tscn, like the tools' other output)."""
    spec = model['spec']
    name = spec['name']
    light = spec.get('light')
    root_name = ''.join(part.capitalize() for part in props.classname(name).split('_'))
    ext = [f'[ext_resource type="PackedScene" path="res://{MODEL_DIR}/{name}.glb" id="model"]']
    if light:
        ext.append(f'[ext_resource type="Script" path="{LIGHT_SCRIPT}" id="light_script"]')
    subs = []
    for i, (_, size, _) in enumerate(boxes):
        subs.append(f'[sub_resource type="BoxShape3D" id="box_{i}"]\nsize = Vector3({_f(size[0])}, {_f(size[1])}, {_f(size[2])})')
    lines = [f'[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]', '']
    lines += ext + ['']
    for s in subs:
        lines += [s, '']
    if boxes:
        lines.append(f'[node name="{root_name}" type="StaticBody3D"]')
        lines.append(f'collision_layer = {LAYERS[spec["layer"]]}')
        lines.append('collision_mask = 0')
    else:
        lines.append(f'[node name="{root_name}" type="Node3D"]')
    if light:
        lines.append('script = ExtResource("light_script")')
        lines.append(f'light_kind = {0 if light["kind"] == "omni" else 1}')
        c = light['color']
        lines.append(f'light_color = Color({_f(c[0])}, {_f(c[1])}, {_f(c[2])}, 1)')
        lines.append(f'light_energy = {_f(light["energy"])}')
        lines.append(f'light_range = {_f(light["range"])}')
        lines.append(f'light_offset = Vector3({_f(light["pos"][0])}, {_f(light["pos"][1])}, {_f(light["pos"][2])})')
        if light.get('angle'):
            lines.append(f'spot_angle = {_f(light["angle"])}')
        if light.get('pitch'):
            lines.append(f'light_pitch = {_f(light["pitch"])}')
    lines.append(f'metadata/surface = "{spec["surface"]}"')
    lines += ['', '[node name="Model" parent="." instance=ExtResource("model")]']
    for i, (centre, _, yaw) in enumerate(boxes):
        lines += ['', f'[node name="Box{i}" type="CollisionShape3D" parent="."]',
                  f'transform = {_transform(centre, yaw)}', f'shape = SubResource("box_{i}")']
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fh:
        fh.write('\n'.join(lines) + '\n')


def tb_size(model):
    """the entity's box in TrenchBroom units: (mins, maxs). An entity with angle 0 is turned
    180 degrees by func_godot, and Godot (x, y, z) is TrenchBroom (y, z, x)."""
    lo, hi = bounds(model)
    mins = np.floor(np.array([-hi[2], -hi[0], lo[1]]) * TB_SCALE)
    maxs = np.ceil(np.array([-lo[2], -lo[0], hi[1]]) * TB_SCALE)
    return mins, maxs


def write_fgd(entries, path):
    """every prop as a func_godot point class (FuncGodotFGDPointClass) in one FGD resource."""
    ext = ['[ext_resource type="Script" path="res://addons/func_godot/src/fgd/func_godot_fgd_file.gd" id="fgd_file"]',
           '[ext_resource type="Script" path="res://addons/func_godot/src/fgd/func_godot_fgd_point_class.gd" id="point_class"]']
    subs = []
    ids = []
    for e in entries:
        cls = e['classname']
        ext.append(f'[ext_resource type="PackedScene" path="res://{e["scene"]}" id="scene_{cls}"]')
        mins, maxs = e['size']
        col = props.CATEGORY_COLORS.get(e['category'], (0.8, 0.8, 0.8))
        desc = e['description'].replace('"', "'")
        meta = (f'"color": Color({_f(col[0])}, {_f(col[1])}, {_f(col[2])}, 1),\n'
                f'"model": "\\"{MODEL_DIR}/{e["name"]}.glb\\"",\n'
                f'"size": AABB({int(mins[0])}, {int(mins[1])}, {int(mins[2])}, {int(maxs[0])}, {int(maxs[1])}, {int(maxs[2])})')
        sub = [f'[sub_resource type="Resource" id="{cls}"]', 'script = ExtResource("point_class")',
               f'classname = "{cls}"', f'description = "{desc}"',
               'meta_properties = Dictionary[String, Variant]({\n' + meta + '\n})']
        if e.get('properties'):
            sub.append('class_properties = Dictionary[String, Variant]({\n' + ',\n'.join(
                f'"{k}": {v}' for k, v in e['properties']) + '\n})')
            sub.append('class_property_descriptions = Dictionary[String, Variant]({\n' + ',\n'.join(
                f'"{k}": "{d}"' for k, d in e['property_descriptions']) + '\n})')
        sub.append(f'scene_file = ExtResource("scene_{cls}")')
        subs.append('\n'.join(sub))
        ids.append(f'SubResource("{cls}")')
    lines = [f'[gd_resource type="Resource" script_class="FuncGodotFGDFile" load_steps={len(ext) + len(subs) + 1} format=3]', '']
    lines += ext + ['']
    for s in subs:
        lines += [s, '']
    lines += ['[resource]', 'script = ExtResource("fgd_file")', 'fgd_name = "ChiipKit"',
              'entity_definitions = Array[Resource]([' + ', '.join(ids) + '])', '']
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fh:
        fh.write('\n'.join(lines))


# Entity properties of lamps (D-124): written into the FGD so TrenchBroom shows them, applied
# by maps/kit/kit_light.gd. Values in Godot's text format; defaults come from each lamp's scene.
def light_properties(light):
    c = light['color']
    return [('light_color', f'Color({_f(c[0])}, {_f(c[1])}, {_f(c[2])}, 1)'),
            ('light_energy', f"{float(light['energy']):.2f}"),
            ('light_range', f"{float(light['range']):.1f}"),
            ('shadows', 'false')]


LIGHT_PROPERTY_DESCRIPTIONS = [
    ('light_color', 'Colour of the light. Keep it warm or neutral (D-031).'),
    ('light_energy', 'Brightness (1 = a normal lamp).'),
    ('light_range', 'How far the light reaches, in metres.'),
    ('shadows', 'Casts shadows. Costly: only a few lamps per map (MAPPING.md).'),
]


def write_texture(image, path):
    from PIL import Image
    Image.fromarray(image).save(path, optimize=True)
    if not os.path.exists(path + '.import'):
        with open(path + '.import', 'w') as fh:
            fh.write(TEXTURE_IMPORT)


def entry(spec, model):
    e = dict(name=spec['name'], classname=props.classname(spec['name']), category=spec['category'],
             description=spec['description'], scene=scene_path(spec), size=tb_size(model))
    if spec.get('light'):
        e['properties'] = light_properties(spec['light'])
        e['property_descriptions'] = LIGHT_PROPERTY_DESCRIPTIONS
    return e


def main(names):
    chosen = list(props.PROPS) if not names else names
    unknown = [n for n in chosen if n not in props.PROPS]
    if unknown:
        raise SystemExit(f'unknown props: {", ".join(unknown)} (known: {", ".join(props.PROPS)})')
    model_dir = os.path.join(PROJECT, MODEL_DIR)
    os.makedirs(model_dir, exist_ok=True)
    entries = []
    order = sorted(props.PROPS, key=lambda n: (list(props.CATEGORY_COLORS).index(props.PROPS[n]['category']), n))
    for name in order:
        spec = props.PROPS[name]
        model = build(spec)
        if name in chosen:
            write_texture(model['albedo'], os.path.join(model_dir, f'{name}_albedo.png'))
            glb = os.path.join(model_dir, f'{name}.glb')
            tris = write_glb(model, glb)
            if not os.path.exists(glb + '.import'):
                with open(glb + '.import', 'w') as fh:
                    fh.write(GLB_IMPORT)
            boxes = collision_boxes(model)
            write_scene(model, boxes, os.path.join(PROJECT, scene_path(spec)))
            lo, hi = bounds(model)
            size = hi - lo
            print(f'{props.classname(name):24s} {tris:5d} triangles, {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} m, '
                  f'texture {model["atlas"].width}x{model["atlas"].height()}, {len(boxes)} box(es), {spec["layer"] if boxes else "no collision"}')
        entries.append(entry(spec, model))
    write_fgd(entries, os.path.join(PROJECT, FGD_PATH))
    print(f'{FGD_PATH}: {len(entries)} entities')
