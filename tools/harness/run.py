"""Runs the real world builder (src/server/World) headlessly under the Luau interpreter
with a mocked Roblox API (tools/harness/mock.luau), and exports what it built.

    python tools/harness/run.py                # build, write out/scene.json, print a summary
    python tools/harness/run.py --luau PATH    # use a specific luau binary

The export lists every part (class, size, CFrame, colour, material, transparency,
collision), every light and particle emitter, and every terrain fill, grouped by zone.
tools/harness/render.py turns it into screenshots.
"""

import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

# Rojo mapping (mirrors default.project.json).
MOUNTS = {
    "src/shared": "ReplicatedStorage/Shared",
    "src/server": "ServerScriptService/Server",
}


def luau_bin():
    if "--luau" in sys.argv:
        return sys.argv[sys.argv.index("--luau") + 1]
    for cand in [os.environ.get("LUAU"), "/tmp/claude-0/tools/luau", "luau"]:
        if cand and (os.path.exists(cand) or cand == "luau"):
            return cand
    return "luau"


def long_string(s):
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    return "[" + "=" * level + "[" + s + "]" + "=" * level + "]"


def collect_sources():
    sources = {}
    for src_dir, inst_path in MOUNTS.items():
        base = os.path.join(ROOT, src_dir)
        for dirpath, _, files in os.walk(base):
            for f in files:
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, base).replace(os.sep, "/")
                if f.endswith(".luau") and not f.endswith(".client.luau") and not f.endswith(".server.luau"):
                    name = rel[: -len(".luau")]
                    if name.endswith("/init"):
                        name = name[: -len("/init")]
                    sources[inst_path + "/" + name] = open(full).read()
                elif f.endswith(".json"):
                    # Rojo turns JSON files into modules returning the decoded table.
                    data = json.load(open(full))
                    sources[inst_path + "/" + rel[: -len(".json")]] = "return " + to_luau(data)
    return sources


def to_luau(v):
    if isinstance(v, dict):
        return "{" + ",".join(f"[{json.dumps(k)}]={to_luau(x)}" for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ",".join(to_luau(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, str):
        return json.dumps(v)
    return repr(v)


EXPORT = r'''
local Vector3, Color3, CFrame, typeof = M.Vector3, M.Color3, M.CFrame, M.typeof
local function num(x) return string.format("%.3f", x) end
local function vec(v) return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]" end
local function col(c) return "[" .. num(c.R) .. "," .. num(c.G) .. "," .. num(c.B) .. "]" end
local function cfr(c)
	local t = {}
	for i = 1, 12 do t[i] = num(c[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local function zoneOf(inst)
	local p = inst
	while p do
		local idx = p:GetAttribute("Index")
		if idx then return idx end
		p = rawget(p, "_props").Parent
	end
	return 0
end
local function emit(s) print("@@" .. s) end

local ws = M.workspace
for _, d in ws:GetDescendants() do
	local cls = rawget(d, "_class")
	if d:IsA("BasePart") and cls ~= "Terrain" then
		local mesh = d:FindFirstChildOfClass("SpecialMesh")
		local meshType = if mesh and rawget(mesh, "_props").MeshType then rawget(mesh, "_props").MeshType.Name else ""
		local meshScale = if mesh and rawget(mesh, "_props").Scale then vec(rawget(mesh, "_props").Scale) else "null"
		local props = rawget(d, "_props")
		local shape = if props.Shape then props.Shape.Name else "Block"
		local mat = if props.Material then props.Material.Name else "Plastic"
		local npc = d:GetAttribute("NpcId")
		emit(string.format('{"k":"part","c":"%s","n":%q,"npc":%q,"z":%d,"s":%s,"cf":%s,"col":%s,"m":"%s","t":%s,"cc":%s,"sh":"%s","mesh":"%s","ms":%s}',
			cls, props.Name, if props.Name == "NPCAnchor" and npc then npc else "", zoneOf(d), vec(props.Size or Vector3.new(4,1,2)), cfr(props.CFrame or CFrame.identity),
			col(props.Color or Color3.fromRGB(163,162,165)), mat, num(props.Transparency or 0),
			tostring(props.CanCollide ~= false), shape, meshType, meshScale))
	elseif d:IsA("Light") then
		local parent = rawget(d, "_props").Parent
		if parent and parent:IsA("BasePart") then
			local props = rawget(d, "_props")
			emit(string.format('{"k":"light","c":"%s","z":%d,"p":%s,"col":%s,"r":%s,"b":%s,"sh":%s,"on":%s}',
				cls, zoneOf(d), vec(parent.Position), col(props.Color or Color3.new(1,1,1)), num(props.Range or 8),
				num(props.Brightness or 1), tostring(props.Shadows == true), tostring(props.Enabled ~= false)))
		end
	elseif cls == "ParticleEmitter" then
		local parent = rawget(d, "_props").Parent
		local props = rawget(d, "_props")
		if parent and parent:IsA("BasePart") then
			local c = Color3.new(1, 1, 1)
			if props.Color and props.Color.args and typeof(props.Color.args[1]) == "Color3" then c = props.Color.args[1] end
			emit(string.format('{"k":"pe","z":%d,"p":%s,"s":%s,"col":%s,"rate":%s}',
				zoneOf(d), vec(parent.Position), vec(parent.Size), col(c), num(props.Rate or 5)))
		end
	end
end
for _, op in M.terrainOps do
	local kind = op[1]
	if kind == "block" or kind == "wedge" then
		emit(string.format('{"k":"t","f":"%s","cf":%s,"s":%s,"m":"%s"}', kind, cfr(op[2]), vec(op[3]), op[4]))
	elseif kind == "ball" then
		emit(string.format('{"k":"t","f":"ball","p":%s,"r":%s,"m":"%s"}', vec(op[2]), num(op[3]), op[4]))
	elseif kind == "cylinder" then
		emit(string.format('{"k":"t","f":"cylinder","cf":%s,"h":%s,"r":%s,"m":"%s"}', cfr(op[2]), num(op[3]), num(op[4]), op[5]))
	end
end
for name, c in M.materialColors do
	emit(string.format('{"k":"mc","m":"%s","col":%s}', name, col(c)))
end
local world = ws:FindFirstChild("World")
if world then
	local sp = world:GetAttribute("StartPosition")
	if sp then emit('{"k":"start","p":' .. vec(sp) .. '}') end
	for _, zone in world:GetChildren() do
		local idx = zone:GetAttribute("Index")
		if idx then
			local mn, mx = zone:GetAttribute("Min"), zone:GetAttribute("Max")
			emit(string.format('{"k":"zone","i":%d,"n":%q,"min":[%s,%s],"max":[%s,%s]}', idx, rawget(zone, "_props").Name, num(mn.X), num(mn.Y), num(mx.X), num(mx.Y)))
		end
	end
end
'''


def build_bundle(entry):
    sources = collect_sources()
    mock = open(os.path.join(HERE, "mock.luau")).read()
    lines = ["local M = (function()", mock, "end)()", "local SOURCES = {"]
    for path, src in sorted(sources.items()):
        lines.append(f"[{json.dumps(path)}] = {long_string(src)},")
    lines.append("}")
    lines.append("local game = M.createGame()")
    lines.append("M.mountSources(game, SOURCES)")
    lines.append("local env, requireModule = M.makeEnv()")
    lines.append(entry)
    lines.append(EXPORT)
    return "\n".join(lines)


BUILD_ENTRY = r'''
local builderModule = game:GetService("ServerScriptService").Server.World.Builder
local ok, err = pcall(function()
	local Builder = requireModule(builderModule)
	requireModule(game:GetService("ServerScriptService").Server.World.CaveArt).debug = true
	local infos = Builder.build()
	local function v(p) return string.format("[%.3f,%.3f,%.3f]", p.X, p.Y, p.Z) end
	for _, info in infos do
		print(string.format("zone %d %s: %d enemies, boss=%s", info.index, info.id, #info.enemies, tostring(info.boss and info.boss.id)))
		for _, e in info.enemies do
			print(string.format('@@{"k":"enemy","z":%d,"kind":"%s","p":%s}', info.index, e.kind, v(e.position)))
		end
		if info.boss then
			print(string.format('@@{"k":"boss","z":%d,"id":"%s","p":%s,"floor":%.3f}', info.index, info.boss.id, v(info.boss.position), info.boss.floorY))
		end
	end
	local Zones = requireModule(game:GetService("ReplicatedStorage").Shared.Zones)
	local Themes = requireModule(game:GetService("ReplicatedStorage").Shared.Themes)
	local function c(col) return string.format("[%.3f,%.3f,%.3f]", col.R, col.G, col.B) end
	for i, zone in Zones do
		local t = Themes[zone.theme]
		print(string.format('@@{"k":"theme","z":%d,"id":"%s","name":%q,"fog":%s,"fogEnd":%.1f,"ambient":%s,"outdoor":%s,"tint":%s,"accent":%s}',
			i, zone.id, zone.name, c(t.fog), t.fogEnd, c(t.ambient), c(t.outdoor), c(t.tint), c(t.accent)))
	end
end)
if not ok then
	print("BUILD ERROR: " .. tostring(err))
	print(debug.traceback())
end
'''


def main():
    os.makedirs(OUT, exist_ok=True)
    bundle = build_bundle(BUILD_ENTRY)
    bundle_path = os.path.join(OUT, "bundle.luau")
    with open(bundle_path, "w") as f:
        f.write(bundle)
    proc = subprocess.run([luau_bin(), bundle_path], capture_output=True, text=True)
    records = []
    errors = False
    for line in proc.stdout.splitlines():
        if line.startswith("@@"):
            records.append(json.loads(line[2:]))
        else:
            print(line)
            if "ERROR" in line:
                errors = True
    if proc.stderr.strip():
        print(proc.stderr)
        errors = True
    with open(os.path.join(OUT, "scene.json"), "w") as f:
        json.dump(records, f)
    counts = {}
    for r in records:
        key = r["k"]
        counts[key] = counts.get(key, 0) + 1
    per_zone = {}
    for r in records:
        if r["k"] == "part":
            per_zone[r["z"]] = per_zone.get(r["z"], 0) + 1
    print("exported:", counts)
    print("parts per zone:", dict(sorted(per_zone.items())))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
