# Development Notes

## 本地开发前提
- 项目是 macOS 原生应用工程。
- 当前 target 的最低系统版本是 macOS 15.0。
- 建议使用完整 Xcode 环境进行构建和运行。
- 如果当前机器只有 Command Line Tools，`xcodebuild` 会因为缺少完整 Xcode 而无法完成工程构建。

## 当前工程事实
- 应用主体界面、设置页和菜单栏入口都基于 SwiftUI；菜单栏场景使用 `MenuBarExtra`。
- `Resources/Info.plist` 中启用了 `LSUIElement`，应用默认以菜单栏工具形态运行，不显示 Dock 图标。
- 当前 `AppDependencies.live` 注入的是 `MockQuoteProvider`，因此现阶段所有行情都来自 mock 数据。
- 当前菜单栏点击后展示的是自定义 SwiftUI window-style 下拉面板；bar 顶部 label 保持简单，面板行交互通过独立 `MenuRowView` 提供 SF Symbol 图标、整行点击和 hover 高亮，设置动作会先收起下拉面板再打开设置窗口。
- 当前已接入标准 `Settings` scene，设置页支持勾选菜单栏展示字段，并通过保存/取消按钮控制是否写回持久化配置。
- 当前没有第三方依赖，也没有 Swift Package 依赖。

## 常见修改入口
- 要替换数据源：优先查看 `Sources/Providers` 与 `Sources/App/AppDependencies.swift`。
- 要调整菜单栏展示：优先查看 `Sources/ViewModels/MenuBarViewModel.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift` 和 `Sources/App/LazyBarApp.swift`。
- 如果要继续减少 AppKit 依赖，优先从 `Sources/Views/MenuBar/MenuBarContentView.swift` 里的退出行为入手。
- 要调整菜单内容或设置入口：优先查看 `Sources/Views/MenuBar/MenuBarContentView.swift`、`Sources/Views/MenuBar/BarDropdownView.swift`、`Sources/Views/MenuBar/MenuRowView.swift` 和 `Sources/App/LazyBarApp.swift`。
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
