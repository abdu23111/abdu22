-- Registry of things the nail can strike (enemies, bosses, echoes). Combat looks up
-- whatever part it overlaps and forwards the hit to the registered handler.

export type Handler = {
	-- Returns true if the strike should grant Soul.
	onHit: (player: Player, damage: number, direction: Vector3) -> boolean,
	-- Walls and inert objects can bounce the player (pogo) but never give Soul.
	pogo: boolean?,
}

local Damageable = {}

local handlers: { [Instance]: Handler } = {}

function Damageable.register(root: Instance, handler: Handler)
	handlers[root] = handler
	root.Destroying:Connect(function()
		handlers[root] = nil
	end)
end

function Damageable.unregister(root: Instance)
	handlers[root] = nil
end

function Damageable.find(part: Instance): (Instance?, Handler?)
	local node: Instance? = part
	while node and node ~= workspace do
		local h = handlers[node]
		if h then
			return node, h
		end
		node = node.Parent
	end
	return nil, nil
end

return Damageable
