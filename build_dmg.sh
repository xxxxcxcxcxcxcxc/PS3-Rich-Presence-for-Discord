#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PS3 Rich Presence"
APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/PS3-Rich-Presence-macOS.dmg"
DMG_ROOT="$ROOT/.build/dmg-root"
ICONSET="$ROOT/.build/PS3RichPresence.iconset"
ICON="$APP/Contents/Resources/AppIcon.icns"

cd "$ROOT"
swift build -c release
SWIFT_BINARY="$(find .build -path '*/release/PS3RichPresence' -type f -perm -111 -print -quit)"
if [[ -z "$SWIFT_BINARY" ]]; then
	echo "Could not find the Swift release binary" >&2
	exit 1
fi
rm -rf "$APP" "$DMG" "$DMG_ROOT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SWIFT_BINARY" "$APP/Contents/MacOS/PS3RichPresence"
cp Info.plist "$APP/Contents/Info.plist"
cp bootstrap.py PS3RPD.py "$APP/Contents/Resources/"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
qlmanage -t -s 1024 -o "$ICONSET" "$ROOT/Assets/AppIcon.svg" >/dev/null 2>&1
mv "$ICONSET/AppIcon.svg.png" "$ICONSET/icon_1024x1024.png"
for size in 16 32 128 256 512; do
	sips -z "$size" "$size" "$ICONSET/icon_1024x1024.png" --out "$ICONSET/icon_${size}x${size}@1x.png" >/dev/null
	double=$((size * 2))
	sips -z "$double" "$double" "$ICONSET/icon_1024x1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ICON"
chmod +x "$APP/Contents/MacOS/PS3RichPresence"

mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG"
printf '\nCreated:\n%s\n%s\n' "$APP" "$DMG"
