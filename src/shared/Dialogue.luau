--!strict
-- NPC and lore-tablet text. Each entry lists line sets; the first set whose `when`
-- attribute is true on the Player is used (a set without `when` is the fallback).

export type LineSet = { when: string?, lines: { string } }
export type Speaker = { name: string, title: string?, shop: boolean?, sets: { LineSet } }

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
		shop = true,
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
}

return Dialogue
