# /review 真实试跑记录

本文记录 MyP-M-A `/review` 在真实项目中的试跑反馈，用于后续改进 skill。它不是对项目本身的正式结论，而是对 `/review` 输出质量的复盘。

## QuickRec Project Review

时间：2026-07-08

输入概况：

- 项目：`E:\codex\QuickRec`
- 场景：使用 `mypm /review` 对真实项目做 project review。
- 输出包含：Review 判断、使用工具与证据来源、对象脉络、Mermaid 架构图、核心流程图、关键发现、值得保留、可进入 `/idea` 的候选迭代点、暂不处理、给下一次模型接手的摘要。

### 做得好的地方

- 自动识别项目对象：发现用户文案可能残留 LetsMakeMoney，但路径指向 QuickRec，因此按 QuickRec 评审。
- 符合“先建地图，再找问题”的 review 思路：先梳理目标、阶段、核心路径、配置、日志和 UI 关系，再输出问题。
- 有证据意识：列出本地文件、文档、Git 和未验证项；关键发现标注 `Confirmed` / `Likely`。
- 没有把 review 发现直接当成确定需求：候选点进入 `/idea`，符合 `/review` 与 `/idea` 的分工。

### 暴露的问题

- Project review 仍偏工程视角，产品定位和用户场景不够深入。需要更明确拆出：
  - 产品定位。
  - 目标用户。
  - 核心使用场景。
  - 当前阶段目标。
  - Lite/Full 等产品线差异背后的用户价值。
- 候选迭代点缺少下一步分流。需要区分：
  - 直接修。
  - 进入 `/idea`。
  - 进入 `/prd`。
  - 进入 `/acceptance`。
  - 暂不做。
- 工具证据还可以更可审计。除了“读了哪些文件/文档/Git”，最好补：
  - 使用过的关键命令。
  - 关键文件路径。
  - 没有执行的验证。
  - 因未验证导致的结论限制。
- 缺少最终的 PM 收口建议。Review 结束后应给出“下一步怎么走”，而不只是列候选点。

### 拟改进方向

- 在 `references/review.md` 的 Project Review 检查重点中加入产品定位、目标用户、核心使用场景、当前阶段目标和产品线边界。
- 在默认输出结构中加入“下一步分流建议”，把发现分为直接修、进 `/idea`、进 `/prd`、进 `/acceptance`、暂不做。
- 在“使用工具与证据来源”中增加“关键命令/关键文件/未执行验证”字段。
- 在质量标准中检查 project review 是否不仅理解工程结构，也理解产品定位和用户价值。

## LetsMakeMoney Project Review

时间：2026-07-08

输入概况：

- 项目：`E:\codex\LetsMakeMoney`
- 场景：使用 `mypm /review` 对真实项目做 project review。
- 输出包含：Review 判断、工具与证据来源、对象脉络、Mermaid 架构图、关键流程图、关键发现、值得保留、可进入 `/idea` 的候选迭代点、暂不处理、给下一次模型接手的摘要。

### 做得好的地方

- 明确避开代码 PR review，自动识别为 Project Review。
- 对项目阶段判断较准确：识别为 v0.4 Beta 测试态，而不是继续拉新需求。
- 产品目标表达较好：将项目定义为“橘猫桌宠 + 薪资小票，把工作时间价值变成可见、轻量、陪伴型桌面工具”。
- 对核心路径、模块关系、配置/状态/日志关系的梳理清晰，适合下一次模型快速接手。
- 工具证据比 QuickRec 更强：不仅列出文件，还提到实际运行 `scripts\verify_v04.ps1` 且通过。
- 对未验证项有边界意识：明确没有用 Computer Use 实跑 UI，不判断所有手动项真实通过。
- 收口方向正确：下一步不是直接开发新需求，而是 v0.4 手动验证、文档状态对齐、Wizard/长按/拖拽/托盘/穿透/UI 真实观感复测。

### 暴露的问题

- “使用工具与证据来源”仍缺少关键命令清单。虽然提到运行了 `scripts\verify_v04.ps1`，但没有完整列出用于阅读项目、检索文件、检查分支和产物的命令。
- 候选迭代点仍只给“下一步”，没有明确分流为直接修、进入 `/idea`、进入 `/prd`、进入 `/acceptance`、暂不做。
- 对用户/使用场景仍可以更深。已说明产品目标，但还可以补：
  - 谁会长期使用桌宠。
  - 为什么薪资 Panel 对用户有价值。
  - 桌宠互动、设置页、向导分别承担什么信任关系。
  - v0.4 Beta 的发布成功标准是什么。
- 关键发现里 Positive 项和问题项混在同一表中，阅读上有效，但后续需求池提取时最好分开为“问题/风险”和“资产/值得保留”。
- 对 `/acceptance` 的承接可以更明确：它指出需手动验证，但可以直接给出“建议下一步进入 `/acceptance` 的验收对象和证据清单”。

### 拟改进方向

- Project Review 的默认输出应增加“产品定位与用户场景”小节，包含目标用户、核心场景、当前阶段目标和成功标准。
- 默认输出应增加“下一步分流建议”小节，明确：
  - 直接修。
  - 进入 `/idea`。
  - 进入 `/prd`。
  - 进入 `/acceptance`。
  - 暂不做。
- 工具证据小节应增加：
  - 关键命令。
  - 关键文件。
  - 已执行验证。
  - 未执行验证。
  - 结论限制。
- 关键发现表建议保留 Positive，但输出时应让 Positive 不干扰问题候选点提取；可在表中继续标类型，也可独立放入“值得保留”。
- 当 review 发现项目处于测试/发布前阶段时，应主动建议 `/acceptance` 承接，并列出最小验收证据。

## LetsMakeMoney v0.4 收尾型 Review

时间：2026-07-09

输入概况：

- 项目：`E:\codex\LetsMakeMoney`
- 场景：v0.4 Beta 已基本完成后，使用 `/review` 做 project + PRD + implementation + release readiness 收尾评审。
- 范围：v0.4 PRD、implementation-plan、progress、verification、release notes、README、Git/tag 状态、发布包 manifest。
- 明确不覆盖：不运行 exe、不做 Computer Use 实测、不重新验收 UI/托盘/日志。

### 做得好的地方

- Review 类型识别更准确：不只是 project review，而是 project + prd + implementation + release readiness 的混合收尾评审。
- 阶段判断正确：明确 v0.4 已形成“可进入验收”的 Beta 闭环，但不是“文档完全一致、发布门禁完全关闭”。
- 没有继续扩新功能：明确当前最该进入 `/acceptance`，而不是继续开发新需求。
- 证据边界清楚：说明依据来自本地文档与 Git 状态，并明确没有运行 exe、没有 Computer Use 实测。
- 版本脉络图有效：用 Mermaid 把 v0.3 -> v0.4，以及橘猫、桌宠窗口、Panel、Settings、发布包、验证体系和待验收项串起来。
- 文档一致性检查很有价值：识别 `current/status` 仍写 test、未合并、未 tag，但真实 Git 已在 main 且 tag 为 `v0.4-beta`。
- 下一步分流清晰：把事项分到 `/acceptance`、直接修文档、bugfix/dev-log、`/idea` 和暂不处理。
- 对 progress 边界判断准确：指出 progress 混入技术排查、bugfix 过程和资源探索流水，应迁到 `dev-log`、`bugfix-log` 或 `spike-log`。

### 暴露的问题

- 作为 review 输出，它已经很好地指出应进入 `/acceptance`，但还可以直接给出可复制的 `/acceptance` 输入提示词，降低用户下一步操作成本。
- Release readiness review 需要固定检查 Git/tag/发布包/manifest/checksum/current/status/release notes 的事实一致性，否则容易只停留在文档阅读。
- 当发现“文档事实冲突”时，应更明确区分：
  - 不需要进入 `/idea` 的事实修正。
  - 需要 `/acceptance` 的真实验收。
  - 需要 `/idea` 的后续候选需求。
- 对 `progress` 的治理建议应沉淀到 PRD 后开发承接规则中：PM progress 只保留状态看板，过程日志迁出。

### 拟改进方向

- 在 `references/review.md` 中考虑增加 release readiness 场景：当 review 范围包含发布包、tag、release notes、manifest 或 verification 时，必须检查事实一致性和发布门禁。
- 收尾型 review 的默认结尾应提供“下一条可直接发送的 `/acceptance` 提示词”。
- 对文档冲突类问题，默认分流为“直接修文档”，不要进入 `/idea`。
- 对已经发布或打 tag 的项目，review 必须显式检查文档是否仍停留在旧分支、未合并、未 tag、待发布等口径。
