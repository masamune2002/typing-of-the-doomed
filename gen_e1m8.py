#!/usr/bin/env python3
"""Generate E1M8.tscn RailNetwork scene file for Typing of the DOOMed.

E1M8 (Phobos Anomaly) is gated by switch-lowered floors (type-23 "S1 Floor
Lower"), not keys/lifts like earlier maps. The critical path from spawn
(sector 9) to the Baron arena has exactly three gates:
  1. F10  - the spawn-room exit wall (sector 10, switch at wad (-2,7))
  2. D21  - a DR door in the descent corridor (auto-gated)
  3. lift 28 - an ascent platform into the boss room (wad trigger (13,-76))

The route ENDS at the Baron arena floor (sector 31, floor 0) where the player
faces the two Barons of Hell from below. The true level exit (a teleporter
closet behind the tag-666 baron-death floor) is deliberately skipped: autoplay
keeps enemies alive, so the barons never die and that floor never lowers.

wadgeo models neither type-23 switch-floors nor type-62 lifts as passable, so
FORCE_OPEN seeds geo.opened with those sectors for pathing. The F10 CONDITION
still gates the rail at runtime (autoplay auto-activates it); the ascent lift
needs no condition (guide's "ascent is naturally stable" pattern) - explicit
beats cross its trigger line so the player physically rides it up.
"""

SPAWN_X = -4.0
SPAWN_Z = 7.0

# Sectors the router must never cross: sector 0 is the nukage (Damage5) pool.
PATH_BLOCK = {0}

# Sectors wadgeo cannot model as passable but which ARE open by the time the
# route needs them (checked/pathed as open from the start; the route crosses
# each exactly once, so pre-opening creates no bogus shortcuts elsewhere):
#   10 = spawn-room exit floor (type-23 S1 Floor Lower, switch (-2,7))
#   28 = ascent lift into the boss room (type-62 Platform Lower Wait Raise)
FORCE_OPEN = {10, 28}

def wad_to_station(wx, wz):
    return (wx - SPAWN_X, 0.0, wz - SPAWN_Z)

# Each entry: (wad_x, wad_z, cond_val_or_None, comment). Door conditions are
# inserted automatically; hand conds (F10) are honored as-is.
RAW = [
    # ===== Spawn room (sector 9) =====
    ( -4.0,   7.0, None, "player start"),
    ( -2.5,   7.0, "F10", "SWITCH: lower spawn-room wall (sector 10)"),

    # ===== Descent staircase -> DR door 21 (gated automatically) =====
    ( 13.0, -14.0, None, "foot of the descent staircase"),
    ( 13.0, -25.0, None, "through DR door 21 into the corridor"),
    ( 13.0, -40.0, None, "spectre corridor (pit, sector 26)"),

    # ===== Ascent lift 28 up into the boss room =====
    # This lift's WR trigger line sits flush with the platform's own edge
    # (z=-76): while the lift is raised it walls off the pit, so the player's
    # CENTER can never cross the line to fire it (they wedge ~10 units short).
    # The pure walkover ascent therefore deadlocks. Instead gate the approach
    # on L28 - the lift var reads true only while the platform is bottomed, so
    # the rail forces it down (autoplay auto-activates) and holds until it has
    # arrived. The player boards the bottomed platform, which then auto-raises
    # ("Platform Lower Wait Raise") and carries them up to the arena floor.
    ( 13.0, -73.0, "L28", "approach lift 28 - wait for it to bottom out"),
    ( 13.0, -77.0, None, "onto lift 28 - ride it up"),
    ( 13.0, -80.0, None, "top of lift (arena platform, sector 27)"),

    # ===== Baron arena (sector 31, floor 0) - final confrontation =====
    ( 13.0, -95.0, None, "BARON ARENA - final node (face the two Barons)"),
]


def expand_route(raw):
    """Route every hop through real geometry, in route order (see gen_e1m7).

    Seeds geo.opened with FORCE_OPEN so the switch-floor and ascent lift the
    route rides are treated as passable by A*."""
    from wadgeo import MapGeo
    geo = MapGeo("DOOM.WAD", "E1M8")
    geo.path_block = set(PATH_BLOCK)
    geo.opened |= FORCE_OPEN

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
    geo = MapGeo("DOOM.WAD", "E1M8")
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

    # Keep the uid of the pre-existing E1M8.tscn stub so references stay valid
    lines.append('[gd_scene format=4 uid="uid://bn211uctg01ts"]')
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
    lines.append('map_name = "E1M8"')
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
    write_tscn("wads/doom/levels/E1M8.tscn")
