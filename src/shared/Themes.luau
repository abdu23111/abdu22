--!strict
-- Colour palettes and lighting moods for each zone. Muted foregrounds, deep hazy
-- backgrounds and a single accent colour give each area its painted feel.

export type Theme = {
	rock: Color3, -- main foreground stone
	rockDark: Color3, -- inner / deeper stone
	rim: Color3, -- accent strip along walkable edges
	smooth: Color3, -- smooth (unclimbable) stone
	backWall: Color3, -- wall directly behind the play plane
	far: { Color3 }, -- parallax silhouette layers, near to far
	accent: Color3, -- glow colour for lights, flora, motes
	fog: Color3,
	fogStart: number,
	fogEnd: number,
	ambient: Color3,
	outdoor: Color3,
	tint: Color3, -- colour correction tint
	material: Enum.Material,
	decor: string,
}

local Themes: { [string]: Theme } = {
	burrows = {
		rock = Color3.fromRGB(58, 56, 64),
		rockDark = Color3.fromRGB(34, 33, 40),
		rim = Color3.fromRGB(150, 146, 150),
		smooth = Color3.fromRGB(80, 78, 88),
		backWall = Color3.fromRGB(26, 26, 34),
		far = { Color3.fromRGB(30, 32, 44), Color3.fromRGB(24, 28, 40), Color3.fromRGB(20, 24, 36) },
		accent = Color3.fromRGB(255, 170, 90),
		fog = Color3.fromRGB(16, 19, 30),
		fogStart = 70,
		fogEnd = 240,
		ambient = Color3.fromRGB(70, 74, 92),
		outdoor = Color3.fromRGB(40, 44, 60),
		tint = Color3.fromRGB(235, 232, 255),
		material = Enum.Material.Slate,
		decor = "caves",
	},
	ruins = {
		rock = Color3.fromRGB(60, 66, 86),
		rockDark = Color3.fromRGB(36, 40, 56),
		rim = Color3.fromRGB(176, 186, 214),
		smooth = Color3.fromRGB(90, 98, 124),
		backWall = Color3.fromRGB(26, 30, 46),
		far = { Color3.fromRGB(34, 40, 62), Color3.fromRGB(28, 34, 56), Color3.fromRGB(22, 28, 50) },
		accent = Color3.fromRGB(150, 200, 255),
		fog = Color3.fromRGB(18, 24, 42),
		fogStart = 70,
		fogEnd = 280,
		ambient = Color3.fromRGB(76, 86, 118),
		outdoor = Color3.fromRGB(46, 54, 80),
		tint = Color3.fromRGB(225, 235, 255),
		material = Enum.Material.Cobblestone,
		decor = "city",
	},
	forest = {
		rock = Color3.fromRGB(44, 62, 52),
		rockDark = Color3.fromRGB(26, 38, 32),
		rim = Color3.fromRGB(110, 170, 110),
		smooth = Color3.fromRGB(70, 92, 84),
		backWall = Color3.fromRGB(18, 30, 26),
		far = { Color3.fromRGB(24, 40, 34), Color3.fromRGB(20, 34, 32), Color3.fromRGB(16, 28, 30) },
		accent = Color3.fromRGB(160, 255, 190),
		fog = Color3.fromRGB(14, 28, 26),
		fogStart = 60,
		fogEnd = 230,
		ambient = Color3.fromRGB(66, 96, 84),
		outdoor = Color3.fromRGB(40, 60, 52),
		tint = Color3.fromRGB(228, 255, 236),
		material = Enum.Material.Ground,
		decor = "forest",
	},
	temple = {
		rock = Color3.fromRGB(96, 88, 78),
		rockDark = Color3.fromRGB(58, 52, 48),
		rim = Color3.fromRGB(230, 196, 120),
		smooth = Color3.fromRGB(150, 138, 118),
		backWall = Color3.fromRGB(40, 34, 36),
		far = { Color3.fromRGB(56, 46, 48), Color3.fromRGB(46, 38, 44), Color3.fromRGB(36, 30, 40) },
		accent = Color3.fromRGB(255, 220, 150),
		fog = Color3.fromRGB(34, 26, 32),
		fogStart = 80,
		fogEnd = 300,
		ambient = Color3.fromRGB(110, 96, 90),
		outdoor = Color3.fromRGB(66, 56, 56),
		tint = Color3.fromRGB(255, 240, 225),
		material = Enum.Material.Marble,
		decor = "temple",
	},
}

return Themes
