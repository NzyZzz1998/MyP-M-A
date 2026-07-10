# 更新记录

## v0.18.0 - 2026-07-10

- 将 `SKILL.md` 收敛为渐进加载调度层，减少默认上下文消耗。
- 收紧触发边界，避免纯代码审查、纯 bugfix、纯数据执行和既定 UI 实现误触发。
- 将 PRD 表达物改为按 UI、API、数据库、状态流和工程治理分类。
- 新增跨阶段追踪规则，并更新需求池、PRD、dev plan、progress、review 和 acceptance 模板。
- 统一 Review 中文证据状态。
- 补充工具能力探测、降级顺序和外部写操作授权边界。
- 补充后端数据库的权限、事务、幂等、迁移、隐私和指标口径检查。
- 移除已合并到主入口的旧 metrics、launch-plan、product-review reference。
- 将 eval 字段统一为 `expectations`，新增文件型数据、后端数据库、Web SaaS 和工程治理用例。
- 新增触发正反例与静态校验脚本。
- 同步真实 Memory 写入与恢复测试状态。
- 完成 v0.17/v0.18 代表性行为对照、三项定向完整 A/B、benchmark 和 eval viewer。
- 增加附件统计对象边界、规范异步状态契约和 `/acceptance` 显式入口判断。
- 记录 PCbuild 分层用户验证门禁：Agent 预检可卡开发承接，真人验证卡公开发布。

## v0.17.0 - 2026-07-09

- 建立第一版验证基础设施。
- 扩展 acceptance 真实试跑记录。
- 增加数据驱动、版本型需求池、高保真原型、部分通过验收、手动补证和 Memory 边界 eval。
