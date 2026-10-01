# Tahoe Launcher 0.2.0

本项目基于 [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher)，保留原作者版权和 GPL v2+ 许可。这一版为 Plasma 6 增加连续开合、可选 KWin 窗口动画，以及应用浏览性能优化。

## 新版行为

- 打开：缩放 `0.94 → 1`（260ms）、淡入（130ms），从启动按钮方向轻微移动；关闭：缩至 `0.96` 并淡出（180ms）。居中模式围绕中心展开。时长随 KDE 系统动画速度调整。
- 连续操作：打开中关闭、关闭中再次点击，都从当前动画值继续。曲线采用 OutCubic / InCubic 近似平稳收敛的手感；这一版不宣称复刻 Apple 的实际弹簧参数或玻璃折射。
- 自动后端：安装并启用专用 KWin effect 后，窗口、原生玻璃背景与模糊区域在合成器中一同变换。检测不到 effect 时使用 QML 内置动画；每次开合锁定同一个后端，避免中途切换。
- 分类浏览：外层 ListView 按行虚拟化，每个缓存行最多创建一行图标。直接读取原 Kicker 模型角色，启动、右键操作仍使用原模型的应用索引。数据变化时刷新可见项。
- 普通列表/网格：启用委托复用和半屏预缓存；图标共享静态阴影 SVG，去掉逐图标 DropShadow 和高亮的额外 OpacityMask 渲染层。
- 搜索：应用页与结果页在固定内容区域内淡化切换，避免两页同时挤占布局；修正列表的重复滚轮驱动。
- 右键菜单、显示模式菜单和会话菜单打开时，启动器不会因菜单取得焦点而提前关闭。

## 安装（Plasma 6，KWin effect 按 6.7 API 开发）

在源码目录执行：

```sh
sh scripts/install.sh
systemctl --user restart plasma-plasmashell.service
```

脚本安装启动器和专用 effect，备份已有版本到 `~/.local/share/tahoelauncher-backups/`，尝试启用并加载 effect。它不会自动重启桌面。支持 `XDG_DATA_HOME`；`kwriteconfig6` 遵循 `XDG_CONFIG_HOME`。

在系统设置 → 桌面特效中确认 **Tahoe Launcher Motion** 已启用，保留 **模糊** 特效。自动检测需要 `qdbus6` / `qdbus-qt6` / `qdbus`，查询有两秒超时。CachyOS / Arch 可安装提供 Qt 6 qdbus 的 `qt6-tools`。启动器初始化和打开时会查询，查询结果用于下一次开合。

如果只需要内置动画：

```sh
sh scripts/install.sh --launcher-only
```

启动器设置中的“Animation”提供 Automatic / Built-in / Off。KWin effect 仅匹配带有 `TahoeLauncher Motion v2|…` 标记且属于 plasmashell 的窗口；将该窗口设为 Floating 只用于取消通用滑动提示，实际位置仍由启动器计算。其它窗口的缩放/滑动效果不需要全局关闭。

## 回退

将备份目录中的 `launcher/contents` 和 `launcher/metadata.json` 复制回 `~/.local/share/plasma/plasmoids/TahoeLauncher/`，然后重启 plasmashell。在桌面特效中关闭 Tahoe Launcher Motion 即可恢复内置后端；修改后若启动器已打开，先关闭再重新打开。

## 验证

```sh
node tests/motion-effect.test.js
python3 tests/qt-smoke.py  # 需要 PySide6；使用 offscreen Qt Quick
```

JS 测试覆盖专用窗口匹配、隐藏/重新显示、动画反向、模糊生命周期、清理和分类行索引。Qt 测试运行实际内置动画与实际分类列表结构，KDE 专有控件用测试替身，检查 3000 个应用展开/长距离滚动时委托数量有界。

云端没有正在运行的 Plasma/KWin 桌面，因此不能在这里确认原生模糊的视觉衔接、Wayland/X11 窗口标记或 GPU 帧时间。安装后需在目标桌面检查：首次打开、快速连点、Escape、点击外部窗口、右键菜单、分类展开/折叠、应用启动、搜索，以及不同屏幕缩放。120Hz 每帧预算约 8.3ms，60Hz 约 16.7ms；测试委托数量不等同于实测帧率提升。

## English

This fork retains the original TahoeLauncher authorship and GPL v2+ license. Version 0.2.0 adds interruptible launcher motion, an optional dedicated KWin effect with transformed background blur, row virtualization for categorized applications, delegate reuse, shared static icon shadows, and overlapping search transitions.

Run `sh scripts/install.sh` from the repository, then reload plasmashell. Existing packages are backed up. Without the optional effect or qdbus detection, the launcher uses built-in motion. The supplied tests verify Qt Quick behavior and effect lifecycle with mocks; native Plasma/KWin visual and GPU validation must run on the target desktop.
