# OpenLaunch 开发说明

## 环境要求

- macOS 26.x 或兼容版本。
- Xcode 26.6。
- Swift 6.3.x。

当前项目使用 Swift Package Manager 组织代码：

- `OpenLaunchCore`：可测试核心逻辑，包括应用模型、排序、扫描和设置存储。
- `OpenLaunch`：AppKit 主循环 + SwiftUI 内容视图的可执行应用，包括窗口、状态栏菜单、快捷键和启动应用。

## 命名约定

推荐保持用户可见产品名为 `OpenLaunch`。

Apple 生态里常见的用户可见应用名通常使用 PascalCase 或 Title Case，例如 `Xcode`、`Final Cut Pro`、`Activity Monitor`。对于这个项目：

- 产品名、app bundle 名、Dock 名称：`OpenLaunch`。
- Swift Package、target、可执行文件：`OpenLaunch` / `OpenLaunchCore`。
- bundle identifier：`dev.openlaunch.OpenLaunch`。
- 仓库名或本地目录名：可使用 `open-launch` 这种 kebab-case，便于命令行和 Git 托管平台识别。

不建议把用户可见 app 名做成 `open-launch`。连字符形式更像命令行工具、仓库目录或 npm package，不像 macOS 图形应用入口。

## 当前行为

- 主窗口使用覆盖式全屏：显示时铺满鼠标所在屏幕，不进入 macOS 原生绿色全屏 Space。
- 覆盖窗口由 AppDelegate 显式创建，不使用 SwiftUI `WindowGroup`，避免 macOS 窗口恢复把启动器还原成普通小窗口。
- 覆盖窗口常态铺满屏幕，不在底部留下可见空条；主内容窗口层级低于系统 Dock、高于普通窗口，让自动隐藏 Dock 能自然浮出。
- 全屏覆盖层显示期间使用系统 `autoHideMenuBar` 和 `autoHideDock` 默认隐藏系统栏，同时用透明顶部触发拦截层阻止鼠标贴顶时菜单栏浮出。
- 状态栏图标左键直接显示 OpenLaunch 全屏覆盖层；右键或 Control 点击才展示菜单。
- Dock 图标使用 `Resources/OpenLaunchAppIcon.icns`，接近系统 Apps 入口图标气质；状态栏图标继续使用现有 SF Symbols 网格符号。
- 全屏背景默认使用系统背景的模糊处理。
- 默认排序为添加时间从旧到新，新添加的软件在最后。
- 默认分页网格保持 7×5，图标默认尺寸为 96×96。
- 全屏覆盖层显示时不展示顶部系统菜单栏整块区域；OpenLaunch 的菜单栏状态项作为退出覆盖层后的启动入口保留。
- 默认应用扫描合并 Spotlight 应用索引和文件系统扫描，使用用户可见路径策略覆盖公开应用目录、用户独立 `.app` 和少量共享支持目录。
- 添加时间优先使用 Spotlight `kMDItemDateAdded`，缺失时依次降级为文件创建时间、文件修改时间。
- 顶部居中液态玻璃风格搜索框，包含放大镜图标、清除按钮和舒适内边距；搜索框右侧提供弱化设置菜单入口，菜单选中项左侧保留独立勾选列；初始进入不主动显示输入光标，用户点击搜索框或直接输入文字后再聚焦并实时过滤。
- 底部仅显示分页圆点，支持点击跳页、鼠标/触控板横向滚轮翻页和横向拖拽翻页；横向滚轮和拖拽都会驱动整页横向轨道，慢速滑动期间使用较长结束窗口避免过早结算，释放后按页面进度回落到当前页或进入相邻页，首尾页使用阻尼。
- 自定义排序拖拽时使用横向插入槽预览和轻微让位反馈，不让被拖拽或刚操作过的 app 图标变暗。
- `Esc`、全局快捷键或点击空白模糊背景隐藏 OpenLaunch。

## 常用命令

运行测试：

```bash
swift test
```

构建调试版本：

```bash
swift build
```

构建本机 `.app`：

```bash
scripts/build-app.sh
```

打包结果位于：

```text
.build/OpenLaunch.app
```

打包脚本会运行 `scripts/generate-app-icon.swift` 生成 Dock 图标，并写入 `CFBundleIconFile` / `CFBundleIconName`。

本机打开：

```bash
open .build/OpenLaunch.app
```

打包 DMG：

```bash
scripts/package-dmg.sh
```

生成结果：

```text
.build/dist/OpenLaunch-0.1.0.dmg
```

本机安装 DMG：

```bash
open .build/dist/OpenLaunch-0.1.0.dmg
```

打开后把 `OpenLaunch.app` 拖到 `Applications` 即可。

打包 PKG：

```bash
scripts/package-pkg.sh
```

生成结果：

```text
.build/dist/OpenLaunch-0.1.0.pkg
```

命令行安装 PKG：

```bash
sudo installer -pkg .build/dist/OpenLaunch-0.1.0.pkg -target /
```

当前推荐使用 DMG 做本机安装；PKG 作为开发阶段的一键安装备选。两者都是本机 Developer Build 产物，未做 Developer ID 签名和 Apple 公证。对外分发前需要补齐签名、公证和必要的发布元数据。

## 开发规范

- 公共类型和关键系统边界使用中文 `///` 文档注释。
- 类型名使用 UpperCamelCase，方法和属性使用 lowerCamelCase。
- 核心逻辑放在 `OpenLaunchCore`，优先用 XCTest 覆盖。
- UI 和 AppKit 集成保持薄层，避免把扫描、排序、存储逻辑写进视图。
- 遵守 Apple Human Interface Guidelines，优先使用系统材质、系统字体、系统图标和克制控件。
- 用户可见名称使用 `OpenLaunch`，仓库或目录可使用 `open-launch`；不要把连字符形式展示为 app 名。
- 默认排序是添加时间从旧到新，扫描器必须优先读取 Spotlight 添加日期。
- 最近打开排序是从旧到新，未打开应用在前，刚打开的应用排在最后；OpenLaunch 启动和系统应用激活都应更新最近打开记录。
- 自定义排序入口位于主界面设置菜单和状态栏右键菜单的“排序方式 -> 自定义排序（拖动图标）”，进入后通过拖动应用图标调整顺序并持久化；拖拽预览以 Dock 式插入槽表达目标位置。
- 默认扫描路径包括 `/Applications`、`~/Applications`、`/System/Applications`、`/System/Cryptexes/App/System/Applications` 和公开 CoreServices 应用目录；扫描结果应保存真实 bundle 路径，避免 Safari 这类符号链接应用显示别名角标。
- 默认扫描器可以使用 Spotlight 获取候选应用，必须排除系统 framework、daemon、updater、模板 app 等内部 bundle；只过滤 `LSBackgroundOnly`，保留有 UI 或菜单栏入口的 `LSUIElement` 应用。
- Dock 或其他应用激活时必须隐藏覆盖层，避免用户点击 Dock app 后仍停留在 OpenLaunch 全屏界面。
- 覆盖窗口不得长期裁掉底部区域作为 Dock 触发带；自动隐藏 Dock 应通过窗口层级低于 Dock 来浮出。
- 不使用 SwiftUI `WindowGroup` 承载主启动器窗口，主窗口必须由 AppKit 显式创建并禁用窗口恢复。
- 无边框主窗口必须允许成为 key/main window，否则搜索输入和 `Esc` 退出会不稳定。
- 构建产物不声明 `LSUIElement`，避免 LaunchServices 把开发构建当作后台 agent 而无法可靠进入当前 Space；覆盖层可见期间保持 `.regular` 前台身份，让系统栏隐藏策略生效，覆盖层隐藏后再切回 `.accessory`。
- 展示阶段需要短暂忽略系统激活回弹产生的 `NSWorkspace.didActivateApplication`，避免刚打开就被误判为用户切换 app 而隐藏。
- OpenLaunch 不参与 macOS secure window restoration；如果开发阶段出现“上次意外退出，是否重新打开窗口”的系统弹窗，应选择“不重新打开”清掉历史崩溃恢复状态。
- `hideMenuBar` 在 macOS 26.5 上必须同时搭配 `hideDock`，否则 AppKit 会抛 `NSInvalidArgumentException`；为保留 Dock 边缘触发能力，覆盖层可见期间只使用 `autoHideMenuBar` / `autoHideDock`，并通过透明顶部触发拦截层避免菜单栏浮出。
- 覆盖层可见期间临时隐藏 OpenLaunch 状态栏项，避免系统菜单栏被触发时出现 OpenLaunch 图标或空白占位；覆盖层隐藏后恢复状态栏入口。
- 状态栏图标使用 OpenLaunch 自有网格符号设计，不直接复制其他应用图形。
