import Foundation

struct AndroidCategory: CleanupCategory {
    let id: CategoryID = .android
    let displayName = "Android Emulator Snapshots"
    let permissionRequirement: PermissionRequirement = .none

    func scan(using context: ScanContext) -> CategoryPlan {
        let avdRoot = context.homeDirectory.appendingPathComponent(".android/avd")
        let targets = immediateContents(of: avdRoot, fileManager: context.fileManager)
            .filter { $0.pathExtension == "avd" && directoryExists(at: $0, fileManager: context.fileManager) }
            .compactMap { avdURL -> DeletionTarget? in
                let snapshotsURL = avdURL.appendingPathComponent("snapshots")
                guard directoryExists(at: snapshotsURL, fileManager: context.fileManager) else {
                    return nil
                }

                let bytes = fileSize(of: snapshotsURL, fileManager: context.fileManager)
                guard bytes > 0 || !immediateContents(of: snapshotsURL, fileManager: context.fileManager).isEmpty else {
                    return nil
                }

                let emulatorName = avdURL.deletingPathExtension().lastPathComponent
                return DeletionTarget(
                    id: snapshotsURL.path,
                    displayName: "\(emulatorName) snapshots",
                    displayPath: homeRelativePath(for: snapshotsURL.path, homeDirectory: context.homeDirectory),
                    absolutePath: snapshotsURL.path,
                    kind: .fileSystemPath,
                    bytes: bytes,
                    modifiedAt: modificationDate(of: snapshotsURL),
                    metadata: ["emulator": emulatorName]
                )
            }
            .sorted { $0.bytes > $1.bytes }

        let groups = targets.isEmpty
            ? []
            : [
                DeletionGroup(
                    id: id.rawValue,
                    displayName: displayName,
                    riskLevel: .safe,
                    confirmationStyle: .category,
                    note: nil,
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
            allowedRoots: [avdRoot.path]
        )
    }
}
