# OpenLaunch 开发说明

## 环境要求

- macOS 26.x 或兼容版本。
- Xcode 26.6。
- Swift 6.3.x。
- uv 0.11.x 或兼容版本，用于运行锁定的 DMG 打包工具链。

当前项目使用 Swift Package Manager 组织代码：

- `OpenLaunchCore`：可测试核心逻辑，包括应用模型、排序、扫描和设置存储。
- `OpenLaunch`：AppKit 主循环 + SwiftUI 内容视图的可执行应用，包括窗口、状态栏入口、快捷键和启动应用。

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
- 状态栏图标左键直接显示 OpenLaunch 全屏覆盖层；右键或 Control 点击只展示“重新扫描 / 退出”维护菜单。
- Dock 图标使用 `Resources/OpenLaunchAppIcon.icns`，接近系统 Apps 入口图标气质；状态栏图标继续使用现有 SF Symbols 网格符号。
- 全屏背景默认使用系统背景的模糊处理。
- 默认排序为添加时间从旧到新，新添加的软件在最后；设置菜单在根层展示排序类型，需要方向的类型再展开具体顺序。
- 默认分页网格保持 7×5，图标默认尺寸为 96×96。
- 全屏覆盖层显示时不展示顶部系统菜单栏整块区域；OpenLaunch 的菜单栏状态项作为退出覆盖层后的启动入口保留。
- 默认应用扫描合并 Spotlight 应用索引和文件系统扫描，使用用户可见路径策略覆盖公开应用目录、用户独立 `.app` 和少量共享支持目录。
- 首次建立应用目录时校验 Spotlight `kMDItemDateAdded`，异常或缺失时降级为文件创建时间、文件修改时间；建档后持久化每个应用的添加时间，自动更新不改变原有顺序，新发现应用使用发现时间。
- OpenLaunch 使用 macOS FSEvents 递归监听默认扫描目录变化，不做后台定时轮询；检测到安装、删除或移动后会在防抖后后台重新扫描。
- 自动刷新发现新增应用后，只在下一次显示启动台时播放一次新增图标入场动画；分页模式会定位到第一个新增应用所在页；删除应用不做退场动画，手动重新扫描不触发新增动画。
- 顶部居中液态玻璃风格搜索框，包含放大镜图标、清除按钮和舒适内边距；搜索框右侧提供弱化设置菜单入口，菜单使用 AppKit 原生 `NSMenu`、少量系统组间分隔线，不使用会吞掉功能图标或插入额外分割线的 SwiftUI `Menu`/inline Picker；选中项左侧保留独立勾选列，右侧保留原功能图标；初始进入不主动显示输入光标，用户点击搜索框或直接输入文字后再聚焦并实时过滤；退出覆盖层时重置搜索文本和焦点状态，避免下次进入残留插入光标。
- 底部仅显示分页圆点，支持点击跳页、鼠标/触控板横向滚轮翻页和横向拖拽翻页；横向滚轮和拖拽都会驱动整页横向轨道，慢速滑动期间使用较长结束窗口避免过早结算，释放后按页面进度回落到当前页或进入相邻页，首尾页使用阻尼。
- 自定义排序拖拽时使用横向插入槽预览和轻微让位反馈，不让被拖拽或刚操作过的 app 图标变暗。
- `Esc`、全局快捷键或点击空白模糊背景隐藏 OpenLaunch；分页模式下点击空白由 AppKit 本地鼠标事件做兜底判断，避免透明 SwiftUI 手势被分页拖拽或嵌入式搜索框吃掉。

## 常用命令

运行测试：

```bash
swift test
```

运行安装包版本与打包约束测试：

```bash
bash Tests/PackageVersionTests.sh
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

DMG 脚本会通过根目录 `uv run --locked` 运行固定版本 `dmgbuild==1.6.7`，并使用根目录 `uv.lock` 锁定传递依赖。默认不需要手动创建 Python 虚拟环境；如果需要使用外部环境，可通过 `DMGBUILD_BIN=/path/to/dmgbuild scripts/package-dmg.sh` 指定。

DMG 安装窗口布局使用 `scripts/dmgbuild-openlaunch.py` 的 dmgbuild 原生 settings 配置，不再保留 appdmg 兼容 JSON 配置。

DMG 安装背景由 `scripts/generate-dmg-background.swift` 在打包时生成，普通和 Retina PNG 写入 `.build/package-assets/`。这些图片属于临时构建产物，不提交到仓库。

应用的 `CFBundleVersion` 默认由 `scripts/resolve-build-number.sh` 使用完整 Git 历史的提交计数生成，确保系统能区分连续安装的构建并刷新 Dock 图标。浅克隆或源码归档需要通过 `OPENLAUNCH_BUILD_NUMBER` 注入正整数构建号；GitHub Actions 使用单调递增的工作流运行编号。

生成结果：

```text
.build/dist/OpenLaunch-<package-version>.dmg
```

`package-version` 由 `scripts/resolve-package-version.sh` 解析：

- 当前提交有 `v` 开头的版本 tag，且工作区干净时，使用 tag 版本，例如 `OpenLaunch-0.1.0-alpha.1.dmg`。
- 当前提交没有版本 tag 时，使用 App 版本加 `-dev`，例如 `OpenLaunch-0.1.0-dev.dmg`。
- 当前提交有版本 tag 但工作区存在未提交改动时，仍标记为开发包，例如 `OpenLaunch-0.1.0-alpha.1-dev.dmg`。

本机安装 DMG：

```bash
open .build/dist/OpenLaunch-<package-version>.dmg
```

打开后把 `OpenLaunch.app` 拖到 `Applications` 即可。

打包 PKG：

```bash
scripts/package-pkg.sh
```

生成结果：

```text
.build/dist/OpenLaunch-<package-version>.pkg
```

命令行安装 PKG：

```bash
sudo installer -pkg .build/dist/OpenLaunch-<package-version>.pkg -target /
```

当前推荐使用 DMG 做本机安装；PKG 作为开发阶段的一键安装备选。两者都是本机 Developer Build 产物，未做 Developer ID 签名和 Apple 公证。对外分发前需要补齐签名、公证和必要的发布元数据。

更完整的版本和发布流程见 `docs/Release.md`。

## 文档索引

- `README.md`：仓库入口、快速开始、当前状态和文档导航。
- `docs/Conventional-Commits.md`：Conventional Commits 中文规范和提交示例。
- `docs/OpenLaunch-PRD.md`：产品定位、MVP 范围、验收标准和版本规划。
- `docs/Development.md`：开发环境、当前行为、常用命令和工程规范。
- `docs/Release.md`：版本策略、tag、DMG/PKG 打包和本机安装流程。

## 开发规范

- 公共类型和关键系统边界使用中文 `///` 文档注释。
- 提交信息遵循 `docs/Conventional-Commits.md`，description 使用中文业务描述，body 优先说明用户可感知变化。
- 类型名使用 UpperCamelCase，方法和属性使用 lowerCamelCase。
- 核心逻辑放在 `OpenLaunchCore`，优先用 XCTest 覆盖。
- UI 和 AppKit 集成保持薄层，避免把扫描、排序、存储逻辑写进视图。
- 遵守 Apple Human Interface Guidelines，优先使用系统材质、系统字体、系统图标和克制控件。
- 用户可见名称使用 `OpenLaunch`，仓库或目录可使用 `open-launch`；不要把连字符形式展示为 app 名。
- 默认排序是添加时间从旧到新；首次建档使用校验后的系统元数据，后续以本地目录保存的首次发现时间为准，用户可切换为“最近添加”倒序。
- 最近打开排序默认从旧到新，未打开应用在前，刚打开的应用排在最后；用户可切换为“最近打开”倒序；OpenLaunch 启动和系统应用激活都应更新最近打开记录。
- 名称排序支持 `A 到 Z` 和 `Z 到 A`；自定义排序不应用排序方向，始终按用户拖拽后的顺序展示。
- 应用展示名优先使用 Spotlight 展示名和本地化 `InfoPlist` 资源；搜索必须保留原始英文名、`.app` 文件名和 bundle identifier 的命中能力。
- 自定义排序入口在排序分组根层显示为“自定义”；普通排序入口在排序分组下直接显示“添加时间 / 名称 / 最近打开”，再展开具体顺序；进入自定义后通过拖动应用图标调整顺序并持久化，拖拽预览以 Dock 式插入槽表达目标位置。
- 默认扫描路径包括 `/Applications`、`~/Applications`、`/System/Applications`、`/System/Cryptexes/App/System/Applications` 和公开 CoreServices 应用目录；扫描结果应保存真实 bundle 路径，避免 Safari 这类符号链接应用显示别名角标。
- 默认扫描路径会通过递归文件系统事件监听应用安装、删除和移动；自动刷新使用防抖，不使用定时轮询。
- 新增应用入场动画最多突出 6 个新增项，避免大批安装时产生过多动效。
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
