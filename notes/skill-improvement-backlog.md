# MyP-M-A Skill 优化 Backlog

本文从真实试跑记录中整理 MyP-M-A 的后续优化方向。它不是正式工作流说明，而是维护 skill 时使用的待办池。

## 当前总体判断

MyP-M-A 已经跑通了两条真实项目链路：

- QuickRec：`/review -> /idea -> /prd -> dev_plan/progress -> implementation -> /acceptance`
- LetsMakeMoney：`/review -> /acceptance -> /idea -> /prd`

当前最值得优化的方向不是继续增加入口，而是提高四个入口之间的承接质量：

- `/idea` 要更会形成版本主线和需求依赖关系。
- `/prd` 要更稳定地区分“方案收敛版 PRD”和“完整可开发 PRD”。
- `/review` 要保持 release readiness 能力，并输出下一条可直接发送的提示词。
- `/acceptance` 需要新增真实试跑 notes，把“实现完成”和“发布证据完成”分开。
- 开发承接阶段要稳定输出 `dev_plan_vx.x.md` 和 `progress_vx.x.md`，并保证 progress 不混入开发日志。

## P0：应立即沉淀

### 0. 用户反馈补强：数据、提问、手动验证、全中文

来源：
- 用户在 QuickRec 和 LetsMakeMoney 两轮真实使用后反馈。

问题：
- `/idea` 缺乏数据分析能力和用户/场景压力测试。
- `/prd` 提问数量偏少，导致需求理解不全。
- `/prd` 后的开发承接缺少独立开发日志约束。
- `/acceptance` 缺少手动验证文档。
- 通用输出必须全中文，部分模板存在乱码。

处理状态：
- 已在 `SKILL.md` 增加全中文、UTF-8、数据/场景压力、PRD 提问深度、高保真原型、手动验证文档规则。
- 已在 `references/idea.md` 增加数据分析、数据库证据、用户/场景压力测试、固定评分阈值、版本型需求池。
- 已在 `references/prd.md` 增加提问深度、完整 PRD 门禁、开发承接自动输出、开发日志边界。
- 已在 `references/acceptance.md` 增加手动验证文档规则。
- 已新增 `templates/dev-log-template.md` 与 `templates/manual-verification-template.md`。
- 已清洗 `acceptance-template.md`、`dev-plan-template.md`、`progress-template.md`。

后续：
- 仍需通过更多项目验证数据分析、数据库分析、后端架构、数据库构筑场景。
- 需要增加 eval 覆盖这些新规则。

### 1. 新增 `/acceptance` 真实试跑记录

来源：

- QuickRec 诊断导出 GUI 验收：部分通过。
- LMM v0.4 收尾验收：已完成验证，进入 v0.5 规划。

问题：

- 当前只有 `idea/prd/review` 的真实试跑 notes，缺少 `acceptance-real-run-notes.md`。
- `/acceptance` 是最依赖工具和证据的入口，需要记录真实场景下的通过、部分通过、待验证、路径不一致、Computer Use 局限。

建议：

- 新增 `notes/acceptance-real-run-notes.md`。
- 记录 QuickRec 案例：实现完成不等于发布证据完成；验收对象路径不一致是发布风险。
- 记录 LMM 案例：release readiness review 后进入 acceptance，剩余验证项关闭后不应继续扩 v0.4。
- 后续考虑把经验补进 `references/acceptance.md`。

### 2. `/prd` 增加“完整 PRD 完成度闸门”

来源：

- LMM v0.5 PRD 初版只完成了类型判断、方案收敛、范围和低保真内容，还不是完整可开发 PRD。
- 用户明确要求完整 PRD 需要高保真版本原型。

问题：

- 当前 `/prd` 规则要求原型图，但没有明确什么时候低保真足够，什么时候必须更新高保真版本原型。
- 容易在“方案收敛版 PRD”之后过早进入 dev plan。

建议：

- 在 `references/prd.md` 中增加“PRD 完成度闸门”：
  - 方案收敛版：只能用于方向确认，不可直接进入开发承接。
  - 完整可开发 PRD：必须补齐功能细节、完整链路、数据配置、影响范围、验收、原型。
  - UI/体验主线版本必须包含高保真版本原型或更新现有原型文件。
- 增加检查项：如果 PRD 没有完整链路和原型更新，不应生成 `dev_plan_vx.x.md`。

### 3. `/idea` 增加“版本主线与依赖关系”要求

来源：

- LMM v0.5 idea-pool 初版内容方向正确，但用户觉得“有点少”。
- 增强后补了 v0.5 主线判断、依赖关系、证据映射、三档范围方案，质量明显提升。

问题：

- 当前 `/idea` 多需求池偏重单个需求评分，但对“版本候选池”缺少主线判断和依赖关系。

建议：

- 在 `references/idea.md` 中增加版本型 idea pool 规则：
  - 如果输入来自上一版本 review/acceptance，必须给出版本主线判断。
  - 必须说明为什么不是其他大方向。
  - 对候选需求画依赖关系图或表。
  - 给出最小方案、推荐方案、过大方案。
  - 把上一版本验收项转译为下一版本候选证据。

## P1：近期优化

### 4. 开发承接规则进一步拆出独立 reference

来源：

- `dev_plan_vx.x.md` 和 `progress_vx.x.md` 已经写进 `references/prd.md`。
- 这部分会继续增长。

问题：

- `references/prd.md` 已经偏长，开发承接内容继续增加会影响 progressive disclosure。

建议：

- 新增 `references/development-handoff.md`。
- `references/prd.md` 只保留简短入口和触发条件。
- 把 dev plan/progress 命名、模板、边界、Vibe Coding checklist、progress 不写开发日志等规则迁移进去。

### 5. 模板需要更贴近真实项目

来源：

- 当前 `templates/dev-plan-template.md` 和 `templates/progress-template.md` 是通用版。
- QuickRec 和 LMM 的真实输出需要版本平级、模块化、总览表、Vibe Coding 最小任务。

建议：

- 增强 `progress-template.md`：
  - 增加“版本主线/当前阶段/总进度”。
  - 增加“模块任务 + 完成度统计”。
  - 增加“验收状态”。
- 增强 `dev-plan-template.md`：
  - 增加“实施前检查”。
  - 增加“与 PRD 对照表”。
  - 增加“不可扩范围项”。

### 6. `/review` 可继续优化“建议下一条提示词”

来源：

- LMM 收尾型 review 说明，输出下一条可发送提示词很有用。

问题：

- `references/review.md` 已加入该项，但还没有示例。

建议：

- 给 release readiness review 增加一段示例提示词。
- 给普通 project review 增加 `/idea` 承接提示词示例。

## P2：后续优化

### 7. agents/openai.yaml 可能需要同步

问题：

- `SKILL.md` 描述扩展了开发承接、release readiness、acceptance 等能力。
- 如果 `agents/openai.yaml` 存在，可能需要检查展示名称、默认提示词和短描述是否仍准确。

建议：

- 检查 `agents/openai.yaml`。
- 如已过期，按 `skill-creator` 的规则重新生成或手动同步。

### 8. 增加轻量 eval 样例

建议样例：

- QuickRec：诊断导出从 idea 到 PRD。
- QuickRec：部分通过 acceptance，判断是否可发布。
- LMM：v0.5 idea pool 初版不足，要求增强。
- LMM：方案收敛版 PRD 是否能进入 dev plan。

目标：

- 检查 MyP-M-A 是否会过早进入代码。
- 检查是否会把 progress 写成开发日志。
- 检查是否会把 release fact mismatch 误判为新需求。

## 已经落地的优化

- `/review` 已补 release readiness review。
- `/review` 已补下一步分流和建议下一条提示词。
- `/prd` 已补 dev plan/progress 开发承接规则。
- 新增 `templates/dev-plan-template.md`。
- 新增 `templates/progress-template.md`。
- 真实试跑 notes 已覆盖 `/idea`、`/prd`、`/review`、`/acceptance`。

## 建议下一步

优先执行：

1. 新增 `notes/acceptance-real-run-notes.md`。
2. 在 `/prd` 中补“完整 PRD 完成度闸门”和“高保真原型要求”。
3. 在 `/idea` 中补“版本主线/依赖关系/三档范围方案”。

这三项会直接改善当前 QuickRec 和 LMM 的下一轮真实使用。

## 2026-07-09 非验证优化推进记录

本轮按“先推进验证以外的优化”处理，未运行新项目验证或 eval。

已完成：

- 新增 `references/development-handoff.md`：拆出完整 PRD 后的开发承接规则，覆盖 `dev_plan_vx.x.md`、`progress_vx.x.md`、`dev_log_vx.x.md`。
- 新增 `references/data-analysis.md`：拆出数据分析、数据库、日志、指标、样本偏差和阶段输出规则。
- 新增 `references/next-step-prompts.md`：统一每个阶段结束后的下一阶段建议和可直接发送提示词。
- 更新 `SKILL.md`：接入上述三个 reference。
- 更新 `references/idea.md`：复杂数据场景指向 `data-analysis.md`。
- 更新 `references/prd.md`：声明开发承接细节以 `development-handoff.md` 为准。
- 重写并清洗模板：`idea-pool-template.md`、`prd-template.md`、`review-report-template.md`、`launch-checklist.md`、`product-brief-template.md`、`roadmap-template.md`。

仍未处理：

- 未跑新项目验证。
- 未增加 eval。
- 未做 skill 触发描述优化。
- 未清理 notes 体积和归档策略。
