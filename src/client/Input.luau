-- Keyboard / gamepad / touch input, exposed as a held-state table plus action callbacks.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Input = {
	left = false,
	right = false,
	up = false,
	down = false,
	jumpHeld = false,
	focusHeld = false,
	stickX = 0,
	stickY = 0,
}

local listeners: { [string]: { (any) -> () } } = {}

function Input.on(action: string, fn: (any) -> ())
	listeners[action] = listeners[action] or {}
	table.insert(listeners[action], fn)
end

local function fire(action: string, ...)
	for _, fn in listeners[action] or {} do
		task.spawn(fn, ...)
	end
end
Input.fire = fire

function Input.axis(): number
	local x = (if Input.right then 1 else 0) - (if Input.left then 1 else 0)
	if x == 0 and math.abs(Input.stickX) > 0.35 then
		x = math.sign(Input.stickX)
	end
	return x
end

function Input.lookUp(): boolean
	return Input.up or Input.stickY > 0.6
end

function Input.lookDown(): boolean
	return Input.down or Input.stickY < -0.6
end

local HOLD = {
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.DPadLeft] = "left",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.DPadRight] = "right",
	[Enum.KeyCode.W] = "up",
	[Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.DPadUp] = "up",
	[Enum.KeyCode.S] = "down",
	[Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.DPadDown] = "down",
}

local JUMP = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.Z] = true, [Enum.KeyCode.ButtonA] = true }
local ATTACK = { [Enum.KeyCode.J] = true, [Enum.KeyCode.X] = true, [Enum.KeyCode.ButtonX] = true }
local DASH = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.L] = true, [Enum.KeyCode.C] = true, [Enum.KeyCode.ButtonR1] = true, [Enum.KeyCode.ButtonB] = true }
local FOCUS = { [Enum.KeyCode.F] = true, [Enum.KeyCode.K] = true, [Enum.KeyCode.ButtonL1] = true }

local function press(key: Enum.KeyCode, down: boolean)
	local hold = HOLD[key]
	if hold then
		(Input :: any)[hold] = down
	end
	if JUMP[key] then
		Input.jumpHeld = down
		fire(if down then "jump" else "jumpRelease")
	elseif ATTACK[key] and down then
		fire("attack")
	elseif DASH[key] and down then
		fire("dash")
	elseif FOCUS[key] then
		Input.focusHeld = down
		fire(if down then "focusStart" else "focusEnd")
	elseif key == Enum.KeyCode.Tab and down then
		fire("charms")
	elseif key == Enum.KeyCode.H and down then
		fire("help")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not processed then
			fire("attack")
		end
		return
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if not processed then
			Input.focusHeld = true
			fire("focusStart")
		end
		return
	end
	if processed and input.KeyCode ~= Enum.KeyCode.ButtonA then
		return
	end
	press(input.KeyCode, true)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		Input.focusHeld = false
		fire("focusEnd")
		return
	end
	press(input.KeyCode, false)
end)

UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		Input.stickX = input.Position.X
		Input.stickY = input.Position.Y
	end
end)

-- Clear held keys when the window loses focus so the character doesn't run away.
UserInputService.WindowFocusReleased:Connect(function()
	Input.left, Input.right, Input.up, Input.down = false, false, false, false
	Input.jumpHeld, Input.focusHeld = false, false
end)

-- ===== Touch controls =====

local function touchButton(gui: ScreenGui, text: string, position: UDim2, size: number, onDown: () -> (), onUp: (() -> ())?)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 22
	button.TextColor3 = Color3.fromRGB(235, 235, 245)
	button.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(size, size)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 200, 220)
	stroke.Transparency = 0.5
	stroke.Parent = button
	button.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)
	button.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch and onUp then
			onUp()
		end
	end)
	button.Parent = gui
	return button
end

if UserInputService.TouchEnabled then
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function hold(field: string)
		return function()
			(Input :: any)[field] = true
		end, function()
			(Input :: any)[field] = false
		end
	end
	local ld, lu = hold("left")
	local rd, ru = hold("right")
	local ud, uu = hold("up")
	local dd, du = hold("down")
	touchButton(gui, "<", UDim2.new(0, 70, 1, -90), 76, ld, lu)
	touchButton(gui, ">", UDim2.new(0, 160, 1, -90), 76, rd, ru)
	touchButton(gui, "^", UDim2.new(0, 115, 1, -170), 56, ud, uu)
	touchButton(gui, "v", UDim2.new(0, 115, 1, -30), 50, dd, du)
	touchButton(gui, "JUMP", UDim2.new(1, -80, 1, -90), 90, function()
		Input.jumpHeld = true
		fire("jump")
	end, function()
		Input.jumpHeld = false
		fire("jumpRelease")
	end)
	touchButton(gui, "NAIL", UDim2.new(1, -180, 1, -80), 76, function()
		fire("attack")
	end)
	touchButton(gui, "DASH", UDim2.new(1, -110, 1, -190), 64, function()
		fire("dash")
	end)
	touchButton(gui, "HEAL", UDim2.new(1, -200, 1, -170), 58, function()
		Input.focusHeld = true
		fire("focusStart")
	end, function()
		Input.focusHeld = false
		fire("focusEnd")
	end)
end

return Input
