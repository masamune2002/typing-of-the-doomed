#!/usr/bin/env python3
"""Generate E2M8.tscn RailNetwork scene for Typing of the DOOMed.

E2M8 (Tower of Babel) - the Cyberdemon boss arena. Vanilla has NO exit
line: the level ends when the Cyberdemon dies. The final station carries
the {"finale"} special (NearbyEnemiesClearedCondition + EpisodeFinaleAction
-> the E2 text wall; [AUTOPLAY] DONE in autoplay).

Layout: the player starts inside the tower around the four-faced switch
pillar. Typing the west face (S1 Build Stairs, tag 7) builds the EAST
stairs (sectors 6/9 - faces build the opposite stairs); walking out over
them auto-opens WR door 2 and crossing the outer closer line seals the
tower behind (one-way, by design). The yard is one big ring: rocket
launcher east, then counterclockwise around the tower, soulsphere
(west pen, +16 step from the yard), and the Cyberdemon southwest.

bake_stairs() rewrites wadgeo's floors for 6/9 to their post-build
heights so routing and station heights match the built staircase.
"""
import railgen

MAP = "E2M8"
UID = "uid://wp4gxi4dyeoph"
SPAWN_X = -3.0
SPAWN_Z = 23.0

PATH_BLOCK = set()


def bake_stairs(geo):
    for si, floor in ((6, 8), (9, 16)):
        f, c, sp, tag = geo.sectors[si]
        geo.sectors[si] = (floor, c, sp, tag)


RAW = [
    # ===== Inside the tower =====
    ( -3.0,  23.0, None, "player start"),
    ( -1.0,  27.0, None, "BLUE ARMOR"),
    ( -1.5,  25.0, "D6", "S1 SWITCH (pillar west face): builds the east"
                         " stairs - type it here"),
    (  0.75, 25.0, None, "up the built stairs (door 2 opens on the walkover)"),

    # ===== East room and out into the yard (one-way) =====
    ( 10.0,  25.0, None, "ROCKET LAUNCHER"),
    ( 20.0,  25.0, None, "into the yard (the tower seals behind)"),

    # ===== Counterclockwise around the tower =====
    ( 25.0,   8.0, None, "east yard (lost soul pen)"),
    ( 14.0, -10.0, None, "southeast bend"),
    (-15.0, -25.0, None, "south yard (lost soul pen)"),
    (-30.0,   0.0, None, "southwest bend"),
    (-26.0,  25.0, None, "west yard"),
    (-16.0,  25.0, None, "SOULSPHERE (west pen)"),
    (-30.0,  10.0, None, "back into the open"),
    (-38.0, -18.0, None,
     "THE CYBERDEMON - episode ends when the tower's master falls",
     {"finale": 30.0}),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    bake_stairs(geo)
    return railgen.expand_route(geo, raw)


# check_route.py applies this too (GEO_PREP hook)
GEO_PREP = bake_stairs


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     geo_prep=bake_stairs)
