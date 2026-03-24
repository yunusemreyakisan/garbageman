import Combine
import Foundation
import GarbagemanCore

struct CleanupSummaryItem: Identifiable {
    let id: CategoryID
    let displayName: String
    let bytes: Int64
}

final class AppViewModel: ObservableObject {
    @Published private(set) var categories: [CategoryViewModel]
    @Published var selectedCategoryID: CategoryID?
    @Published private(set) var permissionSnapshot = PermissionsSnapshot(fullDiskAccessGranted: false, categoryAccess: [:])
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var cleanProgress: CleanupProgress?
    @Published var showingConfirmationSheet = false
    @Published var errorMessage: String?
    @Published private(set) var lastCleanupBytes: Int64?

    private let client: any CleanupClient
    private var cancellables: Set<AnyCancellable> = []
    private var ignoredPermissionBannerCategoryIDs: Set<CategoryID> = []

    init(client: any CleanupClient = LiveCleanupClient()) {
        self.client = client
        self.categories = CategoryID.allCases.map(CategoryViewModel.init)
        bindChildChanges()
    }

    var selectedCategory: CategoryViewModel? {
        guard let selectedCategoryID else {
            return nil
        }
        return categories.first(where: { $0.id == selectedCategoryID })
    }

    var selectedCategoryCount: Int {
        categories.filter { !$0.selectedTargetIDs.isEmpty }.count
    }

    var selectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.selectedBytes }
    }

    var canClean: Bool {
        selectedBytes > 0 && !isScanning && !isCleaning
    }

    var cleanupSummaryItems: [CleanupSummaryItem] {
        categories.compactMap { category in
            guard category.selectedBytes > 0 else {
                return nil
            }

            return CleanupSummaryItem(
                id: category.id,
                displayName: category.displayName,
                bytes: category.selectedBytes
            )
        }
    }

    var permissionBannerCategory: CategoryViewModel? {
        guard
            let selectedCategory,
            selectedCategory.needsPermissionBanner,
            !ignoredPermissionBannerCategoryIDs.contains(selectedCategory.id)
        else {
            return nil
        }

        return selectedCategory
    }

    func categoryViewModel(for id: CategoryID) -> CategoryViewModel? {
        categories.first(where: { $0.id == id })
    }

    func scan() {
        performScan(clearCleanupResult: true)
    }

    func selectCategory(_ categoryID: CategoryID?) {
        selectedCategoryID = categoryID
    }

    func dismissPermissionBanner() {
        guard let selectedCategoryID else {
            return
        }
        ignoredPermissionBannerCategoryIDs.insert(selectedCategoryID)
        objectWillChange.send()
    }

    func openSystemSettings() {
        client.openFullDiskAccessSettings()
    }

    func toggleCategorySelection(_ category: CategoryViewModel) {
        clearCleanupResult()
        selectCategory(category.id)
        category.toggleAllSelection()
    }

    func toggleAllTargets(in category: CategoryViewModel) {
        clearCleanupResult()
        category.toggleAllSelection()
    }

    func toggleTarget(_ targetID: String, in category: CategoryViewModel) {
        clearCleanupResult()
        category.setTargetSelected(targetID, isSelected: !category.isTargetSelected(targetID))
    }

    func presentConfirmation() {
        guard canClean else {
            return
        }
        showingConfirmationSheet = true
    }

    func performCleanup() {
        guard canClean else {
            return
        }

        let cleanupConfiguration = makeConfiguration(clean: true)
        let selectedPlans = categories.compactMap { $0.selectedPlan() }
        let totalTargets = max(1, selectedPlans.reduce(0) { $0 + $1.allTargets.count })

        showingConfirmationSheet = false
        errorMessage = nil
        isCleaning = true
        cleanProgress = CleanupProgress(
            completedUnitCount: 0,
            totalUnitCount: totalTargets,
            currentDescription: "Preparing cleanup…"
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self, client, cleanupConfiguration] in
            guard let self else {
                return
            }

            var plans = selectedPlans
            let errors = client.clean(
                categories: &plans,
                configuration: cleanupConfiguration,
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        self.cleanProgress = progress
                    }
                }
            )
            let freedBytes = plans.reduce(0) { $0 + $1.freedBytes }

            DispatchQueue.main.async {
                self.isCleaning = false
                self.cleanProgress = nil
                self.categories.forEach { $0.clearSelection() }
                self.lastCleanupBytes = freedBytes > 0 ? freedBytes : nil
                if !errors.isEmpty {
                    self.errorMessage = errors.joined(separator: "\n")
                }
                self.performScan(clearCleanupResult: false)
            }
        }
    }

    func prepareForScan(_ snapshot: PermissionsSnapshot) {
        permissionSnapshot = snapshot
        isScanning = true
        errorMessage = nil
        showingConfirmationSheet = false
        ignoredPermissionBannerCategoryIDs.removeAll()
        cleanProgress = nil
        categories.forEach { category in
            category.beginScan(permissionAccess: snapshot.access(for: category.id))
        }
    }

    func applyScanProgress(_ progress: ScanProgress) {
        categoryViewModel(for: progress.categoryID)?.apply(plan: progress.plan)
    }

    func finishScan() {
        isScanning = false

        for category in categories where category.scanState == .scanning {
            category.finishWithoutPlan()
        }

        if selectedCategory == nil {
            selectedCategoryID = categories.first?.id
        }
    }

    private func bindChildChanges() {
        for category in categories {
            category.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    private func clearCleanupResult() {
        if lastCleanupBytes != nil {
            lastCleanupBytes = nil
        }
    }

    private func performScan(clearCleanupResult: Bool) {
        let categoryIDs = CategoryID.allCases
        let configuration = makeConfiguration(clean: false)
        let snapshot = client.evaluatePermissions(for: categoryIDs)
        if clearCleanupResult {
            lastCleanupBytes = nil
        }
        prepareForScan(snapshot)

        DispatchQueue.global(qos: .userInitiated).async { [weak self, client, configuration, snapshot] in
            guard let self else {
                return
            }

            let _ = client.scan(
                configuration: configuration,
                selectedCategoryIDs: categoryIDs,
                permissionSnapshot: snapshot,
                now: Date(),
                progressHandler: { progress in
                    DispatchQueue.main.async {
                        self.applyScanProgress(progress)
                    }
                }
            )

            DispatchQueue.main.async {
                self.finishScan()
            }
        }
    }

    private func makeConfiguration(clean: Bool) -> AppConfiguration {
        AppConfiguration(
            clean: clean,
            summary: false,
            json: false,
            verbose: false,
            onlyCategories: nil,
            skippedCategories: [],
            downloadsOlderThanDays: 30,
            keepLastArchives: 5,
            yesSafe: true
        )
    }
}
