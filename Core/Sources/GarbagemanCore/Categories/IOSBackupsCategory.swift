import Foundation

struct IOSBackupsCategory: CleanupCategory {
    let id: CategoryID = .iosBackups
    let displayName = "iOS Device Backups"
    let permissionRequirement: PermissionRequirement = .fullDiskAccess

    func scan(using context: ScanContext) -> CategoryPlan {
        if context.permissions.access(for: id) == .denied {
            return CategoryPlan(
                id: id,
                displayName: displayName,
                permissionRequirement: permissionRequirement,
                status: .unavailable,
                note: "Full Disk Access is required to inspect MobileSync backups.",
                groups: [],
                allowedRoots: []
            )
        }

        let root = context.homeDirectory.appendingPathComponent("Library/Application Support/MobileSync/Backup")
        let targets = immediateContents(of: root, fileManager: context.fileManager)
            .filter { directoryExists(at: $0, fileManager: context.fileManager) }
            .map { backupURL in
                let info = plistDictionary(at: backupURL.appendingPathComponent("Info.plist")) ?? [:]
                let deviceName = (info["Device Name"] as? String) ?? backupURL.lastPathComponent
                let productName = (info["Product Name"] as? String) ?? ""
                let modifiedAt = modificationDate(of: backupURL)

                var metadata: [String: String] = [:]
                if !productName.isEmpty {
                    metadata["productName"] = productName
                }
                if let modifiedAt {
                    metadata["lastBackupDate"] = iso8601String(modifiedAt) ?? ""
                }

                let title = productName.isEmpty ? deviceName : "\(deviceName) (\(productName))"
                return DeletionTarget(
                    id: backupURL.path,
                    displayName: title,
                    displayPath: homeRelativePath(for: backupURL.path, homeDirectory: context.homeDirectory),
                    absolutePath: backupURL.path,
                    kind: .fileSystemPath,
                    bytes: fileSize(of: backupURL, fileManager: context.fileManager),
                    modifiedAt: modifiedAt,
                    metadata: metadata
                )
            }
            .sorted { $0.bytes > $1.bytes }

        let groups = targets.isEmpty
            ? []
            : [
                DeletionGroup(
                    id: id.rawValue,
                    displayName: displayName,
                    riskLevel: .risky,
                    confirmationStyle: .item,
                    note: "Review each backup before deleting it.",
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
