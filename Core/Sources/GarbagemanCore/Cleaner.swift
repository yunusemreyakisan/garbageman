import Foundation

struct Cleaner {
    let configuration: AppConfiguration
    let fileManager: FileManager
    let commandRunner: any CommandRunning
    let safetyPolicy: SafetyPolicy

    func clean(
        categories: inout [CategoryPlan],
        confirmationHandler: ((ConfirmationRequest) -> Bool)? = nil,
        progressHandler: ((CleanupProgress) -> Void)? = nil
    ) -> [String] {
        var errors: [String] = []
        let totalTargets = categories
            .filter { $0.status == .ready }
            .flatMap(\.groups)
            .reduce(0) { $0 + $1.targets.count }
        var completedTargets = 0

        func emitProgress(_ description: String) {
            progressHandler?(
                CleanupProgress(
                    completedUnitCount: completedTargets,
                    totalUnitCount: totalTargets,
                    currentDescription: description
                )
            )
        }

        for categoryIndex in categories.indices {
            guard categories[categoryIndex].status == .ready else {
                continue
            }

            for groupIndex in categories[categoryIndex].groups.indices {
                let group = categories[categoryIndex].groups[groupIndex]
                guard !group.targets.isEmpty else {
                    continue
                }

                let shouldProceed: Bool
                if group.confirmationStyle == .category {
                    if group.riskLevel == .safe && configuration.yesSafe {
                        shouldProceed = true
                    } else if let confirmationHandler {
                        shouldProceed = confirmationHandler(
                            ConfirmationRequest(
                                scope: .category,
                                categoryID: categories[categoryIndex].id,
                                groupID: group.id,
                                targetID: nil,
                                message: "Delete \(group.displayName) (\(humanBytes(group.totalBytes)))? [y/N]: ",
                                defaultValue: false
                            )
                        )
                    } else {
                        shouldProceed = true
                    }
                } else {
                    shouldProceed = true
                }

                guard shouldProceed else {
                    completedTargets += group.targets.count
                    emitProgress("Skipped \(group.displayName)")
                    continue
                }

                emitProgress("Cleaning: \(group.displayName)")
                var freedBytes: Int64 = 0

                for target in group.targets {
                    if group.confirmationStyle == .item, let confirmationHandler {
                        let shouldDeleteItem = confirmationHandler(
                            ConfirmationRequest(
                                scope: .item,
                                categoryID: categories[categoryIndex].id,
                                groupID: group.id,
                                targetID: target.id,
                                message: itemPrompt(for: target),
                                defaultValue: false
                            )
                        )

                        guard shouldDeleteItem else {
                            completedTargets += 1
                            emitProgress("Skipped \(target.displayName)")
                            continue
                        }
                    }

                    switch target.kind {
                    case .fileSystemPath:
                        guard let absolutePath = target.absolutePath else {
                            errors.append("Missing path for \(target.displayName).")
                            completedTargets += 1
                            emitProgress("Skipping \(target.displayName) (missing path)")
                            continue
                        }

                        let decision = safetyPolicy.evaluate(path: absolutePath, allowedRoots: categories[categoryIndex].allowedRoots)
                        guard decision.allowed else {
                            errors.append("Refused to delete \(absolutePath): \(decision.reason ?? "safety policy rejected it").")
                            completedTargets += 1
                            emitProgress("Skipping \(target.displayName) (safety policy)")
                            continue
                        }

                        guard fileManager.fileExists(atPath: absolutePath) else {
                            completedTargets += 1
                            emitProgress("Skipping \(target.displayName) (already gone)")
                            continue
                        }

                        do {
                            try fileManager.removeItem(atPath: absolutePath)
                            freedBytes += target.bytes
                            completedTargets += 1
                            emitProgress("Deleted \(target.displayPath) (\(humanBytes(target.bytes)))")
                        } catch {
                            errors.append("Failed to delete \(absolutePath): \(error.localizedDescription)")
                            completedTargets += 1
                            emitProgress("Failed \(target.displayPath)")
                        }
                    case .dockerImage:
                        let result = commandRunner.run(executable: "/usr/bin/env", arguments: ["docker", "rmi", target.id])
                        if result.exitCode == 0 {
                            freedBytes += target.bytes
                            completedTargets += 1
                            emitProgress("Deleted docker image \(target.id) (\(humanBytes(target.bytes)))")
                        } else {
                            errors.append("Failed to delete docker image \(target.id): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
                            completedTargets += 1
                            emitProgress("Failed docker image \(target.id)")
                        }
                    }
                }

                categories[categoryIndex].groups[groupIndex].freedBytes = freedBytes
                emitProgress("OK \(group.displayName): \(humanBytes(freedBytes)) freed")
            }
        }

        return errors
    }

    private func itemPrompt(for target: DeletionTarget) -> String {
        var fragments: [String] = []

        if let lastBackupDate = target.metadata["lastBackupDate"], !lastBackupDate.isEmpty {
            fragments.append("last backup \(lastBackupDate)")
        }
        if let runtime = target.metadata["runtime"], !runtime.isEmpty {
            fragments.append(runtime)
        }

        let suffix = fragments.isEmpty ? "" : " [" + fragments.joined(separator: ", ") + "]"
        return "Delete \(target.displayName)\(suffix) (\(humanBytes(target.bytes)))? [y/N]: "
    }
}
