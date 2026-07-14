#!/usr/bin/env python3
"""Generate E2M7.tscn RailNetwork scene for Typing of the DOOMed.

E2M7 (Spawning Vats). Like E1M9/E2M2/E2M4/E2M5 this route ENDS AT A
STRONG MILESTONE: BLUE and YELLOW keycards collected, finishing at the
yellow door. The land beyond (red-pedestal switch room, red doors, exit
switch) sits on interleaved raised tiers that wadgeo cannot route
capsule-safely (every probed approach dead-ends); vanilla reaches them
over nukage tiers - out of scope per the guide.

Route: spawn -> SHOTGUN -> east rim clockwise (the long nukage-canyon rim
at z=-62, then the eastern halls) -> BLUE KEYCARD (103,12) -> retrace ->
blue door 309 (spawn-side) -> CHAINGUN pocket -> northeast tiers ->
YELLOW KEYCARD (55,-33) -> yellow door 102 approach (final node).

PATH_BLOCK: all Damage nukage (the rim route stays dry).
"""
import railgen

MAP = "E2M7"
UID = "uid://dopbtj7e52dvp"
SPAWN_X = 44.5
SPAWN_Z = -55.5

PATH_BLOCK = {0, 10, 29, 30, 31, 47, 49, 53, 61, 62, 74, 75, 76, 80,
              155, 156, 279}

RAW = [
    # ===== Spawn hall =====
    ( 44.5, -55.5, None, "player start"),
    ( 33.5, -55.5, None, "SHOTGUN"),

    # ===== East rim clockwise to the blue key =====
    ( 46.6, -46.4, None, "north out of the spawn hall"),
    ( 57.6, -47.0, None, "east bend (imps)"),
    ( 58.6, -62.9, None, "down to the canyon rim"),
    ( 82.6, -62.0, None, "rim east run (demons)"),
    ( 84.5, -31.0, None, "rim north run"),
    ( 90.6, -13.4, None, "eastern halls"),
    (108.3, -12.4, None, "far east bend"),
    ( 98.1,  -7.4, None, "north corridor"),
    (103.0,  12.0, "key_blue_keycard", "BLUE KEYCARD - rail waits for pickup"),

    # ===== Retrace west to the blue door =====
    ( 98.1,  -7.4, None, "back south"),
    ( 84.5, -31.0, None, "rim again"),
    ( 82.6, -62.0, None, "rim west"),
    ( 58.6, -62.9, None, "rim end"),
    ( 46.6, -46.4, None, "spawn hall north"),
    ( 29.5, -54.5, None, "blue door 309 approach"),
    ( 22.0, -60.0, None, "CHAINGUN (blue pocket)"),
    ( 29.5, -54.5, None, "back out the blue door"),

    # ===== Northeast tiers to the yellow key =====
    ( 41.1, -38.4, None, "tier steps"),
    ( 47.6, -41.9, None, "tier bend"),
    ( 52.1, -41.9, None, "tier east"),
    ( 54.6, -36.9, None, "stairs up the vat platform"),
    ( 55.0, -33.0, "key_yellow_keycard",
     "YELLOW KEYCARD - rail waits for pickup"),

    # ===== The yellow door - the milestone =====
    ( 65.0, -11.5, None,
     "FINAL NODE - the yellow door; the spawning vats' heart lies beyond"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
