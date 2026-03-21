// Note: no import needed for HelperInstaller — it is compiled directly into this target.
import XCTest
@testable import Clearance

final class ClearanceInstallHelperTests: XCTestCase {

    // MARK: - Destination validation

    func testValidateDestinationRejectsInvalidPath() throws {
        XCTAssertThrowsError(
            try HelperInstaller.validateDestination(URL(fileURLWithPath: "/usr/local/bin/other"))
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .invalidDestination)
        }
    }

    func testValidateDestinationAcceptsCorrectPath() {
        XCTAssertNoThrow(
            try HelperInstaller.validateDestination(
                URL(fileURLWithPath: "/usr/local/bin/clearance")
            )
        )
    }

    // MARK: - Source validation

    func testValidateSourceRejectsPathOutsideBundle() throws {
        let (_, helperPath, _) = try makeBundleFixture()
        // This source is in a completely different temp directory — not inside the bundle
        let outsideSource = try makeFile(named: "clearance")

        XCTAssertThrowsError(
            try HelperInstaller.validateSource(outsideSource, helperExecutablePath: helperPath)
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .sourceOutsideBundle)
        }
    }

    func testValidateSourceAcceptsPathInsideBundle() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateSource(source, helperExecutablePath: helperPath)
        )
    }

    // MARK: - Team ID verification

    func testValidateTeamIDRejectsMismatch() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertThrowsError(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { url in
                    url.lastPathComponent == "clearance" ? "AAAAAA" : "BBBBBB"
                }
            )
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .teamIDMismatch)
        }
    }

    func testValidateTeamIDAcceptsMatchingTeamIDs() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { _ in "SAMETEAM" }
            )
        )
    }

    func testValidateTeamIDAllowsBothUnsigned() throws {
        let (source, helperPath, _) = try makeBundleFixture()

        XCTAssertNoThrow(
            try HelperInstaller.validateTeamID(
                source: source,
                helperExecutablePath: helperPath,
                teamIDExtractor: { _ in nil }
            )
        )
    }

    // MARK: - Symlink creation

    func testCreateSymlinkCreatesSymlink() throws {
        let (source, _, destination) = try makeBundleFixture()

        try HelperInstaller.createSymlink(source: source, destination: destination)

        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(atPath: destination.path),
            source.path
        )
    }

    func testCreateSymlinkRefusesToReplaceExistingRegularFile() throws {
        let (source, _, destination) = try makeBundleFixture()
        try Data().write(to: destination)

        XCTAssertThrowsError(
            try HelperInstaller.createSymlink(source: source, destination: destination)
        ) { error in
            XCTAssertEqual(error as? HelperInstallerError, .installFailed("Destination already exists and is not a symlink."))
        }
    }

    func testCreateSymlinkReplacesExistingSymlink() throws {
        let (source, _, destination) = try makeBundleFixture()
        let oldTarget = try makeFile(named: "old-clearance")
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: oldTarget)

        try HelperInstaller.createSymlink(source: source, destination: destination)

        XCTAssertEqual(
            try FileManager.default.destinationOfSymbolicLink(atPath: destination.path),
            source.path
        )
    }

    // MARK: - Helpers (used by later tasks too)

    private func makeFile(named name: String, in dir: URL? = nil) throws -> URL {
        let directory = dir ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    /// Creates a fake bundle at /tmp/<uuid>/fake.app with a clearance binary inside.
    /// Returns (sourceURL, helperExecutablePath, writableDestinationURL).
    private func makeBundleFixture() throws -> (source: URL, helperPath: String, destination: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let helpersDir = dir.appendingPathComponent("fake.app/Contents/Helpers")
        try FileManager.default.createDirectory(at: helpersDir, withIntermediateDirectories: true)
        let source = helpersDir.appendingPathComponent("clearance")
        try Data().write(to: source)
        let helperPath = helpersDir.appendingPathComponent("ClearanceInstallHelper").path
        let binDir = dir.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        let destination = binDir.appendingPathComponent("clearance")
        return (source, helperPath, destination)
    }
}
