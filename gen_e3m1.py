#!/usr/bin/env python3
"""Generate E3M1.tscn RailNetwork scene for Typing of the DOOMed.

E3M1 (Hell Keep). Full exit route. The quirks, all probed:
  - the spawn is a pit ELEVATOR (sector 30, floor -128): S1 switch 199 on
    the pit wall raises it (cond F30 on the spawn station; bake_spawn
    rewrites the floor for routing/heights)
  - the west bridge (sectors 15-19) SINKS behind the player as its W1
    trigger lines are crossed - one-way, modeled by wadgeo's opener sim
  - the hall's east half is platform 11 (floor 104), SR-lowered; its only
    two-sided faces are the switch lines 91/109, so the route crosses it
    dead-center (L11 + a beat ON the platform, guide lift pattern)
  - block 29 (floor 72) before the exit pit is the same SR pattern (L29)
  - the exit is a W1 walkover square in the pit; the rail ends beside it
    and the player types the exit interactable.
"""
import railgen

MAP = "E3M1"
UID = "uid://ttqgg6u0lcxtb"
SPAWN_X = 9.0
SPAWN_Z = 49.0

# Lava: 7/14 (damage), 8 (the -40 moat between the hall and south hall).
PATH_BLOCK = {7, 8, 14}

# SR-lowered platform 11 and block 29 (hand L-conds gate them).
FORCE_OPEN = {11, 29}


def bake_spawn(geo):
    f, c, sp, tag = geo.sectors[30]
    geo.sectors[30] = (-8, c, sp, tag)


GEO_PREP = bake_spawn

RAW = [
    # ===== Spawn elevator =====
    (  9.0,  49.0, "F30", "player start - type the pit switch, the floor"
                          " rises like an elevator"),
    (  6.0,  18.0, None, "medkit (north walk, imps below)"),
    ( 11.0,   3.5, None, "medkit"),
    (  2.0,  -2.0, None, "medkit (main hall)"),

    # NOTE: the west sinking bridge (shotgun) is skipped - its segments
    # lower to lava 40 below the far bank faster than the rail can cross,
    # wedging the player against the bank (autoplay-proven).

    # ===== Across platform 11 to the east wing =====
    ( 14.0,  -1.5, "L11", "SR SWITCH: lowers platform 11 - type it, rail"
                          " waits until the platform is down"),
    ( 14.0,  -2.5, None, "ON the platform"),
    ( 14.0,  -3.5, None, "off the south face"),
    ( 17.0,  -4.5, None, "east wing (imps)"),
    ( 24.0, -11.0, None, "along the lava moat"),
    ( 25.5, -15.0, None, "down to the door lobby"),
    ( 26.4, -15.0, None, "lobby (door 13 gated next)"),
    ( 28.7, -15.0, None, "through the door"),
    ( 28.7, -19.0, None, "center lane - wall 117 juts to x=28 at z=-16 and"
                         " snags the capsule on the west side"),
    ( 28.0, -26.0, None, "south arm"),
    ( 20.0, -30.0, None, "south hall (cacodemons)"),

    # ===== West to the rocket launcher and the exit pit =====
    (-24.0, -33.5, None, "door 195 approach (auto-gated)"),
    (-25.0, -44.0, None, "south corridor"),
    (-25.0, -48.0, None, "health bonuses"),
    (-28.5, -49.0, None, "armor bonuses"),
    (-29.5, -58.5, None, "ROCKET LAUNCHER (door 130 auto-gated)"),
    (-25.0, -61.0, "L29", "SR SWITCH: lowers block 29 - type it"),
    (-25.0, -62.9, None, "ON the lowered block"),
    (-25.0, -65.5, None, "exit pit (medkits + stimpacks)"),
    (-25.0, -67.0, None, "FINAL NODE - type the exit square (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    geo.opened |= set(FORCE_OPEN)
    bake_spawn(geo)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     force_open=FORCE_OPEN, geo_prep=bake_spawn)
