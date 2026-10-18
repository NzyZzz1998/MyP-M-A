$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert-OptInDefaults($Config) {
    foreach ($name in @('memory', 'diagnostics')) {
        if ($Config.$name.mode -ne 'off' -or $Config.$name.consent -isnot [bool] -or $Config.$name.consent) {
            throw "Default opt-in contract violated: $name"
        }
    }
}
$raw = Get-Content -LiteralPath (Join-Path $root 'templates/local-memory-config.example.json') -Raw -Encoding UTF8
Assert-OptInDefaults ($raw | ConvertFrom-Json)
foreach ($name in @('memory', 'diagnostics')) {
    foreach ($mutation in @('mode', 'consent')) {
        $changed = $raw | ConvertFrom-Json
        if ($mutation -eq 'mode') { $changed.$name.mode = 'auto' } else { $changed.$name.consent = $true }
        $rejected = $false
        try { Assert-OptInDefaults $changed } catch { $rejected = $true }
        if (-not $rejected) { throw "Missed opt-in mutation: $name/$mutation" }
    }
}
$skill = Get-Content -LiteralPath (Join-Path $root 'SKILL.md') -Raw -Encoding UTF8
foreach ($token in @('`memory_mode` 默认 `off`', '明确授权', 'Token', '日志独立授权、默认关闭')) {
    if (-not $skill.Contains($token)) { throw "Missing entry consent guard: $token" }
}
$local = Get-Content -LiteralPath (Join-Path $root 'references/local-memory-diagnostics.md') -Raw -Encoding UTF8
function Assert-LocalLifecycle([string]$Skill, [string]$Local) {
    $discovery = $Skill.IndexOf('`.mypm.local.json`')
    if ($discovery -lt 0 -or $discovery -gt $Skill.IndexOf('## 渐进加载')) {
        throw 'Missing early project-local consent discovery'
    }
    if ($Skill.Substring($Skill.IndexOf('## 完成检查')) -notmatch '本地收尾回执') {
        throw 'Missing local closeout receipt in completion check'
    }
    foreach ($token in @('route_selected', 'delivery_completed', 'written_verified', '只开日志', '只读或禁止任何写入', '完整原笔记')) {
        if (-not $Local.Contains($token)) { throw "Missing local lifecycle guard: $token" }
    }
}
Assert-LocalLifecycle $skill $local
$mutations = @(
    @{ skill = $skill.Replace('`.mypm.local.json`', 'local config'); local = $local },
    @{ skill = $skill.Replace('本地收尾回执', 'optional'); local = $local },
    @{ skill = $skill; local = $local.Replace('route_selected', 'route') },
    @{ skill = $skill; local = $local.Replace('delivery_completed', 'delivery') },
    @{ skill = $skill; local = $local.Replace('只读或禁止任何写入', 'bounded task') },
    @{ skill = $skill; local = $local.Replace('只开日志', 'logging') }
)
foreach ($mutation in $mutations) {
    $rejected = $false
    try { Assert-LocalLifecycle $mutation.skill $mutation.local } catch { $rejected = $true }
    if (-not $rejected) { throw 'Missed local lifecycle mutation' }
}
$panel = Get-Content -LiteralPath (Join-Path $root 'evals/local-memory-consent-cases.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($panel.cases).Count -ne 6 -or @($panel.cases.id | Sort-Object -Unique).Count -ne 6) { throw 'Memory supplemental panel identity drift' }
foreach ($case in $panel.cases) {
    if ([string]::IsNullOrWhiteSpace($case.prompt) -or @($case.expected).Count -ne 3) { throw "Invalid local scenario: $($case.id)" }
}
$stable = Get-Content -LiteralPath (Join-Path $root 'evals/evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($id in @(42, 43)) {
    $case = @($stable.evals | Where-Object { $_.id -eq $id })
    if ($case.Count -ne 1 -or $case[0].prompt -notmatch '(授权|允许)') { throw "Missing explicit memory consent in stable $id" }
}
$challenge = Get-Content -LiteralPath (Join-Path $root 'evals/challenge-evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$case = @($challenge.evals | Where-Object { $_.id -eq 'CH-11' })
if ($case.Count -ne 1 -or $case[0].prompt -notmatch '(授权|允许)') { throw 'Missing explicit memory consent in CH-11' }
Write-Host 'Local memory governance passed: off defaults, 4 consent and 6 lifecycle negative mutations, 6 scenario structures, 3 corrected existing cases; no model execution.'
