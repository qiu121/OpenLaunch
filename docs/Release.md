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

## 本机发布流程

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

打包 DMG：

```bash
scripts/package-dmg.sh
```

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
