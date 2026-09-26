# Vesperdeep

*A dark, atmospheric action-adventure metroidvania for Roblox, set in a buried kingdom of moths and beetles.*

The Great Lamp that once lit every tunnel of Vesperdeep has gone cold, and its people have fallen into the **Hush**, a sleep that hollows the shell. You are a small, masked wanderer carrying an unlit lantern. Explore seven interconnected regions, earn the abilities that open new paths, recover lost memories, and face the guardians standing between you and the lamp. Along the way you'll learn what the lamp really burned, and why its keeper let it go dark.

All characters, names, maps, dialogue, story, art and music in this project are original.

---

## Quick start

**Option A: just open it**
1. Download `Vesperdeep.rbxl` from this repo.
2. Double-click it (or open it from Roblox Studio with **File → Open from File**).
3. Press **Play** (F5). The world carves itself out of terrain when the game starts (give it a few seconds).

**Option B: live-sync the code with Rojo** (recommended if you'll edit it)
1. Install [Rojo](https://rojo.space) 7.4+ (e.g. `aftman install` with the included `aftman.toml`), plus the Rojo Studio plugin.
2. In this folder run `rojo serve`.
3. In Studio open a new Baseplate, then click **Connect** in the Rojo plugin.
4. Delete the default `Baseplate` and `SpawnLocation`, then press **Play**.

To rebuild the place file yourself: `rojo build -o Vesperdeep.rbxl`.

> **Saving:** progress uses DataStores. To test saving in Studio, publish the place and turn on
> *Game Settings → Security → Enable Studio Access to API Services*. Without it the game still runs; it just won't remember you.

### Add the music and sound effects (one-time)

Roblox only plays audio that has been uploaded to your account. The game ships with basic built-in sounds, but the real soundtrack and effects are in this repo:

1. In Studio open **Window → Asset Manager → Bulk Import** (or use the Creator Hub) and upload the files in `assets/music/` and `assets/sfx/`.
2. Right-click each uploaded sound → **Copy Asset ID**.
3. Paste the ids into `src/shared/Config.luau`:
   - music goes in `Config.MUSIC`, e.g. `burrows = "rbxassetid://1234567890"`
   - effects go in the first slot of each `Config.SFX` entry, e.g. `slash = { "rbxassetid://…", "rbxasset://sounds/swordslash.wav" }`

| Music | Plays in |
|---|---|
| `burrows` | Ashen Burrows: lonely piano over a low drone |
| `ruins` | Mothlight Ruins: a faded music-box waltz with cello |
| `forest` | Verdant Hush: harp arpeggios and breathy voices |
| `mines` | Glimmerdeep Mines: glassy crystal arpeggios |
| `archive` | Drowned Archive: muffled piano, cello and drips |
| `hollow` | The Hollowroot: a drone and distant notes in the dark |
| `temple` | Sanctum of Still Wings: distant choir and bells |
| `boss` / `boss_final` | guardian fights / the Seraph |
| `ending` | the finale |

Everything is composed and synthesised from scratch by `tools/compose.py` (needs `numpy scipy soundfile`). Tweak it and re-run to make your own versions.

---

## Controls

Vesperdeep is a 2D side-scroller: the camera looks at the caves from the side and everything moves on one plane, with the cave's back wall and distant scenery drifting behind in parallax.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | A / D (or arrows) | Left stick |
| Aim up / down; hold while standing still to look around | W / S | Stick up / down |
| Jump (hold for height) | Space | A |
| Nail strike (strike again quickly for a 3-hit combo) | J or left click | X |
| Upward strike / downward strike in the air (pogo) | W + strike / S + strike | Up / down + X |
| Cleaving Arc *(found later)* | Hold the strike button, release | Hold X |
| Dodge roll (brief invulnerability) | Q or C | L2 |
| Dash *(found later)* | Shift | R1 / B |
| Lumen Bolt *(found later)* | R | R2 |
| Swing from a glowing ring (hold; release or jump to let go) | G | L3 / D-pad up |
| Charge dash (hold to gather, release to launch; jump or hit a wall to stop) | V | D-pad down |
| Soul scream (burst above you) / soul dive (plunge and explode) | W + R / S + R in the air | Up / down + R2 |
| Travel between benches you've rested at | Rest at a bench → Travel | |
| Focus Soul to heal | Hold F or right click | L1 |
| Talk / rest at bench | E | Y |
| Charms (at a bench) | Tab | |
| Journal: map, abilities, memories | M | View / Back |
| Show / hide controls | H | |

Phones and tablets get a floating joystick and on-screen buttons.

---|---|---|
| Move (relative to the camera) | W A S D | Left stick |
| Look around | Mouse | Right stick |
| Lock on to a foe / release | T or middle click | R3 |
| Jump (hold for height) | Space | A |
| Nail strike (auto-aims at nearby foes) | Left click or J | X |
| Upward / downward strike | Look up / look down while striking (down = pogo in mid-air) | |
| Cleaving Arc *(found later)* | Hold the strike button, release | Hold X |
| Dodge roll (brief invulnerability) | Q or C | L2 |
| Dash *(found later)* | Shift | R1 / B |
| Swing from a glowing ring (hold; release or jump to let go) | G | L3 / D-pad up |
| Side view / free camera | V | D-pad down |
| Lumen Bolt *(found later, aims at your lock-on)* | R | R2 |
| Focus Soul to heal | Hold F or right click | L1 |
| Talk / rest at bench | E | Y |
| Charms (at a bench) | Tab | |
| Journal: map, abilities, memories | M | View / Back |
| Show / hide controls | H | |

Phones and tablets get a floating joystick, drag-to-look and on-screen buttons.

---|---|---|
| Move | A / D (or arrows) | Left stick / D-pad |
| Aim up / down, look around (hold while still) | W / S | Stick up / down |
| Jump (hold for height) | Space | A |
| Nail strike | J or left click | X |
| Cleaving Arc *(found later)* | Hold the strike button, release | Hold X |
| Pogo off enemies | Hold S + strike in mid-air | Down + X |
| Sidestep (brief invulnerability) | Q | LT |
| Dash *(found later)* | Shift | RB / B |
| Lumen Bolt *(found later)* | R | RT |
| Focus Soul to heal | Hold F or right click | LB |
| Talk / rest at bench | E | Y |
| Charms (at a bench) | Tab | |
| Journal: map, abilities, memories | M | View / Back |
| Show / hide controls | H | |

Phones and tablets get on-screen buttons.

---

## The world

Eight regions, linked in loops so later abilities open shortcuts back through earlier ground.

| Region | Mood | Guardian | Reward |
|---|---|---|---|
| **Ashen Burrows** | Ember-lit caves where the kingdom began | **Gravelmaw, the Tunneling Mother** | **Drift Cloak** (dash) |
| **Glimmerdeep Mines** | Violet crystal caverns that hum with spilled memories | **Quartzelle, the Facet Matron** | **Cleaving Arc** (charged slash that breaks crystal seals) |
| **Mothlight Ruins** | The fallen capital, pale lamps in silent windows | **Sir Vantis, the Hollow Sentinel** | **Thorn Claws** (a memento; wall sliding and wall jumping are available from the start) |
| **Drowned Archive** | A flooded library of every forgotten word | **Murrow, Archivist of Drowned Words** | **Lumen Bolt** (soul spell that wakes sigils) |
| **Verdant Hush** | A glowing fungal garden that listens | **The Thornwidow, Weaver of Wings** | **Veil Wings** (double jump) |
| **The Hollowroot** *(secret)* | A monochrome abyss of abandoned lanterns | **The Hollow Echo, All Who Turned Back** | The true ending |
| **Sanctum of Still Wings** | Gilded temple halls around the Great Lamp | **Asterion, the Moth Seraph** | The ending |
| **The Glowmire** | A vast open cavern of giant blue mushrooms and a still, glowing lake, between the Ruins and the Archive | none: it's for exploring | A Heart Husk, a memory, Geo caches |

**How abilities open the map:**
- **Dash** crosses wide thorn pits and reaches the high ledge down to the Mines.
- **Claws** climb the Ruins shaft and the well between the Mines and the Archive.
- **Cleaving Arc** shatters crystal seals hiding Heart Husks and charms.
- **Lumen Bolt** wakes the sigil that seals the way into the Hollowroot.
- **Wings** reach the high Sanctum door and many secrets.
- **The Silkline** (from the start): hold G near a glowing ring to swing from it, pump the swing with the movement keys, and let go (or jump) at the top of the arc to fly. Rings hang over the Glowmire's gullies and lake, and one island there can only be reached this way.

**Guardians:** every boss has its own arena, attack patterns and personality, with 2 or 3 **phases** that each open with a stagger and roar. Every attack is telegraphed: the boss glows hot and trembles before striking, and anything about to land (falling stone, crystal spires, ink, feathers) is **marked on the floor** first. Each fight opens with a **cinematic introduction** (gates slam, letterbox, camera pan, title card), and a bench waits just outside every arena.

**Characters:** Old Wick, keeper of the first bench · Brass Tock, the nailsmith · Lirra, wandering merchant · Pell, the lost miner · Quill, the drowned scribe · Ilo, the moss pilgrim · Oriel, the faded bearer · Sael, the last acolyte.

**Enemies:** Husk Mites, Crystal Mites, Gloom Gnats, Ink Wisps (keep their distance and spit ink), Spore Bulbs, Shellguards (wind up and charge), Hollow Hoppers (leap at you). Every enemy attack has a visible wind-up.

**Systems:**
- **Masks and Soul:** striking enemies fills your Soul orb. Spend it to heal (hold Focus) or to cast the Lumen Bolt.
- **Benches:** checkpoints. Resting restores masks, sets your respawn and opens the charm menu.
- **Death:** you drop your Geo as an **Echo**; strike it to take the Geo back.
- **Charms (11):** Swift Mantle, Long Reach, Soul Siphon, Ember Edge, Stone Heart, Quiet Focus, Deep Pockets, Glass Spur, Mirror Shell, Wayfarer's Compass and Kindled Spirit. Each costs notches; guardians and Lirra grant more.
- **Upgrades:** Heart Husks (+1 mask), charm notches, and nail reforging at Brass Tock.
- **Memories (13):** drifting motes of light that replay a moment of the kingdom's past. Together they tell the real story. Reread them in the Journal.
- **Shortcuts:** levers and Lumen sigils permanently open sealed gates.
- **Secrets:** cracked walls (any strike), crystal seals (Cleaving Arc) and cracked floors hide charms, hearts and memories.
- **Map:** the Journal draws every region you've visited, with benches, passages and guardians. The Wayfarer's Compass shows where you are.

---

## Look and performance

- **Designed caves, not one rough surface.** `World/CaveArt.luau` dresses every region from its map: rock buttresses and ribs shape the terrain; a trim and a line of boulders mark where every floor meets the wall; platform edges get rocky lips and hanging moss; walls carry layered ledges, cracks, fossils, glowing fungus, crystal veins and carved panels; ceilings drip stalactites, roots, vines, chains, lanterns and banners.
- **Every region has its own colours and props.** Dusky violet burrows with amber lanterns and coral fungus; a golden ancient city of columns, statues and blue banners; a green overgrown grotto with giant glowing mushrooms, ferns and ivy; an ivory-and-gold sanctum with braziers; a violet crystal mine with mine carts and timber frames; a teal drowned archive of bookshelves and reading desks; a silver abyss of abandoned lanterns; and the Glowmire's blue mushroom forest. Each region owns its terrain materials, so floors, walls and distant rock all differ.
- **Readable lighting.** Pools of coloured light every few metres along every path, lit ledges high on tall walls, lanterns hanging in the dark above, brighter per-region ambient light, a coloured haze instead of black fog, gentle bloom and a light vignette. Motes, spores and dust drift in the air.
- **Set pieces.** Stone arches, timber frames and root arches span the paths; floating platforms become rope bridges, gilded slabs or giant mushroom caps; every doorway has a signpost naming where it leads; windows in the cave walls look out over distant scenery (a lamplit mining village, the golden city's towers, giant trees and waterfalls, crystal spires, drowned stacks, a sea of drifting lanterns, a forest of glowing mushrooms).
- **Animation.** Every character is a hand-authored bone rig (`src/shared/Rigs/`, written by `tools/rigs.py`); no Roblox animation IDs are needed. The Wanderer has idle (breathing, blinking, an occasional look around), run with feet matched to ground speed, run start / stop / turn transitions, jump take-off, rise, apex, fall and landing (deeper the harder you land), wall slide, wall kick, push against walls, dash, dodge, swing, heal, hurt and defeat, and a three-hit combo (slash, rising backhand, heavy finisher) plus up, down and charged strikes. `client/Characters.luau` picks clips with priorities so nothing incompatible overlaps, cancels transitions the moment they stop fitting, and turns the head toward nearby people, items and creatures. Enemies notice you (a hop and a "!"), patrol, turn, wind up, attack, recover, flinch, stagger from heavy blows and play their defeat before shattering; NPCs breathe, blink, glance around, react when you approach and gesture while talking; guardians roar on entrance, reel on phase changes and collapse in light.
- **Combat effects:** each attack has its own sweeping blade arc (shape and colour) laid over its real hitbox, a small contact flash, sparks, a brief hit-stop, light screen shake, recoil and its own sound; the finisher bursts on the ground. Boss slams crack the ground and quakes shake debris loose; every enemy and boss attack is announced by a glow, a flare and a warning ring, and landing spots get glowing columns.
- **A living world:** vines and roots sway, crystals, fungus and mushroom gills pulse, candles and lanterns flicker, water drips in the damp regions and pebbles fall from the ceiling now and then, all animated only near the camera. Effects share a budget so the screen (and the device) never floods.
- **Keeping it playable:** big props stand in a band along each wall so the middle of the path stays clear; anything that looks solid near a wall is collidable, everything else is non-colliding and ignored by gameplay raycasts; nothing is placed on hazards or next to doors, benches, NPCs, items, switches or gates; boss arenas get only non-colliding dressing.
- **Performance:** about 28k parts for the whole kingdom; only the region you're in runs its lights and particles, enemies only think while a player shares their region, and far-away rigs stop animating.

---

## Project layout

```
default.project.json        Rojo project (also sets lighting, gravity, character defaults)
Vesperdeep.rbxl             Ready-to-open place file built from src/
src/shared/                 Code and data used by both server and client
  Config.luau               Every tuning value: jump height, dash, damage, music and SFX ids...
  Zones.luau                The seven maps as ASCII art (generated by tools/zones.py)
  Themes.luau               Palettes, fog and lighting per region
  Dialogue.luau, Memories.luau, Charms.luau, Abilities.luau, Shop.luau
  Rig.luau                  Runtime for the bone rigs: crossfades, events, blinking, head tracking
  Rigs/*.json               Every character's rig and animation clips (generated by tools/rigs.py)
  Hitbox.luau               Nail reach as oriented boxes, shared by client and server
src/server/
  World/Builder.luau        Carves ASCII maps into 3D terrain caverns; doors, gates, switches, items
  World/CaveArt.luau        Set dressing for every region (rocks, trims, props, lights, arches, vistas...)
  World/Props.luau          Interactive pieces: gates, benches, doors, pickups, swing rings, NPC anchors
  Bosses/init.luau          Boss runtime: intros, phases, telegraphs, hazards, rewards
  Bosses/Defs/*.luau        One file per guardian
  Enemies.luau, Combat.luau, PlayerService.luau, Projectiles.luau
src/client/                 Movement, orbit camera, combat feel, HUD, menus, journal, cinematics, audio
  Characters.luau           Animates every player's Wanderer rig
  Creatures.luau            Animates enemies, guardians and Echoes from the server's hitboxes
  NPCs.luau                 The residents' idles, glances, reactions and talking
  Fx.luau                   Slash arcs, impacts, ground bursts, cracks, debris, shatters, wisps, afterimages
  Ambient.luau              Swaying vines, pulsing crystals, flickering lights, falling pebbles
assets/music/, assets/sfx/  The original soundtrack and sound effects (.ogg)
tools/zones.py              Level layout script (writes src/shared/Zones.luau)
tools/compose.py            The procedural composer for all music and sound effects
tools/rigs.py, rigs_extra.py  Character designs and keyframed animation clips (write Rigs/*.json)
tools/preview.py            Renders rig animations to GIFs (`python tools/preview.py showcase`)
tools/harness/              Runs the real world builder headlessly and renders screenshots (see below)
```

### Editing levels

Edit `tools/zones.py` and run `python tools/zones.py` (or edit `src/shared/Zones.luau` directly). Each character is a 4-stud column of the cavern (the layout is extruded sideways into a winding 3D corridor):

```
#  rough stone (climbable)      %  smooth stone (not climbable)
^  thorns                       ~  black ink (hazard)
X  cracked wall (any strike)    Y  crystal seal (Cleaving Arc only)
=  sealed gate, opened by a lever (!) or a Lumen sigil (?) in the same region
B  bench     S  first spawn     G  boss gate
1-9 doorway to the matching digit in another region
c mite  m crystal mite  f gnat  w ink wisp  s spore bulb  g shellguard  h hopper
```

Other letters, such as NPCs, charms, memories, bosses and Geo caches, are defined per region in `tools/zones.py`.

### Previewing the world without Studio

`tools/harness/` runs the actual `Builder`/`CaveArt` code under the standalone Luau interpreter with a small mock of the Roblox API, then renders the result with three.js in headless Chromium:

```
python tools/harness/run.py      # build every region headlessly; prints part/light counts, fails on script errors
python tools/harness/render.py   # screenshots of every region into previews/world/
python tools/harness/check.py    # verifies no terrain or collidable prop blocks any walkable path
```

The renders are approximations (no Roblox terrain textures, simplified lighting), but they show exactly what the builder places, and `run.py` catches runtime errors in the level code before you open Studio. Needs `luau`, Python with `numpy scipy scikit-image`, and Node with `playwright` (`npm install` in `tools/harness/web`).

