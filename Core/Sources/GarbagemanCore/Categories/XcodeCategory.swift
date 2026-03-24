import Foundation

struct XcodeCategory: CleanupCategory {
    let id: CategoryID = .xcode
    let displayName = "Xcode Build Artifacts"
    let permissionRequirement: PermissionRequirement = .none

    func scan(using context: ScanContext) -> CategoryPlan {
        let derivedDataRoot = context.homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        let archivesRoot = context.homeDirectory.appendingPathComponent("Library/Developer/Xcode/Archives")
        var groups: [DeletionGroup] = []

        let derivedDataTargets = immediateContents(of: derivedDataRoot, fileManager: context.fileManager).map { url in
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
        .sorted { $0.bytes > $1.bytes }

        if !derivedDataTargets.isEmpty {
            groups.append(
                DeletionGroup(
                    id: "derived-data",
                    displayName: "Xcode DerivedData",
                    riskLevel: .safe,
                    confirmationStyle: .category,
                    note: nil,
                    targets: derivedDataTargets
                )
            )
        }

        var archiveTargets: [DeletionTarget] = []
        for dateDirectory in immediateContents(of: archivesRoot, fileManager: context.fileManager) {
            archiveTargets.append(contentsOf:
                contentsOfArchiveDirectory(dateDirectory, context: context)
            )
        }

        let sortedArchives = archiveTargets.sorted { lhs, rhs in
            let lhsDate = lhs.modifiedAt ?? .distantPast
            let rhsDate = rhs.modifiedAt ?? .distantPast
            return lhsDate > rhsDate
        }

        let keepCount = max(0, context.configuration.keepLastArchives)
        let deletableArchives = keepCount >= sortedArchives.count ? [] : Array(sortedArchives.dropFirst(keepCount))

        if !deletableArchives.isEmpty {
            groups.append(
                DeletionGroup(
                    id: "archives",
                    displayName: "Xcode Archives",
                    riskLevel: .risky,
                    confirmationStyle: .category,
                    note: "Keeping the newest \(keepCount) archive(s).",
                    targets: deletableArchives
                )
            )
        }

        return CategoryPlan(
            id: id,
            displayName: displayName,
            permissionRequirement: permissionRequirement,
            status: .ready,
            note: nil,
            groups: groups,
            allowedRoots: [derivedDataRoot.path, archivesRoot.path]
        )
    }

    private func contentsOfArchiveDirectory(_ dateDirectory: URL, context: ScanContext) -> [DeletionTarget] {
        immediateContents(of: dateDirectory, fileManager: context.fileManager)
            .filter { $0.pathExtension == "xcarchive" }
            .map { archiveURL in
                DeletionTarget(
                    id: archiveURL.path,
                    displayName: archiveURL.deletingPathExtension().lastPathComponent,
                    displayPath: homeRelativePath(for: archiveURL.path, homeDirectory: context.homeDirectory),
                    absolutePath: archiveURL.path,
                    kind: .fileSystemPath,
                    bytes: fileSize(of: archiveURL, fileManager: context.fileManager),
                    modifiedAt: modificationDate(of: archiveURL),
                    metadata: [:]
                )
            }
    }
}
