--!strict
-- The nail's reach, shared so the client (effects, pogo) and server (damage) agree.

local Hitbox = {}

function Hitbox.nail(rootPosition: Vector3, facing: number, direction: string, reach: number): (Vector3, Vector3)
	if direction == "up" then
		return rootPosition + Vector3.new(0, 3 + 2.4 * reach, 0), Vector3.new(5, 4.8 * reach, 10)
	elseif direction == "down" then
		return rootPosition + Vector3.new(0, -(3 + 2.4 * reach), 0), Vector3.new(5, 4.8 * reach, 10)
	end
	return rootPosition + Vector3.new(facing * (2 + 2.6 * reach), 0.3, 0), Vector3.new(5.2 * reach, 4.8, 10)
end

return Hitbox
