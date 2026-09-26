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

function Grid.zoneIndexById(id: string): number?
	for i, zone in Zones do
		if zone.id == id then
			return i
		end
	end
	return nil
end

return Grid
