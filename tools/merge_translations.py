#!/usr/bin/env python3
"""Merges locale/strings.csv (keys,es,en) with the translations in locale/tr/<lang>.csv (keys,<lang>) into a single
CSV for Godot; a key missing in a language falls back to the English text. Also regenerates the es/en reference
locale/tr/source.csv from strings.csv (so check_translation.py never compares against stale text) and updates the
translations list in project.godot.

Every cell that the merge would change in strings.csv is listed, so a stale locale/tr file cannot silently revert a
string that was changed only in strings.csv (change existing strings with tools/add_keys.py, which writes both).
Usage: python3 tools/merge_translations.py [--check]
  --check  write nothing; exit with status 1 if strings.csv or source.csv are out of sync with locale/tr."""
import csv, io, os, re, sys

LANGS = ["de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]
CHECK = "--check" in sys.argv[1:]


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.reader(f))


def to_text(rows):
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    return buf.getvalue()


def read_text(path):
    with open(path, newline="", encoding="utf-8") as f:
        return f.read()


def write_text(path, text):
    with open(path, "w", newline="", encoding="utf-8") as f:
        f.write(text)


rows = read_csv("locale/strings.csv")
hdr = rows[0]
base = {"keys": 0, "es": hdr.index("es"), "en": hdr.index("en")}
out_hdr = ["keys", "es", "en"]
tr = {}
for lang in LANGS:
    f = f"locale/tr/{lang}.csv"
    if os.path.exists(f):
        tr[lang] = {r[0]: r[1] for r in read_csv(f)[1:] if len(r) == 2}
        out_hdr.append(lang)
out = [out_hdr]
missing = {l: 0 for l in tr}
changed = []
for r in rows[1:]:
    line = [r[0], r[base["es"]], r[base["en"]]]
    for lang in out_hdr[3:]:
        v = tr[lang].get(r[0], "")
        if not v.strip():
            v = r[base["en"]]
            missing[lang] += 1
        old = r[hdr.index(lang)] if lang in hdr and hdr.index(lang) < len(r) else None
        if old is not None and old != v:
            changed.append((r[0], lang, old, v))
        line.append(v)
    out.append(line)
merged = to_text(out)
source = to_text([["keys", "es", "en"]] + [[r[0], r[base["es"]], r[base["en"]]] for r in rows[1:]])
merged_stale = merged != read_text("locale/strings.csv")
source_stale = not os.path.exists("locale/tr/source.csv") or source != read_text("locale/tr/source.csv")

for key, lang, old, new in changed:
    print(f"changed {key} [{lang}]: {old!r} -> {new!r}")
if CHECK:
    if source_stale:
        print("locale/tr/source.csv differs from the es/en columns of locale/strings.csv")
    if merged_stale or source_stale:
        print("out of sync: run python3 tools/merge_translations.py (or tools/add_keys.py for changed strings)")
        sys.exit(1)
    print("in sync")
    sys.exit(0)

write_text("locale/strings.csv", merged)
write_text("locale/tr/source.csv", source)
p = read_text("project.godot")
lst = ", ".join('"res://locale/strings.%s.translation"' % l for l in out_hdr[1:])
p = re.sub(r'locale/translations=PackedStringArray\([^)]*\)', 'locale/translations=PackedStringArray(%s)' % lst, p)
write_text("project.godot", p)
print("languages:", out_hdr[1:], "untranslated keys (English fallback):", missing, "changed cells:", len(changed))
