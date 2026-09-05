$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$scriptRoot = $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-eval-pipeline-" + [Guid]::NewGuid().ToString('N'))

function Write-JsonFile {
    param($Value, [string]$Path)
    [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine, $utf8)
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message expected=$Expected actual=$Actual"
    }
}

try {
    $baseline = Join-Path $tempRoot 'baseline'
    $candidate = Join-Path $tempRoot 'candidate'
    $workspace = Join-Path $tempRoot 'workspace'
    foreach ($path in @($baseline, $candidate, $workspace)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    foreach ($path in @($baseline, $candidate)) {
        New-Item -ItemType Directory -Path (Join-Path $path 'references') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $path 'SKILL.md'), "---`nname: mypm`ndescription: test`n---`n", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $path 'README.md'), "test`n", $utf8)
    }

    $attachment = Join-Path $tempRoot 'attachment.txt'
    [System.IO.File]::WriteAllText($attachment, "fixture`n", $utf8)
    $evalFile = Join-Path $tempRoot 'evals.json'
    Write-JsonFile -Path $evalFile -Value ([ordered]@{
        skill_name = 'mypm'
        version = '0.30.0'
        evals = @(
            [ordered]@{
                id = 'T1'
                name = 'first'
                prompt = 'First request'
                expected_output = 'First expected output'
                expectations = @('criterion-a', 'criterion-b')
                files = @()
            },
            [ordered]@{
                id = 'T2'
                name = 'second'
                prompt = 'Second request'
                expected_output = 'Second expected output'
                expectations = @('criterion-a', 'criterion-b')
                files = @($attachment)
            }
        )
    })

    $regressionScript = Join-Path $scriptRoot 'regression-workspace.ps1'
    $batchScript = Join-Path $scriptRoot 'grading-batches.ps1'
    & $regressionScript -Action Prepare -Workspace $workspace -BaselinePath $baseline -CandidatePath $candidate `
        -EvalFile $evalFile -SuiteLabel 'pipeline-test' -EvaluationTier coverage -ReasoningEffort low `
        -BaselineLabel 'old' -CandidateLabel 'new' -BaselineModel 'test-a' -CandidateModel 'test-b'

    $iteration = Get-Content -LiteralPath (Join-Path $workspace 'iteration.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($directoryName in @($iteration.eval_directories)) {
        foreach ($configuration in @('baseline', 'candidate')) {
            $runDirectory = Join-Path $workspace "$directoryName\$configuration\run-1"
            [System.IO.File]::WriteAllText((Join-Path $runDirectory 'response.md'), "response $directoryName`n", $utf8)
        }
    }

    & $batchScript -Action Prepare -Workspace $workspace -BatchSize 3
    $batchRoot = Join-Path $workspace '_grading-batches'
    $batchManifest = Get-Content -LiteralPath (Join-Path $batchRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $mapping = Get-Content -LiteralPath (Join-Path $batchRoot '_private\mapping.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$batchManifest.item_count) -Expected 4 -Message 'batch item count'
    Assert-Equal -Actual (@($batchManifest.batches).Count) -Expected 2 -Message 'batch count'

    $mappingById = @{}
    foreach ($map in @($mapping.items)) { $mappingById[[string]$map.blind_id] = $map }
    foreach ($batch in @($batchManifest.batches)) {
        $inputPath = Join-Path $batchRoot ([string]$batch.input)
        $inputText = [System.IO.File]::ReadAllText($inputPath, [System.Text.Encoding]::UTF8)
        if ($inputText -match '"configuration"\s*:|"run_directory"\s*:') {
            throw 'blind grading input leaked private mapping fields'
        }
        $input = $inputText | ConvertFrom-Json
        $results = [System.Collections.Generic.List[object]]::new()
        foreach ($item in @($input.items)) {
            $map = $mappingById[[string]$item.blind_id]
            $graded = [System.Collections.Generic.List[object]]::new()
            for ($index = 0; $index -lt @($item.expectations).Count; $index++) {
                $passed = $true
                if ($map.eval_id -eq 'T1' -and $map.configuration -eq 'candidate' -and $index -eq 1) { $passed = $false }
                if ($map.eval_id -eq 'T2' -and $map.configuration -eq 'baseline' -and $index -eq 1) { $passed = $false }
                $graded.Add([ordered]@{
                    text = [string]$item.expectations[$index]
                    passed = $passed
                    evidence = if ($passed) { 'supported' } else { 'not supported' }
                })
            }
            $results.Add([ordered]@{ blind_id = [string]$item.blind_id; expectations = @($graded) })
        }
        Write-JsonFile -Path (Join-Path $batchRoot ([string]$batch.expected_output)) -Value ([ordered]@{ results = @($results) })
    }

    $rootGuardRejected = $false
    try {
        & $batchScript -Action Prepare -Workspace $workspace -OutputDirectory '.' -Overwrite
    } catch {
        $rootGuardRejected = $true
    }
    Assert-Equal -Actual $rootGuardRejected -Expected $true -Message 'workspace-root output guard'

    $firstBatch = @($batchManifest.batches)[0]
    $firstInputPath = Join-Path $batchRoot ([string]$firstBatch.input)
    $firstOutputPath = Join-Path $batchRoot ([string]$firstBatch.expected_output)
    $firstInput = Get-Content -LiteralPath $firstInputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $tamperedOutput = Get-Content -LiteralPath $firstOutputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $tamperedOutput.results[0].expectations[0].text = 'tampered criterion'
    Write-JsonFile -Path $firstOutputPath -Value $tamperedOutput
    $tamperRejected = $false
    try {
        & $batchScript -Action Apply -Workspace $workspace
    } catch {
        $tamperRejected = $true
    }
    Assert-Equal -Actual $tamperRejected -Expected $true -Message 'expectation tamper guard'
    $tamperedOutput.results[0].expectations[0].text = [string]$firstInput.items[0].expectations[0]
    Write-JsonFile -Path $firstOutputPath -Value $tamperedOutput

    & $batchScript -Action Apply -Workspace $workspace
    & $regressionScript -Action Validate -Workspace $workspace

    $report = Get-Content -LiteralPath (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$report.paired_summary.complete_pairs) -Expected 2 -Message 'paired complete count'
    Assert-Equal -Actual ([int]$report.paired_summary.incomplete_pairs) -Expected 0 -Message 'paired incomplete count'
    Assert-Equal -Actual ([int]$report.paired_summary.baseline_wins) -Expected 1 -Message 'baseline wins'
    Assert-Equal -Actual ([int]$report.paired_summary.candidate_wins) -Expected 1 -Message 'candidate wins'
    Assert-Equal -Actual ([int]$report.paired_summary.ties) -Expected 0 -Message 'ties'
    Assert-Equal -Actual ([int]$report.paired_summary.baseline_passed) -Expected 3 -Message 'baseline paired score'
    Assert-Equal -Actual ([int]$report.paired_summary.candidate_passed) -Expected 3 -Message 'candidate paired score'
    Assert-Equal -Actual ([int]$report.paired_summary.total) -Expected 4 -Message 'paired denominator'
    Assert-Equal -Actual (@($report.runs | Where-Object { $_.execution_status -eq 'unknown' -and $_.valid_return_basis -eq 'legacy-artifacts-status-unknown' }).Count) -Expected 4 -Message 'legacy status must remain unknown'
    Assert-Equal $report.paired_summary.baseline_median_duration_ms $null 'missing timing has no median'
    Assert-Equal @($report.summary[0].duration_by_basis).Count 0 'missing timing has no groups'

    $runPaths = @($iteration.eval_directories | ForEach-Object {
        $directoryName = $_
        foreach ($configuration in @('baseline', 'candidate')) { Join-Path $workspace "$directoryName\$configuration\run-1" }
    })
    [System.IO.File]::WriteAllText((Join-Path $runPaths[0] 'response.md'), " `n`t", $utf8)
    Write-JsonFile -Path (Join-Path $runPaths[1] 'execution.json') -Value ([ordered]@{ status = 'execution_failed'; duration_ms = 900001; attempts = 3; stopping_reason = 'fixture error' })
    Write-JsonFile -Path (Join-Path $runPaths[2] 'execution.json') -Value ([ordered]@{ status = 'cancelled'; duration_ms = 1; attempts = 1 })
    [System.IO.File]::WriteAllText((Join-Path $runPaths[3] 'execution.json'), '{invalid-json', $utf8)
    & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
    $invalidReport = Get-Content -LiteralPath (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$invalidReport.paired_summary.complete_pairs) -Expected 0 -Message 'invalid residual files must not form complete pairs'
    Assert-Equal -Actual (@($invalidReport.runs | Where-Object valid_return).Count) -Expected 0 -Message 'empty, failed, cancelled and malformed runs must not count as valid'
    Assert-Equal -Actual ([string]$invalidReport.runs[1].execution_status) -Expected 'execution_failed' -Message 'failed status must be retained'
    Assert-Equal -Actual ([int]$invalidReport.runs[1].execution_attempts) -Expected 3 -Message 'attempt count must be retained'
    Assert-Equal -Actual ([double]$invalidReport.runs[1].duration_ms) -Expected 900001 -Message 'failed execution time must be retained'

    foreach ($path in $runPaths) {
        [System.IO.File]::WriteAllText((Join-Path $path 'response.md'), "completed fixture`n", $utf8)
        Write-JsonFile -Path (Join-Path $path 'execution.json') -Value ([ordered]@{ status = 'succeeded'; duration_ms = 900001; attempts = 3 })
    }
    & $regressionScript -Action Validate -Workspace $workspace
    $longReport = Get-Content -LiteralPath (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$longReport.paired_summary.complete_pairs) -Expected 2 -Message 'late third-attempt answers must be valid'
    Assert-Equal -Actual ([int]$longReport.paired_summary.candidate_passed) -Expected 3 -Message 'execution success must not overwrite failed quality assertions'
    Assert-Equal -Actual (@($longReport.runs | Where-Object { $_.valid_return_basis -eq 'execution-confirmed' }).Count) -Expected 4 -Message 'explicit execution completion must be distinguished'

    Write-JsonFile -Path (Join-Path $runPaths[0] 'execution.json') -Value ([ordered]@{ status = 'running'; duration_ms = 1200; attempts = 1 })
    & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
    $pendingReport = Get-Content -LiteralPath (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([bool]$pendingReport.runs[0].valid_return) -Expected $false -Message 'in-progress execution must not be inferred complete from residual output'

    $timed = [ordered]@{
        status = 'succeeded'; attempts = 3; stopping_reason = 'completed'
        duration_basis = 'per-case-wall-clock'; duration_ms = 900001
        started_at_utc = '2026-09-03T00:00:00.000Z'; ended_at_utc = '2026-09-03T00:15:00.001Z'
    }
    $iteration.execution_protocol | Add-Member -NotePropertyName timing_protocol -NotePropertyValue 'per-case-utc-v1' -Force
    Write-JsonFile -Path (Join-Path $workspace 'iteration.json') -Value $iteration
    foreach ($path in $runPaths) { Write-JsonFile -Path (Join-Path $path 'execution.json') -Value $timed }
    & $regressionScript -Action Validate -Workspace $workspace
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.paired_summary.complete_pairs 2 'UTC late third result'
    Assert-Equal $report.paired_summary.candidate_passed 3 'valid low score retained under UTC protocol'
    Assert-Equal $report.runs[1].execution_attempts 3 'validation must not add a retry'
    $firstAttempt = $timed | ConvertTo-Json | ConvertFrom-Json
    $firstAttempt.attempts = 1
    Write-JsonFile -Path (Join-Path $runPaths[1] 'execution.json') -Value $firstAttempt
    & $regressionScript -Action Validate -Workspace $workspace
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.runs[1].execution_attempts 1 'valid low-scoring first attempt is not retried'
    Assert-Equal $report.runs[1].passed 1 'low score remains unchanged'
    # Queue-state records must survive reporting without becoming valid answers.
    foreach ($queueState in @(
        @{ name = 'third-still-waiting'; status = 'running'; attempts = 3; reason = 'awaiting-result' },
        @{ name = 'optional-fallback'; status = 'cancelled'; attempts = 1; reason = 'optional-fallback' },
        @{ name = 'third-user-stop'; status = 'cancelled'; attempts = 3; reason = 'user-stop' },
        @{ name = 'third-executor-error'; status = 'execution_failed'; attempts = 3; reason = 'executor-error' }
    )) {
        $pending = $timed | ConvertTo-Json | ConvertFrom-Json
        $pending.status = $queueState.status
        $pending.attempts = $queueState.attempts
        $pending.stopping_reason = $queueState.reason
        Write-JsonFile -Path (Join-Path $runPaths[0] 'execution.json') -Value $pending
        $answerHash = (Get-FileHash -LiteralPath (Join-Path $runPaths[1] 'response.md')).Hash
        & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
        $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Equal $report.runs[0].valid_return $false "$($queueState.name) not a valid answer"
        Assert-Equal $report.runs[0].execution_status $queueState.status "$($queueState.name) status retained"
        Assert-Equal $report.runs[0].execution_attempts $queueState.attempts "$($queueState.name) attempts retained"
        Assert-Equal $report.runs[0].stopping_reason $queueState.reason "$($queueState.name) reason retained"
        Assert-Equal $report.runs[0].duration_ms 900001 "$($queueState.name) elapsed retained"
        Assert-Equal $report.runs[1].valid_return $true 'independent valid low score remains scoreable'
        Assert-Equal $report.runs[1].execution_attempts 1 'reporting cannot schedule a retry'
        Assert-Equal $report.runs[1].passed 1 'independent low quality remains unchanged'
        Assert-Equal (Get-FileHash -LiteralPath (Join-Path $runPaths[1] 'response.md')).Hash $answerHash 'reporting cannot replace the answer'
    }
    Remove-Item -LiteralPath (Join-Path $runPaths[0] 'execution.json')
    & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.runs[0].valid_return $false 'new protocol rejects missing execution metadata'

    foreach ($mutation in @(
        @{ field = 'duration_ms'; value = 900100 },
        @{ field = 'duration_basis'; value = 'batch-wall-clock-equal-allocation' },
        @{ field = 'duration_basis'; value = $null },
        @{ field = 'started_at_utc'; value = $null },
        @{ field = 'ended_at_utc'; value = '2026-09-02T00:00:00Z' },
        @{ field = 'ended_at_utc'; value = 'not-a-date' },
        @{ field = 'ended_at_utc'; value = '2026-09-03T08:15:00.001+08:00' },
        @{ field = 'status'; value = $null },
        @{ field = 'status'; value = 'running' },
        @{ field = 'stopping_reason'; value = 'cancelled' },
        @{ field = 'stopping_reason'; value = $null },
        @{ field = 'attempts'; value = 4 }
    )) {
        $bad = $timed | ConvertTo-Json | ConvertFrom-Json
        $bad.($mutation.field) = $mutation.value
        Write-JsonFile -Path (Join-Path $runPaths[0] 'execution.json') -Value $bad
        & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
        $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Equal $report.runs[0].valid_return $false "reject timing mutation $($mutation.field)"
    }
    $iteration.execution_protocol.timing_protocol = 'legacy'
    Write-JsonFile -Path (Join-Path $workspace 'iteration.json') -Value $iteration
    Write-JsonFile -Path (Join-Path $runPaths[0] 'execution.json') -Value ([ordered]@{
        status = 'succeeded'; duration_ms = 900001; duration_basis = 'batch-wall-clock-equal-allocation'
    })
    & $regressionScript -Action Validate -Workspace $workspace
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.runs[0].valid_return $true 'older batch record compatibility'
    Assert-Equal $report.runs[0].duration_basis 'batch-wall-clock-equal-allocation' 'batch label preserved'
    Assert-Equal $report.runs[0].started_at_utc $null 'historical timestamps not fabricated'
    # Each pair is internally consistent; only cross-pair aggregation mixes bases.
    foreach ($bases in @(
        @('per-case-wall-clock', 'batch-wall-clock-equal-allocation'),
        @('per-case-wall-clock', 'per-case-wall-clock'),
        @('batch-wall-clock-equal-allocation', 'batch-wall-clock-equal-allocation'),
        @('legacy-unspecified', 'legacy-unspecified'),
        @('per-case-wall-clock', 'legacy-unspecified')
    )) {
        $durations = @(100, 200, 10000, 5000)
        for ($index = 0; $index -lt $runPaths.Count; $index++) {
            $basis = $bases[[int][Math]::Floor($index / 2)]
            $execution = [ordered]@{ status = 'succeeded'; duration_ms = $durations[$index]; attempts = 1; stopping_reason = 'completed' }
            if ($basis -ne 'legacy-unspecified') { $execution.duration_basis = $basis }
            if ($basis -eq 'per-case-wall-clock') {
                $execution.started_at_utc = '2026-09-03T00:00:00.000Z'
                $execution.ended_at_utc = ([datetime]::Parse('2026-09-03T00:00:00Z').ToUniversalTime()).AddMilliseconds($durations[$index]).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
            }
            Write-JsonFile -Path (Join-Path $runPaths[$index] 'execution.json') -Value $execution
        }
        & $regressionScript -Action Validate -Workspace $workspace
        $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $comparable = $bases[0] -eq $bases[1] -and $bases[0] -ne 'legacy-unspecified'
        $expectedBaseline = if ($comparable) { 5050 } else { $null }
        $expectedCandidate = if ($comparable) { 2600 } else { $null }
        Write-Host "Timing fixture $($bases -join '/'): baseline=$($report.paired_summary.baseline_median_duration_ms) candidate=$($report.paired_summary.candidate_median_duration_ms)"
        Assert-Equal $report.paired_summary.baseline_median_duration_ms $expectedBaseline 'cross-pair baseline median gate'
        Assert-Equal $report.paired_summary.candidate_median_duration_ms $expectedCandidate 'cross-pair candidate median gate'
        Assert-Equal $report.summary[0].median_duration_ms $expectedBaseline 'ordinary baseline median gate'
        Assert-Equal $report.summary[1].median_duration_ms $expectedCandidate 'ordinary candidate median gate'
        Assert-Equal $report.paired_summary.duration_comparable $comparable 'global comparison flag'
        Assert-Equal $report.paired_summary.complete_pairs 2 'timing basis must not change valid returns'
        Assert-Equal $report.paired_summary.candidate_passed 3 'timing basis must not change quality'
        Assert-Equal $report.paired_summary.duration_complete_pairs 2 'retain same-basis pair sample count'
        $groupCount = @($bases | Sort-Object -Unique).Count
        Assert-Equal @($report.paired_summary.duration_by_basis).Count $groupCount 'paired basis groups'
        Assert-Equal @($report.summary[0].duration_by_basis).Count $groupCount 'ordinary basis groups'
        foreach ($row in @($report.summary)) {
            Assert-Equal $row.duration_samples 2 'retain ordinary duration count'
            Assert-Equal $row.duration_comparable $comparable 'ordinary comparison flag'
        }
        if ($groupCount -eq 2) {
            $caseGroup = @($report.paired_summary.duration_by_basis | Where-Object duration_basis -eq 'per-case-wall-clock')[0]
            Assert-Equal $caseGroup.baseline_median_duration_ms 100 'per-case baseline retained'
            Assert-Equal $caseGroup.candidate_median_duration_ms 200 'per-case candidate retained'
            Assert-Equal $caseGroup.duration_complete_pairs 1 'per-case pair count'
            $otherPairGroup = @($report.paired_summary.duration_by_basis | Where-Object duration_basis -ne 'per-case-wall-clock')[0]
            Assert-Equal $otherPairGroup.baseline_median_duration_ms 10000 'other-basis paired baseline retained'
            Assert-Equal $otherPairGroup.candidate_median_duration_ms 5000 'other-basis paired candidate retained'
            Assert-Equal $otherPairGroup.duration_comparable ($bases[1] -ne 'legacy-unspecified') 'unknown group cannot compare speed'
            $otherGroup = @($report.summary[0].duration_by_basis | Where-Object duration_basis -ne 'per-case-wall-clock')[0]
            Assert-Equal $otherGroup.median_duration_ms 10000 'other-basis ordinary median retained'
        }
        $benchmark = Get-Content (Join-Path $workspace 'benchmark-lite.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-Equal $benchmark.paired_summary.baseline_median_duration_ms $expectedBaseline 'benchmark JSON median gate'
        $markdown = Get-Content (Join-Path $workspace 'benchmark-lite.md') -Raw -Encoding UTF8
        if (-not $comparable -and $markdown -notmatch 'baseline unavailable ms.+candidate unavailable ms') { throw 'Markdown leaked mixed/unknown global medians' }
    }
    # A mismatched pair must not be pooled with the remaining known-basis pair.
    foreach ($index in @(0, 1, 2)) { Write-JsonFile -Path (Join-Path $runPaths[$index] 'execution.json') -Value $timed }
    & $regressionScript -Action Validate -Workspace $workspace
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.paired_summary.duration_complete_pairs 1 'mismatched pair excluded from timing pairs'
    Assert-Equal $report.paired_summary.baseline_median_duration_ms $null 'mismatched basis blocks global comparison'
    Assert-Equal $report.paired_summary.duration_by_basis[0].baseline_median_duration_ms 900001 'remaining group retained'
    Write-JsonFile -Path (Join-Path $runPaths[3] 'execution.json') -Value ([ordered]@{
        status = 'execution_failed'; duration_ms = 5000; duration_basis = 'batch-wall-clock-equal-allocation'
    })
    & $regressionScript -Action Validate -Workspace $workspace -AllowIncomplete
    $report = Get-Content (Join-Path $workspace 'validation-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal $report.summary[1].duration_samples 1 'invalid return excluded from ordinary timing samples'
    Assert-Equal @($report.summary[1].duration_by_basis).Count 1 'invalid return excluded from timing groups'
    Assert-Equal $report.summary[1].median_duration_ms 900001 'invalid batch does not contaminate valid case median'
    Assert-Equal $report.paired_summary.baseline_median_duration_ms 900001 'incomplete pair excluded from comparison cohort'
    Write-Host 'Evaluation pipeline test passed: queue-state preservation, basis grouping/global median gates, legacy/batch compatibility, UTC timing rejection, late third result and quality separation (fixtures only).'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTemp = (Resolve-Path -LiteralPath $tempRoot).Path
        $systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not ($resolvedTemp + '\').StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean path outside system temp: $resolvedTemp"
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
