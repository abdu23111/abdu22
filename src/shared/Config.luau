--!strict
-- Global tuning values for Vesperdeep. Tweak freely; both server and client read these.

local Config = {}

-- World grid
Config.TILE = 4 -- studs per map tile
Config.DEPTH = 14 -- thickness of foreground tiles along Z
Config.ZONE_SPACING = 1200 -- zones are laid out side by side along X, this far apart
-- 3D caves: each map is extruded into a winding corridor. Its half-width (in studs) wanders
-- around CORRIDOR by up to CORRIDOR_WANDER; boss arenas open up to ARENA_HALF.
Config.CORRIDOR = 17
Config.CORRIDOR_WANDER = 6
Config.ARENA_HALF = 30
Config.WALL_THICKNESS = 14

-- Player vitals
Config.BASE_MASKS = 5
Config.MAX_SOUL = 99
Config.SOUL_PER_HIT = 11
Config.HEAL_COST = 33
Config.HEAL_TIME = 1.0
Config.INVULN_TIME = 1.25
Config.BASE_NOTCHES = 3

-- Nail
Config.ATTACK_COOLDOWN = 0.32
Config.NAIL_DAMAGE = { 5, 7, 9, 12 } -- by nail level
Config.NAIL_UPGRADE_COST = { 200, 450, 800 } -- cost to go from level n to n+1

-- Cleaving Arc (hold the nail, then release)
Config.CLEAVE_CHARGE = 0.75
Config.CLEAVE_MULT = 2.5

-- Lumen Bolt (soul spell)
Config.BOLT_COST = 33
Config.BOLT_SPEED = 75
Config.BOLT_DAMAGE = 15
Config.BOLT_RANGE = 70

-- Sidestep (dodge, available from the start)
Config.DODGE_SPEED = 58
Config.DODGE_TIME = 0.16
Config.DODGE_INVULN = 0.32
Config.DODGE_COOLDOWN = 0.6

-- Movement
Config.WALK_SPEED = 22
Config.JUMP_VELOCITY = 60
Config.JUMP_CUT = 0.42 -- upward velocity multiplier when jump is released early
Config.MAX_FALL_SPEED = 110
Config.COYOTE_TIME = 0.1
Config.JUMP_BUFFER = 0.12
Config.DASH_SPEED = 85
Config.DASH_TIME = 0.18
Config.DASH_COOLDOWN = 0.45
Config.WALL_SLIDE_SPEED = 9
Config.WALL_JUMP_PUSH = 34
Config.WALL_JUMP_LOCK = 0.16
Config.POGO_VELOCITY = 58
Config.KNOCKBACK = Vector2.new(36, 32)

-- Camera
Config.CAMERA_DISTANCE = 62
Config.CAMERA_ARENA_DISTANCE = 78 -- pulls back during boss fights
Config.CAMERA_FOV = 40
Config.CAMERA_HEIGHT = 3
Config.CAMERA_LOOKAHEAD = 6
Config.CAMERA_PEEK = 12 -- hold up/down while standing still to look around

-- Enemies
Config.ENEMY_RESPAWN_TIME = 90

-- Boss introductions
Config.BOSS_INTRO_TIME = 2.8

-- Music. Upload the .ogg files from assets/music to Roblox (Asset Manager > Import)
-- and paste the resulting ids here, e.g. "rbxassetid://1234567890".
Config.MUSIC = {
	burrows = "",
	ruins = "",
	forest = "",
	temple = "",
	mines = "",
	archive = "",
	hollow = "",
	boss = "",
	boss_final = "",
	ending = "",
}
Config.MUSIC_VOLUME = 0.5

-- Sound effects. Each entry lists your uploaded id first (from assets/sfx) and a sound
-- bundled with the Roblox client as a fallback, so the game has sound out of the box.
Config.SFX = {
	slash = { "", "rbxasset://sounds/swordslash.wav" },
	hit = { "", "rbxasset://sounds/swordlunge.wav" },
	hurt = { "", "rbxasset://sounds/uuhhh.mp3" },
	jump = { "", "rbxasset://sounds/action_jump.mp3" },
	land = { "", "rbxasset://sounds/action_jump_land.mp3" },
	geo = { "", "rbxasset://sounds/electronicpingshort.wav" },
	heal = { "", "rbxasset://sounds/electronicpingshort.wav" },
	dash = { "", "rbxasset://sounds/swordlunge.wav" },
	dodge = { "", "rbxasset://sounds/swordlunge.wav" },
	bolt = { "", "rbxasset://sounds/electronicpingshort.wav" },
	cleave = { "", "rbxasset://sounds/swordslash.wav" },
	charge = { "", "" },
	roar = { "", "" },
	memory = { "", "rbxasset://sounds/electronicpingshort.wav" },
	lever = { "", "rbxasset://sounds/swordlunge.wav" },
	door = { "", "" },
	ui = { "", "rbxasset://sounds/electronicpingshort.wav" },
	shatter = { "", "" },
	impact = { "", "rbxasset://sounds/swordlunge.wav" },
}
Config.SFX_VOLUME = 0.45

return Config
