#!/usr/bin/env python3
"""Generate E3M6.tscn RailNetwork scene for Typing of the DOOMed.

E3M6 (Mt. Erebus) - islands in a lava sea. Full exit route; the blue
skull is REQUIRED (exit-building door 28 is blue-keyed) and lives in the
walkway building on med/hard (the easy-skill copy sits on the open
pedestal the route passes first, so every skill is covered):

  spawn island -> easy pedestal -> south pit -> TELEPORT (pad 93, tag 13)
  onto the building walkway -> crossing walkover 673 opens doors 6/8 ->
  BLUE SKULL inside -> west arm -> porch door 6 -> S1 614 (cond F12)
  lowers tower 12 to walkway level -> across the tower, drop to the lava
  plain -> west shore -> weapons cache (RL/SHOTGUN/CHAINGUN) -> south
  shore -> blue door 28 (auto-gated) -> final node at the W1 exit.

bake_tower rewrites 12 to its lowered floor for routing/heights. Lava
wading is authentic Erebus; crossings are short.
"""
import railgen

MAP = "E3M6"
UID = "uid://gmcnjceozczx2"
SPAWN_X = 53.5
SPAWN_Z = 56.0

PATH_BLOCK = set()


def bake_tower(geo):
    f, c, sp, tag = geo.sectors[12]
    geo.sectors[12] = (72, c, sp, tag)


GEO_PREP = bake_tower

RAW = [
    ( 53.5,  56.0, None, "player start"),
    ( 50.0,  40.0, None, "off the spawn island"),
    ( 32.5, -14.5, None, "key pedestal (the blue skull sits here on easy;"
                         " on med/hard it waits in the building)"),
    ( 16.0, -70.0, None, "south lava crossing"),
    ( 16.0, -73.0, None, "down into the teleporter pit"),
    ( 16.0, -75.2, None, "step to the pad", {"teleport": 13}),

    # ===== On the building walkway (landed on the tag-13 dest) =====
    ( -4.0, -36.0, None, "teleport landing (walkway 11)"),
    ( -6.2, -33.0, None, "crossing the walkover opens the building doors"),
    ( -5.0, -13.5, None, "north arm, into door 8"),
    ( -5.0, -10.0, None, "inside the key room"),
    ( -6.5,  -5.0, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),
    ( -5.0, -10.0, None, "back out"),
    ( -5.0, -13.5, None, "out door 8"),
    ( -6.2, -33.0, None, "west arm"),
    (-25.2, -24.0, None, "porch door 6 (opened by the walkover)"),
    (-28.0, -24.0, None, "the porch"),
    (-32.2, -25.0, "F12", "S1 SWITCH 614: lowers tower 12 - type it"),
    (-25.2, -24.0, None, "back through door 6"),
    ( -4.0, -36.0, None, "walkway east again"),
    ( -0.8, -36.0, None, "across the lowered tower"),
    (  1.5, -36.0, None, "drop to the lava plain"),

    # ===== West shore, weapons, exit =====
    (  2.0, -20.0, None, "north across the plain (cacodemons)"),
    (-20.0,   5.0, None, "west shore"),
    (-30.0,  30.0, None, "ROCKET LAUNCHER (weapons cache)"),
    (-30.0,  34.0, None, "SHOTGUN"),
    (-32.0,  32.0, None, "CHAINGUN"),
    (-36.0,  -8.0, None, "south along the shore (blue door 28 gated next)"),
    (-37.0, -10.5, None, "FINAL NODE - type the exit (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    bake_tower(geo)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     geo_prep=bake_tower)
