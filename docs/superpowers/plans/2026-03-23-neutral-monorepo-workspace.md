# Neutral Monorepo Workspace Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Clearance into a neutral monorepo workspace by moving the current Swift/Xcode app into `apps/macos`, creating a placeholder `apps/tauri`, extracting shared assets and demo fixtures into `packages/*`, and fixing the macOS release/build paths so the app still builds and ships cleanly.

**Architecture:** Keep the macOS app self-contained inside `apps/macos` and extract only genuinely shared repo DNA into `packages/assets` and `packages/demo-corpus`. Add minimal root workspace files (`README.md`, `package.json`, `pnpm-workspace.yaml`) and update the single release workflow to target the new app subtree without introducing heavy JS monorepo orchestration.

**Tech Stack:** Git, XcodeGen, Xcode/xcodebuild, GitHub Actions, Markdown docs, minimal pnpm workspace metadata

---

## Chunk 1: Workspace Shape And Repository Move

### Task 1: Add Root Workspace Files And Placeholder App Structure

**Files:**
- Create: `package.json`
- Create: `pnpm-workspace.yaml`
- Create: `apps/tauri/README.md`
- Create: `apps/tauri/package.json`

- [ ] **Step 1: Add the root workspace manifests**

Create `package.json` and `pnpm-workspace.yaml` with the root acting as the workspace entry point.

```json
{
  "name": "clearance-workspace",
  "private": true,
  "packageManager": "pnpm@10",
  "scripts": {
    "macos:generate": "cd apps/macos && xcodegen generate",
    "macos:build": "cd apps/macos && xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build",
    "macos:test": "cd apps/macos && xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'"
  }
}
```

```yaml
packages:
  - apps/tauri
  - packages/*
```

- [ ] **Step 2: Add the placeholder Tauri app directory**

Create `apps/tauri/README.md` and `apps/tauri/package.json`.

```md
# Clearance Tauri

This directory is reserved for the future shared Tauri implementation of Clearance.

Planned scope:

- Windows
- Linux
- Android
- shared product behavior should eventually align with the macOS app where reasonable

The first monorepo cut intentionally leaves this as a placeholder until the product and runtime shape of the Tauri app are ready.
```

```json
{
  "name": "@clearance/tauri",
  "private": true,
  "version": "0.0.0"
}
```

- [ ] **Step 3: Verify the new workspace manifests and placeholder app metadata**

Run:

```bash
plutil -lint package.json apps/tauri/package.json
sed -n '1,40p' pnpm-workspace.yaml
python3 - <<'PY'
import json
from pathlib import Path

scripts = json.loads(Path("package.json").read_text())["scripts"]
for name in ("macos:generate", "macos:build", "macos:test"):
    print(f"{name}: {scripts[name]}")
PY
```

Expected:
- both JSON files report `OK`
- `pnpm-workspace.yaml` lists `apps/tauri` and `packages/*`
- the printed script names include `macos:generate`, `macos:build`, and `macos:test`

- [ ] **Step 4: Commit the workspace scaffolding**

Run:

```bash
git add package.json pnpm-workspace.yaml apps/tauri
git commit -m "Add neutral monorepo workspace scaffolding"
```

### Task 2: Move Shared Packages And Relocate The macOS App

**Files:**
- Create: `apps/macos/`
- Create: `packages/assets/`
- Create: `packages/demo-corpus/`
- Move: `assets/branding/clearance-app-icon.svg` -> `packages/assets/branding/clearance-app-icon.svg`
- Move: `docs/demo-corpus/01-rich-rendering.md` -> `packages/demo-corpus/01-rich-rendering.md`
- Move: `docs/demo-corpus/02-markdown-kitchen-sink.md` -> `packages/demo-corpus/02-markdown-kitchen-sink.md`
- Move: `docs/demo-corpus/03-links-and-outline.md` -> `packages/demo-corpus/03-links-and-outline.md`
- Move: `Clearance/` -> `apps/macos/Clearance/`
- Move: `ClearanceCLI/` -> `apps/macos/ClearanceCLI/`
- Move: `ClearanceTests/` -> `apps/macos/ClearanceTests/`
- Move: `Clearance.xcodeproj/` -> `apps/macos/Clearance.xcodeproj/`
- Move: `project.yml` -> `apps/macos/project.yml`
- Move: `Packaging/` -> `apps/macos/Packaging/`
- Move: `CHANGELOG.md` -> `apps/macos/CHANGELOG.md`
- Move: `scripts/` -> `apps/macos/scripts/`
- Move: `docs/DEVELOPMENT.md` -> `apps/macos/docs/DEVELOPMENT.md`
- Modify: `README.md`
- Create: `apps/macos/README.md`

- [ ] **Step 1: Create the destination directories**

Run:

```bash
mkdir -p apps/macos apps/tauri packages/assets/branding packages/demo-corpus apps/macos/docs
```

Expected: destination directories exist before `git mv`

- [ ] **Step 2: Move shared assets and shared demo fixtures with `git mv`**

Run:

```bash
git mv assets/branding/clearance-app-icon.svg packages/assets/branding/clearance-app-icon.svg
git mv docs/demo-corpus/01-rich-rendering.md packages/demo-corpus/01-rich-rendering.md
git mv docs/demo-corpus/02-markdown-kitchen-sink.md packages/demo-corpus/02-markdown-kitchen-sink.md
git mv docs/demo-corpus/03-links-and-outline.md packages/demo-corpus/03-links-and-outline.md
```

Expected: `git status --short` shows renames into `packages/*`

- [ ] **Step 3: Move the current macOS app subtree with `git mv`**

Run:

```bash
git mv Clearance apps/macos/Clearance
git mv ClearanceCLI apps/macos/ClearanceCLI
git mv ClearanceTests apps/macos/ClearanceTests
git mv Clearance.xcodeproj apps/macos/Clearance.xcodeproj
git mv project.yml apps/macos/project.yml
git mv Packaging apps/macos/Packaging
git mv CHANGELOG.md apps/macos/CHANGELOG.md
git mv scripts apps/macos/scripts
git mv docs/DEVELOPMENT.md apps/macos/docs/DEVELOPMENT.md
```

Expected: `git status --short` shows the scaffold files from Task 1 plus the planned `packages/*` renames and `apps/macos/*` moves; nothing outside the planned move set appears

- [ ] **Step 4: Create `apps/macos/README.md` from the existing product README content before rewriting the root README**

Move the current product/app-specific content out of the old root README and into `apps/macos/README.md`, updating relative links so it refers to:
- `../../packages/assets/branding/clearance-app-icon.svg`
- `docs/DEVELOPMENT.md`

- [ ] **Step 5: Rewrite the root `README.md` as the workspace README**

Rewrite `README.md` so it describes:
- the repo as the Clearance workspace
- `apps/macos` as the current shipping app
- `apps/tauri` as the future shared Tauri app home
- `packages/assets` and `packages/demo-corpus` as shared DNA
- the root `pnpm` scripts for generating, building, and testing the macOS app
- workspace-level contribution conventions for where app-specific versus workspace-wide changes should live

- [ ] **Step 6: Verify the README split and move set before path-fixing edits**

Run:

```bash
rg -n "apps/macos|apps/tauri|packages/assets|packages/demo-corpus|macos:generate|macos:build|macos:test|Contributing|app-specific|workspace-wide" README.md
rg -n "native macOS app|docs/DEVELOPMENT.md|\\.\\./\\.\\./packages/assets/branding/clearance-app-icon.svg" apps/macos/README.md
git status --short
```

Expected:
- root `README.md` explicitly documents the root macOS scripts and contribution conventions for workspace-wide versus app-specific changes
- `apps/macos/README.md` reads like the product/app README and points at the moved icon asset and development guide
- the status reflects the planned renames and new files only; no accidental deletions outside the planned move

- [ ] **Step 7: Commit the physical repository move**

Run:

```bash
git add README.md apps/macos packages/assets packages/demo-corpus
git commit -m "Move macOS app into monorepo structure"
```

## Chunk 2: Path Fixes, Workflow Updates, And Verification

### Task 3: Update Path-Sensitive Config, Docs, And Workflow References

**Files:**
- Modify: `apps/macos/project.yml`
- Modify: `apps/macos/Clearance.xcodeproj/project.pbxproj`
- Modify: `apps/macos/scripts/generate-app-iconset.sh`
- Modify: `apps/macos/scripts/README.md`
- Modify: `apps/macos/README.md`
- Modify: `apps/macos/docs/DEVELOPMENT.md`
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Update `apps/macos/project.yml` for the new workspace-relative paths**

Adjust these path references using app-root-relative paths because `xcodegen generate` runs inside `apps/macos`:
- `CHANGELOG.md` resource path stays `CHANGELOG.md`
- `Clearance/...`, `ClearanceCLI/...`, `ClearanceTests/...` source roots stay app-root-relative
- demo corpus resource path -> `../../packages/demo-corpus`
- `INFOPLIST_FILE` stays `Clearance/App/Info.plist`
- packaging script path stays `"$PROJECT_DIR/Packaging/build-cli-installer-pkg.sh"`

- [ ] **Step 2: Update the moved macOS icon script and script README**

Fix these references:
- `apps/macos/scripts/generate-app-iconset.sh`
  - workspace root resolution should climb from `apps/macos/scripts` back to the repo root
  - default source SVG -> `packages/assets/branding/clearance-app-icon.svg`
  - default AppIcon destination -> `apps/macos/Clearance/Resources/Assets.xcassets/AppIcon.appiconset`
- `apps/macos/scripts/README.md`
  - point examples and defaults at the new paths

- [ ] **Step 3: Update the moved macOS README and development guide**

Fix these references:
- `apps/macos/docs/DEVELOPMENT.md`
  - build/test/generate commands should run from `apps/macos`
  - shared fixture references should point at `../../packages/demo-corpus`
- `apps/macos/README.md`
  - product README links should resolve from its new directory

- [ ] **Step 4: Update the GitHub release workflow**

Edit `.github/workflows/release.yml` so it explicitly targets the macOS app subtree:
- `PROJECT_FILE: apps/macos/Clearance.xcodeproj`
- run `xcodegen generate --spec apps/macos/project.yml --project apps/macos` from the workspace root
- invoke `apps/macos/Packaging/build-migration-pkg.sh`
- keep artifacts, tags, and release publishing rooted at the workspace level

- [ ] **Step 5: Regenerate the Xcode project from the moved XcodeGen spec**

Run:

```bash
cd apps/macos && xcodegen generate
```

Expected: `apps/macos/Clearance.xcodeproj` is regenerated without referencing old root paths

- [ ] **Step 6: Inspect the regenerated project and workflow for stale old-root references**

Run:

```bash
if rg -n "apps/macos/Clearance|apps/macos/ClearanceCLI|apps/macos/ClearanceTests|\\$PROJECT_DIR/apps/macos/Packaging" apps/macos/project.yml apps/macos/Clearance.xcodeproj/project.pbxproj -S; then exit 1; fi
rg -n "\\.\\./\\.\\./packages/demo-corpus|packages/assets/branding/clearance-app-icon.svg" apps/macos/project.yml apps/macos/docs/DEVELOPMENT.md apps/macos/scripts/generate-app-iconset.sh apps/macos/README.md -S
if rg -n "docs/demo-corpus|assets/branding/clearance-app-icon.svg" apps/macos/project.yml apps/macos/docs/DEVELOPMENT.md apps/macos/scripts/generate-app-iconset.sh apps/macos/README.md -S; then exit 1; fi
rg -n "apps/macos/Clearance.xcodeproj|xcodegen generate --spec apps/macos/project.yml --project apps/macos|apps/macos/Packaging/build-migration-pkg.sh" .github/workflows/release.yml -S
if rg -n "PROJECT_FILE: Clearance.xcodeproj|xcodegen generate$|\\$GITHUB_WORKSPACE/Packaging/build-migration-pkg.sh" .github/workflows/release.yml -S; then exit 1; fi
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'
```

Expected:
- the negative `rg` checks produce no output and exit `0` overall, proving stale root-layout references are gone
- the positive `rg` checks find the moved shared-fixture, shared-asset, and workflow paths
- the Ruby command parses `.github/workflows/release.yml` successfully as valid YAML

- [ ] **Step 7: Commit the path and workflow fixes**

Run:

```bash
git add .github/workflows/release.yml apps/macos/project.yml apps/macos/README.md apps/macos/docs/DEVELOPMENT.md apps/macos/scripts apps/macos/Clearance.xcodeproj
git commit -m "Fix monorepo paths for macOS app and release workflow"
```

### Task 4: Verify The Moved macOS App Still Builds And Tests Cleanly

**Files:**
- Modify: `apps/macos/Clearance.xcodeproj/project.pbxproj` if regenerated changes remain
- Modify: any path-fix file from Task 3 only if verification reveals a real break

- [ ] **Step 1: Run the macOS Debug build from the new app root**

Run:

```bash
cd apps/macos && xcodebuild -project Clearance.xcodeproj -scheme Clearance -configuration Debug -destination 'platform=macOS' build
```

Expected: build exits `0`

- [ ] **Step 2: Run the full macOS test suite from the new app root**

Run:

```bash
cd apps/macos && xcodebuild test -project Clearance.xcodeproj -scheme Clearance -destination 'platform=macOS'
```

Expected: test run exits `0` with `0 failures`

- [ ] **Step 3: Confirm the root workspace scripts still map to the moved app correctly**

Run:

```bash
python3 - <<'PY'
import json
from pathlib import Path

scripts = json.loads(Path("package.json").read_text())["scripts"]
for name in ("macos:generate", "macos:build", "macos:test"):
    print(f"{name}: {scripts[name]}")
PY
```

Expected:
- each printed script starts with `cd apps/macos &&`

- [ ] **Step 4: Commit any final verification-driven fixes if verification required edits**

Run:

```bash
git add apps/macos/Clearance.xcodeproj/project.pbxproj apps/macos/project.yml README.md .github/workflows/release.yml apps/macos/docs/DEVELOPMENT.md apps/macos/scripts/generate-app-iconset.sh apps/macos/scripts/README.md apps/macos/README.md
git commit -m "Verify neutral monorepo macOS build and test paths"
```

Expected:
- create this commit only if Step 1, Step 2, or Step 3 uncovered a real path fix that required another edit
- if verification required no additional edits, skip directly to Step 5 without creating a no-op commit

- [ ] **Step 5: Final readiness check**

Run:

```bash
git status --short --branch
git log --oneline --decorate -n 6
```

Expected:
- branch is clean
- the last commits show scaffolding, repo move, path fixes, and verification
