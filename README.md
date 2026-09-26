# Vesperdeep

*A dark, atmospheric 2D action-adventure for Roblox, set in a buried kingdom of moths and beetles.*

The Great Lamp that once lit every tunnel of Vesperdeep has gone cold, and its people have fallen into the **Hush**, a sleep that hollows the shell. You are a small, masked wanderer carrying an unlit lantern. Descend through four connected regions, earn the abilities that open new paths, gather charms, uncover secrets, and face the guardians standing between you and the lamp.

All characters, names, maps, dialogue, art and music in this project are original.

---

## Quick start

**Option A: just open it**
1. Download `Vesperdeep.rbxl` from this repo.
2. Double-click it (or open it from Roblox Studio with **File → Open from File**).
3. Press **Play** (F5).

**Option B: live-sync the code with Rojo** (recommended if you'll edit it)
1. Install [Rojo](https://rojo.space) 7.4+ (e.g. `aftman install` with the included `aftman.toml`), plus the Rojo Studio plugin.
2. In this folder run `rojo serve`.
3. In Studio open a new Baseplate, then click **Connect** in the Rojo plugin.
4. Delete the default `Baseplate` and `SpawnLocation` (the game builds its own world), then press **Play**.

To rebuild the place file yourself: `rojo build -o Vesperdeep.rbxl`.

> **Saving:** progress uses DataStores. To test saving in Studio, publish the place and turn on
> *Game Settings → Security → Enable Studio Access to API Services*. Without it the game still runs; it just won't remember you.

### Add the music (one-time)

Roblox needs audio uploaded to your account before a game can play it. The soundtrack is included as `.ogg` files:

1. In Studio open **Window → Asset Manager → Bulk Import** (or use the Creator Hub) and upload everything in `assets/music/`.
2. Right-click each uploaded sound → **Copy Asset ID**.
3. Paste the ids into `src/shared/Config.luau` under `Config.MUSIC`, for example `burrows = "rbxassetid://1234567890"`.

| File | Plays in |
|---|---|
| `burrows.ogg` | Ashen Burrows: lonely piano over a low drone |
| `ruins.ogg` | Mothlight Ruins: a faded music-box waltz with cello |
| `forest.ogg` | Verdant Hush: harp arpeggios and breathy voices |
| `temple.ogg` | Sanctum of Still Wings: distant choir and bells |
| `boss.ogg` | every boss fight: driving strings and drums |
| `ending.ogg` | the finale |

The music is composed and synthesised from scratch by `tools/compose.py`. Tweak it and re-run `python tools/compose.py` (needs `numpy scipy soundfile`) to make your own variations.

---

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | A / D (or arrows) | Left stick / D-pad |
| Aim up / down | W / S | Stick up / down |
| Jump (hold for height) | Space | A |
| Nail strike | J or left click | X |
| Pogo off enemies | Hold S + strike in mid-air | Down + X |
| Focus Soul to heal | Hold F or right click | LB |
| Dash *(after it's found)* | Shift | RB / B |
| Talk / rest at bench | E | Y |
| Charms (at a bench) | Tab | |
| Show / hide controls | H | |

Phones and tablets get on-screen buttons.

---

## The world

| Region | Mood | Guardian | Reward |
|---|---|---|---|
| **Ashen Burrows** | Ember-lit caves where the kingdom began | **Gravelmaw, the Tunneling Mother** charges, leaps and bursts from the ground | **Drift Cloak** (dash) |
| **Mothlight Ruins** | The fallen capital, pale lamps in silent windows | **Sir Vantis, the Hollow Sentinel** lunges, slams and makes triple thrusts | **Thorn Claws** (wall cling and wall jump) |
| **Verdant Hush** | A glowing fungal garden that listens | **The Thornwidow, Weaver of Wings** shoots web volleys and drops from the ceiling | **Veil Wings** (double jump) |
| **Sanctum of Still Wings** | Gilded temple halls around the Great Lamp | **Asterion, the Moth Seraph** fires radiant bursts, dives and rains feathers, and gets faster in a second phase | The ending |

Each ability opens the way onward: a thorn pit too wide to jump, a sheer shaft, a cliff of smooth unclimbable stone. Earlier areas hide things you can only reach later.

**Characters:** Old Wick, keeper of the first bench · Brass Tock, the nailsmith (spend Geo to reforge your nail) · Ilo, the moss pilgrim · Sael, the last acolyte · plus weathered tablets that tell the kingdom's story.

**Enemies:** Husk Mites (crawlers), Gloom Gnats (flyers that chase you), Spore Bulbs (lob spores), Shellguards (wind up and charge).

**Systems:**
- **Masks and Soul:** striking enemies fills your Soul orb. Hold Focus to spend 33 Soul and restore a mask.
- **Benches:** checkpoints. Resting restores your masks, sets your respawn point and opens the charm menu.
- **Death:** you drop your Geo and leave an **Echo** behind. Find it and strike it to take your Geo back.
- **Charms (6):** Swift Mantle, Long Reach, Soul Siphon, Ember Edge, Stone Heart and Quiet Focus. Each costs notches, and every guardian you defeat grants another notch.
- **Secrets:** cracked walls hide charms, Heart Husks (+1 max mask) and lore. Hit suspicious walls.

---

## Project layout

```
default.project.json        Rojo project (also sets lighting, gravity, character defaults)
Vesperdeep.rbxl             Ready-to-open place file built from src/
src/shared/                 Code and data used by both server and client
  Config.luau               Every tuning value: jump height, dash speed, damage, music ids...
  Zones.luau                The four maps as ASCII art (edit these to change levels!)
  Themes.luau               Palettes, fog and lighting per region
  Dialogue.luau             All NPC and tablet text
  Charms.luau, Abilities.luau
src/server/                 World building, enemies, bosses, combat, saving
  World/Builder.luau        Turns ASCII maps into tiles, outlines, doors, benches, items
  World/Props.luau          Scenery: parallax backdrops, mist, lights, NPCs, thorns
  Enemies.luau, Bosses.luau, Combat.luau, PlayerService.luau, Projectiles.luau
src/client/                 Movement, camera, combat feel, HUD, menus, atmosphere, music
assets/music/               The original soundtrack (.ogg)
tools/compose.py            The procedural composer that made the soundtrack
```

### Editing levels

Open `src/shared/Zones.luau`. Each character is a 4×4-stud tile:

```
#  rough stone (climbable)     %  smooth stone (not climbable)
^  thorns                      X  cracked wall (secret)
B  bench                       S  first spawn
G  boss gate                   T  boss trigger
1-9 doorway to the matching digit in another zone
c  mite   f  gnat   s  spore bulb   g  shellguard
```

Other letters, such as NPCs, charms, bosses and Geo caches, are defined in each zone's `specials` table. Keep every row the same length.
