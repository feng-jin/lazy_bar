# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，基于 SwiftUI 构建，通过 `MenuBarExtra` 提供菜单栏交互。

应用入口在 `LazyBarApp`，负责创建菜单栏 label 和展开后的内容面板，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容。
  - `QuoteChange`：涨跌方向与样式语义。
- `Providers`
  - `QuoteProviding`：数据来源边界协议。
  - `MockQuoteProvider`：当前 UI prototype 使用的 mock 数据源。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏紧凑标签状态。
  - `StockDetailViewModel`：负责展开详情面板状态。
- `Views`
  - `MenuBarLabelView`：bar 上的紧凑展示。
  - `MenuBarContentView`：点击后弹出的详情容器。
  - 其余 `Detail` 与 `Shared` 视图负责具体展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 将 `MockQuoteProvider` 注入 ViewModel。
3. ViewModel 调用 `QuoteProviding.fetchQuote()` 获取 `StockQuote`。
4. ViewModel 将 `StockQuote` 转成 `DisplayQuote`。
5. SwiftUI Views 直接消费 `DisplayQuote` 完成展示。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。后续接真实行情时，优先新增 provider 实现，而不是改 View。
- `DisplayQuote` 是展示格式化边界。价格、涨跌幅、更新时间等字符串拼装应尽量集中在这里或 ViewModel。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调。
- View 负责渲染，不承接业务逻辑、网络逻辑或跨层状态协调。

## 当前已知事实
- `AppDependencies` 是 mock/real provider 切换的自然入口。
- `MenuBarViewModel` 与 `StockDetailViewModel` 目前存在相似加载逻辑，这是当前实现事实，不必为了“去重”而提前引入复杂抽象。
- `AppDelegate` 通过 `NSApp.setActivationPolicy(.accessory)` 让应用以更符合菜单栏工具的形态运行。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 多标的轮播：优先扩展 provider 返回结构和 ViewModel 状态模型。
- 刷新调度：优先放在 ViewModel 或独立协调层，不要直接写进 View。
- watchlist 配置：应在不破坏当前分层的前提下新增状态和配置入口。
