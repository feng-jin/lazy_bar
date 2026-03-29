# AGENTS.md

## Scope
本文件只定义 agent 的执行规则，不重复承担产品说明或架构文档职责。

开始任务前先阅读：
- `README.md`：项目入口与文档导航。
- `docs/product.md`：产品定位与边界。
- `docs/architecture.md`：代码结构与职责边界。
- `docs/development-notes.md`：工程事实与常见入口。

## Architecture Rules
- 保持分层结构：`Models / Providers / ViewModels / Views`。
- 数据接入统一从 `QuoteProviding` 进入，不要把真实数据逻辑直接塞进 View 或临时散落到别处。
- 展示格式化优先放在 `DisplayQuote` 这类展示模型或 ViewModel 中，不要散落在 SwiftUI View 里。
- 不要把业务逻辑、网络请求或状态协调直接写进 SwiftUI Views。
- mock 与 real provider 的切换入口应集中在 `AppDependencies`。

## Execution Rules
- 开始动手前先读 `README.md`，再读本次任务相关的 `docs/*.md`。
- 如果文档与代码现状不一致，以代码为事实依据，并在同一轮改动里修正文档。
- 任何代码、配置、产品行为或架构边界改动后，必须同步更新对应文档。
- 文档更新是实现的一部分，不是收尾时可选的补充工作。
- 做最小必要改动，不为了“顺手整理”扩大改动面。
- 若需求超出当前阶段边界，先在计划或说明中显式指出，再实施。
- 新增能力时优先复用现有分层，不要绕开既有结构。
- 按影响面更新文档：
  - 产品定位或能力边界变更：更新 `docs/product.md`。
  - 结构、数据流、职责边界变更：更新 `docs/architecture.md`。
  - 阶段目标或优先级变更：更新 `docs/roadmap.md`。
  - 构建前提或工程事实变更：更新 `docs/development-notes.md`。
  - 导航或仓库入口信息变更：更新 `README.md`。

## Legacy Note
仓库里曾有一个误拼的 `AGENGT.md` 草稿文件。正式规范以本文件 `AGENTS.md` 为准，后续不要再维护双份规则来源。
