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
local Characters = require(script.Parent.Characters)
local Creatures = require(script.Parent.Creatures)
local NPCs = require(script.Parent.NPCs)

HUD.onGeo = function()
	require(script.Parent.Sfx).play("geo", 1 + math.random() * 0.2)
end
HUD.init()
Menus.init()
Cinematics.init()
Journal.init()
Atmosphere.init()
Movement.onTeleport = function(facing: Vector3?)
	CameraController.snap()
	if facing then
		CameraController.faceDirection(facing)
	end
end
Movement.init()
CameraController.onModeChanged = function(mode: string)
	HUD.notify(if mode == "side" then "Side view" else "Free camera", "Press V to switch views.", "info")
end
CameraController.init()
Characters.init()
Creatures.init()
NPCs.init()
CombatClient.init()
Pickups.init()
Shortcuts.init()
