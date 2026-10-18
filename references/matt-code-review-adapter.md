# Matt 两轴代码审查适配

这是 MyP-M-A 的本地方法适配，不是已安装的 Matt 原生 Skill。来源是 Matt `code-review` 的固定 [49dd158d](https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/skills/engineering/code-review/SKILL.md)（MIT）；本文件自述适配，没有打包上游正文或全部 smell 清单。调用前读取本文件即可使用两轴方法，不要求网络、tracker 或 Matt setup。

与原版差异：以冻结的目标层文件/差量代替单一 base...HEAD；缺规格只跳过 Spec；不默认并行派两个 Agent；不要求 400 词硬上限；保留原两轴报告后，由主流程生成带来源的核证表，不修改原报告替它改判。

## 执行

1. 按 `references/code-review-scanner.md` 锁定同一快照。只读 snapshot 的文件、分层差量及最小背景；工作区变化时重新验证，不把旧范围重新解释成新范围。
2. **Standards**：读取目标仓库已有 AGENTS/CONTRIBUTING/CODING_STANDARDS 等适用规范；逐项引用规则及具体行。命名、重复、职责分散等仅是可反驳的设计启发，不冒充硬违规，不重复报告工具已充分覆盖的纯格式项。没有规范时注明“无项目规范”，仍可做通用正确性检查。
3. **Spec**：逐项核对用户提供的正式需求与任务，分别找遗漏、未要求的扩张和实现错误，引用原条目。无规格则仅标此轴 skipped，说明原因；不自动联网取私有 Issue、不创建 tracker、不阻塞 Standards。
4. 每个 finding 绑定快照、文件/层、行、证据、影响和置信状态。目标层是暂存时，不将工作区后续修正当作暂存已修复。最终副本中已抵消的层间变动仍记录覆盖，但不重复报已消失缺陷。
5. 保留 `## Standards` 与 `## Spec` 两节原报告及各自覆盖；“没有问题”不是测试、产品验收或发布通过。

## 与 OCR 合作

- single：只用一个专项，再由 MyP-M-A 核证。
- dual-method：当前宿主先 Matt 两轴、再 OCR 规则检查；两个原报告分别留存，明确非独立。本机 OCR 缺失时只能交付 Matt + 本地基础检查，不能写 Matt + OCR 已完成。
- dual-isolated：授权后两位 reviewer 串行、隔离上下文读取同一快照及最小事实，不给先前 findings。一个执行 Matt 两轴，另一个用 OCR delegate 规则；可用同一模型，完成即关闭。默认预算 0 不启动。

合并按“文件 + 根因 + 影响路径”核证，不按投票数提升严重度。保留 provider/轴、原严重度、原证据与主流程裁决；有分歧解释依据，不能覆盖原报告。一个轴失败不会被另一个通过抵消。
