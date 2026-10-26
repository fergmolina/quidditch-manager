#!/bin/bash
# Builds export/QuidditchManager.dmg in the usual macOS layout: the app, an Applications shortcut to drag it onto,
# a background with an arrow and the window pre-arranged. Usage: bash tools/make_dmg.sh   (from the project folder)
set -e
cd "$(dirname "$0")/.."
APP_NAME="Quidditch Manager"
VOL="Quidditch Manager"
STAGE="export/dmg_stage"
RW="export/tmp_rw.dmg"
OUT="export/QuidditchManager.dmg"

# 1. The app (Godot export as .app) and the background.
rm -rf "export/mac/$APP_NAME.app"
mkdir -p export/mac
godot --headless --path . --export-release "macOS" "export/mac/$APP_NAME.app" >/dev/null 2>&1
godot --path . -s tools/make_dmg_bg.gd >/dev/null 2>&1

# 2. Staging folder: app + /Applications shortcut + hidden background.
rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background"
cp -R "export/mac/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp export/dmg_background.png "$STAGE/.background/background.png"

# 3. Read/write image so Finder can arrange the window.
# Detach any volume with the same name (a previously opened DMG would make this one mount as
# "Quidditch Manager 1" and Finder would arrange the wrong one).
for v in /Volumes/"$VOL"*; do
  [ -d "$v" ] && hdiutil detach "$v" -force >/dev/null 2>&1 || true
done
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
ATTACH=$(hdiutil attach -readwrite -noverify -noautoopen "$RW")
DEV=$(echo "$ATTACH" | grep -E '^/dev/' | head -1 | awk '{print $1}')
MOUNT=$(echo "$ATTACH" | grep -o '/Volumes/.*' | head -1)
DISK_NAME=$(basename "$MOUNT")
sleep 2
osascript <<EOS || { echo "ERROR: could not arrange the window with Finder"; hdiutil detach "$DEV" -force >/dev/null; exit 1; }
tell application "Finder"
  tell disk "$DISK_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {170, 200}
    set position of item "Applications" of container window to {490, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOS
sync
if [ ! -f "$MOUNT/.DS_Store" ]; then
  echo "ERROR: Finder did not save the window layout (.DS_Store)"; hdiutil detach "$DEV" -force >/dev/null; exit 1
fi
hdiutil detach "$DEV" >/dev/null || hdiutil detach -force "$DEV" >/dev/null

# 4. Compressed and read-only.
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -rf "$RW" "$STAGE"
ls -la "$OUT"
