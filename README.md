# Tahoe Launcher（macOS 动画增强版）

> 本项目是 [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher) 的修改版（fork），
> 版权与许可归原作者所有（GPL v2+）。原仓库的说明见上游 README。
>
> This is a modified fork of [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher).
> All credit for the original plasmoid goes to [EliverLara](https://github.com/EliverLara).

## 本 fork 的改动 / Changes in this fork

在 Plasma 6.7 (CachyOS) 上为启动器加上 macOS 26 (Tahoe) 风格的呼出 / 关闭动画：

- **打开动画**：面板从轻微模糊、缩小 (0.94)、透明状态放大聚焦到正常状态（250ms，OutCubic）。
- **关闭动画**：所有关闭路径统一走「模糊 + 缩小 (0.9) + 淡出」（300ms，OutCubic），包括：
  点击应用启动、按 Escape、点击 dock/面板按钮、点击桌面空白处或切换到其他窗口。
- **真实 KWin 背景模糊**：面板使用 `PlasmaCore.Types.StandardBackground`，由 PlasmaQuick 向
  KWin 请求真正的背景模糊（`KWindowEffects::enableBlurBehind`，模糊区域按主题背景 SVG 裁形），
  背后是壁纸还是其他窗口都能正确模糊。
  合成器的模糊区域固定在窗口上、无法跟随缩放与淡出，因此只在动画结束后开启：
  打开动画结束时置 `blurEnabled = true`，关闭动画开始时立刻置回 `false`。
- **自绘背景 + 隐藏原生背景**：主题 `dialogs/background` 仍由 `panel` 内的 `KSvg.FrameSvgItem`
  自绘（这样它才参与缩放/淡出动画），PlasmaQuick 自己绘制的那份在 `Component.onCompleted`
  中隐藏，避免叠成两层静态边框。模糊区域来自 SVG 裁形而非该项是否可见，隐藏它不影响模糊。

### 主要修改文件

- `contents/ui/MenuRepresentation.qml`（动画、自绘背景、关闭路径统一）
- `contents/ui/CompactRepresentation.qml`（按钮 toggle 改为动画感知的 `toggleFromButton()`）

## 安装 / Install

```bash
cp -r . ~/.local/share/plasma/plasmoids/TahoeLauncher
systemctl --user restart plasma-plasmashell.service
```

注意：重装上游 TahoeLauncher 或更新主题会覆盖这些修改。
