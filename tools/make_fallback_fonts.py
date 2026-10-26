#!/usr/bin/env python3
"""Builds the bundled fallback fonts in assets/fonts/fallback/ (Noto, SIL OFL 1.1).

The browser build has no system fonts to fall back on, so every character the game fonts lack must ship with
the game: symbols (★ ● ◂ ▸ ⏸ …) and the Japanese and Chinese characters. The CJK fonts are cut down to the
characters the game uses (locale/strings.csv, data/, src/) plus the common sets (JIS level 1 kanji, GB2312
level 1 hanzi), so new translations rarely need a rebuild. Run again after adding text in new characters;
tests/run_tests.gd fails when a translated string uses a character no bundled font has.

Needs fontTools (pip install fonttools). The Noto originals are downloaded once into ~/.cache/qm-noto.
Usage: python3 tools/make_fallback_fonts.py"""
import csv, glob, os, re, urllib.request
from fontTools import subset
from fontTools.ttLib import TTFont

CACHE = os.path.expanduser("~/.cache/qm-noto")
OUT = "assets/fonts/fallback"
NOTO = "https://github.com/notofonts/"
SOURCES = {
    "NotoSansSymbols2-Regular.ttf": NOTO + "notofonts.github.io/raw/main/fonts/NotoSansSymbols2/unhinted/ttf/NotoSansSymbols2-Regular.ttf",
    "NotoSansJP-Regular.otf": NOTO + "noto-cjk/raw/main/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf",
    "NotoSansSC-Regular.otf": NOTO + "noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
}


def source(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        print("downloading", name)
        urllib.request.urlretrieve(SOURCES[name], path)
    return path


def used_chars():
    chars = set()
    for p in glob.glob("src/**/*.gd", recursive=True):
        for s in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', open(p, encoding="utf-8").read()):
            chars |= set(s)
    for row in csv.reader(open("locale/strings.csv", encoding="utf-8")):
        for v in row[1:]:
            chars |= set(v)
    for p in glob.glob("data/**/*.json", recursive=True):
        chars |= set(open(p, encoding="utf-8").read())
    return {c for c in chars if ord(c) > 127}


def double_byte_set(encoding, rows, cols=range(0xA1, 0xFF)):
    out = set()
    for r in rows:
        for c in cols:
            try:
                out |= set(bytes([r, c]).decode(encoding))
            except UnicodeDecodeError:
                pass
    return out


def build(src_name, out_name, chars):
    font = TTFont(source(src_name))
    cmap = font.getBestCmap()
    keep = sorted(ord(c) for c in chars if ord(c) in cmap)
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=keep)
    sub.subset(font)
    font.flavor = None
    path = os.path.join(OUT, out_name)
    font.save(path)
    print(f"{path}: {len(keep)} characters, {os.path.getsize(path)} bytes")


os.makedirs(OUT, exist_ok=True)
# Basic Latin and the no-break spaces too: when Godot shapes a run with a fallback font, a space or digit missing
# from that font is drawn with zero width ("Sun1 August1993").
used = used_chars() | {chr(c) for c in range(0x20, 0x7F)} | {"\u00a0", "\u202f"}
punct = {chr(c) for c in range(0x3000, 0x3040)} | {chr(c) for c in range(0xFF00, 0xFFF0)}
kana = {chr(c) for c in range(0x3040, 0x3100)}
geometric = {chr(c) for c in list(range(0x2190, 0x21FF)) + list(range(0x2295, 0x229A)) + list(range(0x23E9, 0x23FB))
             + list(range(0x25A0, 0x2600)) + list(range(0x2600, 0x2700)) + list(range(0x2700, 0x27C0)) + [0x24D8]}
build("NotoSansSymbols2-Regular.ttf", "NotoSansSymbols2-Subset.ttf", used | geometric)
# JIS X 0208 level 1 kanji (EUC-JP rows 0xB0-0xCF) and GB2312 level 1 hanzi (rows 0xB0-0xD7).
build("NotoSansJP-Regular.otf", "NotoSansJP-Subset.otf", used | punct | kana | geometric | double_byte_set("euc_jp", range(0xB0, 0xD0)))
build("NotoSansSC-Regular.otf", "NotoSansSC-Subset.otf", used | punct | geometric | double_byte_set("gb2312", range(0xB0, 0xD8)))
