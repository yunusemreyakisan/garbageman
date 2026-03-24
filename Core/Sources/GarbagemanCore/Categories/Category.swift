import Foundation

protocol CleanupCategory {
    var id: CategoryID { get }
    var displayName: String { get }
    var permissionRequirement: PermissionRequirement { get }
    func scan(using context: ScanContext) -> CategoryPlan
}
