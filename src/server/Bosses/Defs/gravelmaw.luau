-- Gravelmaw, the Tunneling Mother: a huge grub who guards the Ashen Burrows.
-- Phase 2 (half health): she digs faster and the ceiling sheds more stone.

local MASK = Color3.fromRGB(232, 228, 218)
local EMBER = Color3.fromRGB(255, 150, 60)
local STONE = Color3.fromRGB(150, 140, 130)

return {
	name = "Gravelmaw",
	title = "The Tunneling Mother",
	hp = 130,
	size = Vector3.new(9, 5.6, 6),
	flying = false,
	phases = { 0.5 },
	reward = "dash",
	geo = 120,
	parts = {
		{ shape = Enum.PartType.Ball, size = Vector3.new(4.5, 4.4, 5), offset = Vector3.new(-3, -0.6, 0), color = Color3.fromRGB(96, 84, 74), anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(5, 5.2, 5.5), offset = Vector3.new(-0.6, 0, 0), color = Color3.fromRGB(106, 92, 80), anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(5, 5.6, 5.8), offset = Vector3.new(1.8, 0.2, 0), color = Color3.fromRGB(96, 84, 74), anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(3.4, 3.6, 3.6), offset = Vector3.new(3.8, 0.4, 0.6), color = MASK },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.9, 0.3), offset = Vector3.new(4.7, 0.9, 2.2), color = EMBER, neon = true },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.8, 0.3), offset = Vector3.new(4.0, 1.1, 2.3), color = EMBER, neon = true },
		{ size = Vector3.new(0.5, 2.2, 0.6), offset = Vector3.new(5.3, -1, 1), rz = 0.6, color = Color3.fromRGB(40, 34, 30) },
		{ size = Vector3.new(0.5, 1.6, 0.6), offset = Vector3.new(-0.6, 3, 0), rz = 0.3, color = STONE },
		{ size = Vector3.new(0.5, 1.3, 0.6), offset = Vector3.new(-3, 1.8, 0), rz = 0.4, color = STONE },
	},
	run = function(b)
		while true do
			local roll = b.rng:NextInteger(1, 3)
			if roll == 1 then
				-- Charge into the wall, shaking loose falling stones (marked on the floor first).
				b.faceTarget()
				b.telegraph(0.6)
				b.moveTo(if b.dir > 0 then b.maxX else b.minX, b.groundY, 32)
				b.shake(0.8)
				local xs = {}
				for _ = 1, if b.phase >= 2 then 7 else 5 do
					local x = b.randomX()
					table.insert(xs, x)
					b.marker(x, 3, 0.55)
				end
				b.wait(0.55)
				for _, x in xs do
					b.projectile(Vector3.new(x, b.ceilY - 1.5, 0), Vector3.new(0, -30, 0), { gravity = 70, color = STONE, radius = 1.1, lifetime = 3 })
				end
				b.wait(b.pace(0.9))
			elseif roll == 2 then
				-- Leap onto the player and send ripples along the floor.
				b.telegraph(0.45)
				local x = b.clampX(b.targetPos().X)
				b.marker(x, b.size.X, 0.5)
				b.leap(x, 16, 0.9)
				b.shake(0.5)
				b.shockwaves(28)
				b.wait(b.pace(0.7))
			else
				-- Burrow and burst up beneath the player.
				b.moveTo(b.position.X, b.floorY - b.size.Y, 14)
				b.wait(0.5)
				local x = b.clampX(b.targetPos().X)
				b.position = Vector3.new(x, b.position.Y, 0)
				b.dust(Vector3.new(x, b.floorY, 0))
				b.marker(x, b.size.X * 0.8, b.pace(0.75))
				b.wait(b.pace(0.75))
				b.moveTo(x, b.groundY, 46)
				for i = -2, 2 do
					b.projectile(b.position + Vector3.new(0, 2, 0), Vector3.new(i * 7, 34, 0), { gravity = 70, color = STONE, radius = 0.9, lifetime = 3 })
				end
				b.wait(b.pace(0.8))
			end
		end
	end,
}
