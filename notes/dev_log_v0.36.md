# MyP-M-A v0.36 开发日志

> 本文记录开发过程、关键决策、异常处理和验证结果。它不替代 `notes/progress_v0.36.md`；progress 只保留状态看板和最小任务 checklist。

## 基本信息

- 目标版本：v0.36
- 当前阶段：M0～M5 与独立 `/acceptance` 已完成，Stable（本地已提交）
- PRD：`notes/v0.36-capability-ecosystem-prd.md`
- 开发计划：`notes/dev_plan_v0.36.md`
- 状态看板：`notes/progress_v0.36.md`
- 稳定基线：v0.35.0 Stable
- 日志原则：记录事实、命令、结果、偏差与回退，不复制大段模型回答或正式文档正文

## 开发记录

### 2026-08-17 M0：稳定基线与外部候选边界

- 执行基线：
  - 分支：`main`。
  - HEAD 与 `origin/main`：`c8af239a91043a35d8229746f36cb7f393fb4526`。
  - 进入 M0 时工作区仅有 v0.36 五份承接文档，v0.35 tracked 文件未改动。
- v0.35 冻结结果：
  - 核心运行时：`SKILL.md` + 26 份 reference，共 27 个文件；组合 SHA256 为 `b1eb98ded50e43c083bce82fd212f35e25f2dff920aabef36bbd7885ee05c76d`。
  - 完整评测运行时快照：`SKILL.md` + `agents/` + `references/` + `templates/`，共 39 个文件；组合 SHA256 为 `b5e62b3a7977d2da3b8fd625e98c3c3961433d70d532be759bbd10f970f5bda1`。
  - 当前目录：85 条稳定、21 条挑战、34 条触发、49 个合同、6 个场景组。
  - 五入口 formal 字符：`/review 10206`、`/idea 10578`、`/prd 13260`、`/acceptance 17811`、`/prompt 14057`；四个重入口相对 v0.33 平均下降 `32.99%`。
  - 预算证据：`E:\codex\skill-evals\mypm-v036-external-benchmark-20260817\v035-context-budget.json`。
- 外部候选冻结：
  - phuryn/pm-skills：`18468a95b427e70e258b51389796367c6f684e7d`，MIT，Codex Skill 兼容；进入行为与结构对标。
  - product-on-purpose/pm-skills：`6dcc092f7f77af502077a04cf94b38fc10d2d3c5`，Apache-2.0，含 Codex plugin；进入行为与结构对标。
  - deanpeters/Product-Manager-Skills：`a03af68414bb0b924746c97bddf9a5057d017af7`，CC BY-NC-SA 4.0；能力选择需额外人工路由且再分发限制更强，本版只做结构对标。
  - Anthropic knowledge-work-plugins：`bd1fb11095669f76797a12427791d3b4deeabd16`，Apache-2.0；主要面向 Claude Code/Cowork 与连接器环境，本版只做结构对标。
  - Kappa startup pressure test：`247b06546a4beaf5775180e587d8b3e772ea8574`，MIT；仅覆盖单点创业压力测试，不适合作为 12 条全流程共同候选，只做结构对标。
- 任务边界：EB-01～EB-12 保持 PRD 定义，fixture 必须为合成或中性材料，不复制 QuickRec、LetsMakeMoney 等私有项目原文。
- 工具确认：桌面应用内置 `codex.exe` 可调用，后续模型面板无需依赖独立安装或常驻子 Agent。
- 验证：严格静态校验、上下文预算、仓库身份和候选只读审计均通过。
- 回退点：外部仓库全部位于 `E:\codex\skill-evals\mypm-v036-external-benchmark-20260817\candidates`，未写入主仓库。

### 2026-08-17 PRE：需求收敛与开发承接

- 目标：将“与公开代表 PM Skill 的差距”从讨论收敛为 v0.36 可执行范围。
- 实际改动：
  - 新增 `notes/v0.36-idea-pool.md`。
  - 新增 `notes/v0.36-capability-ecosystem-prd.md`。
  - 新增 `notes/dev_plan_v0.36.md`。
  - 新增 `notes/progress_v0.36.md`。
  - 新增本开发日志。
- 关键决策：
  - v0.36 只做能力注册表、三张试点能力卡、12 条外部对标面板和公开案例规范。
  - 保持五入口不变，不批量新增框架，不新增外部工具硬依赖。
  - 三张卡首轮只声明既有 reference 合同，不形成第二套方法正文。
  - 外部项目的结构规模与行为质量分开；行为对标必须同输入、同模型、同强度并隐藏候选映射。
  - 公开案例本版只完成规范和一个内部 dry-run，不实际发布。
- 计划审计发现：PRD 初稿将 validator 误写到不存在的 `scripts/modules/`；已依据仓库现状修正为 `scripts/validation/`，测试脚本统一为 `scripts/test-v036-governance.ps1`。
- 已验证：
  - `validate-skill.ps1 -Strict` 通过。
  - UTF-8、乱码、IDEA/FR/AC 编号、尾随空格和文件结尾检查通过。
  - IDEA-001～010、FR-001～012、AC-001～015 覆盖完整。
  - 开发承接前未修改 `SKILL.md`、`references/`、`evals/` 或业务脚本。
- 未验证 / 待补证：
  - 外部候选的最终固定 commit、许可证与同宿主运行资格。
  - 三张能力卡的上下文预算和行为回归。
  - 12 条实际模型对标和公开案例 dry-run。
- 回退点：删除 v0.36 新增文档即可恢复到 v0.35 Stable；当前没有运行时改动。

### 2026-08-17 M1：能力注册表与校验基础

- 新增 `capabilities/registry.json` 和作者规范，能力状态固定为 `draft/pilot/active/deprecated/retired`，ID、卡片、引用和评测映射都有唯一性约束。
- 新增 `scripts/validation/validate-capabilities.ps1`，并接入严格校验、通用 validation fixture 与 `scripts/test-v036-governance.ps1`。
- 能力自测为正常样本 1 个、失败样本 6 个，覆盖重复 ID/卡片、无反触发、非法状态、断链、绝对路径和不存在的 eval。
- 在 `evals/contract-registry.json` 登记 registry schema、卡片单一事实源和最小加载三项治理合同；没有改变既有 85 条稳定、21 条挑战和 34 条触发用例的唯一归属。
- 结果：M1 门禁通过，既有 `validate-skill.ps1 -Strict` 调用方式保持不变。

### 2026-08-17 M2：三张能力卡试点

- 新增三张 `pilot` 卡：Discovery 问题验证、产品数据分析、Strategy/GTM 决策。卡片只声明触发、反触发、输入、输出、证据合同、降级和既有 reference 指针，不复制方法正文。
- `evals/context-budget.json` 增加三条按需装配 profile；两次复算结果一致。
- 默认五入口相对 v0.35 保持零增长：formal 字符仍为 `/review 10206`、`/idea 10578`、`/prd 13260`、`/acceptance 17811`、`/prompt 14057`。
- 三项按需装配 formal 字符分别为 Discovery `31533`、Analytics `36126`、Strategy `32917`；增量都可追溯到明确卡片与 reference，不成为默认常驻负载。
- 定向行为证据复用外部同题面板中的相应正例和控制项。Discovery、Analytics、Strategy 均能在适用场景工作，普通路径未观察到由卡片引起的运行时回退。
- 修正面板中的 EB-01 仍出现统计命名不够精确和无来源压力分。这是 v0.35 既有行为缺口，因为本轮未改 `SKILL.md` 或 reference 行为正文；三张卡保持 `pilot`，不提前升级为 `active`。

### 2026-08-17 M3：12 条外部同题对标（首轮证据，后续验收发现任务合同漂移）

- 新增外部候选与任务事实源、12 份中性 fixture、benchmark validator 和 5 个失败夹具。
- 行为候选为 MyP-M-A、phuryn/pm-skills、product-on-purpose/pm-skills；其余候选只做结构观察。
- 运行协议：`gpt-5.6-luna medium` 单次执行、统一输入与禁用工具边界、并发 3、单任务 5 分钟；`gpt-5.6-sol medium` 匿名分维评分。
- 直接使用 Claude CLI 因缺少 API key 返回 401，改用 Codex Desktop 自带 CLI；首轮 stdin 编码导致输出无效，修正为 UTF-8 后只重试无效样本。最终 36/36 回答有效、12/12 任务具备三候选共同样本。
- 匿名评分结果不生成统一总分：
  - MyP-M-A：正确性 `3.17`、证据严谨 `3.08`、决策清晰 `3.75`、完整性 `3.50`、可执行性 `3.25`、简洁度 `2.75`；平均 `2212` 字符、`39706 ms`、关键失败 1。
  - phuryn：`3.67 / 3.92 / 3.83 / 3.58 / 3.08 / 3.33`；平均 `2102` 字符、`40810 ms`、关键失败 0。
  - product-on-purpose：`3.42 / 3.50 / 3.83 / 3.58 / 3.25 / 3.42`；平均 `2068` 字符、`41833 ms`、关键失败 1。
- MyP-M-A 没有在本轮全面领先。该面板曾暴露范围、评分来源和历史补造风险，但独立验收随后确认任务编号与 PRD FR-007 语义不一致，因此本段只保留为失败历史，不能作为 v0.36 正式外部结论。
- 评分器返回的是语义任务名而非 EB ID，汇总前按运行目录的冻结任务 ID 做机械归一，原始评分字段保留。viewer、benchmark、run notes 和原始回答全部留在仓库外工作区。

### 2026-08-17 M4：公开案例规范与内部 dry-run

- 新增公开案例准入规范、manifest schema、活动/撤回索引和公开案例 validator。
- 未获得真实项目单独公开授权，因此没有复制 QuickRec、LetsMakeMoney 或其他私有材料；改用完全合成的 DeskFlow 导出可靠性案例完成端到端演练。
- 案例 manifest 锁定授权、隐私扫描、人工复核、版本、artifact SHA-256、四条证据定位和撤回审计。
- dry-run 完成 `approved -> withdrawn` 生命周期验证：案例不在活动索引，ID 保留于撤回索引，正文不作为公开案例分发。
- 公开案例自测为正常样本 1 个、失败样本 6 个，覆盖无再分发授权、哈希漂移、敏感绝对路径、撤回后仍在活动索引、证据定位为空和隐私扫描非零。
- 结果：自动扫描与人工复核均通过，公开案例数仍为 0；本轮只证明准入机制可执行，不构成真实案例授权或采用证据。

### 2026-08-17 M5：候选收口与独立验收准备

- 将版本元数据更新为 `0.36.0`，README 与 roadmap 状态标记统一为 `candidate`；v0.35.0 保持远端 Stable 与回退基线。
- 最终严格校验结果：`version=0.36.0`、`skill_chars=5666/5700`、稳定 85、挑战 21、触发 34、合同 56、生命周期组 6、能力卡 3、benchmark 任务 12、行为候选 3、公开案例 manifest 1、撤回案例 1、warnings 0。
- 上下文预算执行两次，除 `generated_at` 外语义完全一致；默认五入口 formal 字符仍为 `/review 10206`、`/idea 10578`、`/prd 13260`、`/acceptance 17811`、`/prompt 14057`。
- 独立工具结果：context budget self-test 6 个样本通过；evaluation pipeline、delivery quality pipeline、通用 validation fixture 和 v0.36 governance self-test 均通过；19 个 JSON 与 21 个 PowerShell 文件解析通过。
- 外部 clone validator 按冻结目录复核通过：候选 6、行为候选 3、任务 12、维度 9。
- 完整工作树审计：新增 39 个文件约 183 KB；没有外部 clone、原始回答、评分中间文件、真实项目案例或大体积二进制进入主仓库。敏感 token/credential 模式扫描无命中。
- 清理仓库外临时产物：删除隔离认证副本、295 MB 临时 Codex CLI 和 5 个 smoke 输出；保留输入、回答、评分、benchmark、viewer、运行脚本与两次最终预算报告。
- 状态：`acceptance_ready`。本轮未提交、未推送、未打 tag、未创建 Release，也未把 Candidate 写成 Stable。

### 2026-08-17 ACC：独立验收与 FR-007 证据修复

- 锁定 `main` 基线 HEAD 与 `origin/main` 为 `c8af239a91043a35d8229746f36cb7f393fb4526`，候选为未提交工作树；运行时相对 v0.35 仅修改 `SKILL.md` 版本号，`references/`、`agents/` 和 `templates/` 无正文变化。
- 第一轮独立验收发现 `evals/external-benchmark.json` 的 EB-01～EB-12 语义与 PRD FR-007 表格不一致，AC-007/M3 不能通过。验收立即停止，没有把旧面板冒充正式证据。
- 新增 `evals/external-benchmark-contract.json`，将 12 条任务逐项绑定 FR-007；manifest 增加 `requirement_id`、`semantic_key` 和 `task_contract`，validator 增加 PRD 行、合同和 manifest 三方一致性检查及语义漂移负例。
- 建立修正工作区 `E:\codex\skill-evals\mypm-v036-external-benchmark-contract-aligned-20260817`。9 条任务与旧提示词语义完全一致，按哈希复用 27 份原始运行；EB-01、EB-10、EB-12 共 9 份回答重新执行。旧评分仅保留在 `legacy-grades`，12 条任务全部由 Sol medium 重新匿名评分。
- 修正面板 36/36 回答、12/12 评分有效。MyP-M-A 六个质量维度为 `3.17 / 3.42 / 3.75 / 3.75 / 3.42 / 2.75`，平均 `2148` 字符、`38491 ms`、关键违规 3；phuryn 为 `3.75 / 3.58 / 3.67 / 3.42 / 3.33 / 3.42`，关键违规 2；product-on-purpose 为 `3.25 / 3.42 / 3.67 / 3.33 / 3.33 / 3.33`，关键违规 4。各维度不合并总分。
- MyP-M-A 未全面领先。EB-08 误把局部异步范围扩大为全部异步；EB-12 补造上一轮验收历史，并改写“待产品负责人决策”状态，共计 3 个关键违规。EB-01 的统计命名/压力分和 EB-10 的列项计数进入次级 backlog。
- `verify-evidence.ps1` 复核 36 份运行、27 份继承、9 份新运行、12 份正式评分、盲评映射、候选快照、外部 commit 和临时产物，结果通过。严格 validator、上下文预算、v0.36 self-test、diff、20 个 JSON、21 个 PowerShell、101 个 Markdown、UTF-8、乱码、链接和敏感信息检查全部通过。
- 结论：治理版本达到 Stable 条件。完整稳定集与挑战集未重跑，外部面板为单次执行/单评分器观察；v0.36.0 标记为 Stable（本地已提交），不自动授权 push、tag 或 Release。

## 关键决策

| ID | 决策 | 原因 | 失效条件 |
| --- | --- | --- | --- |
| D-036-001 | 五入口保持不变，能力卡置于内部能力层 | 避免用户入口膨胀并保持既有习惯 | 真实使用证明用户必须直接调用独立能力 |
| D-036-002 | registry 首轮是治理层，不是运行时硬依赖 | 保证 v0.35 可回退和默认装配零增长 | M2 证明运行时接入有明确收益且用户批准 |
| D-036-003 | 三张试点卡映射既有 reference | 最小成本验证架构，避免同时创造新方法 | 现有 reference 无法表达所需合同 |
| D-036-004 | 外部对标不生成统一总分 | 质量、成本和可靠性不可互相抵消 | 无 |
| D-036-005 | 公开案例先规范和内部 dry-run | 真实项目含隐私、路径和第三方内容 | 授权与匿名化门禁全部通过后可进入后续公开阶段 |
| D-036-006 | 三张能力卡保持 `pilot`，不接入默认运行时 | 默认五入口零增长，外部对标仍发现既有证据缺口 | 独立验收通过且真实使用证明按需卡片稳定 |
| D-036-007 | M4 使用完全合成案例 | 没有真实项目的单独公开授权，合成材料足以验证治理生命周期 | 后续取得逐项授权并重新通过隐私与证据门禁 |

## Bugfix 摘要

| 问题 | 影响 | 修复方式 | 验证结果 | 是否阻塞发布 |
| --- | --- | --- | --- | --- |
| PRD validator 目录与仓库现有结构不一致 | 实施会新增第二套脚本目录 | 改为 `scripts/validation/` 并统一测试脚本命名 | 路径审计通过 | 已关闭 |
| benchmark runner 首轮 stdin 编码不一致 | 首批执行未落出有效中文回答 | 固定 UTF-8，只重试无效样本 | 36/36 有效 | 已关闭 |
| 评分器任务标识不是冻结 EB ID | 汇总可能无法稳定关联任务 | 以运行目录任务 ID 机械归一，保留原始字段 | 12 组盲评均可追溯 | 已关闭 |
| benchmark 任务与 PRD FR-007 语义漂移 | 旧面板不能证明 AC-007/M3 | 建立机器合同、三方一致性校验、语义漂移负例和修正证据工作区 | 12/12 合同对齐，36/36 运行和 12/12 新鲜盲评可追溯 | 已关闭 |

## Spike / 技术探索摘要

- 外部候选适配已在 M0/M3 完成。无法同宿主公平执行的三个候选仅做结构观察，没有通过转换后输出冒充原项目行为。

## 验证摘要

- 自动化验证：严格静态校验已通过；能力、benchmark 和公开案例正负 self-test 均通过。
- 行为验证：三张能力卡未改运行时正文；相关外部面板提供正例与控制证据，卡片保持 pilot。
- 外部对标：3 个行为候选、12 条任务、36 份回答与 12 组匿名评分均有效；MyP-M-A 未全面领先。
- 人工验证：候选许可/宿主边界、评分映射与合成案例全文已经复核。
- 发布验证：独立 `/acceptance` 通过，v0.36 为 Stable（本地已提交），v0.35 保持远端回退基线。

## 收尾事项

- 下一任务：用户确认后推送 v0.36.0 Stable；tag 与 Release 继续分别授权。
- 本轮只完成本地提交，不推送、不打 tag、不创建 Release。
- 不公开任何 dry-run 案例；三张能力卡保持 `pilot`。
