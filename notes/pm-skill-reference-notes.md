# PM 类 Skill 参考笔记

本文记录本轮参考公开 PM skill / PM agent 案例后，对 MyP-M-A 的可借鉴点。它不是正式规则，后续应选择性沉淀到 `references/` 和模板中。

## 参考来源

- Product-Manager-Skills：大型 PM skill 框架，覆盖 Claude Code、Cowork、Codex 和 AI agents，强调 battle-tested methods、skill 之间可串联。
- product-on-purpose/pm-skills：较大的 PM skill 系统，包含 68 个 skill、commands、workflows、sub-agents、hooks 和 CI-enforced contracts。
- assimovt/productskills：轻量 PM skill 集合，强调 Discovery、Strategy、Prioritization、PRD writing；每个 skill 绑定一个真实框架，例如 Mom Test、Shape Up、Obviously Awesome、Teresa Torres。
- Digidai/product-manager-skills：定位为 12-domain PM operator，包含 Discovery、Strategy、PRD/Artifacts、SaaS Finance、Growth/PLG、Analytics Ops 等，并包含 metrics calculator、templates、evals、framing gate。

## 对 MyP-M-A 的启发

### 1. 保持一个主入口，但内部能力要更硬

外部案例常把 PM 能力拆成很多 skill 或 commands。MyP-M-A 不一定要照搬，因为用户已经明确偏好 `/idea`、`/prd`、`/review`、`/acceptance` 四个主入口。但每个入口内部要更像一个能力集合：

- `/idea` 内部应包含用户访谈式追问、场景压力测试、数据分析、竞品/替代方案分析、需求池治理。
- `/prd` 内部应包含澄清提问、方案收敛、优先级、范围控制、完整 PRD、原型、开发承接。
- `/acceptance` 内部应包含自动化验证、GUI 验证、人工补证、发布收口。

### 2. `/idea` 要补“数据与场景”两个肌肉

当前 MyP-M-A 的 `/idea` 更依赖 review 或用户给出的方向。后续要补：

- 数据输入识别：日志、埋点、数据库、表格、GitHub issue、用户反馈、录屏/截图、客服记录、崩溃报告。
- 数据分析输出：核心指标、分群、漏斗、频次、错误率、留存/转化、影响面、样本偏差、缺口。
- 场景压力测试：不只给需求打分，还要主动构造使用者、场景、触发条件、替代方案和失败情境。
- 用户压力测试：如果用户没有提供人群、频率、证据、付费/时间成本、替代方案，必须追问或标记低证据。

### 3. `/prd` 要更像“深度访谈 + 交付门禁”

外部 PRD skill 倾向把 PRD 写得结构化，但 MyP-M-A 的差异应是更贴近开发交付。用户反馈显示：问题问得太少会导致后续多轮返工。因此：

- PRD 阶段应允许“分轮提问”，不要为了简洁牺牲理解质量。
- 如果需求复杂、跨模块、涉及 UI/配置/数据/后端，首轮问题数量可以多于普通对话。
- PRD 不是只交文档，还要保证原型、影响范围、验收口径和开发承接条件成熟。

### 4. 手动验证文档应成为 `/acceptance` 的固定分支

桌面应用、托盘、音频、硬件、权限、真实用户路径经常不能完全自动化。MyP-M-A 应在 acceptance 后判断：

- 如果还有人工补证项，输出 `manual_verification_vx.x.md` 或同等手动验证文档。
- 如果没有人工补证项，才进入发布提交/推送/远端同步建议。

### 5. 文档必须全中文，并明确编码要求

MyP-M-A 是中文优先 skill，输出文档必须全中文。除代码标识、命令、文件名、API 字段、英文专有名词外，不应混入英文段落。所有新建 Markdown 文档应使用 UTF-8 编码，避免乱码。

## 适合沉淀的新增规则

- `/idea` 增加固定字段与评分阈值。
- `/idea` 增加数据分析输入与输出模板。
- `/idea` 增加用户/场景压力测试。
- `/prd` 增加澄清提问密度规则。
- `/prd` 增加高保真原型门禁。
- `/prd` 后自动生成 `dev_plan_vx.x.md`、`progress_vx.x.md` 和必要的 `dev_log_vx.x.md`。
- `/acceptance` 增加 `manual_verification_vx.x.md` 模板。
- `SKILL.md` 增加全中文与 UTF-8 编码质量门禁。
