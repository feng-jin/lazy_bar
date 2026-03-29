# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，主体界面与设置页基于 SwiftUI 构建；仅菜单栏系统接入层继续通过 AppKit `NSStatusItem` 提供交互。

应用入口在 `LazyBarApp`，负责创建菜单栏状态项控制器和设置场景，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容。
  - `MenuBarDisplaySettings`：菜单栏字段与颜色开关配置。
  - `QuoteChange`：涨跌方向与 SwiftUI 样式语义。
- `Providers`
  - `QuoteProviding`：数据来源边界协议。
  - `MockQuoteProvider`：当前 UI prototype 使用的 mock 数据源。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏紧凑标签状态。
  - `StockDetailViewModel`：保留为后续详情扩展使用，当前不接入主交互路径。
- `App`
  - `MenuBarStatusItemController`：负责把 `MenuBarViewModel` 的状态映射为 `NSStatusItem` 文本，并管理菜单栏 popover 的展示。
  - `MenuBarSettingsStore`：持久化菜单栏展示设置，供菜单栏和设置页共享。
- `Views`
  - `MenuBarContentView`：菜单栏点击后弹出的 SwiftUI popover 内容，使用 `SettingsLink` 打开设置窗口。
  - `SettingsView`：设置窗口中的菜单栏字段与颜色配置界面。
  - 其余 `Detail` 与 `Shared` 视图负责具体展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 将 `MockQuoteProvider` 注入 `MenuBarViewModel`。
3. ViewModel 调用 `QuoteProviding.fetchQuote()` 获取 `StockQuote`。
4. ViewModel 将 `StockQuote` 转成 `DisplayQuote`。
5. `MenuBarSettingsStore` 从 `UserDefaults` 读取菜单栏展示设置，并由 `MenuBarSettingsViewModel` 提供给设置页编辑。
6. `MenuBarStatusItemController` 同时订阅行情和展示设置，把 `DisplayQuote` 转成符合配置的标题文本并更新 `NSStatusItem`。
7. `MenuBarStatusItemController` 负责打开或关闭菜单栏 popover，popover 内的 `MenuBarContentView` 通过 `SettingsLink` 打开设置窗口。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。后续接真实行情时，优先新增 provider 实现，而不是改 View。
- `DisplayQuote` 是展示格式化边界。菜单栏名称、价格、涨跌幅、更新时间等字符串拼装应尽量集中在这里或 ViewModel。
- `MenuBarDisplaySettings` 和 `MenuBarSettingsStore` 负责展示配置与持久化，避免把设置状态散落在 View 里。
- `QuoteChange` 负责涨跌方向对应的 SwiftUI 样式语义，当前菜单栏与详情展示都复用同一套红涨绿跌颜色约定。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调。
- App 层状态项控制器只负责菜单栏系统组件适配和 popover 展示，不承接业务逻辑、网络逻辑或跨层状态协调。
- View 继续负责详情类和设置类 SwiftUI 界面的渲染，不承接业务逻辑、网络逻辑或跨层状态协调。

## 当前已知事实
- `AppDependencies` 是 mock/real provider 切换的自然入口。
- 当前主交互只依赖 `MenuBarViewModel`；`StockDetailViewModel` 和 Detail 组件仍保留在代码中，但不作为菜单点击后的默认路径。
- `AppDelegate` 通过 `NSApp.setActivationPolicy(.accessory)` 让应用以更符合菜单栏工具的形态运行。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 多标的轮播：优先扩展 provider 返回结构和 ViewModel 状态模型。
- 刷新调度：优先放在 ViewModel 或独立协调层，不要直接写进 View。
- watchlist 与设置配置：应通过 `Settings` scene 扩展入口，同时保持状态与数据边界不下沉到 View。
