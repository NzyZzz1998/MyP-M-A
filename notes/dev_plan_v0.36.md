# dev_plan_v0.36

## 追踪信息

- 当前状态：开发承接完成，待从 M0 开始实施
- 目标版本：MyP-M-A v0.36
- 上游需求池：`notes/v0.36-idea-pool.md`
- 上游 PRD：`notes/v0.36-capability-ecosystem-prd.md`
- 状态看板：`notes/progress_v0.36.md`
- 开发日志：`notes/dev_log_v0.36.md`
- 稳定基线：`v0.35.0 Stable`，远端已同步
- 当前事实源：PRD 定义需求与门禁；本文定义实施顺序、文件和验证；progress 记录实时状态；dev log 记录执行过程

## 1. 开发范围

### 1.1 版本目标

在不新增用户入口、不改变 v0.35 默认行为、不引入外部工具硬依赖的前提下，建立原子能力注册表、三张能力卡试点、12 条外部同题对标面板和公开案例准入规范。

### 1.2 本次包含

- 能力 registry、作者规范、三张试点卡和静态校验。
- 默认装配零增长与按需装配可解释的上下文预算。
- 外部候选身份、许可、版本与宿主兼容性冻结。
- 12 条中性任务、执行协议、分维评分和 viewer/report。
- 公开案例 manifest、自动检查、内部脱敏 dry-run 和撤回测试。
- 对应评测生命周期、严格校验、状态文档和独立 Acceptance。

### 1.3 本次不包含

- 新入口、新 PM 框架、完整能力 Marketplace。
- 企业连接器、PM Coach、跨平台安装或公开网站。
- 修改 Memory 产品或强制安装外部插件。
- 复制外部 Skill 正文、模板或案例。
- 实际公开案例、tag、Release 或未经授权的远端操作。

### 1.4 范围保护

1. M2 门禁通过前不修改 `SKILL.md` 或三份既有 reference 的行为正文。
2. registry 首轮是离线治理与装配声明，不自动成为运行时硬依赖。
3. 外部项目不能以“不兼容当前宿主”计为能力失败，只能降级为结构对标。
4. 关键合同、授权、身份或证据新鲜度回退不能由字符、时长或其他维度抵消。
5. 每个批次独立通过或回退；v0.36 未完成独立 Acceptance 前，v0.35 始终是 Stable。

## 2. PRD 对照

| PRD 需求 | 开发模块 | 任务范围 | 验收对应 |
| --- | --- | --- | --- |
| FR-001～FR-003 | M1 | registry schema、能力卡合同、validator、生命周期 | AC-001～AC-003 |
| FR-004～FR-005 | M2 | 三张试点卡、按需装配、预算和行为回归 | AC-004～AC-006 |
| FR-006 | M0、M3 | 外部候选许可、版本和运行资格 | AC-008 |
| FR-007～FR-009 | M3 | 12 条任务、同题执行、盲评和分维报告 | AC-007～AC-011 |
| FR-010～FR-011 | M4 | 案例规范、manifest、脱敏、撤回 | AC-012～AC-014 |
| FR-012 | 全批次、M5 | 状态、停止、回退和 Stable 门禁 | AC-015 |

## 3. 文件与模块影响

| 批次 | 模块 / 文件 | 改动类型 | 说明 |
| --- | --- | --- | --- |
| M0 | `notes/progress_v0.36.md`、`notes/dev_log_v0.36.md` | 更新 | 锁定身份、范围、候选与状态 |
| M0 | 仓库外 `skill-evals/mypm-v036-*` | 新增 | 保存外部候选快照、回答、评分和 viewer，不纳入主仓库 |
| M1 | `capabilities/registry.json`、`capabilities/README.md` | 新增 | 能力唯一注册与作者合同 |
| M1 | `scripts/validation/validate-capabilities.ps1` | 新增 | 能力结构、引用、生命周期和敏感路径检查 |
| M1 | `scripts/test-v036-governance.ps1` | 新增 | v0.36 正负夹具入口 |
| M1 | `scripts/validate-skill.ps1` | 修改 | 编排新增校验，保持现有参数兼容 |
| M1/M2 | `evals/contract-registry.json`、`evals/eval-lifecycle.json` | 修改 | 登记能力治理与受影响用例，不改变既有唯一归属 |
| M2 | `capabilities/discovery/problem-validation.md` | 新增 | Discovery 试点卡 |
| M2 | `capabilities/analytics/product-data-analysis.md` | 新增 | 数据分析试点卡 |
| M2 | `capabilities/strategy/strategy-gtm-decision.md` | 新增 | Strategy/GTM 试点卡 |
| M2 | `evals/context-budget.json` | 修改 | 增加按需场景，默认组合保持不变 |
| M3 | `evals/external-candidates.json`、`evals/external-benchmark.json` | 新增 | 候选身份与 12 条任务事实源 |
| M3 | `evals/files/external-benchmark/` | 新增 | 中性、非私有 fixture |
| M3 | `scripts/validation/validate-external-benchmark.ps1` | 新增 | 候选、fixture、任务和结论边界校验 |
| M3 | 现有评测脚本 | 条件修改 | 只在无法复用现有管线时最小扩展，必须保持 self-test 兼容 |
| M4 | `examples/public-case-spec.md`、`examples/case-manifest.schema.json` | 新增 | 案例准入与结构合同 |
| M4 | `examples/dry-run/` | 新增 | 不公开脱敏样例和审计摘要 |
| M4 | `scripts/validation/validate-public-cases.ps1` | 新增 | 授权、敏感信息、路径、状态与引用校验 |
| M5 | `README.md`、`CHANGELOG.md`、`notes/mypm-roadmap.md`、`notes/evaluation-history.md` | 修改 | 只回写真实完成状态与证据边界 |

## 4. 实施顺序与依赖

```text
PRE 已完成
  -> M0 冻结稳定基线与外部候选边界
  -> M1 建立 registry 与 validator
  -> M2 三张能力卡试点
  -> M3 外部同题对标
  -> M4 公开案例规范 dry-run
  -> M5 最终静态门禁与 Candidate 收口
  -> 独立 /acceptance
```

- M1 依赖 M0；没有候选与范围冻结不得开始新增治理文件。
- M2 依赖 M1；每张卡可独立通过或回退。
- M3、M4 均依赖 M1，可在 M2 通过后顺序执行；默认不并行启动模型任务和案例审计，减少证据混淆。
- M5 依赖 M2～M4 均通过；若 M3 因合法候选不足降级，只能收口为部分通过，不晋升 Stable。

## 5. 任务拆解

### PRE：PRD 确认与开发承接

#### V036-PRE-001 确认 v0.36 PRD

- 目标：确认 IDEA-001～004 和 FR-001～012 进入开发承接。
- 涉及文件：`notes/v0.36-idea-pool.md`、`notes/v0.36-capability-ecosystem-prd.md`。
- 验证方式：用户明确回复继续；PRD 门禁仅剩实施与验收。
- 完成标准：范围、停止点、延后项和不做项无冲突。

#### V036-PRE-002 生成开发计划与状态看板

- 目标：建立 M0～M5 的顺序、任务、验证和独立回退点。
- 涉及文件：本文、`notes/progress_v0.36.md`。
- 验证方式：FR、AC、任务和批次交叉核对。
- 完成标准：FR-001～012、AC-001～015 均可追踪。

#### V036-PRE-003 建立开发日志

- 目标：将状态看板与实际开发过程分离。
- 涉及文件：`notes/dev_log_v0.36.md`。
- 验证方式：日志模板包含命令、结果、偏差、未验证和回退点。
- 完成标准：后续实施不把流水账写入 progress。

### M0：冻结稳定基线与外部候选边界

#### V036-M0-001 锁定仓库身份与允许变更范围

- 目标：记录分支、HEAD、origin/main、dirty 状态、v0.35 版本事实和允许文件白名单。
- 涉及文件：progress、dev log。
- 验证方式：`git status --short --branch`、`git rev-parse HEAD`、`git rev-parse origin/main`、`git diff --name-status`。
- 完成标准：本轮既有文档和后续允许路径可复核，无无关改动。

#### V036-M0-002 冻结 v0.35 运行时与评测基线

- 目标：保存 39 个运行时文件、五入口预算、85/21/34 目录和关键合同的可复算身份。
- 涉及文件：仓库外基线摘要、dev log。
- 验证方式：现有严格校验、context budget、文件 SHA256 清单。
- 完成标准：候选实施后能逐文件判断是否意外改变 v0.35。

#### V036-M0-003 审核外部代表候选

- 目标：核对仓库 URL、固定 commit、许可证、运行格式、宿主兼容性和允许用途。
- 涉及文件：候选草案、dev log；正式结果在 M3 写入 `evals/external-candidates.json`。
- 验证方式：只读获取仓库 metadata、许可证和安装说明；不复制正文。
- 完成标准：行为候选、结构候选和排除候选分开，原因可审计。

#### V036-M0-004 冻结 12 条任务边界

- 目标：将 PRD 的 EB-01～EB-12 转成中性 fixture 需求，不使用私有项目原文。
- 涉及文件：任务设计草案、dev log。
- 验证方式：逐条核对领域覆盖、硬门禁、可用材料和候选无关措辞。
- 完成标准：12 条任务无候选专属提示、无敏感信息、无重复核心决策。

#### V036-M0-GATE M0 门禁

- 必须证据：身份、运行时基线、外部候选分流、任务边界、严格校验和差异检查。
- 通过后状态：`baseline_locked`，允许进入 M1。

### M1：能力注册表与校验基础

#### V036-M1-001 建立 registry schema 与首版数据

- 目标：实现 PRD FR-001 的字段、状态、排序和唯一 ID 合同。
- 涉及文件：`capabilities/registry.json`。
- 验证方式：JSON 解析、稳定排序、必填字段和枚举检查。
- 完成标准：三项 pilot 可登记，当前不产生运行时依赖。

#### V036-M1-002 编写能力卡作者规范

- 目标：定义卡片允许内容、禁止复制、reference 单一事实源和生命周期。
- 涉及文件：`capabilities/README.md`。
- 验证方式：与 PRD FR-002/003 逐项对照。
- 完成标准：贡献者能独立判断何时新建能力、何时只修改 reference。

#### V036-M1-003 实现能力 validator

- 目标：校验 ID、状态、trigger/anti-trigger、引用、eval 映射、重复覆盖和敏感路径。
- 涉及文件：`scripts/validation/validate-capabilities.ps1`。
- 验证方式：合法 registry 通过；重复 ID、断链、非法状态、无反触发和绝对路径均失败。
- 完成标准：AC-001～003 的静态部分可自动复现。

#### V036-M1-004 接入严格校验编排

- 目标：让 `validate-skill.ps1 -Strict` 调用新模块，同时保持旧参数、摘要和退出码兼容。
- 涉及文件：`scripts/validate-skill.ps1`、必要的 validation common。
- 验证方式：新旧正常仓库结果一致；现有 `test-skill-validation.ps1` 通过。
- 完成标准：新增模块失败会阻断严格校验，既有 self-test 无回退。

#### V036-M1-005 建立 v0.36 正负夹具

- 目标：覆盖 registry、benchmark 和 case 三类治理模块的最小正常/失败样本。
- 涉及文件：`scripts/test-v036-governance.ps1`、临时夹具目录。
- 验证方式：每个失败样本非零退出并点名对象；夹具不污染仓库。
- 完成标准：正常 1 组、能力治理负例至少 5 组通过预期。

#### V036-M1-006 登记治理合同与生命周期

- 目标：为新增能力治理建立唯一合同，避免与现有 49 个合同和 6 个场景组交叉归属。
- 涉及文件：`evals/contract-registry.json`、`evals/eval-lifecycle.json`。
- 验证方式：生命周期、重复、孤儿和交叉归属校验。
- 完成标准：现有 85/21 用例归属不变，新治理用例有唯一状态。

#### V036-M1-GATE M1 门禁

- 必须证据：AC-001～003、现有 validation self-test、evaluation pipeline self-test、UTF-8/乱码和 diff 检查。
- 通过后状态：`registry_ready`，允许进入 M2。

### M2：三张能力卡试点

#### V036-M2-001 冻结试点行为基线

- 目标：为三项能力选择受影响用例、挑战用例、触发正反例和普通控制组。
- 涉及文件：评测工作区、dev log；必要时只登记 lifecycle。
- 验证方式：每张卡至少有一个正例、一个反例、一个相邻控制。
- 完成标准：基线候选、模型、强度、输入和回退点清楚。

#### V036-M2-002 创建 Discovery 试点卡

- 目标：声明问题验证的适用、反触发、输入、输出、证据与停止合同。
- 涉及文件：`capabilities/discovery/problem-validation.md`、registry。
- 验证方式：与 `references/discovery.md` 语义对照、重复正文检查。
- 完成标准：卡片不成为第二套方法正文，不重开已确认实施任务。

#### V036-M2-003 创建数据分析试点卡

- 目标：声明反馈、指标、日志和数据库分析的统计与证据合同。
- 涉及文件：`capabilities/analytics/product-data-analysis.md`、registry。
- 验证方式：统计对象、分子分母、去重、时间窗、来源和降级规则对照。
- 完成标准：无数据请求不误触发，命中时不遗漏关键口径。

#### V036-M2-004 创建 Strategy/GTM 试点卡

- 目标：声明战略决策的适用边界、互斥选项、取舍和禁止堆框架。
- 涉及文件：`capabilities/strategy/strategy-gtm-decision.md`、registry。
- 验证方式：与 `references/strategy-gtm.md` 对照普通 PRD 控制样本。
- 完成标准：普通功能需求不无条件展开市场、定价或 GTM。

#### V036-M2-005 增加按需上下文预算

- 目标：测量默认五入口与三类按需组合，不把所有卡常驻装配。
- 涉及文件：`evals/context-budget.json`、必要的预算脚本兼容调整。
- 验证方式：`measure-context-budget.ps1` 连续运行两次。
- 完成标准：默认入口相对 v0.35 差异为 0；按需增量逐文件可解释。

#### V036-M2-006 执行定向行为与控制回归

- 目标：证明能力声明没有改变五入口阶段、证据和授权合同。
- 涉及文件：仓库外评测输出、`notes/evaluation-history.md` 在 M5 回写。
- 验证方式：同一模型/强度下运行正例、反例、控制；关键差异补到三次。
- 完成标准：critical 回退为 0，控制样本不误加载，所有回答有效。

#### V036-M2-GATE M2 门禁

- 必须证据：AC-004～006、三卡静态映射、默认预算零增长、定向与控制回归、严格校验。
- 通过后状态：`pilot_passed`；失败卡独立撤回，不阻塞其他卡审计。

### M3：12 条外部同题对标

#### V036-M3-001 建立外部候选 registry

- 目标：将 M0 审核结果写入固定 commit、许可、适配和 eligibility 合同。
- 涉及文件：`evals/external-candidates.json`。
- 验证方式：候选版本漂移、缺许可、宿主不兼容夹具。
- 完成标准：行为候选和结构候选严格分开，无“无法运行即失败”。

#### V036-M3-002 建立 12 条 benchmark manifest 与 fixture

- 目标：实现 EB-01～EB-12 的输入、硬门禁和评分维度。
- 涉及文件：`evals/external-benchmark.json`、`evals/files/external-benchmark/`。
- 验证方式：数量、ID、领域、路径、哈希、中性措辞和敏感信息检查。
- 完成标准：AC-007 通过，fixture 可由所有 eligible 候选读取。

#### V036-M3-003 实现 benchmark 静态校验

- 目标：拒绝候选漂移、重复任务、缺 fixture、无硬门禁和统一总分配置。
- 涉及文件：`scripts/validation/validate-external-benchmark.ps1`、v0.36 self-test。
- 验证方式：正常配置和至少 5 个失败夹具。
- 完成标准：AC-007、AC-008 的静态部分通过。

#### V036-M3-004 准备隔离执行工作区

- 目标：复用现有 regression workspace，保存候选身份、输入哈希、模型、强度、超时和结果状态。
- 涉及文件：仓库外工作区；现有脚本仅在必要时最小修改。
- 验证方式：先用两个本地夹具执行 smoke，不调用真实外部候选。
- 完成标准：回答、错误、超时和无效状态分别落盘，不污染主仓库。

#### V036-M3-005 执行 12 条单次同题面板

- 目标：获得所有 eligible 候选的第一轮实际输出。
- 涉及文件：仓库外回答与运行摘要。
- 验证方式：相同模型、强度、输入、工具权限、5 分钟长尾和统一重试规则。
- 完成标准：至少 10 条共同有效；缺失只按协议补跑，不批量启动无界子 Agent。

#### V036-M3-006 执行匿名分维评分

- 目标：按九个维度逐任务评分，不生成单一总分。
- 涉及文件：仓库外评分、映射与审计摘要。
- 验证方式：候选映射隐藏、评分无跨样本引用、关键失败不可抵消。
- 完成标准：AC-009～011 通过；差异或不稳定项再各补到三次。

#### V036-M3-007 生成对标 viewer 与结论

- 目标：展示结构对标、行为对标、共同有效样本、成本和限制。
- 涉及文件：仓库外 `eval-viewer.html`、`summary.md/json`；M5 回写历史摘要。
- 验证方式：随机抽查任务、候选身份、评分证据和无效原因。
- 完成标准：不出现统一质量总分，不宣称跨模型或全场景领先。

#### V036-M3-GATE M3 门禁

- 必须证据：AC-007～011、候选身份、至少 10 条共同有效、评分和 viewer 完整性。
- 通过后状态：`benchmark_complete`；不足则保持部分通过，不进入 Stable。

### M4：公开案例规范与内部 dry-run

#### V036-M4-001 编写公开案例准入规范

- 目标：定义授权、匿名化、真实性、可复现性、中文质量和撤回规则。
- 涉及文件：`examples/public-case-spec.md`。
- 验证方式：与 PRD FR-010/011 逐条核对。
- 完成标准：规范能明确批准、退回和 withdrawn 三种结果。

#### V036-M4-002 建立案例 manifest schema

- 目标：定义案例身份、来源、授权、脱敏、交付、证据和状态字段。
- 涉及文件：`examples/case-manifest.schema.json`。
- 验证方式：合法样例通过；缺授权、非法状态、绝对路径和私有 URL 失败。
- 完成标准：AC-012 的结构部分可自动校验。

#### V036-M4-003 实现公开案例 validator

- 目标：检查 manifest、文件白名单、敏感模式、截图元数据、引用和状态。
- 涉及文件：`scripts/validation/validate-public-cases.ps1`、v0.36 self-test。
- 验证方式：至少 6 个负向夹具；敏感扫描结果可定位文件与类别但不回显秘密。
- 完成标准：AC-013 的自动部分通过。

#### V036-M4-004 选择并复制内部 dry-run 案例

- 目标：选择一段有授权、可脱敏且包含失败修复链的真实工作流。
- 涉及文件：`examples/dry-run/`。
- 实施要点：只复制必要摘要和已批准附件，不移动或改写原项目文档。
- 验证方式：来源授权、文件白名单、案例阶段链和第三方内容审计。
- 完成标准：案例保持真实决策价值，不含原始私有材料。

#### V036-M4-005 执行匿名化与人工审计

- 目标：清理身份、路径、凭据、私有 URL、日志值和截图元数据。
- 涉及文件：dry-run、审计报告。
- 验证方式：validator、UTF-8/乱码、人工全文和图片目视检查。
- 完成标准：自动失败为 0，人工未关闭项为 0。

#### V036-M4-006 验证撤回生命周期

- 目标：模拟 approved 案例发现问题后转为 withdrawn。
- 涉及文件：临时夹具或 dry-run 状态副本。
- 验证方式：公开索引移除、审计记录保留、引用检查通过。
- 完成标准：AC-014 通过，不实际发布案例。

#### V036-M4-GATE M4 门禁

- 必须证据：AC-012～014、自动扫描、人工审计和撤回测试。
- 通过后状态：`case_spec_validated`。

### M5：候选收口与独立验收准备

#### V036-M5-001 运行完整静态与工具门禁

- 目标：验证现有和新增治理没有破坏运行时、评测或文档。
- 验证方式：严格校验、context budget、evaluation pipeline、delivery quality、v0.36 self-test、UTF-8、乱码、链接、JSON/PowerShell、`git diff --check`。
- 完成标准：AC-015 通过，警告为 0 或有用户批准的非阻塞说明。

#### V036-M5-002 审计完整 diff 与仓库外产物

- 目标：确认主仓库只包含正式源码、配置和摘要，未混入外部仓库副本、原始回答或私有案例。
- 验证方式：`git status`、`git diff --stat/name-status`、文件白名单和大文件扫描。
- 完成标准：无无关改动、秘密、临时缓存或原始评测目录。

#### V036-M5-003 回写版本事实源

- 目标：同步 README、CHANGELOG、roadmap 和 evaluation history 的真实状态。
- 实施要点：实现完成只写 Candidate/待 Acceptance，不提前写 Stable、已提交或已同步远端。
- 验证方式：全仓版本、状态、用例数和证据边界扫描。
- 完成标准：四处状态一致，历史结论未被重写。

#### V036-M5-004 准备独立 Acceptance

- 目标：汇总候选身份、门禁、外部对标、案例 dry-run、剩余风险和手动复核项。
- 涉及文件：progress、dev log、必要的 acceptance checklist。
- 验证方式：PRD AC-001～015 逐项映射真实证据。
- 完成标准：状态仅为“开发完成，待 `/acceptance`”。

#### V036-M5-GATE M5 门禁

- 必须证据：M1～M4 独立门禁、完整静态检查、diff 审计和状态一致性。
- 通过后状态：`acceptance_ready`；不自动提交、推送、tag 或 Release。

## 6. 测试与验收

### 6.1 每批最低验证

- M0：严格校验、身份与哈希、外部候选许可/版本人工审计。
- M1：能力 validator 正负夹具、现有 validation 与 evaluation pipeline self-test。
- M2：context budget、三类正反触发、受影响和普通控制用例。
- M3：benchmark validator、隔离 smoke、共同有效样本、匿名评分和 viewer 抽查。
- M4：case validator、敏感信息负例、一个真实 dry-run、人工目视与撤回测试。
- M5：全部静态与工具门禁、完整 diff、事实源一致性和独立 Acceptance 输入。

### 6.2 行为验证策略

- 默认优先单模型、单强度、单次 12 条面板；只有差异、失败或波动任务补到三次。
- 不默认运行 85 条稳定集、21 条挑战集、多模型和多强度笛卡尔积。
- 若能力卡实际改变 `SKILL.md` 或 reference 行为正文，必须按动态发布面板扩大受影响回归。
- 外部候选与 MyP-M-A 必须共享输入和工具边界；不公平样本作废，不强行打分。

### 6.3 人工检查

- 能力卡是否复制 reference 正文或引入双事实源。
- 外部任务是否暗含 MyP-M-A 专属术语、路径或格式。
- 对标评分是否跨样本、泄露候选或将成本与质量混成总分。
- dry-run 文本与图片是否仍可反推用户、设备或私有项目。
- README、CHANGELOG、roadmap 和 evaluation history 是否夸大结果。

## 7. 开发日志约定

- 使用 `notes/dev_log_v0.36.md`。
- 每个任务或紧密关联的 2～3 个任务一条记录。
- 记录：目标、实际改动、关键决策、命令、结果、证据路径、偏差、未验证项和回退点。
- 模型执行只记录模型、强度、任务、有效数、耗时与工作区路径；不复制完整回答到日志。
- 缺陷进入独立 bugfix 章节或文件；探索性适配进入 spike，不污染 progress。

## 8. 风险与回退

| 风险 | 触发信号 | 影响 | 回退 / 处理 |
| --- | --- | --- | --- |
| registry 成为运行时硬依赖 | 缺失 registry 后五入口不可用 | v0.35 兼容回退 | 恢复离线治理；移除运行时接线 |
| 能力卡形成双事实源 | 卡片与 reference 规则冲突或大量重复 | 维护和行为漂移 | 撤回卡片正文，只保留声明与指针 |
| 默认上下文增长 | 任一默认入口相对 v0.35 增长 | 成本和路由污染 | 移除常驻装配；按需加载或回退该卡 |
| 外部候选不可公平运行 | 宿主、模型或输入不等价 | 对标结论无效 | 降级结构对标，不计能力失败 |
| 子 Agent 长尾 | 5 分钟仍无落盘 | 成本和完成率失真 | 关闭任务、记录无效；仅补跑缺失项 |
| 评分偏好或串项 | 盲评证据不支持结果 | 质量结论不可信 | 作废该评分批次，修复协议后重评 |
| 案例泄露敏感信息 | 自动或人工发现路径、凭据、身份 | 隐私和公开风险 | 立即 withdrawn，删除公开索引，保留审计 |
| 文档提前宣称 Stable | 状态与门禁不一致 | 发布事实失真 | 恢复 v0.35 Stable，v0.36 保持 Draft/Candidate |

## 9. 开放问题

- 最终进入行为对标的外部候选由 M0 的许可和宿主兼容审计决定，不在本计划中预设全部可运行。
- dry-run 案例优先从用户自有且已明确允许使用的项目中选择；如果授权无法确认，M4 停在规范与合成负向夹具，不使用真实项目。
- 是否将 registry 接入真实运行时必须以 M2 证据和用户单独确认决定；默认只作为治理与评测层。

## 10. 长期记忆建议

v0.36 将跨多个批次和评测工作区，适合在 M0 启动时创建 Memory 任务。只保存项目路径、版本、PRD/dev plan/progress/dev log 路径、当前批次、阻塞、验证命令和下一任务，不复制正文、原始回答、凭据或私有案例内容。
