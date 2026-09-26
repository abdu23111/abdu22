-- The Journal (press M): a map of the regions you've visited, your abilities and progress,
-- and every memory you've recovered. With the Wayfarer's Compass equipped, the map also
-- shows where you are.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Themes = require(Shared.Themes)
local Grid = require(Shared.Grid)
local Abilities = require(Shared.Abilities)
local Memories = require(Shared.Memories)
local Charms = require(Shared.Charms)
local State = require(script.Parent.State)
local Input = require(script.Parent.Input)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local Journal = {}

local FONT = Enum.Font.Garamond
local TEXT = Color3.fromRGB(232, 230, 240)
local PX = 1.6 -- map pixels per tile
local CELL = Vector2.new(120, 70) -- map pixels per mapPosition unit

local gui: ScreenGui
local root: Frame
local pages: { [string]: Frame } = {}
local tabs: { [string]: TextButton } = {}
local mapCanvas: Frame
local playerDot: Frame
local memoryText: TextLabel
local open = false
local current = "map"

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

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or TEXT
	return new("TextLabel", props)
end

local function decodeSet(attr: string): { [string]: boolean }
	local set = {}
	local raw = player:GetAttribute(attr)
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

-- Greedy rectangles of open (non-solid) tiles, so each room is a handful of frames.
local function openRects(map: { string })
	local h, w = #map, #map[1]
	local used = {}
	local function isOpen(r, c)
		local ch = string.sub(map[r], c, c)
		return ch ~= "#" and ch ~= "%" and ch ~= "Y" and ch ~= "X"
	end
	local rects = {}
	for r = 1, h do
		used[r] = used[r] or {}
		for c = 1, w do
			if not used[r][c] and isOpen(r, c) then
				local c2 = c
				while c2 + 1 <= w and not used[r][c2 + 1] and isOpen(r, c2 + 1) do
					c2 += 1
				end
				local r2 = r
				while r2 + 1 <= h do
					used[r2 + 1] = used[r2 + 1] or {}
					local ok = true
					for cc = c, c2 do
						if used[r2 + 1][cc] or not isOpen(r2 + 1, cc) then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					r2 += 1
				end
				for rr = r, r2 do
					used[rr] = used[rr] or {}
					for cc = c, c2 do
						used[rr][cc] = true
					end
				end
				table.insert(rects, { c, r, c2, r2 })
			end
		end
	end
	return rects
end

local function zoneOrigin(zone): Vector2
	return Vector2.new(zone.mapPosition.X * CELL.X, zone.mapPosition.Y * CELL.Y)
end

local function drawMap()
	for _, child in mapCanvas:GetChildren() do
		if child ~= playerDot and not child:IsA("UIScale") then
			child:Destroy()
		end
	end
	local visited = decodeSet("Visited")
	local bosses = decodeSet("Bosses")
	if State.zone then
		visited[Zones[State.zone].id] = true
	end
	for _, zone in Zones do
		if visited[zone.id] then
			local theme = Themes[zone.theme]
			local origin = zoneOrigin(zone)
			local w, h = #zone.map[1], #zone.map
			local box = new("Frame", {
				Position = UDim2.fromOffset(origin.X, origin.Y),
				Size = UDim2.fromOffset(w * PX, h * PX),
				BackgroundColor3 = Color3.fromRGB(16, 16, 22),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Parent = mapCanvas,
			}, {
				new("UIStroke", { Color = theme.accent, Transparency = 0.5, Thickness = 1 }),
			})
			for _, rect in openRects(zone.map) do
				new("Frame", {
					Position = UDim2.fromOffset((rect[1] - 1) * PX, (rect[2] - 1) * PX),
					Size = UDim2.fromOffset((rect[3] - rect[1] + 1) * PX, (rect[4] - rect[2] + 1) * PX),
					BackgroundColor3 = theme.rim:Lerp(Color3.new(1, 1, 1), 0.2),
					BackgroundTransparency = 0.55,
					BorderSizePixel = 0,
					Parent = box,
				})
			end
			for r, line in zone.map do
				for c = 1, #line do
					local ch = string.sub(line, c, c)
					local icon: Color3? = nil
					local size = 6
					if ch == "B" or ch == "S" then
						icon = Color3.fromRGB(255, 210, 130)
					elseif string.match(ch, "%d") then
						icon, size = Color3.fromRGB(255, 255, 255), 4
					elseif ch == "K" then
						icon, size = if bosses[zone.specials.K.id :: string] then Color3.fromRGB(110, 110, 120) else Color3.fromRGB(230, 70, 80), 8
					end
					if icon then
						new("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromOffset((c - 0.5) * PX, (r - 0.5) * PX),
							Size = UDim2.fromOffset(size, size),
							BackgroundColor3 = icon,
							BorderSizePixel = 0,
							Rotation = 45,
							Parent = box,
						})
					end
				end
			end
			text({
				Position = UDim2.fromOffset(origin.X, origin.Y - 20),
				Size = UDim2.fromOffset(w * PX, 18),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = theme.accent:Lerp(Color3.new(1, 1, 1), 0.4),
				Text = string.upper(zone.name),
				Parent = mapCanvas,
			})
		end
	end
end

local function updatePlayerDot()
	local hasCompass = State.hasCharm("wayfarer_compass")
	local rootPart = State.root
	if not hasCompass or not rootPart or not State.zone then
		playerDot.Visible = false
		return
	end
	local zone = Zones[State.zone]
	local minX, _, _, maxY = Grid.bounds(State.zone)
	local col = (rootPart.Position.X - minX) / Config.TILE
	local row = (maxY - rootPart.Position.Y) / Config.TILE
	local origin = zoneOrigin(zone)
	playerDot.Visible = true
	playerDot.Position = UDim2.fromOffset(origin.X + col * PX, origin.Y + row * PX)
	playerDot.ZIndex = 5
end

local function drawAbilities(page: Frame)
	for _, child in page:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local list = {}
	for key, ability in Abilities do
		table.insert(list, { key = key, ability = ability })
	end
	table.sort(list, function(a, b)
		return a.ability.order < b.ability.order
	end)
	local function row(order: number, title: string, body: string, have: boolean)
		new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = if have then Color3.fromRGB(34, 32, 48) else Color3.fromRGB(18, 18, 24),
			BackgroundTransparency = 0.15,
			Parent = page,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 6) }),
			text({ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 26), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = if have then title else "???" }),
			text({ Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 26), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = Color3.fromRGB(180, 178, 196), Text = if have then body else "Not yet found." }),
		})
	end
	row(0, "Sidestep", "Press Q to hop aside. Brief protection from harm.", true)
	for i, entry in list do
		row(i, entry.ability.name, entry.ability.hint, player:GetAttribute(entry.ability.attribute) == true)
	end
	local memories, totalMemories = 0, 0
	local found = decodeSet("Memories")
	for id in Memories do
		totalMemories += 1
		if found[id] then
			memories += 1
		end
	end
	local owned, totalCharms = 0, 0
	local charms = decodeSet("CharmsOwned")
	for id in Charms do
		totalCharms += 1
		if charms[id] then
			owned += 1
		end
	end
	local bosses = 0
	for _ in decodeSet("Bosses") do
		bosses += 1
	end
	text({
		LayoutOrder = 20,
		Size = UDim2.new(1, 0, 0, 90),
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format(
			"Masks %d   ·   Nail %d   ·   Charms %d/%d   ·   Memories %d/%d   ·   Guardians %d/7",
			(player:GetAttribute("MaxMasks") or 5) :: number,
			(player:GetAttribute("NailLevel") or 1) :: number,
			owned,
			totalCharms,
			memories,
			totalMemories,
			bosses
		),
		Parent = page,
	})
end

local function drawMemories(page: Frame)
	local list = page:FindFirstChild("List") :: ScrollingFrame
	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local found = decodeSet("Memories")
	local ordered = {}
	for id, memory in Memories do
		table.insert(ordered, { id = id, memory = memory })
	end
	table.sort(ordered, function(a, b)
		return a.memory.order < b.memory.order
	end)
	for _, entry in ordered do
		local has = found[entry.id] == true
		local b = new("TextButton", {
			LayoutOrder = entry.memory.order,
			Size = UDim2.new(1, -8, 0, 34),
			BackgroundColor3 = if has then Color3.fromRGB(46, 38, 30) else Color3.fromRGB(18, 18, 24),
			BackgroundTransparency = 0.15,
			AutoButtonColor = has,
			Font = FONT,
			TextSize = 19,
			TextColor3 = if has then Color3.fromRGB(255, 236, 200) else Color3.fromRGB(110, 110, 120),
			Text = if has then entry.memory.title else "· · ·",
			Parent = list,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		if has then
			b.Activated:Connect(function()
				Sfx.play("ui")
				memoryText.Text = string.upper(entry.memory.title) .. "\n\n" .. table.concat(entry.memory.lines, "\n\n")
			end)
		end
	end
end

local function show(page: string)
	current = page
	for name, frame in pages do
		frame.Visible = name == page
		tabs[name].BackgroundColor3 = if name == page then Color3.fromRGB(56, 52, 76) else Color3.fromRGB(24, 24, 34)
	end
	if page == "map" then
		drawMap()
	elseif page == "abilities" then
		drawAbilities(pages.abilities)
	else
		drawMemories(pages.memories)
	end
end

local function setOpen(on: boolean)
	open = on
	root.Visible = on
	State.freeze("journal", on)
	if on then
		Sfx.play("ui", 0.8)
		show(current)
	end
end

function Journal.init()
	gui = new("ScreenGui", { Name = "Journal", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Parent = player:WaitForChild("PlayerGui") })
	root = new("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.88),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIStroke", { Color = Color3.fromRGB(200, 198, 214), Transparency = 0.6 }),
	})
	text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(300, 40), TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, Text = "JOURNAL", Parent = root })
	text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 22), Size = UDim2.fromOffset(300, 24), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 150, 170), Text = "M or ESC to close", Parent = root })

	local order = { "map", "abilities", "memories" }
	local labels = { map = "Map", abilities = "Abilities", memories = "Memories" }
	for i, name in order do
		local tab = new("TextButton", {
			Position = UDim2.fromOffset(24 + (i - 1) * 150, 62),
			Size = UDim2.fromOffset(140, 36),
			BackgroundColor3 = Color3.fromRGB(24, 24, 34),
			Font = FONT,
			TextSize = 20,
			TextColor3 = TEXT,
			Text = labels[name],
			Parent = root,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
		tab.Activated:Connect(function()
			Sfx.play("ui")
			show(name)
		end)
		tabs[name] = tab
		pages[name] = new("Frame", {
			Position = UDim2.fromOffset(24, 110),
			Size = UDim2.new(1, -48, 1, -130),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Visible = false,
			Parent = root,
		})
	end

	-- Map page: a fixed-size canvas scaled to fit.
	mapCanvas = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(1240, 460),
		BackgroundTransparency = 1,
		Parent = pages.map,
	})
	local scale = new("UIScale", { Parent = mapCanvas })
	playerDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Visible = false,
		Parent = mapCanvas,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.fromRGB(255, 200, 120), Thickness = 2 }) })
	local function fit()
		local size = pages.map.AbsoluteSize
		scale.Scale = math.max(0.3, math.min(size.X / 1260, size.Y / 480))
	end
	pages.map:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 150, 170),
		Text = "◆ gold: benches   ◆ white: passages   ◆ red: guardians   ·   Equip the Wayfarer's Compass to see yourself.",
		Parent = pages.map,
	})

	-- Abilities page.
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pages.abilities })

	-- Memories page: list on the left, the chosen memory on the right.
	new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = pages.memories,
	}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })
	memoryText = text({
		Position = UDim2.new(0.38, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		TextSize = 21,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(236, 226, 210),
		Text = "Choose a memory to remember it.",
		Parent = pages.memories,
	})

	Input.on("map", function()
		if not open and State.frozen() then
			return
		end
		setOpen(not open)
	end)
	UserInputService.InputBegan:Connect(function(inputObj)
		if open and (inputObj.KeyCode == Enum.KeyCode.Escape or inputObj.KeyCode == Enum.KeyCode.ButtonB) then
			setOpen(false)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if open and current == "map" then
			updatePlayerDot()
		end
	end)
end

return Journal
