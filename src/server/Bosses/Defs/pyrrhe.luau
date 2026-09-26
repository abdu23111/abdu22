-- Pyrrhe, the Ember Conductor: fifth and last champion of the Hall of Trials. A ringmaster of
-- living flame who blinks around the stage, conducts rows of fire pillars, bursts upward in a
-- column of flame and dives from on high. Beating her grants the Umbral Cloak.
-- Phase 2 (half health): pillars close in from both sides, and she spins a spiral of embers.

local FIRE = Color3.fromRGB(255, 120, 50)
local HOT = Color3.fromRGB(255, 200, 120)

return {
	name = "Pyrrhe",
	title = "The Ember Conductor",
	hp = 320,
	size = Vector3.new(4, 9, 3.5),
	flying = false,
	phases = { 0.5 },
	reward = "shade",
	geo = 300,
	onPhase = function(b)
		b.pillar(b.position.X, 6, 0.6, FIRE)
	end,
	run = function(b)
		local function embers(at: Vector3, n: number)
			for i = 1, n do
				local vx = (i - (n + 1) / 2) * 7
				b.projectile(at, Vector3.new(vx, b.rng:NextNumber(26, 36), 0), { color = HOT, radius = 0.6, gravity = 55, lifetime = 3, quiet = true })
			end
		end
		local last = 0
		while true do
			local roll = b.rng:NextInteger(1, if b.phase >= 2 then 5 else 4)
			if roll == last then
				roll = roll % 4 + 1
			end
			last = roll
			if roll == 1 then
				-- Fire bats: she blinks to a side and sends flames skimming at three heights.
				local side = if b.targetPos().X > (b.minX + b.maxX) / 2 then -1 else 1
				b.teleport(Vector3.new(if side < 0 then b.minX + 4 else b.maxX - 4, b.groundY, 0), FIRE)
				b.faceTarget()
				local n = if b.phase >= 2 then 4 else 3
				for i = 1, n do
					b.telegraph(b.pace(0.25))
					b.setAnim("shoot", true)
					local h = ({ -2.5, 4, 1, 7 })[i]
					b.projectile(b.position + Vector3.new(0, h, 0), b.facing * 42, { color = FIRE, radius = 1.1, lifetime = 3, passWalls = true, quiet = true })
					b.wait(0.2)
				end
				b.rest(0.5)
			elseif roll == 2 then
				-- Conducted pillars: flame columns march across the stage toward you.
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				b.setAnim("shoot", true)
				local xs = {}
				if b.phase >= 2 then
					for k = 0, 4 do
						table.insert(xs, b.minX + 6 + k * 13)
						table.insert(xs, b.maxX - 6 - k * 13)
					end
				else
					local x = b.position.X + b.facing.X * 8
					for _ = 1, 7 do
						if x < b.minX or x > b.maxX then
							break
						end
						table.insert(xs, x)
						x += b.facing.X * 13
					end
				end
				for i, x in xs do
					local delay = (if b.phase >= 2 then math.floor((i - 1) / 2) else i - 1) * 0.22
					task.delay(delay, function()
						if not b.cancelled then
							b.pillarWarn(x, 5, 0.55)
						end
					end)
					task.delay(delay + 0.55, function()
						if not b.cancelled then
							b.pillar(x, 5, 0.45, FIRE)
						end
					end)
				end
				b.wait(#xs * 0.22 + 0.9, "idle")
				b.rest(0.3)
			elseif roll == 3 then
				-- Uppercut: a dash across the floor that ends in a rising column of fire.
				local t = b.targetGround()
				local side = if b.rng:NextNumber() < 0.5 then -1 else 1
				b.teleport(b.clamp(Vector3.new(t.X + side * 22, b.groundY, 0)), FIRE)
				b.faceTarget()
				b.telegraph(b.pace(0.4))
				b.moveTo(Vector3.new(b.targetPos().X, b.groundY, 0), 85, "attack")
				b.setAnim("uppercut", true)
				b.pillar(b.position.X, 5, 0.5, FIRE)
				b.flyTo(b.position + Vector3.new(0, 20, 0), 80, "uppercut")
				embers(b.position, if b.phase >= 2 then 8 else 6)
				b.wait(0.25)
				b.flyTo(Vector3.new(b.position.X, b.groundY, 0), 70, "leap")
				b.setAnim("slam", true)
				b.rest(0.5)
			elseif roll == 4 then
				-- Air dash: from a high corner, a burning dive at you.
				local side = if b.rng:NextNumber() < 0.5 then -1 else 1
				b.teleport(Vector3.new(if side < 0 then b.minX + 6 else b.maxX - 6, b.ceilY - 10, 0), FIRE)
				b.faceTarget()
				b.telegraph(b.pace(0.45))
				local t = b.targetGround()
				b.flyTo(Vector3.new(t.X, b.groundY, 0), 105, "dive")
				b.setAnim("slam", true)
				b.shake(0.7)
				embers(b.position, 6)
				b.shockwaves(34, 30)
				b.rest(0.6)
			else
				-- Ember spiral (phase 2): she spins centre stage, flames spiralling out.
				b.teleport(b.center(), FIRE)
				b.telegraph(0.5)
				b.setAnim("spin", true)
				for wave = 1, 6 do
					for i = 1, 6 do
						local a = (i / 6 + wave * 0.045) * math.pi * 2
						b.projectile(b.position + Vector3.new(0, 1, 0), Vector3.new(math.cos(a) * 24, math.sin(a) * 24, 0), { color = FIRE, radius = 0.8, lifetime = 3.2, passWalls = true, quiet = true })
					end
					b.wait(0.2)
				end
				b.rest(0.7)
			end
		end
	end,
}
