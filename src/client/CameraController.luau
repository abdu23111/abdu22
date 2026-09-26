-- Side-on camera that eases after the player, looks ahead, stays inside the current zone,
-- pulls back during boss fights, lets you peek up and down, pans to bosses for their
-- introductions, and shakes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Net = require(Shared.Net)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local CameraController = {}

local focus = Vector3.zero
local lookahead = 0
local distance = Config.CAMERA_DISTANCE
local peek = 0
local stillTime = 0
local shakeAmount = 0
local snapNext = true
local cinematic: { target: Vector3, untilTime: number }? = nil

function CameraController.snap()
	snapNext = true
end

function CameraController.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

-- Hold the camera on a point for a while (boss introductions).
function CameraController.focusOn(target: Vector3, duration: number)
	cinematic = { target = target, untilTime = os.clock() + duration }
end

local function clampToZone(pos: Vector3, camera: Camera, dist: number): Vector3
	local zone = State.zone
	if not zone then
		return pos
	end
	local minX, maxX, minY, maxY = Grid.bounds(zone)
	local halfH = dist * math.tan(math.rad(camera.FieldOfView / 2))
	local viewport = camera.ViewportSize
	local halfW = halfH * (viewport.X / math.max(viewport.Y, 1))
	local x, y = pos.X, pos.Y
	if maxX - minX <= halfW * 2 then
		x = (minX + maxX) / 2
	else
		x = math.clamp(x, minX + halfW, maxX - halfW)
	end
	if maxY - minY <= halfH * 2 then
		y = (minY + maxY) / 2
	else
		y = math.clamp(y, minY + halfH, maxY - halfH)
	end
	return Vector3.new(x, y, 0)
end

function CameraController.init()
	local camera = workspace.CurrentCamera
	Net.event("CameraShake").OnClientEvent:Connect(CameraController.shake)

	RunService:BindToRenderStep("VesperdeepCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.CAMERA_FOV
		local root = State.root
		if not root then
			return
		end

		-- Peek: hold up or down while standing still.
		local vx = math.abs(root.AssemblyLinearVelocity.X)
		local wantPeek = 0
		if State.grounded and vx < 1 and not State.frozen() then
			stillTime += dt
			if stillTime > 0.45 then
				wantPeek = if Input.lookUp() then 1 elseif Input.lookDown() then -1 else 0
			end
		else
			stillTime = 0
		end
		peek += (wantPeek * Config.CAMERA_PEEK - peek) * math.min(1, dt * 3)

		local wantDistance = if State.bossFight then Config.CAMERA_ARENA_DISTANCE else Config.CAMERA_DISTANCE
		local target
		if cinematic and os.clock() < cinematic.untilTime then
			wantDistance = Config.CAMERA_DISTANCE * 0.8
			target = cinematic.target + Vector3.new(0, 2, 0)
		else
			cinematic = nil
			lookahead += (State.facing * Config.CAMERA_LOOKAHEAD - lookahead) * math.min(1, dt * 2.5)
			target = root.Position + Vector3.new(lookahead, Config.CAMERA_HEIGHT + peek, 0)
		end
		distance += (wantDistance - distance) * math.min(1, dt * 2)
		target = clampToZone(target, camera, distance)

		if snapNext then
			focus = target
			snapNext = false
		else
			local vy = target.Y - focus.Y
			local k = if cinematic then 3 else 7
			-- Follow vertical movement a bit more lazily, like a hand-held storybook camera.
			local kx = 1 - math.exp(-dt * k)
			local ky = 1 - math.exp(-dt * (if cinematic then 3 elseif math.abs(vy) > 10 then 8 else 4))
			focus = Vector3.new(focus.X + (target.X - focus.X) * kx, focus.Y + vy * ky, 0)
		end
		local offset = Vector3.zero
		if shakeAmount > 0.01 then
			offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakeAmount * 2
			shakeAmount *= math.exp(-dt * 7)
		end
		camera.CFrame = CFrame.new(focus + offset + Vector3.new(0, 0, distance))
		camera.Focus = CFrame.new(focus)
	end)
end

return CameraController
