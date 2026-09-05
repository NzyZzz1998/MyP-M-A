param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing v0.41 file: $RelativePath" }
    return [System.IO.File]::ReadAllText($path, $utf8)
}

function Assert-True {
    param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$skill = Read-Utf8 'SKILL.md'
$boundary = Read-Utf8 'references/work-mode-boundary.md'
$prd = Read-Utf8 'references/prd.md'
$review = Read-Utf8 'references/review.md'
$acceptance = Read-Utf8 'references/acceptance.md'
$prompt = Read-Utf8 'references/prompt.md'
$handoff = Read-Utf8 'references/development-handoff.md'
$teamTemplate = Read-Utf8 'templates/prd-team-template.md'
$vibeTemplate = Read-Utf8 'templates/prd-template.md'
$rules = Read-Utf8 'scripts/validation/rules.json' | ConvertFrom-Json
$stable = Read-Utf8 'evals/evals.json' | ConvertFrom-Json
$challenge = Read-Utf8 'evals/challenge-evals.json' | ConvertFrom-Json
$contracts = Read-Utf8 'evals/contract-registry.json' | ConvertFrom-Json
$panel = Read-Utf8 'evals/release-panel.json' | ConvertFrom-Json

$currentVersion = [regex]::Match($skill, '(?m)^\s+version:\s+"([^"]+)"').Groups[1].Value
Assert-True ($currentVersion -in @('0.41.0', '0.42.0')) 'v0.41 historical self-test supports versions 0.41.0 and 0.42.0'
Assert-True ($skill.Contains('delivery_mode=auto') -and $skill.Contains('team_pm') -and $skill.Contains('vibe_coding')) 'Mode router is incomplete'
Assert-True ($skill.Contains('组织协作或意图不明解析为 `team_pm`')) 'Ambiguous mode must default to team_pm'

$anchors = @(
    'work-mode-resolution',
    'work-mode-pm-ownership',
    'work-mode-vibe-depth',
    'work-mode-handoff-authorization',
    'work-mode-fact-parity',
    'work-mode-inheritance',
    'work-mode-acceptance-boundary',
    'work-mode-review-boundary',
    'work-mode-team-template'
)
foreach ($id in $anchors) {
    $mapped = @($contracts.contracts | Where-Object { [string]$_.contract_id -eq $id })
    Assert-True ($mapped.Count -eq 1) "v0.41 contract must exist once: $id"
    $source = Read-Utf8 ([string]$mapped[0].source_file)
    Assert-True $source.Contains("contract:$id") "Contract source is missing anchor: $id"
}

Assert-True ($boundary.Contains('模糊场景是否默认 `team_pm`') -and $boundary.Contains('模式只改变职责和技术深度')) 'Boundary fact-parity rule is missing'
Assert-True ($prd.Contains('端点、协议、表/列/索引、SQL、框架、文件、类、测试实现和部署由下游确认')) 'Team PM implementation boundary is missing'
Assert-True ($review.Contains('不直接替研发做方案')) 'Review engineering handoff boundary is missing'
Assert-True ($acceptance.Contains('不代写或执行构建、迁移、CI、部署脚本')) 'Acceptance execution boundary is missing'
Assert-True ($prompt.Contains('不得把团队产品文档静默升级')) 'Prompt mode inheritance is missing'
Assert-True ($handoff.Contains('模式切换必须由用户授权')) 'Development handoff authorization is missing'
Assert-True ($teamTemplate.Contains('默认停在团队评审与承接点')) 'Team PRD must stop before automatic engineering handoff'
Assert-True ($teamTemplate.Contains('API、表结构、索引、迁移、缓存、日志字段等')) 'Team template must name downstream technical decisions without inventing them'
Assert-True ($vibeTemplate.Contains('Vibe Coding 全流程型')) 'Vibe template identity is missing'

$requiredPrd = @($rules.required_loading_routes.prd)
Assert-True ('references/work-mode-boundary.md' -in $requiredPrd) 'PRD route must load work-mode-boundary.md'
Assert-True ('templates/prd-team-template.md' -notin @($rules.required_loading_routes.review)) 'Team PRD template must not leak into review minimum context'

foreach ($id in @(107..114)) {
    Assert-True (@($stable.evals | Where-Object { [int]$_.id -eq $id }).Count -eq 1) "Stable v0.41 eval must exist once: $id"
    Assert-True (@($contracts.contracts | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count -ge 1) "Stable v0.41 eval must be contract mapped: $id"
}
foreach ($id in @('CH-40', 'CH-41', 'CH-42', 'CH-43', 'CH-44', 'CH-45', 'CH-46')) {
    $eval = @($challenge.evals | Where-Object { [string]$_.id -eq $id })
    Assert-True ($eval.Count -eq 1) "Challenge v0.41 eval must exist once: $id"
    Assert-True (@($eval[0].expectations).Count -ge 7) "Challenge v0.41 eval must have at least 7 expectations: $id"
    Assert-True (@($contracts.contracts | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains $id }).Count -ge 1) "Challenge v0.41 eval must be contract mapped: $id"
}

$expectedRoutes = @{
    '107' = '/prd'; '108' = '/prd'; '109' = '/prd'; '110' = '/prd'
    '111' = '/acceptance'; '112' = '/prompt'; '113' = '/prd'; '114' = '/review'
    'CH-40' = '/prd'; 'CH-41' = '/prd'; 'CH-42' = '/prd'; 'CH-43' = '/prompt'
    'CH-44' = '/prd'; 'CH-45' = '/acceptance'; 'CH-46' = '/prd'
}
foreach ($id in $expectedRoutes.Keys) {
    $entry = @($panel.selection | Where-Object { [string]$_.id -eq $id })
    Assert-True ($entry.Count -eq 1) "v0.41 eval must appear once in release panel: $id"
    Assert-True ([string]$entry[0].route -eq [string]$expectedRoutes[$id]) "v0.41 release-panel route drift: $id"
}

$allEvals = @($stable.evals) + @($challenge.evals)
foreach ($entry in @($panel.selection)) {
    $sourceEval = @($allEvals | Where-Object { [string]$_.id -eq [string]$entry.id })
    Assert-True ($sourceEval.Count -eq 1) "Release-panel source eval must exist once: $($entry.id)"
    $firstLine = @(([string]$sourceEval[0].prompt) -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[0]
    if ($firstLine -match '^\s*(/[a-z]+)\b') {
        Assert-True ([string]$entry.route -eq [string]$Matches[1]) "Release-panel prompt route drift: $($entry.id)"
    }
}

$skillChars = (($skill -replace "`r`n?", "`n")).Length
Assert-True ($skillChars -le [int]$rules.skill_char_budget) "SKILL.md exceeds budget: $skillChars"

Write-Host 'v0.41 work-mode self-test passed: stable=8 challenge=7 contracts=9 team-default=1 vibe-depth=1 fact-parity=1'
