-- Builds every zone as a 3D cave. The ASCII map (see Shared/Zones) is the side profile of
-- the level; it is extruded along Z into a winding corridor whose walls, floors and ceilings
-- are carved from Roblox Terrain. Hazards, gates, doors and interactables are parts that
-- span the corridor, and props line the walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Themes = require(Shared.Themes)
local Grid = require(Shared.Grid)
local Charms = require(Shared.Charms)
local Dialogue = require(Shared.Dialogue)
local Props = require(script.Parent.Props)
local CaveArt = require(script.Parent.CaveArt)

local T = Config.TILE
local WALL = Config.WALL_THICKNESS

local Builder = {}

export type EnemySpawn = { kind: string, position: Vector3, zone: number }
export type BossInfo = {
	id: string,
	zone: number,
	position: Vector3,
	minX: number,
	maxX: number,
	zHalf: number,
	floorY: number,
	ceilY: number,
	gates: { BasePart },
}
export type ZoneInfo = {
	index: number,
	id: string,
	folder: Folder,
	enemies: { EnemySpawn },
	boss: BossInfo?,
	benches: { [string]: CFrame },
}

local make = Props.make
local terrain = workspace.Terrain

local function isSolid(ch: string): boolean
	return ch == "#" or ch == "%"
end

-- Greedy rectangle merge so long walls become a handful of fills / parts.
local function mergeRects(chars: { { string } }, w: number, h: number, match: (string) -> boolean)
	local used = {}
	for r = 1, h do
		used[r] = {}
	end
	local rects = {}
	for r = 1, h do
		for c = 1, w do
			if not used[r][c] and match(chars[r][c]) then
				local c2 = c
				while c2 + 1 <= w and not used[r][c2 + 1] and match(chars[r][c2 + 1]) do
					c2 += 1
				end
				local r2 = r
				while r2 + 1 <= h do
					local ok = true
					for cc = c, c2 do
						if used[r2 + 1][cc] or not match(chars[r2 + 1][cc]) then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					r2 += 1
				end
				for rr = r, r2 do
					for cc = c, c2 do
						used[rr][cc] = true
					end
				end
				table.insert(rects, { c, r, c2, r2 })
			end
		end
	end
	return rects
end

local function maxHalf(zoneIndex: number, c1: number, c2: number): number
	local m = 0
	for c = c1, c2 do
		m = math.max(m, Grid.halfWidth(zoneIndex, c))
	end
	return m
end

-- Center and size of a rectangle of tiles; `zHalf` sets how far it extends along Z.
local function rectToWorld(zoneIndex: number, rect, zHalf: number): (Vector3, Vector3)
	local _, h = Grid.size(zoneIndex)
	local ox = Grid.originX(zoneIndex)
	local c1, r1, c2, r2 = rect[1], rect[2], rect[3], rect[4]
	local left, right = ox + (c1 - 1) * T, ox + c2 * T
	local top, bottom = (h - r1 + 1) * T, (h - r2) * T
	return Vector3.new((left + right) / 2, (top + bottom) / 2, 0), Vector3.new(right - left, top - bottom, zHalf * 2)
end

local function buildTerrain(zoneIndex: number, chars, w: number, h: number, theme, folder: Folder)
	local ox = Grid.originX(zoneIndex)
	local height = h * T
	-- Winding side walls, one slab per column.
	for c = 1, w do
		local hz = Grid.halfWidth(zoneIndex, c)
		local x = ox + (c - 0.5) * T
		for _, side in { -1, 1 } do
			terrain:FillBlock(CFrame.new(x, height / 2, side * (hz + WALL / 2)), Vector3.new(T, height + 8, WALL), theme.wall)
		end
	end
	-- Solid tiles, extruded across the corridor and into the walls.
	for _, rect in mergeRects(chars, w, h, function(ch)
		return ch == "#"
	end) do
		local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + WALL)
		terrain:FillBlock(CFrame.new(center), size, theme.wall)
	end
	-- Walkable tops get the zone's surface material.
	for r = 2, h do
		local c = 1
		while c <= w do
			if chars[r][c] == "#" and not isSolid(chars[r - 1][c]) then
				local c2 = c
				while c2 + 1 <= w and chars[r][c2 + 1] == "#" and not isSolid(chars[r - 1][c2 + 1]) do
					c2 += 1
				end
				local center, size = rectToWorld(zoneIndex, { c, r, c2, r }, maxHalf(zoneIndex, c, c2))
				terrain:FillBlock(CFrame.new(center), size, theme.top)
				c = c2 + 1
			else
				c += 1
			end
		end
	end
	-- Smooth (unclimbable) stone stays as polished parts.
	local mapFolder = make("Folder", { Name = "Map", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(ch)
		return ch == "%"
	end) do
		local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + 2)
		local p = make("Part", {
			Name = "SmoothStone",
			Anchored = true,
			Size = size,
			Position = center,
			Color = theme.smooth,
			Material = Enum.Material.Marble,
			Reflectance = 0.08,
			Parent = mapFolder,
		})
		p:SetAttribute("NoCling", true)
	end
end

local function buildHazards(zoneIndex: number, chars, w: number, h: number, theme, folder: Folder)
	local hazards = make("Folder", { Name = "Hazards", Parent = folder })
	local rng = Random.new(zoneIndex * 1597)
	for _, ch in { "^", "~" } do
		for _, rect in mergeRects(chars, w, h, function(c)
			return c == ch
		end) do
			local hz = maxHalf(zoneIndex, rect[1], rect[3])
			local center, size = rectToWorld(zoneIndex, rect, hz + 1)
			local bottom = center.Y - size.Y / 2
			make("Part", {
				Name = "ThornHitbox",
				Anchored = true,
				CanCollide = false,
				Transparency = 1,
				Size = Vector3.new(size.X - 0.4, T * (if ch == "~" then 0.7 else 0.55), size.Z),
				Position = Vector3.new(center.X, bottom + T * (if ch == "~" then 0.35 else 0.3), 0),
				Parent = hazards,
			})
			if ch == "~" then
				Props.ink(center, size, theme, hazards)
			else
				-- A bramble of pale thorns across the whole corridor.
				local x = center.X - size.X / 2 + 1
				while x < center.X + size.X / 2 do
					local z = -hz
					while z < hz do
						Props.thorn3D(Vector3.new(x + rng:NextNumber(-0.8, 0.8), bottom, z + rng:NextNumber(-1, 1)), rng, hazards)
						z += 2.6
					end
					x += 2.2
				end
			end
		end
	end
end

local function buildBlockers(zoneIndex: number, zoneId: string, chars, w: number, h: number, theme, folder: Folder)
	local breakables = make("Folder", { Name = "Breakables", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "X"
	end) do
		local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + 3)
		local wall = make("Part", {
			Name = "CrackedWall",
			Anchored = true,
			Size = size,
			Position = center,
			Color = theme.wallColor:Lerp(theme.rim, 0.15),
			Material = Enum.Material.Slate,
			Parent = breakables,
		})
		wall:SetAttribute("HP", 3)
		local rng = Random.new(math.floor(center.X))
		for i = 1, 5 do
			make("Part", {
				Name = "Crack",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				Size = Vector3.new(0.3, size.Y * 0.6, 0.3),
				CFrame = CFrame.new(center + Vector3.new(size.X / 2 * (if i % 2 == 0 then 1 else -1), rng:NextNumber(-1, 1), rng:NextNumber(-size.Z / 3, size.Z / 3))) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-30, 30))),
				Color = Color3.fromRGB(10, 10, 14),
				Material = Enum.Material.SmoothPlastic,
				Parent = wall,
			})
		end
	end
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "Y"
	end) do
		local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + 3)
		Props.crystalSeal(center, size, breakables)
	end
	local gates = make("Folder", { Name = "ShortcutGates", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "="
	end) do
		local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + 2)
		Props.shortcutGate(center, size, zoneId, theme, gates)
	end
	local switches = make("Folder", { Name = "Switches", Parent = folder })
	for r = 1, h do
		for c = 1, w do
			local ch = chars[r][c]
			if ch == "!" or ch == "?" then
				Props.switch(Grid.tileCenter(zoneIndex, c, r), if ch == "!" then "lever" else "sigil", zoneId, theme, switches)
			end
		end
	end
end

local function buildDoors(zoneIndex: number, chars, w: number, h: number, theme, doorsFolder: Folder)
	for d = 1, 9 do
		local digit = tostring(d)
		for _, rect in mergeRects(chars, w, h, function(c)
			return c == digit
		end) do
			local hz = maxHalf(zoneIndex, rect[1], rect[3])
			local center, size = rectToWorld(zoneIndex, rect, hz)
			local inward = if rect[1] <= w / 2 then 1 else -1
			local arrival = Grid.tileCenter(zoneIndex, rect[1] + inward * 3, rect[4]) + Vector3.new(0, 1, 0)
			local door = make("Part", {
				Name = "Door" .. digit,
				Anchored = true,
				CanCollide = false,
				Transparency = 1,
				Size = size,
				Position = center,
				Parent = doorsFolder,
			})
			door:SetAttribute("Door", digit)
			door:SetAttribute("Zone", zoneIndex)
			door:SetAttribute("Arrival", arrival)
			door:SetAttribute("Inward", inward)
			Props.doorway(center, size, inward, theme, doorsFolder)
		end
	end
end

local function scanVertical(zoneIndex: number, chars, col: number, row: number, dir: number): number
	local _, h = Grid.size(zoneIndex)
	local r = row
	while r >= 1 and r <= h and not isSolid(chars[r][col]) do
		r += dir
	end
	local edge = Grid.tileCenter(zoneIndex, col, math.clamp(r, 1, h))
	return edge.Y + dir * T / 2
end

function Builder.build(): { ZoneInfo }
	local world = make("Folder", { Name = "World", Parent = workspace })
	-- Animated grass blades on grassy terrain.
	terrain.Decoration = true
	local doorsFolder = make("Folder", { Name = "Doors", Parent = world })
	local infos: { ZoneInfo } = {}

	for zoneIndex, zone in Zones do
		local theme = Themes[zone.theme]
		terrain:SetMaterialColor(theme.wall, theme.wallColor)
		terrain:SetMaterialColor(theme.top, theme.topColor)
		local w, h = Grid.size(zoneIndex)
		local chars = {}
		for r, line in zone.map do
			chars[r] = string.split(line, "")
		end

		local folder = make("Folder", { Name = "Zone_" .. zone.id, Parent = world })
		local minX, maxX, minY, maxY = Grid.bounds(zoneIndex)
		folder:SetAttribute("Index", zoneIndex)
		folder:SetAttribute("Min", Vector2.new(minX, minY))
		folder:SetAttribute("Max", Vector2.new(maxX, maxY))

		buildTerrain(zoneIndex, chars, w, h, theme, folder)
		buildHazards(zoneIndex, chars, w, h, theme, folder)
		buildBlockers(zoneIndex, zone.id, chars, w, h, theme, folder)
		buildDoors(zoneIndex, chars, w, h, theme, doorsFolder)

		local info: ZoneInfo = { index = zoneIndex, id = zone.id, folder = folder, enemies = {}, boss = nil, benches = {} }
		local interact = make("Folder", { Name = "Interact", Parent = folder })
		local items = make("Folder", { Name = "Items", Parent = folder })
		local rng = Random.new(zoneIndex * 733)

		local gates = {}
		for _, rect in mergeRects(chars, w, h, function(c)
			return c == "G"
		end) do
			local center, size = rectToWorld(zoneIndex, rect, maxHalf(zoneIndex, rect[1], rect[3]) + 2)
			table.insert(gates, Props.gate(center, size, theme, folder))
		end

		for r = 1, h do
			for c = 1, w do
				local ch = chars[r][c]
				local pos = Grid.tileCenter(zoneIndex, c, r)
				local floorPos = pos - Vector3.new(0, T / 2, 0)
				local hz = Grid.halfWidth(zoneIndex, c)
				-- NPCs and benches stand toward the back wall, facing into the corridor.
				local backZ = -math.min(hz - 5, 8)
				if ch == "o" then
					local anchors = folder:FindFirstChild("SwingAnchors") or make("Folder", { Name = "SwingAnchors", Parent = folder })
					Props.swingAnchor(pos, scanVertical(zoneIndex, chars, c, r, -1), theme, anchors)
				elseif ch == "S" then
					world:SetAttribute("StartPosition", floorPos + Vector3.new(0, 3, 0))
					world:SetAttribute("StartBench", zone.id .. ":start")
					info.benches[zone.id .. ":start"] = CFrame.new(floorPos + Vector3.new(0, 3, 0))
				elseif ch == "B" then
					local id = string.format("%s:%d,%d", zone.id, c, r)
					Props.bench(id, floorPos + Vector3.new(0, 0, backZ), theme, interact)
					info.benches[id] = CFrame.new(floorPos + Vector3.new(0, 3, backZ + 4))
				elseif string.find("cfsgmhw", ch, 1, true) then
					local z = rng:NextNumber(-hz * 0.4, hz * 0.4)
					table.insert(info.enemies, { kind = ch, position = pos + Vector3.new(0, 0, z), zone = zoneIndex })
				elseif string.match(ch, "%a") and zone.specials[ch] then
					local spec = zone.specials[ch]
					local itemId = string.format("%s:%s:%d,%d", zone.id, ch, c, r)
					if spec.kind == "npc" then
						local speaker = Dialogue[spec.id :: string]
						if spec.tablet then
							Props.npc(spec.id :: string, speaker.name, true, floorPos + Vector3.new(0, 0, backZ), theme, interact)
						else
							Props.npcAnchor(spec.id :: string, speaker.name, floorPos + Vector3.new(0, 0, backZ + 1), interact)
						end
					elseif spec.kind == "charm" then
						local charm = Charms[spec.id :: string]
						Props.pickup(itemId, "charm", spec.id :: string, pos, charm.color, items)
					elseif spec.kind == "heart" then
						Props.pickup(itemId, "heart", "heart", pos, Color3.fromRGB(255, 255, 255), items)
					elseif spec.kind == "geo" then
						local p = Props.pickup(itemId, "geo", "geo", pos, Color3.fromRGB(120, 220, 255), items)
						p:SetAttribute("Amount", spec.amount)
					elseif spec.kind == "memory" then
						Props.pickup(itemId, "memory", spec.id :: string, pos, Color3.fromRGB(255, 244, 214), items)
					elseif spec.kind == "altar" then
						Props.altar(floorPos, interact)
					elseif spec.kind == "boss" then
						local arena = spec.arena :: { number }
						local ox = Grid.originX(zoneIndex)
						info.boss = {
							id = spec.id :: string,
							zone = zoneIndex,
							position = pos,
							minX = ox + (arena[1] - 1) * T,
							maxX = ox + arena[2] * T,
							zHalf = Config.ARENA_HALF - 3,
							floorY = scanVertical(zoneIndex, chars, c, r, 1),
							ceilY = scanVertical(zoneIndex, chars, c, r, -1),
							gates = gates,
						}
					end
				end
			end
		end

		-- Set dressing: rocks, ledges, props, lights, arches, bridges, signs and vistas.
		CaveArt.dress(zoneIndex, chars, w, h, theme, folder)

		Props.ambience(zoneIndex, theme, folder)
		Props.lightShafts(zoneIndex, chars, theme, folder)
		infos[zoneIndex] = info
	end

	return infos
end

return Builder
