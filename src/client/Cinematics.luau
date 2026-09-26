-- Cinematic moments: letterboxed boss introductions, phase-change flashes, and the
-- memory vignettes shown when a drifting memory is collected.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Memories = require(Shared.Memories)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local CameraController = require(script.Parent.CameraController)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local Cinematics = {}

local FONT = Enum.Font.Garamond

local gui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local flashFrame: Frame

local function bars(on: boolean, duration: number)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine)
	TweenService:Create(topBar, info, { Size = UDim2.new(1, 0, if on then 0.11 else 0, 0) }):Play()
	TweenService:Create(bottomBar, info, { Size = UDim2.new(1, 0, if on then 0.11 else 0, 0) }):Play()
end

function Cinematics.flash(strength: number, color: Color3?)
	flashFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1 - strength
	TweenService:Create(flashFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function bossIntro(name: string, title: string, position: Vector3, duration: number)
	State.freeze("intro", true)
	bars(true, 0.4)
	Sfx.play("roar", 0.8)
	CameraController.focusOn(position, duration * 0.8)
	task.delay(duration * 0.35, function()
		HUD.areaTitle(name, title, "boss")
	end)
	task.delay(duration, function()
		State.freeze("intro", false)
		bars(false, 0.6)
	end)
end

local showingMemory = false

local function showMemory(id: string)
	local memory = Memories[id]
	if not memory or showingMemory then
		return
	end
	showingMemory = true
	State.freeze("memory", true)
	Sfx.play("memory", 0.7)

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(14, 10, 8)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 30
	overlay.Parent = gui
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromRGB(60, 44, 30), Color3.fromRGB(10, 8, 8))
	glow.Rotation = 90
	glow.Parent = overlay
	TweenService:Create(overlay, TweenInfo.new(0.8), { BackgroundTransparency = 0.12 }):Play()

	local function text(content: string, size: number, y: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.TextSize = size
		l.TextWrapped = true
		l.TextColor3 = color
		l.TextTransparency = 1
		l.Text = content
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.new(0.7, 0, 0, size * 3)
		l.Position = UDim2.fromScale(0.5, y)
		l.ZIndex = 31
		l.Parent = overlay
		return l
	end

	local header = text("A MEMORY", 18, 0.2, Color3.fromRGB(220, 200, 170))
	local title = text(string.upper(memory.title), 40, 0.27, Color3.fromRGB(255, 236, 200))
	task.wait(0.6)
	TweenService:Create(header, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	TweenService:Create(title, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	task.wait(0.8)
	for i, line in memory.lines do
		local l = text(line, 22, 0.38 + i * 0.1, Color3.fromRGB(236, 226, 210))
		TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
		task.wait(math.clamp(#line / 28, 1.6, 3.2))
	end
	local hint = text("press any key", 16, 0.9, Color3.fromRGB(170, 160, 150))
	TweenService:Create(hint, TweenInfo.new(0.6), { TextTransparency = 0.3 }):Play()
	local done = Instance.new("BindableEvent")
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Gamepad1 then
			done:Fire()
		end
	end)
	task.delay(20, function()
		done:Fire()
	end)
	done.Event:Wait()
	conn:Disconnect()
	for _, child in overlay:GetChildren() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end
	TweenService:Create(overlay, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.wait(0.8)
	overlay:Destroy()
	State.freeze("memory", false)
	showingMemory = false
	HUD.notify("Memory recorded", "Open your journal (M) to read it again.", "info")
end

function Cinematics.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Cinematics"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local function bar(anchorY: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.new(1, 0, 0, 0)
		f.Parent = gui
		return f
	end
	topBar = bar(0)
	bottomBar = bar(1)

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 20
	flashFrame.Parent = gui

	Net.event("BossIntro").OnClientEvent:Connect(bossIntro)
	Net.event("BossPhase").OnClientEvent:Connect(function()
		Cinematics.flash(0.55)
		CameraController.shake(1)
		Sfx.play("roar", 1.1)
	end)
	Net.event("Flash").OnClientEvent:Connect(function(strength: number)
		Cinematics.flash(strength)
	end)
	Net.event("Memory").OnClientEvent:Connect(function(id: string)
		task.spawn(showMemory, id)
	end)

	-- A red pulse at the screen edges whenever a mask is lost.
	local lastMasks = (player:GetAttribute("Masks") or 0) :: number
	player:GetAttributeChangedSignal("Masks"):Connect(function()
		local masks = (player:GetAttribute("Masks") or 0) :: number
		if masks < lastMasks then
			Cinematics.flash(0.35, Color3.fromRGB(120, 10, 20))
			CameraController.shake(0.6)
		end
		lastMasks = masks
	end)
end

return Cinematics
