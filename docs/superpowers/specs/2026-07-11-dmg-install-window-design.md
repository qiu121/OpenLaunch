# OpenLaunch DMG 安装窗口设计

## 背景

当前 DMG 使用纯色背景展示 `OpenLaunch.app` 和 `Applications` 快捷方式，用户能够完成拖拽安装，但两个图标之间缺少明确的方向提示。参考常见 macOS DMG 安装窗口后，本次只补充必要的拖拽指示，不引入品牌大标题、说明文字或装饰纹样。

## 目标

- 用户打开 DMG 后能立即理解需要把 OpenLaunch 拖到 Applications。
- 保持安静、克制的 macOS 系统风格，不让安装窗口显得像营销页面。
- 普通屏幕和 Retina 屏幕上的背景与箭头都保持清晰。
- 本机和 GitHub Actions 使用同一套可复现的背景生成流程。

## 非目标

- 不改变 DMG 文件结构、安装路径或版本命名。
- 不增加许可协议、安装向导、品牌标语或额外操作入口。
- 不修改 OpenLaunch 应用运行时界面。

## 视觉规格

- Finder 窗口维持 `560 × 360`。
- 背景颜色维持 `#F5F7FA`。
- `OpenLaunch.app` 中心维持 `(150, 180)`。
- `Applications` 中心维持 `(410, 180)`。
- 箭头位于两个图标之间，中心为 `(280, 180)`。
- 箭头为水平直箭头，宽约 `82pt`、高约 `24pt`、线宽约 `5pt`。
- 箭头使用中性深灰色和圆角端点，清晰度低于应用图标，不使用阴影、渐变或发光效果。
- 背景不显示 OpenLaunch 标题、安装说明和装饰图案。

## 生成与打包

新增 Swift/AppKit 背景生成脚本，输出以下临时文件：

```text
.build/package-assets/OpenLaunchDMGBackground.png
.build/package-assets/OpenLaunchDMGBackground@2x.png
```

基础图片为 `560 × 360` 像素，HiDPI 图片为 `1120 × 720` 像素。两张图片使用同一套点坐标绘制，保证视觉比例一致。

`scripts/package-dmg.sh` 在运行 `dmgbuild` 前调用背景生成脚本。`scripts/dmgbuild-openlaunch.py` 将 `background` 从颜色值改为基础 PNG 路径。dmgbuild 会发现同名的 `@2x` 文件，并组合为 Finder 可使用的 HiDPI 背景资源。

生成文件继续位于 `.build/`，不提交二进制 PNG 产物。

## 错误处理

- 无法创建输出目录时立即终止打包并输出错误。
- 无法创建位图、图形上下文或 PNG 文件时立即终止。
- 背景生成失败时不继续生成无箭头的 DMG，避免流水线产生外观不完整的安装包。

## 测试与验收

打包约束测试需要验证：

- 背景生成脚本存在，并由 `package-dmg.sh` 调用。
- dmgbuild settings 引用生成的基础背景图片。
- 生成脚本输出 `1x` 和 `2x` 两张图片。
- 两张图片尺寸分别为 `560 × 360` 和 `1120 × 720`。
- DMG 窗口尺寸、图标大小和图标位置保持不变。

人工验收需要验证：

- 打开 DMG 后箭头位于两个图标正中间。
- 箭头不与图标或 Finder 标签重叠。
- 箭头方向明确指向 Applications。
- Retina 屏幕上箭头边缘清晰。
- 窗口没有多余标题、说明文字或装饰元素。

## 文档同步

开发说明补充背景生成脚本和临时产物位置；发布说明补充 DMG 使用 HiDPI 安装背景。README 不增加实现细节。
