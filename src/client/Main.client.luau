-- Vesperdeep client entry point.

local Movement = require(script.Parent.Movement)
local CameraController = require(script.Parent.CameraController)
local CombatClient = require(script.Parent.CombatClient)
local HUD = require(script.Parent.HUD)
local Menus = require(script.Parent.Menus)
local Atmosphere = require(script.Parent.Atmosphere)
local Pickups = require(script.Parent.Pickups)
local Cinematics = require(script.Parent.Cinematics)
local Journal = require(script.Parent.Journal)
local Shortcuts = require(script.Parent.Shortcuts)

HUD.onGeo = function()
	require(script.Parent.Sfx).play("geo", 1 + math.random() * 0.2)
end
HUD.init()
Menus.init()
Cinematics.init()
Journal.init()
Atmosphere.init()
Movement.onTeleport = CameraController.snap
Movement.init()
CameraController.init()
CombatClient.init()
Pickups.init()
Shortcuts.init()
