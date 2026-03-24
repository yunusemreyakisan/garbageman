import Foundation

public enum CategoryID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case caches
    case logs
    case trash
    case xcode
    case simulators
    case brew
    case npm
    case pip
    case yarn
    case gradle
    case pods
    case android
    case docker
    case downloads
    case iosBackups = "ios-backups"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .caches:
            return "User Caches"
        case .logs:
            return "System Logs"
        case .trash:
            return "Trash"
        case .xcode:
            return "Xcode Build Artifacts"
        case .simulators:
            return "iOS Simulator Devices"
        case .brew:
            return "Homebrew Cache"
        case .npm:
            return "npm Cache"
        case .pip:
            return "pip Cache"
        case .yarn:
            return "Yarn Cache"
        case .gradle:
            return "Gradle Cache"
        case .pods:
            return "CocoaPods Cache"
        case .android:
            return "Android Emulator Snapshots"
        case .docker:
            return "Docker Dangling Images"
        case .downloads:
            return "Old Downloads"
        case .iosBackups:
            return "iOS Device Backups"
        }
    }
}

public enum RunMode: String, Sendable {
    case dryRun = "dry-run"
    case clean
}

public enum RiskLevel: String, Sendable {
    case safe
    case risky
}

public enum PermissionRequirement: String, Sendable {
    case none
    case fullDiskAccess = "full-disk-access"
}

public enum CategoryStatus: String, Sendable {
    case ready
    case unavailable
    case skipped
}

public enum ConfirmationStyle: String, Sendable {
    case category
    case item
}

public enum TargetKind: String, Sendable {
    case fileSystemPath = "file-system-path"
    case dockerImage = "docker-image"
}

public struct DeletionTarget: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPath: String
    public let absolutePath: String?
    public let kind: TargetKind
    public let bytes: Int64
    public let modifiedAt: Date?
    public let metadata: [String: String]

    public init(
        id: String,
        displayName: String,
        displayPath: String,
        absolutePath: String?,
        kind: TargetKind,
        bytes: Int64,
        modifiedAt: Date?,
        metadata: [String: String]
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPath = displayPath
        self.absolutePath = absolutePath
        self.kind = kind
        self.bytes = bytes
        self.modifiedAt = modifiedAt
        self.metadata = metadata
    }
}

public struct DeletionGroup: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let riskLevel: RiskLevel
    public let confirmationStyle: ConfirmationStyle
    public var note: String?
    public var targets: [DeletionTarget]
    public var freedBytes: Int64

    public init(
        id: String,
        displayName: String,
        riskLevel: RiskLevel,
        confirmationStyle: ConfirmationStyle,
        note: String?,
        targets: [DeletionTarget],
        freedBytes: Int64 = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.riskLevel = riskLevel
        self.confirmationStyle = confirmationStyle
        self.note = note
        self.targets = targets
        self.freedBytes = freedBytes
    }

    public var totalBytes: Int64 {
        targets.reduce(0) { $0 + $1.bytes }
    }
}

public struct CategoryPlan: Identifiable, Sendable {
    public let id: CategoryID
    public let displayName: String
    public let permissionRequirement: PermissionRequirement
    public var status: CategoryStatus
    public var note: String?
    public var groups: [DeletionGroup]
    public var allowedRoots: [String]

    public init(
        id: CategoryID,
        displayName: String,
        permissionRequirement: PermissionRequirement,
        status: CategoryStatus,
        note: String?,
        groups: [DeletionGroup],
        allowedRoots: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.permissionRequirement = permissionRequirement
        self.status = status
        self.note = note
        self.groups = groups
        self.allowedRoots = allowedRoots
    }

    public var totalBytes: Int64 {
        groups.reduce(0) { $0 + $1.totalBytes }
    }

    public var freedBytes: Int64 {
        groups.reduce(0) { $0 + $1.freedBytes }
    }

    public var allTargets: [DeletionTarget] {
        groups.flatMap(\.targets)
    }

    public func filteringTargets(to selectedTargetIDs: Set<String>) -> CategoryPlan? {
        guard status == .ready else {
            return nil
        }

        let filteredGroups = groups.compactMap { group -> DeletionGroup? in
            var group = group
            group.targets = group.targets.filter { selectedTargetIDs.contains($0.id) }
            group.freedBytes = 0
            return group.targets.isEmpty ? nil : group
        }

        guard !filteredGroups.isEmpty else {
            return nil
        }

        var plan = self
        plan.groups = filteredGroups
        return plan
    }
}

public struct AppConfiguration: Sendable {
    public let clean: Bool
    public let summary: Bool
    public let json: Bool
    public let verbose: Bool
    public let onlyCategories: Set<CategoryID>?
    public let skippedCategories: Set<CategoryID>
    public let downloadsOlderThanDays: Int
    public let keepLastArchives: Int
    public let yesSafe: Bool

    public init(
        clean: Bool,
        summary: Bool,
        json: Bool,
        verbose: Bool,
        onlyCategories: Set<CategoryID>?,
        skippedCategories: Set<CategoryID>,
        downloadsOlderThanDays: Int,
        keepLastArchives: Int,
        yesSafe: Bool
    ) {
        self.clean = clean
        self.summary = summary
        self.json = json
        self.verbose = verbose
        self.onlyCategories = onlyCategories
        self.skippedCategories = skippedCategories
        self.downloadsOlderThanDays = downloadsOlderThanDays
        self.keepLastArchives = keepLastArchives
        self.yesSafe = yesSafe
    }

    public var mode: RunMode {
        clean ? .clean : .dryRun
    }

    public func selectedCategoryIDs() -> [CategoryID] {
        let base = onlyCategories ?? Set(CategoryID.allCases)
        let filtered = base.subtracting(skippedCategories)
        return CategoryID.allCases.filter { filtered.contains($0) }
    }
}

struct ScanContext {
    let configuration: AppConfiguration
    let homeDirectory: URL
    let fileManager: FileManager
    let commandRunner: any CommandRunning
    let permissions: PermissionsSnapshot
    let now: Date
}

public enum PermissionEvaluation: String, Sendable {
    case granted
    case denied
    case notNeeded = "not-needed"
}

public struct PermissionsSnapshot: Sendable {
    public let fullDiskAccessGranted: Bool
    public let categoryAccess: [CategoryID: PermissionEvaluation]

    public init(fullDiskAccessGranted: Bool, categoryAccess: [CategoryID: PermissionEvaluation]) {
        self.fullDiskAccessGranted = fullDiskAccessGranted
        self.categoryAccess = categoryAccess
    }

    public func access(for categoryID: CategoryID) -> PermissionEvaluation {
        categoryAccess[categoryID] ?? .notNeeded
    }

    public var deniedCategories: [CategoryID] {
        CategoryID.allCases.filter { categoryAccess[$0] == .denied }
    }
}

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct ScanProgress: Sendable {
    public let categoryID: CategoryID
    public let completedCategoryCount: Int
    public let totalCategoryCount: Int
    public let plan: CategoryPlan

    public init(
        categoryID: CategoryID,
        completedCategoryCount: Int,
        totalCategoryCount: Int,
        plan: CategoryPlan
    ) {
        self.categoryID = categoryID
        self.completedCategoryCount = completedCategoryCount
        self.totalCategoryCount = totalCategoryCount
        self.plan = plan
    }
}

public struct CleanupProgress: Sendable {
    public let completedUnitCount: Int
    public let totalUnitCount: Int
    public let currentDescription: String

    public init(completedUnitCount: Int, totalUnitCount: Int, currentDescription: String) {
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.currentDescription = currentDescription
    }
}

public struct ConfirmationRequest: Sendable {
    public enum Scope: String, Sendable {
        case category
        case item
    }

    public let scope: Scope
    public let categoryID: CategoryID
    public let groupID: String
    public let targetID: String?
    public let message: String
    public let defaultValue: Bool

    public init(
        scope: Scope,
        categoryID: CategoryID,
        groupID: String,
        targetID: String?,
        message: String,
        defaultValue: Bool
    ) {
        self.scope = scope
        self.categoryID = categoryID
        self.groupID = groupID
        self.targetID = targetID
        self.message = message
        self.defaultValue = defaultValue
    }
}
