# MyP-M-A 评测说明

MyP-M-A 使用两套互补评测，不混合计算总分。
<!-- contract:separate-eval-scores -->

## 稳定集

`evals.json` 用于发现明显行为回退。它覆盖四个产品阶段、`/prompt`、Memory 和常见附件场景。稳定集通过不等于新版整体更好，只表示核心合同没有明显退化。

## 挑战集

`challenge-evals.json` 用于区分细节质量。题目刻意包含统计口径歧义、证据冲突、异步状态、租户权限、产物身份和高风险发布条件。挑战集可以暴露“格式正确但判断错误”的输出。

挑战集规则：

1. 新旧版本必须使用同一模型、同一附件和同一评分器。
2. 首轮各运行一次；存在差异、失败或评分不稳定时，再补到三次。
3. 评分器必须逐条引用输出证据，不能只给总分。
4. 模型超时等待五分钟；仍未落盘时终止该次运行并用备用模型重试，执行器失败不得记为能力失败。
5. 稳定集与挑战集分别汇报通过率、输出长度和人工复核项。

## 回归工作区

`scripts/regression-workspace.ps1` 只负责准备快照、目录和元数据，并校验已有结果。执行目录中的 `task.json` 只包含用户请求和原始附件；预期结果与评分点隔离在 `_grader/`，不得提供给执行模型。脚本不会调用模型，也不会把缺失结果伪装成失败。

```powershell
.\scripts\regression-workspace.ps1 `
  -Action Prepare `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023 `
  -BaselinePath D:\path\to\mypm-v022 `
  -CandidatePath D:\Work\Software\codex_home\.agents\skills\mypm `
  -EvalFile evals\challenge-evals.json
```

模型与评分结果落盘后执行：

```powershell
.\scripts\regression-workspace.ps1 `
  -Action Validate `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023
```

结构校验会生成 `validation-report.json`、`benchmark-lite.json` 和 `benchmark-lite.md`。需要人工逐项对照时，再生成自包含 viewer：

```powershell
.\scripts\generate-eval-viewer.ps1 `
  -Workspace D:\Work\Software\codex_home\skill-evals\mypm-workspace\iteration-v023 `
  -Title 'MyP-M-A v0.22 vs v0.23' `
  -BaselineLabel 'v0.22 基线' `
  -CandidateLabel 'v0.23 候选'
```

Viewer 展示提示词、新旧回答、逐条断言、证据和修复前归档；轻量汇总不能代替人工复核。
