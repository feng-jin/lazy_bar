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
  - `MenuBarContentState`：菜单栏与左键主面板共用的唯一展示内容状态语义，显式表达 `loading / emptyWatchlist / failed / loaded([DisplayQuote])`，由 `MenuBarViewModel` 内部统一复用，避免重复枚举和中间映射胶水。
  - `MenuBarRenderState`：ViewModel 层对外发布的展示输入，收口 `DisplayQuote`、当前展示设置和状态文案这类仍保持层内语义的数据，不直接暴露 Views 层的 `MenuBarPresentation`。
  - `MenuBarViewModel`：负责 settings 订阅、UI 状态发布，以及在 ViewModel 内部把统一内容状态和当前展示设置映射成 `MenuBarRenderState`；它只保留面向 UI 的少量 orchestration，并通过单一入口区分“symbol 列表变化”和“仅展示字段变化”。
  - `QuoteSession`：负责行情拉取、请求取消、快照缓存、交易时段轮询刷新，以及失败时优先回落到最后一次仍有效的成功快照；只暴露 `fetchLatest`、缓存读取和刷新启动/停止这类窄接口给 `MenuBarViewModel`。
  - `MenuBarSettingsViewModel`：负责设置弹窗中的编辑会话协调，维护一份与正式设置同结构的单一草稿 `MenuBarDisplaySettings`，并仅额外保存与 watchlist 顺序对齐的稳定 row id 列表以保持 SwiftUI 输入身份稳定；顶部新增行继续只使用一条临时 `WatchlistEntry`。保存前复用模型层清洗结果写回 settings store 抽象，避免重新引入独立 draft field 状态或双份 watchlist 真源。
- `App`
  - `LazyBarApp`：负责组装依赖，并维持应用生命周期所需的最小 scene。
  - `MenuBarSettingsStore` / `MenuBarSettingsStoring`：`MenuBarSettingsStore` 负责持久化菜单栏展示设置，`MenuBarSettingsStoring` 提供 ViewModel 依赖的最小读写与发布接口；首次启动时使用空 watchlist，后续完全依赖用户手动维护并持久化本地结果。
  - `StatusBarController`：负责状态栏按钮点击、主面板总协调，以及把同一份 `MenuBarPresentation` 同步到 AppKit 宿主和主面板容器尺寸；不承接行情状态推导或展示字段决策。
  - `StatusItemHost` / `QuotesPanelCoordinator` / `OutsideClickMonitor`：同属 AppKit 壳层内部的窄职责对象，分别收口状态栏宿主同步、主面板生命周期，以及面板打开后的外部点击关闭监听，避免这些细节继续堆在 `StatusBarController` 单个类里。
  - `SettingsWindowController`：负责设置弹窗的创建、展示和关闭；只承载 AppKit 窗口与 `NSHostingView` 托管，并在真正展示窗口时触发设置编辑会话初始化，不再把这类时机绑在 SwiftUI `onAppear` 上。
- `Views`
  - `SettingsView`：设置弹窗中的菜单栏字段配置视图；当前拆成“监控股票”和“展示字段”两个 tab，其中展示字段 tab 用带说明的两列卡片式字段选择区承载字段勾选，“监控股票”tab 则收敛为单段式编辑区；View 主要负责布局，并在视图层把 `MenuBarSettingsViewModel` 暴露的值读写接口组装成 `Binding` 接入草稿模型，watchlist 行继续使用稳定 row id 避免 SwiftUI 在删除后复用错误的输入状态。
  - `MenuBarStyle`：菜单栏与左键主面板共享的字体、间距、圆角等样式 token。
  - `MenuBarPresentation`：基于 `DisplayQuote` 和当前展示设置统一产出菜单栏 ticker 与左键股票列表共享的 rows 和 layout。
  - `QuoteColumnLayoutCalculator` / `QuoteColumnsRowView`：菜单栏与左键主面板共享的展示层基础设施，统一负责列宽测量、列布局与行渲染；其中身份列到股价列的前导间距也在这里集中定义。
  - 其余 `Shared` 视图负责通用展示组件。

## 当前数据流
1. `LazyBarApp` 通过 `AppDependencies.live` 组装依赖。
2. `AppDependencies` 组装 `SinaQuoteProvider`、`QuoteSession` 与 `MenuBarSettingsStore`，并注入对应 ViewModel。
3. `LazyBarApp` 创建 `StatusBarController` 与 `SettingsWindowController`。
4. `LazyBarApp` 在装配完成后触发 `MenuBarViewModel.loadIfNeeded()`。
5. `MenuBarViewModel` 首次加载时读取已保存的 watchlist 条目，并调用 `QuoteSession.fetchLatest(symbols:)` 拉取 `[StockQuote]`；`QuoteSession` 内部继续通过 `QuoteProviding` 访问真实或 mock provider，并结合 `QuoteRefreshScheduler` 按 A 股交易时段动态选择刷新间隔重复拉取：交易时段每 3 秒一次，非交易时段最长每 10 分钟一次；若下一次 10 分钟轮询会跨过 09:30 或 13:00 这类交易恢复边界，则会提前在边界时刻唤醒并切回高频刷新。
6. `MenuBarSettingsViewModel` 读取 `MenuBarSettingsStore`；首次启动时 watchlist 为空，设置页支持在草稿态里新增、删除、直接编辑代码和简称。ViewModel 初始化时直接以当前持久化 settings 建立初始 draft，但会忽略 `settingsPublisher` 的初始回放，避免应用启动阶段仅因订阅建立就触发编辑态 draft reset；后续仍只在真正打开设置窗口时通过 `beginEditing()` 重置无未保存改动的 draft。股票代码长度、去重、空名称回退以及“至少保留一个展示字段”的规则由 `MenuBarDisplaySettings` 统一清洗和校验。
8. `MenuBarViewModel` 将 `QuoteSession` 返回的 `[StockQuote]` 转成 `[DisplayQuote]`，并显式维护单一的 `MenuBarContentState` 作为主面板与 bar 共用的界面状态；随后在 ViewModel 内部直接结合当前 settings 生成 `MenuBarRenderState`。Views / AppKit 壳层再基于这份 render state 派生共享 rows、状态文案与动态列宽。列宽会基于当前股票列表里各列最长文本计算，供 bar 与左键列表共享，整体宽度也会随当前可见列动态收紧或扩展；身份列到股价列之间的基准前导间距也由共享布局统一控制，避免价格位数变化时行内视觉间距波动过大。`QuoteSession` 内部保留最近一次成功拉取的原始行情快照：当 symbol 列表变化时，ViewModel 会先让 session 裁剪到仍然有效的旧快照，再立刻进入新一轮拉取，避免 bar 在保存后无意义地回退成启动时的 `loading` 空态；如果只是改了展示字段或股票简称，则会直接基于现有快照重算 `DisplayQuote`，不再先切到 loading 再等待下一次行情刷新。当 watchlist 在加载中发生变更时，session 会取消旧一轮加载并只接受最新一轮请求结果，避免已删除或过期的股票重新写回 UI；定时刷新也通过同一条 session 链路回写最新数据，并在刷新失败时尽量保留上一份成功快照。
9. `StatusBarController` 将 `MenuBarLabelView` 托管到 `StatusItemHost` 内部，并根据 `MenuBarViewModel` 当前 `renderState` 派生出的 layout 同步调整状态栏按钮宽度；bar 的 AppKit 宿主在 render state 变化时会重新生成一次 `MenuBarPresentation`，再替换 `MenuBarLabelView` 的 `rootView` 快照并同步 hosting view 尺寸，以规避 `NSStatusItem` 场景下 SwiftUI 子树偶发残留旧状态文本的问题。宿主仍会显式请求一次 AppKit 刷新，但会把 `layoutSubtreeIfNeeded()` / `displayIfNeeded()` 延后到当前主线程轮次结束后再合并执行，避免在状态栏按钮自身仍处于布局栈时触发递归布局警告。若左键主面板已经打开，`QuotesPanelCoordinator` 会按同一份 `presentation.layout.itemWidth` 重新测量并更新面板容器尺寸，让 bar、popover 外壳和内部股票列表持续共享同一套宽度语义；面板打开后的外部点击关闭监听则交给 `OutsideClickMonitor`，避免控制器同时持有宿主、panel 和事件监听的细节。`MenuBarLabelView` 在裁剪容器里按条目做纵向循环滚动，并在 rows 变化时按新列表重启 ticker，避免左键列表已经切到新顺序或新股票、bar 仍停留在旧播放位置；左键点击后展示的主面板则直接观察 `MenuBarViewModel.renderState`，在视图侧派生同样的 presentation，上半部分继续共享相同的分栏展示数据、动态列宽与共享样式 token，下半部分只承载设置入口、退出和后续少量操作。
10. 左键主面板中的设置按钮会关闭当前面板，并交由 `SettingsWindowController` 打开承载 `SettingsView` 的独立 AppKit 窗口；控制器会在 `show()` 时先通知 `MenuBarSettingsViewModel.beginEditing()`，这样只有用户真正打开设置窗口时才会按当前持久化 settings 重置无未保存改动的 draft，同时每次展示前继续重建 `SettingsView` 以回到“监控股票”tab。

## 关键职责边界
- `QuoteProviding` 是数据接入边界。当前真实行情通过 `SinaQuoteProvider` 落在这一层，后续若要切换到授权源或增加 fallback，优先继续新增或替换 provider 实现，再由 `AppDependencies` 统一装配进 `QuoteSession`，而不是改 View。
- mock 阶段的“实时感”仍通过 `QuoteProviding` + ViewModel 刷新调度来模拟，不把随机波动或拉取时序写进 View。
- `DisplayQuote` 是展示格式化边界。菜单栏 ticker 与左键列表所需的名称、价格、涨跌幅、更新时间以及共享列数据应尽量集中在这里或 ViewModel；当 watchlist 中配置了自定义股票简称时，由 ViewModel 在这里统一覆盖展示名称。
- 共享列布局计算、纯展示 `MenuBarPresentation` 与共享行渲染属于展示层基础设施，应继续集中在展示辅助层；ViewModel 对外只发布 `MenuBarRenderState` 这类不含 Views 层类型的展示输入，具体的 `MenuBarPresentation` 组装停留在 Views / AppKit 壳层，避免 `MenuBarViewModel` 继续直接依赖展示层对象，同时也不再保留只有一层转发价值的 builder。
- `MenuBarDisplaySettings`、`MenuBarSettingsStoring` 和 `MenuBarSettingsStore` 负责展示配置、watchlist 配置与持久化；watchlist 不再依赖 bundle 内置 JSON，首次启动为空列表，后续由用户手动维护。`MenuBarDisplaySettings` 本身收敛 watchlist 归一化和校验语义，`MenuBarSettingsViewModel` 只负责设置弹窗中的单一草稿模型、顶部新增行输入、稳定 row id 映射和值读写接口，以及保存/取消动作；SwiftUI `Binding` 继续留在 `SettingsView` 侧组装，避免草稿里再维护一份重复 watchlist 真源，也避免 ViewModel 直接暴露 SwiftUI 类型。
- `MenuBarViewModel` 负责 UI 所需状态协调和少量 orchestration，`QuoteSession` 负责加载、取消、快照缓存、轮询和失败降级；不要让 View 通过空数组、布尔值等零散信号自行猜测“空 watchlist / 加载中 / 拉取失败”。
- App 层负责 AppKit 壳层装配，以及把既有 presentation/layout 同步到宿主控件；其中状态栏宿主同步、面板生命周期和外部点击监听这类细节应优先拆成窄职责对象，而不是继续堆进一个控制器里；同时 App 层仍不承接业务逻辑、网络逻辑或行情状态计算。
- View 继续负责详情类、设置类以及菜单栏 ticker 的 SwiftUI 渲染；bar 与左键主面板的视觉常量应集中管理并优先共享，设置页中的 tab 切换、字段说明、卡片态样式和布局编排也应尽量集中在 View 层，不把展示结构判断下沉到业务层；滚动动画应限制在固定宽度容器内部，不通过修改 `NSStatusItem` 宽度实现；同一列的字体语义需要在 SwiftUI 渲染与 AppKit 宽度测量之间严格保持一致，尤其是价格和涨跌幅这类数字列。

## 当前已知事实
- `AppDependencies` 是真实 provider、mock provider、`QuoteSession` 与后续 fallback 切换的自然入口。
- watchlist 不再内置基础数据；用户手动维护后的结果通过 `MenuBarSettingsStore` 持久化到 `UserDefaults`。
- 当前主交互只依赖 `MenuBarViewModel` 和 `MenuBarSettingsViewModel`；仓库不再保留未接入主交互的详情原型代码，避免半成品状态模型继续增加认知负担。
- 工程没有第三方依赖，运行时只依赖系统框架 `SwiftUI`、`Foundation` 和 `AppKit`。
- 新浪行情实现当前通过 HTTP 批量请求按 `sh/sz + 代码` 拉取快照文本，再在 provider 层解析为 `StockQuote`；其稳定性和合规性低于授权数据源。

## 后续优先扩展点
- 真实行情接入：从 `Providers` 和 `AppDependencies` 开始扩展。
- 刷新调度：当前由 `QuoteSession` 结合 `QuoteRefreshScheduler` 负责按 A 股交易时段在 3 秒和 10 分钟两档之间切换轮询；后续若要接入更细粒度的交易所日历、午休/节假日规则或推送式链路，可继续沿着这一协调层扩展，但不要直接写进 View。
- watchlist 与设置配置：当前统一通过设置弹窗和 `MenuBarSettingsStore` 维护；后续继续扩展时仍要保持状态与数据边界不下沉到 View。
