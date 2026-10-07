#!/usr/bin/env python3
"""
Extract Items, Professions, Monsters.
Generates lib/campaign_items.ml, lib/campaign_professions.ml, lib/campaign_monsters.ml
"""

import xml.etree.ElementTree as ET
from pathlib import Path
import sys

BASE = Path("game/Assets/Assets")

def parse_item(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    iid = root.get("id")
    text = root.find("Text")
    data = root.find("Data")
    shop = root.find("Shop")
    graphics = root.find("Graphics")
    restriction = root.find("Restriction")
    script = root.find("Script")
    lua_path = BASE / script.get("file").replace("\\", "/") if script is not None else None
    lua_source = lua_path.read_text(encoding="utf-8") if lua_path and lua_path.exists() else ""
    return {
        "id": iid,
        "name_text": text.get("name") if text is not None else "",
        "power_text": text.get("power") if text is not None else "",
        "location": data.get("location") if data is not None else "",
        "cost": int(shop.get("cost")) if shop is not None else 0,
        "rarity": int(shop.get("rarity")) if shop is not None else 0,
        "icon": int(graphics.get("icon")) if graphics is not None else 0,
        "restriction_type": restriction.get("type") if restriction is not None else "none",
        "lua_file": script.get("file") if script is not None else "",
        "lua_object": script.get("object") if script is not None else "",
        "lua_source": lua_source,
    }

def parse_profession(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    pid = root.get("id")
    text = root.find("Text")
    portraits = root.find("Portraits")
    skill = root.find("Skill")
    start = root.find("Start")
    campaign = root.find("Campaign")
    level = root.find("Level")
    sprite = root.find("Sprite")
    xp = root.find("XP")
    spells_elem = root.find("Spell")

    portraits_list = []
    if portraits is not None:
        for p in portraits.findall("Portrait"):
            portraits_list.append({
                "file": p.get("file"),
                "sex": int(p.get("sex")),
                "sprite": p.get("sprite"),
                "age": int(p.get("age")),
            })

    skills = {}
    if skill is not None:
        for attr in ["earth", "fire", "air", "water", "battle", "cunning", "morale"]:
            skills[attr] = int(skill.get(attr))

    starts = {}
    if start is not None:
        for attr in ["earth", "fire", "air", "water", "battle", "cunning", "morale", "gold"]:
            starts[attr] = int(start.get(attr))

    xp_table = {}
    if xp is not None:
        levels_list = []
        for k, v in xp.attrib.items():
            if k.startswith("level") and k != "leveladd":
                levels_list.append((int(k[5:]), int(v)))
            elif k == "leveladd":
                xp_table["leveladd"] = int(v)
        xp_table["levels"] = levels_list
        if "leveladd" not in xp_table:
            xp_table["leveladd"] = 5000

    spell_list = {}
    if spells_elem is not None:
        for k, v in spells_elem.attrib.items():
            if k.startswith("level") and v:
                spell_list[int(k[5:])] = v

    return {
        "id": pid,
        "name_text": text.get("name") if text is not None else "",
        "desc_text": text.get("description") if text is not None else "",
        "portraits": portraits_list,
        "skills": skills,
        "starts": starts,
        "start_city": campaign.get("city") if campaign is not None else "",
        "life_per_level": int(level.get("life")) if level is not None else 0,
        "sprite": sprite.get("id") if sprite is not None else "",
        "xp": xp_table,
        "spells_by_level": spell_list,
    }

def parse_monster(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    mid = root.get("id")
    text = root.find("Text")
    portrait = root.find("Portrait")
    level = root.find("Level")
    skill = root.find("Skill")
    add = root.find("Add")
    data = root.find("Data")
    reward = root.find("Reward")
    types = root.find("Types")
    mount = root.find("Mount")
    sprite = root.find("Sprite")
    spells = root.findall("Spell")
    capture = root.find("Capture")

    capture_grid = []
    if capture is not None:
        for row in capture.findall("Row"):
            capture_grid.append(row.get("data", ""))

    return {
        "id": mid,
        "name_text": text.get("name") if text is not None else "",
        "desc_text": text.get("description") if text is not None else "",
        "capture_text": text.get("capture") if text is not None else "",
        "portrait_file": portrait.get("file") if portrait is not None else "",
        "portrait_index": int(portrait.get("index")) if portrait is not None else 0,
        "portrait_number": int(portrait.get("number")) if portrait is not None else 1,
        "level_min": int(level.get("min")) if level is not None else 1,
        "level_max": int(level.get("max")) if level is not None else 3,
        "level_base": int(level.get("base")) if level is not None else 1,
        "level_to": int(level.get("levelto")) if level is not None else 16,
        "skills": {attr: int(skill.get(attr)) for attr in ["earth", "fire", "air", "water", "battle", "cunning", "morale"]} if skill is not None else {},
        "add": {attr: float(add.get(attr)) for attr in ["earth", "fire", "air", "water", "battle", "cunning", "morale", "life"]} if add is not None else {},
        "life": int(data.get("life")) if data is not None else 0,
        "mount": int(data.get("mount")) if data is not None else 0,
        "minxp": int(reward.get("minxp")) if reward is not None else 0,
        "maxxp": int(reward.get("maxxp")) if reward is not None else 0,
        "mingold": int(reward.get("mingold")) if reward is not None else 0,
        "maxgold": int(reward.get("maxgold")) if reward is not None else 0,
        "type1": types.get("type1") if types is not None else "",
        "type2": types.get("type2") if types is not None else "",
        "type3": types.get("type3") if types is not None else "",
        "type4": types.get("type4") if types is not None else "",
        "mount_speed": int(mount.get("speed")) if mount is not None else 0,
        "mount_fly": int(mount.get("fly")) if mount is not None else 0,
        "mount_spell": mount.get("spell") if mount is not None else "",
        "mount_addstat": int(mount.get("addstat")) if mount is not None else 0,
        "mount_stat": int(mount.get("stat")) if mount is not None else 0,
        "mount_addperlevel": int(mount.get("addperlevel")) if mount is not None else 0,
        "mount_addlevel": int(mount.get("addlevel")) if mount is not None else 0,
        "sprite": sprite.get("id") if sprite is not None else "",
        "spells": [sp.get("tag") for sp in spells],
        "spell_learn": [int(sp.get("learn")) for sp in spells],
        "capture_grid": capture_grid,
    }

def write_module(name, records, fields, lookups, output_path):
    lines = [f"(* Generated by tools/extract_{name}.py -- do not edit *)", ""]
    # Only open Campaign_types for modules that use the shared types
    if name in ("profession", "monster"):
        lines.append("open Campaign_types")
        lines.append("")
    lines.append(f"type {name} = {{")
    for f, t in fields:
        lines.append(f"  {f}: {t};")
    lines.append("}")
    lines.append("")

    lines.append(f"let {name}s = [")
    for r in records:
        lines.append("  {")
        for f, _ in fields:
            v = r[f]
            if isinstance(v, str):
                esc = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
                lines.append(f'    {f} = "{esc}";')
            elif isinstance(v, bool):
                lines.append(f'    {f} = {str(v).lower()};')
            elif isinstance(v, int):
                lines.append(f'    {f} = {v};')
            elif isinstance(v, float):
                lines.append(f'    {f} = {v};')
            elif isinstance(v, list):
                if v and isinstance(v[0], dict):
                    lines.append(f"    {f} = [")
                    for item in v:
                        lines.append("      {")
                        for k, val in item.items():
                            if isinstance(val, str):
                                esc = val.replace("\\", "\\\\").replace('"', '\\"')
                                lines.append(f'        {k} = "{esc}";')
                            elif isinstance(val, (int, float)):
                                lines.append(f"        {k} = {val};")
                            elif isinstance(val, bool):
                                lines.append(f"        {k} = {str(val).lower()};")
                        lines.append("      };")
                    lines.append("    ];")
                elif v and isinstance(v[0], (int, float)):
                    items = "; ".join([str(x) for x in v])
                    lines.append(f"    {f} = [{items}];")
                else:
                    items = "; ".join([f'"{x.replace("\\", "\\\\").replace(chr(34), chr(92)+chr(34))}"' for x in v])
                    lines.append(f"    {f} = [{items}];")
            elif isinstance(v, dict):
                # Record types: generate { field = value; ... } syntax
                record_fields = ["skills", "starts", "add", "xp", "spells_by_level"]
                if f in record_fields:
                    if f == "xp":
                        # xp_table has leveladd and levels list
                        items = []
                        for k, val in v.items():
                            if k == "leveladd":
                                items.append(f"leveladd = {val}")
                            elif k == "levels":
                                # levels is a list of (int * int)
                                levels_str = "[ " + "; ".join([f"({lvl}, {xp})" for lvl, xp in val]) + " ]"
                                items.append(f"levels = {levels_str}")
                        lines.append(f"    {f} = {{ {'; '.join(items)} }};")
                    elif f == "spells_by_level":
                        # spell_table is (int * string) list
                        spells_str = "[ " + "; ".join([f"({lvl}, \"{spell}\")" for lvl, spell in v.items()]) + " ]"
                        lines.append(f"    {f} = {spells_str};")
                    else:
                        items = "; ".join([f"{k} = {val}" for k, val in v.items()])
                        lines.append(f"    {f} = {{ {items} }};")
                else:
                    items = "; ".join([f'({k}, {v})' for k, v in v.items()])
                    lines.append(f"    {f} = [{items}];")
        lines.append("  };")
    lines.append("]")
    lines.append("")

    for lookup in lookups:
        lines.append(lookup)
    lines.append("")

    Path(output_path).write_text("\n".join(lines))
    print(f"Wrote {output_path}")

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    # Items
    items = []
    for xml in sorted((BASE / "Items").glob("I*.xml")):
        items.append(parse_item(xml))

    # Professions
    profs = []
    for xml in sorted((BASE / "Professions").glob("P*.xml")):
        profs.append(parse_profession(xml))

    # Monsters
    monsters = []
    for xml in sorted((BASE / "Monsters").glob("M*.xml")):
        monsters.append(parse_monster(xml))

    if args.check:
        print(f"Items: {len(items)}")
        print(f"Professions: {len(profs)}")
        print(f"Monsters: {len(monsters)}")
        return

    # Items
    item_fields = [
        ("id", "string"), ("name_text", "string"), ("power_text", "string"),
        ("location", "string"), ("cost", "int"), ("rarity", "int"),
        ("icon", "int"), ("restriction_type", "string"),
        ("lua_file", "string"), ("lua_object", "string"), ("lua_source", "string"),
    ]
    write_module("item", items, item_fields, [
        "let item_by_id id = List.find (fun i -> i.id = id) items",
        "let items_by_location loc = List.filter (fun i -> i.location = loc) items",
    ], "lib/campaign_items.ml")

    # Professions
    prof_fields = [
        ("id", "string"), ("name_text", "string"), ("desc_text", "string"),
        ("portraits", "portrait list"), ("skills", "skill_affinities"),
        ("starts", "start_stats"), ("start_city", "string"),
        ("life_per_level", "int"), ("sprite", "string"),
        ("xp", "xp_table"), ("spells_by_level", "spell_table"),
    ]
    write_module("profession", profs, prof_fields, [
        "let profession_by_id id = List.find (fun p -> p.id = id) professions",
    ], "lib/campaign_professions.ml")

    # Monsters
    monster_fields = [
        ("id", "string"), ("name_text", "string"), ("desc_text", "string"),
        ("capture_text", "string"), ("portrait_file", "string"),
        ("portrait_index", "int"), ("portrait_number", "int"),
        ("level_min", "int"), ("level_max", "int"), ("level_base", "int"),
        ("level_to", "int"), ("skills", "skill_affinities"), ("add", "skill_adds"),
        ("life", "int"), ("mount", "int"), ("minxp", "int"), ("maxxp", "int"),
        ("mingold", "int"), ("maxgold", "int"),
        ("type1", "string"), ("type2", "string"), ("type3", "string"), ("type4", "string"),
        ("mount_speed", "int"), ("mount_fly", "int"), ("mount_spell", "string"),
        ("mount_addstat", "int"), ("mount_stat", "int"),
        ("mount_addperlevel", "int"), ("mount_addlevel", "int"),
        ("sprite", "string"), ("spells", "string list"), ("spell_learn", "int list"),
        ("capture_grid", "string list"),
    ]
    write_module("monster", monsters, monster_fields, [
        "let monster_by_id id = List.find (fun m -> m.id = id) monsters",
        "let monster_by_sprite spr = List.find (fun m -> m.sprite = spr) monsters",
    ], "lib/campaign_monsters.ml")

    # Shared type aliases
    shared = []
    shared.append("type portrait = { file: string; sex: int; sprite: string; age: int }")
    shared.append("type skill_affinities = { earth: int; fire: int; air: int; water: int; battle: int; cunning: int; morale: int }")
    shared.append("type start_stats = { earth: int; fire: int; air: int; water: int; battle: int; cunning: int; morale: int; gold: int }")
    shared.append("type skill_adds = { earth: float; fire: float; air: float; water: float; battle: float; cunning: float; morale: float; life: float }")
    shared.append("type xp_table = { leveladd: int; levels: (int * int) list }  (* level -> xp *)")
    shared.append("type spell_table = (int * string) list  (* level -> spell_id *)")
    Path("lib/campaign_types.ml").write_text("\n".join(shared) + "\n")
    print("Wrote lib/campaign_types.ml")

if __name__ == "__main__":
    main()