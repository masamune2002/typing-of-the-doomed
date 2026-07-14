#!/usr/bin/env python3
"""Convert `godot --headless -- --dump-map <MAP>` output into llm/<MAP>.md.

Usage: python3 dump_to_md.py E2M1 [dump_file] [out_file]
       (dump_file defaults to /tmp/dump_<MAP>.txt, out_file to llm/<MAP>.md)

The dump names things from the game's runtime dictionaries, which are
incomplete (e.g. Spectre prints as Unknown(58)); THING_NAMES below overrides
them with the display names the E1 docs established. Linedef type names are
the standard DOOM v1.9 special table.
"""
import re
import sys

MAP_TITLES = {
    "E1M1": "Hangar", "E1M2": "Nuclear Plant", "E1M3": "Toxin Refinery",
    "E1M4": "Command Control", "E1M5": "Phobos Lab",
    "E1M6": "Central Processing", "E1M7": "Computer Station",
    "E1M8": "Phobos Anomaly", "E1M9": "Military Base (Secret)",
    "E2M1": "Deimos Anomaly", "E2M2": "Containment Area", "E2M3": "Refinery",
    "E2M4": "Deimos Lab", "E2M5": "Command Center",
    "E2M6": "Halls of the Damned", "E2M7": "Spawning Vats",
    "E2M8": "Tower of Babel", "E2M9": "Fortress of Mystery (Secret)",
}

ENEMY_NAMES = {
    7: "SpiderMastermind", 9: "ShotgunGuy", 16: "Cyberdemon", 58: "Spectre",
    3001: "Imp", 3002: "Demon", 3003: "BaronOfHell", 3004: "Zombieman",
    3005: "Cacodemon", 3006: "LostSoul",
}
KEY_NAMES = {
    5: "Blue Keycard", 6: "Yellow Keycard", 13: "Red Keycard",
    38: "Red Skull Key", 39: "Yellow Skull Key", 40: "Blue Skull Key",
}
WEAPON_NAMES = {
    2001: "Shotgun", 2002: "Chaingun", 2003: "Rocket Launcher",
    2004: "Plasma Rifle", 2005: "Chainsaw", 2006: "BFG9000",
}
ITEM_NAMES = {
    8: "Backpack", 2011: "Stimpack", 2012: "Medkit",
    2013: "Supercharge (Soulsphere)", 2014: "HealthBonus",
    2015: "ArmorBonus", 2018: "GreenArmor", 2019: "BlueArmor",
    2022: "Invulnerability", 2023: "Berserk", 2024: "Invisibility",
    2025: "Radiation Suit", 2026: "Computer Map",
    2045: "Light Amplification Visor",
}

# Standard DOOM linedef specials (the subset that appears in E1/E2).
LINE_TYPE_NAMES = {
    1: "DR Door Open Wait Close", 2: "W1 Door Open Stay",
    3: "W1 Door Close Stay", 4: "W1 Door Open Wait Close",
    5: "W1 Floor Raise to Lowest Ceiling", 6: "W1 Ceiling Crusher Fast",
    7: "S1 Build Stairs 8", 8: "W1 Build Stairs 8", 9: "S1 Floor Donut",
    10: "W1 Platform Lower Wait Raise", 11: "S1 Exit Level",
    13: "W1 Light to 255", 14: "S1 Floor Raise 32 Change Texture",
    15: "S1 Floor Raise 24 Change Texture", 16: "W1 Door Close Wait Open",
    18: "S1 Floor Raise to Next Higher", 19: "W1 Floor Lower to Highest",
    20: "S1 Floor Raise Next Higher Change Texture",
    21: "S1 Platform Lower Wait Raise",
    22: "W1 Floor Raise Next Higher Change Texture",
    23: "S1 Floor Lower to Lowest", 24: "G1 Floor Raise to Lowest Ceiling",
    25: "W1 Ceiling Crusher Slow", 26: "DR Door Blue Key Open Wait Close",
    27: "DR Door Yellow Key Open Wait Close",
    28: "DR Door Red Key Open Wait Close", 29: "S1 Door Open Wait Close",
    30: "W1 Floor Raise by Shortest Lower Texture",
    31: "D1 Door Open Stay", 32: "D1 Door Blue Key Open Stay",
    33: "D1 Door Red Key Open Stay", 34: "D1 Door Yellow Key Open Stay",
    35: "W1 Light to 35", 36: "W1 Floor Lower to 8 Above Highest Adjacent",
    37: "W1 Floor Lower to Lowest Change Texture+Type",
    38: "W1 Floor Lower to Lowest", 39: "W1 Teleport",
    40: "W1 Ceiling Raise to Highest Ceiling", 41: "S1 Ceiling Lower to Floor",
    42: "SR Door Close Stay", 43: "SR Ceiling Lower to Floor",
    44: "W1 Ceiling Lower to 8 Above Floor", 45: "SR Floor Lower to Highest",
    46: "GR Door Open Stay", 47: "G1 Floor Raise Next Higher Change Texture",
    48: "Scrolling Wall Left", 49: "S1 Ceiling Crusher Slow",
    50: "S1 Door Close Stay", 51: "S1 Exit to Secret Level",
    52: "W1 Exit Level", 53: "W1 Platform Perpetual Raise",
    54: "W1 Platform Stop", 55: "S1 Floor Raise Crush",
    56: "W1 Floor Raise Crush", 57: "W1 Ceiling Crusher Stop",
    58: "W1 Floor Raise 24", 59: "W1 Floor Raise 24 Change Texture",
    60: "SR Floor Lower to Lowest", 61: "SR Door Open Stay",
    62: "SR Platform Lower Wait Raise", 63: "SR Door Open Wait Close",
    64: "SR Floor Raise to Lowest Ceiling", 65: "SR Floor Raise Crush",
    66: "SR Floor Raise 24 Change Texture",
    67: "SR Floor Raise 32 Change Texture",
    68: "SR Floor Raise Next Higher Change Texture",
    69: "SR Floor Raise to Next Higher", 70: "SR Floor Lower to 8 Above Highest Adjacent",
    71: "S1 Floor Lower to 8 Above Highest Adjacent",
    72: "WR Ceiling Lower to 8 Above Floor", 73: "WR Ceiling Crusher Slow",
    74: "WR Ceiling Crusher Stop", 75: "WR Door Close Stay",
    76: "WR Door Close Wait Open", 77: "WR Ceiling Crusher Fast",
    79: "WR Light to 35", 80: "WR Light to Brightest Adjacent",
    81: "WR Light to 255", 82: "WR Floor Lower to Lowest",
    83: "WR Floor Lower to Highest",
    84: "WR Floor Lower to Lowest Change Texture+Type",
    86: "WR Door Open Stay", 87: "WR Platform Perpetual Raise",
    88: "WR Platform Lower Wait Raise", 89: "WR Platform Stop",
    90: "WR Door Open Wait Close", 91: "WR Floor Raise to Lowest Ceiling",
    92: "WR Floor Raise 24", 93: "WR Floor Raise 24 Change Texture",
    94: "WR Floor Raise Crush", 95: "WR Floor Raise Next Higher Change Texture",
    96: "WR Floor Raise by Shortest Lower Texture", 97: "WR Teleport",
    98: "WR Floor Lower to 8 Above Highest Adjacent",
    101: "S1 Floor Raise to Lowest Ceiling",
    102: "S1 Floor Lower to Highest Adjacent", 103: "S1 Door Open Stay",
    104: "W1 Light to Darkest Adjacent", 105: "WR Door Blue Key Open Wait Close",
    106: "WR Door Yellow Key Open Wait Close", 107: "WR Door Red Key Open Wait Close",
    108: "WR Door Open Wait Close Fast", 109: "WR Door Open Stay Fast",
    117: "DR Door Open Wait Close Fast", 118: "D1 Door Open Stay Fast",
    119: "W1 Floor Raise to Next Higher", 120: "WR Platform Lower Wait Raise Fast",
    121: "W1 Platform Lower Wait Raise Fast", 123: "SR Platform Lower Wait Raise Fast",
    124: "W1 Exit to Secret Level", 125: "W1 Teleport Monsters Only",
    126: "WR Teleport Monsters Only",
}

# The WAD addon's TTYPE enum (LevelBuilder.gd) — the dump's trigger= field.
TRIGGER_NAMES = {
    0: "DOOR", 1: "DOOR1", 2: "SWITCH1", 3: "SWITCHR", 4: "WALK1",
    5: "WALKR", 6: "GUN1", 7: "GUNR", 8: "NONE",
}


def fnum(v):
    f = float(v)
    if f == int(f):
        return "%.1f" % f
    return repr(f)


def parse_dump(path):
    d = {"verts": {}, "sectors": [], "triggers": [], "interactions": [],
         "things": [], "tags": {}, "counts": {}}
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith("[BOUNDS]"):
                m = re.match(r"\[BOUNDS\] min=\(([^)]*)\) max=\(([^)]*)\)", line)
                d["min"] = [float(x) for x in m.group(1).split(",")]
                d["max"] = [float(x) for x in m.group(2).split(",")]
            elif line.startswith("[VERTICES]"):
                d["counts"]["verts"] = int(line.split("count=")[1])
            elif line.startswith("[SECTORS]"):
                d["counts"]["sectors"] = int(line.split("count=")[1])
            elif line.startswith("[LINEDEFS]"):
                d["counts"]["linedefs"] = int(line.split("count=")[1])
            elif line.startswith("[THINGS]"):
                d["counts"]["things"] = int(line.split("count=")[1])
            elif line.startswith("[SECTOR] "):
                m = re.match(
                    r"\[SECTOR\] (\d+) floor=([-\d.]+) ceil=([-\d.]+) "
                    r"light=(\d+) type=(\S+) tag=(\d+) floorTex=(\S*) "
                    r"ceilTex=(\S*) neighbours=", line)
                d["sectors"].append({
                    "idx": int(m.group(1)), "floor": float(m.group(2)),
                    "ceil": float(m.group(3)), "light": int(m.group(4)),
                    "type": m.group(5), "tag": int(m.group(6)),
                    "ftex": m.group(7), "ctex": m.group(8)})
            elif line.startswith("[LINEDEF_TRIGGER]"):
                m = re.match(
                    r"\[LINEDEF_TRIGGER\] (\d+) type=(\d+) tag=(\d+) "
                    r"trigger=(\S*) front_sector=(-?\d+) back_sector=(\S+) "
                    r"verts=\((\d+),(\d+)\) start=\(([^)]*)\) end=\(([^)]*)\)",
                    line)
                d["triggers"].append({
                    "idx": int(m.group(1)), "type": int(m.group(2)),
                    "tag": int(m.group(3)), "trigger": m.group(4),
                    "front": int(m.group(5)), "back": m.group(6),
                    "start": m.group(9), "end": m.group(10)})
            elif line.startswith("[INTERACTION]"):
                m = re.match(
                    r"\[INTERACTION\] sector=(\d+) linedef=(-?\d+) type=(\d+) "
                    r"trigger=(\S*) npc=(.*)", line)
                d["interactions"].append({
                    "sector": int(m.group(1)), "linedef": int(m.group(2)),
                    "type": int(m.group(3)), "trigger": m.group(4),
                    "npc": m.group(5)})
            elif line.startswith("[THING]"):
                m = re.match(
                    r"\[THING\] (\d+) type=(\d+) name=(\S+) "
                    r"pos=\(([^,]+), [^,]+, ([^)]+)\) angle=(-?\d+) "
                    r"flags=\[([^\]]*)\]", line)
                d["things"].append({
                    "idx": int(m.group(1)), "type": int(m.group(2)),
                    "name": m.group(3), "x": float(m.group(4)),
                    "z": float(m.group(5)), "angle": int(m.group(6)),
                    "flags": m.group(7)})
            elif line.startswith("[TAG] "):
                m = re.match(r"\[TAG\] (\d+) -> sectors=\[([^\]]*)\]", line)
                secs = [int(s) for s in m.group(2).split(",") if s.strip()]
                d["tags"][int(m.group(1))] = secs
    return d


def tag_cell(tag, tags):
    if tag == 0:
        return "0"
    return "%d -> sectors %s" % (tag, tags.get(tag, []))


def write_md(map_name, d, out_path):
    title = MAP_TITLES.get(map_name, map_name)
    L = []
    L.append("# %s: %s" % (map_name, title))
    L.append("")
    L.append("## Overview")
    L.append("")
    L.append("- **Map**: %s - %s" % (map_name, title))
    L.append("- **Vertices**: %d" % d["counts"]["verts"])
    L.append("- **Sectors**: %d" % d["counts"]["sectors"])
    L.append("- **Linedefs**: %d" % d["counts"]["linedefs"])
    L.append("- **Things**: %d" % d["counts"]["things"])
    w = d["max"][0] - d["min"][0]
    h = d["max"][2] - d["min"][2]
    L.append("- **Bounds**: X=[%s, %s], Y=[%s, %s]" % (
        fnum(d["min"][0]), fnum(d["max"][0]),
        fnum(d["min"][2]), fnum(d["max"][2])))
    L.append("- **Dimensions**: %s x %s" % (fnum(w), fnum(h)))
    L.append("")

    L.append("## Player Start")
    L.append("")
    starts = [t for t in d["things"] if t["type"] == 1]
    for t in starts[:1]:
        L.append("- **PlayerStart**: pos=(%s, %s) angle=%d" % (
            fnum(t["x"]), fnum(t["z"]), t["angle"]))
    L.append("")

    L.append("## Enemies")
    L.append("")
    enemies = [t for t in d["things"] if t["type"] in ENEMY_NAMES]
    L.append("**Total: %d enemies**" % len(enemies))
    L.append("")
    for tid in sorted({t["type"] for t in enemies}):
        group = [t for t in enemies if t["type"] == tid]
        L.append("### %s (type %d) x%d" % (ENEMY_NAMES[tid], tid, len(group)))
        L.append("")
        L.append("| # | Position (x, z) | Angle | Flags |")
        L.append("|---|-----------------|-------|-------|")
        for t in group:
            L.append("| %d | (%s, %s) | %d | %s |" % (
                t["idx"], fnum(t["x"]), fnum(t["z"]), t["angle"], t["flags"]))
        L.append("")

    L.append("## Keys")
    L.append("")
    keys = [t for t in d["things"] if t["type"] in KEY_NAMES]
    if not keys:
        L.append("No keys in this map.")
    for t in keys:
        L.append("- **%s** (type %d): pos=(%s, %s) flags=[%s]" % (
            KEY_NAMES[t["type"]], t["type"], fnum(t["x"]), fnum(t["z"]),
            t["flags"]))
    L.append("")

    L.append("## Weapons")
    L.append("")
    weapons = [t for t in d["things"] if t["type"] in WEAPON_NAMES]
    if not weapons:
        L.append("No weapon pickups in this map.")
    for t in weapons:
        L.append("- **%s** (type %d): pos=(%s, %s) flags=[%s]" % (
            WEAPON_NAMES[t["type"]], t["type"], fnum(t["x"]), fnum(t["z"]),
            t["flags"]))
    L.append("")

    L.append("## Items")
    L.append("")
    items = [t for t in d["things"] if t["type"] in ITEM_NAMES]
    for tid in sorted({t["type"] for t in items}):
        group = [t for t in items if t["type"] == tid]
        L.append("### %s (type %d) x%d" % (ITEM_NAMES[tid], tid, len(group)))
        L.append("")
        for t in group:
            L.append("- pos=(%s, %s) flags=[%s]" % (
                fnum(t["x"]), fnum(t["z"]), t["flags"]))
        L.append("")

    L.append("## Triggers & Doors")
    L.append("")
    L.append("### Linedef Triggers")
    L.append("")
    L.append("| Linedef | Type | Type Name | Tag | Front Sector | Back Sector | Start | End |")
    L.append("|---------|------|-----------|-----|-------------|-------------|-------|-----|")
    scrollers = [t for t in d["triggers"] if t["type"] == 48]
    for t in sorted(d["triggers"], key=lambda t: t["idx"]):
        if t["type"] == 48:
            continue
        tname = LINE_TYPE_NAMES.get(t["type"], "Unknown(%d)" % t["type"])
        L.append("| %d | %d | %s | %s | %d | %s | (%s) | (%s) |" % (
            t["idx"], t["type"], tname, tag_cell(t["tag"], d["tags"]),
            t["front"], t["back"], t["start"], t["end"]))
    L.append("")
    if scrollers:
        L.append("### Scrolling Walls (type 48) x%d" % len(scrollers))
        L.append("")
        L.append("- %d scrolling wall linedefs (decorative, not gameplay triggers)" % len(scrollers))
        L.append("")

    L.append("### Interactions")
    L.append("")
    L.append("| Sector | Linedef | Type | Type Name | Trigger | Trigger Name | NPC |")
    L.append("|--------|---------|------|-----------|---------|-------------|-----|")
    for it in d["interactions"]:
        tname = LINE_TYPE_NAMES.get(it["type"], "Unknown(%d)" % it["type"])
        trig = it["trigger"]
        if trig == "":
            trig_name = "-"
            trig = "-"
        else:
            trig_name = TRIGGER_NAMES.get(int(trig), "?")
        L.append("| %d | %d | %d | %s | %s | %s | %s |" % (
            it["sector"], it["linedef"], it["type"], tname, trig, trig_name,
            it["npc"]))
    L.append("")

    L.append("## Sectors (Notable)")
    L.append("")
    L.append("Only sectors with non-Normal type, non-zero tag, or referenced by triggers.")
    L.append("")
    L.append("| Sector | Floor | Ceiling | Light | Type | Tag | Floor Tex | Ceil Tex |")
    L.append("|--------|-------|---------|-------|------|-----|-----------|----------|")
    referenced = set()
    for t in d["triggers"]:
        referenced.add(t["front"])
        if t["back"] != "none":
            referenced.add(int(t["back"]))
        if t["tag"] != 0:
            referenced.update(d["tags"].get(t["tag"], []))
    for s in d["sectors"]:
        if s["type"] == "Normal" and s["tag"] == 0 and s["idx"] not in referenced:
            continue
        L.append("| %d | %s | %s | %d | %s | %d | %s | %s |" % (
            s["idx"], fnum(s["floor"]), fnum(s["ceil"]), s["light"],
            s["type"], s["tag"], s["ftex"], s["ctex"]))
    L.append("")

    L.append("## Tags")
    L.append("")
    real_tags = sorted(t for t in d["tags"] if t != 0)
    if not real_tags:
        L.append("No tagged sectors in this map.")
    for t in real_tags:
        L.append("- **Tag %d**: Sectors %s" % (t, d["tags"][t]))
    L.append("")

    L.append("## Secret Sectors")
    L.append("")
    secrets = [s for s in d["sectors"] if s["type"] == "Secret"]
    if not secrets:
        L.append("No secret sectors in this map.")
    for s in secrets:
        L.append("- **Sector %d**: floor=%s, ceil=%s, light=%d, tag=%d, floorTex=%s" % (
            s["idx"], fnum(s["floor"]), fnum(s["ceil"]), s["light"],
            s["tag"], s["ftex"]))
    L.append("")

    L.append("## Geometry Summary")
    L.append("")
    L.append("- **Total linedefs**: %d" % d["counts"]["linedefs"])
    L.append("- **Trigger linedefs**: %d" % len(d["triggers"]))
    L.append("- **Approximate bounds**: %d x %d units" % (round(w), round(h)))
    ratio = w / h if h else 0.0
    if ratio >= 1.5:
        layout = "wide/horizontal layout"
    elif ratio <= 0.67:
        layout = "tall/vertical layout"
    else:
        layout = "roughly square layout"
    L.append("- **Layout**: %s (aspect ratio %.2f)" % (layout, ratio))
    L.append("")

    with open(out_path, "w") as fh:
        fh.write("\n".join(L))
    print("Wrote %s (%d enemies, %d keys, %d triggers, %d secrets)" % (
        out_path, len(enemies), len(keys), len(d["triggers"]), len(secrets)))


if __name__ == "__main__":
    map_name = sys.argv[1].upper()
    dump = sys.argv[2] if len(sys.argv) > 2 else "/tmp/dump_%s.txt" % map_name
    out = sys.argv[3] if len(sys.argv) > 3 else "llm/%s.md" % map_name
    write_md(map_name, parse_dump(dump), out)
