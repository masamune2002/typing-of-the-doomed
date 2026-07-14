#!/usr/bin/env python3
"""Generate E2M5.tscn RailNetwork scene for Typing of the DOOMed.

E2M5 (Command Center) - no keys. Like E1M9/E2M2/E2M4 this route ENDS AT A
STRONG MILESTONE: the central complex holding the exit switch has exactly
one entrance (gallery -> north descent -> nukage trench -> staircase
column), and its first +8 shelf (line 590 at the trench mouth) physically
wedges the player capsule in-game (verified by two autoplay runs; the
stall raycast sees nothing because the knee-high riser passes under it).

Route: south ring sweep (medkits, BACKPACK) -> west hall -> gallery ->
north descent, ending at the trench edge overlooking the sealed core.
Skipped: the core spiral + exit switch, far-west wing + plasma pocket,
chaingun/chainsaw pockets (raised/isolated), secrets.
"""
import railgen

MAP = "E2M5"
UID = "uid://vg8rt7skzj3fr"
SPAWN_X = -48.0
SPAWN_Z = -74.5

# All damage floors except trench 63, which is the forced crossing.
PATH_BLOCK = {72, 134, 135, 159, 162, 177, 212, 232}

RAW = [
    # ===== South ring sweep =====
    (-48.0, -74.5, None, "player start"),
    (-49.0, -59.0, None, "medkit (south hall)"),
    (-36.0, -63.0, None, "medkit"),
    (-23.5, -49.5, None, "stimpack (east bend)"),
    (-29.0, -35.0, None, "medkit"),
    (-45.0, -37.5, None, "BACKPACK (ring center)"),
    (-56.0, -38.0, None, "stimpack"),
    (-67.0, -35.0, None, "medkit (west bend)"),

    # ===== West hall and the gallery stairs =====
    (-70.5,   1.0, None, "stimpack (west hall)"),
    (-60.0,  10.0, None, "stimpack (stair hall 16)"),
    (-40.0,  14.0, None, "gallery landing (sector 5)"),
    (-47.0,  22.3, None, "gallery north edge"),

    # ===== North descent - the milestone =====
    (-31.0,  34.0, None,
     "FINAL NODE - the trench before the sealed command core. The core's"
     " spiral (trench crossing + the +8 shelf at line 590) wedges the"
     " player capsule in-game; ending here keeps the route robust."),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
