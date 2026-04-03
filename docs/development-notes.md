# Development Notes

## 本地开发前提
- 项目是 macOS 原生应用工程。
- 当前 target 的最低系统版本是 macOS 15.0。
- 建议使用完整 Xcode 环境进行构建和运行。
- 如果当前机器只有 Command Line Tools，`xcodebuild` 会因为缺少完整 Xcode 而无法完成工程构建。

## 当前工程事实
- 应用主体界面内容基于 SwiftUI；菜单栏入口和设置弹窗壳层使用 AppKit。状态栏入口使用 `NSStatusItem`，左键通过无箭头的自定义面板展示主面板；主面板上半部分是股票列表，下半部分是设置、退出和后续少量功能入口。
- `Resources/Info.plist` 中启用了 `LSUIElement`，应用默认以菜单栏工具形态运行，不显示 Dock 图标。
- 当前 `AppDependencies.live` 注入的是 `SinaQuoteProvider`，默认通过新浪财经未公开快照接口拉取 A 股准实时行情，并按 A 股交易时段动态轮询刷新：交易时段每 3 秒一次，非交易时段最长每 10 分钟一次；若下一次长轮询会跨过 09:30 或 13:00 等交易恢复边界，调度器会在边界时刻提前唤醒，避免开盘后的前几分钟继续停更；`MockQuoteProvider` 仍保留给 Preview、调试和后续兜底场景使用。
- 当前应用首次启动时 watchlist 为空；设置页录入或编辑 watchlist 时只要求 6 位股票代码，简称由用户手动维护，并持久化到本地。
- 当前状态栏宽度在无行情数据时也会按空态/错误态文案计算；首次启动且 watchlist 为空时显示“请先添加股票”，避免状态栏只剩极窄空白区域。
- 当前状态栏使用 SwiftUI ticker view 按股票上下循环播放摘要；ticker 与左键主面板上半部分的股票列表会共享同一套列结构、主副文字体风格、数值字体风格，以及按当前股票里最长字段动态计算出的列宽，因此股票简称、股票代码、股价、涨跌幅都能整列对齐并完整显示，遇到更长的文本时，bar 和左键面板会一起扩展宽度，而不是用 `...` 截断；关闭部分字段后，bar 和左键面板也会随剩余列一起收紧，不再保留固定最小宽度。当前 bar 与左键列表中的股票简称、股票代码、股价、涨跌幅均统一为 12pt；四个字段当前统一按各自列宽右对齐，以便让字段尾部边界更整齐；其中股票简称与股票代码共用同一套主标识颜色和字重，避免视觉节奏不一致，同时身份列到股价列之间会使用比其余列更宽的前导间距，避免价格位数变化时名称与股价看起来贴得过近。左键点击后会从状态栏图标下方展开无箭头的主面板，其容器材质、圆角、分隔线和 hover 态已向 macOS 原生菜单观感收敛，并与状态栏按钮保持同一宽度；股票列表与底部操作区共享同一套行内边距、分隔线起点和紧凑纵向节奏，减少视觉断层；面板外层仅保留纵向留白，因此股票列表内容的左右起止位置会与 bar 对齐；股票展示区达到固定高度上限后会滚动，避免 watchlist 增长时继续撑高面板。
- 当前共享列宽测量与行渲染已经从 `MenuBarViewModel` 抽离到菜单栏视图层辅助对象中，并通过 `MenuBarPresentation` 统一产出 bar ticker 与左键股票列表共用的 rows 和 layout；A 股交易时段对应的刷新间隔计算也已下沉到独立的 `QuoteRefreshScheduler`。`MenuBarViewModel` 主要负责数据拉取、刷新、`DisplayQuote` 生成，以及 `loading / emptyWatchlist / failed / loaded` 的显式状态协调。当 watchlist 在加载过程中被修改时，旧请求会被取消，只有当前仍被跟踪的请求结果允许回写 UI，避免过期行情重新出现在 bar 或主面板里。共享列宽测量当前要求与 SwiftUI 实际渲染使用同一套字体语义和字号，避免字体测量与真实显示不一致导致的列宽误差。这样既避免继续耦合 `AppKit` 字体测量细节，也避免把状态语义散落到 View 里推断。
- 当前设置能力通过独立设置弹窗承载，不再把设置表单直接内嵌到左键主面板里；展示字段编辑与 watchlist 维护继续通过 `MenuBarSettingsViewModel` 的单一草稿模型管理行内编辑、保存前校验、保存和取消，其中展示字段至少要保留一项可见，避免菜单栏和主面板进入空展示状态。展示字段的枚举定义、卡片文案和实际渲染可见性判断统一收敛到 `MenuBarDisplaySettings`，避免设置页勾选项和 bar / 主面板展示出现映射漂移。设置窗口内容区由显式约束填满窗口的 `NSHostingView` 承载，并在展示前按 SwiftUI 内容高度同步窗口尺寸，避免弹窗打开但内容空白；当前窗口宽度已放宽，并将设置内容拆成两个 tab，以避免长表单继续把底部操作区挤出可视范围。
- 设置页当前分成“监控股票”和“展示字段”两个 tab；watchlist tab 已收敛为单段式编辑区，顶部一行录入简称和代码并直接触发添加，下方是带表头的固定高度列表，只保留必要输入、删除和行间分隔，以减少卡片嵌套层级；顶部录入区继续使用原生 SwiftUI `TextField`；展示字段 tab 中使用两列卡片式勾选项，每个字段补充用途说明，减少原先一行一个 `Toggle` 的冗长感；列表本身会在固定高度内滚动，底部保存和取消区域固定在窗口底部，避免随着上方内容变长而消失；保存会立即写回持久化配置但保留弹窗，取消会放弃本轮未保存草稿并关闭窗口。
- 当前没有第三方依赖，也没有 Swift Package 依赖。

## 常见修改入口
- 要替换数据源：优先查看 `Sources/Providers` 与 `Sources/App/AppDependencies.swift`。
- 要调整状态栏标题、ticker 动画或点击行为：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/MenuBarLabelView.swift`、`Sources/Views/MenuBar/MenuBarPresentation.swift`、`Sources/Views/MenuBar/MenuBarStyle.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整主面板内容或股票列表项：优先查看 `Sources/App/StatusBarController.swift`、`Sources/Views/MenuBar/QuotesPopoverView.swift`、`Sources/Views/MenuBar/MenuBarPresentation.swift`、`Sources/Views/MenuBar/MenuBarStyle.swift`、`Sources/Views/MenuBar/QuoteColumnLayout.swift`、`Sources/Views/MenuBar/QuoteColumnsRowView.swift`、`Sources/ViewModels/MenuBarViewModel.swift` 和 `Sources/Models/DisplayQuote.swift`。
- 要调整菜单栏展示配置：优先查看 `Sources/Models/MenuBarDisplaySettings.swift`、`Sources/App/MenuBarSettingsStore.swift`、`Sources/ViewModels/MenuBarSettingsViewModel.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。
- 要调整默认 watchlist 行为或持久化逻辑：优先查看 `Sources/Models/MenuBarDisplaySettings.swift` 和 `Sources/App/MenuBarSettingsStore.swift`。
- 要调整展示格式化：优先查看 `Sources/Models/DisplayQuote.swift`。
- 要确认应用启动、状态栏装配与设置弹窗：优先查看 `Sources/App/LazyBarApp.swift`、`Sources/App/StatusBarController.swift`、`Sources/App/SettingsWindowController.swift`、`Sources/Views/MenuBar/QuotesPopoverView.swift` 和 `Sources/Views/MenuBar/SettingsView.swift`。

## 已知限制
- 当前真实行情依赖新浪未公开快照接口，接口格式、可用性和限流策略都可能随时变化。
- 当前交易时段逻辑只覆盖 A 股常规工作日连续竞价时段，按上海时区在工作日 9:30-11:30、13:00-15:00 期间每 3 秒轮询一次，其余时间最长每 10 分钟轮询一次，并在 9:30、13:00 这类交易恢复边界提前唤醒；尚未接入交易所节假日日历、盘前盘后特殊时段、停牌态专门处理或交易所级推送。
- 当前仓库没有补齐完整测试体系，文档与结构清晰度优先于功能扩张速度。

## 文档职责
- 本文件只记录本地开发前提、工程事实和常见修改入口。
- agent 协作规则统一放在 `AGENTS.md`。
- 产品定位统一放在 `docs/product.md`。
- 架构与数据流统一放在 `docs/architecture.md`。
