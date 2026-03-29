# Development Notes

## 本地开发前提
- 项目是 macOS 原生应用工程。
- 当前 target 的最低系统版本是 macOS 15.0。
- 建议使用完整 Xcode 环境进行构建和运行。
- 如果当前机器只有 Command Line Tools，`xcodebuild` 会因为缺少完整 Xcode 而无法完成工程构建。

## 当前工程事实
- 应用主体界面基于 SwiftUI；菜单栏入口通过 AppKit `NSStatusItem` 提供系统级接入。
- `Resources/Info.plist` 中启用了 `LSUIElement`，应用默认以菜单栏工具形态运行，不显示 Dock 图标。
- `AppDelegate` 中通过 `NSApp.setActivationPolicy(.accessory)` 进一步强化菜单栏工具行为。
- 当前 `AppDependencies.live` 注入的是 `MockQuoteProvider`，因此现阶段所有行情都来自 mock 数据。
- 当前菜单栏点击后展示的是 SwiftUI popover，其中通过 `SettingsLink` 打开设置窗口。
- 当前已接入标准 `Settings` scene，设置页支持勾选菜单栏展示字段和颜色开关。
- 当前菜单栏颜色默认遵循 A 股语义，涨红跌绿，也可以在设置页关闭颜色显示。

## 常见修改入口
- 要替换数据源：优先查看 `Sources/Providers` 与 `Sources/App/AppDependencies.swift`。
- 要调整菜单栏展示：优先查看 `Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/App/AppDelegate.swift`。
- 如果要继续减少 AppKit 依赖，优先保留菜单栏系统接入层不动，先从 `Sources/Views`、`Sources/Models`、`Sources/ViewModels` 往 SwiftUI 语义收敛。
- 要调整菜单内容或设置入口：优先查看 `Sources/App/AppDelegate.swift` 和 `Sources/App/LazyBarApp.swift`。
- 要调整菜单栏展示配置：优先查看 `Sources/Models/MenuBarDisplaySettings.swift`、`Sources/App/MenuBarSettingsStore.swift`、`Sources/ViewModels/MenuBarSettingsViewModel.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。
- 要调整详情面板原型：优先查看 `Sources/ViewModels/StockDetailViewModel.swift` 和 `Sources/Views/Detail`。
- 要调整展示格式化：优先查看 `Sources/Models/DisplayQuote.swift`。
- 要确认应用启动与场景装配：优先查看 `Sources/App/LazyBarApp.swift`。

## 已知限制
- 当前只有单标的 mock 数据链路，没有真实行情。
- 当前还没有多标的轮播实现。
- 当前没有刷新调度、交易时段逻辑和 watchlist 配置。
- 当前仓库没有补齐完整测试体系，文档与结构清晰度优先于功能扩张速度。

## 文档职责
- 本文件只记录本地开发前提、工程事实和常见修改入口。
- agent 协作规则统一放在 `AGENTS.md`。
- 产品定位统一放在 `docs/product.md`。
- 架构与数据流统一放在 `docs/architecture.md`。
