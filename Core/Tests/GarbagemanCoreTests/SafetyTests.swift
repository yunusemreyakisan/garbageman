import Foundation
import XCTest

@testable import GarbagemanCore

final class SafetyTests: XCTestCase {
    func testNeverDeletesForbiddenRoots() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let policy = SafetyPolicy(homeDirectory: home)
        let allowedRoots = [home.appendingPathComponent("Library/Caches").path]

        XCTAssertFalse(policy.isSafeToDelete("/System/Library", allowedRoots: allowedRoots))
        XCTAssertFalse(policy.isSafeToDelete("/Applications/Safari.app", allowedRoots: allowedRoots))
        XCTAssertFalse(policy.isSafeToDelete(home.appendingPathComponent("Documents/file.txt").path, allowedRoots: allowedRoots))
        XCTAssertFalse(policy.isSafeToDelete(home.appendingPathComponent("Desktop/file.txt").path, allowedRoots: allowedRoots))
        XCTAssertFalse(policy.isSafeToDelete(home.appendingPathComponent("Library/Preferences/com.example.plist").path, allowedRoots: allowedRoots))
        XCTAssertFalse(policy.isSafeToDelete(home.appendingPathComponent("Library/Keychains/login.keychain-db").path, allowedRoots: allowedRoots))
    }

    func testOnlyDeletesApprovedPaths() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let policy = SafetyPolicy(homeDirectory: home)
        let allowedRoots = [
            home.appendingPathComponent("Library/Caches").path,
            home.appendingPathComponent(".Trash").path,
        ]

        XCTAssertTrue(policy.isSafeToDelete(home.appendingPathComponent("Library/Caches/com.test.app").path, allowedRoots: allowedRoots))
        XCTAssertTrue(policy.isSafeToDelete(home.appendingPathComponent(".Trash/file.txt").path, allowedRoots: allowedRoots))
    }

    func testRejectsSymlinkEscapes() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let allowedRoot = home.appendingPathComponent("Library/Caches")
        let forbiddenRoot = home.appendingPathComponent("Documents")
        try createDirectory(allowedRoot)
        try createDirectory(forbiddenRoot)
        try createFile(forbiddenRoot.appendingPathComponent("secret.txt"))

        let linkPath = allowedRoot.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(atPath: linkPath.path, withDestinationPath: forbiddenRoot.appendingPathComponent("secret.txt").path)

        let policy = SafetyPolicy(homeDirectory: home)
        XCTAssertFalse(policy.isSafeToDelete(linkPath.path, allowedRoots: [allowedRoot.path]))
    }

    func testRejectsDeletingCategoryRoot() throws {
        let home = try makeTemporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: home) }

        let allowedRoot = home.appendingPathComponent("Library/Caches")
        try createDirectory(allowedRoot)

        let policy = SafetyPolicy(homeDirectory: home)
        XCTAssertFalse(policy.isSafeToDelete(allowedRoot.path, allowedRoots: [allowedRoot.path]))
    }
}
