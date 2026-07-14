#!/usr/bin/env python3
"""Generate E2M2.tscn RailNetwork scene for Typing of the DOOMed.

E2M2 (Containment Area) - the crate maze. Like E1M9, this route ENDS AT A
STRONG MILESTONE instead of the exit: vanilla progression to every key runs
over CRATE-TOP HOPS whose floors only exist after a W1 stair build (line
638) - unmodelable, and exactly the fragile geometry the guide warns about
(the exit additionally needs red door -> nook switch -> pit raise). A
strict-floor reachability flood (no crate tops) fixes the walkable zone;
this route sweeps all of it:

  spawn hall -> S1 switch 1446 lowers the shotgun platform (F196) ->
  shotguns -> east wing (medkit, ROCKET LAUNCHER, BACKPACK) -> the crate
  corridor north (six stimpack fights) -> west spur medkit -> the red
  corridor -> final node at its east end, facing the locked blue doors
  and the red-key alcove beyond ("to be continued").

Skipped: all keys (crate-top climbs), soulsphere pedestal (upper level),
chainsaw/plasma/chaingun (upper west pocket), yellow-door bonus rooms,
secret sectors.
"""
import railgen

MAP = "E2M2"
UID = "uid://teblem2ltj959"
SPAWN_X = 19.0
SPAWN_Z = -143.0

PATH_BLOCK = set()

# Shotgun platform 196 is lowered by S1 switch 1446 (cond F196 at the
# switch); wadgeo can't model switch-floors, so seed it open.
FORCE_OPEN = {196}

RAW = [
    # ===== Spawn hall =====
    ( 19.0, -143.0, None, "player start"),
    ( 21.0, -128.0, None, "clear of the crate corner at (19.5,-127.5) - the"
                          " straight leg otherwise grazes it and snags"),
    ( 21.0, -114.0, "F196", "S1 SWITCH 1446: lowers the shotgun platform"),
    ( 15.0, -131.0, None, "SHOTGUN (on the lowered platform)"),
    ( 13.0, -137.0, None, "shotgun (easy skill)"),

    # ===== East wing =====
    ( 43.0, -127.0, None, "medkit (east hall imps)"),
    ( 83.5, -121.0, None, "ROCKET LAUNCHER (east wing)"),
    ( 67.0, -139.0, None, "BACKPACK (southeast nook)"),

    # ===== North through the crate corridors =====
    ( 57.5, -115.0, None, "stimpack (crate corner)"),
    ( 66.5, -107.0, None, "stimpack"),
    ( 59.0,  -97.0, None, "stimpack (demon alley)"),
    ( 67.0,  -93.0, None, "stimpack"),
    ( 60.0,  -87.0, None, "stimpack"),
    ( 69.0,  -83.0, None, "health bonuses"),
    ( 71.0,  -77.0, None, "stimpack (imp pack)"),

    # ===== West spur, then the red corridor =====
    ( 44.0,  -77.0, None, "stimpack (maze center)"),
    ( 30.0,  -81.5, None, "medkit (southwest nook)"),
    ( 44.0,  -77.0, None, "back east"),
    ( 46.6,  -60.9, None, "red corridor west mouth"),
    ( 60.0,  -61.5, None, "red corridor (spectres)"),
    ( 72.1,  -60.9, None,
     "FINAL NODE - the locked blue doors; the red key waits beyond"),
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
