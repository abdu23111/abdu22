--!strict
-- Charm definitions. Charms are found in the world or bought, and equipped while resting at a bench.

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
	glass_spur = {
		id = "glass_spur",
		name = "Glass Spur",
		cost = 2,
		description = "A shard that hums near light. Lumen Bolts strike 50% harder and fly further.",
		color = Color3.fromRGB(170, 240, 255),
	},
	mirror_shell = {
		id = "mirror_shell",
		name = "Mirror Shell",
		cost = 1,
		description = "Polished until it forgot itself. Sidestep and post-hit protection last longer.",
		color = Color3.fromRGB(220, 220, 240),
	},
	wayfarer_compass = {
		id = "wayfarer_compass",
		name = "Wayfarer's Compass",
		cost = 1,
		description = "Its needle points at whoever carries it. Shows your position on the map.",
		color = Color3.fromRGB(230, 200, 150),
	},
	deep_pockets = {
		id = "deep_pockets",
		name = "Deep Pockets",
		cost = 1,
		description = "A miner's pouch, lined twice. Enemies drop 50% more Geo.",
		color = Color3.fromRGB(120, 220, 255),
	},
	kindled_spirit = {
		id = "kindled_spirit",
		name = "Kindled Spirit",
		cost = 2,
		description = "What is mended burns bright. Healing releases a burst of light that harms nearby foes.",
		color = Color3.fromRGB(255, 230, 170),
	},
}

return Charms
