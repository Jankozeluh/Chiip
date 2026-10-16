"""
props_lights.py - the map kit's lamps (D-124, M10): a model plus a real light.

Part lists like props.py. A lamp's `light` says where its light sits (in prop space), its kind
(omni or spot, with the spot's cone and downward tilt) and its default colour, brightness and
range; the generated scene (maps/kit/lights/<name>.tscn) gets maps/kit/kit_light.gd, which
builds the light, and TrenchBroom shows light_color, light_energy, light_range and shadows as
entity properties. Lit parts use the glowing materials (glow_warm, glow_white).

Where the origin is: floor lamps stand on it; wall lamps have it on the wall face, at the
lamp; ceiling lamps have it on the ceiling, and hang below it.
"""
import math

import numpy as np

from props import box, cyl, ell, prop

WARM = (1.0, 0.74, 0.44)
SODIUM = (1.0, 0.8, 0.55)
NEUTRAL = (1.0, 0.94, 0.84)


@prop('light_wall', 'lights', 'Caged bulkhead lamp for a wall, warm light reaching 7 m. Origin on the wall face, at the lamp.',
      collide='none', surface='metal', density=96,
      light=dict(kind='omni', pos=(0, 0, -0.35), color=WARM, energy=1.4, range=7.0))
def light_wall():
    P = [box((0.22, 0.3, 0.04), (0, 0, -0.02), 'metal_dk', bevel=0.01),
         ell((0.085, 0.12, 0.08), (0, 0, -0.06), 'glow_warm', sides=8, rings=4)]
    for y in (-0.06, 0.06):
        P.append(box((0.2, 0.016, 0.016), (0, y, -0.145), 'metal_dk', bevel=0))
    P.append(box((0.016, 0.27, 0.016), (0, 0, -0.15), 'metal_dk', bevel=0))
    for x in (-0.095, 0.095):
        P.append(box((0.016, 0.016, 0.12), (x, 0, -0.09), 'metal_dk', bevel=0))
    return P


@prop('light_cage', 'lights', 'Bare bulb in a wire cage hanging 0.8 m from the ceiling, warm light reaching 6 m. Origin on the ceiling.',
      collide='none', surface='metal', density=96,
      light=dict(kind='omni', pos=(0, -0.8, 0), color=WARM, energy=1.3, range=6.0))
def light_cage():
    P = [cyl(0.01, 0.62, (0, 0, 0), 'black', axis='-y', sides=4),
         cyl(0.04, 0.08, (0, -0.6, 0), 'metal_dk', axis='-y', sides=6),
         ell((0.055, 0.075, 0.055), (0, -0.74, 0), 'glow_warm', sides=6, rings=4),
         cyl(0.075, 0.012, (0, -0.84, 0), 'metal_dk', axis='-y', sides=6)]
    for a in range(4):
        x, z = 0.072 * math.cos(a * math.pi / 2 + 0.785), 0.072 * math.sin(a * math.pi / 2 + 0.785)
        P.append(box((0.012, 0.2, 0.012), (x, -0.745, z), 'metal_dk', bevel=0))
    return P


@prop('light_ceiling', 'lights', 'Industrial pendant lamp with a dark shade, hanging 0.75 m from the ceiling, warm light reaching 8 m. Origin on the ceiling.',
      collide='none', surface='metal', density=96,
      light=dict(kind='omni', pos=(0, -0.9, 0), color=WARM, energy=1.6, range=8.0))
def light_ceiling():
    return [cyl(0.012, 0.5, (0, 0, 0), 'black', axis='-y', sides=4),
            cyl(0.07, 0.06, (0, -0.5, 0), 'metal_dk', axis='-y', sides=8),
            cyl(0.08, 0.2, (0, -0.55, 0), 'metal_dk', axis='-y', radius_end=0.3, sides=10),
            ell((0.07, 0.06, 0.07), (0, -0.72, 0), 'glow_warm', sides=8, rings=4)]


@prop('light_strip', 'lights', 'Fluorescent tube fitting for a ceiling, 1.25 m long, neutral light reaching 6 m. Origin on the ceiling.',
      collide='none', surface='metal', density=96,
      light=dict(kind='omni', pos=(0, -0.35, 0), color=NEUTRAL, energy=1.0, range=6.0))
def light_strip():
    return [box((1.25, 0.06, 0.18), (0, -0.03, 0), 'paint_light', bevel=0.01),
            box((1.15, 0.04, 0.06), (0, -0.075, 0), 'glow_white', bevel=0.005),
            box((0.04, 0.05, 0.1), (-0.6, -0.08, 0), 'metal_dk', bevel=0),
            box((0.04, 0.05, 0.1), (0.6, -0.08, 0), 'metal_dk', bevel=0)]


def _lens_at(centre, pitch, depth):
    """the point `depth` metres in front of a head at `centre` tilted down by `pitch` degrees."""
    p = math.radians(pitch)
    return (centre[0], centre[1] - depth * math.sin(p), centre[2] - depth * math.cos(p))


@prop('light_flood', 'lights', 'Floodlight on a wall bracket, aimed 30 degrees down: a bright spot light reaching 18 m. Origin on the wall face.',
      collide='none', surface='metal', density=96,
      light=dict(kind='spot', pos=(0, -0.12, -0.55), color=NEUTRAL, energy=3.0, range=18.0, angle=38, pitch=30))
def light_flood():
    head = (0, 0, -0.36)
    lens = _lens_at(head, 30, 0.1)
    return [box((0.06, 0.06, 0.3), (0, 0, -0.15), 'metal_dk', bevel=0),
            box((0.12, 0.16, 0.03), (0, 0, -0.015), 'metal_dk', bevel=0),
            box((0.42, 0.32, 0.18), head, 'metal_dk', bevel=0.02, rot=(-30, 0, 0)),
            box((0.36, 0.26, 0.02), lens, 'glow_white', bevel=0, rot=(-30, 0, 0))]


@prop('light_street', 'lights', 'Street lamp, 5 m pole with an arm, warm light reaching 10 m. Stands on the floor; the arm points to the front.',
      collide=[((0, 2.4, 0), (0.3, 4.8, 0.3))], surface='metal',
      light=dict(kind='omni', pos=(0, 4.3, -1.05), color=SODIUM, energy=2.0, range=10.0))
def light_street():
    return [cyl(0.15, 0.4, (0, 0, 0), 'concrete', sides=8),
            cyl(0.07, 4.45, (0, 0.4, 0), 'metal_dk', sides=8),
            box((0.06, 0.06, 1.0), (0, 4.78, -0.5), 'metal_dk', bevel=0),
            box((0.26, 0.1, 0.5), (0, 4.72, -1.05), 'metal_dk', bevel=0.02),
            box((0.2, 0.02, 0.4), (0, 4.66, -1.05), 'glow_warm', bevel=0)]


@prop('light_worklight', 'lights', 'Two work lights on a tripod, 2.1 m, aimed 25 degrees down: a wide spot light reaching 14 m. See-through: it stops you, not bullets or sight.',
      collide=[((0, 1.05, 0), (0.9, 2.1, 0.9))], layer='seethrough', surface='metal',
      light=dict(kind='spot', pos=(0, 1.95, -0.25), color=NEUTRAL, energy=2.5, range=14.0, angle=50, pitch=25))
def light_worklight():
    apex = np.array([0.0, 1.25, 0.0])
    P = []
    for a in (90, 210, 330):
        foot = np.array([0.42 * math.cos(math.radians(a)), 0.0, 0.42 * math.sin(math.radians(a))])
        P.append(cyl(0.018, float(np.linalg.norm(apex - foot)), tuple(foot), 'metal_dk', axis=tuple(apex - foot), sides=4))
    P.append(cyl(0.025, 0.8, (0, 1.2, 0), 'metal_dk', sides=6))
    P.append(box((0.72, 0.04, 0.04), (0, 2.0, 0), 'metal_dk', bevel=0))
    for x in (-0.3, 0.3):
        head = (x, 2.04, -0.04)
        P.append(box((0.26, 0.2, 0.12), head, 'safety', bevel=0.015, rot=(-25, 0, 0)))
        P.append(box((0.22, 0.16, 0.02), _lens_at(head, 25, 0.065), 'glow_white', bevel=0, rot=(-25, 0, 0)))
    return P
