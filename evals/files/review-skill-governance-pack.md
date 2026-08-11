# 产品经理 Skill 治理材料包

## 当前状态

- 当前稳定版本为 `v0.33.0 Stable`。
- `v0.34.0` 处于 Candidate 治理阶段；M0 基线与 M1 评测/校验基础已通过，M2 入口 reference 试点尚未验收。
- 本轮不得用 Candidate 结论覆盖 Stable，也不得把静态校验写成模型行为通过。

## 入口与运行时

- `SKILL.md` 定义 `/review`、`/idea`、`/prd`、`/acceptance` 四个主入口，以及 `/prompt` 辅助入口。
- 显式入口优先；未给命令时按决策目标选择唯一入口。主入口可带一个辅助通路，但不能跨阶段交付。
- 每个入口只加载必读 reference；深度、数据、工具、代码扫描、Memory 等能力按条件追加。
- 输出默认中文；结论必须区分事实、推断和待确认，并遵守读取、执行、外发与写操作权限。

## Reference 与模板

- `references/review.md`：对象地图、通路选择、证据状态、发现与分流。
- `references/deep-review.md`：用户要求深入时使用的根因分析规则。
- `references/capability-routing.md`、`tooling.md`：外部能力选择、可用性与降级。
- `references/code-review-scanner.md`：扫描器只生成候选 finding，最终结论由 MyP-M-A 完成证据闭环。
- `templates/review-report-template.md`：仅在正式报告落盘时使用，不要求窄 Review 填满全部章节。

## 评测与合同

- 稳定集、挑战集和触发集分开管理，不合并为统一质量总分。
- `contract-registry.json` 记录合同来源文件、入口、风险、稳定/挑战/触发用例与是否属于固定核心。
- 发布面板由 9 条固定核心、变更合同差量和相邻控制组成；未映射的行为文件会阻止面板生成。
- 执行输出与评分点隔离；缺失返回计入完成率，不自动算能力失败。

## 校验器

- `validate-skill.ps1 -Strict` 同时运行旧检查和 docs/evals/contracts 三个模块化校验器。
- 正负夹具覆盖重复 ID、失效路径、非法 UTF-8、孤立合同、面板漏映射和触发摘要过期。
- M1 最近一次记录为旧/新校验均 0 错误、0 警告，pipeline self-test 通过。
- 尚无 M2 reference 改动后的 Sol/Terra 行为结论。
