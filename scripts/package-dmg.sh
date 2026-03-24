#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/garbageman.app"
DMG_PATH="$DIST_DIR/garbageman.dmg"

"$ROOT_DIR/scripts/build-app-bundle.sh"

rm -f "$DMG_PATH"
hdiutil create -volname "garbageman" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

echo "Created $DMG_PATH"
