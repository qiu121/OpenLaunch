# App List Change Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新安装应用在下一次打开 OpenLaunch 时以一次性轻弹动画进入网格。

**Architecture:** 核心层负责比较两次应用列表并记录新增 id；应用状态层负责在自动刷新后保存待展示新增项；SwiftUI 层只读取待动画 id 并驱动 `scale + opacity` 动画。删除项不做退场动画。

**Tech Stack:** Swift 6、AppKit、SwiftUI、XCTest。

## Global Constraints

- 不实现删除应用退场动画。
- 不影响搜索、分页、滚动、自定义排序和手动重新扫描。
- 新增项动画只播放一次。
- 大批新增最多突出前 6 个新增项。
- 使用现有 `stableKey` 作为 app 身份。

---

### Task 1: Core Diff Policy

**Files:**
- Create: `Sources/OpenLaunchCore/AppListChangeSummary.swift`
- Test: `Tests/OpenLaunchCoreTests/AppListChangeSummaryTests.swift`

**Interfaces:**
- Produces: `AppListChangeSummary.addedAppIDs(previousApps:currentApps:limit:) -> [String]`

- [ ] **Step 1: Write failing tests**
- [ ] **Step 2: Run `swift test --filter AppListChangeSummaryTests` and verify failure**
- [ ] **Step 3: Implement `AppListChangeSummary`**
- [ ] **Step 4: Run `swift test --filter AppListChangeSummaryTests` and verify pass**

### Task 2: AppState Pending Animation IDs

**Files:**
- Modify: `Sources/OpenLaunch/AppState.swift`
- Test: `Tests/OpenLaunchCoreTests/AppListChangeSummaryTests.swift`

**Interfaces:**
- Consumes: `AppListChangeSummary.addedAppIDs(previousApps:currentApps:limit:)`
- Produces: `@Published var pendingAnimatedAppIDs: Set<String>` and `consumePendingAnimatedAppIDs() -> Set<String>`

- [ ] **Step 1: Add tests for pending animation id consumption using core policy**
- [ ] **Step 2: Run targeted tests and verify failure where applicable**
- [ ] **Step 3: Record added ids after automatic scan, not manual scan**
- [ ] **Step 4: Run targeted tests and verify pass**

### Task 3: SwiftUI One-Time Entry Animation

**Files:**
- Modify: `Sources/OpenLaunch/ContentView.swift`
- Modify: `docs/OpenLaunch-PRD.md`
- Modify: `docs/Development.md`

**Interfaces:**
- Consumes: `state.pendingAnimatedAppIDs` and `state.consumePendingAnimatedAppIDs()`

- [ ] **Step 1: Add view state for active animated ids**
- [ ] **Step 2: Apply `scaleEffect` and `opacity` only to matching app tiles**
- [ ] **Step 3: Clear pending ids after first presentation**
- [ ] **Step 4: Run `swift test`, `git diff --check`, and `scripts/build-app.sh`**
