# MyP-M-A

MyP-M-A（My Product Manager Assistant）是中文优先的个人产品经理 Skill。内部标识使用 `mypm`，对外展示使用 `MyP-M-A`。

它围绕四个主入口工作：

- `/review`：建立产品与工程地图，发现候选问题。
- `/idea`：判断问题真假、证据、价值与当前阶段。
- `/prd`：收敛方案并形成可开发、可测试、可验收的需求定义。
- `/acceptance`：基于真实实现做验收、发布检查和上线后观察。

完整 PRD 确认后，可继续生成 `dev_plan_vx.x.md`、`progress_vx.x.md` 和按需使用的 `dev_log_vx.x.md`。Basic Memory 只承担跨线程续接，不替代项目仓库中的正式文档。

## 目录

- `SKILL.md`：触发边界、阶段路由和核心约束。
- `references/`：按需加载的工作流规则。
- `templates/`：正式交付物模板。
- `evals/`：行为 eval、触发 eval 和文件型样本。
- `scripts/`：静态校验。
- `notes/`：真实试跑、路线图和维护记录，不属于运行时必读内容。

## 使用

在支持本地 Skill 的 Codex 环境中安装本目录后，可直接使用：

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

## 校验

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill.ps1 -Strict
```

该脚本检查 UTF-8、常见乱码、版本一致性、eval schema、附件路径、本地 Markdown 引用和孤立 runtime 资源。它不能替代模型行为 eval。

## 当前状态

当前版本：`v0.18.0`。

静态结构优化、代表性模型对照、benchmark 和 eval viewer 已完成；三项定向 A/B 回归显示 v0.18 在验收入口与数据证据边界上有稳定提升。34 条正式 eval 已全部通过静态结构校验，但尚未执行统一的全量行为 A/B。详细证据见 `notes/v0.18-validation-summary.md`。
