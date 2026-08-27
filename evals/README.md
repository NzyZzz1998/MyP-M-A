# MyP-M-A 评测说明

MyP-M-A 使用两套互补评测，不混合计算总分。
<!-- contract:separate-eval-scores -->
<!-- contract:eval-execution-isolation -->
<!-- contract:eval-release-panel-lifecycle -->

版本结果、证据边界和清理记录统一保存在 `notes/evaluation-history.md`。本目录只保留可重复执行的用例、附件和操作说明。

## 评测资产架构

v0.41 起，评测“资产目录”和“每轮执行面板”分开治理。历史用例可以保留，但保留不等于每轮都执行；不设置强制删减数量。

| 资产 | 事实源 | 职责 | 默认执行方式 |
| --- | --- | --- | --- |
| 稳定集 | `evals.json` | 防止已验证核心合同回退 | 按合同影响选择；需要全量证明的行为 Stable 候选运行完整活跃组合 |
| 挑战集 | `challenge-evals.json` | 暴露证据冲突、边界和复杂决策缺口 | 与稳定集分开执行、评分和汇报 |
| 触发集 | `trigger-evals.json` | 验证该不该进入 MyP-M-A 以及入口识别 | description、宿主配置或触发题面变化时运行 |
| 固定核心 | `release-panel-core.json` | 五入口、数据、工具、Memory 和高风险证据的长期冒烟 | 每个行为候选进入 T1/T2 |
| 当前差量 | `release-panel.json` | 固定核心、本版合同差量和相邻控制 | 只代表当前候选，不覆盖完整目录 |
| 外部对标 | `external-benchmark-contract.json` | 与其他 PM Skill 做同协议观察 | 只在里程碑版本或专项研究运行 |

机器可读规则位于 `evaluation-policy.json`；逐题状态及决策位于 `eval-state-registry.json`；由九个事实源生成的统一账本位于 `eval-inventory.json`。账本不复制题面和断言，禁止手工维护：

```powershell
.\scripts\build-eval-inventory.ps1
.\scripts\build-eval-inventory.ps1 -Check
```

当前账本覆盖 194 项资产：114 条稳定用例、46 条挑战用例和 34 条触发用例。每项都登记 route、风险、合同或场景归属、生命周期、默认层级和当前选择角色。

## 生命周期与执行层级

用例生命周期固定为 `core`、`active`、`canary`、`archived`、`retired`，不由当前面板角色推导。新行为用例先登记 `canary`；连续两个稳定版本后由维护者决定晋升、合并或归档。每次转换保留版本、原因与决策证据；归档/退役保留最后有效版本，退役另需有效 successor。归档可经新决策恢复，退役不能直接复活，不物理抹除历史证据。

| 层级 | 内容 | 触发条件 |
| --- | --- | --- |
| T0 | Schema、归属、账本新鲜度、链接、UTF-8、预算和确定性自测 | 每次修改 |
| T1 | 固定核心；按需增加触发集 | 入口描述、常驻合同或行为文件变化 |
| T2 | 固定核心 + 本版差量 + 相邻控制 | 每个行为候选版本 |
| T3 | 受影响入口的 active/core/canary 用例 | 入口核心、共享合同变化或 T2 超出默认规模 |
| T4 | 完整 core/active/canary 稳定集与挑战集，分别报告 | 需要全量证明的行为 Stable 候选、重大回退调查或实际覆盖变更 |
| T5 | 七维质量、跨模型与外部 Skill 对标 | 关键节点版本或明确研究任务 |

正确性、证据纪律、完整性和事实保真是不可补偿门禁；清晰度、可执行性和有效返回率是质量门禁；重复度、字符数、完成时长和重试率只作观察。任何报告都不得把这些维度合并成单一质量总分。

T0～T5 是选择协议，不是自动执行器；`coverage / targeted-max` 是现有脚本的执行档位，不与这些层级一一对应。模型调度与重试由外部任务按协议执行。纯文档/工具治理且运行时、题面、断言和覆盖未变时，只做 T0，不追溯改判已验收版本。默认行为基线为 Sol medium 每题一次；非默认模型或强度需在本轮协议单独冻结。

## 稳定集

`evals.json` 用于发现明显行为回退。它覆盖四个产品阶段、`/prompt`、Memory 和常见附件场景。稳定集通过不等于新版整体更好，只表示核心合同没有明显退化。

## 挑战集

`challenge-evals.json` 用于区分细节质量。题目刻意包含统计口径歧义、证据冲突、异步状态、租户权限、产物身份和高风险发布条件。挑战集可以暴露“格式正确但判断错误”的输出。

挑战集规则：

1. 新旧版本必须使用同一模型、同一附件和同一评分器。
2. 默认用 `coverage` 档位、Sol medium 各运行一次；只有受影响、失败或评分不稳定的用例才进入 `targeted-max`，并按需补样本。执行重试与独立多样本复测分别记账，不能混用分母。
3. 评分器必须逐条引用输出证据，不能只给总分。
4. 前两次标准用例 SLA 为五分钟；正式 PRD、深度 Review、复杂 Acceptance 和显式 `long_form` 为十分钟。第三次不因时间自动终止，继续等有效结果；仅明确执行器错误或用户停止可记未完成，不自动追加第四次，不生成空白答案。重试与超时成本单列，不抵扣正确性。
5. 稳定集与挑战集分别汇报；能力比较只使用双方都有效返回的共同样本，同时保留各自完成率和输出长度。
6. max 盲评默认每批 3 条。每条仍独立评分、保留原检查项和中文证据，批量只减少重复冷启动。
7. 执行模型只能读取 `task.json`、对应 Skill 快照和题目点名的附件，并从空临时目录运行；不得扫描共享工作区、其他项目、Memory、历史回答或评分材料。输出出现题目未提供的项目名、路径或状态时，标记为“上下文污染”并排除，不计能力得分。

## 发布面板与执行生命周期

`release-panel-core.json` 固定 9 条长期核心；`release-panel.json` 保存当前候选的核心、合同差量和相邻控制快照。动态面板默认目标为 26 条，超过目标时升级为受影响入口回归，不静默截断 critical 合同。v0.41 的 28 条快照用于保留 15 条工作模式差量和 4 条相邻控制，是当前版本证据，不把 28 改写成新的默认规模。两者都不复制题目或评分点，也不替代稳定集和挑战集完整回归。

只执行当前快照：

```powershell
.\scripts\build-eval-panel.ps1 -OutputPath E:\codex\skill-evals\mypm-release-panel.json
```

按 Git 差异和显式合同生成候选快照：

```powershell
.\scripts\build-eval-panel.ps1 `
  -BaselineRef <baseline-ref> `
  -CandidateRef <candidate-ref> `
  -AffectedContracts acceptance-explicit-inheritance,prd-async-idempotency `
  -SnapshotPath E:\codex\skill-evals\mypm-panel-snapshot.json `
  -OutputPath E:\codex\skill-evals\mypm-release-panel.json
```

同一行为文件承载多个合同、而本轮只修改其中一部分时，可使用 `-UseExplicitAffectedContracts`。此模式要求每个行为文件至少命中一个显式合同；仅版本元数据或重复摘要等无独立行为变化的文件，必须通过 `-NoBehaviorChangeFile` 给出非空审计理由。它不会自动放宽评测范围。

行为文件没有合同映射时生成失败；确属无行为变化时，使用独立 JSON 记录 `source_file` 或 `contract_id` 与非空 `reason`，再通过 `-NoBehaviorChangeFile` 提供。`contract-registry.json` 是合同来源、入口、风险与评测映射的结构化事实源。

运行时默认最大并发 3；每个子 Agent 最多处理 5 条相互独立的用例，完成一批立即关闭。标准等待 5 分钟，长任务等待 10 分钟；超时只重试缺失项，不重跑已落盘回答。执行完成率、共同有效样本得分和输出长度分开报告。入口或共享合同变化先执行 T2/T3；需要全量证明的行为 Stable 候选、重大回退调查或实际覆盖变化才进入 T4，面板只承担快速反馈。

上述等待阈值只适用于前两次。第三次继续等待，不设自动时间截止。T3 同时纳入受影响入口的合同题和场景题，并保留固定核心、去重、排除 archived/retired；冻结快照若含停用题则报错。状态记录缺失时仅旧版无策略仓库可使用兼容模式，新版不得静默降级。

场景条目使用 `category=scenario` 与 `scenario_group_id` 标明归属，不伪造合同 ID。标准快照写入后，合同校验器会核对场景组、用例、入口及生命周期；缺失或伪造归属、混合合同与场景归属、停用条目均被拒绝。生成成功不能替代这一端到端校验。

## 回归工作区

`scripts/regression-workspace.ps1` 只负责准备快照、目录和元数据，并校验已有结果。执行目录中的 `task.json` 只包含用户请求和原始附件；预期结果与评分点隔离在 `_grader/`，不得提供给执行模型。脚本不会调用模型，也不会把缺失结果伪装成失败。

```powershell
.\scripts\regression-workspace.ps1 `
  -Action Prepare `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023 `
  -BaselinePath D:\path\to\mypm-v022 `
  -CandidatePath D:\Work\Software\codex_home\.agents\skills\mypm `
  -EvalFile evals\challenge-evals.json `
  -SuiteLabel '挑战集' `
  -EvaluationTier coverage `
  -ReasoningEffort low `
  -SlaSeconds 300 `
  -MaxConcurrency 3
```

`regression-workspace.ps1` 不直接调用模型。外部执行器只读取各目录中的 `task.json` 和 `_snapshots`；缺失回答保持缺失，不生成空白占位。

回答落盘后，生成匿名盲评批次：

```powershell
.\scripts\grading-batches.ps1 `
  -Action Prepare `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023 `
  -BatchSize 3
```

只能把 `_grading-batches\batch-*-input.json` 提供给评分模型；不得提供 `_private\mapping.json`。评分结果按对应名称保存为 `batch-*-output.json` 后执行：

```powershell
.\scripts\grading-batches.ps1 `
  -Action Apply `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023
```

模型与评分结果落盘后执行：

```powershell
.\scripts\regression-workspace.ps1 `
  -Action Validate `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023
```

结构校验会生成 `validation-report.json`、`benchmark-lite.json` 和 `benchmark-lite.md`。其中配置汇总用于观察有效返回质量和 SLA 完整性；`paired_summary` 只比较双方共同有效样本。需要人工逐项对照时，再生成自包含 viewer：

空白回答、明确失败、取消、运行中或损坏的执行元数据不计有效返回，保留状态、尝试次数和耗时。旧记录缺少执行状态时标为 `unknown`，仅按非空回答与合法评分兼容，并单列 `legacy_status_unknown_runs`；不能声称这部分执行成功已被独立证明。质量盲评准备/汇总复用同一校验，不能靠残留文件生成 100% 有效率。

```powershell
.\scripts\generate-eval-viewer.ps1 `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023 `
  -Title 'MyP-M-A v0.22 vs v0.23' `
  -BaselineLabel 'v0.22 基线' `
  -CandidateLabel 'v0.23 候选'
```

Viewer 展示提示词、新旧回答、逐条断言、证据和修复前归档；轻量汇总不能代替人工复核。

## 七维交付质量评测

正式布尔断言只回答“合同是否满足”，不能单独说明输出是否清晰、重复或便于执行。v0.34 增加 `evals/delivery-quality-rubric.json`，七个维度必须分开报告：

1. 正确性：沿用 `grading.json` 的正式布尔断言，是硬门禁。
2. 决策清晰度、重复度、可执行性：使用隐藏 A/B 映射的逐样本配对盲评。
3. 字符数：机械统计，只报告变化，不把长短直接解释成质量。
4. 完成时长：读取每个运行目录的 `execution.json`，新记录示例为 `{ "status": "succeeded", "duration_ms": 1234, "attempts": 1 }`；失败另记 `stopping_reason`。缺失耗时写 `unavailable`，不能填 0；旧版只有 `duration_ms` 的结构继续兼容但状态为未知。
5. 有效返回率：非空回答、合法逐项评分及执行状态门禁都通过才算有效；旧状态未知材料单列，失败/缺失不伪装成能力低分。质量面板的 100% 只描述预先冻结且已通过校验的配对样本，不代表整个用例库。

质量面板必须冻结 8～10 对样本，覆盖五入口和至少两个复杂场景，不得只选择候选获胜样本。准备匿名批次：

```powershell
.\scripts\delivery-quality-batches.ps1 `
  -Action Prepare `
  -Workspace D:\path\to\quality-workspace `
  -BatchSize 4
```

评分模型只能读取 `_quality-batches/batch-*-input.json`，不得读取 `_private/mapping.json`。结果按 `batch-*-output.json` 落盘后执行：

```powershell
.\scripts\delivery-quality-batches.ps1 `
  -Action Apply `
  -Workspace D:\path\to\quality-workspace
```

发布优先级由 `evals/release-quality-policy.json` 统一定义：正确性、证据纪律和完整性是不可补偿的硬门禁；决策清晰度、可执行性和有效返回率是质量门禁；重复度、字符数和时长只作观察。正式 PRD、验收报告和深度 Review 不设置通用字符上限。

生成的 `quality-report.json` 不包含综合质量总分，并分别报告两项成本观察：

- 成本观察：字符增加超过 15% 或可比较的中位时长增加超过 25%，且清晰度、可执行性均无候选收益时标记需优化。
- 密度观察：候选平均字符增长超过 35%，且基线在至少 50% 的配对样本中重复度更优时标记需优化。

成本或密度观察不能单独阻止正式文档晋升；只有用户明确要求摘要、短提示词或字符上限时，长度才可成为该任务的阻塞条件。历史报告不追溯改写。

## OpenCodeReview 定向覆盖

- 稳定用例 ID 82：私有桌面项目禁止源码外发、没有独立 OCR 模型时，验证 `/review` 会使用本地 Delegation，并明确它不是独立复核。
- 挑战用例 CH-19：远程 OCR 已配置但未获得源码传输授权，且已有先入为主的漏洞猜测时，验证隐私门禁、盲评隔离和 MyP-M-A 证据闭环。
- 两条用例只验证工作流合同；没有真实运行远程 OCR，也不把静态校验视为模型行为得分。

## Discovery 定向覆盖

- 稳定用例 ID 83：多角色访谈归纳，验证来源绑定、反例、样本偏差、事实/解释/机会/方案分层，以及回到 `/idea` 的证据闸门。
- 挑战用例 CH-20：偏置招募、漂亮原型和子 Agent 模拟混合场景，验证机会树层级与“模拟不能补足真实用户证据”的边界。
- 两条用例不要求每次 `/idea` 加载 Discovery；只有访谈、研究、JTBD、切换行为或机会树信号出现时才加载。

## Strategy/GTM 定向覆盖

- 稳定用例 ID 84：小规模内测被要求外推到所有研发团队并照搬竞品席位价格时，验证 ICP、角色、替代方案、选择/排除项和定价证据边界。
- 挑战用例 CH-21：偏置原型样本、竞品价格与多框架堆砌混合时，验证 `/prd` 会停在方案收敛版，不虚构企业需求、支付意愿、渠道能力或市场数字。
- 两条用例不要求普通产品任务加载 Strategy/GTM；只有市场、细分、定位、定价、商业模式、GTM、渠道或增长信号出现时才加载。

完成复核后，应先将长期结论回写 `notes/evaluation-history.md`，再删除仓库外的回答、评分、快照和 viewer。生成型工作区不作为长期档案。
