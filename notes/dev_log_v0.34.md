# v0.34 开发日志

> 本文记录开发过程、关键决策、异常处理和验证结果。它不替代 `notes/progress_v0.34.md`；progress 只保留状态看板和最小任务 checklist。

## 基本信息

- 版本：`v0.34.0 Stable（已同步远端）`
- 对应 PRD：`notes/v0.34-governance-prd.md`
- 对应 dev plan：`notes/dev_plan_v0.34.md`
- 对应 progress：`notes/progress_v0.34.md`
- 当前阶段：Stable 晋升、提交与远端同步完成
- 上一远端稳定版：`v0.33.0 Stable`

## 记录规则

- 每个任务或紧密关联的 2～3 个任务写一条记录。
- 记录实际改动、原因、命令、结果、未验证项和回退点，不复制 PRD 或 dev plan 正文。
- 过程性 Agent 输出、完整日志和临时 viewer 不纳入仓库，只记录正式证据路径与摘要。
- bugfix 流水进入独立 `bugfix_log_v0.34.md`；技术 spike 进入独立文档。
- 未执行的测试、提交、推送、tag、Release 或 Memory 写入不得记为完成。

## 开发记录

### 2026-08-10 / 开发承接

- 本轮目标：把已确认的 v0.34 内部治理 PRD 转成可执行、可跟踪、可回退的开发承接文档。
- 改动模块：`notes/v0.34-governance-prd.md`、`notes/v0.34-idea-pool.md`、`notes/dev_plan_v0.34.md`、`notes/progress_v0.34.md`、本文。
- 关键实现：沿用 PRD 的 M0～M5 顺序；把 FR/AC 映射到 34 个实施任务；为每批定义进入条件、完成条件、验证和独立回退点。
- 遇到的问题：无开发承接阻塞；本轮不应提前修改 Skill 运行规则。
- 处理方式：只更新阶段事实和承接文档，保持 `SKILL.md`、`references/`、`evals/`、`scripts/` 不变。
- 已验证：PRD、需求池、开发承接规范与模板完成交叉核对；`validate-skill.ps1 -Strict`、evaluation pipeline self-test、UTF-8 严格检查和 `git diff --check` 均通过。
- 未验证 / 待补证：M0～M5 的实现、行为回归和候选验收尚未开始。
- 关联 bugfix / spike：无。
- 下一任务：`V034-M0-001`。

### 2026-08-10 / M0 基线与直接治理

- 本轮目标：关闭 V034-M0-001～006 和 M0 门禁，在任何入口行为 reference 改动前建立可复算基线。
- 改动模块：`evals/context-budget.json`、`evals/trigger-baseline.json`、`scripts/measure-context-budget.ps1`、`scripts/test-context-budget.ps1`、roadmap、backlog、dev plan 与 progress。
- 关键实现：定义五入口 minimum/formal/profile 文件组合与 v0.33 字符/字节基线；实现只读预算测量、JSON/Markdown 输出和显式原子落盘；使用去标签输入分别执行 Sol medium、Terra medium 34 条触发分类；修正 roadmap/backlog 的旧 56 条和旧版本待办口径。
- 遇到的问题：Windows PowerShell 5.1 会把无 BOM `.ps1` 中的中文源码按系统代码页解释；`File.Replace` 在该环境下不能使用空备份路径。
- 处理方式：脚本源码保持 ASCII，通过 Unicode 转义生成中文 Markdown；覆盖写采用同目录临时文件和临时备份完成原子替换，并在 finally 中清理。
- 已验证：预算 self-test `6/6`；五入口实际报告连续两次除时间外一致；字符基线逐项匹配 PRD；Sol/Terra medium 均 `34/34`；五项触发输入哈希匹配；严格静态校验、evaluation pipeline self-test 和 `git diff --check` 通过。
- 未验证 / 待补证：M1 合同映射、动态面板、v0.33 回放和 validator 模块化尚未开始。
- 关联 bugfix / spike：两处 PowerShell 5.1 兼容问题在 M0 内闭合，不另建 bugfix log。
- 回退点：删除两个 M0 JSON 与两个预算脚本，恢复 roadmap/backlog 和状态文档；不影响 v0.33 运行规则。
- 下一任务：`V034-M1-001`。

### 2026-08-10 / M1 评测与校验基础

- 本轮目标：关闭 V034-M1-001～006 和 M1 门禁，在 reference 试点前建立合同变化到回归用例的可审计映射。
- 改动模块：`evals/contract-registry.json`、`evals/release-panel-core.json`、`evals/release-panel.json`、`scripts/build-eval-panel.ps1`、`scripts/validation/`、`scripts/test-skill-validation.ps1`、`scripts/validate-skill.ps1` 和评测说明。
- 关键实现：登记 29 条承重合同；固定 9 条核心覆盖五入口、数据、工具、Memory 和高风险证据；动态 builder 支持 Git diff、显式合同、相邻控制、无行为变化豁免和受影响入口全量升级；旧单体检查与 docs/evals/contracts 新模块并行。
- 遇到的问题：若把 eval 36 放入固定核心，v0.33 回放无法证明它由合同差量进入；无受影响合同时，PowerShell 空属性投影会生成单个 null。
- 处理方式：固定验收核心改用 eval 76，eval 36 保留给 `acceptance-explicit-inheritance` 差量；affected contract 数组改为显式管道枚举，空集合保持真正空数组。
- 已验证：v0.33 `d1f19d6..4ca7de3` 回放两次均生成 17 条面板且哈希一致，eval 36、61 位于 delta；正向夹具与七类负向夹具通过；未知合同、重复核心、无映射、有效豁免和 26 条上限升级路径通过；严格校验显示 legacy/modular 均 `0/0`；evaluation pipeline self-test 通过。
- 未验证 / 待补证：M2 `/prompt`、`/review` 真实 reference 切片和双模型行为回归尚未开始；官方 `quick_validate.py` 在系统与 Codex bundled Python 中均因缺少 `PyYAML` 无法启动。
- 关联 bugfix / spike：两处实现细节在 M1 内闭合，不另建 bugfix log。
- 回退点：恢复旧 `release-panel.json`、builder 和单体 validator，删除合同表、核心表、模块与夹具；不影响 v0.33 行为 reference。
- 下一任务：`V034-M2-001`。

### 2026-08-11 / M2 `/prompt`、`/review` 与 Deep Review 试点

- 本轮目标：在不新增入口、框架或外部硬依赖的前提下，降低两个试点入口的实际加载量，并用跨模型差量回归验证承重合同。
- 改动模块：`references/prompt.md`、`references/next-step-prompts.md`、`references/review.md`、`references/deep-review.md`、`evals/contract-registry.json`、`evals/evals.json`、三份 Review 自包含夹具及 `evals/pilot-v0.34-m2.json`。
- 关键实现：`/prompt` 改为固定核心、条件差量、场景矩阵和压缩终检；第二批定向验收保持 L1 四段结构。`/review` 保留项目主通路与实现辅通路，Deep Review 先建对象地图，再按对象选择 3～6 个领域维度。新增稳定用例 85，验证 Skill 治理 Review 不误装 UI、GTM 或数据库维度。
- 测试输入修正：稳定用例 16、17、23 原先声称已有项目、截图或日志材料，但隔离执行未提供附件；补入中性自包含夹具，只修正输入闭合性，不改变评分目标。
- 上下文预算：`/prompt` minimum/formal/memory 分别下降 `27.31% / 32.84% / 23.25%`；`/review` minimum/formal/deep-review 分别下降 `11.57% / 10.10% / 10.01%`。
- 行为验证：首轮宽面板用于发现缺口，不作为最终门禁。修正后 8 条受影响与控制用例中，Sol medium 为 `66/69 -> 67/69`，Terra medium 为 `68/69 -> 68/69`，候选 0 回退；最终 eval 56 单例复验为 Sol `7/8 -> 7/8`、Terra `8/8 -> 8/8`。
- 人工裁决：Sol 的共同漏项是没有逐字写出“禁止虚构证据”，但回答已要求无效证据不得通过并保持发布停止；该项与基线相同，不继续为单次字面波动堆叠规则。早期 Memory 控制失败来自执行器明确禁用 Memory，不能计作 Skill 能力失败。
- 回退点：仅恢复四份试点 reference、合同映射、稳定用例 85 与三份夹具；M0/M1 的预算、触发和 validator 基础保持不动。
- 未执行：未做 85 条稳定集或 21 条挑战集全量回归，未提交、未推送、未打 tag、未创建 Release。
- 下一任务：M3 单入口治理或 M4 交付质量配对评测。

### 2026-08-11 / M3 三个重入口治理

- 本轮目标：在保持数据、异步状态、原型、验收身份、证据继承和发布授权合同的前提下，治理 `/idea`、`/prd`、`/acceptance` 三个高负载入口。
- 改动模块：`references/idea.md`、`references/prd.md`、`references/acceptance.md` 及其动态面板评测工作区。
- 上下文预算：`/idea` 正式装配 `16,750 -> 10,578`（`-36.85%`）；`/prd` 首次治理为 `23,324 -> 13,114`，修复状态合同后的最终值为 `23,324 -> 13,260`（`-43.15%`）；`/acceptance` `22,025 -> 17,706`（`-19.61%`）。连同 `/prompt` 的 `-32.84%`，四个重入口正式负载最终平均下降 `33.11%`；`/review` 试点独立下降 `10.10%`。
- 行为验证：`/idea` Sol `102/106 -> 103/106`、Terra `92/106 -> 99/106`；`/prd` Sol `114/120 -> 120/120`。Terra 首轮暴露异步状态从 `running` 漂移为 `processing`，修复后 eval 32 在 Sol/Terra 候选均为 `9/9`。
- `/acceptance` 验证：第一次 Terra 候选执行忘记加载 Skill 快照，异常降到 `69/89`；该结果判为执行器无效并重跑。正确加载后为 `86/89 -> 86/89`，主验收用例 `6/8 -> 8/8`。波动控制项复验为 Sol `16/16 = 16/16`、Terra `13/16 -> 16/16`。
- 关键教训：行为执行任务必须显式提供 `_snapshots/<configuration>/SKILL.md`；只读 `task.json` 相当于测试裸模型，不能用于版本判断。匿名评分继续严格保护检查项原文，曾拒绝两条被评分器改写的标准文本。
- 回退点：三个入口 reference 可分别恢复；`/prd` 的规范状态基线属于已验证硬合同，不随文本压缩回退。
- 未执行：未重跑 85 条稳定集与 21 条挑战集全量目录；只按合同差量、入口面板和相邻控制收口。

### 2026-08-11 / M4 七维交付质量评测

- 本轮目标：把“正确但更长/更短”的体感拆成正确性、决策清晰度、重复度、可执行性、字符数、完成时长和有效返回率，不生成综合质量总分。
- 改动模块：`evals/delivery-quality-rubric.json`、`scripts/delivery-quality-batches.ps1`、`scripts/regression-workspace.ps1`、`scripts/generate-eval-viewer.ps1`、`scripts/test-delivery-quality.ps1` 及 validator。
- 样本：冻结 10 对 M3 历史输出，覆盖五入口、Sol/Terra medium 和 5 个复杂场景；选择包含候选获胜、同分和不利候选样本，匿名输入映射泄漏为 0。
- 盲评结果：正式正确性 `73/81 -> 81/81`；决策清晰度基线/候选 `2:8`；重复度 `7:3`；可执行性 `4:6`。候选平均字符 `1,656.1 -> 2,644.0`（`+59.6%`）；时长无可信执行元数据，按合同记为 `unavailable`；双方有效返回率均为 `100%`。
- 成本判断：字符增幅超过 15%，但清晰度与可执行性存在候选收益，因此成本边界通过；重复度和长度问题保留为后续观察，不用删承重合同换短文本。
- 管线验证：匿名 A/B 映射、逐样本证据、七维独立展示、可选 `execution.json duration_ms`、旧工作区兼容、品牌扫描和两套 pipeline self-test 均通过。
- 证据位置：仓库外临时工作区 `E:/codex/skill-evals/mypm-v034-m4-quality-20260811/`；长期结论回写评测历史后，该工作区可删除。

### 2026-08-11 / M5 notes 迁移审计

- 先创建 `notes/v0.34-note-migration-audit.md`，记录 10 份历史资料的入站引用、目标和回退方法。
- 更新 6 处有效入站引用后，将 6 份关闭版本资料移入 `notes/archive/`，4 份真实入口案例移入 `notes/cases/`。
- `stage-tooling-audit.md`、`pm-skill-reference-notes.md` 仍是跨版本能力事实源，保留在 notes 根目录。
- 下一任务：同步五份版本事实源并执行 AC-001～AC-010 最终 Candidate 门禁。

### 2026-08-11 / M5 Candidate 门禁收口

- 同步 README、roadmap、CHANGELOG、evaluation history 和 backlog，并创建 `notes/v0.34-candidate-gate.md`。
- 最终预算复算将 `/prd` 补回规范状态合同后的正式装配锁定为 `23,324 -> 13,260`（`-43.15%`）；四个重入口最终平均下降修正为 `33.11%`。阶段性的 `33.27%` 不再作为当前事实。
- 严格校验首次运行真实拦截 CHANGELOG 未分别写出稳定集与挑战集口径；补为稳定集 `未全量重跑 / 666`、挑战集 `未全量重跑 / 190` 后复验通过。
- 两份最终预算报告按 self-test 的同一方法解析 JSON、将 `generated_at` 置空并压缩序列化后完全一致。不同 JSON 序列化实现会得到不同字节哈希，因此不再把临时环境生成的哈希作为门禁证据。
- AC-001～AC-010 按 Candidate 口径通过；AC-009 在独立验收批准 Stable 时必须再次复核。当前只允许进入 `/acceptance`，不授权提交、推送、tag 或 Release。

### 2026-08-11 / 独立验收第一轮证据修正

- Terra medium 首轮独立验收为 PARTIAL：指出 AC-001 临时序列化哈希不可跨环境复现，以及 M3/M4 运行快照到当前候选的继承边界未完整披露。
- 移除不可移植哈希，新增 `context-budget-comparison.json`，记录与 self-test 一致的语义比较方法和 `semantic_equal=true`。
- 新增 `m3-runtime-lineage.json`，逐工作区比较候选快照与当前文件：最终 Sol/Terra 控制组和 Terra acceptance 全面板仅 README 不同；Sol acceptance 首轮还差旧 `prd.md`，因此保留失败但不作为最终通过证据。
- 明确 M4 是冻结历史输出的质量盲评，不宣称为当前候选的新行为执行。下一步由 Sol/Terra medium 复核修订后的证据链。

### 2026-08-11 / 独立验收第二轮

- Sol medium 与 Terra medium 使用相同修订证据包复核 AC-001、M3 lineage、Sol 首轮回退、最终 r2 控制组和 M4 身份边界，二者均给出 PASS。
- Sol/Terra 均确认：PASS 仅代表 Candidate 实施门禁和 A/B 证据链，不等于 Stable，也不授权 commit、push、tag 或 Release。
- 新增 `notes/v0.34-acceptance.md`，保留第一轮 PARTIAL、修正内容、第二轮结论、A/B 数据和剩余边界。

### 2026-08-11 / 本地 Stable 晋升

- 用户在核对 v0.33/v0.34 差异后，授权 v0.34 晋升为本地 Stable 并完成提交收口。
- 将 `SKILL.md`、正式 eval 元数据、README、roadmap、CHANGELOG、evaluation history、backlog 和 progress 同步到 `v0.34.0`。
- 版本晋升只改变版本与治理事实，不改写已验收运行合同；触发 description 和 Agent 配置未变化，因此继承双模型 `34/34` 触发证据。
- 当前目录仍明确披露稳定集 `未全量重跑 / 666`、挑战集 `未全量重跑 / 190`，不把本地 Stable 解释为跨模型普遍优于 v0.33。
- 本轮不推送、不打 tag、不创建 Release；远端稳定基线保持 `v0.33.0`。

### 2026-08-11 / 远端同步

- 用户单独授权 push 后，将发布提交 `e06ee9b` 快进推送到 `origin/main`。
- 全局 Git 代理指向未监听的 `127.0.0.1:17890`；本轮仅对 push 命令临时清空代理配置，未修改用户全局设置。
- 同步 README、roadmap、CHANGELOG、evaluation history、backlog、progress 和验收后续状态为 `remote-synced`，并创建独立状态提交。
- 本轮未创建或移动 tag，未创建 Release。

## 关键决策

| 决策 | 背景 | 取舍 | 影响范围 | 后续观察 |
|---|---|---|---|---|
| 保持 M0 -> M1 -> M2 的强制顺序 | reference 切片必须先有可信基线和门禁 | 延后可见的压缩成果，换取可回退证据 | 全部实施批次 | M1 已捕获 36/61；M2 观察真实切片回归 |
| 固定核心与合同差量分离 | 历史固定 13 条不能解释为何选中 | 核心缩为 9 条，版本风险由 registry 动态补齐 | 发布面板、validator | M2 面板是否稳定控制在 26 条内 |
| M3 每次只处理一个入口 | 三个入口合同复杂且回归成本高 | 周期更长，但失败可独立恢复 | `/idea`、`/prd`、`/acceptance` | 单入口预算与 critical 回退 |
| progress 与 dev log 分离 | 历史 progress 容易混入流水账 | 增加一个文件，换取状态可读性 | v0.34 文档治理 | progress 是否始终只保留状态 |
| v0.34 晋升本地 Stable | M0～M5 与独立验收均通过，用户已授权 | 远端仍停在 v0.33，tag/Release 继续分离授权 | README、roadmap、发布材料 | 严格校验与提交状态 |
| PowerShell 脚本源码保持 ASCII | PowerShell 5.1 对 UTF-8 无 BOM 中文源码不稳定 | 中文输出改由 Unicode 转义生成 | v0.34 新增 `.ps1` | M1 新脚本继续遵守并增加编码夹具 |

## Bugfix 摘要

当前无 bugfix 记录。

## Spike / 技术探索摘要

当前无 spike 记录。

## 验证摘要

- 自动化验证：预算 self-test 6 类通过；最终预算重复输出一致；触发基线 Sol/Terra medium 均 `34/34`；M1 正向 1 类、负向 7 类夹具及 builder 七类路径通过；v0.33 回放确定性通过；严格 validator、旧评测管线和七维交付质量管线 self-test 全部通过；UTF-8、乱码、历史路径和 `git diff --check` 通过。
- 手动验证：已人工核对 FR/AC 与 M0～M5 任务映射、七维 viewer、notes 迁移审计及五份发布事实源。
- 打包验证：不适用，本版本为 Skill 治理。
- 未覆盖项：完整稳定集/挑战集全量回归、可信完成时长、独立 `/acceptance`。

## 收尾事项

- 文档同步：已完成；当前统一为 `v0.34.0 Stable / remote-synced`。
- 发布说明：已更新 Stable changelog，但不宣称已打 tag 或已创建 Release。
- 回滚方式：回到 `26e2e66491280470c1876d29544c826aa626d6d5` 可恢复 v0.33 远端稳定基线；评测与校验资料保留在 v0.34 提交中。
- 下一阶段建议：由用户分别授权 annotated tag 和 Release；在此之前停止其他远端写操作。
