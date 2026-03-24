import XCTest
import GarbagemanCore

@testable import GarbagemanDesktop

final class AppViewModelTests: XCTestCase {
    func testSelectingCategoryUpdatesSummary() throws {
        let viewModel = AppViewModel(client: StubCleanupClient())
        viewModel.prepareForScan(PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:]))

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
                    targets: [
                        DeletionTarget(
                            id: "cache-a",
                            displayName: "A",
                            displayPath: "~/Library/Caches/A",
                            absolutePath: "/tmp/A",
                            kind: .fileSystemPath,
                            bytes: 128,
                            modifiedAt: nil,
                            metadata: [:]
                        ),
                    ]
                ),
            ],
            allowedRoots: ["/tmp"]
        )

        viewModel.applyScanProgress(
            ScanProgress(
                categoryID: .caches,
                completedCategoryCount: 1,
                totalCategoryCount: 1,
                plan: plan
            )
        )
        viewModel.finishScan()

        let category = try XCTUnwrap(viewModel.categoryViewModel(for: .caches))
        viewModel.toggleCategorySelection(category)

        XCTAssertEqual(viewModel.selectedCategoryCount, 1)
        XCTAssertEqual(viewModel.selectedBytes, 128)
        XCTAssertEqual(viewModel.cleanupSummaryItems.first?.displayName, "User Caches")
    }

    func testDeniedCategoryShowsPermissionBannerUntilIgnored() {
        let viewModel = AppViewModel(client: StubCleanupClient())
        viewModel.prepareForScan(
            PermissionsSnapshot(
                fullDiskAccessGranted: false,
                categoryAccess: [.iosBackups: .denied]
            )
        )

        let plan = CategoryPlan(
            id: .iosBackups,
            displayName: "iOS Device Backups",
            permissionRequirement: .fullDiskAccess,
            status: .unavailable,
            note: "Full Disk Access is required to inspect MobileSync backups.",
            groups: [],
            allowedRoots: []
        )

        viewModel.applyScanProgress(
            ScanProgress(
                categoryID: .iosBackups,
                completedCategoryCount: 1,
                totalCategoryCount: 1,
                plan: plan
            )
        )
        viewModel.finishScan()
        viewModel.selectCategory(.iosBackups)

        XCTAssertEqual(viewModel.permissionBannerCategory?.id, .iosBackups)

        viewModel.dismissPermissionBanner()

        XCTAssertNil(viewModel.permissionBannerCategory)
    }
}

private struct StubCleanupClient: CleanupClient {
    func evaluatePermissions(for categoryIDs: [CategoryID]) -> PermissionsSnapshot {
        PermissionsSnapshot(fullDiskAccessGranted: true, categoryAccess: [:])
    }

    func openFullDiskAccessSettings() {}

    func scan(
        configuration: AppConfiguration,
        selectedCategoryIDs: [CategoryID],
        permissionSnapshot: PermissionsSnapshot,
        now: Date,
        progressHandler: ((ScanProgress) -> Void)?
    ) -> [CategoryPlan] {
        []
    }

    func clean(
        categories: inout [CategoryPlan],
        configuration: AppConfiguration,
        progressHandler: ((CleanupProgress) -> Void)?
    ) -> [String] {
        []
    }
}
