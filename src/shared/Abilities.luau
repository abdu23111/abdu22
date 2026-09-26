--!strict
-- Unlockable abilities. Each is stored as a boolean attribute on the Player.

export type Ability = {
	attribute: string,
	name: string,
	hint: string,
	order: number,
}

local Abilities: { [string]: Ability } = {
	dash = {
		attribute = "HasDash",
		name = "Drift Cloak",
		hint = "Press SHIFT (or L) to dash through the air.",
		order = 1,
	},
	cleave = {
		attribute = "HasCleave",
		name = "Cleaving Arc",
		hint = "Hold the nail button, then release for a wide, heavy slash. It shatters crystal seals.",
		order = 2,
	},
	claws = {
		attribute = "HasClaws",
		name = "Thorn Claws",
		hint = "Jump into a rough wall to cling. Jump again to leap off it.",
		order = 3,
	},
	bolt = {
		attribute = "HasBolt",
		name = "Lumen Bolt",
		hint = "Press R to spend Soul on a piercing bolt of light. It wakes Lumen sigils.",
		order = 4,
	},
	wings = {
		attribute = "HasWings",
		name = "Veil Wings",
		hint = "Press JUMP again while airborne to take flight once more.",
		order = 5,
	},
	shade = {
		attribute = "HasShade",
		name = "Umbral Cloak",
		hint = "Your dash turns to shadow and passes through enemies and attacks. It recharges in a moment.",
		order = 6,
	},
}

return Abilities
