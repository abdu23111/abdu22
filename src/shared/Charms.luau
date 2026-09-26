--!strict
-- Charm definitions. Charms are found in the world and equipped while resting at a bench.

export type Charm = {
	id: string,
	name: string,
	cost: number,
	description: string,
	color: Color3,
}

local Charms: { [string]: Charm } = {
	swift_mantle = {
		id = "swift_mantle",
		name = "Swift Mantle",
		cost = 1,
		description = "A scrap of courier silk. Run 15% faster.",
		color = Color3.fromRGB(150, 210, 255),
	},
	ember_edge = {
		id = "ember_edge",
		name = "Ember Edge",
		cost = 2,
		description = "A coal that never cooled. Nail strikes deal 40% more damage.",
		color = Color3.fromRGB(255, 140, 80),
	},
	soul_siphon = {
		id = "soul_siphon",
		name = "Soul Siphon",
		cost = 1,
		description = "Drinks what the nail spills. Gain 50% more Soul per strike.",
		color = Color3.fromRGB(210, 220, 255),
	},
	stone_heart = {
		id = "stone_heart",
		name = "Stone Heart",
		cost = 2,
		description = "Heavy and patient. Grants one extra mask.",
		color = Color3.fromRGB(170, 160, 150),
	},
	quiet_focus = {
		id = "quiet_focus",
		name = "Quiet Focus",
		cost = 2,
		description = "A monk's breathing rhythm. Focus heals 40% faster.",
		color = Color3.fromRGB(180, 255, 200),
	},
	long_reach = {
		id = "long_reach",
		name = "Long Reach",
		cost = 1,
		description = "A cracked lens that makes the world look closer. Nail reaches further.",
		color = Color3.fromRGB(240, 220, 140),
	},
}

return Charms
