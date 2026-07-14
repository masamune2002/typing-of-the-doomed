#!/usr/bin/env python3
"""Generate E3M9.tscn RailNetwork scene for Typing of the DOOMed.

E3M9 (Warrens) - Hell Keep's evil twin: the same layout shifted +4 in x,
until the old exit square turns out to be a W1 wall-lowering REVEAL
(tag 8 drops sectors 7/29/35/38/40/55/57/70 all over the map). Full exit
route:

  F15 spawn elevator -> L66 platform crossing -> east wing (the wall stub
  at (31..32,-16) forces the x=32.7 lane, as on E3M1) -> south hall ->
  DR door 41 -> RL corridor -> L27 block -> the pit -> CROSS THE REVEAL
  SQUARE (Baron ambush) -> south wing to the second RL and the BLUE
  SKULL -> back north (door 41's south face needs the blue skull) ->
  northeast field (crossing the inert W1 teleport line 473) -> east yard
  (walkovers 439/445 lower the red pillars) -> RED SKULL -> retrace ->
  red door 59 -> final node at the W1 exit square beside the spawn tower.
"""
import railgen

MAP = "E3M9"
UID = "uid://bf1v4nc0v9wvx"
SPAWN_X = 13.0
SPAWN_Z = 49.0

# Lava (0/1/22/30 damage); 7/38 are reveal walls that stay routable.
PATH_BLOCK = {0, 1, 22, 30}

# SR platform 66 and block 27 (hand L-conds gate them).
FORCE_OPEN = {66, 27}


def bake_spawn(geo):
    f, c, sp, tag = geo.sectors[15]
    geo.sectors[15] = (-8, c, sp, tag)


GEO_PREP = bake_spawn

RAW = [
    # ===== Spawn elevator and the walk down =====
    ( 13.0,  49.0, "F15", "player start - type the pit switch, the floor"
                          " rises like an elevator"),
    ( 10.0,  18.0, None, "north walk (imps below)"),
    ( 15.0,   3.5, None, "east side"),
    (  6.0,  -2.0, None, "main hall"),

    # ===== Across platform 66 to the east wing =====
    ( 18.0,  -1.5, "L66", "SR SWITCH: lowers platform 66 - type it"),
    ( 18.0,  -2.5, None, "ON the platform"),
    ( 18.0,  -3.5, None, "off the south face"),
    ( 21.0,  -4.5, None, "east wing"),
    ( 28.0, -11.0, None, "along the moat"),
    ( 29.5, -15.0, None, "door lobby approach"),
    ( 30.4, -15.0, None, "lobby (door 68 gated next)"),
    ( 32.7, -15.0, None, "through the door"),
    ( 32.7, -19.0, None, "center lane past the wall stub"),
    ( 32.0, -26.0, None, "south arm"),
    ( 24.0, -30.0, None, "south hall"),

    # ===== West corridor, the pit, and the reveal =====
    (-20.0, -33.5, None, "door 41 approach (DR face, auto-gated)"),
    (-21.0, -44.0, None, "south corridor"),
    (-21.0, -48.0, None, "corridor bend"),
    (-24.5, -49.0, None, "armor bonuses"),
    (-25.5, -58.5, None, "ROCKET LAUNCHER (door 37 auto-gated)"),
    (-23.5, -60.0, None, "antechamber (keeps the cursor tight before the"
                         " block - the player otherwise outruns the lead)"),
    (-21.0, -61.3, "L27", "SR SWITCH: lowers block 27 - type it"),
    (-21.0, -62.9, None, "ON the lowered block"),
    (-21.0, -64.6, None, "off the south face"),
    (-21.0, -69.0, None, "CROSS THE SQUARE - the walls of the Warrens fall"),
    (-21.0, -71.5, None, "stimpacks (Baron ambush)"),

    # ===== South wing: second RL and the blue skull =====
    (-20.0, -112.0, None, "ROCKET LAUNCHER (south wing)"),
    (-20.0, -114.0, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),
    (-21.0, -71.5, None, "back north"),
    (-21.0, -64.6, "L27", "type the block down again (the SR face on this"
                          " side; it re-raised behind us)"),
    (-21.0, -62.9, None, "ON the block"),
    (-21.0, -61.3, None, "off the north face"),
    (-21.0, -37.5, None, "through doors 37 and 41 (blue face, auto-gated)"),
    (-18.0, -33.0, None, "south hall again"),

    # ===== Retrace the east wing back to the main hall (the direct
    # diagonal A* shortcut crosses the lava moat and strands the player) =====
    ( 24.0, -30.0, None, "south hall east"),
    ( 32.0, -26.0, None, "south arm again"),
    ( 32.7, -19.0, None, "center lane"),
    ( 32.7, -15.0, None, "back through door 68 (auto re-gated)"),
    ( 30.4, -15.0, None, "door lobby"),
    ( 28.0, -11.0, None, "along the moat"),
    ( 21.0,  -4.5, None, "east wing"),
    ( 18.0,  -3.5, "L66", "type platform 66 down again (south face)"),
    ( 18.0,  -2.5, None, "ON the platform"),
    ( 18.0,  -1.5, None, "off the north face"),
    (  6.0,  -2.0, None, "main hall again"),
    ( 14.5,  20.0, None, "north of the tower"),
    ( 40.0,  36.6, None, "northeast field (the teleport line is inert)"),
    ( 50.1,  36.6, None, "field east"),
    ( 51.1,  35.1, None, "down into the yard"),
    ( 64.1,  -7.9, None, "east yard (cacodemons)"),
    (100.0,  -8.0, None, "red pillar walkovers lower ahead"),
    (105.0,  -8.0, "key_red_skull", "RED SKULL - rail waits for pickup"),

    # ===== Retrace and exit =====
    ( 64.1,  -7.9, None, "back west"),
    ( 51.1,  35.1, None, "up out of the yard"),
    ( 40.0,  36.6, None, "field again"),
    ( 14.5,  20.0, None, "tower approach"),
    ( 14.5,  16.0, None, "exit nook"),
    ( 14.5,  12.5, None, "red door 59 (auto-gated)"),
    ( 14.8,  11.2, None, "FINAL NODE - type the exit square (final node)"),
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
