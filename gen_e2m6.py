#!/usr/bin/env python3
"""Generate E2M6.tscn RailNetwork scene for Typing of the DOOMed.

E2M6 (Halls of the Damned). Probed progression: the dark maze's door 80
is a plain DR door from the south (hall 6) side - its yellow-key line
only guards the north face - so the YELLOW SKULL is reachable keyless and
is the one key the exit needs (yellow door 165 in front of the S1 exit
switch 513). Blue and red skulls are on the natural sweep and gate bonus
areas, so the route collects all three.

Route: spawn -> rocket launcher -> east hall (SHOTGUN, BLUE SKULL) ->
center halls -> PLASMA RIFLE -> RED SKULL -> the long south corridors ->
hall 6 -> CHAINGUN spur -> dark maze (DR door 80) -> YELLOW SKULL ->
retrace to the northeast loop -> yellow door 165 -> EXIT SWITCH.

PATH_BLOCK: the nukage pools except 55 - the southeast hall's shallow pool
is the vanilla exit approach and the only way to yellow door 165 (the hop
also passes red door 162, auto-gated; the red skull is already in hand).
"""
import railgen

MAP = "E2M6"
UID = "uid://ccpl22fvxs308"
SPAWN_X = 18.5
SPAWN_Z = -12.5

PATH_BLOCK = {57, 59, 62, 64}

RAW = [
    # ===== Spawn and the rocket launcher =====
    ( 18.5, -12.5, None, "player start"),
    ( 24.0, -24.0, None, "shotgun (easy skill)"),
    ( 23.5, -28.0, None, "ROCKET LAUNCHER"),

    # ===== East hall: shotgun + blue skull =====
    ( 56.0,   0.0, None, "SHOTGUN (east hall)"),
    ( 58.5,  -1.5, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),

    # ===== Center halls: plasma + red skull =====
    (  9.0,  49.0, None, "PLASMA RIFLE (north room)"),
    (-21.0,  29.0, "key_red_skull", "RED SKULL - rail waits for pickup"),

    # ===== South corridors to hall 6 =====
    (  2.6,   7.6, None, "center bend"),
    (  4.6,  -6.0, None, "long corridor north end"),
    (  4.6, -38.0, None, "long corridor south end"),
    (-13.4, -37.0, None, "west bend"),
    (-33.0, -36.0, None, "southwest room"),
    (-35.9, -42.9, None, "southwest bend"),
    ( -5.4, -70.5, None, "hall 6 (before the dark maze; the chaingun nook"
                         " west of here wedges the capsule - skipped)"),

    # ===== Dark maze: DR door 80, then the yellow skull =====
    ( -4.0, -67.0, None, "dark maze door 80 approach"),
    ( -4.0, -63.5, None, "through the door (demons in the dark)"),
    ( -9.9, -56.9, None, "maze bend"),
    ( -4.0, -45.0, "key_yellow_skull", "YELLOW SKULL - rail waits for pickup"),

    # ===== Retrace and the northeast loop to the exit =====
    ( -4.0, -63.5, None, "back through the maze"),
    ( -4.0, -67.0, None, "out the DR door (yellow face re-gates it)"),
    (-13.4, -36.0, None, "west bend again"),
    (  6.1, -38.4, None, "corridor mouth"),
    (  6.1,  -8.9, None, "long corridor north"),
    ( 13.1,  -1.9, None, "northeast bend"),
    ( 33.1,  -1.9, None, "east run"),
    ( 42.1, -11.4, None, "turn south"),
    ( 42.5, -26.5, None, "south run"),
    ( 22.1, -39.4, None, "southeast hall"),
    ( 20.0, -45.0, None, "exit corridor mouth"),
    ( 51.0, -29.0, None, "yellow door 165 approach"),
    ( 57.5, -29.0, None, "EXIT SWITCH 513 - type it (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
