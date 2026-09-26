-- Keyboard / mouse / gamepad / touch input for a third-person action game:
-- a 2D move stick, camera look deltas, held buttons and action callbacks.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Input = {
	jumpHeld = false,
	focusHeld = false,
	attackHeld = false,
	swingHeld = false,
	cdashHeld = false,
	stick = Vector2.zero, -- gamepad left stick
	lookStick = Vector2.zero, -- gamepad right stick
	touchMove = Vector2.zero,
	keys = {} :: { [Enum.KeyCode]: boolean },
}

local lookDelta = Vector2.zero
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

-- Movement as (right, forward), each -1..1.
function Input.move(): Vector2
	local k = Input.keys
	local x = (if k[Enum.KeyCode.D] or k[Enum.KeyCode.Right] then 1 else 0) - (if k[Enum.KeyCode.A] or k[Enum.KeyCode.Left] then 1 else 0)
	local y = (if k[Enum.KeyCode.W] or k[Enum.KeyCode.Up] then 1 else 0) - (if k[Enum.KeyCode.S] or k[Enum.KeyCode.Down] then 1 else 0)
	local v = Vector2.new(x, y)
	if Input.stick.Magnitude > 0.15 then
		v = Input.stick
	elseif Input.touchMove.Magnitude > 0.1 then
		v = Input.touchMove
	end
	if v.Magnitude > 1 then
		v = v.Unit
	end
	return v
end

-- Camera look since the last call (radians-ish units; the camera scales them).
function Input.consumeLook(): Vector2
	local d = lookDelta
	lookDelta = Vector2.zero
	return d
end

-- Aim / peek: W / Up / stick up, and S / Down / stick down.
function Input.lookUp(): boolean
	local k = Input.keys
	return k[Enum.KeyCode.W] == true or k[Enum.KeyCode.Up] == true or Input.stick.Y > 0.55 or Input.touchMove.Y > 0.6
end
function Input.lookDown(): boolean
	local k = Input.keys
	return k[Enum.KeyCode.S] == true or k[Enum.KeyCode.Down] == true or Input.stick.Y < -0.55 or Input.touchMove.Y < -0.6
end

local JUMP = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true }
local ATTACK = { [Enum.KeyCode.J] = true, [Enum.KeyCode.ButtonX] = true }
local DASH = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.ButtonB] = true, [Enum.KeyCode.ButtonR1] = true }
local FOCUS = { [Enum.KeyCode.F] = true, [Enum.KeyCode.ButtonL1] = true }
local DODGE = { [Enum.KeyCode.Q] = true, [Enum.KeyCode.C] = true, [Enum.KeyCode.ButtonL2] = true }
local BOLT = { [Enum.KeyCode.R] = true, [Enum.KeyCode.ButtonR2] = true }
local MAP = { [Enum.KeyCode.M] = true, [Enum.KeyCode.ButtonSelect] = true }
local LOCK = { [Enum.KeyCode.T] = true, [Enum.KeyCode.ButtonR3] = true }
local SWING = { [Enum.KeyCode.G] = true, [Enum.KeyCode.ButtonL3] = true, [Enum.KeyCode.DPadUp] = true }
local VIEW = { [Enum.KeyCode.V] = true, [Enum.KeyCode.DPadDown] = true }

local function press(key: Enum.KeyCode, down: boolean)
	Input.keys[key] = down or nil
	if JUMP[key] then
		Input.jumpHeld = down
		fire(if down then "jump" else "jumpRelease")
	elseif ATTACK[key] then
		Input.attackHeld = down
		fire(if down then "attack" else "attackRelease")
	elseif DASH[key] and down then
		fire("dash")
	elseif FOCUS[key] then
		Input.focusHeld = down
		fire(if down then "focusStart" else "focusEnd")
	elseif DODGE[key] and down then
		fire("dodge")
	elseif BOLT[key] and down then
		fire("bolt")
	elseif MAP[key] and down then
		fire("map")
	elseif LOCK[key] and down then
		fire("lock")
	elseif SWING[key] then
		Input.swingHeld = down
		fire(if down then "swing" else "swingRelease")
	elseif VIEW[key] then
		-- Charge dash: hold to gather, release to launch.
		Input.cdashHeld = down
		fire(if down then "cdash" else "cdashRelease")
	elseif key == Enum.KeyCode.Tab and down then
		fire("charms")
	elseif key == Enum.KeyCode.H and down then
		fire("help")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		if not processed then
			Input.attackHeld = true
			fire("attack")
		end
		return
	elseif t == Enum.UserInputType.MouseButton2 then
		if not processed then
			Input.focusHeld = true
			fire("focusStart")
		end
		return
	elseif t == Enum.UserInputType.MouseButton3 then
		fire("lock")
		return
	end
	if processed and input.KeyCode ~= Enum.KeyCode.ButtonA then
		return
	end
	press(input.KeyCode, true)
end)

UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		if Input.attackHeld then
			Input.attackHeld = false
			fire("attackRelease")
		end
		return
	elseif t == Enum.UserInputType.MouseButton2 then
		Input.focusHeld = false
		fire("focusEnd")
		return
	end
	press(input.KeyCode, false)
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			lookDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
		Input.stick = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		Input.lookStick = Vector2.new(input.Position.X, -input.Position.Y)
	end
end)

-- Clear held keys when the window loses focus so the character doesn't run away.
UserInputService.WindowFocusReleased:Connect(function()
	table.clear(Input.keys)
	Input.jumpHeld, Input.focusHeld, Input.attackHeld, Input.swingHeld = false, false, false, false
end)

-- ===== Touch: a floating joystick on the left, camera drag on the right, action buttons =====

local function touchButton(gui: ScreenGui, text: string, position: UDim2, size: number, onDown: () -> (), onUp: (() -> ())?)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
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

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(140, 140)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	ring.BackgroundTransparency = 0.6
	ring.Visible = false
	ring.Parent = gui
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(56, 56)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(220, 220, 235)
	knob.BackgroundTransparency = 0.3
	knob.Parent = ring
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local moveTouch: InputObject? = nil
	local lookTouch: InputObject? = nil
	local moveOrigin = Vector2.zero
	local lastLook = Vector2.zero

	UserInputService.TouchStarted:Connect(function(touch, processed)
		if processed then
			return
		end
		local pos = Vector2.new(touch.Position.X, touch.Position.Y)
		local viewport = workspace.CurrentCamera.ViewportSize
		if pos.X < viewport.X * 0.4 and not moveTouch then
			moveTouch = touch
			moveOrigin = pos
			ring.Position = UDim2.fromOffset(pos.X, pos.Y)
			ring.Visible = true
		elseif not lookTouch then
			lookTouch = touch
			lastLook = pos
		end
	end)
	UserInputService.TouchMoved:Connect(function(touch)
		local pos = Vector2.new(touch.Position.X, touch.Position.Y)
		if touch == moveTouch then
			local d = pos - moveOrigin
			if d.Magnitude > 60 then
				d = d.Unit * 60
			end
			knob.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
			Input.touchMove = Vector2.new(d.X / 60, -d.Y / 60)
		elseif touch == lookTouch then
			lookDelta += (pos - lastLook) * 1.4
			lastLook = pos
		end
	end)
	UserInputService.TouchEnded:Connect(function(touch)
		if touch == moveTouch then
			moveTouch = nil
			Input.touchMove = Vector2.zero
			ring.Visible = false
			knob.Position = UDim2.fromScale(0.5, 0.5)
		elseif touch == lookTouch then
			lookTouch = nil
		end
	end)

	touchButton(gui, "JUMP", UDim2.new(1, -80, 1, -90), 90, function()
		Input.jumpHeld = true
		fire("jump")
	end, function()
		Input.jumpHeld = false
		fire("jumpRelease")
	end)
	touchButton(gui, "NAIL", UDim2.new(1, -180, 1, -80), 76, function()
		Input.attackHeld = true
		fire("attack")
	end, function()
		Input.attackHeld = false
		fire("attackRelease")
	end)
	touchButton(gui, "DASH", UDim2.new(1, -110, 1, -190), 64, function()
		fire("dash")
	end)
	touchButton(gui, "DODGE", UDim2.new(1, -40, 1, -190), 56, function()
		fire("dodge")
	end)
	touchButton(gui, "BOLT", UDim2.new(1, -270, 1, -110), 58, function()
		fire("bolt")
	end)
	touchButton(gui, "HEAL", UDim2.new(1, -200, 1, -170), 58, function()
		Input.focusHeld = true
		fire("focusStart")
	end, function()
		Input.focusHeld = false
		fire("focusEnd")
	end)
	touchButton(gui, "CDASH", UDim2.new(1, -240, 0.45, 0), 58, function()
		Input.cdashHeld = true
		fire("cdash")
	end, function()
		Input.cdashHeld = false
		fire("cdashRelease")
	end)
	touchButton(gui, "SWING", UDim2.new(1, -150, 0.45, 0), 60, function()
		Input.swingHeld = true
		fire("swing")
	end, function()
		Input.swingHeld = false
		fire("swingRelease")
	end)

	touchButton(gui, "MAP", UDim2.new(1, -60, 0, 60), 50, function()
		fire("map")
	end)
end

return Input
