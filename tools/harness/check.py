"""Checks that set dressing never blocks the playable path.

For every standable tile in every zone (open tile on solid ground, not a hazard), the space a
player walks through (from the floor up to two tiles, across the middle of the corridor) must
be free of terrain and of collidable parts. Reads tools/harness/out/scene.json (run.py).

    python tools/harness/check.py
"""

import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import render  # noqa: E402

TILE = 4.0
SPACING = 1200.0
MARGIN = 6.0  # the band along each wall where props are allowed


def load_zones():
    """Minimal parse of src/shared/Zones.luau: id, wide, map rows."""
    src = open(os.path.join(ROOT, "src", "shared", "Zones.luau")).read()
    zones = []
    for block in src.split("\t{\n\t\tid = ")[1:]:
        zid = re.match(r'"(\w+)"', block).group(1)
        wide = re.search(r"wide = ([\d.]+)", block)
        rows = re.findall(r'\t\t\t"([^"]+)",', block.split("map = {")[1])
        arena = re.search(r'kind = "boss".*?arena = \{ (\d+), (\d+) \}', block)
        zones.append({"id": zid, "wide": float(wide.group(1)) if wide else 1.0, "map": rows,
                      "arena": (int(arena.group(1)), int(arena.group(2))) if arena else None})
    return zones


def main():
    scene = render.load_scene()
    zones = load_zones()
    # Half widths come from the builder's own export: read them back from the Grid logic by
    # sampling the side-wall slabs (one FillBlock per column per side).
    problems = 0
    for zi, zone in enumerate(zones, start=1):
        rows = zone["map"]
        h, w = len(rows), len(rows[0])
        ox = (zi - 1) * SPACING
        x0, x1 = ox, ox + w * TILE
        mesh = render.terrain_mesh(scene, x0, x1)
        if mesh is None:
            continue
        hz = {}
        for op in scene["terrain"]:
            if op["f"] == "block" and op["m"] != "Air":
                c = op["cf"]
                s = op["s"]
                if abs(s[0] - TILE) < 1e-3 and abs(s[2] - 14) < 1e-3 and x0 <= c[0] <= x1 and c[2] > 0:
                    col = int((c[0] - ox) // TILE) + 1
                    hz[col] = c[2] - 7
        solid = lambda ch: ch in "#%"
        collidables = [p for p in scene["parts"] if p.get("cc") and x0 - 10 <= p["cf"][0] <= x1 + 10 and p.get("n") not in (
            "VistaBarrier", "DoorPillar", "CrystalSeal", "BossGate", "ShortcutGate", "CrackedWall", "SmoothStone", "Bench", "Switch")]
        zone_problems = []
        for r in range(1, h):
            for c in range(1, w + 1):
                ch = rows[r - 1][c - 1]
                below = rows[r][c - 1]
                if solid(ch) or ch in "^~" or not solid(below):
                    continue
                # Doorways narrow to a portal on purpose.
                if any(rows[r - 1][cc - 1].isdigit() for cc in range(max(1, c - 2), min(w, c + 2) + 1)):
                    continue
                half = hz.get(c)
                if half is None:
                    continue
                band = half - MARGIN
                if band <= 1:
                    continue
                x = ox + (c - 0.5) * TILE
                floor_y = (h - r) * TILE
                clear = 0
                rr = r
                while rr >= 1 and not solid(rows[rr - 1][c - 1]):
                    clear += 1
                    rr -= 1
                # Terrain is checked on Roblox's 4-stud voxel grid, so allow one voxel of slack.
                tband = band - TILE
                for dy in (1.5, 4.0, 7.0):
                    if dy > clear * TILE - 1.5:
                        continue
                    for z in np.linspace(-tband, tband, 7):
                        p = (x, floor_y + dy, z)
                        if render.solid_at(p):
                            zone_problems.append(f"terrain at col {c} row {r} z {z:.0f} (+{dy})")
                            break
                # Collidable parts overlapping the walking band.
                for part in collidables:
                    cx, cy, cz = part["cf"][:3]
                    s = part["s"]
                    ext = max(s) / 2
                    if abs(cx - x) < TILE / 2 + ext and floor_y < cy + ext and cy - ext < floor_y + 7 and abs(cz) + 0 < band - ext:
                        zone_problems.append(f"collidable {part.get('n')} ({part['m']}) at col {c} z {cz:.0f}")
        uniq = sorted(set(zone_problems))
        problems += len(uniq)
        print(f"{zone['id']:10s} {'OK' if not uniq else str(len(uniq)) + ' problems'}")
        for u in uniq[:12]:
            print("   ", u)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
