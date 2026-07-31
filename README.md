# MyP-M-A

MyP-M-A（My Product Manager Assistant）是中文优先的个人产品经理 Skill。内部标识使用 `mypm`，对外展示使用 `MyP-M-A`。

它围绕四个主入口工作：

- `/review`：建立产品与工程地图，发现候选问题。
- `/idea`：判断问题真假、证据、价值与当前阶段。
- `/prd`：收敛方案并形成可开发、可测试、可验收的需求定义。
- `/acceptance`：基于真实实现做验收、发布检查和上线后观察。

另有一个辅助入口 `/prompt`：把当前阶段、正式文件、剩余任务和授权边界压缩成可直接交给同一项目窗口或新线程的执行提示词。它不改变四个产品阶段。

完整 PRD 确认后，可继续生成 `dev_plan_vx.x.md`、`progress_vx.x.md` 和按需使用的 `dev_log_vx.x.md`。Basic Memory 默认在已知项目的新线程恢复上下文，并在稳定阶段收尾时去重更新；它不替代项目仓库中的正式文档。用户可切换 `auto / suggest / off`。

## 目录

- `SKILL.md`：触发边界、阶段路由和核心约束。
- `references/`：按需加载的工作流规则。
- `templates/`：正式交付物模板。
- `evals/`：行为 eval、触发 eval 和文件型样本。
- `scripts/`：静态校验。
- `notes/`：真实试跑、路线图和维护记录，不属于运行时必读内容。

## 使用

在支持本地 Skill 的 Codex 环境中选择 `MyP-M-A` 即可。用户不必记住命令，可以直接提供项目路径、产品想法、PRD、截图、日志或验收结果，Skill 会自动判断入口。

显式入口：

| 入口 | 用途 |
| --- | --- |
| `/review` | 梳理项目/页面/PRD/实现并发现问题 |
| `/idea` | 判断需求真假、价值和当前优先级 |
| `/prd` | 收敛方案并形成可开发需求 |
| `/acceptance` | 基于真实实现做验收与发布判断 |
| `/prompt` | 生成下一阶段、续做、Bugfix、验收、发布或交接提示词 |

示例：

```text
/review 请评审当前项目，先建立产品与工程地图。
```

```text
/idea 我想增加这个功能，帮我判断是不是真需求、现在该不该做。
```

```text
/prd 基于已确认的 IDEA 写完整 PRD，先继续询问会改变范围的问题。
```

```text
/acceptance 基于构建产物、日志和验收标准实际检查是否可发布。
```

```text
/prompt 根据当前 progress 和 verification 生成下一轮定向验收提示词。
```

## 校验

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill.ps1 -Strict
```

该脚本检查 UTF-8、常见乱码、版本一致性、eval schema、附件路径、本地 Markdown 引用和孤立 runtime 资源。它不能替代模型行为 eval。

## 当前状态

当前版本：`v0.30.0` Candidate。评测管线分层、匿名批量盲评和第一批 reference 去重已完成；本地提交，尚未推送。
<!-- project-status: version=0.30.0; state=candidate -->

v0.30 不新增入口或产品能力，主要变化：

- 全覆盖与 `targeted-max` 分层执行，SLA 完成率、共同样本能力得分和输出长度分开统计。
- 匿名盲评默认每批 3 条；评分器看不到版本映射，写回前校验检查项原文、顺序、布尔结果和中文证据。
- `review/prd/acceptance` 不再重复完整模板正文，运行时参考合计减少约 2,485 字符；关键合同继续留在 reference 顶部。
- 补强验收证据表字段、Review 空候选状态，以及版本、路径、数值和单位的输入保真门禁。

13 条相关用例首次 A/B 中，v0.29 为 `101/109`，v0.30 为 `104/109`，候选平均回答长度下降约 `14.3%`。修复两条边界后，v0.30 对 ID 17/76 各 3 次定向复测为 `45/45`；这证明受影响合同稳定，不等同于 99 条全量回归。v0.29 仍是已推送的 Stable 基线（`9b4c297`）。

v0.30 全量状态：稳定集 `待评测 / 624`，挑战集 `待评测 / 156`。

长期结果、证据边界和历史口径统一记录在 [评测历史](notes/evaluation-history.md)；生成型回答、评分和 viewer 仍按临时产物管理。
