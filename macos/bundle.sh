#!/bin/bash
# Build CairoClock.app (menu-bar only app) from the Swift package.
set -e
cd "$(dirname "$0")"

# Usage: ./bundle.sh [release|debug]   (default: release)
config=${1:-release}
case "$config" in release|debug) ;; *) echo "Usage: $0 [release|debug]" >&2; exit 1 ;; esac

swift build -c "$config"

app=build/CairoClock-$config.app
[ "$config" = release ] && app=build/CairoClock.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp ".build/$config/CairoClock" "$app/Contents/MacOS/"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Cairo Clock</string>
	<key>CFBundleIdentifier</key><string>com.github.eexpress.cairo-clock</string>
	<key>CFBundleExecutable</key><string>CairoClock</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
echo "Built $app"
