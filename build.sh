#!/bin/zsh
# Builds a universal ClaudeUsage.app and its release zip.
# With --install, also puts it in /Applications and starts it.
set -euo pipefail
cd "${0:A:h}"
APP=build/ClaudeUsage.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target $arch-apple-macos13.0 \
    Sources/App.swift Sources/Shared/*.swift -o build/ClaudeUsage-$arch
done
lipo -create build/ClaudeUsage-* -output "$APP/Contents/MacOS/ClaudeUsage"

# App icon, generated once and kept in Resources/
if [[ ! -f Resources/AppIcon.icns ]]; then
  swiftc tools/make-icon.swift -o build/make-icon
  ./build/make-icon build/icon.png
  ICONSET=build/AppIcon.iconset
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# The mod, as a marketplace folder the app installs on request
MARKET="$APP/Contents/Resources/marketplace"
mkdir -p "$MARKET/.claude-plugin" "$MARKET/mod"
cp .claude-plugin/marketplace.json "$MARKET/.claude-plugin/"
cp -R mod/usage "$MARKET/mod/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>app.claudeusage</string>
  <key>CFBundleName</key><string>ClaudeUsage</string>
  <key>CFBundleExecutable</key><string>ClaudeUsage</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array>
    <string>en</string><string>fr</string><string>es</string><string>it</string>
    <string>de</string><string>pt</string><string>zh-Hans</string><string>ja</string>
  </array>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/ClaudeUsage.zip
echo "Built: $APP and build/ClaudeUsage.zip"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x ClaudeUsage 2>/dev/null || true
  rm -rf /Applications/ClaudeUsage.app
  cp -R "$APP" /Applications/
  open /Applications/ClaudeUsage.app
  echo "Installed."
fi
