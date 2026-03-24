#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="garbageman"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
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
swift build -c release --product "$APP_NAME"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
popd >/dev/null
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>garbageman</string>
    <key>CFBundleExecutable</key>
    <string>garbageman</string>
    <key>CFBundleIdentifier</key>
    <string>com.yunusemreyakisan.garbageman</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>garbageman</string>
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
</dict>
</plist>
PLIST

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
