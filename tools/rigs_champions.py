"""The five champions of the Hall of Trials (see rigs.py for the format).

Every one is an original design for Vesperdeep:
  sessa     Sessa, the Glaive Dancer   a dragonfly duelist with a twin-bladed glaive
  mirra     Mirra, the Reed Skater     a long-legged water strider with reed sickles
  carapace  The Hollow Warden          a tiny grub inside a huge suit of bronze armour
  vell      Magister Vell              a floating beetle sorcerer with orbiting lanterns
  pyrrhe    Pyrrhe, Ember Conductor    a tall fire-beetle ringmaster with a flaming baton

Clips: idle, move, windup, attack, shoot, throw, leap, slam, spin, dive, uppercut,
vanish, appear, roar, stagger, death (a rig may skip some; the runtime falls back).
"""

import math

from rigs import MASK, K, Rig, loop_keys, mask_face


def glow_eyes(r):
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"


def common(r, body="body", head="head", arm=None, drop=-1.0):
    """Roar, stagger, death, vanish and appear, shared by every champion."""
    roar = {
        body: [K(0, 0), K(0.3, 14, -0.2, 0.1, 0.95, 1.08), K(0.45, 16, -0.25, 0.15), K(1.3, 14, -0.2, 0.1), K(1.6, 0)],
        head: [K(0, 0), K(0.3, 25), K(0.4, 30), K(0.5, 25), K(0.6, 30), K(0.7, 25), K(1.3, 25), K(1.6, 0)],
    }
    if arm:
        roar[arm] = [K(0, 0), K(0.3, 160), K(1.3, 165), K(1.6, 0)]
    r.clip("roar", 1.6, roar, loop=False, events=[[0.3, "roar"]])
    r.clip("stagger", 1.1, {
        body: [K(0, 0), K(0.1, 20, -0.3, -0.2, 1.08, 0.9), K(0.25, 14, -0.25, -0.2), K(0.4, 22, -0.3, -0.25), K(1.1, 0)],
        head: [K(0, 0), K(0.1, -20), K(1.1, 0)],
    }, loop=False)
    r.clip("death", 1.6, {
        body: [K(0, 0), K(0.2, 20, -0.2), K(0.8, -10, 0, drop * 0.5), K(1.6, 70, 0, drop, 1.05, 0.9)],
        head: [K(0, 0), K(0.2, -25), K(1.6, 40)],
    }, loop=False)
    r.clip("vanish", 0.3, {"root": [K(0, 0, 0, 0, 1, 1), K(0.1, 0, 0, 0.1, 1.2, 0.8, "o"), K(0.3, 0, 0, 0.3, 0.1, 1.8)]}, loop=False)
    r.clip("appear", 0.3, {"root": [K(0, 0, 0, 0.3, 0.1, 1.8), K(0.12, 0, 0, 0, 1.15, 0.9, "o"), K(0.3, 0, 0, 0, 1, 1)]}, loop=False, events=[[0, "cast"]])


# ============================================================================ Sessa

def sessa():
    """Sessa, the Glaive Dancer: a slender dragonfly knight in teal plate. Four glassy wings,
    a long jade visor with magenta eyes, and a staff with a crescent blade at each end."""
    r = Rig("sessa", 3.7)
    plate, plate2, dark, jade, eye, wing = (40, 110, 120), (28, 80, 92), (18, 30, 38), (206, 236, 220), (255, 90, 170), (150, 240, 230)
    r.bone("root")
    for side, s in (("B", -1), ("F", 1)):
        up = r.bone("thigh" + side, "root", (0, 3.4, s * 0.45))
        lo = r.bone("shin" + side, up, (0, -1.7))
        r.part(up, "box", (0.34, 1.8, 0.34), (0, -0.85, 0), color=dark if s < 0 else plate2)
        r.part(lo, "box", (0.28, 1.8, 0.28), (0, -0.85, 0), color=dark)
        r.part(lo, "tri", (0.3, 0.6, 0.3), (0.2, -1.75, 0), rot=100, color=plate)
    r.bone("body", "root", (0, 3.4))
    r.bone("tail", "body", (-0.6, 0.6), rest=100)
    r.bone("head", "body", (0.35, 2.6))
    r.bone("armB", "body", (0.1, 2.1, -0.7), rest=-20)
    r.bone("armF", "body", (0.2, 2.1, 0.75), rest=30)
    r.bone("glaive", "armF", (0, -1.4), rest=-60)
    for side, s in (("U", 1), ("D", -1)):
        r.bone("wing" + side, "body", (-0.3, 2.2, 0), rest=40 + s * 10)
    # Torso: a narrow segmented thorax with a bright chest plate.
    r.part("body", "ball", (1.6, 2.6, 1.5), (0, 1.2, 0), color=plate2)
    r.part("body", "ball", (1.4, 1.2, 1.6), (0.15, 1.9, 0), color=plate)
    r.part("body", "box", (0.3, 1.0, 0.9), (0.72, 1.3, 0), rot=-8, color=eye, mat="n", alpha=0.25, tag="glow")
    r.part("body", "ball", (1.2, 0.5, 1.2), (0, 0.1, 0), color=dark)
    # Long dragonfly abdomen trailing behind, banded.
    for i in range(6):
        r.part("tail", "ball", (0.7 - i * 0.05, 0.9, 0.7 - i * 0.05), (0, 0.45 + i * 0.75, 0), color=plate if i % 2 == 0 else dark)
    r.part("tail", "tri", (0.4, 0.8, 0.3), (0, 5.1, 0), color=eye, mat="n")
    # Wings: long panes of glass, veined.
    for side in ("U", "D"):
        for z in (-0.35, 0.35):
            r.part("wing" + side, "ball", (0.6, 4.6, 0.12), (0, 2.3, z), color=wing, mat="g", alpha=0.55)
            r.part("wing" + side, "box", (0.06, 4.2, 0.14), (0, 2.2, z), color=(90, 180, 180), alpha=0.3)
    # Head: a long visor-mask with a crest.
    r.part("head", "ball", (1.3, 1.9, 1.2), (0.1, 0.6, 0), color=jade)
    r.part("head", "ball", (1.0, 0.5, 1.1), (0.2, 0.05, 0), color=(170, 200, 190))
    for s in (-1, 1):
        r.part("head", "ball", (0.2, 0.3, 0.42), (0.62, 0.72, s * 0.25), color=eye, mat="n", tag="eye")
    r.part("head", "tri", (0.3, 1.6, 0.25), (-0.35, 1.7, 0), rot=30, color=plate)
    r.part("head", "tri", (0.2, 1.0, 0.2), (-0.1, 1.6, 0), rot=15, color=eye, mat="n", alpha=0.3)
    # Arms.
    r.part("armB", "box", (0.28, 1.5, 0.28), (0, -0.7, 0), color=dark)
    r.part("armF", "box", (0.32, 1.5, 0.32), (0, -0.7, 0), color=plate2)
    # The glaive: a long shaft with a crescent blade at each end.
    r.part("glaive", "box", (0.2, 7.0, 0.2), (0, 0, 0), color=(60, 50, 70))
    for end in (1, -1):
        r.part("glaive", "tri", (0.22, 1.6, 0.9), (0.35, end * 3.9, 0), rot=0 if end > 0 else 180, color=(230, 235, 245), mat="m")
        r.part("glaive", "tri", (0.22, 1.2, 0.9), (-0.3, end * 3.6, 0), rot=0 if end > 0 else 180, color=(230, 235, 245), mat="m", flip=True)
        r.part("glaive", "box", (0.06, 1.3, 0.24), (0.1, end * 3.7, 0), color=eye, mat="n", alpha=0.3, tag="glow")
    flutter = {"wingU": loop_keys(0.12, (0,), (30,)), "wingD": loop_keys(0.12, (20,), (-10,))}
    r.clip("idle", 1.6, flutter | {
        "body": loop_keys(1.6, (0, 0, 0), (2, 0, 0.12)),
        "tail": loop_keys(1.6, (0,), (6,)),
        "thighF": loop_keys(1.6, (10,), (12,)), "thighB": loop_keys(1.6, (-12,), (-10,)),
        "shinF": loop_keys(1.6, (-20,), (-22,)), "shinB": loop_keys(1.6, (-15,), (-18,)),
        "armF": loop_keys(1.6, (0,), (4,)), "head": loop_keys(1.6, (0,), (-3,)),
    })
    r.clip("move", 0.4, flutter | {
        "thighF": loop_keys(0.4, (40,), (-30,)), "thighB": loop_keys(0.4, (-30,), (40,)),
        "shinF": loop_keys(0.4, (-10,), (-50,)), "shinB": loop_keys(0.4, (-50,), (-10,)),
        "body": loop_keys(0.4, (-14, 0, 0), (-16, 0, 0.12)), "tail": loop_keys(0.4, (14,), (18,)),
    })
    r.clip("windup", 0.35, flutter | {
        "armF": loop_keys(0.35, (160,), (164,)), "glaive": loop_keys(0.35, (40,), (44,)),
        "body": loop_keys(0.35, (14, -0.3, -0.3), (15, -0.3, -0.32)),
        "thighF": loop_keys(0.35, (50,), (52,)), "shinF": loop_keys(0.35, (-60,), (-62,)),
        "thighB": loop_keys(0.35, (-35,), (-36,)), "shinB": loop_keys(0.35, (-30,), (-31,)),
    })
    r.clip("attack", 0.4, flutter | {
        "armF": [K(0, 160), K(0.06, 80, 0, 0, 1, 1, "o"), K(0.4, 70)],
        "glaive": [K(0, 40), K(0.06, -120, 0, 0, 1, 1, "o"), K(0.4, -110)],
        "body": [K(0, 14), K(0.06, -30, 0.6, 0, 1.08, 0.95, "o"), K(0.4, -25, 0.4)],
        "thighF": [K(0, 50), K(0.06, 70), K(0.4, 65)], "thighB": [K(0, -35), K(0.06, -60), K(0.4, -55)],
        "tail": [K(0, 0), K(0.1, 30), K(0.4, 25)],
    }, loop=False, events=[[0.06, "thrust"]])
    r.clip("throw", 0.45, flutter | {
        "armF": [K(0, 170), K(0.08, 60, 0, 0, 1, 1, "o"), K(0.45, 0)],
        "glaive": [K(0, 40), K(0.08, -90), K(0.45, 0)],
        "body": [K(0, 12, -0.2), K(0.08, -20, 0.3, 0, 1.05, 0.96, "o"), K(0.45, 0)],
    }, loop=False, events=[[0.08, "swing"]])
    r.clips["shoot"] = r.clips["throw"]
    r.clip("leap", 0.5, flutter | {
        "thighF": loop_keys(0.5, (80,), (82,)), "thighB": loop_keys(0.5, (70,), (72,)),
        "shinF": loop_keys(0.5, (-110,), (-112,)), "shinB": loop_keys(0.5, (-100,), (-102,)),
        "body": loop_keys(0.5, (-10,), (-12,)), "armF": loop_keys(0.5, (120,), (124,)), "tail": loop_keys(0.5, (-20,), (-24,)),
    })
    r.clip("dive", 0.3, flutter | {
        "body": loop_keys(0.3, (-60, 0, 0), (-62, 0, 0)), "armF": loop_keys(0.3, (90,), (92,)),
        "glaive": loop_keys(0.3, (-110,), (-112,)), "thighF": loop_keys(0.3, (-30,), (-32,)), "thighB": loop_keys(0.3, (-40,), (-42,)),
        "tail": loop_keys(0.3, (40,), (44,)),
    })
    r.clip("slam", 0.5, {"body": [K(0, -20, 0, -1.0, 1.15, 0.82, "o"), K(0.5, 0)], "thighF": [K(0, 70), K(0.5, 0)],
                         "shinF": [K(0, -90), K(0.5, 0)], "thighB": [K(0, -50), K(0.5, 0)], "armF": [K(0, 90), K(0.5, 0)]},
           loop=False, events=[[0, "quake"]])
    spin = [K(0, 0, 0, 0, 1, 1, "l", 0)] + [K(0.15 * i, 0, 0, 0.3, 1, 1, "l", -180 * i) for i in range(1, 5)]
    r.clip("spin", 0.6, flutter | {"root": spin, "armF": loop_keys(0.6, (90,), (92,)), "glaive": loop_keys(0.6, (-90,), (-90,)),
                                   "armB": loop_keys(0.6, (-90,), (-92,))}, events=[[0, "swing"], [0.3, "swing"]])
    common(r, arm="armF")
    glow_eyes(r)
    return r


# ============================================================================ Mirra

def mirra():
    """Mirra, the Reed Skater: a water strider who never quite touches the floor. A low,
    long body on four splayed stilts, a cream mask with orange eyes, and a curved reed
    sickle on each forearm."""
    r = Rig("mirra", 2.5)
    shell, shell2, leg, reed, eye, mask = (104, 88, 52), (78, 66, 40), (46, 40, 30), (160, 220, 96), (255, 160, 60), (240, 230, 206)
    r.bone("root")
    r.bone("body", "root", (0, 3.0))
    r.bone("head", "body", (1.9, 0.5))
    r.part("body", "ball", (4.4, 1.5, 1.8), (-0.2, 0, 0), color=shell)
    r.part("body", "ball", (3.2, 0.9, 1.5), (-0.4, 0.6, 0), color=shell2)
    for i, x in enumerate((-1.6, -0.6, 0.4)):
        r.part("body", "ball", (0.9, 0.35, 1.9), (x, 0.2, 0), color=(200, 180, 110))
    r.part("body", "ball", (2.0, 0.9, 1.3), (-2.4, -0.1, 0), rot=-8, color=shell2)
    r.part("body", "ball", (0.4, 0.4, 0.4), (-3.3, 0.0, 0), color=reed, mat="n", tag="glow")
    mask_face(r, "head", (0.25, 0.2), (1.6, 1.5), "round", color=mask, eye_color=eye)
    for s in (-1, 1):
        r.part("head", "box", (0.08, 1.8, 0.08), (-0.1, 1.3, s * 0.3), rot=30, color=leg)
        r.part("head", "ball", (0.2, 0.2, 0.2), (-0.55, 2.1, s * 0.3), color=reed, mat="n")
    legs = {}
    for i, (x, name) in enumerate(((1.2, "fore"), (-1.0, "hind"))):
        base = -38 if i == 0 else 38
        for side, s in (("L", -1), ("R", 1)):
            up = r.bone(f"{name}{side}", "body", (x, 0, s * 0.8), rest=base)
            lo = r.bone(f"{name}{side}b", up, (0, 2.3), rest=-base * 1.75)
            r.part(up, "box", (0.22, 2.4, 0.22), (0, 1.15, 0), color=leg)
            r.part(up, "ball", (0.38, 0.38, 0.38), (0, 2.3, 0), color=shell2)
            r.part(lo, "box", (0.16, 4.6, 0.16), (0, -2.2, 0), color=leg)
            r.part(lo, "ball", (0.6, 0.16, 0.6), (0, -4.5, 0), color=(120, 200, 220), mat="g", alpha=0.3)
            legs[up] = (i, s)
    for side, s in (("L", -1), ("R", 1)):
        arm = r.bone("arm" + side, "body", (1.6, -0.1, s * 0.6), rest=70)
        blade = r.bone("blade" + side, arm, (0, -1.4), rest=-60)
        r.part(arm, "box", (0.25, 1.5, 0.25), (0, -0.7, 0), color=leg)
        for k in range(3):
            r.part(blade, "box", (0.2, 0.75, 0.28), (k * 0.25, -0.3 - k * 0.6, 0), rot=25 + k * 20, color=reed, mat="n" if k == 2 else "p", alpha=0.1 if k == 2 else 0)

    def stance(length, amp, bob, extra=None):
        out = {}
        for up, (i, s) in legs.items():
            ph = (i + (0 if s < 0 else 1)) % 2
            a0, a1 = (amp, -amp) if ph == 0 else (-amp, amp)
            out[up] = loop_keys(length, (a0, 0, 0, 1, 1, "io", 0, -22 * s), (a1, 0, 0, 1, 1, "io", 0, -22 * s))
        out["body"] = loop_keys(length, (0, 0, 0), (0, 0, bob))
        if extra:
            out.update(extra)
        return out

    r.clip("idle", 2.0, stance(2.0, 3, 0.12, {"head": loop_keys(2.0, (0,), (-5,)), "armL": loop_keys(2.0, (0,), (5,)), "armR": loop_keys(2.0, (4,), (0,))}))
    r.clip("move", 0.5, stance(0.5, 16, 0.05, {"body": loop_keys(0.5, (-4, 0, 0, 1.05, 0.96), (-4, 0, 0.05, 1.05, 0.96))}))
    r.clip("windup", 0.4, stance(0.4, 2, 0, {"body": loop_keys(0.4, (12, -0.4, -0.4), (13, -0.4, -0.42)),
                                             "armL": loop_keys(0.4, (130,), (134,)), "armR": loop_keys(0.4, (110,), (114,)),
                                             "bladeL": loop_keys(0.4, (40,), (42,)), "bladeR": loop_keys(0.4, (40,), (42,))}))
    r.clip("attack", 0.35, stance(0.35, 20, 0, {
        "body": loop_keys(0.35, (-10, 0.4, -0.3, 1.1, 0.9), (-10, 0.4, -0.3, 1.1, 0.9)),
        "armL": loop_keys(0.35, (20,), (60,)), "armR": loop_keys(0.35, (60,), (20,)),
        "bladeL": loop_keys(0.35, (-60,), (-30,)), "bladeR": loop_keys(0.35, (-30,), (-60,)),
    }), events=[[0.05, "slash"]])
    r.clip("throw", 0.4, {"armR": [K(0, 150), K(0.08, 30, 0, 0, 1, 1, "o"), K(0.4, 0)], "bladeR": [K(0, 40), K(0.08, -80), K(0.4, 0)],
                          "armL": [K(0, 120), K(0.12, 20, 0, 0, 1, 1, "o"), K(0.4, 0)],
                          "body": [K(0, 10, -0.2), K(0.08, -10, 0.3, 0, 1.05, 0.95, "o"), K(0.4, 0)]}, loop=False, events=[[0.08, "swing"]])
    r.clips["shoot"] = r.clips["throw"]
    r.clip("leap", 0.5, stance(0.5, 0, 0, {"body": loop_keys(0.5, (-20, 0, 0, 0.95, 1.05), (-22, 0, 0, 0.95, 1.05)),
                                           "armL": loop_keys(0.5, (100,), (104,)), "armR": loop_keys(0.5, (100,), (104,))}))
    r.clip("dive", 0.3, stance(0.3, 0, 0, {"body": loop_keys(0.3, (-40,), (-42,)), "armL": loop_keys(0.3, (60,), (60,)), "armR": loop_keys(0.3, (60,), (60,)),
                                           "bladeL": loop_keys(0.3, (-80,), (-80,)), "bladeR": loop_keys(0.3, (-80,), (-80,))}))
    r.clip("slam", 0.5, {"body": [K(0, 0, 0, -1.2, 1.2, 0.75, "o"), K(0.5, 0)]}, loop=False, events=[[0, "quake"]])
    common(r, arm="armR", drop=-2.0)
    glow_eyes(r)
    return r


# ============================================================================ Carapace

def carapace():
    """The Hollow Warden: a suit of bronze armour far too big for the grub inside. Its visor
    glows orange where the little creature peers out; it drags a spiked mace on a pole."""
    r = Rig("carapace", 4.6)
    bronze, bronze2, dark, rust, glow = (150, 110, 70), (112, 80, 52), (40, 32, 28), (130, 70, 44), (255, 150, 60)
    r.bone("root")
    for side, s in (("B", -1), ("F", 1)):
        leg = r.bone("leg" + side, "root", (0, 2.6, s * 1.3))
        r.part(leg, "ball", (1.5, 2.4, 1.4), (0, -1.0, 0), color=bronze2 if s < 0 else bronze)
        r.part(leg, "ball", (2.0, 0.8, 1.6), (0.3, -2.3, 0), color=dark)
    r.bone("body", "root", (0, 2.6))
    r.bone("head", "body", (0.8, 5.0))
    r.bone("armB", "body", (0.2, 4.2, -2.2), rest=20)
    r.bone("armF", "body", (0.4, 4.2, 2.3), rest=40)
    r.bone("mace", "armF", (0, -2.2), rest=-50)
    # A great rounded cuirass with riveted bands.
    r.part("body", "ball", (5.4, 5.6, 4.6), (0, 2.4, 0), color=bronze)
    r.part("body", "ball", (4.6, 1.2, 4.8), (0.1, 1.0, 0), color=bronze2)
    r.part("body", "ball", (4.2, 1.0, 4.8), (0.2, 3.6, 0), color=bronze2)
    for i in range(5):
        a = -0.8 + i * 0.4
        r.part("body", "ball", (0.35, 0.35, 0.35), (math.cos(a) * 2.6, 2.4 + math.sin(a) * 2.6, 2.1), color=(220, 190, 120), mat="m")
    for s in (-1, 1):
        r.part("body", "ball", (2.4, 1.6, 1.8), (0, 4.7, s * 2.1), color=bronze)  # pauldrons
        r.part("body", "tri", (0.4, 1.2, 0.4), (0, 5.8, s * 2.2), color=rust)
    # Helm: a bucket with a narrow visor and the grub's glowing eye behind it.
    r.part("head", "ball", (3.0, 2.8, 2.8), (0, 0.8, 0), color=bronze)
    r.part("head", "box", (0.4, 0.5, 2.2), (1.35, 0.8, 0), color=dark)
    r.part("head", "ball", (0.3, 0.4, 0.4), (1.4, 0.8, 0.3), color=glow, mat="n", tag="eye")
    r.part("head", "tri", (0.5, 1.8, 0.5), (-0.6, 2.6, 0), rot=25, color=rust)
    r.part("head", "tri", (0.4, 1.4, 0.4), (0.3, 2.5, 0), rot=10, color=rust)
    # Arms and the mace.
    for arm in ("armB", "armF"):
        r.part(arm, "ball", (1.2, 2.4, 1.2), (0, -1.0, 0), color=bronze2)
        r.part(arm, "ball", (1.3, 1.1, 1.3), (0, -2.2, 0), color=dark)
    r.part("mace", "box", (0.35, 6.5, 0.35), (0, -2.8, 0), color=(70, 56, 46))
    r.part("mace", "ball", (2.6, 2.6, 2.6), (0, -6.4, 0), color=(90, 86, 90), mat="m")
    for k in range(8):
        a = k / 8 * math.pi * 2
        r.part("mace", "tri", (0.5, 1.0, 0.5), (math.cos(a) * 1.4, -6.4 + math.sin(a) * 1.4, 0), rot=math.degrees(a) - 90, color=(200, 196, 200), mat="m")
    for z in (-1.3, 1.3):
        r.part("mace", "tri", (0.5, 1.0, 0.5), (0, -6.4, z), color=(200, 196, 200), mat="m")
    walk = {"legF": loop_keys(1.1, (20,), (-20,)), "legB": loop_keys(1.1, (-20,), (20,)),
            "body": loop_keys(1.1, (4, 0, 0), (-4, 0, 0.25), (4, 0, 0), (-4, 0, 0.25)),
            "armF": loop_keys(1.1, (0,), (8,)), "mace": loop_keys(1.1, (0,), (-6,))}
    r.clip("idle", 2.4, {"body": loop_keys(2.4, (0, 0, 0, 1, 1), (0, 0, -0.1, 1.02, 0.98)), "head": loop_keys(2.4, (0,), (-4,)),
                         "armF": loop_keys(2.4, (0,), (4,)), "armB": loop_keys(2.4, (0,), (-4,))})
    r.clip("move", 1.1, walk)
    r.clip("windup", 0.5, {"armF": loop_keys(0.5, (170,), (174,)), "mace": loop_keys(0.5, (40,), (44,)),
                           "body": loop_keys(0.5, (14, -0.4, -0.3), (15, -0.4, -0.32)), "legF": loop_keys(0.5, (30,), (31,)),
                           "legB": loop_keys(0.5, (-25,), (-26,)), "head": loop_keys(0.5, (10,), (12,))})
    r.clip("attack", 0.7, {"armF": [K(0, 170), K(0.12, -10, 0, 0, 1, 1, "o"), K(0.5, -10), K(0.7, 0)],
                           "mace": [K(0, 40), K(0.12, -20), K(0.5, -20), K(0.7, 0)],
                           "body": [K(0, 14), K(0.12, -26, 0.6, -0.3, 1.1, 0.9, "o"), K(0.5, -22, 0.5, -0.3), K(0.7, 0)],
                           "legF": [K(0, 30), K(0.12, 45), K(0.7, 0)], "legB": [K(0, -25), K(0.12, -40), K(0.7, 0)]},
           loop=False, events=[[0.12, "quake"]])
    r.clip("leap", 0.9, {"legF": loop_keys(0.9, (50,), (52,)), "legB": loop_keys(0.9, (40,), (42,)), "armF": loop_keys(0.9, (180,), (184,)),
                         "mace": loop_keys(0.9, (30,), (34,)), "body": loop_keys(0.9, (-8,), (-10,))})
    r.clip("slam", 0.6, {"body": [K(0, -20, 0, -1.2, 1.15, 0.8, "o"), K(0.6, 0)], "armF": [K(0, -10), K(0.6, 0)], "mace": [K(0, -20), K(0.6, 0)],
                         "legF": [K(0, 45), K(0.6, 0)], "legB": [K(0, -40), K(0.6, 0)]}, loop=False, events=[[0, "quake"]])
    r.clip("shoot", 0.5, {"armB": [K(0, 0), K(0.1, 150), K(0.5, 0)], "head": [K(0, 0), K(0.1, 20), K(0.5, 0)]}, loop=False)
    common(r, arm="armF", drop=-1.8)
    glow_eyes(r)
    return r


# ============================================================================ Vell

def vell():
    """Magister Vell: a beetle sorcerer adrift in indigo robes under a great domed shell-hat,
    trailing a lantern staff, with three small lanterns circling him."""
    r = Rig("vell", 3.8)
    robe, robe2, gold, light, shell, mask = (54, 42, 100), (38, 30, 74), (224, 184, 96), (150, 220, 255), (70, 60, 120), (232, 226, 240)
    r.bone("root")
    r.bone("body", "root", (0, 1.8))
    r.bone("hem", "body", (0, -0.2))
    r.bone("head", "body", (0.2, 3.6))
    r.bone("hat", "head", (0, 1.2))
    r.bone("armF", "body", (0.4, 2.8, 1.0), rest=60)
    r.bone("staff", "armF", (0, -1.4), rest=-60)
    r.bone("armB", "body", (0.3, 2.8, -1.0), rest=50)
    r.bone("orbit", "body", (0, 2.0))
    for k in range(3):
        r.bone(f"lamp{k}", "orbit", (0, 0))
    r.part("body", "ball", (2.8, 4.6, 2.6), (0, 1.3, 0), color=robe)
    r.part("body", "box", (0.3, 3.4, 0.6), (1.25, 1.2, 0), color=gold, mat="m")
    r.part("body", "ball", (2.2, 0.6, 2.4), (0, 3.2, 0), color=gold, mat="m")
    r.part("hem", "ball", (3.4, 1.4, 3.0), (0, -0.4, 0), color=robe2)
    for i in range(7):
        a = i / 7 * math.pi * 2
        r.part("hem", "tri", (0.6, 1.4, 0.35), (math.cos(a) * 1.3, -1.4, math.sin(a) * 1.1), rot=180, color=robe2, flip=i % 2 == 0)
    mask_face(r, "head", (0.1, 0.3), (1.6, 1.8), "drop", color=mask, eye_color=light)
    r.part("hat", "ball", (4.0, 2.2, 3.6), (-0.2, 0.3, 0), color=shell)
    r.part("hat", "ball", (4.3, 0.4, 3.9), (-0.2, -0.4, 0), color=gold, mat="m")
    for s in (-1, 1):
        r.part("hat", "ball", (0.5, 0.5, 0.2), (0.2, 0.6, s * 1.6), color=light, mat="n", tag="glow")
    r.part("hat", "tri", (0.4, 1.2, 0.4), (-0.3, 1.9, 0), rot=-15, color=gold, mat="m")
    for arm in ("armF", "armB"):
        r.part(arm, "box", (0.55, 1.6, 0.55), (0, -0.7, 0), color=robe2)
        r.part(arm, "ball", (0.5, 0.5, 0.5), (0, -1.5, 0), color=(40, 34, 30))
    r.part("staff", "box", (0.22, 6.0, 0.22), (0, 1.0, 0), color=(80, 60, 44))
    r.part("staff", "ball", (0.9, 1.1, 0.9), (0, 4.4, 0), color=(60, 56, 50), mat="g", alpha=0.3)
    r.part("staff", "ball", (0.5, 0.6, 0.5), (0, 4.4, 0), color=light, mat="n", tag="glow")
    r.part("staff", "box", (1.0, 0.15, 0.3), (0, 3.7, 0), color=gold, mat="m")
    for k in range(3):
        a = k / 3 * math.pi * 2
        x, z = math.cos(a) * 3.2, math.sin(a) * 3.2
        r.part(f"lamp{k}", "ball", (0.7, 0.9, 0.7), (x, 0, z), color=(60, 56, 50), mat="g", alpha=0.25)
        r.part(f"lamp{k}", "ball", (0.4, 0.5, 0.4), (x, 0, z), color=light, mat="n", tag="glow")
        r.part(f"lamp{k}", "box", (0.6, 0.12, 0.6), (x, 0.5, z), color=gold, mat="m")
    orbit = [K(0, 0, 0, 0, 1, 1, "l", 0), K(1.5, 0, 0, 0.3, 1, 1, "l", 180), K(3.0, 0, 0, 0, 1, 1, "l", 360)]
    fast = [K(0, 0, 0, 0, 1, 1, "l", 0), K(0.4, 0, 0, 0, 1, 1, "l", 180), K(0.8, 0, 0, 0, 1, 1, "l", 360)]
    base = {"root": loop_keys(3.0, (0, 0, 0), (0, 0, 0.5)), "hem": loop_keys(3.0, (6,), (-6,)), "orbit": orbit,
            "staff": loop_keys(3.0, (0,), (4,)), "head": loop_keys(3.0, (-4,), (-8,))}
    r.clip("idle", 3.0, base)
    r.clip("move", 3.0, base | {"body": loop_keys(3.0, (-14,), (-16,)), "hem": loop_keys(3.0, (24,), (28,))})
    r.clip("windup", 0.8, {"orbit": fast, "armF": loop_keys(0.8, (150,), (156,)), "armB": loop_keys(0.8, (130,), (136,)),
                           "staff": loop_keys(0.8, (60,), (64,)), "body": loop_keys(0.8, (12,), (14,)), "hat": loop_keys(0.8, (-6,), (-8,))})
    r.clip("shoot", 0.45, {"armF": [K(0, 150), K(0.08, 50, 0, 0, 1, 1, "o"), K(0.45, 0)], "staff": [K(0, 60), K(0.08, -30), K(0.45, 0)],
                           "body": [K(0, 12), K(0.08, -12, 0.3, 0, 1.05, 0.95, "o"), K(0.45, 0)], "orbit": fast}, loop=False, events=[[0.08, "cast"]])
    r.clips["throw"] = r.clips["shoot"]
    r.clip("attack", 0.4, {"body": loop_keys(0.4, (-30, 0, 0, 0.9, 1.12), (-31, 0, 0, 0.9, 1.12)), "hem": loop_keys(0.4, (30,), (32,)), "orbit": fast})
    r.clip("dive", 0.3, {"body": loop_keys(0.3, (0, 0, 0, 0.85, 1.2), (0, 0, 0, 0.85, 1.2)), "armF": loop_keys(0.3, (170,), (170,)),
                         "armB": loop_keys(0.3, (170,), (170,)), "hem": loop_keys(0.3, (-30,), (-34,)), "orbit": fast})
    r.clip("slam", 0.6, {"body": [K(0, 0, 0, -0.8, 1.2, 0.8, "o"), K(0.6, 0)], "hem": [K(0, 30), K(0.6, 0)]}, loop=False, events=[[0, "quake"]])
    common(r, arm="armF")
    glow_eyes(r)
    return r


# ============================================================================ Pyrrhe

def pyrrhe():
    """Pyrrhe, the Ember Conductor: a tall, thin fire beetle in a crimson tailcoat with a
    horned crest like a top hat. Conducts the flames with a baton that never goes out."""
    r = Rig("pyrrhe", 4.4)
    coat, coat2, gold, dark, ember, mask = (160, 30, 44), (110, 20, 32), (236, 186, 90), (24, 16, 20), (255, 140, 50), (236, 228, 214)
    r.bone("root")
    for side, s in (("B", -1), ("F", 1)):
        up = r.bone("thigh" + side, "root", (0, 3.6, s * 0.5))
        lo = r.bone("shin" + side, up, (0, -1.8))
        r.part(up, "box", (0.36, 1.9, 0.36), (0, -0.9, 0), color=dark)
        r.part(lo, "box", (0.3, 1.9, 0.3), (0, -0.9, 0), color=dark)
        r.part(lo, "ball", (0.8, 0.35, 0.45), (0.25, -1.85, 0), color=(60, 30, 30))
    r.bone("body", "root", (0, 3.6))
    r.bone("tails", "body", (-0.7, 0.6), rest=-10)
    r.bone("head", "body", (0.25, 3.4))
    r.bone("crest", "head", (-0.1, 1.2))
    r.bone("armF", "body", (0.2, 2.8, 0.8), rest=30)
    r.bone("baton", "armF", (0, -1.6), rest=-70)
    r.bone("armB", "body", (0.1, 2.8, -0.8), rest=-10)
    # Tailcoat and waistcoat.
    r.part("body", "ball", (1.9, 3.4, 1.7), (0, 1.5, 0), color=coat)
    r.part("body", "ball", (1.1, 2.4, 1.2), (0.45, 1.5, 0), color=gold)
    for y in (0.9, 1.5, 2.1):
        r.part("body", "ball", (0.2, 0.2, 0.2), (0.98, y, 0), color=dark)
    r.part("body", "ball", (2.4, 0.9, 2.2), (0, 3.0, 0), color=coat2)  # collar
    r.part("body", "tri", (0.4, 0.9, 1.4), (0.8, 3.1, 0), rot=-20, color=(250, 240, 230))  # cravat
    for z in (-0.4, 0.4):
        r.part("tails", "box", (0.3, 3.6, 0.6), (-0.2, -1.6, z), rot=-12, color=coat2)
        r.part("tails", "tri", (0.3, 0.7, 0.6), (-0.6, -3.6, z), rot=160, color=ember, mat="n", alpha=0.2)
    # Head: a narrow mask with ember eyes; a crest of two swept horns like a hat brim.
    mask_face(r, "head", (0.1, 0.4), (1.3, 1.8), "slit", color=mask, eye_color=ember)
    r.part("crest", "box", (1.6, 2.2, 1.3), (-0.1, 0.9, 0), color=dark)
    r.part("crest", "box", (2.4, 0.2, 1.8), (0.1, -0.1, 0), color=dark)
    r.part("crest", "box", (1.7, 0.3, 1.35), (-0.1, 0.35, 0), color=coat)
    r.part("crest", "tri", (0.4, 1.4, 0.4), (-0.7, 2.5, 0), rot=35, color=ember, mat="n")
    # Arms and the flaming baton.
    for arm in ("armF", "armB"):
        r.part(arm, "box", (0.36, 1.7, 0.36), (0, -0.8, 0), color=coat2)
        r.part(arm, "ball", (0.45, 0.45, 0.45), (0, -1.65, 0), color=(250, 240, 230))
    r.part("baton", "box", (0.14, 2.6, 0.14), (0, 1.1, 0), color=dark)
    r.part("baton", "ball", (0.35, 0.35, 0.35), (0, -0.2, 0), color=gold, mat="m")
    r.part("baton", "ball", (0.6, 0.9, 0.6), (0, 2.6, 0), color=ember, mat="n", tag="flame")
    r.part("baton", "ball", (0.35, 0.55, 0.35), (0, 2.75, 0), color=(255, 230, 150), mat="n", tag="flame")
    walk = {"thighF": loop_keys(0.5, (35,), (-30,)), "thighB": loop_keys(0.5, (-30,), (35,)),
            "shinF": loop_keys(0.5, (-10,), (-45,)), "shinB": loop_keys(0.5, (-45,), (-10,)),
            "body": loop_keys(0.5, (-8, 0, 0), (-10, 0, 0.12)), "tails": loop_keys(0.5, (25,), (32,))}
    r.clip("idle", 1.8, {
        "body": loop_keys(1.8, (0, 0, 0, 1, 1), (-3, 0, -0.05, 1.01, 1.02)), "tails": loop_keys(1.8, (0,), (6,)),
        "armF": loop_keys(1.8, (20,), (40,), (10,), (35,)), "baton": loop_keys(1.8, (0,), (15,), (-10,), (10,)),
        "armB": loop_keys(1.8, (-30,), (-26,)), "head": loop_keys(1.8, (0,), (-5,)),
        "thighF": loop_keys(1.8, (8,), (8,)), "thighB": loop_keys(1.8, (-6,), (-6,)),
    })
    r.clip("move", 0.5, walk)
    r.clip("windup", 0.4, {"armF": loop_keys(0.4, (175,), (178,)), "baton": loop_keys(0.4, (30,), (34,)), "armB": loop_keys(0.4, (-80,), (-84,)),
                           "body": loop_keys(0.4, (16, -0.3, -0.3), (17, -0.3, -0.32)), "thighF": loop_keys(0.4, (50,), (51,)),
                           "shinF": loop_keys(0.4, (-70,), (-71,)), "thighB": loop_keys(0.4, (-40,), (-41,)), "tails": loop_keys(0.4, (-10,), (-14,))})
    r.clip("attack", 0.35, {"root": loop_keys(0.35, (0, 0, 0, 1.25, 0.85), (0, 0, 0, 1.28, 0.84)), "body": loop_keys(0.35, (-35, 0.2), (-36, 0.2)),
                            "armF": loop_keys(0.35, (90,), (92,)), "baton": loop_keys(0.35, (-80,), (-82,)), "tails": loop_keys(0.35, (60,), (66,)),
                            "thighF": loop_keys(0.35, (-50,), (-52,)), "thighB": loop_keys(0.35, (-70,), (-72,))})
    r.clip("shoot", 0.4, {"armF": [K(0, 175), K(0.08, 60, 0, 0, 1, 1, "o"), K(0.4, 20)], "baton": [K(0, 30), K(0.08, -40), K(0.4, 0)],
                          "body": [K(0, 16), K(0.08, -12, 0.3, 0, 1.05, 0.96, "o"), K(0.4, 0)]}, loop=False, events=[[0.08, "cast"]])
    r.clips["throw"] = r.clips["shoot"]
    r.clip("uppercut", 0.6, {"root": [K(0, 0, 0, 0, 0.9, 1.15), K(0.6, 0, 0, 0, 0.92, 1.12)],
                             "armF": [K(0, 20), K(0.08, 185, 0, 0, 1, 1, "o"), K(0.6, 180)], "baton": [K(0, 0), K(0.08, -20), K(0.6, -20)],
                             "armB": [K(0, 0), K(0.08, 160), K(0.6, 160)], "body": [K(0, 10), K(0.08, -8, 0, 0.2), K(0.6, -6)],
                             "thighF": [K(0, 40), K(0.08, 10), K(0.6, 5)], "thighB": [K(0, -30), K(0.08, -10), K(0.6, -5)],
                             "tails": [K(0, 0), K(0.1, -50), K(0.6, -45)]}, loop=False, events=[[0.08, "radiance"]])
    r.clip("leap", 0.5, {"thighF": loop_keys(0.5, (80,), (82,)), "thighB": loop_keys(0.5, (70,), (72,)),
                         "shinF": loop_keys(0.5, (-100,), (-102,)), "shinB": loop_keys(0.5, (-100,), (-102,)),
                         "armF": loop_keys(0.5, (140,), (144,)), "tails": loop_keys(0.5, (-30,), (-34,))})
    r.clip("dive", 0.3, {"root": loop_keys(0.3, (0, 0, 0, 1.2, 0.85), (0, 0, 0, 1.22, 0.84)), "body": loop_keys(0.3, (-50,), (-52,)),
                         "armF": loop_keys(0.3, (90,), (92,)), "baton": loop_keys(0.3, (-90,), (-90,)), "tails": loop_keys(0.3, (70,), (74,)),
                         "thighF": loop_keys(0.3, (-40,), (-42,)), "thighB": loop_keys(0.3, (-50,), (-52,))})
    r.clip("slam", 0.5, {"body": [K(0, -15, 0, -1.0, 1.12, 0.84, "o"), K(0.5, 0)], "thighF": [K(0, 70), K(0.5, 0)], "shinF": [K(0, -90), K(0.5, 0)],
                         "thighB": [K(0, -40), K(0.5, 0)]}, loop=False, events=[[0, "quake"]])
    spin = [K(0, 0, 0, 0, 1, 1, "l", 0)] + [K(0.2 * i, 0, 0, 0.2, 1, 1, "l", -180 * i) for i in range(1, 5)]
    r.clip("spin", 0.8, {"root": spin, "armF": loop_keys(0.8, (100,), (100,)), "armB": loop_keys(0.8, (-100,), (-100,)),
                         "tails": loop_keys(0.8, (70,), (74,))}, events=[[0, "radiance"], [0.4, "radiance"]])
    # A bow before the fight: the conductor greets the audience.
    common(r, arm="armF")
    r.clips["roar"]["k"]["body"] = [K(0, 0), K(0.3, -35, 0.2, -0.1), K(0.9, -38, 0.2, -0.1), K(1.2, 8, 0, 0.1), K(1.6, 0)]
    r.clips["roar"]["k"]["armB"] = [K(0, 0), K(0.3, 100), K(0.9, 100), K(1.2, -150), K(1.6, 0)]
    glow_eyes(r)
    return r


def all_rigs():
    return [sessa(), mirra(), carapace(), vell(), pyrrhe()]
