#!/usr/bin/env python3
"""Adds new keys in all 10 languages to locale/strings.csv, locale/tr/<lang>.csv and locale/tr/source.csv.
Usage: python3 tools/add_keys.py <file.json>   ({key: [es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN]})"""
import csv, json, sys
L = ["es", "en", "de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]
NEW = json.load(open(sys.argv[1]))
for k, v in NEW.items():
    assert len(v) == len(L), k


def upsert(path, header, make):
    rows = list(csv.reader(open(path, newline="")))
    idx = {r[0]: i for i, r in enumerate(rows)}
    for k, v in NEW.items():
        line = make(k, v)
        if k in idx:
            rows[idx[k]] = line
        else:
            rows.append(line)
    csv.writer(open(path, "w", newline=""), lineterminator="\n").writerows(rows)


hdr = next(csv.reader(open("locale/strings.csv", newline="")))
assert hdr[1:] == L, hdr
upsert("locale/strings.csv", hdr, lambda k, v: [k] + v)
for i, l in enumerate(L[2:], 2):
    upsert(f"locale/tr/{l}.csv", None, lambda k, v, i=i: [k, v[i]])
upsert("locale/tr/source.csv", None, lambda k, v: [k, v[0], v[1]])
print(len(NEW), "keys")
