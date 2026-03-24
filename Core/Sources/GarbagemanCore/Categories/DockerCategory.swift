import Foundation

struct DockerCategory: CleanupCategory {
    let id: CategoryID = .docker
    let displayName = "Docker Dangling Images"
    let permissionRequirement: PermissionRequirement = .none

    func scan(using context: ScanContext) -> CategoryPlan {
        let result = context.commandRunner.run(
            executable: "/usr/bin/env",
            arguments: ["docker", "images", "--filter", "dangling=true", "--format", "{{json .}}"]
        )

        if result.exitCode != 0 {
            let combinedOutput = (result.stdout + "\n" + result.stderr).lowercased()
            let note = combinedOutput.contains("not found") || combinedOutput.contains("no such file")
                ? "Docker CLI is not available on this system."
                : "Docker is unavailable or the daemon is not running."

            return CategoryPlan(
                id: id,
                displayName: displayName,
                permissionRequirement: permissionRequirement,
                status: .unavailable,
                note: note,
                groups: [],
                allowedRoots: []
            )
        }

        let targets = result.stdout
            .split(separator: "\n")
            .compactMap { line -> DeletionTarget? in
                guard let data = line.data(using: .utf8) else {
                    return nil
                }
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
                }

                let identifier = (object["ID"] as? String) ?? ""
                guard !identifier.isEmpty else {
                    return nil
                }

                let size = (object["Size"] as? String) ?? "0B"
                return DeletionTarget(
                    id: identifier,
                    displayName: "Dangling image \(identifier)",
                    displayPath: identifier,
                    absolutePath: nil,
                    kind: .dockerImage,
                    bytes: parseHumanSizeToBytes(size),
                    modifiedAt: nil,
                    metadata: ["size": size]
                )
            }

        let groups = targets.isEmpty
            ? []
            : [
                DeletionGroup(
                    id: id.rawValue,
                    displayName: displayName,
                    riskLevel: .safe,
                    confirmationStyle: .category,
                    note: "Only untagged dangling images are included.",
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
            allowedRoots: []
        )
    }
}
