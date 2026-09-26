local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local hp = Instance.new("IntValue")
	hp.Name = "HP"
	hp.Value = Config.StartingHP
	hp.Parent = leaderstats
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

while true do
	task.wait(Config.TickSeconds)
	for _, player in Players:GetPlayers() do
		local leaderstats = player:FindFirstChild("leaderstats")
		local hp = leaderstats and leaderstats:FindFirstChild("HP")
		if hp then
			hp.Value += Config.HPPerTick
		end
	end
end
