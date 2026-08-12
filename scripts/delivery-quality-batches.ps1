param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Prepare', 'Apply')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Workspace,

    [string]$RubricPath = 'evals\delivery-quality-rubric.json',

    [ValidateRange(1, 8)]
    [int]$BatchSize = 3,

    [string]$OutputDirectory = '_quality-batches',

    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
$skillRoot = Split-Path -Parent $PSScriptRoot

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $json = $Value | ConvertTo-Json -Depth 40
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8)
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

function Get-StableHash {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Get-Median {
    param([object[]]$Values)
    $numbers = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ } | Sort-Object)
    if ($numbers.Count -eq 0) { return $null }
    $middle = [int][Math]::Floor($numbers.Count / 2)
    if (($numbers.Count % 2) -eq 1) { return [Math]::Round($numbers[$middle], 1) }
    return [Math]::Round(($numbers[$middle - 1] + $numbers[$middle]) / 2, 1)
}

function Resolve-Context {
    $workspacePath = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path
    $iterationPath = Join-Path $workspacePath 'iteration.json'
    if (-not (Test-Path -LiteralPath $iterationPath -PathType Leaf)) {
        throw "iteration.json not found: $iterationPath"
    }
    $rubricCandidate = if ([System.IO.Path]::IsPathRooted($RubricPath)) { $RubricPath } else { Join-Path $skillRoot $RubricPath }
    $rubricResolved = (Resolve-Path -LiteralPath $rubricCandidate -ErrorAction Stop).Path
    $outputPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        [System.IO.Path]::GetFullPath($OutputDirectory)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $workspacePath $OutputDirectory))
    }
    if ($outputPath.Equals($workspacePath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-IsInside -Child $outputPath -Parent $workspacePath)) {
        throw 'Quality batch output must stay inside the regression workspace.'
    }
    return [ordered]@{
        workspace = $workspacePath
        iteration = Read-JsonFile -Path $iterationPath
        rubric = Read-JsonFile -Path $rubricResolved
        rubric_path = $rubricResolved
        output = $outputPath
    }
}

function Get-ExecutionDuration {
    param([Parameter(Mandatory = $true)][string]$RunDirectory)
    $path = Join-Path $RunDirectory 'execution.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $execution = Read-JsonFile -Path $path
        if ($null -ne $execution.duration_ms -and [double]$execution.duration_ms -ge 0) {
            return [Math]::Round([double]$execution.duration_ms, 1)
        }
    } catch {
        return $null
    }
    return $null
}

function Invoke-Prepare {
    $context = Resolve-Context
    $workspacePath = $context.workspace
    $iteration = $context.iteration
    $rubric = $context.rubric
    $outputPath = $context.output
    if (Test-Path -LiteralPath $outputPath) {
        if (-not $Overwrite) { throw "Quality batch directory already exists; use -Overwrite: $outputPath" }
        Remove-Item -LiteralPath $outputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $privatePath = Join-Path $outputPath '_private'
    New-Item -ItemType Directory -Path $privatePath -Force | Out-Null

    $blindDimensions = @($rubric.dimensions | Where-Object { [string]$_.kind -eq 'paired_blind' })
    $pending = [System.Collections.Generic.List[object]]::new()
    $entries = @{}
    $complexCount = 0
    foreach ($directoryName in @($iteration.eval_directories)) {
        $evalDirectory = Join-Path $workspacePath $directoryName
        $task = Read-JsonFile -Path (Join-Path $evalDirectory 'task.json')
        $metadata = Read-JsonFile -Path (Join-Path $workspacePath "$($iteration.grader_directory)\$directoryName.json")
        $entry = [string]$metadata.quality_entry
        if ([string]::IsNullOrWhiteSpace($entry)) { throw "quality_entry is missing: $directoryName" }
        $entries[$entry] = $true
        if ([bool]$metadata.quality_complex) { $complexCount++ }
        $attachments = [System.Collections.Generic.List[object]]::new()
        foreach ($relativeFile in @($task.files)) {
            $attachmentPath = Join-Path $evalDirectory ([string]$relativeFile)
            $attachments.Add([ordered]@{
                name = Split-Path -Leaf $attachmentPath
                content = [System.IO.File]::ReadAllText($attachmentPath, [System.Text.Encoding]::UTF8)
            })
        }
        foreach ($runNumber in 1..([int]$iteration.runs_per_configuration)) {
            $baselineDirectory = Join-Path $evalDirectory "baseline\run-$runNumber"
            $candidateDirectory = Join-Path $evalDirectory "candidate\run-$runNumber"
            $required = @(
                (Join-Path $baselineDirectory 'response.md'),
                (Join-Path $candidateDirectory 'response.md'),
                (Join-Path $baselineDirectory 'grading.json'),
                (Join-Path $candidateDirectory 'grading.json')
            )
            if (@($required | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }).Count -gt 0) {
                throw "Incomplete quality pair: $directoryName run-$runNumber"
            }
            $baselineResponse = [System.IO.File]::ReadAllText($required[0], [System.Text.Encoding]::UTF8)
            $candidateResponse = [System.IO.File]::ReadAllText($required[1], [System.Text.Encoding]::UTF8)
            $hash = Get-StableHash -Value "$($metadata.id)|$runNumber|delivery-quality-v1"
            $baselineFirst = ([Convert]::ToInt32($hash.Substring(0, 2), 16) % 2) -eq 0
            $aConfig = if ($baselineFirst) { 'baseline' } else { 'candidate' }
            $bConfig = if ($baselineFirst) { 'candidate' } else { 'baseline' }
            $pending.Add([ordered]@{
                sort_key = $hash
                eval_id = [string]$metadata.id
                eval_name = [string]$metadata.name
                eval_directory = $directoryName
                entry = $entry
                complex = [bool]$metadata.quality_complex
                model_context = [string]$metadata.quality_model
                run = $runNumber
                prompt = [string]$task.prompt
                attachments = @($attachments)
                expected_output = [string]$metadata.expected_output
                a_configuration = $aConfig
                b_configuration = $bConfig
                a_response = if ($aConfig -eq 'baseline') { $baselineResponse } else { $candidateResponse }
                b_response = if ($bConfig -eq 'baseline') { $baselineResponse } else { $candidateResponse }
                baseline_directory = $baselineDirectory
                candidate_directory = $candidateDirectory
            })
        }
    }

    $minimumPairs = [int]$rubric.sample_policy.minimum_pairs
    $maximumPairs = [int]$rubric.sample_policy.maximum_pairs
    if ($pending.Count -lt $minimumPairs -or $pending.Count -gt $maximumPairs) {
        throw "Quality sample count outside $minimumPairs..${maximumPairs}: $($pending.Count)"
    }
    foreach ($requiredEntry in @($rubric.sample_policy.required_entries)) {
        if (-not $entries.ContainsKey([string]$requiredEntry)) { throw "Missing quality entry: $requiredEntry" }
    }
    if ($complexCount -lt [int]$rubric.sample_policy.minimum_complex_scenarios) {
        throw "Complex quality samples too few: $complexCount"
    }

    $orderedPending = @($pending | Sort-Object sort_key)
    $mappingItems = [System.Collections.Generic.List[object]]::new()
    $batchEntries = [System.Collections.Generic.List[object]]::new()
    for ($offset = 0; $offset -lt $orderedPending.Count; $offset += $BatchSize) {
        $batchNumber = [int]($offset / $BatchSize) + 1
        $batchName = 'batch-{0:D3}' -f $batchNumber
        $lastIndex = [Math]::Min($offset + $BatchSize - 1, $orderedPending.Count - 1)
        $batchItems = [System.Collections.Generic.List[object]]::new()
        for ($index = $offset; $index -le $lastIndex; $index++) {
            $item = $orderedPending[$index]
            $pairId = 'Q{0:D4}' -f ($index + 1)
            $batchItems.Add([ordered]@{
                pair_id = $pairId
                prompt = $item.prompt
                attachments = @($item.attachments)
                expected_output = $item.expected_output
                responses = [ordered]@{ A = $item.a_response; B = $item.b_response }
                dimensions = @($blindDimensions | ForEach-Object {
                    [ordered]@{ id = [string]$_.id; label = [string]$_.label; rule = [string]$_.rule }
                })
            })
            $mappingItems.Add([ordered]@{
                pair_id = $pairId
                batch = $batchName
                eval_id = $item.eval_id
                eval_name = $item.eval_name
                eval_directory = $item.eval_directory
                entry = $item.entry
                complex = $item.complex
                model_context = $item.model_context
                run = $item.run
                a_configuration = $item.a_configuration
                b_configuration = $item.b_configuration
                baseline_directory = $item.baseline_directory
                candidate_directory = $item.candidate_directory
            })
        }
        $inputName = "$batchName-input.json"
        $outputName = "$batchName-output.json"
        Write-JsonFile -Value ([ordered]@{
            schema_version = 1
            instruction = 'Compare each pair independently. Return A, B, or tie for every dimension. Use only evidence from that pair.'
            output_contract = [ordered]@{
                results = @([ordered]@{
                    pair_id = 'Return pair_id unchanged'
                    comparisons = @([ordered]@{ dimension = 'Return dimension id unchanged'; winner = 'A|B|tie'; evidence = 'Chinese evidence' })
                })
            }
            items = @($batchItems)
        }) -Path (Join-Path $outputPath $inputName)
        $batchEntries.Add([ordered]@{ name = $batchName; input = $inputName; expected_output = $outputName; item_count = $batchItems.Count })
    }
    Write-JsonFile -Value ([ordered]@{
        schema_version = 1
        prepared_at_utc = [DateTime]::UtcNow.ToString('o')
        rubric = $context.rubric_path
        pair_count = $mappingItems.Count
        batch_size = $BatchSize
        batches = @($batchEntries)
    }) -Path (Join-Path $outputPath 'manifest.json')
    Write-JsonFile -Value ([ordered]@{
        schema_version = 1
        note = 'Private version mapping. Never provide this file to graders.'
        items = @($mappingItems)
    }) -Path (Join-Path $privatePath 'mapping.json')
    Write-Host "Delivery quality batches prepared: pairs=$($mappingItems.Count) batches=$($batchEntries.Count)"
}

function Invoke-Apply {
    $context = Resolve-Context
    $workspacePath = $context.workspace
    $rubric = $context.rubric
    $outputPath = $context.output
    $manifest = Read-JsonFile -Path (Join-Path $outputPath 'manifest.json')
    $mapping = Read-JsonFile -Path (Join-Path $outputPath '_private\mapping.json')
    $mappingById = @{}
    foreach ($item in @($mapping.items)) { $mappingById[[string]$item.pair_id] = $item }
    $resultsById = @{}
    foreach ($batch in @($manifest.batches)) {
        $outputFile = Join-Path $outputPath ([string]$batch.expected_output)
        if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) { throw "Missing quality grader output: $($batch.expected_output)" }
        $payload = Read-JsonFile -Path $outputFile
        foreach ($result in @($payload.results)) {
            $pairId = [string]$result.pair_id
            if (-not $mappingById.ContainsKey($pairId)) { throw "Unknown quality pair_id: $pairId" }
            if ($resultsById.ContainsKey($pairId)) { throw "Duplicate quality pair_id: $pairId" }
            $resultsById[$pairId] = $result
        }
    }

    $blindDimensions = @($rubric.dimensions | Where-Object { [string]$_.kind -eq 'paired_blind' })
    $dimensionSummary = [ordered]@{}
    foreach ($dimension in $blindDimensions) {
        $dimensionSummary[[string]$dimension.id] = [ordered]@{ baseline_wins = 0; candidate_wins = 0; ties = 0 }
    }
    $cases = [System.Collections.Generic.List[object]]::new()
    $baselinePassed = 0
    $candidatePassed = 0
    $formalTotal = 0
    $baselineChars = 0
    $candidateChars = 0
    $baselineDurations = [System.Collections.Generic.List[double]]::new()
    $candidateDurations = [System.Collections.Generic.List[double]]::new()

    foreach ($pairId in @($mappingById.Keys | Sort-Object)) {
        if (-not $resultsById.ContainsKey($pairId)) { throw "Missing quality result: $pairId" }
        $map = $mappingById[$pairId]
        $result = $resultsById[$pairId]
        $comparisons = @($result.comparisons)
        if ($comparisons.Count -ne $blindDimensions.Count) { throw "Quality dimension count mismatch: $pairId" }
        $normalized = [System.Collections.Generic.List[object]]::new()
        for ($index = 0; $index -lt $blindDimensions.Count; $index++) {
            $expectedId = [string]$blindDimensions[$index].id
            $comparison = $comparisons[$index]
            if ([string]$comparison.dimension -ne $expectedId) { throw "Quality dimension mismatch for $pairId at index $index" }
            $winner = [string]$comparison.winner
            if ($winner -notin @('A', 'B', 'tie')) { throw "Invalid quality winner for ${pairId}: $winner" }
            if ([string]::IsNullOrWhiteSpace([string]$comparison.evidence)) { throw "Empty quality evidence for ${pairId}: $expectedId" }
            $mappedWinner = 'tie'
            if ($winner -eq 'A') { $mappedWinner = [string]$map.a_configuration }
            if ($winner -eq 'B') { $mappedWinner = [string]$map.b_configuration }
            $summary = $dimensionSummary[$expectedId]
            if ($mappedWinner -eq 'baseline') { $summary.baseline_wins++ }
            elseif ($mappedWinner -eq 'candidate') { $summary.candidate_wins++ }
            else { $summary.ties++ }
            $normalized.Add([ordered]@{
                dimension = $expectedId
                winner = $mappedWinner
                evidence = [string]$comparison.evidence
            })
        }

        $baselineResponsePath = Join-Path ([string]$map.baseline_directory) 'response.md'
        $candidateResponsePath = Join-Path ([string]$map.candidate_directory) 'response.md'
        $baselineGrade = Read-JsonFile -Path (Join-Path ([string]$map.baseline_directory) 'grading.json')
        $candidateGrade = Read-JsonFile -Path (Join-Path ([string]$map.candidate_directory) 'grading.json')
        $baselineResponseChars = [System.IO.File]::ReadAllText($baselineResponsePath, [System.Text.Encoding]::UTF8).Length
        $candidateResponseChars = [System.IO.File]::ReadAllText($candidateResponsePath, [System.Text.Encoding]::UTF8).Length
        $baselineDuration = Get-ExecutionDuration -RunDirectory ([string]$map.baseline_directory)
        $candidateDuration = Get-ExecutionDuration -RunDirectory ([string]$map.candidate_directory)
        $baselinePassed += [int]$baselineGrade.summary.passed
        $candidatePassed += [int]$candidateGrade.summary.passed
        $formalTotal += [int]$baselineGrade.summary.total
        $baselineChars += $baselineResponseChars
        $candidateChars += $candidateResponseChars
        if ($null -ne $baselineDuration -and $null -ne $candidateDuration) {
            $baselineDurations.Add([double]$baselineDuration)
            $candidateDurations.Add([double]$candidateDuration)
        }
        $cases.Add([ordered]@{
            pair_id = $pairId
            eval_id = [string]$map.eval_id
            eval_name = [string]$map.eval_name
            entry = [string]$map.entry
            complex = [bool]$map.complex
            model_context = [string]$map.model_context
            formal_correctness = [ordered]@{
                baseline = [ordered]@{ passed = [int]$baselineGrade.summary.passed; total = [int]$baselineGrade.summary.total }
                candidate = [ordered]@{ passed = [int]$candidateGrade.summary.passed; total = [int]$candidateGrade.summary.total }
            }
            comparisons = @($normalized)
            response_chars = [ordered]@{ baseline = $baselineResponseChars; candidate = $candidateResponseChars }
            duration_ms = [ordered]@{ baseline = $baselineDuration; candidate = $candidateDuration; state = if ($null -ne $baselineDuration -and $null -ne $candidateDuration) { 'available' } else { 'unavailable' } }
            valid_return = [ordered]@{ baseline = $true; candidate = $true }
        })
    }

    $pairCount = $cases.Count
    $baselineAverageChars = if ($pairCount -gt 0) { [Math]::Round($baselineChars / $pairCount, 1) } else { $null }
    $candidateAverageChars = if ($pairCount -gt 0) { [Math]::Round($candidateChars / $pairCount, 1) } else { $null }
    $charRatio = if ($baselineChars -gt 0) { [Math]::Round(($candidateChars / $baselineChars) - 1, 4) } else { $null }
    $baselineMedianDuration = Get-Median -Values @($baselineDurations)
    $candidateMedianDuration = Get-Median -Values @($candidateDurations)
    $durationRatio = if ($null -ne $baselineMedianDuration -and $baselineMedianDuration -gt 0) {
        [Math]::Round(($candidateMedianDuration / $baselineMedianDuration) - 1, 4)
    } else { $null }
    $clarity = $dimensionSummary['decision_clarity']
    $actionability = $dimensionSummary['actionability']
    $qualityBenefit = ($clarity.candidate_wins -gt $clarity.baseline_wins) -or ($actionability.candidate_wins -gt $actionability.baseline_wins)
    $charExceeded = $null -ne $charRatio -and $charRatio -gt [double]$rubric.cost_boundary.response_chars_increase_ratio
    $durationExceeded = $null -ne $durationRatio -and $durationRatio -gt [double]$rubric.cost_boundary.median_duration_increase_ratio
    $costPassed = -not (($charExceeded -or $durationExceeded) -and -not $qualityBenefit)
    $redundancy = $dimensionSummary['redundancy']
    $baselineRedundancyWinRatio = if ($pairCount -gt 0) { [Math]::Round($redundancy.baseline_wins / $pairCount, 4) } else { 0 }
    $densityCharExceeded = $null -ne $charRatio -and $charRatio -gt [double]$rubric.density_boundary.response_chars_increase_ratio
    $densityRedundancyExceeded = $baselineRedundancyWinRatio -ge [double]$rubric.density_boundary.baseline_redundancy_win_ratio
    $densityPassed = -not ($densityCharExceeded -and $densityRedundancyExceeded)

    $report = [ordered]@{
        schema_version = 1
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        rubric = $context.rubric_path
        aggregate_score = $null
        pair_count = $pairCount
        dimensions = [ordered]@{
            correctness = [ordered]@{ baseline_passed = $baselinePassed; candidate_passed = $candidatePassed; total = $formalTotal; gate = 'formal-boolean' }
            decision_clarity = $dimensionSummary['decision_clarity']
            redundancy = $dimensionSummary['redundancy']
            actionability = $dimensionSummary['actionability']
            response_chars = [ordered]@{ baseline_average = $baselineAverageChars; candidate_average = $candidateAverageChars; candidate_change_ratio = $charRatio }
            duration_ms = [ordered]@{ state = if ($baselineDurations.Count -gt 0) { 'available' } else { 'unavailable' }; paired_samples = $baselineDurations.Count; baseline_median = $baselineMedianDuration; candidate_median = $candidateMedianDuration; candidate_change_ratio = $durationRatio }
            valid_return_rate = [ordered]@{ baseline = 1.0; candidate = 1.0; baseline_count = $pairCount; candidate_count = $pairCount; expected = $pairCount }
        }
        cost_boundary = [ordered]@{
            passed = $costPassed
            char_threshold_exceeded = $charExceeded
            duration_threshold_exceeded = $durationExceeded
            quality_benefit = $qualityBenefit
        }
        density_boundary = [ordered]@{
            passed = $densityPassed
            char_threshold_exceeded = $densityCharExceeded
            baseline_redundancy_threshold_exceeded = $densityRedundancyExceeded
            baseline_redundancy_win_ratio = $baselineRedundancyWinRatio
        }
        cases = @($cases)
    }
    Write-JsonFile -Value $report -Path (Join-Path $workspacePath 'quality-report.json')
    Write-Host "Delivery quality report applied: pairs=$pairCount cost_passed=$costPassed density_passed=$densityPassed"
}

if ($Action -eq 'Prepare') {
    Invoke-Prepare
} else {
    Invoke-Apply
}
