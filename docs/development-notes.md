# Development Notes

## 本地开发前提
- 项目是 macOS 原生应用工程。
- 当前 target 的最低系统版本是 macOS 15.0。
- 建议使用完整 Xcode 环境进行构建和运行。
- 如果当前机器只有 Command Line Tools，`xcodebuild` 会因为缺少完整 Xcode 而无法完成工程构建。

## 当前工程事实
- 应用主体界面内容基于 SwiftUI；菜单栏入口和设置弹窗壳层使用 AppKit。状态栏入口使用 `NSStatusItem`，左键通过无箭头的自定义面板展示主面板；主面板上半部分是股票列表，下半部分是设置、退出和后续少量功能入口。
- `Resources/Info.plist` 中启用了 `LSUIElement`，应用默认以菜单栏工具形态运行，不显示 Dock 图标。
- 当前 `AppDependencies.live` 注入的是 `SinaQuoteProvider`，默认通过新浪财经未公开快照接口拉取 A 股准实时行情，并按固定节奏轮询刷新；`MockQuoteProvider` 仍保留给 Preview、调试和后续兜底场景使用。
- 当前应用首次启动时 watchlist 为空；设置页录入或编辑 watchlist 时只要求 6 位股票代码，简称由用户手动维护，并持久化到本地。
- 当前状态栏宽度在无行情数据时也会按空态/错误态文案计算；首次启动且 watchlist 为空时显示“请先添加股票”，避免状态栏只剩极窄空白区域。
- 当前状态栏使用 SwiftUI ticker view 按股票上下循环播放摘要；ticker 与左键主面板上半部分的股票列表会共享同一套列结构、主副文字体风格、数值字体风格，以及按当前股票里最长字段动态计算出的列宽，因此股票简称、股票代码、股价、涨跌幅都能整列对齐并完整显示，遇到更长的文本时，bar 和左键面板会一起扩展宽度，而不是用 `...` 截断；关闭部分字段后，bar 和左键面板也会随剩余列一起收紧，不再保留固定最小宽度。当前 bar 与左键列表中的股票简称、股票代码、股价、涨跌幅均统一为 12pt，并共用同一套列间距；其中股票简称与股票代码共用同一套主标识颜色和字重，避免视觉节奏不一致。左键点击后会从状态栏图标下方展开无箭头的主面板，其容器材质、圆角、分隔线和 hover 态已向 macOS 原生菜单观感收敛，并与状态栏按钮保持同一宽度；股票列表与底部操作区共享同一套行内边距、分隔线起点和紧凑纵向节奏，减少视觉断层；面板外层仅保留纵向留白，因此股票列表内容的左右起止位置会与 bar 对齐；股票展示区达到固定高度上限后会滚动，避免 watchlist 增长时继续撑高面板。
- 当前设置能力通过独立设置弹窗承载，不再把设置表单直接内嵌到左键主面板里；展示字段编辑与 watchlist 维护继续通过 `MenuBarSettingsViewModel` 管理草稿、行内编辑、保存前校验、保存和取消。设置窗口内容区由显式约束填满窗口的 `NSHostingView` 承载，并在展示前按 SwiftUI 内容高度同步窗口尺寸，避免弹窗打开但内容空白；当前窗口宽度已放宽，并将设置内容拆成两个 tab，以避免长表单继续把底部操作区挤出可视范围。
- 设置页当前分成“监控股票”和“展示字段”两个 tab；watchlist tab 已收敛为单段式编辑区，顶部一行录入简称和代码并直接触发添加，下方是带表头的固定高度列表，只保留必要输入、删除和行间分隔，以减少卡片嵌套层级；顶部录入区继续使用原生 SwiftUI `TextField`；展示字段 tab 中使用两列卡片式勾选项，每个字段补充用途说明，减少原先一行一个 `Toggle` 的冗长感；列表本身会在固定高度内滚动，底部保存和取消区域固定在窗口底部，避免随着上方内容变长而消失；保存会立即写回持久化配置但保留弹窗，取消会放弃本轮未保存草稿并关闭窗口。
- 当前没有第三方依赖，也没有 Swift Package 依赖。

## 常见修改入口
- 要替换数据源：优先查看 `Sources/Providers` 与 `Sources/App/AppDependencies.swift`。
- 要调整状态栏标题、ticker 动画或点击行为：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整主面板内容或股票列表项：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/QuotesPopoverView.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整菜单栏展示配置：优先查看 `Sources/Models/MenuBarDisplaySettings.swift`、`Sources/App/MenuBarSettingsStore.swift`、`Sources/ViewModels/MenuBarSettingsViewModel.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。
- 要调整默认 watchlist 行为或持久化逻辑：优先查看 `Sources/Models/MenuBarDisplaySettings.swift` 和 `Sources/App/MenuBarSettingsStore.swift`。
- 要调整详情面板原型：优先查看 `Sources/ViewModels/StockDetailViewModel.swift` 和 `Sources/Views/Detail`。
- 要调整展示格式化：优先查看 `Sources/Models/DisplayQuote.swift`。
- 要确认应用启动、状态栏装配与设置弹窗：优先查看 `Sources/App/LazyBarApp.swift`、`Sources/App/StatusBarController.swift`、`Sources/App/SettingsWindowController.swift`、`Sources/Views/MenuBar/QuotesPopoverView.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。

## 已知限制
- 当前真实行情依赖新浪未公开快照接口，接口格式、可用性和限流策略都可能随时变化。
- 当前没有真实行情对应的交易时段逻辑；watchlist 已支持本地持久化维护，但当前只做固定节奏轮询，没有接入交易所级推送或停牌/收盘态专门处理。
- 当前仓库没有补齐完整测试体系，文档与结构清晰度优先于功能扩张速度。

## 文档职责
- 本文件只记录本地开发前提、工程事实和常见修改入口。
- agent 协作规则统一放在 `AGENTS.md`。
- 产品定位统一放在 `docs/product.md`。
- 架构与数据流统一放在 `docs/architecture.md`。
