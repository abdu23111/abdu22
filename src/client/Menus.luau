-- Dialogue box (with the nailsmith's shop) and the charm menu shown while resting at benches.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Charms = require(Shared.Charms)
local Dialogue = require(Shared.Dialogue)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer

local Menus = {}

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

local function panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	props.BackgroundTransparency = 0.12
	return new("Frame", props, {
		new("UICorner", { CornerRadius = UDim.new(0, 10) }),
		new("UIStroke", { Color = Color3.fromRGB(200, 198, 214), Transparency = 0.55, Thickness = 1.5 }),
	})
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or TEXT
	return new("TextLabel", props)
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	props.Font = FONT
	props.TextSize = props.TextSize or 22
	props.TextColor3 = TEXT
	props.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
	props.AutoButtonColor = true
	local b = new("TextButton", props, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	b.Activated:Connect(onClick)
	return b
end

local function decodeSet(attr: string): { [string]: boolean }
	local raw = player:GetAttribute(attr)
	local set = {}
	if typeof(raw) == "string" then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(list) == "table" then
			for _, v in list do
				set[v] = true
			end
		end
	end
	return set
end

-- ===== Dialogue =====

local gui: ScreenGui
local dialogueFrame: Frame
local speakerName: TextLabel
local speakerTitle: TextLabel
local lineLabel: TextLabel
local hintLabel: TextLabel
local shopFrame: Frame
local shopText: TextLabel
local advanceSignal: BindableEvent
local talking = false
local talkEndedAt = 0

local function pickLines(npcId: string): ({ string }, any)
	local speaker = Dialogue[npcId]
	for _, set in speaker.sets do
		if set.when == nil or player:GetAttribute(set.when) == true then
			return set.lines, speaker
		end
	end
	return {}, speaker
end

local function openShop()
	shopFrame.Visible = true
	local level = (player:GetAttribute("NailLevel") or 1) :: number
	local cost = Config.NAIL_UPGRADE_COST[level]
	if cost then
		shopText.Text = string.format("Reforge your nail?  %d → %d damage\nCost: ◆ %d Geo", Config.NAIL_DAMAGE[level], Config.NAIL_DAMAGE[level + 1], cost)
	else
		shopText.Text = "\"That edge is perfect. Nothing left to teach it.\""
	end
end

local function runDialogue(npcId: string)
	if talking or not Dialogue[npcId] or os.clock() - talkEndedAt < 0.6 then
		return
	end
	talking = true
	ProximityPromptService.Enabled = false
	State.freeze("dialogue", true)
	local lines, speaker = pickLines(npcId)
	speakerName.Text = string.upper(speaker.name)
	speakerTitle.Text = speaker.title or ""
	dialogueFrame.Visible = true
	shopFrame.Visible = false
	task.wait(0.2)
	for _, line in lines do
		lineLabel.Text = line
		lineLabel.MaxVisibleGraphemes = 0
		local total = utf8.len(line) or #line
		local skipped = false
		local conn = advanceSignal.Event:Connect(function()
			skipped = true
		end)
		for i = 1, total do
			if skipped then
				break
			end
			lineLabel.MaxVisibleGraphemes = i
			task.wait(0.018)
		end
		conn:Disconnect()
		lineLabel.MaxVisibleGraphemes = -1
		hintLabel.Visible = true
		advanceSignal.Event:Wait()
		hintLabel.Visible = false
	end
	if speaker.shop then
		openShop()
		lineLabel.Text = ""
		advanceSignal.Event:Wait()
	end
	dialogueFrame.Visible = false
	shopFrame.Visible = false
	State.freeze("dialogue", false)
	talking = false
	talkEndedAt = os.clock()
	task.delay(0.4, function()
		if not talking then
			ProximityPromptService.Enabled = true
		end
	end)
end

-- ===== Charms =====

local charmFrame: Frame
local charmList: Frame
local notchLabel: TextLabel
local charmsOpen = false

local ORDER = { "swift_mantle", "long_reach", "soul_siphon", "ember_edge", "stone_heart", "quiet_focus" }

local function refreshCharms()
	if not charmFrame then
		return
	end
	local owned = decodeSet("CharmsOwned")
	local equipped = decodeSet("CharmsEquipped")
	local used = 0
	for id in equipped do
		used += Charms[id].cost
	end
	local notches = (player:GetAttribute("Notches") or Config.BASE_NOTCHES) :: number
	notchLabel.Text = string.format("Notches  %s%s", string.rep("● ", used), string.rep("○ ", math.max(0, notches - used)))
	for _, child in charmList:GetChildren() do
		if child:IsA("GuiButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, id in ORDER do
		local charm = Charms[id]
		local has = owned[id] == true
		local on = equipped[id] == true
		local row = new("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 58),
			BackgroundColor3 = if on then Color3.fromRGB(46, 44, 66) else Color3.fromRGB(20, 20, 30),
			BackgroundTransparency = 0.1,
			AutoButtonColor = has,
			Text = "",
			Parent = charmList,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			new("UIStroke", { Color = if on then charm.color else Color3.fromRGB(80, 80, 100), Transparency = if on then 0 else 0.5 }),
			new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 16), BackgroundColor3 = if has then charm.color else Color3.fromRGB(50, 50, 60), Rotation = 45 }),
			text({ Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -140, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, Text = if has then charm.name else "???" }),
			text({ Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -60, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextWrapped = true, TextColor3 = Color3.fromRGB(180, 178, 196), Text = if has then charm.description else "Somewhere in the kingdom..." }),
			text({ Position = UDim2.new(1, -90, 0, 4), Size = UDim2.fromOffset(80, 26), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18, Text = if has then (if on then "equipped  " else "") .. string.rep("●", charm.cost) else "" }),
		})
		if has then
			row.Activated:Connect(function()
				Net.event("EquipCharm"):FireServer(id, not on)
			end)
		end
	end
end

local function nearBench(): boolean
	local root = State.root
	if not root then
		return false
	end
	for _, model in workspace:WaitForChild("World"):GetDescendants() do
		if model:IsA("Model") and model.Name == "Bench" and model.PrimaryPart then
			if (model.PrimaryPart.Position - root.Position).Magnitude < 12 then
				return true
			end
		end
	end
	return false
end

local function setCharms(open: boolean)
	charmsOpen = open
	charmFrame.Visible = open
	State.freeze("charms", open)
	if open then
		refreshCharms()
	end
end

function Menus.init()
	gui = new("ScreenGui", { Name = "Menus", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui") })
	advanceSignal = Instance.new("BindableEvent")

	dialogueFrame = panel({ Visible = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.62, 0, 0, 170), Parent = gui })
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22), PaddingTop = UDim.new(0, 12), Parent = dialogueFrame })
	speakerName = text({ Size = UDim2.new(1, 0, 0, 30), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Parent = dialogueFrame })
	speakerTitle = text({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(170, 168, 190), Parent = dialogueFrame })
	lineLabel = text({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -70), TextSize = 23, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = dialogueFrame })
	hintLabel = text({ Visible = false, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -8), Size = UDim2.fromOffset(200, 20), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 150, 170), Text = "E / SPACE / CLICK ▸", Parent = dialogueFrame })

	shopFrame = panel({ Visible = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.62, 0, 0, 170), Parent = gui })
	shopText = text({ Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 70), TextSize = 24, TextWrapped = true, Parent = shopFrame })
	button({ Text = "Reforge", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -10, 1, -18), Size = UDim2.fromOffset(160, 44), Parent = shopFrame }, function()
		Net.event("BuyUpgrade"):FireServer()
		advanceSignal:Fire()
	end)
	button({ Text = "Leave", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 10, 1, -18), Size = UDim2.fromOffset(160, 44), Parent = shopFrame }, function()
		advanceSignal:Fire()
	end)

	charmFrame = panel({ Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 540), Parent = gui })
	text({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 36), TextSize = 34, Text = "CHARMS", Parent = charmFrame })
	notchLabel = text({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), TextSize = 20, Parent = charmFrame })
	charmList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 84), Size = UDim2.new(1, -40, 1, -150), Parent = charmFrame }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	button({ Text = "Rise from the bench", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(240, 42), Parent = charmFrame }, function()
		setCharms(false)
	end)

	for _, attr in { "CharmsOwned", "CharmsEquipped", "Notches" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshCharms)
	end

	Net.event("Dialogue").OnClientEvent:Connect(function(npcId: string)
		task.spawn(runDialogue, npcId)
	end)
	Net.event("BenchRest").OnClientEvent:Connect(function()
		HUD.notify("Rested", "Masks restored. Your spirit will return here.", "info")
		setCharms(true)
	end)
	Input.on("charms", function()
		if charmsOpen then
			setCharms(false)
		elseif nearBench() then
			setCharms(true)
		else
			HUD.notify("Charms", "Rest at a bench to change charms.", "info")
		end
	end)

	UserInputService.InputBegan:Connect(function(inputObj, processed)
		if not talking then
			if charmsOpen and (inputObj.KeyCode == Enum.KeyCode.Escape or inputObj.KeyCode == Enum.KeyCode.ButtonB) then
				setCharms(false)
			end
			return
		end
		local k = inputObj.KeyCode
		if k == Enum.KeyCode.E or k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
			advanceSignal:Fire()
		elseif not processed and (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch) then
			advanceSignal:Fire()
		end
	end)

end

return Menus
