# 可选依赖补装

目的：用户升级 MyP-M-A 后，首次使用时检查已授权依赖并补装缺失 Skill。不是更新器、后台服务或新产品入口，也不是“更新本 Skill 即同意安装所有工具”。默认关闭；配置属于本机 Skill 安装，不属于业务项目 Memory/日志配置。

## 执行时机

允许本地执行时，当前 Agent 只查本 Skill 根 `.mypm-dependencies.local.json`。无配置不联网、不创建配置、不提示所有用户安装；有配置且 enabled/consent 都为 true 时调用 `startup`。用户本轮禁止安装、只读或只生成提示词时不调用。仅有文件修改权限不等于下载权限。

`startup` 以 SKILL、依赖清单、安装器和授权范围的指纹去重；升级后首次调用重新核对，同指纹后续不联网。失败也记录已检查，下次不静默重复下载。`already_checked` 必须结合 previous 判断，不能将上次 partial 改称成功。相同版本后手动删掉依赖，需要显式 retry。

这里是 **Skill 驱动的首次使用检查**，不是在 git pull 后必然触发的系统 hook；没有当前 Agent 执行、Python 或本地文件能力就不会自动安装。不能声称已验证其他宿主或全新桌面会话的自动触发。

## 本次登记范围

| 依赖 | 补装策略 |
| --- | --- |
| matt-domain-modeling-pilot | 可选自动补装；固定 Matt commit、MIT、文件 SHA-256 与既有显式调用适配 |
| matt-to-questionnaire-pilot | 同上；保留问卷 pilot 的既有授权与输出边界 |
| matt-code-review-adapter | 本 Skill 内置方法，无需安装上游原生 Skill |
| OCR CLI | 仅提示单独安装授权；不由此脚本下载 |
| 浏览器、数据分析、Figma、图表等宿主能力 | 使用实际宿主插件管理；不伪装成同类 Markdown 包自动安装 |

来源白名单为 [dependency-lock](../capabilities/dependency-lock.json)，必须和 [provider registry](../capabilities/provider-registry.json) 的 commit/产物哈希一致。检索指对已登记清单与指定技能根做本地差集，不全网搜同名包、不扫描所有磁盘、不安装 Matt 全家桶。

## 一次授权与命令

先向用户展示来源、两项名称、宿主实际技能根、下载行为、显式调用策略及禁区，再取得授权。Python 3.10+ 与本地文件能力需已可用，不自动安装运行环境。以实际解释器、路径替换下例；`--consent` 是已有用户授权的记录，不是绕过宿主确认的手段。

```text
python <skill>/scripts/provider_dependencies.py check --skills-root <宿主技能根>
python <skill>/scripts/provider_dependencies.py enable --skills-root <宿主技能根> --provider matt-domain-modeling-pilot --provider matt-to-questionnaire-pilot --consent
python <skill>/scripts/provider_dependencies.py startup
python <skill>/scripts/provider_dependencies.py retry
python <skill>/scripts/provider_dependencies.py disable
```

可只授权一项；其他缺项标记 consent_required，不阻断已授权项。后续新增依赖或依赖包内容/commit 改变须重新确认其授权哈希，旧 consent 不自动扩展。更换电脑或技能根须重新授权；不将本地配置、检查状态与锁提交仓库。关闭补装不会删除已安装文件，也不会关闭/开启 Memory 或日志。

## 安装与失败合同

- 仅从已审核的 raw.githubusercontent.com 固定 commit 拉取小型 Markdown/LICENSE；拒绝跳转、文件哈希不符、越界路径与非登记来源，不运行下载内容。
- 保留许可证；用确定性前缀生成与既有 pilot 相同的 SKILL 哈希，并写入 `allow_implicit_invocation: false` 宿主策略。不重新开放上游隐式调用或自动写文件权限。
- 先下载并核验全部目标文件，再独占创建不存在的目录，SKILL.md 最后发布。已有目录即使为空、缺文件、被修改也不修复或覆盖，返回 existing_conflict。不要用删除已有目录来规避保护。
- 安装互斥锁防止本适配器并发写入；异常残留锁必须先确认无运行者，再人工处理。写入中失败可能留下部分新目录，保留供检查，不标成功、不自动删除或无限重试。
- 每次下载和写入前重查授权。错误只影响对应依赖；记录 installed / existing_conflict / consent_required / failed，不把整体 partial 写成成功。
- 安装成功只证明文件和身份，不证明宿主已暴露、原生调用成功或任务已验收。按宿主提示刷新技能列表；需要新会话时说明具体宿主限制，不固定要求重启。

自动化单测用合成包与临时目录；真实固定源下载、缺失补装、回读和二次不联网另存证据。不用路由表或安装成功替代实际使用评测。

定向回归：`python -B scripts/test_provider_dependencies.py`；变更清单或适配时同时运行 `scripts/test_provider_routing.py` 和严格静态校验。默认关闭、授权与来源漂移、已有目录、写入失败、两次启动分别保留结果，不为此启动全量模型回归。
