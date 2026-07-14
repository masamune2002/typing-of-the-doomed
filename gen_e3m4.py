#!/usr/bin/env python3
"""Generate E3M4.tscn RailNetwork scene for Typing of the DOOMed.

E3M4 (House of Pain). Full exit route, keys in the forced order blue ->
yellow -> red (probe_map):

  spawn -> north halls -> BLUE SKULL -> blue door 166 -> the z=62
  corridor east -> crossing walkover 491 opens the triple door 145/146/147
  (explicit beat pair; FORCE_OPEN for routing) -> south to the YELLOW
  SKULL -> yellow door 77 -> RED SKULL -> east through the red door to
  the W1 exit square.

PATH_BLOCK: the damage floors; 136 stays routable (the corridor crosses
its edge briefly - authentic).
"""
import railgen

MAP = "E3M4"
UID = "uid://ahodrkf9dbwv8"
SPAWN_X = 0.5
SPAWN_Z = -34.5

PATH_BLOCK = {27, 37, 39, 43, 74, 99, 114, 115, 117}

# Triple door 145/146/147, opened by walkover 491 (crossed explicitly).
FORCE_OPEN = {145, 146, 147}

RAW = [
    (  0.5, -34.5, None, "player start"),
    (  0.5, -10.0, None, "north hall (demons)"),
    (  9.0,  75.5, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),

    # ===== Blue door and the east corridor =====
    (  9.5,  62.0, None, "blue door 166 approach (auto-gated)"),
    ( 12.0,  62.0, None, "through the blue door"),
    ( 24.0,  62.0, None, "corridor east (door 161 auto-gated)"),
    ( 27.0,  50.0, None, "corridor bend"),
    ( 30.9,  51.2, None, "before the walkover"),
    ( 30.9,  49.0, None, "cross it - the triple door opens"),
    ( 28.6,  42.1, None, "through the triple door"),
    ( 34.3,  41.8, None, "east side"),
    ( 34.6,  39.1, None, "turn south"),
    ( 29.1,  36.1, None, "south corridor"),
    ( 29.0,  18.0, None, "long walk south (imps + demons)"),
    ( 31.0,   3.5, "key_yellow_skull", "YELLOW SKULL - rail waits for pickup"),

    # ===== Yellow door -> red skull -> exit =====
    ( 34.0,   0.5, None, "flat lane at z=0 (the 63 strip north is a +32"
                         " riser that wedges the capsule)"),
    ( 44.5,   0.5, None, "yellow door 77 approach (auto-gated)"),
    ( 49.0,   0.0, "key_red_skull", "RED SKULL - rail waits for pickup"),
    ( 65.0, -26.5, None, "FINAL NODE - the exit square (red door auto-gated;"
                         " final node)"),
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
