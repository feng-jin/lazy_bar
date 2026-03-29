# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，主体界面内容仍由 SwiftUI 构建；菜单栏入口和设置窗口都由 AppKit 承载。状态栏入口使用 `NSStatusItem`，左键与右键都通过 `NSMenu` 承载各自菜单；设置窗口则由独立 `NSWindowController` 管理。

应用入口在 `LazyBarApp`，负责创建状态栏控制器、设置窗口控制器，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的单只原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容。
  - `MenuBarDisplaySettings`：菜单栏字段配置。
- `Providers`
  - `QuoteProviding`：数据来源边界协议，当前返回股票列表。
  - `MockQuoteProvider`：当前 UI prototype 使用的 mock 数据源；每次拉取都会基于基准价生成小幅波动后的最新报价。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏紧凑标签状态、当前轮播股票、下拉股票列表状态，以及 mock 阶段的定时刷新调度。
  - `StockDetailViewModel`：保留为后续详情扩展使用，当前不接入主交互路径。
- `App`
  - `LazyBarApp`：负责组装依赖，并维持应用生命周期所需的最小 scene。
  - `MenuBarSettingsStore`：持久化菜单栏展示设置，供菜单栏和设置页共享。
  - `StatusBarController`：负责状态栏按钮、左键股票列表菜单、右键系统菜单，以及状态栏标题同步。
  - `SettingsWindowController`：负责设置窗口的创建、展示和关闭。
- `Views`
  - `SettingsView`：设置窗口中的菜单栏字段配置界面。
  - 其余 `Detail` 与 `Shared` 视图负责具体展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 将 `MockQuoteProvider` 注入 `MenuBarViewModel`，并将 `MenuBarSettingsStore` 注入 `MenuBarSettingsViewModel`。
3. `LazyBarApp` 创建 `StatusBarController` 与 `SettingsWindowController`。
4. `LazyBarApp` 在装配完成后触发 `MenuBarViewModel.loadIfNeeded()`。
5. `MenuBarViewModel` 首次加载时调用 `QuoteProviding.fetchQuotes()` 获取 `[StockQuote]`，随后按固定间隔重复拉取。
6. ViewModel 将 `[StockQuote]` 转成 `[DisplayQuote]`，并在内部维护当前轮播中的状态栏摘要项；定时刷新后会保留当前轮播位置，只替换对应股票的最新展示数据。
7. `MenuBarSettingsStore` 从 `UserDefaults` 读取菜单栏展示设置，并由 `MenuBarSettingsViewModel` 同时维护已保存设置和设置页草稿。
8. `StatusBarController` 将当前轮播摘要 `DisplayQuote` 和展示设置组合成状态栏标题；列表项文案继续由 `DisplayQuote` 提供，左键点击后展示股票列表菜单，右键点击后展示系统菜单。
9. 右键选择设置后，由 `SettingsWindowController` 打开承载 `SettingsView` 的 AppKit 窗口。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。后续接真实行情时，优先新增 provider 实现，而不是改 View。
- mock 阶段的“实时感”仍通过 `QuoteProviding` + ViewModel 刷新调度来模拟，不把随机波动或拉取时序写进 View。
- `DisplayQuote` 是展示格式化边界。菜单栏名称、价格、涨跌幅、更新时间以及下拉列表文案应尽量集中在这里或 ViewModel。
- `MenuBarDisplaySettings` 和 `MenuBarSettingsStore` 负责展示配置与持久化，`MenuBarSettingsViewModel` 负责设置页草稿与保存/取消动作，避免把设置状态散落在 View 里。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调。
- App 层负责 AppKit 壳层装配，不承接业务逻辑、网络逻辑或行情状态计算。
- View 继续负责详情类和设置类 SwiftUI 界面的渲染，不承接业务逻辑、网络逻辑或跨层状态协调。

## 当前已知事实
- `AppDependencies` 是 mock/real provider 切换的自然入口。
- 当前主交互只依赖 `MenuBarViewModel` 和 `MenuBarSettingsViewModel`；`StockDetailViewModel` 和 Detail 组件仍保留在代码中，但不作为菜单点击后的默认路径。
- 工程没有第三方依赖，运行时只依赖系统框架 `SwiftUI`、`Foundation` 和 `AppKit`。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 刷新调度：当前由 `MenuBarViewModel` 负责 mock 定时拉取；后续接真实行情时，可继续保留在 ViewModel 或抽到独立协调层，但不要直接写进 View。
- watchlist 与设置配置：应通过 `Settings` scene 扩展入口，同时保持状态与数据边界不下沉到 View。
