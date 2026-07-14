#!/usr/bin/env python3
"""Generate E2M3.tscn RailNetwork scene for Typing of the DOOMed.

E2M3 (Refinery). Probed progression: the map splits into a west half (no
key) and an east half behind blue door 106; the exit switch 520 is in the
southeast. The blue key pocket (-31,-21) is entered from the NORTH via the
plasma-rifle area (the direct approach from the chaingun side is one-way).

Route: spawn -> north stimpacks -> southwest sweep (CHAINGUN) -> north
loop to the SHOTGUN -> west wing (health bonuses, PLASMA RIFLE) -> BLUE
KEYCARD -> east through blue door 106 (auto-gated) -> east yard -> south
corridor -> EXIT SWITCH 520.

PATH_BLOCK: only the inescapable nukage (46, 122/123 around the soulsphere
island - the soulsphere is skipped); shallow nukage the vanilla route wades
stays routable but A* only crosses it when there is no dry way.
"""
import railgen

MAP = "E2M3"
UID = "uid://eykw7kiyrgpb"
SPAWN_X = 15.0
SPAWN_Z = -59.5

# Inescapable damage pits only (climb-out > 24 or ringed by more nukage).
PATH_BLOCK = {46, 122, 123}

RAW = [
    # ===== Spawn hall north =====
    ( 15.0, -59.5, None, "player start"),
    ( 22.5, -25.0, None, "stimpack (north hall)"),
    (  7.0, -25.0, None, "stimpack"),

    # ===== Southwest sweep =====
    ( -7.0, -42.0, None, "stimpack (southwest corridor)"),
    (-16.0, -48.0, None, "medkit"),
    (-23.0, -33.0, None, "stimpack"),
    (-27.0, -33.0, None, "CHAINGUN"),

    # ===== North loop to the shotgun =====
    (  1.0,   4.5, None, "stimpack"),
    (  1.0,   7.0, None, "SHOTGUN"),

    # ===== West wing and the blue key (north entry) =====
    (-31.5,  12.5, None, "health bonuses (west wing)"),
    (-34.5,  -7.0, None, "PLASMA RIFLE"),
    (-29.5, -11.5, None, "medkit"),
    (-31.0, -21.0, "key_blue_keycard", "BLUE KEYCARD - rail waits for pickup"),

    # ===== East through blue door 106 =====
    ( 14.5, -13.5, None, "medkit (center hall)"),
    ( 27.0,   7.0, None, "BACKPACK"),
    ( 45.0,  -6.5, None, "stimpack (east yard, past blue door 106)"),
    ( 32.5, -14.5, None, "stimpack (return corridor)"),

    # ===== South corridor to the exit =====
    ( 20.5, -53.5, None, "medkit (south hall)"),
    ( 40.3, -51.0, None, "EXIT SWITCH 520 - type it (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
