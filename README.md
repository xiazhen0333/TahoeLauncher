# Tahoe Launcher 0.2.0

本项目基于 [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher)，保留原作者版权和 GPL v2+ 许可。这一版为 Plasma 6 增加连续开合、可选 KWin 窗口动画，以及应用浏览性能优化。材质采用半透明磨砂玻璃。

启动器开合按用户提供的 60 fps 录屏拟合。参数和误差见 [测量记录](docs/macos-motion.md)。这些参数不是 Apple 内部参数。

2026-10-06 修正圆角叠加、边界阴影和冷启动动画跳帧。修复记录与待验证范围见 [TODO](TODO.md)。

![统一圆角、阴影与背景模糊](docs/images/launcher-glass-2026-10-06.png)

## 新版行为

- 开合：面板从较大尺寸缩到正常尺寸，轻微回弹后回稳。打开缩放使用角频率 `23 rad/s`、阻尼比 `0.70` 的弹簧。关闭时放大，并在 `92 ms` 内淡出。缩放中心位于面板中心。时长随 KDE 系统动画速度调整。
- 连续操作：反向时保留缩放位置和速度。关闭淡出结束后才隐藏窗口。关闭中再次点击时，继续使用同一个 Wayland 窗口。
- 内容显现：窗口完成首帧后，整个面板延迟 `30 ms` 开始 `100 ms` 淡入。冷启动的首帧不计入动画时长，淡入期间单步最多推进 `33 ms`。搜索栏和图标同步由模糊变清晰，不再单独延迟图标区。模糊仅在动画期间使用一个前景渲染层；软件渲染保留淡化。Off 模式跳过动画。
- 自动后端：安装并启用专用 KWin effect 后，窗口、玻璃背景与模糊区域在合成器中一同变换。检测不到 effect 时使用 QML 内置动画；每次开合锁定同一个后端，避免中途切换。
- 玻璃材质：浅色半透明底色、32 像素圆角过渡、微光边框与背景模糊。两个后端共用一份玻璃 SVG 和静态柔和阴影。禁用 Plasma Dialog 的主题背景与主题阴影，避免旧主题的较小圆角叠在玻璃圆角上。模糊区域直接读取这份 SVG 的遮罩。颜色跟随 KDE 主题。模糊强度遵循系统设置。
- 布局：内容只保留一层边距。网格宽度容纳设置的完整列数，避免 5 列变成 4 列后留下空列。
- 分类浏览：外层 ListView 按行虚拟化，每个缓存行最多创建一行图标。直接读取原 Kicker 模型角色，启动、右键操作仍使用原模型的应用索引。数据变化时刷新可见项。
- 普通列表/网格：启用委托复用和半屏预缓存；图标共享静态阴影 SVG，去掉逐图标 DropShadow 和高亮的额外 OpacityMask 渲染层。
- 搜索：应用页与结果页在固定内容区域内淡化切换，避免两页同时挤占布局；修正列表的重复滚轮驱动。
- 右键菜单、显示模式菜单和会话菜单打开时，启动器不会因菜单取得焦点而提前关闭。

## 安装（Plasma 6，KWin effect 按 6.7 API 开发）

安装需要 CMake、C++ 编译器、Qt 6.7+ 的 Quick/Qml 开发文件和 KF6WindowSystem 开发文件。脚本先编译小型模糊桥接模块；编译失败时保留已安装版本。

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

启动器设置中的“Animation”提供 Automatic / Built-in / Off。KWin effect 仅匹配带有 `TahoeLauncher Motion v4|…|open/close/settled|缩放,透明度` 标记（兼容 v2/v3）且属于 plasmashell 的窗口；将该窗口设为 Floating 只用于取消通用滑动提示，实际位置仍由启动器计算。其它窗口的缩放/滑动效果不需要全局关闭。

## 回退

将备份目录中的 `launcher/contents` 和 `launcher/metadata.json` 复制回 `~/.local/share/plasma/plasmoids/TahoeLauncher/`，然后重启 plasmashell。在桌面特效中关闭 Tahoe Launcher Motion 即可恢复内置后端；修改后若启动器已打开，先关闭再重新打开。

## 验证

```sh
node tests/motion-effect.test.js
python3 tests/qt-smoke.py  # 需要 PySide6；使用 offscreen Qt Quick
python3 tests/install-smoke.py
```

JS 测试覆盖同步重绘回调重入、专用窗口匹配、隐藏/重新显示、动画反向、模糊生命周期、动画结束后的状态释放和分类行索引。Qt 测试运行实际内置动画与实际分类列表结构，KDE 专有控件用测试替身，检查 3000 个应用展开/长距离滚动时委托数量有界。布局测试检查设置的 5 列完整显示。

安装了 Plasma 与 KSvg 的本机还可执行原生测试：

```sh
cmake -S native -B /tmp/tahoe-glass-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/tahoe-glass-build --parallel 2
TAHOE_GLASS_PLUGIN_DIR=/tmp/tahoe-glass-build/qml TAHOE_NATIVE_DIALOG=1 python3 tests/qt-smoke.py
```

测试检查模糊区域与实际 SVG 遮罩一致、四角透明、主题背景禁用及延迟隐藏。

Wayland 桌面内还可运行真实模糊检查，需要 Spectacle。该检查会短暂显示条纹背景，比较开启与关闭模糊后的截图，并检查重复显示和尺寸变化：

```sh
TAHOE_GLASS_PLUGIN_DIR=/tmp/tahoe-glass-build/qml python3 tests/wayland-blur-smoke.py
```

2026-10-06 本机验证环境：CachyOS、Plasma/KWin 6.7.5、Qt 6.11.2、Wayland、Intel Iris Xe。实际启动器首次打开和连续切换 10 次后均保留背景模糊。真实桌面测试验证首次显示、再次显示和尺寸变化后的模糊，条纹亮度标准差为开启时 `0.00`、关闭时 `25.98`。用户提供当前效果截图，并同意提交和合并。

冷启动回归测试模拟首帧等待和长帧，检查动画开头仍保留。真实重启后的首次唤起尚未验证。桥接模块在 Plasma 的显示与尺寸事件结束后设置遮罩，避免 `NoBackground` 再次清除模糊。

未测量 GPU 帧时间。X11、多屏和不同缩放仍需验证。模糊桥接使用 KWindowEffects API，不再遍历 Plasma Dialog 的内部 FrameSvg 结构。测试委托数量不等同于实测帧率提升。

## English

This fork retains the original TahoeLauncher authorship and GPL v2+ license. Version 0.2.0 adds interruptible motion fitted to a supplied 60 fps recording, an optional KWin effect, and application browsing optimizations. See [motion measurements](docs/macos-motion.md).

Installation requires CMake, a C++ compiler, Qt 6.7+ Quick/Qml development files, and KF6WindowSystem development files. Run `sh scripts/install.sh`, then reload plasmashell. The installer builds the native blur bridge before replacing the installed package and backs up existing packages.

Both animation backends use one SVG for the glass surface, corners, border, shadow, and blur mask. Plasma's separate theme shadow is disabled. The bridge restores blur after Plasma's Wayland expose and resize handlers. Opening waits for the first rendered frame so cold initialization cannot consume the reveal.

Local Wayland checks cover first opening, repeated toggles, resize, rounded masks, animation reversal, and deferred hiding. The current result was accepted for merging on 2026-10-06. A first opening after an actual reboot, X11, multiple monitors, and different display scales remain unverified. GPU frame times have not been measured.
