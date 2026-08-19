# 语义图解适配

<!-- capability:visualization.decision-diagram-adapter -->

## 定位

把已确认的节点、关系、状态和顺序转换为可追溯语义图解，不用视觉补全未知事实。

## 适用场景

- `/review` 需要项目、模块、领域或数据关系地图。
- `/prd` 需要流程、状态、时序、ER、泳道或数据流表达物。

## 反触发

- 来源不足以确认节点、边、方向、条件、职责或基数。
- 表格/文字更清楚，或用户只要求装饰图。

## 必要输入

- 读者、决策问题、对象身份和来源定位。
- 节点、边、方向、条件、状态、顺序、职责、基数及未知项。
- 工具六字段、目标用途和许可证。

## 最小流程

1. 冻结语义事实并选架构/流程/状态/时序/ER 等模式。
2. 探测工具真值；不可调用时使用本地 HTML/SVG 或 Mermaid。
3. 建立逐节点、逐边事实映射并生成概览；复杂内容拆细节图。
4. 核对方向、条件、失败/取消/回退和未知项。
5. 交付 HTML、SVG/PNG、manifest、双视口与离线证据。

## 证据与降级

关键语义差异必须为 0。diagram-design 是 MIT 可选 pilot，已安装不等于可调用；身份不明、调用失败或图比文字难核验时降级，不声称已使用。

## 映射

- Reference：`references/visual-delivery.md`、`references/capability-routing.md`
- Eval：stable 103、104、106；challenge CH-35、CH-36、CH-37、CH-38、CH-39
