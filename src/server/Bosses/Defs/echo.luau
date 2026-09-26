-- The Hollow Echo: every lantern-bearer who turned back, gathered into one shape by the dark.
-- It fights like you do: dashing slashes, diving strikes and bolts of shadow.
-- Phase 2 (two thirds): triple bolts. Phase 3 (one third): shadow clones rush from both sides.

local MASK = Color3.fromRGB(236, 236, 242)
local SHADE = Color3.fromRGB(12, 12, 16)
local GLOW = Color3.fromRGB(205, 195, 255)

return {
	name = "The Hollow Echo",
	title = "All Who Turned Back",
	hp = 360,
	size = Vector3.new(3, 5.5, 2.5),
	flying = false,
	phases = { 0.66, 0.33 },
	geo = 500,
	parts = {
		{ shape = Enum.PartType.Ball, size = Vector3.new(2.8, 3.8, 2.4), offset = Vector3.new(0, -0.8, 0), color = SHADE, anim = "breath" },
		{ size = Vector3.new(0.3, 3.6, 2.2), offset = Vector3.new(-1.3, -0.9, 0), color = SHADE, anim = "cape" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(1.9, 2, 1.8), offset = Vector3.new(0, 1.6, 0.1), color = MASK, anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.65, 0.3), offset = Vector3.new(0.4, 1.6, 0.95), color = SHADE, anim = "breath" },
		{ shape = Enum.PartType.Ball, size = Vector3.new(0.35, 0.65, 0.3), offset = Vector3.new(-0.4, 1.6, 0.95), color = SHADE, anim = "breath" },
		{ size = Vector3.new(0.28, 1.5, 0.28), offset = Vector3.new(0.55, 3, 0), rz = -0.35, color = MASK, anim = "breath" },
		{ size = Vector3.new(0.28, 1.5, 0.28), offset = Vector3.new(-0.55, 3, 0), rz = 0.35, color = MASK, anim = "breath" },
		{ size = Vector3.new(0.25, 3.4, 0.25), offset = Vector3.new(1.6, -0.2, 0.8), rz = 0.9, color = GLOW, neon = true },
	},
	onPhase = function(b)
		-- Flickers away and back, shedding shadow.
		b.dust(b.position)
		b.hide()
		b.wait(0.4)
		b.appear(Vector3.new(b.clampX((b.minX + b.maxX) / 2), b.groundY, 0))
	end,
	run = function(b)
		local function shadeBolt(y: number)
			b.projectile(Vector3.new(b.position.X + b.dir * 2, y, 0), Vector3.new(b.dir * 42, 0, 0), { color = GLOW, radius = 1, lifetime = 3 })
		end
		while true do
			local roll = b.rng:NextInteger(1, if b.phase >= 3 then 4 else 3)
			if roll == 1 then
				-- Dash slash across the arena.
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				b.moveTo(b.clampX(b.targetPos().X + b.dir * 10), b.groundY, 72)
				b.wait(0.15)
				if b.phase >= 2 then
					b.faceTarget()
					b.telegraph(0.25)
					b.moveTo(b.clampX(b.targetPos().X + b.dir * 10), b.groundY, 72)
				end
				b.wait(b.pace(0.6))
			elseif roll == 2 then
				-- Leap high, hang, then dive onto the player.
				b.telegraph(0.3)
				b.moveTo(b.position.X, b.groundY + 16, 60)
				local target = b.clampX(b.targetPos().X)
				b.line(b.position, Vector3.new(target, b.groundY, 0), 0.4)
				b.moveTo(target, b.groundY, 90)
				b.shake(0.6)
				b.shockwaves(34)
				b.wait(b.pace(0.6))
			elseif roll == 3 then
				-- Shadow bolts: one at chest height, or three at different heights in later phases.
				b.faceTarget()
				b.telegraph(0.45)
				if b.phase >= 2 then
					local heights = { b.floorY + 1.5, b.floorY + 6, b.floorY + 11 }
					for _ = 1, 3 do
						local pick = table.remove(heights, b.rng:NextInteger(1, #heights)) :: number
						shadeBolt(pick)
						b.wait(0.35)
					end
				else
					shadeBolt(b.floorY + 2.5)
				end
				b.wait(b.pace(0.7))
			else
				-- Clone rush: two shadows charge in from the arena edges.
				b.telegraph(0.4)
				local y = b.floorY + 2.5
				b.marker(b.minX + 2, 3, 0.7)
				b.marker(b.maxX - 2, 3, 0.7)
				b.wait(0.7)
				b.projectile(Vector3.new(b.minX, y, 0), Vector3.new(40, 0, 0), { color = GLOW, radius = 1.4, lifetime = 3, passWalls = true })
				b.projectile(Vector3.new(b.maxX, y, 0), Vector3.new(-40, 0, 0), { color = GLOW, radius = 1.4, lifetime = 3, passWalls = true })
				b.wait(b.pace(1.2))
			end
		end
	end,
}
