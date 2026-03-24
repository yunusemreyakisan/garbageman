import Combine
import Foundation
import GarbagemanCore

enum CategoryScanState {
    case idle
    case scanning
    case finished
}

final class CategoryViewModel: ObservableObject, Identifiable {
    let id: CategoryID
    let presentation: CategoryPresentation

    @Published private(set) var plan: CategoryPlan?
    @Published private(set) var scanState: CategoryScanState = .idle
    @Published private(set) var permissionAccess: PermissionEvaluation = .notNeeded
    @Published private(set) var selectedTargetIDs: Set<String> = []

    init(id: CategoryID) {
        self.id = id
        self.presentation = id.presentation
    }

    var sidebarName: String { presentation.sidebarName }
    var displayName: String { plan?.displayName ?? id.displayName }
    var iconName: String { presentation.icon }
    var section: SidebarSection { presentation.section }
    var groups: [DeletionGroup] { plan?.groups ?? [] }
    var note: String? { plan?.note }
    var totalBytes: Int64 { plan?.totalBytes ?? 0 }
    var selectedBytes: Int64 {
        groups
            .flatMap(\.targets)
            .filter { selectedTargetIDs.contains($0.id) }
            .reduce(0) { $0 + $1.bytes }
    }
    var allTargets: [DeletionTarget] { plan?.allTargets ?? [] }
    var isUnavailable: Bool { plan?.status == .unavailable }
    var isSelectable: Bool { plan?.status == .ready && !allTargets.isEmpty }
    var needsPermissionBanner: Bool { permissionAccess == .denied || plan?.permissionRequirement == .fullDiskAccess && isUnavailable }
    var permissionMessage: String {
        plan?.note ?? "Full Disk Access is required for this category."
    }

    var checkboxState: CheckboxState {
        guard isSelectable else {
            return .off
        }

        if selectedTargetIDs.isEmpty {
            return .off
        }

        if selectedTargetIDs.count == allTargets.count {
            return .on
        }

        return .mixed
    }

    func beginScan(permissionAccess: PermissionEvaluation) {
        self.permissionAccess = permissionAccess
        self.scanState = .scanning
        self.plan = nil
        self.selectedTargetIDs = []
    }

    func apply(plan: CategoryPlan) {
        self.plan = plan
        self.scanState = .finished
        if !isSelectable {
            selectedTargetIDs = []
        }
    }

    func finishWithoutPlan() {
        self.scanState = .finished
        self.plan = nil
        self.selectedTargetIDs = []
    }

    func clearSelection() {
        selectedTargetIDs.removeAll()
    }

    func toggleAllSelection() {
        setAllSelected(checkboxState != .on)
    }

    func setAllSelected(_ isSelected: Bool) {
        guard isSelectable else {
            selectedTargetIDs.removeAll()
            return
        }

        selectedTargetIDs = isSelected ? Set(allTargets.map(\.id)) : []
    }

    func isTargetSelected(_ targetID: String) -> Bool {
        selectedTargetIDs.contains(targetID)
    }

    func selectionState(for targetID: String) -> CheckboxState {
        isTargetSelected(targetID) ? .on : .off
    }

    func setTargetSelected(_ targetID: String, isSelected: Bool) {
        guard allTargets.contains(where: { $0.id == targetID }) else {
            return
        }

        if isSelected {
            selectedTargetIDs.insert(targetID)
        } else {
            selectedTargetIDs.remove(targetID)
        }
    }

    func selectedPlan() -> CategoryPlan? {
        plan?.filteringTargets(to: selectedTargetIDs)
    }
}
