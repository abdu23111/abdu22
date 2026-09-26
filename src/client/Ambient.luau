-- Makes the scenery feel alive without touching anything solid: vines and roots sway from
-- their tops, crystals, fungus and mushroom gills pulse softly, candles and lanterns flicker,
-- crystal light breathes, and every so often a pebble drops from the ceiling somewhere on
-- screen. Only decoration near the camera in the current region is animated, a few dozen
-- times a second, so it stays cheap on every device.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local Ambient = {}

local RADIUS = 110 -- studs from the camera's focus
local RATE = 1 / 30

type Sway = { model: Model, pivot: CFrame, amp: number, phase: number, speed: number }
type Pulse = { part: BasePart, base: number, phase: number, speed: number }
type Glow = { light: PointLight, base: number, phase: number, flicker: boolean }

local sways: { Sway } = {}
local pulses: { Pulse } = {}
local glows: { Glow } = {}
local collectedZone: number? = nil

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local function collect(zoneIndex: number)
	table.clear(sways)
	table.clear(pulses)
	table.clear(glows)
	collectedZone = zoneIndex
	local world = workspace:FindFirstChild("World")
	local zone = Zones[zoneIndex]
	local folder = world and world:FindFirstChild("Zone_" .. zone.id)
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Sway") then
			table.insert(sways, { model = d, pivot = d:GetPivot(), amp = d:GetAttribute("Sway") :: number, phase = math.random() * 6.28, speed = 0.6 + math.random() * 0.5 })
		elseif d:IsA("BasePart") and d:GetAttribute("Pulse") then
			table.insert(pulses, { part = d, base = d.Transparency, phase = math.random() * 6.28, speed = 0.8 + math.random() * 0.8 })
		elseif d:IsA("PointLight") and (d:GetAttribute("Flicker") or d:GetAttribute("Pulse")) then
			table.insert(glows, { light = d, base = d.Brightness, phase = math.random() * 100, flicker = d:GetAttribute("Flicker") == true })
		end
	end
end

local function near(p: Vector3, cx: number, cy: number): boolean
	return math.abs(p.X - cx) < RADIUS and math.abs(p.Y - cy) < RADIUS * 0.7
end

-- A pebble shaken loose from somewhere on screen.
local function dropPebble(cx: number, cy: number)
	if Fx.busy() then
		return
	end
	local x = cx + (math.random() - 0.5) * 70
	local z = -(2 + math.random() * 8)
	local from = Vector3.new(x, cy, z)
	local up = workspace:Raycast(from, Vector3.new(0, 70, 0), terrainParams)
	if not up then
		return
	end
	local top = up.Position - Vector3.new(0, 0.4, 0)
	local down = workspace:Raycast(top, Vector3.new(0, -120, 0), terrainParams)
	if not down or top.Y - down.Position.Y < 10 then
		return
	end
	local s = 0.25 + math.random() * 0.3
	local pebble = Fx.part({
		Size = Vector3.new(s, s * 0.8, s),
		CFrame = CFrame.new(top) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		Color = Color3.fromRGB(120, 112, 108),
		Material = Enum.Material.Slate,
	})
	local t = math.sqrt(2 * (top.Y - down.Position.Y) / workspace.Gravity) * 1.1
	TweenService:Create(pebble, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(down.Position + Vector3.new(0, s * 0.4, 0)) * CFrame.Angles(math.random() * 6, 0, 0) }):Play()
	task.delay(t, function()
		if pebble.Parent then
			Fx.puff(down.Position + Vector3.new(0, 0.2, 0), Color3.fromRGB(150, 145, 140), 0.8, 0.3)
			Fx.fade(pebble, 0.5)
		end
	end)
end

function Ambient.init()
	local acc = 0
	local nextPebble = os.clock() + 3
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < RATE then
			return
		end
		acc = 0
		local zone = State.zone
		if not zone then
			return
		end
		if zone ~= collectedZone then
			collect(zone)
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.Focus.Position
		local cx, cy = focus.X, focus.Y
		local t = os.clock()

		for _, sw in sways do
			if sw.model.Parent and near(sw.pivot.Position, cx, cy) then
				local a = math.sin(t * sw.speed + sw.phase) * sw.amp
				local b = math.sin(t * sw.speed * 0.7 + sw.phase * 1.7) * sw.amp * 0.5
				sw.model:PivotTo(sw.pivot * CFrame.Angles(b, 0, a))
			end
		end
		for _, pu in pulses do
			local part = pu.part
			if part.Parent and near(part.Position, cx, cy) then
				local k = 0.5 + 0.5 * math.sin(t * pu.speed + pu.phase)
				part.Transparency = math.clamp(pu.base + (1 - pu.base) * 0.4 * k, 0, 0.95)
			end
		end
		for _, g in glows do
			local light = g.light
			local host = light.Parent
			if host and host:IsA("BasePart") and near(host.Position, cx, cy) then
				if g.flicker then
					light.Brightness = g.base * (0.82 + 0.3 * math.noise(t * 7, g.phase))
				else
					light.Brightness = g.base * (0.8 + 0.2 * math.sin(t * 1.2 + g.phase))
				end
			end
		end
		if Config.SIDE_VIEW and t >= nextPebble then
			nextPebble = t + 2.5 + math.random() * 3.5
			dropPebble(cx, cy)
		end
	end)
end

return Ambient
