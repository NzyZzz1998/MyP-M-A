# MyP-M-A v0.37 开发日志

> 本文记录开发过程、关键决策、异常处理和验证结果。`notes/progress_v0.37.md` 只保留状态看板和最小任务 checklist。

## 基本信息

- 版本：MyP-M-A `v0.37.0`
- 对应 PRD：`notes/v0.37-fact-fidelity-prd.md`
- 对应 dev plan：`notes/dev_plan_v0.37.md`
- 对应 progress：`notes/progress_v0.37.md`
- 当前阶段：两轮证据治理整改、受影响路由回归和最终独立验收完成；v0.37.0 Stable（本地待提交）
- 稳定回退基线：`v0.36.0`，远端 HEAD `83e619c7ef7cd31cb782f142fa4b5ad65f01c115`，运行时提交 `4bf426c4be8ed2781d660632870a7b2c089c6365`

## 开发记录

### 2026-08-17 PRD 确认与开发承接

- 本轮目标：确认 v0.37 范围，隔离 v0.36 Stable 提交，并生成开发承接文档。
- 改动模块：v0.37 idea pool、PRD、dev plan、progress、dev log、roadmap 和 backlog。
- 关键实现：把 PRD 的 M0～M5、FR-001～FR-007 和 AC-001～AC-015 转为 21 个最小开发/验收任务。
- 遇到的问题：v0.36 Candidate/Stable 文件与 v0.37 idea/PRD 同处未提交工作区，存在混入同一提交的风险。
- 处理方式：先只暂存 v0.36 已验收文件并创建独立提交 `4bf426c`；v0.37 文件保持工作区未提交。
- 已验证：v0.36 提交前 `validate-skill.ps1 -Strict` 和 cached diff 检查通过；提交后 HEAD 与 v0.37 未跟踪文件边界清晰。
- 未验证/待补证：v0.37 的运行时规则、内部失败用例、模型回归和 Candidate 面板均未执行。
- 关联 bugfix/spike：无。

### 2026-08-17 M0：冻结 v0.36 基线

- 本轮目标：同步 v0.36 到远端，并冻结 v0.37 后续比较所需的 Git、运行时、入口预算、任务合同和正式证据身份。
- Git 身份：
  - 分支：`main`。
  - HEAD 与 `origin/main`：`83e619c7ef7cd31cb782f142fa4b5ad65f01c115`。
  - commit tree：`b87d9ec51399348f6e7c9cea1c60587205fe587d`。
  - 稳定运行时提交：`4bf426c4be8ed2781d660632870a7b2c089c6365`。
  - 推送结果：先执行 `c8af239..4bf426c main -> main`，再以纯状态提交执行 `4bf426c..83e619c main -> main`；GitHub 连接器可读取运行时提交。
- 运行时文件 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `SKILL.md` | `248c4f90e0a48963af5990cea9536449b52de6dc593a552066b623e53bb1fbf8` |
| `references/prd.md` | `5341f737ee788bbb2b7da7c4d279aea604bb35ad1d91205ddd981091a0019611` |
| `references/prompt.md` | `e9334ef2ef7c5795020e00a8c6acdaef070cff15aa0818205ea688e0c5af5850` |
| `references/acceptance.md` | `4afe8814977a2ef8a773cb66cb5f066be4fa89bece641b680e224a11813e5237` |
| `references/idea.md` | `3475f55c04b628da0ed3d32e4702e6da203fb0f100f191035a7c0ffc51b201df` |
| `references/intent-implementation-audit.md` | `5be45222c00cd807e3b086914eee9e4af13ecd919cbcc01975df0b54ae2454b0` |

- 运行时聚合：6 个文件、56011 字节，聚合 SHA-256 为 `5026c38f67185231bd7a2cfbb42799bcc62f54f87168ed650447b68feb356743`。
- 上下文预算：

| 入口 | minimum | formal |
| --- | ---: | ---: |
| `/review` | 8781 | 10206 |
| `/idea` | 9252 | 10578 |
| `/prd` | 11231 | 13260 |
| `/acceptance` | 16171 | 17811 |
| `/prompt` | 12492 | 14057 |

- `SKILL.md` 为 5666 字符；heavy formal 平均降幅为 32.99%，测量状态为 `target_met`。
- 任务与证据冻结：
  - `evals/external-benchmark-contract.json` 与 12 个 fixture 共 13 个文件、10116 字节，聚合 SHA-256 为 `cc107f9d7ff7814a8a9122a2d509d2c9166d662bd86495d68b3e4509094c8169`。
  - 正式证据目录 `E:\codex\skill-evals\mypm-v036-external-benchmark-contract-aligned-20260817` 共 321 个文件、2236319 字节，聚合 SHA-256 为 `d1bdac0ea21dec64dfbffe0fbd43fb222dbf24bdc5d5b6d7cc4097f1aa8124bb`。
  - 聚合算法：按冻结的六文件清单顺序，将相对路径与每个文件 SHA-256 以制表符连接，行间使用 LF，再对 UTF-8 字节计算 SHA-256。
- 已验证：本地与远端 SHA 一致；工作区变化仅为 v0.37 文档及其 roadmap/backlog 状态；运行时、eval 和 scripts 无差异。
- 未验证/待补证：内部失败夹具、合同映射、自测和所有模型行为门禁。
- 回退点：M0 只新增事实记录，不改变运行时；v0.37 可直接回到远端状态基线 `83e619c`，运行时内容基线仍为 `4bf426c`。

## M1 失败用例与治理接缝

- 新增 7 条稳定用例（86～92）和 4 条挑战用例（CH-22～CH-25），覆盖 F1～F7、范围阈值、意图实现分类、历史/责任人继承、N1～N4 与摘要计数。
- 新增 6 份合成 fixture；不含真实项目、凭据、Memory 原文或私有日志。
- 所有新增用例均通过 `contract-registry.json` 唯一归属，未与 lifecycle 场景组交叉。
- 新增 `scripts/test-v037-fact-fidelity.ps1` 并接入 Strict，自测含 3 组正例与 3 组反例。
- 红灯证据：旧运行时执行专用自测时首先失败于 `PRD range fidelity contract is missing: add`，证明范围差异合同尚未实现；该失败将在 M2～M5 逐批关闭。
- 回退点：撤回新增 eval、fixture、合同映射和 v0.37 自测即可，不影响 v0.36 运行时与正式外部证据。

## M2 `/prd` 范围门禁

- 在 `references/prd.md` 明确 preserve/add/expand/reduce/remove/reopen/transition 七类变化；未经授权的范围变化只记录为候选或冲突，不进入正式范围。
- 将 `> 50000` 异步与 `<= 50000` 既有同步路径写成同一范围事实，避免只实现条件一侧后把补集写成待确认或全部异步。
- 在 `references/intent-implementation-audit.md` 区分一致、实现偏离、批准后的文档过期、未验证、待确认、范围外变化和不适用。
- EB-08 第一轮仍出现一次小任务同步边界不稳，四份旧输出移入仓库外 `discarded/EB-08-round1/`；规则局部收敛后再进入正式 P0。
- 回退点：只撤回 PRD 与意图实现对照改动；M1 失败用例继续保留。

## M3 历史与状态继承

- `/prompt` 与 `/acceptance` 继承对象、原状态、证据来源、时间/新鲜度、失效条件和决策责任人；未提供历史写“未提供”，不自动补齐。
- 保留失败、待补证、暂不验证、已接受风险和待负责人决定等状态；同源新证据可触发 transition。
- 12 条面板首轮 EB-11 把对象不明的“权限变化”解释为目录 ACL，构成控制项关键回退。旧回答和旧评分保留在仓库外 `discarded/`。
- 只在 `references/acceptance.md` 增加未知权限对象保护后重跑 EB-11；新回答保留原词、标记待验证，Sol medium 独立重评为正确性 4/4、关键违规 0。
- 回退点：只撤回 prompt/acceptance 局部规则；不改写其他入口。

## M4 数值来源与一致性终检

- `/idea` 区分 N1 已确认业务事实、N2 可复算结果、N3 内部启发式和 N4 建议阈值；缺少分母或时间窗时不生成比例。
- 明确证据已经直接证明高价值问题时可跳过压力测试总分，但必须写明证据与原因。
- `SKILL.md` 终检增加事实、范围、状态、数字与摘要机械一致性检查；不以压缩删除正式 PRD、Review 或 Acceptance 承重合同。
- 入口预算没有增长，控制任务没有出现关键回退。
- 回退点：只撤回 idea 与终检改动。

## M5 Candidate 面板与独立验收

- 已评测 Candidate：基线提交 `83e619c7ef7cd31cb782f142fa4b5ad65f01c115` 加本地差量；六文件运行时 SHA-256 为 `88bce7001c8500f67f4c0c290569a3a78cb6aaa3c969c062a71aee32f31135dd`。
- P0：EB-08、EB-12 各执行 Sol medium 三次和 Luna medium 一次，8/8 有效样本，关键违规 0。
- 面板：Luna medium 对 EB-01～EB-12 各执行一次，12/12 有效；Sol medium 匿名评分为正确性 46/48、证据纪律 48/48、决策清晰度 48/48、完整性 44/48、可执行性 44/48、精炼度 39/48。
- 面板最终关键违规为 0。回答合计 24370 字符，平均 2030.8，中位数 1785；运行器未暴露逐任务时长，时长保持 unavailable。
- 评测证据保存在 `E:\codex\skill-evals\mypm-v037-fact-fidelity-20260817`。无效和废弃轮次保留，不覆盖失败历史，也不计入最终分数。
- 版本晋升只修改版本与状态元数据；晋升后本地 Stable 六文件运行时 SHA-256 为 `291b348486f05f2a2d2d7fc7019de8aac2e353d6546386d793b18d6435d02a5b`，行为正文未再改写。
- 首轮独立 `/acceptance` 未通过：内部发布面板未执行、Candidate/任务冻结未机械复算、报告脚本硬编码结论、两处兼容脚本未登记影响范围。版本状态恢复为 Candidate，未用已有面板掩盖缺口。
- 整改后增加 Candidate/任务冻结正反例自测、动态生成面板汇总与 execution manifest、补登记 PowerShell 5.1 兼容脚本范围，并执行 54 条受影响路由 Candidate 回归。
- 受影响路由回归 54/54 有效，首轮 440/459；16 个失败用例无提示重试一次后为 448/459。9 个用例仍有 11 条完整性/格式断言缺失，事实、范围、历史、状态和数值关键违规为 0。未执行 v0.36 配对输出，不宣称版本胜负。
- 后续两次独立只读复核指出：已评测 Candidate 快照未由自测直接读取，内部回归报告仍硬编码首轮分数、重试数和关键违规数。现已增加真实快照核验与漂移反例，并由原始评分和逐条关键性分类动态生成报告；六个行为运行时文件未改变。
- 最终独立 `/acceptance` 复验确认 AC-001～AC-015 全部通过，可晋升 Stable。完整稳定集与挑战集未重跑，不宣称跨模型全面领先。
- commit、push、tag 与 Release 均未授权或执行。
- 首轮最终 Strict 在 Windows PowerShell 下把无 BOM 的 UTF-8 中文自测脚本按本地代码页解析，误报 `test-v036-governance.ps1` 语法错误。静态解析改为先用严格 UTF-8 读取再调用 `Parser.ParseInput`；直接执行仍受 PowerShell 5.1 解码影响，因此将该脚本中的合成展示文本等价改为 ASCII，测试字段、正反例和断言语义不变。
- `test-v037-fact-fidelity.ps1` 必须直接断言中文运行时合同，因此保留中文并写入 UTF-8 BOM，确保 Windows PowerShell 5.1 与新版 PowerShell 的直接执行结果一致。

## 关键决策

| 决策 | 背景 | 取舍 | 影响范围 | 后续观察 |
| --- | --- | --- | --- | --- |
| v0.36 与 v0.37 分离提交 | 两个版本文件同时存在 | 多一步本地提交，换取可靠回退 | Git、版本状态 | M0 再冻结运行时哈希 |
| 采用入口局部合同 + 统一终检 | 外部面板暴露共同根因 | 避免新增通用推理层和默认上下文 | 五入口 reference | 观察是否机械复述 |
| 先失败用例后改运行时 | 防止只针对示例堆规则 | 增加 M1，但能证明旧缺口与新修复 | eval、validator | 控制项不得回退 |
| 分批停点与独立回退 | `/prd`、继承、数值问题可分离 | 执行稍慢，定位更清楚 | M2～M4 | 每批测预算与控制 |
| 不以统一总分放行 | 关键事实错误不能平均 | 报告维度更多，但结论更可信 | M5 评测报告 | 保留关键违规清单 |

## Bugfix 摘要

已关闭两项定向问题：EB-08 小任务同步边界不稳定；EB-11 将对象不明的权限变化具体化。旧失败证据均保留，修复只修改对应入口合同并经过定向复验。

## Spike / 技术探索摘要

当前无技术 spike。本版不引入新的推理层、服务、数据库或外部工具依赖。

## 验证摘要

- 自动化验证：v0.37 专用 self-test、严格静态校验、上下文预算、JSON/PowerShell/UTF-8/乱码/链接与差异检查已通过；最终独立复验在 Windows PowerShell 5.1 下再次通过。
- 行为验证：P0 跨模型定向、一次 12 条 Candidate 面板和 54 条 Candidate-only 受影响路由回归完成；完整稳定集与挑战集未重跑。
- 手动验证：已核对 PRD、dev plan、progress、运行时 diff、候选身份、废弃 lineage 和版本边界。
- 打包验证：不适用；Skill 不生成桌面发布包。
- 未覆盖项：完整稳定集与挑战集、多强度或更多模型面板；这些不属于本版既定门禁。

## 收尾事项

- 文档同步：README、CHANGELOG、evaluation history、roadmap、backlog、PRD、dev plan、progress 和 dev log 已统一为“v0.37.0 Stable（本地待提交）”。
- 发布说明：CHANGELOG 已记录 Stable 事实；未创建 tag 或 Release。
- 回滚方式：撤回当前未提交 v0.37 差量即可回到远端 `83e619c`；不得改写 v0.36 历史。
- 下一阶段建议：由用户决定是否创建独立提交并推送，tag 与 Release 仍分别授权。
