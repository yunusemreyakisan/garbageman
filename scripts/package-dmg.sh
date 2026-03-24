#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/garbageman.app"
DMG_PATH="$DIST_DIR/garbageman.dmg"
REQUIRE_NOTARIZATION="${REQUIRE_NOTARIZATION:-0}"
DEVELOPER_IDENTITY="${DEVELOPER_IDENTITY:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"

should_notarize=0
if [[ "$REQUIRE_NOTARIZATION" == "1" ]]; then
  should_notarize=1
elif [[ -n "$APPLE_ID" || -n "$APPLE_APP_SPECIFIC_PASSWORD" || -n "$APPLE_TEAM_ID" ]]; then
  should_notarize=1
fi

if [[ "$should_notarize" == "1" && -z "$DEVELOPER_IDENTITY" ]]; then
  echo "DEVELOPER_IDENTITY must be set before notarizing the DMG." >&2
  exit 1
fi

if [[ "$should_notarize" == "1" ]]; then
  for variable_name in APPLE_ID APPLE_APP_SPECIFIC_PASSWORD APPLE_TEAM_ID; do
    if [[ -z "${(P)variable_name}" ]]; then
      echo "$variable_name must be set before notarizing the DMG." >&2
      exit 1
    fi
  done
fi

"$ROOT_DIR/scripts/build-app-bundle.sh"

rm -f "$DMG_PATH"
hdiutil create -volname "garbageman" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

if [[ -n "$DEVELOPER_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_IDENTITY" "$DMG_PATH"
fi

if [[ "$should_notarize" == "1" ]]; then
  xcrun notarytool submit \
    "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "Created $DMG_PATH"
