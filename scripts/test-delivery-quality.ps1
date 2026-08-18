$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$scriptRoot = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mypm-delivery-quality-" + [Guid]::NewGuid().ToString('N'))

function Write-JsonFile {
    param($Value, [string]$Path)
    [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine, $utf8)
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message expected=$Expected actual=$Actual" }
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

    $entries = @('idea', 'review', 'prd', 'acceptance', 'prompt', 'idea', 'prd', 'acceptance')
    $evals = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt 8; $index++) {
        $evals.Add([ordered]@{
            id = "Q$($index + 1)"
            name = "quality-$($index + 1)"
            prompt = "Request $($index + 1)"
            expected_output = "Expected $($index + 1)"
            expectations = @('criterion')
            files = @()
            quality_entry = $entries[$index]
            quality_complex = ($index -in @(0, 5))
            quality_model = if (($index % 2) -eq 0) { 'sol-medium' } else { 'terra-medium' }
        })
    }
    $evalFile = Join-Path $tempRoot 'quality-evals.json'
    Write-JsonFile -Path $evalFile -Value ([ordered]@{ skill_name = 'mypm'; version = 'test'; evals = @($evals) })

    & (Join-Path $scriptRoot 'regression-workspace.ps1') -Action Prepare -Workspace $workspace `
        -BaselinePath $baseline -CandidatePath $candidate -EvalFile $evalFile -SuiteLabel 'quality-test' `
        -EvaluationTier coverage -ReasoningEffort low -BaselineLabel old -CandidateLabel new

    $iteration = Get-Content -LiteralPath (Join-Path $workspace 'iteration.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($directoryName in @($iteration.eval_directories)) {
        foreach ($configuration in @('baseline', 'candidate')) {
            $runDirectory = Join-Path $workspace "$directoryName\$configuration\run-1"
            $response = if ($configuration -eq 'baseline') { "Concise answer for $directoryName.`n" } else { "Clear answer with one next action for $directoryName.`n" }
            [System.IO.File]::WriteAllText((Join-Path $runDirectory 'response.md'), $response, $utf8)
            Write-JsonFile -Path (Join-Path $runDirectory 'grading.json') -Value ([ordered]@{
                expectations = @([ordered]@{ text = 'criterion'; passed = $true; evidence = 'supported' })
                summary = [ordered]@{ passed = 1; failed = 0; total = 1 }
            })
            $duration = if ($configuration -eq 'baseline') { 1000 } else { 1050 }
            Write-JsonFile -Path (Join-Path $runDirectory 'execution.json') -Value ([ordered]@{ duration_ms = $duration })
        }
    }

    $qualityScript = Join-Path $scriptRoot 'delivery-quality-batches.ps1'
    & $qualityScript -Action Prepare -Workspace $workspace -BatchSize 4
    $batchRoot = Join-Path $workspace '_quality-batches'
    $manifest = Get-Content -LiteralPath (Join-Path $batchRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $mapping = Get-Content -LiteralPath (Join-Path $batchRoot '_private\mapping.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$manifest.pair_count) -Expected 8 -Message 'quality pair count'
    $mappingById = @{}
    foreach ($map in @($mapping.items)) { $mappingById[[string]$map.pair_id] = $map }

    foreach ($batch in @($manifest.batches)) {
        $inputPath = Join-Path $batchRoot ([string]$batch.input)
        $inputText = [System.IO.File]::ReadAllText($inputPath, [System.Text.Encoding]::UTF8)
        if ($inputText -match '"a_configuration"\s*:|"b_configuration"\s*:|"run_directory"\s*:') {
            throw 'quality blind input leaked private mapping fields'
        }
        $input = $inputText | ConvertFrom-Json
        $results = [System.Collections.Generic.List[object]]::new()
        foreach ($item in @($input.items)) {
            $map = $mappingById[[string]$item.pair_id]
            $candidateSide = if ([string]$map.a_configuration -eq 'candidate') { 'A' } else { 'B' }
            $comparisons = [System.Collections.Generic.List[object]]::new()
            foreach ($dimension in @($item.dimensions)) {
                $winner = if ([string]$dimension.id -eq 'redundancy') {
                    if ($candidateSide -eq 'A') { 'B' } else { 'A' }
                } else { $candidateSide }
                $comparisons.Add([ordered]@{
                    dimension = [string]$dimension.id
                    winner = $winner
                    evidence = 'sample-local evidence'
                })
            }
            $results.Add([ordered]@{ pair_id = [string]$item.pair_id; comparisons = @($comparisons) })
        }
        Write-JsonFile -Path (Join-Path $batchRoot ([string]$batch.expected_output)) -Value ([ordered]@{ results = @($results) })
    }

    & $qualityScript -Action Apply -Workspace $workspace
    & (Join-Path $scriptRoot 'regression-workspace.ps1') -Action Validate -Workspace $workspace
    $report = Get-Content -LiteralPath (Join-Path $workspace 'quality-report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal -Actual ([int]$report.pair_count) -Expected 8 -Message 'quality report pair count'
    Assert-Equal -Actual ([int]$report.dimensions.correctness.candidate_passed) -Expected 8 -Message 'formal correctness'
    Assert-Equal -Actual ([int]$report.dimensions.decision_clarity.candidate_wins) -Expected 8 -Message 'clarity wins'
    Assert-Equal -Actual ([int]$report.dimensions.redundancy.baseline_wins) -Expected 8 -Message 'redundancy baseline wins'
    Assert-Equal -Actual ([int]$report.dimensions.actionability.candidate_wins) -Expected 8 -Message 'actionability wins'
    Assert-Equal -Actual ([string]$report.dimensions.duration_ms.state) -Expected 'available' -Message 'duration state'
    Assert-Equal -Actual ([bool]$report.cost_boundary.passed) -Expected $true -Message 'cost boundary'
    Assert-Equal -Actual ([bool]$report.density_boundary.passed) -Expected $false -Message 'density boundary catches verbose redundant candidate'
    Assert-Equal -Actual ([bool]$report.cost_boundary.blocking) -Expected $false -Message 'cost boundary is observation-only'
    Assert-Equal -Actual ([bool]$report.density_boundary.blocking) -Expected $false -Message 'density boundary is observation-only'
    Assert-Equal -Actual ([double]$report.density_boundary.baseline_redundancy_win_ratio) -Expected 1 -Message 'density redundancy ratio'
    if ($null -ne $report.aggregate_score) { throw 'aggregate quality score must stay null' }
    & (Join-Path $scriptRoot 'generate-eval-viewer.ps1') -Workspace $workspace -Title 'quality-test-viewer' `
        -BaselineLabel old -CandidateLabel new -SuiteLabel 'quality-test'
    $viewer = [System.IO.File]::ReadAllText((Join-Path $workspace 'eval-viewer.html'), [System.Text.Encoding]::UTF8)
    $densityObservationText = -join @([char]0x5BC6, [char]0x5EA6, [char]0x89C2, [char]0x5BDF)
    foreach ($requiredText in @('quality-test-viewer', 'quality-detail-panel', 'quality-grid', $densityObservationText, 'unavailable')) {
        if (-not $viewer.Contains($requiredText)) { throw "viewer is missing quality text: $requiredText" }
    }
    if ($viewer -match 'Superpowers|Prime Radiant') { throw 'viewer contains foreign brand text' }
    Write-Host 'Delivery quality pipeline test passed.'
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
