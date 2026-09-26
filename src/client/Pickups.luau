-- Makes pickups bob and spin, and fades out ones this player has already collected.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Pickups = {}

type Entry = { part: BasePart, base: CFrame, phase: number }

function Pickups.init()
	local entries: { Entry } = {}
	for _, inst in workspace:WaitForChild("World"):GetDescendants() do
		if inst:IsA("BasePart") and inst.Name == "Pickup" then
			table.insert(entries, { part = inst, base = CFrame.new(inst.Position), phase = math.random() * 6 })
		end
	end

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
			local got = collected[e.part:GetAttribute("ItemId")] == true
			e.part.LocalTransparencyModifier = if got then 0.9 else 0
			for _, child in e.part:GetChildren() do
				if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
					child.Enabled = not got
				end
			end
		end
	end
	player:GetAttributeChangedSignal("Collected"):Connect(refresh)
	refresh()

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
