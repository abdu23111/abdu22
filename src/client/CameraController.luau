-- Side-view camera. Looks straight at the play plane from the front, leads a little in the
-- direction you face, lets you peek up/down while standing still, pulls back for boss fights,
-- stays inside the current region's bounds, pans for boss introductions, and shakes on impact.
-- Distant layers (the back wall and the vistas behind it) drift with natural parallax because
-- the camera is a real perspective camera looking into a deep scene.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Grid = require(Shared.Grid)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local CameraController = {}
CameraController.onModeChanged = nil :: ((string) -> ())?

local focus = Vector3.zero
local lead = 0
local peek = 0
local distance = Config.CAMERA_DISTANCE
local shakeAmount = 0
local snapNext = true
local stillSince = 0
local cinematic: { target: Vector3, startTime: number, untilTime: number }? = nil

function CameraController.snap()
	snapNext = true
end

function CameraController.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

-- Kept for callers written for the free camera; the side view has no yaw.
function CameraController.yaw(): number
	return 0
end
function CameraController.faceDirection(_dir: Vector3) end
function CameraController.mode(): string
	return "side"
end
function CameraController.setMode(_mode: string) end

-- Pan to a point and hold there for a while (boss introductions).
function CameraController.focusOn(target: Vector3, duration: number)
	cinematic = { target = target, startTime = os.clock(), untilTime = os.clock() + duration }
end

local function halfExtents(dist: number): (number, number)
	local camera = workspace.CurrentCamera
	local vfov = math.rad(Config.CAMERA_FOV)
	local halfH = math.tan(vfov / 2) * dist
	local aspect = if camera then camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y) else 16 / 9
	return halfH * aspect, halfH
end

function CameraController.init()
	Net.event("CameraShake").OnClientEvent:Connect(CameraController.shake)

	RunService:BindToRenderStep("VesperdeepCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.CAMERA_FOV
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		Input.consumeLook()
		State.cameraYaw = 0

		local root = State.root
		if not root then
			return
		end
		local now = os.clock()

		-- Lead toward where you're facing, a little more when running.
		local wantLead = State.facingVector.X * Config.CAMERA_LOOKAHEAD * (if State.moveSpeed > 4 then 1.3 else 1)
		lead += (wantLead - lead) * math.min(1, dt * 2.5)

		-- Hold up or down while standing still to peek.
		if State.moveSpeed < 1 and State.grounded then
			if stillSince == 0 then
				stillSince = now
			end
		else
			stillSince = 0
		end
		local wantPeek = 0
		if stillSince > 0 and now - stillSince > 0.35 then
			if Input.lookUp() then
				wantPeek = Config.CAMERA_PEEK
			elseif Input.lookDown() then
				wantPeek = -Config.CAMERA_PEEK
			end
		end
		peek += (wantPeek - peek) * math.min(1, dt * 3)

		local wantDistance = if State.bossFight then Config.CAMERA_ARENA_DISTANCE else Config.CAMERA_DISTANCE
		distance += (wantDistance - distance) * math.min(1, dt * 1.5)

		local wantFocus = Vector3.new(root.Position.X + lead, root.Position.Y + Config.CAMERA_HEIGHT + peek, 0)
		if cinematic and now < cinematic.untilTime then
			wantFocus = Vector3.new(cinematic.target.X, cinematic.target.Y + 2, 0)
		else
			cinematic = nil
		end

		-- Stay inside the current region so the view never shows the void past its ends.
		if State.zone and not cinematic then
			local minX, maxX, minY, maxY = Grid.bounds(State.zone)
			local hw, hh = halfExtents(distance)
			if maxX - minX > hw * 2 then
				wantFocus = Vector3.new(math.clamp(wantFocus.X, minX + hw, maxX - hw), wantFocus.Y, 0)
			end
			if maxY - minY > hh * 2 then
				wantFocus = Vector3.new(wantFocus.X, math.clamp(wantFocus.Y, minY + hh, maxY - hh), 0)
			end
		end

		if snapNext then
			focus = wantFocus
			snapNext = false
		else
			-- Horizontal follow is snappy; vertical is softer, but catches up quickly on long falls.
			local kx = 1 - math.exp(-dt * (if cinematic then 2.5 else 7))
			local fallBoost = if root.AssemblyLinearVelocity.Y < -60 then 10 else 4
			local ky = 1 - math.exp(-dt * (if cinematic then 2.5 else fallBoost))
			focus = Vector3.new(focus.X + (wantFocus.X - focus.X) * kx, focus.Y + (wantFocus.Y - focus.Y) * ky, 0)
		end

		local dist = if cinematic then distance * 0.8 else distance
		local eye = focus + Vector3.new(0, dist * 0.06, dist)
		local cf = CFrame.lookAt(eye, focus)
		if shakeAmount > 0.01 then
			local t = now * 40
			local o = Vector3.new(math.noise(t, 0.3), math.noise(0.7, t), 0) * shakeAmount * 1.4
			cf = cf + o
			shakeAmount *= math.exp(-dt * 9)
		end
		camera.CFrame = cf
		camera.Focus = CFrame.new(focus)
	end)
end

return CameraController
