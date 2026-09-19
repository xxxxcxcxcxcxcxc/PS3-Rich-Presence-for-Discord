#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PS3 Rich Presence"
APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/PS3-Rich-Presence-macOS.dmg"
DMG_ROOT="$ROOT/.build/dmg-root"
ICONSET="$ROOT/.build/PS3RichPresence.iconset"
ICON="$APP/Contents/Resources/AppIcon.icns"
BACKGROUND="$ROOT/.build/InstallerBackground.png"
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:--}"

cd "$ROOT"
rm -rf .build/swift-arm64 .build/swift-x86_64
swift build -c release --arch arm64 --scratch-path .build/swift-arm64
ARM_BINARY="$(find .build/swift-arm64 -path '*/release/PS3RichPresence' -type f -perm -111 -print -quit)"
swift build -c release --arch x86_64 --scratch-path .build/swift-x86_64
X86_BINARY="$(find .build/swift-x86_64 -path '*/release/PS3RichPresence' -type f -perm -111 -print -quit)"
if [[ -z "$ARM_BINARY" || -z "$X86_BINARY" ]]; then
	echo "Could not find both Swift release binaries" >&2
	exit 1
fi
rm -rf "$APP" "$DMG" "$DMG_ROOT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP/Contents/MacOS/PS3RichPresence"
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
codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP" >/dev/null

mkdir -p "$DMG_ROOT"
if command -v create-dmg >/dev/null 2>&1; then
	qlmanage -t -s 760 -o "$ROOT/.build" "$ROOT/Assets/InstallerBackground.svg" >/dev/null 2>&1
	mv "$ROOT/.build/InstallerBackground.svg.png" "$BACKGROUND"
	create-dmg \
		--volname "$APP_NAME" \
		--background "$BACKGROUND" \
		--window-pos 200 120 \
		--window-size 760 460 \
		--icon-size 112 \
		--icon "$APP_NAME.app" 190 285 \
		--app-drop-link 570 285 \
		"$DMG" "$APP"
else
	cp -R "$APP" "$DMG_ROOT/$APP_NAME.app"
	ln -s /Applications "$DMG_ROOT/Applications"
	hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG"
fi
printf '\nCreated:\n%s\n%s\n' "$APP" "$DMG"
