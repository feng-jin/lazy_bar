# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，主体界面、设置页和菜单栏入口都基于 SwiftUI 构建；菜单栏场景使用 `MenuBarExtra`。

应用入口在 `LazyBarApp`，负责创建菜单栏场景和设置场景，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容。
  - `MenuBarDisplaySettings`：菜单栏字段配置。
- `Providers`
  - `QuoteProviding`：数据来源边界协议。
  - `MockQuoteProvider`：当前 UI prototype 使用的 mock 数据源。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏紧凑标签状态。
  - `StockDetailViewModel`：保留为后续详情扩展使用，当前不接入主交互路径。
- `App`
  - `LazyBarApp`：负责组装依赖，并声明 `MenuBarExtra` 与 `Settings` 两个场景。
  - `MenuBarSettingsStore`：持久化菜单栏展示设置，供菜单栏和设置页共享。
- `Views`
  - `MenuBarContentView`：菜单栏点击后弹出的 SwiftUI window 内容，使用 `SettingsLink` 打开设置窗口。
  - `MenuBarLabelView`：菜单栏标签视图，根据 `MenuBarViewModel` 与展示设置生成紧凑文案。
  - `SettingsView`：设置窗口中的菜单栏字段配置界面。
  - 其余 `Detail` 与 `Shared` 视图负责具体展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 将 `MockQuoteProvider` 注入 `MenuBarViewModel`，并将 `MenuBarSettingsStore` 注入 `MenuBarSettingsViewModel`。
3. `LazyBarApp` 在装配完成后触发 `MenuBarViewModel.loadIfNeeded()`。
4. ViewModel 调用 `QuoteProviding.fetchQuote()` 获取 `StockQuote`。
5. ViewModel 将 `StockQuote` 转成 `DisplayQuote`。
6. `MenuBarSettingsStore` 从 `UserDefaults` 读取菜单栏展示设置，并由 `MenuBarSettingsViewModel` 提供给设置页编辑。
7. `LazyBarApp` 将 `DisplayQuote` 和展示设置组合到 `MenuBarLabelView`，由 `MenuBarExtra` 渲染菜单栏标签；菜单栏文本的字段拼装继续由 `DisplayQuote` 提供，点击后展示 `MenuBarContentView`。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。后续接真实行情时，优先新增 provider 实现，而不是改 View。
- `DisplayQuote` 是展示格式化边界。菜单栏名称、价格、涨跌幅、更新时间等字符串拼装应尽量集中在这里或 ViewModel。
- `MenuBarDisplaySettings` 和 `MenuBarSettingsStore` 负责展示配置与持久化，避免把设置状态散落在 View 里。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调。
- App 层只负责场景装配，不承接业务逻辑、网络逻辑或跨层状态协调。
- View 继续负责详情类和设置类 SwiftUI 界面的渲染，不承接业务逻辑、网络逻辑或跨层状态协调。

## 当前已知事实
- `AppDependencies` 是 mock/real provider 切换的自然入口。
- 当前主交互只依赖 `MenuBarViewModel` 和 `MenuBarSettingsViewModel`；`StockDetailViewModel` 和 Detail 组件仍保留在代码中，但不作为菜单点击后的默认路径。
- 工程没有第三方依赖，运行时只依赖系统框架 `SwiftUI`、`Foundation` 和少量 `AppKit` 退出行为。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 多标的轮播：优先扩展 provider 返回结构和 ViewModel 状态模型。
- 刷新调度：优先放在 ViewModel 或独立协调层，不要直接写进 View。
- watchlist 与设置配置：应通过 `Settings` scene 扩展入口，同时保持状态与数据边界不下沉到 View。
