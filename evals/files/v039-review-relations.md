# v0.39 Review 关系夹具

已读取材料：

1. `src/api/export.py` 明确把任务写入队列 `export.jobs`。
2. `src/worker/` 目录存在，但当前材料没有给出消费 `export.jobs` 的处理器。
3. `docs/architecture.md` 画出 `API -> Worker -> Storage`，文档更新时间早于最近一次队列重构。
4. 用户提到仪表盘依赖 `reporting-cache`，但本轮没有提供仪表盘代码或配置。

要求：输出项目关系图，并区分直接事实、合理推断和待确认关系。静态搜索未命中不能证明处理器不存在。
