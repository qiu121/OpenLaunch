# OpenLaunch MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable OpenLaunch macOS MVP with app scanning, added-date default sorting, search, grid display, status bar controls, and click-to-launch.

**Architecture:** Use a Swift Package with one executable app target and one test target. Keep testable pure logic in model/store/scanner files, and keep AppKit/SwiftUI integration in focused UI and controller files. Provide a build script that can create a local `.app` bundle from the SwiftPM executable.

**Tech Stack:** Swift 6.3 compiler in Swift 5 language mode, SwiftUI, AppKit, Foundation, XCTest, Swift Package Manager.

---

## File Structure

- `Package.swift`: Swift package manifest for the app and tests.
- `.gitignore`: ignores build artifacts and local app bundles.
- `Sources/OpenLaunch/main.swift`: app entry point.
- `Sources/OpenLaunch/AppModels.swift`: app records, sort modes, display modes, settings types.
- `Sources/OpenLaunch/AppSorter.swift`: deterministic app sorting.
- `Sources/OpenLaunch/AppScanner.swift`: `.app` bundle discovery and metadata extraction.
- `Sources/OpenLaunch/SettingsStore.swift`: JSON settings and recents persistence.
- `Sources/OpenLaunch/AppState.swift`: observable UI state and orchestration.
- `Sources/OpenLaunch/AppDelegate.swift`: status bar item and lifecycle.
- `Sources/OpenLaunch/HotkeyManager.swift`: lightweight global hotkey registration.
- `Sources/OpenLaunch/ContentView.swift`: main SwiftUI window.
- `scripts/build-app.sh`: builds a local `OpenLaunch.app` bundle.
- `Tests/OpenLaunchTests/AppSorterTests.swift`: default and explicit sort behavior.
- `Tests/OpenLaunchTests/SettingsStoreTests.swift`: default settings persistence behavior.
- `Tests/OpenLaunchTests/AppScannerTests.swift`: fake `.app` bundle scanning behavior.

## Tasks

### Task 1: Package Skeleton

- [ ] Create `Package.swift`, `.gitignore`, and source/test directories.
- [ ] Add a minimal executable target and XCTest target.
- [ ] Verify `swift test` can discover the test bundle after tests are added.

### Task 2: Sorting Logic, TDD

- [ ] Write tests proving the default sort is added date descending.
- [ ] Write tests proving name sort is localized ascending.
- [ ] Implement `LaunchableApp`, `AppSortMode`, `DisplayMode`, `OpenLaunchSettings`, and `AppSorter`.
- [ ] Run `swift test --filter AppSorterTests`.

### Task 3: Settings Store, TDD

- [ ] Write tests proving missing settings fall back to added-date sort.
- [ ] Write tests proving saved settings round-trip.
- [ ] Implement `SettingsStore`.
- [ ] Run `swift test --filter SettingsStoreTests`.

### Task 4: App Scanner, TDD

- [ ] Write tests using fake `.app` bundles with `Info.plist`.
- [ ] Implement `AppScanner` with path scanning, Info.plist parsing, duplicate filtering, and added-date fallback.
- [ ] Run `swift test --filter AppScannerTests`.

### Task 5: SwiftUI UI

- [ ] Implement `AppState` for scanning, searching, sorting, and launching.
- [ ] Implement `ContentView` with search, sort picker, display mode picker, grid, page controls, and app tiles.
- [ ] Verify `swift build`.

### Task 6: AppKit Integration

- [ ] Implement `AppDelegate` with status bar menu.
- [ ] Implement a simple global hotkey manager.
- [ ] Ensure app starts with a main window and status item.
- [ ] Verify `swift build`.

### Task 7: Local App Bundle

- [ ] Add `scripts/build-app.sh`.
- [ ] Run the script and verify it creates `.build/OpenLaunch.app`.
- [ ] Update docs with build/run instructions.

### Task 8: Final Verification

- [ ] Run `swift test`.
- [ ] Run `swift build`.
- [ ] Run `scripts/build-app.sh`.
- [ ] Record remaining gaps in the final response.

