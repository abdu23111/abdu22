"""Lays out every zone of Vesperdeep and writes src/shared/Zones.luau.

Maps are drawn with small fill helpers so platform heights and gap widths can be
reasoned about against the movement physics (1 tile = 4 studs):
  single jump ~2 tiles high / ~3 tiles across, double jump ~4 tiles high,
  jump + dash ~6 tiles across, walls of rough stone can be climbed with Thorn Claws.

    python tools/zones.py          # regenerate src/shared/Zones.luau
    python tools/zones.py show     # also print the maps
"""

import os
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "Zones.luau")


class Map:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["."] * w for _ in range(h)]
        self.fill(1, w, 1, 1)
        self.fill(1, 1, 1, h)
        self.fill(w, w, 1, h)
        self.fill(1, w, h, h)

    def fill(self, c1, c2, r1, r2, ch="#"):
        for r in range(r1, r2 + 1):
            for c in range(c1, c2 + 1):
                self.g[r - 1][c - 1] = ch

    def put(self, c, r, ch):
        self.g[r - 1][c - 1] = ch

    def rows(self):
        return ["".join(r) for r in self.g]


def burrows():
    m = Map(140, 30)
    f, p = m.fill, m.put
    f(1, 24, 1, 12)                       # start room ceiling
    f(1, 24, 26, 30); p(8, 25, "B"); p(12, 25, "W")
    f(1, 1, 23, 25, "0")                  # back west to Palewind Hollow
    # Steps up the start room to a high ledge; the last gap needs the Drift Cloak.
    f(19, 22, 24, 24); f(13, 16, 22, 22); f(19, 22, 20, 20); f(13, 16, 18, 18)
    f(2, 7, 18, 18); f(1, 1, 15, 17, "4"); p(4, 17, "M")
    f(25, 26, 30, 30); f(25, 26, 29, 29, "^")
    f(27, 52, 26, 30)
    f(38, 42, 24, 24); p(40, 23, "$")
    p(34, 25, "c"); p(46, 25, "c"); p(44, 20, "f"); p(51, 25, "s")
    f(53, 68, 29, 30); f(53, 68, 28, 28, "^")
    f(54, 57, 24, 24); f(59, 62, 22, 22); f(64, 67, 20, 20)
    f(69, 90, 18, 30)
    # Crystal-sealed pocket beside the last step (needs the Cleaving Arc).
    f(70, 76, 19, 21, "."); f(69, 69, 19, 21, "Y"); p(74, 21, "H")
    p(80, 17, "c"); p(75, 12, "f"); p(84, 11, "f"); p(78, 13, "O")
    f(80, 89, 23, 25, "."); f(90, 90, 23, 25, "X"); p(82, 25, "C"); p(86, 25, "L")
    f(91, 100, 26, 30); p(93, 25, "B"); p(97, 25, "c")
    f(101, 140, 1, 12)
    f(101, 125, 26, 30)
    f(101, 101, 13, 25, "G"); p(116, 25, "K"); f(126, 126, 13, 25, "G")
    f(126, 129, 26, 30)
    f(130, 134, 30, 30); f(130, 134, 29, 29, "^")
    f(135, 140, 26, 30); f(140, 140, 23, 25, "1")
    return m


def ruins():
    m = Map(150, 34)
    f, p = m.fill, m.put
    f(1, 1, 27, 29, "1")
    f(1, 60, 30, 34); p(6, 29, "B"); p(12, 29, "N")
    f(1, 20, 1, 18)
    f(28, 33, 28, 29); f(36, 42, 26, 29)
    f(38, 41, 27, 29, "."); f(42, 42, 27, 29, "Y"); p(39, 29, "D")   # crystal-sealed charm
    p(39, 24, "M")
    p(48, 29, "g"); p(40, 21, "f"); p(56, 29, "c")
    f(61, 90, 34, 34); f(61, 90, 33, 33, "^")
    f(61, 64, 30, 30); f(70, 73, 30, 30); f(78, 81, 30, 30); f(84, 85, 28, 28); f(87, 90, 30, 30)
    p(72, 29, "s"); p(84, 27, "C"); p(76, 24, "f")
    f(91, 105, 30, 34); f(91, 105, 1, 26); f(92, 99, 22, 25, "."); f(95, 96, 26, 26, "X")
    p(98, 25, "H"); p(93, 25, "O")
    p(93, 29, "B"); p(99, 29, "R"); p(103, 29, "L")
    f(106, 150, 1, 16)
    f(106, 136, 30, 34)
    f(106, 106, 17, 29, "G"); p(122, 29, "K"); f(136, 136, 17, 29, "G")
    f(113, 116, 26, 26); f(127, 130, 26, 26)
    f(137, 150, 30, 34)
    f(137, 139, 17, 26); f(144, 150, 6, 29); f(137, 149, 1, 2)
    f(140, 149, 3, 5, "."); f(140, 143, 3, 29, "."); f(150, 150, 3, 5, "2")
    f(144, 149, 14, 16, "."); f(150, 150, 14, 16, "5")                  # side passage to the Archive
    f(144, 149, 27, 29, "."); f(150, 150, 27, 29, "8")                  # low passage to the Glowmire
    p(141, 29, "$")
    return m


def forest():
    m = Map(150, 34)
    f, p = m.fill, m.put
    f(1, 1, 3, 5, "2"); f(1, 12, 6, 34)
    f(16, 20, 12, 12); f(24, 28, 18, 18); f(30, 33, 24, 24); p(26, 17, "M")
    f(5, 11, 27, 29, "."); f(12, 12, 27, 29, "X"); p(7, 29, "C")
    f(13, 95, 30, 34); p(18, 29, "B"); p(24, 29, "N")
    p(34, 29, "c"); p(40, 29, "s"); p(46, 22, "f"); p(52, 29, "c"); p(57, 20, "f")
    f(62, 63, 10, 27); f(68, 69, 10, 27); f(62, 69, 9, 9); p(65, 10, "D")
    # High route to the Hollowroot: needs dash + Veil Wings, and a Lumen sigil opens the gate.
    f(76, 79, 8, 8); f(88, 95, 8, 8); p(84, 7, "?")
    p(76, 29, "g"); p(82, 29, "s"); p(88, 29, "L"); p(91, 29, "B")
    f(96, 150, 1, 12)
    f(96, 96, 5, 7, "6"); f(95, 95, 5, 7, "=")
    f(96, 126, 30, 34)
    f(96, 96, 13, 29, "G"); p(112, 29, "K"); f(126, 126, 13, 29, "G")
    f(127, 135, 30, 34); f(136, 149, 26, 34, "%"); f(150, 150, 23, 25, "3")
    p(144, 25, "$"); p(131, 29, "O")
    return m


def temple():
    m = Map(120, 40)
    f, p = m.fill, m.put
    f(1, 120, 1, 5)
    f(1, 1, 33, 35, "3")
    f(1, 20, 36, 40); f(1, 20, 1, 30); f(12, 19, 27, 29, "."); f(20, 20, 27, 29, "X"); p(14, 29, "C"); p(17, 29, "H")
    p(6, 35, "B"); p(12, 35, "N"); p(17, 35, "L"); p(3, 35, "M")
    f(21, 58, 38, 40); f(21, 58, 37, 37, "^")
    f(22, 25, 33, 33); f(28, 31, 30, 30); f(34, 37, 27, 27); f(40, 43, 24, 24); f(22, 23, 26, 26); p(22, 25, "D")
    p(30, 22, "f"); p(44, 16, "f"); p(36, 26, "c"); p(52, 15, "f")
    f(50, 120, 21, 40)
    p(53, 20, "B")
    f(59, 59, 6, 20, "G"); p(85, 11, "K"); f(111, 111, 6, 20, "G")
    f(68, 72, 16, 16); f(86, 90, 13, 13); f(98, 102, 16, 16)
    p(116, 20, "E")
    return m


def mines():
    m = Map(140, 34)
    f, p = m.fill, m.put
    f(1, 140, 30, 34)
    # West: a climbing well up to the Archive (needs Thorn Claws).
    f(1, 1, 3, 5, "7"); f(2, 4, 6, 6); f(6, 9, 17, 17)
    # Arena of the Facet Matron.
    f(11, 46, 1, 15)
    f(11, 11, 16, 29, "G"); f(46, 46, 16, 29, "G"); p(22, 29, "K")
    f(16, 19, 25, 25); f(38, 41, 25, 25)
    p(50, 29, "B")
    # Crystal field.
    f(47, 99, 1, 14)
    p(56, 29, "m")
    f(61, 65, 30, 30, "."); f(61, 65, 31, 32, "."); f(61, 65, 33, 33, "^")
    f(70, 74, 28, 29); f(76, 78, 26, 26); f(72, 74, 24, 24); f(76, 78, 22, 22); f(72, 74, 20, 20); p(73, 19, "M")
    p(80, 29, "h")
    f(83, 87, 30, 32, "."); f(83, 87, 33, 33, "^")
    p(92, 22, "f"); p(97, 29, "s"); p(66, 24, "f")
    # Entry cavern, with a cracked floor over a hidden pocket.
    f(100, 140, 1, 18)
    f(102, 110, 31, 32, "."); f(106, 107, 30, 30, "X"); f(107, 107, 32, 32); p(103, 32, "C")
    p(133, 29, "B"); p(127, 29, "P"); p(118, 29, "L"); p(112, 29, "m")
    p(120, 24, "O")
    f(140, 140, 27, 29, "4")
    return m


def archive():
    m = Map(140, 40)
    f, p = m.fill, m.put
    f(1, 140, 36, 40)
    f(1, 1, 20, 22, "5"); f(1, 20, 23, 24)
    p(10, 22, "B"); p(15, 22, "Q"); p(18, 22, "M")
    # Hidden reading room under the floor.
    f(4, 12, 37, 38, "."); f(8, 9, 36, 36, "X"); f(9, 9, 38, 38); p(5, 38, "C")
    # Ink pools and shelves.
    f(30, 35, 36, 36, "~"); f(32, 33, 32, 32)
    f(24, 27, 30, 30); f(40, 44, 29, 29); f(47, 50, 25, 25)
    p(40, 28, "w"); p(45, 35, "c"); p(26, 29, "L")
    p(54, 35, "B")
    # Arena of the Archivist.
    f(59, 101, 1, 23)
    f(59, 59, 24, 35, "G"); f(101, 101, 24, 35, "G"); p(74, 30, "K")
    f(66, 70, 34, 34); f(78, 82, 32, 32); f(90, 94, 34, 34)   # shelves above the ink tide
    # East stacks and the climb to the Mines passage.
    f(108, 113, 36, 36, "~")
    p(110, 30, "w"); p(122, 35, "g"); p(106, 20, "w")
    f(104, 107, 31, 31); f(114, 116, 31, 31)
    f(118, 119, 10, 35); f(124, 139, 8, 9); p(130, 7, "O")
    f(140, 140, 5, 7, "7")
    f(140, 140, 33, 35, "9")                                            # east door to the Glowmire
    return m


def glowmire():
    """A vast open cavern of giant mushrooms between the Ruins and the Archive.

    Rises between stepping platforms stay within 2 tiles (a single jump clears ~2.3), gaps
    within 4 (jump + dash clears ~6). Swing anchors (o) offer faster, higher lines and are the
    only way to the lake's heart island; the cathedral pillar is climbed with Thorn Claws.
    """
    m = Map(240, 56)
    f, p = m.fill, m.put
    # West entry hall.
    f(1, 28, 50, 56); f(1, 28, 1, 30); f(1, 1, 47, 49, "8")
    p(6, 49, "B"); p(12, 49, "L"); p(20, 49, "c")
    # Mushroom terraces: a stair of caps up to a long canopy bridge with a Geo cache.
    f(29, 60, 50, 56)
    p(40, 49, "c"); p(52, 49, "s"); p(45, 30, "f")
    f(32, 35, 48, 48); f(38, 41, 46, 46); f(44, 47, 44, 44); f(50, 53, 42, 42); f(56, 59, 40, 40); f(62, 66, 38, 38)
    f(67, 90, 38, 38); p(78, 37, "$"); p(86, 37, "c")
    # Thorn gully with stepping caps, and anchors for swinging over it.
    f(61, 72, 54, 56); f(61, 72, 53, 53, "^"); f(65, 67, 48, 48)
    p(63, 41, "o"); p(70, 41, "o")
    f(73, 90, 50, 56); p(80, 49, "h")
    # The Mirror Lake: a long pool of ink crossed on mushroom caps; anchors high above.
    f(91, 160, 53, 56); f(91, 160, 52, 52, "~")
    for c1, row in [(94, 48), (100, 46), (106, 48), (112, 46), (118, 48), (124, 46), (130, 48), (136, 46), (142, 48), (148, 46), (154, 48)]:
        f(c1, c1 + 3, row, row)
    p(103, 38, "f"); p(127, 40, "w"); p(145, 38, "f")
    for c, r in [(100, 36), (110, 34), (121, 34), (132, 36), (143, 34), (153, 36)]:
        p(c, r, "o")
    # The heart island, reachable only by letting go of a swing at the right moment.
    f(114, 124, 40, 40); p(119, 39, "H")
    # The Spore Cathedral: a tall chamber whose pillar can be climbed to a hidden alcove.
    f(161, 210, 50, 56)
    p(168, 49, "g"); p(185, 40, "f"); p(198, 36, "w"); p(204, 49, "s")
    f(176, 179, 46, 46); f(181, 184, 44, 44)
    f(190, 192, 14, 49)
    f(193, 206, 12, 12); p(198, 11, "M"); p(203, 11, "$")
    p(178, 30, "o"); p(186, 24, "o")
    # East hall and the way on to the Archive.
    f(211, 240, 50, 56); f(211, 240, 1, 28)
    p(218, 49, "B"); p(228, 49, "$"); f(240, 240, 47, 49, "9")
    return m


def trials():
    """The Hall of Trials: a quiet lobby with a bench, the challenge statue and a climbing
    pillar for practising wall jumps, then one great arena where any foe can be faced again."""
    m = Map(92, 26)
    f, p = m.fill, m.put
    f(1, 92, 1, 5)
    f(1, 92, 23, 26)
    # Lobby
    p(5, 22, "B"); p(12, 22, "V"); p(3, 22, "L")
    f(20, 21, 11, 22)                  # climbing pillar (rough stone: cling and wall-jump up it)
    f(27, 28, 8, 18)                   # a second wall to zig-zag between
    p(24, 7, "$")
    f(14, 17, 16, 16)                  # a ledge
    # Arena
    f(34, 34, 6, 22, "G")
    f(35, 38, 18, 18); f(81, 84, 18, 18)   # side ledges
    f(55, 64, 13, 13)                      # a high central platform
    p(45, 15, "K")
    f(89, 92, 6, 22)
    return m


def palewind():
    """Palewind Hollow: the opening walk. A long, misty blue cavern with a cobbled path,
    gentle rises, a thorn gully with a stepping stone, a high ledge worth climbing for, and a
    doorway east into the Ashen Burrows."""
    m = Map(170, 26)
    f, p = m.fill, m.put
    f(1, 170, 1, 3)
    f(1, 170, 22, 26)
    p(6, 21, "S"); p(16, 21, "B"); p(24, 21, "L")
    # A soft rise and fall in the path.
    f(38, 56, 21, 21); f(44, 50, 20, 20)
    p(62, 21, "c")
    # Steps up to a ledge between two rock pillars hanging from the ceiling; wall-jump
    # between them to reach a cache near the roof.
    f(70, 72, 20, 20); f(78, 81, 18, 18)
    f(76, 77, 4, 15); f(82, 83, 4, 14); p(80, 5, "$")
    p(96, 14, "f")
    # A thorn gully with a stepping stone.
    f(104, 115, 22, 22, "."); f(104, 115, 23, 23, "^"); f(107, 108, 22, 22); f(111, 112, 22, 22)
    p(128, 21, "c"); p(140, 13, "f")
    f(146, 158, 21, 21)
    f(170, 170, 18, 21, "0")
    return m


def hollow():
    m = Map(120, 46)
    f, p = m.fill, m.put
    f(1, 1, 4, 6, "6"); f(1, 15, 7, 46)
    p(8, 6, "N")
    # Shortcut: a climbing corridor back up to the entrance, sealed at the top until the
    # lever at the bottom is struck.
    f(5, 7, 7, 43, "."); f(5, 15, 41, 43, "."); f(5, 7, 7, 7, "=")
    # The long descent.
    f(20, 24, 14, 14); f(30, 34, 20, 20); f(18, 22, 26, 26); f(28, 32, 32, 32); f(20, 24, 38, 38)
    f(42, 46, 22, 22); f(52, 58, 23, 23)
    p(22, 13, "h"); p(31, 19, "f"); p(40, 30, "f"); p(30, 31, "h")
    f(16, 120, 44, 46)
    p(20, 43, "!"); p(44, 43, "B"); p(50, 43, "L")
    # Arena of the Hollow Echo, with a crystal-sealed alcove in its outer wall.
    f(59, 120, 1, 29)
    f(60, 66, 20, 22, "."); f(59, 59, 20, 22, "Y"); p(62, 22, "C"); p(65, 22, "H")
    f(59, 59, 30, 43, "G"); f(111, 111, 30, 43, "G"); p(95, 43, "K")
    f(70, 74, 39, 39); f(96, 100, 39, 39)
    p(116, 43, "O")
    return m


META = [
    ("burrows", "Ashen Burrows", "Where the digging began", "burrows", "burrows", burrows, {
        "W": '{ kind = "npc", id = "wick" }',
        "C": '{ kind = "charm", id = "swift_mantle" }',
        "L": '{ kind = "npc", id = "tablet_burrows", tablet = true }',
        "H": '{ kind = "heart" }',
        "M": '{ kind = "memory", id = "first_light" }',
        "O": '{ kind = "memory", id = "diggers_song" }',
        "$": '{ kind = "geo", amount = 60 }',
        "K": '{ kind = "boss", id = "gravelmaw", arena = { 102, 125 } }',
    }, (2, 3)),
    ("ruins", "Mothlight Ruins", "The capital that dimmed", "ruins", "ruins", ruins, {
        "N": '{ kind = "npc", id = "tock" }',
        "R": '{ kind = "npc", id = "lirra" }',
        "C": '{ kind = "charm", id = "long_reach" }',
        "D": '{ kind = "charm", id = "glass_spur" }',
        "H": '{ kind = "heart" }',
        "L": '{ kind = "npc", id = "tablet_ruins", tablet = true }',
        "M": '{ kind = "memory", id = "seventh_bell" }',
        "O": '{ kind = "memory", id = "lamplighters" }',
        "$": '{ kind = "geo", amount = 120 }',
        "K": '{ kind = "boss", id = "vantis", arena = { 107, 135 } }',
    }, (4, 3)),
    ("forest", "Verdant Hush", "The garden that listens", "forest", "forest", forest, {
        "N": '{ kind = "npc", id = "ilo" }',
        "C": '{ kind = "charm", id = "soul_siphon" }',
        "D": '{ kind = "charm", id = "quiet_focus" }',
        "L": '{ kind = "npc", id = "tablet_forest", tablet = true }',
        "M": '{ kind = "memory", id = "widows_loom" }',
        "O": '{ kind = "memory", id = "pilgrims_prayer" }',
        "$": '{ kind = "geo", amount = 150 }',
        "K": '{ kind = "boss", id = "widow", arena = { 97, 125 } }',
    }, (6, 2)),
    ("temple", "Sanctum of Still Wings", "Where the lamp waits", "temple", "temple", temple, {
        "N": '{ kind = "npc", id = "sael" }',
        "C": '{ kind = "charm", id = "stone_heart" }',
        "D": '{ kind = "charm", id = "ember_edge" }',
        "H": '{ kind = "heart" }',
        "L": '{ kind = "npc", id = "tablet_temple", tablet = true }',
        "M": '{ kind = "memory", id = "seraphs_choice" }',
        "E": '{ kind = "altar" }',
        "K": '{ kind = "boss", id = "asterion", arena = { 60, 110 } }',
    }, (8, 1)),
    ("mines", "Glimmerdeep Mines", "Where the crystals remember", "mines", "mines", mines, {
        "P": '{ kind = "npc", id = "pell" }',
        "C": '{ kind = "charm", id = "deep_pockets" }',
        "L": '{ kind = "npc", id = "tablet_mines", tablet = true }',
        "M": '{ kind = "memory", id = "crystal_vein" }',
        "O": '{ kind = "memory", id = "matrons_brood" }',
        "K": '{ kind = "boss", id = "quartzelle", arena = { 12, 45 } }',
    }, (0, 4)),
    ("archive", "Drowned Archive", "Every word the kingdom forgot", "archive", "archive", archive, {
        "Q": '{ kind = "npc", id = "quill" }',
        "C": '{ kind = "charm", id = "mirror_shell" }',
        "L": '{ kind = "npc", id = "tablet_archive", tablet = true }',
        "M": '{ kind = "memory", id = "ink_and_ash" }',
        "O": '{ kind = "memory", id = "last_entry" }',
        "K": '{ kind = "boss", id = "murrow", arena = { 60, 100 } }',
    }, (2, 5)),
    ("hollow", "The Hollowroot", "Where lanterns go to forget", "hollow", "hollow", hollow, {
        "N": '{ kind = "npc", id = "oriel" }',
        "C": '{ kind = "charm", id = "kindled_spirit" }',
        "H": '{ kind = "heart" }',
        "L": '{ kind = "npc", id = "tablet_hollow", tablet = true }',
        "M": '{ kind = "memory", id = "many_lanterns" }',
        "O": '{ kind = "memory", id = "lanterns_truth" }',
        "K": '{ kind = "boss", id = "echo", arena = { 60, 110 } }',
    }, (7, 5)),
    ("glowmire", "The Glowmire", "Where the light pools", "glowmire", "glowmire", glowmire, {
        "L": '{ kind = "npc", id = "tablet_glowmire", tablet = true }',
        "H": '{ kind = "heart" }',
        "M": '{ kind = "memory", id = "mire_bloom" }',
        "$": '{ kind = "geo", amount = 90 }',
    }, (3.6, 6.2), 1.9),
    ("pass", "Palewind Hollow", "Where the wind goes quiet", "hush", "burrows", palewind, {
        "L": '{ kind = "npc", id = "tablet_pass", tablet = true }',
        "$": '{ kind = "geo", amount = 50 }',
    }, (0.4, 2.4)),
    ("trials", "Hall of Trials", "Where every foe waits again", "temple", "temple", trials, {
        "V": '{ kind = "trial" }',
        "L": '{ kind = "npc", id = "tablet_trials", tablet = true }',
        "$": '{ kind = "geo", amount = 40 }',
        "K": '{ kind = "boss", id = "trials", arena = { 35, 88 } }',
    }, (9.2, 3)),
]

HEADER = '''--!strict
-- The zones of Vesperdeep, drawn as ASCII tile maps (1 character = 1 tile of 4x4 studs).
-- Generated by tools/zones.py; small edits by hand are fine (keep every row the same length).
--
-- Legend
--   #  rough stone (solid, clingable)      %  smooth stone (solid, cannot be clung to)
--   ^  thorns (hazard)                     ~  black ink (hazard)
--   X  cracked wall (any strike breaks it) Y  crystal seal (only the Cleaving Arc breaks it)
--   =  sealed gate, opened for good by hitting a lever (!) or a Lumen sigil (?) in the same zone
--   S  first spawn     B  bench (checkpoint)     G  boss gate (closes during a fight)
--   1-9 doorway: leads to the doorway with the same digit in another zone
--   o  swing anchor: a glowing ring to swing from (Silkline)
--   Enemies: c husk mite, f gloom gnat, s spore bulb, g shellguard,
--            m crystal mite, h hollow hopper, w ink wisp
--   Any other letter is looked up in the zone's `specials` table.

export type Special = { kind: string, id: string?, amount: number?, tablet: boolean?, arena: { number }? }
export type Zone = {
	id: string,
	wide: number?, -- corridor width multiplier (the Glowmire is a vast open cavern)
	name: string,
	subtitle: string,
	theme: string,
	music: string,
	mapPosition: Vector2,
	specials: { [string]: Special },
	map: { string },
}

local Zones: { Zone } = {'''


def main():
    out = [HEADER]
    shown = []
    for entry in META:
        zid, name, sub, theme, music, fn, specials, pos = entry[:8]
        wide = entry[8] if len(entry) > 8 else None
        rows = fn().rows()
        assert len({len(r) for r in rows}) == 1, zid
        used = set("".join(rows)) - set("#%^~XY=!?.SBGT0123456789cfsgmhwo")
        missing = used - set(specials)
        assert not missing, (zid, missing)
        shown.append((zid, rows))
        out.append("\t{")
        out.append(f'\t\tid = "{zid}",')
        out.append(f'\t\tname = "{name}",')
        out.append(f'\t\tsubtitle = "{sub}",')
        out.append(f'\t\ttheme = "{theme}",')
        out.append(f'\t\tmusic = "{music}",')
        out.append(f"\t\tmapPosition = Vector2.new({pos[0]}, {pos[1]}),")
        if wide:
            out.append(f"\t\twide = {wide},")
        out.append("\t\tspecials = {")
        for k, v in specials.items():
            key = f'["{k}"]' if not k.isalpha() else k
            out.append(f"\t\t\t{key} = {v},")
        out.append("\t\t},")
        out.append("\t\tmap = {")
        for r in rows:
            out.append(f'\t\t\t"{r}",')
        out.append("\t\t},")
        out.append("\t},")
    out.append("}\n\nreturn Zones\n")
    with open(OUT, "w") as fh:
        fh.write("\n".join(out))
    # Every doorway digit must appear in exactly two zones.
    doors = {}
    for zid, rows in shown:
        for d in "0123456789":
            if any(d in r for r in rows):
                doors.setdefault(d, []).append(zid)
    for d, zs in doors.items():
        assert len(zs) == 2, (d, zs)
    print("doors:", doors)
    if "show" in sys.argv:
        for zid, rows in shown:
            print(zid)
            print("\n".join(rows))


if __name__ == "__main__":
    main()
