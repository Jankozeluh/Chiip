#!/usr/bin/env python3
"""
modelgen.py - Chiip's model generator (D-054, M6 task 2).

Builds a crew class from its part list (crew.py): low-poly pieces fixed to the bones of
one skeleton (rig.py), a palette-limited texture atlas and a team mask (paint.py), and
writes them as a glTF binary (gltf.py) that Godot imports like any other model.

Usage (from the project folder, in the chiip conda environment, D-071):
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py rifleman
    ~/miniconda3/envs/chiip/bin/python tools/modelgen/modelgen.py all

Writes into assets/models/crew/:
    <class>.glb              mesh, skeleton (17 bones, T-pose rest) and animations
    <class>_albedo.png       palette-limited colours; team parts in neutral grey
    <class>_mask.png         red = team colour, green = glows (see paint.py)
    <class>_hit_zones.tres   the hit-zone boxes per bone (a HitZones resource, D-055)
Then run Godot's import (CLAUDE.md) so the game sees the new files.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import crew  # noqa: E402
from geometry import Atlas, PieceMesh  # noqa: E402
from gltf import Glb  # noqa: E402
from paint import Painter  # noqa: E402
from rig import BONES, INDEX, PARENT, quat  # noqa: E402

# The chest and stomach hit zones meet this far below the chest bone (times the body scale):
# at the bottom of the ribcage, about 1.26 m on the Rifleman.
TORSO_SPLIT = 0.06

PROJECT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT_DIR = os.path.join(PROJECT, 'assets', 'models', 'crew')

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
    albedo, mask = Painter(cd['kit'], cd['skin'], seed=sum(map(ord, name))).paint(meshes, atlas)
    return dict(name=name, s=s, body=body, pieces=pieces, atlas=atlas, meshes=meshes, albedo=albedo, mask=mask)


def skinned_arrays(model):
    """vertex arrays in model space at rest, each vertex bound fully to its piece's bone."""
    rest = model['body'].rest_globals()
    atlas = model['atlas']
    tex_w, tex_h = atlas.width, atlas.height()
    verts = {}
    pos, nrm, uv, joint, index = [], [], [], [], []
    for pm in model['meshes']:
        p = pm.piece
        rot, origin = rest[p.bone]
        basis = rot @ p.basis()
        place = origin + rot @ p.pos
        bone = INDEX[p.bone]
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


def write_texture(image, path):
    Image.fromarray(image).save(path, optimize=True)
    if not os.path.exists(path + '.import'):
        with open(path + '.import', 'w') as fh:
            fh.write(TEXTURE_IMPORT)


def main():
    ap = argparse.ArgumentParser(description='Generate Chiip crew models (.glb + textures).')
    ap.add_argument('classes', nargs='+', help="class names (rifleman, bulwark, ...) or 'all'")
    ap.add_argument('--out', default=OUT_DIR)
    a = ap.parse_args()
    names = list(crew.CLASSES) if a.classes == ['all'] else a.classes
    os.makedirs(a.out, exist_ok=True)
    for name in names:
        model = build(name)
        write_texture(model['albedo'], os.path.join(a.out, f'{name}_albedo.png'))
        write_texture(model['mask'], os.path.join(a.out, f'{name}_mask.png'))
        nv, nt = write_glb(model, os.path.join(a.out, f'{name}.glb'))
        boxes = hit_zones(model)
        write_hit_zones(boxes, os.path.join(a.out, f'{name}_hit_zones.tres'))
        for bone, zone, centre, size in boxes:
            print(f'  {zone:8s} on {bone:12s} size {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f}')
        print(f'{name}: scale {model["s"]:.3f}, {len(model["pieces"])} pieces, {nv} vertices, {nt} triangles, '
              f'texture {model["atlas"].width}x{model["atlas"].height()}')


if __name__ == '__main__':
    main()
