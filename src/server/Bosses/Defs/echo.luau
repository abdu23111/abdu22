-- The Hollow Echo: every lantern-bearer who turned back, gathered into one shape by the dark.
-- It fights like you do: dashing slashes, diving strikes and bolts of shadow.
-- Phase 2 (two thirds): chained dashes and triple bolts. Phase 3 (one third): shadow clones
-- rush in from both sides.

local GLOW = Color3.fromRGB(205, 195, 255)

return {
	name = "The Hollow Echo",
	title = "All Who Turned Back",
	hp = 360,
	size = Vector3.new(3, 5.5, 2.5),
	flying = false,
	phases = { 0.66, 0.33 },
	geo = 500,
	onPhase = function(b)
		-- Flickers away and back, shedding shadow.
		b.dust(b.position)
		b.hide()
		b.wait(0.4)
		b.appear(b.center())
	end,
	run = function(b)
		local function shadeBolt(height: number)
			local origin = b.position + b.facing * 2
			local target = b.targetPos()
			local dir = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Unit
			b.projectile(Vector3.new(origin.X, b.floorY + height, origin.Z), dir * 42, { color = GLOW, radius = 1, lifetime = 3 })
		end
		while true do
			local roll = b.rng:NextInteger(1, if b.phase >= 3 then 4 else 3)
			if roll == 1 then
				-- Dash slash through the player.
				for _ = 1, if b.phase >= 2 then 2 else 1 do
					b.faceTarget()
					b.telegraph(b.pace(0.4))
					b.moveTo(b.targetGround() + b.facing * 10, 72, "attack")
					b.wait(0.15)
				end
				b.rest(0.6)
			elseif roll == 2 then
				-- Spring high, hang, then dive onto the player.
				b.telegraph(0.3)
				b.moveTo(Vector3.new(b.position.X, b.groundY + 16, b.position.Z), 60, "leap")
				local target = b.clamp(b.targetGround())
				b.line(b.position, target, 0.4)
				b.moveTo(target, 90, "slam")
				b.shake(0.6)
				b.shockwaves(34)
				b.rest(0.6)
			elseif roll == 3 then
				-- Shadow bolts: one at chest height, or three at different heights later.
				b.faceTarget()
				b.telegraph(0.45)
				if b.phase >= 2 then
					local heights = { 1.5, 6, 11 }
					for _ = 1, 3 do
						shadeBolt(table.remove(heights, b.rng:NextInteger(1, #heights)) :: number)
						b.wait(0.35)
					end
				else
					shadeBolt(2.5)
				end
				b.rest(0.7)
			else
				-- Clone rush: two shadows charge in from either side of the player.
				b.telegraph(0.4)
				local t = b.targetGround()
				local side = Vector3.new(-b.facing.Z, 0, b.facing.X)
				local a, c = b.clamp(t + side * 18), b.clamp(t - side * 18)
				b.marker(a, 2, 0.7)
				b.marker(c, 2, 0.7)
				b.wait(0.7)
				local y = b.floorY + 2.5
				b.projectile(Vector3.new(a.X, y, a.Z), (t - a).Unit * 40, { color = GLOW, radius = 1.4, lifetime = 3, passWalls = true })
				b.projectile(Vector3.new(c.X, y, c.Z), (t - c).Unit * 40, { color = GLOW, radius = 1.4, lifetime = 3, passWalls = true, quiet = true })
				b.rest(1.2)
			end
		end
	end,
}
