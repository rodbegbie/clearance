# Standalone CLI Package and Bundle ID Migration Design

## Goal

Ship Clearance as `com.primeradiant.Clearance`, replace the old `com.jesse.Clearance` app cleanly, preserve user state, and move command-line tool installation to a signed installer package that can request administrator privileges through Installer.app instead of relying on in-app file system writes.

## Context

Clearance currently ships as `com.jesse.Clearance`, embeds a `clearance` helper inside the app bundle, and tries to install `/usr/local/bin/clearance` directly from the app. That direct install path fails on default macOS systems because `/usr/local/bin` is often root-owned. The existing helper design is also path-coupled to the app bundle that contains it, which is the wrong shape for a globally installed command-line tool.

Changing the app bundle identifier to `com.primeradiant.Clearance` is also an app identity change. That needs a deliberate migration path for app replacement and persisted defaults/history. A pure in-app symlink prompt would not solve the bundle identity migration on its own.

## Approaches Considered

### 1. Managed entitlement plus in-app privileged file operation prompt

Use `NSWorkspace.requestAuthorization(to: .createSymbolicLink)` with the `com.apple.developer.security.privileged-file-operations` entitlement to install `/usr/local/bin/clearance` directly from the app.

Why not now:
- Apple approval for that managed entitlement is external to the codebase.
- It solves CLI install but not the bundle ID migration and old-app replacement problem.
- It still leaves us with a path decision for the installed CLI binary.

### 2. Privileged helper tool

Add a root helper and XPC path to install or update the command-line tool.

Why not:
- Far too much machinery for a single symlink or file copy.
- Raises the security and signing bar significantly.
- Does not help with the app replacement story.

### 3. Recommended: pkg-based migration and pkg-based CLI install

Use signed installer packages for privileged installation work. Ship:
- a one-time migration installer package for the app release
- a bundled CLI-only installer package inside the app for the Settings button

Why this is the right cut:
- Matches normal macOS installer behavior for admin-protected paths.
- Uses Installer.app’s built-in privilege prompt.
- Lets us replace the old app at `/Applications/Clearance.app` cleanly.
- Keeps the standalone CLI binary independent from any app bundle path.

## Recommended Design

### App Identity

- Change the app bundle identifier from `com.jesse.Clearance` to `com.primeradiant.Clearance`.
- Keep the visible app name as `Clearance`.
- Treat the first release with the new bundle ID as a migration release.

### Standalone CLI Binary

- Keep a single `clearance` tool target, but change its runtime behavior.
- When run from inside an app bundle, it may still derive the enclosing app URL from its bundle location.
- When run as a standalone binary from `/usr/local/bin/clearance`, it resolves the installed app by bundle identifier `com.primeradiant.Clearance`.
- If no installed app with that bundle identifier is found, it exits with a clear user-facing error.

This removes the path-coupled design flaw. The installed CLI should target the currently installed app by bundle identifier rather than a baked-in app path.

### CLI Installation Package

- Build a CLI-only installer package that installs the standalone `clearance` binary into `/usr/local/bin/clearance`.
- Bundle that package inside the app’s resources.
- Change `Install Command-Line Tool` in Settings to reveal or open the bundled package in Installer.app instead of attempting the install directly.

The package payload should install the actual standalone binary, not a symlink into `Clearance.app`. That keeps the tool working if the app moves and avoids stale path problems.

### One-Time App Migration Package

- Build a separate migration installer package for releases during the bundle ID change.
- That package installs `Clearance.app` into `/Applications`.
- It replaces the old app at the standard installed path.
- It can optionally include the standalone CLI binary too, but it does not need to be the same package as the Settings-installed CLI package.

The important outcome is that we have one canonical installer that can replace the old app in `/Applications` even though the bundle identifier changes.

### First-Launch Data Migration

- On first launch of `com.primeradiant.Clearance`, inspect the old defaults domain `com.jesse.Clearance`.
- If the new domain has not already been migrated and the old domain exists, copy the old persistent domain into the new app’s defaults domain.
- Preserve existing keys in the new domain if they already exist.
- Mark migration complete with a new sentinel key in the new domain.

This captures:
- History (`recentFiles`)
- app settings (`defaultOpenMode`, `theme`, `appearance`, `renderedTextScale`)
- release notes tracking and any other user defaults backed state

The migration should be idempotent and run only once.

### Release and Signing Changes

- Update build configuration to use `com.primeradiant.Clearance`.
- Extend the release workflow to build and sign installer packages.
- Add Developer ID Installer signing support alongside the existing Developer ID Application signing.
- Notarize installer packages as release artifacts.
- Publish the migration package in the GitHub release alongside the zip and dmg.

The current zip/dmg path can remain for normal app delivery. The migration package exists to handle the identity transition cleanly, not to replace every distribution artifact forever.

## Components

### New or Changed Runtime Components

- `Clearance/Services/ClearanceCommandLineTool.swift`
  - support app lookup by bundle identifier
- `ClearanceCLI/main.swift`
  - use the standalone lookup path
- `Clearance/Services/ClearanceCommandLineToolInstaller.swift`
  - replace direct write logic with package-launch logic or package location helpers
- `Clearance/Views/SettingsView.swift`
  - launch the bundled CLI installer package
- new migration service for old-to-new defaults import

### New Packaging Components

- a package root for CLI installer contents and scripts
- a package root for migration installer contents and scripts
- release workflow steps for pkgbuild/productbuild/codesign/notarization

## Data Flow

### CLI Install from Settings

1. User clicks `Install Command-Line Tool`.
2. Clearance locates the bundled CLI installer package resource.
3. Clearance opens the package with Installer.app.
4. Installer prompts for admin credentials if needed.
5. Installer places `/usr/local/bin/clearance`.
6. Future CLI invocations locate `com.primeradiant.Clearance` by bundle identifier.

### App Migration Release

1. User installs the migration package.
2. Installer writes the new app to `/Applications/Clearance.app`, replacing the old standard install.
3. User launches the new app.
4. First-launch migration copies old defaults/history from `com.jesse.Clearance`.
5. New app continues under `com.primeradiant.Clearance`.

## Error Handling

- If the bundled CLI package is missing, Settings shows a clear error.
- If the standalone CLI cannot find `com.primeradiant.Clearance`, it reports that the app is not installed.
- If old defaults migration finds no old domain, it becomes a no-op.
- If migration has already run, it becomes a no-op.
- If the app is installed somewhere other than `/Applications`, the standalone CLI still works because it resolves by bundle identifier rather than path.

## Testing Strategy

- Add unit tests for standalone CLI app resolution by bundle identifier.
- Add unit tests for first-launch defaults migration, including idempotence and merge behavior.
- Add tests for the Settings install action using a package-launch abstraction rather than direct Installer.app calls.
- Add release-script verification for generated packages where feasible.
- Run the full `xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'` suite before integration.

## Risks

- Bundle ID migration may affect update behavior for existing users, so the migration package must be treated as a deliberate release artifact.
- Installer signing adds new secret and workflow requirements.
- If multiple copies of Clearance are installed, bundle-ID lookup may not match the user’s expectation; the first cut should target the registered app for `com.primeradiant.Clearance` and keep the behavior explicit in error text.

## Decision

Proceed with:
- app bundle ID migration to `com.primeradiant.Clearance`
- first-launch defaults/history migration from `com.jesse.Clearance`
- standalone CLI binary installed by pkg
- bundled CLI installer package for Settings
- one-time migration installer package in the release workflow
