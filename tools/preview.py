"""Renders animated previews of Vesperdeep's character rigs straight from the rig data in
src/shared/Rigs/*.json (the same data the game animates), so animations can be reviewed
without opening Roblox Studio. Output goes to previews/.

    python tools/preview.py                 # every rig, every clip
    python tools/preview.py wanderer idle   # one rig / clip

The math here mirrors src/shared/Rig.luau: bones are posed with CFrame-style rotations
(Rx * Ry * Rz, degrees), keys are offsets from each bone's rest pose, and a bone's scale
applies only to its own parts.
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(__file__)
RIGS = os.path.join(HERE, "..", "src", "shared", "Rigs")
OUT = os.path.join(HERE, "..", "previews")


# ----------------------------------------------------------------- rig evaluation

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def ease(e, a):
    if e == "l":
        return a
    if e == "i":
        return 1 - math.cos(a * math.pi / 2)
    if e == "o":
        return math.sin(a * math.pi / 2)
    if e == "s":
        return 0.0
    return (1 - math.cos(a * math.pi)) / 2


def sample(keys, t):
    """Returns (r, x, y, sx, sy, ry, rx) for a channel at time t."""
    def unpack(k):
        return [k[1], k[2], k[3], k[4], k[5], k[7] if len(k) > 7 else 0, k[8] if len(k) > 8 else 0]

    if t <= keys[0][0]:
        return unpack(keys[0])
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a[0] <= t < b[0]:
            f = ease(a[6], (t - a[0]) / max(1e-6, b[0] - a[0]))
            va, vb = unpack(a), unpack(b)
            return [va[j] + (vb[j] - va[j]) * f for j in range(7)]
    return unpack(keys[-1])


def pose(rig, clip, t):
    """World transforms (R, pos) and own scale for every bone."""
    keys = clip["k"] if clip else {}
    if clip and clip["loop"]:
        t = t % clip["len"]
    out = {}
    for bone in rig["bones"]:
        ch = sample(keys[bone["n"]], t) if bone["n"] in keys else [0, 0, 0, 1, 1, 0, 0]
        r, x, y, sx, sy, ry, rx = ch
        local_r = rot_x(math.radians(rx)) @ rot_y(math.radians(ry)) @ rot_z(math.radians(bone["r"] + r))
        at = np.array(bone["at"], dtype=float) + np.array([x, y, 0.0])
        if bone["p"] is None:
            R, P = local_r, at
        else:
            pr, pp, _ = out[bone["p"]]
            R, P = pr @ local_r, pp + pr @ at
        out[bone["n"]] = (R, P, (sx, sy))
    return out


def part_geometry(part, bones):
    """Returns (kind, center, rotation, size) of a part in rig space."""
    R, P, (sx, sy) = bones[part["b"]]
    w, h, d = part["z"]
    o = part["o"]
    center = P + R @ np.array([o[0] * sx, o[1] * sy, o[2]])
    rot = R @ rot_z(math.radians(part["r"]))
    return center, rot, (w * sx, h * sy, d)


# ----------------------------------------------------------------- drawing

VIEW = np.array([0.95, 0.25, 1.0])
VIEW = VIEW / np.linalg.norm(VIEW)
FWD = -VIEW
RIGHT = np.cross(FWD, [0, 1, 0])
RIGHT = RIGHT / np.linalg.norm(RIGHT)
UP = np.cross(RIGHT, FWD)


def project(p, scale, origin):
    return (origin[0] + float(p @ RIGHT) * scale, origin[1] - float(p @ UP) * scale)


def hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def shade(color, rot, kind):
    """Simple key light from the upper front-right, like the game's lanterns."""
    light = np.array([0.4, 0.8, 0.5])
    light /= np.linalg.norm(light)
    facing = rot @ np.array([0, 1, 0]) if kind != "ball" else np.array([0, 1, 0])
    k = 0.72 + 0.28 * max(0.0, float(facing @ light))
    return tuple(int(min(255, c * k)) for c in color)


def outline_poly(part, bones, scale, origin):
    center, rot, (w, h, d) = part_geometry(part, bones)
    kind = part["s"]
    if kind == "ball":
        A = rot @ np.diag([w / 2, h / 2, d / 2])
        P = np.stack([RIGHT, UP])
        S = P @ A @ A.T @ P.T
        vals, vecs = np.linalg.eigh(S)
        vals = np.sqrt(np.maximum(vals, 1e-9))
        c2 = project(center, scale, origin)
        pts = []
        for i in range(28):
            a = i / 28 * 2 * math.pi
            v = vecs @ (vals * np.array([math.cos(a), math.sin(a)]))
            pts.append((c2[0] + v[0] * scale, c2[1] - v[1] * scale))
        return pts
    if kind == "tri":
        s = -1 if part.get("f") else 1
        base = [(-w / 2 * s, -h / 2), (w / 2 * s, -h / 2), (w / 2 * s, h / 2)]
        corners = [np.array([x, y, z]) for x, y in base for z in (-d / 2, d / 2)]
    else:  # box / cyl
        corners = [np.array([x, y, z]) for x in (-w / 2, w / 2) for y in (-h / 2, h / 2) for z in (-d / 2, d / 2)]
    pts = [project(center + rot @ c, scale, origin) for c in corners]
    return hull([(round(x, 2), round(y, 2)) for x, y in pts])


_FIT = {}


def fit(rig, size):
    """Scale and origin that frame the rig's rest pose (cached per rig and size)."""
    key = (rig["name"], size)
    if key not in _FIT:
        bones = pose(rig, rig["clips"].get("idle"), 0)
        xs, ys = [], []
        for part in rig["parts"]:
            for x, y in outline_poly(part, bones, 1.0, (0.0, 0.0)):
                xs.append(x)
                ys.append(y)
        w, h = max(xs) - min(xs), max(ys) - min(ys)
        scale = min(size[0] * 0.82 / max(w, 3.0), size[1] * 0.78 / max(h, 4.5))
        cx = (max(xs) + min(xs)) / 2
        _FIT[key] = (scale, (size[0] / 2 - cx * scale, size[1] * 0.88 - max(ys) * scale))
    return _FIT[key]


def render_frame(rig, clip, t, size=(420, 420), scale=None, extra_yaw=0.0):
    bones = pose(rig, clip, t)
    if extra_yaw:
        R0 = rot_y(extra_yaw)
        bones = {k: (R0 @ R, R0 @ P, s) for k, (R, P, s) in bones.items()}
    if scale is None:
        scale, origin = fit(rig, size)
    else:
        origin = (size[0] / 2, size[1] * 0.86)
    img = Image.new("RGB", size, (14, 13, 20))
    grad = ImageDraw.Draw(img)
    for y in range(size[1]):
        k = y / size[1]
        grad.line([(0, y), (size[0], y)], fill=(int(24 - 12 * k), int(24 - 12 * k), int(36 - 16 * k)))
    # Soft ground shadow.
    shadow = Image.new("L", size, 0)
    ImageDraw.Draw(shadow).ellipse([origin[0] - 2.2 * scale, origin[1] - 0.25 * scale, origin[0] + 2.2 * scale, origin[1] + 0.25 * scale], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    img.paste((6, 6, 9), mask=shadow)

    glow = Image.new("RGB", size, (0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    draw = ImageDraw.Draw(img, "RGBA")
    parts = []
    for part in rig["parts"]:
        center, rot, _ = part_geometry(part, bones)
        parts.append((float(center @ VIEW), part, rot))
    parts.sort(key=lambda p: p[0])
    for _, part, rot in parts:
        poly = outline_poly(part, bones, scale, origin)
        if len(poly) < 3:
            continue
        color = tuple(part["c"])
        alpha = int(255 * (1 - part.get("a", 0)))
        if part["m"] == "n":
            gdraw.polygon(poly, fill=color)
            draw.polygon(poly, fill=color + (alpha,))
        else:
            fill = shade(color, rot, part["s"])
            draw.polygon(poly, fill=fill + (alpha,), outline=(6, 5, 9, min(255, alpha + 40)))
    glow = glow.filter(ImageFilter.GaussianBlur(9))
    img = Image.fromarray(np.clip(np.asarray(img, dtype=np.int32) + np.asarray(glow, dtype=np.int32) * 0.7, 0, 255).astype(np.uint8))
    return img


def render_clip(rig, name, clip, frames_per_second=30, size=(420, 420), label=True):
    length = clip["len"] if clip else 1.0
    total = length * (2 if clip and clip["loop"] and length < 1.2 else 1) + (0 if clip and clip["loop"] else 0.35)
    frames = []
    n = max(2, int(total * frames_per_second))
    for i in range(n):
        t = i / frames_per_second
        img = render_frame(rig, clip, min(t, length) if not clip["loop"] else t, size)
        if label:
            d = ImageDraw.Draw(img)
            d.text((10, 8), f"{rig['name']} · {name}", fill=(210, 205, 225))
        frames.append(img)
    return frames


def save_gif(frames, path, fps=30):
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)


def load(name):
    with open(os.path.join(RIGS, name + ".json")) as f:
        return json.load(f)


def sheet(rig, clips, cols=4, size=(300, 300), fps=24):
    """One GIF with several clips playing side by side."""
    renders = {c: render_clip(rig, c, rig["clips"][c], fps, size) for c in clips}
    n = max(len(v) for v in renders.values())
    rows = math.ceil(len(clips) / cols)
    frames = []
    for i in range(n):
        canvas = Image.new("RGB", (cols * size[0], rows * size[1]), (10, 10, 14))
        for j, c in enumerate(clips):
            seq = renders[c]
            canvas.paste(seq[i % len(seq)], ((j % cols) * size[0], (j // cols) * size[1]))
        frames.append(canvas)
    return frames


def mixed_sheet(entries, cols=4, size=(260, 260), fps=24, seconds=None):
    """One GIF of several (rig, clip) pairs from different rigs playing side by side."""
    renders = []
    for name, clip in entries:
        rig = load(name)
        renders.append(render_clip(rig, clip, rig["clips"][clip], fps, size))
    n = int(seconds * fps) if seconds else max(len(r) for r in renders)
    rows = math.ceil(len(entries) / cols)
    frames = []
    for i in range(n):
        canvas = Image.new("RGB", (cols * size[0], rows * size[1]), (10, 10, 14))
        for j, seq in enumerate(renders):
            canvas.paste(seq[i % len(seq)], ((j % cols) * size[0], (j // cols) * size[1]))
        frames.append(canvas)
    return frames


SHOWCASE = {
    "showcase_wanderer": [("wanderer", c) for c in ["idle", "run", "attackSide", "attackUp", "cleave", "dash", "swing", "heal"]],
    "showcase_npcs": [(n, "idle") for n in ["wick", "tock", "lirra", "pell", "quill", "ilo", "oriel", "sael"]],
    "showcase_npcs_talk": [(n, "talk") for n in ["wick", "tock", "lirra", "pell", "quill", "ilo", "oriel", "sael"]],
    "showcase_enemies": [("mite", "move"), ("crystal_mite", "attack"), ("gnat", "move"), ("wisp", "attack"),
                         ("bulb", "attack"), ("shellguard", "attack"), ("hopper", "attack"), ("mite", "attack")],
    "showcase_bosses": [("gravelmaw", "attack"), ("vantis", "attack"), ("widow", "attack"), ("asterion", "shoot"),
                        ("quartzelle", "attack"), ("murrow", "shoot"), ("echo", "attack"), ("asterion", "roar")],
}


def showcase():
    os.makedirs(OUT, exist_ok=True)
    for name, entries in SHOWCASE.items():
        frames = mixed_sheet(entries, seconds=2.5)
        save_gif(frames, os.path.join(OUT, f"{name}.gif"), fps=24)
        frames[len(frames) // 3].save(os.path.join(OUT, f"{name}.png"))
        print("rendered", name)


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1:] == ["showcase"]:
        showcase()
        return
    names = [sys.argv[1]] if len(sys.argv) > 1 else sorted(f[:-5] for f in os.listdir(RIGS) if f.endswith(".json"))
    for name in names:
        rig = load(name)
        clips = [sys.argv[2]] if len(sys.argv) > 2 else list(rig["clips"].keys())
        if len(clips) == 1:
            frames = render_clip(rig, clips[0], rig["clips"][clips[0]])
            save_gif(frames, os.path.join(OUT, f"{name}_{clips[0]}.gif"))
        else:
            frames = sheet(rig, clips)
            save_gif(frames, os.path.join(OUT, f"{name}.gif"), fps=24)
            frames[0].save(os.path.join(OUT, f"{name}.png"))
        print("rendered", name, len(clips), "clips")


if __name__ == "__main__":
    main()
