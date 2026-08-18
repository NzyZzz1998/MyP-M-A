$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$evidenceRoot = $env:MYPM_V037_EVIDENCE_ROOT

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing v0.37 file: $RelativePath" }
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

function Get-Sha256Text {
    param([Parameter(Mandatory = $true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-AggregateFromRecords {
    param([Parameter(Mandatory = $true)][object[]]$Records)
    $lines = @($Records | ForEach-Object { "$([string]$_.path)`t$([string]$_.sha256)" })
    return Get-Sha256Text -Text ($lines -join "`n")
}

function Get-ActualFileRecords {
    param([Parameter(Mandatory = $true)][string[]]$RelativePaths)
    return @($RelativePaths | ForEach-Object {
        $relative = [string]$_
        $path = Join-Path $root $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing aggregate input: $relative" }
        [pscustomobject]@{
            path = $relative.Replace('\', '/')
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
            bytes = (Get-Item -LiteralPath $path).Length
        }
    })
}

function Test-CandidateIdentity {
    param($Candidate)
    if ($null -eq $Candidate -or [string]::IsNullOrWhiteSpace([string]$Candidate.base_commit)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Candidate.runtime_sha256) -or $null -eq $Candidate.runtime_lock) { return $false }
    $records = @($Candidate.runtime_lock.files)
    if ($records.Count -ne 6 -or @($records | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.path) -or [string]::IsNullOrWhiteSpace([string]$_.sha256) }).Count -gt 0) { return $false }
    return (Get-AggregateFromRecords -Records $records) -eq [string]$Candidate.runtime_sha256
}

function Test-EvaluatedCandidateSnapshot {
    param($Candidate, [Parameter(Mandatory = $true)][string]$SnapshotPath)
    try {
        if ($null -eq $Candidate.evaluated_snapshot -or -not (Test-Path -LiteralPath $SnapshotPath -PathType Leaf)) { return $false }
        $snapshotFile = Get-Item -LiteralPath $SnapshotPath
        if ([int64]$snapshotFile.Length -ne [int64]$Candidate.evaluated_snapshot.bytes) { return $false }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $SnapshotPath).Hash.ToLowerInvariant() -ne [string]$Candidate.evaluated_snapshot.sha256) { return $false }
        $snapshot = [System.IO.File]::ReadAllText($SnapshotPath, $utf8) | ConvertFrom-Json
        if ([string]$snapshot.candidate_id -ne [string]$Candidate.id -or
            [string]$snapshot.base_commit -ne [string]$Candidate.base_commit -or
            [string]$snapshot.runtime_sha256 -ne [string]$Candidate.runtime_sha256 -or
            @($snapshot.files).Count -ne [int]$Candidate.evaluated_snapshot.files) { return $false }
        $evidenceRoot = Split-Path -Parent $SnapshotPath
        $runtimeRoot = Join-Path $evidenceRoot ([string]$Candidate.evaluated_snapshot.runtime_dir)
        foreach ($expected in @($snapshot.files)) {
            $actualPath = Join-Path $runtimeRoot ([string]$expected.path).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $actualPath -PathType Leaf) -or
                [int64](Get-Item -LiteralPath $actualPath).Length -ne [int64]$expected.bytes -or
                (Get-FileHash -Algorithm SHA256 -LiteralPath $actualPath).Hash.ToLowerInvariant() -ne [string]$expected.sha256) { return $false }
        }
        foreach ($expected in @($Candidate.runtime_lock.files)) {
            $actual = @($snapshot.files | Where-Object { [string]$_.path -eq [string]$expected.path })
            if ($actual.Count -ne 1 -or
                [string]$actual[0].sha256 -ne [string]$expected.sha256 -or
                [int64]$actual[0].bytes -ne [int64]$expected.bytes) { return $false }
        }
        $evaluatedRuntimeRecords = @($Candidate.runtime_lock.files | ForEach-Object {
            $relative = [string]$_.path
            $actualPath = Join-Path $runtimeRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            [pscustomobject]@{
                path = $relative
                sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $actualPath).Hash.ToLowerInvariant()
                bytes = (Get-Item -LiteralPath $actualPath).Length
            }
        })
        if ((Get-AggregateFromRecords -Records $evaluatedRuntimeRecords) -ne [string]$snapshot.runtime_sha256) { return $false }
        return $true
    } catch {
        return $false
    }
}

function Test-FrozenInput {
    param($Expected, [object[]]$ActualRecords)
    $bytes = ($ActualRecords | Measure-Object -Property bytes -Sum).Sum
    return $null -ne $Expected -and
        [int]$Expected.files -eq $ActualRecords.Count -and
        [int64]$Expected.bytes -eq [int64]$bytes -and
        [string]$Expected.sha256 -eq (Get-AggregateFromRecords -Records $ActualRecords)
}

function Get-NumberedItemCount {
    param([string]$Text, [string]$Start, [string]$End)
    $endPattern = if ($End) { "(?=^$([regex]::Escape($End))：)" } else { '(?=\z)' }
    $pattern = "(?ms)^$([regex]::Escape($Start))：\s*(?<body>.*?)$endPattern"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return -1 }
    return [regex]::Matches($match.Groups['body'].Value, '(?m)^\d+\.\s').Count
}

function Test-SummaryConsistency {
    param([string]$Fixture, $Summary)
    return [int]$Summary.consistent -eq (Get-NumberedItemCount -Text $Fixture -Start '已确认一致项' -End '已确认偏差') -and
        [int]$Summary.deviations -eq (Get-NumberedItemCount -Text $Fixture -Start '已确认偏差' -End '待验证') -and
        [int]$Summary.pending -eq (Get-NumberedItemCount -Text $Fixture -Start '待验证' -End '')
}

function Test-ScopeFidelity {
    param([string]$Text)
    return $Text.Contains('> 50000') -and $Text.Contains('<= 50000') -and $Text -notmatch '全部.{0,8}(异步|后台)|统一.{0,8}(异步|后台)'
}

function Test-HistoryFidelity {
    param([string]$Text)
    return $Text.Contains('未提供') -and $Text.Contains('待产品负责人决定') -and $Text -notmatch '上一轮.{0,8}(全部)?通过|已延期'
}

function Test-NumberDiscipline {
    param([string]$Text)
    return $Text.Contains('内部启发式') -and $Text.Contains('缺少分母') -and $Text.Contains('建议值/待确认')
}

$stable = Read-Utf8 'evals/evals.json' | ConvertFrom-Json
$challenge = Read-Utf8 'evals/challenge-evals.json' | ConvertFrom-Json
$registry = Read-Utf8 'evals/contract-registry.json' | ConvertFrom-Json
$lifecycle = Read-Utf8 'evals/eval-lifecycle.json' | ConvertFrom-Json

$stableIds = @(86..92)
$challengeIds = @('CH-22', 'CH-23', 'CH-24', 'CH-25')
foreach ($id in $stableIds) {
    Assert-True -Condition (@($stable.evals | Where-Object { [int]$_.id -eq $id }).Count -eq 1) -Message "Stable v0.37 eval must exist once: $id"
}
foreach ($id in $challengeIds) {
    Assert-True -Condition (@($challenge.evals | Where-Object { [string]$_.id -eq $id }).Count -eq 1) -Message "Challenge v0.37 eval must exist once: $id"
}

foreach ($id in $stableIds) {
    $contractOwners = @($registry.contracts | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    $scenarioOwners = @($lifecycle.scenario_groups | Where-Object { @($_.stable_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition (($contractOwners + $scenarioOwners) -eq 1) -Message "Stable eval ownership must be unique: $id"
}
foreach ($id in $challengeIds) {
    $contractOwners = @($registry.contracts | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    $scenarioOwners = @($lifecycle.scenario_groups | Where-Object { @($_.challenge_evals | ForEach-Object { [string]$_ }) -contains [string]$id }).Count
    Assert-True -Condition (($contractOwners + $scenarioOwners) -eq 1) -Message "Challenge eval ownership must be unique: $id"
}

$fixtureFiles = @(
    'evals/files/v037-async-scope-boundary.md',
    'evals/files/v037-intent-implementation-status.md',
    'evals/files/v037-handoff-status.md',
    'evals/files/v037-acceptance-status.md',
    'evals/files/v037-number-sources.md',
    'evals/files/v037-summary-consistency.md'
)
foreach ($file in $fixtureFiles) { [void](Read-Utf8 $file) }

$prd = Read-Utf8 'references/prd.md'
$audit = Read-Utf8 'references/intent-implementation-audit.md'
$prompt = Read-Utf8 'references/prompt.md'
$acceptance = Read-Utf8 'references/acceptance.md'
$idea = Read-Utf8 'references/idea.md'
$skill = Read-Utf8 'SKILL.md'

Assert-ContainsAll -Text $prd -Label 'PRD range fidelity contract' -Values @('preserve', 'add', 'expand', 'reduce', 'remove', 'reopen', 'transition', '> 50000', '<= 50000')
Assert-ContainsAll -Text $audit -Label 'Intent implementation classification' -Values @('实现偏离', '批准后的文档过期', '未验证', '待确认', '范围外变化')
Assert-ContainsAll -Text $prompt -Label 'Prompt state inheritance' -Values @('对象 + 原状态 + 证据来源', '未提供', '待负责人决定')
Assert-ContainsAll -Text $acceptance -Label 'Acceptance state inheritance' -Values @('对象 + 原状态 + 证据来源', '未提供', '待负责人决定')
Assert-ContainsAll -Text $idea -Label 'Idea number source discipline' -Values @('N1 已确认事实', 'N2 可复算结果', 'N3 内部启发式', 'N4 建议阈值')
Assert-ContainsAll -Text $skill -Label 'Guarded output scan' -Values @('事实', '范围', '状态', '数值', '摘要')

$scopeGood = '保留 > 50000 后台任务与 <= 50000 同步路径。'
$scopeBad = '统一全部导出为异步后台任务。'
Assert-True -Condition (Test-ScopeFidelity $scopeGood) -Message 'Positive scope fixture should pass'
Assert-True -Condition (-not (Test-ScopeFidelity $scopeBad)) -Message 'Negative scope fixture should fail'

$historyGood = '上一轮完整历史未提供；真实登录自启待产品负责人决定。'
$historyBad = '上一轮全部通过；真实登录自启已延期。'
Assert-True -Condition (Test-HistoryFidelity $historyGood) -Message 'Positive history fixture should pass'
Assert-True -Condition (-not (Test-HistoryFidelity $historyBad)) -Message 'Negative history fixture should fail'

$numberGood = '31/40 为内部启发式；缺少分母；30% 为建议值/待确认。'
$numberBad = '失败率为 50%，30% 是正式上线门槛。'
Assert-True -Condition (Test-NumberDiscipline $numberGood) -Message 'Positive number fixture should pass'
Assert-True -Condition (-not (Test-NumberDiscipline $numberBad)) -Message 'Negative number fixture should fail'

$candidates = Read-Utf8 'evals/external-candidates.json' | ConvertFrom-Json
$benchmark = Read-Utf8 'evals/external-benchmark.json' | ConvertFrom-Json
$candidate = @($candidates.candidates | Where-Object { [string]$_.id -eq 'mypm-v037' })
Assert-True -Condition ($candidate.Count -eq 1) -Message 'mypm-v037 candidate must exist exactly once'
$candidate = $candidate[0]
Assert-True -Condition (Test-CandidateIdentity -Candidate $candidate) -Message 'mypm-v037 candidate identity lock is invalid'
Assert-True -Condition ([string]$candidate.runtime_lock.algorithm -eq 'sha256(path-tab-sha256-lf-utf8)') -Message 'Candidate runtime aggregate algorithm is not frozen'
$snapshotLock = $candidate.evaluated_snapshot
Assert-True -Condition ($null -ne $snapshotLock -and
    [string]$snapshotLock.root_env -eq 'MYPM_V037_EVIDENCE_ROOT' -and
    [string]$snapshotLock.relative_path -eq 'candidate-snapshot.json' -and
    [string]$snapshotLock.runtime_dir -eq 'candidate' -and
    [string]$snapshotLock.sha256 -match '^[0-9a-f]{64}$' -and
    [int64]$snapshotLock.bytes -gt 0 -and
    [int]$snapshotLock.files -gt 0 -and
    [string]$snapshotLock.allowed_promotion_change.path -eq 'SKILL.md' -and
    [string]$snapshotLock.allowed_promotion_change.from -eq 'version: "0.36.0"' -and
    [string]$snapshotLock.allowed_promotion_change.to -eq 'version: "0.37.0"') -Message 'Evaluated Candidate snapshot lock is incomplete'
$currentSkill = Read-Utf8 'SKILL.md'
$currentVersionMatch = [regex]::Match($currentSkill, 'version:\s*"(?<version>\d+\.\d+\.\d+)"')
Assert-True -Condition $currentVersionMatch.Success -Message 'Current SKILL.md version is missing'
$currentVersion = [version]$currentVersionMatch.Groups['version'].Value
$v037RuntimeState = 'current'
if ($currentVersion -eq [version]'0.37.0') {
    $currentRuntimeRecords = Get-ActualFileRecords -RelativePaths @($candidate.runtime_lock.files | ForEach-Object { [string]$_.path })
    Assert-True -Condition ((Get-AggregateFromRecords -Records $currentRuntimeRecords) -eq [string]$candidate.promoted_runtime_sha256) -Message 'Promoted v0.37 runtime hash does not match the current files'
} elseif ($currentVersion -gt [version]'0.37.0') {
    $handoff = Read-Utf8 'notes/progress_v0.38.md'
    Assert-True -Condition $handoff.Contains('v0.37 未发布候选被 v0.38 吸收') -Message 'Later runtime must record that the unreleased v0.37 Candidate was absorbed'
    $v037RuntimeState = 'absorbed'
} else {
    throw "Current runtime version predates the v0.37 Candidate: $currentVersion"
}
$missingCandidate = [pscustomobject]@{ id = 'mypm-v037' }
Assert-True -Condition (-not (Test-CandidateIdentity -Candidate $missingCandidate)) -Message 'Candidate identity without commit and runtime lock should fail'

$snapshotStatus = 'declared'
if (-not [string]::IsNullOrWhiteSpace($evidenceRoot)) {
    $snapshotPath = Join-Path $evidenceRoot ([string]$snapshotLock.relative_path)
    Assert-True -Condition (Test-EvaluatedCandidateSnapshot -Candidate $candidate -SnapshotPath $snapshotPath) -Message 'Evaluated Candidate snapshot has drifted from its frozen identity'
    if ($currentVersion -eq [version]'0.37.0') {
        $evaluatedSkillPath = Join-Path (Join-Path $evidenceRoot ([string]$snapshotLock.runtime_dir)) 'SKILL.md'
        $evaluatedSkill = [System.IO.File]::ReadAllText($evaluatedSkillPath, $utf8)
        $expectedPromotedSkill = $evaluatedSkill.Replace([string]$snapshotLock.allowed_promotion_change.from, [string]$snapshotLock.allowed_promotion_change.to)
        Assert-True -Condition ($expectedPromotedSkill -eq $currentSkill) -Message 'Promoted SKILL.md contains behavior changes beyond the declared version metadata update'
    }
    $tempSnapshot = Join-Path $evidenceRoot ("candidate-snapshot-drift-$([guid]::NewGuid().ToString('N')).json")
    try {
        $driftedSnapshot = [System.IO.File]::ReadAllText($snapshotPath, $utf8).Replace('"candidate_id": "mypm-v037"', '"candidate_id": "mypm-v037-drifted"')
        [System.IO.File]::WriteAllText($tempSnapshot, $driftedSnapshot, [System.Text.UTF8Encoding]::new($false))
        Assert-True -Condition (-not (Test-EvaluatedCandidateSnapshot -Candidate $candidate -SnapshotPath $tempSnapshot)) -Message 'Synthetic Candidate snapshot drift should fail'
    } finally {
        if (Test-Path -LiteralPath $tempSnapshot) { Remove-Item -LiteralPath $tempSnapshot -Force }
    }
    $snapshotStatus = 'verified'
}

$taskPaths = @('evals/external-benchmark-contract.json') + @($benchmark.tasks | ForEach-Object { [string]$_.fixture })
$taskRecords = Get-ActualFileRecords -RelativePaths $taskPaths
Assert-True -Condition (Test-FrozenInput -Expected $benchmark.frozen_input -ActualRecords $taskRecords) -Message 'External task contract or fixture freeze has drifted'
$driftedRecords = @($taskRecords | ForEach-Object { [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; bytes = $_.bytes } })
$driftedRecords[1].sha256 = ('0' * 64)
Assert-True -Condition (-not (Test-FrozenInput -Expected $benchmark.frozen_input -ActualRecords $driftedRecords)) -Message 'Synthetic task drift should fail the frozen input check'

$summaryFixture = Read-Utf8 'evals/files/v037-summary-consistency.md'
$summaryGood = [pscustomobject]@{ consistent = 2; deviations = 3; pending = 2 }
$summaryBad = [pscustomobject]@{ consistent = 2; deviations = 4; pending = 1 }
Assert-True -Condition (Test-SummaryConsistency -Fixture $summaryFixture -Summary $summaryGood) -Message 'Summary counts should match the fixture'
Assert-True -Condition (-not (Test-SummaryConsistency -Fixture $summaryFixture -Summary $summaryBad)) -Message 'Mismatched summary counts should fail'

foreach ($task in @($benchmark.tasks)) {
    Assert-True -Condition ('mypm-v037' -in @($task.candidate_context.PSObject.Properties.Name)) -Message "Task $($task.id) is missing mypm-v037 context"
}

Write-Host "v0.37 fact fidelity self-test passed: stable=7 challenge=4 fixtures=6 ownership=unique synthetic-positive=6 synthetic-negative=7 candidate=locked runtime=$v037RuntimeState candidate-snapshot=$snapshotStatus task-freeze=locked tasks=12"
