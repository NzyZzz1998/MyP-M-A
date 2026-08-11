# `/review` 入口工作流

`/review` 建立对象地图，再找有证据的候选问题；按材料选 project、page、prd、implementation 或 release readiness 主通路。

## 不可省略合同
<!-- contract:review-core-output -->
<!-- contract:review-route-and-visual -->
<!-- contract:review-slimming-evidence -->
<!-- contract:review-evidence-handoff -->
<!-- contract:review-finding-evidence-source -->
<!-- contract:review-explicit-idea-candidates -->
<!-- contract:review-default-handoff -->
<!-- contract:review-code-scanner-layer -->
<!-- contract:review-strategy-consistency -->

- 首行写 `入口判断：/review`，明确主/辅助通路、覆盖与不覆盖范围、证据来源；不能把多种通路并列而不作判断。
- 先画运转脉络，再列发现。Project Review 必须有 Mermaid/等价关系图；page 给页面结构或用户流程。
- 发现使用 `已确认 / 推断 / 待确认 / 主观判断`，并给可定位来源；未读取、未运行或过期证据不能写成实证。
- 完整 Project Review 有具体现象时单列进入 `/idea` 的候选 ID 与最小验证；没有时明确“当前未形成可证候选点”。Review 不自动升级为 PRD。
- 默认附最多 5 条接手摘要：对象与阶段、正式事实源、稳定结论、阻塞、下一步。
- 代码瘦身逐项核对调用方、动态入口/资源/反射、配置、测试、日志和平台行为；只有摩擦证据成立才给最小调整、验证和独立回退，否则标为待确认。
- 意图文档、实现和测试并存时加载 `intent-implementation-audit.md`，分开记录实现偏离、文档过期、未验证和待确认。
- implementation 有锁定 diff/commit/range 且扫描器可用时加载 `code-review-scanner.md`：MyP-M-A 定范围，扫描器只产候选，最终以可达性、保护条件、测试/复现和需求影响闭环；私有源码外发先授权，Delegation 不冒充独立模型。
- 定位、市场、定价、套餐或渠道承诺与产品现状并存时加载 `strategy-gtm.md`，核对选择、证据和实际能力；宣传不能替代采用、支付或留存证据。

## 选择通路

| 线索 | 主通路 | 核心判断 | 常见去向 |
| --- | --- | --- | --- |
| 仓库、README、配置、日志 | project | 定位、阶段、核心路径、模块/数据/状态、体验与维护债 | `/idea`、治理、`/acceptance` |
| 截图、页面、原型、交互 | page | 信息层级、流程、控件、状态、可用性和视觉密度 | `/idea`、`/prd` |
| PRD、故事、验收、路线图 | prd | 目标、范围、影响、表达物、数据和可验收性 | 修 PRD、补问题 |
| 代码、diff、测试、复现 | implementation | 意图符合、边界、异常、测试、日志和维护性 | bugfix、技术债、补证 |
| tag、包、checksum、状态文档 | release readiness | 版本事实、门禁、文档、剩余验收和回滚 | `/acceptance`、文档治理 |

多条命中时选择最接近当前决策的一条。项目/Skill 架构或瘦身用 project 主、implementation 辅；只审代码时反转，纯发布事实才走 release readiness。

## 执行

1. **锁定对象**：项目/页面/版本、阶段、范围、正式路径和可信证据。列出实际使用的文件、日志、截图、工具与关键命令，明确已执行/未执行；未执行时说明原因并降级。
2. **建立地图**：按对象选择必要关系，不为完整铺满。
   - 产品：用户、目标、场景、成功标准、产品线/版本边界。
   - 工程：入口、模块、所有权、数据/配置/状态、依赖、日志、发布/恢复。
   - 领域：对象、角色、动作、状态、不变量、术语冲突和待确认 ADR。
   关系标注事实、推断或待确认；产品与工程可合图时只画一张，不虚构接口、字段或已实现行为。
3. **按需加深**：用户明确要求深入时加载 `deep-review.md`，按对象选择 3～6 个根因维度；不填充无关领域。
4. **形成主发现表**，每个发现只完整表达一次：

| ID | 现象 | 严重度 | 证据状态与来源 | 影响 | 最小验证/调整 | 去向 |
| --- | --- | --- | --- | --- | --- | --- |

严重度使用 Blocker、Major、Minor、Suggestion；价值和排期交给 `/idea` 或 `/prd`。

5. **分流**：事实性文档/CI/状态可直接治理；价值或时机未知进 `/idea`；已有决策和范围证据进 `/prd`；真实实现/产物进 `/acceptance`；明确缺陷进 bugfix/dev log；不合时机则暂不做。候选超过 2 个时建议建立需求池。

## 通路补充

- **Project**：多租户核对租户上下文、资源归属与跨租户拒绝；queue/worker 核对状态、积压、重试/死信、关联 ID、失败日志与指标，缺证写待确认。
- **Page**：覆盖入口到出口、保存/取消/关闭/返回、正常/禁用/加载/空/错误、窄屏和产品气质。
- **PRD**：覆盖证据、范围/非目标、影响、原型或等价表达物、数据、异常、验收、指标/日志和开放问题。
- **Implementation**：覆盖意图、主链路、异常/回滚/兼容、配置/数据、测试/人工验收、日志、重复编排与隐式依赖；静态无调用不能证明不存在。
- **Release Readiness**：核对分支/远端/tag、产物/manifest/checksum、README/current/status、release notes、verification/progress/checklist、限制和回滚；需运行证据转 `/acceptance`。

## 输出

落盘读 `templates/review-report-template.md`。聊天 Project Review 保留判断/证据、关系图、发现表、最多 3 条保留项、`/idea` 候选和 5 条接手摘要；其余并表。窄 Review 通常 600～1200 字，聊天 Review 1800～3500 字，报告再扩展。
