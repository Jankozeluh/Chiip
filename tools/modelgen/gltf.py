"""
gltf.py - a small glTF 2.0 binary (.glb) writer for Chiip's model generator (D-054, D-071).

Writes exactly what the generator needs and nothing more: one skinned mesh (or a static
one), a skeleton of joint nodes, an external PNG texture with a nearest-neighbour sampler,
and keyframe animations (rotation and translation per joint). No glTF library: a .glb is
a 12-byte header, a JSON chunk and a binary chunk holding the vertex and key data.

Spec: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
"""
import json
import struct

import numpy as np

FLOAT = 5126
UNSIGNED_BYTE = 5121
UNSIGNED_SHORT = 5123
UNSIGNED_INT = 5125
ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963
NEAREST = 9728
NEAREST_MIPMAP_NEAREST = 9984
CLAMP_TO_EDGE = 33071

_TYPE_WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class Glb:
    """Collects the JSON document and the binary buffer, then writes a .glb file."""

    def __init__(self, generator='Chiip modelgen'):
        self.doc = dict(asset=dict(version='2.0', generator=generator), scene=0, scenes=[dict(nodes=[])],
                        nodes=[], buffers=[], bufferViews=[], accessors=[])
        self.bin = bytearray()

    # ------------------------------------------------------------ raw data
    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        view = dict(buffer=0, byteOffset=len(self.bin), byteLength=len(data))
        if target is not None:
            view['target'] = target
        self.bin.extend(data)
        self.doc['bufferViews'].append(view)
        return len(self.doc['bufferViews']) - 1

    def accessor(self, array, kind, component=FLOAT, target=None, bounds=False, normalized=False):
        """adds an accessor for `array` (rows = elements) and returns its index."""
        dtype = {FLOAT: np.float32, UNSIGNED_BYTE: np.uint8, UNSIGNED_SHORT: np.uint16,
                 UNSIGNED_INT: np.uint32}[component]
        a = np.ascontiguousarray(np.asarray(array).astype(dtype))
        width = _TYPE_WIDTH[kind]
        count = a.size // width
        acc = dict(bufferView=self._view(a.tobytes(), target), componentType=component, count=count, type=kind)
        if normalized:
            acc['normalized'] = True
        if bounds:
            flat = a.reshape(count, width)
            acc['min'] = [float(v) for v in flat.min(0)]
            acc['max'] = [float(v) for v in flat.max(0)]
        self.doc['accessors'].append(acc)
        return len(self.doc['accessors']) - 1

    def _add(self, key, item):
        self.doc.setdefault(key, []).append(item)
        return len(self.doc[key]) - 1

    # ------------------------------------------------------------ scene
    def node(self, name, translation=None, rotation=None, children=None, **extra):
        """adds a node; rotation is a quaternion (x, y, z, w)."""
        n = dict(name=name)
        if translation is not None and np.any(np.abs(translation) > 1e-9):
            n['translation'] = [float(v) for v in translation]
        if rotation is not None and abs(rotation[3] - 1.0) > 1e-9:
            n['rotation'] = [float(v) for v in rotation]
        if children:
            n['children'] = list(children)
        n.update(extra)
        return self._add('nodes', n)

    def root(self, node_index):
        self.doc['scenes'][0]['nodes'].append(node_index)

    def texture(self, uri):
        """an external PNG next to the .glb, sampled nearest-neighbour (pixel look)."""
        image = self._add('images', dict(uri=uri))
        sampler = self._add('samplers', dict(magFilter=NEAREST, minFilter=NEAREST_MIPMAP_NEAREST,
                                             wrapS=CLAMP_TO_EDGE, wrapT=CLAMP_TO_EDGE))
        return self._add('textures', dict(source=image, sampler=sampler))

    def material(self, name, texture=None):
        pbr = dict(metallicFactor=0.0, roughnessFactor=1.0)
        if texture is not None:
            pbr['baseColorTexture'] = dict(index=texture)
        return self._add('materials', dict(name=name, pbrMetallicRoughness=pbr))

    def mesh(self, name, positions, normals, uvs, indices, material, joints=None, weights=None):
        """one triangle-list primitive. joints/weights: (N, 4) arrays for a skinned mesh."""
        attrs = dict(POSITION=self.accessor(positions, 'VEC3', target=ARRAY_BUFFER, bounds=True),
                     NORMAL=self.accessor(normals, 'VEC3', target=ARRAY_BUFFER),
                     TEXCOORD_0=self.accessor(uvs, 'VEC2', target=ARRAY_BUFFER))
        if joints is not None:
            attrs['JOINTS_0'] = self.accessor(joints, 'VEC4', UNSIGNED_BYTE, target=ARRAY_BUFFER)
            attrs['WEIGHTS_0'] = self.accessor(weights, 'VEC4', target=ARRAY_BUFFER)
        component = UNSIGNED_SHORT if len(positions) < 65536 else UNSIGNED_INT
        prim = dict(attributes=attrs, indices=self.accessor(indices, 'SCALAR', component, ELEMENT_ARRAY_BUFFER),
                    material=material, mode=4)
        return self._add('meshes', dict(name=name, primitives=[prim]))

    def skin(self, name, joint_nodes, inverse_bind_matrices, skeleton_root):
        """inverse_bind_matrices: (J, 4, 4) row-major numpy matrices; glTF stores them column-major."""
        ibm = np.asarray(inverse_bind_matrices, np.float32).transpose(0, 2, 1).reshape(-1, 16)
        return self._add('skins', dict(name=name, joints=list(joint_nodes), skeleton=skeleton_root,
                                       inverseBindMatrices=self.accessor(ibm, 'MAT4')))

    def animation(self, name, channels):
        """channels: list of (node index, 'rotation' | 'translation', times (K,), values (K, 4|3))."""
        samplers, chans = [], []
        time_cache = {}
        for node, path, times, values in channels:
            key = tuple(np.round(times, 6))
            if key not in time_cache:
                time_cache[key] = self.accessor(np.asarray(times, np.float32), 'SCALAR', bounds=True)
            kind = 'VEC4' if path == 'rotation' else 'VEC3'
            out = self.accessor(np.asarray(values, np.float32), kind)
            samplers.append(dict(input=time_cache[key], output=out, interpolation='LINEAR'))
            chans.append(dict(sampler=len(samplers) - 1, target=dict(node=node, path=path)))
        return self._add('animations', dict(name=name, channels=chans, samplers=samplers))

    # ------------------------------------------------------------ file
    def write(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.doc['buffers'] = [dict(byteLength=len(self.bin))]
        js = json.dumps(self.doc, separators=(',', ':')).encode('utf-8')
        js += b' ' * (-len(js) % 4)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, 'wb') as fh:
            fh.write(struct.pack('<III', 0x46546C67, 2, total))
            fh.write(struct.pack('<II', len(js), 0x4E4F534A))
            fh.write(js)
            fh.write(struct.pack('<II', len(self.bin), 0x004E4942))
            fh.write(bytes(self.bin))
