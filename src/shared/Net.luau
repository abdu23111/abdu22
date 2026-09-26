--!strict
-- Tiny RemoteEvent registry. The server creates remotes on demand; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

Net.NAMES = {
	-- client -> server
	"Attack",
	"Heal",
	"EquipCharm",
	"BuyUpgrade",
	"BuyWare",
	"Bolt",
	"Dodge",
	"EnterZone",
	"Spell",
	"Travel",
	-- server -> client
	"Knockback",
	"HazardRespawn",
	"Notify",
	"AreaTitle",
	"Dialogue",
	"BenchRest",
	"Died",
	"Hit",
	"CameraShake",
	"Memory",
	"BossIntro",
	"BossPhase",
	"Flash",
}

function Net.event(name: string): RemoteEvent
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

if RunService:IsServer() then
	for _, name in Net.NAMES do
		Net.event(name)
	end
end

return Net
