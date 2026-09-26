-- Builds every zone from its ASCII map: collision tiles, painted-looking decor,
-- parallax backgrounds, mist, lights, and all interactive objects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Themes = require(Shared.Themes)
local Grid = require(Shared.Grid)
local Charms = require(Shared.Charms)
local Dialogue = require(Shared.Dialogue)
local Props = require(script.Parent.Props)

local T = Config.TILE
local DEPTH = Config.DEPTH

local Builder = {}

export type EnemySpawn = { kind: string, position: Vector3, zone: number }
export type BossInfo = {
	id: string,
	zone: number,
	position: Vector3,
	minX: number,
	maxX: number,
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

local function isSolid(ch: string): boolean
	return ch == "#" or ch == "%"
end

-- Greedy rectangle merge so long walls become a handful of parts.
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

local function rectToWorld(zoneIndex: number, rect, zOffset: number?): (Vector3, Vector3)
	local _, h = Grid.size(zoneIndex)
	local ox = Grid.originX(zoneIndex)
	local c1, r1, c2, r2 = rect[1], rect[2], rect[3], rect[4]
	local left, right = ox + (c1 - 1) * T, ox + c2 * T
	local top, bottom = (h - r1 + 1) * T, (h - r2) * T
	local size = Vector3.new(right - left, top - bottom, DEPTH)
	local center = Vector3.new((left + right) / 2, (top + bottom) / 2, zOffset or 0)
	return center, size
end

local function buildTiles(zoneIndex: number, chars, w: number, h: number, theme, folder: Folder)
	local mapFolder = make("Folder", { Name = "Map", Parent = folder })
	for _, spec in { { "#", theme.rock, false }, { "%", theme.smooth, true } } do
		local ch, color, slick = spec[1], spec[2], spec[3]
		for _, rect in mergeRects(chars, w, h, function(c)
			return c == ch
		end) do
			local center, size = rectToWorld(zoneIndex, rect)
			local tile = make("Part", {
				Name = if slick then "SmoothStone" else "Stone",
				Anchored = true,
				Size = size,
				Position = center,
				Color = color,
				Material = if slick then Enum.Material.SmoothPlastic else theme.material,
				TopSurface = Enum.SurfaceType.Smooth,
				BottomSurface = Enum.SurfaceType.Smooth,
				Parent = mapFolder,
			})
			if slick then
				tile:SetAttribute("NoCling", true)
				tile.Reflectance = 0.08
			end
			Props.midground(center, size, theme, zoneIndex * 1000 + rect[1] * 37 + rect[2], folder)
			-- Ink outline: a slightly larger near-black slab tucked behind the tile.
			make("Part", {
				Name = "Outline",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Size = size + Vector3.new(1.1, 1.1, -0.6),
				Position = center + Vector3.new(0, 0, -0.5),
				Color = Color3.fromRGB(8, 8, 12),
				Material = Enum.Material.SmoothPlastic,
				Parent = mapFolder,
			})
		end
	end

	-- Accent rims along every walkable top edge, and hanging growth under ceilings.
	local rng = Random.new(zoneIndex * 7919)
	local decor = make("Folder", { Name = "Edges", Parent = folder })
	for r = 2, h do
		local c = 1
		while c <= w do
			if isSolid(chars[r][c]) and not isSolid(chars[r - 1][c]) then
				local c2 = c
				while c2 + 1 <= w and isSolid(chars[r][c2 + 1]) and not isSolid(chars[r - 1][c2 + 1]) do
					c2 += 1
				end
				local a = Grid.tileCenter(zoneIndex, c, r)
				local b = Grid.tileCenter(zoneIndex, c2, r)
				local topY = a.Y + T / 2
				make("Part", {
					Name = "Rim",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Size = Vector3.new(b.X - a.X + T + 0.3, 0.8, DEPTH + 0.8),
					Position = Vector3.new((a.X + b.X) / 2, topY - 0.25, 0),
					Color = theme.rim,
					Material = Enum.Material.SmoothPlastic,
					Parent = decor,
				})
				for cc = c, c2 do
					if rng:NextNumber() < 0.35 then
						Props.edgeTuft(theme, Grid.tileCenter(zoneIndex, cc, r) + Vector3.new(rng:NextNumber(-1.5, 1.5), T / 2, rng:NextNumber(4, 6.5)), rng, decor)
					end
					if rng:NextNumber() < 0.18 then
						-- Lumpy stones along the front lip break up the tile grid.
						Props.edgeLump(theme, Grid.tileCenter(zoneIndex, cc, r) + Vector3.new(rng:NextNumber(-1.5, 1.5), T / 2 - 0.6, DEPTH / 2), rng, decor)
					end
				end
				c = c2 + 1
			else
				c += 1
			end
		end
	end
	for r = 1, h - 1 do
		for c = 1, w do
			if isSolid(chars[r][c]) and chars[r + 1][c] == "." and rng:NextNumber() < 0.22 then
				local p = Grid.tileCenter(zoneIndex, c, r) - Vector3.new(0, T / 2, 0)
				Props.hanging(theme, p + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-4, 5)), rng, decor)
			end
		end
	end
end

local function buildSpikes(zoneIndex: number, chars, w: number, h: number, theme, folder: Folder)
	local hazards = make("Folder", { Name = "Hazards", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "~"
	end) do
		local center, size = rectToWorld(zoneIndex, rect)
		make("Part", {
			Name = "ThornHitbox",
			Anchored = true,
			CanCollide = false,
			Transparency = 1,
			Size = Vector3.new(size.X - 0.4, T * 0.7, DEPTH),
			Position = center + Vector3.new(0, -T * 0.1, 0),
			Parent = hazards,
		})
		Props.ink(center, size, theme, hazards)
	end
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "^"
	end) do
		local center, size = rectToWorld(zoneIndex, rect)
		local bottom = center.Y - size.Y / 2
		make("Part", {
			Name = "ThornHitbox",
			Anchored = true,
			CanCollide = false,
			Transparency = 1,
			Size = Vector3.new(size.X - 0.4, T * 0.55, DEPTH),
			Position = Vector3.new(center.X, bottom + T * 0.3, 0),
			Parent = hazards,
		})
		local tiles = rect[3] - rect[1] + 1
		for i = 0, tiles * 2 - 1 do
			local x = center.X - size.X / 2 + (i + 0.5) * (T / 2)
			Props.thorn(Vector3.new(x, bottom, 0), T * 0.85, hazards)
		end
	end
end

local function buildBreakables(zoneIndex: number, chars, w: number, h: number, theme, folder: Folder)
	local breakables = make("Folder", { Name = "Breakables", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "X"
	end) do
		local center, size = rectToWorld(zoneIndex, rect)
		local wall = make("Part", {
			Name = "CrackedWall",
			Anchored = true,
			Size = size,
			Position = center,
			Color = theme.rock:Lerp(theme.rim, 0.12),
			Material = theme.material,
			Parent = breakables,
		})
		wall:SetAttribute("HP", 3)
		-- Hairline cracks: a subtle tell for observant players.
		for i = 1, 3 do
			make("Part", {
				Name = "Crack",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				Size = Vector3.new(0.25, size.Y * 0.6, 0.2),
				CFrame = CFrame.new(center + Vector3.new((i - 2) * size.X * 0.25, 0, DEPTH / 2 + 0.05)) * CFrame.Angles(0, 0, math.rad(20 * (i - 2) + 8)),
				Color = Color3.fromRGB(10, 10, 14),
				Material = Enum.Material.SmoothPlastic,
				Parent = wall,
			})
		end
	end
end

local function buildSeals(zoneIndex: number, chars, w: number, h: number, folder: Folder)
	local breakables = folder:FindFirstChild("Breakables") :: Folder
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "Y"
	end) do
		local center, size = rectToWorld(zoneIndex, rect)
		Props.crystalSeal(center, size, breakables)
	end
end

-- Shortcut gates ("=") and the levers / Lumen sigils that open them. Opening is per player,
-- so the client hides gates it has unlocked (its own character is simulated locally).
local function buildSwitches(zoneIndex: number, zoneId: string, chars, w: number, h: number, theme, folder: Folder)
	local gates = make("Folder", { Name = "ShortcutGates", Parent = folder })
	for _, rect in mergeRects(chars, w, h, function(c)
		return c == "="
	end) do
		local center, size = rectToWorld(zoneIndex, rect)
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

local function verticalRuns(zoneIndex: number, chars, w: number, h: number, ch: string)
	return mergeRects(chars, w, h, function(c)
		return c == ch
	end)
end

local function buildDoors(zoneIndex: number, chars, w: number, h: number, doorsFolder: Folder)
	for d = 1, 9 do
		local digit = tostring(d)
		for _, rect in verticalRuns(zoneIndex, chars, w, h, digit) do
			local center, size = rectToWorld(zoneIndex, rect)
			local inward = if rect[1] <= w / 2 then 1 else -1
			local bottomRow = rect[4]
			local arrival = Grid.tileCenter(zoneIndex, rect[1] + inward * 3, bottomRow) + Vector3.new(0, 1, 0)
			local door = make("Part", {
				Name = "Door" .. digit,
				Anchored = true,
				CanCollide = false,
				Transparency = 1,
				Size = Vector3.new(size.X, size.Y, DEPTH),
				Position = center,
				Parent = doorsFolder,
			})
			door:SetAttribute("Door", digit)
			door:SetAttribute("Zone", zoneIndex)
			door:SetAttribute("Arrival", arrival)
			-- Soft light spilling in from the next area.
			local glow = make("Part", {
				Name = "DoorGlow",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				Transparency = 0.85,
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(200, 210, 255),
				Size = Vector3.new(0.4, size.Y, DEPTH),
				Position = center + Vector3.new(inward * (T / 2 - 0.2), 0, 0),
				Parent = doorsFolder,
			})
			make("PointLight", { Range = 16, Brightness = 0.8, Color = Color3.fromRGB(200, 210, 255), Parent = glow })
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
	local doorsFolder = make("Folder", { Name = "Doors", Parent = world })
	local infos: { ZoneInfo } = {}

	for zoneIndex, zone in Zones do
		local theme = Themes[zone.theme]
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

		buildTiles(zoneIndex, chars, w, h, theme, folder)
		buildSpikes(zoneIndex, chars, w, h, theme, folder)
		buildBreakables(zoneIndex, chars, w, h, theme, folder)
		buildSeals(zoneIndex, chars, w, h, folder)
		buildSwitches(zoneIndex, zone.id, chars, w, h, theme, folder)
		buildDoors(zoneIndex, chars, w, h, doorsFolder)
		Props.backdrop(zoneIndex, theme, folder)
		Props.foreground(zoneIndex, theme, folder)
		Props.lightShafts(zoneIndex, chars, theme, folder)

		local info: ZoneInfo = { index = zoneIndex, id = zone.id, folder = folder, enemies = {}, boss = nil, benches = {} }
		local interact = make("Folder", { Name = "Interact", Parent = folder })
		local items = make("Folder", { Name = "Items", Parent = folder })

		local floorSpots = {}
		local gates = {}
		for _, rect in verticalRuns(zoneIndex, chars, w, h, "G") do
			local center, size = rectToWorld(zoneIndex, rect)
			table.insert(gates, Props.gate(center, size, theme, folder))
		end

		for r = 1, h do
			for c = 1, w do
				local ch = chars[r][c]
				local pos = Grid.tileCenter(zoneIndex, c, r)
				local floorPos = pos - Vector3.new(0, T / 2, 0)
				if ch == "." and r < h and isSolid(chars[r + 1][c]) and r > 1 and chars[r - 1][c] == "." then
					table.insert(floorSpots, floorPos)
				end
				if ch == "S" then
					world:SetAttribute("StartPosition", floorPos + Vector3.new(0, 3, 0))
					world:SetAttribute("StartBench", zone.id .. ":start")
					info.benches[zone.id .. ":start"] = CFrame.new(floorPos + Vector3.new(0, 3, 0))
				elseif ch == "B" then
					local id = string.format("%s:%d,%d", zone.id, c, r)
					Props.bench(id, floorPos, theme, interact)
					info.benches[id] = CFrame.new(floorPos + Vector3.new(0, 3, 0))
				elseif string.find("cfsgmhw", ch, 1, true) then
					table.insert(info.enemies, { kind = ch, position = pos, zone = zoneIndex })
				elseif string.match(ch, "%a") and zone.specials[ch] then
					local spec = zone.specials[ch]
					local itemId = string.format("%s:%s:%d,%d", zone.id, ch, c, r)
					if spec.kind == "npc" then
						local speaker = Dialogue[spec.id :: string]
						Props.npc(spec.id :: string, speaker.name, spec.tablet == true, floorPos, theme, interact)
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
							floorY = scanVertical(zoneIndex, chars, c, r, 1),
							ceilY = scanVertical(zoneIndex, chars, c, r, -1),
							gates = gates,
						}
					end
				end
			end
		end
		Props.ambience(zoneIndex, theme, floorSpots, folder)
		infos[zoneIndex] = info
	end

	return infos
end

return Builder
