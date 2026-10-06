# 开发与验证

项目由 Plasma 小部件、原生模糊模块和可选 KWin 动画组成。

| 目录 | 内容 |
| --- | --- |
| `contents/` | QML 界面、配置和翻译 |
| `native/` | Qt / KDE 背景模糊模块 |
| `kwin/tahoelauncher-motion/` | KWin 窗口动画 |
| `scripts/` | 安装脚本 |
| `tests/` | 动画、布局和安装测试 |
| `translate/` | 翻译源文件和翻译说明 |

## 基础测试

需要 Node.js、Python 3 和 PySide6。持续集成使用 Node.js 22、Python 3.11 和 PySide6 6.7.3。

在仓库根目录执行：

```sh
node tests/motion-effect.test.js
python3 tests/qt-smoke.py
python3 tests/install-smoke.py
```

JavaScript 测试检查窗口匹配、动画反向、模糊生命周期和分类索引。Qt 测试使用离屏渲染，检查实际动画、5 列布局，以及 3000 个应用的分类浏览。KDE 专有控件使用测试替身。安装测试检查备份、路径含空格和编译失败时保留已有版本。

## 原生模糊测试

需要 Plasma、KSvg，以及 [README](../README.md#安装) 中列出的开发文件。

```sh
cmake -S native -B /tmp/tahoe-glass-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/tahoe-glass-build --parallel 2
TAHOE_GLASS_PLUGIN_DIR=/tmp/tahoe-glass-build/qml TAHOE_NATIVE_DIALOG=1 python3 tests/qt-smoke.py
```

测试检查 SVG 模糊遮罩、四角透明、主题背景禁用和延迟隐藏。

Wayland 桌面内可检查实际背景模糊。此测试需要 Spectacle，会短暂显示条纹背景并截图。

```sh
TAHOE_GLASS_PLUGIN_DIR=/tmp/tahoe-glass-build/qml python3 tests/wayland-blur-smoke.py
```

## 动画与背景

开合参数来自录屏测量，详见 [动画测量记录](macos-motion.md)。反向时保留缩放位置和速度，关闭淡出结束后隐藏窗口。打开动画等待首帧，避免初始化耗时跳过动画开头。

两个动画后端共用 `contents/ui/materials/glass.svg`。原生模块把 SVG 遮罩传给 KWindowEffects，并在 Plasma 的显示与尺寸事件结束后恢复模糊。

KWin 动画只匹配带有 `TahoeLauncher Motion` 标记且属于 plasmashell 的窗口。自动检测支持 `qdbus6`、`qdbus-qt6` 和 `qdbus`，查询超时为 2 秒。每次开合固定使用同一个动画后端；检测结果用于下一次开合。

## 验证范围

以下是 2026-10-06 的已有验证记录：CachyOS、Plasma/KWin 6.7.5、Qt 6.11.2、Wayland、Intel Iris Xe。

- 实际启动器首次打开和连续切换 10 次后均保留背景模糊
- 桌面测试覆盖首次显示、再次显示和尺寸变化
- 条纹亮度标准差：开启模糊为 `0.00`，关闭模糊为 `25.98`
- 冷启动回归测试覆盖模拟首帧等待和长帧

实际重启后的首次唤起、X11、多屏和不同显示缩放仍需验证。GPU 帧时间尚未测量；测试中的委托数量不能直接证明帧率提升。

## 恢复备份

安装脚本输出备份路径。将备份中的 `launcher/contents` 和 `launcher/metadata.json` 复制回安装目录，再重新加载 Plasma。默认安装目录为 `~/.local/share/plasma/plasmoids/TahoeLauncher/`。

如需恢复备份中的 KWin 动画，将 `effect/contents` 和 `effect/metadata.json` 复制回 `~/.local/share/kwin/effects/tahoelauncher-motion/`。在桌面特效中重新加载 **Tahoe Launcher Motion**，或关闭它以使用内置动画。设置了 `XDG_DATA_HOME` 时，上述安装路径使用对应目录。
