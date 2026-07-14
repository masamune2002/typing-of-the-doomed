#!/usr/bin/env python3
"""Shared RailNetwork .tscn generator for the gen_e2m*.py scripts.

The per-map scripts define SPAWN, PATH_BLOCK and RAW (design beats) and call
generate(). Routing/gating logic is expand_route() from gen_e1m9.py verbatim;
the writer adds two E2 station specials the E1 generators lacked:

  {"teleport": tag}  the station ends its rail chain with a
                     TeleportPlayerAction (destination_tag=tag) instead of an
                     advance. The NEXT beat starts a new chain placed exactly
                     on the WAD teleport-destination thing, and triggers by
                     the player landing inside it (EncounterPoint body entry
                     - the E1M8 finale pattern). A fallback RailMarker is
                     emitted at the next beat's position for geometry-only
                     loads. No rail path or routing crosses the gap.

  {"finale": dist}   last station of a boss map (E2M8): waits until nearby
                     enemies are cleared (NearbyEnemiesClearedCondition with
                     max_distance=dist), then runs EpisodeFinaleAction (the
                     episode text wall; prints [AUTOPLAY] DONE in autoplay).

RAW beats are (wad_x, wad_z, cond, comment) or (wad_x, wad_z, cond, comment,
special_dict). Conditions: None, "D<sector>", "F<sector>", "L<sector>",
"key_<name>" - see llm/RAIL_LEVEL_GUIDE.md.
"""

Y_SCALE = 0.038  # the WAD addon's vertical scale factor


def expand_chain(geo, raw):
    """Route every hop through real geometry, in route order (gen_e1m9)."""
    out = [raw[0]]
    unroutable = 0
    for i in range(len(raw) - 1):
        a, b = raw[i], raw[i + 1]
        pa, pb = (a[0], a[1]), (b[0], b[1])
        leg = [pa, pb]
        if geo.seg_scan(pa, pb)[0]:
            path = geo.find_path(pa, pb)
            if path is None:
                print("WARNING: no path (%.1f,%.1f) -> (%.1f,%.1f) [%s]"
                      % (a[0], a[1], b[0], b[1], b[3] or a[3]))
                unroutable += 1
            else:
                leg = path
                bee = ((pb[0] - pa[0]) ** 2 + (pb[1] - pa[1]) ** 2) ** 0.5
                plen = sum(((leg[k+1][0] - leg[k][0]) ** 2
                            + (leg[k+1][1] - leg[k][1]) ** 2) ** 0.5
                           for k in range(len(leg) - 1))
                if plen > max(4 * bee, bee + 25):
                    print("WARNING: suspicious detour %.0f (beeline %.0f) "
                          "(%.1f,%.1f) -> (%.1f,%.1f) [%s]"
                          % (plen, bee, a[0], a[1], b[0], b[1], b[3] or a[3]))
        pending_skip = None
        for j in range(len(leg) - 1):
            p, q = leg[j], leg[j + 1]
            _, gates = geo.seg_scan(p, q)
            dx, dz = q[0] - p[0], q[1] - p[1]
            length = (dx * dx + dz * dz) ** 0.5 or 1.0
            ux, uz = dx / length, dz / length
            for t, sec, mid in gates:
                cond = "D%d" % sec
                if sec == pending_skip:
                    pending_skip = None
                    continue
                pre = (mid[0] - ux * 1.5, mid[1] - uz * 1.5)
                post = (mid[0] + ux * 1.5, mid[1] + uz * 1.5)
                if geo.point_closed_door_sector(q) == sec:
                    if geo.seg_scan(p, pre) == ([], []):
                        out.append((pre[0], pre[1], cond, "at door %d" % sec))
                    else:
                        gt = max(t - 1.0 / length, 0.02)
                        out.append((p[0] + dx * gt, p[1] + dz * gt, cond,
                                    "at door %d" % sec))
                    pending_skip = sec
                    continue
                mid_probs, mid_gates = geo.seg_scan(pre, post)
                if (len(gates) == 1
                        and geo.seg_scan(p, pre) == ([], [])
                        and not mid_probs and [g[1] for g in mid_gates] == [sec]
                        and not geo.seg_scan(post, q)[0]):
                    out.append((pre[0], pre[1], cond, "at door %d" % sec))
                    out.append((post[0], post[1], None, "through door %d" % sec))
                    continue
                t_pre = t - 1.0 / length
                if t_pre <= 0.02:
                    prev = out[-1]
                    if prev[2] is None:
                        out[-1] = (prev[0], prev[1], cond, prev[3] + " @door")
                    elif prev[2] != cond:
                        gt = max(t - 0.3 / length, 0.02)
                        out.append((p[0] + dx * gt, p[1] + dz * gt, cond,
                                    "at door %d" % sec))
                else:
                    out.append((p[0] + dx * t_pre, p[1] + dz * t_pre, cond,
                                "at door %d" % sec))
            geo.commit_hop(p, q, gated=[g[1] for g in gates])
            if j < len(leg) - 2:
                out.append((q[0], q[1], None, "waypoint"))
        out.append(b)
    if unroutable:
        print("WARNING: %d unroutable hops left as straight lines" % unroutable)

    deduped = [out[0]]
    for st in out[1:]:
        prev = deduped[-1]
        close = ((st[0] - prev[0]) ** 2 + (st[1] - prev[1]) ** 2) ** 0.5 < 0.35
        if close and not (st[2] and prev[2]):
            if st[2] and not prev[2]:
                deduped[-1] = st
            continue
        deduped.append(st)
    return deduped


def _special(beat):
    return beat[4] if len(beat) > 4 else None


def expand_route(geo, raw):
    """Split RAW at teleport beats and route each chain separately.
    Returns a flat station list; teleport/finale specials survive expansion
    (they are re-attached to their beat, which routing never moves)."""
    chains = [[]]
    for beat in raw:
        chains[-1].append(beat)
        if _special(beat) and "teleport" in _special(beat):
            chains.append([])
    out = []
    for ci, chain in enumerate(chains):
        if not chain:
            continue
        expanded = expand_chain(geo, [b[:4] for b in chain])
        # Re-attach specials: expansion keeps every RAW beat's position as a
        # station, so match by (x, z).
        specials = {(b[0], b[1]): b[4] for b in chain if _special(b)}
        found = set()
        for st in expanded:
            sp = specials.get((st[0], st[1]))
            if sp:
                found.add((st[0], st[1]))
            out.append((st[0], st[1], st[2], st[3], sp))
        missing = set(specials) - found
        if missing:
            raise RuntimeError("special beats lost in expansion: %s" % missing)
        if ci < len(chains) - 1:
            last_sp = out[-1][4]
            if not (last_sp and "teleport" in last_sp):
                raise RuntimeError(
                    "chain %d must end on its teleport beat, ends at %s"
                    % (ci, out[-1][3]))
    return out


def make_name(i):
    if i == 0:
        return "StationA"
    if i == 1:
        return "StationB"
    return f"Station{i}"


def gen_color(i, total):
    hue = (i * 137.508) % 360
    s, v = 0.7, 0.9
    h = hue / 60.0
    x_val = int(h)
    f = h - x_val
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    if x_val == 0: r, g, b = v, t, p
    elif x_val == 1: r, g, b = q, v, p
    elif x_val == 2: r, g, b = p, v, t
    elif x_val == 3: r, g, b = p, q, v
    elif x_val == 4: r, g, b = t, p, v
    else: r, g, b = v, p, q
    return f"Color({r:.2f}, {g:.2f}, {b:.2f}, 1)"


def generate(map_name, spawn, raw, uid, path_block=(), out_path=None,
             wad="DOOM.WAD", force_open=()):
    from wadgeo import MapGeo
    spawn_x, spawn_z = spawn
    out_path = out_path or f"wads/doom/levels/{map_name}.tscn"

    geo = MapGeo(wad, map_name)
    geo.path_block = set(path_block)
    # Sectors wadgeo can't model as passable (switch-lowered floors) that the
    # route rides open behind a hand-placed condition (e.g. F<sector>).
    geo.opened |= set(force_open)
    route = expand_route(geo, raw)

    spawn_sec = geo.point_sector((spawn_x, spawn_z))
    spawn_floor = geo.sectors[spawn_sec][0]
    stations = []
    for i, (wx, wz, cond, comment, sp) in enumerate(route):
        sec = geo.point_sector((wx, wz))
        floor_raw = geo.sectors[sec][0] if sec is not None else spawn_floor
        sy = round((floor_raw - spawn_floor) * Y_SCALE, 3)
        stations.append({
            "name": make_name(i), "x": wx - spawn_x, "y": sy, "z": wz - spawn_z,
            "cond": cond, "comment": comment, "special": sp})
    total = len(stations)

    has_teleport = any(s["special"] and "teleport" in s["special"]
                       for s in stations)
    has_finale = any(s["special"] and "finale" in s["special"]
                     for s in stations)

    lines = []
    lines.append(f'[gd_scene format=4 uid="{uid}"]')
    lines.append('')
    lines.append('[ext_resource type="Script" uid="uid://cyk7v70xtekvh" path="res://rail/scenes/RailNetwork/RailNetwork.gd" id="1_rn"]')
    lines.append('[ext_resource type="Script" uid="uid://d4j6jipkme5ui" path="res://rail/scenes/RailPath/RailPath.gd" id="2_rp"]')
    lines.append('[ext_resource type="PackedScene" uid="uid://biyil85jx6ee0" path="res://rail/scenes/RailStation/RailStation.tscn" id="3_rs"]')
    lines.append('[ext_resource type="Script" uid="uid://b0e435ir2m5fv" path="res://rail/resources/EncounterAction.gd" id="4_ea"]')
    lines.append('[ext_resource type="PackedScene" path="res://rail/scenes/WadPreview/WadPreview.tscn" id="5_wp"]')
    lines.append('[ext_resource type="Script" uid="uid://dptfbfdqpn0pt" path="res://rail/resources/Actions/AdvanceToNextStationAction.gd" id="6_adv"]')
    lines.append('[ext_resource type="Script" uid="uid://bhwlq2o3k4btg" path="res://rail/resources/EncounterCondition.gd" id="7_ec"]')
    lines.append('[ext_resource type="Script" uid="uid://cjvj83eu0sl8t" path="res://rail/resources/Conditions/VariableCondition.gd" id="8_vc"]')
    if has_teleport:
        lines.append('[ext_resource type="Script" uid="uid://c2yyknt08j3or" path="res://rail/resources/Actions/TeleportPlayerAction.gd" id="9_tp"]')
        lines.append('[ext_resource type="PackedScene" uid="uid://ckj6xvts0psim" path="res://rail/scenes/RailMarker/RailMarker.tscn" id="10_marker"]')
    if has_finale:
        lines.append('[ext_resource type="Script" uid="uid://ks4fobmpgofu" path="res://rail/resources/Actions/EpisodeFinaleAction.gd" id="11_fin"]')
        lines.append('[ext_resource type="Script" uid="uid://dpqsds1tybnew" path="res://rail/resources/Conditions/NearbyEnemiesClearedCondition.gd" id="12_nec"]')
    lines.append('')

    # Advance actions for every station that advances along a rail path
    for i, st in enumerate(stations):
        sp = st["special"]
        if sp and "teleport" in sp:
            lines.append(f'[sub_resource type="Resource" id="Resource_tp_{i}"]')
            lines.append('script = ExtResource("9_tp")')
            lines.append(f'destination_tag = {sp["teleport"]}')
            if i < total - 1:
                lines.append(f'fallback_marker = NodePath("../TeleportDest{sp["teleport"]}Marker")')
            lines.append('metadata/_custom_type_script = "uid://c2yyknt08j3or"')
            lines.append('')
        elif sp and "finale" in sp:
            lines.append(f'[sub_resource type="Resource" id="Resource_fin_{i}"]')
            lines.append('script = ExtResource("11_fin")')
            lines.append('metadata/_custom_type_script = "uid://ks4fobmpgofu"')
            lines.append('')
            lines.append(f'[sub_resource type="Resource" id="Resource_nec_{i}"]')
            lines.append('script = ExtResource("12_nec")')
            lines.append(f'max_distance = {float(sp["finale"])}')
            lines.append('metadata/_custom_type_script = "uid://dpqsds1tybnew"')
            lines.append('')
        else:
            lines.append(f'[sub_resource type="Resource" id="Resource_adv_{i}"]')
            lines.append('resource_local_to_scene = true')
            lines.append('script = ExtResource("6_adv")')
            lines.append('')

    cond_map = {}
    cond_idx = 0
    for i, st in enumerate(stations):
        if st["cond"]:
            rid = f"cond_{cond_idx}"
            cond_map[i] = rid
            lines.append(f'[sub_resource type="Resource" id="Resource_{rid}"]')
            lines.append('script = ExtResource("8_vc")')
            lines.append(f'variable_name = "{st["cond"]}"')
            lines.append('metadata/_custom_type_script = "uid://cjvj83eu0sl8t"')
            lines.append('')
            cond_idx += 1

    def links_from(i):
        """A station links to the next unless it ends its chain."""
        sp = stations[i]["special"]
        if sp and "teleport" in sp:
            return False
        return i < total - 1

    for i in range(total - 1):
        if not links_from(i):
            continue
        dx = stations[i+1]["x"] - stations[i]["x"]
        dy = stations[i+1]["y"] - stations[i]["y"]
        dz = stations[i+1]["z"] - stations[i]["z"]
        lines.append(f'[sub_resource type="Curve3D" id="Curve3D_c{i}"]')
        lines.append('_data = {')
        lines.append(f'"points": PackedVector3Array(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {dx}, {dy}, {dz}),')
        lines.append('"tilts": PackedFloat32Array(0, 0)')
        lines.append('}')
        lines.append('point_count = 2')
        lines.append('')

    lines.append('[node name="RailNetwork" type="Node3D"]')
    lines.append('script = ExtResource("1_rn")')
    lines.append('')
    lines.append('[node name="WadPreview" parent="." instance=ExtResource("5_wp")]')
    lines.append(f'wad_path = "res://{wad}"')
    lines.append(f'map_name = "{map_name}"')
    lines.append('')
    lines.append('[node name="Stations" type="Node3D" parent="."]')
    lines.append('')

    for i, st in enumerate(stations):
        name = st["name"]
        sp = st["special"]
        lines.append(f'[node name="{name}" parent="Stations" instance=ExtResource("3_rs")]')
        if st["x"] != 0.0 or st["y"] != 0.0 or st["z"] != 0.0:
            lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {st["x"]}, {st["y"]}, {st["z"]})')
        if links_from(i):
            lines.append(f'next_stations = Array[NodePath]([NodePath("../{stations[i+1]["name"]}")])')
        if sp and "teleport" in sp:
            lines.append(f'endActions = Array[ExtResource("4_ea")]([SubResource("Resource_tp_{i}")])')
        elif sp and "finale" in sp:
            lines.append(f'endActions = Array[ExtResource("4_ea")]([SubResource("Resource_fin_{i}")])')
        else:
            lines.append(f'endActions = Array[ExtResource("4_ea")]([SubResource("Resource_adv_{i}")])')
        conds = []
        if i in cond_map:
            conds.append(f'SubResource("Resource_{cond_map[i]}")')
        if sp and "finale" in sp:
            conds.append(f'SubResource("Resource_nec_{i}")')
        if conds:
            lines.append(f'conditions = Array[ExtResource("7_ec")]([{", ".join(conds)}])')
        lines.append('one_shot = true')
        lines.append(f'disc_color = {gen_color(i, total)}')
        lines.append('')
        if links_from(i):
            nn = stations[i+1]["name"]
            pn = f'{name}__TO__{nn}'
            lines.append(f'[node name="{pn}" type="Path3D" parent="Stations/{name}"]')
            lines.append(f'curve = SubResource("Curve3D_c{i}")')
            lines.append('script = ExtResource("2_rp")')
            lines.append('from_station = NodePath("..")')
            lines.append(f'to_station = NodePath("../../{nn}")')
            lines.append('')
        if sp and "teleport" in sp and i < total - 1:
            nx = stations[i+1]
            lines.append(f'[node name="TeleportDest{sp["teleport"]}Marker" parent="Stations" instance=ExtResource("10_marker")]')
            lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {nx["x"]}, {nx["y"]}, {nx["z"]})')
            lines.append('disc_color = Color(0.6, 0.2, 0.9, 1)')
            lines.append('')

    with open(out_path, 'w') as f:
        f.write('\n'.join(lines))
    n_tp = sum(1 for s in stations if s["special"] and "teleport" in s["special"])
    print(f"Generated {out_path}: {total} stations, {len(cond_map)} conditions, "
          f"{n_tp} teleports")
    return route
