-- Owns everything about a player's run: saved progress, masks/soul/geo, damage and death,
-- the Echo left behind on death, benches, pickups, charms, the nailsmith and NPC prompts.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Charms = require(Shared.Charms)
local Abilities = require(Shared.Abilities)
local Dialogue = require(Shared.Dialogue)
local Grid = require(Shared.Grid)
local Zones = require(Shared.Zones)
local Shop = require(Shared.Shop)
local Damageable = require(script.Parent.Damageable)
local Props = require(script.Parent.World.Props)

local make = Props.make

local PlayerService = {}
PlayerService.onRest = nil :: (() -> ())?
PlayerService.onHealBurst = nil :: ((Player) -> ())?

type Data = {
	geo: number,
	nailLevel: number,
	hearts: number,
	abilities: { [string]: boolean },
	charmsOwned: { [string]: boolean },
	charmsEquipped: { [string]: boolean },
	collected: { [string]: boolean },
	bosses: { [string]: boolean },
	bench: string?,
	echo: { x: number, y: number, geo: number }?,
	finished: boolean,
	memories: { [string]: boolean },
	switches: { [string]: boolean },
	visited: { [string]: boolean },
	bought: { [string]: boolean },
	extraNotches: number,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("Vesperdeep_v1")
	end)
	if ok then
		store = result
	end
end

local dataByPlayer: { [Player]: Data } = {}
local lastHurt: { [Player]: number } = {}
local lastHeal: { [Player]: number } = {}
local lastHazard: { [Player]: number } = {}
local dodgeUntil: { [Player]: number } = {}
local lastDodge: { [Player]: number } = {}
local dead: { [Player]: boolean } = {}
local benchCFrames: { [string]: CFrame } = {}
local echoFolder: Folder

local function newData(): Data
	return {
		geo = 0,
		nailLevel = 1,
		hearts = 0,
		abilities = {},
		charmsOwned = {},
		charmsEquipped = {},
		collected = {},
		bosses = {},
		bench = nil,
		echo = nil,
		finished = false,
		memories = {},
		switches = {},
		visited = {},
		bought = {},
		extraNotches = 0,
	}
end

function PlayerService.get(player: Player): Data?
	return dataByPlayer[player]
end

function PlayerService.hasCharm(player: Player, id: string): boolean
	local data = dataByPlayer[player]
	return data ~= nil and data.charmsEquipped[id] == true
end

function PlayerService.maxMasks(player: Player): number
	local data = dataByPlayer[player]
	if not data then
		return Config.BASE_MASKS
	end
	return Config.BASE_MASKS + data.hearts + (if data.charmsEquipped.stone_heart then 1 else 0)
end

function PlayerService.notches(player: Player): number
	local data = dataByPlayer[player]
	local defeated = 0
	if data then
		for _ in data.bosses do
			defeated += 1
		end
	end
	return Config.BASE_NOTCHES + defeated + (if data then data.extraNotches else 0)
end

local function setOf(t: { [string]: boolean }): string
	local list = {}
	for k, v in t do
		if v then
			table.insert(list, k)
		end
	end
	return HttpService:JSONEncode(list)
end

function PlayerService.sync(player: Player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	player:SetAttribute("Geo", data.geo)
	player:SetAttribute("NailLevel", data.nailLevel)
	player:SetAttribute("MaxMasks", PlayerService.maxMasks(player))
	player:SetAttribute("Notches", PlayerService.notches(player))
	for key, ability in Abilities do
		player:SetAttribute(ability.attribute, data.abilities[key] == true)
	end
	player:SetAttribute("FinalBossDefeated", data.finished)
	player:SetAttribute("CharmsOwned", setOf(data.charmsOwned))
	player:SetAttribute("CharmsEquipped", setOf(data.charmsEquipped))
	player:SetAttribute("Collected", setOf(data.collected))
	player:SetAttribute("Bosses", setOf(data.bosses))
	player:SetAttribute("EchoDefeated", data.bosses.echo == true)
	player:SetAttribute("Memories", setOf(data.memories))
	player:SetAttribute("Switches", setOf(data.switches))
	player:SetAttribute("Visited", setOf(data.visited))
	player:SetAttribute("Bought", setOf(data.bought))
	local masks = player:GetAttribute("Masks")
	if typeof(masks) == "number" then
		player:SetAttribute("Masks", math.min(masks, PlayerService.maxMasks(player)))
	end
end

function PlayerService.save(player: Player)
	local data = dataByPlayer[player]
	if not data or not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			(store :: DataStore):SetAsync("player_" .. player.UserId, data)
		end)
		if not ok then
			warn("[Vesperdeep] Save failed:", err)
		end
	end)
end

local function notify(player: Player, title: string, subtitle: string?, kind: string?)
	Net.event("Notify"):FireClient(player, title, subtitle or "", kind or "info")
end
PlayerService.notify = notify

-- ===== Rewards =====

function PlayerService.addGeo(player: Player, amount: number)
	local data = dataByPlayer[player]
	if data then
		data.geo += amount
		player:SetAttribute("Geo", data.geo)
	end
end

-- Geo from slain enemies, boosted by Deep Pockets.
function PlayerService.enemyGeo(player: Player, amount: number)
	if PlayerService.hasCharm(player, "deep_pockets") then
		amount = math.ceil(amount * 1.5)
	end
	PlayerService.addGeo(player, amount)
end

-- A lever or Lumen sigil was struck: open that zone's shortcut gates for this player.
function PlayerService.openSwitch(player: Player, zoneId: string)
	local data = dataByPlayer[player]
	if not data or data.switches[zoneId] then
		return
	end
	data.switches[zoneId] = true
	PlayerService.sync(player)
	notify(player, "Somewhere, a gate grinds open.", nil, "secret")
	PlayerService.save(player)
end

function PlayerService.addSoul(player: Player, base: number)
	local amount = if PlayerService.hasCharm(player, "soul_siphon") then math.floor(base * 1.5) else base
	local soul = (player:GetAttribute("Soul") or 0) :: number
	player:SetAttribute("Soul", math.min(Config.MAX_SOUL, soul + amount))
end

function PlayerService.grantAbility(player: Player, key: string)
	local data = dataByPlayer[player]
	local ability = Abilities[key]
	if not data or not ability or data.abilities[key] then
		return
	end
	data.abilities[key] = true
	PlayerService.sync(player)
	notify(player, ability.name, ability.hint, "ability")
	PlayerService.save(player)
end

function PlayerService.markBoss(player: Player, bossId: string, isFinal: boolean)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	data.bosses[bossId] = true
	if isFinal then
		data.finished = true
	end
	PlayerService.sync(player)
	PlayerService.save(player)
end

function PlayerService.hasDefeated(player: Player, bossId: string): boolean
	local data = dataByPlayer[player]
	return data ~= nil and data.bosses[bossId] == true
end

-- ===== Damage, death and the Echo =====

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end
PlayerService.rootOf = rootOf

local function spawnEcho(player: Player)
	local data = dataByPlayer[player]
	if not data or not data.echo then
		return
	end
	for _, old in echoFolder:GetChildren() do
		if old:GetAttribute("Owner") == player.UserId then
			old:Destroy()
		end
	end
	local echo = data.echo
	local model = make("Model", { Name = "Echo_" .. player.Name })
	model:SetAttribute("Owner", player.UserId)
	local body = make("Part", {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3.6, 3),
		Position = Vector3.new(echo.x, echo.y, 0),
		Anchored = true,
		CanCollide = false,
		Color = Color3.fromRGB(12, 10, 18),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		Parent = model,
	})
	make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.6, 1),
		Position = body.Position + Vector3.new(0, 0.9, 1.2),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Color = Color3.fromRGB(230, 230, 236),
		Parent = model,
	})
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(20, 16, 30)),
		Size = NumberSequence.new(2, 4),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(1, 2),
		Rate = 14,
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Parent = body,
	})
	make("BillboardGui", {
		Size = UDim2.fromOffset(160, 24),
		StudsOffset = Vector3.new(0, 3.4, 0),
		AlwaysOnTop = false,
		Parent = body,
	})
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = player.DisplayName .. "'s Echo",
		TextColor3 = Color3.fromRGB(200, 196, 220),
		Font = Enum.Font.Fantasy,
		TextScaled = true,
	})
	label.Parent = body:FindFirstChildOfClass("BillboardGui")
	model.PrimaryPart = body
	model.Parent = echoFolder

	Damageable.register(model, {
		onHit = function(striker: Player)
			if striker ~= player or not model.Parent then
				return false
			end
			local current = dataByPlayer[player]
			if current and current.echo then
				local geo = current.echo.geo
				current.echo = nil
				PlayerService.addGeo(player, geo)
				notify(player, "Echo Reclaimed", string.format("%d Geo returned", geo), "info")
				PlayerService.save(player)
			end
			model:Destroy()
			return true
		end,
	})
end

local function die(player: Player)
	if dead[player] then
		return
	end
	dead[player] = true
	local data = dataByPlayer[player]
	local root = rootOf(player)
	if data and root then
		if data.geo > 0 then
			data.echo = { x = root.Position.X, y = root.Position.Y, geo = data.geo }
			data.geo = 0
			player:SetAttribute("Geo", 0)
		end
	end
	player:SetAttribute("Soul", 0)
	Net.event("Died"):FireClient(player)
	PlayerService.save(player)
	task.delay(2.2, function()
		if player.Parent then
			spawnEcho(player)
			player:LoadCharacter()
		end
	end)
end

-- sourcePosition is used to decide which way the player is knocked back.
function PlayerService.damage(player: Player, amount: number, sourcePosition: Vector3?, hazard: boolean?)
	if dead[player] then
		return
	end
	local now = os.clock()
	local invuln = Config.INVULN_TIME + (if PlayerService.hasCharm(player, "mirror_shell") then 0.5 else 0)
	if not hazard and lastHurt[player] and now - lastHurt[player] < invuln then
		return
	end
	if not hazard and dodgeUntil[player] and now < dodgeUntil[player] then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	lastHurt[player] = now
	local masks = ((player:GetAttribute("Masks") or 0) :: number) - amount
	player:SetAttribute("Masks", math.max(0, masks))
	player:SetAttribute("LastHurt", now)
	if masks <= 0 then
		die(player)
		return
	end
	if hazard then
		Net.event("HazardRespawn"):FireClient(player)
	else
		local dirX = 1
		if sourcePosition then
			dirX = if root.Position.X >= sourcePosition.X then 1 else -1
		end
		Net.event("Knockback"):FireClient(player, dirX)
	end
end

-- ===== Character look =====

local function dressCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart
	local torso = (character:FindFirstChild("UpperTorso") or character:WaitForChild("Torso")) :: BasePart
	humanoid:RemoveAccessories()
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = Config.WALK_SPEED
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JUMP_VELOCITY

	for _, d in character:GetDescendants() do
		if d:IsA("Decal") and d.Name == "face" then
			d.Transparency = 1
		end
	end

	local function attach(p: BasePart, to: BasePart, offset: CFrame)
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = to.CFrame * offset
		make("WeldConstraint", { Part0 = to, Part1 = p, Parent = p })
		p.Parent = character
	end

	local white = Color3.fromRGB(238, 236, 230)
	attach(make("Part", { Name = "Mask", Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.8, 1.6), Color = white, Material = Enum.Material.SmoothPlastic }), head, CFrame.new(0, 0.1, 0))
	-- The camera sees the character side-on, so eyes sit on both flanks and the horns
	-- splay forward and back to read clearly in profile.
	for _, x in { -0.78, 0.78 } do
		attach(make("Part", { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.25, 0.62, 0.42), Color = Color3.fromRGB(8, 8, 12) }), head, CFrame.new(x, 0.05, -0.35))
	end
	for _, z in { -0.35, 0.35 } do
		attach(make("Part", { Name = "Horn", Size = Vector3.new(0.28, 1.4, 0.28), Color = white }), head, CFrame.new(0, 1.25, z) * CFrame.Angles(z * 1.2, 0, 0))
	end
	attach(make("Part", { Name = "Cloak", Size = Vector3.new(2.3, 3, 1.5), Color = Color3.fromRGB(34, 36, 58), Material = Enum.Material.Fabric }), torso, CFrame.new(0, -0.4, 0.55))

	local lantern = make("Part", { Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = Color3.fromRGB(255, 220, 170), Material = Enum.Material.Neon })
	attach(lantern, torso, CFrame.new(0, -0.9, -1.1))
	make("PointLight", { Range = 20, Brightness = 0.9, Color = Color3.fromRGB(255, 226, 190), Shadows = false, Parent = lantern })
end

local function spawnCFrame(player: Player): CFrame
	local data = dataByPlayer[player]
	if data and data.bench and benchCFrames[data.bench] then
		return benchCFrames[data.bench]
	end
	local start = workspace:WaitForChild("World"):GetAttribute("StartPosition")
	return CFrame.new(start or Vector3.new(20, 20, 0))
end

local function onCharacter(player: Player, character: Model)
	dead[player] = false
	player:SetAttribute("Masks", PlayerService.maxMasks(player))
	lastHurt[player] = os.clock()
	dressCharacter(character)
	local cf = spawnCFrame(player)
	task.defer(function()
		character:PivotTo(cf * CFrame.Angles(0, math.rad(-90), 0))
	end)
end

-- ===== Benches, NPCs, pickups, charms, shop =====

local function nearAny(player: Player, parts: { BasePart }, range: number): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, p in parts do
		if (p.Position - root.Position).Magnitude <= range then
			return true
		end
	end
	return false
end

local benchSeats: { BasePart } = {}
local tockParts: { BasePart } = {}
local lirraParts: { BasePart } = {}

local function rest(player: Player, benchId: string)
	local data = dataByPlayer[player]
	if not data or dead[player] then
		return
	end
	data.bench = benchId
	player:SetAttribute("Masks", PlayerService.maxMasks(player))
	PlayerService.save(player)
	if PlayerService.onRest then
		PlayerService.onRest()
	end
	Net.event("BenchRest"):FireClient(player, benchId)
end

local function collect(player: Player, pickup: BasePart)
	local data = dataByPlayer[player]
	if not data or dead[player] then
		return
	end
	local itemId = pickup:GetAttribute("ItemId") :: string
	if data.collected[itemId] then
		return
	end
	data.collected[itemId] = true
	local kind = pickup:GetAttribute("Kind")
	local id = pickup:GetAttribute("Id") :: string
	if kind == "charm" then
		data.charmsOwned[id] = true
		local charm = Charms[id]
		notify(player, charm.name, charm.description .. "  (Equip charms while resting at a bench.)", "charm")
	elseif kind == "heart" then
		data.hearts += 1
		PlayerService.sync(player)
		player:SetAttribute("Masks", PlayerService.maxMasks(player))
		notify(player, "Heart Husk", "Your shell hardens. +1 mask.", "charm")
	elseif kind == "memory" then
		data.memories[id] = true
		-- The vignette pauses the player; keep them safe while they read.
		dodgeUntil[player] = os.clock() + 8
		Net.event("Memory"):FireClient(player, id)
	elseif kind == "geo" then
		data.geo += (pickup:GetAttribute("Amount") or 50) :: number
		notify(player, "Geo Cache", string.format("+%d Geo", (pickup:GetAttribute("Amount") or 50) :: number), "info")
	end
	PlayerService.sync(player)
	PlayerService.save(player)
end

local function equipCharm(player: Player, charmId: unknown, equip: unknown)
	local data = dataByPlayer[player]
	if not data or typeof(charmId) ~= "string" or typeof(equip) ~= "boolean" then
		return
	end
	local charm = Charms[charmId]
	if not charm or not data.charmsOwned[charmId] then
		return
	end
	if not nearAny(player, benchSeats, 14) then
		notify(player, "Charms can only be changed while resting at a bench.", nil, "info")
		return
	end
	if equip then
		local used = 0
		for id in data.charmsEquipped do
			used += Charms[id].cost
		end
		if used + charm.cost > PlayerService.notches(player) then
			notify(player, "Not enough notches", nil, "info")
			return
		end
		data.charmsEquipped[charmId] = true
	else
		data.charmsEquipped[charmId] = nil
	end
	PlayerService.sync(player)
	PlayerService.save(player)
end

local function buyUpgrade(player: Player)
	local data = dataByPlayer[player]
	if not data or not nearAny(player, tockParts, 16) then
		return
	end
	local cost = Config.NAIL_UPGRADE_COST[data.nailLevel]
	if not cost then
		notify(player, "Your nail is already perfect.", "\"Nothing more I can teach that edge.\"", "info")
		return
	end
	if data.geo < cost then
		notify(player, "Not enough Geo", string.format("Brass Tock asks for %d Geo.", cost), "info")
		return
	end
	data.geo -= cost
	data.nailLevel += 1
	PlayerService.sync(player)
	PlayerService.save(player)
	notify(player, "Nail Reforged", string.format("Your nail now strikes for %d.", Config.NAIL_DAMAGE[data.nailLevel]), "ability")
end

function PlayerService.init(infos)
	echoFolder = make("Folder", { Name = "Echoes", Parent = workspace })
	for _, info in infos do
		for id, cf in info.benches do
			benchCFrames[id] = cf
		end
	end

	local world = workspace:WaitForChild("World")
	for _, inst in world:GetDescendants() do
		if inst:IsA("ProximityPrompt") then
			local model = inst:FindFirstAncestorWhichIsA("Model")
			local benchId = inst:GetAttribute("BenchId")
			if benchId then
				table.insert(benchSeats, inst.Parent :: BasePart)
				inst.Triggered:Connect(function(player)
					rest(player, benchId)
				end)
			elseif model and model:GetAttribute("NpcId") then
				local npcId = model:GetAttribute("NpcId") :: string
				if npcId == "tock" then
					table.insert(tockParts, inst.Parent :: BasePart)
				elseif npcId == "lirra" then
					table.insert(lirraParts, inst.Parent :: BasePart)
				end
				inst.Triggered:Connect(function(player)
					if Dialogue[npcId] then
						Net.event("Dialogue"):FireClient(player, npcId)
					end
				end)
			elseif model and model.Name == "Altar" then
				inst.Triggered:Connect(function(player)
					if not player:GetAttribute("FinalBossDefeated") then
						notify(player, "The lamp is cold.", "Something above still keeps it dark.", "info")
						return
					end
					local lamp = model:FindFirstChild("Lamp") :: BasePart
					lamp.Material = Enum.Material.Neon
					lamp.Color = Color3.fromRGB(255, 214, 150)
					local light = lamp:FindFirstChild("LampLight") :: PointLight
					light.Brightness = 4
					Net.event("Notify"):FireAllClients("The Great Lamp is Kindled", "Vesperdeep wakes from the Hush.", "ending")
				end)
			end
		elseif inst:IsA("BasePart") and inst.Name == "Pickup" then
			inst.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorWhichIsA("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					collect(player, inst)
				end
			end)
		elseif inst:IsA("BasePart") and inst.Name == "ThornHitbox" then
			inst.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorWhichIsA("Model")
				local player = character and Players:GetPlayerFromCharacter(character)
				if player and not dead[player] then
					local now = os.clock()
					if not lastHazard[player] or now - lastHazard[player] > 0.6 then
						lastHazard[player] = now
						PlayerService.damage(player, 1, nil, true)
					end
				end
			end)
		end
	end

	Net.event("EquipCharm").OnServerEvent:Connect(equipCharm)
	Net.event("BuyUpgrade").OnServerEvent:Connect(buyUpgrade)
	Net.event("Heal").OnServerEvent:Connect(function(player)
		local data = dataByPlayer[player]
		if not data or dead[player] then
			return
		end
		local now = os.clock()
		local healTime = Config.HEAL_TIME * (if data.charmsEquipped.quiet_focus then 0.6 else 1)
		if lastHeal[player] and now - lastHeal[player] < healTime * 0.8 then
			return
		end
		local soul = (player:GetAttribute("Soul") or 0) :: number
		local masks = (player:GetAttribute("Masks") or 0) :: number
		if soul < Config.HEAL_COST or masks >= PlayerService.maxMasks(player) then
			return
		end
		lastHeal[player] = now
		player:SetAttribute("Soul", soul - Config.HEAL_COST)
		player:SetAttribute("Masks", masks + 1)
		if data.charmsEquipped.kindled_spirit and PlayerService.onHealBurst then
			PlayerService.onHealBurst(player)
		end
	end)

	Net.event("Dodge").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if dead[player] or (lastDodge[player] and now - lastDodge[player] < Config.DODGE_COOLDOWN * 0.8) then
			return
		end
		lastDodge[player] = now
		local extra = if PlayerService.hasCharm(player, "mirror_shell") then 1.6 else 1
		-- A little latency allowance on top of the sidestep itself.
		dodgeUntil[player] = now + Config.DODGE_INVULN * extra + 0.08
	end)

	Net.event("EnterZone").OnServerEvent:Connect(function(player, index: unknown)
		local data = dataByPlayer[player]
		if not data or typeof(index) ~= "number" or PlayerService.zoneOf(player) ~= index then
			return
		end
		local zone = Zones[index]
		if zone and not data.visited[zone.id] then
			data.visited[zone.id] = true
			PlayerService.sync(player)
			PlayerService.save(player)
		end
	end)

	Net.event("BuyWare").OnServerEvent:Connect(function(player, wareId: unknown)
		local data = dataByPlayer[player]
		if not data or typeof(wareId) ~= "string" or not nearAny(player, lirraParts, 16) then
			return
		end
		local ware
		for _, w in Shop do
			if w.id == wareId then
				ware = w
			end
		end
		if not ware or data.bought[ware.id] then
			return
		end
		if data.geo < ware.price then
			notify(player, "Not enough Geo", string.format("Lirra wants %d Geo for that.", ware.price), "info")
			return
		end
		data.geo -= ware.price
		data.bought[ware.id] = true
		if ware.kind == "charm" then
			data.charmsOwned[ware.charm :: string] = true
		elseif ware.kind == "heart" then
			data.hearts += 1
		elseif ware.kind == "notch" then
			data.extraNotches += 1
		end
		PlayerService.sync(player)
		if ware.kind == "heart" then
			player:SetAttribute("Masks", PlayerService.maxMasks(player))
		end
		notify(player, ware.name, ware.description, "charm")
		PlayerService.save(player)
	end)

	local function onPlayer(player: Player)
		local data = newData()
		if store then
			local ok, saved = pcall(function()
				return (store :: DataStore):GetAsync("player_" .. player.UserId)
			end)
			if ok and type(saved) == "table" then
				for k, v in saved do
					(data :: any)[k] = v
				end
			elseif not ok then
				warn("[Vesperdeep] Could not load save (enable Studio API access to test saving):", saved)
			end
		end
		dataByPlayer[player] = data
		player:SetAttribute("Soul", 0)
		PlayerService.sync(player)
		if data.echo then
			spawnEcho(player)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		player:LoadCharacter()
	end

	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerService.save(player)
		for _, echo in echoFolder:GetChildren() do
			if echo:GetAttribute("Owner") == player.UserId then
				echo:Destroy()
			end
		end
		task.defer(function()
			dataByPlayer[player] = nil
			lastHurt[player] = nil
			lastHeal[player] = nil
			lastHazard[player] = nil
			dead[player] = nil
			dodgeUntil[player] = nil
			lastDodge[player] = nil
		end)
	end)
	game:BindToClose(function()
		if not store then
			return
		end
		for player, data in dataByPlayer do
			pcall(function()
				(store :: DataStore):SetAsync("player_" .. player.UserId, data)
			end)
		end
	end)
end

-- Which zone index a player is currently in (by position).
function PlayerService.zoneOf(player: Player): number?
	local root = rootOf(player)
	return root and Grid.zoneAt(root.Position)
end

return PlayerService
