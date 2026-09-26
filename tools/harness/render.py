"""Renders screenshots of the world exactly as the builder generates it.

Takes tools/harness/out/scene.json (from run.py), rebuilds terrain on Roblox's 4-stud voxel
grid (smoothed with marching cubes, like Smooth Terrain), places every part, light and
particle cloud, poses the character rigs where the game spawns them, and renders views with
three.js in headless Chromium.

    python tools/harness/render.py               # every shot in SHOTS
    python tools/harness/render.py burrows_play  # one shot

This is a preview renderer, not Roblox: lighting, materials and fog are approximations of
Future lighting, and terrain textures are replaced by tinted noise.
"""

import base64
import http.server
import json
import math
import os
import socketserver
import subprocess
import sys
import threading

import numpy as np
from scipy import ndimage
from skimage import measure

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out")
WEB = os.path.join(HERE, "web")
SHOTS_DIR = os.path.join(ROOT, "previews", "world")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import preview  # noqa: E402  (rig posing math shared with the animation previewer)

VOX = 4.0

# Roblox's default terrain colours, used when a zone doesn't override a material.
DEFAULT_MAT = {
    "Grass": (106, 127, 63), "Slate": (63, 127, 107), "Concrete": (127, 102, 63), "Brick": (138, 86, 62),
    "Sand": (143, 126, 95), "WoodPlanks": (139, 109, 79), "Rock": (102, 108, 111), "Glacier": (101, 176, 234),
    "Snow": (195, 199, 218), "Sandstone": (137, 90, 71), "Mud": (58, 46, 36), "Basalt": (30, 30, 37),
    "Ground": (102, 92, 59), "CrackedLava": (232, 156, 74), "Asphalt": (115, 123, 107), "Cobblestone": (132, 123, 90),
    "Ice": (129, 194, 224), "LeafyGrass": (115, 132, 74), "Salt": (198, 189, 181), "Limestone": (206, 173, 148),
    "Pavement": (148, 148, 140), "Water": (12, 84, 92),
}

ENEMY_RIGS = {"c": "mite", "m": "crystal_mite", "f": "gnat", "w": "wisp", "s": "bulb", "g": "shellguard", "h": "hopper"}
FLYERS = {"f", "w"}


def load_scene():
    with open(os.path.join(OUT, "scene.json")) as f:
        recs = json.load(f)
    scene = {"parts": [], "lights": [], "pe": [], "terrain": [], "mc": {}, "zones": {}, "themes": {}, "enemies": [], "bosses": [], "start": None}
    for r in recs:
        k = r["k"]
        if k == "part":
            scene["parts"].append(r)
        elif k == "light":
            scene["lights"].append(r)
        elif k == "pe":
            scene["pe"].append(r)
        elif k == "t":
            scene["terrain"].append(r)
        elif k == "mc":
            scene["mc"][r["m"]] = r["col"]
        elif k == "zone":
            scene["zones"][r["i"]] = r
        elif k == "theme":
            scene["themes"][r["z"]] = r
        elif k == "enemy":
            scene["enemies"].append(r)
        elif k == "boss":
            scene["bosses"].append(r)
        elif k == "start":
            scene["start"] = r["p"]
    return scene


def cf_rot(cf):
    return np.array([[cf[3], cf[4], cf[5]], [cf[6], cf[7], cf[8]], [cf[9], cf[10], cf[11]]])


# ----------------------------------------------------------------- terrain

def op_bounds(op):
    if op["f"] == "ball":
        p, r = np.array(op["p"]), op["r"]
        return p - r, p + r
    if op["f"] == "cylinder":
        R = cf_rot(op["cf"])
        half = np.array([op["r"], op["h"] / 2, op["r"]])
    else:
        R = cf_rot(op["cf"])
        half = np.array(op["s"]) / 2
    ext = np.abs(R) @ half
    p = np.array(op["cf"][:3])
    return p - ext, p + ext


def voxelize(ops, lo, hi):
    """Returns (material grid, material names, origin) on the 4-stud grid covering lo..hi."""
    i0 = np.floor(lo / VOX).astype(int)
    i1 = np.ceil(hi / VOX).astype(int)
    shape = tuple(i1 - i0)
    grid = np.zeros(shape, dtype=np.int16)
    names = ["Air"]
    for op in ops:
        a, b = op_bounds(op)
        j0 = np.maximum(np.floor(a / VOX).astype(int) - i0, 0)
        j1 = np.minimum(np.ceil(b / VOX).astype(int) - i0, np.array(shape))
        if np.any(j1 <= j0):
            continue
        xs = (np.arange(j0[0], j1[0]) + i0[0] + 0.5) * VOX
        ys = (np.arange(j0[1], j1[1]) + i0[1] + 0.5) * VOX
        zs = (np.arange(j0[2], j1[2]) + i0[2] + 0.5) * VOX
        X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
        P = np.stack([X, Y, Z], axis=-1)
        if op["f"] == "ball":
            inside = np.linalg.norm(P - np.array(op["p"]), axis=-1) <= op["r"] + 0.8
        else:
            R = cf_rot(op["cf"])
            L = (P - np.array(op["cf"][:3])) @ R  # into local space (R^T applied to rows)
            if op["f"] == "cylinder":
                inside = (np.abs(L[..., 1]) <= op["h"] / 2 + 0.8) & (L[..., 0] ** 2 + L[..., 2] ** 2 <= (op["r"] + 0.8) ** 2)
            else:
                s = np.array(op["s"]) / 2 + 0.8
                inside = (np.abs(L[..., 0]) <= s[0]) & (np.abs(L[..., 1]) <= s[1]) & (np.abs(L[..., 2]) <= s[2])
                if op["f"] == "wedge":
                    # Solid below the slope running from the low front (-Z) edge up to the high back (+Z).
                    inside &= (L[..., 1] + s[1]) / (2 * s[1]) <= (L[..., 2] + s[2]) / (2 * s[2]) + 0.05
        m = op["m"]
        if m == "Air":
            idx = 0
        else:
            if m not in names:
                names.append(m)
            idx = names.index(m)
        sub = grid[j0[0]:j1[0], j0[1]:j1[1], j0[2]:j1[2]]
        sub[inside] = idx
    return grid, names, i0 * VOX


TERRAIN_GRID = {"grid": None, "origin": None}


def solid_at(p):
    grid, origin = TERRAIN_GRID["grid"], TERRAIN_GRID["origin"]
    if grid is None:
        return False
    j = np.floor((np.array(p) - origin) / VOX).astype(int)
    if np.any(j < 0) or np.any(j >= np.array(grid.shape)):
        return False
    return grid[j[0], j[1], j[2]] > 0


def collide_camera(focus, eye):
    """Pull the camera in front of terrain between it and the focus, like CameraController."""
    f, e = np.array(focus, dtype=float), np.array(eye, dtype=float)
    d = e - f
    n = np.linalg.norm(d)
    steps = int(n / 0.5)
    for i in range(1, steps + 1):
        p = f + d * (i / steps)
        if solid_at(p):
            return (f + d / n * max(1.5, (i - 1) * 0.5 - 1.0)).tolist()
    return eye


def value_noise(p, freq, seed=0):
    q = p * freq + seed
    return (np.sin(q[:, 0] * 1.7 + np.sin(q[:, 1] * 2.3)) * np.cos(q[:, 2] * 1.3 + q[:, 1] * 0.7) +
            np.sin(q[:, 1] * 3.1 + q[:, 0] * 0.9) * 0.5) / 1.5


def terrain_mesh(scene, x0, x1):
    ops = []
    for op in scene["terrain"]:
        a, b = op_bounds(op)
        if b[0] >= x0 - 8 and a[0] <= x1 + 8:
            ops.append(op)
    if not ops:
        return None
    lo = np.array([x0 - 8, -16, min(op_bounds(o)[0][2] for o in ops) - 8])
    hi = np.array([x1 + 8, max(op_bounds(o)[1][1] for o in ops) + 8, max(op_bounds(o)[1][2] for o in ops) + 8])
    grid, names, origin = voxelize(ops, lo, hi)
    solid = (grid > 0).astype(np.float32)
    field = ndimage.gaussian_filter(solid, 0.75)
    field = np.pad(field, 1)
    verts, faces, normals, _ = measure.marching_cubes(field, 0.5, spacing=(VOX, VOX, VOX))
    verts = verts - VOX + origin + VOX / 2
    # Colour each vertex from the nearest solid voxel's material.
    idx = np.floor((verts - origin) / VOX).astype(int)
    colors = np.zeros((len(verts), 3), dtype=np.float32)
    best = np.full(len(verts), -np.inf)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                j = idx + np.array([dx, dy, dz])
                j = np.clip(j, 0, np.array(grid.shape) - 1)
                m = grid[j[:, 0], j[:, 1], j[:, 2]]
                center = origin + (j + 0.5) * VOX
                d = -np.linalg.norm(center - verts, axis=1)
                take = (m > 0) & (d > best)
                best[take] = d[take]
                for mi in np.unique(m[take]):
                    name = names[mi]
                    col = scene["mc"].get(name)
                    rgb = np.array(col) if col else np.array(DEFAULT_MAT.get(name, (120, 120, 120))) / 255
                    sel = take & (m == mi)
                    colors[sel] = rgb
    # Painted texture: large-scale tone shifts, strata bands and speckle.
    n1 = value_noise(verts, 0.05, 1.0)
    n2 = value_noise(verts, 0.31, 7.0)
    bands = np.sin(verts[:, 1] * 0.55 + n1 * 2.0) * 0.5 + 0.5
    shade = 0.82 + 0.16 * n1 + 0.08 * n2 + 0.08 * bands
    colors = np.clip(colors * shade[:, None], 0, 1)
    TERRAIN_GRID["grid"], TERRAIN_GRID["origin"] = grid, origin
    return {
        "pos": base64.b64encode(verts.astype(np.float32).tobytes()).decode(),
        "nrm": base64.b64encode((-normals).astype(np.float32).tobytes()).decode(),
        "col": base64.b64encode(colors.astype(np.float32).tobytes()).decode(),
        "idx": base64.b64encode(faces.astype(np.uint32).tobytes()).decode(),
    }


# ----------------------------------------------------------------- rigs

def rig_frame(pos, facing):
    f = np.array([facing[0], 0.0, facing[2]])
    n = np.linalg.norm(f)
    f = f / n if n > 1e-6 else np.array([1.0, 0, 0])
    y = np.array([0.0, 1.0, 0.0])
    z = np.cross(f, y)
    return np.column_stack([f, y, z]), np.array(pos, dtype=float)


def rig_parts(name, clip_name, t, pos, facing, scale=1.0):
    rig = preview.load(name)
    clip = rig["clips"].get(clip_name) or rig["clips"].get("idle")
    bones = preview.pose(rig, clip, t)
    F, P = rig_frame(pos, facing)
    out = []
    for part in rig["parts"]:
        center, rot, size = preview.part_geometry(part, bones)
        wc = P + F @ (center * scale)
        wr = F @ rot
        w, h, d = (s * scale for s in size)
        col = [c / 255 for c in part["c"]]
        mat = {"n": "Neon", "g": "Glass", "m": "Metal", "f": "Fabric"}.get(part["m"], "SmoothPlastic")
        rec = {"k": "part", "t": part.get("a", 0), "col": col, "m": mat, "rig": True}
        if part["s"] == "tri":
            ry = preview.rot_y(-math.pi / 2 if part.get("f") else math.pi / 2)
            wr = wr @ ry
            rec.update({"c": "WedgePart", "s": [d, h, w], "sh": "Block", "mesh": ""})
        elif part["s"] == "ball":
            rec.update({"c": "Part", "s": [w, h, d], "sh": "Block", "mesh": "Sphere"})
        else:
            rec.update({"c": "Part", "s": [w, h, d], "sh": "Block", "mesh": ""})
        rec["cf"] = list(wc) + list(wr.reshape(-1))
        out.append(rec)
    return out


def arc_parts(center, facing, radius, a0, a1, color, glow, thickness, segments=12):
    """The same geometry as client/Fx.arc, fully drawn (the in-game arc sweeps in over ~0.06s)."""
    out = []
    n = segments
    for i in range(n):
        f = i / (n - 1)
        deg = a0 + (a1 - a0) * f
        a = math.radians(180 - deg if facing < 0 else deg)
        taper = math.sin(f * math.pi) ** 0.7
        seg = radius * math.radians(abs(a1 - a0)) / n * 1.35
        for outer in ((False, True) if glow else (False,)):
            r = radius + (thickness * 0.6 if outer else 0)
            pos = [center[0] + math.cos(a) * r, center[1] + math.sin(a) * r, 0.9 if outer else 1.1]
            rot = preview.rot_z(a + math.pi / 2)
            out.append({"k": "part", "c": "Part", "sh": "Block", "mesh": "", "m": "Neon",
                        "t": 0.84 if outer else 0.25 + (1 - f) * 0.45,
                        "col": [c / 255 for c in (glow if outer else color)],
                        "s": [seg, max(0.08, thickness * taper * (1.8 if outer else 1)), 0.15],
                        "cf": pos + list(rot.reshape(-1))})
    return out


def impact_parts(at, color=(255, 255, 255), heavy=False):
    s = 1.7 if heavy else 1
    out = [{"k": "part", "c": "Part", "sh": "Ball", "mesh": "", "m": "Neon", "t": 0.35, "col": [1, 1, 1],
            "s": [1.3 * s] * 3, "cf": list(at) + [1, 0, 0, 0, 1, 0, 0, 0, 1]}]
    rng = np.random.default_rng(3)
    for _ in range(10 if heavy else 7):
        d = rng.normal(size=3)
        d[2] *= 0.25
        d /= np.linalg.norm(d)
        length = (2.2 if heavy else 1.5) * rng.uniform(0.6, 1.3)
        p = np.array(at) + d * (1.2 + length / 2)
        z = d
        x = np.cross([0, 1, 0], z)
        x = x / (np.linalg.norm(x) + 1e-9)
        y = np.cross(z, x)
        R = np.column_stack([x, y, z])
        out.append({"k": "part", "c": "Part", "sh": "Block", "mesh": "", "m": "Neon", "t": 0.0,
                    "col": [c / 255 for c in color], "s": [0.14, 0.14, length], "cf": list(p) + list(R.reshape(-1))})
    return out


def characters(scene, zone, x0, x1, player_at=None, player_facing=(1, 0, 0), player_clip="idle"):
    parts = []
    lights = []

    def inside(p):
        return x0 - 10 <= p[0] <= x1 + 10

    for p in scene["parts"]:
        if p["n"] == "NPCAnchor" and p.get("npc") and inside(p["cf"]):
            feet = [p["cf"][0], p["cf"][1] - p["s"][1] / 2, p["cf"][2]]
            try:
                parts += rig_parts(p["npc"], "idle", 0.7, feet, (0.35, 0, 1))
            except FileNotFoundError:
                pass
    for e in scene["enemies"]:
        if e["z"] == zone and inside(e["p"]):
            rig = ENEMY_RIGS[e["kind"]]
            y = e["p"][1] if e["kind"] in FLYERS else e["p"][1] - 2
            parts += rig_parts(rig, "idle", 0.3, [e["p"][0], y, e["p"][2]], (-1, 0, 0.3))
    for b in [b for b in scene["bosses"] if b["id"] != "trials"]:
        if b["z"] == zone and inside(b["p"]):
            parts += rig_parts(b["id"], "idle", 0.5, [b["p"][0], b["floor"], b["p"][2]], (-1, 0, 0.2))
    if player_at is not None:
        clip_name, clip_t = (player_clip if isinstance(player_clip, tuple) else (player_clip, 0.4))
        parts += rig_parts("wanderer", clip_name, clip_t, player_at, player_facing, PLAYER_SCALE)
        lights.append({"p": [player_at[0], player_at[1] + 2, player_at[2]], "col": [1, 0.84, 0.63], "r": 22, "b": 1.1, "on": True})
    return parts, lights


PLAYER_SCALE = 1.3


# ----------------------------------------------------------------- shots

def zone_by_id(scene, zid):
    for i, t in scene["themes"].items():
        if t["id"] == zid:
            return i
    raise KeyError(zid)


def orbit_camera(focus, yaw_deg, pitch_deg, dist, shoulder=1.4):
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    # Matches CameraController: CFrame.new(focus) * Angles(0, yaw, 0) * Angles(pitch, 0, 0) * (shoulder, 0, dist)
    R = preview.rot_y(yaw) @ preview.rot_x(pitch)
    eye = np.array(focus) + R @ np.array([shoulder, 0, dist])
    target = np.array(focus) + R @ np.array([shoulder, 0, 0])
    return eye.tolist(), target.tolist()


def make_shot(scene, name, zone, x0, x1, eye, target, player_at=None, player_facing=(1, 0, 0), clip="idle", cut_z=None, fov=70, exposure=1.0, extra=None):
    theme = scene["themes"][zone]
    parts = [p for p in scene["parts"] if x0 - 30 <= p["cf"][0] <= x1 + 30 and float(p["t"]) < 0.99]
    lights = [l for l in scene["lights"] if x0 - 30 <= l["p"][0] <= x1 + 30 and l["on"]]
    pes = [p for p in scene["pe"] if x0 - 30 <= p["p"][0] <= x1 + 30]
    char_parts, char_lights = characters(scene, zone, x0, x1, player_at, player_facing, clip)
    if extra:
        char_parts += extra
    terrain = terrain_mesh(scene, x0, x1)
    if cut_z is None:
        eye = collide_camera(target, eye)
    data = {
        "name": name,
        "theme": theme,
        "eye": eye,
        "target": target,
        "fov": fov,
        "cutZ": cut_z,
        "exposure": exposure,
        "parts": parts + char_parts,
        "lights": lights + char_lights,
        "pe": pes,
        "terrain": terrain,
    }
    with open(os.path.join(WEB, "shots", name + ".json"), "w") as f:
        json.dump(data, f)
    return name


def floor_under(scene, x, z, y_hint):
    """Top of the nearest walkable surface under (x, y_hint, z), from terrain fills and parts."""
    best = -1e9
    for op in scene["terrain"]:
        if op["f"] != "block":
            continue
        c, s = op["cf"], op["s"]
        if abs(c[3] - 1) > 1e-3:
            continue
        top = c[1] + s[1] / 2
        if abs(x - c[0]) <= s[0] / 2 and abs(z - c[2]) <= s[2] / 2 and top <= y_hint + 1 and top > best:
            best = top
    return best


def side_camera(focus, dist=52.0):
    """Matches CameraController in side view: straight at the play plane, slightly above."""
    eye = [focus[0], focus[1] + dist * 0.06, dist]
    return eye, [focus[0], focus[1], 0]


def default_shots(scene):
    shots = []
    for zi, theme in sorted(scene["themes"].items()):
        zid = theme["id"]
        zone = scene["zones"][zi]
        x0, x1 = zone["min"][0], zone["max"][0]
        spots = []
        if zi == 1 and scene["start"]:
            spots.append(scene["start"])
        for p in scene["parts"]:
            if p["z"] == zi and p["n"] == "NPCAnchor":
                spots.append([p["cf"][0] + 8, p["cf"][1] + 0.5, 0])
        for e in scene["enemies"]:
            if e["z"] == zi and e["kind"] not in FLYERS:
                spots.append([e["p"][0] - 10, e["p"][1] + 1, 0])
        for k, s in enumerate(spots[:3]):
            fy = floor_under(scene, s[0], 0, s[1] + 2)
            if fy < -1e8:
                continue
            feet = [s[0], fy, 0]
            focus = [feet[0] + 6, feet[1] + 3 + 3, 0]
            eye, target = side_camera(focus)
            shots.append(dict(name=f"{zid}_2d{k + 1}", zone=zi, x0=feet[0] - 90, x1=feet[0] + 90, eye=eye, target=target,
                              player_at=feet, player_facing=(1, 0, 0), clip="run" if k == 1 else "idle", fov=40))
        # A wide shot of a long stretch of the region.
        mid = [(x0 + x1) / 2, (zone["min"][1] + zone["max"][1]) / 2, 0]
        eye, target = side_camera(mid, min(260.0, (x1 - x0) * 0.45))
        shots.append(dict(name=f"{zid}_wide", zone=zi, x0=x0, x1=x1, eye=eye, target=target, fov=40, exposure=1.2))
    return shots


COMBAT = [
    # (name, zone id, hero clip, clip time, arc (a0, a1, radius, lift, color, glow, thickness, segs), enemy (rig, clip, t), heavy)
    ("combat_slash1", "forest", "attackSide", 0.1, (75, -35, 5.6, 0.6, (240, 246, 255), (160, 200, 255), 0.5, 12), ("mite", "hurt", 0.05), False),
    ("combat_slash2", "mines", "attackSide2", 0.1, (-80, 60, 5.4, 0.4, (215, 240, 255), (120, 230, 240), 0.45, 12), ("crystal_mite", "hurt", 0.05), False),
    ("combat_finisher", "ruins", "attackFinish", 0.19, (120, -50, 7.2, 0.8, (255, 244, 214), (255, 196, 110), 0.85, 16), ("shellguard", "stagger", 0.08), True),
    ("combat_upslash", "glowmire", "attackUp", 0.1, (20, 160, 4.6, 1.2, (240, 246, 255), (170, 210, 255), 0.45, 12), ("gnat", "hurt", 0.05), False),
]


def combat_shots(scene):
    shots = []
    for name, zid, clip, t, arc, enemy, heavy in COMBAT:
        zi = zone_by_id(scene, zid)
        # Stand on the first long floor strip near an NPC or bench of the region.
        anchor = next((p for p in scene["parts"] if p["z"] == zi and p["n"] == "NPCAnchor"), None)
        x = (anchor["cf"][0] + 14) if anchor else scene["zones"][zi]["min"][0] + 60
        y = floor_under(scene, x, 0, (anchor["cf"][1] + 3) if anchor else 200)
        feet = [x, y, 0]
        root = [x, y + 3, 0]
        a0, a1, radius, lift, color, glow, thick, segs = arc
        center = [root[0], root[1] + lift, 0]
        extra = arc_parts(center, 1, radius, a0, a1, color, glow, thick, segs)
        rig, eclip, et = enemy
        if rig == "gnat":
            epos = [x + 1.5, y + 3 + 5.0, 0]
            contact = [x + 1.2, y + 3 + 3.8, 1.2]
        else:
            epos = [x + 5.5, y, 0]
            contact = [x + 4.2, y + 3.4, 1.2]
        extra += rig_parts(rig, eclip, et, epos, (-1, 0, 0))
        extra += impact_parts(contact, (255, 220, 150) if heavy else (255, 255, 255), heavy)
        focus = [x + 3, y + 5, 0]
        eye = [focus[0], focus[1] + 1.2, 30]
        shots.append(dict(name=name, zone=zi, x0=x - 60, x1=x + 60, eye=eye, target=focus, player_at=feet,
                          player_facing=(1, 0, 0), clip=(clip, t), fov=40, extra=extra))
    return shots


# The Hall of Trials' champions, each posed in the arena facing the hero.
CHAMPIONS = [("sessa", "windup", 0.1), ("mirra", "attack", 0.1), ("carapace", "windup", 0.2), ("vell", "shoot", 0.08), ("pyrrhe", "uppercut", 0.3)]


def trial_shots(scene):
    shots = []
    try:
        zi = zone_by_id(scene, "trials")
    except KeyError:
        return shots
    boss = next((b for b in scene.get("bosses", []) if b.get("z") == zi), None)
    x0 = scene["zones"][zi]["min"][0]
    ax = (boss["p"][0] if boss else x0 + 180)
    for name, clip, t in CHAMPIONS:
        y = floor_under(scene, ax, 0, (boss["p"][1] if boss else 60) + 2)
        bpos = [ax, y + (10 if name == "vell" else 0), 0]
        hero = [ax - 16, y, 0]
        extra = rig_parts(name, clip, t, bpos, (-1, 0, 0))
        focus = [ax - 6, y + 6, 0]
        eye = [focus[0], focus[1] + 2, 44]
        shots.append(dict(name=f"trials_{name}", zone=zi, x0=ax - 70, x1=ax + 70, eye=eye, target=focus, player_at=hero,
                          player_facing=(1, 0, 0), clip="idle", fov=40, extra=extra))
    return shots


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


def serve():
    os.chdir(WEB)
    httpd = socketserver.TCPServer(("127.0.0.1", 0), Quiet)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def main():
    scene = load_scene()
    os.makedirs(os.path.join(WEB, "shots"), exist_ok=True)
    os.makedirs(SHOTS_DIR, exist_ok=True)
    shots = default_shots(scene) + combat_shots(scene) + trial_shots(scene)
    only = sys.argv[1:]
    if only:
        shots = [s for s in shots if any(s["name"].startswith(o) for o in only)]
    names = []
    for s in shots:
        print("preparing", s["name"])
        names.append(make_shot(scene, **s))
    httpd = serve()
    port = httpd.server_address[1]
    env = dict(os.environ, NODE_PATH="/opt/node22/lib/node_modules")
    subprocess.run(["node", os.path.join(WEB, "capture.js"), str(port), SHOTS_DIR] + names, check=True, env=env)
    httpd.shutdown()


if __name__ == "__main__":
    main()
