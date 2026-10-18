# 外部路由三批增量

## 执行基线

- 阶段：实施；delivery_mode=vibe_coding，仅适用于 MyP-M-A 自身，不改变业务项目模式。
- 事实源：已确认的[路由评审](external-skill-routing-review-20261017.md)及用户三批实施授权；本记录合并增量需求、dev plan、progress 与 dev log，不重写版本 PRD。
- 分支 test，HEAD `deecc50b8865c26c73a2dff0ceaae8f66174c64f`，原有未提交维护全部保留；版本仍为 0.42.0。
- 不安装或全局升级 Skill/CLI，不配置凭据，不使用外部模型或子 Agent，不改业务项目；不全量回归、不提交、不推送、不发布。
- 仅新增三项专项能力的受控选择，不引入 Matt 总控、独立任务系统、prototype 或 writing-for-agents。

## 需求与任务

| ID | 批次 / 合同 | 交付与通过标准 | 状态 |
| --- | --- | --- | --- |
| ROUTE-A | 路由治理 | provider 身份、默认/显式选择、权限闭包、去重/防环、缺依赖降级；状态不互相推导 | 已完成本地实现与定向验证 |
| ROUTE-B | 两个既有 pilot | 来源哈希探测、宿主/文件适配身份、已有术语映射、问卷已知输入复用；不改全局显式策略 | 已完成文件适配及小样本；宿主原生调用未验证 |
| ROUTE-C | Matt + OCR | 同快照覆盖 commit/index/worktree/untracked；两轴原报告、独立性/预算、覆盖与新鲜度检查 | 适配完成；后续授权安装后真实 OCR 双方法补验通过，独立双审未测 |
| ROUTE-V | 定向验证 | 规则正反例、缺依赖、真实临时 Git 仓库测试与当前 Agent 小样本；分开记录证据层级 | 本地验证及 OCR 补验通过；隔离执行和 PS5.1 保留缺口 |

## 文件与回退

- 按需运行时：capability-routing/tooling/code-review-scanner，新增 external-provider-routing、matt-pilot-adapters、matt-code-review-adapter；不改 SKILL.md / description。
- 机器清单与本地助手：capabilities/provider-registry.json、scripts/provider_routing.py、scripts/review_snapshot.py。
- 定向验证：独立 supplemental 用例、Python 单测、PowerShell 结构守卫；不改稳定集/挑战集题面和历史分数。
- 文档：本记录、README、evals README、维护计划与评测历史，仅同步本次增量。
- 每批回退仅撤销本批 patch。A/B/C 分开可停；OCR 缺失不阻塞其他能力，不能用模拟 CLI 宣称真实 OCR 接通。不恢复整个文件到 HEAD，以免抹掉此前 Memory 改动。

## 实施记录

- 开始：已核对现有路由、两个本地 pilot、版本与未提交范围。沿用昨天固定的上游版本，不跟随主分支漂移。
- 验证层级：结构守卫不是模型评测；Python 真实 Git 夹具不是业务项目评审；当前上下文样本不是盲测或隔离双审。
- A/B：新增四项 provider 清单与只读 preflight；两个 pilot 的主文件及领域格式附件锁定哈希。保持显式选择，宿主无原生接口时以 file-adapter/current-agent 执行。
- C：Matt 两轴本地方法适配保留原报告；快照冻结四层、排除、字节/权限身份、diff 哈希、覆盖与失效。OCR 助手只取 delegate 规则，不调用模型、不自动安装。
- 测试首轮：路由测试曾因使用不匹配的 unittest 模块路径未启动，改为仓库既有的直接脚本方式。快照首轮 24 项中发现 diff 未纳入校验、权限位未入身份两处缺口；已修复，原失败保留在本记录，不伪称首轮全过。
- 增补检查：双审复用仅复用已完成 provider，不提前跳过另一审；JSON 凭据模式、Git core.filemode=false 及无末尾换行差量补测。

## 首轮定向结果（安装前）

| 证据层 | 实际执行 | 结论与限制 |
| --- | --- | --- |
| 策略函数 | `python -B scripts/test_provider_routing.py -v`，26/26 | 含授权、模式、去重、防环、来源漂移、依赖缺失、独立预算；不是模型得分 |
| 真实 Git + 适配夹具 | `python -B scripts/test_review_snapshot.py -v`，32/32 | 临时仓库真实读写与冻结；其中 OCR 响应显式模拟，不证明 OCR CLI 可用 |
| 结构守卫 | `test-provider-routing.ps1` | 4 个 provider、4 个反向变异、14 条场景结构通过；不称 14 条模型回归全部通过 |
| 严格静态 | PowerShell 7 `validate-skill.ps1 -Strict` | 通过，warnings=0；输出中的面板/评分数据是自测夹具，不是新全量模型运行 |
| 上下文 | `measure-context-budget.ps1`、`test-context-budget.ps1` | 统计成功，7 个工具用例通过；SKILL 本轮未改，仍 5700/5700；条件路由文本增加，不宣称五入口全零增长或全部缩减目标达成 |
| 格式与解析 | git diff --check、UTF-8、JSON、PowerShell、Python AST、现有 Markdown 链接检查 | 通过；Python 4 个新增文件实际解析，PS 使用当前 PowerShell 7 |
| 本地文件适配 | 当前 Agent 读取两项 pilot 后生成领域差量与 8 题问卷 | 产物实际落盘并回读；已知信息不重问，不双写词汇，不发消息，不批准答案。非盲测、非独立样本 |
| Matt 审查 | 当前 Agent 读取冻结的 unstaged/untracked 两项、规范与规格，保留 Standards/Spec 原报告 | 实际复现合成权限回退；覆盖 2 项、新鲜度通过。无规格变体仅跳过 Spec，同上下文观察不计独立样本 |
| OCR 真实链路 | 实际 helper 调用前置返回 ocr_cli_missing / not_attempted | 待补证；未安装、不发 API，没有 OCR 原报告，不能称双审通过 |
| Windows PowerShell 5.1 | 尝试运行定向守卫，被本机执行策略阻止 | 未执行通过；没有绕过或修改系统策略 |

## 证据定位与身份

本机证据目录：`E:/codex/skill-evals/mypm-routing-20261018`。公开仓库只保留合成场景定义与结果索引，不包含私人项目资料或凭据。

- `candidate-identity.json`：14 个本轮运行时/脚本/清单文件的 SHA-256，范围仅本增量，不是整个 dirty 工作区快照。文件 SHA-256 `7cbd80682956210b6c291d23d79f0da264acc9ec0e5c4480bc10659aa61e38a5`。
- `provider-tests.txt`：`b9227af959c855d11c389d17c297898ca071f9babe9d1812759e139068ac1483`。
- `snapshot-tests.txt`：`a3100098ead50af75c20176e8813129f2136de08812e46f5c1d4fca6e4cc342c`。
- `inputs/` 是两项 pilot 的合成材料；`outputs/domain-review.md`、`outputs/questionnaire.md` 是真实文件适配产物。
- `review-fixture/` 是专用合成 Git 仓库，只有为测试建立的基线提交，非 MyP-M-A 或业务仓库提交。冻结身份见 `frozen/manifest.json`；`outputs/matt-review.md` 和 `matt-coverage.json` 为实际审查/覆盖产物。故意构造缺陷且当前会话知道预期，不据此推断真实代码发现率。
- 合成审查 snapshot SHA-256 `9a5089308d985ccd1d1e3ff5dd4cdc5a9176bc1cec9d3e14916ccb13c472785f`；它是内容清单身份，不是 manifest 文件字节哈希。

## 收口与剩余风险

后续真实未提交代码双审发现 5 项可复现问题，随后已最小修复并补定向反例，当前收口进度见[维护迭代收口](iteration-completion-20261018.md)；另经用户确认增加默认关闭的固定 Skill 缺项补装，详见[本轮代码审查与补装](real-code-dual-review-20261018.md)。原安装前、合成夹具与修复前结论保留，不回写为首次无缺陷，也不以其代替整个迭代验收。

首轮本地三批实现完成，A/B 限定接入及 C 的快照/适配工具通过定向验证；当时整体接入结论为部分通过、真实 OCR 待验证。该历史结论不回写为首次成功。

随后用户单独授权本地安装，已完成真实 OCR v1.13.1 delegate 与当前宿主的同快照双方法补验，详见 [OCR 安装与补验](ocr-live-verification-20261018.md)。不晋升版本，不宣称全量或独立双审通过。首轮不安装限制仅属于原批次，后续安装有单独授权。

1. OCR 真链路已在后续授权内完成；仅对 Python 合成夹具的 workspace dirty 双方法小样本有效。其他机器、版本和真实业务项目须重新探测，不默认安装或申请外部 API。
2. 隔离双审需明确两个 reviewer 总预算及宿主隔离证据；当前为 0，未派 Agent。宿主原生 pilot 调用也未测，文件适配不冒充原生。
3. 前置脚本只检查结构/策略，不强制执行 Agent 的语义行为；当前小样本有上下文污染，长期路由准确率仍未知。不上调历史评分。
4. 快照是本地副本，双读检测不等于原子锁；敏感信息筛查是启发式。保留审前/审后校验，不外发或把测试副本加入公开仓库。
5. 未提交、未推送、不改业务项目，不运行全量稳定/挑战模型回归；之前的 Memory/日志改动和已有笔记全部保留。
