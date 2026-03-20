import XCTest
@testable import Clearance

final class ClearanceCommandLineInstallerTests: XCTestCase {
    func testInstallCreatesSymlinkToHelperExecutable() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installURL = try makeDirectory().appending(path: "bin/clearance")

        try ClearanceCommandLineToolInstaller.install(helperExecutableURL: helperURL, at: installURL)

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: installURL.path), helperURL.path)
    }

    func testInstallReplacesExistingSymlink() throws {
        let directoryURL = try makeDirectory()
        let oldHelperURL = try makeExecutable(named: "old-clearance")
        let newHelperURL = try makeExecutable(named: "new-clearance")
        let installURL = directoryURL.appending(path: "bin/clearance")
        try FileManager.default.createDirectory(at: installURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: installURL, withDestinationURL: oldHelperURL)

        try ClearanceCommandLineToolInstaller.install(helperExecutableURL: newHelperURL, at: installURL)

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: installURL.path), newHelperURL.path)
    }

    func testInstallRefusesToReplaceExistingRegularFile() throws {
        let helperURL = try makeExecutable(named: "clearance")
        let installURL = try makeDirectory().appending(path: "bin/clearance")
        try FileManager.default.createDirectory(at: installURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: installURL)

        XCTAssertThrowsError(
            try ClearanceCommandLineToolInstaller.install(helperExecutableURL: helperURL, at: installURL)
        ) { error in
            XCTAssertEqual(
                error as? ClearanceCommandLineToolInstallerError,
                .existingInstallIsNotASymlink(installURL)
            )
        }
    }

    private func makeExecutable(named name: String) throws -> URL {
        let url = try makeDirectory().appending(path: name)
        try Data().write(to: url)
        return url
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
