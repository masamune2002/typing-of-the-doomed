#!/usr/bin/env python3
"""Generate E3M3.tscn RailNetwork scene for Typing of the DOOMed.

E3M3 (Pandemonium). Full exit route: spawn -> easy shotgun -> the north
maze loop to the BLUE KEYCARD -> the long west halls -> southwest stairs
(50/125-128) -> east room 107 -> the 0.5-unit step 143 crossed
perpendicular (A* clearance can't model it; explicit straight beats) ->
steps to hall 147 -> BLUE DOOR 182 -> manual door 176 -> final node at
the W1 exit square.

Skipped: the BFG/chaingun inner court (walled pocket with its own
machinery), the switch-lowered shotgun pillar 31, all nukage (blocked).
"""
import railgen

MAP = "E3M3"
UID = "uid://ka8vuocr4tmxd"
SPAWN_X = -5.0
SPAWN_Z = 39.0

PATH_BLOCK = {11, 13, 51, 68, 70, 104, 113, 145, 157, 161, 183}

RAW = [
    ( -5.0,  39.0, None, "player start"),
    ( -8.5,  39.0, None, "shotgun (easy skill)"),

    # ===== The parapet loop to the blue skull (explicit beats: the
    # descent off the parapet must be a deliberate drop, or the corner
    # cut at rail speed strands the cursor above - autoplay-proven) =====
    ( -9.9,  15.6, None, "west gallery stairs"),
    ( -6.4,  -0.9, None, "gallery south"),
    (  2.1,  -0.9, None, "up to the parapet"),
    (  3.6,   3.1, None, "parapet turn"),
    ( 16.1,   3.1, None, "parapet east run"),
    ( 16.6,   6.6, None, "parapet north end"),
    ( 14.0,   9.0, None, "DROP into the maze court"),
    (  5.6,  14.6, None, "maze court west"),
    (  0.6,  22.1, None, "down into the key room"),
    ( -2.5,  24.5, "key_blue_skull",
     "BLUE SKULL - rail waits for pickup"),

    # ===== West halls to the southwest stairs =====
    (-37.0,  -6.0, None, "west halls (imps + demons)"),
    (-37.0,  -9.0, None, "stair base"),
    (-35.5, -16.0, None, "stairs up"),
    (-23.8, -23.5, None, "east room 107 (cacodemons)"),

    # ===== The narrow step 143, crossed dead-perpendicular =====
    (-11.0, -24.0, None, "before the half-unit step"),
    ( -8.0, -24.8, None, "over the step into 139"),
    ( -5.0, -29.0, None, "step 153"),
    ( -5.0, -31.0, None, "step 156"),
    ( -4.0, -38.5, None, "hall 147 before the blue door"),

    # ===== Blue door and the exit =====
    (  6.5, -39.0, None, "blue door 182 approach (auto-gated)"),
    (  9.0, -42.0, None, "through the door"),
    ( 11.0, -47.0, None, "exit lobby (door 176 auto-gated)"),
    ( 11.0, -51.0, None, "FINAL NODE - type the exit square (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
