-- The Archivist Murrow, Keeper of Drowned Words: a scholar moth who stayed with the books
-- when the waters rose. Carries the Lumen Bolt, the light Murrow read by.
-- Phase 2 (two thirds): the ink begins to rise. Phase 3 (one third): ink rain and faster blinks.

local MASK = Color3.fromRGB(232, 228, 218)
local ROBE = Color3.fromRGB(40, 70, 74)
local TEAL = Color3.fromRGB(110, 240, 230)
local PAGE = Color3.fromRGB(236, 228, 200)
local INK = Color3.fromRGB(16, 26, 30)

return {
	name = "Murrow",
	title = "Archivist of Drowned Words",
	hp = 280,
	size = Vector3.new(5, 7, 4),
	flying = true,
	phases = { 0.66, 0.33 },
	reward = "bolt",
	geo = 260,
	parts = {
		{ size = Vector3.new(4.5, 4, 0.2), offset = Vector3.new(-2.8, 1.2, -0.8), rz = 0.3, color = Color3.fromRGB(110, 130, 120), transparency = 0.2, flap = 0.25 },
		{ size = Vector3.new(4.5, 4, 0.2), offset = Vector3.new(2.8, 1.2, -0.8), rz = -0.3, color = Color3.fromRGB(110, 130, 120), transparency = 0.2, flap = -0.25 },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 6, 3), offset = Vector3.new(0, -0.5, 0), color = ROBE, anim = "breath" },
		{ size = Vector3.new(4, 1, 3), offset = Vector3.new(0, -3.2, 0), color = Color3.fromRGB(30, 56, 60), anim = "cape" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.2, 2.4, 2.2), offset = Vector3.new(0, 3, 0.2), color = MASK, anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.6, 0.3), offset = Vector3.new(0.45, 3.1, 1.15), color = TEAL, neon = true, anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.6, 0.3), offset = Vector3.new(-0.45, 3.1, 1.15), color = TEAL, neon = true, anim = "breath" },
		{ size = Vector3.new(0.2, 2, 0.2), offset = Vector3.new(0.5, 4.6, 0), rz = -0.4, color = PAGE },
		{ size = Vector3.new(0.2, 2, 0.2), offset = Vector3.new(-0.5, 4.6, 0), rz = 0.4, color = PAGE },
		{ size = Vector3.new(1.8, 0.4, 1.4), offset = Vector3.new(2.4, 0.2, 1.4), rz = 0.2, color = Color3.fromRGB(120, 80, 60), anim = "book" },
		{ size = Vector3.new(1.5, 0.12, 1.1), offset = Vector3.new(2.4, 0.45, 1.4), rz = 0.2, color = TEAL, neon = true, anim = "book" },
	},
	run = function(b)
		local function pageVolley(count: number)
			b.faceTarget()
			b.telegraph(0.45)
			local aim = b.targetPos() - b.position
			local base = math.atan2(aim.Y, aim.X)
			for i = 1, count do
				local a = base + (i - (count + 1) / 2) * 0.22
				b.projectile(b.position + Vector3.new(b.dir * 2, 0, 0), Vector3.new(math.cos(a), math.sin(a), 0) * 26, { color = PAGE, radius = 0.7, lifetime = 4, passWalls = true })
			end
		end
		local function blink()
			-- Vanishes in a swirl of ink and reappears above the player, then slams down.
			b.dust(b.position)
			b.hide()
			local x = b.clampX(b.targetPos().X + b.rng:NextNumber(-4, 4))
			b.marker(x, 5, b.pace(0.7))
			b.wait(b.pace(0.7))
			b.appear(Vector3.new(x, b.ceilY - b.size.Y, 0))
			b.telegraph(0.3)
			b.moveTo(x, b.floorY + b.size.Y / 2, 70)
			b.shake(0.6)
			b.shockwaves(24)
			b.wait(0.3)
			b.moveTo(x, b.ceilY - b.size.Y - 2, 24)
		end
		while true do
			local roll = b.rng:NextInteger(1, if b.phase >= 2 then 4 else 3)
			if roll == 1 then
				b.moveTo(b.randomX(), b.ceilY - b.rng:NextNumber(5, 9), 22)
				pageVolley(if b.phase >= 3 then 7 else 5)
				if b.phase >= 3 then
					b.wait(0.4)
					pageVolley(6)
				end
				b.wait(b.pace(0.7))
			elseif roll == 2 then
				blink()
				b.wait(b.pace(0.6))
			elseif roll == 3 then
				-- Ink rain: drops fall where the floor darkens.
				b.moveTo(b.clampX((b.minX + b.maxX) / 2), b.ceilY - 5, 26)
				b.telegraph(0.4)
				local xs = {}
				for _ = 1, if b.phase >= 3 then 12 else 8 do
					table.insert(xs, b.randomX())
				end
				for _, x in xs do
					b.marker(x, 2, 0.55)
				end
				b.wait(0.55)
				for _, x in xs do
					b.projectile(Vector3.new(x, b.ceilY - 1, 0), Vector3.new(0, -32, 0), { color = INK, radius = 0.8, lifetime = 3, passWalls = true })
					b.wait(0.06)
				end
				b.wait(b.pace(0.6))
			else
				-- The ink tide: the floor floods, and only the shelves are safe.
				b.moveTo(b.clampX((b.minX + b.maxX) / 2), b.ceilY - 4, 26)
				b.telegraph(0.6)
				b.inkTide(b.floorY + 5, if b.phase >= 3 then 4.5 else 3.5)
				pageVolley(5)
				b.wait(1.2)
				pageVolley(5)
				b.wait(b.pace(2))
			end
		end
	end,
}
