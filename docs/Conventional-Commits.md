# Conventional Commits 中文规范

本文档约定 OpenLaunch 的 Git 提交信息格式。目标是让提交记录能清楚表达业务变化、方便回溯版本，并为后续自动生成 changelog 或发布说明保留空间。

## 基本格式

```text
<type>(<scope>): <description>
<type>(<scope>)!: <description>

<body>
```

示例：

```text
feat(settings): 支持排序方向设置

- 用户可以为添加时间、名称、最近打开选择不同顺序。
- 自定义排序继续保持拖拽后的固定顺序，不受方向切换影响。
```

要求：

- `type` 必填。
- `scope` 建议填写，用于说明影响范围。
- `description` 必填，使用简洁中文描述业务变化。
- `body` 建议填写，分点说明用户可感知变化、行为影响和必要技术背景。
- 冒号使用英文半角 `:`，便于后续工具识别。
- 破坏性变化必须在 header 中使用英文半角 `!` 标识，例如 `feat!:` 或 `feat(settings)!:`。

## Description 规范

`description` 应该优先描述“发生了什么业务变化”，不要只写技术动作。

推荐：

```text
fix(search): 重置启动台搜索焦点状态
build(package): 统一安装包版本命名
docs(readme): 完善项目入口文档
```

不推荐：

```text
fix: 修改 SearchField
build: 改脚本
docs: update docs
```

说明：

- 使用中文动词开头，例如 `支持`、`修复`、`统一`、`完善`、`移除`。
- 保持一行，尽量不超过 50 个中文字符。
- 不在 description 末尾加句号。
- 不写“临时处理”“随便改下”“优化一下”这类不可追踪描述。

## Body 规范

`body` 用于补充 description 说不清的内容。优先写业务点，再写技术点。

推荐结构：

```text
- 用户可以...
- 启动台现在会...
- 为避免...，实现上...
```

业务描述优先：

```text
fix(launcher): 修复空白点击无法退出启动台

- 用户点击模糊背景时可以稳定退出全屏启动台。
- 分页模式下由 AppKit 鼠标事件兜底判断空白区域，避免 SwiftUI 手势被分页拖拽吞掉。
```

不推荐只写技术描述：

```text
fix(launcher): 修改 MouseDown

- 调整 LauncherWindow sendEvent。
```

技术描述可以写，但应说明它解决的用户问题。

## 常用 Type

| Type | 用途 | 示例 |
| --- | --- | --- |
| `feat` | 新增用户可感知能力 | `feat(settings): 支持滚动显示模式` |
| `fix` | 修复缺陷或行为回归 | `fix(search): 修复重新进入后残留光标` |
| `docs` | 文档变更 | `docs(readme): 完善项目入口文档` |
| `build` | 构建、打包、依赖、项目配置 | `build(package): 统一安装包版本命名` |
| `test` | 测试新增或调整 | `test(sort): 覆盖最近打开倒序排序` |
| `refactor` | 不改变行为的代码结构调整 | `refactor(scanner): 拆分应用可见性判断` |
| `perf` | 性能优化 | `perf(scanner): 减少重复读取应用元数据` |
| `style` | 代码格式、命名、无行为变化 | `style(ui): 调整菜单项命名格式` |
| `ci` | CI/CD 配置 | `ci(test): 增加 Swift 测试工作流` |
| `chore` | 维护性杂项 | `chore(repo): 更新忽略规则` |
| `revert` | 回滚提交 | `revert: 回滚排序菜单改动` |

## Scope 建议

`scope` 使用小写短横线或单词，表达影响范围。

推荐 scope：

```text
launcher
search
settings
sorting
scanner
status-bar
ui
package
release
readme
docs
tests
```

选择原则：

- 影响用户启动台体验：`launcher`、`ui`。
- 影响搜索框：`search`。
- 影响排序或自定义拖拽：`sorting`。
- 影响应用扫描数量、路径、过滤：`scanner`。
- 影响状态栏入口：`status-bar`。
- 影响 DMG/PKG、版本、构建脚本：`package` 或 `release`。
- 只改 README：`readme`。
- 只改文档：`docs`。

## 破坏性变化

出现不兼容变化时，必须同时满足：

1. 在 header 中使用英文半角 `!` 标识。
2. 在 body 中加入 `BREAKING CHANGE:` 说明影响。

格式：

```text
feat(settings)!: 调整设置文件结构

- 设置文件改为按功能分组保存，便于后续扩展。
- 旧版本设置需要重新生成。

BREAKING CHANGE: 旧的 settings.json 结构不再兼容。
```

不带 scope 时：

```text
feat!: 重建设置存储格式

- 设置数据改为新结构，便于后续支持多配置。

BREAKING CHANGE: 旧版本设置文件需要重新生成。
```

当前阶段尽量避免破坏用户配置；如果不可避免，必须在提交信息中说明迁移影响。

## 拆分提交

一次提交应只表达一个清晰目的。

建议拆分：

- 功能实现和文档更新可以分开。
- 构建脚本和 README 首页可以分开。
- 行为修复和大规模重构应分开。

可以合并：

- 一个小功能及其对应测试。
- 一个 bug 修复及其回归测试。
- 一处文档调整及其文档索引更新。

## OpenLaunch 示例

新增功能：

```text
feat(settings): 支持显示模式切换

- 用户可以在分页和滚动两种启动台布局之间切换。
- 设置会保存到本地，下次打开继续沿用。
```

修复问题：

```text
fix(launcher): 修复点击空白处无法退出

- 用户点击应用图标之外的模糊背景时可以退出全屏启动台。
- 分页拖拽和搜索框交互不会再吞掉空白点击判断。
```

打包发布：

```text
build(package): 统一安装包版本命名

- DMG 和 PKG 使用同一套版本解析规则。
- 有版本 tag 且工作区干净时输出发布包，存在未提交改动时输出开发包。
```

文档：

```text
docs(readme): 完善项目入口文档

- README 顶部展示图标、标语和技术栈徽章。
- 项目结构使用目录级 tree，降低后续文件增减带来的维护成本。
```

## 提交前检查

提交前按变更类型选择必要检查：

```bash
swift test
bash Tests/PackageVersionTests.sh
git diff --check
```

涉及打包脚本时，建议实际运行：

```bash
scripts/package-dmg.sh
scripts/package-pkg.sh
```
