--!strict
-- NPC and lore-tablet text. Each entry lists line sets; the first set whose `when`
-- attribute is true on the Player is used (a set without `when` is the fallback).

export type LineSet = { when: string?, lines: { string } }
export type Speaker = { name: string, title: string?, shop: string?, sets: { LineSet } }

local Dialogue: { [string]: Speaker } = {
	wick = {
		name = "Old Wick",
		title = "Keeper of the First Bench",
		sets = {
			{
				when = "FinalBossDefeated",
				lines = {
					"...Do you feel that? Warmth, rising through the stone.",
					"The Great Lamp burns again. I had forgotten its colour.",
					"Rest here as long as you like, little lampless one. You have earned the quiet.",
				},
			},
			{
				when = "EchoDefeated",
				lines = {
					"You went all the way down, didn't you? To where the old lanterns lie.",
					"You look... lighter. As if you're carrying fewer ghosts. Go on. The lamp is waiting.",
				},
			},
			{
				when = "HasWings",
				lines = {
					"Wings of veil-silk... The Sanctum lies beyond the high ledges of the Hush.",
					"Whoever waits there, they loved this kingdom once. Remember that when you raise your nail.",
				},
			},
			{
				when = "HasDash",
				lines = {
					"You bested the Tunneling Mother? Hah! The old burrows will sleep easier.",
					"East, past the thorn-pit, lie the Mothlight Ruins. Our capital, before the dimming.",
					"And that cloak could carry you to the high ledge in this very cave. The miners' tunnel starts there, down to Glimmerdeep.",
				},
			},
			{
				lines = {
					"Oh... a traveller. And carrying an unlit lantern, of all things.",
					"This is Vesperdeep, or what is left of it. Once, the Great Lamp lit every tunnel.",
					"Then it dimmed, and my people fell into the Hush: a sleep that hollows the shell.",
					"Rest at this bench whenever you are weary. It will remember you.",
					"If you mean to go deeper, you'll need to be quicker than you are. The Mother of these burrows guards a cloak of drifting silk.",
				},
			},
		},
	},
	tock = {
		name = "Brass Tock",
		title = "Nailsmith of the Ruins",
		shop = "nail",
		sets = {
			{
				lines = {
					"Tick. Tock. A customer! Haven't had one since the lamp went out.",
					"That nail of yours is dull as a sleeping beetle. Bring me Geo and I'll hone it.",
				},
			},
		},
	},
	ilo = {
		name = "Ilo",
		title = "Moss Pilgrim",
		sets = {
			{
				when = "HasWings",
				lines = {
					"The widow is gone... The Hush breathes more softly now.",
					"The Sanctum's door is high above the smooth stone. Only wings could reach it.",
				},
			},
			{
				lines = {
					"Shh. The forest is listening. It always listens.",
					"I came here to pray for the lamp, but the moss grew over my prayers.",
					"A widow nests below the roots. She wove wings once, for the Seraph's choir.",
					"Perhaps she would part with a pair... if you part her from her web.",
				},
			},
		},
	},
	sael = {
		name = "Sael",
		title = "The Last Acolyte",
		sets = {
			{
				when = "FinalBossDefeated",
				lines = {
					"You did it. The Seraph sleeps, and the lamp wakes.",
					"I will tend the flame now. Go, walk the kingdom in the light.",
				},
			},
			{
				lines = {
					"You have come so far, lampless one.",
					"Beyond this hall waits Asterion, the Moth Seraph. Our last and brightest keeper.",
					"When the lamp began to fail, Asterion chose darkness. 'Let them rest,' the Seraph said. 'Let the kingdom sleep.'",
					"But sleep became the Hush, and the Hush became an ending.",
					"Kindle your lantern at the altar beyond. Asterion will not let you pass gently.",
				},
			},
		},
	},
	tablet_burrows = {
		name = "Weathered Tablet",
		sets = {
			{
				lines = {
					"'WE DUG TOWARD THE WARMTH, AND THE WARMTH WAS A LAMP, AND THE LAMP WAS A KINGDOM.'",
					"The rest is scratched away by many small claws.",
				},
			},
		},
	},
	tablet_ruins = {
		name = "Weathered Tablet",
		sets = {
			{
				lines = {
					"'BY ORDER OF THE SERAPH: ALL LANTERNS ARE TO BE DIMMED AT THE SEVENTH BELL.'",
					"'THE KINGDOM WILL REST. THE KINGDOM MUST REST.'",
				},
			},
		},
	},
	tablet_forest = {
		name = "Mossy Tablet",
		sets = {
			{
				lines = {
					"'THE WIDOW WOVE A THOUSAND WINGS FOR THE CHOIR. THE CHOIR FLEW, AND SANG, AND WAS HEARD NO MORE.'",
				},
			},
		},
	},
	tablet_temple = {
		name = "Gilded Tablet",
		sets = {
			{
				lines = {
					"'A LANTERN WITHOUT FLAME IS STILL A LANTERN. IT REMEMBERS WHAT IT IS FOR.'",
				},
			},
		},
	},
	lirra = {
		name = "Lirra",
		title = "Wandering Merchant",
		shop = "wares",
		sets = {
			{
				lines = {
					"Oh! A customer who isn't sleeping. How refreshing.",
					"I trade in whatever the Hush leaves lying about. Have a look, and do mind the dust.",
				},
			},
		},
	},
	pell = {
		name = "Pell",
		title = "The Lost Miner",
		sets = {
			{
				when = "HasCleave",
				lines = {
					"You broke the Matron's shell and walked out with her swing. Hah! My old crew would've paid to see that.",
					"Those crystal seals all over the kingdom? One good Cleaving Arc and they'll shatter like sugar.",
				},
			},
			{
				lines = {
					"Careful, careful! Don't tread on the singing ones.",
					"These crystals hold memories, see. The lamp spilled them and the stone drank them up.",
					"Deeper in, the Matron guards her brood. She swings a blade of pure crystal that could split a mountain.",
					"Learn that swing, and no seal in Vesperdeep will stop you.",
				},
			},
		},
	},
	quill = {
		name = "Quill",
		title = "Drowned Scribe",
		sets = {
			{
				when = "HasBolt",
				lines = {
					"You carry the Archivist's light now. Use it kindly.",
					"There are sigils of old light across the kingdom. They wake only for a Lumen Bolt.",
					"One such sigil, high above the Verdant Hush, seals a way down to where lanterns go to forget.",
				},
			},
			{
				lines = {
					"Shh... the books are sleeping. So is Master Murrow, mostly.",
					"The Archivist wrote down every memory the lamp ever ate. Every one.",
					"Then the waters came, and the ink ran, and Master Murrow would not leave the pages.",
					"If you must wake the Archivist, beware the rising ink. It remembers everything it drowns.",
				},
			},
		},
	},
	oriel = {
		name = "Oriel",
		title = "The Faded Bearer",
		sets = {
			{
				when = "EchoDefeated",
				lines = {
					"It's quiet down there now. Thank you.",
					"Go and kindle the lamp. Tell it about us, the ones who turned back. We'd like to be remembered too.",
				},
			},
			{
				lines = {
					"Another lantern. Another little bearer, walking down into the dark.",
					"I came here too, long ago. I turned back at the Seraph's door. So did the others.",
					"Everything we lost gathered at the bottom of the Hollowroot. It has a shape now. It has your shape.",
					"If you face it... don't hate it. It is only afraid.",
				},
			},
		},
	},
	tablet_mines = {
		name = "Miner's Slate",
		sets = {
			{
				lines = {
					"'DO NOT STRIKE THE SINGING STONES. THEY ARE SOMEBODY'S GRANDMOTHER.'",
				},
			},
		},
	},
	tablet_archive = {
		name = "Waterlogged Index",
		sets = {
			{
				lines = {
					"'VOLUME 9,114: MEMORIES OF RAIN. VOLUME 9,115: MEMORIES OF RAIN (CONTINUED).'",
					"'VOLUME 9,116: THE LAST TIME ANYONE SAW THE SURFACE.'",
				},
			},
		},
	},
	tablet_hollow = {
		name = "Cracked Lantern",
		sets = {
			{
				lines = {
					"Someone scratched a name into this lantern's handle, then scratched it out again.",
				},
			},
		},
	},
	tablet_glowmire = {
		name = "Pilgrim's Marker",
		sets = {
			{
				lines = {
					"'HERE THE LIGHT GROWS WILD. TAKE NONE. LEAVE NONE. MIND THE STILL WATER.'",
					"Below, in a smaller hand: 'the rings above the lake will carry you, if you let go at the top.'",
				},
			},
		},
	},
	tablet_pass = {
		name = "Wayside Stone",
		sets = {
			{
				lines = {
					"'TRAVELLER. THE KINGDOM BELOW SLEEPS UNDER THE HUSH. ITS LAMP HAS GONE COLD.'",
					"'EAST LIES THE OLD DIGGING. REST AT THE BENCH, AND WALK SOFTLY.'",
				},
			},
		},
	},
	tablet_trials = {
		name = "Hall Inscription",
		sets = {
			{
				lines = {
					"'THOSE WHO FELL HERE STILL REMEMBER THE FIGHT. TOUCH THE STATUE AND NAME ONE.'",
					"'FIVE CHAMPIONS KEEP THIS HALL. BEAT EACH IN TURN, AND THE LAST WILL LEND YOU ITS SHADOW.'",
					"Scratched beneath: 'climb the pillars. wall to wall. don't look down.'",
				},
			},
		},
	},
}

return Dialogue
