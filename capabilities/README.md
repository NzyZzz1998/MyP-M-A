# MyP-M-A 原子能力规范

本目录是五个用户入口之下的内部能力层。入口负责识别阶段和交付类型；能力卡只补充当前决策真正需要的方法合同，不成为新的命令或第二套工作流。

当前 `registry.json` 登记五张 `pilot` 卡：问题验证、产品数据分析、战略与市场进入决策、协作项目证据适配、产品数据证据适配。后两张只在需要读取企业协作或外部数据对象时加载，统一遵循 `references/enterprise-adapters.md` 的只读信封与授权边界。

## 三条治理合同

1. `contract:capability-registry-schema`：所有能力先进入 `registry.json`，使用全局唯一 ID、显式触发、反触发、输入输出、证据、工具降级和评测映射。
2. `contract:capability-card-single-source`：能力卡只保存轻量声明与原 reference 指针，不复制完整方法正文、模板和历史说明。
3. `contract:capability-card-minimal-loading`：先判断五入口和阶段，再按需加载最小能力集合；默认入口不得常驻装配全部能力卡。

## 能力与入口的关系

- 用户仍只使用 `/review`、`/idea`、`/prd`、`/acceptance`、`/prompt`。
- 能力卡不得反向改变入口、跳过证据门禁或绕过外部写操作授权。
- 多张卡同时命中时，优先级为：安全与授权 > 证据合同 > 入口阶段合同 > 方法建议。
- Memory 和工具仍是弹性能力；卡片只能声明工具类别与不可用时的降级方式。

## Registry 字段

| 字段 | 规则 |
| --- | --- |
| `id` | `<domain>.<capability>`，全局唯一，发布后不得复用 |
| `name_zh` | 面向决策的中文名称，不以框架名充当入口 |
| `domain` | 小写字母与连字符组成的能力域 |
| `status` | `draft`、`pilot`、`active`、`deprecated`、`retired` |
| `card_file` | `pilot` 及以后必填，必须位于仓库内并包含 `capability:<id>` 锚点 |
| `entrypoints` | 五入口中的一个或多个，必须保留前导 `/` |
| `stages` | `discover`、`validate`、`define`、`review`、`deliver`、`handoff` 的子集 |
| `triggers` | 何时需要此能力，至少一条 |
| `anti_triggers` | 何时不得加载，至少一条 |
| `required_inputs` | 缺少时需要核实或明确降级的信息 |
| `outputs` | 可观察的最小交付，不复制入口完整模板 |
| `evidence_contract` | 事实、推断、未知和结论的证据边界 |
| `tool_categories` | 抽象工具类别，不写本机路径或强制插件 |
| `fallback` | 工具或证据不可用时如何继续或停止 |
| `references` | 内容事实源，必须存在且位于 Skill 根目录内 |
| `eval_ids` | `stable`、`challenge`、`trigger` 三类映射 |
| `owner` | 维护责任方 |
| `introduced_in` | 首次引入版本 |
| `replacement` | `deprecated` 时必填，指向替代能力 ID |

## 能力卡固定结构

每张能力卡依次包含：定位、适用场景、反触发、必要输入、最小流程、输出合同、证据门禁、工具与降级、停止条件、reference 与 eval 映射。卡片不重复用户入口说明，也不粘贴完整输出模板。

## 生命周期

- `draft`：只允许静态登记，不参与装配，可暂时没有行为评测。
- `pilot`：卡片、reference 和至少一条稳定或挑战评测必须齐全；只在明确命中时试用。
- `active`：定向与控制回归、上下文预算和独立验收通过。
- `deprecated`：停止新用法，必须声明 `replacement`。
- `retired`：不再装配，但保留 ID、版本和历史证据，不允许复用。

## 新增能力检查

1. 先证明这是可复用决策能力，不是一次性模板或新入口。
2. 检查是否已有能力或 reference 能覆盖，避免同义卡。
3. 写 trigger 与 anti-trigger，再写方法；无法说明反触发的能力不得进入 pilot。
4. 给出受影响用例和普通控制用例，不用字符下降替代行为证据。
5. 运行严格校验、上下文预算和必要回归；失败时逐卡回退。
