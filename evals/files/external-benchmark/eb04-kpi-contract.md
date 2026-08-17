# 团队活跃榜已知事实

- 来源事件：`task_completed(task_id, actor_id, tenant_id, completed_at, status)`。
- 仅 `status=success` 计入完成任务。
- 页面按自然周显示每个租户内成员排名，默认前 20 名。
- 一个 task 可能因重试产生重复事件；`task_id` 在租户内唯一。
- 权限：普通成员只能看本租户，管理员可导出本租户 CSV。
- 数据每天 02:00 UTC 聚合；产品服务时区尚未确认。
- 删除成员、合并账号、迟到事件、0 任务和低样本展示仍未确认。
