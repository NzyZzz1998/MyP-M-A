# PRD 状态事实

对象：异步导出任务。

已确认逻辑状态：

- `draft -> queued`：用户确认创建。
- `queued -> running`：worker 领取。
- `running -> succeeded`：文件生成成功。
- `running -> failed`：处理失败或超时。
- `running -> cancelled`：仅运行中允许用户取消，取消成功必须有反馈。
- `failed -> queued`：用户显式重试；沿用原业务对象，生成新 attempt。
- `succeeded + available/expired`：文件可用性与任务终态分层。

范围保护：没有确认 `queued` 可取消；不得补画。失败、取消、重试和结果过期必须在图中可见。
