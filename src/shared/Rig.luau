-- Runtime for the character rigs in Shared/Rigs (authored in tools/rigs.py). A rig is a small
-- bone hierarchy of simple shapes. Clips are keyframes offsetting each bone from its rest
-- pose; the runtime crossfades between clips, fires clip events, blinks eyes, flickers
-- flames, turns heads toward a look target, and can tint the whole rig (hit flash / warning).
--
-- Rig space: +x is where the character faces, +y up, +z its right side, origin at the feet.
-- Rigs are purely visual and built on each client.

local Rigs = script.Parent:WaitForChild("Rigs")

local Rig = {}
Rig.__index = Rig

local MATERIALS = {
	p = Enum.Material.SmoothPlastic,
	n = Enum.Material.Neon,
	g = Enum.Material.Glass,
	m = Enum.Material.Metal,
	f = Enum.Material.Fabric,
}

local dataCache: { [string]: any } = {}

function Rig.data(name: string): any?
	if dataCache[name] == nil then
		local module = Rigs:FindFirstChild(name)
		dataCache[name] = if module then require(module) :: any else false
	end
	return dataCache[name] or nil
end

-- A CFrame at `position` whose local +x points along `facing` (flattened), +y up.
function Rig.frame(position: Vector3, facing: Vector3): CFrame
	local f = Vector3.new(facing.X, 0, facing.Z)
	if f.Magnitude < 1e-3 then
		f = Vector3.xAxis
	end
	f = f.Unit
	return CFrame.fromMatrix(position, f, Vector3.yAxis, f:Cross(Vector3.yAxis))
end

local function ease(e: string, a: number): number
	if e == "l" then
		return a
	elseif e == "i" then
		return 1 - math.cos(a * math.pi / 2)
	elseif e == "o" then
		return math.sin(a * math.pi / 2)
	elseif e == "s" then
		return 0
	end
	return (1 - math.cos(a * math.pi)) / 2
end

-- Returns r, x, y, sx, sy, ry, rx for a channel at time t.
local function sample(keys, t: number): (number, number, number, number, number, number, number)
	local first = keys[1]
	if t <= first[1] then
		return first[2], first[3], first[4], first[5], first[6], first[8] or 0, first[9] or 0
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t < b[1] then
			local f = ease(a[7], (t - a[1]) / math.max(1e-6, b[1] - a[1]))
			local function l(i1: number, default: number): number
				local va, vb = a[i1] or default, b[i1] or default
				return va + (vb - va) * f
			end
			return l(2, 0), l(3, 0), l(4, 0), l(5, 1), l(6, 1), l(8, 0), l(9, 0)
		end
	end
	local last = keys[#keys]
	return last[2], last[3], last[4], last[5], last[6], last[8] or 0, last[9] or 0
end

export type RigObject = typeof(setmetatable({} :: any, Rig))

function Rig.new(name: string, parent: Instance, scale: number?): any
	local data = Rig.data(name)
	assert(data, "No rig named " .. name)
	local self = setmetatable({}, Rig)
	self.name = name
	self.data = data
	self.scale = scale or 1
	self.model = Instance.new("Model")
	self.model.Name = "Rig_" .. name
	self.parts = {}
	self.partList = {}
	self.cframes = {}
	self.eyes = {}
	self.flames = {}
	self.glows = {}
	self.clip = nil
	self.clipName = nil
	self.time = 0
	self.prev = nil
	self.prevTime = 0
	self.fade = 0
	self.fadeLen = 0.12
	self.speed = 1
	self.onEvent = nil
	self.onFinished = nil
	self.lookTarget = nil
	self.lookYaw = 0
	self.nextBlink = os.clock() + math.random() * 3 + 1
	self.blinkUntil = 0
	self.tintColor = nil
	self.tintAmount = 0

	local s = self.scale
	for i, p in data.parts do
		local shape = p.s
		local part: BasePart
		if shape == "tri" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = p.m ~= "n" and (p.z[1] * p.z[2]) > 0.5
		part.Material = MATERIALS[p.m] or Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(p.c[1], p.c[2], p.c[3])
		part.Transparency = p.a or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "ball" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		local base = Vector3.new(p.z[1], p.z[2], p.z[3]) * s
		part.Size = if shape == "tri" then Vector3.new(base.Z, base.Y, base.X) else base
		part.Parent = self.model
		local entry = {
			part = part,
			data = p,
			base = base,
			color = part.Color,
			lastScale = Vector2.new(1, 1),
			triRot = if shape == "tri" then CFrame.Angles(0, if p.f then -math.pi / 2 else math.pi / 2, 0) else nil,
		}
		self.parts[i] = entry
		self.partList[i] = part
		if p.t == "eye" then
			table.insert(self.eyes, entry)
		elseif p.t == "flame" then
			table.insert(self.flames, entry)
		elseif p.t == "glow" then
			table.insert(self.glows, entry)
		end
	end
	self.boneIndex = {}
	for i, b in data.bones do
		self.boneIndex[b.n] = i
	end
	self.model.Parent = parent
	return self
end

function Rig:has(clipName: string): boolean
	return self.data.clips[clipName] ~= nil
end

-- Play a clip, crossfading from the current pose. Restarting the same looping clip is a no-op
-- unless `restart` is set.
function Rig:play(clipName: string, fade: number?, speed: number?, restart: boolean?)
	local clip = self.data.clips[clipName]
	if not clip then
		return false
	end
	self.speed = speed or 1
	if self.clipName == clipName and not restart then
		return true
	end
	self.prev = self.clip
	self.prevTime = self.time
	self.fadeLen = fade or 0.12
	self.fade = if self.prev and self.fadeLen > 0 then self.fadeLen else 0
	self.clip = clip
	self.clipName = clipName
	self.time = 0
	return true
end

function Rig:finished(): boolean
	return self.clip ~= nil and not self.clip.loop and self.time >= self.clip.len
end

function Rig:tint(color: Color3?, amount: number)
	self.tintColor = color
	self.tintAmount = amount
end

local function channel(clip, boneName: string, t: number)
	if not clip then
		return 0, 0, 0, 1, 1, 0, 0
	end
	local keys = clip.k[boneName]
	if not keys then
		return 0, 0, 0, 1, 1, 0, 0
	end
	if clip.loop then
		t = t % clip.len
	end
	return sample(keys, t)
end

-- Advance the animation and place every part relative to `root` (a CFrame at the feet,
-- from Rig.frame).
function Rig:update(dt: number, root: CFrame)
	local now = os.clock()
	local clip = self.clip
	if clip then
		local before = self.time
		self.time += dt * self.speed
		if self.onEvent and #clip.ev > 0 then
			local a, b = before, self.time
			if clip.loop then
				a, b = before % clip.len, self.time % clip.len
			end
			for _, ev in clip.ev do
				if (a <= ev[1] and ev[1] < b) or (b < a and (ev[1] >= a or ev[1] < b)) then
					self.onEvent(ev[2])
				end
			end
		end
		if not clip.loop and before < clip.len and self.time >= clip.len and self.onFinished then
			self.onFinished(self.clipName)
		end
	end
	local w = 1
	if self.fade > 0 then
		self.fade = math.max(0, self.fade - dt)
		self.prevTime += dt
		w = 1 - self.fade / self.fadeLen
		w = w * w * (3 - 2 * w)
	end

	-- Head tracking toward a world point.
	local wantYaw = 0
	if self.lookTarget then
		local rel = root:PointToObjectSpace(self.lookTarget)
		wantYaw = math.clamp(math.deg(math.atan2(-rel.Z, rel.X)), -50, 50)
	end
	self.lookYaw += (wantYaw - self.lookYaw) * math.min(1, dt * 5)

	local s = self.scale
	local boneCF = {}
	local boneScale = {}
	for i, b in self.data.bones do
		local r, x, y, sx, sy, ry, rx = channel(clip, b.n, self.time)
		if w < 1 then
			local r0, x0, y0, sx0, sy0, ry0, rx0 = channel(self.prev, b.n, self.prevTime)
			r, x, y = r0 + (r - r0) * w, x0 + (x - x0) * w, y0 + (y - y0) * w
			sx, sy = sx0 + (sx - sx0) * w, sy0 + (sy - sy0) * w
			ry, rx = ry0 + (ry - ry0) * w, rx0 + (rx - rx0) * w
		end
		if b.n == "head" then
			ry += self.lookYaw
		end
		local at = b.at
		local local_ = CFrame.new((at[1] + x) * s, (at[2] + y) * s, at[3] * s) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(b.r + r))
		boneCF[i] = if b.p then boneCF[self.boneIndex[b.p]] * local_ else root * local_
		boneScale[i] = Vector2.new(sx, sy)
	end

	-- Blinking and flame flicker.
	local blinking = false
	if #self.eyes > 0 then
		if now >= self.nextBlink then
			self.blinkUntil = now + 0.11
			self.nextBlink = now + 2 + math.random() * 3.5
		end
		blinking = now < self.blinkUntil
	end

	for i, entry in self.parts do
		local p = entry.data
		local bi = self.boneIndex[p.b]
		local sc = boneScale[bi]
		local sy = sc.Y
		if blinking and p.t == "eye" then
			sy *= 0.12
		elseif p.t == "flame" then
			sy *= 0.85 + 0.3 * math.noise(now * 6, i)
		end
		local o = p.o
		local cf = boneCF[bi] * CFrame.new(o[1] * s * sc.X, o[2] * s * sc.Y, o[3] * s) * CFrame.Angles(0, 0, math.rad(p.r))
		if entry.triRot then
			cf *= entry.triRot
		end
		self.cframes[i] = cf
		local want = Vector2.new(sc.X, sy)
		if (want - entry.lastScale).Magnitude > 0.01 then
			entry.lastScale = want
			local base = entry.base
			local size = Vector3.new(base.X * sc.X, base.Y * sy, base.Z)
			entry.part.Size = if entry.triRot then Vector3.new(size.Z, size.Y, size.X) else size
		end
	end
	workspace:BulkMoveTo(self.partList, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- Tint (hit flash, warning glow).
	if self.tintAmount > 0.001 or self.tinted then
		self.tinted = self.tintAmount > 0.001
		for _, entry in self.parts do
			if entry.data.m ~= "n" then
				entry.part.Color = if self.tinted and self.tintColor then entry.color:Lerp(self.tintColor, self.tintAmount) else entry.color
			end
		end
	end
end

function Rig:setTransparency(extra: number)
	for _, entry in self.parts do
		entry.part.Transparency = 1 - (1 - (entry.data.a or 0)) * (1 - extra)
	end
end

function Rig:partsWithTag(tag: string): { BasePart }
	local list = {}
	for _, entry in self.parts do
		if entry.data.t == tag then
			table.insert(list, entry.part)
		end
	end
	return list
end

function Rig:destroy()
	self.model:Destroy()
end

return Rig
