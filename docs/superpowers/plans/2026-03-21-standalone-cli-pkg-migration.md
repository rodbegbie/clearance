# Standalone CLI Package and Bundle ID Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Clearance to `com.primeradiant.Clearance`, migrate user state from `com.jesse.Clearance`, and replace direct CLI installation with a bundled installer package and standalone `clearance` binary.

**Architecture:** The app keeps its current SwiftUI structure, but gains a focused defaults-migration service and a package-launch path for CLI installation. Packaging work adds signed installer packages without replacing the existing zip/dmg release flow, and the standalone CLI locates the app by bundle identifier instead of a hard-coded bundle path.

**Tech Stack:** Swift, SwiftUI, Foundation, AppKit, XcodeGen, GitHub Actions, `pkgbuild`, `productbuild`, notarization tooling

---

## Chunk 1: Bundle ID and Migration Plumbing

### Task 1: Update product identity

**Files:**
- Modify: `project.yml`
- Modify: `ClearanceTests/Services/ClearanceCommandLineToolTests.swift`
- Modify: `ClearanceTests/Services/ReleaseNotesCatalogTests.swift`

- [ ] **Step 1: Write or update failing tests/assertions for the new bundle identifier**
- [ ] **Step 2: Run focused tests to verify current assumptions fail or need updates**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineToolTests -only-testing:ClearanceTests/ReleaseNotesCatalogTests`
- [ ] **Step 3: Change the app bundle identifier to `com.primeradiant.Clearance` and align fixed test fixtures**
- [ ] **Step 4: Run the focused tests again**
- [ ] **Step 5: Commit**

### Task 2: Add first-launch defaults migration

**Files:**
- Create: `Clearance/Services/LegacyDefaultsMigration.swift`
- Modify: `Clearance/App/ClearanceApp.swift`
- Test: `ClearanceTests/Services/LegacyDefaultsMigrationTests.swift`

- [ ] **Step 1: Write failing migration tests**
Cover:
  - copies old persistent domain into the new domain
  - does nothing when already migrated
  - preserves existing values in the new domain
  - no-ops when the old domain is absent
- [ ] **Step 2: Run the focused migration tests to verify failure**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/LegacyDefaultsMigrationTests`
- [ ] **Step 3: Implement `LegacyDefaultsMigration` with a migration sentinel**
- [ ] **Step 4: Invoke migration once during app startup**
- [ ] **Step 5: Run focused migration tests again**
- [ ] **Step 6: Commit**

## Chunk 2: Standalone CLI Behavior

### Task 3: Refactor CLI app lookup

**Files:**
- Modify: `Clearance/Services/ClearanceCommandLineTool.swift`
- Modify: `ClearanceCLI/main.swift`
- Test: `ClearanceTests/Services/ClearanceCommandLineToolTests.swift`

- [ ] **Step 1: Write failing tests for bundle-ID-based app lookup**
Cover:
  - standalone lookup resolves `com.primeradiant.Clearance`
  - bundled helper lookup still resolves the enclosing app
  - missing app yields a clear error
- [ ] **Step 2: Run the focused CLI tests to verify failure**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineToolTests`
- [ ] **Step 3: Implement a small app-locator abstraction and standalone lookup path**
- [ ] **Step 4: Update `main.swift` to use the new lookup rules**
- [ ] **Step 5: Run the focused CLI tests again**
- [ ] **Step 6: Commit**

## Chunk 3: Settings-Initiated CLI Package Install

### Task 4: Replace direct install with package launch

**Files:**
- Modify: `Clearance/Services/ClearanceCommandLineToolInstaller.swift`
- Modify: `Clearance/Views/SettingsView.swift`
- Test: `ClearanceTests/Services/ClearanceCommandLineInstallerTests.swift`

- [ ] **Step 1: Write failing tests for package-based install flow**
Cover:
  - missing bundled package reports a clear error
  - successful path opens the package resource
  - UI status messaging reflects success/failure
- [ ] **Step 2: Run the focused installer tests to verify failure**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/ClearanceCommandLineInstallerTests`
- [ ] **Step 3: Introduce a package-launch abstraction instead of direct symlink creation**
- [ ] **Step 4: Update Settings to launch the package installer**
- [ ] **Step 5: Run the focused installer tests again**
- [ ] **Step 6: Commit**

### Task 5: Add the bundled CLI package resource

**Files:**
- Create: `Packaging/cli-installer/`
- Modify: `project.yml`
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Add a reproducible package layout for the CLI installer**
- [ ] **Step 2: Update the project to bundle the generated CLI installer package as an app resource**
- [ ] **Step 3: Update the release workflow to build, sign, notarize, and bundle the CLI installer package**
- [ ] **Step 4: Run the local packaging smoke path you can run without Apple secrets**
- [ ] **Step 5: Commit**

## Chunk 4: One-Time Migration Release Package

### Task 6: Add the migration installer package build

**Files:**
- Create: `Packaging/app-migration-installer/`
- Modify: `.github/workflows/release.yml`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Define the migration package payload and any postinstall behavior**
- [ ] **Step 2: Update the release workflow to emit the migration package as a release artifact**
- [ ] **Step 3: Add release-note guidance for the migration release**
- [ ] **Step 4: Run the parts of the packaging script that are locally verifiable**
- [ ] **Step 5: Commit**

## Chunk 5: End-to-End Verification

### Task 7: Regenerate project and run the full suite

**Files:**
- Modify: generated project files only if required by `xcodegen`

- [ ] **Step 1: Regenerate the Xcode project if the source project definition changed**
Run: `xcodegen generate`
- [ ] **Step 2: Run focused tests for migration, CLI lookup, and installer behavior**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS' -only-testing:ClearanceTests/LegacyDefaultsMigrationTests -only-testing:ClearanceTests/ClearanceCommandLineToolTests -only-testing:ClearanceTests/ClearanceCommandLineInstallerTests`
- [ ] **Step 3: Run the full test suite**
Run: `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'`
- [ ] **Step 4: Run a local build smoke test**
Run: `xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug build`
- [ ] **Step 5: Verify git diff and package artifacts**
- [ ] **Step 6: Commit final integration work**
