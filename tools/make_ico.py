#!/usr/bin/env python3
"""Builds assets/icon.ico (the Windows .exe icon) from assets/icon.png, with PNG-compressed images at 16-256 px.
Resizing uses macOS `sips`. Run after `tools/make_icon.gd` changes the icon.
Usage: python3 tools/make_ico.py"""
import os, struct, subprocess, tempfile

SRC = "assets/icon.png"
OUT = "assets/icon.ico"
SIZES = [16, 24, 32, 48, 64, 128, 256]

images = []
with tempfile.TemporaryDirectory() as tmp:
    for s in SIZES:
        p = os.path.join(tmp, f"{s}.png")
        subprocess.run(["sips", "-z", str(s), str(s), SRC, "--out", p], check=True, capture_output=True)
        images.append((s, open(p, "rb").read()))

# ICO: header, one 16-byte directory entry per image, then the PNG data. Width/height 0 means 256.
data = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
for s, png in images:
    data += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(png), offset)
    offset += len(png)
for _, png in images:
    data += png
open(OUT, "wb").write(data)
print(f"{OUT}: {len(images)} sizes, {len(data)} bytes")
