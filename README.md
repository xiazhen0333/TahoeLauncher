# Tahoe Launcher 0.2.0

本项目基于 [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher)，保留原作者版权和 GPL v2+ 许可。这一版为 Plasma 6 增加连续开合、可选 KWin 窗口动画，以及应用浏览性能优化。材质采用半透明磨砂玻璃。

## 新版行为

- 开合：缩放在 `0.91 → 1` 之间变化。临界阻尼弹簧先加速，再逐渐减速到目标。参数随 KDE 系统动画速度调整。长帧的单次进度步长限制为 33ms，避免首次创建窗口时跳过开头。
- 连续操作：改变目标时保留当前位置和速度。关闭动画结束后才隐藏窗口。关闭中再次点击时，继续使用同一个 Wayland 窗口。这一版没有使用 Apple 的实际弹簧参数。
- 内容显现：面板先出现，图标区延迟约 60ms 淡入，并由模糊变清晰。模糊使用一个内容区域渲染层，开合动画结束后关闭；软件渲染使用淡入。Off 模式跳过开合与显现动画。
- 自动后端：安装并启用专用 KWin effect 后，窗口、原生玻璃背景与模糊区域在合成器中一同变换。检测不到 effect 时使用 QML 内置动画；每次开合锁定同一个后端，避免中途切换。
- 玻璃材质：浅色半透明底色、平滑大圆角、微光边框与背景模糊。原生后端使用主题阴影，避免两层阴影产生额外外框；内置后端使用静态柔和阴影。颜色跟随 KDE 主题。模糊强度遵循系统设置。
- 布局：内容只保留一层边距。网格宽度容纳设置的完整列数，避免 5 列变成 4 列后留下空列。
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

启动器设置中的“Animation”提供 Automatic / Built-in / Off。KWin effect 仅匹配带有 `TahoeLauncher Motion v4|…|open/close/settled|缩放,透明度` 标记（兼容 v2/v3）且属于 plasmashell 的窗口；将该窗口设为 Floating 只用于取消通用滑动提示，实际位置仍由启动器计算。其它窗口的缩放/滑动效果不需要全局关闭。

## 回退

将备份目录中的 `launcher/contents` 和 `launcher/metadata.json` 复制回 `~/.local/share/plasma/plasmoids/TahoeLauncher/`，然后重启 plasmashell。在桌面特效中关闭 Tahoe Launcher Motion 即可恢复内置后端；修改后若启动器已打开，先关闭再重新打开。

## 验证

```sh
node tests/motion-effect.test.js
python3 tests/qt-smoke.py  # 需要 PySide6；使用 offscreen Qt Quick
```

JS 测试覆盖同步重绘回调重入、专用窗口匹配、隐藏/重新显示、动画反向、模糊生命周期、动画结束后的状态释放和分类行索引。Qt 测试运行实际内置动画与实际分类列表结构，KDE 专有控件用测试替身，检查 3000 个应用展开/长距离滚动时委托数量有界。布局测试检查设置的 5 列完整显示。

安装了 Plasma 与 KSvg 的本机还可执行 `TAHOE_NATIVE_DIALOG=1 python3 tests/qt-smoke.py`。测试检查原生 SVG 的圆角模糊遮罩及延迟隐藏。

本机验证环境：CachyOS、Plasma/KWin 6.7.5、Qt 6.11.2、Wayland、Intel Iris Xe。新弹簧预览版的 30 次快速切换（间隔 65ms）使用同一个窗口标识。关闭完成后，窗口才销毁。打开结束和关闭完成后，专用 effect 均释放动画状态。本机验证保留 5 列布局、左右边距和玻璃背景。弹簧测试检查反转时位置与速度连续，以及 60Hz/144Hz 的同一时刻进度一致。

未测量 GPU 帧时间。X11、多屏和不同缩放仍需验证。原生材质替换依赖 Plasma Dialog 的内部 FrameSvg 结构；本机已验证 6.7.5，其他版本需复测。测试委托数量不等同于实测帧率提升。

## English

This fork retains the original TahoeLauncher authorship and GPL v2+ license. Version 0.2.0 adds interruptible launcher motion, an optional dedicated KWin effect with transformed background blur, row virtualization for categorized applications, delegate reuse, shared static icon shadows, and overlapping search transitions.

Run `sh scripts/install.sh` from the repository, then reload plasmashell. Existing packages are backed up. Without the optional effect or qdbus detection, the launcher uses built-in motion. The launcher keeps its Wayland window mapped during close. A shared critically damped spring preserves position and velocity on reversal. The application area follows the panel with a short delayed fade and blur reveal, using one temporary rendering layer. Frosted glass uses theme colors, smooth corners and a matching blur mask. Layout tests cover all five configured columns. Native behavior and appearance were checked on Plasma/KWin 6.7.5 with Wayland; GPU frame times and X11 remain unmeasured.
