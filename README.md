# Garbageman

[![CI](https://github.com/yunusemreyakisan/garbageman/actions/workflows/ci.yml/badge.svg)](https://github.com/yunusemreyakisan/garbageman/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/yunusemreyakisan/garbageman?display_name=tag)](https://github.com/yunusemreyakisan/garbageman/releases/latest)

Garbageman is a native macOS cleanup app built on the same rules and categories as the `garbageman` CLI. It helps you review reclaimable space across common system, developer, and device-related locations, then remove selected items through a deliberate scan, review, and confirm workflow.

<img width="1293" height="844" alt="Screenshot 2026-03-24 at 16 23 10" src="https://github.com/user-attachments/assets/e2ed31d8-1b9c-423e-9341-4554bece28c8" />

## Key features

- Focused single-window interface with grouped navigation and a dedicated detail view
- Review-first scanning so reclaimable space is estimated before any deletion occurs
- Category-level or item-level confirmation based on the risk profile of each cleanup target
- Clear reclaimable-space summaries, cleanup progress, and issue reporting
- Built-in Full Disk Access guidance for protected locations, including a shortcut to System Settings

## What Garbageman can clean

| Area | Categories |
| --- | --- |
| System | User Caches, System Logs, Trash |
| Developer | Xcode Build Artifacts, iOS Simulator Devices, Homebrew Cache, npm Cache, pip Cache, Yarn Cache, Gradle Cache, CocoaPods Cache, Android Emulator Snapshots, Docker Dangling Images |
| Personal and device | Old Downloads, iOS Device Backups |

Default behavior is intentionally conservative: Old Downloads only includes direct files older than 30 days, Xcode archive cleanup keeps the five most recent archives, and iOS backups are reviewed item by item.

## How it works

1. Click **Scan** to analyze all supported cleanup categories.
2. Review results by category, including size totals and individual cleanup targets.
3. Select the items you want to remove.
4. Confirm the cleanup before any files are deleted.
5. Let Garbageman complete the cleanup, report any issues, and refresh the view with an updated scan.

If a category requires additional access, Garbageman surfaces that requirement clearly in the interface instead of failing silently.

## Install

The recommended way to install Garbageman is to download the latest disk image from [Releases](https://github.com/yunusemreyakisan/garbageman/releases/latest).

1. Download `garbageman-x.y.z.dmg`.
2. Open the disk image.
3. Drag `Garbageman.app` into `/Applications`.

## Permissions and safety

Garbageman is designed to be cautious by default.

- Scans are read-only. Nothing is deleted during analysis.
- `iOS Device Backups` requires Full Disk Access to inspect `~/Library/Application Support/MobileSync/Backup`.
- Cleanup is restricted to approved locations discovered for each category.
- The cleaner refuses to delete the category root itself, even when that location is otherwise approved.
- The safety policy blocks deletions outside approved roots and rejects sensitive locations such as `/System`, `/Applications`, `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Library/Preferences`, and `~/Library/Keychains`.
- When additional access is required, the app shows a warning banner with an **Open System Settings** action.

Licensed under the [MIT License](LICENSE).
