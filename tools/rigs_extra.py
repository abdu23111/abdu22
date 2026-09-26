"""NPC, enemy and boss rigs for Vesperdeep (see rigs.py for the format).

Clip names the game looks for:
  NPCs     idle, notice (player walks up), talk (during dialogue)
  enemies  idle, move, windup, attack, hurt
  bosses   idle, move, windup, attack, shoot, slam, leap, roar, stagger, death
           (+ vanish / burrow / dive where a boss has them)
Missing clips fall back to sensible neighbours in the runtime.
"""

import math

from rigs import EYE, INK, MASK, MASK_SHADE, WARM, K, Rig, loop_keys, mask_face, wanderer


def ring(r, bone, n, radius, y, size, color, z_scale=1.0, **kw):
    for i in range(n):
        a = i / n * math.pi * 2
        r.part(bone, "ball", size, (math.cos(a) * radius, y, math.sin(a) * radius * z_scale), color=color, **kw)


def legs_pair(r, parent, name, at, length, color, foot=True, rest=0):
    """Two legs (left/right) hanging from `at`, named name+'L' / name+'R'."""
    for side, suffix in ((-1, "L"), (1, "R")):
        b = r.bone(name + suffix, parent, (at[0], at[1], side * at[2]), rest=rest)
        r.part(b, "box", (0.26, length, 0.26), (0, -length / 2, 0), color=color)
        if foot:
            r.part(b, "ball", (0.45, 0.25, 0.35), (0.1, -length, 0), color=color)


def talk_nod(length=1.6, head="head", arm=None, arm_amp=35, extra=None):
    keys = {head: loop_keys(length, (0,), (-8,), (4,), (-6,))}
    if arm:
        keys[arm] = loop_keys(length, (0,), (arm_amp,), (arm_amp * 0.4,), (arm_amp * 0.9,))
    keys.update(extra or {})
    return keys


# =============================================================================== NPCs

def wick():
    """Old Wick: a plump candle-grub elder who keeps dozing off by his bench."""
    r = Rig("wick", 0)
    tan, tan2 = (200, 176, 136), (176, 150, 112)
    r.bone("root")
    r.bone("body", "root", (0, 0.2))
    r.bone("head", "body", (0.45, 2.3))
    r.bone("flame", "head", (0.0, 1.35))
    r.bone("arm", "body", (0.55, 1.4, 0.85), rest=35)
    r.bone("stick", "arm", (0.0, -0.7), rest=-35)
    for i, (y, w) in enumerate(((0.45, 2.4), (1.2, 2.2), (1.9, 1.8))):
        r.part("body", "ball", (w, 1.0, w * 0.95), (-0.15 * i, y, 0), color=tan if i % 2 == 0 else tan2)
    mask_face(r, "head", (0.1, 0.3), (1.5, 1.35), "slit")
    r.part("head", "box", (0.9, 0.08, 0.95), (0.35, -0.05, 0), rot=8, color=(150, 130, 100))  # wrinkle
    r.part("head", "box", (0.55, 0.7, 0.55), (0, 0.95, 0), color=(236, 226, 205))  # candle stub
    r.part("head", "box", (0.62, 0.15, 0.62), (0, 0.62, 0), color=(220, 205, 180))
    r.part("flame", "ball", (0.35, 0.7, 0.35), (0, 0.2, 0), color=(255, 196, 110), mat="n", tag="flame")
    r.part("flame", "ball", (0.18, 0.35, 0.18), (0, 0.12, 0), color=(255, 245, 210), mat="n")
    r.part("arm", "box", (0.25, 0.8, 0.25), (0, -0.35, 0), color=tan2)
    r.part("stick", "box", (0.14, 2.6, 0.14), (0, -1.1, 0), color=(90, 66, 44))
    r.part("stick", "ball", (0.3, 0.3, 0.3), (0, 0.2, 0), color=(110, 80, 50))
    r.clip("idle", 4.2, {
        "body": [K(0, 0, 0, 0, 1, 1), K(1.4, 0, 0, 0, 1.02, 1.03), K(2.8, 0, 0, 0, 1, 1), K(4.2, 0, 0, 0, 1, 1)],
        # Slowly nods off... then jerks awake.
        "head": [K(0, 0), K(2.6, -26, 0, -0.15, 1, 1, "i"), K(3.1, -30, 0, -0.18, 1, 1, "s"), K(3.15, 8, 0, 0.05, 1, 1, "o"), K(3.6, 0), K(4.2, 0)],
        "flame": loop_keys(4.2, (0, 0, 0, 1, 1), (-8, 0, 0, 0.9, 1.15), (6, 0, 0, 1.05, 0.9), (-3, 0, 0, 0.95, 1.1)),
        "arm": loop_keys(4.2, (0,), (-4,)),
    })
    r.clip("notice", 1.2, {
        "head": [K(0, -20), K(0.25, 10, 0, 0.1), K(1.2, 0)],
        "arm": [K(0, 0), K(0.3, 95), K(0.5, 70), K(0.7, 95), K(0.9, 70), K(1.2, 0)],
        "stick": [K(0, 0), K(0.3, -60), K(1.2, 0)],
        "body": [K(0, 0), K(0.25, -6, 0, 0.05), K(1.2, 0)],
    }, loop=False)
    r.clip("talk", 1.8, talk_nod(1.8, arm="arm", arm_amp=40, extra={
        "flame": loop_keys(1.8, (0, 0, 0, 1, 1), (-6, 0, 0, 0.92, 1.1), (5, 0, 0, 1.05, 0.95)),
    }))
    return r


def tock():
    """Brass Tock: a stout, brass-shelled smith who never stops hammering."""
    r = Rig("tock", 0)
    brass, brass2, leather = (168, 116, 62), (130, 86, 46), (84, 56, 40)
    r.bone("root")
    r.bone("anvil", "root", (1.6, 0))
    legs_pair(r, "root", "leg", (0, 1.0, 0.45), 0.9, (40, 30, 26))
    r.bone("body", "root", (0, 1.0))
    r.bone("head", "body", (0.35, 1.85))
    r.bone("arm", "body", (0.45, 1.3, 0.95), rest=40)
    r.bone("hammer", "arm", (0, -0.8), rest=-20)
    r.bone("armB", "body", (0.3, 1.2, -0.95), rest=20)
    r.part("anvil", "box", (1.4, 0.5, 0.9), (0, 1.05, 0), color=(60, 60, 68), mat="m")
    r.part("anvil", "box", (0.6, 0.8, 0.6), (0, 0.4, 0), color=(44, 44, 50), mat="m")
    r.part("anvil", "ball", (0.35, 0.2, 0.35), (0.1, 1.35, 0), color=(255, 140, 60), mat="n", tag="glow")
    r.part("body", "ball", (2.3, 2.4, 2.2), (0, 0.9, 0), color=brass)
    r.part("body", "ball", (2.0, 1.6, 2.3), (-0.2, 1.4, 0), color=brass2)
    r.part("body", "box", (0.3, 1.3, 1.5), (0.95, 0.5, 0), color=leather)  # apron
    r.part("body", "ball", (1.0, 1.0, 0.3), (-0.95, 1.2, 0), color=(200, 160, 80), mat="m")  # gear on the back
    ring(r, "body", 8, 0.55, 1.2, (0.22, 0.22, 0.22), (200, 160, 80), z_scale=0.001, mat="m")
    mask_face(r, "head", (0.15, 0.35), (1.6, 1.4), "round")
    r.part("head", "box", (0.3, 0.12, 1.3), (0.62, 0.45, 0), color=(70, 50, 30))  # goggle strap
    for side in (-1, 1):
        r.part("head", "ball", (0.2, 0.45, 0.45), (0.72, 0.45, side * 0.27), color=(120, 190, 220), mat="g", alpha=0.3)
    r.part("head", "box", (0.25, 0.7, 0.25), (-0.1, 1.05, 0), rot=25, color=brass)  # horn
    r.part("arm", "box", (0.35, 0.9, 0.35), (0, -0.4, 0), color=brass2)
    r.part("armB", "box", (0.32, 0.8, 0.32), (0, -0.35, 0), color=brass2)
    r.part("hammer", "box", (0.14, 1.2, 0.14), (0, -0.5, 0), color=(80, 60, 40))
    r.part("hammer", "box", (0.7, 0.45, 0.45), (0, -1.15, 0), color=(90, 90, 100), mat="m")
    # Idle: rhythmic hammering, head ticking side to side like a clock.
    r.clip("idle", 1.3, {
        "arm": [K(0, 0), K(0.45, 120, 0, 0, 1, 1, "i"), K(0.6, -5, 0, 0, 1, 1, "o"), K(0.75, 5), K(1.3, 0)],
        "hammer": [K(0, 0), K(0.45, 30), K(0.6, -10), K(1.3, 0)],
        "body": [K(0, 0), K(0.45, 6), K(0.6, -8, 0, -0.05, 1.03, 0.97), K(1.3, 0)],
        "head": [K(0, 0, 0, 0, 1, 1, "io", 0, 6), K(0.65, 0, 0, 0, 1, 1, "io", 0, -6), K(1.3, 0, 0, 0, 1, 1, "io", 0, 6)],
    }, events=[[0.6, "spark"]])
    r.clip("notice", 1.3, {
        "arm": [K(0, 0), K(0.3, 150), K(1.0, 150), K(1.3, 0)],
        "head": [K(0, 0), K(0.3, 8, 0, 0, 1, 1, "io", 25), K(1.0, 8, 0, 0, 1, 1, "io", 25), K(1.3, 0)],
        "body": [K(0, 0), K(0.3, 4), K(1.3, 0)],
    }, loop=False)
    r.clip("talk", 1.4, talk_nod(1.4, arm="arm", arm_amp=70, extra={"hammer": loop_keys(1.4, (0,), (-30,))}))
    return r


def lirra():
    """Lirra: a chatty merchant moth under a towering pack of curiosities."""
    r = Rig("lirra", 0)
    fur, dusk, pack = (236, 226, 210), (120, 70, 96), (110, 82, 58)
    r.bone("root")
    legs_pair(r, "root", "leg", (0, 1.1, 0.35), 1.0, (40, 26, 36))
    r.bone("body", "root", (0, 1.1))
    r.bone("pack", "body", (-0.8, 1.2))
    r.bone("head", "body", (0.3, 2.0))
    r.bone("antL", "head", (-0.05, 0.9, -0.3), rest=35)
    r.bone("antR", "head", (-0.05, 0.9, 0.3), rest=35)
    r.bone("armL", "body", (0.3, 1.4, -0.75), rest=30)
    r.bone("armR", "body", (0.3, 1.4, 0.75), rest=30)
    r.part("body", "ball", (1.7, 2.2, 1.6), (0, 0.9, 0), color=dusk)
    ring(r, "body", 7, 0.7, 1.75, (0.6, 0.45, 0.6), fur)  # fluffy collar
    r.part("pack", "box", (1.6, 2.4, 1.6), (0, 0.6, 0), color=pack)
    r.part("pack", "box", (1.2, 0.9, 1.3), (0.1, 2.1, 0), color=(90, 66, 46))
    r.part("pack", "ball", (0.5, 0.5, 0.5), (0.4, 2.8, 0.3), color=(210, 180, 90), mat="m")
    r.part("pack", "box", (0.18, 1.6, 0.18), (-0.4, 2.8, -0.3), rot=15, color=(70, 50, 34))  # a rolled map
    lamp = (255, 190, 140)
    r.part("pack", "ball", (0.45, 0.55, 0.45), (0.8, 1.6, 0.6), color=lamp, mat="n", tag="glow")
    mask_face(r, "head", (0.1, 0.4), (1.5, 1.4), "drop", color=fur)
    for ant in ("antL", "antR"):
        r.part(ant, "box", (0.1, 0.6, 0.1), (0, 0.3, 0), color=fur)
        r.part(ant, "ball", (0.35, 1.1, 0.16), (-0.3, 0.95, 0), rot=40, color=fur)
    for arm in ("armL", "armR"):
        r.part(arm, "box", (0.24, 0.8, 0.24), (0, -0.4, 0), color=(60, 40, 52))
    r.clip("idle", 2.2, {
        "body": loop_keys(2.2, (3, 0, 0), (-3, 0, 0.05), (3, 0, 0), (-3, 0, 0.05)),
        "pack": loop_keys(2.2, (-3,), (4,), (-3,), (4,)),
        "head": loop_keys(2.2, (0, 0, 0, 1, 1, "io", 12), (-4, 0, 0, 1, 1, "io", -8)),
        "armR": loop_keys(2.2, (0,), (20,), (0,), (-10,)),
        "antL": loop_keys(2.2, (0,), (8,)),
        "antR": loop_keys(2.2, (0,), (-6,)),
    })
    r.clip("notice", 0.9, {
        "root": [K(0, 0), K(0.1, 0, 0, 0, 1.1, 0.9), K(0.3, 0, 0, 0.8, 0.95, 1.05, "o"), K(0.5, 0, 0, 0, 1.08, 0.92), K(0.9, 0)],
        "armL": [K(0, 0), K(0.3, 150), K(0.9, 0)],
        "armR": [K(0, 0), K(0.3, 150), K(0.9, 0)],
    }, loop=False)
    r.clip("talk", 1.5, {
        "armL": loop_keys(1.5, (70,), (100,)),
        "armR": loop_keys(1.5, (80,), (50,)),
        "head": loop_keys(1.5, (0,), (-8,), (4,)),
        "body": loop_keys(1.5, (0,), (-4,)),
    })
    return r


def pell():
    """Pell: a jittery little miner who startles at every sound."""
    r = Rig("pell", 0)
    shell, shell2 = (104, 90, 76), (80, 68, 58)
    r.bone("root")
    legs_pair(r, "root", "leg", (0, 0.8, 0.35), 0.75, (36, 30, 28))
    r.bone("body", "root", (0, 0.8))
    r.bone("head", "body", (0.35, 1.6))
    r.bone("arm", "body", (0.3, 1.1, 0.8), rest=30)
    r.bone("pick", "arm", (0, -0.65), rest=60)
    r.part("body", "ball", (1.9, 1.9, 1.8), (0, 0.8, 0), color=shell)
    r.part("body", "ball", (1.5, 1.2, 1.9), (-0.3, 1.2, 0), color=shell2)
    mask_face(r, "head", (0.1, 0.3), (1.35, 1.25), "round")
    r.part("head", "ball", (1.6, 0.8, 1.6), (0, 0.75, 0), color=(150, 118, 60), mat="m")  # helmet
    r.part("head", "box", (0.3, 0.3, 0.3), (0.72, 0.8, 0), color=(60, 50, 40))
    r.part("head", "ball", (0.3, 0.3, 0.3), (0.86, 0.8, 0), color=(240, 160, 255), mat="n", tag="glow")
    r.part("arm", "box", (0.25, 0.7, 0.25), (0, -0.33, 0), color=shell2)
    r.part("pick", "box", (0.12, 1.4, 0.12), (0, -0.6, 0), color=(90, 66, 44))
    r.part("pick", "tri", (0.8, 0.25, 0.12), (0.35, -1.25, 0), rot=0, color=(160, 160, 176), mat="m")
    r.part("pick", "tri", (0.8, 0.25, 0.12), (-0.35, -1.25, 0), rot=0, color=(160, 160, 176), mat="m", flip=True)
    # Idle: nervous glances left and right, tap-tap with the pick.
    r.clip("idle", 3.0, {
        "head": [K(0, 0, 0, 0, 1, 1, "io", 0), K(0.4, 0, 0, 0, 1, 1, "io", 35), K(1.0, 0, 0, 0, 1, 1, "io", 35),
                 K(1.3, 0, 0, 0, 1, 1, "io", -35), K(1.9, 0, 0, 0, 1, 1, "io", -35), K(2.2, 0, 0, 0, 1, 1, "io", 0), K(3.0, 0)],
        "arm": [K(0, 0), K(2.3, 0), K(2.45, 25), K(2.55, 0), K(2.7, 25), K(2.8, 0), K(3.0, 0)],
        "body": loop_keys(3.0, (0, 0, 0, 1, 1), (0, 0, 0, 1.02, 0.98), (0, 0, 0, 1, 1), (0, 0, 0, 0.98, 1.02)),
    })
    r.clip("notice", 1.0, {
        "root": [K(0, 0), K(0.08, 0, 0, 1.0, 0.85, 1.2, "o"), K(0.3, 0, 0, 0, 1.15, 0.85), K(0.5, 0, 0, 0, 1, 1), K(1.0, 0)],
        "arm": [K(0, 0), K(0.1, 100), K(1.0, 0)],
        "head": [K(0, 0), K(0.1, 15), K(1.0, 0)],
    }, loop=False)
    r.clip("talk", 1.1, talk_nod(1.1, arm="arm", arm_amp=60, extra={"body": loop_keys(1.1, (0,), (-5,), (3,))}))
    return r


def quill():
    """Quill: a tall, soft-spoken scribe forever writing in a floating book."""
    r = Rig("quill", 0)
    robe, robe2, page = (46, 102, 104), (32, 76, 78), (236, 228, 200)
    r.bone("root")
    r.bone("body", "root", (0, 0))
    r.bone("head", "body", (0.2, 3.5))
    r.bone("arm", "body", (0.35, 2.7, 0.7), rest=55)
    r.bone("pen", "arm", (0, -0.85), rest=-40)
    r.bone("book", "root", (1.3, 2.2))
    r.part("body", "ball", (1.6, 3.8, 1.5), (0, 1.8, 0), color=robe)
    r.part("body", "ball", (1.9, 1.0, 1.8), (0, 0.4, 0), color=robe2)
    r.part("body", "ball", (1.2, 0.6, 1.4), (0.1, 3.1, 0), color=robe2)  # collar
    mask_face(r, "head", (0.1, 0.4), (1.3, 1.5), "tall")
    for side in (-1, 1):  # spectacles
        r.part("head", "ball", (0.12, 0.42, 0.42), (0.72, 0.42, side * 0.22), color=(190, 240, 235), mat="g", alpha=0.45)
    r.part("head", "box", (0.1, 0.9, 0.1), (-0.1, 1.2, 0.2), rot=30, color=page)
    r.part("head", "box", (0.1, 0.9, 0.1), (-0.1, 1.2, -0.2), rot=40, color=page)
    r.part("arm", "box", (0.22, 0.95, 0.22), (0, -0.45, 0), color=robe2)
    r.part("pen", "box", (0.08, 1.1, 0.08), (0, -0.45, 0), color=(60, 50, 40))
    r.part("pen", "ball", (0.12, 0.8, 0.3), (0.02, 0.2, 0), rot=10, color=page)
    r.part("book", "box", (1.1, 0.12, 0.8), (0, 0, 0), rot=-15, color=(120, 80, 60))
    r.part("book", "box", (1.0, 0.08, 0.72), (0, 0.08, 0), rot=-15, color=page)
    r.part("book", "ball", (0.5, 0.1, 0.4), (0, 0.15, 0), rot=-15, color=(110, 240, 230), mat="n", alpha=0.4, tag="glow")
    r.clip("idle", 2.4, {
        "arm": loop_keys(2.4, (0, 0, 0), (8, 0.05, 0), (-4, 0, 0), (10, 0.05, 0), (0, 0, 0), (6, -0.05, 0)),
        "pen": loop_keys(2.4, (0,), (-10,), (5,), (-12,)),
        "head": loop_keys(2.4, (-16,), (-14,)),
        "book": loop_keys(2.4, (0, 0, 0), (2, 0, 0.12), (0, 0, 0), (-2, 0, 0.1)),
        "body": loop_keys(2.4, (0, 0, 0, 1, 1), (0, 0, 0, 1.01, 1.02)),
    })
    r.clip("notice", 1.4, {
        "head": [K(0, -16), K(0.4, 6), K(1.4, 0)],
        "arm": [K(0, 0), K(0.4, 60), K(0.9, 60), K(1.4, 0)],  # adjusts the spectacles
        "pen": [K(0, 0), K(0.4, 40), K(1.4, 0)],
    }, loop=False)
    r.clip("talk", 1.6, {
        "arm": loop_keys(1.6, (70,), (95,), (80,)),
        "pen": loop_keys(1.6, (60,), (70,)),
        "head": loop_keys(1.6, (0,), (-6,), (3,)),
        "book": loop_keys(1.6, (0, 0, 0), (0, 0, 0.1)),
    })
    return r


def ilo():
    """Ilo: a moss-covered pilgrim, kneeling in prayer, who moves as slowly as the forest."""
    r = Rig("ilo", 0)
    cloak, moss, glow = (54, 82, 62), (84, 130, 80), (170, 255, 190)
    r.bone("root")
    r.bone("body", "root", (0, 0))
    r.bone("head", "body", (0.35, 2.2))
    r.bone("hands", "body", (0.75, 1.4))
    r.part("body", "ball", (2.2, 2.4, 2.0), (0, 1.1, 0), color=cloak)
    r.part("body", "ball", (1.9, 0.8, 2.1), (0, 0.3, 0), color=(40, 62, 48))
    for i in range(9):
        a = i * 2.1
        r.part("body", "ball", (0.5, 0.35, 0.5), (math.cos(a) * 0.9 - 0.2, 0.6 + (i % 4) * 0.45, math.sin(a) * 0.85), color=moss)
    for i in range(4):
        r.part("body", "ball", (0.22, 0.22, 0.22), (math.cos(i * 1.7) * 0.95 - 0.1, 1.0 + i * 0.3, math.sin(i * 1.7) * 0.9), color=glow, mat="n", tag="glow")
    r.part("head", "ball", (1.7, 1.6, 1.7), (-0.1, 0.45, 0), color=cloak)  # hood
    mask_face(r, "head", (0.2, 0.3), (1.2, 1.2), "drop")
    r.part("hands", "ball", (0.5, 0.7, 0.4), (0, 0, 0), color=(60, 90, 66))
    r.clip("idle", 5.0, {
        "body": loop_keys(5.0, (0, 0, 0, 1, 1), (-10, 0.05, -0.05, 1.02, 0.98)),
        "head": loop_keys(5.0, (-10,), (-24,)),
        "hands": loop_keys(5.0, (0, 0, 0), (0, 0, -0.06)),
    })
    r.clip("notice", 2.4, {
        "head": [K(0, -20), K(1.6, 8, 0, 0.05, 1, 1, "io", 15), K(2.4, 0)],
        "body": [K(0, -8), K(1.6, 2), K(2.4, 0)],
    }, loop=False)
    r.clip("talk", 2.6, {
        "body": loop_keys(2.6, (0,), (-12,)),
        "head": loop_keys(2.6, (-4,), (-16,)),
        "hands": loop_keys(2.6, (0, 0, 0), (0, 0.05, 0.1)),
    })
    return r


def oriel():
    """Oriel: the faded ghost of an earlier lantern-bearer, drifting and flickering."""
    r = wanderer("oriel", cloak=(150, 150, 170), cloak_dark=(120, 120, 140), mask=(230, 230, 240), eye=(170, 200, 255),
                 nail=(200, 200, 210), glow=(220, 220, 255), lining=(190, 190, 210), scarf=(170, 170, 200),
                 fur=(220, 222, 236), wing=(200, 200, 225), chitin=(120, 120, 140), gold=(200, 200, 215))
    r.anchor = 0
    for p in r.parts:
        p["a"] = max(p.get("a", 0), 0.45)
        if p.get("t") == "glow" and p["b"] == "lantern":
            p["c"] = [140, 140, 150]
            p["m"] = "p"
    base = {k: v for k, v in r.clips.items() if k in ("idle",)}
    r.clips = {}
    r.clip("idle", 3.2, {
        "root": loop_keys(3.2, (0, 0, 0.5), (3, 0, 0.8), (0, 0, 0.5), (-3, 0, 0.7)),
        "hem": loop_keys(3.2, (-10,), (-18,)),
        "head": loop_keys(3.2, (-8,), (-4,)),
        "armF": loop_keys(3.2, (-10,), (-5,)),
        "lantern": loop_keys(3.2, (10,), (-6,)),
    })
    r.clip("notice", 1.6, {
        "root": [K(0, 0, 0, 0.5), K(0.8, 0, 0.3, 0.9), K(1.6, 0, 0, 0.6)],
        "armB": [K(0, 0), K(0.8, 120), K(1.6, 0)],
        "lantern": [K(0, 0), K(0.8, -30), K(1.6, 0)],
    }, loop=False)
    r.clip("talk", 2.0, {
        "root": loop_keys(2.0, (0, 0, 0.6), (0, 0, 0.75)),
        "armB": loop_keys(2.0, (110,), (120,)),
        "head": loop_keys(2.0, (0,), (-8,)),
        "hem": loop_keys(2.0, (-12,), (-20,)),
    })
    del base
    return r


def sael():
    """Sael: the last acolyte, tall and serene beneath a slowly turning halo."""
    r = Rig("sael", 0)
    robe, trim, gold = (226, 220, 204), (200, 176, 120), (255, 222, 150)
    r.bone("root")
    r.bone("body", "root", (0, 0))
    r.bone("head", "body", (0.1, 3.9))
    r.bone("halo", "head", (-0.35, 0.6))
    r.bone("armL", "body", (0.2, 3.1, -0.7), rest=15)
    r.bone("armR", "body", (0.2, 3.1, 0.7), rest=15)
    r.part("body", "ball", (1.7, 4.2, 1.7), (0, 2.0, 0), color=robe)
    r.part("body", "ball", (2.1, 1.0, 2.1), (0, 0.4, 0), color=(206, 198, 180))
    r.part("body", "box", (0.25, 3.0, 0.4), (0.8, 2.0, 0), color=trim)
    r.part("body", "ball", (1.4, 0.5, 1.5), (0, 3.45, 0), color=trim)
    mask_face(r, "head", (0.1, 0.45), (1.25, 1.6), "tall")
    r.part("head", "tri", (0.3, 1.2, 0.2), (-0.2, 1.4, 0.25), rot=20, color=robe)
    r.part("head", "tri", (0.3, 1.2, 0.2), (-0.2, 1.4, -0.25), rot=20, color=robe)
    ring(r, "halo", 12, 1.0, 0.8, (0.22, 0.22, 0.22), gold, z_scale=1.0, mat="n")
    r.part("halo", "ball", (0.1, 2.0, 2.0), (0, 0.8, 0), color=gold, mat="n", alpha=0.75, tag="glow")
    for arm in ("armL", "armR"):
        r.part(arm, "box", (0.4, 1.2, 0.4), (0, -0.55, 0), color=robe)
        r.part(arm, "ball", (0.5, 0.4, 0.5), (0, -1.15, 0), color=(206, 198, 180))
    r.clip("idle", 4.0, {
        "body": loop_keys(4.0, (0, 0, 0, 1, 1), (0, 0, 0.02, 1.01, 1.02)),
        "halo": loop_keys(4.0, (0, 0, 0, 1, 1, "io", 0), (0, 0, 0.12, 1, 1, "io", 90), (0, 0, 0, 1, 1, "io", 180), (0, 0, 0.12, 1, 1, "io", 270)),
        "head": loop_keys(4.0, (-4,), (-8,)),
        "armL": loop_keys(4.0, (30,), (34,)),
        "armR": loop_keys(4.0, (30,), (34,)),
    })
    r.clip("notice", 1.8, {
        "body": [K(0, 0), K(0.7, -18, 0.1), K(1.2, -18, 0.1), K(1.8, 0)],  # a slow bow
        "head": [K(0, 0), K(0.7, -12), K(1.8, 0)],
        "armR": [K(0, 30), K(0.7, 70), K(1.8, 30)],
    }, loop=False)
    r.clip("talk", 2.2, {
        "armR": loop_keys(2.2, (110,), (130,)),
        "armL": loop_keys(2.2, (30,), (36,)),
        "head": loop_keys(2.2, (0,), (-6,)),
    })
    return r


# ============================================================================= enemies

def mite(name="mite", shell=(88, 78, 70), crystals=False):
    """A small shelled crawler with a pale face and busy legs."""
    r = Rig(name, 1.2)
    r.bone("root")
    r.bone("body", "root", (0, 0.9))
    r.bone("head", "body", (1.1, 0.0))
    for i, x in enumerate((0.6, -0.1, -0.8)):
        for side, s in (("L", -1), ("R", 1)):
            b = r.bone(f"leg{i}{side}", "body", (x, -0.2, s * 0.7), rest=20 - i * 20)
            r.part(b, "box", (0.14, 0.8, 0.14), (0, -0.35, 0), color=INK)
    r.part("body", "ball", (2.6, 1.8, 2.0), (-0.2, 0.3, 0), color=shell)
    r.part("body", "ball", (2.0, 0.6, 1.7), (-0.35, 0.9, 0), color=tuple(max(0, c - 20) for c in shell))
    mask_face(r, "head", (0.15, 0.1), (1.1, 1.0), "round")
    r.part("head", "box", (0.08, 0.7, 0.08), (0.2, 0.7, 0.2), rot=-30, color=MASK_SHADE)
    if crystals:
        for i, (x, h, rot) in enumerate(((-0.5, 1.6, 15), (0.1, 1.2, -20), (-1.1, 1.1, 40))):
            r.part("body", "box", (0.4, h, 0.4), (x, 1.2 + h * 0.3, (i - 1) * 0.3), rot=rot, color=(240, 150, 255), mat="n", alpha=0.15)
    legs = {}
    for i in range(3):
        a, b = (f"leg{i}L", f"leg{i}R")
        phase = (35, -35) if i % 2 == 0 else (-35, 35)
        legs[a] = loop_keys(0.36, (phase[0],), (phase[1],))
        legs[b] = loop_keys(0.36, (phase[1],), (phase[0],))
    r.clip("move", 0.36, dict(legs, body=loop_keys(0.36, (0, 0, 0), (-3, 0, 0.08), (0, 0, 0), (3, 0, 0.08))))
    r.clip("idle", 2.0, {"body": loop_keys(2.0, (0, 0, 0, 1, 1), (0, 0, -0.04, 1.03, 0.97)), "head": loop_keys(2.0, (0,), (-8,))})
    r.clip("windup", 0.5, {"body": loop_keys(0.5, (10, -0.2, 0.1), (12, -0.25, 0.12)), "head": loop_keys(0.5, (15,), (18,))})
    r.clip("attack", 0.4, dict(legs, body=loop_keys(0.4, (-12, 0.2), (-14, 0.25))))
    r.clip("hurt", 0.25, {"body": [K(0, 0), K(0.05, 18, -0.3, 0.2, 0.9, 1.1), K(0.25, 0)], "head": [K(0, 0), K(0.05, 25), K(0.25, 0)]}, loop=False)
    return r


def gnat():
    """Gloom Gnat: a fuzzy buzzing ball with a single ember eye."""
    r = Rig("gnat", 0)
    r.bone("root")
    r.bone("body", "root", (0, 0))
    r.bone("wingL", "body", (-0.2, 0.7, -0.4), rest=20)
    r.bone("wingR", "body", (-0.2, 0.7, 0.4), rest=20)
    r.part("body", "ball", (2.0, 1.9, 1.9), (0, 0, 0), color=(58, 44, 72))
    r.part("body", "ball", (1.2, 1.1, 1.6), (0.45, 0.1, 0), color=(74, 58, 90))
    r.part("body", "ball", (0.2, 0.5, 0.5), (1.0, 0.2, 0), color=(255, 150, 70), mat="n", tag="glow")
    r.part("body", "box", (0.1, 0.8, 0.1), (0.3, -1.1, 0.3), rot=15, color=INK)
    r.part("body", "box", (0.1, 0.8, 0.1), (-0.2, -1.1, -0.3), rot=-10, color=INK)
    for w in ("wingL", "wingR"):
        r.part(w, "ball", (1.8, 0.1, 1.1), (-0.5, 0.2, 0), color=(200, 200, 230), alpha=0.5)
    flap = {"wingL": loop_keys(0.06, (-30, 0, 0, 1, 1, "l", 0, -40), (30, 0, 0, 1, 1, "l", 0, 40)),
            "wingR": loop_keys(0.06, (-30, 0, 0, 1, 1, "l", 0, 40), (30, 0, 0, 1, 1, "l", 0, -40))}
    r.clip("idle", 0.06, flap)
    r.clip("move", 0.06, dict(flap, body=loop_keys(0.06, (-15,), (-15,))))
    r.clip("hurt", 0.25, dict(flap, body=[K(0, 0), K(0.05, 30, -0.3), K(0.25, 0)]), loop=False)
    return r


def wisp():
    """Ink Wisp: a drifting droplet of living ink that spits at intruders."""
    r = Rig("wisp", 0)
    ink, teal = (14, 20, 26), (110, 240, 230)
    r.bone("root")
    r.bone("body", "root", (0, 0))
    r.bone("tail1", "body", (-0.1, -0.9), rest=-10)
    r.bone("tail2", "tail1", (0, -0.9), rest=-10)
    r.bone("head", "body", (0.3, 0.6))
    r.part("body", "ball", (2.0, 2.2, 1.9), (0, 0, 0), color=ink)
    r.part("tail1", "ball", (1.3, 1.4, 1.2), (0, -0.4, 0), color=ink)
    r.part("tail2", "tri", (0.8, 1.4, 0.6), (0, -0.6, 0), rot=180, color=ink)
    mask_face(r, "head", (0.1, 0.0), (1.1, 1.0), "drop", eye_color=teal)
    r.part("body", "ball", (2.15, 2.35, 2.05), (-0.05, 0, 0), color=teal, mat="n", alpha=0.93, tag="glow")  # ink sheen
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    r.clip("idle", 1.6, {
        "body": loop_keys(1.6, (0, 0, 0), (4, 0, 0.2)),
        "tail1": loop_keys(1.6, (15,), (-15,)),
        "tail2": loop_keys(1.6, (-20,), (20,)),
    })
    r.clip("move", 1.0, {"body": loop_keys(1.0, (-10, 0, 0), (-12, 0, 0.15)), "tail1": loop_keys(1.0, (25,), (5,)), "tail2": loop_keys(1.0, (-10,), (25,))})
    r.clip("windup", 0.5, {"body": loop_keys(0.5, (15, -0.2, 0, 1.15, 0.9), (17, -0.2, 0, 1.2, 0.88)), "head": loop_keys(0.5, (10,), (12,))})
    r.clip("attack", 0.3, {"body": [K(0, 15, 0, 0, 1.2, 0.9), K(0.06, -20, 0.4, 0, 0.8, 1.2, "o"), K(0.3, 0)]}, loop=False)
    r.clip("hurt", 0.25, {"body": [K(0, 0), K(0.05, 25, -0.3, 0, 1.2, 0.8), K(0.25, 0)]}, loop=False)
    return r


def bulb():
    """Spore Bulb: a rooted pod that swells before loosing a spore."""
    r = Rig("bulb", 0)
    stem, pod, spot = (70, 92, 60), (96, 124, 72), (210, 255, 150)
    r.bone("root")
    r.bone("stem", "root", (0, 0))
    r.bone("pod", "stem", (0, 1.4))
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        r.part("stem", "box", (0.2, 0.9, 0.2), (math.cos(a) * 0.5, 0.2, math.sin(a) * 0.5), rot=math.degrees(a) % 60 - 30, color=(56, 74, 48))
    r.part("stem", "box", (0.45, 1.5, 0.45), (0, 0.7, 0), color=stem)
    r.part("pod", "ball", (2.6, 2.3, 2.6), (0, 0.8, 0), color=pod)
    r.part("pod", "ball", (1.2, 0.6, 1.2), (0.7, 1.7, 0), color=(76, 100, 58))
    for i, (x, y, z) in enumerate(((0.9, 0.8, 0.6), (0.6, 1.3, -0.7), (-0.4, 1.4, 0.8), (1.1, 0.4, -0.3))):
        r.part("pod", "ball", (0.35, 0.35, 0.35), (x, y, z), color=spot, mat="n", tag="glow")
    r.part("pod", "ball", (0.3, 0.8, 0.9), (1.25, 1.0, 0), color=EYE)  # the mouth
    r.clip("idle", 2.4, {"pod": loop_keys(2.4, (4, 0, 0, 1, 1), (-4, 0, 0.05, 1.04, 0.97)), "stem": loop_keys(2.4, (2,), (-2,))})
    r.clip("windup", 0.45, {"pod": loop_keys(0.45, (10, 0, 0, 1.18, 1.18), (11, 0, 0, 1.22, 1.2))})
    r.clip("attack", 0.35, {"pod": [K(0, 10, 0, 0, 1.2, 1.2), K(0.06, -15, 0.2, 0, 0.8, 0.85, "o"), K(0.35, 0)]}, loop=False)
    r.clip("hurt", 0.25, {"pod": [K(0, 0), K(0.05, 20, 0, 0, 0.9, 1.1), K(0.25, 0)]}, loop=False)
    return r


def shellguard():
    """Shellguard: a heavy beetle soldier behind a tower shield."""
    r = Rig("shellguard", 2.4)
    armor, armor2 = (70, 74, 96), (52, 56, 76)
    r.bone("root")
    legs_pair(r, "root", "leg", (0, 1.3, 0.55), 1.2, (40, 42, 56))
    r.bone("body", "root", (0, 1.3))
    r.bone("head", "body", (0.6, 2.3))
    r.bone("shield", "body", (1.2, 1.1, 0.4))
    r.part("body", "ball", (2.6, 3.2, 2.4), (0, 1.3, 0), color=armor)
    r.part("body", "ball", (2.4, 1.8, 2.6), (-0.3, 2.0, 0), color=armor2)
    mask_face(r, "head", (0.15, 0.2), (1.4, 1.4), "slit")
    r.part("head", "box", (0.25, 1.2, 0.25), (-0.2, 1.1, 0), rot=30, color=MASK)
    r.part("shield", "box", (0.35, 3.0, 2.0), (0.1, 0.1, 0), color=(150, 150, 170), mat="m")
    r.part("shield", "box", (0.4, 0.3, 1.2), (0.12, 0.6, 0), color=(110, 110, 130), mat="m")
    walk = {"legL": loop_keys(0.7, (25,), (-25,)), "legR": loop_keys(0.7, (-25,), (25,)),
            "body": loop_keys(0.7, (0, 0, 0), (0, 0, 0.1), (0, 0, 0), (0, 0, 0.1))}
    r.clip("idle", 2.2, {"body": loop_keys(2.2, (0, 0, 0, 1, 1), (0, 0, 0, 1.02, 0.98)), "head": loop_keys(2.2, (0,), (-5,))})
    r.clip("move", 0.7, walk)
    r.clip("windup", 0.3, {"body": loop_keys(0.3, (-12, -0.1, -0.3), (-13, -0.12, -0.32)), "legL": loop_keys(0.3, (40,), (42,)), "legR": loop_keys(0.3, (-30,), (-32,)),
                           "shield": loop_keys(0.3, (0, 0.15, 0), (2, 0.18, 0))})
    r.clip("attack", 0.3, {"legL": loop_keys(0.3, (45,), (-45,)), "legR": loop_keys(0.3, (-45,), (45,)), "body": loop_keys(0.3, (-20, 0.2), (-22, 0.2))})
    r.clip("hurt", 0.3, {"body": [K(0, 0), K(0.06, 10, -0.2), K(0.3, 0)]}, loop=False)
    return r


def hopper():
    """Hollow Hopper: a pale-limbed leaper that crouches, quivering, before it springs."""
    r = Rig("hopper", 1.7)
    r.bone("root")
    r.bone("body", "root", (0, 1.4))
    r.bone("head", "body", (0.8, 0.6))
    for side, s in (("L", -1), ("R", 1)):
        r.bone("thigh" + side, "body", (-0.4, -0.2, s * 0.8), rest=-60)
        r.bone("shin" + side, "thigh" + side, (0, -1.1), rest=110)
        r.part("thigh" + side, "box", (0.3, 1.2, 0.3), (0, -0.55, 0), color=(200, 200, 206))
        r.part("shin" + side, "box", (0.22, 1.3, 0.22), (0, -0.6, 0), color=(200, 200, 206))
    r.part("body", "ball", (2.6, 2.2, 2.2), (0, 0.2, 0), color=(30, 30, 34))
    mask_face(r, "head", (0.2, 0.2), (1.5, 1.3), "tall")
    crouch = {"thighL": (-20,), "thighR": (-20,), "shinL": (30,), "shinR": (30,)}
    r.clip("idle", 1.8, {"body": loop_keys(1.8, (0, 0, 0, 1, 1), (0, 0, -0.05, 1.03, 0.97))})
    r.clip("windup", 0.35, {
        "body": loop_keys(0.35, (8, 0, -0.5, 1.1, 0.9), (9, 0.03, -0.52, 1.1, 0.9)),
        **{k: loop_keys(0.35, v, (v[0] - 3,)) for k, v in crouch.items()},
    })
    r.clip("attack", 0.5, {
        "body": loop_keys(0.5, (-10, 0, 0, 0.9, 1.12), (-12, 0, 0, 0.9, 1.12)),
        "thighL": loop_keys(0.5, (30,), (30,)), "thighR": loop_keys(0.5, (30,), (30,)),
        "shinL": loop_keys(0.5, (-60,), (-60,)), "shinR": loop_keys(0.5, (-60,), (-60,)),
    })
    r.clip("move", 0.5, {"body": loop_keys(0.5, (-5, 0, 0), (-5, 0, 0.1))})
    r.clip("hurt", 0.25, {"body": [K(0, 0), K(0.05, 20, -0.3), K(0.25, 0)]}, loop=False)
    return r


# ============================================================================== bosses

def boss_common(r, body="body", head="head", roar_head=25, stagger_body=18, death_drop=-1.0):
    """Roar, stagger and death clips that every boss shares in spirit."""
    r.clip("roar", 1.6, {
        body: [K(0, 0), K(0.3, 12, -0.2, 0.1, 0.95, 1.08), K(0.45, 14, -0.25, 0.15), K(1.3, 12, -0.2, 0.1), K(1.6, 0)],
        head: [K(0, 0), K(0.3, roar_head), K(0.4, roar_head + 5), K(0.5, roar_head), K(0.6, roar_head + 5), K(0.7, roar_head), K(1.3, roar_head), K(1.6, 0)],
    }, loop=False, events=[[0.3, "roar"]])
    r.clip("stagger", 1.1, {
        body: [K(0, 0), K(0.1, stagger_body, -0.3, -0.2, 1.08, 0.9), K(0.25, stagger_body - 4, -0.25, -0.2), K(0.4, stagger_body + 3, -0.3, -0.25), K(1.1, 0)],
        head: [K(0, 0), K(0.1, -20), K(1.1, 0)],
    }, loop=False)
    r.clip("death", 1.6, {
        body: [K(0, 0), K(0.2, stagger_body, -0.2), K(0.8, -10, 0, death_drop * 0.5), K(1.6, 60, 0, death_drop, 1.05, 0.9)],
        head: [K(0, 0), K(0.2, -25), K(1.6, 40)],
    }, loop=False)


def gravelmaw():
    """Gravelmaw, the Tunneling Mother: a colossal grub with stone-crusted segments."""
    r = Rig("gravelmaw", 2.8)
    hide, hide2, stone, ember = (106, 92, 80), (92, 80, 70), (150, 140, 130), (255, 150, 60)
    r.bone("root")
    r.bone("body", "root", (0, 2.6))
    prev = "body"
    for i in range(4):
        b = r.bone(f"seg{i}", prev, (-2.2 if i else -1.2, 0))
        prev = b
        size = 4.4 - i * 0.6
        r.part(b, "ball", (size * 1.1, size, size * 1.05), (0, -0.2 * i, 0), color=hide if i % 2 == 0 else hide2)
        r.part(b, "box", (0.5, 1.4 - i * 0.2, 0.5), (0.1, size * 0.45, 0), rot=15, color=stone)
        r.part(b, "box", (0.4, 1.0, 0.4), (-0.4, size * 0.4, 0.8), rot=30, color=stone)
    r.part("body", "ball", (5.0, 5.2, 5.0), (0, 0, 0), color=hide)
    r.bone("head", "body", (2.2, 0.5))
    mask_face(r, "head", (0.5, 0.2), (3.2, 3.0), "slit", eye_color=ember)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    for side, s in (("L", -1), ("R", 1)):
        b = r.bone("jaw" + side, "head", (1.8, -0.8, s * 0.7), rest=-20)
        r.part(b, "tri", (0.5, 1.8, 0.4), (0.2, -0.6, 0), rot=150, color=(40, 34, 30))
    wave = 1.0
    move = {f"seg{i}": loop_keys(wave, (8, 0, 0.15 * (i % 2)), (-8, 0, -0.15 * (i % 2))) for i in range(4)}
    move["body"] = loop_keys(wave, (0, 0, 0, 1.03, 0.97), (0, 0, 0.2, 0.97, 1.03))
    r.clip("idle", 2.6, {**{f"seg{i}": loop_keys(2.6, (0, 0, 0, 1, 1), (3, 0, 0.05, 1.02, 1.03)) for i in range(4)},
                         "body": loop_keys(2.6, (0, 0, 0, 1, 1), (0, 0, 0.05, 1.02, 1.03)),
                         "jawL": loop_keys(2.6, (0,), (8,)), "jawR": loop_keys(2.6, (0,), (8,))})
    r.clip("move", wave, move)
    r.clip("windup", 0.5, {"body": loop_keys(0.5, (20, -0.3, 0.8), (22, -0.3, 0.9)), "head": loop_keys(0.5, (15,), (18,)),
                           "jawL": loop_keys(0.5, (30,), (36,)), "jawR": loop_keys(0.5, (30,), (36,)),
                           "seg0": loop_keys(0.5, (-10,), (-12,))})
    r.clip("attack", 0.5, dict(move, body=loop_keys(0.5, (-10, 0.3, 0), (-12, 0.3, 0.1)), jawL=loop_keys(0.5, (35,), (0,)), jawR=loop_keys(0.5, (35,), (0,))))
    r.clip("leap", 0.9, {f"seg{i}": loop_keys(0.9, (-25,), (-28,)) for i in range(4)} | {"body": loop_keys(0.9, (-20,), (-22,))})
    r.clip("slam", 0.5, {"body": [K(0, 0, 0, -0.8, 1.2, 0.75, "o"), K(0.5, 0)], "jawL": [K(0, 40), K(0.5, 0)], "jawR": [K(0, 40), K(0.5, 0)]}, loop=False, events=[[0, "quake"]])
    r.clip("burrow", 0.8, {"body": loop_keys(0.8, (-35, 0.5, -0.5), (-37, 0.5, -0.6)), "head": loop_keys(0.8, (-20,), (-22,))})
    r.clip("shoot", 0.5, {"body": [K(0, 0), K(0.1, 15, 0, 0.3), K(0.5, 0)], "jawL": [K(0, 0), K(0.1, 45), K(0.5, 0)], "jawR": [K(0, 0), K(0.1, 45), K(0.5, 0)]}, loop=False)
    boss_common(r, roar_head=30)
    return r


def vantis():
    """Sir Vantis, the Hollow Sentinel: a lance-knight whose armour outlived him."""
    r = Rig("vantis", 4.0)
    plate, plate2, dark, cape, eye = (150, 156, 180), (100, 106, 132), (40, 42, 56), (120, 32, 44), (150, 210, 255)
    r.bone("root")
    legs_pair(r, "root", "leg", (0, 2.4, 0.6), 2.3, dark)
    r.bone("body", "root", (0, 2.4))
    r.bone("cape", "body", (-0.9, 3.3), rest=-6)
    r.bone("head", "body", (0.3, 4.3))
    r.bone("lanceArm", "body", (0.4, 3.2, 1.7), rest=60)
    r.bone("lance", "lanceArm", (0, -1.2), rest=-100)
    r.bone("shieldArm", "body", (0.3, 3.2, -1.3), rest=30)
    r.part("cape", "box", (0.25, 4.2, 2.6), (-0.1, -2.0, 0), color=cape)
    r.part("cape", "tri", (0.3, 0.8, 1.0), (-0.1, -4.4, 0.6), rot=180, color=cape)
    r.part("body", "ball", (3.2, 4.4, 2.8), (0, 1.6, 0), color=(60, 64, 88))
    r.part("body", "ball", (3.8, 1.5, 3.6), (0, 3.4, 0), color=plate)
    r.part("body", "ball", (2.6, 2.0, 2.6), (0.3, 1.6, 0), color=plate2)
    r.part("body", "box", (3.0, 0.4, 2.8), (0, 0.4, 0), color=dark)
    mask_face(r, "head", (0.25, 0.4), (1.8, 2.1), "slit", eye_color=eye)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    r.part("head", "tri", (0.4, 2.2, 0.3), (-0.4, 1.9, 0), rot=15, color=MASK)  # crest
    r.part("head", "box", (1.9, 0.25, 2.0), (0.25, 1.0, 0), color=plate)
    r.part("lanceArm", "box", (0.6, 1.4, 0.6), (0, -0.6, 0), color=plate2)
    r.part("lance", "box", (0.3, 7.5, 0.3), (0, 2.2, 0), color=(205, 205, 220), mat="m")
    r.part("lance", "tri", (0.6, 1.5, 0.3), (0.3, 6.6, 0), color=(230, 235, 245), mat="m")
    r.part("lance", "tri", (0.6, 1.5, 0.3), (-0.3, 6.6, 0), color=(230, 235, 245), mat="m", flip=True)
    r.part("lance", "box", (0.1, 6.0, 0.35), (0.12, 3.0, 0), color=eye, mat="n", alpha=0.6, tag="glow")
    r.part("shieldArm", "box", (0.55, 1.3, 0.55), (0, -0.6, 0), color=plate2)
    r.part("shieldArm", "ball", (0.5, 3.0, 2.2), (0.3, -1.4, 0), color=plate)
    walk = {"legL": loop_keys(1.0, (22,), (-22,)), "legR": loop_keys(1.0, (-22,), (22,)),
            "body": loop_keys(1.0, (0, 0, 0), (0, 0, 0.15), (0, 0, 0), (0, 0, 0.15)),
            "cape": loop_keys(1.0, (6,), (12,))}
    r.clip("idle", 2.8, {"body": loop_keys(2.8, (0, 0, 0, 1, 1), (0, 0, -0.04, 1.01, 1.01)), "cape": loop_keys(2.8, (0,), (5,)),
                         "head": loop_keys(2.8, (0,), (-4,)), "lanceArm": loop_keys(2.8, (0,), (3,))})
    r.clip("move", 1.0, walk)
    r.clip("windup", 0.4, {"lanceArm": loop_keys(0.4, (60, -0.4, 0), (62, -0.42, 0)), "lance": loop_keys(0.4, (-20,), (-22,)),
                           "body": loop_keys(0.4, (10, -0.3, -0.3), (11, -0.3, -0.32)), "legL": loop_keys(0.4, (30,), (31,)), "legR": loop_keys(0.4, (-25,), (-26,))})
    r.clip("attack", 0.45, {"lanceArm": [K(0, 60), K(0.08, -40, 0.8, 0, 1, 1, "o"), K(0.45, 0)], "lance": [K(0, -20), K(0.08, 0), K(0.45, 0)],
                            "body": [K(0, 10), K(0.08, -18, 0.6, 0, 1.05, 0.96, "o"), K(0.45, 0)], "cape": [K(0, 0), K(0.1, 30), K(0.45, 0)],
                            "legL": [K(0, 30), K(0.08, 50), K(0.45, 0)], "legR": [K(0, -25), K(0.08, -45), K(0.45, 0)]}, loop=False, events=[[0.08, "thrust"]])
    r.clip("leap", 0.8, {"legL": loop_keys(0.8, (60,), (62,)), "legR": loop_keys(0.8, (50,), (52,)), "body": loop_keys(0.8, (-10,), (-12,)),
                         "lanceArm": loop_keys(0.8, (100,), (104,)), "cape": loop_keys(0.8, (-30,), (-34,))})
    r.clip("slam", 0.6, {"body": [K(0, -15, 0, -1.0, 1.12, 0.82, "o"), K(0.6, 0)], "lanceArm": [K(0, -60), K(0.6, 0)],
                         "legL": [K(0, 45), K(0.6, 0)], "legR": [K(0, -40), K(0.6, 0)]}, loop=False, events=[[0, "quake"]])
    r.clip("shoot", 0.5, {"lanceArm": [K(0, 0), K(0.1, 140), K(0.5, 0)]}, loop=False)
    boss_common(r, roar_head=20)
    r.clips["roar"]["k"]["lanceArm"] = [K(0, 0), K(0.3, 150), K(1.3, 150), K(1.6, 0)]
    return r


def widow():
    """The Thornwidow, Weaver of Wings: an eight-legged matriarch strung with silk."""
    r = Rig("widow", 2.6)
    shell, shell2, fang, eye = (40, 36, 48), (54, 48, 60), (200, 196, 190), (255, 70, 90)
    r.bone("root")
    r.bone("body", "root", (0, 2.6))
    r.bone("abdomen", "body", (-1.6, 0.6))
    r.bone("head", "body", (1.8, 0.2))
    r.part("body", "ball", (3.4, 2.6, 3.2), (0, 0, 0), color=shell2)
    r.part("abdomen", "ball", (4.6, 3.8, 4.2), (-1.4, 0.6, 0), color=shell)
    for i, (x, y, z) in enumerate(((-1.0, 1.8, 0.8), (-2.2, 1.4, -1.0), (-0.6, 2.2, -0.6))):
        r.part("abdomen", "tri", (0.4, 1.0, 0.3), (x, y, z), rot=-20 + i * 15, color=(150, 255, 170), mat="n", alpha=0.3)
    mask_face(r, "head", (0.3, 0.1), (2.2, 2.0), "round", eye_color=eye)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    for side, s in (("L", -1), ("R", 1)):
        b = r.bone("fang" + side, "head", (1.3, -0.7, s * 0.4), rest=-10)
        r.part(b, "tri", (0.3, 0.9, 0.25), (0, -0.4, 0), rot=180, color=fang)
    legs = {}
    for i in range(4):
        x = 1.0 - i * 0.7
        for side, s in (("L", -1), ("R", 1)):
            up = r.bone(f"l{i}{side}", "body", (x, 0.3, s * 1.2), rest=0)
            lo = r.bone(f"l{i}{side}b", up, (0, 2.25), rest=0)
            yaw = (35 - i * 22) * s
            r.part(up, "box", (0.32, 2.4, 0.32), (0, 1.1, 0), color=(28, 24, 32))
            r.part(up, "ball", (0.5, 0.5, 0.5), (0, 2.25, 0), color=(40, 34, 46))
            r.part(lo, "box", (0.24, 3.6, 0.24), (0, -1.7, 0), color=(22, 20, 26))
            r.part(lo, "tri", (0.24, 0.6, 0.24), (0, -3.7, 0), rot=180, color=(150, 255, 170), mat="n", alpha=0.4)
            r.bones[-2]["r"] = 0
            legs[up] = (i, s, yaw)
    # Legs splay outward (tilt) and swing in alternating tetrapods.
    def leg_keys(length, amp, lift, raise_front=0):
        out = {}
        for up, (i, s, yaw) in legs.items():
            ph = (i + (0 if s < 0 else 1)) % 2
            a0, a1 = (amp, -amp) if ph == 0 else (-amp, amp)
            tilt = -62 * s
            extra = raise_front if i == 0 else 0
            out[up] = loop_keys(length, (a0 + extra, 0, 0, 1, 1, "io", yaw, tilt), (a1 + extra, 0, lift, 1, 1, "io", yaw, tilt))
            out[up + "b"] = loop_keys(length, (0, 0, 0, 1, 1, "io", 0, 118 * s), (0, 0, 0, 1, 1, "io", 0, 118 * s))
        return out
    r.clip("idle", 2.0, dict(leg_keys(2.0, 4, 0), body=loop_keys(2.0, (0, 0, 0), (0, 0, -0.1)), abdomen=loop_keys(2.0, (0, 0, 0, 1, 1), (3, 0, 0, 1.03, 1.04))))
    r.clip("move", 0.5, dict(leg_keys(0.5, 22, 0.1), body=loop_keys(0.5, (0, 0, 0), (0, 0, 0.1))))
    r.clip("windup", 0.4, dict(leg_keys(0.4, 4, 0, raise_front=-70), body=loop_keys(0.4, (15, -0.3, 0.3), (16, -0.3, 0.32)),
                               fangL=loop_keys(0.4, (30,), (35,)), fangR=loop_keys(0.4, (30,), (35,))))
    r.clip("attack", 0.4, dict(leg_keys(0.4, 30, 0.1), body=loop_keys(0.4, (-10, 0.3), (-12, 0.3))))
    r.clip("shoot", 0.45, dict(leg_keys(0.45, 4, 0), abdomen=[K(0, 0, 0, 0, 1, 1), K(0.08, -15, 0, 0, 1.15, 0.9, "o"), K(0.45, 0)]), loop=False)
    r.clip("leap", 0.6, dict(leg_keys(0.6, 0, 0, raise_front=-40), body=loop_keys(0.6, (0, 0, 0, 0.95, 1.05), (0, 0, 0, 0.95, 1.05))))
    r.clip("slam", 0.5, {"body": [K(0, 0, 0, -1.0, 1.15, 0.8, "o"), K(0.5, 0)]}, loop=False, events=[[0, "quake"]])
    boss_common(r, head="head", roar_head=25)
    return r


def asterion():
    """Asterion, the Moth Seraph: pale and immense, with eye-spotted wings and a halo."""
    r = Rig("asterion", 3.5)
    pale, wing, gold = (228, 220, 198), (250, 240, 215), (255, 220, 150)
    r.bone("root")
    r.bone("body", "root", (0, 3.0))
    r.bone("head", "body", (0.2, 2.9))
    r.bone("halo", "head", (-0.4, 0.8))
    for side, s in (("L", -1), ("R", 1)):
        r.bone("wing" + side, "body", (-0.3, 1.6, s * 0.8), rest=0)
        r.bone("wingLow" + side, "body", (-0.3, 0.6, s * 0.8), rest=0)
        r.part("wing" + side, "ball", (3.2, 5.0, 0.2), (-0.8, 1.6, s * 2.2), rot=-25, color=wing, alpha=0.05)
        r.part("wing" + side, "ball", (1.3, 1.3, 0.3), (-0.8, 2.2, s * 2.6), color=(255, 200, 120), mat="n", tag="glow")
        r.part("wing" + side, "ball", (0.6, 0.6, 0.35), (-0.8, 2.2, s * 2.7), color=(60, 40, 30))
        r.part("wingLow" + side, "ball", (2.2, 3.4, 0.2), (-0.9, -0.8, s * 1.7), rot=20, color=(236, 226, 200), alpha=0.05)
        r.bone("arm" + side, "body", (0.4, 2.0, s * 0.7), rest=40)
        r.part("arm" + side, "box", (0.3, 1.8, 0.3), (0, -0.8, 0), color=pale)
    r.part("body", "ball", (2.4, 4.6, 2.2), (0, 1.2, 0), color=pale)
    ring(r, "body", 8, 0.9, 2.6, (0.8, 0.6, 0.8), (245, 238, 225))  # fur ruff
    r.part("body", "tri", (1.2, 2.2, 1.0), (0, -1.6, 0), rot=180, color=pale)
    mask_face(r, "head", (0.1, 0.4), (2.0, 2.2), "tall", eye_color=gold)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    for side in (-1, 1):
        r.part("head", "ball", (0.3, 1.8, 0.5), (-0.3, 1.6, side * 0.5), rot=30, color=pale)
    ring(r, "halo", 14, 1.5, 0.9, (0.25, 0.25, 0.25), gold, mat="n")
    r.part("halo", "ball", (0.1, 3.0, 3.0), (0, 0.9, 0), color=gold, mat="n", alpha=0.8, tag="glow")

    def flap(length, amp, base=0, spread=0):
        return {
            "wingL": loop_keys(length, (0, 0, 0, 1, 1, "io", -base - amp - spread), (0, 0, 0, 1, 1, "io", -base + amp - spread)),
            "wingR": loop_keys(length, (0, 0, 0, 1, 1, "io", base + amp + spread), (0, 0, 0, 1, 1, "io", base - amp + spread)),
            "wingLowL": loop_keys(length, (0, 0, 0, 1, 1, "io", -base - amp * 0.7), (0, 0, 0, 1, 1, "io", -base + amp * 0.7)),
            "wingLowR": loop_keys(length, (0, 0, 0, 1, 1, "io", base + amp * 0.7), (0, 0, 0, 1, 1, "io", base - amp * 0.7)),
        }
    halo = {"halo": loop_keys(3.0, (0, 0, 0, 1, 1, "io", 0), (0, 0, 0.15, 1, 1, "io", 180))}
    r.clip("idle", 1.1, flap(1.1, 25, 10) | {"body": loop_keys(1.1, (0, 0, 0), (0, 0, 0.35))} | halo)
    r.clip("move", 0.7, flap(0.7, 30, 10) | {"body": loop_keys(0.7, (-10, 0, 0), (-10, 0, 0.2))} | halo)
    r.clip("windup", 0.5, flap(0.5, 6, -40) | {"body": loop_keys(0.5, (10, 0, 0, 1.05, 1.05), (11, 0, 0.1, 1.06, 1.06)),
                                               "armL": loop_keys(0.5, (140,), (145,)), "armR": loop_keys(0.5, (140,), (145,))})
    r.clip("shoot", 0.4, {"wingL": [K(0, 0, 0, 0, 1, 1, "o", 40), K(0.08, 0, 0, 0, 1, 1, "io", -60), K(0.4, 0, 0, 0, 1, 1, "io", -10)],
                          "wingR": [K(0, 0, 0, 0, 1, 1, "o", -40), K(0.08, 0, 0, 0, 1, 1, "io", 60), K(0.4, 0, 0, 0, 1, 1, "io", 10)]}, loop=False, events=[[0.08, "radiance"]])
    r.clip("attack", 0.5, flap(0.5, 4, 55) | {"body": loop_keys(0.5, (-45, 0, 0, 0.9, 1.1), (-46, 0, 0, 0.9, 1.1))})
    r.clip("slam", 0.5, flap(0.5, 20, 0) | {"body": [K(0, -20, 0, -0.5), K(0.5, 0)]}, loop=False)
    boss_common(r, roar_head=18)
    r.clips["roar"]["k"].update(flap(1.6, 5, -50))
    return r


def quartzelle():
    """Quartzelle, the Facet Matron: a crystal-grown beetle queen with a blade of quartz."""
    r = Rig("quartzelle", 3.8)
    shell, shell2, crystal, glow = (70, 54, 92), (84, 64, 110), (240, 150, 255), (255, 120, 230)
    r.bone("root")
    for i, x in enumerate((1.0, -0.2, -1.4)):
        for side, s in (("L", -1), ("R", 1)):
            b = r.bone(f"leg{i}{side}", "root", (x, 2.2, s * 1.3), rest=15 - i * 15)
            r.part(b, "box", (0.35, 2.4, 0.35), (0, -1.1, 0), color=(30, 24, 44))
    r.bone("body", "root", (0, 2.2))
    r.bone("head", "body", (1.8, 2.4))
    r.bone("blade", "body", (1.4, 1.6, 1.5), rest=-40)
    r.part("body", "ball", (5.0, 3.8, 4.0), (-1.2, 0.6, 0), color=shell)
    r.part("body", "ball", (3.2, 3.8, 3.4), (0.9, 1.6, 0), color=shell2)
    for i, (x, y, h, rot) in enumerate(((-1.6, 2.6, 3.0, 20), (-2.6, 2.0, 2.2, 45), (-0.6, 2.6, 2.0, -10), (-2.0, 2.8, 1.6, 5))):
        r.part("body", "box", (0.9, h, 0.9), (x, y + h * 0.3, (i % 3 - 1) * 0.8), rot=rot, color=crystal, mat="n", alpha=0.2, tag="glow")
    mask_face(r, "head", (0.2, 0.2), (2.2, 2.2), "drop", eye_color=glow)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    for i, (x, h, rot, z) in enumerate(((0.0, 2.2, 0, 0), (-0.4, 1.8, 20, 0.6), (-0.4, 1.8, 20, -0.6), (0.3, 1.4, -20, 0.3))):
        r.part("head", "box", (0.5, h, 0.5), (x, 1.4 + h * 0.3, z), rot=rot, color=crystal, mat="n", alpha=0.15)
    r.part("blade", "box", (0.5, 1.4, 0.5), (0, -0.6, 0), color=(30, 24, 44))
    r.part("blade", "box", (0.6, 5.0, 0.35), (0, -3.5, 0), color=(255, 200, 255), mat="n", alpha=0.15, tag="glow")
    r.part("blade", "tri", (0.6, 1.2, 0.35), (0, -6.6, 0), rot=180, color=(255, 200, 255), mat="n", alpha=0.15)
    legs = {}
    for i in range(3):
        a, b = f"leg{i}L", f"leg{i}R"
        ph = (20, -20) if i % 2 == 0 else (-20, 20)
        legs[a] = loop_keys(0.8, (ph[0],), (ph[1],))
        legs[b] = loop_keys(0.8, (ph[1],), (ph[0],))
    r.clip("idle", 2.6, {"body": loop_keys(2.6, (0, 0, 0, 1, 1), (-3, 0, 0.1, 1.01, 1.02)), "head": loop_keys(2.6, (0,), (-6,)), "blade": loop_keys(2.6, (0,), (6,))})
    r.clip("move", 0.8, dict(legs, body=loop_keys(0.8, (0, 0, 0), (0, 0, 0.12))))
    r.clip("windup", 0.5, {"blade": loop_keys(0.5, (200,), (204,)), "body": loop_keys(0.5, (12, -0.3), (13, -0.32)), "head": loop_keys(0.5, (10,), (12,))})
    r.clip("attack", 0.5, dict(legs, blade=[K(0, 200), K(0.08, 20, 0, 0, 1, 1, "o"), K(0.5, 0)], body=[K(0, 12), K(0.08, -15, 0.5), K(0.5, 0)]), loop=False, events=[[0.08, "slash"]])
    r.clip("shoot", 0.6, {"body": [K(0, 0), K(0.15, 18, -0.3, 0.3), K(0.45, 18, -0.3, 0.3), K(0.6, 0)], "head": [K(0, 0), K(0.15, 20), K(0.6, 0)]}, loop=False, events=[[0.15, "beam"]])
    r.clip("slam", 0.5, {"body": [K(0, 0, 0, -0.8, 1.1, 0.85, "o"), K(0.5, 0)], "blade": [K(0, -60), K(0.5, 0)]}, loop=False, events=[[0, "quake"]])
    r.clip("leap", 0.6, dict(legs, body=loop_keys(0.6, (-15,), (-16,))))
    boss_common(r, roar_head=22)
    r.clips["roar"]["k"]["blade"] = [K(0, 0), K(0.3, 220), K(1.3, 220), K(1.6, 0)]
    return r


def murrow():
    """Murrow, Archivist of Drowned Words: a robed moth scholar adrift with an open book."""
    r = Rig("murrow", 3.5)
    robe, robe2, page, teal, wing = (40, 70, 74), (30, 56, 60), (236, 228, 200), (110, 240, 230), (110, 130, 120)
    r.bone("root")
    r.bone("body", "root", (0, 2.0))
    r.bone("hem", "body", (0, -0.4))
    r.bone("head", "body", (0.2, 3.4))
    r.bone("book", "body", (1.8, 2.0))
    for side, s in (("L", -1), ("R", 1)):
        r.bone("wing" + side, "body", (-0.5, 2.6, s * 0.6))
        r.part("wing" + side, "ball", (2.6, 3.6, 0.2), (-0.8, 0.8, s * 1.6), rot=-20, color=wing, alpha=0.15)
        r.part("wing" + side, "ball", (0.7, 0.7, 0.3), (-0.8, 1.2, s * 1.9), color=teal, mat="n", tag="glow")
        r.bone("arm" + side, "body", (0.4, 2.6, s * 0.9), rest=50)
        r.part("arm" + side, "box", (0.45, 1.6, 0.45), (0, -0.7, 0), color=robe2)
    r.part("body", "ball", (2.6, 4.8, 2.4), (0, 1.2, 0), color=robe)
    r.part("hem", "ball", (3.0, 1.2, 2.8), (0, -0.6, 0), color=robe2)
    for i in range(6):
        a = i / 6 * math.pi * 2
        r.part("hem", "tri", (0.5, 1.2, 0.3), (math.cos(a) * 1.1, -1.4, math.sin(a) * 1.0), rot=180, color=robe2, flip=i % 2 == 0)
    mask_face(r, "head", (0.1, 0.35), (1.8, 2.0), "tall", eye_color=teal)
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    for side in (-1, 1):
        r.part("head", "ball", (0.25, 1.9, 0.9), (-0.4, 1.7, side * 0.45), rot=35, color=page)  # feathered antennae
    r.part("book", "box", (1.6, 0.2, 1.2), (0, 0, 0), rot=-10, color=(120, 80, 60))
    r.part("book", "box", (1.5, 0.12, 1.1), (0, 0.14, 0), rot=-10, color=page)
    r.part("book", "ball", (0.9, 0.2, 0.8), (0, 0.3, 0), rot=-10, color=teal, mat="n", alpha=0.4, tag="glow")
    float_ = {"root": loop_keys(2.2, (0, 0, 0), (0, 0, 0.4)), "hem": loop_keys(2.2, (5,), (-5,)),
              "book": loop_keys(2.2, (0, 0, 0), (4, 0, 0.3)),
              "wingL": loop_keys(1.4, (0, 0, 0, 1, 1, "io", -10), (0, 0, 0, 1, 1, "io", 15)),
              "wingR": loop_keys(1.4, (0, 0, 0, 1, 1, "io", 10), (0, 0, 0, 1, 1, "io", -15))}
    r.clip("idle", 2.2, float_ | {"head": loop_keys(2.2, (-10,), (-14,))})
    r.clip("move", 1.2, float_ | {"body": loop_keys(1.2, (-12,), (-14,))})
    r.clip("windup", 0.5, {"armL": loop_keys(0.5, (120,), (126,)), "armR": loop_keys(0.5, (120,), (126,)),
                           "book": loop_keys(0.5, (0, -0.8, 1.6), (4, -0.8, 1.7)), "body": loop_keys(0.5, (10,), (11,))})
    r.clip("shoot", 0.4, {"book": [K(0, 0, -0.8, 1.6), K(0.08, -20, 0.8, 0.4, 1.2, 1.2, "o"), K(0.4, 0)],
                          "armR": [K(0, 120), K(0.08, 40), K(0.4, 0)]}, loop=False, events=[[0.08, "pages"]])
    r.clip("attack", 0.5, {"body": loop_keys(0.5, (-30, 0, 0, 0.9, 1.12), (-31, 0, 0, 0.9, 1.12)), "hem": loop_keys(0.5, (30,), (32,))})
    r.clip("slam", 0.5, {"body": [K(0, 0, 0, -0.6, 1.15, 0.85, "o"), K(0.5, 0)]}, loop=False, events=[[0, "splash"]])
    r.clip("vanish", 0.4, {"root": [K(0, 0, 0, 0, 1, 1), K(0.4, 0, 0, -0.5, 0.2, 1.6)]}, loop=False)
    boss_common(r, roar_head=15)
    return r


def echo():
    """The Hollow Echo: the Wanderer's silhouette, inverted: a dark mask with burning pale eyes."""
    r = wanderer("echo", cloak=(12, 12, 16), cloak_dark=(6, 6, 9), mask=(26, 26, 30), eye=(230, 225, 255),
                 nail=(205, 195, 255), glow=(205, 195, 255), shade=True, lining=(28, 24, 36), scarf=(40, 22, 34),
                 fur=(34, 32, 42), wing=(30, 28, 44), chitin=(10, 10, 14), gold=(90, 86, 120))
    r.anchor = 3.0
    for p in r.parts:
        if p.get("t") == "eye":
            p["m"] = "n"
    c = r.clips
    alias = {"move": "run", "windup": "charge", "attack": "dash", "slam": "attackDown", "shoot": "bolt", "leap": "rise", "vanish": "dodge"}
    for new, old in alias.items():
        r.clips[new] = c[old]
    boss_common(r, roar_head=20)
    r.clips["roar"]["k"]["armF"] = [K(0, 0), K(0.3, 160), K(1.3, 160), K(1.6, 0)]
    return r


def recolor(r, old, new):
    for p in r.parts:
        if tuple(p["c"]) == tuple(old):
            p["c"] = list(new)


def enrich(r):
    """A second pass that gives every enemy a stronger colour identity and a few details:
    glowing markings, plates, stripes, crests. Shapes and bones are untouched."""
    n = r.name
    if n == "mite":
        recolor(r, (88, 78, 70), (150, 92, 60))
        recolor(r, (68, 58, 50), (118, 70, 46))
        for x in (-1.1, -0.35, 0.4):
            r.part("body", "ball", (0.7, 0.32, 1.7), (x, 1.12, 0), rot=10, color=(96, 56, 38))
        for side in (-1, 1):
            for x in (-0.9, 0.0):
                r.part("body", "ball", (0.3, 0.3, 0.18), (x, 0.55, side * 0.98), color=(255, 176, 80), mat="n", tag="glow")
        for side in (-1, 1):
            r.part("head", "tri", (0.16, 0.45, 0.14), (0.75, -0.35, side * 0.25), rot=200, color=(60, 40, 30))
    elif n == "crystal_mite":
        recolor(r, (70, 54, 92), (110, 70, 160))
        recolor(r, (50, 34, 72), (80, 46, 124))
        for side in (-1, 1):
            r.part("body", "ball", (0.3, 0.3, 0.18), (-0.5, 0.6, side * 0.98), color=(120, 220, 255), mat="n", tag="glow")
    elif n == "gnat":
        recolor(r, (58, 44, 72), (92, 52, 110))
        recolor(r, (74, 58, 90), (120, 74, 140))
        for i, x in enumerate((-0.35, -0.75)):
            r.part("body", "ball", (0.35, 1.6 - i * 0.25, 1.65 - i * 0.25), (x, -0.05, 0), rot=10, color=(240, 150, 60))
        for z in (-0.3, 0, 0.3):
            r.part("body", "ball", (0.35, 0.45, 0.35), (0.2, 0.95, z), color=(170, 120, 200))
    elif n == "wisp":
        for i, (x, y, z) in enumerate(((0.2, 1.4, 0.5), (-0.4, 1.6, -0.4), (-0.9, 1.1, 0.2))):
            r.part("body", "ball", (0.3, 0.3, 0.3), (x, y, z), color=(160, 255, 240), mat="n", tag="glow")
    elif n == "bulb":
        recolor(r, (96, 124, 72), (120, 170, 80))
        for i in range(6):
            a = i / 6 * math.pi * 2
            r.part("pod", "ball", (0.9, 0.3, 0.7), (math.cos(a) * 1.1, -0.2, math.sin(a) * 1.1), rot=15, color=(236, 110, 170))
        r.part("pod", "ball", (0.5, 0.5, 0.5), (0, 2.1, 0), color=(255, 140, 200), mat="n", tag="glow")
    elif n == "shellguard":
        recolor(r, (70, 74, 96), (48, 80, 150))
        recolor(r, (52, 56, 76), (36, 60, 120))
        for z in (-1.0, 1.0):
            r.part("shield", "box", (0.42, 3.05, 0.16), (0.12, 0.1, z), color=(226, 180, 90), mat="m")
        r.part("shield", "box", (0.45, 0.6, 0.6), (0.14, 0.1, 0), rot=45, color=(255, 200, 110), mat="n", tag="glow")
        r.part("head", "ball", (0.5, 1.3, 0.35), (-0.3, 1.2, 0), rot=35, color=(200, 50, 60))
        r.part("body", "box", (2.5, 0.2, 2.5), (0, 1.0, 0), color=(226, 180, 90), mat="m")
    elif n == "hopper":
        recolor(r, (30, 30, 34), (70, 44, 100))
        for side in (-1, 1):
            r.part("body", "tri", (0.3, 0.9, 0.3), (-0.6 + side * 0.1, 1.3, side * 0.3), rot=-20, color=(150, 110, 200))
        r.part("body", "tri", (0.3, 1.1, 0.3), (-0.2, 1.4, 0), rot=-10, color=(170, 130, 220))
        for leg in ("thighL", "thighR", "shinL", "shinR"):
            r.part(leg, "box", (0.34, 0.18, 0.34), (0, -0.5, 0), color=(120, 80, 160))
        for p in r.parts:
            if p.get("t") == "eye":
                p["c"] = [240, 120, 255]
                p["m"] = "n"
    return r


def all_rigs():
    rigs = [
        wick(), tock(), lirra(), pell(), quill(), ilo(), oriel(), sael(),
        mite(), mite("crystal_mite", (70, 54, 92), crystals=True), gnat(), wisp(), bulb(), shellguard(), hopper(),
        gravelmaw(), vantis(), widow(), asterion(), quartzelle(), murrow(), echo(),
    ]
    return [enrich(r) for r in rigs]
