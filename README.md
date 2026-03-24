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

## Release

Push to `main` after updating `Sources/GarbagemanDesktop/AppBuildInfo.swift`.

The release workflow will:

1. run tests
2. create `vX.Y.Z` if that version tag does not already exist
3. build `garbageman.app` and `garbageman-X.Y.Z.dmg`
4. create or update the GitHub Release for that tag
5. optionally update the Homebrew cask when `HOMEBREW_TAP_TOKEN` is configured
