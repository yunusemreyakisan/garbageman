import Foundation

public struct CleanupEngine {
    private let fileManager: FileManager
    private let commandRunner: any CommandRunning
    private let homeDirectory: URL
    private let scanner: Scanner

    public init(
        fileManager: FileManager = .default,
        commandRunner: any CommandRunning = ProcessRunner(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
        self.homeDirectory = homeDirectory
        self.scanner = Scanner()
    }

    public func evaluatePermissions(for categoryIDs: [CategoryID]) -> PermissionsSnapshot {
        permissions().evaluate(for: categoryIDs)
    }

    public func openFullDiskAccessSettings() {
        permissions().openFullDiskAccessSettings()
    }

    public func scan(
        configuration: AppConfiguration,
        selectedCategoryIDs: [CategoryID]? = nil,
        permissionSnapshot: PermissionsSnapshot? = nil,
        now: Date = Date(),
        progressHandler: ((ScanProgress) -> Void)? = nil
    ) -> [CategoryPlan] {
        let resolvedCategoryIDs = selectedCategoryIDs ?? configuration.selectedCategoryIDs()
        let permissions = permissionSnapshot ?? evaluatePermissions(for: resolvedCategoryIDs)
        let context = ScanContext(
            configuration: configuration,
            homeDirectory: homeDirectory,
            fileManager: fileManager,
            commandRunner: commandRunner,
            permissions: permissions,
            now: now
        )

        return scanner.scan(
            selectedCategoryIDs: resolvedCategoryIDs,
            context: context,
            onCategoryScanned: progressHandler
        )
    }

    public func clean(
        categories: inout [CategoryPlan],
        configuration: AppConfiguration,
        confirmationHandler: ((ConfirmationRequest) -> Bool)? = nil,
        progressHandler: ((CleanupProgress) -> Void)? = nil
    ) -> [String] {
        Cleaner(
            configuration: configuration,
            fileManager: fileManager,
            commandRunner: commandRunner,
            safetyPolicy: SafetyPolicy(homeDirectory: homeDirectory)
        )
        .clean(
            categories: &categories,
            confirmationHandler: confirmationHandler,
            progressHandler: progressHandler
        )
    }

    private func permissions() -> Permissions {
        Permissions(
            fileManager: fileManager,
            commandRunner: commandRunner,
            homeDirectory: homeDirectory
        )
    }
}
