--!strict
-- Movement abilities. Each is stored as a boolean attribute on the Player.

export type Ability = {
	attribute: string,
	name: string,
	hint: string,
}

local Abilities: { [string]: Ability } = {
	dash = {
		attribute = "HasDash",
		name = "Drift Cloak",
		hint = "Press SHIFT (or L) to dash through the air.",
	},
	claws = {
		attribute = "HasClaws",
		name = "Thorn Claws",
		hint = "Jump into a rough wall to cling. Jump again to leap off it.",
	},
	wings = {
		attribute = "HasWings",
		name = "Veil Wings",
		hint = "Press JUMP again while airborne to take flight once more.",
	},
}

return Abilities
