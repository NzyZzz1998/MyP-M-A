param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Prepare', 'Validate')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [string]$BaselinePath,
    [string]$CandidatePath,
    [string]$EvalFile = 'evals\evals.json',
    [ValidateRange(1, 10)]
    [int]$Runs = 1,

    [string]$SuiteLabel = '未命名评测集',
    [ValidateSet('coverage', 'targeted-max')]
    [string]$EvaluationTier = 'coverage',
    [ValidateRange(30, 1800)]
    [int]$SlaSeconds = 300,
    [ValidateRange(1, 3)]
    [int]$MaxConcurrency = 3,
    [ValidateSet('unspecified', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra')]
    [string]$ReasoningEffort = 'unspecified',
    [string]$BaselineLabel = '基线版本',
    [string]$CandidateLabel = '候选版本',
    [string]$BaselineModel = '',
    [string]$CandidateModel = '',
    [switch]$AllowIncomplete
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$skillRoot = Split-Path -Parent $PSScriptRoot

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $json = $Value | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8)
}

function Resolve-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
        throw "Directory not found: $Path"
    }
    return [System.IO.Path]::GetFullPath($resolved.Path).TrimEnd('\')
}

function Resolve-InputFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BasePath
    )

    $candidate = $Path
    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $BasePath $candidate
    }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
}

function Test-IsInside {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $childPath = [System.IO.Path]::GetFullPath($Child).TrimEnd('\') + '\'
    $parentPath = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    return $childPath.StartsWith($parentPath, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-Median {
    param([object[]]$Values)

    $numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ } | Sort-Object)
    if ($numbers.Count -eq 0) {
        return $null
    }
    $middle = [int][Math]::Floor($numbers.Count / 2)
    if (($numbers.Count % 2) -eq 1) {
        return [Math]::Round($numbers[$middle], 1)
    }
    return [Math]::Round(($numbers[$middle - 1] + $numbers[$middle]) / 2, 1)
}

function Copy-RuntimeSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($name in @('SKILL.md', 'README.md')) {
        $sourceFile = Join-Path $Source $name
        if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $Destination $name)
        }
    }
    foreach ($name in @('agents', 'references', 'templates')) {
        $sourceDirectory = Join-Path $Source $name
        if (Test-Path -LiteralPath $sourceDirectory -PathType Container) {
            Copy-Item -LiteralPath $sourceDirectory -Destination (Join-Path $Destination $name) -Recurse
        }
    }
}

function Get-EvalDirectoryName {
    param($Eval)

    $raw = "eval-$($Eval.id)-$($Eval.name)"
    return ([regex]::Replace($raw, '[^\p{L}\p{Nd}._-]+', '-')).Trim('-')
}

function Invoke-Prepare {
    if (-not $BaselinePath) {
        throw 'Prepare requires -BaselinePath.'
    }

    $baseline = Resolve-Directory $BaselinePath
    $candidate = if ($CandidatePath) { Resolve-Directory $CandidatePath } else { Resolve-Directory $skillRoot }
    $workspacePath = [System.IO.Path]::GetFullPath($Workspace).TrimEnd('\')

    if ((Test-IsInside -Child $workspacePath -Parent $baseline) -or (Test-IsInside -Child $workspacePath -Parent $candidate)) {
        throw 'Workspace must be outside baseline and candidate skill directories.'
    }
    if (Test-Path -LiteralPath $workspacePath) {
        if (@(Get-ChildItem -LiteralPath $workspacePath -Force).Count -gt 0) {
            throw "Workspace already contains files; use a new directory: $workspacePath"
        }
    } else {
        New-Item -ItemType Directory -Path $workspacePath -Force | Out-Null
    }

    $evalPath = Resolve-InputFile -Path $EvalFile -BasePath $candidate
    $evalData = [System.IO.File]::ReadAllText($evalPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if (-not $evalData.evals -or @($evalData.evals).Count -eq 0) {
        throw "No evals found in: $evalPath"
    }

    $snapshotRoot = Join-Path $workspacePath '_snapshots'
    Copy-RuntimeSnapshot -Source $baseline -Destination (Join-Path $snapshotRoot 'baseline')
    Copy-RuntimeSnapshot -Source $candidate -Destination (Join-Path $snapshotRoot 'candidate')
    $graderRoot = Join-Path $workspacePath '_grader'
    New-Item -ItemType Directory -Path $graderRoot -Force | Out-Null
    Copy-Item -LiteralPath $evalPath -Destination (Join-Path $graderRoot 'eval-source.json')

    $evalDirectories = [System.Collections.Generic.List[string]]::new()
    foreach ($eval in @($evalData.evals)) {
        $directoryName = Get-EvalDirectoryName $eval
        $evalDirectories.Add($directoryName)
        $evalDirectory = Join-Path $workspacePath $directoryName
        New-Item -ItemType Directory -Path $evalDirectory -Force | Out-Null
        Write-JsonFile -Value $eval -Path (Join-Path $graderRoot "$directoryName.json")

        $taskFiles = [System.Collections.Generic.List[string]]::new()
        $inputDirectory = Join-Path $evalDirectory 'inputs'
        foreach ($relativeFile in @($eval.files)) {
            $sourceFile = Resolve-InputFile -Path ([string]$relativeFile) -BasePath $candidate
            New-Item -ItemType Directory -Path $inputDirectory -Force | Out-Null
            $destinationName = Split-Path -Leaf $sourceFile
            $destinationFile = Join-Path $inputDirectory $destinationName
            if (Test-Path -LiteralPath $destinationFile) {
                $destinationName = "$($taskFiles.Count + 1)-$destinationName"
                $destinationFile = Join-Path $inputDirectory $destinationName
            }
            Copy-Item -LiteralPath $sourceFile -Destination $destinationFile
            $taskFiles.Add("inputs/$destinationName")
        }
        $task = [ordered]@{
            id = $eval.id
            name = $eval.name
            prompt = $eval.prompt
            files = @($taskFiles)
        }
        Write-JsonFile -Value $task -Path (Join-Path $evalDirectory 'task.json')

        foreach ($configuration in @('baseline', 'candidate')) {
            foreach ($runNumber in 1..$Runs) {
                $runDirectory = Join-Path $evalDirectory "$configuration\run-$runNumber"
                New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
            }
        }
    }

    $manifest = [ordered]@{
        schema_version = 2
        prepared_at_utc = [DateTime]::UtcNow.ToString('o')
        eval_source = $evalPath
        suite_label = $SuiteLabel
        evaluation_tier = $EvaluationTier
        eval_count = @($evalData.evals).Count
        runs_per_configuration = $Runs
        configurations = @(
            [ordered]@{ name = 'baseline'; label = $BaselineLabel; model = $BaselineModel; source = $baseline; snapshot = '_snapshots/baseline' },
            [ordered]@{ name = 'candidate'; label = $CandidateLabel; model = $CandidateModel; source = $candidate; snapshot = '_snapshots/candidate' }
        )
        execution_protocol = [ordered]@{
            reasoning_effort = $ReasoningEffort
            sla_seconds = $SlaSeconds
            max_concurrency = $MaxConcurrency
            missing_result_policy = 'runtime-incomplete-not-capability-failure'
            comparison_policy = 'paired-complete-runs-only'
        }
        eval_directories = @($evalDirectories)
        grader_directory = '_grader'
        execution = 'external'
        note = 'Execution directories contain task.json and raw inputs only. Grading criteria are isolated under _grader. Missing model outputs are not capability failures.'
    }
    Write-JsonFile -Value $manifest -Path (Join-Path $workspacePath 'iteration.json')

    Write-Host "Regression workspace prepared: $workspacePath"
    Write-Host "Evals=$($manifest.eval_count) runs=$Runs expected_outputs=$($manifest.eval_count * $Runs * 2)"
}

function Invoke-Validate {
    $workspacePath = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path
    $manifestPath = Join-Path $workspacePath 'iteration.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "iteration.json not found: $manifestPath"
    }

    $manifest = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $records = [System.Collections.Generic.List[object]]::new()
    $recordIndex = @{}
    $configurationTotals = @{}
    foreach ($configuration in @($manifest.configurations)) {
        $configurationTotals[$configuration.name] = [ordered]@{
            expected_runs = 0
            complete_runs = 0
            execution_confirmed_runs = 0
            legacy_status_unknown_runs = 0
            missing_runs = 0
            invalid_runs = 0
            passed = 0
            total = 0
            response_chars = 0
            duration_values = [System.Collections.Generic.List[double]]::new()
        }
    }

    foreach ($directoryName in @($manifest.eval_directories)) {
        $evalDirectory = Join-Path $workspacePath $directoryName
        $metadataPath = Join-Path $workspacePath "$($manifest.grader_directory)\$directoryName.json"
        $metadata = [System.IO.File]::ReadAllText($metadataPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $expectedTexts = @($metadata.expectations | ForEach-Object { [string]$_ })

        foreach ($configuration in @($manifest.configurations)) {
            foreach ($runNumber in 1..([int]$manifest.runs_per_configuration)) {
                $totals = $configurationTotals[$configuration.name]
                $totals.expected_runs++
                $runDirectory = Join-Path $evalDirectory "$($configuration.name)\run-$runNumber"
                $responsePath = Join-Path $runDirectory 'response.md'
                $gradingPath = Join-Path $runDirectory 'grading.json'
                $executionPath = Join-Path $runDirectory 'execution.json'
                $state = 'complete'
                $issues = [System.Collections.Generic.List[string]]::new()
                $executionIssues = [System.Collections.Generic.List[string]]::new()
                $passed = 0
                $total = 0
                $responseChars = 0
                $durationMs = $null
                $durationState = 'unavailable'
                $executionStatus = 'unknown'
                $executionAttempts = $null
                $stoppingReason = $null
                $returnBasis = 'legacy-artifacts-status-unknown'

                if (-not (Test-Path -LiteralPath $responsePath -PathType Leaf)) {
                    $state = 'missing'
                    $issues.Add('response.md is missing')
                } else {
                    $responseText = [System.IO.File]::ReadAllText($responsePath, [System.Text.Encoding]::UTF8)
                    $responseChars = $responseText.Length
                    if ([string]::IsNullOrWhiteSpace($responseText)) {
                        $state = 'invalid'
                        $issues.Add('response.md is empty or whitespace-only')
                    }
                }
                if (-not (Test-Path -LiteralPath $gradingPath -PathType Leaf)) {
                    $state = 'missing'
                    $issues.Add('grading.json is missing')
                }

                if (Test-Path -LiteralPath $executionPath -PathType Leaf) {
                    try {
                        $execution = [System.IO.File]::ReadAllText($executionPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
                        if ($null -eq $execution -or $execution -is [array] -or $execution -isnot [pscustomobject]) { throw 'execution.json must contain an object' }
                        $executionAttempts = $execution.attempts
                        $stoppingReason = $execution.stopping_reason
                        if ($null -ne $execution.PSObject.Properties['status']) {
                            $executionStatus = [string]$execution.status
                            if ($executionStatus -in @('succeeded', 'completed', 'complete', 'success', 'ok')) {
                                $returnBasis = 'execution-confirmed'
                            } else {
                                $state = 'invalid'
                                $issues.Add("execution.json does not record successful completion: $executionStatus")
                            }
                        }
                        $parsedDuration = 0.0
                        if ($null -ne $execution.duration_ms -and [double]::TryParse([string]$execution.duration_ms, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedDuration) -and $parsedDuration -ge 0 -and -not [double]::IsInfinity($parsedDuration) -and -not [double]::IsNaN($parsedDuration)) {
                            $durationMs = [Math]::Round($parsedDuration, 1)
                            $durationState = 'available'
                        } else {
                            $durationState = 'invalid'
                            $executionIssues.Add('execution.json duration_ms must be a non-negative number')
                        }
                    } catch {
                        $state = 'invalid'
                        $executionStatus = 'invalid-metadata'
                        $durationState = 'invalid'
                        $issues.Add('execution.json is invalid; completion cannot be inferred from residual files')
                        $executionIssues.Add("execution.json cannot be parsed: $($_.Exception.Message)")
                    }
                }

                if ($state -eq 'complete') {
                    try {
                        $grading = [System.IO.File]::ReadAllText($gradingPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
                        $gradedExpectations = @($grading.expectations)
                        if ($gradedExpectations.Count -ne $expectedTexts.Count) {
                            $issues.Add("expectation count mismatch: expected=$($expectedTexts.Count) actual=$($gradedExpectations.Count)")
                        }
                        for ($index = 0; $index -lt [Math]::Min($gradedExpectations.Count, $expectedTexts.Count); $index++) {
                            $item = $gradedExpectations[$index]
                            if ([string]$item.text -ne $expectedTexts[$index]) {
                                $issues.Add("expectation text mismatch at index $index")
                            }
                            if ($item.passed -isnot [bool]) {
                                $issues.Add("expectation passed is not boolean at index $index")
                            }
                            if ([string]::IsNullOrWhiteSpace([string]$item.evidence)) {
                                $issues.Add("expectation evidence is empty at index $index")
                            }
                        }

                        $passed = @($gradedExpectations | Where-Object { $_.passed -eq $true }).Count
                        $total = $gradedExpectations.Count
                        $failed = $total - $passed
                        if ($null -eq $grading.summary) {
                            $issues.Add('summary is missing')
                        } elseif ([int]$grading.summary.passed -ne $passed -or [int]$grading.summary.failed -ne $failed -or [int]$grading.summary.total -ne $total) {
                            $issues.Add('summary counts do not match expectations')
                        }
                    } catch {
                        $issues.Add("grading.json cannot be parsed: $($_.Exception.Message)")
                    }

                    if ($issues.Count -gt 0) {
                        $state = 'invalid'
                    }
                }

                if ($state -eq 'complete') {
                    $totals.complete_runs++
                    if ($returnBasis -eq 'execution-confirmed') { $totals.execution_confirmed_runs++ } else { $totals.legacy_status_unknown_runs++ }
                    $totals.passed += $passed
                    $totals.total += $total
                    $totals.response_chars += $responseChars
                    if ($durationState -eq 'available') {
                        $totals.duration_values.Add([double]$durationMs)
                    }
                } elseif ($state -eq 'missing') {
                    $totals.missing_runs++
                } else {
                    $totals.invalid_runs++
                }

                $record = [ordered]@{
                    eval_id = [string]$metadata.id
                    eval_name = [string]$metadata.name
                    configuration = [string]$configuration.name
                    run = $runNumber
                    state = $state
                    passed = $passed
                    total = $total
                    response_chars = $responseChars
                    valid_return = ($state -eq 'complete')
                    valid_return_basis = if ($state -eq 'complete') { $returnBasis } else { 'not-valid' }
                    execution_status = $executionStatus
                    execution_attempts = $executionAttempts
                    stopping_reason = $stoppingReason
                    duration_ms = $durationMs
                    duration_state = $durationState
                    issues = @($issues)
                    execution_issues = @($executionIssues)
                }
                $records.Add($record)
                $recordIndex["$($record.eval_id)|$($record.configuration)|$runNumber"] = $record
            }
        }
    }

    $summaryRows = [System.Collections.Generic.List[object]]::new()
    foreach ($configuration in @($manifest.configurations)) {
        $totals = $configurationTotals[$configuration.name]
        $passRate = if ($totals.total -gt 0) { [Math]::Round($totals.passed / $totals.total, 4) } else { $null }
        $averageChars = if ($totals.complete_runs -gt 0) { [Math]::Round($totals.response_chars / $totals.complete_runs, 1) } else { $null }
        $validReturnRate = if ($totals.expected_runs -gt 0) { [Math]::Round($totals.complete_runs / $totals.expected_runs, 4) } else { $null }
        $medianDuration = Get-Median -Values @($totals.duration_values)
        $summaryRows.Add([ordered]@{
            configuration = [string]$configuration.name
            expected_runs = $totals.expected_runs
            complete_runs = $totals.complete_runs
            execution_confirmed_runs = $totals.execution_confirmed_runs
            legacy_status_unknown_runs = $totals.legacy_status_unknown_runs
            missing_runs = $totals.missing_runs
            invalid_runs = $totals.invalid_runs
            passed = $totals.passed
            total = $totals.total
            pass_rate = $passRate
            average_response_chars = $averageChars
            valid_return_rate = $validReturnRate
            duration_samples = $totals.duration_values.Count
            median_duration_ms = $medianDuration
        })
    }

    $paired = [ordered]@{
        expected_pairs = [int]$manifest.eval_count * [int]$manifest.runs_per_configuration
        complete_pairs = 0
        incomplete_pairs = 0
        baseline_passed = 0
        candidate_passed = 0
        total = 0
        baseline_wins = 0
        candidate_wins = 0
        ties = 0
        baseline_response_chars = 0
        candidate_response_chars = 0
        baseline_pass_rate = $null
        candidate_pass_rate = $null
        baseline_average_response_chars = $null
        candidate_average_response_chars = $null
        duration_complete_pairs = 0
        baseline_median_duration_ms = $null
        candidate_median_duration_ms = $null
    }
    $baselineDurationValues = [System.Collections.Generic.List[double]]::new()
    $candidateDurationValues = [System.Collections.Generic.List[double]]::new()
    foreach ($directoryName in @($manifest.eval_directories)) {
        $metadataPath = Join-Path $workspacePath "$($manifest.grader_directory)\$directoryName.json"
        $metadata = [System.IO.File]::ReadAllText($metadataPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($runNumber in 1..([int]$manifest.runs_per_configuration)) {
            $baselineRecord = $recordIndex["$($metadata.id)|baseline|$runNumber"]
            $candidateRecord = $recordIndex["$($metadata.id)|candidate|$runNumber"]
            if ($null -eq $baselineRecord -or $null -eq $candidateRecord -or
                $baselineRecord.state -ne 'complete' -or $candidateRecord.state -ne 'complete') {
                $paired.incomplete_pairs++
                continue
            }

            $paired.complete_pairs++
            $paired.baseline_passed += [int]$baselineRecord.passed
            $paired.candidate_passed += [int]$candidateRecord.passed
            $paired.total += [int]$baselineRecord.total
            $paired.baseline_response_chars += [int]$baselineRecord.response_chars
            $paired.candidate_response_chars += [int]$candidateRecord.response_chars
            if ($baselineRecord.duration_state -eq 'available' -and $candidateRecord.duration_state -eq 'available') {
                $paired.duration_complete_pairs++
                $baselineDurationValues.Add([double]$baselineRecord.duration_ms)
                $candidateDurationValues.Add([double]$candidateRecord.duration_ms)
            }
            if ([int]$baselineRecord.passed -gt [int]$candidateRecord.passed) {
                $paired.baseline_wins++
            } elseif ([int]$candidateRecord.passed -gt [int]$baselineRecord.passed) {
                $paired.candidate_wins++
            } else {
                $paired.ties++
            }
        }
    }
    $paired.baseline_pass_rate = if ($paired.total -gt 0) { [Math]::Round($paired.baseline_passed / $paired.total, 4) } else { $null }
    $paired.candidate_pass_rate = if ($paired.total -gt 0) { [Math]::Round($paired.candidate_passed / $paired.total, 4) } else { $null }
    $paired.baseline_average_response_chars = if ($paired.complete_pairs -gt 0) { [Math]::Round($paired.baseline_response_chars / $paired.complete_pairs, 1) } else { $null }
    $paired.candidate_average_response_chars = if ($paired.complete_pairs -gt 0) { [Math]::Round($paired.candidate_response_chars / $paired.complete_pairs, 1) } else { $null }
    $paired.baseline_median_duration_ms = Get-Median -Values @($baselineDurationValues)
    $paired.candidate_median_duration_ms = Get-Median -Values @($candidateDurationValues)

    $report = [ordered]@{
        schema_version = 2
        validated_at_utc = [DateTime]::UtcNow.ToString('o')
        workspace = $workspacePath
        allow_incomplete = [bool]$AllowIncomplete
        summary = @($summaryRows)
        paired_summary = $paired
        runs = @($records)
    }
    Write-JsonFile -Value $report -Path (Join-Path $workspacePath 'validation-report.json')
    Write-JsonFile -Value ([ordered]@{ summary = @($summaryRows); paired_summary = $paired }) -Path (Join-Path $workspacePath 'benchmark-lite.json')

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# 轻量回归汇总')
    $lines.Add('')
    $lines.Add('本文只报告结构、运行完整性与聚合分数，不能替代正式评测页面和人工复核。')
    $lines.Add('空白回答、失败或未完成的执行记录不计有效返回。旧记录缺少执行状态时只按非空回答与有效评分兼容，不推断执行成功；超时成本不改变回答有效性或质量分数。')
    $lines.Add('')
    $lines.Add('| 配置 | 有效返回 | 有效率 | 缺失 | 无效 | 通过 | 总计 | 通过率 | 平均字符 | 时长样本 | 中位时长(ms) |')
    $lines.Add('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |')
    foreach ($row in $summaryRows) {
        $rate = if ($null -eq $row.pass_rate) { 'n/a' } else { '{0:P1}' -f $row.pass_rate }
        $chars = if ($null -eq $row.average_response_chars) { 'n/a' } else { [string]$row.average_response_chars }
        $validRate = if ($null -eq $row.valid_return_rate) { 'n/a' } else { '{0:P1}' -f $row.valid_return_rate }
        $duration = if ($null -eq $row.median_duration_ms) { 'unavailable' } else { [string]$row.median_duration_ms }
        $lines.Add("| $($row.configuration) | $($row.complete_runs)/$($row.expected_runs) | $validRate | $($row.missing_runs) | $($row.invalid_runs) | $($row.passed) | $($row.total) | $rate | $chars | $($row.duration_samples) | $duration |")
    }
    $lines.Add('')
    foreach ($row in $summaryRows) {
        $lines.Add("- $($row.configuration)：执行成功有明确记录 $($row.execution_confirmed_runs) 份；历史状态未知、按材料兼容 $($row.legacy_status_unknown_runs) 份。")
    }
    $lines.Add('')
    $lines.Add('## 共同有效样本')
    $lines.Add('')
    $lines.Add('只在基线和候选都完成且评分有效的相同用例上比较能力。缺失结果保留为运行完整性问题。')
    $lines.Add('')
    $lines.Add("- 共同样本：$($paired.complete_pairs)/$($paired.expected_pairs)，不完整：$($paired.incomplete_pairs)")
    $lines.Add("- 得分：baseline $($paired.baseline_passed)/$($paired.total)，candidate $($paired.candidate_passed)/$($paired.total)")
    $lines.Add("- 用例胜负：baseline $($paired.baseline_wins) 胜，candidate $($paired.candidate_wins) 胜，$($paired.ties) 平")
    $lines.Add("- 平均字符：baseline $($paired.baseline_average_response_chars)，candidate $($paired.candidate_average_response_chars)")
    $baselineDuration = if ($null -eq $paired.baseline_median_duration_ms) { 'unavailable' } else { [string]$paired.baseline_median_duration_ms }
    $candidateDuration = if ($null -eq $paired.candidate_median_duration_ms) { 'unavailable' } else { [string]$paired.candidate_median_duration_ms }
    $lines.Add("- 配对中位时长：baseline $baselineDuration ms，candidate $candidateDuration ms；可比较 $($paired.duration_complete_pairs) 对")
    [System.IO.File]::WriteAllLines((Join-Path $workspacePath 'benchmark-lite.md'), $lines, $utf8)

    $problemCount = @($records | Where-Object { $_.state -ne 'complete' }).Count
    Write-Host "Regression results validated: runs=$($records.Count) incomplete_or_invalid=$problemCount"
    if ($problemCount -gt 0 -and -not $AllowIncomplete) {
        exit 2
    }
}

if ($Action -eq 'Prepare') {
    Invoke-Prepare
} else {
    Invoke-Validate
}
