-- Vesperdeep server entry point: build the world, then start every system.

local Builder = require(script.Parent.World.Builder)
local PlayerService = require(script.Parent.PlayerService)
local Projectiles = require(script.Parent.Projectiles)
local Enemies = require(script.Parent.Enemies)
local Bosses = require(script.Parent.Bosses)
local Combat = require(script.Parent.Combat)

local infos = Builder.build()

local solid = {}
for _, info in infos do
	table.insert(solid, info.folder:FindFirstChild("Map"))
	table.insert(solid, info.folder:FindFirstChild("Breakables"))
end

PlayerService.init(infos)
PlayerService.onRest = Enemies.resetAll
Projectiles.init(solid, function(player, amount, position)
	PlayerService.damage(player, amount, position)
end)
Enemies.init(infos, PlayerService)
Bosses.init(infos, PlayerService)
Combat.init(infos, PlayerService)

print("[Vesperdeep] The kingdom stirs.")
