# CI 治理需求背景

仓库已有 lint、unit test、package 三个工作流，但分支规则只要求 unit test。
目标是减少发布分支漏跑打包检查，不新增用户界面。
需要保护现有开发速度，允许文档-only PR 跳过 package。
失败时必须能看出具体门禁和回退方式。
