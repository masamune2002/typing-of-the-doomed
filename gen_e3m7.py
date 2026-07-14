#!/usr/bin/env python3
"""Generate E3M7.tscn RailNetwork scene for Typing of the DOOMed.

E3M7 (Limbo). Full exit route with two teleports and two ride-up floors:

  spawn -> west gallery loop -> BLUE SKULL -> east wing -> blue door 20
  (walk-openable + keyed; FORCE_OPEN + hand D20) -> south causeway,
  crossing the trench on its static stairs (the raise-bridge switch
  shares its name with W1 lower lines and auto-activates wrong) -> drop
  into the blood sea -> west along the shore -> RED SKULL -> pad 847 (tag 22)
  teleports back to mid-map -> south corridor -> red door 130 -> pad 945
  (tag 18) teleports to the exit courtyard -> descend into the pit onto
  elevator 135 -> S1 859 (cond F135) rides it up -> red door 138 ->
  final node at the W1 exit square.

The yellow skull's island needs its own teleport loop and gates nothing
on this route; skipped.
"""
import railgen

MAP = "E3M7"
UID = "uid://q2g5koisv8skp"
SPAWN_X = 11.5
SPAWN_Z = 43.5

PATH_BLOCK = set()

# 71 = switch-raised bridge (F71 typed at the switch, bridge baked below);
# 20 = walk-openable blue door (hand D20); 135 = ride-up elevator (F135
# typed aboard - NOT baked, its floor rises with the player).
FORCE_OPEN = {20, 135}


RAW = [
    ( 11.5,  43.5, None, "player start"),
    ( 13.0,  30.0, None, "south walk"),
    ( 13.0,  23.0, None, "crossroads"),
    ( -2.0,  10.0, None, "west hall"),
    (-16.0,  18.0, None, "gallery bend (imps)"),
    (-15.0,  34.0, None, "gallery north"),
    (  1.0,  47.0, None, "key door (auto-gated)"),
    (  5.0,  51.0, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),

    # ===== East wing, blue door, the south causeway =====
    ( 13.0,  23.0, None, "crossroads again"),
    ( 28.0,  10.0, None, "east wing"),
    ( 41.0,   0.0, None, "east hall"),
    ( 51.0,  -3.0, None, "hall bend"),
    ( 45.0, -14.0, "D20", "BLUE DOOR 20 - type it (walk-openable + keyed)"),
    ( 45.0, -19.0, None, "through the door"),
    ( 45.0, -24.0, None, "causeway north"),
    ( 45.0, -28.0, None, "DROP into the trench (the bridge switch is a"
                         " dedupe trap; the trench stairs are static)"),
    ( 40.0, -30.0, None, "trench west"),
    ( 33.0, -30.5, None, "stair base"),
    ( 33.0, -36.0, None, "up the west stairs"),
    ( 39.0, -36.0, None, "south ledge"),
    ( 45.0, -36.0, None, "causeway south"),
    ( 45.0, -43.0, None, "the trap lines lower the bridge behind"),
    ( 45.0, -46.0, None, "ledge"),
    ( 45.0, -48.5, None, "DROP into the blood sea"),
    ( 45.0, -53.0, None, "south shore"),
    ( 45.0, -61.0, None, "shore bend"),
    ( 34.0, -56.0, None, "west along the shore (spectres)"),
    ( 22.0, -56.0, None, "shore"),
    (  4.0, -59.0, None, "shore west"),
    (-14.5, -55.5, "key_red_skull", "RED SKULL - rail waits for pickup"),

    # ===== Teleport back to mid-map =====
    ( -6.0, -64.5, None, "step to the pad", {"teleport": 22}),
    (-13.0,  35.0, None, "teleport landing (mid-map)"),

    # ===== South corridor, red door, the exit teleport =====
    ( 13.0,  -2.0, None, "south corridor"),
    ( 13.0, -25.0, None, "corridor south (cacodemons)"),
    ( 10.0, -42.0, None, "corridor bend"),
    ( -3.0, -54.5, None, "RED DOOR 130 (auto-gated)"),
    ( -3.0, -51.5, None, "onto the exit pad", {"teleport": 18}),

    # ===== Exit courtyard =====
    (-49.0, -41.0, None, "teleport landing (exit courtyard)"),
    (-46.0, -44.0, None, "courtyard ledge"),
    (-42.0, -51.0, None, "descend into the pit"),
    (-38.0, -47.0, None, "pit floor"),
    (-35.0, -44.0, "F135", "ON elevator 135 - type S1 859 on the west wall,"
                           " the floor rides up"),
    (-35.0, -48.0, None, "off onto the exit ledge"),
    (-35.0, -51.5, None, "FINAL NODE - red door 138, then type the exit"
                         " square (final node)"),
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
