$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'validation/validate-docs.ps1')
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mypm-v042-' + [Guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
function Assert-Observation {
    param([bool]$Valid, [string]$Label, [string]$ExpectedError, [int]$ExpectedWarnings = -1)
    $result = New-MypmValidationResult
    Invoke-MypmLatestObservationValidation -Root $temp -Result $result
    if (($result.Errors.Count -eq 0) -ne $Valid) { throw "$Label : $($result.Errors -join '; ')" }
    if ($ExpectedError -and ($result.Errors -join '; ') -notmatch $ExpectedError) { throw "$Label : missing expected error $ExpectedError" }
    if ($ExpectedWarnings -ge 0 -and $result.Warnings.Count -ne $ExpectedWarnings) { throw "$Label : unexpected warning count $($result.Warnings.Count)" }
    Write-Host "PASS: $Label"
}
try {
    & (Join-Path $PSScriptRoot 'test-local-memory-governance.ps1')
    & (Join-Path $PSScriptRoot 'test-provider-routing.ps1')
    # Text guards check instruction/template consistency, not model behavior.
    foreach ($guard in @(
        @{ path = 'references/prd.md'; tokens = @(
            '导出对象、筛选与数据截至时点', '并发/频率/容量限制及超限体验',
            '不编造存储介质、表字段、队列或 worker 实现'
        ) },
        @{ path = 'references/acceptance.md'; tokens = @(
            '已解析的交付模式', '题内已点名的负责人原样承接',
            '候选产物身份 <-> source commit/等价构建身份',
            '不清零已经绑定同一候选的独立局部证据',
            '输出四项闭包清单并逐项标 `已提供 / 缺失 / 不适用`',
            '每行在通过标准中引用既有要求的 ID 或来源',
            '新增建议另列，确认前不进入必关缺口或发布前置',
            '把既有行为展开为可观察检查不需要另设确认门禁',
            '负向验证只证明合同禁止的动作未发生',
            '只有本轮需补证的要求包含异常路径时',
            '**严重但待核实风险**', '**已证实阻塞**'
        ) },
        @{ path = 'templates/acceptance-template.md'; tokens = @(
            '交付模式：team_pm / vibe_coding', '预期标准及来源 ID / 原文',
            '不通过处理及负责人', '新增建议另列', '点名确认人及待确认状态',
            '组合证据闭包：候选产物 <-> source commit / 等价构建身份'
        ) },
        @{ path = 'templates/manual-verification-template.md'; tokens = @(
            '交付模式：继承验收文档', '来源验收 ID / 要求原文',
            '验证人 / 决策负责人', '必须满足：引用来源标准，仅展开等价观察',
            '不适用的日志、配置、文件检查略去', '新增建议单列待确认'
        ) }
    )) {
        $text = Get-Content -LiteralPath (Join-Path $root $guard.path) -Raw -Encoding UTF8
        foreach ($token in $guard.tokens) {
            if (-not $text.Contains($token)) { throw "Acceptance text guard missing in $($guard.path): $token" }
        }
        Write-Host "PASS: acceptance instruction/template text guard $($guard.path)"
    }
    $stablePanel = Get-Content -LiteralPath (Join-Path $root 'evals/evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $case61 = @($stablePanel.evals | Where-Object { [int]$_.id -eq 61 })[0]
    $case81 = @($stablePanel.evals | Where-Object { [int]$_.id -eq 81 })[0]
    if ([string]$case61.expected_output -notmatch '超限体验' -or [string]$case61.expected_output -notmatch '不应编造物理存储') { throw 'Stable 61 product-semantic async rubric drift' }
    if ([string]$case81.expected_output -notmatch '不清零已绑定同一候选的独立局部证据' -or @($case81.expectations)[2] -notmatch '等价构建身份') { throw 'Stable 81 evidence-lineage rubric drift' }
    Write-Host 'PASS: stable 61/81 contract-aligned rubric guards'
    $gatePanel = Get-Content -LiteralPath (Join-Path $root 'evals/v042-gate-boundary-evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $gateNames = @('v042_proactive_gate_suggestion', 'v042_evidenced_omitted_gate_blocks', 'v042_credible_risk_pending_verification')
    if (@($gatePanel.evals).Count -ne 3 -or @($gatePanel.evals.id | Sort-Object -Unique).Count -ne 3 -or
        @($gatePanel.evals.name | Sort-Object -Unique).Count -ne 3) { throw 'Gate boundary panel identity/count mismatch' }
    foreach ($case in $gatePanel.evals) {
        if ($case.name -notin $gateNames -or @($case.expectations).Count -lt 6 -or @($case.expectations).Count -gt 8 -or
            @($case.files).Count -ne 0 -or $case.prompt -notmatch 'delivery_mode=team_pm' -or $case.prompt -notmatch 'memory_mode=off' -or
            [string]::IsNullOrWhiteSpace($case.expected_output)) { throw "Invalid gate boundary fixture: $($case.name)" }
    }
    Write-Host 'PASS: three gate-boundary fixtures structurally valid; no model behavior tested.'
    # Maintenance fixtures supplement, but do not change, the release portfolio.
    $documentPanel = Get-Content -LiteralPath (Join-Path $root 'evals/v042-document-maintenance-evals.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($documentPanel.evals).Count -ne 7 -or @($documentPanel.evals.id | Sort-Object -Unique).Count -ne 7 -or
        @($documentPanel.evals.name | Sort-Object -Unique).Count -ne 7) { throw 'Document maintenance fixture identities must be unique' }
    foreach ($case in $documentPanel.evals) {
        if ([string]::IsNullOrWhiteSpace($case.prompt) -or @($case.expectations).Count -lt 4 -or
            @($case.issues).Count -eq 0 -or @($case.issues | Where-Object { $_ -notin @('I-01','I-03','I-04') }).Count -gt 0) {
            throw "Invalid document maintenance case: $($case.id)"
        }
        $fixtureNames = @()
        if ($case.PSObject.Properties.Name -contains 'fixture_files') {
            $fixtureNames = @($case.fixture_files.PSObject.Properties.Name)
        }
        if (@(Compare-Object @($case.files) $fixtureNames).Count -ne 0) { throw "Fixture/files mismatch: $($case.id)" }
        foreach ($path in $fixtureNames) {
            if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|[/\\])\.\.([/\\]|$)|:' -or
                [string]::IsNullOrWhiteSpace([string]$case.fixture_files.$path)) { throw "Unsafe or empty fixture: $path" }
        }
    }
    $drawio = $documentPanel.evals[2].fixture_files.'flow/收货.drawio'
    $xml = [xml]$drawio
    if (@($xml.SelectNodes('//mxCell[@edge="1"]')).Count -ne 1 -or
        @($xml.SelectNodes('//mxCell[@id="end-note"]')).Count -ne 1) { throw 'Partial-sync graph fixture lost edge or target node' }
    foreach ($guard in @(
        @{ path = 'references/prd.md'; tokens = @('直接增量修订', '用户要求完整重编', 'references/traceability.md', 'references/data-analysis.md') },
        @{ path = 'references/traceability.md'; tokens = @('跨材料同步', '历史比较和归档保留原版本', '节点文本回读不等于图形已渲染') },
        @{ path = 'references/prompt.md'; tokens = @('跨材料交接', '未同步项、原因及下一步') },
        @{ path = 'references/data-analysis.md'; tokens = @('按输出用途选择深度', '不默认平均每日百分比', '正式完整数据合同仍覆盖必要异常和验收') }
    )) {
        $text = Get-Content -LiteralPath (Join-Path $root $guard.path) -Raw -Encoding UTF8
        foreach ($token in $guard.tokens) {
            if (-not $text.Contains($token)) { throw "Document maintenance routing guard missing: $($guard.path): $token" }
        }
    }
    Write-Host 'PASS: seven document-maintenance fixtures, graph structure and routing guards; no model behavior tested.'
    & (Join-Path $PSScriptRoot 'test-full-thread-maintenance.ps1')
    New-Item -ItemType Directory -Path (Join-Path $temp 'evals'), (Join-Path $temp 'notes') -Force | Out-Null
    foreach ($file in @('evals/latest-observation.json', 'README.md', 'notes/v0.42-stable-readme-archive.md', 'notes/mypm-roadmap.md', 'notes/evaluation-history.md')) {
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $temp $file)
    }
    Assert-Observation $true 'current observation'
    $record = Get-Content (Join-Path $temp 'evals/latest-observation.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $recordPath = Join-Path $temp 'evals/latest-observation.json'
    $originalRecord = [IO.File]::ReadAllText($recordPath, [Text.Encoding]::UTF8)
    $record.snapshot_head = '0' * 40
    [IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 20), $utf8)
    Assert-Observation $false 'snapshot_head rejects forty zeros' 'snapshot_head'
    [IO.File]::WriteAllText($recordPath, $originalRecord, $utf8)
    $record = $originalRecord | ConvertFrom-Json
    foreach ($field in @('source', 'source_sha256', 'snapshot_head')) {
        foreach ($kind in @('missing', 'null', 'empty', 'whitespace', 'number', 'array')) {
            $changed = $originalRecord | ConvertFrom-Json
            switch ($kind) {
                'missing' { $changed.PSObject.Properties.Remove($field) }
                'null' { $changed.$field = $null }
                'empty' { $changed.$field = '' }
                'whitespace' { $changed.$field = '   ' }
                'number' { $changed.$field = 42 }
                'array' { $changed.$field = @($record.$field) }
            }
            [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
            Assert-Observation $false "$field rejects $kind" $field
        }
    }
    foreach ($mutation in @('missing-models', 'duplicate-models', 'score-count', 'duration-basis')) {
        $changed = $originalRecord | ConvertFrom-Json
        switch ($mutation) {
            'missing-models' { $changed.PSObject.Properties.Remove('models') }
            'duplicate-models' { $changed.models = @($changed.models[0], $changed.models[0]) }
            'score-count' { $changed.scores = @($changed.scores | Select-Object -First 2) }
            'duration-basis' { $changed.duration_basis = 'model-latency' }
        }
        [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
        Assert-Observation $false "observation rejects $mutation" 'identity or metric boundary'
    }
    foreach ($head in @('abc123', ('g' * 40), ($record.snapshot_head + "`n"), ('a' * 40))) {
        $changed = $originalRecord | ConvertFrom-Json
        $changed.snapshot_head = $head
        [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
        Assert-Observation $false 'malformed or unrelated snapshot_head' 'snapshot_head'
    }
    foreach ($hash in @('bad', ('0' * 64), ('a' * 64))) {
        $changed = $originalRecord | ConvertFrom-Json
        $changed.source_sha256 = $hash
        [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
        Assert-Observation $false 'malformed or unrelated source hash' 'identity'
    }
    [IO.File]::WriteAllText($recordPath, $originalRecord, $utf8)
    $historyPath = Join-Path $temp 'notes/evaluation-history.md'
    $history = [IO.File]::ReadAllText($historyPath, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($historyPath, $history.Replace($record.snapshot_head, ('b' * 40)), $utf8)
    Assert-Observation $false 'selected historical HEAD drift' 'historical snapshot identity'
    [IO.File]::WriteAllText($historyPath, $history, $utf8)

    # Isolated external fixtures never alter the real evidence directory.
    $evidence = Join-Path $temp 'external-evidence'
    New-Item -ItemType Directory -Path $evidence | Out-Null
    $changed = $originalRecord | ConvertFrom-Json
    $changed.source = Join-Path $evidence 'benchmark.json'
    [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
    Assert-Observation $true 'offline historical identity remains valid without git or external evidence' '' 0
    $offlineResult = New-MypmValidationResult
    Invoke-MypmLatestObservationValidation -Root $temp -Result $offlineResult
    if ($offlineResult.Errors.Count -gt 0 -or $offlineResult.Warnings.Count -gt 0) { throw 'Offline optional evidence would fail the Strict warning-to-error policy' }
    if ($offlineResult.Metrics.observation_source_bytes -ne 'unavailable' -or $offlineResult.Metrics.observation_external_identity -ne 'unavailable') { throw 'Offline verification limits must remain observable' }
    $changed.snapshot_head = 'a' * 40
    [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
    Assert-Observation $false 'offline mismatch still rejected' 'historical snapshot identity'
    $changed.snapshot_head = $record.snapshot_head.ToUpperInvariant()
    [IO.File]::WriteAllText($recordPath, ($changed | ConvertTo-Json -Depth 20), $utf8)
    $manifestPath = Join-Path $evidence 'run-manifest.json'
    [IO.File]::WriteAllText($manifestPath, (@{ head = $record.snapshot_head } | ConvertTo-Json), $utf8)
    Assert-Observation $true 'matching external historical HEAD accepts hex case' '' 0
    foreach ($manifest in @(@{ head = ('c' * 40) }, @{}, @{ head = @($record.snapshot_head) })) {
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json), $utf8)
        Assert-Observation $false 'conflicting or missing external manifest HEAD' 'run-manifest head'
    }
    [IO.File]::WriteAllText($manifestPath, '{invalid', $utf8)
    Assert-Observation $false 'malformed external manifest'
    [IO.File]::WriteAllText($manifestPath, (@{ head = $record.snapshot_head } | ConvertTo-Json), $utf8)
    [IO.File]::WriteAllText($changed.source, '{}', $utf8)
    Assert-Observation $false 'available conflicting benchmark is not skipped' 'Source benchmark hash mismatch'
    if (Test-Path -LiteralPath $record.source -PathType Leaf) {
        Copy-Item -LiteralPath $record.source -Destination $changed.source -Force
        Assert-Observation $true 'copied source bytes and historical manifest match' '' 0
    } else {
        Write-Host 'SKIP: real source bytes unavailable; synthetic and local identity fixtures still ran.'
    }
    [IO.File]::WriteAllText($recordPath, $originalRecord, $utf8)
    if (Test-Path -LiteralPath $record.source) {
        if ((Get-FileHash -LiteralPath $record.source -Algorithm SHA256).Hash -ne $record.source_sha256) { throw 'Source benchmark hash mismatch' }
        $benchmark = Get-Content -LiteralPath $record.source -Raw -Encoding UTF8 | ConvertFrom-Json
        $scores = @(foreach ($suite in @('stable', 'challenge')) {
            foreach ($model in @($record.models)) { "$($benchmark.suites.$suite.$model.passed)/$($benchmark.suites.$suite.$model.total)" }
        })
        if (($scores -join ',') -ne ($record.scores -join ',')) { throw 'Source benchmark score mismatch' }
    }
    foreach ($case in @(
        @{ path = $record.documents[0].path; old = '861/883'; new = '862/883' },
        @{ path = $record.documents[0].path; old = '97.51%'; new = '100.00%' },
        @{ path = $record.documents[0].path; old = $record.documents[0].required_patterns[6]; new = 'independent correctness' },
        @{ path = 'notes/mypm-roadmap.md'; old = $record.documents[1].required_patterns[3]; new = 'measured case latency' },
        @{ path = 'notes/evaluation-history.md'; old = $record.documents[2].required_patterns[6]; new = $record.documents[2].required_patterns[6].Replace('640', '160') }
    )) {
        $path = Join-Path $temp $case.path
        $original = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($path, $original.Replace($case.old, $case.new), $utf8)
        Assert-Observation $false "conflicting current record $($case.old)"
        [IO.File]::WriteAllText($path, $original, $utf8)
    }
    [IO.File]::AppendAllText((Join-Path $temp 'notes/evaluation-history.md'), "`n## Older fixture`n822/883 was not an independent correctness score.`n", $utf8)
    Assert-Observation $true 'older archive remains outside selected section'
    Remove-Item -LiteralPath (Join-Path $temp 'evals/latest-observation.json')
    Assert-Observation $true 'optional record preserves legacy self-test semantics'
    Write-Host 'v0.42 governance fixtures passed; no model execution.'
} finally {
    $resolved = [IO.Path]::GetFullPath($temp)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
