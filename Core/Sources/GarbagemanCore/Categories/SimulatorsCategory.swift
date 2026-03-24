import Foundation

struct SimulatorsCategory: CleanupCategory {
    let id: CategoryID = .simulators
    let displayName = "iOS Simulator Devices"
    let permissionRequirement: PermissionRequirement = .none

    func scan(using context: ScanContext) -> CategoryPlan {
        let root = context.homeDirectory.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        let targets = immediateContents(of: root, fileManager: context.fileManager)
            .filter { directoryExists(at: $0, fileManager: context.fileManager) }
            .map { deviceURL in
                let info = plistDictionary(at: deviceURL.appendingPathComponent("device.plist")) ?? [:]
                let name = (info["name"] as? String) ?? deviceURL.lastPathComponent
                let runtime = humanRuntimeName(info["runtime"] as? String)
                let title = runtime.isEmpty ? name : "\(runtime) / \(name)"

                var metadata: [String: String] = [:]
                if !runtime.isEmpty {
                    metadata["runtime"] = runtime
                }
                metadata["deviceName"] = name

                return DeletionTarget(
                    id: deviceURL.path,
                    displayName: title,
                    displayPath: homeRelativePath(for: deviceURL.path, homeDirectory: context.homeDirectory),
                    absolutePath: deviceURL.path,
                    kind: .fileSystemPath,
                    bytes: fileSize(of: deviceURL, fileManager: context.fileManager),
                    modifiedAt: modificationDate(of: deviceURL),
                    metadata: metadata
                )
            }
            .sorted { $0.bytes > $1.bytes }

        let groupedTargets = Dictionary(grouping: targets) { target in
            let runtime = target.metadata["runtime"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return runtime.isEmpty ? "Unknown Runtime" : runtime
        }

        let groups = groupedTargets.map { runtime, runtimeTargets in
            let sortedTargets = runtimeTargets.sorted { lhs, rhs in
                if lhs.bytes == rhs.bytes {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.bytes > rhs.bytes
            }

            return DeletionGroup(
                id: "runtime-\(slugifiedRuntimeName(runtime))",
                displayName: "\(runtime) Simulators",
                riskLevel: .risky,
                confirmationStyle: .category,
                note: "Includes \(sortedTargets.count) device(s).",
                targets: sortedTargets
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalBytes == rhs.totalBytes {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.totalBytes > rhs.totalBytes
        }

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

    private func humanRuntimeName(_ runtimeIdentifier: String?) -> String {
        guard let runtimeIdentifier, !runtimeIdentifier.isEmpty else {
            return ""
        }

        let trimmed = runtimeIdentifier.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        let parts = trimmed.split(separator: "-")
        guard let first = parts.first else {
            return trimmed
        }

        let platform = String(first)
        let version = parts.dropFirst().joined(separator: ".")
        switch platform {
        case let value where value.lowercased().hasPrefix("ios"):
            return version.isEmpty ? "iOS" : "iOS \(version)"
        case let value where value.lowercased().hasPrefix("watchos"):
            return version.isEmpty ? "watchOS" : "watchOS \(version)"
        case let value where value.lowercased().hasPrefix("tvos"):
            return version.isEmpty ? "tvOS" : "tvOS \(version)"
        default:
            return trimmed.replacingOccurrences(of: "-", with: " ")
        }
    }

    private func slugifiedRuntimeName(_ runtime: String) -> String {
        let lowered = runtime.lowercased()
        let replaced = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }

        let slug = String(replaced)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return slug.isEmpty ? "unknown-runtime" : slug
    }
}
