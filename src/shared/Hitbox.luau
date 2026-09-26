--!strict
-- The nail's reach as an oriented box, shared so the client (effects, pogo) and server
-- (damage) agree. `rootCFrame` is the character's HumanoidRootPart CFrame.

local Hitbox = {}

local function flatLook(cf: CFrame): Vector3
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
end

-- Returns the box's CFrame and size for a strike direction:
-- "side" (in front), "up", "down" (beneath, for pogo), "cleave" (the Great Slash: wide and
-- long), "dashslash" (a long strip along the lunge) or "cyclone" (all around the body).
function Hitbox.nail(rootCFrame: CFrame, direction: string, reach: number): (CFrame, Vector3)
	local pos = rootCFrame.Position
	local look = flatLook(rootCFrame)
	local center: Vector3
	local size: Vector3
	if direction == "cleave" then
		center = pos + look * (3 + 3.2 * reach) + Vector3.new(0, 0.5, 0)
		size = Vector3.new(10 * reach, 7, 8.5 * reach)
	elseif direction == "dashslash" then
		center = pos + look * (6 * reach) + Vector3.new(0, 0.4, 0)
		size = Vector3.new(6, 5.5, 15 * reach)
	elseif direction == "cyclone" then
		center = pos + Vector3.new(0, 0.6, 0)
		size = Vector3.new(7, 7.5, 13 * reach)
	elseif direction == "up" then
		center = pos + Vector3.new(0, 3 + 2.4 * reach, 0) + look * 0.8
		size = Vector3.new(6, 4.8 * reach, 6)
	elseif direction == "down" then
		center = pos - Vector3.new(0, 3 + 2.4 * reach, 0)
		size = Vector3.new(6, 4.8 * reach, 6)
	else
		center = pos + look * (2 + 2.6 * reach) + Vector3.new(0, 0.3, 0)
		size = Vector3.new(6.5 * reach, 5, 5.2 * reach)
	end
	return CFrame.lookAt(center, center + look), size
end

return Hitbox
