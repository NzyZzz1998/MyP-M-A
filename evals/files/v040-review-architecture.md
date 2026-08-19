# Review 架构事实

对象：MyP-M-A skill，当前版本 0.40.0 Candidate。

已确认：

- `SKILL.md` 负责五入口路由，并按条件加载 `references/*.md`。
- `capabilities/registry.json` 登记能力卡；能力卡引用 reference 与 eval ID。
- `scripts/validate-skill.ps1` 调用 validation 模块，读取 eval、合同和能力注册表。
- `evals/contract-registry.json` 将行为合同映射到稳定/挑战用例。
- 正式视觉产物由当前入口回写，不自动发布或上传。

工具状态：diagram-design 缓存存在，但当前会话未暴露该 skill，尚未调用成功。

未知：当前没有证据证明 diagram-design 能在本轮直接生成产物，也没有证据说明它与 validator 存在调用关系。
