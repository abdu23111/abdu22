-- Third-person orbit camera: mouse / right stick / touch-drag to look, pulls in against cave
-- walls, lock-on that keeps a target framed, slow orbits for boss introductions, and shake.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local CameraController = {}

local DISTANCE = 17
local ARENA_DISTANCE = 22
local SHOULDER = 1.4
local MOUSE_SENS = 0.0042
local STICK_SENS = 2.6

local yaw = 0
local pitch = math.rad(-12)
local distance = DISTANCE
local focus = Vector3.zero
local shakeAmount = 0
local snapNext = true
local cinematic: { target: Vector3, startTime: number, untilTime: number, startYaw: number }? = nil

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include

function CameraController.snap()
	snapNext = true
end

function CameraController.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

function CameraController.yaw(): number
	return yaw
end

-- Turn the camera to look along a horizontal direction.
function CameraController.faceDirection(dir: Vector3)
	if dir.Magnitude > 1e-3 then
		yaw = math.atan2(-dir.X, -dir.Z)
	end
end

-- Slowly orbit a point for a while (boss introductions).
function CameraController.focusOn(target: Vector3, duration: number)
	cinematic = { target = target, startTime = os.clock(), untilTime = os.clock() + duration, startYaw = yaw }
end

local function refreshFilter()
	local list = { workspace.Terrain }
	local world = workspace:FindFirstChild("World")
	if world then
		for _, zone in world:GetChildren() do
			for _, name in { "Map", "Breakables", "ShortcutGates" } do
				local f = zone:FindFirstChild(name)
				if f then
					table.insert(list, f)
				end
			end
		end
	end
	castParams.FilterDescendantsInstances = list
end

-- Pull the camera in front of any wall between it and the player.
local function collide(from: Vector3, to: Vector3): Vector3
	local dir = to - from
	local hit = workspace:Spherecast(from, 0.9, dir, castParams)
	if hit then
		return from + dir.Unit * math.max(1.5, hit.Distance - 0.2)
	end
	return to
end

function CameraController.init()
	refreshFilter()
	Net.event("CameraShake").OnClientEvent:Connect(CameraController.shake)

	RunService:BindToRenderStep("VesperdeepCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 70

		-- Free the mouse whenever a menu is open.
		if State.uiOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end

		local root = State.root
		if not root then
			return
		end

		local look = Input.consumeLook()
		if not State.uiOpen() then
			yaw -= look.X * MOUSE_SENS
			pitch -= look.Y * MOUSE_SENS
			local stick = Input.lookStick
			if stick.Magnitude > 0.15 then
				yaw -= stick.X * STICK_SENS * dt
				pitch -= stick.Y * STICK_SENS * 0.6 * dt
			end
		end

		-- Lock-on: steer toward keeping the target in front, slightly to the side.
		local target = State.lockTarget
		if target and target.Parent then
			local to = target.Position - root.Position
			local wantYaw = math.atan2(-to.X, -to.Z)
			local diff = (wantYaw - yaw + math.pi) % (2 * math.pi) - math.pi
			yaw += diff * math.min(1, dt * 6)
			local flat = Vector3.new(to.X, 0, to.Z).Magnitude
			local wantPitch = math.clamp(-math.atan2(math.max(0, root.Position.Y - target.Position.Y) + 4, flat + 6), math.rad(-40), math.rad(-5))
			pitch += (wantPitch - pitch) * math.min(1, dt * 3)
		end
		pitch = math.clamp(pitch, math.rad(-65), math.rad(45))

		local wantDistance = if State.bossFight then ARENA_DISTANCE else DISTANCE
		distance += (wantDistance - distance) * math.min(1, dt * 2)

		local wantFocus = root.Position + Vector3.new(0, 2.6, 0)
		if snapNext then
			focus = wantFocus
			snapNext = false
			refreshFilter()
		else
			local k = 1 - math.exp(-dt * 14)
			local ky = 1 - math.exp(-dt * 7)
			focus = Vector3.new(focus.X + (wantFocus.X - focus.X) * k, focus.Y + (wantFocus.Y - focus.Y) * ky, focus.Z + (wantFocus.Z - focus.Z) * k)
		end

		local cf
		if cinematic and os.clock() < cinematic.untilTime then
			local t = os.clock() - cinematic.startTime
			local c = cinematic.target
			local a = cinematic.startYaw + t * 0.35
			local eye = c + Vector3.new(math.sin(a) * 24, 7, math.cos(a) * 24)
			eye = collide(c + Vector3.new(0, 4, 0), eye)
			cf = CFrame.lookAt(eye, c + Vector3.new(0, 3, 0))
		else
			cinematic = nil
			local orbit = CFrame.new(focus) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			local desired = (orbit * CFrame.new(SHOULDER, 0, distance)).Position
			local eye = collide(focus, desired)
			cf = CFrame.lookAt(eye, (orbit * CFrame.new(SHOULDER, 0, 0)).Position)
		end

		if shakeAmount > 0.01 then
			local o = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shakeAmount * 1.2
			cf = cf + o
			shakeAmount *= math.exp(-dt * 8)
		end
		camera.CFrame = cf
		camera.Focus = CFrame.new(focus)
		State.cameraYaw = yaw
	end)
end

return CameraController
