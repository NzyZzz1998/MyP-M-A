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

当前版本：`v0.27.0 candidate`，已完成本地能力编排、入口合同优化和 v0.26 全量 A/B，尚未提交或推送。
<!-- project-status: version=0.27.0; state=candidate -->

v0.27 不新增入口，重点补强外部能力编排：`/idea` 形成数据证据包，`/review` 增加领域、决策与有证据的代码瘦身，`/prd` 区分逻辑原型和 UI 原型并声明测试接缝，`/acceptance` 使用 Web、Desktop、Data/API、Release 多轨道证据清单。专门 skill、插件和工具只有在当前环境可用且能减少关键不确定性时才调用。

完整 A/B 使用同一 Luna `low` 执行与评分口径。稳定集：v0.26 为 `546/587（93.0%）`，v0.27 为 `572/587（97.4%）`，平均输出字符 `729.8 -> 693.6`。挑战集单独报告：v0.26 为 `126/136（92.7%）`，v0.27 为 `131/136（96.3%）`，平均输出字符 `929.8 -> 1074.0`。挑战集长度上涨用于补齐复杂数据、AI、安全、Memory 冲突与原型合同；两套分数不合并为统一质量总分。
