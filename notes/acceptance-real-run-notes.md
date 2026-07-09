# /acceptance 真实试跑记录

本文记录 MyP-M-A `/acceptance` 在真实项目中的试跑反馈，用于后续改进 skill。它不是项目正式验收文档本体，而是对 `/acceptance` 工作流输出质量和证据要求的复盘。

## QuickRec v1.4.x Diagnostic Export Acceptance

时间：2026-07-09

项目：

- `E:\codex\QuickRec-v14x-diagnostics`

功能：

- v1.4.x 诊断导出能力。

关联文档：

- PRD：`doc/PRD-diagnostic-export-v1.4.x.md`
- dev plan：`doc/dev_plan_v1.4.x.md`
- progress：`doc/progress_v1.4.x.md`
- acceptance checklist：`doc/v1.4.x-acceptance-checklist.md`

### 阶段一：首次 /acceptance

首次验收结论：

- 部分通过。
- 暂不建议直接发布为最终 v1.4.x。

已通过证据：

- 打包产物可启动。
- 诊断日志目录生成。
- 日志包含启动、快捷键触发、编码完成、保存成功。
- 全屏录制通过热键生成 MP4。
- MP4 使用 FFmpeg 抽样解析无错误。

未通过或待验证项：

- 托盘菜单无法被 Computer Use 稳定打开。
- 设置页“诊断”分组缺少 GUI 截图证据。
- “复制诊断信息”“打开日志目录”“导出诊断文件”缺少 GUI 点击证据。
- 自定义诊断目录保存后重启保持缺少 GUI 证据。
- 区域 / 窗口录制未在本轮 GUI 验证。
- 系统声 / 麦克风 / 双音频未逐项 GUI 回归。
- FFmpeg 缺失或保存路径不可写等异常场景未验证。

重要风险：

- 用户提供的正式路径 `E:\codex\QuickRec\dist\QuickRec\QuickRec.exe` 是旧产物。
- 实际验收对象为 `E:\codex\QuickRec-v14x-diagnostics\dist\QuickRec\QuickRec.exe`。
- 发布前必须统一最终发布源和验收对象。

做得好的地方：

- 没有因为自动化测试和基础启动通过就给出“通过”结论。
- 明确区分“功能实现完成”和“发布证据完成”。
- 把路径不一致识别为发布前风险，而不是忽略。
- 明确列出待补证 GUI 项目。

暴露的问题：

- `/acceptance` 需要更强调“验收对象路径一致性”。
- 对桌面软件，Computer Use 无法稳定操作托盘时，应主动要求人工补证，而不是硬判失败。
- 自动化测试不能替代 GUI 验收，尤其是托盘、真实桌面、音频设备和设置页按钮。

### 阶段二：补证后复验

复验结论：

- 通过。
- 可进入最终发布收口。

关键证据：

- 验收清单 A-I 均标记为 `通过`：`doc/v1.4.x-acceptance-checklist.md`。
- `progress_v1.4.x.md` 更新为 `通过 / 可发布`。
- 诊断导出文件存在：
  - `E:\QRtest\pkg_audio\QuickRecDiagnostics\diagnostic_20260709_142944.txt`
- 日志证据存在：
  - `E:\QRtest\pkg_audio\QuickRecDiagnostics\quickrec.log`
- 日志确认：
  - 复制诊断信息成功。
  - 打开日志目录成功。
  - 导出诊断文件成功。
  - 全屏 / 区域 / 窗口录制均保存成功。
  - 系统声 / 麦克风 / 双音频均完成捕获与保存。
  - FFmpeg 缺失时记录 `FFmpeg not found; recording cannot start`。
- 抽样校验 4 个录制 MP4，打包内 FFmpeg 解析无错误。
- `ffmpeg.exe` 已恢复，临时 `.bak` 不存在。

### 阶段三：最终发布收口

最终结论：

- v1.4.x 诊断导出能力通过 / 可发布。

已完成：

- release notes 已追加 `v1.4.x 诊断导出能力补充`。
- 新增 `doc/changelog.md`。
- 状态一致性已同步：
  - PRD：`已验收通过 / 可发布`
  - dev plan：`已完成 / 已验收通过`
  - progress：`通过 / 可发布`
  - acceptance checklist：`通过 / 可发布`
- 最终发布源：
  - `E:\codex\QuickRec-v14x-diagnostics`
- 最终发布产物：
  - `E:\codex\QuickRec-v14x-diagnostics\dist\QuickRec\QuickRec.exe`
- 发布提交：
  - `16c7dce feat(v1.4.x): add diagnostic export workflow`
- 本地 tag：
  - `v1.4.1`
- 旧 tag：
  - `v1.4` 保持不覆盖，仍指向原 v1.4 稳定候选。

验证证据：

- `45 passed`：配置、诊断、设置页、主流程相关测试。
- `10 passed, 1 skipped`：packaging 测试。
- GUI 手动验收通过。
- 诊断证据文件存在。
- 日志证据存在。
- 抽样 MP4 解析通过。

已知限制：

- 不做云上传。
- 不做自动修复。
- 不做复杂诊断中心。
- 当前诊断信息只保存在本地，可能包含本机路径、窗口标题等上下文。
- CI 不能替代真实托盘、真实桌面、真实音频设备验收。

回滚方式：

- 代码回滚：回到 `v1.4` tag。
- 发布包回滚：使用上一版 v1.4 稳定包。
- 本次补丁 tag：`v1.4.1`。

### 可沉淀为 /acceptance 规则

- 验收前必须确认“验收对象”和“最终发布对象”是同一个路径、分支或构建产物。
- 自动化测试通过不等于 GUI / 桌面 / 托盘 / 音频验收通过。
- 对桌面应用，Computer Use 无法稳定点击托盘时，应标记为“待人工补证”，而不是直接判定通过。
- `/acceptance` 可以分阶段输出：
  - 首次验收：通过 / 部分通过 / 未通过 / 待验证。
  - 补证复验：只复核缺口项和关键回归。
  - 发布收口：同步 release notes、changelog、progress、tag、回滚方式。
- “实现完成”和“可发布”必须分开判断。
- 异常场景至少要覆盖一个真实失败路径，例如 FFmpeg 缺失、保存路径不可写、配置损坏或日志目录不可写。
- 发布前必须写清已知限制和回滚方式。
