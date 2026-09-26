-- Opens shortcut gates for this player once they've struck the lever or Lumen sigil in that
-- zone. Gates are only opened locally: the character is simulated on this client, so a
-- gate that is passable here is passable for this player, while it stays shut for others.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Shortcuts = {}

local function openedSet(): { [string]: boolean }
	local set = {}
	local raw = player:GetAttribute("Switches")
	if typeof(raw) == "string" then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(list) == "table" then
			for _, id in list do
				set[id] = true
			end
		end
	end
	return set
end

local function refresh()
	local opened = openedSet()
	for _, inst in workspace:WaitForChild("World"):GetDescendants() do
		if inst:IsA("BasePart") and inst.Name == "ShortcutGate" then
			local open = opened[inst:GetAttribute("Switch")] == true
			inst.CanCollide = not open
			inst.LocalTransparencyModifier = if open then 1 else 0
			for _, child in inst:GetDescendants() do
				if child:IsA("BasePart") then
					child.LocalTransparencyModifier = if open then 1 else 0
				end
			end
		elseif inst:IsA("BasePart") and inst.Name == "Switch" then
			local open = opened[inst:GetAttribute("Zone")] == true
			if open then
				inst.Color = Color3.fromRGB(120, 120, 130)
				if inst:GetAttribute("Kind") == "lever" then
					inst.CFrame = CFrame.new(inst.Position) * CFrame.Angles(0, 0, math.rad(25))
				end
				local light = inst:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = false
				end
			end
		end
	end
end

function Shortcuts.init()
	local Sfx = require(script.Parent.Sfx)
	player:GetAttributeChangedSignal("Switches"):Connect(function()
		Sfx.play("lever")
		refresh()
	end)
	refresh()
end

return Shortcuts
