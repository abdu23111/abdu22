--!strict
-- Collectible memories: fragments of the kingdom's past, found as drifting motes of light.
-- Read together, they tell what really happened to the Great Lamp.

export type Memory = { title: string, order: number, lines: { string } }

local Memories: { [string]: Memory } = {
	first_light = {
		title = "First Light",
		order = 1,
		lines = {
			"A tunnel. Warmth ahead. A hundred small claws digging toward it.",
			"When the stone gave way, the light was so bright that nobody spoke for a whole day.",
			"They named the place Vesperdeep: the evening that goes down forever, and still has light at the bottom.",
		},
	},
	diggers_song = {
		title = "The Diggers' Song",
		order = 2,
		lines = {
			"'Dig, little claw, dig toward the glow, / the lamp remembers what we don't know.'",
			"Every burrow-child learned the song. Nobody ever asked what the second line meant.",
		},
	},
	seventh_bell = {
		title = "The Seventh Bell",
		order = 3,
		lines = {
			"The capital rang its bells seven times each evening, and at the seventh the lanterns were fed.",
			"Not with oil. Each household brought the lamp a single memory: a birthday, a joke, a first word.",
			"The lamp drank it, and burned warmer, and the household forgot. It seemed a small price.",
		},
	},
	lamplighters = {
		title = "The Lamplighters",
		order = 4,
		lines = {
			"The Lamplighters' guild kept careful ledgers of what was given.",
			"In the last pages the handwriting grows shaky. 'The lamp asks for more each year,' one writes.",
			"'Today my daughter gave her mother's face. She didn't cry. She couldn't remember why she should.'",
		},
	},
	widows_loom = {
		title = "The Widow's Loom",
		order = 5,
		lines = {
			"The weaver wove wings for the Seraph's choir: a thousand pairs, light as breath.",
			"The choir flew up into the lamp to sing it bright, and did not come down.",
			"She kept weaving long after. She said the lamp might send one back if the wings were beautiful enough.",
		},
	},
	pilgrims_prayer = {
		title = "A Pilgrim's Prayer",
		order = 6,
		lines = {
			"'Let me keep one thing. Just one. The sound of the rain on the high roots.'",
			"'Take the rest if you must. But leave me the rain.'",
		},
	},
	seraphs_choice = {
		title = "The Seraph's Choice",
		order = 7,
		lines = {
			"Asterion stood before the lamp and saw what it truly was: a hunger that would eat the kingdom's past until nothing remained.",
			"So the Seraph dimmed it. Let them sleep in the dark, Asterion thought, but let them keep who they are.",
			"The Hush was mercy. The Hush was also a slow ending. Asterion knew both, and chose anyway.",
		},
	},
	crystal_vein = {
		title = "The Crystal Vein",
		order = 8,
		lines = {
			"The miners found that the crystals of Glimmerdeep held light the way the lamp did.",
			"Break one, and for a moment you heard a stranger laughing, or a lullaby in a voice you never knew.",
			"The crystals were made of memories the lamp had spilled. The miners stopped breaking them.",
		},
	},
	matrons_brood = {
		title = "The Matron's Brood",
		order = 9,
		lines = {
			"Quartzelle grew her children inside the crystal so they'd never forget anything at all.",
			"They sang every song the kingdom had lost, over and over, and could not stop.",
		},
	},
	ink_and_ash = {
		title = "Ink and Ash",
		order = 10,
		lines = {
			"The Archivist Murrow wrote down every memory before it was fed to the lamp.",
			"'If the kingdom must forget,' Murrow wrote, 'then at least the pages will remember.'",
			"When the waters rose, Murrow stayed with the books. The ink ran, and so did Murrow's mind.",
		},
	},
	last_entry = {
		title = "The Last Entry",
		order = 11,
		lines = {
			"'The lamp does not need memories freely stolen. It needs one given freely, by someone with nothing else to lose.'",
			"'A vessel with an empty lantern. A child of no one. Someone the lamp has never fed upon.'",
			"The page is signed with an ink-blot shaped like a moth.",
		},
	},
	many_lanterns = {
		title = "So Many Lanterns",
		order = 12,
		lines = {
			"At the bottom of the Hollowroot lie hundreds of lanterns, all unlit, all the same as yours.",
			"You were not the first to come looking for the lamp. You are only the first to get this far.",
		},
	},
	lanterns_truth = {
		title = "The Lantern's Truth",
		order = 13,
		lines = {
			"The Echo was every bearer who turned back, gathered into one shape by the dark.",
			"It fought you because it was afraid. Not of dying. Of being remembered as a failure.",
			"When you kindle the lamp, give it this: that they tried. The kingdom can afford to remember that.",
		},
	},
}

return Memories
