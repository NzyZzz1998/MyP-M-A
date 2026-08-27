<p align="center">
  <picture>
    <source media="(max-width: 600px)" srcset="assets/readme/hero-mobile.svg">
    <img src="assets/readme/hero.svg" alt="MyP-M-A：共享一份产品事实，按团队协作或 Vibe Coding 两种模式推进交付" width="100%">
  </picture>
</p>

# MyP-M-A

**面向团队协作与 Vibe Coding 的中文产品经理 Skill：把需求写完整，把职责说清楚，把证据留给下一步。**

`v0.41.0 Stable` · `中文优先` · `5 个入口` · `2 种交付模式` · `证据驱动`

MyP-M-A 是安装在 Codex、Claude Code 等 Agent 宿主中的工作规则，不是独立应用，也不自带模型。提供项目、想法、截图或反馈，它会帮助你理解问题、判断价值、定义需求，再对真实交付做验收。

**公司协作时，交付完整的产品文档；自己做产品时，经确认后继续承接原型、开发计划和验收。** 不会仅因为项目里有代码，就把一份团队 PRD 扩写成工程实施手册。

[开始使用](#开始使用) · [选择交付方式](#选择交付方式) · [交付示例](#交付示例) · [质量与验证边界](#质量与验证边界)

## 先看交付

从[项目关系图](examples/showcase/01-review-project-map.md)、[异步导出 PRD](examples/showcase/03-prd-async-export.md)到[发布验收报告](examples/showcase/04-acceptance-release-gate.md)，仓库中提供了可以直接阅读的交付示例。它们是**完全合成的演示材料**，展示文档结构与判断方式，不是客户案例或真实测试证据；异步导出示例展示的是工程增强深度，不代表团队 PRD 必须包含表结构。

## 开始使用

### 1. 安装到正在使用的宿主

使用标准 `SKILL.md` 目录结构，选择一种安装位置即可。以下为 PowerShell 个人级安装示例：

```powershell
# Codex：使用这一条
git clone https://github.com/NzyZzz1998/MyP-M-A.git "$HOME\.agents\skills\mypm"

# Claude Code：使用这一条
git clone https://github.com/NzyZzz1998/MyP-M-A.git "$HOME\.claude\skills\mypm"
```

仓库访问需具备相应权限。已经安装时，在现有目录更新，不要覆盖本地修改或再装同名副本。

<details>
<summary><strong>个人级、项目级与自定义目录</strong></summary>

| 宿主 | 个人安装位置 | 项目级安装位置 |
| --- | --- | --- |
| Codex | `~/.agents/skills/mypm/` | `<PROJECT>/.agents/skills/mypm/` |
| Claude Code | `~/.claude/skills/mypm/` | `<PROJECT>/.claude/skills/mypm/` |

以上为默认本地目录；自定义存储或符号链接以宿主实际扫描目录为准。目录规则见 [Codex 官方文档](https://developers.openai.com/codex/skills/)和 [Claude Code 官方文档](https://code.claude.com/docs/en/skills)。

</details>

### 2. 发出第一条任务

安装并让宿主加载技能后，把下面这段发给 Agent。它是对话任务文本，**不是终端命令**：

```text
mypm /review

评审当前项目，先说明用户、核心流程、模块关系和当前进度，
再列出有证据的问题与下一步建议。本轮只读，不修改代码。
```

不记入口也可以直接说“使用 MyP-M-A 帮我判断这个想法”。提供相关项目路径、文档或反馈即可；只有会影响当前判断的信息缺失时，才需要补充澄清。

## 选择交付方式

v0.41 的重点是**同一份产品事实，两种交付深度**。模式改变职责和工程深度，不改变已确认的范围、数字、状态或验收标准。

| | 团队协作型 `team_pm` | 全流程型 `vibe_coding` |
| --- | --- | --- |
| 适合谁 | 在公司与设计、研发、测试协作的产品经理 | 自己用 Agent 做产品、继续实现与验证的人 |
| 产品交付 | 目标、范围、流程、业务规则、权限、指标、影响与验收 | 同样完整的产品要求 |
| 原型责任 | 明确设计要求；交由设计承接，或按用户要求代做 | 正式 PRD 阶段更新或补齐高保真原型 |
| 技术深度 | 不擅自定义物理 API、数据库表、代码或部署方案 | 补充有依据的工程约束与接口、数据设计 |
| 停止位置 | 产品评审与角色交接点 | 按授权分阶段推进，不自动越过 PRD 确认点 |

默认 `delivery_mode=auto`：组织协作或意图不明时按团队协作型处理；明确要求同一 Agent 继续实现、测试或发布承接时采用全流程型。显式指定优先。

**写给团队的 PRD：**

```text
mypm /prd

delivery_mode=team_pm
依据当前需求材料，写一份供设计、研发和测试评审的完整 PRD。
说清业务流程、规则、影响范围和验收，不代替研发决定物理实现。
本轮停在 PRD 确认点。
```

**自己用 Agent 做产品：**

```text
mypm /prd

delivery_mode=vibe_coding
依据已确认需求完善 PRD，更新高保真原型并补齐工程承接所需约束。
后续由同一 Agent 实现；先让我确认 PRD，再生成开发计划与任务。
本轮不要进入业务代码实现。
```

## 五个入口

| 入口 | 核心问题 | 主要交付 | 明确不做 |
| --- | --- | --- | --- |
| `/review` | 项目现在是什么样，问题在哪里 | 产品/工程地图、证据化发现、影响与分流 | 不把发现直接升级成需求 |
| `/idea` | 这是真问题吗，值得现在做吗 | 需求池、证据等级、压力测试、最小实验 | 不用评分替代证据 |
| `/prd` | 应该做成什么，怎样避免遗漏 | 完整需求、影响范围、业务状态与数据口径、原型要求、开发前验收 | 不擅自扩大技术深度 |
| `/acceptance` | 实际实现是否达到发布标准 | 产物身份、真实证据、缺口、人工验证、发布结论 | 不用计划或代码阅读替代实测 |
| `/prompt` | 下一轮怎样交接得短而完整 | 带事实、范围、证据、授权和停止条件的提示词 | 不改写上游结论 |

可从任一入口开始，不必每次重走全流程。`/prompt` 负责阶段间交接，不是第五个产品阶段；这些入口由 Skill 解释，不保证在每个宿主中注册为同名斜杠菜单。

<p align="center">
  <picture>
    <source media="(max-width: 600px)" srcset="assets/readme/product-loop-mobile.svg">
    <img src="assets/readme/product-loop.svg" alt="从项目评审、想法验证、PRD 到开发承接与实际验收；Prompt 负责交接，可按任务从任一阶段进入" width="100%">
  </picture>
</p>

## 一份完整 PRD 包含什么

**减少越界，不减少需求细节。** 保存、取消、关闭、失败、恢复和旧体验保护，都是产品需求的一部分。

<details>
<summary><strong>展开完整 PRD 的十项检查</strong></summary>

1. 背景、问题、目标与非目标。
2. 用户、场景、前置条件和成功出口。
3. 范围、优先级、版本边界与依赖关系。
4. 从入口到出口的主流程、分支流程和取消/关闭行为。
5. 业务规则、状态、权限、异常、恢复与旧体验保护。
6. 数据口径、指标、日志和证据要求。
7. 前端、后端、数据、配置、发布、测试等影响范围。
8. 信息架构、交互状态、原型责任与设计验收要求。
9. 开发前验收目标、通过标准和不通过处理。
10. 未决问题、风险、假设与后续承接。

</details>

团队协作型由设计角色承接原型；用户要求代做或没有下游设计角色时才生成高保真原型。全流程型在正式 PRD 阶段补齐可验证的高保真原型，并在确认与授权后生成：

- `dev_plan_vx.x.md`：实施顺序、影响文件、风险与回退。
- `progress_vx.x.md`：最小可执行任务和状态看板。
- `dev_log_vx.x.md`：独立记录开发过程，不与进度混写。

## 交付示例

以下均为完全合成的演示用例，用来展示判断方式和交付结构，不替代真实项目证据：

| 用例 | 关键能力 |
| --- | --- |
| [项目评审](examples/showcase/01-review-project-map.md) | 先建立项目地图，再区分实现偏离、文档过期和验证缺口 |
| [想法验证](examples/showcase/02-idea-value-test.md) | 锁定统计口径，证明问题但不替预设方案找理由 |
| [正式 PRD：工程增强示例](examples/showcase/03-prd-async-export.md) | 将异步导出展开为权限、状态、数据库、失败链路和开发前验收 |
| [发布验收](examples/showcase/04-acceptance-release-gate.md) | 自动测试全绿时仍依据真实冲突阻止错误发布 |
| [提示词交接](examples/showcase/05-prompt-handoff.md) | 保留事实、验证和授权边界，同时压缩下一轮任务 |

[查看完整演示目录](examples/showcase/README.md)

## 使用边界与可选能力

- **正确性、证据、完整性优先**：更短、更快或更好看不能抵消关键事实错误。
- **未知保持未知**：不编造用户、阈值、接口、字段、状态或完成结果。
- **阶段不能越级**：Review 发现不是确认需求，方案收敛版不是完整 PRD，测试计划不是实际验收。
- **范围必须可追踪**：正式交付引用上游 ID、版本、文件和证据，写清非目标与回退。
- **仓库是事实源**：Basic Memory 只负责跨线程续接，不能覆盖项目中的 PRD、进度和验收事实。
- **外部写入单独授权**：提交、推送、Tag、Release、上传和可见性变更不会因验收通过而自动执行。

浏览器、Computer Use、GitHub、数据库、图表和 Basic Memory 均按需使用，**不是全部安装后才能开始**。工具由宿主提供；不可用时保留待验证项，不能将只读检查当成真实操作成功。

Basic Memory 支持 `auto`、`suggest`、`off` 三种模式。默认仅在已知项目的新线程上下文不足时恢复，在稳定阶段结束时去重更新；不把完整聊天、凭据或临时日志写进记忆。详见[工具策略](references/tooling.md)和[记忆边界](references/memory-integration.md)。

## 质量与验证边界

当前版本：`v0.41.0 Stable`。运行时、评测治理和 README 已本地提交，待同步 `main`。README 内容及静态检查完成，浏览器视觉复查仍待验证。`v0.40.0` 保持稳定回退；本轮不创建 tag 或 Release。
<!-- project-status: version=0.41.0; state=local-committed -->

**已验证的是本版职责边界和受影响路径，不是所有模型、所有场景全面领先。** 完整稳定集、完整挑战集与跨模型面板未重跑；评测治理自测也不计入模型得分。

<details>
<summary><strong>展开 v0.41 验证范围与结果</strong></summary>

| 证据面 | 结果与范围 |
| --- | --- |
| 评测资产 | 194 项统一账本：114 条稳定用例、46 条挑战用例、34 条触发用例；不等于每轮全跑 |
| 完整稳定集 | 未全量重跑 / 883 个检查项 |
| 完整挑战集 | 未全量重跑 / 376 个检查项 |
| 发布面板 | 固定核心 + 9 个工作模式合同差量，共 28 条用例 |
| 静态门禁 | PowerShell 7 与 Windows PowerShell 5.1 Strict、资产账本新鲜度、负向自测和上下文预算均通过，warnings=0 |
| 动态行为 | Sol medium 单次，双方 28/28 有效；v0.40 为 `190/206`，v0.41 为 `201/206`，候选 10 胜、0 负、18 平 |
| 证据继承 | 主面板 23 条继承未受影响结果，5 条用定向结果替换；题面补全的 2 条同题复测 `12/14 → 14/14`，不与主面板相加 |
| 运行时独立验收 | 首轮发现的 route、快照继承、题面披露、预算判定和回退身份 5 项缺口均已关闭；运行时阻塞项 0 |
| 评测治理增量 | 独立审计 R1～R5 全部关闭；双引擎自测各 5 个正向、23 个负向通过；不增加模型得分，README 视觉复查另列待验证 |

完整记录见[运行时证据影响表](notes/v0.41-evidence-impact.md)与[治理增量验收](notes/v0.41-governance-acceptance.md)。

</details>

评测资产按 T0～T5 分层执行，并区分 core、active、canary、archived、retired 生命周期。正确性、证据纪律、完整性和事实保真属于硬门禁，不生成掩盖关键错误的统一总分。详见[评测方法](evals/README.md)、[机器策略](evals/evaluation-policy.json)和[资产账本](evals/eval-inventory.json)。

## 参与维护

修改 Skill 后，在仓库根目录运行静态校验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill.ps1 -Strict
```

该命令检查 UTF-8、常见乱码、版本一致性、运行时引用、评测 schema、生命周期归属、资产账本新鲜度、本地 Markdown 链接和孤立资源。静态校验不能替代模型行为评测。

<details>
<summary><strong>仓库结构</strong></summary>

```text
mypm/
├─ SKILL.md       # 入口路由与常驻核心合同
├─ capabilities/  # 离线注册表与按需能力卡
├─ references/    # 按当前入口渐进加载的规则
├─ templates/     # PRD、验收、计划等正式模板
├─ evals/         # 稳定、挑战、触发与文件型用例
├─ examples/      # 公开案例准入规范与合成演示
├─ scripts/       # 静态校验与评测治理工具
├─ assets/readme/ # README 静态视觉资产
├─ notes/         # 路线图、评测历史与版本事实源
└─ agents/        # Agent 宿主展示与默认提示配置
```

</details>

| 继续了解 | 文档入口 |
| --- | --- |
| 产品与演进 | [版本变化](CHANGELOG.md) · [路线图](notes/mypm-roadmap.md) · [版本标签](notes/version-tags.md) |
| 本版设计与进度 | [PRD](notes/v0.41-team-boundary-prd.md) · [开发计划](notes/dev_plan_v0.41.md) · [进度与门禁](notes/progress_v0.41.md) |
| 评测与历史 | [评测方法](evals/README.md) · [资产治理](notes/v0.41-evaluation-governance.md) · [长期结果](notes/evaluation-history.md) |

内部标识固定为 `mypm`，对外展示名称固定为 `MyP-M-A`。
