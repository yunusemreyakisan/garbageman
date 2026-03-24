import Foundation

struct SafetyDecision {
    let allowed: Bool
    let reason: String?
}

struct SafetyPolicy {
    let homeDirectory: URL

    private var forbiddenRoots: [String] {
        let home = homeDirectory.standardizedFileURL.path
        return [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/Applications",
            home + "/Applications",
            home + "/Documents",
            home + "/Desktop",
            home + "/Pictures",
            home + "/Movies",
            home + "/Library/Mobile Documents",
            home + "/Library/Keychains",
            home + "/Library/Preferences",
            home + "/Library/Mail",
            home + "/Library/Application Support/AddressBook",
        ]
    }

    func evaluate(path: String, allowedRoots: [String]) -> SafetyDecision {
        let candidate = URL(fileURLWithPath: standardizePath(path)).resolvingSymlinksInPath().standardizedFileURL.path
        let normalizedAllowedRoots = allowedRoots.map { URL(fileURLWithPath: standardizePath($0)).resolvingSymlinksInPath().standardizedFileURL.path }

        if normalizedAllowedRoots.isEmpty {
            return SafetyDecision(allowed: false, reason: "No approved cleanup roots were configured for this category.")
        }

        if let forbidden = forbiddenRoots.first(where: { isSameOrDescendant(candidate, of: $0) }) {
            return SafetyDecision(allowed: false, reason: "Path is inside forbidden root \(forbidden).")
        }

        for root in normalizedAllowedRoots {
            if candidate == root {
                return SafetyDecision(allowed: false, reason: "Refusing to delete the category root itself.")
            }

            if isSameOrDescendant(candidate, of: root) {
                return SafetyDecision(allowed: true, reason: nil)
            }
        }

        return SafetyDecision(allowed: false, reason: "Path is outside the approved cleanup roots.")
    }

    func isSafeToDelete(_ path: String, allowedRoots: [String]) -> Bool {
        evaluate(path: path, allowedRoots: allowedRoots).allowed
    }

    private func isSameOrDescendant(_ path: String, of root: String) -> Bool {
        let normalizedRoot = root.hasSuffix("/") ? String(root.dropLast()) : root
        return path == normalizedRoot || path.hasPrefix(normalizedRoot + "/")
    }
}
