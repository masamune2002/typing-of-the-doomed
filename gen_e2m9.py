#!/usr/bin/env python3
"""Generate E2M9.tscn RailNetwork scene for Typing of the DOOMed.

E2M9 (Fortress of Mystery, the E2 secret map) is a two-room arena:
  - west fortress: 4 barons at the corners, every weapon on the floor
  - east courtyard: 10 cacodemons, soulsphere island
  - far-east key room (secret sector 5) with four alcoves:
      switch 97 (S1, tag 26) opens door 13 -> BLUE skull
      blue door 9   -> RED skull
      red door 12   -> YELLOW skull
      yellow door 15 -> W1 exit pad (typed exit interactable on sector 16)

Key order blue -> red -> yellow is forced (probe_map.py). All doors are
D1 open-stay, auto-gated by expand_route; the switch beat hand-carries
D13 per the guide (type at the switch, not the remote door).
"""
import railgen

MAP = "E2M9"
UID = "uid://hs2e6ns7xt8ar"
SPAWN_X = 2.0
SPAWN_Z = 10.0

# Sector 1 is the Damage20 lava moat in the courtyard; sector 0 is the
# soulsphere pit inside it (floor -48: drop in and never climb out).
PATH_BLOCK = {0, 1}

# Each entry: (wad_x, wad_z, cond_val_or_None, comment). Door conditions are
# inserted automatically; hand conds (switch, keys) are honored as-is.
RAW = [
    # ===== West fortress: weapon sweep past the corner barons =====
    (  2.0,  10.0, None, "player start"),
    ( 18.0,  -4.0, None, "ROCKET LAUNCHER (baron corner)"),
    (  2.0, -16.0, None, "PLASMA RIFLE (south nook)"),
    (-14.0,  -4.0, None, "CHAINGUN (baron corner)"),
    (-26.0,  12.0, None, "BACKPACK (west nook)"),
    (-14.0,  28.0, None, "COMPUTER MAP (baron corner)"),
    (  2.0,  40.0, None, "CHAINSAW (north nook)"),
    ( 18.0,  28.0, None, "SHOTGUN (baron corner)"),
    (  2.0,  12.0, None, "BLUE ARMOR (center)"),

    # ===== Door 18 east into the cacodemon courtyard =====
    ( 36.0,  12.0, None, "medkit (courtyard west)"),
    ( 52.0,  -4.0, None, "medkit (courtyard south ring; soulsphere pit is lava)"),
    ( 68.0,  12.0, None, "medkit (courtyard east)"),

    # ===== Key room (door 6 auto-gated) =====
    ( 77.2,  11.2, "D13", "SWITCH (S1 97, tag 26): opens blue-skull door 13"),
    ( 79.0,   8.5, "key_blue_skull", "BLUE SKULL - rail waits for pickup"),
    ( 77.0,  15.5, "key_red_skull", "RED SKULL (behind blue door 9)"),
    ( 83.5,  13.5, "key_yellow_skull", "YELLOW SKULL (behind red door 12)"),

    # ===== Yellow door 15 to the exit pad (typed W1 exit on sector 16) =====
    ( 81.0,   9.0, None, "EXIT ANTECHAMBER - type the exit pad (final node)"),
]


def expand_route(raw):
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", MAP)
    geo.path_block = set(PATH_BLOCK)
    return railgen.expand_route(geo, raw)


if __name__ == "__main__":
    railgen.generate(MAP, (SPAWN_X, SPAWN_Z), RAW, UID, PATH_BLOCK)
