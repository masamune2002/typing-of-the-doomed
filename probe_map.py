#!/usr/bin/env python3
"""Progression probe for a WAD map (the BFS the RAIL_LEVEL_GUIDE prescribes).

Prints spawn/keys/exits, then runs a reachability closure from the spawn:
which keys are collectable with no keys, which doors those unlock, and so on
until the exit is reachable. Teleporter lines contribute directed edges
(front sector -> tagged destination sector), flagged in the output so a
route knows where a TeleportPlayerAction chain break is required.

Usage: python3 probe_map.py E2M1
"""
import sys
from collections import defaultdict
from wadgeo import MapGeo, MIN_GAP, MAX_STEP

BLUE_DOORS = {26, 32, 99, 133}
YELLOW_DOORS = {27, 34, 136, 137}
RED_DOORS = {28, 33, 134, 135}
KEY_THINGS = {5: "blue", 40: "blue", 6: "yellow", 39: "yellow",
              13: "red", 38: "red"}
EXIT_LINES = {11: "S1 Exit", 51: "S1 Secret Exit", 52: "W1 Exit",
              124: "W1 Secret Exit"}
TELEPORT_LINES = {39, 97}


def build(map_name):
    geo = MapGeo("DOOM.WAD", map_name)
    # sector -> key color required (via any key-door special targeting it)
    key_door = {}
    tele_edges = []       # (front_sector, dest_sector, linedef)
    exits = []            # (linedef, type, front_sector, midpoint)
    edges = defaultdict(set)
    for li, (v1, v2, flags, special, tag, s_right, s_left) in enumerate(geo.linedefs):
        (x1, z1), (x2, z2) = geo.verts[v1], geo.verts[v2]
        mid = ((x1 + x2) / 2, (z1 + z2) / 2)
        if special in EXIT_LINES:
            fs = geo.side_sector[s_right]
            exits.append((li, special, fs, mid))
        color = ("blue" if special in BLUE_DOORS else
                 "yellow" if special in YELLOW_DOORS else
                 "red" if special in RED_DOORS else None)
        if color:
            if tag == 0 and s_left != 0xFFFF:
                targets = [geo.side_sector[s_left]]
            else:
                targets = [si for si, s in enumerate(geo.sectors) if s[3] == tag]
            for t in targets:
                key_door[t] = color
        if special in TELEPORT_LINES and s_left != 0xFFFF and tag != 0:
            fs = geo.side_sector[s_right]
            for si, s in enumerate(geo.sectors):
                if s[3] == tag:
                    tele_edges.append((fs, si, li))
        if s_left == 0xFFFF:
            continue
        fs, bs = geo.side_sector[s_right], geo.side_sector[s_left]
        f1, c1 = geo.sectors[fs][0], geo.sectors[fs][1]
        f2, c2 = geo.sectors[bs][0], geo.sectors[bs][1]
        movable = fs in geo.movable or bs in geo.movable
        for a, b, fa, ca, fb, cb in ((fs, bs, f1, c1, f2, c2),
                                     (bs, fs, f2, c2, f1, c1)):
            gap = min(ca, cb) - max(fa, fb)
            climb = fb - fa
            if (gap >= MIN_GAP and climb <= MAX_STEP) or movable:
                edges[a].add((b, li))
    return geo, edges, key_door, tele_edges, exits


def reachable(geo, edges, key_door, tele_edges, start, have_keys, use_tele=True):
    seen = {start}
    stack = [start]
    while stack:
        cur = stack.pop()
        for nxt, li in edges[cur]:
            if nxt in seen:
                continue
            need = key_door.get(nxt)
            if need and need not in have_keys:
                continue
            seen.add(nxt)
            stack.append(nxt)
        if use_tele:
            for fs, dest, li in tele_edges:
                if fs == cur and dest not in seen:
                    seen.add(dest)
                    stack.append(dest)
    return seen


def main(map_name):
    geo, edges, key_door, tele_edges, exits = build(map_name)
    start_pos = geo.player_start()
    start = geo.point_sector(start_pos)
    print("spawn pos=(%.1f,%.1f) sector=%d floor=%d"
          % (start_pos[0], start_pos[1], start, geo.sectors[start][0]))

    keys = []
    for x, y, ang, ttype, flags in geo.things:
        if ttype in KEY_THINGS:
            p = (x * 0.03125, -y * 0.03125)
            sec = geo.point_sector(p)
            keys.append((KEY_THINGS[ttype], p, sec))
            print("key %s pos=(%.1f,%.1f) sector=%d floor=%d"
                  % (KEY_THINGS[ttype], p[0], p[1], sec, geo.sectors[sec][0]))
    for li, sp, fs, mid in exits:
        print("exit line %d (%s type %d) front_sector=%d at (%.1f,%.1f)"
              % (li, EXIT_LINES[sp], sp, fs, mid[0], mid[1]))
    if key_door:
        by_color = defaultdict(list)
        for s, c in key_door.items():
            by_color[c].append(s)
        for c in by_color:
            print("%s-key door sectors: %s" % (c, sorted(by_color[c])))
    if tele_edges:
        seen_t = set()
        for fs, dest, li in tele_edges:
            if (fs, dest) not in seen_t:
                seen_t.add((fs, dest))
                print("teleport edge: sector %d -> sector %d (line %d)"
                      % (fs, dest, li))

    for use_tele in ((True, False) if tele_edges else (True,)):
        label = "with teleports" if use_tele else "NO teleports"
        have = set()
        order = []
        while True:
            seen = reachable(geo, edges, key_door, tele_edges, start, have,
                             use_tele)
            got = {c for c, p, s in keys if s in seen} - have
            exits_ok = [li for li, sp, fs, mid in exits if fs in seen]
            print("[%s] keys=%s -> reach %d sectors, new keys=%s, exits=%s"
                  % (label, sorted(have), len(seen), sorted(got),
                     exits_ok))
            if not got:
                break
            # add one key at a time to expose forced order
            for c, p, s in keys:
                if c in got:
                    have.add(c)
                    order.append(c)
                    break
        print("[%s] key order (greedy): %s" % (label, order))


if __name__ == "__main__":
    main(sys.argv[1].upper())
