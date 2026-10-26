#!/usr/bin/env python3
"""Validates a translation locale/tr/<lang>.csv (columns keys,<lang>) against locale/tr/source.csv:
missing or extra keys, placeholders ({x}, %s, %d, %.1f, \\n, [b]...) and the comma count in list strings.
Usage: python3 tools/check_translation.py <lang>"""
import csv, re, sys
LISTS = {"ui.enc.tabs", "ui.months", "ui.profile.tabs", "ui.weekdays"}
FREE = {"ui.date_format", "ui.date_month_year"}
lang = sys.argv[1]
src = {r[0]: r for r in list(csv.reader(open("locale/tr/source.csv", newline="")))[1:]}
rows = list(csv.reader(open(f"locale/tr/{lang}.csv", newline="")))
assert rows[0] == ["keys", lang], f"header must be keys,{lang}: {rows[0]}"
tr = {}
errs = []
for r in rows[1:]:
    if len(r) != 2:
        errs.append(f"row with {len(r)} columns: {r[:1]}")
        continue
    if r[0] in tr:
        errs.append(f"duplicate key: {r[0]}")
    tr[r[0]] = r[1]
pat = re.compile(r"\{[A-Za-z_0-9]+\}|%[sd]|%\.\d+f|\\n|\[/?[a-z]+\]")
for k, r in src.items():
    if k not in tr:
        errs.append(f"missing: {k}")
        continue
    if k not in FREE and sorted(set(pat.findall(r[2]))) != sorted(set(pat.findall(tr[k]))):
        errs.append(f"placeholder mismatch in {k}: {sorted(pat.findall(r[2]))} vs {sorted(pat.findall(tr[k]))}")
    if k in LISTS and r[2].count(",") != tr[k].count(","):
        errs.append(f"list {k} must have {r[2].count(',') + 1} comma-separated items")
    if r[2].strip() and not tr[k].strip():
        errs.append(f"empty: {k}")
for k in tr:
    if k not in src:
        errs.append(f"unknown key: {k}")
print("\n".join(errs[:80]))
print(f"{lang}: {len(tr)}/{len(src)} keys, {len(errs)} problems")
sys.exit(1 if errs else 0)
