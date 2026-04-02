# Lazy Bar

Lazy Bar 是一个面向上班族的 macOS 菜单栏盯盘工具，目标是在不打扰正常工作的前提下，把关键行情信息持续放在 bar 上。

## 当前状态
- 当前仓库处于以真实行情为主的早期可用阶段。
- 当前是单 target 的 macOS 原生应用；菜单栏入口由 AppKit 承载，主面板内容继续复用 SwiftUI 视图。
- 当前默认通过新浪财经未公开快照接口拉取 A 股准实时行情，并继续按固定节奏轮询刷新；仓库仍保留 mock 行情 provider 供 Preview 和后续兜底使用。应用启动后会先从项目内 `Resources/watchlist-base.json` 读取基础监控股票列表。
- 当前菜单栏可展示股票代码、股票简称、最新价和涨跌幅，展示字段可在独立设置弹窗中通过带说明的两列卡片式选项勾选；设置页支持在基础 watchlist 之上手动新增、删除和直接编辑股票代码/简称，并提供“恢复 Base 列表”按钮。左键主面板中的股票区域在达到上限后会滚动，避免占用过大空间。点击保存会立即提交但不关闭弹窗，点击取消会放弃本轮未保存修改并关闭弹窗。
- 左键点击菜单栏会从状态栏图标下方展开无箭头的主面板；面板分成上下两个区域，上半部分是股票列表，下半部分只保留设置、退出以及后续少量功能入口。底部操作区使用更接近系统下拉菜单项的整行点击、高亮反馈与图标样式。面板整体使用更贴近 macOS 原生菜单的材质、圆角边界、分隔线与 hover 高亮，并优先与 bar 使用同一宽度和左右边界对齐；bar 与上半部分股票列表会共享同一套列结构、列间距、主副文字体风格、数值字体风格，以及按当前股票里最长字段动态计算出的列宽，因此股票简称列、股票代码列、股价列、涨跌幅列都能独立对齐并完整显示；当关闭部分字段后，bar 和主面板宽度也会随当前可见列一起收紧，保持紧凑展示。
- 设置弹窗由 AppKit 独立窗口承载，设置内容继续复用 SwiftUI `SettingsView`；左键面板本身不再承载具体设置表单。
- 当前没有第三方依赖，也没有 Swift Package 依赖，工程只使用系统框架。
- 产品方向与详细边界见 [docs/product.md](docs/product.md)。

## 代码结构
- `Sources/Models`：领域模型与展示模型。
- `Sources/Providers`：数据来源边界与 provider 实现。
- `Sources/ViewModels`：菜单栏和详情面板的状态协调。
- `Sources/Views`：SwiftUI 视图。
- `Sources/App`：AppKit 壳层、设置持久化，以及 base watchlist 加载。
- `Sources/PreviewSupport`：Preview 所需的示例数据。
- `Resources`：`Info.plist` 与资源文件。

## 阅读顺序
1. [产品定位](docs/product.md)
2. [架构说明](docs/architecture.md)
3. [路线图](docs/roadmap.md)
4. [开发备注](docs/development-notes.md)
5. [Agent 规范](AGENTS.md)

## 文档边界
- `README.md`：项目入口、当前状态、目录概览、阅读顺序。
- `AGENTS.md`：agent 执行规则与协作约束。
- `docs/product.md`：产品定位、目标用户、场景、设计原则。
- `docs/architecture.md`：当前代码结构、数据流、职责边界。
- `docs/roadmap.md`：阶段目标与后续演进顺序。
- `docs/development-notes.md`：本地开发前提、工程事实、常见入口。

## 开发前提
- 目标平台：macOS。
- 最低系统版本：macOS 15.0。
- UI 技术栈：SwiftUI 优先，仅保留系统框架范围内的能力。
- 建议使用完整 Xcode 环境；仅安装 Command Line Tools 时，`xcodebuild` 无法完成完整工程构建。

## 协作要求
- agent 执行前先读 `README.md` 与相关 `docs/*.md`。
- 改动完成后同步更新对应文档。
- 具体执行规则见 [AGENTS.md](AGENTS.md)。

## 下一步重点
- 为真实 A 股行情 provider 增加更稳妥的错误提示、兜底与切换策略。
- 继续打磨纵向 ticker 节奏与刷新策略，并在接入真实行情后替换 mock 刷新链路。
- 逐步补齐更多设置项、错误态和空态表现。
