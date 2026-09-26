-- Side-on camera that eases after the player, looks ahead, stays inside the current zone and can shake.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Net = require(Shared.Net)
local State = require(script.Parent.State)

local CameraController = {}

local focus = Vector3.zero
local lookahead = 0
local shakeAmount = 0
local snapNext = true

function CameraController.snap()
	snapNext = true
end

function CameraController.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

local function clampToZone(pos: Vector3, camera: Camera): Vector3
	local zone = State.zone
	if not zone then
		return pos
	end
	local minX, maxX, minY, maxY = Grid.bounds(zone)
	local halfH = Config.CAMERA_DISTANCE * math.tan(math.rad(camera.FieldOfView / 2))
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
		lookahead += (State.facing * Config.CAMERA_LOOKAHEAD - lookahead) * math.min(1, dt * 2.5)
		local target = clampToZone(root.Position + Vector3.new(lookahead, Config.CAMERA_HEIGHT, 0), camera)
		if snapNext then
			focus = target
			snapNext = false
		else
			local vy = target.Y - focus.Y
			-- Follow vertical movement a bit more lazily, like a hand-held storybook camera.
			local kx = 1 - math.exp(-dt * 7)
			local ky = 1 - math.exp(-dt * (if math.abs(vy) > 10 then 8 else 4))
			focus = Vector3.new(focus.X + (target.X - focus.X) * kx, focus.Y + vy * ky, 0)
		end
		local offset = Vector3.zero
		if shakeAmount > 0.01 then
			offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shakeAmount * 2
			shakeAmount *= math.exp(-dt * 7)
		end
		camera.CFrame = CFrame.new(focus + offset + Vector3.new(0, 0, Config.CAMERA_DISTANCE))
		camera.Focus = CFrame.new(focus)
	end)
end

return CameraController
