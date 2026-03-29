# Lazy Bar

Lazy Bar 是一个面向上班族的 macOS 菜单栏盯盘工具，目标是在不打扰正常工作的前提下，把关键行情信息持续放在 bar 上。

## 当前状态
- 当前仓库仍处于 UI prototype 阶段。
- 当前是单 target 的 macOS 原生应用；菜单栏入口和设置窗口都由 AppKit 承载，设置窗口内容继续复用 SwiftUI 视图。
- 当前只使用 mock 数据，尚未接入真实行情；当前 mock 链路已提供多只示例股票。
- 当前菜单栏可展示股票代码、股票简称、最新价和涨跌幅，展示字段可在设置中勾选，并通过保存/取消按钮提交或放弃修改。
- 左键点击菜单栏会弹出股票列表，右键点击会显示系统菜单中的“设置 Settings”和“退出 Quit Lazy Bar”；bar 顶部仍显示第一只股票的紧凑摘要。
- 右键菜单当前保持纯 AppKit `NSMenu` 交互；设置窗口也由 AppKit 直接打开，因此不再依赖 `Settings` scene 或 `SettingsLink`。
- 当前没有第三方依赖，也没有 Swift Package 依赖，工程只使用系统框架。
- 产品方向与详细边界见 [docs/product.md](docs/product.md)。

## 代码结构
- `Sources/Models`：领域模型与展示模型。
- `Sources/Providers`：数据来源边界与 provider 实现。
- `Sources/ViewModels`：菜单栏和详情面板的状态协调。
- `Sources/Views`：SwiftUI 视图。
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
- 完成多只个股滚动展示的 V1 形态。
- 接入真实 A 股行情 provider。
- 稳定轮播与刷新策略。
- 逐步补齐设置项、错误态、空态和 watchlist 配置。
