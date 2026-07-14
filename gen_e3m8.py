#!/usr/bin/env python3
"""Generate E3M8.tscn RailNetwork scene for Typing of the DOOMed.

E3M8 (Dis) - the Spider Mastermind arena. No exit line: the episode (and
the game) ends when the boss dies, so the last station carries the
{"finale"} special (NearbyEnemiesCleared + EpisodeFinaleAction -> the E3
text wall).

Route: spawn chamber -> D1 door -> ROCKET LAUNCHER on the walk south ->
the four-door weapons bunker (PLASMA RIFLE + BLUE ARMOR; its doors are
D1 manual outside and W1-auto from inside, so wadgeo needs FORCE_OPEN +
a hand D8 cond) -> east across the arena to face the Mastermind.
"""
import railgen

MAP = "E3M8"
UID = "uid://rg42ucrhctpxd"
SPAWN_X = 5.5
SPAWN_Z = 46.5

PATH_BLOCK = set()

# Bunker door 8 is both W1-openable (from inside) and D1 manual (outside);
# wadgeo's walkover branch wins, so seed it open and gate by hand.
FORCE_OPEN = {8}

RAW = [
    ( 5.5,  46.5, None, "player start"),
    ( 5.0,  38.0, None, "through the D1 door (auto-gated)"),
    ( 5.0,  14.0, None, "ROCKET LAUNCHER (cacodemons on the flanks)"),
    ( 5.0, -13.0, "D8", "bunker door 8 - type it"),
    ( 8.0, -18.0, None, "PLASMA RIFLE"),
    ( 2.0, -22.0, None, "BLUE ARMOR"),
    ( 5.0, -13.5, None, "out of the bunker (its walkovers reopen the doors)"),
    (35.0,   5.0, None, "east across the arena"),
    (40.0,  16.0, None,
     "THE SPIDER MASTERMIND - the game ends when it falls",
     {"finale": 30.0}),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    geo.opened |= set(FORCE_OPEN)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     force_open=FORCE_OPEN)
