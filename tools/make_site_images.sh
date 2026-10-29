#!/usr/bin/env bash
# Images for the website (server/static/): the home page captures, resized to WebP from docs/screenshots/, and the
# link-preview image (tools/make_og_image.gd). Needs cwebp (brew install webp) and godot on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
for pair in "match-2d:shot-match" "squad:shot-squad" "hogwarts:shot-hogwarts"; do
  cwebp -quiet -q 80 -resize 960 0 "docs/screenshots/${pair%%:*}.png" -o "server/static/${pair##*:}.webp"
done
godot --headless --path . -s tools/make_og_image.gd
ls -l server/static/og.jpg server/static/shot-*.webp
