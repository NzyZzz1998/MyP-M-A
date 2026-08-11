# LetsMakeMoney v0.4 项目摘要

- 定位：Windows 桌面陪伴工具，把工资时间感知、桌宠陪伴和轻量桌面入口组合在一起。
- 目标用户：希望在工作日感知今日收入、又不想打开复杂效率软件的个人用户。
- 当前阶段：v0.4 Beta，重点是桌宠交互、透明窗口/点击穿透、Panel、Settings、Wizard 与托盘恢复的可靠性。
- 核心路径：首次 Wizard 配置薪资与宠物 -> 主 Panel 显示今日收入 -> 桌宠交互 -> Settings 调整显示/行为 -> 托盘隐藏与恢复。
- 主要模块：`Main` 负责窗口与流程编排；`Config` 保存用户设置；Panel/Pet/Settings/Wizard 提供界面；WindowsPlatform/native 负责透明窗口、穿透、托盘和任务栏策略。
- 已知证据：v0.4 文档记录了真实 Windows 验收仍在进行；当前附件没有代码扫描、运行日志或最新发布包身份。
