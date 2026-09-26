-- Small local-only visual effects: glowing shards, fading puffs, dust.

local TweenService = game:GetService("TweenService")

local Fx = {}

local folder = Instance.new("Folder")
folder.Name = "LocalFx"
folder.Parent = workspace

-- An anchored, non-interactive neon part. Stretched balls become sphere meshes.
function Fx.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	local size = props.Size
	if props.Shape == Enum.PartType.Ball and size and not (size.X == size.Y and size.Y == size.Z) then
		p.Shape = Enum.PartType.Block
		p.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = folder
	return p
end

-- Tween a part to invisible (plus any extra goals) and destroy it.
function Fx.fade(p: BasePart, duration: number, goals: { [string]: any }?)
	local goal = goals or {}
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(duration, function()
		p:Destroy()
	end)
end

-- A soft, expanding cloud (dust, landing puffs, spell impacts).
function Fx.puff(position: Vector3, color: Color3, size: number, duration: number?)
	local p = Fx.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size * 0.6, 1),
		Position = position + Vector3.new(0, 0, 1.5),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.45,
	})
	Fx.fade(p, duration or 0.4, { Size = Vector3.new(size * 2.2, size * 1.1, 1), Position = p.Position + Vector3.new(0, size * 0.3, 0) })
end

-- Several small streaks flying outward.
function Fx.sparks(at: Vector3, color: Color3?, count: number?, length: number?)
	for _ = 1, count or 6 do
		local p = Fx.part({
			Size = Vector3.new(0.2, length or 1.4, 0.2),
			Color = color or Color3.fromRGB(255, 255, 255),
			CFrame = CFrame.new(at + Vector3.new(0, 0, 2)) * CFrame.Angles(0, 0, math.random() * math.pi * 2),
		})
		local dir = p.CFrame.UpVector
		Fx.fade(p, 0.22, { CFrame = p.CFrame + dir * 2.5 })
	end
end

return Fx
