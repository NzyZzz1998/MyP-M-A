# 外部能力路由

本文件用于四个产品阶段入口及 `/prompt` 的按需能力选择，不要求每次调用外部能力；只有当前判断需要专门方法、且运行环境确认该能力可用时才加载。
<!-- contract:capability-minimal-route -->
<!-- contract:capability-evidence-package -->
<!-- contract:capability-acceptance-tracks -->
<!-- contract:capability-code-review-scanner -->
<!-- contract:capability-discovery-pack -->
<!-- contract:capability-strategy-gtm-pack -->
<!-- contract:capability-runtime-probe -->
<!-- contract:capability-enterprise-adapter-route -->
<!-- contract:capability-decision-chart-route -->
<!-- contract:visual-delivery-route -->

## 路由原则

1. 先写清要回答的产品问题，再选能力。
2. 先探测当前会话暴露的真实接口，再做针对本轮对象的最小调用；区分已安装、可调用和调用成功，不以文档名称或历史成功代替本轮证据。
3. 一项能力只承担一个明确任务，产出必须回到当前入口的结论或文档。
4. 不为了“更专业”并行调用多个重叠能力。默认子 Agent 预算为 0；只有工作彼此独立且确有收益时才并行，遵守既有并发与生命周期规则。
5. 外部能力的输出是证据或分析材料，不自动成为产品结论。MyP-M-A 仍负责证据分级、范围判断、门禁和下一步。
6. 能力不可用、输入不足或成本明显高于收益时，使用本地 reference 完成可支持部分，并把其余结论标为“待验证”。

选择 Matt pilot、代码审查提供者或同类能力发生重叠时，按需读取 `references/external-provider-routing.md`：明确注册/安装/宿主暴露/适配就绪/调用/验证六类身份、显式选择和嵌套权限；普通任务不加载整套清单。

## 路由表

| 当前问题 | 优先能力 | 适用入口 | 必要输入 | 要带回的结果 |
| --- | --- | --- | --- | --- |
| 需要设计访谈、归纳研究、表达 JTBD 或构建机会树 | 本地 `references/discovery.md` | `/idea`、`/review` | 决策问题、参与者/来源、原始记录、已知偏差 | 可追溯观察、矛盾证据、机会、关键未知和最小实验 |
| 多义术语或领域边界需专项澄清 | 用户选择后 `matt-domain-modeling-pilot`；见 `references/matt-pilot-adapters.md` | `/review`、`/idea`、`/prd` | 项目事实源、已有术语、争议、写入授权 | 带来源的术语差量、冲突与 ADR 候选；不另建事实源 |
| 需要给一位知情者一份可填写的异步问卷 | 用户选择后 `matt-to-questionnaire-pilot`；见 `references/matt-pilot-adapters.md` | `/review`、`/idea`、`/prd` | 收件角色、决策缺口、已知事实、输出目标 | 问卷与答案归属；生成不等于发送或批准 |
| 不清楚业务问题、用户、决策或数据边界 | `data-analytics:gather-business-context` | `/idea`、`/review` | 目标、对象、已有材料 | 决策问题、已知事实、缺口和建议下一个分析能力 |
| 需要建立数据表、字段、口径和关系地图 | `data-analytics:create-data-context` | `/idea`、`/prd` | schema、样例、字典或查询 | 粒度、主键、关系、时间、质量和可回答问题 |
| 不确定数据能否支撑结论 | `data-analytics:analyze-data-quality` | `/idea`、`/acceptance` | 数据集、时间范围、来源 | 完整性、重复、异常、偏差、可信范围和修复动作 |
| 用真实数据判断产品表现或取舍 | `data-analytics:product-business-analysis` | `/idea` | 指标/行为数据与业务问题 | 发现、分群、限制和可行动判断 |
| 指标突然变化，需要定位驱动因素 | `data-analytics:metric-diagnostics` | `/idea`、发布后 `/acceptance` | 指标定义、时间窗、维度、基线 | 复算结果、变化幅度、候选驱动和验证步骤 |
| 需要市场规模、敏感性或假设区间 | `data-analytics:market-sizing` | `/idea` | 市场定义、约束、可引用来源 | 假设、区间、敏感性和不能推出的结论 |
| 需要细分、定位、定价、GTM 或增长取舍 | 本地 `references/strategy-gtm.md`，按需结合网页/数据能力 | `/review`、`/idea`、`/prd`、发布后 `/acceptance` | 决策问题、目标角色、替代方案、市场/价格/渠道证据及时间 | 战略选择与排除项、证据边界、最小验证和阶段去向 |
| PRD 需要 KPI、护栏和目标 | `data-analytics:design-kpis` | `/prd` | 目标、用户行为、数据可得性 | 主指标、输入指标、护栏、口径和目标依据 |
| 已完成分析，需要核对计算与主张 | `data-analytics:validate-data` | `/acceptance` | 原始数据、分析结果、口径 | 复算、异常、可复现性和结论限制 |
| Web 页面需要真实浏览器操作和证据 | `webapp-testing` 或浏览器验证能力 | `/review`、`/acceptance` | URL、测试账号/前置条件、预期 | 操作步骤、截图、控制台/网络错误和实际结果 |
| 桌面窗口、托盘、系统权限或原生行为 | Computer Use + 日志/配置 | `/review`、`/acceptance` | 可执行产物、配置、日志、恢复方式 | 截图、动作、日志事件、产物变化和未覆盖项 |
| UI/交互 PRD 需要高保真表达 | 现有设计系统、Figma、frontend/UI skill | `/prd` | 产品气质、页面状态、已有原型 | 可交互原型、状态覆盖、文件路径和验证结果 |
| 需要核对 GitHub PR、CI、tag、Release | GitHub 插件或本地 git | `/review`、`/acceptance` | 仓库、分支/PR、权限范围 | 可审计的远端状态、CI、发布身份和授权缺口 |
| 需要对齐远端仓库、协作文档或任务系统与本地事实 | `references/enterprise-adapters.md` + 当前可用只读工具 | `/review`、`/acceptance`、`/prompt` | 稳定对象 ID、读取范围、时间和目标事实源 | 只读证据信封、身份冲突、可继承事实和最小补证 |
| 需要读取外部指标、评测 JSON/CSV 或查询结果作产品判断 | `references/enterprise-adapters.md` + 数据能力 | `/idea`、`/review`、`/acceptance` | 数据对象、唯一键、分母、时间窗、筛选和版本 | 可复算分维结果、数据新鲜度、限制和产品判断 |
| 已验证事实需要图表或语义图解回答明确问题 | `references/visual-delivery.md`；数值再读 `chart-delivery.md` | `/idea`、`/review`、`/prd`、`/acceptance` | 问题、冻结事实、目标载体、可编辑要求和许可 | 对应源文件、事实映射和载体验证；仅 HTML 检查双视口 |
| 需要评审代码 diff、commit 或发布区间 | 本地 OCR delegate；显式选择可用 Matt 两轴适配；详见代码扫描合同 | `/review` implementation | 仓库/ref、目标层、排除项、最小规格与对应授权 | 同快照覆盖、原报告、核证及独立性限制；缺 CLI 不冒称 OCR |

能力名称只是已知实现示例。当前环境存在等价能力时可以替换，但必须报告真实调用对象；没有能力时不要建议安装与当前结论无关的插件。

## 产品阶段的最小编排

### `/idea`

访谈、研究笔记、JTBD 或机会树优先使用 Discovery；结构化数据进入数据分析；市场、定位、定价、GTM 或增长取舍进入 Strategy/GTM。证据可以汇合，但不得用访谈次数冒充用户比例、用行为数据猜动机，或用竞品标价证明支付意愿。先锁定问题、对象、时间窗、粒度和可信边界，再选择最贴近的能力；最终只形成一份当前入口结论。

真实数据质量未知时先做质量分析；可用后再做产品、指标或市场判断。外部数据先锁定对象、版本、分母和新鲜度；无数据不假装分析。冻结数值确需可视化时走视觉合同，否则保留表格。最终记录“选择的能力 + 用途”或“未调用 + 原因”。

### `/review`

先用本地文件和最小运行证据建产品/领域/工程地图，外部能力只补缺口。跨系统对齐读 `enterprise-adapters.md`，不得凭标题合并对象；代码扫描读 `code-review-scanner.md`，战略承诺并存时读 `strategy-gtm.md`。正式关系图走视觉合同，证据不足只画待确认边。外部结论仍由 MyP-M-A 核验。

### `/prd`

先确定要验证的是业务逻辑还是界面交互：

- 逻辑不确定：优先状态机、决策表、接口契约或轻量逻辑原型；正式图解走视觉合同。
- 界面不确定：优先高保真可交互原型，并覆盖关键状态和出口。
- 两者都不确定：先做能回答最大风险的一个，不自动同时制作重型前后端原型。

外部设计或数据能力必须受 PRD 已确认范围约束，不代替提问门禁，也不擅自引入新字段、指标或页面。

若 ICP、定位、套餐、价格或渠道选择会改变本版范围，读取 `references/strategy-gtm.md`。只把已确认选择写成需求；关键战略假设未确认时停在方案收敛版。

### `/acceptance`

按被验收对象选择执行轨道：

- Web：浏览器操作、控制台、网络、截图和可访问性。
- Desktop：Computer Use、进程、日志、配置、文件和系统状态。
- Data/API：查询/接口、口径复算、数据质量、权限和迁移证据。
- Release：源码、候选产物、哈希、CI、tag/Release、回滚和发布面。
- Visual：源事实、映射、目标载体源文件、对应渲染/编辑检查和可访问性；仅 HTML 要求双视口与离线。按目标载体探测可用工具，不把网页工具作为 PPTX/drawio 的硬依赖。

一个验收项可以跨轨道，但必须在同一证据清单中汇总，不能让不同工具各自给出互相冲突的“通过”。

验收依赖外部协作或数据系统时，按需读取 `references/enterprise-adapters.md`；记录稳定身份、读取时间、版本/筛选、新鲜度和限制。默认只读，任何评论、任务、文档、代码或仪表盘写入都单独等待授权。

发布后需要判断渠道、激活、留存或定价假设时，可读取 `references/strategy-gtm.md`，但该分析属于上线观察或下一轮 `/idea`，不能回写为候选实现已经通过。

## 能力调用记录

只要使用外部能力，最终输出至少记录真实调用状态；未成功调用的能力不能写入“已使用”：

```markdown
| 能力/工具 | 探测/调用 | 状态 | 直接证据 | 限制/降级 |
| --- | --- | --- | --- | --- |
```

如果没有使用外部能力，可以用一句话说明“现有材料足以完成本轮判断”，无需为了填表制造调用。

## 证据包

`/idea` 的复杂数据判断建议压缩为：

```markdown
## 证据包

- 决策问题：
- 数据/来源：
- 统计对象与粒度：
- 时间范围与新鲜度：
- 数据质量与代表性：
- 关键发现：
- 反证或替代解释：
- 不能推出的结论：
- 对价值/时机判断的影响：
- 最小补证或实验：
```

没有数据时，“证据包”可以只写当前材料、关键假设和最小采集方案；不得填入虚构数值。

## 冲突与停止条件

- 工具结果与仓库事实冲突：保留冲突，核对对象身份、时间和版本，不自行选更乐观的结论。
- 数据质量不足：停止计算精确 KPI 或外推总体，改为给可信范围和补证动作。
- 自动化无法覆盖真实设备、账号、托盘、权限或感官体验：转入手动验证文档。
- 外部能力要求写入远端、生产数据、消息、费用或发布：等待用户授权。
- 同一问题连续调用两个能力仍无法减少关键不确定性：停止扩张，报告阻塞。
