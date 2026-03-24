import Foundation
import XCTest

@testable import GarbagemanCore

final class CleanerTests: XCTestCase {
    func testCleanerDeletesApprovedPathsWhenConfirmed() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let cachesRoot = home.appendingPathComponent("Library/Caches")
        let cacheFile = cachesRoot.appendingPathComponent("test.cache")
        try createFile(cacheFile, size: 64)

        var plans = [
            CategoryPlan(
                id: .caches,
                displayName: "User Caches",
                permissionRequirement: .none,
                status: .ready,
                note: nil,
                groups: [
                    DeletionGroup(
                        id: "caches",
                        displayName: "User Caches",
                        riskLevel: .safe,
                        confirmationStyle: .category,
                        note: nil,
                        targets: [
                            DeletionTarget(
                                id: cacheFile.path,
                                displayName: "test.cache",
                                displayPath: homeRelativePath(for: cacheFile.path, homeDirectory: home),
                                absolutePath: cacheFile.path,
                                kind: .fileSystemPath,
                                bytes: 64,
                                modifiedAt: nil,
                                metadata: [:]
                            ),
                        ]
                    ),
                ],
                allowedRoots: [cachesRoot.path]
            ),
        ]

        let cleaner = Cleaner(
            configuration: AppConfiguration(
                clean: true,
                summary: false,
                json: false,
                verbose: false,
                onlyCategories: [.caches],
                skippedCategories: [],
                downloadsOlderThanDays: 30,
                keepLastArchives: 5,
                yesSafe: true
            ),
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            safetyPolicy: SafetyPolicy(homeDirectory: home)
        )

        let errors = cleaner.clean(categories: &plans)

        XCTAssertTrue(errors.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertEqual(plans[0].groups[0].freedBytes, 64)
    }

    func testCleanerRejectsForbiddenPathEvenIfPlanClaimsIt() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let documentsRoot = home.appendingPathComponent("Documents")
        let documentFile = documentsRoot.appendingPathComponent("keep.txt")
        try createFile(documentFile, size: 64)

        var plans = [
            CategoryPlan(
                id: .caches,
                displayName: "User Caches",
                permissionRequirement: .none,
                status: .ready,
                note: nil,
                groups: [
                    DeletionGroup(
                        id: "caches",
                        displayName: "User Caches",
                        riskLevel: .safe,
                        confirmationStyle: .category,
                        note: nil,
                        targets: [
                            DeletionTarget(
                                id: documentFile.path,
                                displayName: "keep.txt",
                                displayPath: homeRelativePath(for: documentFile.path, homeDirectory: home),
                                absolutePath: documentFile.path,
                                kind: .fileSystemPath,
                                bytes: 64,
                                modifiedAt: nil,
                                metadata: [:]
                            ),
                        ]
                    ),
                ],
                allowedRoots: [documentsRoot.path]
            ),
        ]

        let cleaner = Cleaner(
            configuration: AppConfiguration(
                clean: true,
                summary: false,
                json: false,
                verbose: false,
                onlyCategories: [.caches],
                skippedCategories: [],
                downloadsOlderThanDays: 30,
                keepLastArchives: 5,
                yesSafe: true
            ),
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            safetyPolicy: SafetyPolicy(homeDirectory: home)
        )

        let errors = cleaner.clean(categories: &plans)

        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentFile.path))
        XCTAssertEqual(plans[0].groups[0].freedBytes, 0)
    }

    func testCleanerPromptsPerSimulatorRuntimeGroup() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let simulatorRoot = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        let runtimePath = simulatorRoot.appendingPathComponent("device-a")
        try createFile(runtimePath.appendingPathComponent("data.bin"), size: 64)

        var plans = [
            CategoryPlan(
                id: .simulators,
                displayName: "iOS Simulator Devices",
                permissionRequirement: .none,
                status: .ready,
                note: nil,
                groups: [
                    DeletionGroup(
                        id: "runtime-ios-18-2",
                        displayName: "iOS 18.2 Simulators",
                        riskLevel: .risky,
                        confirmationStyle: .category,
                        note: "Includes 1 device(s).",
                        targets: [
                            DeletionTarget(
                                id: runtimePath.path,
                                displayName: "iOS 18.2 / iPhone 15",
                                displayPath: homeRelativePath(for: runtimePath.path, homeDirectory: home),
                                absolutePath: runtimePath.path,
                                kind: .fileSystemPath,
                                bytes: 64,
                                modifiedAt: nil,
                                metadata: [
                                    "runtime": "iOS 18.2",
                                    "deviceName": "iPhone 15",
                                ]
                            ),
                        ]
                    ),
                ],
                allowedRoots: [simulatorRoot.path]
            ),
        ]

        let cleaner = Cleaner(
            configuration: AppConfiguration(
                clean: true,
                summary: false,
                json: false,
                verbose: false,
                onlyCategories: [.simulators],
                skippedCategories: [],
                downloadsOlderThanDays: 30,
                keepLastArchives: 5,
                yesSafe: false
            ),
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            safetyPolicy: SafetyPolicy(homeDirectory: home)
        )
        var messages: [String] = []

        let errors = cleaner.clean(
            categories: &plans,
            confirmationHandler: { request in
                messages.append(request.message)
                return false
            }
        )

        XCTAssertTrue(errors.isEmpty)
        XCTAssertTrue(messages.contains(where: { $0.contains("Delete iOS 18.2 Simulators") }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimePath.path))
    }

    func testCleanerAutoConfirmsWhenConfirmationHandlerIsMissing() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let downloadsRoot = home.appendingPathComponent("Downloads")
        let oldFile = downloadsRoot.appendingPathComponent("old.zip")
        try createFile(oldFile, size: 64)

        var plans = [
            CategoryPlan(
                id: .downloads,
                displayName: "Old Downloads",
                permissionRequirement: .none,
                status: .ready,
                note: nil,
                groups: [
                    DeletionGroup(
                        id: "downloads",
                        displayName: "Old Downloads",
                        riskLevel: .risky,
                        confirmationStyle: .item,
                        note: nil,
                        targets: [
                            DeletionTarget(
                                id: oldFile.path,
                                displayName: "old.zip",
                                displayPath: homeRelativePath(for: oldFile.path, homeDirectory: home),
                                absolutePath: oldFile.path,
                                kind: .fileSystemPath,
                                bytes: 64,
                                modifiedAt: nil,
                                metadata: [:]
                            ),
                        ]
                    ),
                ],
                allowedRoots: [downloadsRoot.path]
            ),
        ]

        let cleaner = Cleaner(
            configuration: AppConfiguration(
                clean: true,
                summary: false,
                json: false,
                verbose: false,
                onlyCategories: [.downloads],
                skippedCategories: [],
                downloadsOlderThanDays: 30,
                keepLastArchives: 5,
                yesSafe: false
            ),
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            safetyPolicy: SafetyPolicy(homeDirectory: home)
        )

        let errors = cleaner.clean(categories: &plans)

        XCTAssertTrue(errors.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        XCTAssertEqual(plans[0].groups[0].freedBytes, 64)
    }

    func testCleanerReportsProgressForProcessedTargets() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let cachesRoot = home.appendingPathComponent("Library/Caches")
        let fileA = cachesRoot.appendingPathComponent("a.bin")
        let fileB = cachesRoot.appendingPathComponent("b.bin")
        try createFile(fileA, size: 32)
        try createFile(fileB, size: 16)

        var plans = [
            CategoryPlan(
                id: .caches,
                displayName: "User Caches",
                permissionRequirement: .none,
                status: .ready,
                note: nil,
                groups: [
                    DeletionGroup(
                        id: "caches",
                        displayName: "User Caches",
                        riskLevel: .safe,
                        confirmationStyle: .category,
                        note: nil,
                        targets: [
                            DeletionTarget(
                                id: fileA.path,
                                displayName: "a.bin",
                                displayPath: homeRelativePath(for: fileA.path, homeDirectory: home),
                                absolutePath: fileA.path,
                                kind: .fileSystemPath,
                                bytes: 32,
                                modifiedAt: nil,
                                metadata: [:]
                            ),
                            DeletionTarget(
                                id: fileB.path,
                                displayName: "b.bin",
                                displayPath: homeRelativePath(for: fileB.path, homeDirectory: home),
                                absolutePath: fileB.path,
                                kind: .fileSystemPath,
                                bytes: 16,
                                modifiedAt: nil,
                                metadata: [:]
                            ),
                        ]
                    ),
                ],
                allowedRoots: [cachesRoot.path]
            ),
        ]

        let cleaner = Cleaner(
            configuration: AppConfiguration(
                clean: true,
                summary: false,
                json: false,
                verbose: false,
                onlyCategories: [.caches],
                skippedCategories: [],
                downloadsOlderThanDays: 30,
                keepLastArchives: 5,
                yesSafe: true
            ),
            fileManager: .default,
            commandRunner: StubCommandRunner(),
            safetyPolicy: SafetyPolicy(homeDirectory: home)
        )
        var progressEvents: [CleanupProgress] = []

        let errors = cleaner.clean(
            categories: &plans,
            progressHandler: { progressEvents.append($0) }
        )

        XCTAssertTrue(errors.isEmpty)
        XCTAssertGreaterThanOrEqual(progressEvents.count, 3)
        XCTAssertEqual(progressEvents.last?.completedUnitCount, 2)
        XCTAssertEqual(progressEvents.last?.totalUnitCount, 2)
    }

    func testCategoryPlanFilteringTargetsKeepsOnlySelectedItems() {
        let first = DeletionTarget(
            id: "1",
            displayName: "A",
            displayPath: "A",
            absolutePath: "/tmp/A",
            kind: .fileSystemPath,
            bytes: 10,
            modifiedAt: nil,
            metadata: [:]
        )
        let second = DeletionTarget(
            id: "2",
            displayName: "B",
            displayPath: "B",
            absolutePath: "/tmp/B",
            kind: .fileSystemPath,
            bytes: 20,
            modifiedAt: nil,
            metadata: [:]
        )
        let plan = CategoryPlan(
            id: .caches,
            displayName: "User Caches",
            permissionRequirement: .none,
            status: .ready,
            note: nil,
            groups: [
                DeletionGroup(
                    id: "caches",
                    displayName: "User Caches",
                    riskLevel: .safe,
                    confirmationStyle: .category,
                    note: nil,
                    targets: [first, second]
                ),
            ],
            allowedRoots: ["/tmp"]
        )

        let filtered = plan.filteringTargets(to: ["2"])

        XCTAssertEqual(filtered?.groups.count, 1)
        XCTAssertEqual(filtered?.groups.first?.targets.count, 1)
        XCTAssertEqual(filtered?.groups.first?.targets.first?.id, "2")
        XCTAssertEqual(filtered?.totalBytes, 20)
    }
}
