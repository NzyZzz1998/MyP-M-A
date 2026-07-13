# MyP-M-A

MyP-M-A（My Product Manager Assistant）是中文优先的个人产品经理 Skill。内部标识使用 `mypm`，对外展示使用 `MyP-M-A`。

它围绕四个主入口工作：

- `/review`：建立产品与工程地图，发现候选问题。
- `/idea`：判断问题真假、证据、价值与当前阶段。
- `/prd`：收敛方案并形成可开发、可测试、可验收的需求定义。
- `/acceptance`：基于真实实现做验收、发布检查和上线后观察。

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

## 校验

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-skill.ps1 -Strict
```

该脚本检查 UTF-8、常见乱码、版本一致性、eval schema、附件路径、本地 Markdown 引用和孤立 runtime 资源。它不能替代模型行为 eval。

## 当前状态

当前版本：`v0.20.0`。

v0.20 将 Basic Memory 从阶段末提示升级为事件驱动续接层：默认 `auto`，只在已知项目的新线程恢复和稳定阶段收尾写入；支持 `suggest / off`，并新增去重、事实源核对、敏感信息排除和写入结果确认。
