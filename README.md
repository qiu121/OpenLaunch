<p align="center">
  <img src="Resources/OpenLaunchAppIcon.iconset/icon_512x512.png" width="128" alt="OpenLaunch Logo">
</p>

<h1 align="center">OpenLaunch</h1>

<p align="center">
  简易实现的 macOS 全屏启动台。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.x-orange" alt="Swift">
  <img src="https://img.shields.io/badge/AppKit-%2B%20SwiftUI-0A84FF" alt="AppKit + SwiftUI">
  <img src="https://img.shields.io/badge/Package-SwiftPM-lightgrey" alt="Swift Package Manager">
</p>

OpenLaunch 专注一件事：用全屏网格快速找到并打开 app。

## 功能

- 全屏覆盖式启动台，不进入 macOS 原生绿色全屏 Space。
- 展示应用图标和名称，点击后打开目标 app 并隐藏 OpenLaunch。
- 支持搜索框实时过滤，退出后重置搜索文本和焦点。
- 支持分页网格和滚动模式。
- 支持添加时间、名称、最近打开、自定义排序。
- 添加时间、名称、最近打开支持正序和倒序。
- 自定义排序支持拖拽调整顺序并持久化。
- 应用安装或移除后自动刷新列表。

## 快速开始

运行测试：

```bash
swift test
```

构建本机 `.app`：

```bash
scripts/build-app.sh
```

打开开发构建：

```bash
open .build/OpenLaunch.app
```

打包 DMG：

```bash
scripts/package-dmg.sh
```

打开安装包：

```bash
open .build/dist/OpenLaunch-<package-version>.dmg
```

打开 DMG 后，把 `OpenLaunch.app` 拖到 `Applications` 即可。

## 项目结构

```text
.
├── Package.swift                         # SwiftPM 包定义
├── README.md                             # 项目入口文档
├── Resources/                            # App 图标资源
├── Sources/
│   ├── OpenLaunch/                       # AppKit + SwiftUI 应用层
│   └── OpenLaunchCore/                   # 可测试核心逻辑
├── Tests/
│   ├── OpenLaunchCoreTests/              # 核心逻辑单元测试
│   └── PackageVersionTests.sh            # 安装包版本命名测试
├── docs/
│   ├── Conventional-Commits.md           # 提交信息规范
│   ├── Development.md                    # 开发说明
│   ├── OpenLaunch-PRD.md                 # 产品需求文档
│   └── Release.md                        # 发布和打包说明
└── scripts/                              # 构建、图标生成和打包脚本
```

## 文档

- [PRD](docs/OpenLaunch-PRD.md)：产品定位、MVP 范围、验收标准和版本规划。
- [开发说明](docs/Development.md)：环境要求、当前行为、常用命令和工程规范。
- [发布说明](docs/Release.md)：版本策略、tag、DMG/PKG 产物和本机安装流程。
- [提交规范](docs/Conventional-Commits.md)：Conventional Commits 中文规范和 OpenLaunch 示例。

## 版本与安装包

OpenLaunch 使用 Git tag 标记发布节点，安装包文件名由 `scripts/resolve-package-version.sh` 生成：

```text
OpenLaunch-<package-version>.dmg
OpenLaunch-<package-version>.pkg
```

示例：

```text
OpenLaunch-0.1.0.dmg
OpenLaunch-0.1.0-alpha.1.dmg
OpenLaunch-0.1.0-dev.dmg
```

详细规则见 [发布说明](docs/Release.md)。
