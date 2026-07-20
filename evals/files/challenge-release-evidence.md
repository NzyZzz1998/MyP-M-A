# v3.1 候选发布证据

## 身份

- 验收分支：`release/v3.1`
- 当前 HEAD：`a84c2ef`
- 候选包记录的 source commit：`7a11d90`
- 候选包 SHA-256：`111122223333444455556666777788889999AAAABBBBCCCCDDDDEEEEFFFF0000`
- 本轮实际启动包 SHA-256：`999922223333444455556666777788889999AAAABBBBCCCCDDDDEEEEFFFF0000`

## 证据

- CI：126 passed
- 数据迁移：仅在 SQLite mock 上通过
- PostgreSQL production-like migration：未执行
- GUI 截图：来自 HTML prototype，页面角标为 DEMO DATA
- 安装器：未签名
- 便携 Zip：可启动
- 回滚演练：上一轮在 commit `7a11d90` 上通过

## 变更

`7a11d90` 之后修改了 migration、权限中间件和导出任务状态机。
