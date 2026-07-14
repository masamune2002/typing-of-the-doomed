#!/usr/bin/env python3
"""Generate E2M4.tscn RailNetwork scene for Typing of the DOOMed.

E2M4 (Deimos Lab). Like E1M9/E2M2 this route ENDS AT A STRONG MILESTONE:
both keycards collected and the yellow door opened. The vanilla endgame
past that point runs through a teleporter-shuttle booth pair and a deep
nukage moat whose exit ledge (168/169/170) has no modelable entrance -
exactly the fragile geometry the guide says to skip.

Probed progression (probe_map.py + wadgeo):
  spawn yard (shotgun) -> pad tag 12 -> east zone -> hall 156 -> room 148
  (medkit, BACKPACK) -> strips 195/197/196 -> room 192 -> SR switch 1098
  calls LIFT 194 (cond L194, guide ascent pattern) -> ride up to the
  pedestal ring -> BLUE KEYCARD (193) -> S1 switch 1101 (cond F189) drops
  tower 189 to walkway level -> cross to walkway 183 (the crusher lines it
  fires target strips 184/191, which the route never touches) -> static
  drop into hall 156 -> west corridor -> blue door 64 -> YELLOW KEYCARD
  (65) + BACKPACK -> yellow door 72 -> final node past the door.
"""
import railgen

MAP = "E2M4"
UID = "uid://ducv075ibksi5"
SPAWN_X = -24.0
SPAWN_Z = 81.0

# Deep nukage moat + shuttle booths + the unreachable exit pocket: the
# milestone route never needs them; keep A* out of one-way drops.
PATH_BLOCK = {145, 147, 159, 160, 168, 169, 170, 171, 172, 174, 175,
              178, 179, 180}

# 194 = pedestal lift (called by SR 1098, gated L194); 189 = tower lowered
# by S1 1101 (gated F189). wadgeo can't model either; seed them open.
FORCE_OPEN = {194, 189}

RAW = [
    # ===== Chain 1: spawn yard =====
    (-24.0,  81.0, None, "player start"),
    ( -4.0,  88.0, None, "medkit (spawn yard)"),
    (  2.0,  90.0, None, "SHOTGUN"),
    (-11.0,  83.0, None, "step onto the teleporter", {"teleport": 12}),

    # ===== Chain 2: east zone back west =====
    ( 81.0,  79.0, None, "teleport landing (northeast hall)"),
    ( 30.0,  77.0, None, "north corridor"),
    (  0.0,  64.0, None, "hall 156 (imps)"),
    (-22.0,  19.0, None, "west corridor 61 (the dark maze core is skipped -"
                         " its walkovers raise barriers, see"
                         " raise_walkovers_are_traps)"),
    (-26.0,  66.0, None, "north strips toward the lift room"),

    # ===== Lift 194 ascent to the blue key (guide ascent pattern) =====
    (-20.6,  78.3, "L194", "SR SWITCH 1098: calls lift 194 - type it, rail"
                           " waits until the platform is down"),
    (-19.0,  73.0, None, "ON the lift - it auto-raises to the pedestal ring"),
    (-16.0,  72.0, "key_blue_keycard", "BLUE KEYCARD - rail waits for pickup"),
    (-17.0,  77.3, "F189", "S1 SWITCH 1101: lowers tower 189 - type it"),
    (-12.0,  72.0, None, "cross the lowered tower"),
    (  0.0,  78.0, None, "east walkway 183"),
    (  2.0,  64.0, None, "static drop back into hall 156"),

    # ===== Blue door -> yellow key =====
    (-22.0,  18.0, None, "blue door 64 approach (west corridor again)"),
    (-17.0, -11.0, "key_yellow_keycard",
     "YELLOW KEYCARD - rail waits for pickup"),
    (-25.0, -19.0, None, "BACKPACK (south alcove)"),

    # ===== Yellow door - the milestone =====
    ( -6.2,   6.0, None, "yellow door 72 approach"),
    ( -3.5,   6.0, None,
     "FINAL NODE - past the yellow door; the nukage court lies beyond"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    geo.opened |= set(FORCE_OPEN)
    railgen.raise_walkovers_are_traps(geo)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK,
                     force_open=FORCE_OPEN,
                     geo_prep=railgen.raise_walkovers_are_traps)
