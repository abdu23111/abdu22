-- The Thornwidow, Weaver of Wings: she wove the choir's wings and waits for them to return.
-- Phase 2 (half health): double web volleys and a web rain while she hangs from the ceiling.

local MASK = Color3.fromRGB(232, 228, 218)
local WEB = Color3.fromRGB(235, 235, 245)

local parts = {
	{ shape = Enum.PartType.Ball, size = Vector3.new(5, 4.2, 5), offset = Vector3.new(-2.4, 0.8, 0), color = Color3.fromRGB(40, 36, 48), anim = "breath" },
	{ shape = Enum.PartType.Ball, size = Vector3.new(3.6, 3, 3.8), offset = Vector3.new(0.8, 0, 0), color = Color3.fromRGB(54, 48, 60) },
	{ shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.2, 2.4), offset = Vector3.new(2.6, 0.3, 0.4), color = MASK },
	{ shape = Enum.PartType.Ball, size = Vector3.new(0.45, 0.45, 0.3), offset = Vector3.new(3.4, 0.7, 1.5), color = Color3.fromRGB(255, 70, 90), neon = true },
	{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.35, 0.3), offset = Vector3.new(3.0, 0.1, 1.6), color = Color3.fromRGB(255, 70, 90), neon = true },
	{ shape = Enum.PartType.Ball, size = Vector3.new(1, 1, 0.4), offset = Vector3.new(-2.6, 1.6, 2.3), color = Color3.fromRGB(150, 255, 170), neon = true, transparency = 0.2 },
}
for i = 1, 4 do
	local x = -1.8 + (i - 1) * 1.3
	table.insert(parts, { size = Vector3.new(0.3, 4, 0.3), offset = Vector3.new(x, -1.6, 1.8), rz = if i % 2 == 0 then 0.6 else -0.5, color = Color3.fromRGB(28, 24, 32), anim = if i % 2 == 0 then "leg" else "legB" })
	table.insert(parts, { size = Vector3.new(0.3, 4, 0.3), offset = Vector3.new(x + 0.5, -1.6, -1.8), rz = if i % 2 == 0 then -0.5 else 0.6, color = Color3.fromRGB(22, 20, 26), anim = if i % 2 == 0 then "legB" else "leg" })
end

return {
	name = "The Thornwidow",
	title = "Weaver of Wings",
	hp = 230,
	size = Vector3.new(8, 5, 6),
	flying = false,
	phases = { 0.5 },
	reward = "wings",
	geo = 260,
	parts = parts,
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				for _ = 1, if b.phase >= 2 then 2 else 1 do
					b.faceTarget()
					b.telegraph(0.4)
					local aim = b.targetPos() - b.position
					local base = math.atan2(aim.Y, aim.X)
					for _, spread in { -0.28, 0, 0.28 } do
						local a = base + spread
						b.projectile(b.position, Vector3.new(math.cos(a), math.sin(a), 0) * 30, { color = WEB, radius = 0.8, lifetime = 3 })
					end
					b.wait(0.5)
				end
				b.wait(b.pace(0.5))
			elseif roll == 2 then
				-- Climb to the ceiling, stalk the player, then drop.
				local top = b.ceilY - b.size.Y / 2
				b.moveTo(b.position.X, top, 34)
				local stalk = 1.2
				local dropTimer = 0
				while stalk > 0 do
					local dt = b.step()
					stalk -= dt
					dropTimer -= dt
					local tx = b.clampX(b.targetPos().X)
					local x = b.position.X + math.clamp(tx - b.position.X, -22 * dt, 22 * dt)
					b.position = Vector3.new(x, top, 0)
					if b.phase >= 2 and dropTimer <= 0 then
						dropTimer = 0.3
						b.projectile(Vector3.new(b.randomX(), top, 0), Vector3.new(0, -26, 0), { color = WEB, radius = 0.6, lifetime = 3 })
					end
				end
				b.marker(b.position.X, b.size.X, 0.4)
				b.telegraph(0.4)
				b.moveTo(b.position.X, b.groundY, 80)
				b.shake(0.7)
				b.shockwaves(26)
				b.wait(b.pace(0.8))
			else
				b.faceTarget()
				b.telegraph(0.35)
				b.moveTo(b.clampX(b.targetPos().X + b.dir * 4), b.groundY, 42)
				b.wait(b.pace(0.6))
			end
		end
	end,
}
