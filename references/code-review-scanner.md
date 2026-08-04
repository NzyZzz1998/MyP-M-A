# 代码评审扫描层

本文件用于 `/review` 的 implementation 主通路或辅助通路。OpenCodeReview（OCR）或等价工具只负责选择代码范围、加载语言规则和生成候选 finding；MyP-M-A 仍负责对象身份、需求语境、证据闭环、严重度和最终分流。

<!-- contract:code-review-scanner-purpose -->
<!-- contract:code-review-scanner-privacy -->
<!-- contract:code-review-scanner-delegation -->
<!-- contract:code-review-scanner-evidence-closure -->

## 触发边界

满足以下任一条件时按需使用扫描层：

- 用户明确要求评审代码、diff、commit、PR 或发布区间；
- Project Review 需要 implementation 辅助通路，且代码规模足以让语言规则扫描降低遗漏；
- 当前问题集中在资源清理、并发/异步、权限、安全、事务、失败补偿或测试覆盖。

单文件且上下文清楚、只有文档/页面/PRD、没有可锁定代码对象，或工具成本高于收益时，不为展示工具而调用。全仓 `scan` 只在用户明确要求完整代码基线评审，或 diff 无法代表目标时使用。

## 固定编排

### 1. MyP-M-A 先锁定对象

在调用扫描器前确认：

- 仓库路径、产品线、分支/HEAD、dirty 状态；
- 评审模式：workspace、单 commit、`base..head`/tag 区间或指定文件；
- 需求/PRD、release notes、测试和已知限制中与本次 diff 直接相关的最小背景；
- 排除项：生成文件、依赖、构建产物、二进制、证据目录、无关文档及敏感文件。

没有锁定 ref 时不得把“当前工作区”“最近版本”自行替换为猜测范围。dirty 工作区必须说明是否纳入。

### 2. 探测 OCR 能力与数据边界

先运行版本/帮助或等价只读探测，记录真实工具、版本和模式。OCR 有两种不同证据身份：

| 模式 | 工具职责 | 是否独立模型评审 | 使用条件 |
| --- | --- | --- | --- |
| `ocr review` / `ocr scan` | 选择代码并调用配置的 LLM | 是，但仅限与主判断隔离执行时 | 已授权向该 provider 发送本次代码 |
| `ocr delegate preview/rule` | 本地选择 diff 与解析语言规则，宿主完成判断 | 否 | 无独立后端、禁止外发或只需规则层 |

`review`/`scan` 会把代码发送给配置的 LLM 服务。私有仓库、商业代码或未知项目策略下，未获明确授权不得运行远端模型模式；工具已安装、已有 API key 或用户要求“深度评审”都不等于外发授权。先排除凭据、用户数据和无关源码。

### 3. 选择最小模式

参考命令，路径和 ref 必须替换为本轮已确认值：

```powershell
# 本地预览，不调用 LLM
ocr delegate preview --from <base> --to <head> --exclude '<patterns>'
ocr delegate rule <reviewable-files>

# 已授权的独立评审
ocr review --from <base> --to <head> --audience agent --format json `
  --exclude '<patterns>' --max-tokens-budget <budget>
```

- workspace 变更省略 ref；单提交使用 `--commit <sha>`。
- 需求背景只传与代码判断直接相关的最小事实，不传先前 finding、怀疑的 bug、期望答案或拟定修复，以免锚定扫描器。
- 设置预算后必须记录 reviewed、skipped、failed 数量；部分结果不能支持“未发现问题”的全范围结论。

### 4. 保持评审身份诚实

- 独立模型模式：尽量先运行扫描器，再读取其结果并与 MyP-M-A 发现交叉核对；不得把主任务已有答案泄漏给独立 reviewer。
- Delegation Mode：明确写“同一宿主依据 OCR 范围与规则完成第二遍检查”，不得称为双模型 A/B 或独立交叉验证。
- 同一个 finding 被两条规则重复命中时合并，不按票数提高严重度。

### 5. MyP-M-A 完成证据闭环

每个候选 finding 在进入主发现表前至少核对：

1. 是否属于锁定 diff/文件范围，还是无关历史问题；
2. 调用方、数据来源、类型/配置/平台合同是否使路径真实可达；
3. 是否已有保护、测试或上游约束排除该问题；
4. 能否用最小测试、日志、静态证明或复现确认；
5. 是否违反 PRD、用户路径、安全边界、兼容或发布承诺；
6. 影响、修复方向、回归范围和独立回退是否明确。

最终标记为“已确认 / 高度可能 / 待确认 / 已驳回”。外部扫描结果本身不能写成“已确认”，无法复现的并发或平台假设保留为残余风险。发现优先写正确性、安全、数据损失、权限、资源、事务与用户可见失败；纯风格建议默认不进入产品主发现表。

### 6. 统一输出，不复制两套报告

除非用户明确要求比较工具，默认只输出一张 MyP-M-A 主发现表，并在证据来源中注明 `OCR independent`、`OCR delegation`、测试或文档。另附最小调用记录：

| 能力/模式 | 评审范围 | reviewed/skipped/failed | 发现去重 | 限制/降级 |
| --- | --- | --- | --- | --- |

没有 finding 时只能写“在已扫描范围内未发现可确认问题”；同时报告未扫描文件、未运行测试和平台边界。

## 降级与停止

- OCR 不存在：使用本地 git diff、`rg`、语言检查器和定向测试，说明未使用外部扫描层。
- OCR 无 LLM/API 或代码禁止外发：切换 Delegation Mode，不要求用户为了本轮安装或配置远端服务。
- OCR 只有部分文件完成：保留有效 finding，未完成范围写待验证；不要无界重试。
- scanner finding 缺少可达性或证据：降级为待确认或驳回，不为凑数量保留。
- 工具要求修改代码、远端评论、PR 或发布：停在只读报告；写操作另行取得授权。
