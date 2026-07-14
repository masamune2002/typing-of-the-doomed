#!/usr/bin/env python3
"""Generate E2M1.tscn RailNetwork scene for Typing of the DOOMed.

E2M1 (Deimos Anomaly) is the episode's teleporter maze: progression hops
between disconnected zones through four scripted teleports (the rail player
ignores walkover pads, so each is a TeleportPlayerAction chain break - see
railgen.py). Probed progression (probe_map.py):

  1. spawn zone (floor ~0): east wing fight, BLUE KEYCARD on foot,
     bonus corridor south -> pad A (tag 3) -> southern lowlands
  2. lowlands (floor -56/-64): zombie pack, RED KEYCARD (sector 5),
     pad B (tag 6) -> NW zone
  3. NW zone (floor -64): demon pack; S1 switch in teleport closet 43
     lowers platform 39 (cond F39 at the switch); red door 82 detour
     down the trench to the loot room 91 (blue armor + computer map);
     back up through blue door 87 into pad chamber 83 (tag 7) -> center
  4. center-west zone (floor 0): caco ambush, imp trio; NW pad (tag 8)
     -> exit zone
  5. exit zone: crossing line 377 (W1, tag 20) lowers floor 35 - explicit
     beat pair per the guide; cacodemon + imp guard the S1 exit switch 178.

Skipped: teleport closets 3->25 / 24->4 / 12->76 (return trips), secret
sectors, the sector-0 soulsphere... (E2M1 has none; nothing else notable).
"""
import railgen

MAP = "E2M1"
UID = "uid://cfsdxl3dcjgv8"
SPAWN_X = 0.0
SPAWN_Z = -1.5

# 1 = lava pool (Damage, tag 17, S1-raisable); 60 = raised teleport-dest
# pillar beside the NW pad; 25/4/76/53/54/45/21/84 stay routable (teleport
# dest boxes at floor level) but 13's box walls handle themselves.
PATH_BLOCK = {1, 60}

# Platform 39 is lowered by the S1 switch in closet 43 (cond F39 on the
# switch beat); wadgeo can't model switch-floors, so seed it open.
FORCE_OPEN = {39}

RAW = [
    # ===== Chain 1: spawn zone =====
    (  0.0,  -1.5, None, "player start"),
    ( 47.5,  16.0, None, "zombiemen at the key pedestal yard"),
    ( 50.0,  14.0, None, "medkit"),
    ( 46.0,  18.0, "key_blue_keycard", "BLUE KEYCARD - rail waits for pickup"),
    ( -1.0, -17.0, None, "shotgun (easy) on pad room floor",
     {"teleport": 3}),

    # ===== Chain 2: southern lowlands -> east stairs -> ledge -> yard =====
    # The lava pool (sector 1) blocks the direct west path; the real flow
    # climbs the east stairs to the shotgun ledge, sweeps it west, and drops
    # back into the lowlands through door 9 (opened by switch 379 in the
    # yard - deduped interactable is sector_6, which also sets D9's var).
    ( 53.0, -11.0, None, "teleport landing (lowlands)"),
    ( 63.5,   2.5, None, "medkit (zombie corner, east stairs)"),
    ( 63.0,  15.0, None, "SHOTGUN (imp ledge)"),
    ( 57.5,  17.5, None, "imps on the ledge"),
    ( 38.5,  15.5, None, "GREEN ARMOR (west end of the ledge)"),
    ( 36.5,   7.0, "D6", "S1 SWITCH 379 (tag 16): opens doors 6+9 - type it"),
    ( 31.5,  -3.5, None, "medkit below (drop through door 9; imps+zombies)"),
    ( 33.5,  -4.5, None, "armor bonus"),
    ( 35.0,  -4.5, "key_red_keycard", "RED KEYCARD - rail waits for pickup"),
    ( 38.5,  -2.5, None, "step onto pad B", {"teleport": 6}),

    # ===== Chain 3: NW zone (landed at tag 6 dest) =====
    ( 37.0,  35.0, None, "teleport landing (NW)"),
    ( 27.0,  34.5, None, "teleport-closet door 44 approach"),
    ( 25.2,  37.4, "F39", "S1 SWITCH 260: lowers platform 39 (type it here)"),
    ( 27.0,  34.5, None, "back out of the closet"),
    ( 19.5,  27.5, None, "medkit (demon pack on the lowered platform)"),
    ( 17.5,  23.5, None, "medkit"),
    ( 11.0,  21.5, None, "drop into the trench"),
    ( 12.0,  17.0, None, "trench bend (spectre; red door 82 gated)"),
    (  7.5,  14.5, None, "BLUE ARMOR (loot room)"),
    ( 16.5,  14.5, None, "COMPUTER MAP (shotgunguys)"),
    ( 12.0,  21.0, None, "climb back out of the trench"),
    ( 11.5,  36.0, None, "blue door 87 approach (demons)"),
    ( 15.5,  36.0, None, "pad chamber 83 behind the blue door",
     {"teleport": 7}),

    # ===== Chain 4: center-west zone (tag 7 dest) =====
    (  1.0,  19.0, None, "teleport landing (center-west)"),
    ( -3.5,  17.5, None, "stimpack (cacodemon ambush west)"),
    ( -2.5,  19.5, None, "stimpack"),
    ( -5.0,  37.5, None, "NW teleporter pad (imp trio + demon)",
     {"teleport": 8}),

    # ===== Chain 5: exit zone (tag 8 dest) =====
    ( 67.0,  21.0, None, "teleport landing (exit yard)"),
    ( 67.0,  24.4, None, "before the tag-20 trigger line"),
    ( 67.0,  26.6, None, "cross trigger 377 - floor 35 lowers"),
    ( 64.5,  31.5, None, "medkit (cacodemon)"),
    ( 67.0,  37.0, None, "imp guard"),
    ( 67.0,  38.6, None, "EXIT SWITCH 178 - type it (final node)"),
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
