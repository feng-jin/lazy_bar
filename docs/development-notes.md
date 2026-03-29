# Development Notes

## 本地开发前提
- 项目是 macOS 原生应用工程。
- 当前 target 的最低系统版本是 macOS 15.0。
- 建议使用完整 Xcode 环境进行构建和运行。
- 如果当前机器只有 Command Line Tools，`xcodebuild` 会因为缺少完整 Xcode 而无法完成工程构建。

## 当前工程事实
- 应用主体界面内容基于 SwiftUI；菜单栏入口和设置窗口壳层使用 AppKit。状态栏入口使用 `NSStatusItem`，左键通过无箭头的自定义面板展示股票列表，右键通过 `NSMenu` 展示系统菜单。
- `Resources/Info.plist` 中启用了 `LSUIElement`，应用默认以菜单栏工具形态运行，不显示 Dock 图标。
- 当前 `AppDependencies.live` 注入的是 `MockQuoteProvider`，因此现阶段所有行情都来自 mock 数据；当前 mock 数据会按固定节奏重复拉取，并围绕基准价生成小幅波动，模拟准实时更新。
- 当前状态栏使用 SwiftUI ticker view 按股票上下循环播放摘要；ticker 与左键列表会共享同一套列结构、列间距、主副文字体风格、数值字体风格，以及按当前股票里最长字段动态计算出的列宽，因此股票简称、股价、涨跌幅都能整列对齐，遇到更长的股价或涨跌幅时，bar 和左键面板会一起扩展宽度；若系统可用宽度仍不足，则优先压缩股价列。左键点击后会从状态栏图标下方展开无箭头的股票列表面板，其容器材质、圆角、分隔线和 hover 态已向 macOS 原生菜单观感收敛，并优先与状态栏按钮使用同一宽度和左右边界对齐；面板高度会按当前内容真实测量并随股票个数自适应，超过上限后再滚动；右键点击后会从状态栏图标下方展开设置和退出系统菜单。
- 当前右键菜单保持纯 AppKit `NSMenu`；设置入口通过 `SettingsWindowController` 打开独立 AppKit 窗口，不使用 `SettingsLink` 或 `Settings` scene。
- 设置页支持勾选菜单栏展示字段，并通过保存/取消按钮控制是否写回持久化配置。
- 当前没有第三方依赖，也没有 Swift Package 依赖。

## 常见修改入口
- 要替换数据源：优先查看 `Sources/Providers` 与 `Sources/App/AppDependencies.swift`。
- 要调整状态栏标题、ticker 动画或点击行为：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整菜单内容或股票列表项：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/QuotesPopoverView.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整菜单栏展示配置：优先查看 `Sources/Models/MenuBarDisplaySettings.swift`、`Sources/App/MenuBarSettingsStore.swift`、`Sources/ViewModels/MenuBarSettingsViewModel.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。
- 要调整详情面板原型：优先查看 `Sources/ViewModels/StockDetailViewModel.swift` 和 `Sources/Views/Detail`。
- 要调整展示格式化：优先查看 `Sources/Models/DisplayQuote.swift`。
- 要确认应用启动、状态栏装配与设置窗口：优先查看 `Sources/App/LazyBarApp.swift`、`Sources/App/StatusBarController.swift` 和 `Sources/App/SettingsWindowController.swift`。

## 已知限制
- 当前还没有真实行情。
- 当前没有真实行情对应的交易时段逻辑和 watchlist 配置；仅有 mock 阶段的定时刷新模拟。
- 当前仓库没有补齐完整测试体系，文档与结构清晰度优先于功能扩张速度。

## 文档职责
- 本文件只记录本地开发前提、工程事实和常见修改入口。
- agent 协作规则统一放在 `AGENTS.md`。
- 产品定位统一放在 `docs/product.md`。
- 架构与数据流统一放在 `docs/architecture.md`。
