import Foundation

struct DirectoryResolution {
    let url: URL?
    let status: CategoryStatus
    let note: String?

    static func ready(_ url: URL?, note: String? = nil) -> DirectoryResolution {
        DirectoryResolution(url: url, status: .ready, note: note)
    }

    static func unavailable(_ note: String) -> DirectoryResolution {
        DirectoryResolution(url: nil, status: .unavailable, note: note)
    }
}

struct GenericDirectoryCategory: CleanupCategory {
    let id: CategoryID
    let displayName: String
    let permissionRequirement: PermissionRequirement
    let source: (ScanContext) -> DirectoryResolution

    init(
        id: CategoryID,
        displayName: String,
        permissionRequirement: PermissionRequirement = .none,
        source: @escaping (ScanContext) -> DirectoryResolution
    ) {
        self.id = id
        self.displayName = displayName
        self.permissionRequirement = permissionRequirement
        self.source = source
    }

    func scan(using context: ScanContext) -> CategoryPlan {
        if context.permissions.access(for: id) == .denied {
            return CategoryPlan(
                id: id,
                displayName: displayName,
                permissionRequirement: permissionRequirement,
                status: .unavailable,
                note: "Full Disk Access is required for this category.",
                groups: [],
                allowedRoots: []
            )
        }

        let resolution = source(context)
        guard resolution.status == .ready else {
            return CategoryPlan(
                id: id,
                displayName: displayName,
                permissionRequirement: permissionRequirement,
                status: resolution.status,
                note: resolution.note,
                groups: [],
                allowedRoots: []
            )
        }

        guard let root = resolution.url else {
            return CategoryPlan(
                id: id,
                displayName: displayName,
                permissionRequirement: permissionRequirement,
                status: .ready,
                note: resolution.note,
                groups: [],
                allowedRoots: []
            )
        }

        let targets = immediateContents(of: root, fileManager: context.fileManager).map { url in
            DeletionTarget(
                id: url.path,
                displayName: url.lastPathComponent,
                displayPath: homeRelativePath(for: url.path, homeDirectory: context.homeDirectory),
                absolutePath: url.path,
                kind: .fileSystemPath,
                bytes: fileSize(of: url, fileManager: context.fileManager),
                modifiedAt: modificationDate(of: url),
                metadata: [:]
            )
        }
        .sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.bytes > rhs.bytes
        }

        let groups = targets.isEmpty
            ? []
            : [
                DeletionGroup(
                    id: id.rawValue,
                    displayName: displayName,
                    riskLevel: .safe,
                    confirmationStyle: .category,
                    note: resolution.note,
                    targets: targets
                ),
            ]

        return CategoryPlan(
            id: id,
            displayName: displayName,
            permissionRequirement: permissionRequirement,
            status: .ready,
            note: resolution.note,
            groups: groups,
            allowedRoots: [root.path]
        )
    }
}
