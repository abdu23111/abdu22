-- Shape-building helpers used by the Builder: thorns, gates, benches, NPCs, pickups,
-- the parallax backdrop, and ambient mist / motes / lights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local T = Config.TILE

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local Props = {}

function Props.make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	-- Ball parts are always perfectly round, so stretched "balls" become sphere meshes.
	local size = props.Size
	if props.Shape == Enum.PartType.Ball and typeof(size) == "Vector3" and not (size.X == size.Y and size.Y == size.Z) then
		inst.Shape = Enum.PartType.Block
		inst.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local make = Props.make

-- Non-interactive scenery part.
local function deco(props: { [string]: any }): BasePart
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	if props.Material == nil then
		props.Material = Enum.Material.SmoothPlastic
	end
	return make(props.ClassName or "Part", props)
end

local function part(className: string, props: { [string]: any }): BasePart
	props.ClassName = nil
	local p = make(className, props)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if props.Material == nil then
		p.Material = Enum.Material.SmoothPlastic
	end
	return p
end

-- A flat triangle facing the camera, built from two wedges. `base` is the centre of its base edge.
function Props.triangle(base: Vector3, width: number, height: number, thickness: number, pointDown: boolean, color: Color3, parent: Instance, material: Enum.Material?)
	local hw = width / 2
	local dir = if pointDown then -1 else 1
	local y = base.Y + dir * height / 2
	for side = -1, 1, 2 do
		local towardCenter = -side
		local x = base.X + side * hw / 2
		local cf
		if pointDown then
			cf = CFrame.new(x, y, base.Z) * CFrame.Angles(0, 0, math.pi) * CFrame.Angles(0, math.rad(-90 * towardCenter), 0)
		else
			cf = CFrame.new(x, y, base.Z) * CFrame.Angles(0, math.rad(90 * towardCenter), 0)
		end
		part("WedgePart", {
			Size = Vector3.new(thickness, height, hw),
			CFrame = cf,
			Color = color,
			Material = material,
			Parent = parent,
		})
	end
end

function Props.thorn(base: Vector3, height: number, parent: Instance)
	Props.triangle(base, T * 0.5, height, 3, false, Color3.fromRGB(210, 205, 215), parent)
	Props.triangle(base + Vector3.new(T * 0.25, 0, -2.5), T * 0.45, height * 0.8, 3, false, Color3.fromRGB(120, 116, 128), parent)
end

function Props.edgeTuft(theme, pos: Vector3, rng: Random, parent: Instance)
	if theme.decor == "forest" then
		for i = 1, rng:NextInteger(2, 4) do
			part("Part", {
				Size = Vector3.new(0.25, rng:NextNumber(0.8, 2.2), 0.25),
				CFrame = CFrame.new(pos + Vector3.new(i * 0.35 - 0.8, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
				Color = theme.rim:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.2)),
				Parent = parent,
			})
		end
	elseif theme.decor == "temple" then
		part("Part", {
			Size = Vector3.new(0.6, 0.6, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(45)),
			Color = theme.rim,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			Parent = parent,
		})
	elseif theme.decor == "crystal" then
		for _ = 1, rng:NextInteger(1, 3) do
			part("Part", {
				Size = Vector3.new(0.5, rng:NextNumber(0.8, 2.4), 0.5),
				CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 0.5, 0)) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-30, 30))),
				Color = theme.accent:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.3)),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				Parent = parent,
			})
		end
	elseif theme.decor == "library" then
		for i = 0, rng:NextInteger(0, 2) do
			part("Part", {
				Size = Vector3.new(1.4, 0.35, 1),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.2 + i * 0.36, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
				Color = Color3.fromHSV(rng:NextNumber(0.02, 0.55), 0.35, 0.35),
				Parent = parent,
			})
		end
	elseif theme.decor == "abyss" then
		part("Part", {
			Size = Vector3.new(0.15, rng:NextNumber(0.8, 2), 0.15),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-35, 35))),
			Color = Color3.fromRGB(200, 200, 205),
			Parent = parent,
		})
	else
		part("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(0.6, 1.4),
			Position = pos + Vector3.new(0, 0.2, 0),
			Color = theme.rock:Lerp(theme.rim, rng:NextNumber(0.1, 0.5)),
			Parent = parent,
		})
	end
end

function Props.hanging(theme, pos: Vector3, rng: Random, parent: Instance)
	if theme.decor == "forest" then
		local len = rng:NextNumber(2, 7)
		part("Part", {
			Size = Vector3.new(0.3, len, 0.3),
			Position = pos - Vector3.new(0, len / 2, 0),
			Color = theme.rim:Lerp(Color3.new(0, 0, 0), 0.4),
			Parent = parent,
		})
		if rng:NextNumber() < 0.35 then
			part("Part", {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.7,
				Position = pos - Vector3.new(0, len, 0),
				Color = theme.accent,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
		end
	elseif theme.decor == "city" then
		local len = rng:NextNumber(1.5, 5)
		part("Part", {
			Size = Vector3.new(0.15, len, 0.15),
			Position = pos - Vector3.new(0, len / 2, 0),
			Color = Color3.fromRGB(20, 22, 30),
			Parent = parent,
		})
	elseif theme.decor == "temple" then
		if rng:NextNumber() < 0.4 then
			local len = rng:NextNumber(3, 6)
			part("Part", {
				Size = Vector3.new(1.6, len, 0.1),
				Position = pos - Vector3.new(0, len / 2, -0.5),
				Color = Color3.fromRGB(120, 36, 44),
				Parent = parent,
			})
		end
	elseif theme.decor == "crystal" then
		local len = rng:NextNumber(1.5, 4.5)
		part("Part", {
			Size = Vector3.new(0.7, len, 0.7),
			CFrame = CFrame.new(pos - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-12, 12))),
			Color = theme.accent:Lerp(theme.rock, rng:NextNumber(0.1, 0.5)),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			Parent = parent,
		})
	elseif theme.decor == "library" then
		local len = rng:NextNumber(2, 6)
		part("Part", {
			Size = Vector3.new(0.15, len, 0.15),
			Position = pos - Vector3.new(0, len / 2, 0),
			Color = Color3.fromRGB(30, 40, 44),
			Parent = parent,
		})
		if rng:NextNumber() < 0.4 then
			part("Part", {
				Size = Vector3.new(1.2, 1.5, 0.05),
				CFrame = CFrame.new(pos - Vector3.new(0, len + 0.6, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-20, 20))),
				Color = Color3.fromRGB(220, 214, 190),
				Parent = parent,
			})
		end
	elseif theme.decor == "abyss" then
		local len = rng:NextNumber(3, 9)
		part("Part", {
			Size = Vector3.new(0.2, len, 0.2),
			CFrame = CFrame.new(pos - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10))),
			Color = Color3.fromRGB(190, 190, 196),
			Transparency = 0.2,
			Parent = parent,
		})
	else
		Props.triangle(pos, rng:NextNumber(1.2, 2.6), rng:NextNumber(1.5, 4), 2, true, theme.rock:Lerp(theme.rim, 0.15), parent)
	end
end

-- Boss gate: invisible and passable until closed.
function Props.gate(center: Vector3, size: Vector3, theme, parent: Instance): BasePart
	local gate = make("Part", {
		Name = "BossGate",
		Anchored = true,
		CanCollide = false,
		Transparency = 1,
		Size = Vector3.new(size.X * 0.6, size.Y, size.Z),
		Position = center,
		Color = Color3.fromRGB(20, 20, 26),
		Parent = parent,
	})
	for i = -math.floor(size.Z / 6), math.floor(size.Z / 6) do
		part("Part", {
			Name = "Bar",
			Size = Vector3.new(0.7, size.Y, 0.7),
			Position = center + Vector3.new(0, 0, i * 3),
			Color = theme.rim:Lerp(Color3.new(0, 0, 0), 0.5),
			Transparency = 1,
			Parent = gate,
		})
	end
	return gate
end

function Props.setGate(gate: BasePart, closed: boolean)
	gate.CanCollide = closed
	gate.Transparency = if closed then 0.6 else 1
	for _, bar in gate:GetChildren() do
		if bar:IsA("BasePart") then
			bar.Transparency = if closed then 0 else 1
		end
	end
end

local function prompt(parent: Instance, action: string, object: string)
	return make("ProximityPrompt", {
		ActionText = action,
		ObjectText = object,
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonY,
		HoldDuration = 0,
		MaxActivationDistance = 9,
		RequiresLineOfSight = false,
		Parent = parent,
	})
end

function Props.bench(id: string, floor: Vector3, theme, parent: Instance)
	local model = make("Model", { Name = "Bench", Parent = parent })
	model:SetAttribute("BenchId", id)
	local z = -2
	local wood = Color3.fromRGB(70, 52, 44)
	local seat = part("Part", { Name = "Seat", Size = Vector3.new(7, 0.6, 2.6), Position = floor + Vector3.new(0, 1.7, z), Color = wood, Parent = model })
	part("Part", { Size = Vector3.new(7, 2.4, 0.4), Position = floor + Vector3.new(0, 3.1, z - 1.2), Color = wood, Parent = model })
	for _, x in { -3, 3 } do
		part("Part", { Size = Vector3.new(0.5, 1.7, 2), Position = floor + Vector3.new(x, 0.85, z), Color = wood:Lerp(Color3.new(0, 0, 0), 0.3), Parent = model })
	end
	part("Part", { Size = Vector3.new(0.3, 7, 0.3), Position = floor + Vector3.new(4.5, 3.5, z - 1), Color = Color3.fromRGB(30, 30, 36), Parent = model })
	local lamp = part("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
		Position = floor + Vector3.new(4.5, 7.3, z - 1),
		Color = Color3.fromRGB(255, 200, 130),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	make("PointLight", { Range = 20, Brightness = 1.6, Color = Color3.fromRGB(255, 190, 120), Shadows = true, Parent = lamp })
	model.PrimaryPart = seat
	local p = prompt(seat, "Rest", "Bench")
	p:SetAttribute("BenchId", id)
end

local NPC_LOOKS = {
	wick = { body = Color3.fromRGB(196, 170, 128), extra = "flame" },
	tock = { body = Color3.fromRGB(160, 104, 60), extra = "gear" },
	ilo = { body = Color3.fromRGB(70, 112, 80), extra = "moss" },
	sael = { body = Color3.fromRGB(226, 220, 204), extra = "halo" },
	lirra = { body = Color3.fromRGB(120, 70, 96), extra = "pack" },
	pell = { body = Color3.fromRGB(110, 96, 80), extra = "helmet" },
	quill = { body = Color3.fromRGB(50, 110, 112), extra = "feather" },
	oriel = { body = Color3.fromRGB(190, 190, 200), extra = "ghost" },
}

function Props.npc(id: string, name: string, isTablet: boolean, floor: Vector3, theme, parent: Instance)
	local model = make("Model", { Name = "NPC_" .. id, Parent = parent })
	model:SetAttribute("NpcId", id)
	local z = -1.5
	local anchor
	if isTablet then
		anchor = part("Part", { Size = Vector3.new(3.2, 4.6, 1), Position = floor + Vector3.new(0, 2.3, z), Color = theme.rock:Lerp(theme.rim, 0.25), Material = Enum.Material.Slate, Parent = model })
		for i = 1, 3 do
			part("Part", {
				Size = Vector3.new(2 - i * 0.3, 0.2, 0.1),
				Position = floor + Vector3.new(0, 3.6 - i * 0.8, z + 0.55),
				Color = theme.accent,
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				Parent = model,
			})
		end
		make("PointLight", { Range = 9, Brightness = 0.6, Color = theme.accent, Parent = anchor })
		prompt(anchor, "Read", name)
	else
		local look = NPC_LOOKS[id] or { body = Color3.fromRGB(120, 120, 130) }
		anchor = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 4, 3), Position = floor + Vector3.new(0, 2, z), Color = look.body, Parent = model })
		local head = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.5, Position = floor + Vector3.new(0, 4.6, z), Color = Color3.fromRGB(236, 234, 226), Parent = model })
		for _, x in { -0.5, 0.5 } do
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.8, 0.3), Position = head.Position + Vector3.new(x, 0, 1.15), Color = Color3.fromRGB(10, 10, 14), Parent = model })
		end
		if look.extra == "flame" then
			local flame = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 1.3, 0.7), Position = head.Position + Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(255, 180, 80), Material = Enum.Material.Neon, Parent = model })
			make("PointLight", { Range = 14, Brightness = 1.4, Color = Color3.fromRGB(255, 170, 90), Parent = flame })
			part("Part", { Size = Vector3.new(0.4, 0.7, 0.4), Position = head.Position + Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(240, 230, 210), Parent = model })
		elseif look.extra == "gear" then
			part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3.4, 3.4), CFrame = CFrame.new(anchor.Position + Vector3.new(0, 0.6, -1.6)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(200, 160, 80), Material = Enum.Material.Metal, Parent = model })
			make("PointLight", { Range = 10, Brightness = 0.8, Color = Color3.fromRGB(255, 200, 140), Parent = anchor })
		elseif look.extra == "moss" then
			for i = 1, 5 do
				part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = anchor.Position + Vector3.new(math.cos(i) * 1.4, 0.8 + math.sin(i * 2) * 0.6, 1), Color = theme.accent, Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
			end
			make("PointLight", { Range = 10, Brightness = 0.8, Color = theme.accent, Parent = anchor })
		elseif look.extra == "pack" then
			part("Part", { Size = Vector3.new(2.6, 3, 1.8), Position = anchor.Position + Vector3.new(0, 1, -1.8), Color = Color3.fromRGB(96, 72, 50), Material = Enum.Material.Fabric, Parent = model })
			local lamp = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Position = anchor.Position + Vector3.new(1.6, 2.8, -1.8), Color = Color3.fromRGB(255, 200, 140), Material = Enum.Material.Neon, Parent = model })
			make("PointLight", { Range = 12, Brightness = 1, Color = Color3.fromRGB(255, 200, 140), Parent = lamp })
		elseif look.extra == "helmet" then
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 1.2, 2.8), Position = head.Position + Vector3.new(0, 0.9, 0), Color = Color3.fromRGB(150, 120, 60), Material = Enum.Material.Metal, Parent = model })
			local lamp = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = head.Position + Vector3.new(0, 1.1, 1.3), Color = Color3.fromRGB(240, 160, 255), Material = Enum.Material.Neon, Parent = model })
			make("PointLight", { Range = 14, Brightness = 1.2, Color = Color3.fromRGB(240, 160, 255), Parent = lamp })
		elseif look.extra == "feather" then
			part("Part", { Size = Vector3.new(0.3, 3, 0.8), CFrame = CFrame.new(head.Position + Vector3.new(0.8, 1.6, -0.3)) * CFrame.Angles(0, 0, math.rad(-25)), Color = Color3.fromRGB(230, 240, 235), Parent = model })
			make("PointLight", { Range = 10, Brightness = 0.8, Color = theme.accent, Parent = anchor })
		elseif look.extra == "ghost" then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 0.45
				end
			end
			make("PointLight", { Range = 12, Brightness = 0.8, Color = Color3.fromRGB(230, 230, 255), Parent = head })
		elseif look.extra == "halo" then
			part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.8, 2.8), CFrame = CFrame.new(head.Position + Vector3.new(0, 0.2, -0.8)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Parent = model })
			make("PointLight", { Range = 12, Brightness = 1, Color = Color3.fromRGB(255, 220, 150), Parent = head })
		end
		for _, x in { -0.6, 0.6 } do
			part("Part", { Size = Vector3.new(0.2, 1.4, 0.2), CFrame = CFrame.new(head.Position + Vector3.new(x, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(-x * 30)), Color = Color3.fromRGB(236, 234, 226), Parent = model })
		end
		prompt(anchor, "Listen", name)
	end
	model.PrimaryPart = anchor
end

function Props.pickup(itemId: string, kind: string, id: string, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = make("Part", {
		Name = "Pickup",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(45)),
		Color = color,
		Material = Enum.Material.Neon,
		Shape = if kind == "heart" then Enum.PartType.Ball else Enum.PartType.Block,
		Parent = parent,
	})
	p:SetAttribute("ItemId", itemId)
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Id", id)
	make("PointLight", { Range = 12, Brightness = 1.2, Color = color, Parent = p })
	make("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		Size = NumberSequence.new(0.4, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 8,
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(180, 180),
		Parent = p,
	})
	return p
end

function Props.altar(floor: Vector3, parent: Instance)
	local model = make("Model", { Name = "Altar", Parent = parent })
	local gold = Color3.fromRGB(220, 186, 110)
	part("Part", { Size = Vector3.new(6, 1, 4), Position = floor + Vector3.new(0, 0.5, -2), Color = gold, Material = Enum.Material.Marble, Parent = model })
	part("Part", { Size = Vector3.new(2.4, 3.4, 2.4), Position = floor + Vector3.new(0, 2.7, -2), Color = gold:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Marble, Parent = model })
	local lamp = part("Part", {
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3,
		Position = floor + Vector3.new(0, 5.8, -2),
		Color = Color3.fromRGB(60, 56, 50),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Parent = model,
	})
	make("PointLight", { Name = "LampLight", Range = 60, Brightness = 0, Color = Color3.fromRGB(255, 210, 140), Parent = lamp })
	model.PrimaryPart = lamp
	prompt(lamp, "Kindle the Lantern", "Great Lamp")
end

local function glowProp(style: string, floor: Vector3, theme, rng: Random, parent: Instance): BasePart
	local z = 0
	local light
	if style == "caves" then
		light = part("Part", { Size = Vector3.new(1, 2.2, 1), CFrame = CFrame.new(floor + Vector3.new(0, 0.8, z)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))), Color = theme.accent, Material = Enum.Material.Neon, Parent = parent })
		part("Part", { Size = Vector3.new(0.7, 1.4, 0.7), CFrame = CFrame.new(floor + Vector3.new(0.8, 0.5, z)) * CFrame.Angles(0, 0, math.rad(-30)), Color = theme.accent, Material = Enum.Material.Neon, Parent = parent })
	elseif style == "city" then
		part("Part", { Size = Vector3.new(0.4, 8, 0.4), Position = floor + Vector3.new(0, 4, z), Color = Color3.fromRGB(24, 26, 36), Parent = parent })
		part("Part", { Size = Vector3.new(2, 0.3, 0.3), Position = floor + Vector3.new(0.8, 8, z), Color = Color3.fromRGB(24, 26, 36), Parent = parent })
		light = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Position = floor + Vector3.new(1.6, 7.3, z), Color = theme.accent, Material = Enum.Material.Neon, Parent = parent })
	elseif style == "forest" then
		local h = rng:NextNumber(1.5, 3.5)
		part("Part", { Size = Vector3.new(0.5, h, 0.5), Position = floor + Vector3.new(0, h / 2, z), Color = Color3.fromRGB(200, 220, 200), Parent = parent })
		light = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.2, 2.6), Position = floor + Vector3.new(0, h, z), Color = theme.accent, Material = Enum.Material.Neon, Parent = parent })
	elseif style == "crystal" then
		for i = 1, 3 do
			local p = part("Part", {
				Size = Vector3.new(0.9, rng:NextNumber(1.8, 3.6), 0.9),
				CFrame = CFrame.new(floor + Vector3.new((i - 2) * 0.8, 1, z)) * CFrame.Angles(0, math.rad(45), math.rad((i - 2) * 22)),
				Color = theme.accent:Lerp(Color3.new(1, 1, 1), 0.2 * i),
				Material = Enum.Material.Neon,
				Transparency = 0.15,
				Parent = parent,
			})
			light = light or p
		end
	elseif style == "library" then
		-- A floating reading candle.
		part("Part", { Size = Vector3.new(0.5, 1.2, 0.5), Position = floor + Vector3.new(0, 3, z), Color = Color3.fromRGB(230, 226, 210), Parent = parent })
		light = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.8, 0.5), Position = floor + Vector3.new(0, 3.9, z), Color = theme.accent, Material = Enum.Material.Neon, Parent = parent })
	elseif style == "abyss" then
		-- A pale wisp flame in an abandoned lantern.
		part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.8, 1.4), Position = floor + Vector3.new(0, 0.9, z), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.Glass, Transparency = 0.3, Parent = parent })
		light = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Position = floor + Vector3.new(0, 0.9, z), Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.Neon, Parent = parent })
	else
		part("Part", { Size = Vector3.new(1, 2.5, 1), Position = floor + Vector3.new(0, 1.25, z), Color = theme.rim:Lerp(Color3.new(0, 0, 0), 0.4), Parent = parent })
		part("Part", { Size = Vector3.new(2.4, 0.6, 2.4), Position = floor + Vector3.new(0, 2.8, z), Color = theme.rim, Material = Enum.Material.Metal, Parent = parent })
		light = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.8, 1.2), Position = floor + Vector3.new(0, 3.8, z), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, Parent = parent })
	end
	make("PointLight", { Range = 16, Brightness = 1.1, Color = light.Color, Shadows = false, Parent = light })
	-- A few drifting motes circle every light, like tiny glowing insects.
	make("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(light.Color),
		LightEmission = 1,
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2, 4),
		Rate = 2.5,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.6, 0),
		Parent = light,
	})
	return light
end

function Props.ambience(zoneIndex: number, theme, folder: Folder)
	local ambience = make("Folder", { Name = "Ambience", Parent = folder })
	local minX, maxX, _, maxY = Grid.bounds(zoneIndex)
	local width = maxX - minX
	local depth = Config.CORRIDOR * 2

	-- Low banks of mist drifting along the corridor floor and higher up.
	local mistColor = theme.fog:Lerp(Color3.new(1, 1, 1), 0.35)
	for _, frac in { 0.12, 0.45, 0.78 } do
		local holder = deco({ Name = "Mist", Transparency = 1, Size = Vector3.new(width, 10, depth), Position = Vector3.new(minX + width / 2, maxY * frac, 0), Parent = ambience })
		make("ParticleEmitter", {
			Texture = SMOKE,
			Color = ColorSequence.new(mistColor),
			LightInfluence = 0.5,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(12, 20),
			Lifetime = NumberRange.new(10, 16),
			Rate = width / 30,
			Speed = NumberRange.new(0.5, 1.6),
			SpreadAngle = Vector2.new(180, 20),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-6, 6),
			EmissionDirection = Enum.NormalId.Right,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Parent = holder,
		})
	end

	-- Drifting dust motes everywhere, plus a zone-specific floater: leaves in the forest,
	-- spores in the burrows, crystal glints in the mines, ash, pages, pale petals...
	local volume = deco({ Name = "Motes", Transparency = 1, Size = Vector3.new(width, maxY, depth), Position = Vector3.new(minX + width / 2, maxY / 2, 0), Parent = ambience })
	make("ParticleEmitter", {
		Name = "Dust",
		Texture = SPARKLE,
		Color = ColorSequence.new(theme.accent:Lerp(Color3.new(1, 1, 1), 0.5)),
		LightEmission = 0.6,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(0.18),
		Lifetime = NumberRange.new(8, 12),
		Rate = width / 10,
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.1, 0),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Parent = volume,
	})
	local floaters = {
		forest = { color = Color3.fromRGB(110, 170, 90), size = 0.5, fall = -1.2, spin = 90, light = 0 },
		burrows = { color = Color3.fromRGB(255, 190, 120), size = 0.22, fall = 0.4, spin = 0, light = 1 },
		mines = { color = Color3.fromRGB(245, 180, 255), size = 0.25, fall = 0.1, spin = 0, light = 1 },
		ruins = { color = Color3.fromRGB(190, 200, 220), size = 0.3, fall = -0.6, spin = 40, light = 0.2 },
		archive = { color = Color3.fromRGB(230, 222, 196), size = 0.45, fall = -0.8, spin = 120, light = 0 },
		temple = { color = Color3.fromRGB(255, 225, 160), size = 0.25, fall = 0.2, spin = 0, light = 1 },
		hollow = { color = Color3.fromRGB(235, 235, 245), size = 0.3, fall = -0.3, spin = 60, light = 0.4 },
	}
	local f = floaters[theme.decor == "caves" and "burrows" or theme.decor == "city" and "ruins" or theme.decor == "crystal" and "mines"
		or theme.decor == "library" and "archive" or theme.decor == "abyss" and "hollow" or theme.decor]
	if f then
		make("ParticleEmitter", {
			Name = "Floaters",
			Texture = if f.light > 0.5 then SPARKLE else SMOKE,
			Color = ColorSequence.new(f.color),
			LightEmission = f.light,
			LightInfluence = 1 - f.light,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.2),
				NumberSequenceKeypoint.new(0.85, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(f.size),
			Lifetime = NumberRange.new(9, 14),
			Rate = width / 40,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-f.spin, f.spin),
			Acceleration = Vector3.new(0.4, f.fall, 0),
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Parent = volume,
		})
	end
end

-- A pool of glossy black ink with a faint glowing skin.
function Props.ink(center: Vector3, size: Vector3, theme, parent: Instance)
	local top = center.Y + size.Y / 2
	part("Part", {
		Name = "Ink",
		Size = Vector3.new(size.X, size.Y * 0.8, size.Z),
		Position = Vector3.new(center.X, top - size.Y * 0.4 - 0.4, 0),
		Color = Color3.fromRGB(6, 8, 12),
		Material = Enum.Material.Glass,
		Reflectance = 0.35,
		Transparency = 0.05,
		Parent = parent,
	})
	local skin = part("Part", {
		Size = Vector3.new(size.X, 0.15, size.Z),
		Position = Vector3.new(center.X, top - 0.4, 0),
		Color = theme.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.75,
		Parent = parent,
	})
	make("ParticleEmitter", {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(20, 30, 36)),
		Size = NumberSequence.new(0.6, 1.4),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(1, 2),
		Rate = size.X / 6,
		Speed = NumberRange.new(0.5, 1.5),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Parent = skin,
	})
end

-- Crystal seal: only the Cleaving Arc can break it.
function Props.crystalSeal(center: Vector3, size: Vector3, parent: Instance)
	local seal = make("Part", {
		Name = "CrystalSeal",
		Anchored = true,
		Size = size,
		Position = center,
		Color = Color3.fromRGB(226, 150, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = parent,
	})
	seal:SetAttribute("Seal", true)
	seal:SetAttribute("HP", 1)
	local rng = Random.new(math.floor(center.X * 7 + center.Y))
	for _ = 1, 5 do
		part("Part", {
			Size = Vector3.new(0.8, rng:NextNumber(2, size.Y * 0.9), 0.8),
			CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-3, 5))) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-25, 25))),
			Color = Color3.fromRGB(250, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = seal,
		})
	end
	make("PointLight", { Range = 14, Brightness = 1.2, Color = Color3.fromRGB(230, 160, 255), Parent = seal })
end

-- A sealed shortcut gate. The client hides it once the player has opened this zone's switch.
function Props.shortcutGate(center: Vector3, size: Vector3, zoneId: string, theme, parent: Instance)
	local gate = make("Part", {
		Name = "ShortcutGate",
		Anchored = true,
		Size = size,
		Position = center,
		Color = Color3.fromRGB(26, 26, 32),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	gate:SetAttribute("Switch", zoneId)
	local bars = math.max(2, math.floor(size.Z / 2.5))
	for i = 1, bars do
		local t = (i - 0.5) / bars - 0.5
		local horizontal = size.X > size.Y
		part("Part", {
			Size = if horizontal then Vector3.new(size.X + 0.4, 0.5, 0.5) else Vector3.new(0.5, size.Y + 0.4, 0.5),
			Position = center + Vector3.new(if horizontal then 0 else size.X / 2, if horizontal then size.Y / 2 else 0, t * size.Z),
			Color = theme.rim:Lerp(Color3.new(0, 0, 0), 0.4),
			Material = Enum.Material.Metal,
			Parent = gate,
		})
	end
end

function Props.switch(pos: Vector3, kind: string, zoneId: string, theme, parent: Instance)
	local target
	if kind == "lever" then
		part("Part", { Size = Vector3.new(2.4, 0.8, 2), Position = pos - Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.Metal, Parent = parent })
		target = make("Part", {
			Name = "Switch",
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(0.5, 3.4, 0.5),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(-25)),
			Color = theme.rim,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Position = pos + Vector3.new(0.7, 1.6, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Parent = target })
	else
		target = make("Part", {
			Name = "Switch",
			Anchored = true,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 0.5),
			Position = pos,
			Color = Color3.fromRGB(255, 236, 190),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = parent,
		})
		part("Part", { Size = Vector3.new(0.3, 2.2, 0.2), Position = pos + Vector3.new(0, 0, 0.4), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Parent = target })
		part("Part", { Size = Vector3.new(2.2, 0.3, 0.2), Position = pos + Vector3.new(0, 0, 0.4), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Parent = target })
		make("PointLight", { Range = 12, Brightness = 1, Color = Color3.fromRGB(255, 230, 180), Parent = target })
	end
	target:SetAttribute("Kind", kind)
	target:SetAttribute("Zone", zoneId)
end

-- Slanted beams of pale light falling from openings near the top of a zone, with dust in them.
function Props.lightShafts(zoneIndex: number, chars, theme, folder: Folder)
	local shafts = make("Folder", { Name = "LightShafts", Parent = folder })
	local rng = Random.new(zoneIndex * 7717)
	local w, h = Grid.size(zoneIndex)
	local lastCol = -100
	local count = 0
	for c = 2, w - 1 do
		if c - lastCol > 22 and count < 6 and rng:NextNumber() < 0.25 then
			local r0 = nil
			for r = 2, math.floor(h * 0.5) do
				if chars[r][c] == "." and chars[r - 1][c] ~= "." then
					r0 = r
					break
				end
			end
			if r0 then
				lastCol = c
				count += 1
				local top = Grid.tileCenter(zoneIndex, c, r0) + Vector3.new(0, T / 2, 0)
				local len = rng:NextNumber(60, 110)
				local angle = math.rad(rng:NextNumber(10, 22))
				local z = rng:NextNumber(-Config.CORRIDOR * 0.6, Config.CORRIDOR * 0.6)
				local cf = CFrame.new(top + Vector3.new(0, 0, z)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, angle) * CFrame.new(0, -len / 2, 0)
				local thick = rng:NextNumber(6, 11)
				local beam = part("Part", {
					Name = "Shaft",
					Size = Vector3.new(thick, len, thick),
					CFrame = cf,
					Color = theme.accent:Lerp(Color3.new(1, 1, 1), 0.6),
					Material = Enum.Material.Neon,
					Transparency = 0.955,
					Parent = shafts,
				})
				make("ParticleEmitter", {
					Texture = SPARKLE,
					Color = ColorSequence.new(Color3.fromRGB(255, 250, 235)),
					LightEmission = 1,
					Size = NumberSequence.new(0.18),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.35),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Lifetime = NumberRange.new(5, 8),
					Rate = 4,
					Speed = NumberRange.new(0.2, 0.6),
					SpreadAngle = Vector2.new(180, 180),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					Parent = beam,
				})
			end
		end
	end
end

-- ===== 3D props =====

-- A single pale thorn blade at a random angle; many of them make a bramble.
function Props.thorn3D(base: Vector3, rng: Random, parent: Instance)
	local h = rng:NextNumber(2.2, 3.4)
	part("WedgePart", {
		Size = Vector3.new(0.4, h, rng:NextNumber(0.9, 1.5)),
		CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-18, 18))),
		Color = Color3.fromRGB(214, 208, 218):Lerp(Color3.fromRGB(120, 116, 128), rng:NextNumber(0, 0.6)),
		Parent = parent,
	})
end

-- An invisible anchor where each client builds the NPC's animated rig.
function Props.npcAnchor(id: string, name: string, floor: Vector3, parent: Instance)
	local anchor = make("Part", {
		Name = "NPCAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(3, 5, 3),
		Position = floor + Vector3.new(0, 2.5, 0),
		Parent = parent,
	})
	anchor:SetAttribute("NpcId", id)
	anchor:SetAttribute("Facing", Vector3.new(0.35, 0, 1).Unit)
	local model = make("Model", { Name = "NPC_" .. id, Parent = parent })
	model:SetAttribute("NpcId", id)
	anchor.Parent = model
	model.PrimaryPart = anchor
	prompt(anchor, if id == "lirra" or id == "tock" then "Trade" else "Listen", name)
end

-- A glowing archway where a passage leads on to another region.
function Props.doorway(center: Vector3, size: Vector3, inward: number, theme, parent: Instance)
	local x = center.X + inward * (T / 2 - 0.3)
	local glowColor = theme.accent:Lerp(Color3.new(1, 1, 1), 0.5)
	local veil = part("Part", {
		Name = "DoorVeil",
		Size = Vector3.new(0.3, size.Y, size.Z),
		Position = Vector3.new(x, center.Y, center.Z),
		Color = glowColor,
		Material = Enum.Material.Neon,
		Transparency = 0.88,
		Parent = parent,
	})
	make("PointLight", { Range = 22, Brightness = 1.4, Color = glowColor, Parent = veil })
	make("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(glowColor),
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(1.5, 3),
		Rate = 12,
		Speed = NumberRange.new(1, 3),
		EmissionDirection = if inward > 0 then Enum.NormalId.Right else Enum.NormalId.Left,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Parent = veil,
	})
end

-- Region-specific set dressing against the cave walls.
function Props.wallDecor(theme, floor: Vector3, side: number, rng: Random, parent: Instance)
	local style = theme.decor
	if style == "caves" then
		-- Stalagmite: crossed triangles make a cone-like spire.
		local h, w = rng:NextNumber(4, 10), rng:NextNumber(2, 4)
		for _, yaw in { 0, math.pi / 2 } do
			local cf = CFrame.new(floor) * CFrame.Angles(0, yaw, 0)
			local model = make("Model", { Parent = parent })
			Props.triangle(Vector3.zero, w, h, w * 0.8, false, theme.wallColor:Lerp(theme.rim, 0.15), model)
			model:PivotTo(cf)
		end
	elseif style == "city" then
		-- A broken column, sometimes toppled.
		local h = rng:NextNumber(5, 14)
		local r = rng:NextNumber(1.6, 2.4)
		part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), CFrame = CFrame.new(floor + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = theme.smooth, Material = Enum.Material.Cobblestone, Parent = parent })
		part("Part", { Size = Vector3.new(r * 2.6, 0.8, r * 2.6), Position = floor + Vector3.new(0, 0.4, 0), Color = theme.rim:Lerp(theme.rock, 0.5), Parent = parent })
		if rng:NextNumber() < 0.5 then
			part("Part", { Size = Vector3.new(r * 2.6, 0.8, r * 2.6), Position = floor + Vector3.new(0, h, 0), Color = theme.rim:Lerp(theme.rock, 0.5), Parent = parent })
		end
	elseif style == "forest" then
		-- Giant glowing mushrooms and curling roots.
		local h = rng:NextNumber(3, 9)
		part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.9, 0.9), CFrame = CFrame.new(floor + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90 + rng:NextNumber(-10, 10))), Color = Color3.fromRGB(200, 214, 196), Parent = parent })
		local cap = part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.8, h * 0.3, h * 0.8), Position = floor + Vector3.new(0, h, 0), Color = theme.accent:Lerp(theme.rock, 0.35), Material = Enum.Material.Neon, Transparency = 0.1, Parent = parent })
		for _ = 1, 3 do
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.3, 0.6), Position = cap.Position + Vector3.new(rng:NextNumber(-1, 1), 0.4, rng:NextNumber(-1, 1)) * h * 0.3, Color = Color3.fromRGB(255, 255, 230), Material = Enum.Material.Neon, Parent = parent })
		end
		make("PointLight", { Range = h * 2.5, Brightness = 0.9, Color = theme.accent, Shadows = false, Parent = cap })
	elseif style == "temple" then
		local h = rng:NextNumber(10, 20)
		part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.8, 2.8), CFrame = CFrame.new(floor + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = theme.smooth, Material = Enum.Material.Marble, Parent = parent })
		part("Part", { Size = Vector3.new(4, 1, 4), Position = floor + Vector3.new(0, h, 0), Color = theme.rim, Material = Enum.Material.Marble, Parent = parent })
		part("Part", { Size = Vector3.new(3.8, 0.8, 3.8), Position = floor + Vector3.new(0, 0.4, 0), Color = theme.rim, Material = Enum.Material.Marble, Parent = parent })
	elseif style == "crystal" then
		for _ = 1, rng:NextInteger(3, 6) do
			local h = rng:NextNumber(2, 8)
			part("Part", {
				Size = Vector3.new(rng:NextNumber(0.8, 1.8), h, rng:NextNumber(0.8, 1.8)),
				CFrame = CFrame.new(floor + Vector3.new(rng:NextNumber(-1.5, 1.5), h * 0.4, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-25, 25))),
				Color = theme.accent:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.4)),
				Material = Enum.Material.Glass,
				Transparency = 0.25,
				Parent = parent,
			})
		end
	elseif style == "library" then
		-- A tall drowned bookshelf.
		local h = rng:NextNumber(8, 16)
		local wood = Color3.fromRGB(70, 50, 38)
		local shelf = make("Model", { Parent = parent })
		part("Part", { Size = Vector3.new(6, h, 1.2), Position = Vector3.new(0, h / 2, -0.6 * side), Color = wood, Material = Enum.Material.WoodPlanks, Parent = shelf })
		for y = 1.5, h - 1, 2.2 do
			part("Part", { Size = Vector3.new(6, 0.25, 1.4), Position = Vector3.new(0, y, 0), Color = wood, Parent = shelf })
			local x = -2.6
			while x < 2.6 do
				local bw = rng:NextNumber(0.3, 0.6)
				part("Part", { Size = Vector3.new(bw, rng:NextNumber(1.2, 1.9), 1), Position = Vector3.new(x + bw / 2, y + 0.9, 0), Color = Color3.fromHSV(rng:NextNumber(0, 0.6), 0.35, rng:NextNumber(0.2, 0.45)), Parent = shelf })
				x += bw + 0.05
			end
		end
		shelf:PivotTo(CFrame.new(floor) * CFrame.Angles(0, 0, 0))
	elseif style == "abyss" then
		for i = 1, rng:NextInteger(3, 6) do
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.6, 1.2), Position = floor + Vector3.new(rng:NextNumber(-2, 2), 0.8 + (i % 3) * 1.2, rng:NextNumber(-2, 2)), Color = Color3.fromRGB(46, 46, 52), Material = Enum.Material.Glass, Transparency = 0.2, Parent = parent })
		end
	end
end

-- A Silkline ring: a glowing hoop hanging on a chain, the anchor players swing from.
function Props.swingAnchor(pos: Vector3, ceilingY: number, theme, parent: Instance)
	local glow = theme.accent:Lerp(Color3.new(1, 1, 1), 0.45)
	local anchor = make("Part", {
		Name = "SwingAnchor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Position = pos,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Color = glow,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	-- The hoop, facing along the corridor so it reads from the side and from behind.
	local radius = 1.9
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part("Part", {
			Size = Vector3.new(0.3, 0.32, radius * 0.56),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = glow,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
	end
	-- Chain up into the dark.
	local top = math.min(ceilingY, pos.Y + 60)
	if top > pos.Y + radius then
		part("Part", {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(top - pos.Y - radius, 0.22, 0.22),
			CFrame = CFrame.new(pos + Vector3.new(0, (top - pos.Y + radius) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(70, 70, 80),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
	make("PointLight", { Range = 20, Brightness = 1.4, Color = glow, Parent = anchor })
	make("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(glow),
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 6,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Parent = anchor,
	})
	return anchor
end

-- A light source at the base of a wall; a few cast real shadows.
function Props.glowLight(theme, floor: Vector3, rng: Random, parent: Instance, shadows: boolean)
	local light = glowProp(theme.decor, floor, theme, rng, parent)
	local pointLight = light:FindFirstChildOfClass("PointLight")
	if pointLight then
		pointLight.Shadows = shadows
		pointLight.Range = 22
	end
end

return Props
