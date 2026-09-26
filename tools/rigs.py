"""Character rigs and keyframed animations for Vesperdeep.

Every character (the player, NPCs, enemies and bosses) is a small 2D bone rig made of
simple 3D shapes, seen side-on. This script writes one JSON module per rig into
src/shared/Rigs/, which Rojo turns into ModuleScripts. The game's Rig runtime and the
preview renderer (tools/preview.py) both read exactly this data.

Coordinates: x points the way the character faces, y is up, z points to its right side.
Units are studs. Rig origin (0, 0, 0) is at the feet / ground contact unless noted.
Bones mostly swing in the side plane (rotation about z, "r"); keys may also turn (ry,
about y) and tilt (rx, about x) for 3D motion such as looking around.

    python tools/rigs.py
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "Rigs")

# --------------------------------------------------------------------- palette
# One consistent palette: pale masks, deep ink bodies, a single accent glow each.
MASK = (238, 234, 224)
MASK_SHADE = (206, 200, 190)
INK = (16, 14, 20)
EYE = (8, 8, 12)
CLOAK = (40, 42, 70)
CLOAK_DARK = (28, 29, 50)
NAIL = (214, 220, 232)
NAIL_GLOW = (190, 215, 255)
WARM = (255, 204, 140)


# --------------------------------------------------------------------- builders

class Rig:
    def __init__(self, name, anchor):
        self.name = name
        self.anchor = anchor
        self.bones = []
        self.parts = []
        self.clips = {}

    def bone(self, n, parent=None, at=(0, 0, 0), rest=0):
        z = at[2] if len(at) > 2 else 0
        self.bones.append({"n": n, "p": parent, "at": [round(at[0], 3), round(at[1], 3), round(z, 3)], "r": rest})
        return n

    def part(self, b, shape, size, off=(0, 0, 0), rot=0, color=INK, mat="p", alpha=0, flip=False, tag=None):
        w, h = size[0], size[1]
        d = size[2] if len(size) > 2 else min(w, h)
        x, y = off[0], off[1]
        z = off[2] if len(off) > 2 else 0
        p = {"b": b, "s": shape, "z": [w, h, d], "o": [x, y, z], "r": rot, "c": list(color), "m": mat}
        if alpha:
            p["a"] = alpha
        if flip:
            p["f"] = 1
        if tag:
            p["t"] = tag
        self.parts.append(p)

    def clip(self, name, length, keys, loop=True, events=None):
        self.clips[name] = {"len": length, "loop": loop, "k": keys, "ev": events or []}

    def to_json(self):
        return {"name": self.name, "anchor": self.anchor, "bones": self.bones, "parts": self.parts, "clips": self.clips}


def K(t, r=0, x=0, y=0, sx=1, sy=1, e="io", ry=0, rx=0):
    """One key: time, rotation (degrees, + tips the top backwards), offset, scale, ease to the
    next key ("l" linear, "i" in, "o" out, "io" in-out, "s" step), plus optional turn / tilt."""
    key = [round(t, 4), r, x, y, sx, sy, e]
    if ry or rx:
        key += [ry, rx]
    return key


def loop_keys(length, *frames):
    """Evenly spaced looping keys; the first frame is repeated at the end."""
    n = len(frames)
    keys = []
    for i, f in enumerate(frames):
        keys.append(K(length * i / n, *f))
    keys.append(K(length, *frames[0]))
    return keys


def mask_face(r, bone, center, size, eye_style="tall", eye_gap=0.19, color=MASK, eye_color=EYE, depth=None):
    """A pale mask with two hollow eyes on its front (+x) face."""
    cx, cy = center
    d = depth or size[0] * 0.95
    r.part(bone, "ball", (size[0], size[1], d), (cx, cy, 0), color=color)
    r.part(bone, "ball", (size[0] * 0.75, size[1] * 0.3, d * 0.8), (cx + 0.05, cy - size[1] * 0.3, 0), color=MASK_SHADE)
    if eye_style == "tall":
        ew, eh = d * 0.2, size[1] * 0.36
    elif eye_style == "round":
        ew, eh = d * 0.24, size[1] * 0.24
    elif eye_style == "slit":
        ew, eh = d * 0.3, size[1] * 0.12
    else:  # "drop": wide and soft
        ew, eh = d * 0.26, size[1] * 0.3
    gz = eye_gap * d
    fx = cx + size[0] * 0.5 * (1 - (gz / (d * 0.5)) ** 2) ** 0.5 * 0.96
    for side in (-1, 1):
        r.part(bone, "ball", (0.22, eh, ew), (fx, cy + size[1] * 0.02, side * gz), color=eye_color, tag="eye")


# --------------------------------------------------------------------- the player

def wanderer(name="wanderer", cloak=CLOAK, cloak_dark=CLOAK_DARK, mask=MASK, eye=EYE, nail=NAIL, glow=NAIL_GLOW, shade=False):
    """The Wanderer: a small masked vessel with feathered antennae, a round travelling
    cloak, a slender needle-nail and an unlit lantern at the hip."""
    r = Rig(name, 3.0)
    r.bone("root")
    r.bone("hips", "root", (0, 1.25))
    r.bone("legB", "hips", (-0.05, 0.05, -0.38))
    r.bone("legF", "hips", (0.05, 0.05, 0.38))
    r.bone("body", "hips", (0, 0))
    r.bone("hem", "body", (-0.05, 0.15))
    r.bone("lantern", "body", (-0.2, 0.55, -1.0), rest=-8)
    r.bone("armB", "body", (0.05, 1.35, -0.85), rest=-15)
    r.bone("head", "body", (0.08, 1.85))
    r.bone("antB", "head", (-0.15, 1.05, -0.3), rest=42)
    r.bone("antF", "head", (-0.15, 1.05, 0.3), rest=42)
    r.bone("armF", "body", (0.1, 1.35, 0.85), rest=20)
    r.bone("nail", "armF", (0.05, -0.75, 0.15), rest=40)

    # Legs: short dark stalks with rounded feet.
    for leg in ("legB", "legF"):
        tone = INK if leg == "legF" else (10, 9, 13)
        r.part(leg, "box", (0.32, 0.95, 0.32), (0, -0.5, 0), color=tone)
        r.part(leg, "ball", (0.55, 0.32, 0.4), (0.12, -1.02, 0), color=tone)
    # Left arm, mostly hidden by the cloak.
    r.part("armB", "box", (0.26, 0.85, 0.26), (0, -0.42, 0), color=(12, 11, 16))
    # Cloak: a round bell with a collar and a tattered hem all the way around.
    r.part("body", "ball", (2.1, 2.35, 2.1), (-0.05, 0.95, 0), color=cloak)
    r.part("body", "ball", (1.5, 1.0, 1.7), (0.15, 1.6, 0), color=cloak_dark)
    for i in range(8):
        a = i / 8 * math.pi * 2
        hx, hz = math.cos(a) * 0.85, math.sin(a) * 0.85
        r.part("hem", "tri", (0.5, 0.65 + 0.12 * (i % 3), 0.35), (hx - 0.05, -0.08, hz), rot=180, color=cloak_dark, flip=(i % 2 == 0))
    # Lantern hanging at the left hip.
    r.part("lantern", "box", (0.12, 0.35, 0.12), (0, -0.15, 0), color=INK)
    r.part("lantern", "ball", (0.5, 0.6, 0.5), (0, -0.55, 0), color=(60, 56, 50), mat="g", alpha=0.25)
    r.part("lantern", "ball", (0.24, 0.3, 0.24), (0, -0.55, 0), color=WARM, mat="n", tag="glow")
    r.part("lantern", "box", (0.44, 0.1, 0.44), (0, -0.25, 0), color=INK)
    # Head: the mask, with cheek plates and a hairline crack.
    mask_face(r, "head", (0.05, 0.45), (1.85, 1.75), "tall", color=mask, eye_color=eye)
    r.part("head", "box", (0.05, 0.45, 0.05), (0.62, 1.05, 0.28), rot=-25, color=(90, 86, 84))
    # Feathered antennae sweeping back.
    for ant in ("antB", "antF"):
        # A thin stalk that curls back into a feathered plume.
        r.part(ant, "box", (0.11, 0.7, 0.11), (0, 0.33, 0), color=mask)
        r.part(ant, "box", (0.1, 0.55, 0.1), (-0.12, 0.85, 0), rot=25, color=mask)
        r.part(ant, "ball", (0.3, 0.95, 0.14), (-0.45, 1.25, 0), rot=55, color=mask)
        r.part(ant, "ball", (0.2, 0.6, 0.12), (-0.75, 1.3, 0), rot=75, color=MASK_SHADE)
    # Right arm and the needle-nail.
    r.part("armF", "box", (0.28, 0.85, 0.28), (0, -0.4, 0), color=INK)
    r.part("armF", "ball", (0.36, 0.36, 0.36), (0, -0.82, 0), color=INK)
    r.part("nail", "box", (0.2, 0.55, 0.2), (0, -0.25, 0), color=(40, 36, 44))
    r.part("nail", "box", (0.5, 0.12, 0.25), (0, -0.52, 0), color=(70, 64, 80))
    r.part("nail", "box", (0.15, 2.0, 0.12), (0, -1.55, 0), color=nail)
    r.part("nail", "tri", (0.15, 0.45, 0.12), (0.0, -2.75, 0), rot=180, color=nail)
    r.part("nail", "box", (0.05, 1.9, 0.14), (0.06, -1.5, 0), color=glow, mat="n", alpha=0.35, tag="glow")
    if shade:
        # The Echo: tattered wisps of darkness trailing from the cloak.
        for i, (dx, dy, dz) in enumerate(((-1.2, 1.4, 0.3), (-1.35, 0.7, -0.3), (-1.1, 2.1, 0))):
            r.part("hem", "tri", (0.35, 0.9, 0.3), (dx, dy, dz), rot=100 + i * 12, color=(6, 6, 9))

    # ---------------- animations
    # Idle: slow breath, antennae drift, the nail resting.
    r.clip("idle", 2.6, {
        "body": loop_keys(2.6, (0, 0, 0, 1, 1), (0, 0, 0.02, 1.02, 1.03)),
        "head": loop_keys(2.6, (0, 0, 0), (-2, 0, -0.04)),
        "antF": loop_keys(2.6, (0,), (6,), (-2,), (4,)),
        "antB": loop_keys(2.6, (0,), (-4,), (5,), (-2,)),
        "hem": loop_keys(2.6, (0,), (2,)),
        "lantern": loop_keys(2.6, (0,), (5,), (0,), (-4,)),
        "armF": loop_keys(2.6, (0,), (-3,)),
        "nail": loop_keys(2.6, (0,), (2,)),
    })
    # Run: legs cycle, the body leans in and bobs twice per stride, the cloak trails.
    run = 0.42
    r.clip("run", run, {
        "legF": loop_keys(run, (38,), (0, 0, 0.08), (-42,), (0, 0, 0.18)),
        "legB": loop_keys(run, (-42,), (0, 0, 0.18), (38,), (0, 0, 0.08)),
        "hips": loop_keys(run, (0, 0, 0), (0, 0, 0.14), (0, 0, 0), (0, 0, 0.14)),
        "body": loop_keys(run, (-9, 0.05), (-11, 0.05), (-9, 0.05), (-11, 0.05)),
        "head": loop_keys(run, (4,), (2,), (4,), (2,)),
        "hem": loop_keys(run, (14,), (20,), (14,), (20,)),
        "antF": loop_keys(run, (22,), (30,), (22,), (30,)),
        "antB": loop_keys(run, (24,), (32,), (24,), (32,)),
        "armF": loop_keys(run, (-25,), (10,), (25,), (10,)),
        "armB": loop_keys(run, (25,), (0,), (-25,), (0,)),
        "lantern": loop_keys(run, (18,), (26,), (18,), (26,)),
    })
    # Jump anticipation: a quick crouch before take-off.
    r.clip("jumpStart", 0.1, {
        "hips": [K(0, 0, 0, 0, 1, 1), K(0.1, 0, 0, -0.35, 1.12, 0.84)],
        "legF": [K(0, 0), K(0.1, 35)],
        "legB": [K(0, 0), K(0.1, -30)],
        "body": [K(0, 0), K(0.1, -6)],
    }, loop=False)
    # Rising: stretched long, antennae and cloak swept down by the air.
    r.clip("rise", 0.5, {
        "hips": loop_keys(0.5, (0, 0, 0.1, 0.92, 1.1), (0, 0, 0.12, 0.93, 1.08)),
        "legF": loop_keys(0.5, (25, 0, 0.1), (28, 0, 0.1)),
        "legB": loop_keys(0.5, (-35, 0, 0.1), (-32, 0, 0.1)),
        "hem": loop_keys(0.5, (-8,), (-10,)),
        "antF": loop_keys(0.5, (40,), (44,)),
        "antB": loop_keys(0.5, (42,), (46,)),
        "armF": loop_keys(0.5, (-20,), (-24,)),
        "armB": loop_keys(0.5, (35,), (38,)),
    })
    # Falling: the cloak billows up, arms lift, legs dangle.
    r.clip("fall", 0.36, {
        "hem": loop_keys(0.36, (-24, 0, 0.1), (-30, 0, 0.14)),
        "body": loop_keys(0.36, (4, 0, 0, 1.04, 0.97), (5, 0, 0, 1.05, 0.96)),
        "armF": loop_keys(0.36, (90,), (98,)),
        "armB": loop_keys(0.36, (-95,), (-103,)),
        "legF": loop_keys(0.36, (10,), (14,)),
        "legB": loop_keys(0.36, (-8,), (-12,)),
        "antF": loop_keys(0.36, (-12,), (-18,)),
        "antB": loop_keys(0.36, (-10,), (-16,)),
        "head": loop_keys(0.36, (-6,), (-8,)),
    })
    # Landing: squash, then settle with a small overshoot.
    r.clip("land", 0.24, {
        "hips": [K(0, 0, 0, -0.4, 1.18, 0.78, "o"), K(0.12, 0, 0, 0.04, 0.96, 1.04), K(0.24, 0, 0, 0, 1, 1)],
        "legF": [K(0, 40), K(0.24, 0)],
        "legB": [K(0, -34), K(0.24, 0)],
        "head": [K(0, -10), K(0.12, 3), K(0.24, 0)],
        "antF": [K(0, -30), K(0.14, 12), K(0.24, 0)],
        "antB": [K(0, -28), K(0.14, 10), K(0.24, 0)],
        "hem": [K(0, -18), K(0.24, 0)],
    }, loop=False)
    # Turning: a squeeze through the middle, the renderer flips facing at the narrowest point.
    r.clip("turn", 0.12, {
        "root": [K(0, 0, 0, 0, 1, 1), K(0.06, 0, 0, 0, 0.55, 1.03), K(0.12, 0, 0, 0, 1, 1)],
    }, loop=False)
    # Keys are offsets from each bone's rest pose. armF rests at 20 degrees (hand slightly
    # forward) and the nail at +40 from the arm (blade angled forward and down).
    # Side slash: wind up high behind, whip through level, follow through low.
    r.clip("attackSide", 0.3, {
        "armF": [K(0, 0), K(0.05, 180, 0, 0, 1, 1, "i"), K(0.09, 75, 0, 0, 1, 1, "o"), K(0.3, 0)],
        "nail": [K(0, 0), K(0.05, -40), K(0.09, -40), K(0.3, 0)],
        "body": [K(0, 0), K(0.05, 10, -0.08), K(0.09, -14, 0.22, 0, 1.06, 0.97, "o"), K(0.3, 0)],
        "head": [K(0, 0), K(0.05, 6), K(0.09, -8), K(0.3, 0)],
        "hem": [K(0, 0), K(0.09, 14), K(0.3, 0)],
        "armB": [K(0, 0), K(0.09, 40), K(0.3, 0)],
    }, loop=False, events=[[0.08, "swing"]])
    r.clip("attackUp", 0.3, {
        "armF": [K(0, 0), K(0.05, 40, 0, 0, 1, 1, "i"), K(0.09, 160, 0, 0, 1, 1, "o"), K(0.3, 0)],
        "nail": [K(0, 0), K(0.05, -40), K(0.09, -40), K(0.3, 0)],
        "body": [K(0, 0), K(0.05, -6, 0, -0.05, 1.05, 0.95), K(0.09, 6, 0, 0.12, 0.95, 1.08, "o"), K(0.3, 0)],
        "head": [K(0, 0), K(0.09, 12), K(0.3, 0)],
    }, loop=False, events=[[0.08, "swing"]])
    r.clip("attackDown", 0.3, {
        "armF": [K(0, 0), K(0.05, 150, 0, 0, 1, 1, "i"), K(0.09, -20, 0, 0, 1, 1, "o"), K(0.3, 0)],
        "nail": [K(0, 0), K(0.05, -40), K(0.09, -40), K(0.3, 0)],
        "body": [K(0, 0), K(0.05, 12, 0, 0.1), K(0.09, -20, 0, -0.1, 1.05, 0.95, "o"), K(0.3, 0)],
        "legF": [K(0, 0), K(0.09, 50), K(0.3, 0)],
        "legB": [K(0, 0), K(0.09, 40), K(0.3, 0)],
        "head": [K(0, 0), K(0.09, -14), K(0.3, 0)],
    }, loop=False, events=[[0.08, "swing"]])
    # Cleaving Arc: coil back and tremble while charging...
    r.clip("charge", 0.2, {
        "armF": loop_keys(0.2, (180,), (177,)),
        "nail": loop_keys(0.2, (-40,), (-38,)),
        "body": loop_keys(0.2, (14, -0.12, -0.08, 1.04, 0.95), (15, -0.1, -0.06, 1.04, 0.95)),
        "hips": loop_keys(0.2, (0, 0, -0.15), (0, 0.03, -0.15)),
        "legF": loop_keys(0.2, (30,), (32,)),
        "legB": loop_keys(0.2, (-26,), (-28,)),
        "head": loop_keys(0.2, (8,), (9,)),
    })
    # ...then release in one huge sweep.
    r.clip("cleave", 0.45, {
        "armF": [K(0, 180), K(0.08, 75, 0, 0, 1, 1, "o"), K(0.45, 0)],
        "nail": [K(0, -40), K(0.08, -40), K(0.45, 0)],
        "body": [K(0, 14, -0.1), K(0.08, -22, 0.45, 0, 1.12, 0.92, "o"), K(0.45, 0)],
        "hips": [K(0, 0, 0, -0.15), K(0.08, 0, 0.3, -0.1), K(0.45, 0)],
        "legF": [K(0, 30), K(0.08, 45), K(0.45, 0)],
        "legB": [K(0, -26), K(0.08, -40), K(0.45, 0)],
        "hem": [K(0, 0), K(0.1, 28), K(0.45, 0)],
    }, loop=False, events=[[0.07, "swing"]])
    # Lumen Bolt: a two-handed thrust with recoil.
    r.clip("bolt", 0.32, {
        "armF": [K(0, 0), K(0.05, 40), K(0.1, 70, 0, 0, 1, 1, "o"), K(0.32, 0)],
        "armB": [K(0, 0), K(0.1, 105), K(0.32, 0)],
        "body": [K(0, 0), K(0.05, -8, 0.1), K(0.1, 10, -0.25, 0, 0.95, 1.05, "o"), K(0.32, 0)],
        "head": [K(0, 0), K(0.1, 8), K(0.32, 0)],
        "hem": [K(0, 0), K(0.1, -14), K(0.32, 0)],
    }, loop=False, events=[[0.08, "cast"]])
    # Taking a hit: snapped backwards, arms thrown out, then recovering.
    r.clip("hurt", 0.4, {
        "body": [K(0, 0), K(0.05, 24, -0.25, 0.1, 0.9, 1.1, "o"), K(0.4, 0)],
        "head": [K(0, 0), K(0.05, 22), K(0.4, 0)],
        "armF": [K(0, 0), K(0.05, -80), K(0.4, 0)],
        "armB": [K(0, 0), K(0.05, 75), K(0.4, 0)],
        "legF": [K(0, 0), K(0.05, -30), K(0.4, 0)],
        "legB": [K(0, 0), K(0.05, 30), K(0.4, 0)],
        "antF": [K(0, 0), K(0.08, -35), K(0.4, 0)],
        "antB": [K(0, 0), K(0.08, -35), K(0.4, 0)],
    }, loop=False)
    # Focus: kneeling, hands drawn in, breathing with the gathering light.
    r.clip("heal", 0.9, {
        "hips": loop_keys(0.9, (0, 0, -0.35), (0, 0, -0.38)),
        "legF": loop_keys(0.9, (70, 0.1, 0.1), (70, 0.1, 0.1)),
        "legB": loop_keys(0.9, (-60, 0, 0.15), (-60, 0, 0.15)),
        "body": loop_keys(0.9, (-10, 0, 0, 1, 1), (-10, 0, 0, 1.03, 1.04)),
        "head": loop_keys(0.9, (-16,), (-12,)),
        "armF": loop_keys(0.9, (30,), (34,)),
        "armB": loop_keys(0.9, (65,), (69,)),
        "nail": loop_keys(0.9, (-60,), (-60,)),
        "antF": loop_keys(0.9, (-10,), (-4,)),
        "antB": loop_keys(0.9, (-8,), (-2,)),
    })
    # Dash: stretched flat into the direction of travel, cloak streaming behind.
    r.clip("dash", 0.18, {
        "root": loop_keys(0.18, (0, 0, 0, 1.25, 0.84), (0, 0, 0, 1.28, 0.82)),
        "body": loop_keys(0.18, (-24, 0.1), (-26, 0.1)),
        "hem": loop_keys(0.18, (40,), (46,)),
        "legF": loop_keys(0.18, (-60,), (-64,)),
        "legB": loop_keys(0.18, (-70,), (-74,)),
        "head": loop_keys(0.18, (8,), (8,)),
        "antF": loop_keys(0.18, (55,), (60,)),
        "antB": loop_keys(0.18, (58,), (62,)),
        "armF": loop_keys(0.18, (-80,), (-84,)),
        "armB": loop_keys(0.18, (-70,), (-74,)),
    })
    # Sidestep: a light hop backwards.
    r.clip("dodge", 0.22, {
        "body": [K(0, 0), K(0.06, 16, 0, 0.2, 0.92, 1.06, "o"), K(0.22, 0)],
        "legF": [K(0, 0), K(0.06, 45), K(0.22, 0)],
        "legB": [K(0, 0), K(0.06, 55), K(0.22, 0)],
        "hem": [K(0, 0), K(0.06, -20), K(0.22, 0)],
        "head": [K(0, 0), K(0.06, 10), K(0.22, 0)],
    }, loop=False)
    # Double jump: a full forward somersault.
    r.clip("flip", 0.34, {
        "root": [K(0, 0, 0, 0, 1, 1, "l"), K(0.17, -180, 0, 1.5, 0.9, 0.9, "l"), K(0.34, -360, 0, 0, 1, 1)],
        "legF": [K(0, 0), K(0.1, 70), K(0.34, 0)],
        "legB": [K(0, 0), K(0.1, 70), K(0.34, 0)],
        "armF": [K(0, 0), K(0.1, -80), K(0.34, 0)],
    }, loop=False)
    # Clinging to a wall (facing away from it): pressed flat, sliding.
    r.clip("wall", 0.4, {
        "body": loop_keys(0.4, (8, -0.2), (9, -0.22)),
        "armB": loop_keys(0.4, (-85,), (-90,)),
        "armF": loop_keys(0.4, (-120,), (-124,)),
        "legB": loop_keys(0.4, (-40,), (-44,)),
        "legF": loop_keys(0.4, (20,), (24,)),
        "hem": loop_keys(0.4, (-20,), (-24,)),
        "antF": loop_keys(0.4, (-20,), (-14,)),
        "antB": loop_keys(0.4, (-18,), (-12,)),
    })
    # Death: staggers, drops to its knees, and topples; the mask rolls free.
    r.clip("death", 1.6, {
        "body": [K(0, 0), K(0.15, 20, -0.2), K(0.6, -8, 0, -0.3), K(1.1, 75, -0.3, -0.9, 1, 1, "i"), K(1.6, 82, -0.35, -1.0)],
        "head": [K(0, 0), K(0.15, 18), K(0.6, -25), K(1.1, 30, 0.4, -0.2), K(1.6, 60, 0.9, -0.5)],
        "hips": [K(0, 0), K(0.6, 0, 0, -0.5), K(1.6, 0, 0, -0.6)],
        "legF": [K(0, 0), K(0.6, 80), K(1.6, 85)],
        "legB": [K(0, 0), K(0.6, -70), K(1.6, -40)],
        "armF": [K(0, 0), K(0.3, -80), K(1.1, 40), K(1.6, 50)],
        "armB": [K(0, 0), K(0.3, 95), K(1.6, 35)],
        "antF": [K(0, 0), K(1.6, -58)],
        "antB": [K(0, 0), K(1.6, -70)],
    }, loop=False, events=[[1.1, "thud"]])
    # Resting on a bench.
    r.clip("sit", 3.0, {
        "hips": loop_keys(3.0, (0, 0, -0.4), (0, 0, -0.42)),
        "legF": loop_keys(3.0, (85, 0.15), (85, 0.15)),
        "legB": loop_keys(3.0, (80, 0.05), (80, 0.05)),
        "body": loop_keys(3.0, (6, 0, 0, 1, 1), (6, 0, 0.02, 1.02, 1.03)),
        "head": loop_keys(3.0, (-8,), (-4,)),
        "antF": loop_keys(3.0, (-6,), (2,)),
        "antB": loop_keys(3.0, (-4,), (4,)),
    })
    return r


def main():
    os.makedirs(OUT, exist_ok=True)
    rigs = [wanderer()]
    try:
        import rigs_extra  # noqa: F401  (NPCs, enemies and bosses live in rigs_extra.py)
        rigs += rigs_extra.all_rigs()
    except ImportError:
        pass
    names = []
    for rig in rigs:
        with open(os.path.join(OUT, rig.name + ".json"), "w") as f:
            json.dump(rig.to_json(), f, separators=(",", ":"))
        names.append(rig.name)
    print("wrote", len(names), "rigs:", ", ".join(names))


if __name__ == "__main__":
    main()
