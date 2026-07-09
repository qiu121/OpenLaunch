# App List Change Animation Design

## Goal

OpenLaunch 自动检测到新安装应用后，在用户下一次打开启动台时，让新增应用以一次性轻弹动画进入网格；删除应用不做退场动画，只让现有图标自然重排。

## Scope

- 只标记自动扫描发现的新增应用。
- 只在下一次显示启动台时播放一次新增动画。
- 不缓存已删除应用图标，不展示卸载后的幽灵图标。
- 搜索、分页切换、手动排序、手动重新扫描不额外触发新增动画。

## Approach

在核心层新增列表变更摘要，按 `LaunchableApp.stableKey` 比较扫描前后的应用集合。`AppState` 在自动目录刷新完成后记录新增 id，并在启动台即将显示时暴露给 SwiftUI；`ContentView` 对这些 id 对应的 `AppTile` 应用 `scale + opacity` 的短弹簧动画，播放后清空待展示 id。

## Animation

- 新增图标初始状态：`scale 0.82`，`opacity 0`。
- 展示状态：`scale 1.0`，`opacity 1.0`。
- 动画曲线：短弹簧，接近现有分页和拖拽预览的响应速度。
- 大批新增时最多突出前 6 个新增项，其余随布局重排，不逐个强调。

## Testing

- 核心测试验证列表 diff 能识别新增项，并忽略删除项动画。
- `AppState` 测试或可测试策略验证自动刷新记录新增 id，手动扫描不触发。
- SwiftUI 动画细节以结构化状态和编译验证为主，不做像素级测试。
