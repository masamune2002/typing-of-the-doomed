#!/usr/bin/env python3
"""Validate a RailNetwork route against WAD geometry (see wadgeo.py).

Replays the route in order with wadgeo's trigger-state simulation: every hop
must be walkable given the doors/floors opened so far, and every manual-door
crossing must be gated by a matching D<sector> condition on the departing
station.

Usage: python3 check_route.py E1M6 gen_e1m6   (module must expose RAW + SPAWN)
"""
import sys
import importlib
from wadgeo import MapGeo


def check(map_name, raw, spawn=None, path_block=(), verbose=True, force_open=()):
    geo = MapGeo("DOOM.WAD", map_name)
    geo.path_block = set(path_block)
    # Sectors wadgeo can't model as passable (switch-floors, lifts) but which
    # the route rides open - seed them so their hops don't read as blocked.
    geo.opened |= set(force_open)
    if spawn is not None and verbose:
        ps = geo.player_start()
        print("playerstart=(%.1f,%.1f) expected spawn=(%.1f,%.1f)"
              % (ps[0], ps[1], spawn[0], spawn[1]))
    blocked = []
    for i in range(len(raw) - 1):
        a, b = raw[i], raw[i + 1]
        pa, pb = (a[0], a[1]), (b[0], b[1])
        probs, gates = geo.seg_scan(pa, pb)
        for g in gates:
            sec = g[1]
            cond = "D%d" % sec
            # the gate may sit one station back when the route transits
            # through the open door slab in two sub-hops
            prev_cond = raw[i - 1][2] if i > 0 else None
            if a[2] != cond and prev_cond != cond:
                probs = probs + ["ungated door sec %d" % sec]
        if probs:
            blocked.append((i, sorted(set(probs))))
        geo.commit_hop(pa, pb, gated=[g[1] for g in gates])
    if verbose:
        for i, probs in blocked:
            a, b = raw[i], raw[i + 1]
            print("BLOCKED #%d (%.1f,%.1f) -> #%d (%.1f,%.1f) [%s]: %s"
                  % (i, a[0], a[1], i + 1, b[0], b[1], b[3] or a[3], "; ".join(probs)))
        print("%d/%d hops blocked" % (len(blocked), len(raw) - 1))
    return blocked


if __name__ == "__main__":
    map_name = sys.argv[1] if len(sys.argv) > 1 else "E1M6"
    gen_mod = sys.argv[2] if len(sys.argv) > 2 else "gen_" + map_name.lower()
    mod = importlib.import_module(gen_mod)
    raw = mod.expand_route(mod.RAW) if hasattr(mod, "expand_route") else mod.RAW
    check(map_name, raw, (mod.SPAWN_X, mod.SPAWN_Z),
          getattr(mod, "PATH_BLOCK", ()),
          force_open=getattr(mod, "FORCE_OPEN", ()))
