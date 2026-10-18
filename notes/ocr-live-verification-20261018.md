# OCR 本地安装与真实双方法复验

## 范围与身份

- 用户授权：本地安装 OCR，继续验证 Matt + OCR 双审；不全量回归、不提交、不推送。
- delivery_mode=vibe_coding；仅 MyP-M-A 适配及合成夹具，不修改业务项目。
- 本次模式为 `dual-method`：当前 Agent 串行使用两种方法，不独立、不盲测，不启动子 Agent 或外部模型。OCR delegate 提供真实文件选择与规则，代码判断仍由当前 Agent 完成。
- MyP-M-A 分支 `test`，HEAD `deecc50b8865c26c73a2dff0ceaae8f66174c64f`；保留全部既有未提交改动，版本仍为 0.42.0。
- 上游 [v1.13.1](https://github.com/alibaba/open-code-review/releases/tag/v1.13.1) 对应 `8eb83340a487b1150af00701b94f01af97e4b4d6`，与上一轮锁定来源一致。使用官方 Windows amd64 Release 二进制，不安装 npm 包或自动更新器。
- 实际安装位置：当前用户既有 PATH 目录 `C:/Users/win/.local/bin/opencodereview.exe`；安装文件与校验清单保留在 `E:/codex/tools/open-code-review/1.13.1`。本机命令名为 `opencodereview`，适配器已能自动发现；没有修改系统/用户 PATH、覆盖同名文件或配置凭据。

## 验证计划与停止条件

1. 比对官方 Release digest、sha256sum.txt 与下载文件，失败则不运行。
2. 实际执行版本、delegate 帮助、provider probe 与显式双方法前置检查。
3. 复用上一轮冻结快照 `9a5089308d985ccd1d1e3ff5dd4cdc5a9176bc1cec9d3e14916ccb13c472785f`；审前/后核验一致。Matt 原报告不改写，单独记录本次复核与继承身份。
4. 真实 OCR workspace preview 与冻结的 unstaged/untracked 清单逐项比对，范围预览只作交叉核验；调用真实 delegate rule 并读取返回的全部规则。
5. 依据冻结源文件检查，保存 OCR 原报告与覆盖报告，再核证、去重、解释方法差异。规则加载成功不等于审查完成，合成缺陷发现不等于产品验收通过。
6. 只验证本地适配、来源、报告、覆盖和格式；缺依赖、范围变化或需要外发则停止相关步骤。独立双审与全量回归继续不做。

证据目录：`E:/codex/skill-evals/mypm-ocr-live-20261018`。历史首次缺 CLI 的结果见[三批增量](routing-integration-20261018.md)，不回写为首次成功。

## 实际结果

**通过本地双方法链路补验，不是独立双模型审查。** OCR 提供真实 CLI 范围与规则，Matt 为现有本地两轴方法适配；两份代码判断均来自当前 Agent。原始报告分别保存，再由 MyP-M-A 核证去重。

| 检查 | 实际结果 | 边界 |
| --- | --- | --- |
| 安装身份 | `open-code-review v1.13.1 (8eb8334) windows/amd64`；官方 digest 与校验清单均一致 | 未安装宿主插件或外部模型后端 |
| 提供者探测 | 已发现 opencodereview.exe，help 成功；dual-method plan=ready，agent_budget=0 | ready 只是前置检查，真实执行另取证 |
| 工作区范围 | 真实 preview 返回 main.py modified、helper.py added，和冻结清单一致 | 本次两文件样本，不覆盖所有语言/所有 Git 层的 OCR 实测 |
| 空已提交区间 | 同一 base 到 HEAD 返回 0 文件，工作区仍返回 2 文件 | 不能把提交区间为空当作 dirty 工作区无待审文件 |
| 真实规则 | Python 系统规则组覆盖两份文件，原输出哈希往返一致 | rule 命令不调用 LLM；不是 OCR 独立发现缺陷 |
| 原报告与核证 | Matt 原报告逐字节保留；OCR 原报告另存；相同权限根因合并一项 | OCR 未增加新的高风险发现，不宣称增益 |
| 文件覆盖 | 两份报告各 reviewed=2、skipped=0、failed=0 | 覆盖率不是质量分；源文件故意含合成缺陷 |
| 复现与新鲜度 | 冻结前后代码实际执行，member 从 false 变 true；审前/后 fresh=true | 仅证明合成 S-01 违规，不是生产权限漏洞 |
| 机械交叉核验 | 16/16，安装、版本、范围、规则、原报告、覆盖、复现、新鲜度 | 非模型评测断言，不并入历史分数 |
| 回归 | 路由 27/27，快照/适配 33/33；PowerShell 7 Strict 通过，warnings=0 | 严格校验中的模型面板是工具夹具，没有运行完整模型回归 |

安装二进制 SHA-256：`a9a2b2148bd983be42b8f8fc1cd433e9100b620014408481495bf86cd64ea3ec`。

本轮唯一运行时修复：Windows Python stdout 默认 GBK，首次落盘规则出现 6 个替换字符。先新增两个失败用例，再将 provider_routing.py / review_snapshot.py 的 JSON 输出改为 ASCII 转义，解码后仍保留完整 Unicode；没有改规则内容、选择逻辑、权限或预算。默认 GBK 下再次真实调用通过，原规则文本 SHA-256 `1ea8dfe66e43359c26b1fc882842e998725243534af63455d456032523137d2c` 与回读内容一致。

首轮错误文件、UTF-8 临时绕行产物和最终默认环境产物分别保留；未覆盖旧失败。无需用户永久设置环境变量。首轮 14 文件身份清单已不是最新脚本快照，使用本次 `final-evidence-index.json` 核对当前身份。

## 证据索引

上述仓库外目录包含：

- `installation.json`、`provider-probe.json`、`dual-method-plan.json`：安装、来源与前置身份。
- `ocr-preview.json`、`ocr-empty-committed-range.json`、`ocr-rules-final.json`：真实 CLI 输出；`ocr-rules.json` 是保留的首轮编码失败，不用于当前审查。
- `matt-original.md`、`ocr-original.md`、`reconciled-review.md`：各自原报告及核证；Matt 原报告中的“未安装”是原轮次历史，不是当前状态。
- `matt-coverage.json`、`ocr-coverage.json`、对应 check JSON、`snapshot-before.json`、`snapshot-after.json`、`permission-reproduction.json`：同快照覆盖与复现。
- `encoding-*-before.txt`、`provider-regression.txt`、`snapshot-regression.txt`、`encoding-final-check.json`：先失败后修复的定向证据。
- `live-evidence-checks.json`：16 项机械核对；`strict-final.txt`：修复后的严格校验；`final-evidence-index.json`：产物及受影响仓库文件哈希。

## 修改范围与停止点

本次修改既有文件 8 个：README、evals README、三批增量记录、评测历史、两个 Python 助手与其测试；新增本记录。未修改其他前序维护、SKILL.md、版本、权限配置、hooks、Git index/HEAD 或评测正式题面。既有未提交改动全部保留。

下一步可在用户指定的真实代码范围内使用单审或双方法；本机安装无需重复授权。独立双审仍需明确 reviewer 资源与隔离证据，不能由本次安装授权推导。完整稳定集/挑战集、其他模型/语言、Windows PowerShell 5.1 执行、生产适用性继续待验证；不为补齐这些范围自行扩大测试。

没有全量回归、业务代码修改、提交、推送、tag、Release 或新的 Stable 晋升。
