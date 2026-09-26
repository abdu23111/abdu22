-- Vesperdeep client entry point.

local Movement = require(script.Parent.Movement)
local CameraController = require(script.Parent.CameraController)
local CombatClient = require(script.Parent.CombatClient)
local HUD = require(script.Parent.HUD)
local Menus = require(script.Parent.Menus)
local Atmosphere = require(script.Parent.Atmosphere)
local Pickups = require(script.Parent.Pickups)

HUD.init()
Menus.init()
Atmosphere.init()
Movement.onTeleport = CameraController.snap
Movement.init()
CameraController.init()
CombatClient.init()
Pickups.init()
