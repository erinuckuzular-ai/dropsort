#!/bin/bash
# Package ~/Applications/Dropsort.app into a polished dist/Dropsort.dmg
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Dropsort.app"
VOL="Dropsort"
WORK="$(mktemp -d)"
TMP="$WORK/rw.dmg"
MNT="/Volumes/$VOL"
mkdir -p "$DIR/dist"

# detach any stale Dropsort volume (visible mount must be unique for Finder)
[ -d "$MNT" ] && hdiutil detach "$MNT" -force 2>/dev/null || true

hdiutil create -size 40m -volname "$VOL" -fs HFS+ -o "$TMP" >/dev/null
hdiutil attach "$TMP" -noautoopen >/dev/null

cp -R "$APP" "$MNT/"
ln -s /Applications "$MNT/Applications"
mkdir "$MNT/.background"
cp "$DIR/Resources/dmg-background.png" "$MNT/.background/bg.png"
cp "$DIR/Resources/Dropsort.icns" "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT" 2>/dev/null || true

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 140, 960, 580}
    set vo to the icon view options of container window
    set arrangement of vo to not arranged
    set icon size of vo to 120
    set text size of vo to 13
    set background picture of vo to file ".background:bg.png"
    set position of item "Dropsort.app" of container window to {165, 232}
    set position of item "Applications" of container window to {495, 232}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync; sleep 1
hdiutil detach "$MNT" -force >/dev/null
rm -f "$DIR/dist/Dropsort.dmg"
hdiutil convert "$TMP" -format UDZO -imagekey zlib-level=9 -o "$DIR/dist/Dropsort.dmg" >/dev/null
rm -rf "$WORK"
echo "Built $DIR/dist/Dropsort.dmg"
