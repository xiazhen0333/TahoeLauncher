# Tahoe Launcher

一个 macOS 风格的 KDE Plasma 应用启动器。

基于 [EliverLara/TahoeLauncher](https://github.com/EliverLara/TahoeLauncher)，这个分支加入了可连续反向的开合动画、磨砂玻璃背景和应用浏览优化。

![Tahoe Launcher 应用分类视图](docs/images/launcher-glass-2026-10-06.png)

## 功能

- 按分类浏览应用，或切换为网格、列表视图
- 搜索应用，访问收藏和关机、重启等会话操作
- 开合时缩放、淡化；连续点击可随时改变动画方向
- 半透明玻璃背景、圆角和背景模糊，颜色跟随 KDE 主题
- 可选 KWin 动画，让窗口和背景模糊一起缩放
- 自定义启动器图标、图标大小、行列数和弹出位置

## 安装

需要 KDE Plasma 6。安装脚本会编译原生模糊模块，因此还需要：

- CMake 3.16 或更高版本
- 支持 C++17 的编译器
- Qt 6.7 或更高版本的 Quick、Qml 开发文件
- KF6WindowSystem 开发文件

可选 KWin 动画按 KWin 6.7 API 开发。当前桌面验证环境为 CachyOS、Plasma/KWin 6.7.5、Qt 6.11.2 和 Wayland。

1. 下载源码。

   ```sh
   git clone --branch master https://github.com/xiazhen0333/TahoeLauncher.git
   cd TahoeLauncher
   ```

2. 安装启动器和 KWin 动画。

   ```sh
   sh scripts/install.sh
   ```

   脚本先编译模糊模块，成功后安装到当前用户目录。已有版本会备份到 `~/.local/share/tahoelauncher-backups/`；设置了 `XDG_DATA_HOME` 时使用对应目录。

3. 重新加载 Plasma。

   ```sh
   systemctl --user restart plasma-plasmashell.service
   ```

4. 在面板的“添加小部件”中搜索 **Tahoe Launcher**，将它添加到面板。

在“系统设置 → 桌面特效”中启用 **Tahoe Launcher Motion** 和 **模糊**。动画自动检测需要 Qt 6 的 `qdbus` 工具；CachyOS / Arch 由 `qt6-tools` 提供。

如果只使用内置动画，安装时执行：

```sh
sh scripts/install.sh --launcher-only
```

此方式仍会编译模糊模块，但不安装或启用 KWin 动画。

## 使用

点击面板图标打开启动器，在顶部输入应用名称即可搜索。点击左上角图标可切换全部应用与收藏。右上角菜单可切换显示方式。

右键点击面板图标，打开启动器设置。**Animation** 提供 3 个选项：

- **Automatic**：优先使用 KWin 动画，不可用时使用内置动画
- **Built-in**：使用内置动画
- **Off**：关闭开合动画

## 开发与反馈

欢迎提交修复、翻译和使用反馈。报告问题时，请注明 Plasma、KWin、Qt 版本，以及 Wayland / X11、显示缩放和复现步骤。

测试命令与验证范围见 [开发文档](docs/development.md)。动画参数见 [测量记录](docs/macos-motion.md)，待验证问题见 [TODO](TODO.md)。

## 来源与许可

原项目由 [EliverLara](https://github.com/EliverLara) 开发，本分支保留原作者及其他贡献者的版权声明。

代码采用 [GPL-2.0-or-later](LICENSE)。Feather 和 Lucide 图标分别采用 [MIT](contents/ui/icons/feather/LICENSE) 和 [ISC](contents/ui/icons/lucide/LICENSE) 许可。
