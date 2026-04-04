# Architecture

## 当前实现概览
当前工程是一个单 target 的 macOS 原生应用，主体界面内容仍由 SwiftUI 构建；菜单栏入口和设置弹窗都由 AppKit 承载。状态栏入口使用 `NSStatusItem`，左键通过无箭头的自定义面板承载主面板；主面板分成上半部分的股票列表和下半部分的轻量操作区。SwiftUI scene 仅保留最小生命周期占位，不承接实际设置内容。

应用入口在 `LazyBarApp`，负责创建状态栏控制器、设置窗口控制器，并将依赖注入到对应的 ViewModel。

## 分层结构
- `Models`
  - `StockQuote`：provider 返回的单只原始行情领域模型。
  - `DisplayQuote`：面向 UI 的展示模型，负责把数值和时间格式化成可直接展示的内容，并统一产出菜单栏与主面板共享的列数据。
  - `MenuBarDisplaySettings`：菜单栏字段配置与 watchlist 条目列表；每个条目包含股票简称和股票代码。字段定义、文案、字段可见性切换，以及 watchlist 的股票代码归一化、空简称回退、去重和“至少保留一个展示字段”的校验都集中在这里，避免设置页勾选项与 bar / 主面板渲染各自维护映射，也避免同一套规则在 ViewModel 和 View 中重复实现。
- `Providers`
  - `QuoteProviding`：数据来源边界协议，按当前 watchlist 中的股票代码返回股票列表。
  - `SinaQuoteProvider`：当前 live 环境默认使用的真实行情 provider；通过新浪财经未公开快照接口按股票代码批量拉取 A 股准实时行情。
  - `MockQuoteProvider`：保留用于 Preview、调试或未来兜底的 mock 数据源；每次拉取都会基于基准价生成小幅波动后的最新报价，并按请求的股票代码返回对应 mock 股票。
- `ViewModels`
  - `MenuBarViewModel`：负责菜单栏 ticker 数据源、下拉股票列表状态，以及定时刷新调度；通过独立的 `QuoteRefreshScheduler` 计算 A 股交易时段下的刷新节奏；同时直接发布 bar 与左键列表共用的 `MenuBarPresentation`，避免再引入额外展示派生转发层。
  - `MenuBarSettingsViewModel`：负责设置弹窗中的编辑会话协调，维护一份与正式设置同结构的单一草稿 `MenuBarDisplaySettings`，并仅为 watchlist 行编辑补充一层轻量 draft row id 以保持列表输入身份稳定；顶部新增行继续只使用一条临时 `WatchlistEntry`。保存前复用模型层清洗结果写回 store，避免重新引入独立 draft field 状态。
- `App`
  - `LazyBarApp`：负责组装依赖，并维持应用生命周期所需的最小 scene。
  - `MenuBarSettingsStore`：持久化菜单栏展示设置，供菜单栏和设置页共享；首次启动时使用空 watchlist，后续完全依赖用户手动维护并持久化本地结果。
  - `StatusBarController`：负责状态栏按钮、左键主面板，以及状态栏标题同步。
  - `SettingsWindowController`：负责设置弹窗的创建、展示和关闭；只承载 AppKit 窗口与 `NSHostingView` 托管，不再重复承担设置视图初始化细节。
- `Views`
  - `SettingsView`：设置弹窗中的菜单栏字段配置视图；当前拆成“监控股票”和“展示字段”两个 tab，其中展示字段 tab 用带说明的两列卡片式字段选择区承载字段勾选，“监控股票”tab 则收敛为单段式编辑区；View 主要负责布局和基于草稿模型的直接绑定，字段开关不再拆成多组手写 `Binding(get:set:)` 胶水，watchlist 行则继续使用稳定 row id 避免 SwiftUI 在删除后复用错误的输入状态。
  - `MenuBarStyle`：菜单栏与左键主面板共享的字体、间距、圆角等样式 token。
  - `MenuBarPresentation`：基于 `DisplayQuote` 和当前展示设置统一产出菜单栏 ticker 与左键股票列表共享的 rows 和 layout。
  - `QuoteColumnLayoutCalculator` / `QuoteColumnsRowView`：菜单栏与左键主面板共享的展示层基础设施，统一负责列宽测量、列布局与行渲染；其中身份列到股价列的前导间距也在这里集中定义。
  - 其余 `Shared` 视图负责通用展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 组装 `SinaQuoteProvider` 与 `MenuBarSettingsStore`，并注入对应 ViewModel。
3. `LazyBarApp` 创建 `StatusBarController` 与 `SettingsWindowController`。
4. `LazyBarApp` 在装配完成后触发 `MenuBarViewModel.loadIfNeeded()`。
5. `MenuBarViewModel` 首次加载时读取已保存的 watchlist 条目，并调用 `QuoteProviding.fetchQuotes(symbols:)` 获取 `[StockQuote]`，随后按 A 股交易时段动态选择刷新间隔重复拉取：交易时段每 3 秒一次，非交易时段最长每 10 分钟一次；若下一次 10 分钟轮询会跨过 09:30 或 13:00 这类交易恢复边界，则会提前在边界时刻唤醒并切回高频刷新。
6. `MenuBarSettingsViewModel` 读取 `MenuBarSettingsStore`；首次启动时 watchlist 为空，设置页支持在草稿态里新增、删除、直接编辑代码和简称。ViewModel 只协调编辑中的草稿值与保存/取消动作，股票代码长度、去重、空名称回退以及“至少保留一个展示字段”的规则由 `MenuBarDisplaySettings` 统一清洗和校验。
8. `MenuBarViewModel` 将 `[StockQuote]` 转成 `[DisplayQuote]`，并显式维护 `loading / emptyWatchlist / failed / loaded` 这类主面板与 bar 共用的界面状态；同时它会直接基于 `viewState + settings` 派生当前 `MenuBarPresentation`，集中生成共享 rows、状态文案与动态列宽。列宽会基于当前股票列表里各列最长文本计算，供 bar 与左键列表共享，整体宽度也会随当前可见列动态收紧或扩展；身份列到股价列之间的基准前导间距也由共享布局统一控制，避免价格位数变化时行内视觉间距波动过大。ViewModel 内部会保留最近一次成功拉取的原始行情快照：当 symbol 列表变化时会立刻进入新一轮拉取，并先基于仍然有效的旧快照维持当前已加载股票，避免 bar 在保存后先退回成启动时的 `loading` 空态；如果只是改了展示字段或股票简称，则会直接基于现有快照重算 `DisplayQuote`，不再先切到 loading 再等待下一次行情刷新。当 watchlist 在加载中发生变更时，ViewModel 会取消旧一轮加载并只接受最新一轮请求结果，避免已删除或过期的股票重新写回 UI；定时刷新时直接替换最新展示数据，并在刷新失败时尽量保留上一份成功快照。
9. `StatusBarController` 将 `MenuBarLabelView` 托管到 `NSStatusBarButton` 内部，并根据 `MenuBarViewModel` 当前 `presentation` 中的 layout 同步调整状态栏按钮宽度；bar 的 AppKit 宿主在 `presentation` 变化时会直接替换一次 `MenuBarLabelView` 的 `rootView` 快照，并同步 hosting view 尺寸，以规避 `NSStatusItem` 场景下 SwiftUI 子树偶发残留旧状态文本的问题。`MenuBarLabelView` 在裁剪容器里按条目做纵向循环滚动，并在 rows 变化时按新列表重启 ticker，避免左键列表已经切到新顺序或新股票、bar 仍停留在旧播放位置；左键点击后展示的主面板则直接观察 `MenuBarViewModel.presentation`，上半部分继续共享相同的分栏展示数据、动态列宽与共享样式 token，下半部分只承载设置入口、退出和后续少量操作。
10. 左键主面板中的设置按钮会关闭当前面板，并交由 `SettingsWindowController` 打开承载 `SettingsView` 的独立 AppKit 窗口。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。当前真实行情通过 `SinaQuoteProvider` 落在这一层，后续若要切换到授权源或增加 fallback，优先继续新增或替换 provider 实现，而不是改 View。
- mock 阶段的“实时感”仍通过 `QuoteProviding` + ViewModel 刷新调度来模拟，不把随机波动或拉取时序写进 View。
- `DisplayQuote` 是展示格式化边界。菜单栏 ticker 与左键列表所需的名称、价格、涨跌幅、更新时间以及共享列数据应尽量集中在这里或 ViewModel；当 watchlist 中配置了自定义股票简称时，由 ViewModel 在这里统一覆盖展示名称。
- 共享列布局计算、菜单栏共享 rows/layout 组装，以及共享行渲染属于展示层基础设施，应继续集中在展示辅助层；但最终给 bar 和左键列表消费的 `MenuBarPresentation` 由 `MenuBarViewModel` 直接发布，避免额外的展示派生转发层让状态出现不同步。
- `MenuBarDisplaySettings` 和 `MenuBarSettingsStore` 负责展示配置、watchlist 配置与持久化；watchlist 不再依赖 bundle 内置 JSON，首次启动为空列表，后续由用户手动维护。`MenuBarDisplaySettings` 本身收敛 watchlist 归一化和校验语义，`MenuBarSettingsViewModel` 只负责设置弹窗中的单一草稿模型、顶部新增行输入，以及保存/取消动作，避免把设置状态散落在 View 里，也避免 ViewModel 继续膨胀成字段拼装器。
- ViewModel 负责加载状态、错误降级和 UI 所需状态协调；交易时段轮询节奏由独立调度器计算；不要让 View 通过空数组、布尔值等零散信号自行猜测“空 watchlist / 加载中 / 拉取失败”。
- App 层负责 AppKit 壳层装配，不承接业务逻辑、网络逻辑或行情状态计算。
- View 继续负责详情类、设置类以及菜单栏 ticker 的 SwiftUI 渲染；bar 与左键主面板的视觉常量应集中管理并优先共享，设置页中的 tab 切换、字段说明、卡片态样式和布局编排也应尽量集中在 View 层，不把展示结构判断下沉到业务层；滚动动画应限制在固定宽度容器内部，不通过修改 `NSStatusItem` 宽度实现；同一列的字体语义需要在 SwiftUI 渲染与 AppKit 宽度测量之间严格保持一致，尤其是价格和涨跌幅这类数字列。

## 当前已知事实
- `AppDependencies` 是真实 provider、mock provider 与后续 fallback 切换的自然入口。
- watchlist 不再内置基础数据；用户手动维护后的结果通过 `MenuBarSettingsStore` 持久化到 `UserDefaults`。
- 当前主交互只依赖 `MenuBarViewModel` 和 `MenuBarSettingsViewModel`；仓库不再保留未接入主交互的详情原型代码，避免半成品状态模型继续增加认知负担。
- 工程没有第三方依赖，运行时只依赖系统框架 `SwiftUI`、`Foundation` 和 `AppKit`。
- 新浪行情实现当前通过 HTTP 批量请求按 `sh/sz + 代码` 拉取快照文本，再在 provider 层解析为 `StockQuote`；其稳定性和合规性低于授权数据源。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 刷新调度：当前由 `MenuBarViewModel` 负责按 A 股交易时段在 3 秒和 10 分钟两档之间切换轮询；后续若要接入更细粒度的交易所日历、午休/节假日规则或推送式链路，可继续保留在 ViewModel 或抽到独立协调层，但不要直接写进 View。
- watchlist 与设置配置：当前统一通过设置弹窗和 `MenuBarSettingsStore` 维护；后续继续扩展时仍要保持状态与数据边界不下沉到 View。
