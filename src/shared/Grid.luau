--!strict
-- Converts between map tiles and world space. Zones sit side by side along X on the Z = 0 plane.

local Config = require(script.Parent.Config)
local Zones = require(script.Parent.Zones)

local Grid = {}

local T = Config.TILE

function Grid.size(zoneIndex: number): (number, number)
	local map = Zones[zoneIndex].map
	return #map[1], #map
end

function Grid.originX(zoneIndex: number): number
	return (zoneIndex - 1) * Config.ZONE_SPACING
end

-- World position of the centre of tile (col, row). Row 1 is the top of the map.
function Grid.tileCenter(zoneIndex: number, col: number, row: number): Vector3
	local _, h = Grid.size(zoneIndex)
	return Vector3.new(Grid.originX(zoneIndex) + (col - 0.5) * T, (h - row + 0.5) * T, 0)
end

function Grid.bounds(zoneIndex: number): (number, number, number, number)
	local w, h = Grid.size(zoneIndex)
	local ox = Grid.originX(zoneIndex)
	return ox, ox + w * T, 0, h * T
end

function Grid.zoneAt(position: Vector3): number?
	for i = 1, #Zones do
		local minX, maxX, minY, maxY = Grid.bounds(i)
		if position.X >= minX - 8 and position.X <= maxX + 8 and position.Y >= minY - 40 and position.Y <= maxY + 40 then
			return i
		end
	end
	return nil
end

-- Half-width of the cave corridor at a map column (studs, measured from z = 0).
local halfCache: { [number]: { number } } = {}
function Grid.halfWidth(zoneIndex: number, col: number): number
	local cache = halfCache[zoneIndex]
	if not cache then
		cache = {}
		local zone = Zones[zoneIndex]
		local w = #zone.map[1]
		local arena: { number }? = nil
		for _, spec in zone.specials do
			if spec.kind == "boss" and spec.arena then
				arena = spec.arena
			end
		end
		for c = 1, w do
			local wide = zone.wide or 1
			local base = (Config.CORRIDOR + Config.CORRIDOR_WANDER * math.noise(c * 0.07, zoneIndex * 3.1)) * wide
			if arena and c >= arena[1] - 2 and c <= arena[2] + 2 then
				-- Ease into the arena's wider chamber.
				local inside = math.min(c - (arena[1] - 2), (arena[2] + 2) - c)
				local t = math.clamp(inside / 4, 0, 1)
				base = base + (Config.ARENA_HALF - base) * t
			end
			cache[c] = math.floor(base / Config.TILE + 0.5) * Config.TILE
		end
		halfCache[zoneIndex] = cache
	end
	local w = #cache
	return cache[math.clamp(math.floor(col + 0.5), 1, w)]
end

-- Map column for a world X inside a zone.
function Grid.colAt(zoneIndex: number, x: number): number
	return (x - Grid.originX(zoneIndex)) / T + 0.5
end

function Grid.zoneIndexById(id: string): number?
	for i, zone in Zones do
		if zone.id == id then
			return i
		end
	end
	return nil
end

return Grid
