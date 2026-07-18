#!/usr/bin/env python3
"""Retrofit E1M1-E1M8 rail scenes with skirmish stops and interactable looks.

Two edits, applied directly to wads/doom/levels/<MAP>.tscn (the tscn files
are the live source for these maps now - the E1 generators predate the
per-station NearbyEnemiesCleared/LookAtNextStation retrofits):

1. Skirmish stations: find straight rail segments that pass within
   SEG_RANGE of clusters of >= MIN_CLUSTER enemies that no existing
   station covers (nothing within COVER_RANGE, the NEC gate radius), and
   split the segment there with a new one_shot station gated on
   NearbyEnemiesClearedCondition. The new station sits ON the existing
   straight segment, so routing stays proven; its height comes from the
   sector floor (same formula as railgen) with a lerp fallback.

2. LookAtInteractableAction: every station holding a VariableCondition on
   an interactable (D<n>/F<n>/L<n>/key_*) gets the action appended to its
   startActions, so the camera lands on the thing the player must type.

Usage: python3 add_skirmish_stations.py [--dry-run] [MAP ...]

ONE-SHOT MIGRATION - already applied (2026-07-17). The level tscn files
carry hand tweaks made in the editor since (station moves, removed sleeps,
E1M2 adjustments); re-running would duplicate Skirmish stations and stomp
those. Only aim it at fresh maps, never the whole set, without checking.
"""
import re
import sys

from wadgeo import MapGeo

Y_SCALE = 0.038
COVER_RANGE = 10.0   # NEC max_distance: the latch only ever grabs enemies this close
# Enemies in this game DO NOT move (Moving.gd is a stub): an enemy is only
# ever encountered if some station puts it within COVER_RANGE, in sight, and
# inside the rail camera's forward cone (visible_to_player = LOS + on-screen,
# and the camera is rail-driven: it faces the next station).
FOV_COVER_DEG = 55.0  # generous cone for judging existing stations
WEDGE_DEG = 70.0      # a new stop aims its camera at its cluster (marker +
                      # LookAtAction), so the cluster just has to fit on screen
MIN_CLUSTER = 2      # lone strays don't get their own station
END_MARGIN = 2.0     # keep new stations clear of the segment's endpoints
MIN_SEG_LEN = 4.5
CLUSTER_GAP = 5.0    # projections further apart than this start a new cluster
MAX_CLUSTERS_PER_SEG = 2

LAI_UID = "uid://xdgbgwfgyprn"
LANS_UID = "uid://pbvkbscoohxo"
NEC_UID = "uid://dpqsds1tybnew"
VC_UID = "uid://cjvj83eu0sl8t"

MAPS = {
    "E1M1": {"spawn": (33.0, 113.0)},
    "E1M2": {"spawn": (-1.0, 7.5)},
    "E1M3": {"spawn": (-46.0, 104.5)},
    "E1M4": {"spawn": (63.5, -35.0)},
    "E1M5": {"spawn": (-7.0, 19.5)},
    "E1M6": {"spawn": (1.0, 43.0)},
    "E1M7": {"spawn": (3.0, -16.5)},
    "E1M8": {"spawn": (-4.0, 7.0), "force_open": {10, 28}},
}

EXT_PATHS = {
    "station": "res://rail/scenes/RailStation/RailStation.tscn",
    "railpath": "res://rail/scenes/RailPath/RailPath.gd",
    "ea": "res://rail/resources/EncounterAction.gd",
    "ec": "res://rail/resources/EncounterCondition.gd",
    "adv": "res://rail/resources/Actions/AdvanceToNextStationAction.gd",
    "lans": "res://rail/resources/Actions/LookAtNextStationAction.gd",
    "nec": "res://rail/resources/Conditions/NearbyEnemiesClearedCondition.gd",
    "vc": "res://rail/resources/Conditions/VariableCondition.gd",
    "lai": "res://rail/resources/Actions/LookAtInteractableAction.gd",
    "lookat": "res://rail/resources/Actions/LookAtAction.gd",
    "marker": "res://rail/scenes/RailMarker/RailMarker.tscn",
}
LOOKAT_UID = "uid://pmiut2p0fl0o"
MARKER_UID = "uid://ckj6xvts0psim"


class Block:
    def __init__(self, header, lines):
        self.header = header
        self.lines = lines  # body lines, without the header

    def text(self):
        return "\n".join([self.header] + self.lines)

    def get(self, key):
        for ln in self.lines:
            if ln.startswith(key + " = "):
                return ln[len(key) + 3:]
        return None

    def set(self, key, value):
        for i, ln in enumerate(self.lines):
            if ln.startswith(key + " = "):
                self.lines[i] = f"{key} = {value}"
                return
        self.lines.append(f"{key} = {value}")


def parse_blocks(text):
    """Split a tscn into (preamble_lines, [Block...]) preserving order."""
    lines = text.split("\n")
    blocks = []
    cur = None
    preamble = []
    for ln in lines:
        if ln.startswith("["):
            if cur:
                blocks.append(cur)
            cur = Block(ln, [])
        elif cur:
            cur.lines.append(ln)
        else:
            preamble.append(ln)
    if cur:
        blocks.append(cur)
    # strip trailing blank lines inside each block body (re-added on write)
    for b in blocks:
        while b.lines and b.lines[-1] == "":
            b.lines.pop()
    return preamble, blocks


def write_blocks(path, preamble, blocks):
    parts = []
    if preamble:
        parts.append("\n".join(preamble))
    parts.extend(b.text() for b in blocks)
    with open(path, "w") as f:
        f.write("\n\n".join(parts) + "\n")


def header_attr(header, attr):
    m = re.search(attr + r'="([^"]*)"', header)
    return m.group(1) if m else None


def ext_id(header):
    m = re.search(r'(?:^|\s)id="([^"]*)"', header)
    return m.group(1) if m else None


def parse_enemies(map_name):
    """(x, z, type_name) for every UV-spawned enemy in llm/<MAP>.md."""
    out = []
    in_section = False
    type_name = "?"
    for ln in open(f"llm/{map_name}.md"):
        ln = ln.strip()
        if ln.startswith("## "):
            in_section = ln == "## Enemies"
            continue
        if not in_section:
            continue
        m = re.match(r"### (\w+)", ln)
        if m:
            type_name = m.group(1)
            continue
        m = re.match(r"\|\s*\d+\s*\|\s*\(([-\d.]+),\s*([-\d.]+)\)\s*\|\s*[-\d]+\s*\|\s*([a-z ]*)\|", ln)
        if m and "hard" in m.group(3):
            out.append((float(m.group(1)), float(m.group(2)), type_name))
    return out


def in_cone(p, d, e, cos_max):
    """Is e inside the view cone at p facing unit direction d?"""
    vx, vz = e[0] - p[0], e[1] - p[1]
    vl = (vx * vx + vz * vz) ** 0.5
    if vl < 1e-6:
        return True
    return (vx * d[0] + vz * d[1]) / vl >= cos_max


def sight_clear(geo, a, b):
    """DOOM-style sight test: one-sided lines block, two-sided lines block
    when the shared vertical window is shut (closed door, floor-to-ceiling
    height mismatch). Movement flags don't matter for seeing."""
    for _t, li in geo._crossings(a, b):
        _v1, _v2, _flags, _special, _tag, s_right, s_left = geo.linedefs[li]
        if s_left == 0xFFFF:
            return False
        fs, bs = geo.side_sector[s_right], geo.side_sector[s_left]
        window = min(geo.sectors[fs][1], geo.sectors[bs][1]) \
            - max(geo.sectors[fs][0], geo.sectors[bs][0])
        if window < 16:
            return False
    return True


def project(a, b, p):
    """(t, dist) of p onto segment a-b (t clamped to [0,1])."""
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    ll = dx * dx + dz * dz
    t = 0.0 if ll == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / ll))
    cx, cz = ax + dx * t, az + dz * t
    return t, ((p[0] - cx) ** 2 + (p[1] - cz) ** 2) ** 0.5


def process_map(map_name, dry_run):
    cfg = MAPS[map_name]
    spawn = cfg["spawn"]
    path = f"wads/doom/levels/{map_name}.tscn"
    preamble, blocks = parse_blocks(open(path).read())

    exts = {}
    for b in blocks:
        if b.header.startswith("[ext_resource"):
            p = header_attr(b.header, "path")
            for key, want in EXT_PATHS.items():
                if p == want:
                    exts[key] = ext_id(b.header)
    missing = [k for k in EXT_PATHS
               if k not in exts and k not in ("lai", "vc", "lookat", "marker")]
    if missing:
        raise RuntimeError(f"{map_name}: missing ext_resources {missing}")
    for key, new_id, uid, rtype in (
            ("lai", "99_lai", LAI_UID, "Script"),
            ("lookat", "99_look", LOOKAT_UID, "Script"),
            ("marker", "99_marker", MARKER_UID, "PackedScene")):
        if key not in exts:
            exts[key] = new_id
            last_ext = max(i for i, b in enumerate(blocks)
                           if b.header.startswith("[ext_resource"))
            blocks.insert(last_ext + 1, Block(
                f'[ext_resource type="{rtype}" uid="{uid}" path="{EXT_PATHS[key]}" id="{new_id}"]', []))

    subres = {}
    stations = {}
    paths = []
    for b in blocks:
        if b.header.startswith("[sub_resource"):
            subres[header_attr(b.header, "id")] = b
        elif b.header.startswith("[node"):
            name = header_attr(b.header, "name")
            parent = header_attr(b.header, "parent")
            inst = re.search(r'instance=ExtResource\("([^"]*)"\)', b.header)
            if parent == "Stations" and inst and inst.group(1) == exts["station"]:
                tf = b.get("transform")
                if tf:
                    nums = [float(x) for x in tf.split("(", 1)[1].rstrip(")").split(",")]
                    org = tuple(nums[9:12])
                else:
                    org = (0.0, 0.0, 0.0)
                stations[name] = {"block": b, "pos": org}
            elif (parent or "").startswith("Stations/") and b.get("script") == f'ExtResource("{exts["railpath"]}")':
                frm = parent.split("/")[-1].split("__TO__")[0]
                to = re.search(r'NodePath\("\.\./\.\./([^"]*)"\)', b.get("to_station") or "")
                cur = re.search(r'SubResource\("([^"]*)"\)', b.get("curve") or "")
                if to and cur:
                    paths.append({"block": b, "from": frm, "to": to.group(1),
                                  "curve": cur.group(1), "parent": parent})

    geo = MapGeo("DOOM.WAD", map_name)
    geo.opened |= set(cfg.get("force_open", ()))
    spawn_sec = geo.point_sector(spawn)
    spawn_floor = geo.sectors[spawn_sec][0]

    def pred_y(p):
        sec = geo.point_sector(p)
        if sec is None:
            return None
        return round((geo.sectors[sec][0] - spawn_floor) * Y_SCALE, 3)

    def dump_pos(st):
        x, _, z = stations[st]["pos"]
        return (x + spawn[0], z + spawn[1])

    # sanity: the local = dump - spawn convention must hold for this scene
    bad = sum(1 for s in stations if geo.point_sector(dump_pos(s)) is None)
    if bad > len(stations) * 0.1:
        raise RuntimeError(f"{map_name}: {bad}/{len(stations)} stations outside map - spawn offset wrong?")

    # ---- task 1: skirmish stations -------------------------------------
    enemies = parse_enemies(map_name)

    # Each station looks toward its next station (LookAtNextStation runs on
    # entry); a station with no outgoing path keeps its incoming direction.
    next_of = {}
    prev_of = {}
    for pth in paths:
        next_of.setdefault(pth["from"], pth["to"])
        prev_of.setdefault(pth["to"], pth["from"])

    def station_dir(name):
        other, flip = next_of.get(name), 1.0
        if other is None:
            other, flip = prev_of.get(name), -1.0 if prev_of.get(name) else 1.0
        if other is None:
            return None
        p, q = dump_pos(name), dump_pos(other)
        dx, dz = (q[0] - p[0]) * flip, (q[1] - p[1]) * flip
        ln = (dx * dx + dz * dz) ** 0.5
        return (dx / ln, dz / ln) if ln > 1e-6 else None

    import math
    cos_cover = math.cos(math.radians(FOV_COVER_DEG))

    # covered = some existing stop puts the enemy in the NEC ring, in sight,
    # and inside the camera cone. Anything else never latches: it is either
    # ridden past or shoots from off-screen - both are blow-pasts.
    def covered(e):
        for name in stations:
            p = dump_pos(name)
            if (e[0] - p[0]) ** 2 + (e[1] - p[1]) ** 2 > COVER_RANGE ** 2:
                continue
            d = station_dir(name)
            if d is not None and not in_cone(p, d, e, cos_cover):
                continue
            if sight_clear(geo, p, (e[0], e[1])):
                return True
        return False

    uncovered = [e for e in enemies if not covered(e)]

    segs = []  # straight, splittable segments
    for pth in paths:
        cb = subres.get(pth["curve"])
        if cb is None or cb.get("point_count") != "2":
            continue
        m = re.search(r"PackedVector3Array\(([^)]*)\)", cb.text())
        pts = [float(x) for x in m.group(1).split(",")]
        if len(pts) != 18 or any(abs(v) > 1e-9 for v in pts[:15]):
            continue
        a, b = dump_pos(pth["from"]), dump_pos(pth["to"])
        seg_len = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        if seg_len < MIN_SEG_LEN:
            continue
        segs.append({"path": pth, "a": a, "b": b, "len": seg_len, "hits": []})

    # Sample candidate stop points along every segment and greedily pick the
    # ones that engage the most still-unengaged enemies. A new stop aims its
    # camera at its cluster, so an enemy is engageable when it is inside the
    # NEC ring with sight - as long as the whole cluster fits in one screen
    # wedge for the camera to face.
    def best_wedge(p, idxs):
        """Largest subset of enemies (by index) within one WEDGE_DEG view."""
        if not idxs:
            return set()
        angs = sorted((math.atan2(uncovered[i][1] - p[1], uncovered[i][0] - p[0]), i)
                      for i in idxs)
        ext = angs + [(a + 2 * math.pi, i) for a, i in angs]
        half = math.radians(WEDGE_DEG)
        best = set()
        for s in range(len(angs)):
            grp = {i for a, i in ext[s:s + len(angs)] if a - ext[s][0] <= half}
            if len(grp) > len(best):
                best = grp
        return best

    samples = []
    for seg in segs:
        n = int(seg["len"])
        for i in range(n + 1):
            t = i / n
            if t * seg["len"] < END_MARGIN or (1 - t) * seg["len"] < END_MARGIN:
                continue
            px = seg["a"][0] + (seg["b"][0] - seg["a"][0]) * t
            pz = seg["a"][1] + (seg["b"][1] - seg["a"][1]) * t
            sec = geo.point_sector((px, pz))
            if sec is None or sec in geo.movable:
                continue  # don't park an encounter inside a door/lift slab
            in_ring = {i for i, e in enumerate(uncovered)
                       if (e[0] - px) ** 2 + (e[1] - pz) ** 2 <= COVER_RANGE ** 2
                       and sight_clear(geo, (px, pz), (e[0], e[1]))}
            cover = best_wedge((px, pz), in_ring)
            if cover:
                samples.append({"seg": seg, "t": t, "p": (px, pz), "cover": cover})

    remaining = set(range(len(uncovered)))
    picks = []
    while True:
        best = None
        for s in samples:
            per_seg = [p for p in picks if p["seg"] is s["seg"]]
            if len(per_seg) >= MAX_CLUSTERS_PER_SEG:
                continue
            if any(abs(p["t"] - s["t"]) * s["seg"]["len"] < CLUSTER_GAP for p in per_seg):
                continue
            gain = s["cover"] & remaining
            if len(gain) >= MIN_CLUSTER and (best is None or len(gain) > len(best[1])):
                best = (s, gain)
        if best is None:
            break
        best[0]["gain"] = best[1]
        picks.append(best[0])
        remaining -= best[1]

    inserts = []  # (segment, [ (t, point, engaged_enemies, aim_point) ... ])
    for seg in segs:
        placed = []
        for p in sorted((p for p in picks if p["seg"] is seg), key=lambda p: p["t"]):
            engaged = [uncovered[i] for i in p["gain"]]
            aim = (sum(e[0] for e in engaged) / len(engaged),
                   sum(e[1] for e in engaged) / len(engaged))
            placed.append((p["t"], p["p"], engaged, aim))
        if placed:
            inserts.append((seg, placed))

    # ---- task 2: look-at-interactable ----------------------------------
    lai_targets = []
    for name, st in stations.items():
        if "vc" not in exts:
            break
        conds = st["block"].get("conditions") or ""
        for rid in re.findall(r'SubResource\("([^"]*)"\)', conds):
            cb = subres.get(rid)
            if cb is None or cb.get("script") != f'ExtResource("{exts["vc"]}")':
                continue
            var = (cb.get("variable_name") or "").strip('"')
            if re.fullmatch(r"[DFL]\d+|key_\w+", var):
                lai_targets.append((name, var))

    print(f"\n=== {map_name}: {len(enemies)} enemies, {len(uncovered)} uncovered, "
          f"{sum(len(p) for _, p in inserts)} new stations, {len(lai_targets)} look-ats ===")
    for seg, placed in inserts:
        for t, pt, near, aim in placed:
            kinds = {}
            for e in near:
                kinds[e[2]] = kinds.get(e[2], 0) + 1
            print(f"  {seg['path']['from']} -> {seg['path']['to']} @t={t:.2f} "
                  f"({pt[0]:.1f},{pt[1]:.1f}): " + ", ".join(f"{v}x{k}" for k, v in kinds.items()))
    for name, var in lai_targets:
        print(f"  look-at {var} on {name}")
    if dry_run:
        return

    first_node = next(i for i, b in enumerate(blocks) if b.header.startswith("[node"))
    new_subs = []
    new_nodes = []

    # look-at actions
    for i, (name, var) in enumerate(lai_targets):
        rid = f"Resource_lai_{i}"
        new_subs.append(Block(f'[sub_resource type="Resource" id="{rid}"]', [
            f'script = ExtResource("{exts["lai"]}")',
            f'variable_name = "{var}"',
            "blocking = false",
            f'metadata/_custom_type_script = "{LAI_UID}"',
        ]))
        sa = stations[name]["block"].get("startActions")
        if sa is None:
            stations[name]["block"].set(
                "startActions",
                f'Array[ExtResource("{exts["ea"]}")]([SubResource("{rid}")])')
        else:
            stations[name]["block"].set(
                "startActions", sa[:sa.rindex("])")] + f', SubResource("{rid}")])')

    # skirmish stations
    counter = 1
    for seg, placed in inserts:
        pth = seg["path"]
        a_name, b_name = pth["from"], pth["to"]
        a_pos, b_pos = stations[a_name]["pos"], stations[b_name]["pos"]
        y_ok = all(
            pred_y(dump_pos(n)) is not None and abs(pred_y(dump_pos(n)) - stations[n]["pos"][1]) < 0.6
            for n in (a_name, b_name))
        chain = []
        for t, pt, near, aim in placed:
            y = pred_y(pt) if y_ok and pred_y(pt) is not None \
                else round(a_pos[1] + (b_pos[1] - a_pos[1]) * t, 3)
            ay = pred_y(aim)
            aim_local = (round(aim[0] - spawn[0], 3), ay if ay is not None else y,
                         round(aim[1] - spawn[1], 3))
            chain.append((f"Skirmish{counter}",
                          (round(pt[0] - spawn[0], 3), y, round(pt[1] - spawn[1], 3)),
                          aim_local))
            counter += 1
        hops = [(a_name, a_pos, None)] + chain + [(b_name, b_pos, None)]

        # repoint A's existing path/curve at the first new station
        old_nodepath = f'{pth["parent"]}/{a_name}__TO__{b_name}'
        new_pathname = f"{a_name}__TO__{chain[0][0]}"
        new_nodepath = f'{pth["parent"]}/{new_pathname}'
        pth["block"].header = pth["block"].header.replace(
            f'name="{a_name}__TO__{b_name}"', f'name="{new_pathname}"')
        pth["block"].set("to_station", f'NodePath("../../{chain[0][0]}")')
        a_block = stations[a_name]["block"]
        ns = a_block.get("next_stations")
        if ns is None or f'NodePath("../{b_name}")' not in ns:
            raise RuntimeError(f"{map_name}: {a_name} next_stations missing ../{b_name}")
        a_block.set("next_stations",
                    ns.replace(f'NodePath("../{b_name}")', f'NodePath("../{chain[0][0]}")'))
        curve_block = subres[pth["curve"]]
        d = (chain[0][1][0] - a_pos[0], chain[0][1][1] - a_pos[1], chain[0][1][2] - a_pos[2])
        for i, ln in enumerate(curve_block.lines):
            if "PackedVector3Array" in ln:
                curve_block.lines[i] = (
                    f'"points": PackedVector3Array(0, 0, 0, 0, 0, 0, 0, 0, 0, '
                    f'0, 0, 0, 0, 0, 0, {d[0]}, {d[1]}, {d[2]}),')
        for b in blocks:  # PathViz children of the renamed path node
            par = header_attr(b.header, "parent") or ""
            if par == old_nodepath or par.startswith(old_nodepath + "/"):
                b.header = b.header.replace(
                    f'parent="{old_nodepath}', f'parent="{new_nodepath}')

        for i in range(1, len(hops) - 1):
            name, pos, aim = hops[i]
            nxt_name, nxt_pos, _ = hops[i + 1]
            new_subs.append(Block(f'[sub_resource type="Resource" id="Resource_lans_{name}"]', [
                f'script = ExtResource("{exts["lans"]}")',
                "blocking = false",
                f'metadata/_custom_type_script = "{LANS_UID}"',
            ]))
            new_subs.append(Block(f'[sub_resource type="Resource" id="Resource_look_{name}"]', [
                f'script = ExtResource("{exts["lookat"]}")',
                f'targetNode = NodePath("../{name}Marker")',
                "blocking = false",
                f'metadata/_custom_type_script = "{LOOKAT_UID}"',
            ]))
            new_subs.append(Block(f'[sub_resource type="Resource" id="Resource_adv_{name}"]', [
                "resource_local_to_scene = true",
                f'script = ExtResource("{exts["adv"]}")',
            ]))
            new_subs.append(Block(f'[sub_resource type="Resource" id="Resource_nec_{name}"]', [
                f'script = ExtResource("{exts["nec"]}")',
                "max_distance = 10.0",
                f'metadata/_custom_type_script = "{NEC_UID}"',
            ]))
            d = (nxt_pos[0] - pos[0], nxt_pos[1] - pos[1], nxt_pos[2] - pos[2])
            new_subs.append(Block(f'[sub_resource type="Curve3D" id="Curve3D_{name}"]', [
                "_data = {",
                f'"points": PackedVector3Array(0, 0, 0, 0, 0, 0, 0, 0, 0, '
                f'0, 0, 0, 0, 0, 0, {d[0]}, {d[1]}, {d[2]}),',
                '"tilts": PackedFloat32Array(0, 0)',
                "}",
                "point_count = 2",
            ]))
            new_nodes.append(Block(
                f'[node name="{name}" parent="Stations" instance=ExtResource("{exts["station"]}")]', [
                    f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})",
                    f'next_stations = Array[NodePath]([NodePath("../{nxt_name}")])',
                    f'startActions = Array[ExtResource("{exts["ea"]}")]([SubResource("Resource_lans_{name}"), SubResource("Resource_look_{name}")])',
                    f'endActions = Array[ExtResource("{exts["ea"]}")]([SubResource("Resource_adv_{name}")])',
                    f'conditions = Array[ExtResource("{exts["ec"]}")]([SubResource("Resource_nec_{name}")])',
                    "one_shot = true",
                    "disc_color = Color(1, 0.55, 0.1, 1)",
                ]))
            new_nodes.append(Block(
                f'[node name="{name}__TO__{nxt_name}" type="Path3D" parent="Stations/{name}"]', [
                    f'curve = SubResource("Curve3D_{name}")',
                    f'script = ExtResource("{exts["railpath"]}")',
                    'from_station = NodePath("..")',
                    f'to_station = NodePath("../../{nxt_name}")',
                ]))
            new_nodes.append(Block(
                f'[node name="{name}Marker" parent="Stations" instance=ExtResource("{exts["marker"]}")]', [
                    f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {aim[0]}, {aim[1]}, {aim[2]})",
                    "disc_color = Color(1, 0.3, 0.1, 1)",
                ]))

    blocks[first_node:first_node] = new_subs
    blocks.extend(new_nodes)
    write_blocks(path, preamble, blocks)
    print(f"  wrote {path}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    for m in (args or list(MAPS)):
        process_map(m, dry)
