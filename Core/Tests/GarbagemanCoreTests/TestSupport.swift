import Foundation

@testable import GarbagemanCore

final class StubCommandRunner: CommandRunning {
    var handler: (String, [String]) -> CommandResult

    init(handler: @escaping (String, [String]) -> CommandResult = { _, _ in
        CommandResult(exitCode: 0, stdout: "", stderr: "")
    }) {
        self.handler = handler
    }

    func run(executable: String, arguments: [String]) -> CommandResult {
        handler(executable, arguments)
    }
}

func makeTemporaryHomeDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func createDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func createFile(_ url: URL, size: Int = 16) throws {
    try createDirectory(url.deletingLastPathComponent())
    try Data(repeating: 0x41, count: size).write(to: url)
}

func setModificationDate(_ date: Date, for url: URL) throws {
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}

func writePlistDictionary(_ dictionary: [String: Any], to url: URL) throws {
    try createDirectory(url.deletingLastPathComponent())
    let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
    try data.write(to: url)
}
