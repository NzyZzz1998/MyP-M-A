$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing v0.38 file: $RelativePath" }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Assert-True {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-ContainsAll {
    param([string]$Text, [string[]]$Values, [string]$Label)
    foreach ($value in $Values) {
        Assert-True -Condition $Text.Contains($value) -Message "$Label is missing: $value"
    }
}

function Test-MinimalAction {
    param([string]$Text)
    return $Text.Contains('负责人') -and $Text.Contains('输入') -and $Text.Contains('产物') -and
        $Text.Contains('停止条件') -and $Text.Contains('回写') -and $Text.Contains('确认前不是正式门禁') -and
        $Text -notmatch '(?<!无量表的)31/40.{0,8}(正式|通过|批准)'
}

function Test-HandoffGateDiscipline {
    param([string]$Text)
    return $Text.Contains('dist/App-v2.1.zip') -and $Text.Contains('A19F0C7E2B4D') -and
        $Text -notmatch '(缺少|必须提供)(分支|HEAD|dirty).{0,12}(停止|阻塞|不得验收)'
}

function Test-AdapterEnvelope {
    param([string]$Text)
    foreach ($field in @('source_system', 'object_type/object_id', 'captured_at', 'version_or_ref', 'scope_or_filter', 'access_mode', 'facts', 'freshness', 'limitations', 'evidence_location')) {
        if (-not $Text.Contains($field)) { return $false }
    }
    return $true
}

function Test-StableIdentityJoin {
    param([string]$Text)
    return $Text.Contains('TASK-88') -and $Text.Contains('PR-42') -and
        $Text.Contains('不能') -and $Text.Contains('标题') -and
        $Text -notmatch 'TASK-88\s*(=|即|就是)\s*PR-42'
}

$skill = Read-Utf8 'SKILL.md'
$idea = Read-Utf8 'references/idea.md'
$prompt = Read-Utf8 'references/prompt.md'
$acceptance = Read-Utf8 'references/acceptance.md'
$adapter = Read-Utf8 'references/enterprise-adapters.md'
$routing = Read-Utf8 'references/capability-routing.md'
$rules = Read-Utf8 'scripts/validation/rules.json' | ConvertFrom-Json
$stable = Read-Utf8 'evals/evals.json' | ConvertFrom-Json
$challenge = Read-Utf8 'evals/challenge-evals.json' | ConvertFrom-Json
$contracts = Read-Utf8 'evals/contract-registry.json' | ConvertFrom-Json
$lifecycle = Read-Utf8 'evals/eval-lifecycle.json' | ConvertFrom-Json
$capabilities = Read-Utf8 'capabilities/registry.json' | ConvertFrom-Json

$versionMatch = [regex]::Match($skill, 'version:\s*"(?<version>\d+\.\d+\.\d+)"')
Assert-True -Condition ($versionMatch.Success -and [version]$versionMatch.Groups['version'].Value -ge [version]'0.38.0') -Message 'SKILL.md version must preserve v0.38 behavior or later'
Assert-ContainsAll -Text $idea -Label 'Evidence-to-action contract' -Values @('evidence-action-minimal-contract', '负责人角色', '可检查产物', '确认前不是正式门禁', '回写位置不可省略', '证据区之后只能用', '禁止重列数字或用自然语言改写同一事实', '正文不得超过 1200 字', '不删结论、证据边界或行动合同')
Assert-ContainsAll -Text $prompt -Label 'Handoff gate contract' -Values @('handoff-no-new-gates', '不得把可选的分支、HEAD、dirty', '新增为硬门禁')
Assert-ContainsAll -Text $acceptance -Label 'Acceptance identity contract' -Values @('产物验收优先', '不得因材料未要求的字段缺失而新增硬门禁')
Assert-True -Condition (Test-AdapterEnvelope $adapter) -Message 'Enterprise adapter envelope is incomplete'
Assert-ContainsAll -Text $adapter -Label 'Enterprise adapter authorization' -Values @('默认只读', '标题、姓名或文本相似不能自动证明是同一对象', '任何写入另行授权')
Assert-True -Condition $routing.Contains('capability-enterprise-adapter-route') -Message 'Enterprise adapter route contract is missing'

$requiredLoading = @($rules.required_loading_routes.PSObject.Properties | ForEach-Object { @($_.Value) })
Assert-True -Condition ('references/enterprise-adapters.md' -notin $requiredLoading) -Message 'Enterprise adapter must not become a default route dependency'

$stableIds = @(93..96)
$challengeIds = @('CH-26', 'CH-27', 'CH-28')
foreach ($id in $stableIds) {
    Assert-True -Condition (@($stable.evals | Where-Object { [int]$_.id -eq $id }).Count -eq 1) -Message "Stable v0.38 eval must exist once: $id"
    $owners = @($contracts.contracts | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count +
        @($lifecycle.scenario_groups | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition ($owners -eq 1) -Message "Stable v0.38 eval ownership must be unique: $id"
}
foreach ($id in $challengeIds) {
    Assert-True -Condition (@($challenge.evals | Where-Object { [string]$_.id -eq $id }).Count -eq 1) -Message "Challenge v0.38 eval must exist once: $id"
    $owners = @($contracts.contracts | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count +
        @($lifecycle.scenario_groups | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition ($owners -eq 1) -Message "Challenge v0.38 eval ownership must be unique: $id"
}

foreach ($file in @(
    'evals/files/v038-evidence-action.md',
    'evals/files/v038-handoff-minimal.md',
    'evals/files/v038-enterprise-project.md',
    'evals/files/v038-product-data.md'
)) { [void](Read-Utf8 $file) }

$projectCard = @($capabilities.capabilities | Where-Object { [string]$_.id -eq 'collaboration.project-evidence-adapter' })
$dataCard = @($capabilities.capabilities | Where-Object { [string]$_.id -eq 'analytics.product-evidence-adapter' })
Assert-True -Condition ($projectCard.Count -eq 1 -and [string]$projectCard[0].status -eq 'pilot') -Message 'Project evidence adapter capability is not a single pilot'
Assert-True -Condition ($dataCard.Count -eq 1 -and [string]$dataCard[0].status -eq 'pilot') -Message 'Product evidence adapter capability is not a single pilot'
Assert-True -Condition (95 -in @($projectCard[0].eval_ids.stable) -and 'CH-26' -in @($projectCard[0].eval_ids.challenge)) -Message 'Project adapter eval mapping is incomplete'
Assert-True -Condition (96 -in @($dataCard[0].eval_ids.stable) -and 'CH-27' -in @($dataCard[0].eval_ids.challenge)) -Message 'Product adapter eval mapping is incomplete'

$actionGood = '负责人：产品经理；输入：18 条反馈；产物：验证记录；建议阈值确认前不是正式门禁；停止条件：无可绑定任务；回写：需求池。'
$actionBad = '31/40 正式通过，直接开发。'
Assert-True -Condition (Test-MinimalAction $actionGood) -Message 'Positive evidence-to-action fixture should pass'
Assert-True -Condition (-not (Test-MinimalAction $actionBad)) -Message 'Pseudo-precision action fixture should fail'

$handoffGood = '验收 dist/App-v2.1.zip，SHA-256 A19F0C7E2B4D；材料未提供分支和 HEAD，不新增门禁。'
$handoffBad = '缺少 HEAD，必须提供分支后停止验收。'
Assert-True -Condition (Test-HandoffGateDiscipline $handoffGood) -Message 'Positive handoff fixture should pass'
Assert-True -Condition (-not (Test-HandoffGateDiscipline $handoffBad)) -Message 'Invented identity gate fixture should fail'

$identityGood = 'TASK-88 与 PR-42 标题相同，但标题不能证明是同一对象。'
$identityBad = 'TASK-88 = PR-42，因为标题相同。'
Assert-True -Condition (Test-StableIdentityJoin $identityGood) -Message 'Positive cross-system identity fixture should pass'
Assert-True -Condition (-not (Test-StableIdentityJoin $identityBad)) -Message 'Title-only object merge fixture should fail'

$panelChangedFiles = @(
    'SKILL.md',
    'references/acceptance.md',
    'references/capability-routing.md',
    'references/enterprise-adapters.md',
    'references/idea.md',
    'references/prd.md',
    'references/prompt.md',
    'references/review.md',
    'references/tooling.md'
)
$panelContracts = @(
    'acceptance-artifact-evidence-freshness',
    'capability-minimal-route',
    'enterprise-adapter-data-provenance',
    'enterprise-adapter-readonly',
    'evidence-action-minimal-contract',
    'handoff-no-new-gates',
    'prd-known-facts',
    'review-evidence-handoff',
    'tooling-capability-state'
)
$panelTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('mypm-v038-panel-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $panelTemp -Force | Out-Null
try {
    $snapshotPath = Join-Path $panelTemp 'release-panel.json'
    $outputPath = Join-Path $panelTemp 'release-panel-evals.json'
    & (Join-Path $root 'scripts\build-eval-panel.ps1') `
        -BaselineRef 'v0.37-frozen-candidate-88bce700' `
        -CandidateRef 'working-tree-v0.38' `
        -ChangedFiles $panelChangedFiles `
        -AffectedContracts $panelContracts `
        -UseExplicitAffectedContracts `
        -NoBehaviorChangeFile 'evals\release-panel-waivers.json' `
        -SnapshotPath $snapshotPath `
        -OutputPath $outputPath

    $generatedPanel = [System.IO.File]::ReadAllText($snapshotPath, $utf8) | ConvertFrom-Json
    Assert-True -Condition ([string]$generatedPanel.baseline_ref -eq 'v0.37-frozen-candidate-88bce700') -Message 'v0.38 release panel baseline is stale'
    Assert-True -Condition ([string]$generatedPanel.candidate_ref -eq 'working-tree-v0.38') -Message 'v0.38 release panel candidate is stale'
    Assert-True -Condition ([string]$generatedPanel.contract_selection_mode -eq 'explicit-audited') -Message 'v0.38 release panel must use audited explicit contracts'
    Assert-True -Condition (@($generatedPanel.selection).Count -le [int]$generatedPanel.max_cases) -Message 'v0.38 release panel silently exceeded max cases'
    Assert-True -Condition (@($generatedPanel.affected_contracts).Count -eq $panelContracts.Count) -Message 'v0.38 release panel contract count is inconsistent'
    Assert-True -Condition ((@($generatedPanel.changed_files) -join '|') -eq (@($panelChangedFiles | Sort-Object -Unique) -join '|')) -Message 'v0.38 release panel changed-file scope is inconsistent'
    foreach ($id in @(93, 94, 95, 96)) {
        Assert-True -Condition (@($generatedPanel.selection | Where-Object { [string]$_.suite -eq 'stable' -and [string]$_.id -eq [string]$id }).Count -eq 1) -Message "v0.38 release panel is missing stable eval $id"
    }
    foreach ($id in @('CH-26', 'CH-27', 'CH-28')) {
        Assert-True -Condition (@($generatedPanel.selection | Where-Object { [string]$_.suite -eq 'challenge' -and [string]$_.id -eq $id }).Count -eq 1) -Message "v0.38 release panel is missing challenge eval $id"
    }
} finally {
    Remove-Item -LiteralPath $panelTemp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'v0.38 evidence/action/adapter self-test passed: stable=4 challenge=3 capabilities=2 default-load=0 synthetic-positive=3 synthetic-negative=3'
