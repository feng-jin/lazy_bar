# Lazy Bar

Lazy Bar 是一个面向上班族的 macOS 菜单栏盯盘工具，目标是在不打扰正常工作的前提下，把关键行情信息持续放在 bar 上。

## 快速开始
1. 下载并打开 Lazy Bar。
2. 如果系统拦截首次启动，按下方“首次打开（未签名版本）”完成放行。
3. 启动后在菜单栏找到 Lazy Bar。
4. 首次打开若还没有 watchlist，菜单栏会显示“请先添加股票”。
5. 左键点击菜单栏，打开主面板。
6. 在主面板底部进入设置，先添加你要看的股票，再按需要调整展示字段。

## 首次打开（未签名版本）
- 当前发布包未做开发者签名与公证，macOS 首次打开时可能会提示应用无法验证或已被阻止打开。
- 如果双击应用后被系统拦截，请打开“系统设置 > 隐私与安全性”，在安全提示区域找到 Lazy Bar，并点击“仍要打开”。
- 点击“仍要打开”后，再次启动应用；系统若再次弹出确认框，继续选择打开即可。
- 若你已经把应用拖入“应用程序”目录，仍然建议先完成上述放行操作，再进行首次启动。

## 怎么用
- 左键点击菜单栏图标，会从状态栏下方展开主面板。
- 主面板上半部分显示当前 watchlist 的股票列表，下半部分提供设置和退出入口。
- 设置窗口分为“监控股票”和“展示字段”两个 tab。
- 在“监控股票”里手动录入简称和 6 位股票代码，可新增、删除和直接编辑自选股。
- 在“展示字段”里可勾选股票简称、股票代码、最新价和涨跌幅；系统要求至少保留一个字段可见。
- 点击保存会立即生效但不会关闭窗口；点击取消会放弃本轮未保存修改并关闭窗口。

## 当前能力
- 当前聚焦 A 股场景，默认通过新浪财经未公开快照接口拉取准实时行情。
- 按 A 股交易时段动态轮询刷新：交易时段内每 3 秒拉取一次，非交易时段每 10 分钟拉取一次。
- 菜单栏会按股票逐条轮播摘要，主面板中的股票列表与菜单栏保持同步。
- watchlist 首次启动默认为空，由用户在设置页手动录入并持久化到本地。
- 当前菜单栏和主面板可展示股票简称、股票代码、最新价和涨跌幅，并按共享列宽对齐显示。
- 左键主面板当前提供“检查更新”入口，并预留 Sparkle 自动升级能力；实际更新是否可用取决于发布包是否配置好 appcast 与签名信息。
- 当前通过 Swift Package 引入 Sparkle 作为唯一第三方依赖，其余运行时能力仍以系统框架为主。
- 产品方向与详细边界见 [docs/product.md](docs/product.md)。

## 当前状态
- 当前仓库处于以真实行情为主的早期可用阶段。
- 当前是单 target 的 macOS 原生应用；菜单栏入口由 AppKit 承载，主面板内容继续复用 SwiftUI 视图。
- 设置弹窗由 AppKit 独立窗口承载，设置内容继续复用 SwiftUI `SettingsView`；左键面板本身不再承载具体设置表单。
- 左键主面板底部现在包含“检查更新 / 设置 / 退出”三类轻量操作，其中更新能力由 Sparkle 驱动。
- bar 与主面板股票列表共享同一份展示数据和列结构；当展示字段变化或股票顺序变化时，两边会同步更新。
- 当前主面板中的股票区域在达到高度上限后会滚动，避免 watchlist 增长时继续撑高面板。

## 代码结构
- `Sources/Models`：领域模型与展示模型。
- `Sources/Providers`：数据来源边界与 provider 实现。
- `Sources/ViewModels`：菜单栏与设置窗口的状态协调，以及 `QuoteSession` 这类窄职责上层协调对象。
- `Sources/Views`：SwiftUI 视图，以及菜单栏共享样式、纯展示 `MenuBarPresentation`、行组件、列布局计算等展示层基础设施。
- `Sources/App`：AppKit 壳层、状态栏宿主/主面板协调与设置持久化。
- `Sources/App/AppUpdater.swift`：Sparkle 更新能力封装与配置缺失提示。
- `release.sh`：当前本地发布入口，转调 Sparkle Release 构建脚本并把产物输出到相邻的 `../lazy_bar_update` 目录。
- `scripts/build_sparkle_release.sh`：本地构建 Release 包、打 zip 并生成 Sparkle `appcast.xml` 的辅助脚本。
- `Sources/PreviewSupport`：Preview 所需的示例数据。
- `Resources`：`Info.plist` 与资源文件。

## 阅读顺序
1. [产品定位](docs/product.md)
2. [架构说明](docs/architecture.md)
3. [路线图](docs/roadmap.md)
4. [开发备注](docs/development-notes.md)
5. [Agent 规范](AGENTS.md)

## 文档边界
- `README.md`：项目入口、上手说明、当前状态、目录概览、阅读顺序。
- `AGENTS.md`：agent 执行规则与协作约束。
- `docs/product.md`：产品定位、目标用户、场景、设计原则。
- `docs/architecture.md`：当前代码结构、数据流、职责边界。
- `docs/roadmap.md`：阶段目标与后续演进顺序。
- `docs/development-notes.md`：本地开发前提、工程事实、常见入口。

## 开发前提
- 目标平台：macOS。
- 最低系统版本：macOS 15.0。
- UI 技术栈：SwiftUI 优先，仅保留系统框架范围内的能力。
- 第三方依赖：Sparkle 2（通过 Swift Package 引入，用于应用更新）。
- 建议使用完整 Xcode 环境；仅安装 Command Line Tools 时，`xcodebuild` 无法完成完整工程构建。

## 发布命令
- 当前仓库根目录的发布入口命令是 `bash release.sh 0.1.0`。
- 该命令会转调 `scripts/build_sparkle_release.sh`，并将 zip 与 `appcast.xml` 输出到相邻目录 `../lazy_bar_update`。

## 协作要求
- agent 执行前先读 `README.md` 与相关 `docs/*.md`。
- 改动完成后同步更新对应文档。
- 具体执行规则见 [AGENTS.md](AGENTS.md)。

## 下一步重点
- 为真实 A 股行情 provider 增加更稳妥的错误提示、兜底与切换策略。
- 继续打磨纵向 ticker 节奏与刷新策略，并在接入真实行情后替换 mock 刷新链路。
- 逐步补齐更多设置项、错误态和空态表现。
