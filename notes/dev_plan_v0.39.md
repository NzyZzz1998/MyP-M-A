# MyP-M-A v0.39 开发计划

## 追踪信息

- 当前状态：实现完成、独立验收未通过，Candidate 晋升已终止
- 目标版本：`0.39.0`
- 上游来源：`notes/v0.39-reliable-delivery-prd.md`
- 下游承接：`notes/progress_v0.39.md`、独立 `/acceptance`
- 当前事实源：v0.39 PRD、v0.38 Stable 工作树与 `E:/codex/skill-evals/mypm-v039-baseline-20260818/baseline-manifest.json`
- 最后更新：2026-08-18

## 1. 开发范围

- 本次包含：FR-001～FR-011；五类承重事实不变量、入口局部合同、终检、评测治理、真实首次使用和一张 Lieflat Charts 可选 pilot 能力卡。
- 本次不包含：新入口、PM 框架、批量能力卡、Marketplace、连接器扩张、公开案例、图表默认装配或商业化。
- 范围保护：五入口默认加载集合不得增加；Lieflat 不复制、不默认安装、不成为硬依赖；事实终检与图表 pilot 可独立回退。

## 2. PRD 对照

| PRD 需求 | 开发模块 | 覆盖 |
| --- | --- | --- |
| FR-001～FR-004 | M1 事实锚点与入口语义 | 是 |
| FR-005～FR-006 | M2 验收继承与共享终检 | 是 |
| FR-007～FR-008 | M3/M4 评测治理与行为回归 | 是 |
| FR-009 | M6 真实首次使用观察 | 是 |
| FR-010 | M0/M7 身份、状态与回退 | 是 |
| FR-011 | M5 图表能力卡与浏览器试点 | 是 |

## 3. 文件与模块影响

| 模块 | 主要文件 | 改动 |
| --- | --- | --- |
| 核心路由 | `SKILL.md` | 以替换而非叠加方式加入轻量终检入口 |
| 五入口合同 | `references/idea.md`、`review.md`、`prd.md`、`acceptance.md`、`prompt.md` | 补统计对象、UI 值、推断、证据继承和交接事实保护 |
| 模板 | `templates/prd-template.md` | 增加 UI 状态和值语义检查位 |
| 图表适配 | `references/chart-delivery.md`、`capabilities/visualization/decision-chart-adapter.md`、registry/routing/tooling | 可选 pilot、许可、数据、浏览器和降级合同 |
| 评测 | `evals/evals.json`、`challenge-evals.json`、`contract-registry.json`、`release-panel.json`、`eval-lifecycle.json`、fixture | stable 97～102、CH-29～CH-34 与唯一所有权 |
| 校验 | `scripts/test-v039-reliable-delivery.ps1`、`scripts/validate-skill.ps1` | 正反例、自测和上下文门禁 |
| 状态 | README、CHANGELOG、roadmap、backlog、progress、dev log | Candidate/Stable 事实同步 |

## 4. 实施顺序

1. M0 固化 v0.38 差量快照并锁定范围。
2. M1/M2 先写失败 fixture，再以局部替换实现事实合同。
3. M3 注册 eval、合同和 self-test，关闭静态门禁。
4. M4 运行敏感题和控制题，未通过时只修对应入口。
5. M5 独立实现 Lieflat pilot，并做许可、保真、双视口与降级验收。
6. M6 执行 12 题候选面板和真实首次使用观察。
7. M7 独立验收并同步状态，不自动提交或发布。

## 5. 任务拆解

### M0 基线冻结

- `V039-M0-001` 保存 tracked patch、未跟踪文件和 SHA-256 manifest。
- `V039-M0-002` 排除 v0.39 规划文件并验证快照可读。
- `V039-M0-003` 回写 PRD 授权、dev plan、progress 与 dev log。

### M1 事实锚点与入口合同

- `V039-M1-001` 增加跨对象统计口径与分母不漂移合同。
- `V039-M1-002` 增加数字、单位、比较符和数量级终检。
- `V039-M1-003` 增加 Review 事实/推断/待验证关系标签。
- `V039-M1-004` 增加 PRD UI 当前值、保存值、默认值和无变化语义。

### M2 验收继承与共享终检

- `V039-M2-001` 增加 Acceptance 同对象证据继承和选择性失效合同。
- `V039-M2-002` 增加 Prompt 交接事实与状态原样继承检查。
- `V039-M2-003` 以替换方式收敛 SKILL 终检，保持 `<=5700` 字符和默认加载不增长。

### M3 评测与静态治理

- `V039-M3-001` 新增 stable 97～102、CH-29～CH-34 和合成 fixture。
- `V039-M3-002` 注册唯一合同、生命周期与发布面板影响。
- `V039-M3-003` 新增 v0.39 self-test 正反例并接入 Strict。
- `V039-M3-004` 通过 JSON、PowerShell、UTF-8、链接、敏感信息和差异检查。

### M4 定向行为回归

- `V039-M4-001` EB-01/07/09/10/11 各 3 次，共 15 个有效样本且关键事实违规为 0。
- `V039-M4-002` EB-03/05/12 控制题无新关键错误。
- `V039-M4-003` 分维记录正确性、证据、完整性、可执行性、精炼度、字符和有效率。

### M5 Lieflat Charts pilot

- `V039-M5-001` 锁定官方来源 commit、许可证和第三方资源清单。
- `V039-M5-002` 新增一张 pilot 能力卡、按需路由和不可用降级。
- `V039-M5-003` 从冻结 benchmark 生成可追溯 HTML 与 manifest。
- `V039-M5-004` 验证数值/单位/聚合、1440x900、390x844、控制台、CDN/离线和负例。

### M6 候选面板与首次使用

- `V039-M6-001` 定向通过后运行一次 12 题候选面板。
- `V039-M6-002` 检查正确性、证据、完整性、决策清晰度、可执行性和有效返回率门禁；精炼度、字符数和时长只作观察。
- `V039-M6-003` 由维护者真实完成发现入口、完整阶段、续接和下一提示词路径并记录卡点。

### M7 独立验收

- `V039-M7-001` 锁定候选身份、完整 diff、证据路径和未跟踪文件。
- `V039-M7-002` 复跑 Strict、context budget、v0.39 self-test 和全部机械检查。
- `V039-M7-003` 核对 M0～M6、风险、外部写授权和回退可用性。
- `V039-M7-004` 形成 Stable 或未通过结论并同步状态文档。

## 6. 测试与验收

- 自动化：Strict、context budget、v0.39 self-test、评测管线、JSON/PowerShell 解析。
- 行为：15 个敏感样本、3 个控制任务、一次 12 题候选面板；结果分维报告。
- 浏览器：图表 HTML 桌面和窄屏、资源、交互、控制台、数据逐值复核。
- 人工：真实首次使用路径；只记录本次观察，不外推成功率。
- 回归：v0.36～v0.38 self-test、默认加载集合、五入口触发与中文输出。

## 7. 开发日志约定

- 使用 `notes/dev_log_v0.39.md` 记录实现、失败、修复、证据和回退。
- progress 只保留 checklist、状态、阻塞、最新验证和下一步。
- 行为与图表证据保存在仓库外 `E:/codex/skill-evals/`，仓库只保存可追溯摘要。

## 8. 风险与回退

| 风险 | 影响 | 回退 |
| --- | --- | --- |
| v0.38 未提交 | 无 Git commit 回退 | 使用基线 manifest、binary patch 与未跟踪快照 |
| 终检造成重复 | 可读性与维护成本回退 | 删除重复框架，不删除承重事实；字符增长本身不触发回退 |
| 规则跨入口误伤 | 控制题回退 | 只撤回最近入口合同 |
| Lieflat 许可或保真失败 | 图表不可发布 | 整体撤回 M5，不影响 M1～M4 |
| 行为工具不可用 | 无法满足 Stable | 保持 Candidate，不能用静态测试冒充 |

## 9. 开放问题

- 无范围或顺序开放问题。提交、推送、tag 和 Release 仍分别等待用户授权。
