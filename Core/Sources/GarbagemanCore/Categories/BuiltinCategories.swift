import Foundation

enum CategoryFactory {
    static func allCategories() -> [CleanupCategory] {
        [
            GenericDirectoryCategory(
                id: .caches,
                displayName: "User Caches",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent("Library/Caches"))
                }
            ),
            GenericDirectoryCategory(
                id: .logs,
                displayName: "System Logs",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent("Library/Logs"))
                }
            ),
            GenericDirectoryCategory(
                id: .trash,
                displayName: "Trash",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent(".Trash"))
                }
            ),
            XcodeCategory(),
            SimulatorsCategory(),
            GenericDirectoryCategory(
                id: .brew,
                displayName: "Homebrew Cache",
                source: { context in
                    let result = context.commandRunner.run(executable: "/opt/homebrew/bin/brew", arguments: ["--cache"])
                    if result.exitCode != 0 {
                        let fallback = context.commandRunner.run(executable: "/usr/local/bin/brew", arguments: ["--cache"])
                        guard fallback.exitCode == 0 else {
                            return .unavailable("Homebrew is not available on this system.")
                        }

                        let path = fallback.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                        return .ready(path.isEmpty ? nil : URL(fileURLWithPath: path))
                    }

                    let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .ready(path.isEmpty ? nil : URL(fileURLWithPath: path))
                }
            ),
            GenericDirectoryCategory(
                id: .npm,
                displayName: "npm Cache",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent(".npm/_cacache"))
                }
            ),
            GenericDirectoryCategory(
                id: .pip,
                displayName: "pip Cache",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent("Library/Caches/pip"))
                }
            ),
            GenericDirectoryCategory(
                id: .yarn,
                displayName: "Yarn Cache",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent("Library/Caches/Yarn"))
                }
            ),
            GenericDirectoryCategory(
                id: .gradle,
                displayName: "Gradle Cache",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent(".gradle/caches"))
                }
            ),
            GenericDirectoryCategory(
                id: .pods,
                displayName: "CocoaPods Cache",
                source: { context in
                    .ready(context.homeDirectory.appendingPathComponent("Library/Caches/CocoaPods"))
                }
            ),
            AndroidCategory(),
            DockerCategory(),
            DownloadsCategory(),
            IOSBackupsCategory(),
        ]
    }
}
