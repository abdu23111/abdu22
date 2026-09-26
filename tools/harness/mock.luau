-- A small, headless stand-in for the parts of the Roblox API the world builder uses, so the
-- real Builder/Props code can run under the standalone Luau interpreter. It records every
-- part, light, particle emitter and terrain fill so tools/harness can export and render them.
--
-- This is a test double, not an emulator: physics, rendering, replication and most services
-- are stubs. Anything the builder calls that isn't modelled raises an error, which is the
-- point: it catches runtime mistakes before they reach Studio.

local M = {}

-- ===== helpers =====

local function typed(t, name)
	return setmetatable(t, t.__mt or {})
end

local TYPE_KEY = "__rbxtype"

local function rtype(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and mt[TYPE_KEY] then
			return mt[TYPE_KEY]
		end
	end
	return t
end
M.typeof = rtype

-- ===== Vector3 =====

local V3 = {}
V3[TYPE_KEY] = "Vector3"
local Vector3 = {}

local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end

V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	elseif k == "z" then
		return v.Z
	end
	local f = Vector3[k]
	if f then
		return f
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("%g, %g, %g", a.X, a.Y, a.Z)
end

function Vector3.new(x, y, z)
	return v3(x or 0, y or 0, z or 0)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function Vector3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function Vector3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function Vector3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function Vector3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
M.Vector3 = Vector3

-- ===== Vector2 =====

local V2 = {}
V2[TYPE_KEY] = "Vector2"
local Vector2 = {}
local function v2(x, y)
	return setmetatable({ X = x, Y = y }, V2)
end
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	end
	return Vector2[k]
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function Vector2.new(x, y)
	return v2(x or 0, y or 0)
end
function Vector2.Lerp(a, b, t)
	return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t)
end
function Vector2.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
M.Vector2 = Vector2

-- ===== CFrame (rotation stored as rows of a 3x3 matrix) =====

local CF = {}
CF[TYPE_KEY] = "CFrame"
local CFrame = {}

local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, CF)
end

CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return v3(c[1], c[2], c[3])
	elseif k == "X" then
		return c[1]
	elseif k == "Y" then
		return c[2]
	elseif k == "Z" then
		return c[3]
	elseif k == "RightVector" or k == "XVector" then
		return v3(c[4], c[7], c[10])
	elseif k == "UpVector" or k == "YVector" then
		return v3(c[5], c[8], c[11])
	elseif k == "ZVector" then
		return v3(c[6], c[9], c[12])
	elseif k == "LookVector" then
		return v3(-c[6], -c[9], -c[12])
	elseif k == "Rotation" then
		return cf(0, 0, 0, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
	end
	local f = CFrame[k]
	if f then
		return f
	end
	error("CFrame has no member " .. tostring(k), 2)
end

local function mulRot(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[4 + i * 3 + k] * b[4 + k * 3 + j]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

local function applyRot(c, x, y, z)
	return c[4] * x + c[5] * y + c[6] * z, c[7] * x + c[8] * y + c[9] * z, c[10] * x + c[11] * y + c[12] * z
end

CF.__mul = function(a, b)
	local tb = rtype(b)
	if tb == "CFrame" then
		local r = mulRot(a, b)
		local x, y, z = applyRot(a, b[1], b[2], b[3])
		return cf(a[1] + x, a[2] + y, a[3] + z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
	elseif tb == "Vector3" then
		local x, y, z = applyRot(a, b.X, b.Y, b.Z)
		return v3(a[1] + x, a[2] + y, a[3] + z)
	end
	error("bad CFrame multiply with " .. tb, 2)
end
CF.__add = function(a, v)
	return cf(a[1] + v.X, a[2] + v.Y, a[3] + v.Z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
end
CF.__sub = function(a, v)
	return cf(a[1] - v.X, a[2] - v.Y, a[3] - v.Z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12])
end
CF.__eq = function(a, b)
	for i = 1, 12 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function fromRot(pos, r)
	return cf(pos.X, pos.Y, pos.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
end

local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end

local function fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end

function CFrame.new(a, b, c, ...)
	if a == nil then
		return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if type(a) == "number" then
		local extra = { ... }
		if #extra == 9 then
			return cf(a, b, c, table.unpack(extra))
		end
		return cf(a, b or 0, c or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if b ~= nil and rtype(b) == "Vector3" then
		return CFrame.lookAt(a, b)
	end
	return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
function CFrame.Angles(x, y, z)
	return rx(x) * ry(y) * rz(z)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return ry(y) * rx(x) * rz(z)
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0, t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.yAxis
	local look = (target - at)
	if look.Magnitude < 1e-9 then
		return CFrame.new(at)
	end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.xAxis)
		end
	end
	right = right.Unit
	local up2 = right:Cross(look).Unit
	return fromMatrix(at, right, up2, -look)
end
CFrame.fromMatrix = fromMatrix
function CFrame.Inverse(c)
	-- transpose rotation
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = c[4], c[7], c[10], c[5], c[8], c[11], c[6], c[9], c[12]
	local x, y, z = c[1], c[2], c[3]
	local ix = -(r00 * x + r01 * y + r02 * z)
	local iy = -(r10 * x + r11 * y + r12 * z)
	local iz = -(r20 * x + r21 * y + r22 * z)
	return cf(ix, iy, iz, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
function CFrame.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CFrame.ToWorldSpace(a, b)
	return a * b
end
function CFrame.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CFrame.PointToWorldSpace(a, v)
	return a * v
end
function CFrame.VectorToWorldSpace(a, v)
	local x, y, z = applyRot(a, v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CFrame.VectorToObjectSpace(a, v)
	return a:Inverse():VectorToWorldSpace(v)
end
function CFrame.GetComponents(c)
	return table.unpack(c)
end
CFrame.components = CFrame.GetComponents
function CFrame.Lerp(a, b, t)
	-- Position lerp; rotation snaps halfway (good enough for a headless build).
	local src = if t < 0.5 then a else b
	return cf(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, table.unpack(src, 4, 12))
end
function CFrame.ToEulerAnglesXYZ(c)
	local y = math.asin(math.clamp(c[6], -1, 1))
	local x = math.atan2(-c[9], c[12])
	local z = math.atan2(-c[5], c[4])
	return x, y, z
end
function CFrame.ToOrientation(c)
	local x = math.asin(math.clamp(-c[9], -1, 1))
	local y = math.atan2(c[6], c[12])
	local z = math.atan2(c[7], c[8])
	return x, y, z
end
CFrame.identity = cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
M.CFrame = CFrame

-- ===== Color3 & friends =====

local C3 = {}
C3[TYPE_KEY] = "Color3"
local Color3 = {}
local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
C3.__index = function(_, k)
	local f = Color3[k]
	if f then
		return f
	end
	if k == "r" or k == "g" or k == "b" then
		return nil
	end
	error("Color3 has no member " .. tostring(k), 2)
end
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
function Color3.new(r, g, b)
	return c3(r or 0, g or 0, b or 0)
end
function Color3.fromRGB(r, g, b)
	return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return c3(v, t, p)
	elseif i == 1 then
		return c3(q, v, p)
	elseif i == 2 then
		return c3(p, v, t)
	elseif i == 3 then
		return c3(p, q, v)
	elseif i == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
function Color3.fromHex(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function Color3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function Color3.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, if mx == 0 then 0 else d / mx, mx
end
M.Color3 = Color3

local function plainType(name, ctor)
	local mt = { [TYPE_KEY] = name }
	mt.__index = mt
	return function(...)
		local t = ctor(...)
		return setmetatable(t, mt)
	end
end

M.NumberRange = { new = plainType("NumberRange", function(a, b)
	return { Min = a, Max = b or a }
end) }
M.NumberSequence = { new = plainType("NumberSequence", function(...)
	return { args = { ... } }
end) }
M.ColorSequence = { new = plainType("ColorSequence", function(...)
	return { args = { ... } }
end) }
M.NumberSequenceKeypoint = { new = plainType("NumberSequenceKeypoint", function(t, v)
	return { Time = t, Value = v }
end) }
M.ColorSequenceKeypoint = { new = plainType("ColorSequenceKeypoint", function(t, v)
	return { Time = t, Value = v }
end) }
local UDimNew = plainType("UDim", function(s, o)
	return { Scale = s or 0, Offset = o or 0 }
end)
M.UDim = { new = UDimNew }
local UDim2New = plainType("UDim2", function(xs, xo, ys, yo)
	return { X = UDimNew(xs, xo), Y = UDimNew(ys, yo) }
end)
M.UDim2 = {
	new = UDim2New,
	fromScale = function(x, y)
		return UDim2New(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return UDim2New(0, x, 0, y)
	end,
}
M.TweenInfo = { new = plainType("TweenInfo", function(...)
	return { args = { ... } }
end) }
M.PhysicalProperties = { new = plainType("PhysicalProperties", function(...)
	return { args = { ... } }
end) }
M.BrickColor = { new = plainType("BrickColor", function(n)
	return { Name = n }
end) }
M.Rect = { new = plainType("Rect", function(...)
	return { args = { ... } }
end) }
M.Font = {
	new = plainType("Font", function(...)
		return { args = { ... } }
	end),
	fromEnum = plainType("Font", function(e)
		return { enum = e }
	end),
}
M.RaycastParams = { new = plainType("RaycastParams", function()
	return { FilterDescendantsInstances = {} }
end) }
M.OverlapParams = { new = plainType("OverlapParams", function()
	return { FilterDescendantsInstances = {} }
end) }

-- ===== Enum =====

local enumCache = {}
local EnumItemMT = { [TYPE_KEY] = "EnumItem" }
EnumItemMT.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
EnumItemMT.__index = function(_, k)
	error("EnumItem has no member " .. tostring(k), 2)
end
M.Enum = setmetatable({}, {
	__index = function(_, typeName)
		local group = enumCache[typeName]
		if not group then
			group = setmetatable({}, {
				__index = function(g, itemName)
					local item = setmetatable({ EnumType = typeName, Name = itemName, Value = 0 }, EnumItemMT)
					rawset(g, itemName, item)
					return item
				end,
			})
			enumCache[typeName] = group
		end
		return group
	end,
})

-- ===== Random (deterministic) =====

local RandomMT = { [TYPE_KEY] = "Random" }
RandomMT.__index = RandomMT
function RandomMT:_next()
	-- 32-bit xorshift
	local s = self.s
	s = bit32.bxor(s, bit32.lshift(s, 13))
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5))
	self.s = s
	return s / 4294967296
end
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RandomMT:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end
function RandomMT:NextUnitVector()
	local v = v3(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
	return v.Unit
end
M.Random = {
	new = function(seed)
		local s = math.floor(math.abs(seed or os.clock() * 1000)) % 4294967295
		if s == 0 then
			s = 2463534242
		end
		local r = setmetatable({ s = s }, RandomMT)
		for _ = 1, 4 do
			r:_next()
		end
		return r
	end,
}

-- ===== Signals =====

local SignalMT = { [TYPE_KEY] = "RBXScriptSignal" }
SignalMT.__index = SignalMT
function SignalMT:Connect(fn)
	table.insert(self.handlers, fn)
	local conn = { Connected = true }
	function conn.Disconnect()
		conn.Connected = false
	end
	return conn
end
SignalMT.Once = SignalMT.Connect
function SignalMT:Wait()
	return coroutine.yield()
end
function SignalMT:Fire(...)
	for _, h in self.handlers do
		h(...)
	end
end
local function signal()
	return setmetatable({ handlers = {} }, SignalMT)
end

-- ===== Instances =====

local ISA = {
	BasePart = { Part = true, WedgePart = true, CornerWedgePart = true, MeshPart = true, TrussPart = true, SpawnLocation = true, Seat = true, BasePart = true, UnionOperation = true },
	Light = { PointLight = true, SpotLight = true, SurfaceLight = true, Light = true },
	GuiObject = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true },
	LuaSourceContainer = { Script = true, LocalScript = true, ModuleScript = true },
	PVInstance = { Model = true, Part = true, WedgePart = true, CornerWedgePart = true, MeshPart = true, Workspace = true },
	ValueBase = { StringValue = true, NumberValue = true, IntValue = true, BoolValue = true, ObjectValue = true, Vector3Value = true },
	Constraint = { RopeConstraint = true, AlignOrientation = true, AlignPosition = true, WeldConstraint = true },
}

local PART_DEFAULTS = {
	Size = function()
		return v3(4, 1, 2)
	end,
	CFrame = function()
		return CFrame.identity
	end,
	Color = function()
		return Color3.fromRGB(163, 162, 165)
	end,
	Transparency = 0,
	Reflectance = 0,
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	CastShadow = true,
	Locked = false,
	Massless = false,
	Material = function()
		return M.Enum.Material.Plastic
	end,
	Shape = function()
		return M.Enum.PartType.Block
	end,
	TopSurface = function()
		return M.Enum.SurfaceType.Smooth
	end,
	BottomSurface = function()
		return M.Enum.SurfaceType.Smooth
	end,
}

local LIGHT_DEFAULTS = { Brightness = 1, Range = 8, Enabled = true, Shadows = false, Color = function()
	return c3(1, 1, 1)
end, Angle = 90 }

local SIGNAL_NAMES = {
	Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
	AncestryChanged = true, Touched = true, TouchEnded = true, Triggered = true, PromptShown = true, PromptHidden = true,
	Destroying = true, AttributeChanged = true, MouseButton1Click = true, Activated = true, Event = true, Completed = true,
	OnServerEvent = true, OnClientEvent = true, OnInvoke = true, Died = true, StateChanged = true, Heartbeat = true,
	RenderStepped = true, Stepped = true, PlayerAdded = true, PlayerRemoving = true, CharacterAdded = true,
	InputBegan = true, InputEnded = true, InputChanged = true, TriggerEnded = true, Ended = true,
}

local Inst = {}
local InstMT = { [TYPE_KEY] = "Instance" }
M.allInstances = {}

local function isA(inst, cls)
	local own = rawget(inst, "_class")
	if own == cls or cls == "Instance" then
		return true
	end
	local group = ISA[cls]
	return group ~= nil and group[own] == true
end

InstMT.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	if k == "Position" and props.CFrame then
		return props.CFrame.Position
	elseif k == "Orientation" then
		return v3(0, 0, 0)
	elseif k == "ClassName" then
		return rawget(self, "_class")
	elseif k == "Parent" then
		return nil
	end
	local method = Inst[k]
	if method then
		return method
	end
	if SIGNAL_NAMES[k] then
		local s = signal()
		props[k] = s
		return s
	end
	for _, child in rawget(self, "_children") do
		if rawget(child, "_props").Name == k then
			return child
		end
	end
	-- Unset but plausible properties return nil only for known classes of fields.
	local cls = rawget(self, "_class")
	if isA(self, "BasePart") and PART_DEFAULTS[k] ~= nil then
		local d = PART_DEFAULTS[k]
		return if type(d) == "function" then d() else d
	end
	if isA(self, "Light") and LIGHT_DEFAULTS[k] ~= nil then
		local d = LIGHT_DEFAULTS[k]
		return if type(d) == "function" then d() else d
	end
	if cls == "Model" and k == "PrimaryPart" then
		return nil
	end
	if cls == "Workspace" and k == "CurrentCamera" then
		return nil
	end
	error(string.format("%s.%s is not a valid member (mock)", cls, tostring(k)), 2)
end

local function setParent(self, parent)
	local old = rawget(self, "_props").Parent
	if old == parent then
		return
	end
	if old then
		local list = rawget(old, "_children")
		for i, c in list do
			if c == self then
				table.remove(list, i)
				break
			end
		end
	end
	rawget(self, "_props").Parent = parent
	if parent then
		table.insert(rawget(parent, "_children"), self)
	end
end

-- Properties scripts are actually allowed to set on Terrain (others, like Decoration, are
-- Studio-only and throw in a real game).
local TERRAIN_WRITABLE = { Name = true, Parent = true, WaterColor = true, WaterReflectance = true, WaterTransparency = true, WaterWaveSize = true, WaterWaveSpeed = true }

InstMT.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	if rawget(self, "_class") == "Terrain" and not TERRAIN_WRITABLE[k] then
		error("Unable to assign property " .. tostring(k) .. ". Property is not scriptable (mock)", 2)
	end
	if k == "Parent" then
		setParent(self, v)
	elseif k == "Position" then
		local c = props.CFrame or CFrame.identity
		props.CFrame = cf(v.X, v.Y, v.Z, table.unpack(c, 4, 12))
	elseif k == "Orientation" then
		local p = (props.CFrame or CFrame.identity).Position
		props.CFrame = CFrame.new(p) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	elseif k == "Size" and props.Shape and props.Shape.Name == "Ball" then
		local s = math.min(v.X, v.Y, v.Z)
		props.Size = v3(s, s, s)
	elseif k == "Shape" and v.Name == "Ball" and props.Size then
		props.Shape = v
		local s = math.min(props.Size.X, props.Size.Y, props.Size.Z)
		props.Size = v3(s, s, s)
	else
		props[k] = v
	end
end
InstMT.__tostring = function(self)
	return rawget(self, "_props").Name
end

local function newInstance(className, parent)
	local self = setmetatable({ _class = className, _props = { Name = className }, _children = {}, _attrs = {} }, InstMT)
	if className == "Part" or className == "WedgePart" or className == "CornerWedgePart" or className == "TrussPart" then
		rawget(self, "_props").CFrame = CFrame.identity
		rawget(self, "_props").Size = if className == "Part" then v3(4, 1, 2) else v3(4, 1, 2)
	end
	table.insert(M.allInstances, self)
	if parent then
		self.Parent = parent
	end
	return self
end
M.newInstance = newInstance

function Inst:IsA(cls)
	return isA(self, cls)
end
function Inst:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in rawget(n, "_children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(name, recursive)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_props").Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "_children") do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst:WaitForChild(name)
	local c = self:FindFirstChild(name)
	if not c then
		error("WaitForChild would hang forever: " .. tostring(self) .. "." .. name, 2)
	end
	return c
end
function Inst:FindFirstChildOfClass(cls)
	for _, c in rawget(self, "_children") do
		if rawget(c, "_class") == cls then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(cls)
	for _, c in rawget(self, "_children") do
		if isA(c, cls) then
			return c
		end
	end
	return nil
end
function Inst:FindFirstAncestorOfClass(cls)
	local p = rawget(self, "_props").Parent
	while p do
		if rawget(p, "_class") == cls then
			return p
		end
		p = rawget(p, "_props").Parent
	end
	return nil
end
function Inst:FindFirstAncestor(name)
	local p = rawget(self, "_props").Parent
	while p do
		if rawget(p, "_props").Name == name then
			return p
		end
		p = rawget(p, "_props").Parent
	end
	return nil
end
function Inst:IsDescendantOf(other)
	local p = rawget(self, "_props").Parent
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "_props").Parent
	end
	return false
end
function Inst:SetAttribute(k, v)
	rawget(self, "_attrs")[k] = v
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end
function Inst:GetAttributeChangedSignal()
	return signal()
end
function Inst:GetPropertyChangedSignal()
	return signal()
end
function Inst:Destroy()
	setParent(self, nil)
	rawset(self, "_destroyed", true)
end
function Inst:ClearAllChildren()
	for _, c in table.clone(rawget(self, "_children")) do
		c:Destroy()
	end
end
function Inst:Clone()
	local copy = newInstance(rawget(self, "_class"))
	for k, v in rawget(self, "_props") do
		if k ~= "Parent" then
			rawget(copy, "_props")[k] = v
		end
	end
	for k, v in rawget(self, "_attrs") do
		rawget(copy, "_attrs")[k] = v
	end
	for _, c in rawget(self, "_children") do
		c:Clone().Parent = copy
	end
	return copy
end
function Inst:GetFullName()
	local names = {}
	local n = self
	while n do
		table.insert(names, 1, rawget(n, "_props").Name)
		n = rawget(n, "_props").Parent
	end
	return table.concat(names, ".")
end
-- Model
function Inst:GetPivot()
	local pp = rawget(self, "_props").PrimaryPart
	if pp then
		return pp.CFrame
	end
	return rawget(self, "_props").CFrame or CFrame.identity
end
function Inst:PivotTo(target)
	local cls = rawget(self, "_class")
	if cls == "Model" then
		local pivot = self:GetPivot()
		local delta = target * pivot:Inverse()
		for _, d in self:GetDescendants() do
			if isA(d, "BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		if not rawget(self, "_props").PrimaryPart then
			rawget(self, "_props").CFrame = target
		end
	else
		self.CFrame = target
	end
end
Inst.SetPrimaryPartCFrame = Inst.PivotTo
function Inst:GetBoundingBox()
	return self:GetPivot(), v3(4, 4, 4)
end
function Inst:ScaleTo() end
-- Parts / effects / sounds / tags
function Inst:Emit() end
function Inst:Play() end
function Inst:Stop() end
function Inst:Pause() end
function Inst:Resume() end
function Inst:Clear() end
function Inst:AddTag(tag)
	rawget(self, "_attrs")["__tag_" .. tag] = true
end
function Inst:HasTag(tag)
	return rawget(self, "_attrs")["__tag_" .. tag] == true
end
function Inst:RemoveTag() end
function Inst:SetNetworkOwner() end
function Inst:ApplyImpulse() end
function Inst:BreakJoints() end

M.Instance = {
	new = function(className, parent)
		return newInstance(className, parent)
	end,
}

-- ===== Terrain =====

M.terrainOps = {}
M.materialColors = {}

local function makeTerrain(workspaceInst)
	local terrain = newInstance("Terrain", workspaceInst)
	terrain.Name = "Terrain"
	local ops = M.terrainOps
	local function matName(m)
		assert(rtype(m) == "EnumItem" and m.EnumType == "Material", "terrain fill needs an Enum.Material")
		return m.Name
	end
	rawset(terrain, "FillBlock", function(_, c, size, mat)
		assert(rtype(c) == "CFrame" and rtype(size) == "Vector3", "FillBlock(CFrame, Vector3, Material)")
		table.insert(ops, { "block", c, size, matName(mat) })
	end)
	rawset(terrain, "FillBall", function(_, center, radius, mat)
		assert(rtype(center) == "Vector3" and type(radius) == "number", "FillBall(Vector3, number, Material)")
		table.insert(ops, { "ball", center, radius, matName(mat) })
	end)
	rawset(terrain, "FillCylinder", function(_, c, height, radius, mat)
		assert(rtype(c) == "CFrame" and type(height) == "number" and type(radius) == "number", "FillCylinder(CFrame, number, number, Material)")
		table.insert(ops, { "cylinder", c, height, radius, matName(mat) })
	end)
	rawset(terrain, "FillWedge", function(_, c, size, mat)
		assert(rtype(c) == "CFrame" and rtype(size) == "Vector3", "FillWedge(CFrame, Vector3, Material)")
		table.insert(ops, { "wedge", c, size, matName(mat) })
	end)
	rawset(terrain, "SetMaterialColor", function(_, mat, color)
		M.materialColors[matName(mat)] = color
	end)
	rawset(terrain, "GetMaterialColor", function(_, mat)
		return M.materialColors[matName(mat)] or c3(0.5, 0.5, 0.5)
	end)
	rawset(terrain, "Clear", function()
		table.clear(ops)
	end)
	rawset(terrain, "FillRegion", function() end)
	return terrain
end

-- ===== DataModel =====

function M.createGame()
	local game = newInstance("DataModel")
	game.Name = "game"
	local services = {}
	local function service(name, className)
		local s = newInstance(className or name, game)
		s.Name = name
		services[name] = s
		return s
	end
	local ws = service("Workspace")
	M.terrain = makeTerrain(ws)
	for _, n in { "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "Lighting", "SoundService", "StarterGui" } do
		service(n)
	end
	local players = service("Players")
	rawset(players, "GetPlayers", function()
		return {}
	end)
	local tween = service("TweenService")
	rawset(tween, "Create", function()
		return { Play = function() end, Cancel = function() end, Pause = function() end, Completed = signal() }
	end)
	local run = service("RunService")
	rawset(run, "IsServer", function()
		return true
	end)
	rawset(run, "IsClient", function()
		return false
	end)
	rawset(run, "IsStudio", function()
		return true
	end)
	local http = service("HttpService")
	rawset(http, "JSONEncode", function()
		return "[]"
	end)
	rawset(http, "JSONDecode", function()
		return {}
	end)
	rawset(http, "GenerateGUID", function()
		return "00000000-0000-0000-0000-000000000000"
	end)
	local cs = service("CollectionService")
	rawset(cs, "AddTag", function(_, inst, tag)
		inst:AddTag(tag)
	end)
	rawset(cs, "GetTagged", function()
		return {}
	end)
	local debris = service("Debris")
	rawset(debris, "AddItem", function() end)
	local physics = service("PhysicsService")
	rawset(physics, "RegisterCollisionGroup", function() end)
	rawset(physics, "CollisionGroupSetCollidable", function() end)
	service("ProximityPromptService")
	rawset(game, "GetService", function(_, name)
		local s = services[name]
		if not s then
			error("mock has no service " .. name, 2)
		end
		return s
	end)
	rawset(ws, "Raycast", function()
		return nil
	end)
	rawset(ws, "GetPartBoundsInBox", function()
		return {}
	end)
	rawset(ws, "GetPartBoundsInRadius", function()
		return {}
	end)
	rawset(ws, "Spherecast", function()
		return nil
	end)
	rawset(ws, "BulkMoveTo", function() end)
	M.game = game
	M.workspace = ws
	return game
end

-- ===== task library (spawned threads that yield are simply parked) =====

-- Threads started with task.spawn/defer; only these are parked by task.wait (the main
-- build runs straight through, as it would in a real server with time to spare).
local spawned = setmetatable({}, { __mode = "k" })

M.task = {
	wait = function(t)
		local co = coroutine.running()
		if co and spawned[co] and coroutine.isyieldable() then
			coroutine.yield()
		end
		return t or 0
	end,
	spawn = function(f, ...)
		local co = if type(f) == "thread" then f else coroutine.create(f)
		spawned[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end,
	defer = function(f, ...)
		local co = coroutine.create(f)
		spawned[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end,
	delay = function() end,
	cancel = function() end,
}

-- ===== module loader =====

-- `sources` maps instance paths like "ReplicatedStorage/Shared/Config" to Luau source.
function M.mountSources(game, sources)
	local byPath = {}
	for path, src in sources do
		local parts = string.split(path, "/")
		local node = game:GetService(parts[1])
		for i = 2, #parts do
			local name = parts[i]
			local child = node:FindFirstChild(name)
			if not child then
				local cls = if i == #parts then "ModuleScript" else "Folder"
				child = newInstance(cls, node)
				child.Name = name
			elseif i == #parts and rawget(child, "_class") == "Folder" then
				-- init.luau: the folder itself is the module.
				rawset(child, "_class", "ModuleScript")
			end
			node = child
		end
		rawset(node, "_source", src)
		rawset(node, "_path", path)
		byPath[path] = node
	end
	return byPath
end

function M.makeEnv(extra)
	local cache = {}
	local env = {}
	local function requireModule(module)
		if cache[module] ~= nil then
			return cache[module]
		end
		local src = rawget(module, "_source")
		assert(src, "require: no source for " .. tostring(module))
		local fn, err = loadstring(src, "=" .. rawget(module, "_path"))
		assert(fn, err)
		local modEnv = setmetatable({ script = module }, { __index = env })
		setfenv(fn, modEnv)
		local result = fn()
		cache[module] = result
		return result
	end
	local globals = {
		game = M.game,
		workspace = M.workspace,
		Instance = M.Instance,
		Vector3 = M.Vector3,
		Vector2 = M.Vector2,
		CFrame = M.CFrame,
		Color3 = M.Color3,
		Enum = M.Enum,
		Random = M.Random,
		NumberRange = M.NumberRange,
		NumberSequence = M.NumberSequence,
		ColorSequence = M.ColorSequence,
		NumberSequenceKeypoint = M.NumberSequenceKeypoint,
		ColorSequenceKeypoint = M.ColorSequenceKeypoint,
		UDim = M.UDim,
		UDim2 = M.UDim2,
		TweenInfo = M.TweenInfo,
		PhysicalProperties = M.PhysicalProperties,
		BrickColor = M.BrickColor,
		Rect = M.Rect,
		Font = M.Font,
		RaycastParams = M.RaycastParams,
		OverlapParams = M.OverlapParams,
		task = M.task,
		typeof = M.typeof,
		require = requireModule,
		tick = os.clock,
		time = os.clock,
		wait = M.task.wait,
		spawn = M.task.spawn,
		delay = M.task.delay,
		warn = function(...)
			print("[warn]", ...)
		end,
	}
	for k, v in extra or {} do
		globals[k] = v
	end
	setmetatable(env, { __index = function(_, k)
		local g = globals[k]
		if g ~= nil then
			return g
		end
		return (getfenv(0) :: any)[k]
	end })
	return env, requireModule
end

return M
