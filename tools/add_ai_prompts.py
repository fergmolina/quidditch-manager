#!/usr/bin/env python3
"""Adds to docs/art/crests and docs/art/portraits (prompts.md + batches.json) the clubs and school houses that have no
batch yet, without touching existing batches (sheets already saved stay valid). Crests in batches of 4, portraits of 2.
Sheets are saved outside the repository, in ../Quidditch Manager - work/sheets/<crests|portraits>/<batch>.png.
Usage: python3 tools/add_ai_prompts.py"""
import glob, json, re

PACK = "data/packs/1993-94"
SHEETS = "../Quidditch Manager - work/sheets"
NAMES = [("#000000", "black"), ("#212121", "near-black"), ("#FFFFFF", "white"), ("#F5F5F5", "off-white"), ("#ECEFF1", "pale grey-white"),
         ("#B0BEC5", "silver grey"), ("#BDBDBD", "grey"), ("#455A64", "slate grey"), ("#37474F", "dark slate"), ("#B71C1C", "deep red"),
         ("#C62828", "red"), ("#E53935", "bright red"), ("#8E1B1B", "maroon"), ("#7B1F1F", "garnet"), ("#C60C30", "red"), ("#D52B1E", "red"),
         ("#E91E63", "pink"), ("#4A148C", "deep purple"), ("#6A1B9A", "purple"), ("#0D47A1", "royal blue"), ("#1565C0", "blue"),
         ("#1A237E", "navy"), ("#283593", "indigo"), ("#003478", "navy"), ("#0277BD", "ocean blue"), ("#1E88E5", "sky blue"),
         ("#4FC3F7", "light blue"), ("#B3E5FC", "ice blue"), ("#00838F", "dark teal"), ("#00695C", "deep teal"), ("#1B5E20", "forest green"),
         ("#2E7D32", "green"), ("#33691E", "olive green"), ("#FDD835", "yellow"), ("#FFEB3B", "yellow"), ("#FFC107", "amber"),
         ("#FFD54F", "pale gold"), ("#D4AF37", "old gold"), ("#FFB300", "amber gold"), ("#F4B400", "golden yellow"), ("#FF8F00", "orange"),
         ("#F36C21", "orange"), ("#3E2723", "dark brown"), ("#4E342E", "dark brown"), ("#795548", "brown")]
POS = [("Chaser", "holding a red quaffle under one arm"), ("Beater", "resting a wooden beater's bat on the shoulder"),
       ("Seeker", "with flying goggles pushed up on the forehead, reaching up as if for the snitch"), ("Keeper", "wearing big padded keeper's gloves, arms crossed")]
BUILD = ["tall and gangly", "short and stocky", "wiry", "broad-shouldered", "lanky", "sturdy and round-faced"]
AGE = ["young (about 20)", "in their late twenties", "a seasoned veteran in their thirties", "about 25"]
TRAIT = {"aggressive": "Fierce, combative expression.", "clever": "Sly, knowing smile.", "showmanship": "Showing off, theatrical pose.",
         "flair": "Cocky, stylish pose.", "balanced": "Calm, confident stance.", "resilient": "Determined, gritty look.",
         "flamboyant": "Theatrical pose.", "defensive": "Wary, guarded stance.", "attacking": "Leaning forward, eager to attack.", "speed": "Restless, ready to sprint."}


def cname(h):
    h = h.upper()
    r, g, b = int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
    return min(NAMES, key=lambda kv: (int(kv[0][1:3], 16) - r) ** 2 + (int(kv[0][3:5], 16) - g) ** 2 + (int(kv[0][5:7], 16) - b) ** 2)[1]


def col(h):
    return f"{cname(h)} ({h})"


def section_style(md, marker):
    m = re.search(r"```\n(" + re.escape(marker) + r".*?)\n\n", md, re.S)
    return m.group(1)


CREST_STYLE = ("Use the attached image ONLY as a style reference: copy exactly its look — vintage embroidered cloth patches, twill fabric "
               "background, thick raised cream/gold satin-stitched border with slightly frayed edges, emblem embroidered with visible stitch "
               "direction, muted slightly faded colours. Do NOT reuse its emblems. Draw exactly these 4 new patches, each with the emblem and "
               "colours described, arranged in a 2×2 grid (left to right, top to bottom), same size, well separated, on a plain flat light grey "
               "background. No text, letters or numbers on the patches. They are the four house crests of one school: use the same heater-shield "
               "shape for all four so they read as a matching set.")

PORTRAIT_STYLE = ("I attached reference illustrations: use them ONLY as a style reference. Copy their look exactly: pencil drawing with a "
                  "soft watercolour wash, loose sketchy linework, slightly elongated quirky proportions, expressive gently caricatured faces, "
                  "muted slightly faded colours, skin tones lightly shaded in watercolour, lots of empty space around the figure. Draw 2 "
                  "full-body Quidditch players standing side by side (LEFT is the first, RIGHT is the second), each holding a broomstick, on a "
                  "plain flat light grey background, with plenty of space between them and around the edges. Keep the caricature gentle, "
                  "whimsical and respectful: exaggerate pose, posture and personality, never ethnic features. No text, no letters, no numbers, "
                  "no logos other than the small chest badge described. Wide landscape image.")


def add_houses(kind, batches, md, style):
    """School houses (data/packs/<pack>/schools/*.json with house_info) that have no crest/portrait yet:
    crests in fours (one batch per school, hs_<school>_1) and portraits in twos (hs_<school>_1 and _2)."""
    schools = {d["id"]: d for d in json.load(open("data/shared/schools.json"))["schools"]}
    have = {i for v in batches.values() for i in v}
    if kind == "portraits":
        have |= {f.split("/")[-1][:-4] for f in glob.glob("assets/portraits/hs_*.png")}
    else:
        have |= {f.split("/")[-1][:-4] for f in glob.glob("assets/crests/ai/hs_*.png")}
    per = 4 if kind == "crests" else 2
    for f in sorted(glob.glob(f"{PACK}/schools/*.json")):
        d = json.load(open(f))
        sid = d["school_id"]
        sc = schools.get(sid, {})
        info = d.get("house_info", {})
        houses = [h for h in sc.get("houses", []) if h in info and f"hs_{sid[7:]}_{h.lower().replace(' ', '_')}" not in have]
        if not houses:
            continue
        short = sc.get("short_name", sid)
        lines = [f"## Houses of {short}", ""]
        for b in range(0, len(houses), per):
            chunk = houses[b:b + per]
            key = f"hs_{sid[7:]}_{b // per + 1}"
            while key in batches:
                key = key.rsplit("_", 1)[0] + "_" + str(int(key.rsplit("_", 1)[1]) + 1)
            batches[key] = [f"hs_{sid[7:]}_{h.lower().replace(' ', '_')}" for h in chunk]
            lines += [f"### Batch {b // per + 1} — save as `{SHEETS}/{kind}/{key}.png`", "", "```"]
            if kind == "crests":
                lines += [CREST_STYLE, ""]
                for j, h in enumerate(chunk, 1):
                    c = d["house_colors"][h]
                    lines.append(f"{j}. House {h} of {short}: {col(c['primary'])} background, {col(c['secondary'])} details; emblem: {info[h]['emblem_desc']}.")
            else:
                lines += [style, ""]
                for j, h in enumerate(chunk):
                    c = d["house_colors"][h]
                    k = b + j + sum(map(ord, sid))
                    pos, prop = POS[k % 4]
                    g = "witch" if k % 2 == 0 else "wizard"
                    lines.append(f"{'LEFT: ' if j == 0 else 'RIGHT: '}{h} house ({short}): a teenage {g} student (about 15), {BUILD[k % 6]}, playing {pos}, {prop}. "
                                 f"School Quidditch robes in {col(c['primary'])} with {col(c['secondary'])} trim, short cape, shin guards, boots; "
                                 f"a small embroidered house badge on the chest showing {info[h]['emblem_desc']}.")
            lines += ["```", ""]
        md = md.rstrip() + "\n\n" + "\n".join(lines)
        print(f"{kind}: houses of {short} +{len(houses)}")
    return md


def main():
    clubs = {json.load(open(f))["id"]: json.load(open(f)) for f in glob.glob(f"{PACK}/clubs/*.json")}
    comps = [json.load(open(f)) for f in sorted(glob.glob(f"{PACK}/competitions/*.json"))]
    for kind, per, marker in [("crests", 4, "Use the attached image ONLY"), ("portraits", 2, "I attached reference illustrations")]:
        tf = f"docs/art/{kind}/batches.json"
        md_f = f"docs/art/{kind}/prompts.md"
        batches = json.load(open(tf))
        md = open(md_f).read()
        style = section_style(md, marker) if marker in md else (CREST_STYLE if kind == "crests" else PORTRAIT_STYLE)
        have = {i for v in batches.values() for i in v}
        if kind == "portraits":
            have |= {f.split("/")[-1][:-4] for f in glob.glob("assets/portraits/*.png")}
        else:
            have |= {f.split("/")[-1][:-4] for f in glob.glob("assets/crests/ai/*.png")}
        add = []
        for c in comps:
            missing = [i for i in c["club_ids"] if i not in have]
            if not missing:
                continue
            n0 = 1 + max([int(k.rsplit("_", 1)[1]) for k in batches if k.startswith(c["id"] + "_")] or [0])
            lines = [f"## {c['name']}", ""]
            for b in range(0, len(missing), per):
                chunk = missing[b:b + per]
                key = f"{c['id']}_{n0 + b // per}"
                batches[key] = chunk
                lines += [f"### Batch {n0 + b // per} — save as `{SHEETS}/{kind}/{key}.png`", "", "```"]
                if kind == "crests":
                    st = style.replace("these 4 new", f"these {len(chunk)} new")
                    if len(chunk) < 4:
                        st = st.replace("2×2 grid", f"row of {len(chunk)}")
                    lines += [st, ""]
                    for j, i in enumerate(chunk, 1):
                        d = clubs[i]
                        lines.append(f"{j}. {d['name']}: {col(d['colors']['primary'])} background, {col(d['colors']['secondary'])} details; emblem: {d.get('emblem_desc', '')}.")
                else:
                    st = style
                    if len(chunk) == 1:
                        st = st.replace("Draw 2 full-body Quidditch players standing side by side (LEFT is the first, RIGHT is the second)", "Draw 1 full-body Quidditch player standing").replace("between them and around", "around").replace("Wide landscape image.", "Square image.")
                    lines += [st, ""]
                    for j, i in enumerate(chunk):
                        d = clubs[i]
                        k = len(have) + len(add) + j
                        pos, prop = POS[k % 4]
                        tag = (d.get("identity", {}).get("style_tags") or [""])[0]
                        label = ("LEFT: " if j == 0 else "RIGHT: ") if len(chunk) > 1 else ""
                        lines.append(f"{label}{d['name']} ({d['city']}): a {'witch' if k % 2 == 0 else 'wizard'}, {AGE[k % 4]}, {BUILD[k % 6]}, playing {pos}, {prop}. "
                                     f"Robes: tunic in {col(d['colors']['primary'])} with {col(d['colors']['secondary'])} trim and belt, short cape, leather shin guards and boots; "
                                     f"a small embroidered badge on the chest showing {d.get('emblem_desc', 'its emblem')}. {TRAIT.get(tag, '')}".rstrip())
                    add += chunk
                lines += ["```", ""]
            have |= set(missing)
            md = md.rstrip() + "\n\n" + "\n".join(lines)
            print(f"{kind}: {c['id']} +{len(missing)}")
        md = add_houses(kind, batches, md, style)
        open(md_f, "w").write(md.rstrip() + "\n")
        json.dump(batches, open(tf, "w"), indent=1)


if __name__ == "__main__":
    main()
