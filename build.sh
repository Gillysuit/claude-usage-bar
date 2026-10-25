#!/bin/zsh
# Builds ClaudeUsage.app into ./build. Run ./build.sh --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "${0:A:h}"

APP=build/ClaudeUsage.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/ClaudeUsage" Sources/*.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.gil.claude-usage-bar</string>
  <key>CFBundleName</key><string>ClaudeUsage</string>
  <key>CFBundleExecutable</key><string>ClaudeUsage</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force -s - "$APP"
echo "built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x ClaudeUsage || true
  while pgrep -x ClaudeUsage >/dev/null; do sleep 0.2; done
  mkdir -p ~/Applications
  rm -rf ~/Applications/ClaudeUsage.app
  cp -R "$APP" ~/Applications/
  open ~/Applications/ClaudeUsage.app
  echo "installed ~/Applications/ClaudeUsage.app"
fi
