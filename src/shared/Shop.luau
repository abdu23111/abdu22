--!strict
-- Wares sold by Lirra, the wandering merchant of the Ruins.

export type Ware = { id: string, name: string, kind: string, charm: string?, price: number, description: string }

local Shop: { Ware } = {
	{
		id = "compass",
		name = "Wayfarer's Compass",
		kind = "charm",
		charm = "wayfarer_compass",
		price = 120,
		description = "Shows where you stand on your map.",
	},
	{
		id = "heart",
		name = "Heart Husk",
		kind = "heart",
		price = 450,
		description = "A hardened shell-plate. +1 mask.",
	},
	{
		id = "notch",
		name = "Charm Notch",
		kind = "notch",
		price = 350,
		description = "Room for one more charm.",
	},
}

return Shop
