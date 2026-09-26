-- Heads-up display: soul orb, masks, geo, boss health, notifications, area title cards,
-- the controls panel and the ending sequence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)

local player = Players.LocalPlayer

local HUD = {}

local TEXT = Color3.fromRGB(232, 230, 240)
local FONT = Enum.Font.Garamond

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: UDim?): UICorner
	return new("UICorner", { CornerRadius = radius or UDim.new(1, 0) })
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0.7
	return new("TextLabel", props)
end

local function fade(inst: GuiObject, target: number, duration: number)
	local goals: { [string]: any } = {}
	if inst:IsA("TextLabel") then
		goals.TextTransparency = target
		goals.TextStrokeTransparency = math.max(target, 0.7)
	elseif inst:IsA("Frame") then
		goals.BackgroundTransparency = target
	end
	TweenService:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Sine), goals):Play()
end

local gui: ScreenGui
local soulFill: Frame
local soulStroke: UIStroke
local maskRow: Frame
local geoLabel: TextLabel
local bossFrame: Frame
local bossName: TextLabel
local bossFill: Frame
local notifyTitle: TextLabel
local notifySub: TextLabel
local notifyToken = 0
local areaName: TextLabel
local areaSub: TextLabel
local areaLine: Frame
local areaToken = 0
local help: Frame

local function refreshMasks()
	local masks = (player:GetAttribute("Masks") or 0) :: number
	local maxMasks = (player:GetAttribute("MaxMasks") or Config.BASE_MASKS) :: number
	for _, child in maskRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i = 1, maxMasks do
		local full = i <= masks
		new("Frame", {
			Name = "Mask" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(22, 30),
			BackgroundColor3 = if full then Color3.fromRGB(240, 238, 232) else Color3.fromRGB(20, 20, 28),
			BackgroundTransparency = if full then 0 else 0.4,
			Parent = maskRow,
		}, {
			corner(UDim.new(0.5, 0)),
			new("UIStroke", { Color = Color3.fromRGB(200, 198, 210), Thickness = 1.5, Transparency = if full then 0.6 else 0.2 }),
		})
	end
end

local function refreshSoul()
	local soul = (player:GetAttribute("Soul") or 0) :: number
	local f = math.clamp(soul / Config.MAX_SOUL, 0, 1)
	TweenService:Create(soulFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(f, f) }):Play()
	soulStroke.Color = if soul >= Config.HEAL_COST then Color3.fromRGB(250, 250, 255) else Color3.fromRGB(140, 140, 160)
end

local lastGeo = 0
local function refreshGeo()
	local geo = (player:GetAttribute("Geo") or 0) :: number
	geoLabel.Text = "◆ " .. tostring(geo)
	if geo > lastGeo and HUD.onGeo then
		HUD.onGeo()
	end
	lastGeo = geo
end

function HUD.notify(title: string, subtitle: string?, kind: string?)
	notifyToken += 1
	local token = notifyToken
	local duration = if kind == "ability" then 6 elseif kind == "charm" then 5 else 3
	notifyTitle.Text = string.upper(title)
	notifyTitle.TextSize = if kind == "ability" then 40 else 30
	notifyTitle.TextColor3 = if kind == "ability" then Color3.fromRGB(255, 236, 190) elseif kind == "secret" then Color3.fromRGB(190, 230, 255) else TEXT
	notifySub.Text = subtitle or ""
	fade(notifyTitle, 0, 0.4)
	fade(notifySub, 0, 0.6)
	task.delay(duration, function()
		if token == notifyToken then
			fade(notifyTitle, 1, 0.8)
			fade(notifySub, 1, 0.8)
		end
	end)
end

function HUD.areaTitle(name: string, subtitle: string, kind: string?)
	areaToken += 1
	local token = areaToken
	if kind == "boss" then
		areaSub.Text = ""
		areaName.Text = string.upper(name)
		task.delay(0.1, function()
			areaSub.Text = subtitle
		end)
	elseif kind == "victory" then
		areaName.Text = string.upper(name)
		areaSub.Text = subtitle
	else
		areaName.Text = string.upper(name)
		areaSub.Text = subtitle
	end
	areaName.TextColor3 = if kind == "boss" then Color3.fromRGB(255, 225, 215) else TEXT
	fade(areaName, 0, 1.2)
	fade(areaSub, 0, 1.6)
	fade(areaLine, 0.3, 1.6)
	task.delay(if kind == "boss" then 3 else 3.5, function()
		if token == areaToken then
			fade(areaName, 1, 1.5)
			fade(areaSub, 1, 1.5)
			fade(areaLine, 1, 1.5)
		end
	end)
end

local function refreshBoss()
	local root = ReplicatedStorage:FindFirstChild("BossState")
	local shown = false
	if root then
		for _, folder in root:GetChildren() do
			if folder:GetAttribute("Active") and folder:GetAttribute("Zone") == State.zone then
				shown = true
				bossName.Text = string.upper(folder:GetAttribute("Name") or "")
				local hp = (folder:GetAttribute("Health") or 0) :: number
				local max = math.max(1, (folder:GetAttribute("MaxHealth") or 1) :: number)
				TweenService:Create(bossFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(hp / max, 1) }):Play()
			end
		end
	end
	bossFrame.Visible = shown
end

local function playEnding()
	local overlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 226, 170),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = gui,
	})
	TweenService:Create(overlay, TweenInfo.new(3, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.05 }):Play()
	task.wait(3)
	TweenService:Create(overlay, TweenInfo.new(4), { BackgroundColor3 = Color3.fromRGB(28, 22, 18) }):Play()
	local lines = {
		{ "The Great Lamp burns once more.", 34 },
		{ "Warmth runs through the tunnels like a remembered song.", 24 },
		{ "In the Burrows, in the Ruins, in the Hush, small shells stir and wake.", 24 },
		{ "And a lantern that was never lit glows softly, at last.", 24 },
		if player:GetAttribute("EchoDefeated")
			then { "Somewhere in the light, every bearer who turned back is remembered too.", 24 }
			else { "Far below, in the Hollowroot, something still waits to be remembered...", 22 },
		{ "VESPERDEEP", 64 },
		{ "Thank you for playing.", 22 },
	}
	for i, entry in lines do
		local l = label({
			Size = UDim2.new(1, -80, 0, entry[2] + 16),
			Position = UDim2.new(0.5, 0, 0.2 + i * 0.09, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = entry[1],
			TextSize = entry[2],
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(255, 236, 200),
			TextTransparency = 1,
			ZIndex = 21,
			Parent = overlay,
		})
		task.wait(2.2)
		fade(l, 0, 1.5)
	end
	task.wait(6)
	for _, child in overlay:GetChildren() do
		if child:IsA("TextLabel") then
			fade(child, 1, 2)
		end
	end
	TweenService:Create(overlay, TweenInfo.new(3), { BackgroundTransparency = 1 }):Play()
	task.wait(3.2)
	overlay:Destroy()
end

function HUD.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, Parent = player:WaitForChild("PlayerGui") })

	-- Soul orb + masks + geo
	local vitals = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(420, 110), Parent = gui })
	local orb = new("Frame", {
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		BackgroundTransparency = 0.25,
		Parent = vitals,
	}, { corner() })
	soulStroke = new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(140, 140, 160), Parent = orb })
	soulFill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.fromRGB(236, 238, 250),
		Parent = orb,
	}, { corner() })
	maskRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(100, 10), Size = UDim2.fromOffset(320, 32), Parent = vitals }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	geoLabel = label({ Position = UDim2.fromOffset(102, 48), Size = UDim2.fromOffset(200, 30), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Text = "◆ 0", Parent = vitals })

	-- Boss bar
	bossFrame = new("Frame", { Visible = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.5, 0, 0, 50), Parent = gui })
	bossName = label({ Size = UDim2.new(1, 0, 0, 28), TextSize = 26, Text = "", Parent = bossFrame })
	local bar = new("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(20, 18, 26), BackgroundTransparency = 0.2, Parent = bossFrame }, { corner(UDim.new(0, 4)) })
	bossFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(236, 226, 220), Parent = bar }, { corner(UDim.new(0, 4)) })

	-- Notifications
	notifyTitle = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.new(0.8, 0, 0, 44), TextSize = 30, TextTransparency = 1, Text = "", Parent = gui })
	notifySub = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.24, 26), Size = UDim2.new(0.6, 0, 0, 60), TextSize = 20, TextWrapped = true, TextTransparency = 1, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = gui })

	-- Area title card
	areaSub = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.8, 0, 0, 30), TextSize = 22, TextTransparency = 1, Text = "", Parent = gui })
	areaName = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.new(0.9, 0, 0, 70), TextSize = 58, TextTransparency = 1, Text = "", Parent = gui })
	areaLine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.43, 44), Size = UDim2.fromOffset(360, 2), BackgroundColor3 = TEXT, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })

	-- Controls panel
	help = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -24), Size = UDim2.fromOffset(380, 204), BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 0.35, Parent = gui }, {
		corner(UDim.new(0, 8)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingRight = UDim.new(0, 14) }),
	})
	label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Text = table.concat({
			"<b>WASD</b>   move      <b>MOUSE</b>   look      <b>T</b>   lock on",
			"<b>SPACE</b>   jump (hold for height)      <b>Q</b>   dodge roll",
			"<b>CLICK</b> / <b>J</b>   strike  ·  hold to charge (later)",
			"look up / down to strike up · pogo downward in the air",
			"<b>F</b> or <b>RIGHT-CLICK</b> (hold)   focus Soul to heal",
			"<b>SHIFT</b> dash   ·   <b>R</b> Lumen Bolt   (once found)",
			"<b>E</b>   talk / rest    <b>TAB</b>   charms    <b>M</b>   journal",
			"<b>H</b>   hide this panel",
		}, "\n"),
		Parent = help,
	})
	task.delay(30, function()
		help.Visible = false
	end)
	Input.on("help", function()
		help.Visible = not help.Visible
	end)

	for _, attr in { "Masks", "MaxMasks" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshMasks)
	end
	player:GetAttributeChangedSignal("Soul"):Connect(refreshSoul)
	player:GetAttributeChangedSignal("Geo"):Connect(refreshGeo)
	refreshMasks()
	refreshSoul()
	lastGeo = (player:GetAttribute("Geo") or 0) :: number
	refreshGeo()

	task.spawn(function()
		local root = ReplicatedStorage:WaitForChild("BossState")
		local function watch(folder: Instance)
			folder.AttributeChanged:Connect(refreshBoss)
		end
		for _, f in root:GetChildren() do
			watch(f)
		end
		root.ChildAdded:Connect(watch)
		while true do
			refreshBoss()
			task.wait(0.5)
		end
	end)

	Net.event("Notify").OnClientEvent:Connect(function(title: string, subtitle: string, kind: string)
		if kind == "ending" then
			task.spawn(playEnding)
			if HUD.onEnding then
				HUD.onEnding()
			end
		else
			HUD.notify(title, subtitle, kind)
		end
	end)
	Net.event("AreaTitle").OnClientEvent:Connect(function(name: string, subtitle: string, kind: string)
		HUD.areaTitle(name, subtitle, kind)
		if kind == "victory" and HUD.onVictory then
			HUD.onVictory()
		end
	end)
end

HUD.onEnding = nil :: (() -> ())?
HUD.onGeo = nil :: (() -> ())?
HUD.onVictory = nil :: (() -> ())?

return HUD
