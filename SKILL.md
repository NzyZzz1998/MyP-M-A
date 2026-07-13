---
name: mypm
display_name: MyP-M-A
description: "Use when：用户需要做产品评审、判断需求价值、撰写或完善 PRD、规划开发承接、验收真实实现，或决定项目/版本能否发布；用户不必记命令，提供项目路径、想法、文档、截图、日志或验收结果即可自动分流到 /review、/idea、/prd、/acceptance。纯代码审查、单纯修 bug、直接执行 SQL/日志分析、按既定设计实现 UI 时不单独触发，除非同时需要产品范围或发布判断。"
argument-hint: "[/review|/idea|/prd|/acceptance] 描述、路径或附件"
metadata:
  display_name: MyP-M-A
  full_name: My Product Manager Assistant
  version: "0.20.0"
  language: zh-CN
---

# MyP-M-A

MyP-M-A 是中文优先的个人产品经理工作流。它先帮助用户形成有证据的产品判断，再选择最小必要交付物；正式文档服务下一阶段执行，不以模板完整代替问题理解。

## 使用边界

- 使用本 skill：产品规划、需求澄清、价值判断、版本取舍、PRD、产品评审、开发承接、验收与发布判断。
- 不单独使用本 skill：纯代码审查、已有 bug 的技术修复、单纯 SQL/日志执行、仅按既定设计实现 UI。此类任务只有在需要判断用户价值、范围、验收或版本取舍时才接入 MyP-M-A。
- 默认中文输出。除代码标识、命令、文件名、API/数据库字段和专有名词外，正式文档不混入英文段落；新建 Markdown 使用 UTF-8。
- 区分事实、假设、决策、风险和开放问题。工具不可用时，把受影响结论降级为“待验证”。
- 保护个人项目和小团队项目的可完成性：先小闭环、核心路径和已有体验，再考虑扩张。

## 渐进加载

不要默认读取全部 reference。先判断任务，再加载最小集合：

| 任务 | 必读 | 按条件读取 | 正式文件模板 |
| --- | --- | --- | --- |
| `/idea`、需求池、价值判断 | `references/idea.md` | 有日志、表格、数据库、Issue、反馈或竞品证据时读 `references/data-analysis.md`；需要外部取证时读 `references/tooling.md` | 需求超过 2 个时读 `templates/idea-pool-template.md` |
| `/review`、项目/页面/PRD/实现评审 | `references/review.md` | 有仓库、exe、网页、日志、截图或发布物时读 `references/tooling.md` | 需要落盘时读 `templates/review-report-template.md` |
| `/prd`、版本范围、需求文档 | `references/prd.md` | 涉及数据/后端时读 `references/data-analysis.md`；影响范围不清时读 `references/tooling.md` | 完整成文时读 `templates/prd-template.md` |
| PRD 后开发承接 | `references/development-handoff.md` | 跨线程时读 `references/memory-integration.md` | 读 `templates/dev-plan-template.md`、`templates/progress-template.md`；需要过程记录时再读 `templates/dev-log-template.md` |
| 实施、Bugfix、分批推进 | `references/workflow-control.md` | 需要开发承接事实时读 `references/development-handoff.md` | 沿用项目已有 progress/dev log/bugfix log |
| `/acceptance`、发布检查 | `references/acceptance.md`、`references/tooling.md` | 有长期发布状态时读 `references/memory-integration.md` | 读 `templates/acceptance-template.md`；有人工补证项时读 `templates/manual-verification-template.md` |
| 产品简报 | `references/product-brief.md` | 无 | 需要落盘时读 `templates/product-brief-template.md` |
| 问题尚未成形 | `references/problem-framing.md` | 需要判断价值时再进入 `/idea` | 无固定模板 |
| 路线图 | `references/roadmap.md` | 无 | 需要落盘时读 `templates/roadmap-template.md` |
| 红队、用户故事 | 对应的 `references/red-team.md`、`references/user-stories.md` | 无 | 无固定模板 |
| 深度判断 | `references/judgment-framework.md` | 用户说“更深入/不要只是能用”时再读 `references/deep-review.md`；个人项目或 UI 取舍时读 `references/personal-preferences.md` | 无固定模板 |
| 项目进入、阶段收尾 | `references/memory-integration.md` | 阶段真正结束时再读 `references/next-step-prompts.md` | 无固定模板 |

正式多阶段项目还要读取 `references/traceability.md`，保持 Review、IDEA、PRD、开发承接、Acceptance 和 Release 的来源与状态可追踪。一次性轻量咨询不强制建立编号。

有现成 PRD、dev plan、progress、verification 或候选产物时，还要读取 `references/workflow-control.md`，先识别真实子阶段、门禁影响面和可继承证据，再决定本轮工作。

## 四个主入口

MyP-M-A 在 Codex 中只保留一个 Skill 入口。用户可以显式输入四个命令，也可以直接描述任务，由 Skill 自动分流：

| 用户材料或意图 | 自动入口 |
| --- | --- |
| 项目路径、页面、PRD、代码实现、版本现状，希望先梳理或找问题 | `/review` |
| 想法、反馈、候选需求、是否值得做、下一版做什么 | `/idea` |
| 已确认方向，需要收敛方案、写需求、补影响范围或原型 | `/prd` |
| 已有实现、exe/网页/包、测试、日志或验收结果，需要判断是否通过/发布 | `/acceptance` |

显式命令优先。没有命令时，根据用户目标和已有产物判断；先用一行输出 `入口判断：/review|/idea|/prd|/acceptance` 及真实子阶段，再开展工作。实施、Bugfix、开发承接和发布收口是内部子阶段，不新增对外 Skill 入口。材料同时命中多条通路时，选择最接近用户当前决策的问题；只有选择不同入口会显著改变结果时才追问。

### `/review`：建立地图，再发现问题

自动识别 project、page、prd、implementation、release readiness 主通路。先说明产品定位、目标用户、当前阶段、核心路径、模块/数据/状态关系，再列发现。可视化只在关系复杂、能显著帮助理解时使用；project review 必须有项目或模块图。

每个发现记录现象、证据、影响、严重度、最小建议和去向。证据状态统一使用：`已确认`、`高度可能`、`待确认`、`主观判断`。Review 发现默认是候选点，不直接等同于确定需求。

### `/idea`：发现问题，判断价值

回答：问题是否真实、证据是否足够、价值是什么、现在是否该做、最小下一步是什么。证据不足、范围过大或方案先行时，使用 8 维 0-5 分压力测试；分数必须绑定证据，证据闸门优先于总分。

需求超过 2 个时输出 Markdown 需求池。版本型需求池补充版本主线、证据映射、依赖关系、最小/推荐/过大三档范围和最终分流。

### `/prd`：收敛方案，定义需求

先识别正式推进型、原型验证型或方案收敛版。复杂需求通过分轮提问补齐用户、场景、范围、数据、失败态、非目标和验收；探索 2-3 个有真实取舍的方案，确认当前版本优先级后再成文。

完整 PRD 必须包含影响范围、完整入口到出口链路、数据来源、开发前验收口径、范围保护和合适的需求表达物：

- UI/交互需求：更新已有高保真原型；没有时输出高保真原型或明确原型文件。
- API/后端需求：接口契约、错误码、权限和必要时序图。
- 数据库需求：表字段、关系、迁移、兼容、回滚和必要 ER/数据流图。
- 状态/异步需求：状态机、时序图或流程图。
- 纯工程治理：影响矩阵、验证计划和回退方案，不强制伪造 UI 原型。

完整 PRD 经用户确认后进入开发承接；方案收敛版不能生成 dev plan。开发承接前必须检查项目结构和历史文档风格，避免计划脱离真实实现。

### `/acceptance`：实际验收，控制发布风险

只基于开发结果、构建产物、日志、截图、配置、测试、CI 或用户证据判断。开始时先写 `入口判断：/acceptance` 及当前阶段，避免把验收、开发前标准制定和需求判断混为一谈。结论仅使用：通过、部分通过、未通过、待验证。没有实际证据时只能给待验收清单，不能判定通过。

仍有自动化无法覆盖的托盘、硬件、权限、视觉、真实账号或设备路径时，输出手动验证文档。全部证据闭合后，才给发布收口建议；提交、推送、tag、release 等外部写操作等待用户授权。

## 开发承接边界

- `dev_plan_vx.x.md`：实施顺序、影响文件、任务、验证、风险和回退。
- `progress_vx.x.md`：状态、最小任务 checklist、阻塞、最近验证和下一步。
- `dev_log_vx.x.md`：需要时记录开发过程；bugfix 和技术 spike 可继续独立记录。

Progress 不保存开发流水、bug 修复过程或大量排查细节。开发承接发现 PRD 缺少链路、数据、表达物或验收标准时，返回 `/prd`，不靠实施计划补产品缺口。

开发承接完成后进入“实施”子阶段。此后按里程碑或强关联任务分批执行，不因用户继续写 `/prd` 就重复生成需求文档。阶段、门禁状态、验证层级和证据继承以 `references/workflow-control.md` 为准。

实施阶段的输出开头必须列“事实源：PRD、dev plan、progress”及实际文件名，并明确本轮是否改写 PRD。验证层级允许提前推进 MVP 时，必须列“进入开发授权：已获得 / 未获得”；未获得用户明确授权时只能建议，不能擅自进入实施。

实施请求缺少项目路径、正式文件或可访问工作区时，先报告输入阻塞并索取最小信息，绝不编造分支、HEAD、哈希、测试结果或完成状态。用户只问“能否降低某个验证门禁”时，先回答门禁决策，不自动扩写整份 PRD。

## 工具与证据

- `/idea` 用工具找用户、行为、问题和竞品证据。
- `/review` 用工具理解真实对象和发现问题。
- `/prd` 用工具确认影响范围、既有行为和数据来源。
- `/acceptance` 用工具实际操作并形成可审计证据。

先检查当前环境可用能力，再选择最小必要工具。只读检查可以主动执行；会修改远端、发布、发送消息、改生产数据或产生费用的操作必须等待用户授权。具体降级顺序见 `references/tooling.md`。

## 长期记忆

Basic Memory 是跨线程续接层，不是聊天归档。每次进入明确项目时先确定 `memory_mode`：`auto`（默认）、`suggest` 或 `off`。

- `auto`：已知项目的新线程或上下文不足时，先恢复记忆，再读取项目正式文档核对；形成稳定阶段结论后，搜索并更新已有项目笔记，不重复创建。
- `suggest`：不直接读写，只在适合时给出 Memory 建议。
- `off`：本轮完全不调用，也不输出 Memory 建议。

只保存未来会复用的决策、偏好、项目约定、稳定路径、版本/发布状态、阻塞和下次继续点。正式 PRD、需求池、进度与验收文档仍留在项目仓库；两者冲突时以仓库事实源为准并修正记忆。工具不可用、信息仍是草稿或内容包含敏感信息时不得假装写入。详细规则见 `references/memory-integration.md`。

## 阶段完成标准

完成前检查：

- 判断是否基于证据，并标出未验证项。
- 写清目标用户、场景、目标、非目标、风险和取舍。
- 交付物是否匹配当前阶段，没有过早升级。
- 正式文档是否引用上游 ID、版本和来源文件。
- 输出是否全中文、UTF-8、无乱码。
- 下一步是否明确；只有阶段真正结束时才加载 `references/next-step-prompts.md` 生成可直接发送的提示词。
- 按 `memory_mode` 完成必要的恢复或阶段收尾写入；不保存完整聊天、临时过程、大段日志或敏感信息，并在实际读写后简短报告结果。

## UI 与 AI 补充

UI 反馈要把“怪、丑、不精致”翻译为信息层级、空间密度、组件一致性、交互状态、边界和产品气质问题。AI/Agent 需求要写清输入、模型处理、工具调用、用户确认、失败模式、评估样例、反馈闭环和人工兜底。
