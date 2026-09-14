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
- **自绘磨砂背景**：`PlasmaCore.Dialog` 使用 `NoBackground` 后由 QML 自绘背景——
  运行时通过 `corona.wallpaper()` 取当前壁纸 → `ShaderEffectSource` 裁剪面板区域 →
  `FastBlur` 模糊 → 叠加主题 `dialogs/background`，还原原生 KWin blur 的磨砂玻璃观感。
- **圆角保留**：壁纸模糊层用主题背景的 alpha 作为 `OpacityMask` 蒙版裁剪，主题 SVG 的圆角不会被壁纸填成直角。

### 主要修改文件

- `contents/ui/MenuRepresentation.qml`（动画、自绘背景、关闭路径统一）
- `contents/ui/CompactRepresentation.qml`（按钮 toggle 改为动画感知的 `toggleFromButton()`）

## 安装 / Install

```bash
cp -r . ~/.local/share/plasma/plasmoids/TahoeLauncher
systemctl --user restart plasma-plasmashell.service
```

注意：重装上游 TahoeLauncher 或更新主题会覆盖这些修改。
