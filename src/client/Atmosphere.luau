-- Mood per zone: lighting and fog, colour grading, depth-of-field on the painted backdrops,
-- a soft vignette, area title cards and crossfading music.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Themes = require(Shared.Themes)
local Grid = require(Shared.Grid)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Atmosphere = {}

local tracks: { [string]: Sound } = {}
local currentTrack: string? = nil
local endingPlayed = false
local colorCorrection: ColorCorrectionEffect

local function makeEffects()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy() -- Atmosphere would override our fog.
		end
	end
	Lighting.Brightness = 1
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2

	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Contrast = 0.12
	colorCorrection.Saturation = -0.12
	colorCorrection.Brightness = 0.02
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 32
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FocusDistance = Config.CAMERA_DISTANCE
	dof.InFocusRadius = 26
	dof.FarIntensity = 0.5
	dof.NearIntensity = 0.3
	dof.Parent = Lighting

	-- Vignette built from four gradient edges.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")
	local edges = {
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0.72), -90 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 },
	}
	for _, e in edges do
		local f = Instance.new("Frame")
		f.Size = e[1]
		f.Position = e[2]
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0.35, 1)
		g.Parent = f
	end
end

local function makeMusic()
	for name, id in Config.MUSIC do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "Music_" .. name
			s.SoundId = id
			s.Looped = name ~= "ending"
			s.Volume = 0
			s.Parent = SoundService
			tracks[name] = s
		end
	end
end

local function playTrack(name: string?)
	if name == currentTrack then
		return
	end
	currentTrack = name
	for trackName, sound in tracks do
		if trackName == name then
			if not sound.IsPlaying then
				sound.TimePosition = 0
				sound:Play()
			end
			TweenService:Create(sound, TweenInfo.new(2.5), { Volume = Config.MUSIC_VOLUME }):Play()
		else
			local t = TweenService:Create(sound, TweenInfo.new(2.5), { Volume = 0 })
			t:Play()
			t.Completed:Once(function()
				if currentTrack ~= trackName then
					sound:Stop()
				end
			end)
		end
	end
end

local function applyZone(index: number)
	local zone = Zones[index]
	local theme = Themes[zone.theme]
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		FogColor = theme.fog,
		FogStart = theme.fogStart,
		FogEnd = theme.fogEnd,
		Ambient = theme.ambient,
		OutdoorAmbient = theme.outdoor,
	}):Play()
	TweenService:Create(colorCorrection, info, { TintColor = theme.tint }):Play()
	HUD.areaTitle(zone.name, zone.subtitle, "area")
end

local function bossActiveHere(): boolean
	local root = ReplicatedStorage:FindFirstChild("BossState")
	if not root then
		return false
	end
	for _, folder in root:GetChildren() do
		if folder:GetAttribute("Active") and folder:GetAttribute("Zone") == State.zone then
			return true
		end
	end
	return false
end

function Atmosphere.init()
	makeEffects()
	makeMusic()

	HUD.onEnding = function()
		endingPlayed = true
		playTrack("ending")
		TweenService:Create(Lighting, TweenInfo.new(8), {
			Ambient = Color3.fromRGB(150, 130, 110),
			OutdoorAmbient = Color3.fromRGB(110, 96, 80),
			FogColor = Color3.fromRGB(70, 56, 44),
		}):Play()
	end

	task.spawn(function()
		while true do
			local root = State.root
			if root then
				local zone = Grid.zoneAt(root.Position)
				if zone and zone ~= State.zone then
					State.zone = zone
					applyZone(zone)
				end
			end
			if State.zone and not endingPlayed then
				playTrack(if bossActiveHere() then "boss" else Zones[State.zone].music)
			end
			task.wait(0.25)
		end
	end)
end

return Atmosphere
