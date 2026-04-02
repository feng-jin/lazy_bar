# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，主体界面内容仍由 SwiftUI 构建；菜单栏入口和设置弹窗都由 AppKit 承载。状态栏入口使用 `NSStatusItem`，左键通过无箭头的自定义面板承载主面板；主面板分成上半部分的股票列表和下半部分的轻量操作区。SwiftUI scene 仅保留最小生命周期占位，不承接实际设置内容。

应用入口在 `LazyBarApp`，负责创建状态栏控制器、设置窗口控制器，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的单只原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容。
  - `MenuBarDisplaySettings`：菜单栏字段配置与 watchlist 条目列表；每个条目包含股票简称和股票代码。
- `Providers`
  - `QuoteProviding`：数据来源边界协议，按当前 watchlist 中的股票代码返回股票列表。
  - `MockQuoteProvider`：当前 UI prototype 使用的 mock 数据源；每次拉取都会基于基准价生成小幅波动后的最新报价，并按请求的股票代码返回对应 mock 股票。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏 ticker 条目来源、下拉股票列表状态，以及 mock 阶段的定时刷新调度。
  - `StockDetailViewModel`：保留为后续详情扩展使用，当前不接入主交互路径。
- `App`
  - `LazyBarApp`：负责组装依赖，并维持应用生命周期所需的最小 scene。
  - `MenuBarSettingsStore`：持久化菜单栏展示设置，供菜单栏和设置页共享。
  - `StatusBarController`：负责状态栏按钮、左键主面板，以及状态栏标题同步。
  - `SettingsWindowController`：负责设置弹窗的创建、展示和关闭。
- `Views`
  - `SettingsView`：设置弹窗中的菜单栏字段配置视图。
  - 其余 `Detail` 与 `Shared` 视图负责具体展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 将 `MockQuoteProvider` 注入 `MenuBarViewModel`，并将 `MenuBarSettingsStore` 注入 `MenuBarSettingsViewModel`。
3. `LazyBarApp` 创建 `StatusBarController` 与 `SettingsWindowController`。
4. `LazyBarApp` 在装配完成后触发 `MenuBarViewModel.loadIfNeeded()`。
5. `MenuBarViewModel` 首次加载时读取已保存的 watchlist 条目，并调用 `QuoteProviding.fetchQuotes(symbols:)` 获取 `[StockQuote]`，随后按固定间隔重复拉取。
6. ViewModel 将 `[StockQuote]` 转成 `[DisplayQuote]`，并按当前菜单栏展示设置生成 ticker 所需的分栏展示条目与动态列宽；列宽会基于当前股票列表里各列最长文本计算，供 bar 与左键列表共享，整体宽度也会随当前可见列动态收紧或扩展；定时刷新时直接替换最新展示数据。
7. `MenuBarSettingsStore` 从 `UserDefaults` 读取菜单栏展示设置与 watchlist 条目，并由 `MenuBarSettingsViewModel` 同时维护已保存设置和设置页草稿。
8. `StatusBarController` 将 `MenuBarLabelView` 托管到 `NSStatusBarButton` 内部，并根据 `MenuBarViewModel` 产出的动态列宽同步调整状态栏按钮宽度；`MenuBarLabelView` 在裁剪容器里按条目做纵向循环滚动，并使用 `DisplayQuote` 提供的分栏展示数据对齐渲染股票简称、股价与涨跌幅；左键点击后展示的主面板直接观察与 bar 相同的 `MenuBarViewModel` 和 `MenuBarSettingsStore`，上半部分继续复用相同的分栏展示数据、动态列宽与共享样式 token，下半部分只承载设置入口、退出和后续少量操作。
9. 左键主面板中的设置按钮会关闭当前面板，并交由 `SettingsWindowController` 打开承载 `SettingsView` 的独立 AppKit 窗口。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。后续接真实行情时，优先新增 provider 实现，而不是改 View。
- mock 阶段的“实时感”仍通过 `QuoteProviding` + ViewModel 刷新调度来模拟，不把随机波动或拉取时序写进 View。
- `DisplayQuote` 是展示格式化边界。菜单栏 ticker 与左键列表所需的名称、价格、涨跌幅、更新时间以及分栏展示内容应尽量集中在这里或 ViewModel；当 watchlist 中配置了自定义股票简称时，由 ViewModel 在这里统一覆盖展示名称。
- `MenuBarDisplaySettings` 和 `MenuBarSettingsStore` 负责展示配置、watchlist 配置与持久化，`MenuBarSettingsViewModel` 负责设置弹窗中的草稿、股票简称/代码编辑以及保存/取消动作，避免把设置状态散落在 View 里。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调。
- App 层负责 AppKit 壳层装配，不承接业务逻辑、网络逻辑或行情状态计算。
- View 继续负责详情类、设置类以及菜单栏 ticker 的 SwiftUI 渲染；bar 与左键主面板的视觉常量应集中管理并优先共享，滚动动画应限制在固定宽度容器内部，不通过修改 `NSStatusItem` 宽度实现。

## 当前已知事实
- `AppDependencies` 是 mock/real provider 切换的自然入口。
- 当前主交互只依赖 `MenuBarViewModel` 和 `MenuBarSettingsViewModel`；`StockDetailViewModel` 和 Detail 组件仍保留在代码中，但不作为菜单点击后的默认路径。
- 工程没有第三方依赖，运行时只依赖系统框架 `SwiftUI`、`Foundation` 和 `AppKit`。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 刷新调度：当前由 `MenuBarViewModel` 负责 mock 定时拉取；后续接真实行情时，可继续保留在 ViewModel 或抽到独立协调层，但不要直接写进 View。
- watchlist 与设置配置：当前统一通过设置弹窗和 `MenuBarSettingsStore` 维护；后续继续扩展时仍要保持状态与数据边界不下沉到 View。
