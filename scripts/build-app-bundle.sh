#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Garbageman"
EXECUTABLE_NAME="garbageman"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_ICON_PATH="$ROOT_DIR/Resources/AppIcon.icns"
ENTITLEMENTS_PATH="$ROOT_DIR/Resources/garbageman.entitlements"
VERSION_FILE="$ROOT_DIR/Sources/GarbagemanDesktop/AppBuildInfo.swift"
REQUIRE_DEVELOPER_IDENTITY="${REQUIRE_DEVELOPER_IDENTITY:-0}"
DEVELOPER_IDENTITY="${DEVELOPER_IDENTITY:-}"

version="$(
  sed -n 's/.*static let version = "\(.*\)".*/\1/p' "$VERSION_FILE" | head -n 1
)"

if [[ -z "$version" ]]; then
  echo "Unable to determine app version from $VERSION_FILE" >&2
  exit 1
fi

if [[ "$REQUIRE_DEVELOPER_IDENTITY" == "1" && -z "$DEVELOPER_IDENTITY" ]]; then
  echo "DEVELOPER_IDENTITY must be set when REQUIRE_DEVELOPER_IDENTITY=1." >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

pushd "$ROOT_DIR" >/dev/null
swift build -c release --product "$EXECUTABLE_NAME"
cp ".build/release/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
popd >/dev/null
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

if [[ -f "$APP_ICON_PATH" ]]; then
  cp "$APP_ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Garbageman</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.yunusemreyakisan.garbageman</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Garbageman</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE" 2>/dev/null || true

if [[ -n "$DEVELOPER_IDENTITY" ]]; then
  codesign \
    --force \
    --deep \
    --strict \
    --timestamp \
    --options runtime \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$DEVELOPER_IDENTITY" \
    "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
