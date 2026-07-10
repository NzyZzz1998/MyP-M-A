# 当前导出接口

- `POST /api/exports`：提交导出请求，返回 `job_id`。
- `GET /api/exports/{job_id}`：返回 `status`、`file_url`、`error_message`。
- 当前已知问题：未定义幂等键；未说明跨租户访问；任务失败后没有重试入口。
- worker 通过队列异步生成 CSV，文件默认保存 24 小时。
