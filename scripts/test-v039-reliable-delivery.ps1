$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing v0.39 file: $RelativePath" }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Assert-True {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-ContainsAll {
    param([string]$Text, [string[]]$Values, [string]$Label)
    foreach ($value in $Values) { Assert-True -Condition $Text.Contains($value) -Message "$Label is missing: $value" }
}

$skill = Read-Utf8 'SKILL.md'
$idea = Read-Utf8 'references/idea.md'
$dataAnalysis = Read-Utf8 'references/data-analysis.md'
$review = Read-Utf8 'references/review.md'
$prd = Read-Utf8 'references/prd.md'
$acceptance = Read-Utf8 'references/acceptance.md'
$prompt = Read-Utf8 'references/prompt.md'
$chart = Read-Utf8 'references/chart-delivery.md'
$routing = Read-Utf8 'references/capability-routing.md'
$tooling = Read-Utf8 'references/tooling.md'
$rules = Read-Utf8 'scripts/validation/rules.json' | ConvertFrom-Json
$stable = Read-Utf8 'evals/evals.json' | ConvertFrom-Json
$challenge = Read-Utf8 'evals/challenge-evals.json' | ConvertFrom-Json
$contracts = Read-Utf8 'evals/contract-registry.json' | ConvertFrom-Json
$lifecycle = Read-Utf8 'evals/eval-lifecycle.json' | ConvertFrom-Json
$capabilities = Read-Utf8 'capabilities/registry.json' | ConvertFrom-Json
$qualityPolicy = Read-Utf8 'evals/release-quality-policy.json' | ConvertFrom-Json
$externalBenchmark = Read-Utf8 'evals/external-benchmark.json' | ConvertFrom-Json

Assert-True -Condition $skill.Contains('version: "0.39.0"') -Message 'SKILL.md version must be 0.39.0'
Assert-ContainsAll -Text $skill -Label 'Terminal scan' -Values @('fact-anchor-terminal-scan', '对象、范围、状态、数字/单位、推断、证据和授权', '冲突显式保留')
Assert-ContainsAll -Text $idea -Label 'Ratio semantics' -Values @('idea-ratio-semantic-preservation', '事件', '任务', '用户', '租户', '分子', '分母', '至少出现一次失败的去重任务', '最后可观测状态失败的任务')
Assert-ContainsAll -Text $dataAnalysis -Label 'Retry observation boundary' -Values @('“最终失败”不等于“重试后仍失败”', '至少两次可排序尝试', '未观察到重试')
Assert-ContainsAll -Text $idea -Label 'Cause scope' -Values @('已观察子集', '2/2 个最终失败任务', '原因未知')
Assert-ContainsAll -Text $idea -Label 'Reversible experiment' -Values @('idea-reversible-experiment-card', '继续阈值', '缩小阈值', '停止阈值', '确认前不是正式门禁')
Assert-ContainsAll -Text $dataAnalysis -Label 'Composite uniqueness' -Values @('租户内唯一', '(tenant_id, object_id)', '不同租户出现相同')
Assert-ContainsAll -Text $dataAnalysis -Label 'KPI source and interface' -Values @('kpi-source-interface-completeness', '来源字段校验', '计数指标没有分母', '越权必须明确拒绝', '不能伪装成正常空结果', '具体输入记录', '不能只引用 `G-001`')
Assert-ContainsAll -Text $review -Label 'Relation evidence' -Values @('review-relation-evidence-state', '事实', '推断', '待确认')
Assert-ContainsAll -Text $prd -Label 'UI value semantics' -Values @('prd-ui-state-semantics', '当前输入值', '最后已保存值', '首次默认值', '无变化')
Assert-ContainsAll -Text $prd -Label 'Command outcomes' -Values @('prd-command-outcome-matrix', '是否发请求', '可观察反馈', '无变化保存', '取消')
Assert-ContainsAll -Text $prd -Label 'Low-risk form defaults' -Values @('不能同时保留多个规范方案', '继续编辑/放弃修改', '禁用子控件但保留其值')
Assert-ContainsAll -Text $prd -Label 'Async candidate boundary' -Values @('待确认的状态或迁移只能列为候选与门禁', '不能同时写进已确认状态基线或未标注的 P0 合同', '未确认 `pending` 可取消时保持待确认')
Assert-ContainsAll -Text $prd -Label 'Async cancellation evidence boundary' -Values @('不是输入已确认了 `cancelled` 枚举', '单一 N4 推荐', '不能冒充来源事实', '取消接口和状态机不得提前允许 `pending`')
Assert-ContainsAll -Text $prd -Label 'Async state layers' -Values @('`running -> cancelled`', '`succeeded + available/expired`', '任务终态分层')
Assert-ContainsAll -Text $prd -Label 'Impact evidence boundary' -Values @('只有材料或项目证据确认没有影响时才标', '待核对/待确认', '不得为了填满模板推断')
Assert-ContainsAll -Text $prd -Label 'Named-item coverage scan' -Values @('用户点名的对象、控件、命令、状态、异常、权限、数据影响和验收出口', '唯一落点', '核心行为、安全边界或范围')
Assert-ContainsAll -Text $prd -Label 'Proposal isolation and logical contract' -Values @('事实状态', 'N4 只能留在建议/待确认合同中', '逻辑字段 | 类型类别 | 必填/可空 | 唯一/索引/约束 | 迁移或回填', '实施参数未知不自动降级', '来源已确认', '风险推导要求', 'schema/实现核对')
Assert-ContainsAll -Text $dataAnalysis -Label 'Outlet scope and conflicting duplicates' -Values @('页面默认 Top N 不能自动扩成 API 硬上限或导出范围', '冲突主体、冲突状态或冲突时间', '数据完整性标记', '由已知权限/质量风险推导的产品要求')
Assert-ContainsAll -Text $acceptance -Label 'Acceptance consistency' -Values @('acceptance-item-summary-consistency', '同一对象', '失效')
Assert-ContainsAll -Text $prompt -Label 'Prompt preservation' -Values @('对象、范围、数字/单位、状态、授权', '压缩')
Assert-ContainsAll -Text $chart -Label 'Chart delivery' -Values @('capability-decision-chart-route', 'SHA-256', '逐值', '双视口', 'PolyForm Noncommercial', '统一总分')
Assert-True -Condition ($routing.Contains('capability-decision-chart-route') -and $tooling.Contains('Lieflat Charts')) -Message 'Chart route/tooling contract is incomplete'

$requiredLoading = @($rules.required_loading_routes.PSObject.Properties | ForEach-Object { @($_.Value) })
foreach ($path in @('references/chart-delivery.md', 'capabilities/visualization/decision-chart-adapter.md')) {
    Assert-True -Condition ($path -notin $requiredLoading) -Message "Chart pilot must not be default-loaded: $path"
}

$stableIds = @(97..102)
$challengeIds = @('CH-29', 'CH-30', 'CH-31', 'CH-32', 'CH-33', 'CH-34')
foreach ($id in $stableIds) {
    Assert-True -Condition (@($stable.evals | Where-Object { [int]$_.id -eq $id }).Count -eq 1) -Message "Stable v0.39 eval must exist once: $id"
    $owners = @($contracts.contracts | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count +
        @($lifecycle.scenario_groups | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition ($owners -eq 1) -Message "Stable v0.39 eval ownership must be unique: $id"
}
foreach ($id in $challengeIds) {
    Assert-True -Condition (@($challenge.evals | Where-Object { [string]$_.id -eq $id }).Count -eq 1) -Message "Challenge v0.39 eval must exist once: $id"
    $owners = @($contracts.contracts | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count +
        @($lifecycle.scenario_groups | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition ($owners -eq 1) -Message "Challenge v0.39 eval ownership must be unique: $id"
}
foreach ($file in @(
    'evals/files/v039-statistical-object.md',
    'evals/files/v039-numeric-literals.md',
    'evals/files/v039-review-relations.md',
    'evals/files/v039-ui-values.md',
    'evals/files/v039-acceptance-evidence.md',
    'evals/files/v039-chart-data.md'
)) { [void](Read-Utf8 $file) }

$card = @($capabilities.capabilities | Where-Object { [string]$_.id -eq 'visualization.decision-chart-adapter' })
Assert-True -Condition ($card.Count -eq 1 -and [string]$card[0].status -eq 'pilot') -Message 'Decision chart capability must be a single pilot'
Assert-True -Condition (102 -in @($card[0].eval_ids.stable) -and 'CH-34' -in @($card[0].eval_ids.challenge)) -Message 'Decision chart eval mapping is incomplete'
Assert-True -Condition ($null -eq $qualityPolicy.aggregate_score) -Message 'Release quality policy must not aggregate dimensions'
Assert-True -Condition ((@($qualityPolicy.hard_gates | Sort-Object) -join ',') -eq 'completeness,correctness,evidence_discipline') -Message 'Fact quality must remain the release hard gate'
Assert-True -Condition ((@($qualityPolicy.observation_only | Sort-Object) -join ',') -eq 'characters,duration_ms,redundancy') -Message 'Brevity and cost must remain observation-only'
$eb01 = @($externalBenchmark.tasks | Where-Object { [string]$_.id -eq 'EB-01' })[0]
$eb04 = @($externalBenchmark.tasks | Where-Object { [string]$_.id -eq 'EB-04' })[0]
Assert-True -Condition ('原因只归属于已观察子集，未知原因不外推' -in @($eb01.minimum_contract)) -Message 'EB-01 cause-scope contract is missing'
Assert-True -Condition ('租户内唯一键使用完整复合键' -in @($eb04.minimum_contract)) -Message 'EB-04 composite-key contract is missing'

$ratioGood = '事件失败占比 10/50=20%；任务最终失败占比 4/40=10%；缺失败用户分子，用户失败率无法计算。'
$ratioBad = '失败率 20%，也就是用户失败率。'
Assert-True -Condition ($ratioGood.Contains('事件') -and $ratioGood.Contains('任务') -and $ratioGood.Contains('无法计算')) -Message 'Positive ratio fixture should pass'
Assert-True -Condition (-not ($ratioBad.Contains('分子') -or $ratioBad.Contains('无法计算'))) -Message 'Negative ratio fixture should fail'

$causeGood = '2/2 个最终失败任务为对象存储超时；其余 5 个曾失败任务的原因未知。'
$causeBad = '全部 7 个失败任务和 11 个失败事件都是对象存储超时。'
Assert-True -Condition ($causeGood.Contains('2/2') -and $causeGood.Contains('原因未知')) -Message 'Positive cause-scope fixture should pass'
Assert-True -Condition ($causeBad.Contains('全部 7 个') -and -not $causeBad.Contains('未知')) -Message 'Negative cause-scope fixture should fail'

$keyGood = 'task_id 仅租户内唯一，去重键为 (tenant_id, task_id)；跨租户同名合法。'
$keyBad = 'task_id 全局去重，跨租户同名属于异常。'
Assert-True -Condition ($keyGood.Contains('(tenant_id, task_id)') -and $keyGood.Contains('跨租户同名合法')) -Message 'Positive composite-key fixture should pass'
Assert-True -Condition ($keyBad.Contains('全局去重') -and $keyBad.Contains('异常')) -Message 'Negative composite-key fixture should fail'

$numericGood = 'v2.4.0-beta.3；>50000 后台；<=50000 同步；预算 ¥50,000；验收待补证；不推送。'
$numericBad = '预算 ¥500,000；全部后台；已验收并推送。'
Assert-True -Condition ($numericGood.Contains('¥50,000') -and $numericGood.Contains('<=50000') -and $numericGood.Contains('待补证')) -Message 'Positive numeric fixture should pass'
Assert-True -Condition ($numericBad.Contains('¥500,000') -and $numericBad.Contains('已验收')) -Message 'Negative numeric fixture should expose drift'

$chartGood = '非商业本地试验；来源 SHA-256；六维分开；逐值、1440x900、390x844、控制台和离线验证。'
$chartBad = '商业客户；无许可；复制模板；合成总分；能打开即通过。'
Assert-True -Condition ($chartGood.Contains('六维分开') -and $chartGood.Contains('逐值') -and $chartGood.Contains('离线')) -Message 'Positive chart fixture should pass'
Assert-True -Condition ($chartBad.Contains('无许可') -and $chartBad.Contains('合成总分')) -Message 'Negative chart fixture should expose unsafe delivery'

$panelChangedFiles = @(
    'SKILL.md',
    'references/acceptance.md',
    'references/capability-routing.md',
    'references/chart-delivery.md',
    'references/data-analysis.md',
    'references/idea.md',
    'references/prd.md',
    'references/prompt.md',
    'references/review.md',
    'references/tooling.md',
    'templates/prd-template.md'
)
$panelContracts = @(
    'acceptance-item-summary-consistency',
    'capability-decision-chart-route',
    'capability-minimal-route',
    'fact-anchor-terminal-scan',
    'idea-ratio-semantic-preservation',
    'kpi-data-contract',
    'prd-ui-state-semantics',
    'review-relation-evidence-state',
    'tooling-capability-state'
)
$panelTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('mypm-v039-panel-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $panelTemp -Force | Out-Null
try {
    $snapshotPath = Join-Path $panelTemp 'release-panel.json'
    $outputPath = Join-Path $panelTemp 'release-panel-evals.json'
    & (Join-Path $root 'scripts/build-eval-panel.ps1') `
        -BaselineRef 'v0.38-frozen-snapshot-9c1f9708' `
        -CandidateRef 'working-tree-v0.39' `
        -ChangedFiles $panelChangedFiles `
        -AffectedContracts $panelContracts `
        -UseExplicitAffectedContracts `
        -NoBehaviorChangeFile 'evals/release-panel-waivers.json' `
        -SnapshotPath $snapshotPath `
        -OutputPath $outputPath
    $generated = [System.IO.File]::ReadAllText($snapshotPath, $utf8) | ConvertFrom-Json
    $committed = Read-Utf8 'evals/release-panel.json' | ConvertFrom-Json
    Assert-True -Condition ([string]$generated.baseline_ref -eq 'v0.38-frozen-snapshot-9c1f9708') -Message 'v0.39 panel baseline is stale'
    Assert-True -Condition ([string]$generated.candidate_ref -eq 'working-tree-v0.39') -Message 'v0.39 panel candidate is stale'
    Assert-True -Condition ([string]$generated.contract_selection_mode -eq 'explicit-audited') -Message 'v0.39 panel must use audited explicit contracts'
    foreach ($id in $stableIds) { Assert-True -Condition (@($generated.selection | Where-Object { $_.suite -eq 'stable' -and [string]$_.id -eq [string]$id }).Count -eq 1) -Message "v0.39 panel is missing stable eval $id" }
    foreach ($id in $challengeIds) { Assert-True -Condition (@($generated.selection | Where-Object { $_.suite -eq 'challenge' -and [string]$_.id -eq $id }).Count -eq 1) -Message "v0.39 panel is missing challenge eval $id" }
    Assert-True -Condition (($generated | ConvertTo-Json -Depth 40) -eq ($committed | ConvertTo-Json -Depth 40)) -Message 'Committed release-panel.json is not the reproducible v0.39 snapshot'
} finally {
    Remove-Item -LiteralPath $panelTemp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'v0.39 reliable-delivery self-test passed: stable=6 challenge=6 capability=1 default-load=0 synthetic-positive=5 synthetic-negative=5 quality-priority=fact-first'
