#!/usr/bin/env python3
"""Removes from docs/art/<crests|portraits|brooms>/prompts.md the batches whose sheet is already saved in the work
folder (the sheets stay there: they are needed to import again). League headings are kept only if a batch is left.
Usage: python3 tools/clean_prompts.py [crests|portraits|brooms] [sheets=<dir>]
Default sheets folder: ../Quidditch Manager - work/sheets/<kind>/"""
import os, re, sys
args = sys.argv[1:]
kind = next((a for a in args if a in ("crests", "portraits", "brooms")), "crests")
root = next((a[7:] for a in args if a.startswith("sheets=")), os.path.join("..", "Quidditch Manager - work", "sheets"))
sheets = os.path.join(root, kind)
md_f = f"docs/art/{kind}/prompts.md"
done = {f.rsplit(".", 1)[0] for f in os.listdir(sheets)} if os.path.isdir(sheets) else set()
s = open(md_f).read()
parts = re.split(r"(?m)^(?=### Batch |## |---$)", s)
out = []
removed = 0
for p in parts:
    m = re.match(r"### Batch .*?([^/`]+?)\.png", p)
    if m and m.group(1) in done:
        removed += 1
        continue
    out.append(p)
res = []
for i, p in enumerate(out):
    if p.startswith("## ") and not p.startswith("## How") and (i + 1 >= len(out) or not out[i + 1].startswith("### Batch")) and "|" not in p and "```" not in p:
        continue
    res.append(p)
open(md_f, "w").write("".join(res))
left = len(re.findall(r"(?m)^### Batch ", "".join(res)))
print(f"{kind}: removed {removed} finished batches, {left} left")
