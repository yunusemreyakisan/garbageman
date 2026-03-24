import Foundation

struct Permissions {
    let fileManager: FileManager
    let commandRunner: any CommandRunning
    let homeDirectory: URL

    func evaluate(for categoryIDs: [CategoryID]) -> PermissionsSnapshot {
        let hasFullDiskAccess = checkFullDiskAccess()
        var categoryAccess: [CategoryID: PermissionEvaluation] = [:]

        for categoryID in categoryIDs {
            switch categoryID {
            case .iosBackups:
                let backupsPath = homeDirectory.appendingPathComponent("Library/Application Support/MobileSync/Backup")
                if directoryExists(at: backupsPath, fileManager: fileManager), !hasFullDiskAccess {
                    categoryAccess[categoryID] = .denied
                } else {
                    categoryAccess[categoryID] = .granted
                }
            default:
                categoryAccess[categoryID] = .notNeeded
            }
        }

        return PermissionsSnapshot(fullDiskAccessGranted: hasFullDiskAccess, categoryAccess: categoryAccess)
    }

    func checkFullDiskAccess() -> Bool {
        let tccDatabase = homeDirectory.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        if fileManager.isReadableFile(atPath: tccDatabase.path) {
            return true
        }

        let mobileSyncPath = homeDirectory.appendingPathComponent("Library/Application Support/MobileSync")
        if directoryExists(at: mobileSyncPath, fileManager: fileManager) {
            return fileManager.isReadableFile(atPath: mobileSyncPath.path)
        }

        return false
    }

    func openFullDiskAccessSettings() {
        _ = commandRunner.run(
            executable: "/usr/bin/open",
            arguments: ["x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]
        )
    }
}
