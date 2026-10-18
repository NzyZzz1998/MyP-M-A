入口判断：/acceptance — 项目身份与维护范围阶段核验
交付模式：team_pm。阶段结论：通过（仅限本记录范围）。整个版本是否可发布：本轮不判断。

# MyP-M-A 本地维护阶段复核

## 核验对象与边界

- 日期：2026-10-17，Asia/Shanghai；文件基线采集时间：2026-10-17T23:21:59.8352128+08:00。
- 项目：`D:\Work\Software\codex_home\.agents\skills\mypm`。
- 上游标准：本轮用户要求；事实源为 `SKILL.md`、`README.md`、`notes/full-thread-maintenance-verification-20261017.md`，发布历史补读 `notes/v0.42-stable-decision.md`。
- 只核验项目定位、实际 Git 身份、版本、默认五入口，以及已有维护、全量回归和发布结论的适用范围。该阶段完成后停止。
- 项目内只新增本文件；保留已有工作区，不新增产品能力、不改版本、不提交、不推送、不打 tag、不创建子任务。

## 身份与证据

| 字段 | 本轮直接证据 |
| --- | --- |
| 定位 | 中文优先的通用产品经理助手 Skill；面向团队协作与 Vibe Coding，安装于 Agent 宿主，不是独立应用或自带模型 |
| 内部标识 / 对外名称 | `mypm` / `MyP-M-A` |
| Git 根目录 | `D:/Work/Software/codex_home/.agents/skills/mypm` |
| 分支 | `test` |
| HEAD | `deecc50b8865c26c73a2dff0ceaae8f66174c64f` |
| Dirty 状态 | 是；开始时 15 个已跟踪修改、15 个未跟踪文件，无暂存变更；不能用 HEAD 单独代表当前候选文件内容 |
| Skill 版本 | `SKILL.md` 的 `metadata.version="0.42.0"`，与 README 版本标识一致；不等于当前维护候选已晋升新 Stable |
| 默认五入口 | `/review`、`/idea`、`/prd`、`/acceptance`、`/prompt`；后者为辅助入口，实施与发布收口属于内部阶段 |
| 交付模式 | `team_pm`、`vibe_coding` 两种；本轮是已授权的小范围验收，不承接实现 |

以下 SHA-256 对应本轮读取的文件字节，避免相同版本号被误认为相同快照：

| 来源 | SHA-256 |
| --- | --- |
| `notes/full-thread-maintenance-verification-20261017.md` | `5c734d29fbcca99fbcca42583961c3b4db2b1520c9a8053c42ef0a46e023960a` |
| `notes/v0.42-stable-decision.md` | `3cf5d34f1024f925bab784c0e63b3c46bc5239c9eb4d9efccc101ee3209805c0` |
| `README.md` | `c244738a783bb1d682435d847165fbfee5b1018713e525be9b8d0c66c5673d51` |
| `SKILL.md` | `a2a67c21824d81ef2533a0bb73a88554c76a58691793e8c2a1cd29e73115c90f` |

## 逐项结论

| ID | 预期与来源 | 实际结果及证据 | 四态结论 |
| --- | --- | --- | --- |
| A-01 | 核对指定路径、实际分支、HEAD、dirty；来源：本轮要求 | 本地 Git 与上述身份一致；工作区已有改动，详细状态附后 | 通过 |
| A-02 | 版本、定位及五入口一致；来源：SKILL、README | 两份材料均为 0.42.0、通用产品经理 Skill、同一组五入口与两种模式 | 通过 |
| A-03 | 已有维护结果不冒充当前全量通过；来源：全线程维护报告 | 报告明确是本地维护候选；首轮 40/41，两次不同快照补测各 4/4，不合并成最终快照 41/41 | 通过 |
| A-04 | 全量与发布结论有适用范围；来源：README、Stable 决定 | 旧全量、各轮定向快照与维护者发布决定分别保留，当前 dirty 候选不继承整版全量通过或发布许可 | 通过 |
| A-05 | 执行 `git diff --check`；来源：本轮要求 | 实际退出码 0，无输出 | 通过 |
| A-06 | 仅非 Strict 静态校验；来源：本轮要求 | 实际退出码 0，version=0.42.0，warnings=0；未传 `-Strict` | 通过 |
| A-07 | 既有项目文件保持原样；来源：本轮要求 | 两项检查后、报告写入前，对基线 275 个文件逐一 SHA-256 比较：修改 0、删除 0、新增 0；报告新增后的最终核对见收尾记录 | 通过 |

本范围无未关闭缺口。未执行范围不计入本轮通过分母，也不作为扩展测试的理由。

## 历史证据的适用范围

| 原证据对象 | 本轮处理与限制 |
| --- | --- |
| v0.42 四模型 medium 全量 | 依据既有记录继承为历史观察：114 条稳定用例、46 条挑战用例，每模型一次有效结果，共 640/640 回答、214/214 匿名评分输入。Stable 决定记录将全量绑定冻结 HEAD `377630d466e990a0120d145d1ed17444580f2658`；本轮未读取全部原始答复、评分或重跑，不升级为当前候选的新测结果 |
| v0.42 Stable 决定 | 2026-09-07 的维护者决定及收口提交 `79646a1658ab603076f37b3b4f33a241faf55672` 为历史状态。B-01 仍是“已接受风险、尚未修复”，R7 独立技术验收未通过，不改写为通过，不自动给后续快照豁免 |
| 2026-10-17 全线程维护 | 报告记录 Astra ultra、首轮 40/41、两题基线与候选各 8/8、两次补测各 4/4；14 个场景运行、17 份有效回合答复。仅对应各次快照及定向范围，非全量、非跨模型回归 |
| 既有静态检查 | 全线程报告中的 258 文件、正文 5688/5700 等是当时快照数据；本轮静态输出为 266 文件、正文 5700/5700，不混用历史计数 |
| README 远端同步措辞 | 顶部维护说明明确后续修改保留在本地；质量章节“main 与 test 已同步远端”按原 Stable 历史理解。当前 dirty 状态不能证明当前文件已同步。本轮未查询远端，远端实时状态待验证 |

历史有效结果不被本轮清零；当前维护候选整体能否发布，以及变更后的行为是否仍满足全部合同，均不在本次判定内。后续如需重开，只依据届时范围和变化核验受影响证据，不自动要求或执行全量。

## 使用工具与实际检查

使用本地 PowerShell 7.6.5、Git、文件读取及 SHA-256 比对；未使用 GitHub/CI、浏览器、GUI 或模型评测服务。按入口合同读取验收、工具、阶段控制及验收模板，不执行模板中的范围外项目。

本轮两项指定验证命令：

```powershell
git diff --check
& 'C:\Users\win\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -File '.\scripts\validate-skill.ps1'
```

非 Strict 校验的实际摘要：

```text
Latest observation evidence: source_bytes=verified external_identity=verified; unavailable means local historical identity only, not external verification.
MyP-M-A static validation passed: version=0.42.0 skill_chars=5700/5700 evals=114 challenges=46 triggers=34 contracts=84 lifecycle_groups=6 capabilities=7 benchmark_tasks=12 behavior_candidates=4 public_cases=1 withdrawn_cases=1 portfolio_cases=194 portfolio_core=9 portfolio_canary=15 files=266 modules=9 warnings=0
```

上述检查在新增本记录之前执行；`git diff --check` 不覆盖未跟踪文件内容，不能替代行为验收。静态输出中的用例、合同及资产数量是校验资产计数，不是本轮执行的模型样本数量。275 是排除 `.git` 后、含本地忽略文件的字节保留基线，266 是校验器自己的扫描计数，口径不同。

项目现有本地配置及适配器 `status` 确认 Memory=auto、diagnostics=local。按已启用模块的既有项目授权执行库外阶段收尾，项目内不添加载荷；该操作不属于新增测试，也不把恢复或单次写回成功扩张为长期可靠性验收。完整阶段回执据实际调用报告。

## 起始工作区状态

```text
 M README.md
 M SKILL.md
 M evals/README.md
 M evals/challenge-evals.json
 M evals/eval-inventory.json
 M evals/evals.json
 M notes/evaluation-history.md
 M notes/mypm-roadmap.md
 M references/development-handoff.md
 M references/memory-integration.md
 M references/prompt.md
 M references/tooling.md
 M references/workflow-control.md
 M scripts/test-v042-governance.ps1
 M templates/progress-template.md
?? .gitignore
?? evals/local-memory-consent-cases.json
?? evals/v042-full-thread-maintenance-evals.json
?? notes/full-thread-maintenance-plan-20261017.md
?? notes/full-thread-maintenance-verification-20261017.md
?? notes/local-maintenance-checkpoint-20261017.md
?? notes/local-memory-diagnostics-pilot-20261017.md
?? notes/prd-authoring-maintenance-pilot-plan.md
?? notes/skill-value-pilot-plan.md
?? references/local-memory-diagnostics.md
?? scripts/mypm_local.py
?? scripts/test-full-thread-maintenance.ps1
?? scripts/test-local-memory-governance.ps1
?? scripts/test_mypm_local.py
?? templates/local-memory-config.example.json
```

这些文件均是本轮开始前已有状态，不计作本轮新增或修复。

## 未验证项与后续边界

- 不跑 Strict、自测脚本、单元测试、其他定向测试或任何模型回归；不新评估历史分数，也不据本轮静态通过宣称泛化收益。
- 不核对远端当前分支、Release、tag 或 CI，不判断当前整版、源码公开或分发产物可发布；便携包、安装器及商店包不属于本轮对象。
- B-01 未修复的历史状态保留；真实 Memory 全生命周期、长期免提醒可靠性等既有未验收项不在本轮扩测。
- 无需额外手动验证文档：本轮身份与范围核对已有直接本地证据，没有点名 GUI 或人工操作路径。
- 本阶段收尾后停止。后续维护、验证或发布须依据后续用户任务推进；本轮不继续下一阶段。

## 收尾记录

2026-10-17 23:24:44 +08:00 已完成新增文件回读与全文件清单比对：基线 275 个既有文件的 SHA-256 全部不变，删除 0；唯一新增为本记录，文件总数 276。分支仍为 test，HEAD 不变；Git 状态为 15 个已跟踪修改、16 个未跟踪文件，比起始状态只多本记录。随后仅在本记录中补入这条收尾结果，未操作已有文件。

阶段执行状态：已完成；本次范围验收：通过；整体版本发布结论：未判断。两项检查无失败，不需要补测或进入下一阶段。
