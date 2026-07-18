#!/usr/bin/env python3
"""Insert a SleepForTargetsAction before the advance on NEC-gated stations.

For every station in wads/doom/levels/*.tscn whose conditions include a
NearbyEnemiesClearedCondition and whose endActions include an
AdvanceToNextStationAction, insert a blocking SleepForTargetsAction
(milliseconds = MS) immediately before the advance: after the encounter
clears, the player gets a beat to pick up whatever is on screen before the
rail rolls on - and no wait at all when nothing is visible.
"""
import glob
import re

from add_skirmish_stations import Block, parse_blocks, write_blocks, header_attr, ext_id

MS = 1000
SFT_PATH = "res://rail/resources/Actions/SleepForTargetsAction.gd"
SFT_UID = open("rail/resources/Actions/SleepForTargetsAction.gd.uid").read().strip()
NEC_PATH = "res://rail/resources/Conditions/NearbyEnemiesClearedCondition.gd"
ADV_PATH = "res://rail/resources/Actions/AdvanceToNextStationAction.gd"
ST_PATH = "res://rail/scenes/RailStation/RailStation.tscn"

for path in sorted(glob.glob("wads/doom/levels/*.tscn")):
    preamble, blocks = parse_blocks(open(path).read())
    exts = {}
    for b in blocks:
        if b.header.startswith("[ext_resource"):
            exts[header_attr(b.header, "path")] = ext_id(b.header)
    if NEC_PATH not in exts or ADV_PATH not in exts or ST_PATH not in exts:
        continue
    nec_ref = f'ExtResource("{exts[NEC_PATH]}")'
    adv_ref = f'ExtResource("{exts[ADV_PATH]}")'
    sft_id = exts.get(SFT_PATH, "99_sft")
    subres = {}
    for b in blocks:
        if b.header.startswith("[sub_resource"):
            subres[header_attr(b.header, "id")] = b

    new_subs = []
    count = 0
    for b in blocks:
        if not b.header.startswith("[node"):
            continue
        inst = re.search(r'instance=ExtResource\("([^"]*)"\)', b.header)
        if header_attr(b.header, "parent") != "Stations" or not inst \
                or inst.group(1) != exts[ST_PATH]:
            continue
        conds = b.get("conditions") or ""
        if not any(subres.get(rid) is not None and subres[rid].get("script") == nec_ref
                   for rid in re.findall(r'SubResource\("([^"]*)"\)', conds)):
            continue
        ea = b.get("endActions")
        if ea is None:
            continue
        adv_id = next((rid for rid in re.findall(r'SubResource\("([^"]*)"\)', ea)
                       if subres.get(rid) is not None and subres[rid].get("script") == adv_ref),
                      None)
        if adv_id is None:
            continue
        rid = f"Resource_sft_{count}"
        count += 1
        new_subs.append(Block(f'[sub_resource type="Resource" id="{rid}"]', [
            f'script = ExtResource("{sft_id}")',
            f"milliseconds = {MS}",
            f'metadata/_custom_type_script = "{SFT_UID}"',
        ]))
        b.set("endActions", ea.replace(f'SubResource("{adv_id}")',
                                       f'SubResource("{rid}"), SubResource("{adv_id}")', 1))

    if not count:
        continue
    if SFT_PATH not in exts:
        last_ext = max(i for i, b in enumerate(blocks) if b.header.startswith("[ext_resource"))
        blocks.insert(last_ext + 1, Block(
            f'[ext_resource type="Script" uid="{SFT_UID}" path="{SFT_PATH}" id="99_sft"]', []))
    first_node = next(i for i, b in enumerate(blocks) if b.header.startswith("[node"))
    blocks[first_node:first_node] = new_subs
    write_blocks(path, preamble, blocks)
    print(f"{path}: {count} sleeps inserted")
