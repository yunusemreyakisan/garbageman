import Foundation
import XCTest

@testable import GarbagemanCore

final class ScannerTests: XCTestCase {
    func testDownloadsCategoryOnlyIncludesDirectOldFiles() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let downloads = home.appendingPathComponent("Downloads")
        let oldFile = downloads.appendingPathComponent("old.zip")
        let newFile = downloads.appendingPathComponent("new.zip")
        let nestedFile = downloads.appendingPathComponent("folder/nested.zip")

        try createFile(oldFile, size: 128)
        try createFile(newFile, size: 128)
        try createFile(nestedFile, size: 128)

        let now = Date()
        try setModificationDate(now.addingTimeInterval(-90 * 86_400), for: oldFile)
        try setModificationDate(now.addingTimeInterval(-2 * 86_400), for: newFile)
        try setModificationDate(now.addingTimeInterval(-90 * 86_400), for: nestedFile)

        let configuration = AppConfiguration(
            clean: false,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: [.downloads],
            skippedCategories: [],
            downloadsOlderThanDays: 30,
            keepLastArchives: 5,
            yesSafe: false
        )
        let context = ScanContext(
            configuration: configuration,
            homeDirectory: home,
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            permissions: PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:]),
            now: now
        )

        let plan = DownloadsCategory().scan(using: context)
        let targets = plan.groups.flatMap(\.targets)

        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(targets.first?.displayName, "old.zip")
    }

    func testXcodeCategoryKeepsNewestArchives() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let archivesRoot = home.appendingPathComponent("Library/Developer/Xcode/Archives/2026-03-24")
        let archiveA = archivesRoot.appendingPathComponent("AppA.xcarchive")
        let archiveB = archivesRoot.appendingPathComponent("AppB.xcarchive")

        try createDirectory(archiveA)
        try createDirectory(archiveB)

        let now = Date()
        try setModificationDate(now.addingTimeInterval(-10_000), for: archiveA)
        try setModificationDate(now.addingTimeInterval(-1_000), for: archiveB)

        let configuration = AppConfiguration(
            clean: false,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: [.xcode],
            skippedCategories: [],
            downloadsOlderThanDays: 30,
            keepLastArchives: 1,
            yesSafe: false
        )
        let context = ScanContext(
            configuration: configuration,
            homeDirectory: home,
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            permissions: PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:]),
            now: now
        )

        let plan = XcodeCategory().scan(using: context)
        let archiveGroup = try XCTUnwrap(plan.groups.first(where: { $0.id == "archives" }))

        XCTAssertEqual(archiveGroup.targets.count, 1)
        XCTAssertEqual(archiveGroup.targets.first?.displayName, "AppA")
        XCTAssertEqual(archiveGroup.note, "Keeping the newest 1 archive(s).")
    }

    func testSelectedCategoryIDsApplyOnlyAndSkip() {
        let configuration = AppConfiguration(
            clean: false,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: [.caches, .logs, .trash],
            skippedCategories: [.logs],
            downloadsOlderThanDays: 30,
            keepLastArchives: 5,
            yesSafe: false
        )

        XCTAssertEqual(configuration.selectedCategoryIDs(), [.caches, .trash])
    }

    func testSimulatorsCategoryGroupsDevicesByRuntime() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let devicesRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        let ios182A = devicesRoot.appendingPathComponent("A1")
        let ios182B = devicesRoot.appendingPathComponent("B2")
        let ios171 = devicesRoot.appendingPathComponent("C3")

        try createDirectory(ios182A)
        try createDirectory(ios182B)
        try createDirectory(ios171)

        try writePlistDictionary(
            [
                "name": "iPhone 15",
                "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            ],
            to: ios182A.appendingPathComponent("device.plist")
        )
        try writePlistDictionary(
            [
                "name": "iPad Air",
                "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            ],
            to: ios182B.appendingPathComponent("device.plist")
        )
        try writePlistDictionary(
            [
                "name": "iPhone SE",
                "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-17-1",
            ],
            to: ios171.appendingPathComponent("device.plist")
        )

        try createFile(ios182A.appendingPathComponent("data.bin"), size: 128)
        try createFile(ios182B.appendingPathComponent("data.bin"), size: 64)
        try createFile(ios171.appendingPathComponent("data.bin"), size: 32)

        let now = Date()
        let configuration = AppConfiguration(
            clean: false,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: [.simulators],
            skippedCategories: [],
            downloadsOlderThanDays: 30,
            keepLastArchives: 5,
            yesSafe: false
        )
        let context = ScanContext(
            configuration: configuration,
            homeDirectory: home,
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            permissions: PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:]),
            now: now
        )

        let plan = SimulatorsCategory().scan(using: context)

        XCTAssertEqual(plan.groups.count, 2)

        let ios182Group = try XCTUnwrap(plan.groups.first(where: { $0.displayName == "iOS 18.2 Simulators" }))
        XCTAssertEqual(ios182Group.confirmationStyle, .category)
        XCTAssertEqual(ios182Group.targets.count, 2)
        XCTAssertEqual(ios182Group.note, "Includes 2 device(s).")

        let ios171Group = try XCTUnwrap(plan.groups.first(where: { $0.displayName == "iOS 17.1 Simulators" }))
        XCTAssertEqual(ios171Group.targets.count, 1)
    }

    func testScannerReportsProgressForEachScannedCategory() {
        let configuration = AppConfiguration(
            clean: false,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: [.caches, .trash],
            skippedCategories: [],
            downloadsOlderThanDays: 30,
            keepLastArchives: 5,
            yesSafe: false
        )
        let home = FileManager.default.homeDirectoryForCurrentUser
        let context = ScanContext(
            configuration: configuration,
            homeDirectory: home,
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            permissions: PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:]),
            now: Date()
        )

        let scanner = Scanner(
            categories: [
                GenericDirectoryCategory(id: .caches, displayName: "User Caches") { _ in .ready(nil) },
                GenericDirectoryCategory(id: .trash, displayName: "Trash") { _ in .ready(nil) },
            ]
        )
        var updates: [ScanProgress] = []

        let plans = scanner.scan(
            selectedCategoryIDs: [.caches, .trash],
            context: context,
            onCategoryScanned: { updates.append($0) }
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(updates.map(\.categoryID), [.caches, .trash])
        XCTAssertEqual(updates.map(\.completedCategoryCount), [1, 2])
        XCTAssertTrue(updates.allSatisfy { $0.totalCategoryCount == 2 })
    }
}
