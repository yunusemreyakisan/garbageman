import Foundation

struct DownloadsCategory: CleanupCategory {
    let id: CategoryID = .downloads
    let displayName = "Old Downloads"
    let permissionRequirement: PermissionRequirement = .none

    func scan(using context: ScanContext) -> CategoryPlan {
        let root = context.homeDirectory.appendingPathComponent("Downloads")
        let threshold = context.now.addingTimeInterval(TimeInterval(-86_400 * max(0, context.configuration.downloadsOlderThanDays)))
        let targets = immediateContents(of: root, fileManager: context.fileManager)
            .filter { url in
                let values = (try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])) ?? URLResourceValues()
                guard values.isDirectory != true else {
                    return false
                }

                guard let modified = values.contentModificationDate else {
                    return false
                }

                return modified < threshold
            }
            .map { url in
                DeletionTarget(
                    id: url.path,
                    displayName: url.lastPathComponent,
                    displayPath: homeRelativePath(for: url.path, homeDirectory: context.homeDirectory),
                    absolutePath: url.path,
                    kind: .fileSystemPath,
                    bytes: fileSize(of: url, fileManager: context.fileManager),
                    modifiedAt: modificationDate(of: url),
                    metadata: [
                        "olderThanDays": String(context.configuration.downloadsOlderThanDays),
                    ]
                )
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.modifiedAt ?? .distantFuture
                let rhsDate = rhs.modifiedAt ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhsDate < rhsDate
            }

        let groups = targets.isEmpty
            ? []
            : [
                DeletionGroup(
                    id: id.rawValue,
                    displayName: displayName,
                    riskLevel: .risky,
                    confirmationStyle: .item,
                    note: "Only direct files older than \(context.configuration.downloadsOlderThanDays) days are included.",
                    targets: targets
                ),
            ]

        return CategoryPlan(
            id: id,
            displayName: displayName,
            permissionRequirement: permissionRequirement,
            status: .ready,
            note: nil,
            groups: groups,
            allowedRoots: [root.path]
        )
    }
}
