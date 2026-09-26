-- Shape-building helpers used by the Builder: thorns, gates, benches, NPCs, pickups,
-- the parallax backdrop, and ambient mist / motes / lights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local T = Config.TILE
local DEPTH = Config.DEPTH

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
		Size = Vector3.new(size.X * 0.6, size.Y, DEPTH),
		Position = center,
		Color = Color3.fromRGB(20, 20, 26),
		Parent = parent,
	})
	for i = -1, 1 do
		part("Part", {
			Name = "Bar",
			Size = Vector3.new(0.5, size.Y, 0.5),
			Position = center + Vector3.new(i * 1.1, 0, DEPTH / 2 - 1),
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

-- ===== Backdrop =====

local function silhouette(style: string, x: number, maxY: number, z: number, s: number, color: Color3, rng: Random, parent: Instance, windowColor: Color3?)
	if style == "caves" then
		local r = rng:NextNumber()
		if r < 0.45 then
			Props.triangle(Vector3.new(x, -20, z), rng:NextNumber(10, 24) * s, rng:NextNumber(35, 95) * s, 2, false, color, parent)
		elseif r < 0.85 then
			Props.triangle(Vector3.new(x, maxY + 20, z), rng:NextNumber(10, 22) * s, rng:NextNumber(25, 70) * s, 2, true, color, parent)
		else
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(18, 40) * s, Position = Vector3.new(x, rng:NextNumber(-10, 10), z), Color = color, Parent = parent })
		end
	elseif style == "city" then
		local w = rng:NextNumber(12, 26) * s
		local h = rng:NextNumber(30, 100) * s
		part("Part", { Size = Vector3.new(w, h, 2), Position = Vector3.new(x, -10 + h / 2, z), Color = color, Parent = parent })
		if rng:NextNumber() < 0.6 then
			Props.triangle(Vector3.new(x, -10 + h, z), w * 1.1, w * rng:NextNumber(0.5, 1.2), 2, false, color, parent)
		else
			part("Part", { Size = Vector3.new(w * 0.2, h * 0.4, 2), Position = Vector3.new(x, -10 + h * 1.2, z), Color = color, Parent = parent })
		end
		if windowColor then
			for _ = 1, rng:NextInteger(1, 4) do
				part("Part", {
					Size = Vector3.new(1.4 * s, 2.4 * s, 0.2),
					Position = Vector3.new(x + rng:NextNumber(-w / 3, w / 3), -10 + h * rng:NextNumber(0.3, 0.9), z + 1.2),
					Color = windowColor,
					Material = Enum.Material.Neon,
					Transparency = rng:NextNumber(0.5, 0.8),
					Parent = parent,
				})
			end
		end
	elseif style == "forest" then
		local w = rng:NextNumber(3, 9) * s
		part("Part", {
			Size = Vector3.new(w, maxY + 80, 2),
			CFrame = CFrame.new(x, maxY / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))),
			Color = color,
			Parent = parent,
		})
		for _ = 1, rng:NextInteger(1, 3) do
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(rng:NextNumber(20, 40), rng:NextNumber(12, 22), 2) * s, Position = Vector3.new(x + rng:NextNumber(-12, 12) * s, maxY * rng:NextNumber(0.55, 1.05), z), Color = color, Parent = parent })
		end
		if windowColor and rng:NextNumber() < 0.5 then
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2 * s, Position = Vector3.new(x + rng:NextNumber(-8, 8), maxY * rng:NextNumber(0.1, 0.8), z + 1.2), Color = windowColor, Material = Enum.Material.Neon, Transparency = 0.4, Parent = parent })
		end
	elseif style == "crystal" then
		-- Leaning crystal spires with a faint inner glow.
		local base = Vector3.new(x, rng:NextNumber(-20, 0), z)
		for _ = 1, rng:NextInteger(2, 4) do
			local h = rng:NextNumber(25, 80) * s
			local w = rng:NextNumber(4, 10) * s
			part("Part", {
				Size = Vector3.new(w, h, 2),
				CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-8, 8) * s, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-22, 22))),
				Color = color,
				Parent = parent,
			})
			if windowColor and rng:NextNumber() < 0.5 then
				part("Part", {
					Size = Vector3.new(w * 0.25, h * 0.7, 0.3),
					CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-8, 8) * s, h * 0.45, 1.2)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-22, 22))),
					Color = windowColor,
					Material = Enum.Material.Neon,
					Transparency = 0.75,
					Parent = parent,
				})
			end
		end
	elseif style == "library" then
		-- Towering drowned bookshelves and reading arches.
		local w = rng:NextNumber(10, 22) * s
		local h = rng:NextNumber(50, 130) * s
		part("Part", { Size = Vector3.new(w, h, 2), Position = Vector3.new(x, -10 + h / 2, z), Color = color, Parent = parent })
		local shelves = math.floor(h / (6 * s))
		for i = 1, math.min(shelves, 14) do
			part("Part", {
				Size = Vector3.new(w * 0.9, 0.5 * s, 0.4),
				Position = Vector3.new(x, -10 + i * 6 * s, z + 1.1),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.08),
				Parent = parent,
			})
		end
		if windowColor and rng:NextNumber() < 0.6 then
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6 * s, Position = Vector3.new(x + rng:NextNumber(-w / 3, w / 3), -10 + h * rng:NextNumber(0.2, 0.9), z + 1.4), Color = windowColor, Material = Enum.Material.Neon, Transparency = 0.45, Parent = parent })
		end
	elseif style == "abyss" then
		-- Pale hanging roots and heaps of abandoned lanterns.
		if rng:NextNumber() < 0.6 then
			local len = rng:NextNumber(40, 140) * s
			part("Part", {
				Size = Vector3.new(rng:NextNumber(0.8, 2.5) * s, len, 1),
				CFrame = CFrame.new(x, maxY + 20 - len / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.1),
				Parent = parent,
			})
		else
			local base = Vector3.new(x, rng:NextNumber(-15, 5), z)
			for i = 1, rng:NextInteger(3, 7) do
				part("Part", {
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(3, 4, 2) * s * rng:NextNumber(0.6, 1.2),
					Position = base + Vector3.new(rng:NextNumber(-10, 10) * s, i * 1.6 * s, 0),
					Color = color,
					Parent = parent,
				})
			end
		end
	else -- temple
		local r = rng:NextNumber()
		if r < 0.55 then
			local w = rng:NextNumber(5, 9) * s
			local h = maxY + 40
			part("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, w, w), CFrame = CFrame.new(x, h / 2 - 20, z) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Parent = parent })
			part("Part", { Size = Vector3.new(w * 1.6, w * 0.5, 2.5), Position = Vector3.new(x, maxY * rng:NextNumber(0.2, 0.5), z), Color = color, Parent = parent })
		else
			-- A praying moth statue: body, head and two folded wings.
			local base = Vector3.new(x, rng:NextNumber(-5, 20), z)
			local sz = rng:NextNumber(14, 26) * s
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(sz * 0.35, sz, 2), Position = base + Vector3.new(0, sz * 0.5, 0), Color = color, Parent = parent })
			part("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(sz * 0.3, sz * 0.3, 2), Position = base + Vector3.new(0, sz * 1.05, 0), Color = color, Parent = parent })
			Props.triangle(base + Vector3.new(-sz * 0.35, sz * 0.2, 0), sz * 0.6, sz * 1.1, 2, false, color, parent)
			Props.triangle(base + Vector3.new(sz * 0.35, sz * 0.2, 0), sz * 0.6, sz * 1.1, 2, false, color, parent)
		end
	end
end

function Props.backdrop(zoneIndex: number, theme, folder: Folder)
	local backdrop = make("Folder", { Name = "Backdrop", Parent = folder })
	local rng = Random.new(zoneIndex * 104729)
	local minX, maxX, _, maxY = Grid.bounds(zoneIndex)
	local width = maxX - minX

	make("Part", {
		Name = "Void",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.new(width + 900, maxY + 500, 2),
		Position = Vector3.new(minX + width / 2, maxY / 2, -180),
		Color = theme.fog,
		Material = Enum.Material.SmoothPlastic,
		Parent = backdrop,
	})

	local layers = {
		{ z = -DEPTH / 2 - 14, scale = 0.9, spacing = 20 },
		{ z = -60, scale = 1.5, spacing = 30 },
		{ z = -115, scale = 2.4, spacing = 44 },
	}
	for i, layer in layers do
		local color = theme.far[i]
		local margin = 60 + i * 50
		local x = minX - margin
		while x < maxX + margin do
			local tint = color:Lerp(theme.accent, rng:NextNumber(0, 0.04))
			silhouette(theme.decor, x, maxY, layer.z, layer.scale, tint, rng, backdrop, if i < 3 then theme.accent else nil)
			x += rng:NextNumber(0.6, 1.4) * layer.spacing
		end
	end
end

local function glowProp(style: string, floor: Vector3, theme, rng: Random, parent: Instance)
	local z = -3.5
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
end

function Props.ambience(zoneIndex: number, theme, floorSpots: { Vector3 }, folder: Folder)
	local ambience = make("Folder", { Name = "Ambience", Parent = folder })
	local rng = Random.new(zoneIndex * 31337)
	local minX, maxX, _, maxY = Grid.bounds(zoneIndex)
	local width = maxX - minX

	local lastX = -math.huge
	for _, spot in floorSpots do
		if spot.X - lastX > 26 and rng:NextNumber() < 0.5 then
			glowProp(theme.decor, spot, theme, rng, ambience)
			lastX = spot.X
		end
	end

	local mistColor = theme.fog:Lerp(Color3.new(1, 1, 1), 0.35)
	for _, frac in { 0.12, 0.45, 0.78 } do
		local holder = deco({ Name = "Mist", Transparency = 1, Size = Vector3.new(width, 10, 26), Position = Vector3.new(minX + width / 2, maxY * frac, -3), Parent = ambience })
		make("ParticleEmitter", {
			Texture = SMOKE,
			Color = ColorSequence.new(mistColor),
			LightInfluence = 0.4,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.86),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(14, 22),
			Lifetime = NumberRange.new(10, 16),
			Rate = width / 45,
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

	local motes = deco({ Name = "Motes", Transparency = 1, Size = Vector3.new(width, maxY, 20), Position = Vector3.new(minX + width / 2, maxY / 2, 0), Parent = ambience })
	make("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(theme.accent),
		LightEmission = 1,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(6, 10),
		Rate = width / 18,
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.25, 0),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Parent = motes,
	})
end

-- ===== Layered scenery (added for depth) =====

local function subfolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	return make("Folder", { Name = name, Parent = parent })
end

-- A darker, larger slab behind each block of rock, plus loose boulders along its edges,
-- so caves read as deep rooms instead of flat tiles.
function Props.midground(center: Vector3, size: Vector3, theme, seed: number, zoneFolder: Instance)
	local mid = subfolder(zoneFolder, "Midground")
	local rng = Random.new(seed)
	local grow = Vector3.new(rng:NextNumber(2, 7), rng:NextNumber(2, 7), 0)
	part("Part", {
		Size = Vector3.new(size.X + grow.X, size.Y + grow.Y, 8),
		Position = center + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.5, 1.5), -DEPTH / 2 - 5),
		Color = theme.rockDark,
		Material = theme.material,
		Parent = mid,
	})
	if size.X * size.Y > 60 then
		for _ = 1, rng:NextInteger(1, 3) do
			local edge = Vector3.new(rng:NextNumber(-0.5, 0.5) * size.X, (if rng:NextNumber() < 0.5 then -0.5 else 0.5) * size.Y, 0)
			part("Part", {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(3, 6), 4),
				Position = center + edge + Vector3.new(0, 0, -DEPTH / 2 - rng:NextNumber(1, 4)),
				Color = theme.rockDark:Lerp(theme.rock, 0.35),
				Material = theme.material,
				Parent = mid,
			})
		end
	end
end

function Props.edgeLump(theme, pos: Vector3, rng: Random, parent: Instance)
	part("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(rng:NextNumber(1.4, 2.8), rng:NextNumber(0.9, 1.6), rng:NextNumber(1.2, 2)),
		Position = pos,
		Color = theme.rock:Lerp(theme.rim, rng:NextNumber(0.1, 0.3)),
		Material = theme.material,
		Parent = parent,
	})
end

-- A pool of glossy black ink with a faint glowing skin.
function Props.ink(center: Vector3, size: Vector3, theme, parent: Instance)
	local top = center.Y + size.Y / 2
	part("Part", {
		Name = "Ink",
		Size = Vector3.new(size.X, size.Y * 0.8, DEPTH + 0.4),
		Position = Vector3.new(center.X, top - size.Y * 0.4 - 0.4, 0),
		Color = Color3.fromRGB(6, 8, 12),
		Material = Enum.Material.Glass,
		Reflectance = 0.35,
		Transparency = 0.05,
		Parent = parent,
	})
	local skin = part("Part", {
		Size = Vector3.new(size.X, 0.15, DEPTH + 0.5),
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
		Size = Vector3.new(size.X, size.Y, DEPTH),
		Position = center,
		Color = Color3.fromRGB(26, 26, 32),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	gate:SetAttribute("Switch", zoneId)
	local bars = math.max(2, math.floor(math.max(size.X, size.Y) / 1.6))
	for i = 1, bars do
		local t = (i - 0.5) / bars - 0.5
		local horizontal = size.X > size.Y
		part("Part", {
			Size = if horizontal then Vector3.new(0.4, size.Y + 0.4, 0.6) else Vector3.new(size.X + 0.4, 0.4, 0.6),
			Position = center + (if horizontal then Vector3.new(t * size.X, 0, DEPTH / 2) else Vector3.new(0, t * size.Y, DEPTH / 2)),
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

-- Dark shapes close to the camera frame the view like the edge of a painting.
function Props.foreground(zoneIndex: number, theme, folder: Folder)
	local fg = make("Folder", { Name = "Foreground", Parent = folder })
	local rng = Random.new(zoneIndex * 5099)
	local minX, maxX, _, maxY = Grid.bounds(zoneIndex)
	local color = theme.fog:Lerp(Color3.new(0, 0, 0), 0.55)
	local x = minX + rng:NextNumber(10, 40)
	while x < maxX do
		local z = rng:NextNumber(15, 22)
		if rng:NextNumber() < 0.5 then
			Props.triangle(Vector3.new(x, maxY + 2, z), rng:NextNumber(5, 12), rng:NextNumber(12, 30), 2, true, color, fg)
		else
			local h = rng:NextNumber(8, 22)
			part("Part", {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(rng:NextNumber(10, 22), h, 3),
				Position = Vector3.new(x, rng:NextNumber(-4, 2), z),
				Color = color,
				Parent = fg,
			})
			if theme.decor == "forest" or theme.decor == "abyss" then
				for _ = 1, 3 do
					part("Part", {
						Size = Vector3.new(0.4, rng:NextNumber(4, 10), 0.4),
						CFrame = CFrame.new(x + rng:NextNumber(-5, 5), h / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
						Color = color,
						Parent = fg,
					})
				end
			end
		end
		x += rng:NextNumber(45, 90)
	end
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
				local cf = CFrame.new(top) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -len / 2, -6)
				local beam = part("Part", {
					Name = "Shaft",
					Size = Vector3.new(rng:NextNumber(7, 14), len, 0.2),
					CFrame = cf,
					Color = theme.accent:Lerp(Color3.new(1, 1, 1), 0.6),
					Material = Enum.Material.Neon,
					Transparency = 0.93,
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

return Props
