# Privileged CLI Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When `/usr/local/bin` is not writable, prompt the user for their admin password and create the `clearance` symlink using a privileged helper binary.

**Architecture:** A new `ClearanceInstallHelper` tool target contains all privileged logic. The main app uses Authorization Services to show an inline auth dialog, then spawns the helper as root via `AuthorizationExecuteWithPrivileges`. The helper validates arguments, verifies code signing Team IDs, and creates the symlink. Success/failure is communicated through stdout (empty = success, message = failure).

**Tech Stack:** Swift 6.0, Foundation, Security framework, Authorization Services (`AuthorizationCreate`, `AuthorizationCopyRights`, `AuthorizationExecuteWithPrivileges`)

**Spec:** `docs/superpowers/specs/2026-03-20-privileged-cli-installer-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `ClearanceInstallHelper/main.swift` | CLI entry point: parse args, call `HelperInstaller`, write errors to stdout |
| Create | `ClearanceInstallHelper/HelperInstaller.swift` | Core logic: validate args, verify Team IDs, create symlink. Compiled directly into the test target too. |
| Create | `ClearanceTests/Services/ClearanceInstallHelperTests.swift` | Unit tests for `HelperInstaller` |
| Modify | `project.yml` | Add `ClearanceInstallHelper` target; add `HelperInstaller.swift` as an explicit source for `ClearanceTests` |
| Modify | `Clearance/Services/ClearanceCommandLineToolInstaller.swift` | Add `PrivilegedRunner` type and privileged fallback |
| Modify | `ClearanceTests/Services/ClearanceCommandLineInstallerTests.swift` | Add tests for privileged path error mapping |

**Note on `HelperInstaller` test access:** `HelperInstaller.swift` is listed as a direct source file for the `ClearanceTests` target in `project.yml` — it is compiled straight into the test bundle. No `import` statement is needed to use `HelperInstaller` in tests; it is simply in scope. The `@testable import Clearance` in the test file imports the main app module for other types; `HelperInstaller` and `HelperInstallerError` are available without any import.

---

## Task 1: Add `ClearanceInstallHelper` target to project.yml

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add the target**

In `project.yml`, add after the `ClearanceCLI` target block and before `ClearanceTests`:

```yaml
  ClearanceInstallHelper:
    type: tool
    platform: macOS
    sources:
      - path: ClearanceInstallHelper
    settings:
      base:
        PRODUCT_NAME: ClearanceInstallHelper
        SWIFT_VERSION: 6.0
        ENABLE_HARDENED_RUNTIME: YES
    dependencies:
      - sdk: Security.framework
```

In the `Clearance` target's `dependencies`, add after the `ClearanceCLI` embed block:

```yaml
      - target: ClearanceInstallHelper
        link: false
        embed: true
        copy:
          destination: wrapper
          subpath: Contents/Helpers
```

In the `ClearanceTests` target, change `sources` to include the shared logic file:

```yaml
    sources:
      - path: ClearanceTests
      - path: ClearanceInstallHelper/HelperInstaller.swift
```

- [ ] **Step 2: Create the source directory and regenerate the project**

```bash
mkdir -p ClearanceInstallHelper
xcodegen generate
```

Expected: `Created project at /path/to/Clearance.xcodeproj`

- [ ] **Step 3: Verify the build succeeds**

```bash
xcodebuild build -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' 2>&1 | grep -E "(BUILD|error:)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add project.yml Clearance.xcodeproj/project.pbxproj
git commit -m "Add ClearanceInstallHelper target to project"
```

---

## Task 2: `HelperInstaller` — skeleton and destination validation (TDD)

**Files:**
- Create: `ClearanceInstallHelper/HelperInstaller.swift`
- Create: `ClearanceTests/Services/ClearanceInstallHelperTests.swift`

- [ ] **Step 1: Create a minimal `HelperInstaller.swift` stub — no implementation yet**

```swift
// ClearanceInstallHelper/HelperInstaller.swift
import Foundation
import Security

enum HelperInstallerError: LocalizedError, Equatable {
    case invalidDestination
    case sourceOutsideBundle
    case teamIDMismatch
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination:
            return "Destination must be /usr/local/bin/clearance."
        case .sourceOutsideBundle:
            return "Source binary is not inside the app bundle."
        case .teamIDMismatch:
            return "Source binary is not signed by the same developer as this helper."
        case .installFailed(let message):
            return message
        }
    }
}

enum HelperInstaller {
    typealias TeamIDExtractor = (URL) -> String?

    static func install(
        source: URL,
        destination: URL,
        helperExecutablePath: String = CommandLine.arguments[0],
        teamIDExtractor: TeamIDExtractor = HelperInstaller.teamID(forURL:)
    ) throws {
        // TODO
    }

    static func validateDestination(_ url: URL) throws {
        // TODO
    }

    static func validateSource(_ source: URL, helperExecutablePath: String) throws {
        // TODO
    }

    static func validateTeamID(
        source: URL,
        helperExecutablePath: String,
        teamIDExtractor: TeamIDExtractor
    ) throws {
        // TODO
    }

    static func createSymlink(source: URL, destination: URL) throws {
        // TODO
    }

    static func teamID(forURL url: URL) -> String? {
        // TODO
        return nil
    }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
// ClearanceTests/Services/ClearanceInstallHelperTests.swift
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
    func makeBundleFixture() throws -> (source: URL, helperPath: String, destination: URL) {
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
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests 2>&1 | grep -E "(passed|failed|error:)"
```

Expected: Both destination tests FAIL (the TODO stubs don't throw or validate anything).

- [ ] **Step 4: Implement `validateDestination`**

```swift
static func validateDestination(_ url: URL) throws {
    guard url.path == "/usr/local/bin/clearance" else {
        throw HelperInstallerError.invalidDestination
    }
}
```

Also wire it into `install`:

```swift
static func install(
    source: URL,
    destination: URL,
    helperExecutablePath: String = CommandLine.arguments[0],
    teamIDExtractor: TeamIDExtractor = HelperInstaller.teamID(forURL:)
) throws {
    try validateDestination(destination)
}
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests 2>&1 | grep -E "(passed|failed)"
```

Expected: Both destination tests PASS.

- [ ] **Step 6: Commit**

```bash
git add ClearanceInstallHelper/HelperInstaller.swift ClearanceTests/Services/ClearanceInstallHelperTests.swift
git commit -m "Add HelperInstaller skeleton and destination validation"
```

---

## Task 3: `HelperInstaller` — source path validation

**Files:**
- Modify: `ClearanceInstallHelper/HelperInstaller.swift`
- Modify: `ClearanceTests/Services/ClearanceInstallHelperTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `ClearanceInstallHelperTests`:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests/testValidateSourceRejectsPathOutsideBundle 2>&1 | grep -E "(passed|failed)"
```

Expected: FAILED

- [ ] **Step 3: Implement `validateSource`**

```swift
static func validateSource(_ source: URL, helperExecutablePath: String) throws {
    let helperURL = URL(fileURLWithPath: helperExecutablePath)
    let bundleRoot = helperURL
        .deletingLastPathComponent() // Helpers
        .deletingLastPathComponent() // Contents
        .deletingLastPathComponent() // bundle root

    let bundlePrefix = bundleRoot.path + "/"
    guard source.path.hasPrefix(bundlePrefix),
          FileManager.default.isReadableFile(atPath: source.path) else {
        throw HelperInstallerError.sourceOutsideBundle
    }
}
```

Wire into `install`:

```swift
static func install(...) throws {
    try validateDestination(destination)
    try validateSource(source, helperExecutablePath: helperExecutablePath)
}
```

- [ ] **Step 4: Run all helper tests**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests 2>&1 | grep -E "(passed|failed)"
```

Expected: All passing.

- [ ] **Step 5: Commit**

```bash
git add ClearanceInstallHelper/HelperInstaller.swift ClearanceTests/Services/ClearanceInstallHelperTests.swift
git commit -m "Add source path validation to HelperInstaller"
```

---

## Task 4: `HelperInstaller` — Team ID verification

**Files:**
- Modify: `ClearanceInstallHelper/HelperInstaller.swift`
- Modify: `ClearanceTests/Services/ClearanceInstallHelperTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `ClearanceInstallHelperTests`. The `teamIDExtractor` is injected so tests don't need real signed binaries:

```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests/testValidateTeamIDRejectsMismatch 2>&1 | grep -E "(passed|failed)"
```

Expected: FAILED

- [ ] **Step 3: Implement `validateTeamID` and `teamID(forURL:)`**

```swift
static func validateTeamID(
    source: URL,
    helperExecutablePath: String,
    teamIDExtractor: TeamIDExtractor
) throws {
    let helperURL = URL(fileURLWithPath: helperExecutablePath)
    let helperTeamID = teamIDExtractor(helperURL)
    let sourceTeamID = teamIDExtractor(source)

    // Both unsigned — allow through. If either is signed, they must match.
    if helperTeamID != nil || sourceTeamID != nil {
        guard helperTeamID == sourceTeamID else {
            throw HelperInstallerError.teamIDMismatch
        }
    }
}

static func teamID(forURL url: URL) -> String? {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
          let staticCode else { return nil }
    // SecStaticCode and SecCode share the same CF backing type; unsafeBitCast is
    // the standard workaround since SecCodeCopySigningInformation requires SecCode.
    let code = unsafeBitCast(staticCode, to: SecCode.self)
    var info: CFDictionary?
    guard SecCodeCopySigningInformation(
        code,
        SecCSFlags(rawValue: kSecCSSigningInformation),
        &info
    ) == errSecSuccess,
          let dict = info as? [String: Any] else { return nil }
    return dict[kSecCodeInfoTeamIdentifier as String] as? String
}
```

Wire into `install`:

```swift
static func install(...) throws {
    try validateDestination(destination)
    try validateSource(source, helperExecutablePath: helperExecutablePath)
    try validateTeamID(
        source: source,
        helperExecutablePath: helperExecutablePath,
        teamIDExtractor: teamIDExtractor
    )
}
```

- [ ] **Step 4: Run all helper tests**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests 2>&1 | grep -E "(passed|failed)"
```

Expected: All passing.

- [ ] **Step 5: Commit**

```bash
git add ClearanceInstallHelper/HelperInstaller.swift ClearanceTests/Services/ClearanceInstallHelperTests.swift
git commit -m "Add Team ID verification to HelperInstaller"
```

---

## Task 5: `HelperInstaller` — symlink creation

**Files:**
- Modify: `ClearanceInstallHelper/HelperInstaller.swift`
- Modify: `ClearanceTests/Services/ClearanceInstallHelperTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `ClearanceInstallHelperTests`. These call `createSymlink` directly using the writable temp destination from `makeBundleFixture`:

```swift
// MARK: - Symlink creation

func testCreateSymlinkCreatesSymlink() throws {
    let (source, _, destination) = try makeBundleFixture()

    try HelperInstaller.createSymlink(source: source, destination: destination)

    XCTAssertEqual(
        try FileManager.default.destinationOfSymbolicLink(atPath: destination.path),
        source.path
    )
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests/testCreateSymlinkCreatesSymlink 2>&1 | grep -E "(passed|failed)"
```

Expected: FAILED

- [ ] **Step 3: Implement `createSymlink`**

```swift
static func createSymlink(source: URL, destination: URL) throws {
    let fm = FileManager.default
    if (try? fm.destinationOfSymbolicLink(atPath: destination.path)) != nil {
        try fm.removeItem(at: destination)
    }
    do {
        try fm.createSymbolicLink(at: destination, withDestinationURL: source)
    } catch {
        throw HelperInstallerError.installFailed(error.localizedDescription)
    }
}
```

Wire into `install`:

```swift
static func install(...) throws {
    try validateDestination(destination)
    try validateSource(source, helperExecutablePath: helperExecutablePath)
    try validateTeamID(
        source: source,
        helperExecutablePath: helperExecutablePath,
        teamIDExtractor: teamIDExtractor
    )
    try createSymlink(source: source, destination: destination)
}
```

- [ ] **Step 4: Run all helper tests**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceInstallHelperTests 2>&1 | grep -E "(passed|failed)"
```

Expected: All passing.

- [ ] **Step 5: Commit**

```bash
git add ClearanceInstallHelper/HelperInstaller.swift ClearanceTests/Services/ClearanceInstallHelperTests.swift
git commit -m "Add symlink creation to HelperInstaller"
```

---

## Task 6: `main.swift` — entry point

**Files:**
- Create: `ClearanceInstallHelper/main.swift`

- [ ] **Step 1: Write `main.swift`**

```swift
// ClearanceInstallHelper/main.swift
import Foundation

guard CommandLine.arguments.count == 3 else {
    print("Usage: ClearanceInstallHelper <source> <destination>")
    exit(1)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2])

do {
    try HelperInstaller.install(source: source, destination: destination)
    // Empty stdout on success — the app reads empty pipe as success
} catch {
    print(error.localizedDescription)
    exit(1)
}
```

- [ ] **Step 2: Verify the project builds**

```bash
xcodebuild build -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' 2>&1 | grep -E "(BUILD|error:)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ClearanceInstallHelper/main.swift
git commit -m "Add ClearanceInstallHelper entry point"
```

---

## Task 7: `ClearanceCommandLineToolInstaller` — privileged fallback

**Files:**
- Modify: `Clearance/Services/ClearanceCommandLineToolInstaller.swift`
- Modify: `ClearanceTests/Services/ClearanceCommandLineInstallerTests.swift`

**Note:** `makeDirectory()` already exists in `ClearanceCommandLineInstallerTests`. The new `makeNonWritableDirectory()` helper added below calls it.

- [ ] **Step 1: Write failing tests**

Add to `ClearanceCommandLineInstallerTests`:

```swift
func testPrivilegedInstallIsAttemptedWhenDirectoryNotWritable() throws {
    let helperURL = try makeExecutable(named: "clearance")
    let installDirectoryURL = try makeNonWritableDirectory()
    let installURL = installDirectoryURL.appending(path: "clearance")

    var privilegedRunnerCalled = false
    let runner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _, _ in
        privilegedRunnerCalled = true
    }

    try ClearanceCommandLineToolInstaller.install(
        helperExecutableURL: helperURL,
        at: installURL,
        privilegedRunner: runner
    )

    XCTAssertTrue(privilegedRunnerCalled)
}

func testPrivilegedInstallCancellationIsSilent() throws {
    let helperURL = try makeExecutable(named: "clearance")
    let installDirectoryURL = try makeNonWritableDirectory()
    let installURL = installDirectoryURL.appending(path: "clearance")

    let cancellingRunner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _, _ in
        throw ClearanceCommandLineToolInstallerError.privilegedInstallCancelled
    }

    XCTAssertNoThrow(
        try ClearanceCommandLineToolInstaller.install(
            helperExecutableURL: helperURL,
            at: installURL,
            privilegedRunner: cancellingRunner
        )
    )
}

func testPrivilegedInstallSurfacesHelperError() throws {
    let helperURL = try makeExecutable(named: "clearance")
    let installDirectoryURL = try makeNonWritableDirectory()
    let installURL = installDirectoryURL.appending(path: "clearance")

    let failingRunner = ClearanceCommandLineToolInstaller.PrivilegedRunner { _, _, _ in
        throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed("helper said no")
    }

    XCTAssertThrowsError(
        try ClearanceCommandLineToolInstaller.install(
            helperExecutableURL: helperURL,
            at: installURL,
            privilegedRunner: failingRunner
        )
    ) { error in
        XCTAssertEqual(
            error as? ClearanceCommandLineToolInstallerError,
            .privilegedInstallFailed("helper said no")
        )
    }
}

private func makeNonWritableDirectory() throws -> URL {
    let url = try makeDirectory().appending(path: "bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: url.path)
    addTeardownBlock {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
    return url
}
```

- [ ] **Step 2: Run failing tests**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineInstallerTests/testPrivilegedInstallIsAttemptedWhenDirectoryNotWritable 2>&1 | grep -E "(passed|failed|error:)"
```

Expected: FAILED (compile error — `PrivilegedRunner` and new error cases don't exist yet)

- [ ] **Step 3: Implement the privileged fallback**

Replace the entire `ClearanceCommandLineToolInstaller.swift`:

```swift
import Foundation
import Security

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case existingInstallIsNotASymlink(URL)
    case installDirectoryNotWritable(URL)
    case privilegedInstallCancelled
    case privilegedInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .existingInstallIsNotASymlink(let url):
            return "\(url.path) already exists and is not a symlink."
        case .installDirectoryNotWritable(let url):
            return "\(url.path) is not writable. Could not obtain admin privileges."
        case .privilegedInstallCancelled:
            return nil
        case .privilegedInstallFailed(let message):
            return message
        }
    }
}

struct ClearanceCommandLineToolInstaller {
    struct PrivilegedRunner {
        var run: (_ helperBinary: URL, _ source: URL, _ destination: URL) throws -> Void

        init(_ run: @escaping (_ helperBinary: URL, _ source: URL, _ destination: URL) throws -> Void) {
            self.run = run
        }

        static let live = PrivilegedRunner { helperBinary, source, destination in
            var authRef: AuthorizationRef?
            let createStatus = AuthorizationCreate(nil, nil, [], &authRef)
            guard createStatus == errSecSuccess, let authRef else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Authorization failed (\(createStatus))."
                )
            }
            defer { AuthorizationFree(authRef, [.destroyRights]) }

            var copyStatus: OSStatus = errSecSuccess
            "system.privilege.admin".withCString { nameCStr in
                var item = AuthorizationItem(name: nameCStr, valueLength: 0, value: nil, flags: 0)
                withUnsafeMutablePointer(to: &item) { itemPtr in
                    var rights = AuthorizationRights(count: 1, items: itemPtr)
                    copyStatus = AuthorizationCopyRights(
                        authRef, &rights, nil,
                        [.interactionAllowed, .extendRights, .preAuthorize],
                        nil
                    )
                }
            }

            if copyStatus == errAuthorizationCanceled {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallCancelled
            }
            guard copyStatus == errSecSuccess else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Authorization failed (\(copyStatus))."
                )
            }

            var pipe: UnsafeMutablePointer<FILE>? = nil
            var execStatus: OSStatus = errSecSuccess
            source.path.withCString { sourceCStr in
                destination.path.withCString { destCStr in
                    var args: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: sourceCStr),
                        UnsafeMutablePointer(mutating: destCStr),
                        nil
                    ]
                    execStatus = AuthorizationExecuteWithPrivileges(
                        authRef, helperBinary.path, [], &args, &pipe
                    )
                }
            }

            guard execStatus == errSecSuccess else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Could not launch installer (\(execStatus))."
                )
            }

            var output = ""
            if let pipe {
                var buffer = [CChar](repeating: 0, count: 512)
                while fgets(&buffer, Int32(buffer.count), pipe) != nil {
                    output += String(cString: buffer)
                }
                fclose(pipe)
            }

            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(message)
            }
        }
    }

    static let installURL = URL(fileURLWithPath: "/usr/local/bin/clearance")

    static func install(
        helperExecutableURL: URL,
        at installURL: URL = installURL,
        fileManager: FileManager = .default,
        privilegedRunner: PrivilegedRunner = .live
    ) throws {
        let installDirectoryURL = installURL.deletingLastPathComponent()
        let directoryExists = fileManager.fileExists(atPath: installDirectoryURL.path)
        let directoryWritable = fileManager.isWritableFile(atPath: installDirectoryURL.path)

        if directoryExists && !directoryWritable {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
            return
        }

        do {
            try fileManager.createDirectory(
                at: installDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError
        {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
            return
        }

        if (try? fileManager.destinationOfSymbolicLink(atPath: installURL.path)) != nil {
            try fileManager.removeItem(at: installURL)
        } else if fileManager.fileExists(atPath: installURL.path) {
            throw ClearanceCommandLineToolInstallerError.existingInstallIsNotASymlink(installURL)
        }

        do {
            try fileManager.createSymbolicLink(at: installURL, withDestinationURL: helperExecutableURL)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError
        {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
        }
    }

    private static func installWithPrivileges(
        helperExecutableURL: URL,
        installURL: URL,
        privilegedRunner: PrivilegedRunner
    ) throws {
        guard let installHelperURL = Bundle.main.url(
            forAuxiliaryExecutable: "ClearanceInstallHelper"
        ) else {
            throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                "ClearanceInstallHelper not found in app bundle."
            )
        }

        do {
            try privilegedRunner.run(installHelperURL, helperExecutableURL, installURL)
        } catch ClearanceCommandLineToolInstallerError.privilegedInstallCancelled {
            return  // Silent no-op — user's intent is clear
        }
        // All other errors propagate to the caller
    }
}
```

- [ ] **Step 4: Run all installer tests**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineInstallerTests 2>&1 | grep -E "(passed|failed)"
```

Expected: All passing (existing 4 tests + 3 new ones).

- [ ] **Step 5: Run the full test suite**

```bash
xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' 2>&1 | grep -E "(Executed|BUILD)"
```

Expected: `** BUILD SUCCEEDED **` with 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Clearance/Services/ClearanceCommandLineToolInstaller.swift ClearanceTests/Services/ClearanceCommandLineInstallerTests.swift
git commit -m "Add privileged install fallback to ClearanceCommandLineToolInstaller"
```

---

## Task 8: Manual smoke test

This step cannot be automated — it requires a real auth dialog.

- [ ] **Step 1: Build and run the app**

In Xcode: open `Clearance.xcodeproj`, build and run the `Clearance` scheme.

- [ ] **Step 2: Trigger installation**

Open Settings → click "Install Command-Line Tool". On a standard system where `/usr/local/bin` is owned by root, the inline macOS "enter your password" auth sheet should appear.

- [ ] **Step 3: Enter admin credentials and verify**

After authenticating:

```bash
ls -la /usr/local/bin/clearance
# Expected: /usr/local/bin/clearance -> /path/to/Clearance.app/Contents/Helpers/clearance
clearance --help
```

- [ ] **Step 4: Verify cancellation is silent**

Click "Install Command-Line Tool" again. Press Cancel in the auth sheet. Settings should return to idle with no error message shown.
