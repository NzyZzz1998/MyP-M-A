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
        schema_version = 1
        prepared_at_utc = [DateTime]::UtcNow.ToString('o')
        eval_source = $evalPath
        eval_count = @($evalData.evals).Count
        runs_per_configuration = $Runs
        configurations = @(
            [ordered]@{ name = 'baseline'; source = $baseline; snapshot = '_snapshots/baseline' },
            [ordered]@{ name = 'candidate'; source = $candidate; snapshot = '_snapshots/candidate' }
        )
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
    $configurationTotals = @{}
    foreach ($configuration in @($manifest.configurations)) {
        $configurationTotals[$configuration.name] = [ordered]@{
            expected_runs = 0
            complete_runs = 0
            missing_runs = 0
            invalid_runs = 0
            passed = 0
            total = 0
            response_chars = 0
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
                $state = 'complete'
                $issues = [System.Collections.Generic.List[string]]::new()
                $passed = 0
                $total = 0
                $responseChars = 0

                if (-not (Test-Path -LiteralPath $responsePath -PathType Leaf)) {
                    $state = 'missing'
                    $issues.Add('response.md is missing')
                } else {
                    $responseChars = [System.IO.File]::ReadAllText($responsePath, [System.Text.Encoding]::UTF8).Length
                }
                if (-not (Test-Path -LiteralPath $gradingPath -PathType Leaf)) {
                    $state = 'missing'
                    $issues.Add('grading.json is missing')
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
                    $totals.passed += $passed
                    $totals.total += $total
                    $totals.response_chars += $responseChars
                } elseif ($state -eq 'missing') {
                    $totals.missing_runs++
                } else {
                    $totals.invalid_runs++
                }

                $records.Add([ordered]@{
                    eval_id = [string]$metadata.id
                    eval_name = [string]$metadata.name
                    configuration = [string]$configuration.name
                    run = $runNumber
                    state = $state
                    passed = $passed
                    total = $total
                    response_chars = $responseChars
                    issues = @($issues)
                })
            }
        }
    }

    $summaryRows = [System.Collections.Generic.List[object]]::new()
    foreach ($configuration in @($manifest.configurations)) {
        $totals = $configurationTotals[$configuration.name]
        $passRate = if ($totals.total -gt 0) { [Math]::Round($totals.passed / $totals.total, 4) } else { $null }
        $averageChars = if ($totals.complete_runs -gt 0) { [Math]::Round($totals.response_chars / $totals.complete_runs, 1) } else { $null }
        $summaryRows.Add([ordered]@{
            configuration = [string]$configuration.name
            expected_runs = $totals.expected_runs
            complete_runs = $totals.complete_runs
            missing_runs = $totals.missing_runs
            invalid_runs = $totals.invalid_runs
            passed = $totals.passed
            total = $totals.total
            pass_rate = $passRate
            average_response_chars = $averageChars
        })
    }

    $report = [ordered]@{
        schema_version = 1
        validated_at_utc = [DateTime]::UtcNow.ToString('o')
        workspace = $workspacePath
        allow_incomplete = [bool]$AllowIncomplete
        summary = @($summaryRows)
        runs = @($records)
    }
    Write-JsonFile -Value $report -Path (Join-Path $workspacePath 'validation-report.json')
    Write-JsonFile -Value ([ordered]@{ summary = @($summaryRows) }) -Path (Join-Path $workspacePath 'benchmark-lite.json')

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Lightweight regression summary')
    $lines.Add('')
    $lines.Add('This file reports structure and aggregate scores only. It does not replace the official eval viewer or manual review.')
    $lines.Add('')
    $lines.Add('| Configuration | Complete | Missing | Invalid | Passed | Total | Pass rate | Avg chars |')
    $lines.Add('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |')
    foreach ($row in $summaryRows) {
        $rate = if ($null -eq $row.pass_rate) { 'n/a' } else { '{0:P1}' -f $row.pass_rate }
        $chars = if ($null -eq $row.average_response_chars) { 'n/a' } else { [string]$row.average_response_chars }
        $lines.Add("| $($row.configuration) | $($row.complete_runs)/$($row.expected_runs) | $($row.missing_runs) | $($row.invalid_runs) | $($row.passed) | $($row.total) | $rate | $chars |")
    }
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
