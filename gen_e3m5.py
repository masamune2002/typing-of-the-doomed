#!/usr/bin/env python3
"""Generate E3M5.tscn RailNetwork scene for Typing of the DOOMed.

E3M5 (Unholy Cathedral). Full exit route, entirely on foot (the map's
teleporters are shortcuts the rail doesn't need):

  spawn hall -> east aisle -> nave doors -> west nook -> the center
  court -> south transept -> south nave -> blue antechamber -> S1 1075
  (cond F186) lowers the BLUE SKULL pedestal -> key -> retrace north ->
  east hall -> blue door 89 -> the exit chapel (door 152) -> final node
  at the W1 exit square.

The yellow key/door wing (opened from the far southwest) is a side quest
the exit never needs; skipped. bake_pedestal rewrites 186 to its lowered
floor for routing/heights.
"""
import railgen

MAP = "E3M5"
UID = "uid://e231rf0wppm05"
SPAWN_X = -7.0
SPAWN_Z = 58.5

PATH_BLOCK = {0, 43, 45, 226, 235, 243}


def bake_pedestal(geo):
    # "Lower to highest adjacent" -> 24 (step island 187), not 0.
    f, c, sp, tag = geo.sectors[186]
    geo.sectors[186] = (24, c, sp, tag)


GEO_PREP = bake_pedestal

RAW = [
    ( -7.0,  58.5, None, "player start"),
    ( -3.0,  50.0, None, "east aisle"),
    ( -3.0,  36.0, None, "aisle south (demons in the dark)"),
    (  0.0,  33.0, None, "nave door (auto-gated)"),
    ( -7.0,  24.0, None, "the nave (cacodemons)"),
    (-22.0,  15.0, None, "west nook door (auto-gated)"),
    (-22.0,  12.0, None, "through the nook"),
    ( -7.0,  -9.0, None, "center court"),
    (  8.0, -32.0, None, "south transept (door auto-gated)"),
    ( -7.0, -45.0, None, "south nave"),
    ( -6.0, -57.0, None, "chapel door (auto-gated)"),
    ( -7.0, -71.0, None, "blue antechamber"),
    (  1.0, -79.0, "F186", "S1 SWITCH 1075: lowers the key pedestal -"
                           " type it here"),
    (-10.0, -79.0, None, "line up on the step island"),
    (-15.0, -79.0, None, "head-on over the +24 step (dead-center; corner"
                         " grazes wedge the capsule)"),
    (-19.0, -83.0, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),

    # ===== Retrace north and east to the exit =====
    ( -7.0, -71.0, None, "back through the antechamber"),
    ( -7.0, -45.0, None, "south nave again"),
    (  8.0, -32.0, None, "transept"),
    ( -7.0,  -9.0, None, "center court again"),
    ( 23.0,  -9.0, None, "east hall (spectres)"),
    ( 35.0,  -9.0, None, "blue door 89 (auto-gated)"),
    ( 41.0,  -9.0, None, "through the blue door"),
    ( 39.0, -17.0, None, "exit chapel (door 152 auto-gated)"),
    ( 39.0, -19.4, None, "FINAL NODE - type the exit square (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    bake_pedestal(geo)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     geo_prep=bake_pedestal)
