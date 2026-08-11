# progress_v0.34

## 追踪信息

- 当前状态：M0～M5 与独立 `/acceptance` 已通过；用户已批准晋升本地 Stable 并进入提交收口
- 目标版本：`v0.34.0 Stable`
- 上游来源：`notes/v0.34-governance-prd.md`、`notes/dev_plan_v0.34.md`
- 下游承接：远端推送、annotated tag 与 Release（分别等待用户授权）
- 当前事实源：本文记录实时状态；PRD 定义需求合同；dev plan 定义任务与验证
- 对应开发日志：`notes/dev_log_v0.34.md`
- 上一远端稳定版：`v0.33.0 Stable`
- 最后更新：2026-08-11

## 版本目标

在保持五入口承重合同、中文输出、证据与授权边界不回退的前提下，完成入口级上下文预算、动态评测面板、触发新鲜度、validator 模块化和文档事实源治理。

## 状态总览

- 开发承接：3/3，已完成。
- 实施任务：34/34，M0～M5 已完成。
- 发布状态：`v0.34.0` 已晋升本地 Stable 并进入提交收口；远端仍为 `v0.33.0`。
- 当前门禁：M5 与独立 `/acceptance` 均通过。
- 当前阻塞：无。

| 里程碑 | 模块 | 依赖 | 状态 | 完成度 |
|---|---|---|---|---:|
| PRE | PRD 确认与开发承接 | 完整 PRD | 通过 | 3/3 |
| M0 | 基线与直接治理项 | PRE | 通过 | 7/7 |
| M1 | 评测与校验基础 | M0 通过 | 通过 | 7/7 |
| M2 | `/prompt`、`/review` 试点 | M1 通过 | 通过 | 5/5 |
| M3 | 三个重入口扩展 | M2 通过 | 通过 | 5/5 |
| M4 | 交付质量配对评测 | M2 结果可用 | 通过 | 5/5 |
| M5 | 文档与发布收口准备 | M3/M4 通过或缩小范围 | 通过 | 5/5 |
| ACC | 独立 Candidate 验收 | M5 通过 | 通过 | 1/1 |
| REL | 本地 Stable 晋升与提交 | ACC 通过、用户授权 | 通过 | 1/1 |

## 模块任务

### PRE：开发承接

- [x] V034-PRE-001 用户确认 `notes/v0.34-governance-prd.md`，获得开发承接授权。
- [x] V034-PRE-002 生成 `notes/dev_plan_v0.34.md`，锁定 M0～M5 顺序、范围、验证和回退。
- [x] V034-PRE-003 生成本状态看板和 `notes/dev_log_v0.34.md`，分离状态与过程记录。

### M0：锁定基线与直接治理项

- [x] V034-M0-001 记录分支、HEAD、dirty 状态、稳定基线和允许修改范围。
- [x] V034-M0-002 创建 `evals/context-budget.json`，定义五入口装配清单与预算。
- [x] V034-M0-003 创建 `scripts/measure-context-budget.ps1` 及六类隔离自测。
- [x] V034-M0-004 用同一规范化方法冻结 v0.33 五入口实测基线。
- [x] V034-M0-005 用 Sol medium、Terra medium 补齐当前 description 的 34/34 触发基线。
- [x] V034-M0-006 修正 roadmap 与 backlog 的过期版本、eval 数量和阶段口径。
- [x] V034-M0-GATE 通过预算复算、触发新鲜度、文档扫描、严格校验和 `git diff --check`。

### M1：建立评测与校验基础

- [x] V034-M1-001 创建 `evals/contract-registry.json` 并映射现有 critical 合同。
- [x] V034-M1-002 创建 9 条固定核心 `evals/release-panel-core.json`。
- [x] V034-M1-003 改造动态面板 builder，支持差量、控制、无映射失败和 26 条升级规则。
- [x] V034-M1-004 回放 v0.33 变化，证明 eval 36、61 由合同映射进入面板。
- [x] V034-M1-005 将 validator 拆为 common/docs/evals/contracts 模块并保持命令兼容。
- [x] V034-M1-006 增加正常与七类负向夹具，保持 evaluation pipeline self-test 通过。
- [x] V034-M1-GATE 通过回放、双轨 validator、全部夹具、严格校验和 pipeline self-test。

### M2：`/prompt`、`/review` 试点与 Deep Review 装配

- [x] V034-M2-001 冻结试点文件、预算、合同、用例、控制组和回退点。
- [x] V034-M2-002 治理 `/prompt` 的三份 reference 装配，保持 L1 与授权合同。
- [x] V034-M2-003 治理 `/review` 与 Deep Review，支持按领域选择 3～6 个维度。
- [x] V034-M2-004 用 Sol medium、Terra medium 执行动态面板和相邻控制回归。
- [x] V034-M2-GATE 两入口分别达到至少 10% 正式负载下降且 critical/控制 0 回退。

### M3：扩展 `/idea`、`/prd`、`/acceptance`

- [x] V034-M3-001 单独治理 `/idea`，验证数据、假设、阈值和需求池合同。
- [x] V034-M3-002 单独治理 `/prd`，验证 UI、异步后端/数据库和方案收敛合同。
- [x] V034-M3-003 单独治理 `/acceptance`，验证身份、继承、失败注入和发布面合同。
- [x] V034-M3-004 汇总五入口预算，核对四个重入口平均下降与单入口上限。
- [x] V034-M3-GATE 每个入口独立通过，四个重入口正式负载最终平均下降 `33.11%`。

### M4：交付质量配对评测

- [x] V034-M4-001 创建七维 `evals/delivery-quality-rubric.json`，不设综合质量总分。
- [x] V034-M4-002 冻结覆盖五入口、Sol/Terra medium 和 5 个复杂场景的 10 个历史配对样本。
- [x] V034-M4-003 执行隐藏版本映射的逐样本盲评，记录胜/平与样本内证据。
- [x] V034-M4-004 更新评测工作区和 viewer，分开展示七维、时长与有效性。
- [x] V034-M4-GATE 通过 AC-007、成本边界、品牌检查和两套 pipeline self-test。

### M5：文档与发布收口准备

- [x] V034-M5-001 为拟移动历史 notes 生成 `notes/v0.34-note-migration-audit.md`。
- [x] V034-M5-002 更新 6 处入站引用后，将 6 份历史资料和 4 份真实案例分别迁入 `notes/archive/`、`notes/cases/`。
- [x] V034-M5-003 同步 README、roadmap、CHANGELOG、evaluation history 和 backlog。
- [x] V034-M5-004 汇总 AC-001～AC-010，执行最终 Candidate 门禁。
- [x] V034-M5-GATE 状态达到可进入 `/acceptance`；不自动提交、推送、tag 或 Release。

### ACC：独立 Candidate 验收

- [x] V034-ACC-001 Terra medium 第一轮发现证据哈希与 lineage 问题，保留 PARTIAL 记录。
- [x] V034-ACC-002 修正证据方法与 M3 运行快照 lineage，严格校验通过。
- [x] V034-ACC-GATE Sol medium、Terra medium 第二轮均为 PASS；不自动升级 Stable 或授权远端写操作。

### REL：本地 Stable 晋升与提交

- [x] V034-REL-001 用户授权将 `v0.34.0` 晋升为本地 Stable，并同步版本事实源、完成本地提交收口。

## 当前阻塞

- 无实施输入阻塞。
- M0～M5 与独立 `/acceptance` 已完成；只等待用户版本与 Git 操作决策。
- 外部 Agent、Memory 或 Computer Use 不可用不阻塞核心治理；按 AC-010 降级为待验证。

## 最近验证

- 验证时间：2026-08-11
- 验证对象：五入口上下文治理、M3 三入口动态面板、相邻控制、M4 七维交付质量和评测管线兼容性
- 验证方式：上下文预算复算；Sol medium、Terra medium 隔离执行；Terra medium 匿名布尔评分与配对质量盲评；波动项定向复验；严格静态校验、预算 self-test、两套 evaluation pipeline self-test 与链接扫描
- 结果：四个重入口正式负载最终平均下降 `33.11%`；`/idea` Sol `102/106 -> 103/106`、Terra `92/106 -> 99/106`；`/prd` Sol `114/120 -> 120/120`，Terra 的状态合同缺口修复后 eval 32 双模型候选均为 `9/9`；`/acceptance` Terra 最终 `86/89 -> 86/89`，主验收用例 `6/8 -> 8/8`，Sol/Terra 控制复验分别 `16/16 = 16/16`、`13/16 -> 16/16`。M4 正确性 `73/81 -> 81/81`，清晰度候选 `8:2`、可执行性候选 `6:4`、重复度基线 `7:3`；字符 `+59.6%`，时长 `unavailable`，有效返回均为 `100%`，成本边界通过。
- 遗留问题：M4 表明候选输出更完整但也明显更长、更重复；该问题进入后续观察，不在 M5 为追求短文本重新改写承重合同。官方 `quick_validate.py` 因本机 Python 缺少 `PyYAML` 未能启动，不属于本轮门禁。
- 证据状态：新测
- 失效条件：PRD 范围、验收标准、任务依赖或目标版本发生变化

## 下一步

- 本地 Stable 与提交收口已获授权。
- 推送、annotated tag 和 Release 分别等待用户授权。
- 远端稳定基线仍为 `v0.33.0`，不得在未授权时改写远端状态。

## 记录边界

本文只记录状态、最小任务、阻塞、验证结果和下一步。详细实现、命令输出、决策和异常进入 `notes/dev_log_v0.34.md`；缺陷进入独立 bugfix log；技术探索进入独立 spike 文档。
