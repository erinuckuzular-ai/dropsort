#!/bin/bash
# Package ~/Applications/Dropsort.app into dist/Dropsort.dmg
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Dropsort.app"
STAGE="$(mktemp -d)/Dropsort"
mkdir -p "$STAGE" "$DIR/dist"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DIR/dist/Dropsort.dmg"
hdiutil create -volname "Dropsort" -srcfolder "$STAGE" -ov -format UDZO "$DIR/dist/Dropsort.dmg"
echo "Built $DIR/dist/Dropsort.dmg"
