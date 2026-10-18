$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Read-Text([string]$Path) { Get-Content -LiteralPath (Join-Path $root $Path) -Raw -Encoding UTF8 }
function Assert-Guards([string]$Prompt, [string]$Acceptance, [string]$Visual, [string]$Local) {
    foreach ($pair in @(
        @($Prompt, '阶段不能证明资产不存在'),
        @($Prompt, '未提供写“未提供，待核对”'),
        @($Acceptance, '明确要求签名时阻塞该安装器'),
        @($Acceptance, '要求未提供时列待核实风险与签名建议'),
        @($Visual, '正式出图与图表验收都核对来源版本/定位'),
        @($Visual, '非 HTML 不强加浏览器检查'),
        @($Local, '日志 `event/report` 直接访问本地 SQLite'),
        @($Local, '正常、非零返回、超时都释放本次进程树')
    )) { if (-not $pair[0].Contains($pair[1])) { throw "Missing repair guard: $($pair[1])" } }
}
$texts = @((Read-Text 'references/prompt.md'), (Read-Text 'references/acceptance.md'),
           (Read-Text 'references/visual-delivery.md'), (Read-Text 'references/local-memory-diagnostics.md'))
Assert-Guards @texts
$mutations = @(
    @{i=0;t='阶段不能证明资产不存在'}, @{i=0;t='未提供写“未提供，待核对”'},
    @{i=1;t='明确要求签名时阻塞该安装器'}, @{i=1;t='要求未提供时列待核实风险与签名建议'},
    @{i=2;t='正式出图与图表验收都核对来源版本/定位'}, @{i=2;t='非 HTML 不强加浏览器检查'},
    @{i=3;t='日志 `event/report` 直接访问本地 SQLite'}, @{i=3;t='正常、非零返回、超时都释放本次进程树'}
)
foreach ($m in $mutations) {
    $changed = $texts.Clone()
    $changed[$m.i] = $changed[$m.i].Replace($m.t, 'removed')
    $rejected = $false
    try { Assert-Guards @changed } catch { $rejected = $true }
    if (-not $rejected) { throw "Missed mutation: $($m.t)" }
}
$stable = (Read-Text 'evals/evals.json' | ConvertFrom-Json).evals
$challenge = (Read-Text 'evals/challenge-evals.json' | ConvertFrom-Json).evals
foreach ($case in @($stable | Where-Object { $_.id -in @(39,53) }) + @($challenge | Where-Object { $_.id -eq 'CH-10' })) {
    if (($case.expectations -join '') -match '未签名安装器(不能|不得)') { throw "Blanket signature ban remains: $($case.id)" }
}
Write-Host 'Post-regression text guards passed: current plus 8 negative mutations and 3 signing rubrics; not model behavior.'
