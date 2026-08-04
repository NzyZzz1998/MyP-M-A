# MyP-M-A 阶段与外部能力审计

本文整理当前 MyP-M-A 在真实项目试跑后的阶段边界、输入要求、输出内容、外部能力依赖和待优化方向。它不是正式工作流规则，而是下一轮优化 `SKILL.md`、`references/` 和模板前的盘点材料。

## 当前阶段地图

```mermaid
flowchart LR
  A["/review<br/>理解项目与发现候选点"] --> B["/idea<br/>判断真假、价值、时机"]
  B --> C["/prd<br/>收敛方案、定义需求"]
  C --> D["dev_plan_vx.x.md<br/>开发承接计划"]
  D --> E["progress_vx.x.md<br/>状态看板与最小任务"]
  E --> F["implementation<br/>开发实现"]
  F --> G["/acceptance<br/>实际验收与发布收口"]
  G --> H["release closeout<br/>发布说明、tag、回滚、状态一致性"]
  G --> B
```

当前四个主入口已经比较清晰：

- `/review`：项目理解、对象脉络、架构图、候选问题发现。
- `/idea`：发现问题 -> 判断价值，回答是不是真问题、值不值得继续、现在该不该做。
- `/prd`：收敛方案 -> 定义需求，产出可开发、可测试、可验收的需求文档。
- `/acceptance`：开发完成后的实际验收、发布前检查、回滚和发布说明。

开发承接不是独立对外入口，但已经成为 `/prd` 之后的固定产物：

- `dev_plan_vx.x.md`：实施顺序、影响文件、风险、测试命令、回退方式。
- `progress_vx.x.md`：状态看板、模块 checklist、阻塞项、验证结果、下一步。

## 各阶段输入与输出

| 阶段 | 输入要求 | 核心输出 | 不该输出 |
|---|---|---|---|
| `/review` | 项目路径、页面截图、PRD、实现分支、发布包、文档目录、用户想 review 的对象 | Review 判断、对象脉络、架构图/流程图、关键发现、值得保留、候选问题、下一步分流、可直接发送的下一条提示词 | 不把候选问题直接当成确定需求；不只列问题而不建立项目地图 |
| `/idea` | 用户想法、review 候选点、验收遗留项、用户反馈、竞品/市场证据、多个候选需求 | 需求池或轻量 brief、证据等级、压力测试评分、价值判断、阶段结论、最小下一步、进入 `/prd` 或继续验证的建议 | 不写完整 PRD；不做实际验收通过/失败判断 |
| `/prd` | 已验证需求或准备原型验证的想法、idea 结论、用户确认的问题、现有文档/代码/原型 | PRD 类型判断、候选方案、推荐优先级、版本范围、完整 PRD、影响范围、原型、开发前验收目标与标准 | 不跳过澄清直接成文；不在 PRD 不完整时进入 dev plan |
| 开发承接 | 已确认的完整 PRD、现有代码结构、历史计划与 progress 风格 | `dev_plan_vx.x.md`、`progress_vx.x.md`，每个模块拆成 Vibe Coding 最小任务 | 不写开发日志、bugfix 流水账、技术 spike 细节 |
| `/acceptance` | 开发结果、构建产物、exe/网页、日志、配置、测试命令、CI、用户手动证据、发布包 | 通过/部分通过/未通过/待验证，证据表，回归范围，发布检查，回滚方式，发布说明，上线后观察 | 不重复判断需求真假；不把自动化测试通过等同于 GUI/桌面/真实设备通过 |
| 发布收口 | 验收通过证据、release notes、changelog、tag、发布包、checksums、回滚目标 | 状态一致性、发布提交、tag、已知限制、回滚说明 | 不移动旧 tag；不让文档状态与真实 tag/分支/产物冲突 |

## 外部能力依赖矩阵

| 外部能力 | 属于什么 | 主要阶段 | 使用目的 | 当前规则状态 |
|---|---|---|---|---|
| 本地文件与 shell | Codex 基础工具 | `/review`、`/prd`、`/acceptance`、开发承接 | 读代码、文档、日志、配置、测试、构建、git 状态 | 已写入 `references/tooling.md`，可继续细化 |
| GitHub 插件 | 外部插件能力 | 四个入口，尤其 review/acceptance/release | 读 PR、Issue、CI、Release、提交/推送、review comments | 已有原则，但每阶段触发条件还可更明确 |
| OpenCodeReview 或等价代码扫描器 | 外部 CLI/模型能力 | `/review` 的 implementation 通路 | 锁定 diff/commit/release 范围、加载语言规则、发现代码候选问题 | 已接入；远程处理私有源码需明确授权，候选必须由 MyP-M-A 做证据闭环 |
| Computer Use | 外部插件/skill 能力 | `/review`、`/acceptance`，必要时 `/prd` | 操作 Windows exe、托盘、菜单、弹窗、真实点击路径、截图 | 已写入 tooling；需补“不可稳定操作托盘时标记人工补证” |
| 浏览器 / Playwright / webapp-testing | 外部工具/skill 能力 | `/review`、`/acceptance`，必要时 `/prd` | 验证网页原型、Web UI、响应式、控制台、交互 | 已有原则，需补高保真原型验证场景 |
| Web 搜索 | 网络能力 | `/idea`、必要时 `/prd` | 查竞品、市场信号、公开资料、同类产品做法 | 已有原则；要强调证据来源和时效 |
| 图片/文档/PDF/表格工具 | 外部 skill 或本地解析能力 | 四个入口 | 读取截图、PRD、会议纪要、验收记录、数据表 | 已有原则；可补截图反馈进入 `/review` 或 `/prd` 的分流 |
| UI/UX / frontend-design 类 skill | 外部 skill | `/prd`、UI review、原型优化 | 高保真原型、组件规范、视觉精修建议 | 尚未正式纳入 MyP-M-A 工具策略 |
| superpowers 类 skill | 外部 skill 参考 | `/prd`、开发承接 | brainstorming、writing-plans、verification-before-completion 等能力参考 | 已被经验吸收，但不应强依赖；可写成“可借鉴能力” |
| skill-creator | 外部 skill | MyP-M-A 自身维护 | 修改 skill、拆 reference、写 eval、验证 skill 结构 | 维护阶段使用，不属于用户项目阶段 |
| Vercel/Netlify/部署工具 | 外部插件 | `/acceptance`、发布收口 | 检查部署、环境变量、Preview、回滚 | 已有原则，但当前真实案例较少 |
| Lark/协作文档工具 | 外部插件 | 四个入口 | 需求池、会议纪要、任务、协作文档 | 已有原则，未在本轮项目验证 |

## 本轮真实项目沉淀

### QuickRec

已经跑通了完整链路：

- `/review -> /idea -> /prd -> dev_plan/progress -> implementation -> /acceptance -> release closeout`

关键经验：

- `/idea` 的轻量需求池有效，能避免把所有 review 发现都推进 PRD。
- `/prd` 对单个功能可以做到比旧提示词更深，特别是影响范围、完整链路、开发前验收和非目标。
- `/acceptance` 必须区分“实现完成”和“可发布”，第一次部分通过是正确判断。
- 验收对象路径必须和最终发布对象一致，路径不一致是发布风险。
- 自动化测试通过不能替代 GUI、托盘、真实桌面、真实音频设备验收。
- 发布收口需要同步 PRD、dev plan、progress、acceptance checklist、release notes、changelog、tag、回滚方式。
- Full / Lite 项目拆分说明：产品线边界与历史文档归属也应纳入 review 和文档治理判断。

### LetsMakeMoney

本轮链路大致为：

- v0.4 收尾验证 -> `/idea` v0.5 -> `/prd` v0.5 -> 高保真原型 -> dev plan/progress -> implementation -> `/acceptance` -> bugfix -> 待人工补证

关键经验：

- `/idea` 初版如果只列候选项会显得薄，需要补版本主线、证据映射、依赖关系和三档范围方案。
- `/prd` 初版可能只是方案收敛版，不等于完整可开发 PRD。
- UI/体验主线版本必须要求高保真原型或更新现有原型文件，低保真线框不够。
- 完整 PRD 后才能进入 dev plan/progress。
- `progress` 不应混入开发日志；bugfix、dev log、spike log 应另建文档。
- `/acceptance` 对桌面应用要承认 Computer Use 局限。托盘左键这类项目，如果工具不能稳定点击，应标为人工补证，而不是硬判通过。
- bugfix 后可进行定向复验，不必重跑所有无关项，但发布前必须保留补证口径。

## 已经落地的优化

- `/review` 已补 release readiness review。
- `/review` 已补下一步分流与建议下一条提示词。
- `/prd` 已补 dev plan/progress 开发承接规则。
- 已新增 `templates/dev-plan-template.md`。
- 已新增 `templates/progress-template.md`。
- 已新增 `/acceptance` 真实试跑 notes。
- `references/tooling.md` 已有四入口工具策略。

## 原本打算继续优化的内容

### P0：应优先落地

1. `/idea` 增加版本型需求池规则。
   - 如果输入来自上一版本 review/acceptance，必须输出版本主线判断。
   - 必须说明为什么不是其他大方向。
   - 必须给候选需求依赖关系图或表。
   - 必须给最小方案、推荐方案、过大方案。
   - 必须把上一版本验收项映射为下一版本候选证据。

2. `/prd` 增加完整度门禁。
   - 区分“方案收敛版 PRD”和“完整可开发 PRD”。
   - 方案收敛版不能直接进入 dev plan。
   - 完整 PRD 必须包含完整功能链路、影响范围、配置/数据、保存/取消/关闭/失败反馈、开发前验收、原型。
   - UI/体验主线版本必须包含高保真原型或更新现有原型文件。

3. `/acceptance` 增加发布证据门禁。
   - 验收对象必须和最终发布对象一致。
   - 自动化测试、打包 smoke、GUI 手动验收、异常场景、发布说明要分开记录。
   - Computer Use 无法覆盖的桌面/托盘项应标为人工补证。
   - 允许阶段化输出：首次验收、补证复验、发布收口。

### P1：近期优化

4. 拆出 `references/development-handoff.md`。
   - `references/prd.md` 已经偏长，开发承接规则适合独立维护。
   - 内容包括命名、模板、边界、Vibe Coding checklist、progress 不写开发日志。

5. 增强模板。
   - `progress-template.md` 增加版本主线、阶段、模块完成度、验收状态。
   - `dev-plan-template.md` 增加 PRD 对照表、实施前检查、不扩范围项。

6. `/review` 增加下一条提示词示例。
   - Release readiness -> `/acceptance` 示例。
   - Project review -> `/idea` 需求池示例。
   - 文档事实冲突 -> 直接文档治理示例。

7. 把 UI/UX 外部 skill 纳入 `/prd` 的可选能力。
   - 当需求是 UI polish、设置窗口、组件系统、高保真原型时，可调用 UI/UX、frontend-design 或相关设计 skill。
   - 但最终仍要回到 MyP-M-A 的 PRD/验收结构，不让设计建议漂在外面。

### P2：后续优化

8. 检查是否存在 `agents/openai.yaml` 或插件元数据需要同步。
9. 增加轻量 eval。
   - QuickRec：诊断导出从 idea 到 PRD。
   - QuickRec：部分通过 acceptance 是否能阻止发布。
   - LMM：v0.5 idea pool 初版不足时是否能增强。
   - LMM：方案收敛版 PRD 是否会误进入 dev plan。
10. 建立版本文档治理规则。
   - Full / Lite 或多产品线拆分时，历史 PRD、技术设计、release notes 应归属正确产品线。
   - Lite 第一个版本不应背负 Full 历史文档。
   - post-split 文档治理提交不能移动发布 tag。

## 待用户继续补充的问题

用户正在思考的优化内容还未合并。下一轮可以按以下问题继续：

- `/idea` 需求池是否要固定字段和评分阈值？
- `/prd` 高保真原型是“必须生成 HTML”，还是“已有原型则必须更新”？
- `dev_plan/progress` 是否作为 `/prd` 后自动交付，还是用户确认后再生成？
- `/acceptance` 发布收口是否需要单独模板，还是继续放在 acceptance 模板内？
- MyP-M-A 是否应该提供“下一条提示词生成器”作为每个阶段固定尾部？
- 外部工具是否要写成硬性触发条件，还是保持“需要证据时调用”的弹性？

## 用户补充反馈 - 2026-07-09

本轮用户明确补充了以下使用不足和决策，已作为下一轮正式规则优化依据。

### /idea 不足

- 缺乏数据分析能力。
- 未自动化对使用者进行压力测试，尤其是场景缺失、用户缺失、频率缺失。
- 目前更多依赖 review 或用户提供需求/方向，需要补额外迭代能力。

已转化为规则：

- `/idea` 增加数据分析补强，覆盖日志、表格、数据库、GitHub issue、用户反馈、埋点和竞品资料。
- `/idea` 增加用户与场景压力测试。
- `/idea` 需求池需要固定字段和评分阈值。

### /prd 不足

- 问题数量相比 superpowers 类 skill 显著减少，导致需求理解不全。
- LMM 验证结束后又做了多轮沟通重新修订，说明 PRD 初版的提问深度不足。
- 未明确开发日志，开发承接时需要对开发日志做约束。

已转化为规则：

- `/prd` 增加提问深度补充：小改动、单功能、版本级、跨前后端/数据库需求采用不同提问密度。
- `/prd` 增加完整 PRD 门禁，方案收敛版不能直接进入 dev plan。
- 完整 PRD 后默认交付 `dev_plan_vx.x.md`、`progress_vx.x.md`，必要时交付 `dev_log_vx.x.md`。
- 开发日志独立于 progress，格式参考 LMM 旧 progress 的开发日志颗粒度。

### /acceptance 不足

- 缺少手动验证文档。

已转化为规则：

- `/acceptance` 完成后先判断是否存在人工补证项。
- 如存在，输出 `manual_verification_vx.x.md` 或版本目录下的 `manual-verification.md`。
- 如不存在，再准备本地与远端仓库提交/推送建议，并等待用户决策。

### 通用问题

- 当前项目数量太少，很多场景未发挥，包括完整后端架构、数据分析、数据库分析、数据库构筑。
- 输出文档必须全中文。
- 部分文档存在乱码。
- 还需要参考其他 PM 类 skill 优化当前 skill。

已转化为规则：

- `SKILL.md` 增加全中文与 UTF-8 编码门禁。
- 新增 `notes/pm-skill-reference-notes.md`。
- 清洗乱码模板：`acceptance-template.md`、`dev-plan-template.md`、`progress-template.md`。

### 用户明确决策

- `/idea` 需求池需要固定字段和评分阈值。
- `/prd` 高保真原型：已有原型则更新；没有原型则在 PRD 正式完成阶段必须输出高保真原型。
- `dev_plan/progress` 需要作为 `/prd` 后的自动交付。
- `/acceptance` 不需要单独发布收口模板；acceptance 完成后优先判断是否需要手动验证文档。
- 每个阶段需要提供下一阶段任务建议；用户无异议时，根据需求输出下一阶段提示词。
- 外部工具触发保持弹性，不写成过硬的强制触发条件。
