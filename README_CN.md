# Dock Click Minimize

[English](README.md) | 简体中文

Dock Click Minimize 是一个极轻量的原生 macOS 小工具，为 Dock 增加类似 Windows 任务栏的切换行为：

- 当前应用已经在前台时，点击它的 Dock 图标，最小化当前最前面的普通窗口。
- 再次点击同一个 Dock 图标，让 macOS 使用原生行为恢复窗口。
- 点击其他应用时，保持 macOS 默认的切换行为。

项目使用 Objective-C 编写，并直接通过 Apple Command Line Tools 构建。不使用 Xcode 工程、Electron、Node.js、Python Runtime、WebView、第三方 GUI 框架、轮询或后台 daemon。

## 截图

下面是实际原生设置窗口和菜单栏菜单的截图。图片已经脱敏，不包含桌面内容、文件名、账户名称或运行时数据。

### 设置窗口

![Dock Click Minimize 中文设置窗口](docs/images/settings-cn.png)

### 菜单栏菜单

![Dock Click Minimize 中文菜单栏菜单](docs/images/menu-cn.png)

## 下载

从 [Releases](https://github.com/tmzw8cgfzr-oss/DockClickMinimize/releases/latest) 下载最新的 `DockClickMinimize-vX.Y.Z-macOS-arm64.zip`，解压后将 `DockClickMinimize.app` 移动到 `~/Applications` 或 `/Applications`。

Release 使用 ad-hoc 签名，没有使用付费 Apple Developer 证书进行公证。如果 macOS 首次阻止启动，请按住 Control 点击 App，选择“打开”并确认一次。

## 系统要求

- macOS 13.0 或更高版本
- 已发布的 arm64 版本需要 Apple Silicon
- 辅助功能权限

程序只需要辅助功能权限，不请求 Input Monitoring、屏幕录制、自动化或网络权限。

## 使用方法

1. 启动 `DockClickMinimize.app`。
2. 打开“系统设置 → 隐私与安全性 → 辅助功能”。
3. 启用当前安装的 `DockClickMinimize.app` 条目。
4. 在设置窗口中启用或停用 Dock 点击行为。

首次启动会打开一个小型原生设置窗口。`Command-W` 只关闭设置窗口，监听程序仍在后台运行；`Command-Q` 才会退出程序。启用菜单栏图标后，可以从菜单栏重新打开设置窗口。

设置窗口右上角提供 `CN / EN` 切换，首次运行默认选择 `CN`，选择会保存在本机。设置窗口、应用菜单和菜单栏菜单会跟随当前语言。

## 行为边界

程序只通过 session-level、listen-only 的 `CGEventTap` 观察 `leftMouseDown`，不会拦截或保存输入。

只有同时满足以下条件时才执行最小化：

1. 命中的 Dock Item 是应用，而不是废纸篓、文件夹、Stack、Launchpad 或最近使用项目。
2. 被点击的应用通过 Bundle ID 与当前 frontmost application 相同。
3. 应用存在一个符合条件的普通窗口。
4. 窗口没有已经最小化，也不是 macOS 全屏窗口。

原始点击始终 pass through 给 Dock。后台应用、没有普通窗口的应用、已经最小化的窗口、全屏窗口、带修饰键的点击都会直接交给 macOS 默认处理。

## 从源码构建

如果尚未安装 Apple Command Line Tools，可以执行：

```sh
xcode-select --install
```

不需要 Xcode，直接构建：

```sh
./build.sh
```

安装经过校验的构建版本：

```sh
./build.sh install
open "$HOME/Applications/DockClickMinimize.app"
```

构建使用 `clang`、`AppKit.framework`、`ApplicationServices.framework` 和 `CoreGraphics.framework`。如需构建其他架构，可以设置 `ARCH`，例如：

```sh
ARCH=x86_64 ./build.sh
```

## 项目结构

```text
DockClickMinimize/
├── main.m
├── DockMonitor.m
├── DockMonitor.h
├── build.sh
├── Info.plist
├── docs/images/
│   ├── settings-en.png
│   ├── settings-cn.png
│   ├── menu-en.png
│   └── menu-cn.png
└── README_CN.md
```

菜单栏菜单只在用户点击图标时创建，关闭后立即释放，减少空闲内存占用。在作者的 Apple Silicon 测试机上，安装后的 App 约 1.3 MB；保留菜单栏图标时，空闲物理内存占用约 31 MB。

## 图标与实现

App 内置的 Dock 图标是参考 [Tabler Icons](https://tabler.io/icons) 中开源的窗口最小化图标风格独立重绘的；Tabler Icons 使用 MIT 许可证（[许可证](https://github.com/tabler/tabler-icons/blob/main/LICENSE)），运行时不链接任何第三方库。

实现独立完成，没有复制其他项目的代码。Dock 命中判断和窗口操作使用 macOS 公开的 Accessibility 与 Core Graphics API。

## 许可证

当前项目还没有添加许可证文件。仓库公开并不自动授予广泛的复制、修改和再发布权利；如果希望明确授权方式，可以再添加合适的开源许可证。
