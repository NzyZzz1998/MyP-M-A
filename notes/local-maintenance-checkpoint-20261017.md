入口判断：/acceptance — 项目身份与维护范围阶段核验

交付模式：`team_pm`。核验日期：2026-10-17（Asia/Shanghai）。

# MyP-M-A 本地维护阶段核验

## 核验对象与阶段结论

**通过：本轮限定的“项目身份与维护范围”已核对，指定两项检查通过。版本整体可发布性：待验证，本轮不作发布判断。**

对象为 `D:\Work\Software\codex_home\.agents\skills\mypm` 当前本地维护工作树。用户本轮指令是验收标准：读取指定事实源，核对实际身份、默认五入口和历史结论适用范围；仅运行 `git diff --check` 与非 Strict 的 `scripts/validate-skill.ps1`；仅新增本记录，完成一个阶段后停止。

本轮不新增产品能力、不晋升版本、不提交、不推送、不打 tag，不创建子任务，不继续下一阶段。已有 dirty 文件是执行前状态，不计为本轮修改。

## 当前身份

身份取证时间：2026-10-17 23:01:33 +08:00。环境为 Windows、PowerShell Core 7.6.5。

| 字段 | 实际值 | 证据 |
| --- | --- | --- |
| 项目名称 / 内部标识 | MyP-M-A / `mypm` | `SKILL.md` frontmatter 与 README |
| 定位 | 中文优先的通用产品经理 Skill，支持团队协作与 Vibe Coding | `SKILL.md`、README |
| 当前分支 | `test` | `git branch --show-current` |
| HEAD | `deecc50b8865c26c73a2dff0ceaae8f66174c64f` | `git rev-parse HEAD` |
| 工作树 | dirty；执行前 15 个已跟踪文件修改、14 个未跟踪文件；暂存修改 0 | `git status --porcelain=v1 --untracked-files=all`、`git diff --cached --stat` |
| Skill 版本 | `0.42.0` | `SKILL.md` 的 `metadata.version` |
| README 发布标签 | `v0.42.0 Stable`，同时明确本地维护候选尚未重跑全量或晋升新 Stable | README 顶部维护状态及质量边界 |
| 正文预算 | `5696/5700` | 本轮非 Strict 静态校验输出 |
| 本地 upstream 展示 | `test...origin/test` | `git status --short --branch`；只反映本地跟踪信息，不证明实时远端同步 |

默认五入口在 `SKILL.md` 路由表与 README 中一致：

| 入口 | 当前职责 |
| --- | --- |
| `/review` | 理解现状、建立项目地图、发现问题 |
| `/idea` | 判断问题与需求的真实性、价值和时机 |
| `/prd` | 收敛方案，形成需求定义或原型验证合同 |
| `/acceptance` | 依据实际证据验收实现、候选产物或发布状态 |
| `/prompt` | 辅助交接；不是第五个产品阶段 |

实施、Bugfix、开发承接和发布收口为内部阶段；本轮未增加入口。两种交付模式仍为 `team_pm`、`vibe_coding`，默认 `delivery_mode=auto`。

## 工具与证据来源

- 本轮真实调用：本地 PowerShell / shell；用 `Get-Content`、`rg` 读取与定位文档，用 Git 查询身份与差异，用 `Get-FileHash -Algorithm SHA256` 固定来源及比对既有文件。只读身份取证与文件回读不计作测试套件。
- 主要事实源：[SKILL.md](../SKILL.md)、[README.md](../README.md)、[全线程复盘维护验证](full-thread-maintenance-verification-20261017.md)。补充读取[Stable 决定](v0.42-stable-decision.md)以定位原全量冻结身份与风险接受范围。
- 流程依据：`references/acceptance.md`、`references/tooling.md`、`references/workflow-control.md` 和 `templates/acceptance-template.md`；按本轮小范围压缩记录。
- 没有调用 GitHub / CI、浏览器、Computer Use、Memory 写回或模型评测工具；没有运行 Strict 自测或其他测试套件。宿主注入的历史记忆不作为当前事实或新增授权来源。
- 历史报告的成绩在下节只作范围核对，不冒充本轮重测。本轮没有重新审计全部历史回答、评分及仓库外证据包。

主要来源在本轮读取时的 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `SKILL.md` | `CFAE856A956AC2E1C5A6F6F0DA926D331C9644CF8A555E70397DF56CCA4CB3B5` |
| `README.md` | `9D7E59A5B88261742F5EFBDC2EF1E45B4B0A787785A9609041243671FA8CC2E3` |
| `notes/full-thread-maintenance-verification-20261017.md` | `5C734D29FBCCA99FBCCA42583961C3B4DB2B1520C9A8053C42EF0A46E023960A` |
| `scripts/validate-skill.ps1` | `508FADCF70265F27C1A284ECAF4684BC1AE2A7CA317EDA1FC14D0D1658D9E167` |

## 历史结论的适用范围

| 历史证据对象 | 原记录与范围 | 本轮处理及不得外推的结论 |
| --- | --- | --- |
| v0.42 四模型 medium 全量 | Stable 决定记载冻结分支 `test`、HEAD `377630d466e990a0120d145d1ed17444580f2658`；114 条稳定用例、46 条挑战用例 × 4 模型，640/640 有效回答，214/214 匿名评分输入；34 条触发用例未在该轮模型重跑 | 保留为原冻结对象的历史证据。有效返回不等于正确回答，资产数量不等于本轮执行数量；不移植为当前 dirty 工作树全量通过 |
| v0.42 Stable 决定 | 2026-09-07 维护者接受 B-01 已知风险后决定晋升；Stable 收口提交 `79646a1658ab603076f37b3b4f33a241faf55672`；记录中的 tag 固定于后续状态提交 `15d65a90c047ac7858e0df72eed3aac57108abad` | 发布决定、全量冻结提交与当前 HEAD 是不同身份。原独立技术验收未通过仍保留；B-01 为已接受风险、尚未修复。历史授权不扩展到本轮提交、推送或发布 |
| 已提交前五项维护 | README 与全线程记录记载 I-01～I-05 已推送 `test`，对应 `deecc50`；两批定向检查分别 23/23、44/44 | 当前本地 HEAD 与该记录一致。推送状态只作为历史记载，本轮未查实时远端；这两批分数不是全量回归成绩 |
| 八项全线程复盘维护 | 报告结论为本地维护候选、可进入维护者复核；Astra ultra 定向观察首轮候选 40/41、基线两题 8/8；后续两次不同修订快照分别补测 4/4、4/4 | 只核对报告的范围声明，不重跑。不得拼接为“最终快照全量 41/41”，也不证明当前全部本地改动已通过行为验收 |
| 该批次机械与静态证据 | 报告记载机械检查 52/52、补测文件检查 7/7，以及当时的严格静态/自测结果；格式转换只做 HTML 正文解析 | 保留历史范围；不继承为本轮 Strict、GUI、跨宿主或模型运行结果 |

历史身份差异已显式保留：全线程报告当时记载 `SKILL.md` 不变、正文 `5688/5700`；本轮工作树显示 `SKILL.md` 已修改、正文 `5696/5700`。该报告描述的是当时维护批次，不能据其“未修改”声明覆盖后续本地维护状态。本轮不裁定后续变更的功能质量。

README 的“main 与 test 已同步远端”位于历史发布说明中，需结合顶部的维护状态与冻结快照限制理解；本轮没有 fetch 或查询远端，不能据此声称当前 dirty 工作树已同步、两分支当前相同或当前维护候选可发布。

## 本轮两项实际检查

两项均在本记录创建前执行，退出码均为 0；记录随后单独落盘回读。

| ID | 命令与预期 | 实际结果 | 四态结论 / 证据关系 |
| --- | --- | --- | --- |
| C-01 | `git diff --check`；检查当前 Git 差异的空白问题 | 无输出，exit code 0 | 通过 / 新测 |
| C-02 | `pwsh -NoProfile -File .\scripts\validate-skill.ps1`；不传 `-Strict` | 静态校验通过，warnings=0，exit code 0 | 通过 / 新测 |

C-02 原始摘要：

```text
Latest observation evidence: source_bytes=verified external_identity=verified; unavailable means local historical identity only, not external verification.
MyP-M-A static validation passed: version=0.42.0 skill_chars=5696/5700 evals=114 challenges=46 triggers=34 contracts=84 lifecycle_groups=6 capabilities=7 benchmark_tasks=12 behavior_candidates=4 public_cases=1 withdrawn_cases=1 portfolio_cases=194 portfolio_core=9 portfolio_canary=15 files=265 modules=9 warnings=0
```

脚本输出中的用例、合同与文件数是静态资产统计；`source_bytes` 与 `external_identity` 是脚本内对应观察源的核对结果，不表示本轮审计了全部历史证据。`files=265` 是新增本记录前的校验扫描口径。C-01 不覆盖未跟踪文件内容；本记录以实际落盘回读确认，未将其冒充受 Git diff 检查覆盖。

## 逐项验收结论

| ID | 预期 / 标准来源 | 实际结果与证据 | 结论 |
| --- | --- | --- | --- |
| A-01 | 用户要求核对真实项目身份 | 本地 Git 给出 `test` / `deecc50b8865c26c73a2dff0ceaae8f66174c64f` / dirty，详见身份表 | 通过 |
| A-02 | 用户要求核对 Skill 版本与默认五入口 | 当前文件版本 `0.42.0`；两个事实源的五入口一致 | 通过 |
| A-03 | 用户要求明确已有全量回归适用范围 | 已区分原冻结全量、分批定向及本轮静态，不合并成绩、不迁移候选身份 | 通过 |
| A-04 | 用户要求明确发布结论适用范围 | 已保留 B-01 风险接受与原技术未通过；当前维护候选不获得新 Stable 或发布结论 | 通过 |
| A-05 | 用户只允许两项检查 | C-01、C-02 实际通过；没有运行其他测试或模型回归 | 通过 |
| A-06 | 用户仅允许新增本记录，保留已有文件 | 272 个既有文件逐一哈希一致，唯一新增为本记录；分支、HEAD 及原 dirty 项保持不变，详见下一节 | 通过 |

## 文件边界与回读

执行前通过 `git ls-files --cached --others --exclude-standard` 枚举并计算 272 个既有文件的 SHA-256；这是保留已有内容的比对基线，不是测试套件。该口径不含 Git 元数据或被忽略文件。

2026-10-17 23:04:13 +08:00，落盘后回读本记录，并重新读取 Git 身份、状态和文件哈希：272/272 个既有文件字节一致，既有文件变化 0、缺失 0，新增文件仅 `notes/local-maintenance-checkpoint-20261017.md`。原 29 条 dirty 状态完整保留，新增状态只有 `?? notes/local-maintenance-checkpoint-20261017.md`；因此结束时为 15 个已跟踪修改、15 个未跟踪文件、暂存修改 0。分支仍为 `test`，HEAD 仍为 `deecc50b8865c26c73a2dff0ceaae8f66174c64f`。

随后仅将上述回读结果补入本记录，A-06 收口为通过。**任务执行状态：已完成；本阶段验收：通过；版本整体验收：待验证。** 没有把未验证的版本级事项计作本阶段缺口，也没有把本阶段通过扩大为发布结论。

## 未验证项与停止边界

- 当前维护候选的模型行为全量、其他测试、Strict 自测、真实 GUI、异常路径、跨宿主运行及 Memory/诊断功能均暂不验证；已有历史结果按原对象保留。本轮范围不需要额外手动验证文档。
- 实时远端 `main` / `test`、tag、Release 与 CI 状态未查询；不作远端同步声明。
- 当前版本整体可发布性保持待验证；本轮小范围核验通过不代替版本验收，不新增发布豁免或义务。
- 后续若另行验收，应重新锁定对应工作树、变更范围和必要证据；相关对象变化时只重开受影响项。此处是后续边界记录，不启动后续工作。
- 本阶段以本记录落盘回读和简短汇报为收尾。任务完成后停止，不继续维护、修复或发布；提交、推送、tag、Release、上传及可见性变更均暂不执行。
