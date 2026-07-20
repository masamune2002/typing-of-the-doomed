#!/usr/bin/env python3
"""Round off a map's rail-path corners (Catmull-Rom style bezier handles).

Every rail segment is a straight 2-point Curve3D, so the ride turns hard at
each station. This rewrites each curve's handles so consecutive segments
share a tangent (the chord between the previous and next stations), which
turns the polyline into a smooth spline through the same stations.

Handles are clamped hard (HANDLE_MAX world units, and a third of the
segment) because the player physically walks the curve: big handles cut
corners, and a cut corner grazes door jambs and convex walls (the
capsule-snag class in llm/RAIL_LEVEL_GUIDE.md). Smoothing is XZ-only so
vertical profiles (stairs, drops) stay exactly linear.

Usage: python3 smooth_rail_paths.py E1M1 [more maps ...]
Idempotent: recomputes every 2-point curve's handles from station
positions, so re-running after station moves is safe. Curves with more
than 2 points (hand-made) are left alone.
"""
import re
import sys

from add_skirmish_stations import parse_blocks, write_blocks, header_attr, ext_id, EXT_PATHS

HANDLE_MAX = 0.8      # world units; ~0.23u max corner cut on a right angle
CATMULL_K = 1.0 / 6.0


def process(map_name):
    path = f"wads/doom/levels/{map_name}.tscn"
    preamble, blocks = parse_blocks(open(path).read())
    exts = {}
    for b in blocks:
        if b.header.startswith("[ext_resource"):
            p = header_attr(b.header, "path")
            for key, want in EXT_PATHS.items():
                if p == want:
                    exts[key] = ext_id(b.header)

    subres = {}
    stations = {}
    for b in blocks:
        if b.header.startswith("[sub_resource"):
            subres[header_attr(b.header, "id")] = b
        elif b.header.startswith("[node"):
            parent = header_attr(b.header, "parent")
            inst = re.search(r'instance=ExtResource\("([^"]*)"\)', b.header)
            if parent == "Stations" and inst and inst.group(1) == exts["station"]:
                tf = b.get("transform")
                org = (0.0, 0.0, 0.0)
                if tf:
                    nums = [float(x) for x in tf.split("(", 1)[1].rstrip(")").split(",")]
                    org = tuple(nums[9:12])
                stations[header_attr(b.header, "name")] = org

    paths = []
    for b in blocks:
        if not b.header.startswith("[node"):
            continue
        parent = header_attr(b.header, "parent")
        if (parent or "").startswith("Stations/") \
                and b.get("script") == f'ExtResource("{exts["railpath"]}")':
            to = re.search(r'NodePath\("\.\./\.\./([^"]*)"\)', b.get("to_station") or "")
            cur = re.search(r'SubResource\("([^"]*)"\)', b.get("curve") or "")
            frm = parent.split("/")[-1].split("__TO__")[0]
            if to and cur and frm in stations and to.group(1) in stations:
                paths.append({"from": frm, "to": to.group(1), "curve": cur.group(1)})

    prev_of = {}
    next_of = {}
    for p in paths:
        next_of.setdefault(p["from"], p["to"])
        prev_of.setdefault(p["to"], p["from"])

    def sub(a, b):
        return (a[0] - b[0], a[1] - b[1], a[2] - b[2])

    def handle(tangent, seg_len):
        tx, tz = tangent[0], tangent[2]
        tl = (tx * tx + tz * tz) ** 0.5
        if tl < 1e-6 or seg_len < 1e-6:
            return (0.0, 0.0, 0.0)
        mag = min(tl * CATMULL_K, seg_len / 3.0, HANDLE_MAX)
        return (round(tx / tl * mag, 4), 0.0, round(tz / tl * mag, 4))

    changed = 0
    for p in paths:
        cb = subres.get(p["curve"])
        if cb is None or cb.get("point_count") != "2":
            continue
        a = stations[p["from"]]
        b = stations[p["to"]]
        delta = sub(b, a)
        seg_len = (delta[0] ** 2 + delta[2] ** 2) ** 0.5
        pv = stations.get(prev_of.get(p["from"], ""), None)
        nx = stations.get(next_of.get(p["to"], ""), None)
        out_a = handle(sub(b, pv) if pv else delta, seg_len)
        in_b_dir = handle(sub(nx, a) if nx else delta, seg_len)
        in_b = (-in_b_dir[0], -in_b_dir[1], -in_b_dir[2])
        pts = (f"0, 0, 0, {out_a[0]}, {out_a[1]}, {out_a[2]}, 0, 0, 0, "
               f"{in_b[0]}, {in_b[1]}, {in_b[2]}, 0, 0, 0, "
               f"{delta[0]}, {delta[1]}, {delta[2]}")
        for i, ln in enumerate(cb.lines):
            if "PackedVector3Array" in ln:
                cb.lines[i] = f'"points": PackedVector3Array({pts}),'
                changed += 1

    write_blocks(path, preamble, blocks)
    print(f"{map_name}: smoothed {changed}/{len(paths)} segments")


if __name__ == "__main__":
    for m in sys.argv[1:] or ["E1M1"]:
        process(m)
