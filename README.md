# garbageman-app

`garbageman-app` is the native macOS desktop companion to the `garbageman` CLI.

It keeps the same cleanup categories and safety rules, but presents them in a single-window SwiftUI interface: scan first, review reclaimable space, then explicitly confirm deletion.

## Stack

- SwiftUI on macOS 13+
- MVVM
- local `Core/` Swift package for scan, permission, and cleanup logic
- direct `.dmg` distribution

## Layout

- grouped sidebar with category checkboxes and size badges
- detail panel with per-item selection
- summary bar with reclaimable size
- confirmation sheet before deletion
- inline cleanup progress
- Full Disk Access banner for protected categories

## Development

```bash
swift build
swift test
swift test --package-path Core
./scripts/build-app-bundle.sh
./scripts/package-dmg.sh
```

Local packaging uses an ad-hoc signature by default so the app bundle is structurally valid for development. Internet distribution still requires a Developer ID signature and notarization.

## Release

Push to `main` after updating `Sources/GarbagemanDesktop/AppBuildInfo.swift`.

The release workflow will:

1. run tests
2. skip publishing if that version tag already points at an older commit
3. import the Developer ID certificate from GitHub secrets
4. build, sign, notarize, and staple `Garbageman.app` and `garbageman-X.Y.Z.dmg`
5. create `vX.Y.Z` if that version tag does not already exist on the current commit
6. create or update the GitHub Release for that tag
7. optionally update the Homebrew cask when `HOMEBREW_TAP_TOKEN` is configured

Required repository secrets for releases:

- `BUILD_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12`
- `P12_PASSWORD`: password for the `.p12`
- `KEYCHAIN_PASSWORD`: temporary keychain password for the GitHub Actions runner
- `APPLE_ID`: Apple ID used with `notarytool`
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for the Apple ID
- `APPLE_TEAM_ID`: Apple Developer team identifier
