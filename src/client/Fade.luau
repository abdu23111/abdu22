-- Full-screen fade used for doorways, hazard respawns, death and the ending.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fade = {}

local gui = Instance.new("ScreenGui")
gui.Name = "Fade"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Parent = gui

local function tween(target: number, duration: number, color: Color3?)
	if color then
		frame.BackgroundColor3 = color
	end
	local t = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Sine), { BackgroundTransparency = target })
	t:Play()
	t.Completed:Wait()
end

-- Fade to black (yields).
function Fade.out(duration: number, color: Color3?)
	tween(0, duration, color or Color3.new(0, 0, 0))
end

-- Fade back in (yields).
function Fade.into(duration: number)
	tween(1, duration)
end

return Fade
