# 专项提供者路由合同

只在选择 Matt pilot、代码扫描或重叠提供者时读取。主流程与正式事实源仍由 MyP-M-A 管理，不新增入口。清单是 `capabilities/provider-registry.json`；它和能力卡 registry 分开，不代表宿主安装状态。

## 选择与权限

1. 锁定问题、当前入口、delivery_mode、输入/产物及实际授权。普通 PRD、解释、交接沿用 MyP-M-A；TDD/debug 沿用项目已选提供者，不因本机有 Superpowers 或 Matt 就重复执行。
2. 有多义业务术语时可推荐领域 pilot；需从一位知情者异步取得信息时可推荐问卷 pilot。没有用户选择只给建议，保持既有显式调用限制。一次明确选择在同对象同范围内有效，不重复确认已知答案。
3. 只有明确代码评审意图才用代码层；默认本地 OCR delegate，缺失降级本地 Git/规则。用户点名 Matt 或双审才加载对应适配。禁止将 code-review 工具同名误当 Alibaba OCR。
4. 记录本次调用栈及已完成的“问题 + 对象快照 + 能力 + 提供者”。重复请求继承有效结果，递归进入同一 provider 时停止该分支。除明确双审外，一项问题只选一个同类提供者。
5. 安装、全局升级、凭据配置、外部模型传输、远端写入、commit/push/发布分别授权。预算默认 0；嵌套调用继承同一预算和权限，不能由 research、grilling 或 codebase-design 绕开。获准 Agent 完成后关闭，不自动继承上游并发或生命周期。
6. 缺输入/授权只停止受影响步骤；未授权不安装补齐，不无限重试，不把失败降级为成功。已单独授权的固定 Skill 缺项按 `references/provider-dependencies.md` 补装；不包括 CLI、凭据或全局升级。显式要求某 provider 的任务，替代结果必须标记“该 provider 未执行”，不能视为其完成。

## 六类事实分别记

| 字段 | 证明什么 |
| --- | --- |
| registered | MyP-M-A 有此提供者规则，不表示安装 |
| installed / file_present | 本轮定位到文件或可执行程序 |
| host_exposed | 宿主实际提供可调用接口；没有 Skill 工具就不虚构 |
| adapter_ready | 本地来源与必要文件通过检查，可按适配规则读取执行 |
| invocation | not_attempted / succeeded / failed，需实际动作与产物 |
| verification | verified_scope 与 pending_scope，注明结构/模拟/真实调用，版本变化则旧验证失效 |

Python 可用时，用 `scripts/provider_routing.py probe --skills-root <宿主实际技能根>` 获取身份；不提供根时仅检查本 Skill 的相邻目录与 PATH，不扫描整个机器。`plan` 从 stdin 接收请求，输出权限与选路决定；**它不会调用 Skill、运行 OCR、授权写文件或隔离 Agent**，也不是安全沙箱。没有 Python 可按相同表逐项检查，无强制安装。

文件适配仅在用户选择后读取已确认路径及必要附件，记录 `file-adapter/current-agent`；这不是宿主原生 Skill 调用。来源哈希变化时先评审差异并更新验证，不能静默当旧版通过。

复用时传 `evidence_context={question_sha256,object_sha256}`，以及 `completion_receipts=[{provider,capability,question_sha256,object_sha256}]`。问题哈希绑定当前完整问题及约束，对象哈希绑定实际输入/代码快照；两项必须是从本轮事实源计算的 SHA-256。仅四项全部匹配且 provider 身份仍就绪才复用；旧 `completed_providers` 名称列表兼容接收但不作为凭据。调用者须核对原报告真实存在、覆盖与新鲜度；preflight 只校验字段和匹配关系，不替调用者证明报告内容。双审只跳过已核实的那一审。

## 输入输出与降级

| 专项 | 必要输入 / 禁止触发 | 输出 / 降级 |
| --- | --- | --- |
| domain_modeling | 明确对象、既有术语及争议；不是读一遍词汇表就触发，不用于自动创造架构 | 带来源的术语差量、冲突与 ADR 候选；缺 pilot 时按本地 review 分析，注明未使用 Matt |
| questionnaire | 收件角色、目标决策、已知事实；不重复访谈已知答案、不代发消息 | 可填写问卷及答案归属；缺 pilot 时用 discovery 输出本地草稿，不称 Matt 产物 |
| code_review | 仓库、base、目标层、排除与最小规格；纯 PRD 不触发 | 快照、逐文件覆盖、原报告和核证；OCR 缺失保留 Git/Matt 结果但 OCR 待验证 |

领域与问卷按 `references/matt-pilot-adapters.md`；代码按 `references/code-review-scanner.md` 与 `references/matt-code-review-adapter.md`。用户明确禁止执行项目操作的 `/prompt` 只生成交接，不启动任何适配。

`plan` 请求示例：

```json
{"capability":"questionnaire","entry":"/idea","delivery_mode":"team_pm","selected_provider":"matt-to-questionnaire-pilot","explicit_selection":true,"requested_effects":[],"authorized_effects":[],"call_stack":[]}
```

双审在请求中补 `review_mode`。`dual-method` 是共享上下文两种方法；`dual-isolated` 要求明确资源授权、`agent_budget >= 2` 及 `isolated_contexts=true`。此数值是本适配的两位隔离 reviewer 执行需求，不是所有评审的硬门禁；默认串行、每次一位，均不读对方发现。实际隔离须以宿主证据复核，布尔字段本身不是证明。
