import Foundation

public protocol CommandRunning {
    func run(executable: String, arguments: [String]) -> CommandResult
}

public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(executable: String, arguments: [String]) -> CommandResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }
}

func homeRelativePath(for path: String, homeDirectory: URL) -> String {
    let standardizedHome = homeDirectory.standardizedFileURL.path
    let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

    if standardizedPath == standardizedHome {
        return "~"
    }

    if standardizedPath.hasPrefix(standardizedHome + "/") {
        return "~" + String(standardizedPath.dropFirst(standardizedHome.count))
    }

    return standardizedPath
}

func standardizePath(_ path: String) -> String {
    URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL.path
}

func fileExists(at url: URL, fileManager: FileManager) -> Bool {
    fileManager.fileExists(atPath: url.path)
}

func directoryExists(at url: URL, fileManager: FileManager) -> Bool {
    var isDirectory = ObjCBool(false)
    let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

func immediateContents(of directory: URL, fileManager: FileManager) -> [URL] {
    guard directoryExists(at: directory, fileManager: fileManager) else {
        return []
    }

    do {
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    } catch {
        return []
    }
}

func fileSize(of url: URL, fileManager: FileManager) -> Int64 {
    let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]

    guard let resourceValues = try? url.resourceValues(forKeys: keys) else {
        return 0
    }

    if resourceValues.isDirectory == true {
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        )

        var total: Int64 = 0

        while let child = enumerator?.nextObject() as? URL {
            let values = (try? child.resourceValues(forKeys: keys)) ?? URLResourceValues()
            if values.isDirectory == true {
                continue
            }

            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0)
        }

        return total
    }

    return Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? resourceValues.fileSize ?? 0)
}

func modificationDate(of url: URL) -> Date? {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey])).flatMap(\.contentModificationDate)
}

func plistDictionary(at url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url) else {
        return nil
    }

    let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return propertyList as? [String: Any]
}

public func humanBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
}

func iso8601String(_ date: Date?) -> String? {
    guard let date else {
        return nil
    }

    return ISO8601DateFormatter().string(from: date)
}

func parseHumanSizeToBytes(_ text: String) -> Int64 {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !trimmed.isEmpty else {
        return 0
    }

    let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGTP]?B)"#
    guard
        let regex = try? NSRegularExpression(pattern: pattern),
        let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
        let numberRange = Range(match.range(at: 1), in: trimmed),
        let unitRange = Range(match.range(at: 2), in: trimmed),
        let value = Double(trimmed[numberRange])
    else {
        return 0
    }

    let unit = String(trimmed[unitRange])
    let multiplier: Double

    switch unit {
    case "KB":
        multiplier = 1_000
    case "MB":
        multiplier = 1_000_000
    case "GB":
        multiplier = 1_000_000_000
    case "TB":
        multiplier = 1_000_000_000_000
    default:
        multiplier = 1
    }

    return Int64(value * multiplier)
}
