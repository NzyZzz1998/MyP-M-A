# MyP-M-A 评测说明

MyP-M-A 使用两套互补评测，不混合计算总分。
<!-- contract:separate-eval-scores -->
<!-- contract:eval-execution-isolation -->
<!-- contract:eval-release-panel-lifecycle -->

版本结果、证据边界和清理记录统一保存在 `notes/evaluation-history.md`。本目录只保留可重复执行的用例、附件和操作说明。

## 稳定集

`evals.json` 用于发现明显行为回退。它覆盖四个产品阶段、`/prompt`、Memory 和常见附件场景。稳定集通过不等于新版整体更好，只表示核心合同没有明显退化。

## 挑战集

`challenge-evals.json` 用于区分细节质量。题目刻意包含统计口径歧义、证据冲突、异步状态、租户权限、产物身份和高风险发布条件。挑战集可以暴露“格式正确但判断错误”的输出。

挑战集规则：

1. 新旧版本必须使用同一模型、同一附件和同一评分器。
2. 默认先用 `coverage` 档位和较低成本推理强度各运行一次；只有受影响、失败或评分不稳定的用例才进入 `targeted-max`，并按需补到三次。
3. 评分器必须逐条引用输出证据，不能只给总分。
4. 模型超时等待五分钟；仍未落盘时终止该次运行。执行器失败单独计入 SLA 完成率，不得记为能力失败。
5. 稳定集与挑战集分别汇报；能力比较只使用双方都有效返回的共同样本，同时保留各自完成率和输出长度。
6. max 盲评默认每批 3 条。每条仍独立评分、保留原检查项和中文证据，批量只减少重复冷启动。
7. 执行模型只能读取 `task.json`、对应 Skill 快照和题目点名的附件，并从空临时目录运行；不得扫描共享工作区、其他项目、Memory、历史回答或评分材料。输出出现题目未提供的项目名、路径或状态时，标记为“上下文污染”并排除，不计能力得分。

## 发布面板与执行生命周期

`release-panel-core.json` 固定 9 条长期核心；`release-panel.json` 保存当前候选的核心、合同差量和相邻控制快照。动态面板默认最多 26 条，超过上限时升级为受影响入口全量回归，不静默截断 critical 合同。两者都不复制题目或评分点，也不替代稳定集和挑战集全量回归。

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

行为文件没有合同映射时生成失败；确属无行为变化时，使用独立 JSON 记录 `source_file` 或 `contract_id` 与非空 `reason`，再通过 `-NoBehaviorChangeFile` 提供。`contract-registry.json` 是合同来源、入口、风险与评测映射的结构化事实源。

运行时默认最大并发 3；每个子 Agent 最多处理 5 条相互独立的用例，完成一批立即关闭。单批等待上限 5 分钟；超时只重试缺失项，不重跑已落盘回答。执行完成率、共同有效样本得分和输出长度分开报告。入口、常驻合同或证据门禁变化时仍应跑稳定集与挑战集全量 A/B；面板只承担快速反馈。

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
4. 完成时长：可选读取每个运行目录的 `execution.json`；格式为 `{ "duration_ms": 1234 }`。缺失时写 `unavailable`，不能填 0。
5. 有效返回率：回答和逐项评分都通过结构校验才算有效；缺失单独报告，不伪装成能力失败。

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

生成的 `quality-report.json` 不包含综合质量总分。字符增加超过 15% 或可比较的中位时长增加超过 25%，且清晰度、可执行性均无候选收益时，该批次不通过。配对盲评不稳定时只把三个体验维度降级为观察项，正确性门禁保持不变。

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
