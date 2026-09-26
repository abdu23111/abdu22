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
local Net = require(Shared.Net)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Atmosphere = {}

local tracks: { [string]: Sound } = {}
local currentTrack: string? = nil
local endingPlayed = false
local colorCorrection: ColorCorrectionEffect
local atmosphere: Atmosphere

local function makeEffects()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	-- A volumetric haze that swallows the far caverns; each region tints it.
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(16, 19, 30)
	atmosphere.Decay = Color3.fromRGB(8, 9, 14)
	atmosphere.Parent = Lighting
	Lighting.Brightness = 1
	Lighting.ClockTime = 0
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.35
	-- Lift the whole image a little: caves should be moody, not black.
	Lighting.ExposureCompensation = 0.35

	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Contrast = 0.1
	colorCorrection.Saturation = 0.1
	colorCorrection.Brightness = 0.04
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 32
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FocusDistance = 18
	dof.InFocusRadius = 40
	dof.FarIntensity = 0.22
	dof.NearIntensity = 0
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
		g.Transparency = NumberSequence.new(0.55, 1)
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
	TweenService:Create(atmosphere, info, {
		Color = theme.fog,
		Decay = theme.fog:Lerp(Color3.new(0, 0, 0), 0.5),
		Density = math.clamp(85 / theme.fogEnd, 0.2, 0.34),
	}):Play()
	HUD.areaTitle(zone.name, zone.subtitle, "area")
end

-- Returns the music key of a boss fighting in the current zone, if any.
local function bossMusicHere(): string?
	local root = ReplicatedStorage:FindFirstChild("BossState")
	if not root then
		return nil
	end
	for _, folder in root:GetChildren() do
		if folder:GetAttribute("Active") and folder:GetAttribute("Zone") == State.zone then
			return (folder:GetAttribute("Music") or "boss") :: string
		end
	end
	return nil
end

-- Performance: only the zone you're in (and neighbours you can glimpse) runs its particles
-- and lights. Everything else in the world sleeps.
local zoneEffects: { [number]: { Instance } } = {}

local function collectEffects()
	local world = workspace:WaitForChild("World")
	for _, folder in world:GetChildren() do
		local index = folder:GetAttribute("Index")
		if typeof(index) == "number" then
			local list = {}
			for _, d in folder:GetDescendants() do
				-- Pickups and switches manage their own glow (collected / opened).
				if (d:IsA("ParticleEmitter") or d:IsA("PointLight")) and not d:FindFirstAncestor("Items") and not d:FindFirstAncestor("Switches") then
					table.insert(list, d)
				end
			end
			zoneEffects[index] = list
		end
	end
end

local function setZoneEffects(active: number)
	for index, list in zoneEffects do
		local on = index == active
		for _, effect in list do
			(effect :: any).Enabled = on
		end
	end
end

-- A soft dark vignette around the screen edges that frames every scene.
local function makeVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5
	gui.Parent = player:WaitForChild("PlayerGui")
	local edges = {
		{ UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.7), -90 },
		{ UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0.22, 0, 1, 0), UDim2.fromScale(0.78, 0), 180 },
	}
	for _, e in edges do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.Size = e[1]
		f.Position = e[2]
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.45, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
end

function Atmosphere.init()
	makeVignette()
	makeEffects()
	makeMusic()
	collectEffects()

	HUD.onEnding = function()
		endingPlayed = true
		playTrack("ending")
		TweenService:Create(Lighting, TweenInfo.new(8), {
			Ambient = Color3.fromRGB(150, 130, 110),
			OutdoorAmbient = Color3.fromRGB(110, 96, 80),
			FogColor = Color3.fromRGB(70, 56, 44),
		}):Play()
		TweenService:Create(atmosphere, TweenInfo.new(8), { Color = Color3.fromRGB(120, 96, 70), Density = 0.3 }):Play()
	end

	task.spawn(function()
		while true do
			local root = State.root
			if root then
				local zone = Grid.zoneAt(root.Position)
				if zone and zone ~= State.zone then
					State.zone = zone
					applyZone(zone)
					setZoneEffects(zone)
					Net.event("EnterZone"):FireServer(zone)
				end
			end
			local bossMusic = if State.zone then bossMusicHere() else nil
			State.bossFight = bossMusic ~= nil
			if State.zone and not endingPlayed then
				local key = bossMusic or Zones[State.zone].music
				if bossMusic and not tracks[key] then
					key = "boss"
				end
				playTrack(key)
			end
			task.wait(0.25)
		end
	end)
end

return Atmosphere
