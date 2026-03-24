# Garbageman

[![CI](https://github.com/yunusemreyakisan/garbageman/actions/workflows/ci.yml/badge.svg)](https://github.com/yunusemreyakisan/garbageman/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/yunusemreyakisan/garbageman?display_name=tag)](https://github.com/yunusemreyakisan/garbageman/releases/latest)

Garbageman is the native macOS desktop companion to the `garbageman` CLI. It brings the same cleanup categories and safety rules into a single-window SwiftUI app: scan first, inspect what is reclaimable, then explicitly confirm deletion.

- macOS 13+
- Native `SwiftUI` interface
- Powered by the local `GarbagemanCore` package
- Packaged as a `.dmg`, with CI-based release publishing and optional signing and notarization when release credentials are configured

## Key features

- Single-window cleanup workflow with a grouped sidebar and dedicated detail view
- Scan-first behavior so nothing is deleted during analysis
- Per-category and per-item review depending on the risk level of each cleanup target
- Reclaimable-space summary with an explicit confirmation sheet before deletion
- Inline cleanup progress and issue reporting
- Full Disk Access guidance inside the app, including a shortcut to System Settings when needed

## What Garbageman can clean

| Area | Categories |
| --- | --- |
| System | User Caches, System Logs, Trash |
| Developer | Xcode Build Artifacts, iOS Simulator Devices, Homebrew Cache, npm Cache, pip Cache, Yarn Cache, Gradle Cache, CocoaPods Cache, Android Emulator Snapshots, Docker Dangling Images |
| Personal and device | Old Downloads, iOS Device Backups |

Current defaults are conservative: Old Downloads only includes direct files older than 30 days, Xcode archive cleanup keeps the newest five archives, and iOS backups are reviewed item by item.

## How it works

1. Click **Scan** to analyze all supported cleanup categories.
2. Review grouped results in the sidebar and detail pane, including size totals and individual targets.
3. Select the items you want to remove.
4. Confirm the cleanup from the summary sheet before anything is deleted.
5. Let the app run the cleanup, report any issues, and refresh the UI with a follow-up scan.

If a category needs additional permission, Garbageman surfaces that requirement in the interface instead of silently failing.

## Install

The simplest way to use Garbageman is to download the latest disk image from [Releases](https://github.com/yunusemreyakisan/garbageman/releases/latest).

1. Download `garbageman-x.y.z.dmg`.
2. Open the disk image.
3. Drag `Garbageman.app` into `/Applications`.

If you prefer a local build, use the commands in [Build from source](#build-from-source).

## Permissions and safety

Garbageman is intentionally conservative.

- `iOS Device Backups` requires Full Disk Access to inspect `~/Library/Application Support/MobileSync/Backup`.
- Scanning never deletes anything.
- Cleanup is restricted to category-specific approved roots discovered by the scanner.
- The cleaner refuses to delete the category root itself, even inside an approved location.
- The safety policy blocks deletions outside approved roots and rejects sensitive paths such as `/System`, `/Applications`, `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Library/Preferences`, and `~/Library/Keychains`.
- When extra access is required, the app shows a warning banner with an **Open System Settings** action.

## Build from source

```bash
swift build
swift test
swift test --package-path Core
./scripts/build-app-bundle.sh
./scripts/package-dmg.sh
```

Local packaging uses an ad-hoc signature by default so the app bundle is structurally valid for development. Internet distribution still requires a Developer ID signature and notarization.

## Release process

- Update `Sources/GarbagemanDesktop/AppBuildInfo.swift` with the next version.
- Push to `main`.
- CI runs the app tests, the core package tests, and validates the app bundle build.
- The release workflow creates or reuses the matching `vX.Y.Z` tag, builds the DMG, and publishes the GitHub Release assets; when release credentials are configured, it also signs and notarizes the artifact.
- If `HOMEBREW_TAP_TOKEN` is configured, the workflow can also update the Homebrew cask in the tap repository.
- Optional release signing secrets: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `APPLE_TEAM_ID`.

## Project structure

- `Sources/GarbagemanDesktop` contains the native macOS app, SwiftUI screens, and view models.
- `Core/Sources/GarbagemanCore` contains the scanning engine, permission checks, cleanup orchestration, and safety policy.
- `scripts` contains the app bundle and DMG packaging helpers.

Licensed under the [MIT License](LICENSE).
