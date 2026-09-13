# Dock Click Minimize

[English](#english) | [简体中文](#简体中文)

## English

Dock Click Minimize is a tiny, native macOS utility that adds a Windows-style Dock toggle:

- Click the Dock icon of the already frontmost app → minimize its front normal window.
- Click the same Dock icon again → let macOS restore it natively.
- Click another app → keep macOS's normal activation behavior.

It is written in Objective-C and built directly with Apple's Command Line Tools. There is no Xcode project, Electron, Node.js, Python runtime, WebView, SwiftUI, third-party GUI framework, polling loop, or background daemon.

### Download

Download the latest `DockClickMinimize-vX.Y.Z-macOS-arm64.zip` from [Releases](../../releases/latest), unzip it, and move `DockClickMinimize.app` to `~/Applications` or `/Applications`.

The release is ad-hoc signed, not notarized with a paid Apple Developer certificate. If macOS blocks the first launch, Control-click the app, choose **Open**, and confirm once.

### Requirements

- macOS 13.0 or later
- Apple Silicon for the published arm64 release
- Accessibility permission

Only Accessibility is needed. The app does not request Input Monitoring, Screen Recording, Automation, or network access.

### Usage

1. Launch `DockClickMinimize.app`.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable the currently installed `DockClickMinimize.app` entry.
4. Use the settings window to enable or disable the Dock behavior.

The first launch opens a small native settings window. `Command-W` closes that window and keeps the listener running in the background; `Command-Q` quits the app. The optional menu bar item can reopen the settings window.

The settings window has a `CN / EN` switch in the upper-right corner. The default is `CN`, and the selection is saved locally. Settings, the application menu, and the menu bar menu follow the selected language.

### Behavior boundaries

The listener observes only `leftMouseDown` events through a session-level, listen-only `CGEventTap`. It never intercepts or stores input.

The app acts only when all of the following are true:

1. The clicked Dock item is an application, not Trash, a folder, a Stack, Launchpad, or a recent item.
2. The clicked application matches the current frontmost application by Bundle ID.
3. The app has one eligible normal window.
4. The window is not already minimized and is not full screen.

The original click is always passed through to the Dock. No action is taken for background apps, apps without a normal window, minimized windows, full-screen windows, or modified clicks.

### Build from source

Install Apple's Command Line Tools if needed:

```sh
xcode-select --install
```

Build without Xcode:

```sh
cd DockClickMinimize
./build.sh
```

Install the verified build into the current user's Applications folder:

```sh
./build.sh install
open "$HOME/Applications/DockClickMinimize.app"
```

The build uses `clang`, `AppKit.framework`, `ApplicationServices.framework`, and `CoreGraphics.framework`. The `ARCH` environment variable can be used for a source build of another architecture, for example `ARCH=x86_64 ./build.sh`.

### Project layout

```text
DockClickMinimize/
├── main.m
├── DockMonitor.m
├── DockMonitor.h
├── build.sh
├── Info.plist
└── README.md
```

The menu bar menu is created only when its icon is clicked and released after it closes, keeping the idle process small. On the author's Apple Silicon test machine, the installed app is about 1.3 MB and idles around 31 MB physical footprint with the menu bar icon enabled.

### Icon and implementation

The bundled Dock icon is an independent redraw in the style of the open-source window-minimize icon from [Tabler Icons](https://tabler.io/icons). Tabler Icons is MIT-licensed ([license](https://github.com/tabler/tabler-icons/blob/main/LICENSE)); no third-party library is linked at runtime.

The implementation is independent and does not copy code from other projects. The Dock hit-test and window operations use public macOS Accessibility and Core Graphics APIs.

---

## 简体中文

一个极轻量的 macOS 菜单栏 utility：当某个应用已经在前台时，再点击它的 Dock 图标，只最小化当前最前面的一个普通窗口；点击非前台应用的 Dock 图标则完全交给 macOS 默认处理。

## 构建

不需要 Xcode 工程、Node.js、Python Runtime 或第三方 GUI 框架。只需 macOS Command Line Tools：

```sh
cd DockClickMinimize
./build.sh
```

生成：

```text
DockClickMinimize/DockClickMinimize.app
```

如果项目目录位于 iCloud、FileProvider 或其他会自动附加 Finder 元数据的位置，建议直接构建并安装到用户 Applications 目录：

```sh
./build.sh install
open "$HOME/Applications/DockClickMinimize.app"
```

安装模式每次都从全新的临时 staging bundle 签名，不会把工作区的 Finder 元数据带进 App；安装完成后会进行严格签名校验。

## 运行与权限

```sh
open DockClickMinimize.app
```

这是一个带彩色 Dock 图标和菜单栏图标的原生 App；启动时会打开一个很小的设置窗口，之后也可以从 Dock 或右上角菜单栏图标的 `Open Settings…` 打开。设置窗口里的 `Keep in Menu Bar` 用于保留或恢复菜单栏状态项。设置窗口打开时显示 Dock 图标；`Command+W` 关闭窗口后只隐藏 Dock 图标，程序仍留在后台继续监听，菜单栏状态项保持可用；再次打开设置时恢复 Dock 图标。`Command+Q` 才退出程序。若 Finder 首次提示无法验证开发者，请对 App 右键选择“打开”，再确认一次；终端中的 `open DockClickMinimize.app` 也可以直接启动本地构建版本。

设置窗口右上角提供 `CN / EN` 语言切换，首次运行默认 CN；选择会保存到本机偏好设置，并同步更新设置窗口、应用菜单和菜单栏菜单。

首次运行后，打开“系统设置 → 隐私与安全性 → 辅助功能”，将当前正在运行的 `DockClickMinimize.app` 加入并启用。程序不会反复弹出权限请求。若系统列表中已有旧的同名条目，请先移除旧条目，再添加当前 App；macOS 会按代码签名身份保存 Accessibility 授权。

当前构建使用固定的 ad-hoc designated requirement，重复执行 `./build.sh` 不会因为普通的代码重编译改变 TCC 身份。第一次授权请针对当前这个 App 条目打开 Accessibility，然后点击设置窗口中的 `Refresh Status`。

菜单栏菜单包含：

- `Enabled`
- `Accessibility: Granted / Not Granted`
- 一句功能说明

设置窗口包含 `Keep in Menu Bar` 开关；关闭时移除菜单栏状态项，重新打开时从这里恢复。`Enabled` 和菜单栏开关都会保存到本机偏好设置。窗口关闭不会退出程序；关闭 `Enabled` 时，状态会显示为 `Disabled`。
- `Quit`

`Start at Login` 暂未加入，以保持第一版的体积与依赖最小；后续可单独使用 `SMAppService` 增加。

## 行为边界

程序只监听 `leftMouseDown`，不监听键盘，不轮询 Dock，也不记录输入。

1. 使用 `kCGSessionEventTap` 的 listen-only 模式观察 `leftMouseDown`，不拦截、不修改原始鼠标事件。
2. 通过 `AXUIElementCopyElementAtPosition` 判断鼠标下方是否为 `AXApplicationDockItem`。
3. 验证命中的 AX 元素属于 Dock；优先使用 Dock `AXURL` 对应的 Bundle ID 与 `NSWorkspace.frontmostApplication` 做精确比较，只有 Dock 没有提供应用 URL 时才退回比较标题。
4. 仅当两者相同，才查询 `AXFocusedWindow`、`AXMainWindow`、`AXWindows`。
5. 找到一个可最小化、非全屏、非已最小化的普通窗口后，等待 Dock 完成原生点击处理，再设置 `AXMinimized = true`。
6. 原始点击始终 pass through 给 Dock，所以第二次点击已最小化窗口时由 macOS 原生恢复。

以下情况明确 pass through：后台应用、非应用 Dock item、Trash/文件夹/Stack/Launchpad、没有普通窗口、窗口已最小化、全屏窗口、带 Command/Option/Control/Shift 修饰键的点击，以及 Accessibility 不可用。

## 依赖与权限

- 系统 Framework：`AppKit.framework`、`ApplicationServices.framework`、`CoreGraphics.framework`
- Accessibility：需要，用于 Dock hit-test 和窗口 AX 操作
- Input Monitoring：不需要。本程序只观察 session-level 鼠标点击，不监听键盘，也不创建 HID-level 或 active event tap
- Screen Recording：不需要
- Automation / Apple Events：不需要

## 设计与取舍

界面采用原生 `NSWindow`、`NSStackView`、`NSStatusItem` / `NSMenu`，没有 WebView、Electron、SwiftUI、私有 SkyLight API 或后台 daemon。菜单栏状态菜单只在点击图标时创建，关闭后立即释放，避免菜单项图结构常驻内存。Dock 图标是一个本地 `.icns` 资源，图形基于 [Tabler Icons](https://tabler.io/icons) 的开源窗口最小化风格重新绘制；Tabler Icons 使用 MIT 许可证（[许可证](https://github.com/tabler/tabler-icons/blob/main/LICENSE)），运行时不引入任何第三方库。窗口关闭时通过系统的 accessory activation policy 隐藏 Dock 图标，但不影响菜单栏功能；开机自启留到后续阶段，避免为了一个开关引入额外状态管理。

## 许可证

本目录中的实现为独立实现，不复制第三方项目代码。相关实现思路参考了公开资料与 Apple Accessibility / Core Graphics 文档。
