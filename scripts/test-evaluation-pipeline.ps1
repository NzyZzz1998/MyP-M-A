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

    Write-Host 'Evaluation pipeline test passed.'
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
