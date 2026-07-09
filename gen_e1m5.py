#!/usr/bin/env python3
"""Generate E1M5.tscn RailNetwork scene file for Typing of the DOOMed.

Station positions are based on enemy/item positions from the WAD dump
to ensure they're in walkable space. The route follows actual corridors.
"""

SPAWN_X = -7.0
SPAWN_Z = 19.5

def wad_to_station(wx, wz):
    return (wx - SPAWN_X, 0.0, wz - SPAWN_Z)

# Each entry: (wad_x, wad_z, cond_val_or_None, comment)
# Names are auto-generated: StationA, StationB, Station2, Station3, ...
RAW = [
    # ===== Phase 1: Start → south through corridor =====
    (-7.0,  19.5, None, "player start"),
    (-7.0,  16.0, None, ""),
    (-7.0,  12.0, None, ""),
    (-7.0,   8.0, None, ""),
    (-7.0,   5.0, None, "stimpack area"),
    (-9.0,   5.0, None, "stimpack"),
    (-13.0,  5.0, None, "green armor"),
    (-9.0,   1.0, None, "heading back east"),
    (-3.0,   1.0, None, "shotgunguy"),
    (-2.0,  -1.0, None, ""),
    (-2.0,  -5.0, None, "corridor south"),
    (-2.0,  -8.0, None, "spectre"),

    # ===== Phase 2: Through D71, trigger F91 to raise east platform =====
    (-2.0, -10.0, "D71", "door sector 71"),
    (-2.0, -11.0, None, "through door 71"),
    (-2.0, -14.0, "F91", "raise floor sector 91 - opens east path"),

    # ===== Phase 3: Back north, east through raised platform =====
    ( 0.0, -8.0, None, "heading back north"),
    ( 8.0, -2.0, None, "back east in start area"),
    (12.0, -5.0, None, "imp"),
    (16.0, -5.0, None, "east past raised F91"),
    (20.0, -6.0, None, ""),
    (24.0, -7.0, None, ""),
    (28.0, -5.5, None, "spectre"),
    (28.0, -10.0, None, "shotgunguy"),

    # ===== Phase 4: North then east through door 95 to chaingun =====
    (28.0, -5.5, None, "spectre - heading north"),
    (32.0, -4.0, None, ""),
    (34.5, -6.0, "D95", "door sector 95 north entrance"),
    (36.0, -6.0, None, "through door"),
    (38.5, -5.0, None, "armor bonus"),
    (40.5, -3.0, None, "blue armor"),
    (40.5, -1.5, None, "ROCKET LAUNCHER"),
    (42.0, -6.0, None, ""),
    (47.5, -18.5, None, "armor bonus"),
    (49.0, -18.5, None, "stimpack"),
    (50.0, -21.5, None, "medkit"),
    (53.0, -19.5, None, "CHAINGUN"),
    (48.0, -21.0, None, "computer map"),

    # ===== Phase 5: South to east wing door 121 =====
    (42.0, -26.0, None, "heading south"),
    (40.0, -30.0, "D121", "door sector 121"),
    (42.0, -30.0, None, "through door"),
    (42.0, -34.0, None, "demon"),
    (44.0, -36.0, None, "demon"),
    (42.0, -40.0, None, "demon"),
    (42.0, -44.0, None, "shotgunguy"),
    (38.0, -43.5, None, "imp"),
    (36.0, -47.5, None, "imp"),
    (34.0, -45.5, None, "imp"),
    (34.0, -41.5, None, "shotgunguy"),
    (34.0, -36.0, None, "shotgunguy"),

    # ===== Phase 6: Back west to yellow key =====
    (33.5, -26.0, None, "shotgunguy"),
    (29.5, -28.0, None, "shotgunguy"),
    (26.5, -28.0, None, "shotgunguy"),
    (21.5, -25.0, None, "YELLOW KEYCARD"),
    (21.5, -26.5, None, "medkit"),

    # ===== Phase 6: East corridor =====
    (26.5, -28.0, None, "shotgunguy"),
    (29.5, -28.0, None, "shotgunguy"),
    (31.0, -31.0, None, "shotgunguy"),
    (32.5, -31.0, None, "shotgunguy"),
    (33.5, -26.0, None, "shotgunguy"),

    # ===== Phase 7: South to east wing corridor =====
    (35.5, -31.0, None, "shotgunguy"),
    (37.0, -38.0, None, "zombieman"),

    # ===== Phase 8: East wing through door 121 =====
    (40.0, -30.0, "D121", "door sector 121"),
    (42.0, -30.0, None, "through door"),
    (42.0, -34.0, None, "demon"),
    (44.0, -36.0, None, "demon"),
    (42.0, -40.0, None, "demon"),
    (42.0, -44.0, None, "shotgunguy"),
    (38.0, -43.5, None, "imp"),
    (36.0, -47.5, None, "imp"),
    (34.0, -45.5, None, "imp"),
    (34.0, -41.5, None, "shotgunguy"),
    (34.0, -36.0, None, "shotgunguy"),

    # ===== Phase 9: To switch door + chaingun =====
    (42.0, -32.0, None, ""),
    (44.0, -30.0, None, "sector 122 switch"),
    (46.0, -30.0, "D122", "switch door sector 122"),
    (49.0, -30.0, None, ""),
    (51.5, -34.0, None, "shotgunguy"),
    (50.5, -36.0, None, "imp"),
    (50.0, -44.0, None, "imp"),
    (49.0, -38.0, None, "shotgunguy"),
    (50.0, -30.0, None, ""),
    (50.0, -24.0, None, ""),
    (50.0, -21.5, None, "medkit"),
    (53.0, -19.5, None, "CHAINGUN"),
    (49.0, -18.5, None, "stimpack"),
    (48.0, -21.0, None, "computer map"),

    # ===== Phase 10: Return west from east area =====
    (46.0, -26.0, None, ""),
    (42.0, -28.0, None, ""),
    (38.0, -30.0, None, ""),
    (34.0, -30.0, None, ""),
    (30.0, -28.0, None, ""),
    (26.0, -28.0, None, ""),
    (22.0, -26.0, None, ""),
    (18.0, -28.0, None, "shotgunguy"),

    # ===== Phase 11: Central area → blue key =====
    (12.0, -26.0, None, "zombieman"),
    ( 8.0, -29.0, None, "medkit"),
    ( 7.25,-28.5, None, "switch sector 141"),
    ( 6.0, -30.0, None, "zombieman"),
    ( 6.0, -32.5, None, "BLUE KEYCARD"),
    ( 4.0, -34.0, None, "health bonus"),
    ( 3.5, -34.0, None, "imp"),
    ( 4.0, -36.0, None, "health bonus"),

    # ===== Phase 12: Head to yellow key door =====
    ( 0.0, -34.0, None, ""),
    (-5.0, -30.0, None, ""),
    (-8.5, -25.0, None, "stimpack"),
    (-10.0,-26.0, None, ""),
    (-14.0,-26.0, None, "shotgunguy area"),
    (-16.0,-26.0, None, "zombieman"),
    (-16.0,-22.0, None, "zombieman"),
    (-17.0,-20.0, None, "shotgunguy"),

    # ===== Phase 13: Through yellow key door =====
    (-20.0,-26.0, "key_yellow_keycard", "yellow key door"),
    (-22.0,-26.0, None, "through door"),

    # ===== Phase 14: West nukage corridors =====
    (-24.0,-25.0, None, "demon"),
    (-26.0,-26.0, None, "demon"),
    (-30.0,-27.0, None, "zombieman"),
    (-30.0,-25.0, None, "zombieman"),
    (-31.0,-26.0, None, "imp"),
    (-32.0,-26.0, None, "imp"),

    # ===== Phase 15: To switch + deeper west =====
    (-34.0,-26.0, None, "switch area"),
    (-38.0,-26.0, None, ""),
    (-39.0,-26.0, None, ""),

    # ===== Phase 16: West room enemies =====
    (-43.0,-22.0, None, "imp/zombieman area"),
    (-43.5,-22.0, None, "imp"),
    (-44.0,-21.0, None, "zombieman"),
    (-43.0,-26.0, None, "center of room"),
    (-43.0,-31.0, None, "shotgunguy"),
    (-43.5,-30.0, None, "imp"),
    (-44.0,-31.0, None, "zombieman"),

    # ===== Phase 17: Deeper west - nukage + demons =====
    (-48.0,-26.0, None, ""),
    (-48.0,-14.0, None, "demon"),
    (-48.0,-38.0, None, "demon"),

    # ===== Phase 18: Far west - chainsaw =====
    (-51.0,-23.0, None, "shotgunguy"),
    (-53.0,-24.0, None, "zombieman"),
    (-55.0,-23.0, None, "zombieman"),
    (-56.5,-26.0, None, "medkit"),
    (-59.0,-23.5, None, "CHAINSAW"),
    (-55.0,-29.0, None, "zombieman"),
    (-53.0,-28.0, None, "zombieman"),
    (-51.0,-29.0, None, "shotgunguy"),

    # ===== Phase 19: South through west rooms =====
    (-43.0,-38.0, None, ""),
    (-42.0,-41.5, None, "imp/shotgunguy"),
    (-42.5,-43.0, None, "shotgunguy"),
    (-40.5,-43.0, None, "shotgunguy"),
    (-39.0,-43.0, None, "shotgunguy"),
    (-39.5,-41.5, None, "imp"),

    # ===== Phase 20: Return east from west area =====
    (-31.0,-39.5, None, "stimpack"),
    (-25.0,-43.5, None, "medkit"),
    (-22.0,-44.5, None, "health bonus"),
    (-19.0,-39.0, "D52", "door sector 52"),
    (-19.0,-42.0, None, ""),
    (-14.0,-39.0, None, ""),
    (-14.5,-34.0, None, "shotgunguy"),
    (-14.0,-28.0, None, "shotgunguy"),
    (-10.0,-34.0, None, ""),
    (-10.0,-39.0, None, "zombieman"),

    # ===== Phase 21: South to blue key door =====
    (-7.0, -39.0, None, "shotgunguy"),
    (-8.5, -37.5, None, "shotgunguy"),
    (-5.0, -39.0, None, "zombieman"),
    ( 0.0, -39.0, None, "zombieman"),
    ( 3.5, -40.5, None, "spectre"),
    ( 0.0, -43.0, None, "spectre"),
    (-1.0, -46.0, None, "stimpack"),
    ( 0.0, -49.0, "key_blue_keycard", "BLUE KEY DOOR"),
    ( 0.0, -51.0, None, "through blue key door"),

    # ===== Phase 22: Southern dark area =====
    (-1.0, -54.0, None, ""),
    (-5.5, -57.5, None, "rocket launcher"),
    (-10.0,-54.0, None, "medkit"),
    (-14.0,-56.0, None, "zombieman"),
    (-16.0,-62.0, None, "medkit"),
    (-12.0,-65.5, None, "shotgunguy"),
    (-10.0,-62.5, None, "spectre"),
    (-8.0, -62.0, None, ""),
    (-6.0, -62.0, None, "shotgunguy"),
    (-1.5, -60.0, None, "shotgunguy"),
    ( 0.0, -63.5, None, "medkit"),
    ( 1.5, -60.0, None, "shotgunguy"),
    ( 6.0, -59.0, None, "shotgunguy"),
    ( 6.0, -67.5, None, "shotgunguy"),
    ( 9.0, -66.5, None, "spectre"),
    (14.0, -63.0, None, "spectre/shotgunguy"),
    (14.0, -54.0, None, "shotgunguy"),
    (12.0, -64.0, None, "zombieman"),
    (10.0, -54.0, None, "medkit"),
    ( 3.5, -69.0, None, "medkit"),
    ( 0.0, -71.0, None, "shotgunguy"),
    (-3.0, -69.0, None, "spectre"),
    (-8.0, -69.5, None, "medkit"),
    (-11.0,-73.0, None, "demon"),
    (-8.0, -77.0, None, "demon"),
    (-11.0,-77.0, None, "demon"),

    # ===== Phase 23: Exit =====
    (-6.0, -73.0, "D117", "door sector 117"),
    (-6.0, -74.5, None, "through door"),
    (-7.0, -76.0, None, ""),
    (-9.0, -78.0, None, "EXIT switch"),
]


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


def write_tscn(filepath):
    stations = []
    for i, (wx, wz, cond, comment) in enumerate(RAW):
        sx, _, sz = wad_to_station(wx, wz)
        stations.append({"name": make_name(i), "x": sx, "y": 0.0, "z": sz,
                         "cond": cond, "comment": comment})
    total = len(stations)
    lines = []

    lines.append('[gd_scene format=4 uid="uid://duxptqocjb3w6"]')
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
    lines.append('say_hello = true')
    lines.append('')
    lines.append('[node name="WadPreview" parent="." instance=ExtResource("5_wp")]')
    lines.append('wad_path = "res://DOOM.WAD"')
    lines.append('map_name = "E1M5"')
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
    write_tscn("wads/doom/levels/E1M5.tscn")
