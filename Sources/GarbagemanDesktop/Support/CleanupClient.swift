import Foundation
import GarbagemanCore

protocol CleanupClient {
    func evaluatePermissions(for categoryIDs: [CategoryID]) -> PermissionsSnapshot
    func openFullDiskAccessSettings()
    func scan(
        configuration: AppConfiguration,
        selectedCategoryIDs: [CategoryID],
        permissionSnapshot: PermissionsSnapshot,
        now: Date,
        progressHandler: ((ScanProgress) -> Void)?
    ) -> [CategoryPlan]
    func clean(
        categories: inout [CategoryPlan],
        configuration: AppConfiguration,
        progressHandler: ((CleanupProgress) -> Void)?
    ) -> [String]
}

struct LiveCleanupClient: CleanupClient {
    private let engine: CleanupEngine

    init(engine: CleanupEngine = CleanupEngine()) {
        self.engine = engine
    }

    func evaluatePermissions(for categoryIDs: [CategoryID]) -> PermissionsSnapshot {
        engine.evaluatePermissions(for: categoryIDs)
    }

    func openFullDiskAccessSettings() {
        engine.openFullDiskAccessSettings()
    }

    func scan(
        configuration: AppConfiguration,
        selectedCategoryIDs: [CategoryID],
        permissionSnapshot: PermissionsSnapshot,
        now: Date,
        progressHandler: ((ScanProgress) -> Void)?
    ) -> [CategoryPlan] {
        engine.scan(
            configuration: configuration,
            selectedCategoryIDs: selectedCategoryIDs,
            permissionSnapshot: permissionSnapshot,
            now: now,
            progressHandler: progressHandler
        )
    }

    func clean(
        categories: inout [CategoryPlan],
        configuration: AppConfiguration,
        progressHandler: ((CleanupProgress) -> Void)?
    ) -> [String] {
        engine.clean(
            categories: &categories,
            configuration: configuration,
            confirmationHandler: nil,
            progressHandler: progressHandler
        )
    }
}
