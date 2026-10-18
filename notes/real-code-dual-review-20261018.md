# 本轮未提交代码双方法审查与依赖补装

## 结论与身份

- 对象为 MyP-M-A 自身，不是业务项目。delivery_mode=vibe_coding；分支 `test`，HEAD `deecc50b8865c26c73a2dff0ceaae8f66174c64f`。
- 原审查快照 SHA-256：`4ee4f5008c920e68ec958ee230572a95b8ef5452bff74adbf4d26e26ef288958`；包含 46 个未提交差量，未漏掉 untracked，暂存/提交差量为空。
- 实际代码范围 10 文件：3 个 Python 实现、3 个 Python 测试、4 个 PowerShell 测试。其他 36 项文档/清单只作最小背景，不宣称逐项业务内容审计。
- Matt 本地两轴适配 + 真实 Alibaba OCR v1.13.1 delegate 规则；当前 Agent 串行完成两遍，共享上下文，**非独立双模型审查**，无外部模型请求、无子 Agent。
- 去重后 5 项 P2 均有定向复现。审查批次保留发现、没有同时修订三个已审实现；后续最小修复及反例回归见[维护迭代收口](iteration-completion-20261018.md)。以下原报告、行号与结果均属于修复前身份，不被新增安装器测试或修复通过抵消。

## 已确认发现

| ID / 来源 | 定位 | 可达问题与影响 | 最小修复与回归 |
| --- | --- | --- | --- |
| DR-01 / Matt Spec | `scripts/provider_routing.py:162` | completed_providers 仅含名称就可返回 reuse，没有核对问题/对象快照；可能继承别的对象或旧代码的审查结果 | 引入问题和快照绑定的完成凭据；缺身份、快照变化、另一问题不得复用；同对象重复可复用 |
| DR-02 / Matt + OCR | `scripts/mypm_local.py:31`、`:277` | 常见 JSON 的带引号 password 键绕过凭据正则，虚构密码测试写入后返回 written_verified | 补常见结构化键格式拦截与 JSON/Markdown 用例，保持隐私人工核对，不宣称通用 DLP |
| DR-03 / Matt + OCR | `scripts/mypm_local.py:298` | provider 已写入后回读失败，与写前失败同样返回 memory_unavailable，无法确定“未写”还是“已写待核对” | 显式保存写入阶段与 outcome_unknown；写后超时/读回不符先核对现状，禁止盲重试 |
| DR-04 / Matt + OCR | `scripts/review_snapshot.py:82` | 未配置可选 core.filemode 时 Git 返回 1，冻结助手因此拒绝合法仓库 | 使用 Git 配置缺省值；覆盖 absent/true/false，不能吞掉其他 Git 错误 |
| DR-05 / OCR | `scripts/review_snapshot.py:314` | {} 等任意可解析 JSON 被称为 rules_loaded，缺少规则 schema/内容/请求文件覆盖核对 | 验证实际版本合同，保留未覆盖文件；空/缺项/错版响应不得称对应规则已取得 |

DR-02/03 使用合成 Memory provider，未向真实个人记忆写凭据；DR-04 使用真实临时 Git 仓库；DR-05 使用明确标注的模拟异常响应，本机真实 OCR 返回有效规则。复现证明错误路径存在，不代表这些异常已在真实业务里发生。

没有正式严重级别标准时这里的 P2 表示应在发布前正常修复的明确缺陷，不将启发式建议上升为新的产品门禁。初始 Matt 4 项、OCR 4 项，3 个根因重复，合并为 5 项；不因两方法同时命中而加重等级。

## 覆盖与补读

快照启发式将四个 Python 文件排除为 sensitive_content：两项是凭据检测正则本身，两项是虚构测试字符串。原 manifest 不修改；自动覆盖报告保留 6 reviewed、40 skipped（其中 36 非本轮代码范围），另列 4 项人工补读，均核对原文件字节 SHA 与快照一致。没有把 skipped 填成 reviewed，也没有关闭默认隐私防护。

审查结束、开始新功能前 freshness 为 true。OCR 原始规则、Matt 原报告、OCR 原报告和复现独立保留；后续补装改动使完整旧快照失效，旧报告只对应原代码身份。新安装器单独做代码检查与定向测试，不能冒称已纳入初始双审。

## 已批准增量：固定依赖补装

用户另行确认：默认关闭；一次授权后，在升级首次使用时检索并安装已登记固定来源的缺失 Skill；不自动装 CLI、不配置凭据、不覆盖已有 Skill。

- 新增 `capabilities/dependency-lock.json`、`scripts/provider_dependencies.py`、`scripts/test_provider_dependencies.py` 与 `references/provider-dependencies.md`。
- 修改 SKILL 工具导航、README、专项路由合同和忽略清单；不改五入口、业务项目模式、Memory/诊断开关或宿主 hooks。
- 两项旧 pilot 从 Matt 固定 `6acc160e4e0cd062dbbbd7a1b26ae92855edf07e` 下载，保留 MIT；确定性适配后哈希与既有 registry 一致，保留显式调用策略。新依赖或包指纹变化须再次确认。
- 每个依赖独立结果，已存在/漂移不覆盖；失败不无限重试；授权撤回停止后续操作。安装成功不等于宿主暴露或调用成功。
- 触发是 Skill 正文约定的首次使用动作，不是更新后的后台自动执行。Python/文件能力缺失只降级，不强装环境。

## 验证记录

仓库外证据目录：`E:/codex/skill-evals/mypm-real-dual-review-20261018`。

- `matt-original.md` / `ocr-original.md`：原报告。
- `frozen/manifest.json`、`review-end-freshness.json`：冻结范围与审后身份。
- `ocr-rules.json`、`ocr-manual-supplement-rules.json`：真实 CLI 原规则。
- `reproductions.json` / `reproduce.py`：5 项最小复现与人工补读哈希。
- `dependency-live-install.json`：首轮隔离安装 2/2、适配探测 ready，第二次不联网。
- `dependency-live-install-final-first-failure.json`：最终脚本复验首次为 partial，领域包失败且未创建目录，问卷包成功。原错误只包含汇总原因，不能确定是网络、身份还是其他前置错误；保留失败，不改写成首次全过。随后补充 failure_phase/error_type 与白名单 error_code 便于定位。
- `dependency-live-install-final.json`：一次显式重试只下载缺失领域包的 4 个文件，问卷包未重装；结果 2/2 ready，第二次不联网。没有覆盖本机两个已有 pilot，没有启用本机自动补装。该次网络恢复不证明失败根因已定位。
- `test_provider_dependencies.py.txt`：首轮 20 项，补充非法配置、过大已有文件与隐式调用策略保护后 23 项通过。路由 27、Memory/日志 36、快照 33 项也通过，合计 119 项定向单测；它们未覆盖原 5 项已复现错误，不把绿灯当作无缺陷证明。
- 严格静态通过，warnings=0；SKILL 5697/5700；上下文工具、git diff --check 通过。最终解析、覆盖统计和文件身份见 `final-verification.json`，不把工具夹具计为模型得分。

本审查批次无完整模型回归、无 commit/push/tag/Release。跨宿主的新会话触发、不同网络与平台尚未验证。DR-01～05 的后续修复与新测单独记录，不更改原始证据或将当前候选冒称已完成全量比较。
