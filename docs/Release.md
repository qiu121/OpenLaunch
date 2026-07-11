# OpenLaunch 发布说明

本文档记录 OpenLaunch 的版本管理、构建产物命名和本机安装流程。

当前阶段是 Developer Build / alpha 验收，不包含 Developer ID 签名、公证、自动更新和公开分发流程。

## 版本模型

OpenLaunch 同时使用三类版本信息：

1. App 版本：写入 `Info.plist` 的 `CFBundleShortVersionString`，当前为 `0.1.0`。
2. 构建号：写入 `Info.plist` 的 `CFBundleVersion`，当前为 `1`。
3. Git tag：标记发布节点，例如 `v0.1.0-alpha.1`。

推荐发布节奏：

```text
v0.1.0-alpha.1
v0.1.0-alpha.2
v0.1.0-beta.1
v0.1.0-rc.1
v0.1.0
```

语义约定：

- `alpha`：本机功能验收，允许较多交互和稳定性问题。
- `beta`：主要功能已经稳定，开始关注边界场景和安装体验。
- `rc`：候选正式版，只接受阻断问题修复。
- 正式版：面向稳定使用；公开分发前还需要签名和公证。

## 安装包命名

DMG 和 PKG 文件名由 `scripts/resolve-package-version.sh` 决定。

规则：

- 当前提交有 `v` 开头的版本 tag，且工作区干净时，使用 tag 版本。
- 当前提交没有版本 tag 时，使用 App 版本加 `-dev`。
- 当前提交有版本 tag 但工作区存在未提交改动时，使用 tag 版本加 `-dev`。

示例：

```text
OpenLaunch-0.1.0-alpha.1.dmg
OpenLaunch-0.1.0-alpha.1.pkg
OpenLaunch-0.1.0-dev.dmg
OpenLaunch-0.1.0-dev.pkg
OpenLaunch-0.1.0-alpha.1-dev.dmg
OpenLaunch-0.1.0-alpha.1-dev.pkg
```

这个规则的目标是让“正式发布包”和“本机临时构建包”在文件名上直接区分开。

## 本机打包流程

发布前检查工作区：

```bash
git status --short
```

运行测试：

```bash
swift test
bash Tests/PackageVersionTests.sh
git diff --check
```

确认需要发布的提交：

```bash
git log --oneline -5
```

创建 tag：

```bash
git tag -a v0.1.0-alpha.1 -m "OpenLaunch v0.1.0-alpha.1"
```

同步 Python 打包工具依赖：

```bash
uv sync --locked
```

打包 DMG：

```bash
scripts/package-dmg.sh
```

DMG 打包说明：

- `scripts/package-dmg.sh` 使用固定版本 `dmgbuild==1.6.7` 生成安装窗口布局。
- 如果未指定 `DMGBUILD_BIN`，脚本会通过根目录 `uv run --locked` 使用 `uv.lock` 中锁定的打包依赖。
- CI 环境需要运行在 macOS，并提供 `uv` 和 Xcode 命令行工具。
- 安装窗口布局由 `scripts/dmgbuild-openlaunch.py` 描述，便于审查和复现。
- DMG 卷图标和 `.dmg` 文件图标继续复用 OpenLaunch 的安装包图标脚本。

打包 PKG：

```bash
scripts/package-pkg.sh
```

检查产物：

```bash
ls -lh .build/dist
```

本机安装：

```bash
open .build/dist/OpenLaunch-0.1.0-alpha.1.dmg
```

打开 DMG 后，把 `OpenLaunch.app` 拖到 `Applications`。

## GitHub Actions

仓库提供 `.github/workflows/package.yml` 作为打包流水线示例。

打包任务固定使用 `macos-26`，避免 `macos-latest` 迁移期间因系统和默认 Xcode 变化产生不可复现的构建结果。

触发方式：

- `push` 到 `v*` tag：运行测试，打包 DMG/PKG，上传 artifact，并创建 GitHub Release。
- `workflow_dispatch`：手动触发一次开发构建，只上传 artifact，不创建 Release。
- `schedule`：每周运行一次健康构建，只上传 artifact，不创建 Release。

关键步骤：

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0

- uses: astral-sh/setup-uv@11f9893b081a58869d3b5fccaea48c9e9e46f990 # v8.3.2
  with:
    version: "0.11.28"
    enable-cache: true

- run: uv sync --locked
- run: swift test
- run: bash Tests/PackageVersionTests.sh
- run: bash scripts/package-dmg.sh
- run: bash scripts/package-pkg.sh
```

Release 发布只在 tag 构建中执行：

```yaml
if: github.ref_type == 'tag'
```

当前阶段未配置 Developer ID 签名和 Apple 公证。公开分发前，需要在 GitHub Actions 中增加证书导入、`codesign`、`notarytool` 和 `stapler` 步骤，并通过 Secrets 管理 Apple 开发者账号相关凭据。

## 版本策略建议

推荐以 Git tag 作为发布版本的唯一来源。

- 正式或预发布版本：创建 `v0.1.0`、`v0.1.0-alpha.1`、`v0.1.0-beta.1` 这类 tag。
- 本机开发构建：不打 tag，输出 `OpenLaunch-0.1.0-dev.dmg` / `.pkg`。
- tag 提交存在未提交改动：输出 `OpenLaunch-0.1.0-alpha.1-dev.dmg` / `.pkg`，避免误当发布包。
- 定时构建：只用于验证主分支仍可构建，不建议生成正式版本号，也不建议自动发布 Release。

如果后续需要 nightly 包，可以另加独立命名规则，例如 `OpenLaunch-0.1.0-nightly.<run-number>.dmg`。当前阶段先不引入 nightly 版本号，避免和语义化发布版本混在一起。

## 本机验收清单

安装后建议逐项验收：

- 状态栏图标左键可以进入启动台。
- 状态栏图标右键只显示“重新扫描 / 退出”。
- 搜索框首次进入不残留输入光标。
- 点击搜索框或直接输入文字后可以实时过滤应用。
- 点击空白处可以退出启动台。
- 点击应用图标后能切换到目标 app，并隐藏启动台。
- 分页圆点可点击跳页。
- 横向拖拽或触控板横向滚动可分页。
- 分页和滚动显示模式可切换。
- 添加时间、名称、最近打开排序和方向切换可用。
- 自定义排序拖拽后重启仍能保留。
- 应用名称按系统本地化展示，搜索英文原名仍可命中。
- 安装或移除应用后能自动后台刷新列表。
- 新增应用在下一次打开启动台时有一次性入场动画。
- 重新扫描不会造成崩溃或列表异常清空。

## PKG

项目保留 `scripts/package-pkg.sh` 作为一键安装备选。

当前推荐优先使用 DMG：

- DMG 更适合本机拖拽安装。
- PKG 更适合需要命令行安装或后续企业分发的场景。
- 对外分发 PKG 前同样需要签名和公证。

## 不提交的产物

以下内容属于本机构建或 IDE 状态，不应提交：

- `.build/`
- `DerivedData/`
- `.swiftpm/`
- `.xcodeproj/`
- `.xcworkspace/`
- `*.xcuserstate`
- `OpenLaunch.app/`
- `*.dSYM`

这些规则已经写入 `.gitignore`。
