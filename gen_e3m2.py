#!/usr/bin/env python3
"""Generate E3M2.tscn RailNetwork scene for Typing of the DOOMed.

E3M2 (Slough of Despair) - the hand-shaped map. Full exit route:

  spawn (wrist) -> palm sweep (ROCKET LAUNCHER, PLASMA RIFLE) -> south
  finger stim + CHAINGUN spur -> middle plateau 14 -> BLUE KEYCARD via
  the 56 ledge (no lift needed) -> east into corridor 31; crossing line
  233 lowers the 256 overlook 45 to walkway level -> across 45 to the
  exit strip 35 -> blue door 40 -> switch nook 39: S1 459 (cond F36)
  lowers the exit chamber 36 -> back out the door and onto the lowered
  chamber -> final node beside the W1 exit pad 37.

bake_floors() rewrites 45/96 and 36/112 (their post-trigger heights) so
routing and station heights match; the walkover 233 and typed F36 do the
real work in-game. Sector 17's lava is trivial and unblocked; there are
no other damage floors on the route.
"""
import railgen

MAP = "E3M2"
UID = "uid://ak0zanzfw4h6e"
SPAWN_X = 68.0
SPAWN_Z = 9.0

PATH_BLOCK = set()


def bake_floors(geo):
    for si, floor in ((45, 96), (36, 112)):
        f, c, sp, tag = geo.sectors[si]
        geo.sectors[si] = (floor, c, sp, tag)


GEO_PREP = bake_floors

RAW = [
    # ===== Wrist and palm =====
    ( 68.0,   9.0, None, "player start"),
    ( 52.5,   3.5, None, "stimpack (wrist)"),
    ( 38.0, -20.0, None, "stimpack (palm ambush)"),
    ( 30.0, -30.5, None, "ROCKET LAUNCHER"),
    ( 18.5, -41.5, None, "PLASMA RIFLE (ambush)"),

    # NOTE: the south palm + chaingun fingers sit past a +24 rim riser
    # that wedges the capsule (two autoplay stalls at (29..33,-58)) - the
    # plateau is entered from the plasma ledge instead.

    # ===== Blue key via the middle plateau =====
    ( 12.0, -44.0, None, "up onto the middle plateau"),
    ( -8.0, -45.0, None, "middle plateau west"),
    (-12.0, -48.0, None, "ledge 56"),
    (-15.5, -57.0, "key_blue_skull", "BLUE KEYCARD - rail waits for pickup"),
    (-12.0, -48.0, None, "back up the ledge"),

    # ===== Corridor 31, the lowering overlook, the exit finger =====
    ( 12.0, -44.0, None, "plateau east again"),
    ( 12.0, -48.0, None, "into corridor 31 - the walkover lowers overlook 45"),
    ( -2.0, -58.0, None, "across the lowered overlook"),
    ( -2.0, -64.0, None, "exit strip 35"),
    (  0.7, -69.0, None, "blue door 40 approach (auto-gated)"),
    (  2.7, -69.0, "F36", "S1 SWITCH 459 in the nook: lowers the exit"
                          " chamber - type it here"),
    (  0.7, -69.0, None, "back out through the blue door"),
    ( -2.0, -69.0, None, "exit strip again"),
    ( -1.0, -75.0, None, "onto the lowered chamber floor"),
    ( -1.0, -78.0, None, "FINAL NODE - type the exit pad (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    bake_floors(geo)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     geo_prep=bake_floors)
