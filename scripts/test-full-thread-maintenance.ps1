$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$texts = @{}
foreach ($path in @('references/memory-integration.md','references/workflow-control.md','references/development-handoff.md','references/prompt.md','templates/progress-template.md')) {
    $texts[$path] = Get-Content -LiteralPath (Join-Path $root $path) -Raw -Encoding UTF8
}
function Get-ContractErrors([hashtable]$Sources) {
    $memory = $Sources['references/memory-integration.md']
    if ($memory -match '[A-Za-z]:[\\/]') { 'memory-fixed-root' }
    foreach ($token in @('只有 `auto` 执行自动恢复/写入合同','`off` 不读写也不给 Memory 建议','`suggest` 只给建议','未执行搜索/读取','不把重启设为必经步骤','授权不自动扩展','仓库读取结果单独据实报告')) {
        if (-not $memory.Contains($token)) { "memory:$token" }
    }
    if ($Sources['references/workflow-control.md'] -match '门禁和任务状态统一使用') { 'conflated-states' }
    foreach ($token in @('任务执行、门禁证据与验收结论分别记录','脚本完成不等于数据处理完成','建议先做受控小样本')) {
        if (-not $Sources['references/workflow-control.md'].Contains($token)) { "states:$token" }
    }
    if (-not $Sources['references/development-handoff.md'].Contains('以下 Memory 条目和示例均受此条件约束')) { 'handoff-mode-scope' }
    if (-not $Sources['references/prompt.md'].Contains('旧机器的绝对路径只作需映射线索')) { 'portable-handoff' }
    foreach ($token in @('任务执行状态：','门禁证据状态：','验收结论：')) {
        if (-not $Sources['templates/progress-template.md'].Contains($token)) { "template:$token" }
    }
}
function Get-PanelErrors($Panel) {
    $cases = @($Panel.evals)
    if ($cases.Count -ne 10 -or @($cases.id | Sort-Object -Unique).Count -ne 10 -or @($cases.name | Sort-Object -Unique).Count -ne 10) { 'panel-identity' }
    foreach ($case in $cases) {
        if ([string]::IsNullOrWhiteSpace($case.prompt) -or @($case.expectations).Count -lt 4) { 'panel-content' }
        if (@($case.issues).Count -eq 0 -or @($case.issues | Where-Object { $_ -notmatch '^R-0[1-8]$' }).Count) { 'panel-issue' }
        $files = @($case.files)
        $fixtures = @($case.fixture_files.PSObject.Properties.Name)
        if ((($files | Sort-Object) -join '|') -cne (($fixtures | Sort-Object) -join '|')) { 'panel-files' }
        foreach ($path in $files) {
            if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|[/\\])\.\.([/\\]|$)|:') { 'panel-path' }
        }
    }
    $multi = @($cases | Where-Object { $_.id -eq 4 })
    if ($multi.Count -ne 1 -or @($multi[0].turns).Count -ne 3) { 'panel-multi-turn' }
}
function Assert-Result($Errors, [string]$Expected, [string]$Label) {
    $found = @($Errors | Where-Object { $null -ne $_ })
    if ($Expected) {
        if ($Expected -notin $found) { throw "$Label did not detect $Expected : $found" }
    } elseif ($found.Count) { throw "$Label : $found" }
    Write-Host "PASS: $Label"
}
Assert-Result (Get-ContractErrors $texts) '' 'current runtime/template consistency'
foreach ($mutation in @(
    @{path='references/memory-integration.md';old='不内置某台电脑的路径';new='路径固定 C:\Example\memory-root';error='memory-fixed-root'},
    @{path='references/memory-integration.md';old='只有 `auto` 执行自动恢复/写入合同';new='所有模式执行恢复';error='memory:只有 `auto` 执行自动恢复/写入合同'},
    @{path='references/memory-integration.md';old='`off` 不读写也不给 Memory 建议';new='off 也建议';error='memory:`off` 不读写也不给 Memory 建议'},
    @{path='references/memory-integration.md';old='未执行搜索/读取';new='已恢复';error='memory:未执行搜索/读取'},
    @{path='references/memory-integration.md';old='授权不自动扩展';new='授权自动扩展';error='memory:授权不自动扩展'},
    @{path='references/memory-integration.md';old='仓库读取结果单独据实报告';new='仓库一律未核对';error='memory:仓库读取结果单独据实报告'},
    @{path='references/workflow-control.md';old='任务执行、门禁证据与验收结论分别记录';new='正式门禁和任务状态统一使用';error='conflated-states'},
    @{path='references/workflow-control.md';old='建议先做受控小样本';new='直接跑全部';error='states:建议先做受控小样本'},
    @{path='references/development-handoff.md';old='以下 Memory 条目和示例均受此条件约束';new='以下总是执行';error='handoff-mode-scope'},
    @{path='references/prompt.md';old='旧机器的绝对路径只作需映射线索';new='沿用旧根';error='portable-handoff'},
    @{path='templates/progress-template.md';old='门禁证据状态：';new='状态：';error='template:门禁证据状态：'}
)) {
    $changed = $texts.Clone()
    if (-not $changed[$mutation.path].Contains($mutation.old)) { throw 'Mutation did not hit source' }
    $changed[$mutation.path] = $changed[$mutation.path].Replace($mutation.old,$mutation.new)
    Assert-Result (Get-ContractErrors $changed) $mutation.error "reject $($mutation.error)"
}
$json = Get-Content -LiteralPath (Join-Path $root 'evals/v042-full-thread-maintenance-evals.json') -Raw -Encoding UTF8
Assert-Result (Get-PanelErrors ($json | ConvertFrom-Json)) '' 'ten supplemental fixtures'
foreach ($kind in @('identity','content','issue','files','path','multi-turn')) {
    $panel = $json | ConvertFrom-Json
    switch ($kind) {
        'identity' { $panel.evals[1].id = $panel.evals[0].id }
        'content' { $panel.evals[0].prompt = '' }
        'issue' { $panel.evals[0].issues = @('R-99') }
        'files' { $panel.evals[0].files = @('other.sql') }
        'path' { $panel.evals[0].files = @('../escape.sql') }
        'multi-turn' { $panel.evals[3].turns = @('continue') }
    }
    Assert-Result (Get-PanelErrors $panel) "panel-$kind" "reject panel $kind"
}
Write-Host 'Full-thread maintenance checks passed: 2 valid fixtures and 17 negative mutations; text/structure only, no model behavior.'
