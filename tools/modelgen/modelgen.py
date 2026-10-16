#!/usr/bin/env python3
"""
modelgen.py - Chiip's model generator (D-054, M6 task 2).

Builds a crew class from its part list (crew.py): low-poly pieces fixed to the bones of
one skeleton (rig.py), a palette-limited texture atlas and a team mask (paint.py), and
writes them as a glTF binary (gltf.py) that Godot imports like any other model.

Usage (from the project folder, in the chiip conda environment, D-071):
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py rifleman     one class
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py weapons      the arsenal only
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py all          every class and the arsenal
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py props [prop names]   the map kit's props

"props" builds the map kit's props instead (props.py, written by kit.py, D-122): models,
scenes and their TrenchBroom entities. Without names it builds every prop.

`weapons` builds every item of weapons.py (rifle, carbine, smg, shotgun, sniper, pistol,
hand_cannon, knife, frag, flashbang, smoke, defuse_kit) and writes, without touching the crew:
    assets/models/weapons/<id>.glb          static mesh in weapon space (origin at the grip)
    assets/models/weapons/<id>_albedo.png   its palette texture
    assets/ui/weapons/<id>.png              buy-menu icon, 128 x 48 (icons.py)
    assets/ui/weapons/<id>_kill.png         kill-feed icon, 16 px tall, white silhouette
    (the vests armor and armor_helmet get a buy icon only)
It prints every item's triangle count (guns stay under 700, grenades under 250), and writes
two overview images, icons_sheet.png and guns_sheet.png, to --sheets (default: not written).
The crew models always hold the rifle (HELD_GUN). A class writes into assets/models/crew/:
    <class>.glb              mesh, skeleton (17 bones, T-pose rest) and animations
    <class>_albedo.png       palette-limited colours; team parts in neutral grey
    <class>_mask.png         red = team colour, green = glows (see paint.py)
    <class>_hit_zones.tres   the hit-zone boxes per bone (a HitZones resource, D-055)
    <class>_arms.glb         first-person arms with their clips (fparms.py); shares the albedo
Then run Godot's import (CLAUDE.md) so the game sees the new files.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import anims  # noqa: E402
import crew  # noqa: E402
import fparms  # noqa: E402
import holds  # noqa: E402
import icons  # noqa: E402
import weapons  # noqa: E402
from geometry import Atlas, PieceMesh  # noqa: E402
from gltf import Glb  # noqa: E402
from paint import Painter  # noqa: E402
from rig import BONES, INDEX, PARENT, quat  # noqa: E402

# The chest and stomach hit zones meet this far below the chest bone (times the body scale):
# at the bottom of the ribcage, about 1.26 m on the Rifleman.
TORSO_SPLIT = 0.06

PROJECT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT_DIR = os.path.join(PROJECT, 'assets', 'models', 'crew')
GUN_DIR = os.path.join(PROJECT, 'assets', 'models', 'weapons')
ICON_DIR = os.path.join(PROJECT, 'assets', 'ui', 'weapons')
# The gun every class holds: the AK-style rifle (the rest of the arsenal is picked up in game).
HELD_GUN = 'rifle'
# Most triangles an item may have: guns, and grenades (they are drawn and held in numbers).
MAX_GUN_TRIANGLES = 700
MAX_GRENADE_TRIANGLES = 250
GRENADES = ('frag', 'flashbang', 'smoke')

# Godot import settings for the generated textures: lossless (the palette must survive),
# mipmaps for distance, and no switch to VRAM compression when Godot sees them used in 3D.
TEXTURE_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=true
process/fix_alpha_border=false
detect_3d/compress_to=0
"""


def build(name):
    """everything about one class: scale, body, pieces, meshes, atlas, textures."""
    s = crew.class_scale(name)
    body = crew.body_of(name, s)
    pieces = crew.parts(name, s)
    atlas = Atlas()
    meshes = [PieceMesh(p, atlas) for p in pieces]
    atlas.pack()
    cd = crew.CLASSES[name]
    kit = dict(cd['kit'], GLOVE=crew.GLOVES[name])
    albedo, mask = Painter(kit, cd['skin'], seed=sum(map(ord, name))).paint(meshes, atlas)
    model = dict(name=name, s=s, body=body, pieces=pieces, atlas=atlas, meshes=meshes, albedo=albedo, mask=mask)
    rig = anims.Rig(body, weapons.GUNS[HELD_GUN]()[1])
    rig.points = bone_points(model)
    model['rig'] = rig
    return model


def bone_points(model):
    """every bone's mesh vertices relative to the bone (rest rotations are the identity)."""
    rest = model['body'].rest_globals()
    pts = {}
    for pm in model['meshes']:
        p = pm.piece
        if p.bone == 'weapon':
            continue
        rot, origin = rest[p.bone]
        basis = rot @ p.basis()
        place = origin + rot @ p.pos
        v = np.array([place + basis @ q for tri, _, _ in pm.triangles(model['atlas']) for q in tri])
        pts.setdefault(p.bone, []).append(v - origin)
    return {b: np.unique(np.round(np.concatenate(v), 4), axis=0) for b, v in pts.items()}


def skinned_arrays(model, meshes=None, rest=None, index_of=None):
    """vertex arrays in model space at rest, each vertex bound fully to its piece's bone.
    By default the whole body on the body's skeleton; the first-person arms pass their own
    meshes, rest pose and bone indices."""
    meshes = model['meshes'] if meshes is None else meshes
    rest = model['body'].rest_globals() if rest is None else rest
    index_of = INDEX if index_of is None else index_of
    atlas = model['atlas']
    tex_w, tex_h = atlas.width, atlas.height()
    verts = {}
    pos, nrm, uv, joint, index = [], [], [], [], []
    for pm in meshes:
        p = pm.piece
        rot, origin = rest[p.bone]
        basis = rot @ p.basis()
        place = origin + rot @ p.pos
        bone = index_of[p.bone]
        for tri, normals, texel in pm.triangles(atlas):
            for k in range(3):
                v = place + basis @ tri[k]
                n = basis @ normals[k]
                n = n / np.linalg.norm(n)
                t = (texel[k, 0] / tex_w, texel[k, 1] / tex_h)
                key = (bone,) + tuple(np.round(v, 5)) + tuple(np.round(n, 4)) + tuple(np.round(t, 6))
                if key not in verts:
                    verts[key] = len(pos)
                    pos.append(v)
                    nrm.append(n)
                    uv.append(t)
                    joint.append(bone)
                index.append(verts[key])
    joints = np.zeros((len(pos), 4), np.uint8)
    joints[:, 0] = joint
    weights = np.zeros((len(pos), 4), np.float32)
    weights[:, 0] = 1.0
    return np.array(pos), np.array(nrm), np.array(uv), np.array(index, np.uint32), joints, weights


def write_arms_glb(model, path):
    """the class's first-person arms (fparms.py): its own arm pieces on a 7-bone camera-space
    skeleton, sharing the body's texture atlas, with the first-person clips."""
    name = model['name']
    arms = fparms.ArmsRig(model['body'], weapons.GUNS[HELD_GUN]()[1])
    meshes = [pm for pm in model['meshes'] if pm.piece.bone in fparms.ARM_BONES]
    rest = arms.rest_globals()
    pos, nrm, uv, idx, joints, weights = skinned_arrays(model, meshes, rest, fparms.INDEX)
    g = Glb()
    rots = arms.rest_rotations()
    node_of = {}
    for b in reversed(fparms.BONES):
        kids = [node_of[c] for c in fparms.BONES if fparms.PARENT[c] == b]
        node_of[b] = g.node(b, translation=arms.off[b], rotation=quat(rots[b]), children=kids)
    tex = g.texture(f'{name}_albedo.png')
    mesh = g.mesh(f'{name}_arms', pos, nrm, uv, idx, g.material(name, tex), joints, weights)
    ibm = []
    for b in fparms.BONES:
        r, p = rest[b]
        m = np.eye(4)
        m[:3, :3] = r.T
        m[:3, 3] = -r.T @ p
        ibm.append(m)
    skin = g.skin(f'{name}_arms', [node_of[b] for b in fparms.BONES], ibm, node_of['view'])
    g.root(node_of['view'])
    g.root(g.node('arms', mesh=mesh, skin=skin))
    clips = fparms.clips(arms)
    # M7 (D-096): every other weapon's first-person clips, around its own points.
    for set_name in holds.SETS:
        if set_name != 'rifle':
            clips += fparms.set_clips(model['body'], set_name, holds.style(set_name), holds.points(set_name))
    for clip, loop, channels in clips:
        g.animation(clip + ('-loop' if loop else ''), [(node_of[b], kind, t, v) for b, kind, t, v in channels])
    g.write(path)
    return len(idx) // 3, len(clips)


def write_glb(model, path, animations=()):
    name = model['name']
    body = model['body']
    pos, nrm, uv, idx, joints, weights = skinned_arrays(model)
    g = Glb()
    offsets, rots = body.rest_offsets(), body.rest_rotations()
    node_of = {}
    for b in reversed(BONES):        # children first, so their indices exist
        kids = [node_of[c] for c in BONES if PARENT[c] == b]
        node_of[b] = g.node(b, translation=offsets[b], rotation=quat(rots[b]), children=kids)
    tex = g.texture(f'{name}_albedo.png')
    mat = g.material(name, tex)
    mesh = g.mesh(name, pos, nrm, uv, idx, mat, joints, weights)
    rest = body.rest_globals()
    ibm = []
    for b in BONES:
        r, p = rest[b]
        m = np.eye(4)
        m[:3, :3] = r.T
        m[:3, 3] = -r.T @ p
        ibm.append(m)
    skin = g.skin(name, [node_of[b] for b in BONES], ibm, node_of['hips'])
    # The bones and the mesh are the scene's top nodes; Godot puts them in a Skeleton3D
    # under a root named after the file.
    g.root(node_of['hips'])
    g.root(g.node('body', mesh=mesh, skin=skin))
    for anim_name, channels in animations:
        g.animation(anim_name, [(node_of[b], path, t, v) for b, path, t, v in channels])
    g.write(path)
    return len(pos), len(idx) // 3


# Hitbox.Zone in weapons/hitbox.gd
ZONE_IDS = {'head': 0, 'stomach': 1, 'chest': 2, 'arms': 3, 'legs': 4}


def hit_zones(model):
    """the hit-zone boxes of a class: (bone, zone, centre, size), centre in the bone's frame.

    Head, arms and legs get one box per bone around the pieces of that zone. The torso is
    split at TORSO_SPLIT below the chest bone: everything of the chest and stomach zones
    above it is the chest box (on the chest bone), everything below it the stomach box (on
    the spine bone, down over the pelvis), so the two never overlap and a plate carrier
    that hangs low counts as stomach where it covers the belly, as in CS."""
    rest = model['body'].rest_globals()
    s = model['s']
    split = rest['chest'][1][1] - TORSO_SPLIT * s
    groups = {}
    torso = []
    for pm in model['meshes']:
        p = pm.piece
        if p.zone is None:
            continue
        rot, origin = rest[p.bone]
        basis = rot @ p.basis()
        place = origin + rot @ p.pos
        pts = np.array([place + basis @ q for tri, _, _ in pm.triangles(model['atlas']) for q in tri])
        if p.zone in ('chest', 'stomach'):
            torso.append(pts)
        else:
            groups.setdefault((p.bone, p.zone), []).append(pts)
    boxes = []
    for (bone, zone), pts in groups.items():
        boxes.append((bone, zone, np.concatenate(pts)))
    above = [q[q[:, 1] >= split] for q in torso]
    below = [q[q[:, 1] < split] for q in torso]
    chest = np.concatenate([q for q in above if len(q)])
    stomach = np.concatenate([q for q in below if len(q)])
    chest = np.vstack([chest, chest[:1] * [1, 0, 1] + [0, split, 0]])       # starts exactly at the split
    stomach = np.vstack([stomach, stomach[:1] * [1, 0, 1] + [0, split, 0]])
    boxes += [('chest', 'chest', chest), ('spine', 'stomach', stomach)]
    out = []
    for bone, zone, pts in boxes:
        lo, hi = pts.min(0), pts.max(0)
        out.append((bone, zone, (lo + hi) / 2 - rest[bone][1], hi - lo))
    order = ['head', 'chest', 'stomach', 'arms', 'legs']
    return sorted(out, key=lambda b: (order.index(b[1]), BONES.index(b[0])))


def write_hit_zones(boxes, path):
    """a HitZones resource (characters/crew/hit_zones.gd) in Godot's text format."""
    vec = lambda vs: ', '.join(f'{v:.4f}' for vec3 in vs for v in vec3)
    lines = ['[gd_resource type="Resource" script_class="HitZones" format=3]', '',
             '[ext_resource type="Script" path="res://characters/crew/hit_zones.gd" id="hit_zones_script"]', '',
             '[resource]', 'script = ExtResource("hit_zones_script")',
             'bones = PackedStringArray(' + ', '.join(f'"{b[0]}"' for b in boxes) + ')',
             'zones = PackedInt32Array(' + ', '.join(str(ZONE_IDS[b[1]]) for b in boxes) + ')',
             'centers = PackedVector3Array(' + vec([b[2] for b in boxes]) + ')',
             'sizes = PackedVector3Array(' + vec([b[3] for b in boxes]) + ')', '']
    with open(path, 'w') as fh:
        fh.write('\n'.join(lines))


def build_item(name):
    """a gun, grenade or piece of gear: its pieces and points, meshes, atlas and painted texture."""
    maker = weapons.GUNS.get(name) or weapons.GEAR[name]
    pieces, points = maker()
    atlas = Atlas()
    meshes = [PieceMesh(p, atlas) for p in pieces]
    atlas.pack()
    albedo, _ = Painter(weapons.kit_for(name), 'skin_l', seed=7).paint(meshes, atlas)
    return dict(name=name, pieces=pieces, points=points, atlas=atlas, meshes=meshes, albedo=albedo)


def write_gun(item, out_dir):
    """a static model in weapon space (weapons.py), with its own palette texture; returns
    its triangle count."""
    name, atlas, meshes = item['name'], item['atlas'], item['meshes']
    pos, nrm, uv, idx = [], [], [], []
    verts = {}
    for pm in meshes:
        basis = pm.piece.basis()
        for tri, normals, texel in pm.triangles(atlas):
            for k in range(3):
                v = pm.piece.pos + basis @ tri[k]
                n = basis @ normals[k]
                t = (texel[k, 0] / atlas.width, texel[k, 1] / atlas.height())
                key = tuple(np.round(v, 5)) + tuple(np.round(n, 4)) + tuple(np.round(t, 6))
                if key not in verts:
                    verts[key] = len(pos)
                    pos.append(v)
                    nrm.append(n / np.linalg.norm(n))
                    uv.append(t)
                idx.append(verts[key])
    os.makedirs(out_dir, exist_ok=True)
    write_texture(item['albedo'], os.path.join(out_dir, f'{name}_albedo.png'))
    g = Glb()
    mat = g.material(name, g.texture(f'{name}_albedo.png'))
    mesh = g.mesh(name, np.array(pos), np.array(nrm), np.array(uv), np.array(idx, np.uint32), mat)
    g.root(g.node(name, mesh=mesh))
    g.write(os.path.join(out_dir, f'{name}.glb'))
    return len(idx) // 3


def write_weapons(gun_dir, icon_dir, sheets=None):
    """every item of the arsenal: .glb + texture for the guns, grenades and the kit (not the
    vests), icons for all of them, and the contact sheets if `sheets` is a folder."""
    tris = {}
    problems = []
    for name in list(weapons.GUNS) + list(weapons.GEAR):
        item = build_item(name)
        tris[name] = icons.item_triangles(item['meshes'], item['atlas'], item['albedo'])
        if name in weapons.GEAR:
            print(f'{name}: {len(item["pieces"])} pieces, icon only')
            continue
        n = write_gun(item, gun_dir)
        limit = MAX_GRENADE_TRIANGLES if name in GRENADES else MAX_GUN_TRIANGLES
        print(f'{name}: {len(item["pieces"])} pieces, {n} triangles' + ('' if n < limit else f'  TOO MANY (limit {limit})'))
        if n >= limit:
            problems.append(name)
    made = icons.write_icons(tris, icon_dir, gear_only=tuple(weapons.GEAR))
    print(f'{len(made)} items, icons in {os.path.relpath(icon_dir, PROJECT)}')
    if sheets:
        os.makedirs(sheets, exist_ok=True)
        icons.contact_sheets(tris, made, os.path.join(sheets, 'icons_sheet.png'), os.path.join(sheets, 'guns_sheet.png'))
    if problems:
        sys.exit(f'too many triangles: {", ".join(problems)}')


def write_texture(image, path):
    Image.fromarray(image).save(path, optimize=True)
    if not os.path.exists(path + '.import'):
        with open(path + '.import', 'w') as fh:
            fh.write(TEXTURE_IMPORT)


def main():
    ap = argparse.ArgumentParser(description='Generate Chiip crew models, the arsenal (.glb + textures + icons) or map-kit props.')
    ap.add_argument('targets', nargs='+', help="class names (rifleman, bulwark, ...), 'weapons' (the arsenal), 'all' (both), or 'props [names]' (the map kit)")
    ap.add_argument('--out', default=OUT_DIR)
    ap.add_argument('--sheets', default=None, help='folder for the icon and gun overview images (outside the project)')
    a = ap.parse_args()
    if a.targets[0] == 'props':
        import kit
        kit.main(a.targets[1:])
        return
    names = []
    for t in a.targets:
        names += list(crew.CLASSES) + ['weapons'] if t == 'all' else [t]
    os.makedirs(a.out, exist_ok=True)
    for name in names:
        if name == 'weapons':
            write_weapons(GUN_DIR, ICON_DIR, a.sheets)
            continue
        model = build(name)
        write_texture(model['albedo'], os.path.join(a.out, f'{name}_albedo.png'))
        write_texture(model['mask'], os.path.join(a.out, f'{name}_mask.png'))
        clips = anims.all_clips(model['rig'])
        # M7 (D-096): the other weapons' holds, aim poses, reloads and attacks.
        clips += anims.set_clips(model['body'], model['rig'].points, list(holds.SETS), holds.points, holds.style,
                                 weapons.GUNS['rifle']()[1])
        glb_path = os.path.join(a.out, f'{name}.glb')
        # Godot's importer loops animations whose names end in "-loop" and drops the suffix.
        nv, nt = write_glb(model, glb_path, [(n + ('-loop' if loop else ''), ch) for n, loop, ch in clips])
        arms_tris, arms_clips = write_arms_glb(model, os.path.join(a.out, f'{name}_arms.glb'))
        print(f'  first-person arms: {arms_tris} triangles, {arms_clips} animations')
        boxes = hit_zones(model)
        write_hit_zones(boxes, os.path.join(a.out, f'{name}_hit_zones.tres'))
        for bone, zone, centre, size in boxes:
            print(f'  {zone:8s} on {bone:12s} size {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f}')
        print(f'{name}: scale {model["s"]:.3f}, {len(model["pieces"])} pieces, {nv} vertices, {nt} triangles, '
              f'texture {model["atlas"].width}x{model["atlas"].height()}, {len(clips)} animations')


if __name__ == '__main__':
    main()
