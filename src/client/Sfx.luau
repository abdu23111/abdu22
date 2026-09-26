-- One-shot sound effects, configured in Shared.Config.SFX (your upload first, then a
-- sound bundled with the Roblox client as a fallback).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

local sounds: { [string]: Sound } = {}
for name, ids in Config.SFX do
	local id = if ids[1] ~= "" then ids[1] else ids[2]
	if id and id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = id
		sound.Volume = Config.SFX_VOLUME
		sound.Parent = SoundService
		sounds[name] = sound
	end
end

function Sfx.play(name: string, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
		SoundService:PlayLocalSound(sound)
	end
end

return Sfx
