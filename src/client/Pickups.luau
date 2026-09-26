-- Makes pickups bob and spin, and fades out ones this player has already collected.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Fx = require(script.Parent.Fx)

local Pickups = {}

type Entry = { part: BasePart, base: CFrame, phase: number }

function Pickups.init()
	local entries: { Entry } = {}
	for _, inst in workspace:WaitForChild("World"):GetDescendants() do
		if inst:IsA("BasePart") and inst.Name == "Pickup" then
			table.insert(entries, { part = inst, base = CFrame.new(inst.Position), phase = math.random() * 6 })
		end
	end

	local seen: { [string]: boolean }? = nil
	local function refresh()
		local collected = {}
		local raw = player:GetAttribute("Collected")
		if typeof(raw) == "string" then
			local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok then
				for _, id in list do
					collected[id] = true
				end
			end
		end
		for _, e in entries do
			local id = e.part:GetAttribute("ItemId")
			local got = collected[id] == true
			-- A discovery: a burst of light where the item was, the first time it's taken.
			if got and seen and not seen[id] then
				local at = e.part.Position
				Fx.glitter(at, e.part.Color:Lerp(Color3.new(1, 1, 1), 0.3), 40, 3)
				Fx.ring(at - Vector3.new(0, 2, 0), e.part.Color, 9, 0.7, 0.3)
				Fx.light(at, e.part.Color, 30, 4, 0.8)
				local column = Fx.part({ Size = Vector3.new(1.2, 30, 1.2), Position = at + Vector3.new(0, 14, 0), Color = e.part.Color:Lerp(Color3.new(1, 1, 1), 0.5), Transparency = 0.3 })
				Fx.fade(column, 0.9, { Size = Vector3.new(0.1, 40, 0.1) })
			end
			e.part.LocalTransparencyModifier = if got then 0.9 else 0
			for _, child in e.part:GetChildren() do
				if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
					child.Enabled = not got
				end
			end
		end
	end
	player:GetAttributeChangedSignal("Collected"):Connect(function()
		refresh()
		seen = {}
		for _, e in entries do
			if e.part.LocalTransparencyModifier > 0.5 then
				(seen :: any)[e.part:GetAttribute("ItemId")] = true
			end
		end
	end)
	refresh()
	seen = {}
	for _, e in entries do
		if e.part.LocalTransparencyModifier > 0.5 then
			(seen :: any)[e.part:GetAttribute("ItemId")] = true
		end
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, e in entries do
			if e.part.Parent then
				e.part.CFrame = e.base * CFrame.new(0, math.sin(t * 2 + e.phase) * 0.35, 0) * CFrame.Angles(0, t * 1.5, math.rad(45))
			end
		end
	end)
end

return Pickups
