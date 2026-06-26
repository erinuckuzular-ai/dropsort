#!/bin/bash
# Build Dropsort.app, install to ~/Applications, and set up the login agent.
set -e
APP="$HOME/Applications/Dropsort.app"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Compiling…"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O "$DIR/Sources/main.swift" "$DIR/Sources/Settings.swift" -o "$APP/Contents/MacOS/Dropsort"
cp "$DIR/Resources/Info.plist"   "$APP/Contents/Info.plist"
cp "$DIR/Resources/Dropsort.icns" "$APP/Contents/Resources/Dropsort.icns"
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Installing login agent…"
PLIST="$HOME/Library/LaunchAgents/com.dropsort.agent.plist"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.dropsort.agent</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/Dropsort</string></array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict></plist>
PL
launchctl bootout gui/$(id -u)/com.dropsort.agent 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

echo "Done. Dropsort is in your menu bar. Grant it Full Disk Access when asked."
