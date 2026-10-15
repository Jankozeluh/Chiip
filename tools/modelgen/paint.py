"""
paint.py - paints the texture atlas of a generated model (D-054).

Every texel takes its colour from one of the 16-shade ramps of the concept palette
(tools/concept/spritegen.py, D-070), so a model has the same palette as its concept sheet.
The class's kit decides which ramp each material uses. A little baked light (lighter tops,
darker undersides and edges), grain and a few patterns (webbing, knit ribs, wood grain)
give the pieces a hand-painted pixel look; the real lighting comes from the engine.

Team colour is not painted (D-053). Texels of team parts get a neutral grey of the right
brightness instead, and the mask texture marks them: red = team colour, green = glowing
(unshaded). The team-colour shader (characters/crew/crew.gdshader) multiplies that grey by
the viewer's team colour, so the grey must be TEAM_BASE (linear) where the team colour should
show unchanged.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'concept'))
import spritegen as concept  # noqa: E402  (palette ramps and class kits)

from geometry import FACE_NAMES  # noqa: E402

# Linear brightness of a team texel that shows the team colour unchanged; must match
# TEAM_BASE in characters/crew/crew.gdshader.
TEAM_BASE = 0.5
TEAM_RAMP = 'team_blue'

# base: shade 0-15 on the ramp at mid brightness; grain: chance of a +-1 shade speck;
# pattern: extra detail; outline: darker rim on box sides.
MATERIALS = {
    'top':     dict(slot='TOP', base=9, grain=0.20),
    'sleeve':  dict(slot='SLEEVE', base=9, grain=0.15),
    'bottom':  dict(slot='BOTTOM', base=8, grain=0.22),
    'coat':    dict(slot='COAT', base=8, grain=0.22),
    'gear':    dict(slot='GEAR', base=8, grain=0.15, pattern='webbing'),
    'gear_dk': dict(slot='GEAR', base=5, grain=0.15),
    'plate':   dict(slot='GEAR', base=9, grain=0.08, pattern='plate'),
    'team':    dict(slot='TEAM', base=9, grain=0.10),
    'knit':    dict(slot='KNIT', base=8, grain=0.10, pattern='rib'),
    'furn':    dict(slot='FURN', base=8, grain=0.10, pattern='woodgrain'),
    'boot':    dict(slot='BOOT', base=4, grain=0.12),
    'skin':    dict(slot='SKIN', base=10, grain=0.06),
    'brow':    dict(slot='SKIN', base=5, grain=0.0),
    'mask':    dict(ramp='charcoal', base=5, grain=0.10, pattern='rib'),
    'glove':   dict(ramp='grey', base=4, grain=0.12),
    'sole':    dict(ramp='grey', base=2, grain=0.05),
    'metal':   dict(ramp='gunmetal', base=7, grain=0.25, pattern='speckle'),
    'polymer': dict(ramp='grey', base=4, grain=0.10),
    'lens':    dict(ramp='glass', base=5, grain=0.0, pattern='glint'),
    'glow':    dict(ramp='fb_cool', base=11, grain=0.0, glow=True),
    'eye':     dict(ramp='grey', base=1, grain=0.0),
}


def _srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def _luma(rgb_lin):
    return rgb_lin[..., 0] * 0.2126 + rgb_lin[..., 1] * 0.7152 + rgb_lin[..., 2] * 0.0722


def material_ramp(mat, kit, skin):
    """(ramp name, lo, hi, is_team) for a material under a class kit."""
    md = MATERIALS[mat]
    if 'ramp' in md:
        return md['ramp'], 0, 15, False
    slot = md['slot']
    sv = skin if slot == 'SKIN' else 'TEAM' if slot == 'TEAM' else kit[slot]
    if sv == 'TEAM':
        return TEAM_RAMP, 0, 15, True
    if isinstance(sv, tuple):
        return sv[0], sv[1], sv[2], False
    return sv, 0, 15, False


class Painter:
    def __init__(self, kit, skin, seed=1):
        self.kit, self.skin = kit, skin
        self.rng = np.random.default_rng(seed)
        team = _srgb_to_lin(concept.PAL8[concept.RAMP_ID[TEAM_RAMP] * 16:(concept.RAMP_ID[TEAM_RAMP] + 1) * 16] / 255.0)
        self.team_luma = _luma(team)

    def paint(self, meshes, atlas):
        """returns (albedo RGB uint8 image, mask RGB uint8 image) for the atlas."""
        h = atlas.height()
        albedo = np.zeros((h, atlas.width, 3), np.uint8)
        mask = np.zeros((h, atlas.width, 3), np.uint8)
        for pm in meshes:
            for f, side in enumerate(pm.sides):
                self._paint_side(pm, f, side, atlas.rects[side['rect']], albedo, mask)
        return albedo, mask

    def _paint_side(self, pm, f, side, rect, albedo, mask):
        piece = pm.piece
        x0, y0, w, h = rect
        # the padding ring repeats the edge texels, so filtering never picks up a neighbour
        ii = np.arange(-1, w + 1)
        jj = np.arange(-1, h + 1)
        u = (np.clip(ii, 0, w - 1) + 0.5) / w
        v = (np.clip(jj, 0, h - 1) + 0.5) / h
        U, V = np.meshgrid(u, v)
        P = side['to_point'](U, V)
        name = FACE_NAMES[f]
        mats = np.full(U.shape, piece.mat, dtype=object)
        for test, mat in piece.decals:
            hit = np.vectorize(lambda x, y, z: bool(test(x, y, z, name)))(P[..., 0], P[..., 1], P[..., 2])
            mats[hit] = mat
        Ic, Jc = np.meshgrid(np.clip(ii, 0, w - 1), np.clip(jj, 0, h - 1))
        lo, hi = pm.lo, pm.hi
        height = max(hi[1] - lo[1], 1e-6)
        rel_y = (P[..., 1] - lo[1]) / height              # 0 at the bottom of the piece, 1 at the top
        for mat in set(mats.ravel()):
            sel = mats == mat
            md = MATERIALS[mat]
            ramp, rlo, rhi, team = material_ramp(mat, self.kit, self.skin)
            shade = np.full(U.shape, float(md['base']))
            # baked light: lighter top, darker bottom, a soft gradient down the sides
            if name == '+y':
                shade += 1
            elif name == '-y':
                shade -= 2
            else:
                shade += np.where(rel_y > 0.8, 1, 0) - np.where(rel_y < 0.15, 1, 0)
            if piece.shape == 'box' and md.get('pattern') != 'plate' and w > 3 and h > 3:
                edge = (Ic == 0) | (Jc == 0) | (Ic == w - 1) | (Jc == h - 1)
                shade -= 1.0 * edge
            grain = md.get('grain', 0.0)
            if grain > 0:
                r = self.rng.random(U.shape)
                shade += 1.0 * (r < grain / 2) - 1.0 * ((r >= grain / 2) & (r < grain))
            shade += self._pattern(md.get('pattern'), Ic, Jc, w, h, P)
            shade = np.clip(np.round(shade), 0, 15)
            idx = np.round(rlo + (rhi - rlo) * shade / 15.0).astype(int)
            rgb = concept.PAL8[concept.RAMP_ID[ramp] * 16 + idx]
            if team:
                grey = TEAM_BASE * self.team_luma[idx] / self.team_luma[md['base']]
                g = np.round(_lin_to_srgb(grey) * 255).astype(np.uint8)
                rgb = np.stack([g, g, g], -1)
            ys, xs = np.nonzero(sel)
            albedo[y0 - 1 + ys, x0 - 1 + xs] = rgb[ys, xs]
            mask[y0 - 1 + ys, x0 - 1 + xs, 0] = 255 if team else 0
            mask[y0 - 1 + ys, x0 - 1 + xs, 1] = 255 if md.get('glow') else 0

    def _pattern(self, pattern, I, J, w, h, P):
        if pattern == 'webbing':          # horizontal straps every few texels
            return -1.0 * ((J % 4) == 3)
        if pattern == 'rib':              # knit ribs
            return -1.0 * ((I % 2) == 1)
        if pattern == 'woodgrain':        # streaks along the length
            streak = self.rng.random(h + 2)[np.clip(J + 1, 0, h + 1)] < 0.35
            return -1.0 * streak
        if pattern == 'speckle':
            return (self.rng.random(I.shape) < 0.08) * 1.0
        if pattern == 'plate':            # a light rim and dark rivets in the corners
            rim = (I == 0) | (J == 0) | (I == w - 1) | (J == h - 1)
            rivet = ((I == 1) | (I == w - 2)) & ((J == 1) | (J == h - 2)) & (w > 5) & (h > 5)
            return rim * 1.0 - rivet * 3.0
        if pattern == 'glint':
            return ((I == 1) & (J == 1)) * 4.0
        return 0.0
