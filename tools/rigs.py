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

def wanderer(name="wanderer", cloak=(34, 98, 116), cloak_dark=(22, 64, 80), mask=MASK, eye=(255, 190, 90), nail=NAIL, glow=NAIL_GLOW, shade=False,
             lining=(232, 150, 70), scarf=(196, 72, 52), fur=(240, 228, 204), wing=(176, 150, 200), chitin=(58, 36, 50), gold=(226, 180, 90)):
    """The Wanderer: a young moth adventurer. A pale oval mask with big amber eyes, a cream
    fur ruff, feathered fronds for antennae, a teal travelling cloak lined in amber, a rust
    scarf, dusty wings folded under the cloak, a lantern at the hip and a gilded leaf-blade."""
    r = Rig(name, 3.0)
    # A clean, readable silhouette: a big pale mask, a small bell of cloak, thin dark legs
    # that stay visible below it, and a slim blade. Detail is kept to what reads in motion.
    r.bone("root")
    r.bone("hips", "root", (0, 1.4))
    r.bone("legB", "hips", (-0.05, 0.05, -0.3))
    r.bone("legF", "hips", (0.05, 0.05, 0.3))
    r.bone("body", "hips", (0, 0))
    r.bone("hem", "body", (-0.05, 0.1))
    r.bone("scarf", "body", (-0.45, 1.3), rest=-10)
    r.bone("lantern", "body", (-0.55, 0.5, -0.72), rest=-8)
    r.bone("armB", "body", (0.0, 1.1, -0.62), rest=-15)
    r.bone("head", "body", (0.06, 1.5))
    r.bone("antB", "head", (-0.15, 1.05, -0.3), rest=38)
    r.bone("antF", "head", (-0.15, 1.05, 0.3), rest=38)
    r.bone("armF", "body", (0.1, 1.1, 0.66), rest=20)
    r.bone("nail", "armF", (0.02, -0.62, 0.12), rest=40)

    # Legs: thin chitin with small boots, long enough to read every stride.
    for leg in ("legB", "legF"):
        tone = chitin if leg == "legF" else tuple(int(c * 0.7) for c in chitin)
        r.part(leg, "box", (0.26, 1.25, 0.26), (0, -0.62, 0), color=tone)
        r.part(leg, "ball", (0.52, 0.34, 0.42), (0.12, -1.28, 0), color=(126, 76, 50))
    r.part("armB", "box", (0.24, 0.8, 0.24), (0, -0.4, 0), color=chitin)
    # Small folded wings peeking out behind.
    for side in (-1, 1):
        r.part("body", "ball", (0.26, 1.35, 0.85), (-0.85, 1.05, side * 0.42), rot=26, color=wing)
    # The cloak: a bell of teal cloth with the amber lining showing at the front.
    r.part("body", "ball", (1.75, 1.9, 1.6), (-0.05, 0.8, 0), color=cloak)
    r.part("body", "ball", (0.3, 1.1, 0.55), (0.78, 0.72, 0), color=lining)
    r.part("hem", "ball", (2.0, 0.75, 1.8), (-0.08, 0.05, 0), color=cloak_dark)
    for i in range(8):
        a = i / 8 * math.pi * 2
        r.part("hem", "tri", (0.5, 0.55 + 0.15 * (i % 2), 0.32), (math.cos(a) * 0.85 - 0.08, -0.35, math.sin(a) * 0.8), rot=180, color=cloak_dark, flip=(i % 2 == 0))
    # Scarf: wrapped at the throat, its tails stream behind on their own bone.
    r.part("body", "ball", (1.25, 0.42, 1.25), (0.05, 1.35, 0), color=scarf)
    r.part("scarf", "box", (1.1, 0.3, 0.12), (-0.5, 0, 0.3), color=scarf, mat="f")
    r.part("scarf", "box", (0.9, 0.26, 0.12), (-0.45, -0.22, 0.18), rot=-12, color=tuple(int(c * 0.8) for c in scarf), mat="f")
    # A small lantern at the back hip.
    r.part("lantern", "box", (0.1, 0.3, 0.1), (0, -0.12, 0), color=INK)
    r.part("lantern", "ball", (0.44, 0.52, 0.44), (0, -0.48, 0), color=(60, 56, 50), mat="g", alpha=0.25)
    r.part("lantern", "ball", (0.24, 0.3, 0.24), (0, -0.48, 0), color=WARM, mat="n", tag="glow")
    r.part("lantern", "box", (0.4, 0.08, 0.4), (0, -0.2, 0), color=gold, mat="m")
    # Head: a big oval mask with amber eyes and a small glowing gem.
    r.part("head", "ball", (1.7, 1.85, 1.55), (0.05, 0.55, 0), color=mask)
    r.part("head", "ball", (1.35, 0.55, 1.25), (0.12, 0.08, 0), color=MASK_SHADE)
    for side in (-1, 1):
        z = side * 0.35
        r.part("head", "ball", (0.2, 0.66, 0.42), (0.83, 0.55, z), color=eye, mat="n", tag="eye")
        r.part("head", "ball", (0.12, 0.36, 0.2), (0.9, 0.5, z * 0.95), color=(24, 14, 10), tag="eye")
        r.part("head", "ball", (0.06, 0.12, 0.1), (0.95, 0.66, z * 0.9 + 0.05), color=(255, 250, 240), mat="n", tag="eye")
    r.part("head", "box", (0.12, 0.18, 0.18), (0.8, 1.2, 0), rot=45, color=(110, 230, 220), mat="n")
    # Feathered antennae.
    for ant in ("antB", "antF"):
        r.part(ant, "box", (0.09, 0.8, 0.09), (0, 0.38, 0), color=gold)
        for k, (ox, oy, w, h, rot) in enumerate(((-0.05, 0.5, 0.5, 0.24, 70), (-0.2, 0.9, 0.62, 0.26, 55), (-0.45, 1.2, 0.6, 0.24, 40))):
            r.part(ant, "ball", (w, h, 0.1), (ox + 0.12, oy, 0), rot=rot, color=fur if k % 2 == 0 else (250, 238, 214))
    # Sword arm and a slim leaf-blade with a glowing fuller.
    r.part("armF", "box", (0.26, 0.8, 0.26), (0, -0.38, 0), color=chitin)
    r.part("armF", "ball", (0.36, 0.36, 0.36), (0, -0.78, 0), color=(126, 76, 50))
    r.part("nail", "box", (0.16, 0.4, 0.16), (0, -0.15, 0), color=(92, 56, 40))
    r.part("nail", "box", (0.6, 0.12, 0.24), (0, -0.38, 0), color=gold, mat="m")
    r.part("nail", "box", (0.16, 1.75, 0.34), (0, -1.3, 0), color=nail, mat="m")
    r.part("nail", "tri", (0.16, 0.5, 0.34), (0, -2.42, 0), rot=180, color=nail, mat="m")
    r.part("nail", "box", (0.05, 1.6, 0.1), (0.07, -1.25, 0), color=glow, mat="n", alpha=0.2, tag="glow")
    if shade:
        for i, (dx, dy, dz) in enumerate(((-1.1, 1.3, 0.3), (-1.25, 0.6, -0.3), (-1.0, 1.9, 0))):
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
    # Wall slide: back to the wall, one claw dragging on the stone, knees bent, cloak
    # streaming upward, a small judder as it scrapes down.
    r.clip("wall", 0.24, {
        "root": loop_keys(0.24, (0, -0.04, 0), (0, 0.03, 0.03), (0, -0.02, -0.02)),
        "hips": loop_keys(0.24, (0, 0, -0.2, 1.04, 0.95), (0, 0, -0.22, 1.05, 0.94)),
        "body": loop_keys(0.24, (10, -0.25), (12, -0.27), (9, -0.24)),
        "armB": loop_keys(0.24, (-140,), (-146,), (-138,)),
        "armF": loop_keys(0.24, (40,), (46,), (38,)),
        "nail": loop_keys(0.24, (-20,), (-20,), (-20,)),
        "legB": loop_keys(0.24, (-55,), (-60,), (-52,)),
        "legF": loop_keys(0.24, (35,), (40,), (33,)),
        "hem": loop_keys(0.24, (-38,), (-44,), (-36,)),
        "head": loop_keys(0.24, (-6,), (-8,), (-5,)),
        "antF": loop_keys(0.24, (-30,), (-24,), (-32,)),
        "antB": loop_keys(0.24, (-28,), (-22,), (-30,)),
    })
    # ---- Transitions and variations -------------------------------------------------
    # Idle variation: glances toward the viewer, then back over the shoulder, antennae perking.
    r.clip("idleLook", 3.2, {
        "head": [K(0, 0), K(0.45, -4, 0, 0, 1, 1, "io", -38), K(1.3, -2, 0, 0, 1, 1, "io", -38),
                 K(1.75, 6, 0, 0, 1, 1, "io", 24), K(2.5, 6, 0, 0, 1, 1, "io", 24), K(3.2, 0)],
        "antF": [K(0, 0), K(0.4, -14), K(0.65, 5), K(1.75, -10), K(2.0, 4), K(3.2, 0)],
        "antB": [K(0, 0), K(0.45, -12), K(0.7, 4), K(1.8, -9), K(2.05, 3), K(3.2, 0)],
        "body": [K(0, 0), K(0.45, 0, 0.03), K(1.75, -2, -0.03), K(3.2, 0)],
        "armF": [K(0, 0), K(1.75, -6), K(3.2, 0)],
        "hem": [K(0, 0), K(1.75, 4), K(3.2, 0)],
    }, loop=False)
    # Starting to run: a quick crouch and lean before the first stride.
    r.clip("runStart", 0.18, {
        "hips": [K(0, 0, 0, 0, 1, 1), K(0.08, 0, 0, -0.2, 1.08, 0.92), K(0.18, 0, 0, 0)],
        "body": [K(0, 0), K(0.08, -22, 0.12), K(0.18, -11, 0.05)],
        "legF": [K(0, 0), K(0.08, -35), K(0.18, 38)],
        "legB": [K(0, 0), K(0.08, 30), K(0.18, -42)],
        "hem": [K(0, 0), K(0.18, 18)],
        "antF": [K(0, 0), K(0.18, 26)],
        "antB": [K(0, 0), K(0.18, 28)],
        "armF": [K(0, 0), K(0.18, -25)],
    }, loop=False)
    # Stopping: a braced skid, the cloak and antennae swinging on past, then settling.
    r.clip("runStop", 0.32, {
        "hips": [K(0, 0, 0, 0), K(0.08, 0, 0, -0.15, 1.06, 0.94, "o"), K(0.32, 0)],
        "body": [K(0, -10, 0.05), K(0.08, 14, -0.1, -0.05, 1.05, 0.95, "o"), K(0.32, 0)],
        "legF": [K(0, 38), K(0.08, -40), K(0.32, 0)],
        "legB": [K(0, -30), K(0.08, -18), K(0.32, 0)],
        "hem": [K(0, 20), K(0.1, -26), K(0.32, 0)],
        "head": [K(0, 4), K(0.08, -8), K(0.32, 0)],
        "antF": [K(0, 28), K(0.1, -18), K(0.32, 0)],
        "antB": [K(0, 30), K(0.12, -16), K(0.32, 0)],
        "armF": [K(0, 10), K(0.1, -20), K(0.32, 0)],
    }, loop=False)
    # The top of a jump: legs tucked, the blade held out, the cloak floating.
    r.clip("apex", 0.5, {
        "legF": loop_keys(0.5, (45,), (48,)),
        "legB": loop_keys(0.5, (30,), (34,)),
        "hips": loop_keys(0.5, (0, 0, 0.05), (0, 0, 0.07)),
        "body": loop_keys(0.5, (-4,), (-5,)),
        "hem": loop_keys(0.5, (-14,), (-18,)),
        "armF": loop_keys(0.5, (40,), (44,)),
        "armB": loop_keys(0.5, (-30,), (-34,)),
        "antF": loop_keys(0.5, (10,), (14,)),
        "antB": loop_keys(0.5, (12,), (16,)),
    })
    # Pressing against a wall: leaning in, hands on the stone, feet shuffling.
    r.clip("push", 0.9, {
        "body": loop_keys(0.9, (-18, 0.15), (-20, 0.17)),
        "armF": loop_keys(0.9, (80,), (86,)),
        "armB": loop_keys(0.9, (70,), (76,)),
        "legF": loop_keys(0.9, (-20,), (-8,)),
        "legB": loop_keys(0.9, (25,), (35,)),
        "head": loop_keys(0.9, (6,), (4,)),
        "hem": loop_keys(0.9, (10,), (14,)),
        "nail": loop_keys(0.9, (-30,), (-30,)),
    })
    # Soul dive: curled into a spearhead, blade pointed straight down.
    r.clip("dive", 0.2, {
        "root": loop_keys(0.2, (0, 0, 0, 0.9, 1.12), (0, 0, 0, 0.88, 1.14)),
        "body": loop_keys(0.2, (-4,), (-6,)),
        "armF": loop_keys(0.2, (-20,), (-22,)),
        "nail": loop_keys(0.2, (-40,), (-40,)),
        "armB": loop_keys(0.2, (60,), (64,)),
        "legF": loop_keys(0.2, (60,), (64,)),
        "legB": loop_keys(0.2, (50,), (54,)),
        "hem": loop_keys(0.2, (-50,), (-58,)),
        "antF": loop_keys(0.2, (40,), (50,)),
        "antB": loop_keys(0.2, (42,), (52,)),
        "head": loop_keys(0.2, (-12,), (-14,)),
    })
    # Soul scream: head thrown back, arms flung wide.
    r.clip("shriek", 0.6, {
        "head": [K(0, 0), K(0.08, 30, 0, 0.1), K(0.45, 32, 0, 0.1), K(0.6, 0)],
        "body": [K(0, 0), K(0.06, 8, 0, -0.08, 1.06, 0.94), K(0.12, -10, 0, 0.1, 0.94, 1.08, "o"), K(0.45, -8), K(0.6, 0)],
        "armF": [K(0, 0), K(0.1, 150), K(0.45, 155), K(0.6, 0)],
        "armB": [K(0, 0), K(0.1, -150), K(0.45, -155), K(0.6, 0)],
        "antF": [K(0, 0), K(0.1, -40), K(0.45, -45), K(0.6, 0)],
        "antB": [K(0, 0), K(0.1, -42), K(0.45, -47), K(0.6, 0)],
        "hem": [K(0, 0), K(0.12, -30), K(0.6, 0)],
    }, loop=False, events=[[0.1, "cast"]])
    # Kicking off a wall.
    r.clip("wallJump", 0.26, {
        "body": [K(0, 10, -0.1), K(0.06, -18, 0.15, 0, 0.94, 1.08, "o"), K(0.26, 0)],
        "legF": [K(0, 50), K(0.06, -30), K(0.26, 0)],
        "legB": [K(0, 40), K(0.06, -45), K(0.26, 0)],
        "armB": [K(0, -60), K(0.08, 60), K(0.26, 0)],
        "hem": [K(0, 0), K(0.08, 30), K(0.26, 0)],
        "antF": [K(0, -20), K(0.1, 30), K(0.26, 0)],
        "antB": [K(0, -18), K(0.1, 32), K(0.26, 0)],
    }, loop=False)
    # Catching a wall: a hard little squash against the stone before the slide.
    r.clip("wallGrab", 0.16, {
        "hips": [K(0, 0, -0.1, -0.1, 0.85, 1.12, "o"), K(0.16, 0, 0, -0.2, 1.04, 0.95)],
        "body": [K(0, 22, -0.3), K(0.16, 10, -0.25)],
        "armB": [K(0, -170), K(0.16, -140)],
        "legB": [K(0, -80), K(0.16, -55)],
        "legF": [K(0, 55), K(0.16, 35)],
        "hem": [K(0, 20), K(0.16, -38)],
        "antF": [K(0, 30), K(0.16, -30)],
        "antB": [K(0, 32), K(0.16, -28)],
    }, loop=False, events=[[0, "thud"]])
    # ---- Nail arts ---------------------------------------------------------------------
    # Dash Slash: the whole body flattens into a lunging thrust, blade straight ahead.
    r.clip("dashSlash", 0.45, {
        "root": [K(0, 0, 0, 0, 1.3, 0.82, "o"), K(0.16, 0, 0, 0, 1.2, 0.86), K(0.45, 0, 0, 0, 1, 1)],
        "armF": [K(0, 60), K(0.04, 95, 0, 0, 1, 1, "o"), K(0.3, 90), K(0.45, 0)],
        "nail": [K(0, -40), K(0.04, -125), K(0.3, -125), K(0.45, 0)],
        "body": [K(0, -30, 0.2), K(0.16, -34, 0.3), K(0.45, 0)],
        "legF": [K(0, -40), K(0.16, -70), K(0.45, 0)],
        "legB": [K(0, -60), K(0.16, -80), K(0.45, 0)],
        "hem": [K(0, 40), K(0.2, 50), K(0.45, 0)],
        "armB": [K(0, -60), K(0.2, -80), K(0.45, 0)],
        "antF": [K(0, 55), K(0.3, 60), K(0.45, 0)],
        "antB": [K(0, 58), K(0.3, 62), K(0.45, 0)],
        "head": [K(0, 10), K(0.45, 0)],
    }, loop=False, events=[[0.04, "swing"]])
    # Cyclone Slash: blade held straight out, spinning round and round.
    spin = [K(0, 0, 0, 0, 1, 1, "l", 0)]
    for i in range(1, 6):
        spin.append(K(i * 0.13, 0, 0, 0.15, 1, 1, "l", -180 * i))
    spin.append(K(0.8, 0, 0, 0, 1, 1, "io", -900))
    r.clip("cyclone", 0.8, {
        "root": spin,
        "armF": [K(0, 0), K(0.06, 90), K(0.68, 92), K(0.8, 0)],
        "nail": [K(0, 0), K(0.06, -130), K(0.68, -130), K(0.8, 0)],
        "armB": [K(0, 0), K(0.06, -90), K(0.68, -92), K(0.8, 0)],
        "legF": [K(0, 0), K(0.06, 30), K(0.68, 34), K(0.8, 0)],
        "legB": [K(0, 0), K(0.06, -20), K(0.68, -24), K(0.8, 0)],
        "hem": [K(0, 0), K(0.1, -40), K(0.68, -44), K(0.8, 0)],
        "antF": [K(0, 0), K(0.1, 50), K(0.8, 0)],
        "antB": [K(0, 0), K(0.1, 52), K(0.8, 0)],
    }, loop=False, events=[[0.05, "swing"], [0.31, "swing"], [0.57, "swing"]])
    # ---- The combo ---------------------------------------------------------------------
    # Second strike: a rising backhand from low behind to high in front.
    r.clip("attackSide2", 0.32, {
        "armF": [K(0, 0), K(0.05, -70, 0, 0, 1, 1, "i"), K(0.1, 150, 0, 0, 1, 1, "o"), K(0.32, 0)],
        "nail": [K(0, 0), K(0.05, -20), K(0.1, -50), K(0.32, 0)],
        "body": [K(0, 0), K(0.05, -12, 0.08, -0.08, 1.04, 0.96), K(0.1, 12, 0.18, 0.08, 0.96, 1.06, "o"), K(0.32, 0)],
        "head": [K(0, 0), K(0.05, -6), K(0.1, 10), K(0.32, 0)],
        "hem": [K(0, 0), K(0.1, -18), K(0.32, 0)],
        "armB": [K(0, 0), K(0.1, -50), K(0.32, 0)],
        "legF": [K(0, 0), K(0.05, 20), K(0.32, 0)],
        "legB": [K(0, 0), K(0.05, -20), K(0.32, 0)],
    }, loop=False, events=[[0.08, "swing"]])
    # Finisher: coil high, step in and bring the blade down in one heavy chop.
    r.clip("attackFinish", 0.55, {
        "armF": [K(0, 0), K(0.12, 200, 0, 0, 1, 1, "i"), K(0.18, 45, 0, 0, 1, 1, "o"), K(0.55, 0)],
        "nail": [K(0, 0), K(0.12, -50), K(0.18, -45), K(0.55, 0)],
        "body": [K(0, 0), K(0.12, 18, -0.15, 0.1, 0.95, 1.08), K(0.18, -28, 0.5, -0.15, 1.14, 0.88, "o"), K(0.4, -12, 0.2, -0.05), K(0.55, 0)],
        "hips": [K(0, 0, 0, 0), K(0.12, 0, -0.1, 0.1), K(0.18, 0, 0.35, -0.25, 1.1, 0.9, "o"), K(0.55, 0)],
        "legF": [K(0, 0), K(0.12, -20), K(0.18, 50), K(0.55, 0)],
        "legB": [K(0, 0), K(0.12, 20), K(0.18, -45), K(0.55, 0)],
        "head": [K(0, 0), K(0.12, 10), K(0.18, -16), K(0.55, 0)],
        "hem": [K(0, 0), K(0.12, -20), K(0.2, 34), K(0.55, 0)],
        "armB": [K(0, 0), K(0.12, -80), K(0.18, 70), K(0.55, 0)],
        "antF": [K(0, 0), K(0.12, 20), K(0.18, -30), K(0.55, 0)],
        "antB": [K(0, 0), K(0.12, 22), K(0.18, -32), K(0.55, 0)],
    }, loop=False, events=[[0.17, "swing"], [0.2, "thud"]])
    # Swinging on the Silkline: one arm up holding the thread, legs and cloak trailing.
    r.clip("swing", 0.8, {
        "armF": loop_keys(0.8, (165,), (172,)),
        "nail": loop_keys(0.8, (-30,), (-34,)),
        "armB": loop_keys(0.8, (140,), (150,)),
        "body": loop_keys(0.8, (-8, 0, 0, 0.96, 1.06), (-4, 0, 0, 0.97, 1.05)),
        "legF": loop_keys(0.8, (-25,), (-15,)),
        "legB": loop_keys(0.8, (20,), (30,)),
        "hem": loop_keys(0.8, (-24,), (-14,)),
        "head": loop_keys(0.8, (-10,), (-6,)),
        "antF": loop_keys(0.8, (30,), (40,)),
        "antB": loop_keys(0.8, (34,), (44,)),
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
    hero_motion(r)
    return r


def hero_motion(r):
    """The core moveset, animated for snap and readability: strong key poses reached fast
    (ease-out), brief holds on contact frames, overlapping cloak/scarf/antennae that trail the
    body, and squash and stretch on every take-off, landing and strike.

    Angle guide (the side plane): + swings a hanging limb's end forward. armF rests at 20 and
    the nail at +40 on it, so arm offset + nail offset + 60 is the blade's angle from
    straight down (90 = level forward, 180 = straight up)."""
    O = "o"
    # Idle: a slow breath, the cloak and scarf drifting, blade held low behind.
    r.clip("idle", 2.4, {
        "hips": loop_keys(2.4, (0, 0, 0, 1, 1), (0, 0, -0.03, 1.02, 0.98)),
        "body": loop_keys(2.4, (2, 0, 0, 1, 1), (3, 0, 0.02, 1.02, 1.03)),
        "head": loop_keys(2.4, (0, 0, 0), (-3, 0, -0.03)),
        "antF": loop_keys(2.4, (0,), (7,), (-2,), (5,)),
        "antB": loop_keys(2.4, (0,), (-4,), (6,), (-2,)),
        "hem": loop_keys(2.4, (0,), (3,)),
        "scarf": loop_keys(2.4, (0,), (8,), (2,), (6,)),
        "lantern": loop_keys(2.4, (0,), (6,), (0,), (-5,)),
        "armF": loop_keys(2.4, (-45,), (-42,)),
        "nail": loop_keys(2.4, (-10,), (-8,)),
        "armB": loop_keys(2.4, (10,), (6,)),
        "legF": loop_keys(2.4, (6,), (6,)),
        "legB": loop_keys(2.4, (-6,), (-6,)),
    })
    # Run: a quick, bouncy scamper. Big clear strides, the body pitched forward and bobbing
    # up on each passing step, the cloak and scarf streaming, blade trailed low behind.
    run = 0.36
    r.clip("run", run, {
        "legF": loop_keys(run, (55, 0, 0), (5, 0, 0.2), (-50, 0, 0), (0, 0, 0)),
        "legB": loop_keys(run, (-50, 0, 0), (0, 0, 0), (55, 0, 0), (5, 0, 0.2)),
        "hips": loop_keys(run, (0, 0, -0.08, 1.05, 0.95), (0, 0, 0.2, 0.96, 1.05), (0, 0, -0.08, 1.05, 0.95), (0, 0, 0.2, 0.96, 1.05)),
        "body": loop_keys(run, (-16, 0.08), (-12, 0.08), (-16, 0.08), (-12, 0.08)),
        "head": loop_keys(run, (8,), (3,), (8,), (3,)),
        "hem": loop_keys(run, (26,), (34,), (26,), (34,)),
        "scarf": loop_keys(run, (40,), (55,), (40,), (55,)),
        "antF": loop_keys(run, (30,), (42,), (30,), (42,)),
        "antB": loop_keys(run, (34,), (46,), (34,), (46,)),
        "armF": loop_keys(run, (-60,), (-45,), (-60,), (-45,)),
        "nail": loop_keys(run, (-15,), (-10,), (-15,), (-10,)),
        "armB": loop_keys(run, (40,), (0,), (-40,), (0,)),
        "lantern": loop_keys(run, (25,), (35,), (25,), (35,)),
    })
    # Take-off: one frame of crouch.
    r.clip("jumpStart", 0.08, {
        "hips": [K(0, 0, 0, 0, 1, 1), K(0.08, 0, 0, -0.4, 1.18, 0.8, O)],
        "legF": [K(0, 0), K(0.08, 40)], "legB": [K(0, 0), K(0.08, -35)],
        "body": [K(0, 0), K(0.08, -8)], "hem": [K(0, 0), K(0.08, 12)],
    }, loop=False)
    # Rising: stretched tall, legs trailing, everything loose swept down by the air.
    r.clip("rise", 0.4, {
        "hips": loop_keys(0.4, (0, 0, 0.1, 0.88, 1.14), (0, 0, 0.12, 0.9, 1.12)),
        "legF": loop_keys(0.4, (-20, 0, 0.1), (-24, 0, 0.1)),
        "legB": loop_keys(0.4, (-40, 0, 0.1), (-44, 0, 0.1)),
        "body": loop_keys(0.4, (-4,), (-6,)),
        "hem": loop_keys(0.4, (-14,), (-18,)),
        "scarf": loop_keys(0.4, (-40,), (-48,)),
        "antF": loop_keys(0.4, (50,), (55,)), "antB": loop_keys(0.4, (52,), (58,)),
        "armF": loop_keys(0.4, (-70,), (-74,)), "nail": loop_keys(0.4, (-10,), (-10,)),
        "armB": loop_keys(0.4, (-40,), (-44,)),
    })
    # Top of the arc: legs tucked, a moment of float.
    r.clip("apex", 0.5, {
        "legF": loop_keys(0.5, (55, 0, 0.12), (58, 0, 0.12)), "legB": loop_keys(0.5, (35, 0, 0.12), (38, 0, 0.12)),
        "hips": loop_keys(0.5, (0, 0, 0.08, 1.03, 0.97), (0, 0, 0.1, 1.03, 0.97)),
        "body": loop_keys(0.5, (-2,), (-4,)),
        "hem": loop_keys(0.5, (-20,), (-26,)), "scarf": loop_keys(0.5, (10,), (20,)),
        "armF": loop_keys(0.5, (-30,), (-26,)), "armB": loop_keys(0.5, (30,), (34,)),
        "antF": loop_keys(0.5, (10,), (16,)), "antB": loop_keys(0.5, (12,), (18,)),
    })
    # Falling: cloak billowing up, legs apart and reaching for the ground, arms out.
    r.clip("fall", 0.3, {
        "hem": loop_keys(0.3, (-32, 0, 0.12), (-40, 0, 0.16)),
        "scarf": loop_keys(0.3, (70,), (85,)),
        "body": loop_keys(0.3, (4, 0, 0, 1.04, 0.97), (6, 0, 0, 1.05, 0.96)),
        "armF": loop_keys(0.3, (40,), (48,)), "nail": loop_keys(0.3, (-30,), (-30,)),
        "armB": loop_keys(0.3, (-80,), (-90,)),
        "legF": loop_keys(0.3, (20,), (26,)), "legB": loop_keys(0.3, (-18,), (-24,)),
        "antF": loop_keys(0.3, (-20,), (-28,)), "antB": loop_keys(0.3, (-18,), (-26,)),
        "head": loop_keys(0.3, (-8,), (-10,)),
    })
    # Landing: a hard squash, cloak slapping down, then a quick spring back.
    r.clip("land", 0.2, {
        "hips": [K(0, 0, 0, -0.5, 1.28, 0.7, O), K(0.09, 0, 0, 0.05, 0.95, 1.06), K(0.2, 0, 0, 0, 1, 1)],
        "legF": [K(0, 55), K(0.2, 6)], "legB": [K(0, -45), K(0.2, -6)],
        "body": [K(0, -10), K(0.09, 4), K(0.2, 2)],
        "head": [K(0, -12), K(0.09, 5), K(0.2, 0)],
        "hem": [K(0, 30), K(0.12, -8), K(0.2, 0)],
        "scarf": [K(0, 60), K(0.2, 0)],
        "antF": [K(0, -40), K(0.12, 14), K(0.2, 0)], "antB": [K(0, -38), K(0.12, 12), K(0.2, 0)],
        "armF": [K(0, -20), K(0.2, -45)],
    }, loop=False)
    # Side slash: a flick up behind, then the blade whips level through the front and snaps
    # down, body lunging after it. Contact at 0.06; the follow-through pose holds briefly.
    r.clip("attackSide", 0.26, {
        "armF": [K(0, 0), K(0.03, 150, 0, 0, 1, 1, O), K(0.06, 50, 0, 0, 1, 1, O), K(0.12, -5), K(0.18, -8), K(0.26, -40)],
        "nail": [K(0, 0), K(0.03, -30), K(0.06, -20), K(0.12, 0), K(0.26, -10)],
        "body": [K(0, 0), K(0.03, 10, -0.1, 0.05, 0.94, 1.06), K(0.06, -18, 0.3, 0, 1.1, 0.93, O), K(0.18, -12, 0.2), K(0.26, 0)],
        "hips": [K(0, 0, 0, 0), K(0.06, 0, 0.25, -0.1), K(0.18, 0, 0.18, -0.08), K(0.26, 0)],
        "legF": [K(0, 6), K(0.06, 45), K(0.26, 6)], "legB": [K(0, -6), K(0.06, -35), K(0.26, -6)],
        "head": [K(0, 0), K(0.03, 8), K(0.06, -8), K(0.26, 0)],
        "hem": [K(0, 0), K(0.06, 26), K(0.26, 0)], "scarf": [K(0, 0), K(0.08, 60), K(0.26, 10)],
        "armB": [K(0, 0), K(0.06, 55), K(0.26, 0)],
        "antF": [K(0, 0), K(0.08, 30), K(0.26, 0)], "antB": [K(0, 0), K(0.08, 32), K(0.26, 0)],
    }, loop=False, events=[[0.05, "swing"]])
    # Second strike: a rising backhand from low behind to high in front.
    r.clip("attackSide2", 0.28, {
        "armF": [K(0, -40), K(0.03, -70, 0, 0, 1, 1, O), K(0.07, 120, 0, 0, 1, 1, O), K(0.14, 140), K(0.2, 135), K(0.28, 0)],
        "nail": [K(0, -10), K(0.03, 0), K(0.07, -70), K(0.14, -60), K(0.28, 0)],
        "body": [K(0, 0), K(0.03, -12, 0, -0.1, 1.05, 0.95), K(0.07, 12, 0.25, 0.12, 0.93, 1.1, O), K(0.2, 8, 0.15), K(0.28, 0)],
        "hips": [K(0, 0, 0, 0), K(0.07, 0, 0.22, 0.05), K(0.28, 0)],
        "legF": [K(0, 6), K(0.03, 25), K(0.07, 40), K(0.28, 6)], "legB": [K(0, -6), K(0.07, -30), K(0.28, -6)],
        "head": [K(0, 0), K(0.03, -8), K(0.07, 12), K(0.28, 0)],
        "hem": [K(0, 0), K(0.07, -24), K(0.28, 0)], "scarf": [K(0, 0), K(0.09, -40), K(0.28, 0)],
        "armB": [K(0, 0), K(0.07, -60), K(0.28, 0)],
        "antF": [K(0, 0), K(0.09, -30), K(0.28, 0)], "antB": [K(0, 0), K(0.09, -32), K(0.28, 0)],
    }, loop=False, events=[[0.06, "swing"]])
    # Finisher: rear right back, blade overhead, then a leaping chop that slams down in front.
    r.clip("attackFinish", 0.5, {
        "armF": [K(0, 0), K(0.1, 195, 0, 0, 1, 1, O), K(0.16, 35, 0, 0, 1, 1, O), K(0.3, 25), K(0.5, -40)],
        "nail": [K(0, 0), K(0.1, -40), K(0.16, -35), K(0.3, -30), K(0.5, -10)],
        "body": [K(0, 0), K(0.1, 20, -0.2, 0.15, 0.92, 1.12), K(0.16, -32, 0.55, -0.2, 1.18, 0.85, O), K(0.3, -26, 0.45, -0.15), K(0.5, 0)],
        "hips": [K(0, 0, 0, 0), K(0.1, 0, -0.15, 0.25), K(0.16, 0, 0.45, -0.3, 1.12, 0.88, O), K(0.3, 0, 0.4, -0.25), K(0.5, 0)],
        "legF": [K(0, 6), K(0.1, -30), K(0.16, 60), K(0.3, 55), K(0.5, 6)],
        "legB": [K(0, -6), K(0.1, 25), K(0.16, -50), K(0.3, -45), K(0.5, -6)],
        "head": [K(0, 0), K(0.1, 12), K(0.16, -18), K(0.5, 0)],
        "hem": [K(0, 0), K(0.1, -26), K(0.18, 40), K(0.5, 0)], "scarf": [K(0, 0), K(0.1, -30), K(0.2, 80), K(0.5, 10)],
        "armB": [K(0, 0), K(0.1, -90), K(0.16, 80), K(0.5, 0)],
        "antF": [K(0, 0), K(0.1, 25), K(0.18, -40), K(0.5, 0)], "antB": [K(0, 0), K(0.1, 27), K(0.18, -42), K(0.5, 0)],
    }, loop=False, events=[[0.15, "swing"], [0.17, "thud"]])
    # Up slash: a crouch, then the whole body stretches up behind the blade.
    r.clip("attackUp", 0.26, {
        "armF": [K(0, 0), K(0.03, 20, 0, 0, 1, 1, O), K(0.06, 150, 0, 0, 1, 1, O), K(0.14, 165), K(0.26, -40)],
        "nail": [K(0, 0), K(0.03, -20), K(0.06, -30), K(0.14, -20), K(0.26, -10)],
        "body": [K(0, 0), K(0.03, -8, 0, -0.1, 1.08, 0.92), K(0.06, 8, 0, 0.15, 0.9, 1.14, O), K(0.14, 6, 0, 0.1), K(0.26, 0)],
        "hips": [K(0, 0, 0, 0), K(0.03, 0, 0, -0.15), K(0.06, 0, 0, 0.1), K(0.26, 0)],
        "head": [K(0, 0), K(0.06, 16), K(0.26, 0)],
        "hem": [K(0, 0), K(0.06, -20), K(0.26, 0)], "scarf": [K(0, 0), K(0.08, -50), K(0.26, 0)],
        "legF": [K(0, 6), K(0.03, 30), K(0.06, 0), K(0.26, 6)], "legB": [K(0, -6), K(0.03, -25), K(0.06, 0), K(0.26, -6)],
        "armB": [K(0, 0), K(0.06, -40), K(0.26, 0)],
    }, loop=False, events=[[0.05, "swing"]])
    # Down slash (air): blade raised, then driven straight down, legs tucked.
    r.clip("attackDown", 0.26, {
        "armF": [K(0, 0), K(0.03, 140, 0, 0, 1, 1, O), K(0.06, -15, 0, 0, 1, 1, O), K(0.14, -20), K(0.26, -20)],
        "nail": [K(0, 0), K(0.03, -30), K(0.06, -45), K(0.14, -45), K(0.26, -10)],
        "body": [K(0, 0), K(0.03, 12, 0, 0.1), K(0.06, -24, 0, -0.1, 1.06, 0.94, O), K(0.14, -20), K(0.26, 0)],
        "legF": [K(0, 0), K(0.06, 70), K(0.26, 20)], "legB": [K(0, 0), K(0.06, 55), K(0.26, 10)],
        "head": [K(0, 0), K(0.06, -16), K(0.26, 0)],
        "hem": [K(0, 0), K(0.06, -30), K(0.26, 0)], "scarf": [K(0, 0), K(0.08, -60), K(0.26, 0)],
    }, loop=False, events=[[0.05, "swing"]])
    # Dash: flattened into a streak, everything loose flung straight back.
    r.clip("dash", 0.16, {
        "root": loop_keys(0.16, (0, 0, 0, 1.3, 0.82), (0, 0, 0, 1.32, 0.8)),
        "body": loop_keys(0.16, (-30, 0.1), (-32, 0.1)),
        "hem": loop_keys(0.16, (55,), (62,)), "scarf": loop_keys(0.16, (80,), (90,)),
        "legF": loop_keys(0.16, (-65,), (-70,)), "legB": loop_keys(0.16, (-80,), (-84,)),
        "head": loop_keys(0.16, (10,), (10,)),
        "antF": loop_keys(0.16, (65,), (70,)), "antB": loop_keys(0.16, (68,), (72,)),
        "armF": loop_keys(0.16, (-95,), (-98,)), "nail": loop_keys(0.16, (-10,), (-10,)),
        "armB": loop_keys(0.16, (-80,), (-84,)),
    })
    # Wall slide: back pressed to the wall, the rear hand clawing the stone, knees up, the
    # cloak and scarf lifted by the slide, a tiny judder as it scrapes down.
    r.clip("wall", 0.2, {
        "root": loop_keys(0.2, (0, -0.05, 0), (0, -0.02, 0.03), (0, -0.05, -0.02)),
        "hips": loop_keys(0.2, (0, -0.1, -0.15, 1.04, 0.95), (0, -0.1, -0.17, 1.05, 0.94)),
        "body": loop_keys(0.2, (12, -0.2), (14, -0.22), (11, -0.2)),
        "armB": loop_keys(0.2, (-150,), (-156,), (-148,)),
        "armF": loop_keys(0.2, (-20,), (-15,), (-22,)), "nail": loop_keys(0.2, (-10,), (-10,), (-10,)),
        "legB": loop_keys(0.2, (-30,), (-34,), (-28,)), "legF": loop_keys(0.2, (55,), (60,), (52,)),
        "hem": loop_keys(0.2, (-40,), (-46,), (-38,)), "scarf": loop_keys(0.2, (-70,), (-80,), (-66,)),
        "head": loop_keys(0.2, (-8,), (-10,), (-7,)),
        "antF": loop_keys(0.2, (-35,), (-28,), (-36,)), "antB": loop_keys(0.2, (-32,), (-26,), (-34,)),
    })
    # Kicking off a wall: legs snap straight, the body launches out and up.
    r.clip("wallJump", 0.24, {
        "body": [K(0, 12, -0.15), K(0.05, -20, 0.15, 0.1, 0.9, 1.12, O), K(0.24, -4)],
        "hips": [K(0, 0, 0, -0.15, 1.1, 0.9), K(0.05, 0, 0, 0.1, 0.92, 1.1, O), K(0.24, 0)],
        "legF": [K(0, 55), K(0.05, -40), K(0.24, -15)], "legB": [K(0, -30), K(0.05, -60), K(0.24, -30)],
        "armB": [K(0, -150), K(0.06, 60), K(0.24, 0)], "armF": [K(0, -20), K(0.06, -70), K(0.24, -50)],
        "hem": [K(0, -40), K(0.08, 35), K(0.24, 0)], "scarf": [K(0, -70), K(0.08, 70), K(0.24, 20)],
        "antF": [K(0, -30), K(0.1, 45), K(0.24, 10)], "antB": [K(0, -28), K(0.1, 47), K(0.24, 12)],
    }, loop=False)
    # Taking a hit: snapped backwards, limbs flung, then gathering itself.
    r.clip("hurt", 0.36, {
        "body": [K(0, 0), K(0.04, 28, -0.3, 0.1, 0.86, 1.14, O), K(0.36, 0)],
        "hips": [K(0, 0, 0, 0), K(0.04, 0, -0.2, 0.1), K(0.36, 0)],
        "head": [K(0, 0), K(0.04, 25), K(0.36, 0)],
        "armF": [K(0, 0), K(0.04, -90), K(0.36, -45)], "armB": [K(0, 0), K(0.04, 90), K(0.36, 0)],
        "legF": [K(0, 0), K(0.04, -35), K(0.36, 6)], "legB": [K(0, 0), K(0.04, 40), K(0.36, -6)],
        "hem": [K(0, 0), K(0.06, -30), K(0.36, 0)], "scarf": [K(0, 0), K(0.06, -60), K(0.36, 0)],
        "antF": [K(0, 0), K(0.06, -40), K(0.36, 0)], "antB": [K(0, 0), K(0.06, -40), K(0.36, 0)],
    }, loop=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    rigs = [wanderer()]
    try:
        import rigs_extra  # noqa: F401  (NPCs, enemies and bosses live in rigs_extra.py)
        rigs += rigs_extra.all_rigs()
    except ImportError:
        pass
    import rigs_champions  # the Hall of Trials' champions
    rigs += rigs_champions.all_rigs()
    names = []
    for rig in rigs:
        with open(os.path.join(OUT, rig.name + ".json"), "w") as f:
            json.dump(rig.to_json(), f, separators=(",", ":"))
        names.append(rig.name)
    print("wrote", len(names), "rigs:", ", ".join(names))


if __name__ == "__main__":
    main()
