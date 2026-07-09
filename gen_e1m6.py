#!/usr/bin/env python3
"""Generate E1M6.tscn RailNetwork scene file for Typing of the DOOMed.

RAW below holds design "beats" (positions from llm/E1M6.md, guaranteed
walkable) in play order. expand_route() then:
  - A*-routes every hop that isn't directly walkable (wadgeo.py, real
    WAD linedefs, directional steps, player-radius clearance)
  - auto-inserts a condition station (D<sector>) in front of every closed
    manual door the route crosses, so the rail waits for the typed door

Progression: shotgun (W) -> courtyard + red key (NE) -> red doors ->
blue key (NW) -> RL room -> blue door -> yellow key -> stairs + closets ->
central complex + east wing (blue door 218) -> yellow door south ->
walkway + south switch ledge -> south rooms -> door 37 -> arena -> exit.
Skipped secrets: soulsphere lift (181), medkit closet (65), blue-armor pit.
"""

SPAWN_X = 1.0
SPAWN_Z = 43.0

# Sectors the router must never cross: 180 = blue-armor pit (no way back
# out). The raised imp ledge (151) and W1 doors are handled automatically
# by wadgeo's walkover-trigger simulation.
PATH_BLOCK = {180}

def wad_to_station(wx, wz):
    return (wx - SPAWN_X, 0.0, wz - SPAWN_Z)

# Each entry: (wad_x, wad_z, cond_val_or_None, comment). Conditions for
# doors are inserted automatically; hand conds are still honored if set.
RAW = [
    # ===== Hub =====
    (  1.0,  43.0, None, "player start"),
    (  9.5,  43.0, None, "stimpack"),
    (  4.5,  35.5, None, "armor bonus"),
    (-12.0,  35.5, None, "stimpack"),

    # ===== West room - shotgun (door 158 gated automatically) =====
    (-17.0,  43.0, None, "SHOTGUN"),
    (-20.0,  26.0, None, "zombiemen"),
    (-26.0,  36.0, None, "shotgunguy"),

    # ===== Courtyard - chaingun + red key =====
    ( 22.0,  36.0, None, "shotgunguy"),
    ( 46.0,  33.0, None, "zombieman"),
    ( 40.0,  48.0, None, "CHAINGUN"),
    ( 52.5,  42.0, "key_red_keycard", "RED KEYCARD - rail waits for pickup"),
    ( 56.0,  42.5, None, "spectre pocket"),
    ( 54.0,  56.0, None, "imp pocket"),
    ( 34.0,  60.0, None, "imp pocket"),
    ( 20.5,  51.0, None, "shotgunguy pocket"),
    ( 22.0,  43.0, "D187", "wait for the trap door to reopen"),

    # ===== Red door NW - blue key =====
    (-26.0,  36.0, None, "red door approach"),
    (-28.0,  41.0, None, "through red door"),
    (-43.0,  44.0, None, "stimpack"),
    (-48.0,  54.0, "key_blue_keycard", "BLUE KEYCARD - rail waits for pickup"),
    (-33.5,  41.5, None, "imp closet"),
    (-26.0,  36.0, None, "back through red door"),

    # ===== Central complex (hub south door gated automatically) =====
    (  8.0,  24.0, None, "shotgunguy"),
    ( -2.0,  18.0, None, "imp"),
    (  1.0,   4.0, None, "GREEN ARMOR"),
    ( -7.0,   4.0, None, "demon"),
    ( 14.0,   5.5, None, "health bonus"),

    # ===== SE yard + east area (blue door 218) =====
    ( 40.0,   8.0, None, "zombieman (walk trigger lowers imp ledge)"),
    ( 50.0,   6.0, None, "shotgunguy - blue door approach"),
    ( 61.0,  18.0, None, "zombieman (east area)"),
    ( 72.0,  17.0, None, "imps"),
    ( 67.0,  44.0, None, "imp"),
    ( 60.0,  61.0, None, "imp"),
    ( 82.0,  70.0, "D242", "SWITCH - opens corridor door (rail waits here)"),

    # ===== Corridor + stairs - yellow key =====
    ( 45.0,  26.5, None, "armor bonus (corridor)"),
    ( 34.0,  19.0, "key_yellow_keycard", "YELLOW KEYCARD - rail waits for pickup"),
    ( 31.0,  23.0, None, "GREEN ARMOR"),
    ( 51.0,  24.0, None, "closet imps"),
    ( 55.0,  19.0, None, "closet spectres"),
    ( 49.5,  29.0, None, "armor bonus (back out north)"),

    # ===== South corridor - yellow door =====
    (  4.5,  -0.5, None, "health bonus"),
    ( -2.0, -10.0, None, "demon"),
    ( -2.0, -15.0, None, "medkit"),
    ( -2.0, -17.0, None, "demons - yellow door approach"),

    # ===== Upper walkway + south switch =====
    (  4.0, -24.0, None, "zombieman"),
    (-18.0, -24.0, None, "zombieman"),
    ( -2.0, -70.0, None, "imps on the ledge"),
    ( -2.0, -73.5, "D37", "SWITCH - opens door 37 (rail waits here)"),

    # ===== Nukage + south rooms =====
    ( 10.0, -31.0, None, "RADIATION SUIT (drop into nukage)"),
    ( -2.0, -38.0, None, "shotgunguys"),
    (  4.0, -46.0, None, "shotgunguy"),
    ( -8.0, -54.0, None, "zombieman"),
    ( -2.0, -57.5, None, "zombieman"),

    # ===== West through door 37 =====
    (-16.0, -45.5, None, "stimpack"),
    (-24.0, -40.0, None, "shotgunguy (through door 37)"),
    (-30.0, -40.0, None, "GREEN ARMOR"),

    # ===== Arena =====
    (-43.5, -46.5, None, "imp (drop into arena)"),
    (-48.0, -35.0, None, "shotgunguy"),
    (-52.0, -47.0, None, "demon"),
    (-51.5, -49.5, None, "stimpack"),
    (-49.5, -43.3, None, "approach walk trigger"),
    (-52.0, -43.0, None, "walk trigger - west arena opens"),
    (-56.0, -42.0, None, "stimpack"),
    (-62.0, -39.0, None, "medkit"),
    (-64.0, -48.0, None, "demon"),
    (-68.5, -41.0, None, "imps"),

    # ===== Exit =====
    (-46.5, -43.0, "D28", "SWITCH - opens exit passage (rail waits here)"),
    (-61.0, -56.0, None, "spectres"),
    (-63.0, -64.0, None, "health bonuses (through exit doors)"),
    (-62.0, -62.5, None, "EXIT switch"),
]


def expand_route(raw):
    """Route every hop through real geometry, in route order.

    Unwalkable hops are replaced by A* waypoints; every closed manual door
    crossed gets a 'D<sector>' condition station right before it; walkover
    triggers the route crosses open their target sectors for later hops."""
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", "E1M6")
    geo.path_block = set(PATH_BLOCK)

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
                    # exit crossing of a slab whose entry was already gated;
                    # the player transits the open door in one motion
                    pending_skip = None
                    continue
                # Center the crossing between the jambs (crossed line's
                # midpoint): a rail that grazes the frame snags the player.
                pre = (mid[0] - ux * 1.5, mid[1] - uz * 1.5)
                post = (mid[0] + ux * 1.5, mid[1] + uz * 1.5)
                if geo.point_closed_door_sector(q) == sec:
                    # q sits inside the slab: gate before it, finish the
                    # crossing on the next sub-hop
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
                    # too close to the previous station: gate that one, or if
                    # it already carries another condition, squeeze a gate in
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

    # Drop near-duplicate consecutive stations (keep whichever carries a
    # condition; a zero-length rail curve never reports arrival).
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


def make_name(i):
    if i == 0: return "StationA"
    if i == 1: return "StationB"
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


Y_SCALE = 0.038  # the WAD addon's vertical scale factor


def write_tscn(filepath):
    from wadgeo import MapGeo
    stations = []
    route = expand_route(RAW)
    # Stations must sit at their sector's floor height: a y=0 station under
    # an elevated floor snaps below the map at runtime (and its rail path
    # with it), stranding the rail cursor underground.
    geo = MapGeo("DOOM.WAD", "E1M6")
    spawn_sec = geo.point_sector((SPAWN_X, SPAWN_Z))
    spawn_floor = geo.sectors[spawn_sec][0]
    for i, (wx, wz, cond, comment) in enumerate(route):
        sx, _, sz = wad_to_station(wx, wz)
        sec = geo.point_sector((wx, wz))
        floor_raw = geo.sectors[sec][0] if sec is not None else spawn_floor
        sy = round((floor_raw - spawn_floor) * Y_SCALE, 3)
        stations.append({"name": make_name(i), "x": sx, "y": sy, "z": sz,
                         "cond": cond, "comment": comment})
    total = len(stations)
    lines = []

    # Keep the uid of the pre-existing E1M6.tscn stub so references stay valid
    lines.append('[gd_scene format=4 uid="uid://r4av0u5554ux"]')
    lines.append('')
    lines.append('[ext_resource type="Script" uid="uid://cyk7v70xtekvh" path="res://rail/scenes/RailNetwork/RailNetwork.gd" id="1_rn"]')
    lines.append('[ext_resource type="Script" uid="uid://d4j6jipkme5ui" path="res://rail/scenes/RailPath/RailPath.gd" id="2_rp"]')
    lines.append('[ext_resource type="PackedScene" uid="uid://biyil85jx6ee0" path="res://rail/scenes/RailStation/RailStation.tscn" id="3_rs"]')
    lines.append('[ext_resource type="Script" uid="uid://b0e435ir2m5fv" path="res://rail/resources/EncounterAction.gd" id="4_ea"]')
    lines.append('[ext_resource type="PackedScene" path="res://rail/scenes/WadPreview/WadPreview.tscn" id="5_wp"]')
    lines.append('[ext_resource type="Script" uid="uid://dptfbfdqpn0pt" path="res://rail/resources/Actions/AdvanceToNextStationAction.gd" id="6_adv"]')
    lines.append('[ext_resource type="Script" uid="uid://bhwlq2o3k4btg" path="res://rail/resources/EncounterCondition.gd" id="7_ec"]')
    lines.append('[ext_resource type="Script" uid="uid://cjvj83eu0sl8t" path="res://rail/resources/Conditions/VariableCondition.gd" id="8_vc"]')
    lines.append('')

    # Every station gets an advance action; the last one has no next station,
    # which makes autoplay print DONE and quit cleanly at the end of the rail.
    for i in range(total):
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

    for i in range(total - 1):
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
    lines.append('wad_path = "res://DOOM.WAD"')
    lines.append('map_name = "E1M6"')
    lines.append('')
    lines.append('[node name="Stations" type="Node3D" parent="."]')
    lines.append('')

    for i, st in enumerate(stations):
        name = st["name"]
        lines.append(f'[node name="{name}" parent="Stations" instance=ExtResource("3_rs")]')
        if st["x"] != 0.0 or st["y"] != 0.0 or st["z"] != 0.0:
            lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {st["x"]}, {st["y"]}, {st["z"]})')
        if i < total - 1:
            lines.append(f'next_stations = Array[NodePath]([NodePath("../{stations[i+1]["name"]}")])')
        lines.append(f'endActions = Array[ExtResource("4_ea")]([SubResource("Resource_adv_{i}")])')
        if i in cond_map:
            lines.append(f'conditions = Array[ExtResource("7_ec")]([SubResource("Resource_{cond_map[i]}")])')
        lines.append('one_shot = true')
        lines.append(f'disc_color = {gen_color(i, total)}')
        lines.append('')
        if i < total - 1:
            nn = stations[i+1]["name"]
            pn = f'{name}__TO__{nn}'
            lines.append(f'[node name="{pn}" type="Path3D" parent="Stations/{name}"]')
            lines.append(f'curve = SubResource("Curve3D_c{i}")')
            lines.append('script = ExtResource("2_rp")')
            lines.append('from_station = NodePath("..")')
            lines.append(f'to_station = NodePath("../../{nn}")')
            lines.append('')

    with open(filepath, 'w') as f:
        f.write('\n'.join(lines))
    print(f"Generated {filepath}: {total} stations, {len(cond_map)} conditions")


if __name__ == "__main__":
    write_tscn("wads/doom/levels/E1M6.tscn")
